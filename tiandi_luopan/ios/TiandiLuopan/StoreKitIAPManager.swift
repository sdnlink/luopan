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
        case .vipYearly: return "演象·年度堪舆会员 (连续包年)"
        case .proLifetime: return "演象·大师终身专业版"
        case .floorplanSingle: return "户型空间立极·全屋风水体检"
        case .tianjiSingle: return "福宅天机堪舆全案宣纸长图"
        }
    }
    
    var priceText: String {
        switch self {
        case .vipYearly: return "¥198/年"
        case .proLifetime: return "¥298"
        case .floorplanSingle: return "¥19.9"
        case .tianjiSingle: return "¥9.9"
        }
    }
    
    var desc: String {
        switch self {
        case .vipYearly: return "全量解锁四大场景全息交互、奇门全息排盘、流年紫白布防、八煞黄泉及天机长图无限次导出"
        case .proLifetime: return "一次付费，终身永久享受演象时空罗盘所有专业特权与未来更新"
        case .floorplanSingle: return "解锁单套户型几何立极、大门灶卫明财文昌位吉凶深度诊断报告"
        case .tianjiSingle: return "单次导出高精度无水印古典宣纸朱丝栏勘测长卷"
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
            delegate?.iapManagerDidFailPurchase(productId: id, errorMsg: "设备当前受家长控制或系统限制，无法完成应用内购买。")
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
            self?.delegate?.iapManagerDidFailPurchase(productId: "", errorMsg: "恢复购买失败: \(error.localizedDescription)")
        }
    }
    
    private func handleFailed(_ transaction: SKPaymentTransaction) {
        let pid = transaction.payment.productIdentifier
        var errorMsg = "购买已取消或发生未知错误"
        if let err = transaction.error as? SKError {
            switch err.code {
            case .paymentCancelled:
                errorMsg = "用户已取消支付"
            case .paymentNotAllowed:
                errorMsg = "该 Apple ID 不允许进行应用内购买"
            case .paymentInvalid:
                errorMsg = "支付凭证无效，请检查付款方式"
            case .clientInvalid:
                errorMsg = "客户端无权发起支付"
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
