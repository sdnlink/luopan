import UIKit

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
    }

    /// 是否还有别的场景处于前台活跃状态。
    private func isAnotherSceneActive(excluding scene: UIScene) -> Bool {
        UIApplication.shared.connectedScenes.contains { other in
            other !== scene && other.activationState == .foregroundActive
        }
    }
}
