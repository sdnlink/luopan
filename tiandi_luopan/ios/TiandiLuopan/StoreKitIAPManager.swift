import Foundation
import StoreKit
import Combine
import CryptoKit
import Security
import UIKit

/// Live exports keep their slot until completion or cancellation. Wall-clock
/// expiry would allow a long-running share to succeed without paying for it.
struct ConsumableCreditReservations {
    private var tokens: Set<String> = []
    var count: Int { tokens.count }

    mutating func reserve(availableCredits: Int, token: String = UUID().uuidString) -> String? {
        guard availableCredits > tokens.count, !tokens.contains(token) else { return nil }
        tokens.insert(token)
        return token
    }

    func contains(_ token: String) -> Bool { tokens.contains(token) }

    @discardableResult
    mutating func finish(_ token: String) -> Bool {
        tokens.remove(token) != nil
    }
}

enum IAPLedgerStorageError: Error {
    case keychain(OSStatus)
    case invalidKey
    case missingKey
    case invalidMirror
    case persistenceFailed
}

/// Preserve the existing seal bytes while making the key eligible for system
/// backup migration. Never replace a temporarily inaccessible key or return a
/// newly generated key before Keychain confirms it was stored successfully.
final class IAPSealKeyStore {
    static let account = "com.yanxiang.compass.iap.seal.key"
    static let legacyAccount = "com.yanxiang.luopan.iap.seal.key"
    private let lock = NSLock()
    private var cachedKey: Data?
    private let read: (String) throws -> Data?
    private let write: (String, Data) throws -> Data
    private let makeMigratable: (String) throws -> Void
    private let generate: () throws -> Data

    init(read: @escaping (String) throws -> Data? = IAPSealKeyStore.readKey,
         write: @escaping (String, Data) throws -> Data = IAPSealKeyStore.writeKey,
         makeMigratable: @escaping (String) throws -> Void = IAPSealKeyStore.upgradeAccessibility,
         generate: @escaping () throws -> Data = IAPSealKeyStore.generateKey) {
        self.read = read
        self.write = write
        self.makeMigratable = makeMigratable
        self.generate = generate
    }

    func key(createIfMissing: Bool = true) throws -> SymmetricKey {
        lock.lock()
        defer { lock.unlock() }
        if let cachedKey { return SymmetricKey(data: cachedKey) }
        let key: Data
        if let existing = try read(Self.account) {
            guard existing.count >= 32 else { throw IAPLedgerStorageError.invalidKey }
            try makeMigratable(Self.account)
            key = existing
        } else if let legacy = try read(Self.legacyAccount) {
            guard legacy.count >= 32 else { throw IAPLedgerStorageError.invalidKey }
            key = try write(Self.account, legacy)
            try makeMigratable(Self.account)
        } else {
            guard createIfMissing else { throw IAPLedgerStorageError.missingKey }
            key = try write(Self.account, generate())
        }
        guard key.count >= 32 else { throw IAPLedgerStorageError.invalidKey }
        cachedKey = key
        return SymmetricKey(data: key)
    }

    static func readKey(account: String) throws -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrAccount as String: account,
                                   kSecReturnData as String: true,
                                   kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw IAPLedgerStorageError.keychain(status) }
        guard let data = item as? Data else { throw IAPLedgerStorageError.invalidKey }
        return data
    }

    static func writeKey(account: String, data: Data) throws -> Data {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrAccount as String: account,
                                   kSecValueData as String: data,
                                   kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem, let existing = try readKey(account: account) {
            try upgradeAccessibility(account: account)
            return existing
        }
        guard status == errSecSuccess else { throw IAPLedgerStorageError.keychain(status) }
        return data
    }

    static func upgradeAccessibility(account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrAccount as String: account]
        let attributes: [String: Any] = [kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else { throw IAPLedgerStorageError.keychain(status) }
    }

    static func generateKey() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw IAPLedgerStorageError.keychain(status) }
        return Data(bytes)
    }
}

/// The activity controller retains this lease until its completion handler is
/// released. Dismissing SwiftUI's sheet must not cancel a pending success.
final class TianjiExportCreditLease {
    private let lock = NSLock()
    private var finished = false
    private let settlement: (Bool) -> Void

    init(settlement: @escaping (Bool) -> Void) { self.settlement = settlement }

    func complete(success: Bool) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        lock.unlock()
        settlement(success)
    }

    deinit { complete(success: false) }
}

// MARK: - 权益校验结果 (StoreKit 2 权威校验)

public struct ReceiptValidationResult {
    public let isValidContainer: Bool
    public let bundleIDMatched: Bool
    public let purchasedProductIDs: Set<String>
    public let latestExpirationDate: Date?
    public let receiptSHA256: String
    /// StoreKit 2 中证书链可信等价于交易通过 Apple 系统级验证（.verified）。
    public let certificateChainValid: Bool
    /// StoreKit 2 中数字签名由 Apple 在系统层校验，App 无需自行解析 CMS。
    public let signatureValid: Bool

    /// 仅结构层面有效（存在已验证容器 + BundleID 匹配），不含权益确认。
    public var isStructurallyValid: Bool {
        return isValidContainer && bundleIDMatched
    }

    /// 可信权益：存在通过 Apple 系统级验证（.verified）的 AppTransaction/交易，
    /// 且 BundleID 匹配。StoreKit 2 的签名与证书链由系统保证，
    /// 不再依赖本地 ASN.1/CMS 手写验签。
    public var isTrusted: Bool {
        return isValidContainer && bundleIDMatched && certificateChainValid && signatureValid
    }
}

/// A signed grant for the active one-shot case. New grants also require a
/// committed debit in the sealed ledger; an interrupted save cannot unlock one.
public struct FloorplanAccessGrant: Codable, Equatable {
    public let id: String
    public let signature: String
    var requiresCommittedDebit: Bool { id.hasPrefix("floorplan-v2-") }

    public init(id: String, signature: String) {
        self.id = id
        self.signature = signature
    }
}

/// Keep saving and settlement in one path for both image import and report
/// generation. Failed saves release the slot without ever spending a credit.
enum FloorplanCreditPurchase {
    enum Outcome {
        case unavailable, saveFailed, commitFailed
        case completed(FloorplanAccessGrant)
    }

    static func acquire(reserve: () -> FloorplanAccessGrant?,
                        persist: (FloorplanAccessGrant) -> Bool,
                        commit: (FloorplanAccessGrant) -> Bool,
                        cancel: (FloorplanAccessGrant) -> Void) -> Outcome {
        guard let grant = reserve() else { return .unavailable }
        defer { cancel(grant) }
        guard persist(grant) else { return .saveFailed }
        guard commit(grant) else { return .commitFailed }
        return .completed(grant)
    }
}

// MARK: - IAP 商品与权益定义

public enum IAPProductID: String, CaseIterable, Equatable {
    case vipYearly = "com.yanxiang.compass.vip.yearly"           // 演象·年度堪舆会员 198元/年
    case proLifetime = "com.yanxiang.compass.pro.lifetime"       // 演象·大师终身版 298元 一次性买断
    case floorplanSingle = "com.yanxiang.compass.floorplan.case"   // 户型空间立极·单套全案 19.9元
    case tianjiSingle = "com.yanxiang.compass.tianji.single"       // 福宅天机宣纸长卷·单次高清导出 9.9元

    var title: String {
        switch self {
        case .vipYearly: return LocalizationManager.shared.t("product_vip_yearly_title")
        case .proLifetime: return LocalizationManager.shared.t("product_pro_lifetime_title")
        case .floorplanSingle: return LocalizationManager.shared.t("product_floorplan_single_title")
        case .tianjiSingle: return LocalizationManager.shared.t("product_tianji_single_title")
        }
    }

    var priceText: String {
        // Prices are storefront-specific and must never come from a language
        // table. This value is only used while StoreKit is still loading.
        return LocalizationManager.shared.t("price_unavailable")
    }

    var desc: String {
        switch self {
        case .vipYearly: return LocalizationManager.shared.t("product_vip_yearly_desc")
        case .proLifetime: return LocalizationManager.shared.t("product_pro_lifetime_desc")
        case .floorplanSingle: return LocalizationManager.shared.t("product_floorplan_single_desc")
        case .tianjiSingle: return LocalizationManager.shared.t("product_tianji_single_desc")
        }
    }

    var includesAllFeatures: Bool { self == .vipYearly || self == .proLifetime }
}

/// A purchase disclosure is usable only when the App Store supplies a complete
/// title, storefront price and billing period. Product names never imply cadence.
struct SubscriptionPurchaseTerms: Equatable {
    enum Unit: CaseIterable, Equatable {
        case day, week, month, year

        func formatKey(value: Int) -> String {
            switch (self, value == 1) {
            case (.day, true): return "subscription_period_day_one"
            case (.day, false): return "subscription_period_day_many"
            case (.week, true): return "subscription_period_week_one"
            case (.week, false): return "subscription_period_week_many"
            case (.month, true): return "subscription_period_month_one"
            case (.month, false): return "subscription_period_month_many"
            case (.year, true): return "subscription_period_year_one"
            case (.year, false): return "subscription_period_year_many"
            }
        }
    }

    let title: String
    let displayPrice: String
    let periodValue: Int
    let periodUnit: Unit

