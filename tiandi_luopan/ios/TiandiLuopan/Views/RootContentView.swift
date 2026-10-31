import SwiftUI
import UIKit

// MARK: - iOS 14.0 颜色向下兼容扩展
extension Color {
    public static let yanCyan = Color(red: 0.0, green: 0.82, blue: 0.95)
    public static let yanBrown = Color(red: 0.65, green: 0.45, blue: 0.25)
}

// MARK: - iPad 与多设备全景屏幕字体自适应扩展 (Adaptive Typography)
extension Font {
    /// 全景自适应计算最优字体字号：
    /// 在 iPhone 上保持设计原始字号，在 iPad Pro / iPad Air / iPad mini 大屏上自动按 1.35x 比例智能放大，
    /// 确保罗盘刻度、度数、八方吉凶、户型体检、九宫飞星、系统设置等所有界面的文本层次均清晰可辨。
    public static func adaptive(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let scale: CGFloat = isPad ? 1.35 : 1.0
        let scaledSize = (size * scale).rounded()
        return Font.system(size: scaledSize, weight: weight, design: design)
    }

    public static func adaptive(size: CGFloat, design: Font.Design) -> Font {
        adaptive(size: size, weight: .regular, design: design)
    }
}


// MARK: - 天机演象 纯原生 SwiftUI 根视图 (Root Content View - PRD 5.0 标准五大场景)

public struct RootContentView: View {
    private let motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var selectedTab: Int
    
    public init() {
        var initialTab = 0
        if let tabArgIndex = CommandLine.arguments.firstIndex(of: "-selectedTab"),
           tabArgIndex + 1 < CommandLine.arguments.count,
           let tabValue = Int(CommandLine.arguments[tabArgIndex + 1]) {
            initialTab = tabValue
        }
        _selectedTab = State(initialValue: initialTab)
        
        // 自定义原生 TabBar 深色黑金质感外观
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 14/255.0, green: 14/255.0, blue: 17/255.0, alpha: 1.0)
        
        let itemAppearance = UITabBarItemAppearance()
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let tabFontSize: CGFloat = isPad ? 13 : 10
        let tabFont = UIFont.systemFont(ofSize: tabFontSize, weight: .medium)
        itemAppearance.normal.iconColor = UIColor.systemGray2
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray2,
            .font: tabFont
        ]
        
        itemAppearance.selected.iconColor = UIColor(red: 242/255.0, green: 217/255.0, blue: 115/255.0, alpha: 1.0)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 242/255.0, green: 217/255.0, blue: 115/255.0, alpha: 1.0),
            .font: tabFont
        ]
        
        appearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 主罗盘与天心十道 (含120分金、64卦、24山、双轴水准仪、空亡详勘)
            CompassMainView(isActive: selectedTab == 0)
                .tabItem {
                    Image(systemName: "safari.fill")
                    Text(lang.t("tab_compass"))
                }
                .tag(0)
            
            // Tab 2: AR 实景天心透视与形煞智能标注 (前后镜头翻转、靶心动态测角、水印快照存证)
            ARVisionView(isActive: selectedTab == 1)
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text(lang.t("tab_ar"))
                }
                .tag(1)
            
            // Tab 3: 户型空间立极与全屋风水体检 (中宫重心立极、罗盘半透明叠透、火烧天门/鬼门体检)
            FloorplanView(isActive: selectedTab == 2)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text(lang.t("tab_floorplan"))
                }
                .tag(2)
            
            // Tab 4: 玄空理气与三式绝学 (玄空飞星、八宅三合、流年紫白、时家奇门、天机长卷)
            XuanKongGridView(isActive: selectedTab == 3)
                .tabItem {
                    Image(systemName: "square.grid.3x3.fill")
                    Text(lang.t("tab_analysis"))
                }
                .tag(3)
            
            // Tab 5: 系统设置与会员中心 (四档 StoreKit 内购、特权矩阵、8字传感器校准)
            SettingsView(isActive: selectedTab == 4)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text(lang.t("tab_settings"))
                }
                .tag(4)
        }
        .accentColor(Color(red: 0.95, green: 0.85, blue: 0.45))
        .preferredColorScheme(.dark)
        .onAppear {
            motion.start()
            updateResourceUsage()
        }
        .onChange(of: selectedTab) { _ in
            updateResourceUsage()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Re-enable sensors only after the app is visible again. Keeping
            // Core Location/Core Motion streams alive while the app is
            // backgrounded wastes battery and can keep the device warm.
            updateResourceUsage()
            motion.resumeIfSensorsEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            motion.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    /// The live compass and camera survey need an awake screen while they are
    /// in use.  Reports, settings and the paywall should follow the user's
    /// normal Auto-Lock preference to avoid draining the battery while idle.
    private func updateResourceUsage() {
        UIApplication.shared.isIdleTimerDisabled = selectedTab == 0 || selectedTab == 1
        motion.setDeviceMotionEnabled(selectedTab == 0)
        motion.setHeadingUpdatesEnabled(selectedTab != 4)
        motion.resumeIfSensorsEnabled()
    }
}
