import SwiftUI

// MARK: - iOS 14.0 颜色向下兼容扩展
extension Color {
    public static let yanCyan = Color(red: 0.0, green: 0.82, blue: 0.95)
    public static let yanBrown = Color(red: 0.65, green: 0.45, blue: 0.25)
}

// MARK: - 演象·时空罗盘 纯原生 SwiftUI 根视图 (Root Content View - PRD 5.0 标准五大场景)

public struct RootContentView: View {
    @StateObject private var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var selectedTab: Int = 0
    
    public init() {
        // 自定义原生 TabBar 深色黑金质感外观
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 14/255.0, green: 14/255.0, blue: 17/255.0, alpha: 1.0)
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.systemGray2
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray2]
        
        itemAppearance.selected.iconColor = UIColor(red: 242/255.0, green: 217/255.0, blue: 115/255.0, alpha: 1.0)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 242/255.0, green: 217/255.0, blue: 115/255.0, alpha: 1.0)]
        
        appearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 主罗盘与天心十道 (含120分金、64卦、24山、双轴水准仪、空亡详勘)
            CompassMainView()
                .tabItem {
                    Image(systemName: "safari.fill")
                    Text(lang.t("tab_compass"))
                }
                .tag(0)
            
            // Tab 2: AR 实景天心透视与形煞智能标注 (前后镜头翻转、靶心动态测角、水印快照存证)
            ARVisionView()
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text(lang.t("tab_ar"))
                }
                .tag(1)
            
            // Tab 3: 户型空间立极与全屋风水体检 (中宫重心立极、罗盘半透明叠透、火烧天门/鬼门体检)
            FloorplanView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text(lang.t("tab_floorplan"))
                }
                .tag(2)
            
            // Tab 4: 玄空理气与三式绝学 (玄空飞星、八宅三合、流年紫白、时家奇门、天机长卷)
            XuanKongGridView()
                .tabItem {
                    Image(systemName: "square.grid.3x3.fill")
                    Text(lang.t("tab_analysis"))
                }
                .tag(3)
            
            // Tab 5: 系统设置与会员中心 (四档Apple Pay内购收银台、特权矩阵、8字传感器校准)
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text(lang.t("tab_settings"))
                }
                .tag(4)
        }
        .accentColor(Color(red: 0.95, green: 0.85, blue: 0.45))
        .onAppear {
            motion.start()
        }
    }
}
