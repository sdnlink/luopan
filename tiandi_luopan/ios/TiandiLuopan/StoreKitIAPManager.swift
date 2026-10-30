import Foundation
import StoreKit
import Combine
import CryptoKit
import Security
import UIKit

// MARK: - 本地 App Store 收据校验结果

public struct ReceiptValidationResult {
    public let isValidContainer: Bool
    public let bundleIDMatched: Bool
    public let purchasedProductIDs: Set<String>
    public let latestExpirationDate: Date?
    public let receiptSHA256: String
    /// PKCS#7 证书链是否链到系统信任锚（Apple 签发证书链）。
    public let certificateChainValid: Bool
    /// CMS 数字签名是否由签名者证书私钥签发（防伪造/防篡改）。
    public let signatureValid: Bool

    /// 仅结构层面有效（PKCS#7 容器 + BundleID 匹配），不含密码学验证。
    public var isStructurallyValid: Bool {
        return isValidContainer && bundleIDMatched
    }

    /// 可信收据：结构有效 **且** 证书链可信 **且** 数字签名验证通过。
    /// App Store 真收据必然同时满足三项；伪造/篡改数据无法通过 Apple 签名验证。
    public var isTrusted: Bool {
        return isValidContainer && bundleIDMatched && certificateChainValid && signatureValid
    }
}

// MARK: - IAP 商品与权益定义

public enum IAPProductID: String, CaseIterable {
    case vipYearly = "com.yanxiang.luopan.vip.yearly"           // 演象·年度堪舆会员 198元/年
    case proLifetime = "com.yanxiang.luopan.pro.lifetime"       // 演象·大师终身版 298元 一次性买断
    case floorplanSingle = "com.yanxiang.luopan.floorplan.single" // 户型空间立极·单套全案 19.9元
    case tianjiSingle = "com.yanxiang.luopan.tianji.single"       // 福宅天机宣纸长卷·单次高清导出 9.9元
    
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
    func iapManagerDidUpdateProducts(_ products: [SKProduct])
    func iapManagerDidCompletePurchase(productId: String, transactionId: String)
    func iapManagerDidFailPurchase(productId: String, errorMsg: String)
    func iapManagerDidRestorePurchases(unlockedProductIds: [String])
}

// MARK: - StoreKit 管理器