    init?(title: String, displayPrice: String, periodValue: Int, periodUnit: Unit) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let price = displayPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !price.isEmpty, periodValue > 0 else { return nil }
        self.title = title
        self.displayPrice = price
        self.periodValue = periodValue
        self.periodUnit = periodUnit
    }

    var localizedPeriod: String {
        String(format: LocalizationManager.shared.t(periodUnit.formatKey(value: periodValue)), periodValue)
    }

    var localizedPricePerPeriod: String {
        String(format: LocalizationManager.shared.t("subscription_price_per_period"), displayPrice, localizedPeriod)
    }
}

/// Product identifiers used by released builds.  Product IDs are immutable in
/// App Store Connect, so an app update must continue to recognize identifiers
/// from older builds while presenting the current canonical IDs to StoreKit.
private enum IAPProductKind {
    case vipYearly
    case proLifetime
    case floorplanSingle
    case tianjiSingle
}

/// Access is protected by the manager's entitlement lock. A pre-sync scan must
/// never overwrite the authoritative result of an explicit restore.
struct EntitlementScanCoordinator {
    private(set) var revision = 0
    private(set) var isRestoring = false

    mutating func beginRestore() {
        isRestoring = true
        revision += 1
    }

    mutating func beginScan(restoring: Bool) -> Int? {
        guard restoring || !isRestoring else { return nil }
        revision += 1
        return revision
    }

    mutating func revoke() { revision += 1 }
    mutating func endRestore() { isRestoring = false }
    func canCommit(_ expectedRevision: Int) -> Bool { revision == expectedRevision }
}

enum PurchaseRestoreEnvironment {
    case production, sandbox, xcode, unknown

    var noPurchasesMessageKey: String {
        switch self {
        case .sandbox: return "iap_restore_none_sandbox"
        case .xcode: return "iap_restore_none_xcode"
        case .production, .unknown: return "iap_restore_none"
        }
    }
}

enum EntitlementVerificationOutcome {
    case verified([String])
    case unavailable
    case superseded
}

// MARK: - IAP 代理协议

public protocol StoreKitIAPManagerDelegate: AnyObject {
    func iapManagerDidUpdateProducts(_ products: [Product])
    func iapManagerDidCompletePurchase(productId: String, transactionId: String)
    func iapManagerDidFailPurchase(productId: String, errorMsg: String)
    func iapManagerDidRestorePurchases(unlockedProductIds: [String])
}

// MARK: - StoreKit 2 管理器（验证为主、本地为辅的权益模型）

/// 权益计算逻辑（对应业务要求）：
/// 1. 购买成功 ≠ 永久拥有会员。年度订阅的会员状态只由
///    `Transaction.currentEntitlements` 中**当前有效**的订阅交易决定，
///    到期日采用苹果权威 `expirationDate`，订阅失效即撤销，不存在“买断”误判。
/// 2. 自动续订 ≠ 当前订阅始终有效。每次权威验证都重新读取
///    `currentEntitlements`：续费成功则刷新到期日，扣款失败/用户取消续订
///    则到期后自动消失（不是本地 +365 天推算）。
/// 3. 删除 App 后重装可恢复。重装后本地无任何数据，权益完全由
///    `currentEntitlements` 驱动恢复（苹果按账号同步未撤销交易）。
/// 4. 退款及时撤销。`Transaction.updates` 推送撤销交易（revocationDate）
///    时立即权威对账；若 App 未运行，系统保留该事件，启动/回前台时
///    `currentEntitlements` 已不含退款交易，对账即收回。
/// 5. 本地缓存不代替苹果交易验证。本地仅保存“最近一次苹果验证结果的
///    全量镜像”（带 Keychain HMAC 封印防篡改），且只由权威验证覆写；
///    无验证背书（重装/首次启动）不显示任何权益，验证完成前保持锁定。
public class StoreKitIAPManager: ObservableObject {

    public static let shared = StoreKitIAPManager()
    public weak var delegate: StoreKitIAPManagerDelegate?

    @Published public var isVIPUser: Bool = false
    @Published public var isLifetimeUser: Bool = false
    @Published public var floorplanCreditsCount: Int = 0
    @Published public var tianjiCreditsCount: Int = 0
    @Published public private(set) var isLoadingProducts: Bool = false
    /// Invalidates price views whenever StoreKit returns metadata. This is
    /// separate from the loading flag because a paywall may be presented
    /// after a request has already completed.
    @Published public private(set) var productsRevision: Int = 0
    @Published public private(set) var isProcessingPurchase: Bool = false
    @Published public private(set) var isRestoringPurchases: Bool = false
    @Published public private(set) var lastErrorMessage: String?
    @Published public private(set) var lastStatusMessage: String?
    @Published public private(set) var lastCompletedProductID: String?

    // MARK: - 权益镜像模型

    struct ConsumableGrant: Codable {
        var productID: String
        var consumed: Bool
        var revoked: Bool
    }

    /// 本地权益镜像：唯一被 UI 读取的本地数据，只由权威验证覆写。
    /// - 验证段（isLifetime / vipExpireDate / purchasedProductIDs）：由
    ///   `Transaction.currentEntitlements` 全量覆写，权威验证完成即覆盖，
    ///   订阅失效/退款后覆写为空即撤销。
    /// - 账本段（floorplanCredits / tianjiCredits）：消费型商品本地记账，
    ///   仅在苹果已验证交易背书下增减；验证覆写不触碰账本段。
    /// - isAuthoritative == false 仅表示一次性从旧版（v1 标志）迁移的数据，
    ///   启动后立即被首次权威验证覆盖。
    struct EntitlementMirror: Codable {
        var verifiedAt: Date
        var isAuthoritative: Bool
        var isLifetime: Bool
        /// Apple 当前仍授予年度订阅（交易未撤销地存在于 currentEntitlements，
        /// 或 SubscriptionInfo.status 显示 subscribed/inGracePeriod）。
        /// 宽限期内 expirationDate 已过但权益有效，此时 vipExpireDate 不可靠，
        /// 必须靠本标志保持可用，避免把有效会员锁成 0。
        var vipActive: Bool
        var vipExpireDate: TimeInterval
        var floorplanCredits: Int
        var tianjiCredits: Int
        var purchasedProductIDs: [String]
        /// Maps each newly minted consumable credit to its transaction. This
        /// lets a later Apple revocation remove an unused credit locally.
        var consumableGrants: [String: ConsumableGrant]
        /// Durable idempotency ledger for verified transactions. Keeping this
        /// in the sealed mirror makes credit minting and transaction claiming
        /// one persisted state transition.
        var processedTransactionIDs: [String]
        var redeemedFloorplanGrantIDs: [String]

        mutating func redeemFloorplanGrant(_ id: String) -> Bool {
            guard isAuthoritative, floorplanCredits > 0,
                  !redeemedFloorplanGrantIDs.contains(id) else { return false }
            floorplanCredits -= 1
            redeemedFloorplanGrantIDs.append(id)
            return true
        }

        mutating func applyMembershipSnapshot(from verified: EntitlementMirror) {
            verifiedAt = verified.verifiedAt
            isAuthoritative = verified.isAuthoritative
            isLifetime = verified.isLifetime
            vipActive = verified.vipActive
            vipExpireDate = verified.vipExpireDate
            purchasedProductIDs = verified.purchasedProductIDs
        }

        func allowsFamilyRoomAllocation(at date: Date) -> Bool {
            isAuthoritative && (isLifetime || vipActive || vipExpireDate > date.timeIntervalSince1970)
        }

        func restoredProductIDs(confirmed: [String], at date: Date) -> [String] {
            guard isAuthoritative else { return [] }
            return Array(Set(confirmed)).filter { productID in
                switch productID {
                case IAPProductID.vipYearly.rawValue:
                    return vipActive || vipExpireDate > date.timeIntervalSince1970
                case IAPProductID.proLifetime.rawValue:
                    return isLifetime
                default:
                    return false
                }
            }.sorted()
        }

        mutating func revokePaidProduct(_ productID: String) {
            if productID == IAPProductID.proLifetime.rawValue {
                isLifetime = false
            } else if productID == IAPProductID.vipYearly.rawValue {
                vipActive = false
                vipExpireDate = 0
            }
            purchasedProductIDs.removeAll { $0 == productID }
        }

        private enum CodingKeys: String, CodingKey {
            case verifiedAt, isAuthoritative, isLifetime, vipActive, vipExpireDate
            case floorplanCredits, tianjiCredits, purchasedProductIDs
            case consumableGrants
            case processedTransactionIDs
            case redeemedFloorplanGrantIDs
        }

