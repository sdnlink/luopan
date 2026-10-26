import SwiftUI

// MARK: - 演象·时空罗盘 纯原生 SwiftUI 根视图 (Root Content View)

public struct RootContentView: View {
    @StateObject private var motion = CompassMotionManager.shared
    @State private var selectedTab: Int = 0
    
    public init() {
        // 自定义原生 TabBar 深色金质外观
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
            // Tab 1: 主罗盘与天心十道
            CompassMainView()
                .tabItem {
                    Image(systemName: "safari.fill")
                    Text("时空罗盘")
                }
                .tag(0)
            
            // Tab 2: AR 实景天心透视与形煞智能标注
            ARVisionView()
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("全景形煞")
                }
                .tag(1)
            
            // Tab 3: 玄空飞星九宫排盘
            XuanKongGridView()
                .tabItem {
                    Image(systemName: "square.grid.3x3.fill")
                    Text("三元九运")
                }
                .tag(2)
            
            // Tab 4: 八宅明镜与三合水法
            BaZhaiView()
                .tabItem {
                    Image(systemName: "water.waves")
                    Text("八宅三合")
                }
                .tag(3)
            
            // Tab 5: 系统设置与专业版
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("系统设置")
                }
                .tag(4)
        }
        .accentColor(Color(red: 0.95, green: 0.85, blue: 0.45))
        .onAppear {
            motion.start()
        }
    }
}
