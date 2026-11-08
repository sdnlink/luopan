import UIKit
import WidgetKit
import Combine
import CoreSpotlight

/// 小组件深链与主屏快捷指令（Quick Actions / Spotlight）的待处理路由。
/// 不能用 NotificationCenter 直接投递：冷启动时 SceneDelegate 同步发通知，
/// SwiftUI 视图树尚未挂载，.onReceive 订阅者还不存在，通知会被静默吞掉。
/// 改为把「意图」留在单例状态里，由 RootContentView 挂载后主动消费。
public final class AppNavigationRouter: ObservableObject {
    public static let shared = AppNavigationRouter()

    @Published public private(set) var pendingAlmanacRoute = false
    @Published public private(set) var pendingTabRoute: (tab: Int, subTab: Int?, openDailyCard: Bool)? = nil

    private init() {}

    public func requestAlmanac() {
        pendingAlmanacRoute = true
    }

    public func requestRoute(tab: Int, subTab: Int? = nil, openDailyCard: Bool = false) {
        pendingTabRoute = (tab: tab, subTab: subTab, openDailyCard: openDailyCard)
    }

    /// 幂等消费：只有第一个消费者拿到 true，避免冷/热启动两条路径重复跳转。
    public func consumeAlmanac() -> Bool {
        guard pendingAlmanacRoute else { return false }
        pendingAlmanacRoute = false
        return true
    }

    public func consumeTabRoute() -> (tab: Int, subTab: Int?, openDailyCard: Bool)? {
        guard let route = pendingTabRoute else { return nil }
        pendingTabRoute = nil
        return route
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
        if let shortcut = connectionOptions.shortcutItem {
            Self.routeShortcutType(shortcut.type)
        }
        if let activity = connectionOptions.userActivities.first {
            Self.routeUserActivity(activity)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // 已运行状态下点击小组件：同样转发，避免只冷启动到首页。
        if let url = URLContexts.first?.url {
            Self.routeWidgetURL(url)
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Self.routeShortcutType(shortcutItem.type)
        completionHandler(true)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        Self.routeUserActivity(userActivity)
    }

    /// 处理本 App 的深链（日课、罗盘财喜吉方、户型宅谱、奇门遁甲）。
    /// 冷启动与热启动都先写入单例状态，再由 RootContentView 挂载后消费；
    /// 通知仅作热启动时的即时补充。
    public static func routeWidgetURL(_ url: URL) {
        guard url.scheme == "tiandiluopan" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let sheetParam = queryItems.first(where: { $0.name == "sheet" })?.value
        let indexParam = queryItems.first(where: { $0.name == "index" })?.value
        let subParam = queryItems.first(where: { $0.name == "sub" })?.value

        switch url.host {
        case "almanac":
            AppNavigationRouter.shared.requestAlmanac()
        case "compass":
            CompassLayerManager.shared.showDailyGodMarkers = true
            let shouldOpenDailyCard = (sheetParam == "dailySign" || sheetParam == "dailyCard")
            AppNavigationRouter.shared.requestRoute(tab: 0, subTab: nil, openDailyCard: shouldOpenDailyCard)
        case "floorplan":
            AppNavigationRouter.shared.requestRoute(tab: 2, subTab: nil, openDailyCard: false)
        case "qimen":
            AppNavigationRouter.shared.requestRoute(tab: 3, subTab: 3, openDailyCard: false)
        case "tab":
            if subParam == "qimen" {
                AppNavigationRouter.shared.requestRoute(tab: 3, subTab: 3, openDailyCard: false)
            } else if indexParam == "3" {
                AppNavigationRouter.shared.requestRoute(tab: 2, subTab: nil, openDailyCard: false)
            } else if let idxStr = indexParam, let idx = Int(idxStr) {
                AppNavigationRouter.shared.requestRoute(tab: max(0, min(4, idx)), subTab: nil, openDailyCard: false)
            } else {
                return
            }
        default:
            return
        }
        NotificationCenter.default.post(name: .didTapAlmanacWidget, object: nil)
    }

    public static func routeShortcutType(_ type: String) {
        switch type {
        case "com.yanxiang.compass.shortcut.dailygods":
            CompassLayerManager.shared.showDailyGodMarkers = true
            AppNavigationRouter.shared.requestRoute(tab: 0, subTab: nil, openDailyCard: false)
        case "com.yanxiang.compass.shortcut.dailycard", "com.yanxiang.compass.shortcut.dailysign":
            CompassLayerManager.shared.showDailyGodMarkers = true
            AppNavigationRouter.shared.requestRoute(tab: 0, subTab: nil, openDailyCard: true)
        case "com.yanxiang.compass.shortcut.zeri":
            AppNavigationRouter.shared.requestAlmanac()
        case "com.yanxiang.compass.shortcut.floorplan":
            AppNavigationRouter.shared.requestRoute(tab: 2, subTab: nil, openDailyCard: false)
        case "com.yanxiang.compass.shortcut.qimen":
            AppNavigationRouter.shared.requestRoute(tab: 3, subTab: 3, openDailyCard: false)
        default:
            return
        }
        NotificationCenter.default.post(name: .didTapAlmanacWidget, object: nil)
    }

    private static func routeUserActivity(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == CSSearchableItemActionType,
              let id = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
        switch id {
        case "spotlight.zeri":
            AppNavigationRouter.shared.requestAlmanac()
        case "tiandiluopan://compass?guide=dailyGods":
            CompassLayerManager.shared.showDailyGodMarkers = true
            AppNavigationRouter.shared.requestRoute(tab: 0, subTab: nil, openDailyCard: false)
        case "tiandiluopan://compass?sheet=dailySign":
            CompassLayerManager.shared.showDailyGodMarkers = true
            AppNavigationRouter.shared.requestRoute(tab: 0, subTab: nil, openDailyCard: true)
        case "spotlight.bazhai":
            AppNavigationRouter.shared.requestRoute(tab: 3, subTab: 1, openDailyCard: false)
        case "spotlight.qimen", "tiandiluopan://tab?index=2&sub=qimen":
            AppNavigationRouter.shared.requestRoute(tab: 3, subTab: 3, openDailyCard: false)
        case "spotlight.floorplan", "tiandiluopan://tab?index=3":
            AppNavigationRouter.shared.requestRoute(tab: 2, subTab: nil, openDailyCard: false)
        default:
            return
        }
        NotificationCenter.default.post(name: .didTapAlmanacWidget, object: nil)
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {
        StoreKitIAPManager.shared.refreshEntitlements()
        StoreKitIAPManager.shared.refreshProductsIfNeeded()
        CompassMotionManager.shared.resumeIfSensorsEnabled()
        CompassMotionManager.shared.refreshTimeAndSolarTerm()
        RetentionServiceManager.shared.syncNotificationAuthorizationStatus()
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
        CompassMotionManager.shared.refreshTimeAndSolarTerm()
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
