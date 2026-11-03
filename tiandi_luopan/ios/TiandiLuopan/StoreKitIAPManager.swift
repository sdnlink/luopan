import Foundation
import StoreKit
import Combine
import CryptoKit
import Security
import UIKit

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

/// A signed, device-bound grant for the currently active one-shot floorplan
/// case. The grant is an integrity check for the local layout cache; production
/// ownership and cross-device synchronization still belong to a server ledger.
public struct FloorplanAccessGrant: Codable, Equatable {
    public let id: String
    public let signature: String

    public init(id: String, signature: String) {
        self.id = id
        self.signature = signature
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
    @Published public private(set) var lastErrorMessage: String?
    @Published public private(set) var lastStatusMessage: String?
    @Published public private(set) var lastCompletedProductID: String?

    // MARK: - 权益镜像模型

    private struct ConsumableGrant: Codable {
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
    private struct EntitlementMirror: Codable {
        var verifiedAt: Date
        var isAuthoritative: Bool
        var isLifetime: Bool
        /// Apple 当前仍授予年度订阅（交易未撤销地存在于 currentEntitlements，
        /// 或 SubscriptionInfo.status 显示 subscribed/inGracePeriod/billingRetry）。
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

        private enum CodingKeys: String, CodingKey {
            case verifiedAt, isAuthoritative, isLifetime, vipActive, vipExpireDate
            case floorplanCredits, tianjiCredits, purchasedProductIDs
            case consumableGrants
            case processedTransactionIDs
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
             processedTransactionIDs: [String] = []) {
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
        }
    }

    private let kMirrorKey = "yx_iap_entitlement_mirror_v2"
    private let kMirrorSealKey = "yx_iap_entitlement_mirror_seal"
    private let kKeychainSealAccount = "com.yanxiang.compass.iap.seal.key"
    private let kLegacyKeychainSealAccount = "com.yanxiang.luopan.iap.seal.key"
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
    /// In-flight exports reserve a slot in memory and only debit the durable
    /// balance after the deliverable succeeds.  A process termination therefore
    /// cannot permanently destroy a paid credit.  Stale reservations are
    /// released after a short timeout so an interrupted share sheet cannot
    /// block the next export forever.
    private var activeTianjiReservations: [String: Date] = [:]
    private let tianjiReservationTimeout: TimeInterval = 300
    private var transactionListener: Task<Void, Never>?
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
        // 4. 权威对账（currentEntitlements 驱动，验证完成即覆写镜像）
        runVerification()
        fetchProducts()
    }

    deinit {
        transactionListener?.cancel()
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
            cachedMirror = readMirrorFromStorage()
            cachedMirrorLoadedFromStorage = true
        }
        return cachedMirror
    }

    private func readMirrorFromStorage() -> EntitlementMirror? {
        guard let data = UserDefaults.standard.data(forKey: kMirrorKey),
              let seal = UserDefaults.standard.string(forKey: kMirrorSealKey),
              let mirror = try? JSONDecoder().decode(EntitlementMirror.self, from: data) else {
            return nil
        }
        // Mirrors written before per-transaction consumable grants were added
        // used the v2 payload. Accept that seal once and re-seal on the next
        // entitlement/transaction write so upgrades do not discard a valid
        // local cache.
        guard computeMirrorSeal(mirror) == seal
                || computeV3MirrorSeal(mirror) == seal
                || computePreConsumableGrantSeal(mirror) == seal
                || computeLegacyMirrorSeal(mirror) == seal else {
            return nil
        }
        return mirror
    }

    /// 覆写镜像（带锁）。
    private func updateMirror(_ mirror: EntitlementMirror) {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        updateMirrorLocked(mirror)
    }

    /// 假设调用方已持有 entitlementLock。
    private func updateMirrorLocked(_ mirror: EntitlementMirror) {
        cachedMirror = mirror
        cachedMirrorLoadedFromStorage = true
        let data = (try? JSONEncoder().encode(mirror)) ?? Data()
        UserDefaults.standard.set(data, forKey: kMirrorKey)
        UserDefaults.standard.set(computeMirrorSeal(mirror), forKey: kMirrorSealKey)
    }