        init(verifiedAt: Date,
             isAuthoritative: Bool,
             isLifetime: Bool,
             vipActive: Bool,
             vipExpireDate: TimeInterval,
             floorplanCredits: Int,
             tianjiCredits: Int,
             purchasedProductIDs: [String],
             consumableGrants: [String: ConsumableGrant] = [:],
             processedTransactionIDs: [String] = [],
             redeemedFloorplanGrantIDs: [String] = []) {
            self.verifiedAt = verifiedAt
            self.isAuthoritative = isAuthoritative
            self.isLifetime = isLifetime
            self.vipActive = vipActive
            self.vipExpireDate = vipExpireDate
            self.floorplanCredits = floorplanCredits
            self.tianjiCredits = tianjiCredits
            self.purchasedProductIDs = purchasedProductIDs
            self.consumableGrants = consumableGrants
            self.processedTransactionIDs = processedTransactionIDs
            self.redeemedFloorplanGrantIDs = redeemedFloorplanGrantIDs
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            verifiedAt = try container.decode(Date.self, forKey: .verifiedAt)
            isAuthoritative = try container.decode(Bool.self, forKey: .isAuthoritative)
            isLifetime = try container.decode(Bool.self, forKey: .isLifetime)
            // Mirrors written before the Apple-grant flag existed keep a false
            // value and are refreshed by the next authoritative verification.
            vipActive = try container.decodeIfPresent(Bool.self, forKey: .vipActive) ?? false
            vipExpireDate = try container.decode(TimeInterval.self, forKey: .vipExpireDate)
            floorplanCredits = try container.decode(Int.self, forKey: .floorplanCredits)
            tianjiCredits = try container.decode(Int.self, forKey: .tianjiCredits)
            purchasedProductIDs = try container.decode([String].self, forKey: .purchasedProductIDs)
            consumableGrants = try container.decodeIfPresent([String: ConsumableGrant].self, forKey: .consumableGrants) ?? [:]
            // Mirrors written before the idempotency ledger was introduced
            // decode as an empty ledger and are migrated from the legacy key
            // when the next verified transaction is handled.
            processedTransactionIDs = try container.decodeIfPresent([String].self, forKey: .processedTransactionIDs) ?? []
            redeemedFloorplanGrantIDs = try container.decodeIfPresent([String].self, forKey: .redeemedFloorplanGrantIDs) ?? []
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(verifiedAt, forKey: .verifiedAt)
            try container.encode(isAuthoritative, forKey: .isAuthoritative)
            try container.encode(isLifetime, forKey: .isLifetime)
            try container.encode(vipActive, forKey: .vipActive)
            try container.encode(vipExpireDate, forKey: .vipExpireDate)
            try container.encode(floorplanCredits, forKey: .floorplanCredits)
            try container.encode(tianjiCredits, forKey: .tianjiCredits)
            try container.encode(purchasedProductIDs, forKey: .purchasedProductIDs)
            try container.encode(consumableGrants, forKey: .consumableGrants)
            try container.encode(processedTransactionIDs, forKey: .processedTransactionIDs)
            try container.encode(redeemedFloorplanGrantIDs, forKey: .redeemedFloorplanGrantIDs)
        }
    }

    private let kMirrorKey = "yx_iap_entitlement_mirror_v2"
    private let kMirrorSealKey = "yx_iap_entitlement_mirror_seal"
    private let kSealedMirrorKey = "yx_iap_sealed_ledger_v1"
    private let sealKeyStore = IAPSealKeyStore()
    private var ledgerStorageUnavailable = false
    /// Apple can still restore memberships while an old consumable ledger is
    /// unreadable. Keep those verified rights in memory without overwriting it.
    private var verifiedMembershipFallback: EntitlementMirror?
    private let storageFeedbackLock = NSLock()
    private var didReportStorageFailure = false

    private struct SealedMirrorEnvelope: Codable {
        let data: Data
        let seal: String
    }
    // 旧版（v1）本地标志，仅供一次性迁移读取，不再作为权益真值
    private let kIsVIP = "yx_iap_is_vip"
    private let kIsLifetime = "yx_iap_is_lifetime"
    private let kVIPExpireDate = "yx_iap_vip_expire_date"
    private let kFloorplanCredits = "yx_iap_floorplan_credits"
    private let kTianjiCredits = "yx_iap_tianji_credits"
    private let kProcessedTransactionIDs = "yx_iap_processed_transaction_ids"

    private var availableProducts: [String: Product] = [:]
    private var lastProductsFetchDate: Date?
    private let productsRetryInterval: TimeInterval = 30
    private let entitlementLock = NSLock()
    private var entitlementScans = EntitlementScanCoordinator()
    private var revokedEntitlementTransactionIDs = Set<UInt64>()
    /// In-flight exports reserve a slot in memory and only debit the durable
    /// balance after the deliverable succeeds.  A process termination therefore
    /// cannot permanently destroy a paid credit. Active operations own their
    /// reservation until completion, cancellation, or controller teardown.
    private var activeTianjiReservations = ConsumableCreditReservations()
    private var activeFloorplanReservations = ConsumableCreditReservations()
    private var transactionListener: Task<Void, Never>?
    private var unfinishedTransactionsTask: Task<Void, Never>?
    private var verificationTask: Task<Void, Never>?
    /// 内存镜像（主线程读写），避免 SwiftUI 每帧 JSON 解码 + HMAC
    private var cachedMirror: EntitlementMirror?
    private var cachedMirrorLoadedFromStorage = false

    private func productKind(for productID: String) -> IAPProductKind? {
        switch productID {
        case IAPProductID.vipYearly.rawValue, "com.yanxiang.luopan.vip.yearly":
            return .vipYearly
        case IAPProductID.proLifetime.rawValue, "com.yanxiang.luopan.pro.lifetime":
            return .proLifetime
        case IAPProductID.floorplanSingle.rawValue,
             "com.yanxiang.compass.floorplan.single",
             "com.yanxiang.luopan.floorplan.single":
            return .floorplanSingle
        case IAPProductID.tianjiSingle.rawValue, "com.yanxiang.luopan.tianji.single":
            return .tianjiSingle
        default:
            return nil
        }
    }

    // MARK: - 初始化

    private init() {
        // 1. 一次性迁移旧版 v1 标志到镜像（带封印，权威验证会立即覆盖）
        migrateLegacyEntitlementsIfNeeded()
        migrateLegacyTransactionLedgerIfNeeded()
        // 2. 同步读取镜像用于启动即时的 UI 反馈；无镜像（重装/首启）保持锁定
        let mirror = currentMirror()
        self.isVIPUser = mirror.map { $0.isAuthoritative && ($0.isLifetime || $0.vipActive || $0.vipExpireDate > Date().timeIntervalSince1970) } ?? false
        self.isLifetimeUser = mirror?.isAuthoritative == true && (mirror?.isLifetime ?? false)
        self.floorplanCreditsCount = mirror?.isAuthoritative == true ? (mirror?.floorplanCredits ?? 0) : 0
        self.tianjiCreditsCount = mirror?.isAuthoritative == true ? (mirror?.tianjiCredits ?? 0) : 0
        // 3. 交易监听（续期/退款/跨设备恢复/Ask to Buy 结果）
        listenForTransactions()
        retryUnfinishedTransactions()
        // 4. 权威对账（currentEntitlements 驱动，验证完成即覆写镜像）
        runVerification()
        fetchProducts()
    }

    deinit {
        transactionListener?.cancel()
        unfinishedTransactionsTask?.cancel()
        verificationTask?.cancel()
    }

    public func purchase(productId: String) {
        purchaseProduct(id: productId)
    }

    // MARK: - 权益镜像（本地缓存层，绝不独立裁决权益）

    private func freshEmptyMirror() -> EntitlementMirror {
        EntitlementMirror(verifiedAt: Date(),
                          isAuthoritative: false,
                          isLifetime: false,
                          vipActive: false,
                          vipExpireDate: 0,
                          floorplanCredits: 0,
                          tianjiCredits: 0,
                          purchasedProductIDs: [],
                          consumableGrants: [:],
                          processedTransactionIDs: [])
    }

    /// 读内存镜像（带锁）；首次访问从磁盘读取并校验 HMAC 封印（篡改视为无镜像）。
    /// 所有镜像内存访问都在 entitlementLock 保护下，避免异步对账与 UI 查询竞争。
    private func currentMirror() -> EntitlementMirror? {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        return currentMirrorLocked()
    }

    /// 假设调用方已持有 entitlementLock。
    private func currentMirrorLocked() -> EntitlementMirror? {
        if !cachedMirrorLoadedFromStorage {
            do {
                cachedMirror = try readMirrorFromStorage()
                if let verified = verifiedMembershipFallback {
                    if cachedMirror == nil { cachedMirror = verified }
                    else { cachedMirror?.applyMembershipSnapshot(from: verified) }
                    verifiedMembershipFallback = nil
                }
                cachedMirrorLoadedFromStorage = true
                ledgerStorageUnavailable = false
                resetStorageFailureFeedback()
            } catch {
                // Retry later and preserve every stored byte. An inaccessible
                // key is not evidence that the customer has no paid balance.
                ledgerStorageUnavailable = true
                reportLedgerStorageFailure()
                return verifiedMembershipFallback
            }
        }
        return cachedMirror
    }

    private func readMirrorFromStorage() throws -> EntitlementMirror? {
        let defaults = UserDefaults.standard
        let data: Data
        let seal: String
        if let envelopeData = defaults.data(forKey: kSealedMirrorKey) {
            let envelope = try JSONDecoder().decode(SealedMirrorEnvelope.self, from: envelopeData)
            data = envelope.data
            seal = envelope.seal
        } else {
            guard let legacyData = defaults.data(forKey: kMirrorKey) else { return nil }
            guard let legacySeal = defaults.string(forKey: kMirrorSealKey) else {
                throw IAPLedgerStorageError.invalidMirror
            }
            data = legacyData
            seal = legacySeal
        }
        let mirror = try JSONDecoder().decode(EntitlementMirror.self, from: data)
        // Do not generate a replacement key for an existing paid ledger.
        let key = try sealKeyStore.key(createIfMissing: false)
        // Mirrors written before per-transaction consumable grants were added
        // used the v2 payload. Accept that seal once and re-seal on the next
        // entitlement/transaction write so upgrades do not discard a valid
        // local cache.
        guard computeMirrorSeal(mirror, using: key) == seal
                || (mirror.redeemedFloorplanGrantIDs.isEmpty && (
                    computeV4MirrorSeal(mirror, using: key) == seal
                    || computeV3MirrorSeal(mirror, using: key) == seal
                    || computePreConsumableGrantSeal(mirror, using: key) == seal
                    || computeLegacyMirrorSeal(mirror, using: key) == seal)) else {
            throw IAPLedgerStorageError.invalidMirror
        }
        return mirror
    }

