import Foundation
import StoreKit
import Combine

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
    
    private var productsRequest: SKProductsRequest?
    private var availableProducts: [String: SKProduct] = [:]
    private let entitlementLock = NSLock()
    
    // 本地持久化权益 Keys
    private let kIsVIP = "yx_iap_is_vip"
    private let kIsLifetime = "yx_iap_is_lifetime"
    private let kVIPExpireDate = "yx_iap_vip_expire_date"
    private let kFloorplanCredits = "yx_iap_floorplan_credits"
    private let kTianjiCredits = "yx_iap_tianji_credits"
    private let kProcessedTransactionIDs = "yx_iap_processed_transaction_ids"
    
    private override init() {
        super.init()
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
        isLoadingProducts = true
        let productIdentifiers = Set(IAPProductID.allCases.map { $0.rawValue })
        productsRequest?.cancel()
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
    }
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.productsRequest(request, didReceive: response)
            }
            return
        }
        guard let activeRequest = productsRequest, request === activeRequest else { return }
        isLoadingProducts = false
        productsRequest = nil
        availableProducts.removeAll()
        for product in response.products {
            availableProducts[product.productIdentifier] = product
        }
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
        SKPaymentQueue.default().restoreCompletedTransactions()
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
        var unlocked: [String] = []
        if isVIP() { unlocked.append(IAPProductID.vipYearly.rawValue) }
        if isLifetime() { unlocked.append(IAPProductID.proLifetime.rawValue) }
        
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
                return true
            }
            if Date().timeIntervalSince1970 < expire {
                return true
            }
            defaults.set(false, forKey: kIsVIP)
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
        return UserDefaults.standard.bool(forKey: kIsLifetime)
    }
    
    public func floorplanCredits() -> Int {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
        return UserDefaults.standard.integer(forKey: kFloorplanCredits)
    }
    
    public func tianjiCredits() -> Int {
        entitlementLock.lock()
        defer { entitlementLock.unlock() }
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
}
