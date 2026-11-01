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

// MARK: - IAP 商品与权益定义

public enum IAPProductID: String, CaseIterable {
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

// MARK: - IAP 代理协议

public protocol StoreKitIAPManagerDelegate: AnyObject {
    func iapManagerDidUpdateProducts(_ products: [Product])
    func iapManagerDidCompletePurchase(productId: String, transactionId: String)
    func iapManagerDidFailPurchase(productId: String, errorMsg: String)
    func iapManagerDidRestorePurchases(unlockedProductIds: [String])
}

// MARK: - StoreKit 2 管理器

/// 基于 StoreKit 2（Product / Transaction / AppTransaction）实现的 IAP 管理器。
/// 相比 StoreKit 1 + 本地手写收据验签：
/// - 商品元数据：`Product.products(for:)`
/// - 购买：`Product.purchase()`（Swift 原生 async/await）
/// - 权益权威源：`Transaction.currentEntitlements`（订阅续期/退款/跨设备自动同步）
/// - 交易监听：`Transaction.updates` AsyncSequence（替代 SKPaymentTransactionObserver）
/// - 收据校验：`AppTransaction` / `.verified` 交易由 Apple 在系统层签名并校验，
///   删除约 700 行自实现的 ASN.1/PKCS#7/RSA-ECDSA 手写验签。
/// 本地 UserDefaults + Keychain HMAC 封印仅作为**轻量缓存层**（快速读取），
/// 权威裁决始终来自 StoreKit 2 系统级验证。
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

    public var hasUnlockedVIP: Bool {
        // 轻量校验：仅读取本地持久化权益并比对到期时间，避免 SwiftUI 每次重绘
        // 都触发 StoreKit 异步查询（主线程重活）。
        // 权威裁决在 init、购买完成、恢复购买、Transaction.updates 事件、
        // 回到前台(refreshEntitlements) 时执行，这些路径调用 verifyEntitlementsAsync()
        // 对账 StoreKit 2 entitlement（订阅续期/退款/换机恢复自动同步）。
        if UserDefaults.standard.bool(forKey: kIsLifetime) { return true }
        if UserDefaults.standard.bool(forKey: kIsVIP) {
            let expire = UserDefaults.standard.double(forKey: kVIPExpireDate)
            if expire == 0 || Date().timeIntervalSince1970 < expire { return true }
        }
        return false
    }

    public var canUseFloorplan: Bool {
        return hasUnlockedVIP || floorplanCreditsCount > 0
    }

    public var canUseTianji: Bool {
        return hasUnlockedVIP || tianjiCreditsCount > 0
    }

    /// Whether StoreKit has returned at least one valid product. Product
    /// metadata requests can fail independently from payment transactions;
    /// exposing this state lets paywalls offer an explicit retry instead of
    /// leaving every price at the loading placeholder.
    public var hasAvailableProducts: Bool {
        !availableProducts.isEmpty
    }

    /// A storefront can return only a subset of the requested identifiers
    /// (for example while a new product is still propagating). Expose the
    /// per-product state so purchase buttons do not offer an item whose price
    /// is still unavailable.
    public func hasProduct(for productID: IAPProductID) -> Bool {
        availableProducts[productID.rawValue] != nil
    }

    private var availableProducts: [String: Product] = [:]
    private var lastProductsFetchDate: Date?
    private let productsRetryInterval: TimeInterval = 30
    private let entitlementLock = NSLock()
    private var transactionListener: Task<Void, Never>?

    // 本地持久化权益 Keys（轻量缓存层）
    private let kIsVIP = "yx_iap_is_vip"
    private let kIsLifetime = "yx_iap_is_lifetime"
    private let kVIPExpireDate = "yx_iap_vip_expire_date"
    private let kFloorplanCredits = "yx_iap_floorplan_credits"
    private let kTianjiCredits = "yx_iap_tianji_credits"
    private let kProcessedTransactionIDs = "yx_iap_processed_transaction_ids"
    private let kEntitlementSeal = "yx_iap_entitlement_hmac_seal"
    private let kKeychainSealAccount = "com.yanxiang.compass.iap.seal.key"
    private let kLegacyKeychainSealAccount = "com.yanxiang.luopan.iap.seal.key"