    /// 覆写镜像（带锁）。
    @discardableResult
    private func updateMirror(_ mirror: EntitlementMirror) -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        return updateMirrorLocked(mirror)
    }

    /// 假设调用方已持有 entitlementLock。
    @discardableResult
    private func updateMirrorLocked(_ mirror: EntitlementMirror) -> Bool {
        guard !ledgerStorageUnavailable else { reportLedgerStorageFailure(); return false }
        do {
            let key = try sealKeyStore.key()
            let data = try JSONEncoder().encode(mirror)
            let envelope = SealedMirrorEnvelope(data: data, seal: computeMirrorSeal(mirror, using: key))
            // The payload and seal must be a single defaults value. Separate
            // writes can leave a valid paid ledger with a mismatched old seal.
            UserDefaults.standard.set(try JSONEncoder().encode(envelope), forKey: kSealedMirrorKey)
            cachedMirror = mirror
            cachedMirrorLoadedFromStorage = true
            resetStorageFailureFeedback()
            UserDefaults.standard.removeObject(forKey: kMirrorKey)
            UserDefaults.standard.removeObject(forKey: kMirrorSealKey)
            return true
        } catch {
            reportLedgerStorageFailure()
            return false
        }
    }

    private func computeMirrorSeal(_ mirror: EntitlementMirror, using key: SymmetricKey) -> String {
        let legacySeal = computeV4MirrorSeal(mirror, using: key)
        let payload = "v5|\(legacySeal)|\(mirror.redeemedFloorplanGrantIDs.sorted().joined(separator: ","))"
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    private func computeV4MirrorSeal(_ mirror: EntitlementMirror, using key: SymmetricKey) -> String {
        let payload = "v4|\(Int64(mirror.verifiedAt.timeIntervalSince1970.rounded()))|\(mirror.isAuthoritative ? 1 : 0)|\(mirror.isLifetime ? 1 : 0)|\(mirror.vipActive ? 1 : 0)|\(Int64(mirror.vipExpireDate.rounded()))|\(mirror.floorplanCredits)|\(mirror.tianjiCredits)|\(mirror.purchasedProductIDs.sorted().joined(separator: ","))|\(mirror.processedTransactionIDs.sorted().joined(separator: ","))|\(consumableGrantSealPayload(mirror.consumableGrants))"
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    /// Seal format used by the immediately preceding mirror version (v3),
    /// which predates the vipActive Apple-grant flag. It remains readable so
    /// an upgrade does not discard a valid local cache; the next authoritative
    /// verification re-seals with the current payload.
    private func computeV3MirrorSeal(_ mirror: EntitlementMirror, using key: SymmetricKey) -> String {
        let payload = "v3|\(Int64(mirror.verifiedAt.timeIntervalSince1970.rounded()))|\(mirror.isAuthoritative ? 1 : 0)|\(mirror.isLifetime ? 1 : 0)|\(Int64(mirror.vipExpireDate.rounded()))|\(mirror.floorplanCredits)|\(mirror.tianjiCredits)|\(mirror.purchasedProductIDs.sorted().joined(separator: ","))|\(mirror.processedTransactionIDs.sorted().joined(separator: ","))|\(consumableGrantSealPayload(mirror.consumableGrants))"
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    /// Seal format used by the immediately preceding mirror version, which
    /// already included processed transaction IDs but did not track grant
    /// ownership. It remains readable so an upgrade does not discard a valid
    /// local balance.
    private func computePreConsumableGrantSeal(_ mirror: EntitlementMirror, using key: SymmetricKey) -> String {
        let payload = "v2|\(Int64(mirror.verifiedAt.timeIntervalSince1970.rounded()))|\(mirror.isAuthoritative ? 1 : 0)|\(mirror.isLifetime ? 1 : 0)|\(Int64(mirror.vipExpireDate.rounded()))|\(mirror.floorplanCredits)|\(mirror.tianjiCredits)|\(mirror.purchasedProductIDs.sorted().joined(separator: ","))|\(mirror.processedTransactionIDs.sorted().joined(separator: ","))"
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    private func computeLegacyMirrorSeal(_ mirror: EntitlementMirror, using key: SymmetricKey) -> String {
        let payload = "v2|\(Int64(mirror.verifiedAt.timeIntervalSince1970.rounded()))|\(mirror.isAuthoritative ? 1 : 0)|\(mirror.isLifetime ? 1 : 0)|\(Int64(mirror.vipExpireDate.rounded()))|\(mirror.floorplanCredits)|\(mirror.tianjiCredits)|\(mirror.purchasedProductIDs.sorted().joined(separator: ","))"
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    private func consumableGrantSealPayload(_ grants: [String: ConsumableGrant]) -> String {
        grants.keys.sorted().compactMap { transactionID in
            guard let grant = grants[transactionID] else { return nil }
            return "\(transactionID):\(grant.productID):\(grant.consumed ? 1 : 0):\(grant.revoked ? 1 : 0)"
        }.joined(separator: ",")
    }

    private func reportLedgerStorageFailure() {
        storageFeedbackLock.lock()
        guard !didReportStorageFailure else { storageFeedbackLock.unlock(); return }
        didReportStorageFailure = true
        storageFeedbackLock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.lastErrorMessage = LocalizationManager.shared.t("iap_storage_unavailable")
        }
    }

    private func resetStorageFailureFeedback() {
        storageFeedbackLock.lock()
        didReportStorageFailure = false
        storageFeedbackLock.unlock()
    }

    /// 一次性迁移 v1 本地标志（仅当镜像不存在时执行）。
    /// 迁移数据 isAuthoritative=false：仅作为待校验缓存保存；在首次
    /// 权威验证完成前不参与收费门控，避免退款权益或篡改状态被短暂使用。
    private func migrateLegacyEntitlementsIfNeeded() {
        guard currentMirror() == nil else { return }
        let defaults = UserDefaults.standard
        let hasLegacyData = defaults.object(forKey: kIsVIP) != nil
            || defaults.object(forKey: kIsLifetime) != nil
            || defaults.object(forKey: kVIPExpireDate) != nil
            || defaults.object(forKey: kFloorplanCredits) != nil
            || defaults.object(forKey: kTianjiCredits) != nil
        guard hasLegacyData else { return }
        var mirror = freshEmptyMirror()
        mirror.isLifetime = defaults.bool(forKey: kIsLifetime)
        mirror.vipExpireDate = defaults.double(forKey: kVIPExpireDate)
        mirror.floorplanCredits = defaults.integer(forKey: kFloorplanCredits)
        mirror.tianjiCredits = defaults.integer(forKey: kTianjiCredits)
        updateMirror(mirror)
    }

    /// Move the old unsealed processed-transaction list into the HMAC-sealed
    /// mirror before any new transaction callback can mint a credit.
    private func migrateLegacyTransactionLedgerIfNeeded() {
        let legacyIDs = Set(UserDefaults.standard.stringArray(forKey: kProcessedTransactionIDs) ?? [])
        guard !legacyIDs.isEmpty else { return }
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard var mirror = currentMirrorLocked() else { return }
        let merged = Set(mirror.processedTransactionIDs).union(legacyIDs)
        mirror.processedTransactionIDs = merged.sorted()
        guard updateMirrorLocked(mirror) else { return }
        UserDefaults.standard.removeObject(forKey: kProcessedTransactionIDs)
    }

    // MARK: - 权益查询（只读镜像；无验证背书不显示权益）

    public var hasUnlockedVIP: Bool {
        // 镜像缺失（重装/首启）→ 返回 false 保持锁定；权威验证由
        // init / refreshEntitlements / 购买完成 / updates 事件持续驱动。
        guard let mirror = currentMirror(), mirror.isAuthoritative else { return false }
        if mirror.isLifetime { return true }
        // 苹果当前授予中（含宽限期/账单重试）不因本地到期日已过而锁
        if mirror.vipActive { return true }
        if mirror.vipExpireDate > Date().timeIntervalSince1970 { return true }
        return false
    }

    public var canUseFloorplan: Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return false }
        return isVIPUnlocked() || mirror.floorplanCredits > activeFloorplanReservations.count
    }

    /// Both membership products include family room allocation; case credits do not.
    public var canUseFamilyRoomAllocation: Bool {
        currentMirror()?.allowsFamilyRoomAllocation(at: Date()) == true
    }

    public var canUseTianji: Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return false }
        if mirror.isLifetime || mirror.vipActive || mirror.vipExpireDate > Date().timeIntervalSince1970 {
            return true
        }
        // Credits are not debited while an export is in flight.  Exclude the
        // reserved slots here so a second page cannot spend the same credit.
        return mirror.tianjiCredits > activeTianjiReservations.count
    }

    public func isVIP() -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return false }
        if mirror.isLifetime { return true }
        if mirror.vipActive { return true }
        return mirror.vipExpireDate > Date().timeIntervalSince1970
    }

    public func isLifetime() -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return false }
        return mirror.isLifetime
    }

    public func floorplanCredits() -> Int {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return 0 }
        return mirror.floorplanCredits
    }

    public func tianjiCredits() -> Int {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return 0 }
        return mirror.tianjiCredits
    }

    private func isVIPUnlocked() -> Bool {
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return false }
        if mirror.isLifetime { return true }
        if mirror.vipActive { return true }
        return mirror.vipExpireDate > Date().timeIntervalSince1970
    }

    /// Mark the oldest unused grant for a successful one-shot operation. The
    /// aggregate balance remains the source used by the UI, while this small
    /// per-transaction ledger makes later refund/revocation handling precise.
    private func markConsumableGrantConsumedLocked(
        kind: IAPProductKind,
        mirror: inout EntitlementMirror
    ) {
        for transactionID in mirror.consumableGrants.keys.sorted() {
            guard var grant = mirror.consumableGrants[transactionID],
                  !grant.consumed,
                  !grant.revoked,
                  let grantKind = productKind(for: grant.productID) else { continue }
            let matches: Bool
            switch (kind, grantKind) {
            case (.floorplanSingle, .floorplanSingle), (.tianjiSingle, .tianjiSingle):
                matches = true
            default:
                matches = false
            }
            guard matches else { continue }
            grant.consumed = true
            mirror.consumableGrants[transactionID] = grant
            return
        }
    }

    /// Revoke an unused local consumable credit when StoreKit reports a
    /// refund. A credit already spent cannot be reconstructed locally; the
    /// server ledger remains required for cross-device and post-consumption
    /// refund policy.
    private func revokeConsumableGrant(productID: String, transactionID: String) -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        // A revocation can be delivered immediately after the purchase and
        // before the first entitlement snapshot marks the mirror
        // authoritative.  The transaction itself is already StoreKit
        // verified, so revoke a matching grant regardless of that snapshot
        // flag; otherwise the credit could survive until a later sync.
        let stored = currentMirrorLocked()
        guard !ledgerStorageUnavailable else { return false }
        guard var mirror = stored,
              var grant = mirror.consumableGrants[transactionID],
              !grant.revoked else { return true }
        grant.revoked = true
        mirror.consumableGrants[transactionID] = grant
        if !grant.consumed, let kind = productKind(for: productID) {
            switch kind {
            case .floorplanSingle:
                mirror.floorplanCredits = max(0, mirror.floorplanCredits - 1)
            case .tianjiSingle:
                mirror.tianjiCredits = max(0, mirror.tianjiCredits - 1)
            case .vipYearly, .proLifetime:
                break
            }
        }
        guard updateMirrorLocked(mirror) else { return false }
        let floorplan = mirror.floorplanCredits
        let tianji = mirror.tianjiCredits
        DispatchQueue.main.async { [weak self] in
            self?.floorplanCreditsCount = floorplan
            self?.tianjiCreditsCount = tianji
        }
        return true
    }

    // MARK: - 消费型商品记账（仅苹果已验证交易背书下增减）

    /// Compatibility migration for previously paid unsigned layouts only.
    /// New purchases must use reserve/commit so a failed save never debits.
    public func issueFloorplanAccessGrant() -> FloorplanAccessGrant? {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        _ = currentMirrorLocked()
        guard !ledgerStorageUnavailable else { return nil }
        let id = UUID().uuidString
        do {
            return FloorplanAccessGrant(id: id, signature: try floorplanGrantSignature(for: id, createKey: true))
        } catch {
            reportLedgerStorageFailure()
            return nil
        }
    }

    public func validateFloorplanAccessGrant(_ grant: FloorplanAccessGrant) -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard !grant.id.isEmpty, !grant.signature.isEmpty else { return false }
        guard (try? floorplanGrantSignature(for: grant.id)) == grant.signature else { return false }
        return !grant.requiresCommittedDebit
            || currentMirrorLocked()?.redeemedFloorplanGrantIDs.contains(grant.id) == true
    }

    private func floorplanGrantSignature(for id: String, createKey: Bool = false) throws -> String {
        let payload = Data("floorplan-grant-v1|\(id)".utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: payload,
                                                 using: try sealKeyStore.key(createIfMissing: createKey))
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    public func reserveFloorplanCredit() -> FloorplanAccessGrant? {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative, !isVIPUnlocked(),
              mirror.floorplanCredits > activeFloorplanReservations.count else { return nil }
        let id = "floorplan-v2-\(UUID().uuidString)"
        do {
            let signature = try floorplanGrantSignature(for: id)
            guard activeFloorplanReservations.reserve(availableCredits: mirror.floorplanCredits, token: id) != nil else { return nil }
            return FloorplanAccessGrant(id: id, signature: signature)
        } catch {
            reportLedgerStorageFailure()
            return nil
        }
    }

    /// The caller must first persist the layout containing this grant. The
    /// debit and grant activation then become one sealed ledger transition.
    public func commitFloorplanCreditReservation(_ grant: FloorplanAccessGrant) -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard grant.requiresCommittedDebit,
              (try? floorplanGrantSignature(for: grant.id)) == grant.signature,
              var mirror = currentMirrorLocked() else { return false }
        if mirror.redeemedFloorplanGrantIDs.contains(grant.id) { return true }
        guard activeFloorplanReservations.contains(grant.id), mirror.redeemFloorplanGrant(grant.id) else { return false }
        markConsumableGrantConsumedLocked(kind: .floorplanSingle, mirror: &mirror)
        guard updateMirrorLocked(mirror) else { return false }
        activeFloorplanReservations.finish(grant.id)
        let remain = mirror.floorplanCredits
        DispatchQueue.main.async { [weak self] in self?.floorplanCreditsCount = remain }
        return true
    }

    public func cancelFloorplanCreditReservation(_ grant: FloorplanAccessGrant) {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        activeFloorplanReservations.finish(grant.id)
    }

    public func consumeTianjiCredit() -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return false }
        if isVIPUnlocked() { return true }
        guard mirror.tianjiCredits > activeTianjiReservations.count else { return false }
        var updated = mirror
        updated.tianjiCredits -= 1
        markConsumableGrantConsumedLocked(kind: .tianjiSingle, mirror: &updated)
        guard updateMirrorLocked(updated) else { return false }
        let remain = updated.tianjiCredits
        DispatchQueue.main.async { [weak self] in self?.tianjiCreditsCount = remain }
        return true
    }

    /// Reserve one export slot before an asynchronous save/share operation.
    /// The durable credit is debited only after the deliverable succeeds;
    /// process termination therefore leaves the paid credit available. The
    /// token makes commit/refund idempotent across completion callbacks.
    public func reserveTianjiCredit() -> String? {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return nil }
        if isVIPUnlocked() { return nil }
        return activeTianjiReservations.reserve(availableCredits: mirror.tianjiCredits)
    }

    /// Commit a reservation after the deliverable was produced. This is the
    /// only path that debits the durable balance for an export.
    public func commitTianjiCreditReservation(_ token: String) {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard activeTianjiReservations.contains(token) else { return }
        guard var mirror = currentMirrorLocked(), mirror.isAuthoritative,
              mirror.tianjiCredits > 0 else { return }
        mirror.tianjiCredits -= 1
        markConsumableGrantConsumedLocked(kind: .tianjiSingle, mirror: &mirror)
        guard updateMirrorLocked(mirror) else { return }
        activeTianjiReservations.finish(token)
        let remain = mirror.tianjiCredits
        DispatchQueue.main.async { [weak self] in self?.tianjiCreditsCount = remain }
    }

    /// Return a reservation when the export/share operation failed or was
    /// cancelled. Since reservation does not debit the balance, this only
    /// releases the in-flight slot. Repeated calls are harmless.
    public func refundTianjiCreditReservation(_ token: String) {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        activeTianjiReservations.finish(token)
    }

    /// Atomically claim a verified transaction and, for consumables, mint its
    /// credit in the same sealed mirror write. Replayed transactions return
    /// false but are still finished by the caller, so a crash cannot either
    /// lose a credit or leave a transaction permanently pending.
    private func applyVerifiedTransactionIfNeeded(productID: String, transactionID: String) throws -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let kind = productKind(for: productID) else { return false }
        var mirror = currentMirrorLocked() ?? freshEmptyMirror()
        guard !ledgerStorageUnavailable else { throw IAPLedgerStorageError.persistenceFailed }
        // Migrate the legacy unsealed ledger into the sealed mirror before
        // checking the transaction. This prevents an old build's processed ID
        // from minting a second credit after upgrade.
        let legacyIDs = Set(UserDefaults.standard.stringArray(forKey: kProcessedTransactionIDs) ?? [])
        var processedIDs = Set(mirror.processedTransactionIDs).union(legacyIDs)
        guard !processedIDs.contains(transactionID) else { return false }
        processedIDs.insert(transactionID)
        mirror.processedTransactionIDs = processedIDs.sorted()
        switch kind {
        case .floorplanSingle:
            mirror.floorplanCredits += 1
            mirror.consumableGrants[transactionID] = ConsumableGrant(
                productID: productID,
                consumed: false,
                revoked: false
            )
        case .tianjiSingle:
            mirror.tianjiCredits += 1
            mirror.consumableGrants[transactionID] = ConsumableGrant(
                productID: productID,
                consumed: false,
                revoked: false
            )
        case .vipYearly, .proLifetime:
            break
        }
        guard updateMirrorLocked(mirror) else { throw IAPLedgerStorageError.persistenceFailed }
        if !legacyIDs.isEmpty {
            UserDefaults.standard.removeObject(forKey: kProcessedTransactionIDs)
        }
        return true
    }

    private func isSupportedProductID(_ productID: String) -> Bool {
        productKind(for: productID) != nil
    }

    private func hasExpectedProductType(_ product: Product) -> Bool {
        guard let kind = productKind(for: product.id) else { return false }
        switch kind {
        case .vipYearly:
            return product.type == .autoRenewable
        case .proLifetime:
            return product.type == .nonConsumable
        case .floorplanSingle, .tianjiSingle:
            return product.type == .consumable
        }
    }

    // MARK: - 商品信息请求 (StoreKit 2)

    public func fetchProducts() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.fetchProducts() }
            return
        }
        isLoadingProducts = true
        lastProductsFetchDate = Date()
        let identifiers = Set(IAPProductID.allCases.map { $0.rawValue })
        Task {
            do {
                let storeProducts = try await Product.products(for: identifiers)
                await MainActor.run {
                    self.isLoadingProducts = false
                    self.availableProducts.removeAll()
                    for product in storeProducts {
                        guard self.hasExpectedProductType(product) else {
                            print("StoreKit product type mismatch: \(product.id) (\(product.type))")
                            continue
                        }
                        self.availableProducts[product.id] = product
                    }
                    self.productsRevision &+= 1
                    self.delegate?.iapManagerDidUpdateProducts(storeProducts)
                }
            } catch {
                await MainActor.run { self.isLoadingProducts = false }
                // Product metadata can fail to load before the user has
                // attempted a purchase (offline launch, storefront outage, or
                // a temporary App Store response). This is not a payment
                // failure; publishing it via lastErrorMessage would make every
                // paywall present a misleading purchase-error alert on startup.
                print("StoreKit request products failed: \(error.localizedDescription)")
            }
        }
    }

    /// Retry a transient product metadata failure when the app returns to the
    /// foreground or the paywall is shown. StoreKit can fail the first request
    /// during an offline launch; without a later retry all paywalls would keep
    /// showing “price unavailable” until the user attempted a purchase.
    public func refreshProductsIfNeeded(force: Bool = false) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshProductsIfNeeded(force: force)
            }
            return
        }
        if !force,
           let lastProductsFetchDate = lastProductsFetchDate,
           Date().timeIntervalSince(lastProductsFetchDate) < productsRetryInterval,
           (isLoadingProducts || !availableProducts.isEmpty) {
            return
        }
        fetchProducts()
    }

    // MARK: - 收据刷新 (StoreKit 2 AppTransaction)

    /// StoreKit 2 中收据即 AppTransaction。刷新 = 向 App Store 重新拉取
    /// AppTransaction 后重跑权威对账。订阅续期与退款由 StoreKit 自动同步，
    /// 此方法仅在需要强制重新拉取收据时使用（行为与旧 SKReceiptRefreshRequest 对齐）。
    public func refreshReceipt(completion: ((Bool) -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshReceipt(completion: completion)
            }
            return
        }
        Task {
            let ok = await refreshAppTransaction()
            DispatchQueue.main.async { completion?(ok) }
        }
    }

    private func refreshAppTransaction() async -> Bool {
        do {
            _ = try await AppTransaction.refresh()
            await verifyEntitlementsAsync()
            return (currentMirror()?.isAuthoritative ?? false)
        } catch {
            return false
        }
    }

    // MARK: - 购买商品 (StoreKit 2)

    public func purchaseProduct(id: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.purchaseProduct(id: id) }
            return
        }
        lastErrorMessage = nil
        lastStatusMessage = nil
        guard !isProcessingPurchase else { return }

        guard let product = availableProducts[id] else {
            failPurchase(id: id, message: LocalizationManager.shared.t("iap_err_product_unavailable"))
            fetchProducts()
            return
        }

        guard let productID = IAPProductID(rawValue: id), canPurchaseProduct(for: productID) else {
            failPurchase(id: id, message: LocalizationManager.shared.t("iap_err_product_unavailable"))
            fetchProducts()
            return
        }

        isProcessingPurchase = true
        Task {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await self.handleVerified(transaction)
                    case .unverified(_, let error):
                        await MainActor.run {
                            self.isProcessingPurchase = false
                            self.lastErrorMessage = error.localizedDescription
                            self.delegate?.iapManagerDidFailPurchase(productId: id, errorMsg: error.localizedDescription)
                        }
                    }
                case .userCancelled:
                    // 与旧实现一致：取消不清空 lastErrorMessage（避免误导），
                    // 但 delegate 仍收到失败回调供 UI 复位。
                    await MainActor.run {
                        self.isProcessingPurchase = false
                        self.delegate?.iapManagerDidFailPurchase(productId: id, errorMsg: LocalizationManager.shared.t("iap_err_payment_cancelled"))
                    }
                case .pending:
                    // Ask to Buy / 组织审批等待中，StoreKit 会通过 Transaction.updates
                    // 在后续给出最终结果；本地仅复位 spinner 并给出提示。
                    await MainActor.run {
                        self.isProcessingPurchase = false
                        self.lastStatusMessage = LocalizationManager.shared.t("iap_purchase_deferred")
                    }
                @unknown default:
                    await MainActor.run {
                        self.isProcessingPurchase = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessingPurchase = false
                    self.lastErrorMessage = error.localizedDescription
                    self.delegate?.iapManagerDidFailPurchase(productId: id, errorMsg: error.localizedDescription)
                }
            }
        }
    }

    private func failPurchase(id: String, message: String) {
        isProcessingPurchase = false
        lastErrorMessage = message
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.iapManagerDidFailPurchase(productId: id, errorMsg: message)
        }
    }

    // MARK: - 恢复购买 (StoreKit 2)

    /// StoreKit 2 没有独立的 restore transaction API：用户主动恢复时先
    /// 调用 `AppStore.sync()`，再以 `Transaction.currentEntitlements` 对账。
    /// 消费型额度仍是本地账本，不由 Apple 的恢复流程重新发放。
    public func restorePurchases(onCompletion: ((String) -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.restorePurchases(onCompletion: onCompletion)
            }
            return
        }
        guard !isProcessingPurchase else { return }
        lastErrorMessage = nil
        lastStatusMessage = nil
        beginRestoreReconciliation()
        isRestoringPurchases = true
        isProcessingPurchase = true
        Task {
            do {
                // currentEntitlements is normally synchronized automatically,
                // but an explicit user restore must ask the App Store to sync
                // first (especially after an account/device change).
                try await AppStore.sync()
                await self.reconcileUnfinishedTransactions()
                var outcome = await self.verifyEntitlementsAsync(restoring: true)
                // A verified refund can invalidate an in-flight restore scan.
                // Re-read once with the latest revoked-transaction set.
                if case .superseded = outcome { outcome = await self.verifyEntitlementsAsync(restoring: true) }
                let environment = await self.currentRestoreEnvironment()
                let finalOutcome = outcome
                await MainActor.run {
                    self.endRestoreReconciliation()
                    self.isRestoringPurchases = false
                    self.isProcessingPurchase = false
                    switch finalOutcome {
                    case .verified(let confirmed):
                        // A refund can arrive while the environment lookup is
                        // awaiting Apple. Report only rights still present now.
                        let unlocked = self.currentMirror()?.restoredProductIDs(confirmed: confirmed, at: Date()) ?? []
                        let message = LocalizationManager.shared.t(unlocked.isEmpty
                            ? environment.noPurchasesMessageKey : "iap_restore_success")
                        if let onCompletion { onCompletion(message) }
                        else { self.lastStatusMessage = message }
                        self.delegate?.iapManagerDidRestorePurchases(unlockedProductIds: unlocked)
                    case .unavailable, .superseded:
                        let message = LocalizationManager.shared.t("iap_restore_unavailable")
                        if let onCompletion { onCompletion(message) }
                        else { self.lastErrorMessage = message }
                    }
                }
            } catch {
                await MainActor.run {
                    self.endRestoreReconciliation()
                    self.isRestoringPurchases = false
                    self.isProcessingPurchase = false
                    if let onCompletion { onCompletion(error.localizedDescription) }
                    else { self.lastErrorMessage = error.localizedDescription }
                }
            }
        }
    }

    private func currentRestoreEnvironment() async -> PurchaseRestoreEnvironment {
        if let result = try? await AppTransaction.shared, case .verified(let transaction) = result {
            if transaction.environment == .sandbox { return .sandbox }
            if transaction.environment == .xcode { return .xcode }
            if transaction.environment == .production { return .production }
        }
        // Older sandbox installations may not have an app transaction yet.
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" { return .sandbox }
        return .unknown
    }

    /// Clear one-shot UI feedback when a payment screen is presented again.
    /// Entitlements and the sealed transaction ledger are persisted separately
    /// from these one-shot UI messages and are intentionally left untouched.
    public func clearTransientMessages() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.clearTransientMessages()
            }
            return
        }
        lastErrorMessage = nil
        lastStatusMessage = nil
    }

    // MARK: - StoreKit 2 交易监听 (Transaction.updates)

    /// 监听 App Store 推送的交易更新：订阅续期、退款撤销、跨设备恢复、
    /// Ask to Buy 最终结果等。替代旧的 SKPaymentTransactionObserver。
    private func listenForTransactions() {
        transactionListener?.cancel()
        transactionListener = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self = self else { return }
                switch update {
                case .verified(let transaction):
                    await self.handleTransactionUpdate(transaction)
                case .unverified(_, let error):
                    // 未通过系统级验证：不解锁权益，仅记录
                    print("StoreKit unverified transaction: \(error.localizedDescription)")
                }
            }
        }
    }

    private func reconcileUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            guard !Task.isCancelled else { return }
            if case .verified(let transaction) = result {
                await handleTransactionUpdate(transaction)
            }
        }
    }

    private func retryUnfinishedTransactions() {
        guard unfinishedTransactionsTask == nil else { return }
        unfinishedTransactionsTask = Task { [weak self] in
            await self?.reconcileUnfinishedTransactions()
            self?.unfinishedTransactionsTask = nil
        }
    }

    private func handleTransactionUpdate(_ transaction: Transaction) async {
        let pid = transaction.productID
        guard isSupportedProductID(pid) else {
            // Do not grant unknown products, but finish them so a future
            // product identifier cannot keep the update stream replaying
            // forever after an app update.
            await transaction.finish()
            return
        }

        // 退款/撤销：立即权威对账。currentEntitlements 已不含该交易，
        // 验证覆写镜像即收回权益（订阅失效同理由到期逻辑处理）。
        if transaction.revocationDate != nil {
            if let kind = productKind(for: pid) {
                switch kind {
                case .floorplanSingle, .tianjiSingle:
                    guard revokeConsumableGrant(productID: pid, transactionID: String(transaction.id)) else { return }
                case .vipYearly, .proLifetime:
                    revokePaidEntitlement(productID: pid, transactionID: transaction.id)
                }
            }
            await transaction.finish()
            await verifyEntitlementsAsync()
            return
        }

        let txId = String(transaction.id)
        let didProcess: Bool
        do {
            didProcess = try applyVerifiedTransactionIfNeeded(productID: pid, transactionID: txId)
        } catch {
            await reportPurchasePersistenceFailure(productID: pid)
            return // Keep the Apple transaction unfinished for a later retry.
        }
        // Always finish a replay as well. A previous crash may have committed
        // the ledger but not reached finish(), and returning early would leave
        // StoreKit delivering the same transaction forever.
        await transaction.finish()

        // 订阅/非消耗品：即使交易 ID 已入账（重放/跨设备恢复），也要重新
        // 权威对账刷新到期日；幂等只继续挡消费型额度，避免重复加次数。
        let kind = productKind(for: pid)
        if didProcess || kind == .vipYearly || kind == .proLifetime {
            await verifyEntitlementsAsync()
        }
        guard didProcess else { return }

        await MainActor.run {
            if !self.isRestoringPurchases { self.isProcessingPurchase = false }
            self.lastCompletedProductID = pid
            self.delegate?.iapManagerDidCompletePurchase(productId: pid, transactionId: txId)
        }
    }

    /// 购买成功（Product.purchase() 返回 .verified）后处理。
    private func handleVerified(_ transaction: Transaction) async {
        let pid = transaction.productID
        let txId = String(transaction.id)
        let didProcess: Bool
        do {
            didProcess = try applyVerifiedTransactionIfNeeded(productID: pid, transactionID: txId)
        } catch {
            await reportPurchasePersistenceFailure(productID: pid)
            return
        }
        await transaction.finish()

        // 订阅/非消耗品：即使交易 ID 已入账，也重新权威对账刷新到期日。
        let kind = productKind(for: pid)
        if didProcess || kind == .vipYearly || kind == .proLifetime {
            await verifyEntitlementsAsync()
        }
        guard didProcess else {
            await MainActor.run { self.isProcessingPurchase = false }
            return
        }

        await MainActor.run {
            self.isProcessingPurchase = false
            self.lastCompletedProductID = pid
            self.delegate?.iapManagerDidCompletePurchase(productId: pid, transactionId: txId)
        }
    }

    private func reportPurchasePersistenceFailure(productID: String) async {
        await MainActor.run {
            if !self.isRestoringPurchases { self.isProcessingPurchase = false }
            let message = LocalizationManager.shared.t("iap_storage_unavailable")
            self.lastErrorMessage = message
            self.delegate?.iapManagerDidFailPurchase(productId: productID, errorMsg: message)
        }
    }


    // MARK: - 商品价格与状态

    public var hasAvailableProducts: Bool {
        !availableProducts.isEmpty
    }

    public func hasProduct(for productID: IAPProductID) -> Bool {
        availableProducts[productID.rawValue] != nil
    }

    func subscriptionPurchaseTerms(for productID: IAPProductID) -> SubscriptionPurchaseTerms? {
        guard let product = availableProducts[productID.rawValue], product.type == .autoRenewable,
              let period = product.subscription?.subscriptionPeriod else { return nil }
        let unit: SubscriptionPurchaseTerms.Unit
        switch period.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: return nil
        }
        return SubscriptionPurchaseTerms(title: product.displayName, displayPrice: product.displayPrice,
                                         periodValue: period.value, periodUnit: unit)
    }

    func canPurchaseProduct(for productID: IAPProductID) -> Bool {
        guard let product = availableProducts[productID.rawValue],
              !product.displayPrice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return productID != .vipYearly || subscriptionPurchaseTerms(for: productID) != nil
    }

    func localizedBillingPrice(for productID: IAPProductID) -> String {
        subscriptionPurchaseTerms(for: productID)?.localizedPricePerPeriod ?? localizedPrice(for: productID)
    }

    public func localizedPrice(for productID: IAPProductID) -> String {
        guard let product = availableProducts[productID.rawValue] else {
            return isLoadingProducts
                ? LocalizationManager.shared.t("price_loading")
                : LocalizationManager.shared.t("price_unavailable")
        }
        // StoreKit 2 的 displayPrice 已按当前 storefront 与语言格式化
        let price = product.displayPrice
        return price.isEmpty ? LocalizationManager.shared.t("price_unavailable") : price
    }

    public func getStatusJSON() -> String {
        let status: [String: Any] = [
            "isVIP": isVIP(),
            "isLifetime": isLifetime(),
            "floorplanCredits": floorplanCredits(),
            "tianjiCredits": tianjiCredits()
        ]
        if let data = try? JSONSerialization.data(withJSONObject: status, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"isVIP\":false,\"isLifetime\":false,\"floorplanCredits\":0,\"tianjiCredits\":0}"
    }

    public func getProductsJSON() -> String {
        var list: [[String: Any]] = []
        for item in IAPProductID.allCases {
            var price = LocalizationManager.shared.t("price_unavailable")
            if let product = availableProducts[item.rawValue], !product.displayPrice.isEmpty {
                price = product.displayPrice
            }
            list.append([
                "id": item.rawValue,
                "title": item.title,
                "price": price,
                "desc": item.desc
            ])
        }
        if let data = try? JSONSerialization.data(withJSONObject: list, options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }

    // MARK: - 权威权益验证（验证为主）

    /// 同步入口：基于最近一次权威验证镜像构建结果。
    /// StoreKit 2 的 AppTransaction 与已验证交易由 Apple 在系统层签名并校验，
    /// App 不再需要自行解析 ASN.1/PKCS#7 或维护本地收据文件哈希。
    public func verifyReceipt() -> ReceiptValidationResult {
        guard let mirror = currentMirror(), mirror.isAuthoritative else {
            return emptyReceiptResult()
        }
        return ReceiptValidationResult(
            isValidContainer: true,
            bundleIDMatched: true,   // currentEntitlements 交易已由系统验证绑定本 App
            purchasedProductIDs: Set(mirror.purchasedProductIDs),
            latestExpirationDate: mirror.vipExpireDate > 0
                ? Date(timeIntervalSince1970: mirror.vipExpireDate)
                : nil,
            receiptSHA256: "",
            certificateChainValid: true,
            signatureValid: true
        )
    }

    private func emptyReceiptResult() -> ReceiptValidationResult {
        return ReceiptValidationResult(
            isValidContainer: false,
            bundleIDMatched: false,
            purchasedProductIDs: [],
            latestExpirationDate: nil,
            receiptSHA256: "",
            certificateChainValid: false,
            signatureValid: false
        )
    }

    /// 启动权威验证（去重：同一时刻只跑一轮）。
    private func runVerification() {
        guard verificationTask == nil else { return }
        verificationTask = Task { [weak self] in
            await self?.verifyEntitlementsAsync()
            self?.verificationTask = nil
        }
    }

    /// An explicit verified revocation takes effect before any asynchronous
    /// reconciliation. Older scans cannot commit over this state transition.
    private func revokePaidEntitlement(productID: String, transactionID: UInt64) {
        entitlementLock.lock()
        entitlementScans.revoke()
        revokedEntitlementTransactionIDs.insert(transactionID)
        var mirror = currentMirrorLocked() ?? freshEmptyMirror()
        mirror.revokePaidProduct(productID)
        if ledgerStorageUnavailable { verifiedMembershipFallback = mirror }
        else { updateMirrorLocked(mirror) }
        entitlementLock.unlock()
        DispatchQueue.main.async { [weak self] in self?.publishCurrentEntitlements() }
    }

    private func beginRestoreReconciliation() {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        entitlementScans.beginRestore()
    }

    private func endRestoreReconciliation() {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        entitlementScans.endRestore()
    }

    private func entitlementScanState(restoring: Bool) -> (revision: Int, revokedIDs: Set<UInt64>)? {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let revision = entitlementScans.beginScan(restoring: restoring) else { return nil }
        return (revision, revokedEntitlementTransactionIDs)
    }

    /// Call on the main thread and read the latest committed mirror, so a
    /// queued UI publication cannot re-advertise a concurrently revoked grant.
    private func publishCurrentEntitlements() {
        guard let mirror = currentMirror() else { return }
        isVIPUser = mirror.isAuthoritative && (mirror.isLifetime || mirror.vipActive
            || mirror.vipExpireDate > Date().timeIntervalSince1970)
        isLifetimeUser = mirror.isAuthoritative && mirror.isLifetime
        floorplanCreditsCount = mirror.isAuthoritative ? mirror.floorplanCredits : 0
        tianjiCreditsCount = mirror.isAuthoritative ? mirror.tianjiCredits : 0
    }

    /// Persist a complete StoreKit entitlement snapshot from a synchronous
    /// context. Keeping the lock operations here avoids Swift 6's
    /// “lock/unlock unavailable from asynchronous contexts” diagnostic in the
    /// async transaction scanner.
    private func persistEntitlementSnapshot(isLifetime: Bool,
                                            vipActive: Bool,
                                            vipExpire: TimeInterval,
                                            purchasedProductIDs: [String],
                                            expectedRevision: Int) -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard entitlementScans.canCommit(expectedRevision) else { return false }
        var mirror = currentMirrorLocked() ?? freshEmptyMirror()
        mirror.verifiedAt = Date()
        mirror.isAuthoritative = true
        mirror.isLifetime = isLifetime
        mirror.vipActive = vipActive
        mirror.vipExpireDate = vipExpire
        mirror.purchasedProductIDs = purchasedProductIDs.sorted()
        if ledgerStorageUnavailable {
            // Only verified membership fields are available in this fallback;
            // never trust or re-mint a balance whose seal cannot be checked.
            verifiedMembershipFallback = mirror
            return true
        }
        return updateMirrorLocked(mirror)
    }

    /// Re-evaluate time-based entitlements when the app returns to foreground.
    /// 权威对账：以 Transaction.currentEntitlements 覆写镜像验证段。
    public func refreshEntitlements() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshEntitlements()
            }
            return
        }
        retryUnfinishedTransactions()
        runVerification()
    }

    /// StoreKit 2 权威对账（唯一允许覆写验证段的路径）：
    /// 1. Transaction.currentEntitlements —— 系统级验证的当前有效权益
    ///    （订阅含权威 expirationDate；退款交易已自动移除）；
    /// 2. 全量覆写镜像验证段：有效则点亮/刷新到期日，失效/退款则收回；
    /// 3. 账本段（消费型 credits）不在此覆写，由已验证交易记账维护。
    ///
    /// 订阅有效性以「苹果当前是否仍授予」为准，而不是只看本地镜像里抄来
    /// 的到期日：
    /// - currentEntitlements 中未撤销的年度订阅即视为授予中（该序列只含
    ///   subscribed / inGracePeriod），宽限期保持可用；
    /// - 本地缓存为空（对账瞬间 currentEntitlements 尚未同步）而镜像此前
    ///   有效时，先查 Product.SubscriptionInfo.status 二次确认：状态为
    ///   subscribed/inGracePeriod 保持订阅可用；明确 expired/revoked 则收回。
    ///   信息不足时仅保留旧订阅状态；终身权益独立按当前交易快照对账。
    /// - 用户主动恢复时始终复核订阅状态，不要求旧镜像中已经有订阅。
    @discardableResult
    private func verifyEntitlementsAsync(restoring: Bool = false) async -> EntitlementVerificationOutcome {
        guard let scan = entitlementScanState(restoring: restoring) else { return .superseded }
        var isLifetime = false
        var vipActive = false
        var vipExpire: TimeInterval = 0
        var purchasedProductIDs: [String] = []
        var confirmedProductIDs: [String] = []
        var encounteredUnverifiedTransaction = false
        var subscriptionStatusUnavailable = false

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let tx) = entitlement else {
                encounteredUnverifiedTransaction = true
                continue
            }
            guard tx.revocationDate == nil, !scan.revokedIDs.contains(tx.id) else { continue }
            guard let product = productKind(for: tx.productID) else { continue }
            purchasedProductIDs.append(tx.productID)
            switch product {
            case .proLifetime:
                // 非消耗品：未撤销则永久有效（退款后自动移出 currentEntitlements）
                isLifetime = true
                confirmedProductIDs.append(IAPProductID.proLifetime.rawValue)
            case .vipYearly:
                // 出现在 currentEntitlements 中 = 苹果当前授予（订阅中或宽限中），
                // 不因 expirationDate 已过而锁；expirationDate 仅作展示与兜底。
                vipActive = true
                confirmedProductIDs.append(IAPProductID.vipYearly.rawValue)
                if let exp = tx.expirationDate {
                    vipExpire = max(vipExpire, exp.timeIntervalSince1970)
                }
            case .floorplanSingle, .tianjiSingle:
                break
            }
        }

        // Subscription status can confirm a grace period when the entitlement
        // stream has not caught up. It cannot validate a lifetime purchase.
        if !vipActive {
            let prev = currentMirror()
            let prevActive = prev?.isAuthoritative == true
                && (prev?.vipActive == true || (prev?.vipExpireDate ?? 0) > Date().timeIntervalSince1970)
            if restoring || prevActive {
                switch await currentSubscriptionRenewalState(loadIfNeeded: restoring, revokedIDs: scan.revokedIDs) {
                case .active(let productID, let expiration):
                    vipActive = true
                    vipExpire = expiration?.timeIntervalSince1970 ?? 0
                    purchasedProductIDs.append(productID)
                    confirmedProductIDs.append(IAPProductID.vipYearly.rawValue)
                case .inactive:
                    // 明确 expired/revoked → 允许覆写收回
                    break
                case .unknown:
                    subscriptionStatusUnavailable = true
                    // Preserve only the prior subscription while offline.
                    // Never skip reconciliation of the lifetime entitlement.
                    vipActive = prev?.vipActive ?? false
                    vipExpire = prev?.vipExpireDate ?? 0
                }
                if vipActive || vipExpire > Date().timeIntervalSince1970 {
                    purchasedProductIDs.append(IAPProductID.vipYearly.rawValue)
                }
            }
        }

        // An unverified transaction or failed lookup is not proof that the
        // customer never bought anything. Preserve the cache and report retry.
        if restoring && confirmedProductIDs.isEmpty && (encounteredUnverifiedTransaction || subscriptionStatusUnavailable) {
            return .unavailable
        }

        // 覆写镜像验证段（保留账本段；消费型商品不因验证清零/恢复）
        guard persistEntitlementSnapshot(
            isLifetime: isLifetime,
            vipActive: vipActive,
            vipExpire: vipExpire,
            purchasedProductIDs: purchasedProductIDs,
            expectedRevision: scan.revision
        ) else { return .superseded }

        // 发布 UI（主线程）
        await MainActor.run {
            self.publishCurrentEntitlements()
        }
        return .verified(Array(Set(confirmedProductIDs)).sorted())
    }

    /// 用 Product.SubscriptionInfo.status 确认苹果侧订阅续期状态。
    /// Restore must work before the paywall has loaded any product metadata.
    private func currentSubscriptionRenewalState(loadIfNeeded: Bool, revokedIDs: Set<UInt64>) async -> SubscriptionRenewalStateSummary {
        var product = await MainActor.run { self.availableProducts[IAPProductID.vipYearly.rawValue] }
        if product == nil && loadIfNeeded {
            do {
                let products = try await Product.products(for: [IAPProductID.vipYearly.rawValue])
                product = products.first { $0.id == IAPProductID.vipYearly.rawValue && $0.type == .autoRenewable }
            } catch {
                return .unknown
            }
        }
        guard let subscription = product?.subscription else { return .unknown }
        guard let statuses = try? await subscription.status else {
            return .unknown
        }
        var hasUnverifiedStatus = false
        for status in statuses {
            guard case .verified(let transaction) = status.transaction,
                  case .verified = status.renewalInfo else {
                hasUnverifiedStatus = true
                continue
            }
            guard productKind(for: transaction.productID) == .vipYearly,
                  transaction.revocationDate == nil, !revokedIDs.contains(transaction.id) else { continue }
            if status.state == .subscribed || status.state == .inGracePeriod {
                return .active(productID: transaction.productID, expiration: transaction.expirationDate)
            }
        }
        return hasUnverifiedStatus ? .unknown : .inactive
    }

    private enum SubscriptionRenewalStateSummary {
        case active(productID: String, expiration: Date?)
        case inactive
        case unknown
    }

}
