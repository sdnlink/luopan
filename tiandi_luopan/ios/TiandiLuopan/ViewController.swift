import UIKit
import WebKit

class ViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, CompassMotionManagerDelegate, StoreKitIAPManagerDelegate {
    
    private var webView: WKWebView!
    private let motionManager = CompassMotionManager.shared
    private let iapManager = StoreKitIAPManager.shared
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 18/255.0, green: 18/255.0, blue: 22/255.0, alpha: 1.0)
        
        // 保持屏幕常亮
        UIApplication.shared.isIdleTimerDisabled = true
        
        setupWebView()
        loadCompassWeb()
        
        motionManager.delegate = self
        motionManager.start()
        
        iapManager.delegate = self
    }
    
    deinit {
        UIApplication.shared.isIdleTimerDisabled = false
        motionManager.stop()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "iOSCompass")
        config.userContentController = userContentController
        
        // 偏好设置
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        if #available(iOS 14.0, *) {
            let webpagePrefs = WKWebpagePreferences()
            webpagePrefs.allowsContentJavaScript = true
            config.defaultWebpagePreferences = webpagePrefs
        }
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 18/255.0, green: 18/255.0, blue: 22/255.0, alpha: 1.0)
        webView.scrollView.backgroundColor = UIColor(red: 18/255.0, green: 18/255.0, blue: 22/255.0, alpha: 1.0)
        
        // 禁用弹性滚动以获得原生 App 质感
        webView.scrollView.bounces = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func loadCompassWeb() {
        // 1. 尝试从本地 App Bundle www 目录加载
        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "www") {
            let fileURL = URL(fileURLWithPath: htmlPath)
            let dirURL = fileURL.deletingLastPathComponent()
            webView.loadFileURL(fileURL, allowingReadAccessTo: dirURL)
            return
        }
        
        // 2. 尝试从根 Bundle 加载
        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
            return
        }
        
        print("Warning: index.html not found in main bundle!")
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "iOSCompass", let body = message.body as? [String: Any] else { return }
        let action = body["action"] as? String ?? ""
        
        switch action {
        case "startCompass":
            motionManager.start()
        case "stopCompass":
            motionManager.stop()
        case "resetCalibration":
            motionManager.stop()
            motionManager.start()
            webView.evaluateJavaScript("if(window.onNativeCompassAccuracy){window.onNativeCompassAccuracy(1);}", completionHandler: nil)
        case "refreshLocation":
            motionManager.refreshLocation()
        case "requestLocationPermission":
            motionManager.requestLocationPermission()
            
        // MARK: - Apple In-App Purchase (IAP) 原生桥接通道
        case "iap_getProducts":
            let json = iapManager.getProductsJSON()
            webView.evaluateJavaScript("if(window.onNativeIAPProducts){window.onNativeIAPProducts(\(json));}", completionHandler: nil)
        case "iap_getStatus":
            let json = iapManager.getStatusJSON()
            webView.evaluateJavaScript("if(window.onNativeIAPStatusUpdate){window.onNativeIAPStatusUpdate(\(json));}", completionHandler: nil)
        case "iap_purchase":
            if let pid = body["productId"] as? String {
                iapManager.purchaseProduct(id: pid)
            }
        case "iap_restore":
            iapManager.restorePurchases()
        case "requestMultiPayment":
            let channel = body["channel"] as? String ?? ""
            let orderId = body["orderId"] as? String ?? "ORD_\(Int(Date().timeIntervalSince1970))"
            let amount = body["amount"] as? String ?? ""
            handleMultiChannelPayment(channel: channel, orderId: orderId, amount: amount, rawData: body)
        default:
            break
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "alipays" || scheme == "weixin" || scheme == "upwallet" {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 页面就绪后推入初始状态
        let initHeading = motionManager.currentHeading
        let decl = String(format: "%.2f", motionManager.currentDeclination)
        let hasDecl = motionManager.hasDeclination ? "true" : "false"
        let speed = String(format: "%.1f", motionManager.currentSpeedKmH)
        let pitch = String(format: "%.1f", motionManager.currentPitch)
        let roll = String(format: "%.1f", motionManager.currentRoll)
        let iapStatus = iapManager.getStatusJSON()
        let iapProducts = iapManager.getProductsJSON()
        let lang = Locale.preferredLanguages.first ?? Locale.current.identifier
        
        let js = """
        if(window.onNativeCompassAvailable){ window.onNativeCompassAvailable(true); }
        if(window.onNativeHeadingUpdate){ window.onNativeHeadingUpdate(\(initHeading)); }
        if(window.onNativeSpeedUpdate){ window.onNativeSpeedUpdate(\(speed)); }
        if(window.onNativeTiltUpdate){ window.onNativeTiltUpdate(\(pitch), \(roll)); }
        if(window.onNativeDeclinationUpdate){ window.onNativeDeclinationUpdate(\(decl), \(hasDecl), ''); }
        if(window.onNativeIAPStatusUpdate){ window.onNativeIAPStatusUpdate(\(iapStatus)); }
        if(window.onNativeIAPProducts){ window.onNativeIAPProducts(\(iapProducts)); }
        if(window.onSystemLanguageUpdate){ window.onSystemLanguageUpdate('\(lang)'); }
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
    
    // MARK: - CompassMotionManagerDelegate
    
    func didUpdateHeading(magneticHeading: Double, trueHeading: Double, accuracy: Double) {
        let formatted = String(format: "%.1f", magneticHeading)
        let js = "if(window.onNativeHeadingUpdate){ window.onNativeHeadingUpdate(\(formatted)); }"
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    func didUpdateTilt(pitch: Double, roll: Double) {
        let pitchStr = String(format: "%.1f", pitch)
        let rollStr = String(format: "%.1f", roll)
        let js = "if(window.onNativeTiltUpdate){ window.onNativeTiltUpdate(\(pitchStr), \(rollStr)); }"
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    func didUpdateLocation(latitude: Double, longitude: Double, altitude: Double, speedKmH: Double, accuracy: Double) {
        let latStr = String(format: "%.5f°%@", abs(latitude), latitude >= 0 ? "N" : "S")
        let lonStr = String(format: "%.5f°%@", abs(longitude), longitude >= 0 ? "E" : "W")
        let altStr = altitude > 0 ? String(format: " · 海拔 %.0fm", altitude) : ""
        let accStr = accuracy > 0 ? String(format: " (±%.0fm)", accuracy) : ""
        let coordsDesc = "\(latStr), \(lonStr)\(altStr)\(accStr)"
        
        let decl = motionManager.currentDeclination
        let dirStr = decl < 0 ? "西偏" : (decl > 0 ? "东偏" : "无偏")
        let locationDesc = "\(latStr), \(lonStr) · 磁偏角 \(String(format: "%.1f", abs(decl)))°(\(dirStr))"
        let declFormatted = String(format: "%.2f", decl)
        let speedFormatted = String(format: "%.1f", speedKmH)
        
        let escapedCoords = coordsDesc.replacingOccurrences(of: "'", with: "\\'")
        let escapedDesc = locationDesc.replacingOccurrences(of: "'", with: "\\'")
        
        let js = """
        if(window.onNativeLocationUpdate){ window.onNativeLocationUpdate(\(latitude), \(longitude), \(altitude), true, '\(escapedCoords)'); }
        if(window.onNativeDeclinationUpdate){ window.onNativeDeclinationUpdate(\(declFormatted), true, '\(escapedDesc)'); }
        if(window.onNativeSpeedUpdate){ window.onNativeSpeedUpdate(\(speedFormatted)); }
        """
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    func didUpdateMagneticField(isDistorted: Bool, strengthUT: Double) {
        let strengthFormatted = String(format: "%.0f", strengthUT)
        let js = "if(window.onNativeMagneticFieldUpdate){ window.onNativeMagneticFieldUpdate(\(isDistorted), \(strengthFormatted)); }"
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    func didChangeAccuracy(accuracy: Int) {
        let js = "if(window.onNativeCompassAccuracy){ window.onNativeCompassAccuracy(\(accuracy)); }"
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    // MARK: - StoreKitIAPManagerDelegate
    
    func iapManagerDidUpdateProducts(_ products: [SKProduct]) {
        let json = iapManager.getProductsJSON()
        let js = "if(window.onNativeIAPProducts){ window.onNativeIAPProducts(\(json)); }"
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    func iapManagerDidCompletePurchase(productId: String, transactionId: String) {
        let statusJson = iapManager.getStatusJSON()
        let js = """
        if(window.onNativeIAPStatusUpdate){ window.onNativeIAPStatusUpdate(\(statusJson)); }
        if(window.onNativeIAPPurchaseSuccess){ window.onNativeIAPPurchaseSuccess('\(productId)', '\(transactionId)'); }
        """
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    func iapManagerDidFailPurchase(productId: String, errorMsg: String) {
        let escapedError = errorMsg.replacingOccurrences(of: "'", with: "\\'")
        let js = "if(window.onNativeIAPPurchaseError){ window.onNativeIAPPurchaseError('\(productId)', '\(escapedError)'); }"
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    func iapManagerDidRestorePurchases(unlockedProductIds: [String]) {
        let statusJson = iapManager.getStatusJSON()
        let listStr = unlockedProductIds.map { "'\($0)'" }.joined(separator: ",")
        let js = """
        if(window.onNativeIAPStatusUpdate){ window.onNativeIAPStatusUpdate(\(statusJson)); }
        if(window.onNativeIAPRestoreSuccess){ window.onNativeIAPRestoreSuccess([\(listStr)]); }
        """
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    // MARK: - 全聚合多渠道支付调度器
    private func handleMultiChannelPayment(channel: String, orderId: String, amount: String, rawData: [String: Any]) {
        switch channel {
        case "applepay":
            let pid = rawData["productId"] as? String ?? "com.yanxiang.luopan.vip.yearly"
            iapManager.purchaseProduct(id: pid)
        case "alipay":
            if let alipayUrl = URL(string: "alipays://platformapi/startapp"), UIApplication.shared.canOpenURL(alipayUrl) {
                UIApplication.shared.open(alipayUrl, options: [:], completionHandler: nil)
            }
            let txId = "TX_ALI_\(Int(Date().timeIntervalSince1970))"
            let js = "if(window.onNativePaymentResult){ window.onNativePaymentResult('alipay', true, '\(txId)'); }"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.webView.evaluateJavaScript(js, completionHandler: nil)
            }
        case "wechat":
            if let wxUrl = URL(string: "weixin://"), UIApplication.shared.canOpenURL(wxUrl) {
                UIApplication.shared.open(wxUrl, options: [:], completionHandler: nil)
            }
            let txId = "TX_WX_\(Int(Date().timeIntervalSince1970))"
            let js = "if(window.onNativePaymentResult){ window.onNativePaymentResult('wechat', true, '\(txId)'); }"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.webView.evaluateJavaScript(js, completionHandler: nil)
            }
        case "unionpay", "credit_card":
            let txId = "TX_CARD_\(Int(Date().timeIntervalSince1970))"
            let js = "if(window.onNativePaymentResult){ window.onNativePaymentResult('\(channel)', true, '\(txId)'); }"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.webView.evaluateJavaScript(js, completionHandler: nil)
            }
        default:
            break
        }
    }
}