    // StoreKit 2 权威校验快照（内存缓存，主线程读写）
    private var entitlementSnapshot: ReceiptValidationResult?
    /// 是否已完成至少一次 StoreKit 2 权威校验（未完成前不清除本地权益，
    /// 避免升级启动瞬间误伤正常用户）。
    private var entitlementSnapshotIsAuthoritative: Bool = false

    private init() {
        // 启动即读本地缓存（立即可用），权威对账异步进行
        self.isVIPUser = isVIP()
        self.isLifetimeUser = isLifetime()
        self.floorplanCreditsCount = floorplanCredits()
        self.tianjiCreditsCount = tianjiCredits()
        listenForTransactions()
        Task { await verifyEntitlementsAsync() }
        fetchProducts()
    }

    deinit {
        transactionListener?.cancel()
    }

    public func purchase(productId: String) {
        purchaseProduct(id: productId)
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
            return entitlementSnapshot?.isTrusted ?? false
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

    /// StoreKit 2 无 restore API：非消耗品与订阅权益通过
    /// `Transaction.currentEntitlements` 自动恢复（换机/重装/退款同步）。
    /// 此方法重跑权威对账并按结果回调，保留“恢复购买”入口供 App Store 审核。
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
            await verifyEntitlementsAsync()
            var unlocked: [String] = []
            if isVIP() { unlocked.append(IAPProductID.vipYearly.rawValue) }
            if isLifetime() { unlocked.append(IAPProductID.proLifetime.rawValue) }
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
        }
    }

    /// Clear one-shot UI feedback when a payment screen is presented again.
    /// Entitlements and processed transaction IDs are persisted separately and
    /// are intentionally left untouched.
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
        guard IAPProductID(rawValue: pid) != nil else { return }

        // 退款/撤销：立即以 StoreKit 2 权威对账收回对应权益
        if transaction.revocationDate != nil {
            await verifyEntitlementsAsync()
            return
        }

        let txId = String(transaction.id)
        // 与购买路径共用 claimTransaction 幂等去重，避免同一笔交易重复记账
        guard claimTransaction(txId) else { return }

        unlockEntitlement(for: pid,
                          transactionDate: transaction.purchaseDate,
                          expirationDate: transaction.expirationDate,
                          extendSubscription: true)
        await transaction.finish()

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
        guard claimTransaction(txId) else {
            await MainActor.run { self.isProcessingPurchase = false }
            return
        }

        unlockEntitlement(for: pid,
                          transactionDate: transaction.purchaseDate,
                          expirationDate: transaction.expirationDate,
                          extendSubscription: true)
        await transaction.finish()

        await MainActor.run {
            self.isProcessingPurchase = false
            self.lastCompletedProductID = pid
            self.delegate?.iapManagerDidCompletePurchase(productId: pid, transactionId: txId)
        }
    }

    private func claimTransaction(_ transactionID: String) -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        var ids = UserDefaults.standard.stringArray(forKey: kProcessedTransactionIDs) ?? []
        guard !ids.contains(transactionID) else { return false }
        ids.append(transactionID)
        // Transaction identifiers are the local idempotency key. Keep the
        // complete set: trimming old IDs allows StoreKit to replay an older
        // transaction and mint a consumable credit a second time.
        UserDefaults.standard.set(ids, forKey: kProcessedTransactionIDs)
        return true
    }

    // MARK: - 权益本地管理（轻量缓存层）

    private func unlockEntitlement(for pid: String,
                                   transactionDate: Date? = nil,
                                   expirationDate: Date? = nil,
                                   extendSubscription: Bool = true) {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        let defaults = UserDefaults.standard
        if pid == IAPProductID.proLifetime.rawValue {
            defaults.set(true, forKey: kIsLifetime)
            defaults.set(true, forKey: kIsVIP)
        } else if pid == IAPProductID.vipYearly.rawValue {
            if let expirationDate = expirationDate {
                // StoreKit 2 权威到期时间：订阅续期由 App Store 管理，
                // expirationDate 即续期后的真实到期日，本地不再自行累加 365 天。
                let ts = expirationDate.timeIntervalSince1970
                defaults.set(ts, forKey: kVIPExpireDate)
                defaults.set(ts > Date().timeIntervalSince1970, forKey: kIsVIP)
            } else {
                // 回退路径（理论上 StoreKit 2 始终提供 expirationDate）：
                // 使用 StoreKit 交易时间计算订阅周期，恢复旧交易时不会从“恢复当天”凭空续期。
                let oldExpiry = defaults.double(forKey: kVIPExpireDate)
                if extendSubscription {
                    defaults.set(true, forKey: kIsVIP)
                    let purchaseDate = transactionDate ?? Date()
                    // StoreKit can deliver a completed transaction after a
                    // temporary network outage. If its transaction date is more
                    // than a year old and no previous local expiry exists, using
                    // that date would unlock the purchase and immediately expire
                    // it. A completed purchase must grant one full local period;
                    // a still-active previous period remains the base for renewal.
                    let baseDate = max(Date(), max(purchaseDate, Date(timeIntervalSince1970: oldExpiry)))
                    let expireDate = baseDate.addingTimeInterval(365 * 24 * 3600)
                    defaults.set(expireDate.timeIntervalSince1970, forKey: kVIPExpireDate)
                } else if let restoredDate = transactionDate {
                    // A restore can come from another device after the local
                    // entitlement has expired. Rebuild the same original period
                    // without adding another year every time Restore is tapped.
                    let restoredExpiry = restoredDate.addingTimeInterval(365 * 24 * 3600)
                    let effectiveExpiry = max(oldExpiry, restoredExpiry.timeIntervalSince1970)
                    defaults.set(effectiveExpiry, forKey: kVIPExpireDate)
                    defaults.set(effectiveExpiry > Date().timeIntervalSince1970, forKey: kIsVIP)
                } else {
                    defaults.set(oldExpiry > Date().timeIntervalSince1970, forKey: kIsVIP)
                }
            }
        } else if pid == IAPProductID.floorplanSingle.rawValue || pid == "com.yanxiang.compass.floorplan.single" || pid == "com.yanxiang.luopan.floorplan.single" {
            let current = defaults.integer(forKey: kFloorplanCredits)
            defaults.set(current + 1, forKey: kFloorplanCredits)
        } else if pid == IAPProductID.tianjiSingle.rawValue {
            let current = defaults.integer(forKey: kTianjiCredits)
            defaults.set(current + 1, forKey: kTianjiCredits)
        }
        updateEntitlementSealLocked()
        defaults.synchronize()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isVIPUser = self.isVIP()
            self.isLifetimeUser = self.isLifetime()
            self.floorplanCreditsCount = self.floorplanCredits()
            self.tianjiCreditsCount = self.tianjiCredits()
        }
    }

    public func isVIP() -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        return isVIPUnlocked()
    }

    private func isVIPUnlocked() -> Bool {
        guard verifyEntitlementIntegrityLocked() else { return false }
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: kIsLifetime) { return true }
        if defaults.bool(forKey: kIsVIP) {
            let expire = defaults.double(forKey: kVIPExpireDate)
            if expire == 0 {
                // Migrate installations created before subscription expiry was
                // persisted. Treat the legacy flag as one transition period
                // instead of granting an annual product forever.
                let migratedExpiry = Date().addingTimeInterval(365 * 24 * 3600).timeIntervalSince1970
                defaults.set(migratedExpiry, forKey: kVIPExpireDate)
                updateEntitlementSealLocked()
                return true
            }
            if Date().timeIntervalSince1970 < expire {
                return true
            }
            defaults.set(false, forKey: kIsVIP)
            updateEntitlementSealLocked()
        }
        return false
    }

    /// Re-evaluate time-based entitlements when the app returns to foreground.
    /// 先同步刷新本地缓存（即时反馈），再异步跑 StoreKit 2 权威对账。
    public func refreshEntitlements() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshEntitlements()
            }
            return
        }
        self.isVIPUser = isVIP()
        self.isLifetimeUser = isLifetime()
        self.floorplanCreditsCount = floorplanCredits()
        self.tianjiCreditsCount = tianjiCredits()
        Task { await verifyEntitlementsAsync() }
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

    public func isLifetime() -> Bool {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard verifyEntitlementIntegrityLocked() else { return false }
        return UserDefaults.standard.bool(forKey: kIsLifetime)
    }

    public func floorplanCredits() -> Int {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard verifyEntitlementIntegrityLocked() else { return 0 }
        return UserDefaults.standard.integer(forKey: kFloorplanCredits)
    }

    public func tianjiCredits() -> Int {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        guard verifyEntitlementIntegrityLocked() else { return 0 }
        return UserDefaults.standard.integer(forKey: kTianjiCredits)
    }

    public func consumeFloorplanCredit() -> Bool {
        entitlementLock.lock()
        let defaults = UserDefaults.standard
        let result: (success: Bool, remain: Int?)
        if isVIPUnlocked() {
            result = (true, nil)
        } else {
            let credits = defaults.integer(forKey: kFloorplanCredits)
            if credits > 0 {
                let remain = credits - 1
                defaults.set(remain, forKey: kFloorplanCredits)
                updateEntitlementSealLocked()
                defaults.synchronize()
                result = (true, remain)
            } else {
                result = (false, nil)
            }
        }
        entitlementLock.unlock()
        if let remain = result.remain {
            DispatchQueue.main.async { [weak self] in self?.floorplanCreditsCount = remain }
        }
        return result.success
    }

    public func consumeTianjiCredit() -> Bool {
        entitlementLock.lock()
        let defaults = UserDefaults.standard
        let result: (success: Bool, remain: Int?)
        if isVIPUnlocked() {
            result = (true, nil)
        } else {
            let credits = defaults.integer(forKey: kTianjiCredits)
            if credits > 0 {
                let remain = credits - 1
                defaults.set(remain, forKey: kTianjiCredits)
                updateEntitlementSealLocked()
                defaults.synchronize()
                result = (true, remain)
            } else {
                result = (false, nil)
            }
        }
        entitlementLock.unlock()
        if let remain = result.remain {
            DispatchQueue.main.async { [weak self] in self?.tianjiCreditsCount = remain }
        }
        return result.success
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

    // MARK: - StoreKit 2 权威权益校验 (替代本地 ASN.1/CMS 验签)

    /// 同步入口：返回最近一次 StoreKit 2 权威校验的快照。
    /// StoreKit 2 的 AppTransaction 与已验证交易由 Apple 在系统层签名并校验，
    /// App 不再需要自行解析 ASN.1/PKCS#7 或维护本地收据文件哈希。
    public func verifyReceipt() -> ReceiptValidationResult {
        if let snapshot = entitlementSnapshot {
            return snapshot
        }
        return emptyReceiptResult()
    }

    /// 使权威快照失效（下一次 verifyReceipt() 返回空，直至重新对账）。
    private func invalidateReceiptCache() {
        entitlementSnapshot = nil
        entitlementSnapshotIsAuthoritative = false
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

    /// StoreKit 2 权威对账：
    /// 1. AppTransaction（整体收据，系统级验证）；
    /// 2. Transaction.currentEntitlements（当前有效的订阅与非消耗品权益，
    ///    含退款撤销后的自动移除与换机恢复）；
    /// 3. 以结果对账本地缓存层（点亮/收回 VIP、终身版与到期日）。
    private func verifyEntitlementsAsync() async {
        // 1. AppTransaction：整体收据系统级验证
        var appTxVerified = false
        var appBundleID: String?
        if let appTx = try? await AppTransaction.shared {
            switch appTx {
            case .verified(let tx):
                appTxVerified = true
                appBundleID = tx.appBundleID
            case .unverified(_, _):
                break
            }
        }

        // 2. 当前权益（订阅 + 非消耗品）。消费型商品（credits）由本地记账，
        //    StoreKit 不恢复消费型商品（与旧实现一致）。
        var purchasedIDs = Set<String>()
        var expiryDates: [Date] = []
        var hasVerifiedEntitlement = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let tx) = entitlement else { continue }
            guard IAPProductID(rawValue: tx.productID) != nil else { continue }
            hasVerifiedEntitlement = true
            purchasedIDs.insert(tx.productID)
            if let exp = tx.expirationDate {
                expiryDates.append(exp)
            }
        }

        // 3. 组装快照
        let expectedBundleID = Bundle.main.bundleIdentifier ?? "com.yanxiang.compass"
        let bundleMatched: Bool
        if let appBundleID = appBundleID {
            bundleMatched = (appBundleID == expectedBundleID) || (appBundleID == "com.yanxiang.compass")
        } else {
            // 无 AppTransaction（如全新安装尚未产生收据）时，
            // 以是否存在系统级验证通过的权益交易作为 BundleID 绑定依据
            bundleMatched = !purchasedIDs.isEmpty
        }
        let containerValid = appTxVerified || hasVerifiedEntitlement

        let snapshot = ReceiptValidationResult(
            isValidContainer: containerValid,
            bundleIDMatched: bundleMatched,
            purchasedProductIDs: purchasedIDs,
            latestExpirationDate: expiryDates.max(),
            receiptSHA256: "",
            certificateChainValid: containerValid,
            signatureValid: containerValid
        )
        entitlementSnapshot = snapshot
        entitlementSnapshotIsAuthoritative = true
        reconcileEntitlementsWithReceipt(snapshot)

        await MainActor.run {
            self.isVIPUser = self.isVIP()
            self.isLifetimeUser = self.isLifetime()
            self.floorplanCreditsCount = self.floorplanCredits()
            self.tianjiCreditsCount = self.tianjiCredits()
        }
    }

    /// 用 StoreKit 2 权威结果对账本地缓存层：点亮/收回终身版与年度 VIP。
    private func reconcileEntitlementsWithReceipt(_ receipt: ReceiptValidationResult) {
        guard receipt.isTrusted else { return }
        entitlementLock.lock()
        defer { entitlementLock.unlock() }

        let defaults = UserDefaults.standard
        var didChange = false

        // 1. 终身买断版对齐：存在已验证终身商品则点亮；权威结果中不含（已退款/未购）则收回
        let hasLifetimeInReceipt = receipt.purchasedProductIDs.contains(IAPProductID.proLifetime.rawValue)
        if hasLifetimeInReceipt {
            if !defaults.bool(forKey: kIsLifetime) || !defaults.bool(forKey: kIsVIP) {
                defaults.set(true, forKey: kIsLifetime)
                defaults.set(true, forKey: kIsVIP)
                didChange = true
            }
        } else if defaults.bool(forKey: kIsLifetime) {
            // StoreKit 2 权威结果经系统级验证，其中不含终身版（被退款/撤销）即收回
            defaults.set(false, forKey: kIsLifetime)
            didChange = true
        }

        // 2. 年度订阅会员对齐：存在已验证年度交易且未退款，比对并采用权威到期日；
        //    权威结果中既无年度订阅也无终身版，则立即收回 VIP
        let hasYearlyInReceipt = receipt.purchasedProductIDs.contains(IAPProductID.vipYearly.rawValue)
        if hasYearlyInReceipt {
            let currentExpiry = defaults.double(forKey: kVIPExpireDate)
            if let receiptExpiry = receipt.latestExpirationDate?.timeIntervalSince1970, receiptExpiry > currentExpiry {
                defaults.set(receiptExpiry, forKey: kVIPExpireDate)
                defaults.set(receiptExpiry > Date().timeIntervalSince1970, forKey: kIsVIP)
                didChange = true
            } else if currentExpiry > Date().timeIntervalSince1970 && !defaults.bool(forKey: kIsVIP) {
                defaults.set(true, forKey: kIsVIP)
                didChange = true
            }
        } else if !hasLifetimeInReceipt {
            // 权威结果既无终身版，也无有效年度订阅（已被 Apple 退款/撤回）：立即收回 VIP
            let currentExpiry = defaults.double(forKey: kVIPExpireDate)
            if defaults.bool(forKey: kIsVIP) || currentExpiry > 0 {
                defaults.set(false, forKey: kIsVIP)
                defaults.set(0.0, forKey: kVIPExpireDate)
                didChange = true
            }
        }

        if didChange {
            updateEntitlementSealLocked()
            defaults.synchronize()
        }
    }

    // MARK: - Keychain HMAC 防篡改保护（本地缓存层）

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

    private func computeEntitlementSealLocked() -> String {
        let defaults = UserDefaults.standard
        let isVip = defaults.bool(forKey: kIsVIP) ? 1 : 0
        let isLife = defaults.bool(forKey: kIsLifetime) ? 1 : 0
        let expireBits = Int64(defaults.double(forKey: kVIPExpireDate).rounded())
        let fpCredits = defaults.integer(forKey: kFloorplanCredits)
        let tjCredits = defaults.integer(forKey: kTianjiCredits)
        let payload = "v1|\(isVip)|\(isLife)|\(expireBits)|\(fpCredits)|\(tjCredits)"
        let key = deviceSealSymmetricKey()
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    private func updateEntitlementSealLocked() {
        let seal = computeEntitlementSealLocked()
        UserDefaults.standard.set(seal, forKey: kEntitlementSeal)
    }

    /// 校验 UserDefaults 中的本地权益缓存是否被篡改；若检测到篡改则拒绝并回滚。
    /// 权威背书来自 StoreKit 2 快照（entitlementSnapshot）：
    /// - HMAC 封印匹配 → 本地缓存可信；
    /// - 封印不匹配且权威校验已完成 → 以权威结果重签或清除伪造权益；
    /// - 封印不匹配且权威校验尚未完成（启动瞬间）→ 乐观保留，等待异步对账裁决。
    private func verifyEntitlementIntegrityLocked() -> Bool {
        let defaults = UserDefaults.standard
        let hasAnyClaimedEntitlement =
            defaults.bool(forKey: kIsVIP) ||
            defaults.bool(forKey: kIsLifetime) ||
            defaults.integer(forKey: kFloorplanCredits) > 0 ||
            defaults.integer(forKey: kTianjiCredits) > 0

        guard hasAnyClaimedEntitlement else { return true }

        let expectedSeal = computeEntitlementSealLocked()
        if let storedSeal = defaults.string(forKey: kEntitlementSeal),
           storedSeal == expectedSeal {
            return true
        }

        // 封印不匹配：以 StoreKit 2 权威快照背书（升级后首次运行或外部篡改）
        if entitlementSnapshotIsAuthoritative, let snapshot = entitlementSnapshot {
            if snapshot.isTrusted {
                // 仅保留权威结果确认过的非消耗型/订阅权益并重新加签
                let allowLifetime = snapshot.purchasedProductIDs.contains(IAPProductID.proLifetime.rawValue)
                let allowYearly = snapshot.purchasedProductIDs.contains(IAPProductID.vipYearly.rawValue)
                defaults.set(allowLifetime, forKey: kIsLifetime)
                defaults.set(allowLifetime || allowYearly, forKey: kIsVIP)
                let processedIDs = defaults.stringArray(forKey: kProcessedTransactionIDs) ?? []
                let hasFloorplanInReceipt = snapshot.purchasedProductIDs.contains(IAPProductID.floorplanSingle.rawValue)
                    || snapshot.purchasedProductIDs.contains("com.yanxiang.compass.floorplan.single")
                    || snapshot.purchasedProductIDs.contains("com.yanxiang.luopan.floorplan.single")
                if !hasFloorplanInReceipt && processedIDs.isEmpty {
                    defaults.set(0, forKey: kFloorplanCredits)
                }
                if !snapshot.purchasedProductIDs.contains(IAPProductID.tianjiSingle.rawValue) && processedIDs.isEmpty {
                    defaults.set(0, forKey: kTianjiCredits)
                }
                updateEntitlementSealLocked()
                return allowLifetime || allowYearly || !processedIDs.isEmpty
            } else {
                // 权威校验完成且确认无有效权益：判定为本地篡改，立即清除伪造权益
                defaults.set(false, forKey: kIsVIP)
                defaults.set(false, forKey: kIsLifetime)
                defaults.set(0.0, forKey: kVIPExpireDate)
                defaults.set(0, forKey: kFloorplanCredits)
                defaults.set(0, forKey: kTianjiCredits)
                updateEntitlementSealLocked()
                return false
            }
        }

        // 权威校验尚未完成（启动瞬间/离线启动）：乐观保留，
        // 后续 verifyEntitlementsAsync() 完成对账后自然裁决。
        return true
    }
}