public class StoreKitIAPManager: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    
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
        // 都重新解析+验签 App Store 收据（主线程重活，会造成明显卡顿）。
        // 针对篡改/到期的完整校验（本地收据签名 + 防篡改 HMAC 封印）在
        // init、购买完成、恢复购买、回到前台(refreshEntitlements) 时执行，
        // 这些路径会调用 isVIP()/isLifetime()，进而触发真正的收据验证。
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
    
    private var productsRequest: SKProductsRequest?
    private var availableProducts: [String: SKProduct] = [:]
    private var lastProductsFetchDate: Date?
    private let productsRetryInterval: TimeInterval = 30
    private let entitlementLock = NSLock()
    
    // 本地持久化权益 Keys
    private let kIsVIP = "yx_iap_is_vip"
    private let kIsLifetime = "yx_iap_is_lifetime"
    private let kVIPExpireDate = "yx_iap_vip_expire_date"
    private let kFloorplanCredits = "yx_iap_floorplan_credits"
    private let kTianjiCredits = "yx_iap_tianji_credits"
    private var receiptRefreshRequest: SKReceiptRefreshRequest?
    private var receiptRefreshCompletion: ((Bool) -> Void)?
    // 收据校验结果缓存：以收据文件修改时间为 key，文件不变则直接复用，
    // 避免 isVIP()/floorplanCredits() 等查询在每次调用时重复解析 ASN.1 + 验签（主线程重活）。
    private var cachedReceiptResult: ReceiptValidationResult?
    private var cachedReceiptModDate: Date?
    private let kProcessedTransactionIDs = "yx_iap_processed_transaction_ids"
    private let kEntitlementSeal = "yx_iap_entitlement_hmac_seal"
    private let kKeychainSealAccount = "com.yanxiang.compass.iap.seal.key"
    private let kLegacyKeychainSealAccount = "com.yanxiang.luopan.iap.seal.key"
    
    private override init() {
        super.init()
        reconcileEntitlementsWithReceipt(verifyReceipt())
        self.isVIPUser = isVIP()
        self.isLifetimeUser = isLifetime()
        self.floorplanCreditsCount = floorplanCredits()
        self.tianjiCreditsCount = tianjiCredits()
        SKPaymentQueue.default().add(self)
        fetchProducts()
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    public func purchase(productId: String) {
        purchaseProduct(id: productId)
    }
    
    // MARK: - 商品信息请求
    
    public func fetchProducts() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.fetchProducts() }
            return
        }
        isLoadingProducts = true
        lastProductsFetchDate = Date()
        let productIdentifiers = Set(IAPProductID.allCases.map { $0.rawValue })
        productsRequest?.cancel()
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
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
           // A failed/empty request must be recoverable the next time the
           // paywall or foreground lifecycle appears. Otherwise the initial
           // offline launch can leave every price unavailable for the whole
           // retry window even after the App Store connection is restored.
           (isLoadingProducts || !availableProducts.isEmpty) {
            return
        }
        fetchProducts()
    }
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.productsRequest(request, didReceive: response)
            }
            return
        }
        if let activeRefresh = receiptRefreshRequest, request === activeRefresh {
            receiptRefreshRequest = nil
            let completion = receiptRefreshCompletion
            receiptRefreshCompletion = nil
            completion?(false)
            return
        }
        guard let activeRequest = productsRequest, request === activeRequest else { return }
        isLoadingProducts = false
        productsRequest = nil
        availableProducts.removeAll()
        for product in response.products {
            availableProducts[product.productIdentifier] = product
        }
        productsRevision &+= 1
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.iapManagerDidUpdateProducts(Array(self.availableProducts.values))
        }
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.request(request, didFailWithError: error)
            }
            return
        }
        if let activeRefresh = receiptRefreshRequest, request === activeRefresh {
            receiptRefreshRequest = nil
            let completion = receiptRefreshCompletion
            receiptRefreshCompletion = nil
            completion?(false)
            return
        }
        guard let activeRequest = productsRequest, request === activeRequest else { return }
        isLoadingProducts = false
        productsRequest = nil
        // Product metadata can fail to load before the user has attempted a
        // purchase (offline launch, storefront outage, or a temporary App
        // Store response). This is not a payment failure; publishing it via
        // lastErrorMessage would make every paywall present a misleading
        // purchase-error alert on app startup. Prices remain unavailable and
        // an explicit purchase attempt will show the actionable retry error.
        print("StoreKit request products failed: \(error.localizedDescription)")
    }
    
    public func requestDidFinish(_ request: SKRequest) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.requestDidFinish(request)
            }
            return
        }
        if let activeRefresh = receiptRefreshRequest, request === activeRefresh {
            receiptRefreshRequest = nil
            invalidateReceiptCache() // 刷新后收据已更新，强制重读
            let result = verifyReceipt()
            reconcileEntitlementsWithReceipt(result)
            let completion = receiptRefreshCompletion
            receiptRefreshCompletion = nil
            completion?(result.isTrusted)
        }
    }
    
    /// 刷新 App Store 本地签名收据 (SKReceiptRefreshRequest) 并执行本地校验恢复权益
    public func refreshReceipt(completion: ((Bool) -> Void)? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.refreshReceipt(completion: completion)
            }
            return
        }
        receiptRefreshCompletion = completion
        receiptRefreshRequest?.cancel()
        let request = SKReceiptRefreshRequest(receiptProperties: nil)
        request.delegate = self
        receiptRefreshRequest = request
        request.start()
    }
    
    // MARK: - 购买商品
    
    public func purchaseProduct(id: String) {
        lastErrorMessage = nil
        lastStatusMessage = nil
        guard !isProcessingPurchase else { return }
        guard SKPaymentQueue.canMakePayments() else {
            failPurchase(id: id, message: LocalizationManager.shared.t("iap_err_parental_controls"))
            return
        }
        
        guard let product = availableProducts[id] else {
            failPurchase(id: id, message: LocalizationManager.shared.t("iap_err_product_unavailable"))
            fetchProducts()
            return
        }

        isProcessingPurchase = true
        SKPaymentQueue.default().add(SKPayment(product: product))
    }

    private func failPurchase(id: String, message: String) {
        isProcessingPurchase = false
        lastErrorMessage = message
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.iapManagerDidFailPurchase(productId: id, errorMsg: message)
        }
    }
    
    // MARK: - 恢复购买 (App Store 审核必备)
    
    public func restorePurchases() {
        lastErrorMessage = nil
        lastStatusMessage = nil
        guard !isProcessingPurchase else { return }
        isProcessingPurchase = true
        invalidateReceiptCache()
        let localReceipt = verifyReceipt()
        if localReceipt.isTrusted {
            reconcileEntitlementsWithReceipt(localReceipt)
        } else {
            refreshReceipt()
        }
        SKPaymentQueue.default().restoreCompletedTransactions()
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
    
    // MARK: - SKPaymentTransactionObserver
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.paymentQueue(queue, updatedTransactions: transactions)
            }
            return
        }
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                handlePurchased(transaction)
            case .restored:
                handleRestored(transaction)
            case .failed:
                handleFailed(transaction)
            case .deferred:
                // A deferred transaction is waiting for Ask to Buy or an
                // organisation approval.  StoreKit will send a later update
                // for the same transaction; leaving the local spinner on
                // would make the paywall appear permanently stuck.
                isProcessingPurchase = false
                lastStatusMessage = LocalizationManager.shared.t("iap_purchase_deferred")
            case .purchasing:
                break
            @unknown default:
                break
            }
        }
    }
    
    private func handlePurchased(_ transaction: SKPaymentTransaction) {
        invalidateReceiptCache() // 交易完成后本地收据可能更新，下次校验强制重读
        let pid = transaction.payment.productIdentifier
        let txId = transaction.transactionIdentifier ?? "\(pid)-\(transaction.transactionDate?.timeIntervalSince1970 ?? 0)"
        if !claimTransaction(txId) {
            SKPaymentQueue.default().finishTransaction(transaction)
            isProcessingPurchase = false
            return
        }

        unlockEntitlement(for: pid, transactionDate: transaction.transactionDate, extendSubscription: true)
        SKPaymentQueue.default().finishTransaction(transaction)
        
        DispatchQueue.main.async { [weak self] in
            self?.isProcessingPurchase = false
            self?.lastCompletedProductID = pid
            self?.delegate?.iapManagerDidCompletePurchase(productId: pid, transactionId: txId)
        }
    }
    
    private func handleRestored(_ transaction: SKPaymentTransaction) {
        invalidateReceiptCache() // 恢复购买后本地收据可能更新，下次校验强制重读
        let pid = transaction.payment.productIdentifier
        let txId = transaction.transactionIdentifier ?? "\(pid)-restored"
        // A restore callback replays an existing transaction. Non-consumable
        // entitlements must be re-applied even when this transaction ID was
        // already seen, otherwise a restored lifetime purchase can remain
        // hidden behind stale local flags. `extendSubscription: false` keeps
        // the operation idempotent and never adds another 365 days.
        if pid == IAPProductID.vipYearly.rawValue || pid == IAPProductID.proLifetime.rawValue {
            _ = claimTransaction(txId)
            unlockEntitlement(for: pid, transactionDate: transaction.transactionDate, extendSubscription: false)
        }
        // Consumables are not restorable through the App Store. Ignore any
        // unexpected replay so restore cannot mint additional credits.
        SKPaymentQueue.default().finishTransaction(transaction)
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
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.paymentQueueRestoreCompletedTransactionsFinished(queue)
            }
            return
        }
        reconcileEntitlementsWithReceipt(verifyReceipt())
        var unlocked: [String] = []
        if isVIP() { unlocked.append(IAPProductID.vipYearly.rawValue) }
        if isLifetime() { unlocked.append(IAPProductID.proLifetime.rawValue) }
        if unlocked.isEmpty {
            // Stopping the spinner without feedback leaves users unsure
            // whether restore completed or silently failed. Consumable
            // credits are intentionally not restored by StoreKit, so only
            // report the absence of restorable subscriptions/non-consumables.
            lastStatusMessage = LocalizationManager.shared.t("iap_restore_none")
        } else {
            lastStatusMessage = nil
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isProcessingPurchase = false
            self?.delegate?.iapManagerDidRestorePurchases(unlockedProductIds: unlocked)
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.paymentQueue(queue, restoreCompletedTransactionsFailedWithError: error)
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.isProcessingPurchase = false
            self?.lastErrorMessage = error.localizedDescription
            self?.delegate?.iapManagerDidFailPurchase(productId: "", errorMsg: "\(LocalizationManager.shared.t("iap_err_restore_failed_prefix"))\(error.localizedDescription)")
        }
    }
    
    private func handleFailed(_ transaction: SKPaymentTransaction) {
        let pid = transaction.payment.productIdentifier
        let lang = LocalizationManager.shared
        var errorMsg = lang.t("iap_err_cancelled_or_unknown")
        if let err = transaction.error as? SKError {
            switch err.code {
            case .paymentCancelled:
                errorMsg = lang.t("iap_err_payment_cancelled")
            case .paymentNotAllowed:
                errorMsg = lang.t("iap_err_payment_not_allowed")
            case .paymentInvalid:
                errorMsg = lang.t("iap_err_payment_invalid")
            case .clientInvalid:
                errorMsg = lang.t("iap_err_client_invalid")
            default:
                errorMsg = err.localizedDescription
            }
        }
        SKPaymentQueue.default().finishTransaction(transaction)
        
        DispatchQueue.main.async { [weak self] in
            self?.isProcessingPurchase = false
            if let code = (transaction.error as? SKError)?.code, code != .paymentCancelled {
                self?.lastErrorMessage = errorMsg
            }
            self?.delegate?.iapManagerDidFailPurchase(productId: pid, errorMsg: errorMsg)
        }
    }
    
    // MARK: - 权益本地管理
    
    private func unlockEntitlement(for pid: String, transactionDate: Date? = nil, extendSubscription: Bool = true) {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        let defaults = UserDefaults.standard
        if pid == IAPProductID.proLifetime.rawValue {
            defaults.set(true, forKey: kIsLifetime)
            defaults.set(true, forKey: kIsVIP)
        } else if pid == IAPProductID.vipYearly.rawValue {
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
                // StoreKit/receipt validation remains authoritative for
                // auto-renewable subscriptions in production.
                let restoredExpiry = restoredDate.addingTimeInterval(365 * 24 * 3600)
                let effectiveExpiry = max(oldExpiry, restoredExpiry.timeIntervalSince1970)
                defaults.set(effectiveExpiry, forKey: kVIPExpireDate)
                defaults.set(effectiveExpiry > Date().timeIntervalSince1970, forKey: kIsVIP)
            } else {
                defaults.set(oldExpiry > Date().timeIntervalSince1970, forKey: kIsVIP)
            }
        } else if pid == IAPProductID.floorplanSingle.rawValue {
            let current = defaults.integer(forKey: kFloorplanCredits)
            defaults.set(current + 1, forKey: kFloorplanCredits)
        } else if pid == IAPProductID.tianjiSingle.rawValue {
            let current = defaults.integer(forKey: kTianjiCredits)
            defaults.set(current + 1, forKey: kTianjiCredits)
        }
        if true {
            updateEntitlementSealLocked()
        }
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
                // persisted.  Treat the legacy flag as one transition period
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
    public func refreshEntitlements() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reconcileEntitlementsWithReceipt(self.verifyReceipt())
            self.isVIPUser = self.isVIP()
            self.isLifetimeUser = self.isLifetime()
            self.floorplanCreditsCount = self.floorplanCredits()
            self.tianjiCreditsCount = self.tianjiCredits()
        }
    }

    public func localizedPrice(for productID: IAPProductID) -> String {
        guard let product = availableProducts[productID.rawValue] else {
            return isLoadingProducts
                ? LocalizationManager.shared.t("price_loading")
                : LocalizationManager.shared.t("price_unavailable")
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? LocalizationManager.shared.t("price_unavailable")
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
            if let skp = availableProducts[item.rawValue] {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.locale = skp.priceLocale
                if let formattedPrice = formatter.string(from: skp.price) {
                    price = formattedPrice
                }
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
    
    // MARK: - 本地收据校验 (appStoreReceiptURL / ASN.1 PKCS#7) 与 Keychain HMAC 防篡改保护
    
    /// 读取并校验 Bundle.main.appStoreReceiptURL 本地收据容器、BundleID 与内购商品载荷（基于 ASN.1 DER TLV 结构化解析）
    /// 该入口带缓存：收据文件未变化时直接返回上次结果，避免每次权益查询都重新解析 ASN.1 + CMS 验签（主线程重活）。
    public func verifyReceipt() -> ReceiptValidationResult {
        if let url = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: url.path) {
            let mod = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if let cached = cachedReceiptResult, let cachedMod = cachedReceiptModDate, cachedMod == mod {
                return cached
            }
            let result = computeReceiptValidation()
            cachedReceiptResult = result
            cachedReceiptModDate = mod
            return result
        }
        cachedReceiptResult = nil
        cachedReceiptModDate = nil
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

    /// 使收据校验缓存失效（购买/恢复/刷新收据后调用，确保下次读取最新收据）。
    private func invalidateReceiptCache() {
        cachedReceiptResult = nil
        cachedReceiptModDate = nil
    }

    /// 真正执行 App Store 本地收据的 ASN.1 解析与密码学验签。
    private func computeReceiptValidation() -> ReceiptValidationResult {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path),
              let receiptData = try? Data(contentsOf: receiptURL),
              receiptData.count > 64 else {
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
        
        let digest = SHA256.hash(data: receiptData)
        let sha256Hex = digest.map { String(format: "%02x", $0) }.joined()
        let bytes = [UInt8](receiptData)
        
        // 1. 校验 PKCS#7 / ASN.1 DER 外层 SEQUENCE (0x30) 及 signedData OID (1.2.840.113549.1.7.2)
        let pkcs7SignedDataOID: [UInt8] = [0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02]
        let outerTLV = readASN1TLV(in: bytes, at: 0, limit: bytes.count)
        let isASN1Sequence = (outerTLV?.tag == 0x30)
        let hasSignedDataOID = receiptData.range(of: Data(pkcs7SignedDataOID)) != nil
        let isValidContainer = isASN1Sequence && hasSignedDataOID
        
        // 2. 通过 ASN.1 DER TLV 递归遍历 Apple Receipt Attribute (SEQUENCE { INTEGER type, INTEGER version, OCTET STRING value })
        //    Info.plist 与 project.pbxproj 的真实 Bundle ID 为 "com.yanxiang.compass"
        let expectedBundleID = Bundle.main.bundleIdentifier ?? "com.yanxiang.compass"
        var parsedBundleID: String?
        var purchasedIDs = Set<String>()
        var expiryDates: [Date] = []
        
        parseASN1ReceiptAttributes(in: bytes, range: 0..<bytes.count, depth: 0) { attrType, valueRange in
            switch attrType {
            case 2:
                // Attribute Type 2: Bundle Identifier (UTF8String 0x0C / IA5String 0x16)
                if let bundleStr = self.decodeASN1String(in: bytes, range: valueRange), !bundleStr.isEmpty {
                    parsedBundleID = bundleStr
                }
            case 17:
                // Attribute Type 17: In-App Purchase Receipt (嵌套 SET of InAppAttribute)
                let iapRecord = self.parseInAppPurchaseRecord(in: bytes, range: valueRange)
                guard !iapRecord.isCancelled,
                      let productID = iapRecord.productID,
                      IAPProductID(rawValue: productID) != nil else {
                    return
                }
                purchasedIDs.insert(productID)
                if let expDate = iapRecord.expirationDate {
                    expiryDates.append(expDate)
                } else if productID == IAPProductID.vipYearly.rawValue,
                          let purchaseDate = iapRecord.purchaseDate,
                          let derivedExpiry = Calendar(identifier: .gregorian).date(byAdding: .year, value: 1, to: purchaseDate) {
                    expiryDates.append(derivedExpiry)
                }
            default:
                break
            }
        }
        
        let bundleIDMatched = (parsedBundleID == expectedBundleID) || (parsedBundleID == "com.yanxiang.compass")
        let latestExpiry = expiryDates.max()
        
        // 3. 密码学验证：PKCS#7 证书链可信度 + CMS 数字签名。
        //    结构/BundleID 校验可被任意“长得像收据”的数据通过，只有 Apple
        //    签发的证书链与签名才能证明该收据确由 App Store 生成且未被篡改。
        let signatureVerification = ReceiptSignatureVerifier.verify(receiptData: receiptData)
        
        return ReceiptValidationResult(
            isValidContainer: isValidContainer,
            bundleIDMatched: bundleIDMatched,
            purchasedProductIDs: purchasedIDs,
            latestExpirationDate: latestExpiry,
            receiptSHA256: sha256Hex,
            certificateChainValid: signatureVerification.certificateChainValid,
            signatureValid: signatureVerification.signatureValid
        )
    }
    
    // MARK: - PKCS#7 收据密码学验证 (Apple App Store Receipt Signature)

    private static let signedDataOID: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02]       // 1.2.840.113549.1.7.2
    private static let sha1OID: [UInt8] = [0x2B, 0x0E, 0x03, 0x02, 0x1A]                                     // 1.3.14.3.2.26
    private static let sha256OID: [UInt8] = [0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01]           // 2.16.840.1.101.3.4.2.1
    private static let sha1WithRSAOID: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x05]     // 1.2.840.113549.1.1.5
    private static let sha256WithRSAOID: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B]   // 1.2.840.113549.1.1.11
    private static let rsaEncryptionOID: [UInt8] = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01]   // 1.2.840.113549.1.1.1
    private static let ecdsaWithSHA256OID: [UInt8] = [0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02]       // 1.2.840.10045.4.3.2

    /// 对 App Store 本地收据做两层密码学验证：
    /// 1) 证书链可信（SecTrust 链到系统信任锚，即 Apple 签发的证书链）；
    /// 2) CMS 数字签名由签名者证书的私钥签发（防止内容被篡改或整体伪造）。
    /// 结构校验（SEQUENCE/OID/BundleID）无法证明“这是 Apple 生成的收据”，
    /// 只有签名链可以。实现遵循 RFC 5652 (CMS) 对带 signedAttrs 的签名约定。
    fileprivate struct ReceiptSignatureVerifier {
        struct VerificationResult {
            let certificateChainValid: Bool
            let signatureValid: Bool
        }

        private struct DERNode {
            let tag: UInt8
            let isConstructed: Bool
            let valueRange: Range<Int>
            let nextOffset: Int
        }

        static func verify(receiptData: Data) -> VerificationResult {
            let bytes = [UInt8](receiptData)
            let empty = VerificationResult(certificateChainValid: false, signatureValid: false)

            // 外层：SEQUENCE { OID signedData, [0] EXPLICIT SignedData }
            guard let outer = readDER(bytes, 0, bytes.count), outer.tag == 0x30,
                  let oid = readDER(bytes, outer.valueRange.lowerBound, outer.valueRange.upperBound),
                  oid.tag == 0x06,
                  Array(bytes[oid.valueRange]) == signedDataOID,
                  let sdExplicit = readDER(bytes, oid.nextOffset, outer.valueRange.upperBound),
                  sdExplicit.tag == 0xA0,
                  let signedData = readDER(bytes, sdExplicit.valueRange.lowerBound, sdExplicit.valueRange.upperBound),
                  signedData.tag == 0x30 else {
                return empty
            }

            // SignedData: version, digestAlgorithms, contentInfo, [0] certificates, [1] crls?, signerInfos
            let sdRange = signedData.valueRange
            guard let version = readDER(bytes, sdRange.lowerBound, sdRange.upperBound), version.tag == 0x02,
                  let digestAlgs = readDER(bytes, version.nextOffset, sdRange.upperBound), digestAlgs.tag == 0x31,
                  let contentInfo = readDER(bytes, digestAlgs.nextOffset, sdRange.upperBound), contentInfo.tag == 0x30 else {
                return empty
            }
            // contentInfo: SEQUENCE { OID, content? }；content 字段原始编码（含 [0] EXPLICIT 标签）作为无 signedAttrs 时的被签数据
            guard let ciOID = readDER(bytes, contentInfo.valueRange.lowerBound, contentInfo.valueRange.upperBound),
                  ciOID.tag == 0x06 else {
                return empty
            }
            let contentFieldRange = ciOID.nextOffset..<contentInfo.valueRange.upperBound

            // certificates [0] IMPLICIT（可选）
            var cursor = contentInfo.nextOffset
            var certificates: [Data] = []
            if let certSet = readDER(bytes, cursor, sdRange.upperBound), certSet.tag == 0xA0 {
                var off = certSet.valueRange.lowerBound
                let certLimit = certSet.valueRange.upperBound
                while off + 2 <= certLimit {
                    guard let cert = readDER(bytes, off, certLimit), cert.tag == 0x30 else { break }
                    certificates.append(Data(bytes[cert.valueRange]))
                    off = cert.nextOffset
                }
                cursor = certSet.nextOffset
            }
            // crls [1] IMPLICIT（可选）
            if let crlSet = readDER(bytes, cursor, sdRange.upperBound), crlSet.tag == 0xA1 {
                cursor = crlSet.nextOffset
            }
            guard let signerInfos = readDER(bytes, cursor, sdRange.upperBound), signerInfos.tag == 0x31,
                  let signer = readDER(bytes, signerInfos.valueRange.lowerBound, signerInfos.valueRange.upperBound),
                  signer.tag == 0x30 else {
                return empty
            }

            // SignerInfo: version, issuerAndSerial, digestAlgorithm, [0] signedAttrs?, signatureAlgorithm, signature
            let siRange = signer.valueRange
            guard let siVersion = readDER(bytes, siRange.lowerBound, siRange.upperBound), siVersion.tag == 0x02,
                  let issuerSerial = readDER(bytes, siVersion.nextOffset, siRange.upperBound), issuerSerial.tag == 0x30,
                  let digAlg = readDER(bytes, issuerSerial.nextOffset, siRange.upperBound), digAlg.tag == 0x30,
                  let digAlgOID = readDER(bytes, digAlg.valueRange.lowerBound, digAlg.valueRange.upperBound),
                  digAlgOID.tag == 0x06 else {
                return empty
            }
            let digestAlgOIDBytes = Array(bytes[digAlgOID.valueRange])

            var siCursor = digAlg.nextOffset
            var signedAttrsValue: [UInt8]?
            if let attrs = readDER(bytes, siCursor, siRange.upperBound), attrs.tag == 0xA0 {
                signedAttrsValue = Array(bytes[attrs.valueRange])
                siCursor = attrs.nextOffset
            }
            guard let sigAlg = readDER(bytes, siCursor, siRange.upperBound), sigAlg.tag == 0x30,
                  let sigAlgOID = readDER(bytes, sigAlg.valueRange.lowerBound, sigAlg.valueRange.upperBound),
                  sigAlgOID.tag == 0x06,
                  let signature = readDER(bytes, sigAlg.nextOffset, siRange.upperBound), signature.tag == 0x04 else {
                return empty
            }
            let sigAlgOIDBytes = Array(bytes[sigAlgOID.valueRange])
            let signatureData = Data(bytes[signature.valueRange])
            guard !signatureData.isEmpty else { return empty }

            // 签名者证书序列号：issuerAndSerial = SEQUENCE { issuer Name, serial INTEGER }
            guard let issuerName = readDER(bytes, issuerSerial.valueRange.lowerBound, issuerSerial.valueRange.upperBound),
                  issuerName.tag == 0x30,
                  let serial = readDER(bytes, issuerName.nextOffset, issuerSerial.valueRange.upperBound),
                  serial.tag == 0x02 else {
                return empty
            }
            let serialBytes = Array(bytes[serial.valueRange])
            guard !serialBytes.isEmpty else { return empty }

            // 在证书集合中定位签名者证书：tbsCertificate 内的第一个 INTEGER 即 serialNumber
            var signerCertDER: Data?
            for certData in certificates {
                let cbytes = [UInt8](certData)
                guard let cert = readDER(cbytes, 0, cbytes.count), cert.tag == 0x30,
                      let tbs = readDER(cbytes, cert.valueRange.lowerBound, cert.valueRange.upperBound), tbs.tag == 0x30,
                      let certSerial = readDER(cbytes, tbs.valueRange.lowerBound, tbs.valueRange.upperBound),
                      certSerial.tag == 0x02,
                      Array(cbytes[certSerial.valueRange]) == serialBytes else { continue }
                signerCertDER = certData
                break
            }
            guard let signerCertDER = signerCertDER else { return empty }

            // ===== 1. 证书链验证（系统信任锚） =====
            // SecTrustCreateWithCertificates 约定首个证书为待评估的叶子证书。
            // PKCS#7 中的 certificates 为无序集合，必须确保 signerCert 排在首位。
            guard let signerCert = SecCertificateCreateWithData(nil, signerCertDER as CFData) else { return empty }
            var orderedCerts: [SecCertificate] = [signerCert]
            for cdata in certificates where cdata != signerCertDER {
                if let cert = SecCertificateCreateWithData(nil, cdata as CFData) {
                    orderedCerts.append(cert)
                }
            }
            let policy = SecPolicyCreateBasicX509()
            var trust: SecTrust?
            let trustStatus = SecTrustCreateWithCertificates(orderedCerts as CFArray, [policy] as CFArray, &trust)
            guard trustStatus == errSecSuccess, let trust = trust else { return empty }
            let chainValid = SecTrustEvaluateWithError(trust, nil)

            // ===== 2. CMS 数字签名验证 =====
            // 直接从签名者叶子证书拷贝公钥，确保验签公钥与签名私钥严格对应
            guard chainValid, let publicKey = SecCertificateCopyKey(signerCert) ?? SecTrustCopyPublicKey(trust) else {
                return VerificationResult(certificateChainValid: chainValid, signatureValid: false)
            }

            // 被签数据：有 signedAttrs 时按 CMS 约定重编码为 SET (0x31) 再摘要；
            // 无 signedAttrs 时退化为对 contentInfo.content 字段原始编码摘要。
            let dataToDigest: Data
            if let attrsValue = signedAttrsValue {
                let setBytes = [UInt8(0x31)] + derLengthBytes(attrsValue.count) + attrsValue
                dataToDigest = Data(setBytes)
            } else {
                dataToDigest = Data(bytes[contentFieldRange])
            }

            // 算法映射（Apple 收据以 RSA 为主，ECDSA 作兜底）
            var keyAlgorithm: SecKeyAlgorithm?
            var useSHA256 = false
            switch sigAlgOIDBytes {
            case sha1WithRSAOID:
                keyAlgorithm = .rsaSignatureDigestPKCS1v15SHA1
            case sha256WithRSAOID:
                keyAlgorithm = .rsaSignatureDigestPKCS1v15SHA256
                useSHA256 = true
            case rsaEncryptionOID:
                if digestAlgOIDBytes == sha256OID {
                    keyAlgorithm = .rsaSignatureDigestPKCS1v15SHA256
                    useSHA256 = true
                } else if digestAlgOIDBytes == sha1OID {
                    keyAlgorithm = .rsaSignatureDigestPKCS1v15SHA1
                } else {
                    return VerificationResult(certificateChainValid: true, signatureValid: false)
                }
            case ecdsaWithSHA256OID:
                keyAlgorithm = .ecdsaSignatureMessageX962SHA256
            default:
                return VerificationResult(certificateChainValid: true, signatureValid: false)
            }
            guard let keyAlgorithm = keyAlgorithm else {
                return VerificationResult(certificateChainValid: true, signatureValid: false)
            }
            guard SecKeyIsAlgorithmSupported(publicKey, .verify, keyAlgorithm) else {
                return VerificationResult(certificateChainValid: true, signatureValid: false)
            }

            let signedDataForVerification: Data
            if keyAlgorithm == .ecdsaSignatureMessageX962SHA256 {
                signedDataForVerification = dataToDigest
            } else {
                signedDataForVerification = useSHA256
                    ? Data(SHA256.hash(data: dataToDigest))
                    : Data(Insecure.SHA1.hash(data: dataToDigest))
            }

            var verifyError: Unmanaged<CFError>?
            let signatureValid = SecKeyVerifySignature(
                publicKey,
                keyAlgorithm,
                signedDataForVerification as CFData,
                signatureData as CFData,
                &verifyError
            )
            return VerificationResult(certificateChainValid: true, signatureValid: signatureValid)
        }

        // MARK: DER 读取与长度编码

        private static func readDER(_ bytes: [UInt8], _ offset: Int, _ limit: Int) -> DERNode? {
            guard offset >= 0, offset + 2 <= limit else { return nil }
            let tag = bytes[offset]
            let isConstructed = (tag & 0x20) != 0
            var idx = offset + 1
            let lenByte = bytes[idx]
            idx += 1
            if (lenByte & 0x80) == 0 {
                let length = Int(lenByte)
                guard idx + length <= limit else { return nil }
                return DERNode(tag: tag, isConstructed: isConstructed, valueRange: idx..<(idx + length), nextOffset: idx + length)
            } else {
                let octetsCount = Int(lenByte & 0x7F)
                guard octetsCount >= 1, octetsCount <= 4, idx + octetsCount <= limit else { return nil }
                var length = 0
                for i in 0..<octetsCount {
                    length = (length << 8) | Int(bytes[idx + i])
                }
                idx += octetsCount
                guard length >= 0, idx + length <= limit else { return nil }
                return DERNode(tag: tag, isConstructed: isConstructed, valueRange: idx..<(idx + length), nextOffset: idx + length)
            }
        }

        private static func derLengthBytes(_ length: Int) -> [UInt8] {
            if length < 128 { return [UInt8(length)] }
            var value = length
            var octets: [UInt8] = []
            while value > 0 {
                octets.insert(UInt8(value & 0xFF), at: 0)
                value >>= 8
            }
            return [0x80 | UInt8(octets.count)] + octets
        }
    }

    // MARK: - ASN.1 DER TLV 结构化解析器 (Apple PKCS#7 Receipt Attributes)

    private struct ASN1TLV {
        let tag: UInt8
        let isConstructed: Bool
        let isIndefiniteLength: Bool
        let valueRange: Range<Int>
        let nextOffset: Int
    }
    
    private struct InAppPurchaseRecord {
        var productID: String?
        var purchaseDate: Date?
        var expirationDate: Date?
        var isCancelled: Bool = false
    }
    
    /// 读取单个 ASN.1 DER/BER TLV 节点（带严格边界检查，支持定长与 BER 不定长 0x80 容器）
    private func readASN1TLV(in bytes: [UInt8], at offset: Int, limit: Int) -> ASN1TLV? {
        guard offset >= 0, offset + 2 <= limit else { return nil }
        let tag = bytes[offset]
        let isConstructed = (tag & 0x20) != 0
        var idx = offset + 1
        
        // 处理高标签号形式 (High-tag-number form: 低 5 位全 1)
        if (tag & 0x1F) == 0x1F {
            while idx < limit && (bytes[idx] & 0x80) != 0 {
                idx += 1
            }
            idx += 1
            guard idx < limit else { return nil }
        }
        
        let lenByte = bytes[idx]
        idx += 1
        
        if lenByte == 0x80 {
            // BER 不定长编码（仅允许出现在 constructed 容器中，以 0x00 0x00 结尾）
            guard isConstructed else { return nil }
            return ASN1TLV(
                tag: tag,
                isConstructed: true,
                isIndefiniteLength: true,
                valueRange: idx..<limit,
                nextOffset: limit
            )
        } else if (lenByte & 0x80) == 0 {
            let length = Int(lenByte)
            guard idx + length <= limit else { return nil }
            return ASN1TLV(
                tag: tag,
                isConstructed: isConstructed,
                isIndefiniteLength: false,
                valueRange: idx..<(idx + length),
                nextOffset: idx + length
            )
        } else {
            let octetsCount = Int(lenByte & 0x7F)
            guard octetsCount >= 1, octetsCount <= 4, idx + octetsCount <= limit else { return nil }
            var length = 0
            for i in 0..<octetsCount {
                length = (length << 8) | Int(bytes[idx + i])
            }
            idx += octetsCount
            guard length >= 0, idx + length <= limit else { return nil }
            return ASN1TLV(
                tag: tag,
                isConstructed: isConstructed,
                isIndefiniteLength: false,
                valueRange: idx..<(idx + length),
                nextOffset: idx + length
            )
        }
    }
    
    /// 判断 SEQUENCE (0x30) 是否为 Apple ReceiptAttribute 三元组: (INTEGER type, INTEGER version, OCTET STRING value)
    private func tryParseReceiptAttributeTuple(in bytes: [UInt8], range: Range<Int>) -> (attrType: Int, valueRange: Range<Int>)? {
        guard let first = readASN1TLV(in: bytes, at: range.lowerBound, limit: range.upperBound),
              first.tag == 0x02,
              first.valueRange.count >= 1, first.valueRange.count <= 4,
              let second = readASN1TLV(in: bytes, at: first.nextOffset, limit: range.upperBound),
              second.tag == 0x02,
              second.valueRange.count >= 1, second.valueRange.count <= 4,
              let third = readASN1TLV(in: bytes, at: second.nextOffset, limit: range.upperBound),
              third.tag == 0x04,
              third.nextOffset == range.upperBound else {
            return nil
        }
        var attrType = 0
        for idx in first.valueRange {
            attrType = (attrType << 8) | Int(bytes[idx])
        }
        return (attrType, third.valueRange)
    }
    
    /// 递归遍历 PKCS#7 容器与 Apple Receipt Attribute SET
    private func parseASN1ReceiptAttributes(
        in bytes: [UInt8],
        range: Range<Int>,
        depth: Int,
        onAttribute: (Int, Range<Int>) -> Void
    ) {
        guard depth <= 24 else { return }
        var offset = range.lowerBound
        let limit = range.upperBound
        
        while offset + 2 <= limit {
            // BER End-of-Contents (0x00, 0x00)
            if bytes[offset] == 0x00 && bytes[offset + 1] == 0x00 {
                offset += 2
                continue
            }
            guard let tlv = readASN1TLV(in: bytes, at: offset, limit: limit) else {
                break
            }
            if tlv.tag == 0x30, let tuple = tryParseReceiptAttributeTuple(in: bytes, range: tlv.valueRange) {
                onAttribute(tuple.attrType, tuple.valueRange)
            } else if tlv.isConstructed {
                parseASN1ReceiptAttributes(in: bytes, range: tlv.valueRange, depth: depth + 1, onAttribute: onAttribute)
            } else if tlv.tag == 0x04, tlv.valueRange.count >= 2 {
                // PKCS#7 eContent 的 OCTET STRING 内部封装了 Receipt Attribute SET (0x31) 或 SEQUENCE (0x30)
                let firstInnerByte = bytes[tlv.valueRange.lowerBound]
                if firstInnerByte == 0x31 || firstInnerByte == 0x30 || firstInnerByte == 0x04 {
                    parseASN1ReceiptAttributes(in: bytes, range: tlv.valueRange, depth: depth + 1, onAttribute: onAttribute)
                }
            }
            guard tlv.nextOffset > offset else { break }
            offset = tlv.nextOffset
        }
    }
    
    /// 解析单个 In-App Purchase Attribute (Type 17) 内部的商品 ID、购买时间、到期时间与取消状态
    private func parseInAppPurchaseRecord(in bytes: [UInt8], range: Range<Int>) -> InAppPurchaseRecord {
        var record = InAppPurchaseRecord()
        parseASN1ReceiptAttributes(in: bytes, range: range, depth: 0) { subType, subValueRange in
            switch subType {
            case 1702:
                // In-App Product Identifier
                if let pid = self.decodeASN1String(in: bytes, range: subValueRange), !pid.isEmpty {
                    record.productID = pid
                }
            case 1704:
                // Purchase Date (RFC 3339)
                if let date = self.decodeASN1Date(in: bytes, range: subValueRange) {
                    record.purchaseDate = date
                }
            case 1708:
                // Subscription Expiration Date (RFC 3339)
                if let date = self.decodeASN1Date(in: bytes, range: subValueRange) {
                    record.expirationDate = date
                }
            case 1712:
                // Cancellation Date (非空说明该笔交易已被 Apple 退款/撤销)
                if let cancelStr = self.decodeASN1String(in: bytes, range: subValueRange)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !cancelStr.isEmpty {
                    record.isCancelled = true
                }
            default:
                break
            }
        }
        return record
    }
    
    /// 从 ReceiptAttribute 的 OCTET STRING 载荷中精确解码内部 ASN.1 字符串 (UTF8String / IA5String / PrintableString / UTCTime / GeneralizedTime)
    private func decodeASN1String(in bytes: [UInt8], range: Range<Int>) -> String? {
        guard !range.isEmpty else { return nil }
        if let innerTLV = readASN1TLV(in: bytes, at: range.lowerBound, limit: range.upperBound),
           innerTLV.nextOffset == range.upperBound {
            let validStringTags: Set<UInt8> = [0x0C, 0x16, 0x13, 0x17, 0x18, 0x1A, 0x1E]
            if validStringTags.contains(innerTLV.tag) {
                let slice = Data(bytes[innerTLV.valueRange])
                return String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .ascii)
            }
        }
        return nil
    }
    
    /// 从 ASN.1 字符串载荷中解析 RFC3339 / ISO8601 / ASN.1 时间戳（支持毫秒、不同时区与多种编码标签）
    private func decodeASN1Date(in bytes: [UInt8], range: Range<Int>) -> Date? {
        guard let rawString = decodeASN1String(in: bytes, range: range)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawString.isEmpty else {
            return nil
        }
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFractional.date(from: rawString) {
            return date
        }
        let isoStandard = ISO8601DateFormatter()
        isoStandard.formatOptions = [.withInternetDateTime]
        if let date = isoStandard.date(from: rawString) {
            return date
        }
        let fallbackFormats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss VV",
            "yyyyMMddHHmmss'Z'",
            "yyMMddHHmmss'Z'"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for fmt in fallbackFormats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: rawString) {
                return date
            }
        }
        return nil
    }
    
    /// 根据已通过本地校验的 App Store 收据恢复或修正本地权益并更新防篡改签名
    private func reconcileEntitlementsWithReceipt(_ receipt: ReceiptValidationResult) {
        guard receipt.isTrusted else { return }
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        
        let defaults = UserDefaults.standard
        var didChange = false
        
        // 1. 终身买断版对齐：收据存在有效终身商品且未退款则点亮；若收据可信但不含终身商品（已退款/未购），则立即收回
        let hasLifetimeInReceipt = receipt.purchasedProductIDs.contains(IAPProductID.proLifetime.rawValue)
        if hasLifetimeInReceipt {
            if !defaults.bool(forKey: kIsLifetime) || !defaults.bool(forKey: kIsVIP) {
                defaults.set(true, forKey: kIsLifetime)
                defaults.set(true, forKey: kIsVIP)
                didChange = true
            }
        } else if defaults.bool(forKey: kIsLifetime) {
            // 收据经过密码学校验完全可信，但有效商品中不含终身版（说明被退款/撤销，或未购买）
            defaults.set(false, forKey: kIsLifetime)
            didChange = true
        }
        
        // 2. 年度订阅会员对齐：收据存在有效年度交易且未退款，比对并延展到期日；若已退款且无终身版，则立即收回 VIP
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
            // 收据中既无终身版，也无有效年度订阅（已被苹果退款/撤回）：立即收回 VIP
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
    
    /// 校验 UserDefaults 中的权益是否经过合法签名或具备有效本地收据背书；若检测到篡改则拒绝并回滚
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
        
        // 若未找到签名或签名不匹配（如版本升级首次运行或外部篡改 plist）：
        // 检查本地是否存在合法的 App Store 签名收据或已完成交易记录进行背书
        let receipt = verifyReceipt()
        let processedIDs = defaults.stringArray(forKey: kProcessedTransactionIDs) ?? []
        if receipt.isTrusted && !receipt.purchasedProductIDs.isEmpty {
            // 仅保留收据确认过的非消耗型/订阅权益并重新加签
            let allowLifetime = receipt.purchasedProductIDs.contains(IAPProductID.proLifetime.rawValue)
            let allowYearly = receipt.purchasedProductIDs.contains(IAPProductID.vipYearly.rawValue)
            defaults.set(allowLifetime, forKey: kIsLifetime)
            defaults.set(allowLifetime || allowYearly, forKey: kIsVIP)
            if !receipt.purchasedProductIDs.contains(IAPProductID.floorplanSingle.rawValue) && processedIDs.isEmpty {
                defaults.set(0, forKey: kFloorplanCredits)
            }
            if !receipt.purchasedProductIDs.contains(IAPProductID.tianjiSingle.rawValue) && processedIDs.isEmpty {
                defaults.set(0, forKey: kTianjiCredits)
            }
            updateEntitlementSealLocked()
            return allowLifetime || allowYearly || !processedIDs.isEmpty
        } else if !processedIDs.isEmpty, receipt.isTrusted {
            // 兼容已有合法 StoreKit 交易 ID 记录的版本升级或签名格式演进：
            // 必须同时满足本地收据通过 Apple 签名验证（isTrusted 含证书链+数字签名）。
            // 若全部非消耗型/订阅商品均已被 Apple 退款撤回（purchasedProductIDs 为空），
            // 则严禁保留终身版与 VIP 权益，必须清除已退款的伪造/陈旧 VIP 状态。
            var didClear = false
            if defaults.bool(forKey: kIsLifetime) {
                defaults.set(false, forKey: kIsLifetime)
                didClear = true
            }
            if defaults.bool(forKey: kIsVIP) {
                defaults.set(false, forKey: kIsVIP)
                defaults.set(0.0, forKey: kVIPExpireDate)
                didClear = true
            }
            if didClear {
                defaults.synchronize()
            }
            updateEntitlementSealLocked()
            return !processedIDs.isEmpty
        }
        
        // 判定为无收据、无合法交易签名的 UserDefaults 本地篡改：立即清除伪造权益
        defaults.set(false, forKey: kIsVIP)
        defaults.set(false, forKey: kIsLifetime)
        defaults.set(0.0, forKey: kVIPExpireDate)
        defaults.set(0, forKey: kFloorplanCredits)
        defaults.set(0, forKey: kTianjiCredits)
        updateEntitlementSealLocked()
        return false
    }
}
