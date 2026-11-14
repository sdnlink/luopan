import UIKit
import WidgetKit
import Combine
import CoreSpotlight

public enum AnalysisFeature: String, CaseIterable, Identifiable, Hashable {
    case xuanKong, baZhai, sanHe, owner, dates, purpleWhite, qimen
    public var id: String { rawValue }
    var requiresVIP: Bool { self == .owner || self == .sanHe }
    var legacySubTab: Int? {
        switch self {
        case .xuanKong: return 0
        case .baZhai, .sanHe: return 1
        case .purpleWhite: return 2
        case .qimen: return 3
        case .owner, .dates: return nil
        }
    }
    static func fromLegacySubTab(_ index: Int) -> AnalysisFeature? {
        let features: [AnalysisFeature] = [.xuanKong, .baZhai, .purpleWhite, .qimen]
        return features.indices.contains(index) ? features[index] : nil
    }
    var titleKey: String {
        switch self {
        case .xuanKong: return "xuankong_stars"
        case .baZhai: return "bazhai_tab_title"
        case .sanHe: return "sanhe_tab_title"
        case .owner: return "bz_tool_owner"
        case .dates: return "bz_tool_dates"
        case .purpleWhite: return "purple_white"
        case .qimen: return "qimen_dunjia"
        }
    }
    var subtitleKey: String {
        switch self {
        case .xuanKong: return "analysis_xk_hint"
        case .baZhai: return "analysis_bz_hint"
        case .sanHe: return "analysis_water_hint"
        case .owner: return "bz_tool_owner_hint"
        case .dates: return "bz_tool_dates_hint"
        case .purpleWhite: return "analysis_pw_hint"
        case .qimen: return "analysis_qimen_hint"
        }
    }
    var symbol: String {
        switch self {
        case .xuanKong: return "square.grid.3x3.fill"
        case .baZhai: return "house.fill"
        case .sanHe: return "water.waves"
        case .owner: return "person.2.fill"
        case .dates: return "calendar.badge.clock"
        case .purpleWhite: return "sparkles"
        case .qimen: return "safari"
        }
    }
}

public struct AnalysisFeatureRequest: Identifiable {
    public let id = UUID()
    public let feature: AnalysisFeature
    public init(feature: AnalysisFeature) { self.feature = feature }
}

/// 小组件深链与主屏快捷指令（Quick Actions / Spotlight）的待处理路由。
/// 不能用 NotificationCenter 直接投递：冷启动时 SceneDelegate 同步发通知，
/// SwiftUI 视图树尚未挂载，.onReceive 订阅者还不存在，通知会被静默吞掉。
/// 改为把「意图」留在单例状态里，由 RootContentView 挂载后主动消费。
public final class AppNavigationRouter: ObservableObject {
    public static let shared = AppNavigationRouter()

    @Published public private(set) var pendingAlmanacRoute = false
    @Published public private(set) var pendingTabRoute: (tab: Int, subTab: Int?, openDailyCard: Bool, feature: AnalysisFeature?)? = nil

    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    public func requestAlmanac() {
        pendingAlmanacRoute = true
        notificationCenter.post(name: .didRequestAppNavigation, object: self)
    }

    public func requestRoute(tab: Int, subTab: Int? = nil, openDailyCard: Bool = false, feature: AnalysisFeature? = nil) {
        pendingTabRoute = (tab: tab, subTab: subTab, openDailyCard: openDailyCard, feature: feature)
        notificationCenter.post(name: .didRequestAppNavigation, object: self)
    }

    /// 幂等消费：只有第一个消费者拿到 true，避免冷/热启动两条路径重复跳转。
    public func consumeAlmanac() -> Bool {
        guard pendingAlmanacRoute else { return false }
        pendingAlmanacRoute = false
        return true
    }

    public func consumeTabRoute() -> (tab: Int, subTab: Int?, openDailyCard: Bool, feature: AnalysisFeature?)? {
        guard let route = pendingTabRoute else { return nil }
        pendingTabRoute = nil
        return route
    }
}

extension Notification.Name {
    public static let didRequestAppNavigation = Notification.Name("com.yanxiang.compass.didRequestAppNavigation")
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
        switch url.host {
        case "floorplan": AppNavigationRouter.shared.requestRoute(tab: 2)
        case "projects": AppNavigationRouter.shared.requestRoute(tab: 0)
        case "measure": AppNavigationRouter.shared.requestRoute(tab: 1)
        default: return
        }
    }

    public static func routeShortcutType(_ type: String) {
        if type == "com.yanxiang.compass.shortcut.floorplan" {
            AppNavigationRouter.shared.requestRoute(tab: 2)
        }
    }

    private static func routeUserActivity(_ activity: NSUserActivity) {
        guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              id == "spotlight.floorplan" else { return }
        AppNavigationRouter.shared.requestRoute(tab: 2)
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {
        StoreKitIAPManager.shared.refreshEntitlements()
        StoreKitIAPManager.shared.refreshProductsIfNeeded()
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