    private func computeMirrorSeal(_ mirror: EntitlementMirror) -> String {
        let payload = "v4|\(Int64(mirror.verifiedAt.timeIntervalSince1970.rounded()))|\(mirror.isAuthoritative ? 1 : 0)|\(mirror.isLifetime ? 1 : 0)|\(mirror.vipActive ? 1 : 0)|\(Int64(mirror.vipExpireDate.rounded()))|\(mirror.floorplanCredits)|\(mirror.tianjiCredits)|\(mirror.purchasedProductIDs.sorted().joined(separator: ","))|\(mirror.processedTransactionIDs.sorted().joined(separator: ","))|\(consumableGrantSealPayload(mirror.consumableGrants))"
        let key = deviceSealSymmetricKey()
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    /// Seal format used by the immediately preceding mirror version (v3),
    /// which predates the vipActive Apple-grant flag. It remains readable so
    /// an upgrade does not discard a valid local cache; the next authoritative
    /// verification re-seals with the v4 payload.
    private func computeV3MirrorSeal(_ mirror: EntitlementMirror) -> String {
        let payload = "v3|\(Int64(mirror.verifiedAt.timeIntervalSince1970.rounded()))|\(mirror.isAuthoritative ? 1 : 0)|\(mirror.isLifetime ? 1 : 0)|\(Int64(mirror.vipExpireDate.rounded()))|\(mirror.floorplanCredits)|\(mirror.tianjiCredits)|\(mirror.purchasedProductIDs.sorted().joined(separator: ","))|\(mirror.processedTransactionIDs.sorted().joined(separator: ","))|\(consumableGrantSealPayload(mirror.consumableGrants))"
        let key = deviceSealSymmetricKey()
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    /// Seal format used by the immediately preceding mirror version, which
    /// already included processed transaction IDs but did not track grant
    /// ownership. It remains readable so an upgrade does not discard a valid
    /// local balance.
    private func computePreConsumableGrantSeal(_ mirror: EntitlementMirror) -> String {
        let payload = "v2|\(Int64(mirror.verifiedAt.timeIntervalSince1970.rounded()))|\(mirror.isAuthoritative ? 1 : 0)|\(mirror.isLifetime ? 1 : 0)|\(Int64(mirror.vipExpireDate.rounded()))|\(mirror.floorplanCredits)|\(mirror.tianjiCredits)|\(mirror.purchasedProductIDs.sorted().joined(separator: ","))|\(mirror.processedTransactionIDs.sorted().joined(separator: ","))"
        let key = deviceSealSymmetricKey()
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    private func computeLegacyMirrorSeal(_ mirror: EntitlementMirror) -> String {
        let payload = "v2|\(Int64(mirror.verifiedAt.timeIntervalSince1970.rounded()))|\(mirror.isAuthoritative ? 1 : 0)|\(mirror.isLifetime ? 1 : 0)|\(Int64(mirror.vipExpireDate.rounded()))|\(mirror.floorplanCredits)|\(mirror.tianjiCredits)|\(mirror.purchasedProductIDs.sorted().joined(separator: ","))"
        let key = deviceSealSymmetricKey()
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    private func consumableGrantSealPayload(_ grants: [String: ConsumableGrant]) -> String {
        grants.keys.sorted().compactMap { transactionID in
            guard let grant = grants[transactionID] else { return nil }
            return "\(transactionID):\(grant.productID):\(grant.consumed ? 1 : 0):\(grant.revoked ? 1 : 0)"
        }.joined(separator: ",")
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
        updateMirrorLocked(mirror)
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
        guard let mirror = currentMirror(), mirror.isAuthoritative else { return false }
        return hasUnlockedVIP || mirror.floorplanCredits > 0
    }

    public var canUseTianji: Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return false }
        pruneExpiredTianjiReservationsLocked()
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
    private func revokeConsumableGrant(productID: String, transactionID: String) {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        // A revocation can be delivered immediately after the purchase and
        // before the first entitlement snapshot marks the mirror
        // authoritative.  The transaction itself is already StoreKit
        // verified, so revoke a matching grant regardless of that snapshot
        // flag; otherwise the credit could survive until a later sync.
        guard var mirror = currentMirrorLocked(),
              var grant = mirror.consumableGrants[transactionID],
              !grant.revoked else { return }
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
        updateMirrorLocked(mirror)
        let floorplan = mirror.floorplanCredits
        let tianji = mirror.tianjiCredits
        DispatchQueue.main.async { [weak self] in
            self?.floorplanCreditsCount = floorplan
            self?.tianjiCreditsCount = tianji
        }
    }

    // MARK: - 消费型商品记账（仅苹果已验证交易背书下增减）

    /// Issue a device-bound grant after a verified floorplan credit is
    /// consumed. Saved layouts store this grant instead of trusting a mutable
    /// boolean in UserDefaults.
    public func issueFloorplanAccessGrant() -> FloorplanAccessGrant {
        let id = UUID().uuidString
        return FloorplanAccessGrant(id: id, signature: floorplanGrantSignature(for: id))
    }

    public func validateFloorplanAccessGrant(_ grant: FloorplanAccessGrant) -> Bool {
        guard !grant.id.isEmpty, !grant.signature.isEmpty else { return false }
        return floorplanGrantSignature(for: grant.id) == grant.signature
    }

    private func floorplanGrantSignature(for id: String) -> String {
        let payload = Data("floorplan-grant-v1|\(id)".utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: payload, using: deviceSealSymmetricKey())
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    public func consumeFloorplanCredit() -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return false }
        if isVIPUnlocked() { return true }
        guard mirror.floorplanCredits > 0 else { return false }
        var updated = mirror
        updated.floorplanCredits -= 1
        markConsumableGrantConsumedLocked(kind: .floorplanSingle, mirror: &updated)
        updateMirrorLocked(updated)
        let remain = updated.floorplanCredits
        DispatchQueue.main.async { [weak self] in self?.floorplanCreditsCount = remain }
        return true
    }

    public func consumeTianjiCredit() -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let mirror = currentMirrorLocked(), mirror.isAuthoritative else { return false }
        if isVIPUnlocked() { return true }
        pruneExpiredTianjiReservationsLocked()
        guard mirror.tianjiCredits > activeTianjiReservations.count else { return false }
        var updated = mirror
        updated.tianjiCredits -= 1
        markConsumableGrantConsumedLocked(kind: .tianjiSingle, mirror: &updated)
        updateMirrorLocked(updated)
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
        pruneExpiredTianjiReservationsLocked()
        guard mirror.tianjiCredits > activeTianjiReservations.count else { return nil }
        let token = UUID().uuidString
        activeTianjiReservations[token] = Date()
        return token
    }

    /// Commit a reservation after the deliverable was produced. This is the
    /// only path that debits the durable balance for an export.
    public func commitTianjiCreditReservation(_ token: String) {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        pruneExpiredTianjiReservationsLocked()
        // Consume the in-flight slot even when a concurrent refund or
        // entitlement refresh removed the underlying credit.  Leaving the
        // token in the reservation table would make every later export look
        // busy until the five-minute timeout.
        guard activeTianjiReservations.removeValue(forKey: token) != nil else { return }
        guard var mirror = currentMirrorLocked(), mirror.isAuthoritative,
              mirror.tianjiCredits > 0 else { return }
        mirror.tianjiCredits -= 1
        markConsumableGrantConsumedLocked(kind: .tianjiSingle, mirror: &mirror)
        updateMirrorLocked(mirror)
        let remain = mirror.tianjiCredits
        DispatchQueue.main.async { [weak self] in self?.tianjiCreditsCount = remain }
    }

    /// Return a reservation when the export/share operation failed or was
    /// cancelled. Since reservation does not debit the balance, this only
    /// releases the in-flight slot. Repeated calls are harmless.
    public func refundTianjiCreditReservation(_ token: String) {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        activeTianjiReservations.removeValue(forKey: token)
    }

    /// Release interrupted export slots. The manager calls this while checking
    /// availability, so an interrupted share sheet cannot block future use.
    private func pruneExpiredTianjiReservationsLocked() {
        let cutoff = Date().addingTimeInterval(-tianjiReservationTimeout)
        activeTianjiReservations = activeTianjiReservations.filter { $0.value > cutoff }
    }

    /// Atomically claim a verified transaction and, for consumables, mint its
    /// credit in the same sealed mirror write. Replayed transactions return
    /// false but are still finished by the caller, so a crash cannot either
    /// lose a credit or leave a transaction permanently pending.
    private func applyVerifiedTransactionIfNeeded(productID: String, transactionID: String) -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard let kind = productKind(for: productID) else { return false }
        var mirror = currentMirrorLocked() ?? freshEmptyMirror()
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
        updateMirrorLocked(mirror)
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
    public func restorePurchases() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.restorePurchases()
            }
            return
        }
        lastErrorMessage = nil
        lastStatusMessage = nil
        guard !isProcessingPurchase else { return }
        isProcessingPurchase = true
        Task {
            do {
                // currentEntitlements is normally synchronized automatically,
                // but an explicit user restore must ask the App Store to sync
                // first (especially after an account/device change).
                try await AppStore.sync()
                await self.verifyEntitlementsAsync()
                var unlockedList: [String] = []
                if self.isVIP() { unlockedList.append(IAPProductID.vipYearly.rawValue) }
                if self.isLifetime() { unlockedList.append(IAPProductID.proLifetime.rawValue) }
                let unlocked = unlockedList
                await MainActor.run {
                    if unlocked.isEmpty {
                        // Consumable credits are intentionally not restorable by
                        // StoreKit; only report the absence of restorable
                        // subscriptions/non-consumables.
                        self.lastStatusMessage = LocalizationManager.shared.t("iap_restore_none")
                    } else {
                        self.lastStatusMessage = nil
                    }
                    self.isProcessingPurchase = false
                    self.delegate?.iapManagerDidRestorePurchases(unlockedProductIds: unlocked)
                }
            } catch {
                await MainActor.run {
                    self.isProcessingPurchase = false
                    self.lastErrorMessage = error.localizedDescription
                }
            }
        }
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
                    revokeConsumableGrant(productID: pid, transactionID: String(transaction.id))
                case .vipYearly, .proLifetime:
                    break
                }
            }
            await transaction.finish()
            await verifyEntitlementsAsync()
            return
        }

        let txId = String(transaction.id)
        let didProcess = applyVerifiedTransactionIfNeeded(productID: pid, transactionID: txId)
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
            self.isProcessingPurchase = false
            self.lastCompletedProductID = pid
            self.delegate?.iapManagerDidCompletePurchase(productId: pid, transactionId: txId)
        }
    }

    /// 购买成功（Product.purchase() 返回 .verified）后处理。
    private func handleVerified(_ transaction: Transaction) async {
        let pid = transaction.productID
        let txId = String(transaction.id)
        let didProcess = applyVerifiedTransactionIfNeeded(productID: pid, transactionID: txId)
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


    // MARK: - 商品价格与状态

    public var hasAvailableProducts: Bool {
        !availableProducts.isEmpty
    }

    public func hasProduct(for productID: IAPProductID) -> Bool {
        availableProducts[productID.rawValue] != nil
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

    /// Persist a complete StoreKit entitlement snapshot from a synchronous
    /// context. Keeping the lock operations here avoids Swift 6's
    /// “lock/unlock unavailable from asynchronous contexts” diagnostic in the
    /// async transaction scanner.
    private func persistEntitlementSnapshot(isLifetime: Bool,
                                            vipActive: Bool,
                                            vipExpire: TimeInterval,
                                            purchasedProductIDs: [String]) -> (floorplan: Int, tianji: Int) {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        var mirror = currentMirrorLocked() ?? freshEmptyMirror()
        mirror.verifiedAt = Date()
        mirror.isAuthoritative = true
        mirror.isLifetime = isLifetime
        mirror.vipActive = vipActive
        mirror.vipExpireDate = vipExpire
        mirror.purchasedProductIDs = purchasedProductIDs.sorted()
        updateMirrorLocked(mirror)
        return (mirror.floorplanCredits, mirror.tianjiCredits)
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
    ///   subscribed / inGracePeriod），宽限期与账单重试期保持可用；
    /// - 本地缓存为空（对账瞬间 currentEntitlements 尚未同步）而镜像此前
    ///   有效时，先查 Product.SubscriptionInfo.status 二次确认：状态为
    ///   subscribed/inGracePeriod/billingRetry 保持可用；明确 expired/revoked
    ///   才锁定；信息不足（商品未加载）则保留旧镜像、跳过本次覆写，等待
    ///   下一次对账，绝不用一次空缓存把昨天还有效的会员清成 0。
    private func verifyEntitlementsAsync() async {
        var isLifetime = false
        var vipActive = false
        var vipExpire: TimeInterval = 0
        var purchasedProductIDs: [String] = []

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let tx) = entitlement else { continue }
            guard let product = productKind(for: tx.productID) else { continue }
            purchasedProductIDs.append(tx.productID)
            switch product {
            case .proLifetime:
                // 非消耗品：未撤销则永久有效（退款后自动移出 currentEntitlements）
                isLifetime = true
            case .vipYearly:
                // 出现在 currentEntitlements 中 = 苹果当前授予（订阅中或宽限中），
                // 不因 expirationDate 已过而锁；expirationDate 仅作展示与兜底。
                vipActive = true
                if let exp = tx.expirationDate {
                    vipExpire = max(vipExpire, exp.timeIntervalSince1970)
                }
            case .floorplanSingle, .tianjiSingle:
                break
            }
        }

        // 空缓存保护：本次没有读到任何订阅/终身交易，但镜像此前有效。
        // 不能直接覆写清 0 —— 可能是 currentEntitlements 尚未同步到设备。
        if !isLifetime && !vipActive {
            let prev = currentMirror()
            let prevActive = prev?.isAuthoritative == true
                && (prev?.isLifetime == true || prev?.vipActive == true
                    || (prev?.vipExpireDate ?? 0) > Date().timeIntervalSince1970)
            if prevActive {
                switch await currentSubscriptionRenewalState() {
                case .active:
                    // 苹果仍授予（subscribed/inGracePeriod/billingRetry）→ 保持可用
                    vipActive = true
                case .inactive:
                    // 明确 expired/revoked → 允许覆写收回
                    break
                case .unknown:
                    // 商品未加载或状态不可得：保留旧镜像验证段，等待下一次对账
                    return
                }
            }
        }

        // 覆写镜像验证段（保留账本段；消费型商品不因验证清零/恢复）
        let snapshot = persistEntitlementSnapshot(
            isLifetime: isLifetime,
            vipActive: vipActive,
            vipExpire: vipExpire,
            purchasedProductIDs: purchasedProductIDs
        )
        let floorplanCredits = snapshot.floorplan
        let tianjiCredits = snapshot.tianji

        let finalLifetime = isLifetime
        let finalVipActive = vipActive
        let finalVipExpire = vipExpire

        // 发布 UI（主线程）
        await MainActor.run {
            self.isVIPUser = finalLifetime || finalVipActive || (finalVipExpire > Date().timeIntervalSince1970)
            self.isLifetimeUser = finalLifetime
            self.floorplanCreditsCount = floorplanCredits
            self.tianjiCreditsCount = tianjiCredits
        }
    }

    /// 用 Product.SubscriptionInfo.status 确认苹果侧订阅续期状态。
    /// 纯读属性，不触发任何登录弹窗；商品尚未加载时返回 unknown。
    private func currentSubscriptionRenewalState() async -> SubscriptionRenewalStateSummary {
        guard let product = availableProducts[IAPProductID.vipYearly.rawValue],
              let subscription = product.subscription else {
            return .unknown
        }
        let states = subscription.status.map { $0.state }
        if states.contains(where: { $0 == .subscribed || $0 == .inGracePeriod || $0 == .billingRetry }) {
            return .active
        }
        if states.contains(where: { $0 == .expired || $0 == .revoked }) {
            return .inactive
        }
        return .unknown
    }

    private enum SubscriptionRenewalStateSummary {
        case active
        case inactive
        case unknown
    }

    // MARK: - Keychain HMAC 防篡改保护（镜像封印）

    /// 获取或生成保存在 Keychain 中的设备级 256-bit HMAC 密钥（向下兼容旧版 Keychain 账户迁移）
    private func deviceSealSymmetricKey() -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: kKeychainSealAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let keyData = item as? Data, keyData.count >= 32 {
            return SymmetricKey(data: keyData)
        }

        // 向下兼容旧版 Keychain 账户 "com.yanxiang.luopan.iap.seal.key"，平滑迁移至 "com.yanxiang.compass.iap.seal.key"
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: kLegacyKeychainSealAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var legacyItem: CFTypeRef?
        if SecItemCopyMatching(legacyQuery as CFDictionary, &legacyItem) == errSecSuccess,
           let legacyKeyData = legacyItem as? Data, legacyKeyData.count >= 32 {
            let migrateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: kKeychainSealAccount,
                kSecValueData as String: legacyKeyData,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            SecItemDelete(migrateQuery as CFDictionary)
            SecItemAdd(migrateQuery as CFDictionary, nil)
            return SymmetricKey(data: legacyKeyData)
        }

        var randomBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let vendorSalt = UIDevice.current.identifierForVendor?.uuidString ?? "com.yanxiang.compass.device"
        var combined = Data(randomBytes)
        if let vendorData = vendorSalt.data(using: .utf8) {
            combined.append(vendorData)
        }
        let derivedKeyData = Data(SHA256.hash(data: combined))

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: kKeychainSealAccount,
            kSecValueData as String: derivedKeyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(addQuery as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)
        return SymmetricKey(data: derivedKeyData)
    }
}
