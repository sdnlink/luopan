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
        switch self {
        case .vipYearly: return LocalizationManager.shared.t("price_vip_yearly")
        case .proLifetime: return LocalizationManager.shared.t("price_pro_lifetime")
        case .floorplanSingle: return LocalizationManager.shared.t("price_floorplan_single")
        case .tianjiSingle: return LocalizationManager.shared.t("price_tianji_single")
        }
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
    
    public var hasUnlockedVIP: Bool {
        return isVIPUser || isLifetimeUser
    }
    
    public var canUseFloorplan: Bool {
        return hasUnlockedVIP || floorplanCreditsCount > 0
    }
    
    public var canUseTianji: Bool {
        return hasUnlockedVIP || tianjiCreditsCount > 0
    }
    
    private var productsRequest: SKProductsRequest?
    private var availableProducts: [String: SKProduct] = [:]
    
    // 本地持久化权益 Keys
    private let kIsVIP = "yx_iap_is_vip"
    private let kIsLifetime = "yx_iap_is_lifetime"
    private let kVIPExpireDate = "yx_iap_vip_expire_date"
    private let kFloorplanCredits = "yx_iap_floorplan_credits"
    private let kTianjiCredits = "yx_iap_tianji_credits"
    
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
        let productIdentifiers = Set(IAPProductID.allCases.map { $0.rawValue })
        productsRequest?.cancel()
        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
    }
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
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
        print("StoreKit request products failed: \(error.localizedDescription)")
    }
    
    // MARK: - 购买商品
    
    public func purchaseProduct(id: String) {
        guard SKPaymentQueue.canMakePayments() else {
            delegate?.iapManagerDidFailPurchase(productId: id, errorMsg: LocalizationManager.shared.t("iap_err_parental_controls"))
            return
        }
        
        if let product = availableProducts[id] {
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)
        } else {
            // 如果未能从 StoreKit 缓存，尝试通过 ID 构造
            let payment = SKMutablePayment()
            payment.productIdentifier = id
            SKPaymentQueue.default().add(payment)
        }
    }
    
    // MARK: - 恢复购买 (App Store 审核必备)
    
    public func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // MARK: - SKPaymentTransactionObserver
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                handlePurchased(transaction)
            case .restored:
                handleRestored(transaction)
            case .failed:
                handleFailed(transaction)
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }
    }
    
    private func handlePurchased(_ transaction: SKPaymentTransaction) {
        let pid = transaction.payment.productIdentifier
        unlockEntitlement(for: pid)
        SKPaymentQueue.default().finishTransaction(transaction)
        
        let txId = transaction.transactionIdentifier ?? UUID().uuidString
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.iapManagerDidCompletePurchase(productId: pid, transactionId: txId)
        }
    }
    
    private func handleRestored(_ transaction: SKPaymentTransaction) {
        let pid = transaction.payment.productIdentifier
        unlockEntitlement(for: pid)
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        var unlocked: [String] = []
        if isVIP() { unlocked.append(IAPProductID.vipYearly.rawValue) }
        if isLifetime() { unlocked.append(IAPProductID.proLifetime.rawValue) }
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.iapManagerDidRestorePurchases(unlockedProductIds: unlocked)
        }
    }
    
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
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
            self?.delegate?.iapManagerDidFailPurchase(productId: pid, errorMsg: errorMsg)
        }
    }
    
    // MARK: - 权益本地管理
    
    private func unlockEntitlement(for pid: String) {
        let defaults = UserDefaults.standard
        if pid == IAPProductID.proLifetime.rawValue {
            defaults.set(true, forKey: kIsLifetime)
            defaults.set(true, forKey: kIsVIP)
        } else if pid == IAPProductID.vipYearly.rawValue {
            defaults.set(true, forKey: kIsVIP)
            let oneYearLater = Date().addingTimeInterval(365 * 24 * 3600)
            defaults.set(oneYearLater.timeIntervalSince1970, forKey: kVIPExpireDate)
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
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: kIsLifetime) { return true }
        if defaults.bool(forKey: kIsVIP) {
            let expire = defaults.double(forKey: kVIPExpireDate)
            if expire == 0 || Date().timeIntervalSince1970 < expire {
                return true
            }
        }
        return false
    }
    
    public func isLifetime() -> Bool {
        return UserDefaults.standard.bool(forKey: kIsLifetime)
    }
    
    public func floorplanCredits() -> Int {
        return UserDefaults.standard.integer(forKey: kFloorplanCredits)
    }
    
    public func tianjiCredits() -> Int {
        return UserDefaults.standard.integer(forKey: kTianjiCredits)
    }
    
    public func consumeFloorplanCredit() -> Bool {
        if isVIP() { return true }
        let credits = floorplanCredits()
        if credits > 0 {
            let remain = credits - 1
            UserDefaults.standard.set(remain, forKey: kFloorplanCredits)
            UserDefaults.standard.synchronize()
            DispatchQueue.main.async { [weak self] in
                self?.floorplanCreditsCount = remain
            }
            return true
        }
        return false
    }
    
    public func consumeTianjiCredit() -> Bool {
        if isVIP() { return true }
        let credits = tianjiCredits()
        if credits > 0 {
            let remain = credits - 1
            UserDefaults.standard.set(remain, forKey: kTianjiCredits)
            UserDefaults.standard.synchronize()
            DispatchQueue.main.async { [weak self] in
                self?.tianjiCreditsCount = remain
            }
            return true
        }
        return false
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
            var price = item.priceText
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
