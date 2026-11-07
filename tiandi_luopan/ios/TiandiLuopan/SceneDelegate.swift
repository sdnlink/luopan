import UIKit
import WidgetKit
import Combine

/// 小组件深链的待处理路由。
/// 不能用 NotificationCenter 直接投递：冷启动时 SceneDelegate 同步发通知，
/// SwiftUI 视图树尚未挂载，.onReceive 订阅者还不存在，通知会被静默吞掉。
/// 改为把「意图」留在单例状态里，由 RootContentView 挂载后主动消费。
public final class AppNavigationRouter: ObservableObject {
    public static let shared = AppNavigationRouter()

    @Published public private(set) var pendingAlmanacRoute = false

    private init() {}

    public func requestAlmanac() {
        pendingAlmanacRoute = true
    }

    /// 幂等消费：只有第一个消费者拿到 true，避免冷/热启动两条路径重复跳转。
    public func consumeAlmanac() -> Bool {
        guard pendingAlmanacRoute else { return false }
        pendingAlmanacRoute = false
        return true
    }
}

extension Notification.Name {
    /// 保留给已有监听方使用（热启动即时性），冷启动以 AppNavigationRouter 为准。
    public static let didTapAlmanacWidget = Notification.Name("com.yanxiang.compass.didTapAlmanacWidget")
}

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = ViewController()
        self.window = window
        window.makeKeyAndVisible()
        // 冷启动时由小组件 URL 拉起：把目标页交给 RootContentView 切换。
        if let url = connectionOptions.urlContexts.first?.url {
            Self.routeWidgetURL(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // 已运行状态下点击小组件：同样转发，避免只冷启动到首页。
        if let url = URLContexts.first?.url {
            Self.routeWidgetURL(url)
        }
    }

    /// 仅处理本 App 的日课深链，其它 scheme 忽略。
    /// 冷启动与热启动都先写入单例状态，再由 RootContentView 挂载后消费；
    /// 通知仅作热启动时的即时补充。
    private static func routeWidgetURL(_ url: URL) {
        guard url.scheme == "tiandiluopan", url.host == "almanac" else { return }
        AppNavigationRouter.shared.requestAlmanac()
        NotificationCenter.default.post(name: .didTapAlmanacWidget, object: nil)
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {
        StoreKitIAPManager.shared.refreshEntitlements()
        StoreKitIAPManager.shared.refreshProductsIfNeeded()
        CompassMotionManager.shared.resumeIfSensorsEnabled()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // 多窗口（Stage Manager / 多场景）下，一个窗口 resignActive 不代表全 App 不可见，
        // 传感器与常亮开关都是全局单例，只有最后一个活跃场景失去前台时才动，
        // 否则另一个窗口的罗盘会被误停、屏幕也会被允许自动锁屏。
        guard !isAnotherSceneActive(excluding: scene) else { return }
        UIApplication.shared.isIdleTimerDisabled = false
        CompassMotionManager.shared.stop()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        CompassMotionManager.shared.resumeIfSensorsEnabled()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        guard !isAnotherSceneActive(excluding: scene) else { return }
        UIApplication.shared.isIdleTimerDisabled = false
        CompassMotionManager.shared.stop()
        // 跨日 / 节气交接后回到前台时，让小组件重建 Timeline。
        WidgetCenter.shared.reloadTimelines(ofKind: "TiandiLuopanAlmanacWidget")
    }

    /// 是否还有别的场景处于前台活跃状态。
    private func isAnotherSceneActive(excluding scene: UIScene) -> Bool {
        UIApplication.shared.connectedScenes.contains { other in
            other !== scene && other.activationState == .foregroundActive
        }
    }
}
