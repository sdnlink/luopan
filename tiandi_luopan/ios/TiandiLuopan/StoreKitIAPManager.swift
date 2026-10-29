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
    
    public var isTrusted: Bool {
        return isValidContainer && bundleIDMatched
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
        // Read the persisted expiry on every entitlement check. The app can
        // remain in the foreground past an annual expiry, so relying only on
        // the last published Boolean would keep premium screens unlocked
        // until the next scene activation.
        return isLifetimeUser || isVIP()
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
    private let kProcessedTransactionIDs = "yx_iap_processed_transaction_ids"
    private let kEntitlementSeal = "yx_iap_entitlement_hmac_seal"
    private let kKeychainSealAccount = "com.yanxiang.luopan.iap.seal.key"
    
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
    
    /// 读取并校验 Bundle.main.appStoreReceiptURL 本地收据容器、BundleID 与内购商品载荷
    public func verifyReceipt() -> ReceiptValidationResult {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path),
              let receiptData = try? Data(contentsOf: receiptURL),
              receiptData.count > 64 else {
            return ReceiptValidationResult(
                isValidContainer: false,
                bundleIDMatched: false,
                purchasedProductIDs: [],
                latestExpirationDate: nil,
                receiptSHA256: ""
            )
        }
        
        let digest = SHA256.hash(data: receiptData)
        let sha256Hex = digest.map { String(format: "%02x", $0) }.joined()
        
        // 1. 校验 PKCS#7 / ASN.1 DER 外层 SEQUENCE (0x30) 及 signedData OID (1.2.840.113549.1.7.2)
        let pkcs7SignedDataOID = Data([0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x02])
        let isASN1Sequence = receiptData.first == 0x30
        let hasSignedDataOID = receiptData.range(of: pkcs7SignedDataOID) != nil
        let isValidContainer = isASN1Sequence && hasSignedDataOID
        
        // 2. 校验收据内嵌 Bundle Identifier (防止跨包移植其它 App 的收据文件)
        let expectedBundleID = Bundle.main.bundleIdentifier ?? "com.yanxiang.luopan"
        let bundleIDMatched: Bool
        if let bundleBytes = expectedBundleID.data(using: .utf8),
           receiptData.range(of: bundleBytes) != nil {
            bundleIDMatched = true
        } else if let fallbackBytes = "com.yanxiang.luopan".data(using: .utf8),
                  receiptData.range(of: fallbackBytes) != nil {
            bundleIDMatched = true
        } else {
            bundleIDMatched = false
        }
        
        // 3. 解析收据内包含的内购商品标识与订阅到期时间 (ASN.1 IA5String RFC3339 时间戳)
        var purchasedIDs = Set<String>()
        for item in IAPProductID.allCases {
            if let pidBytes = item.rawValue.data(using: .utf8),
               receiptData.range(of: pidBytes) != nil {
                purchasedIDs.insert(item.rawValue)
            }
        }
        
        let latestExpiry = extractLatestReceiptExpiryDate(from: receiptData)
        return ReceiptValidationResult(
            isValidContainer: isValidContainer,
            bundleIDMatched: bundleIDMatched,
            purchasedProductIDs: purchasedIDs,
            latestExpirationDate: latestExpiry,
            receiptSHA256: sha256Hex
        )
    }
    
    /// 从 ASN.1 IA5String (Tag 0x16) 载荷中提取收据内的最新 RFC3339 订阅到期时间
    private func extractLatestReceiptExpiryDate(from data: Data) -> Date? {
        let bytes = [UInt8](data)
        let count = bytes.count
        guard count > 32 else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        var dates: [Date] = []
        var idx = 0
        while idx < count - 22 {
            // ASN.1 IA5String tag = 0x16, 典型 RFC3339 长度 20..30 字节 (例如 "2027-10-29T12:00:00Z")
            if bytes[idx] == 0x16 {
                let len = Int(bytes[idx + 1])
                if len >= 19 && len <= 32 && (idx + 2 + len) <= count {
                    let slice = Data(bytes[(idx + 2)..<(idx + 2 + len)])
                    if let str = String(data: slice, encoding: .ascii),
                       str.contains("T"), str.hasSuffix("Z"),
                       let parsed = isoFormatter.date(from: str) {
                        dates.append(parsed)
                        idx += 2 + len
                        continue
                    }
                }
            }
            idx += 1
        }
        return dates.max()
    }
    
    /// 根据已通过本地校验的 App Store 收据恢复或修正本地权益并更新防篡改签名
    private func reconcileEntitlementsWithReceipt(_ receipt: ReceiptValidationResult) {
        guard receipt.isTrusted else { return }
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        
        let defaults = UserDefaults.standard
        var didChange = false
        
        if receipt.purchasedProductIDs.contains(IAPProductID.proLifetime.rawValue) {
            if !defaults.bool(forKey: kIsLifetime) || !defaults.bool(forKey: kIsVIP) {
                defaults.set(true, forKey: kIsLifetime)
                defaults.set(true, forKey: kIsVIP)
                didChange = true
            }
        }
        
        if receipt.purchasedProductIDs.contains(IAPProductID.vipYearly.rawValue) {
            let currentExpiry = defaults.double(forKey: kVIPExpireDate)
            if let receiptExpiry = receipt.latestExpirationDate?.timeIntervalSince1970, receiptExpiry > currentExpiry {
                defaults.set(receiptExpiry, forKey: kVIPExpireDate)
                defaults.set(receiptExpiry > Date().timeIntervalSince1970, forKey: kIsVIP)
                didChange = true
            } else if currentExpiry > Date().timeIntervalSince1970 && !defaults.bool(forKey: kIsVIP) {
                defaults.set(true, forKey: kIsVIP)
                didChange = true
            }
        }
        
        if didChange {
            updateEntitlementSealLocked()
            defaults.synchronize()
        }
    }
    
    /// 获取或生成保存在 Keychain 中的设备级 256-bit HMAC 密钥
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
        
        var randomBytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let vendorSalt = UIDevice.current.identifierForVendor?.uuidString ?? "com.yanxiang.luopan.device"
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
            if ! receipt.purchasedProductIDs.contains(IAPProductID.floorplanSingle.rawValue) {
                defaults.set(0, forKey: kFloorplanCredits)
            }
            if ! receipt.purchasedProductIDs.contains(IAPProductID.tianjiSingle.rawValue) {
                defaults.set(0, forKey: kTianjiCredits)
            }
            updateEntitlementSealLocked()
            return allowLifetime || allowYearly
        } else if !processedIDs.isEmpty && defaults.string(forKey: kEntitlementSeal) == nil {
            // 兼容已有合法交易 ID 列表的旧版升级迁移（首次生成防篡改签名）
            updateEntitlementSealLocked()
            return true
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
