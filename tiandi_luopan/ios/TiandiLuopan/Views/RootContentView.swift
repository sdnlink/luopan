import SwiftUI
import UIKit

// MARK: - iOS 14.0 颜色向下兼容扩展
extension Color {
    public static let yanCyan = Color(red: 0.0, green: 0.82, blue: 0.95)
    public static let yanBrown = Color(red: 0.65, green: 0.45, blue: 0.25)
    public static let yanGold = Color(red: 0.95, green: 0.80, blue: 0.25)
}

// MARK: - iPad 与多设备全景屏幕字体自适应扩展 (Adaptive Typography)
extension Font {
    /// 全景自适应计算最优字体字号：
    /// 在 iPhone 上保持设计原始字号，在 iPad Pro / iPad Air / iPad mini 大屏上自动按 1.35x 比例智能放大，
    /// 确保罗盘刻度、度数、八方吉凶、户型体检、九宫飞星、系统设置等所有界面的文本层次均清晰可辨。
    private static var isRegularLayout: Bool {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
            return window.traitCollection.horizontalSizeClass == .regular
        }
        return UITraitCollection.current.horizontalSizeClass == .regular
    }

    /// 全景自适应计算最优字体字号：
    /// 在 iPhone 上保持设计原始字号，在 iPad Pro / iPad Air / iPad mini 大屏上自动按 1.35x 比例智能放大，
    /// 确保罗盘刻度、度数、八方吉凶、户型体检、九宫飞星、系统设置等所有界面的文本层次均清晰可辨。
    public static func adaptive(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        // 按“可用空间”而非设备 idiom 决定字体放大：水平尺寸类为 regular 时使用大屏
        // 比例（iPad 全形态、iPhone Duo 展开态内屏），紧凑宽度（常规 iPhone 与
        // iPhone Duo 外屏）保持原字号。苹果 iPhone Duo 适配要求禁用
        // userInterfaceIdiom 做布局决策，改用 size class / 可用空间。
        let isLarge = isRegularLayout
        let scale: CGFloat = isLarge ? 1.35 : 1.0
        let scaledSize = (size * scale).rounded()
        return Font.system(size: scaledSize, weight: weight, design: design)
    }

    public static func adaptive(size: CGFloat, design: Font.Design) -> Font {
        adaptive(size: size, weight: .regular, design: design)
    }
}


// MARK: - iPhone Duo 折叠屏展开态双栏容器 (Foldable Two-Pane Adaptive Layout)
//
// 展开态（horizontalSizeClass == .regular：iPhone Duo 内屏 / iPad 全形态）：
//   左栏 = 主交互区（罗盘盘面 / AR 取景 / 户型画布 / 九宫排盘）
//   右栏 = 分析解释区（分金歌诀 / 形煞研判 / 体检报告 / 格局评析），中间细分隔线。
// 折叠态（compact：常规 iPhone、iPhone Duo 外屏）：保持原单列纵向布局，
// 分析区仍紧随主区之后，与旧版体验完全一致。
// 依据苹果 iPhone Duo 适配要求：按 size class / 可用空间决策布局，
// 禁用 userInterfaceIdiom（与上方 Font.adaptive 口径一致）。
public struct FoldableTwoPane<Main: View, Analysis: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 展开态左栏（主交互区）占整宽比例，收敛到 0.5 ~ 0.7。
    private let mainColumnRatio: CGFloat
    /// 折叠态纵向排布间距（须与调用方原布局 VStack spacing 一致）。
    private let compactSpacing: CGFloat
    /// 展开态右栏底色（与各 Tab 深色底一致）。
    private let analysisBackground: Color
    /// 展开态右栏内容的纵向对齐（默认顶部，符合阅读习惯；不影响折叠态）。
    private let analysisAlignment: Alignment

    private let main: Main
    private let analysis: Analysis

    public init(mainColumnRatio: CGFloat = 0.6,
                compactSpacing: CGFloat = 8,
                analysisBackground: Color = Color(red: 0.07, green: 0.07, blue: 0.09),
                analysisAlignment: Alignment = .top,
                @ViewBuilder main: () -> Main,
                @ViewBuilder analysis: () -> Analysis) {
        self.mainColumnRatio = min(max(mainColumnRatio, 0.5), 0.7)
        self.compactSpacing = compactSpacing
        self.analysisBackground = analysisBackground
        self.analysisAlignment = analysisAlignment
        self.main = main()
        self.analysis = analysis()
    }

    public var body: some View {
        if horizontalSizeClass == .regular {
            ProportionalTwoPaneLayout(mainRatio: mainColumnRatio) {
                main
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1)

                analysis
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: analysisAlignment)
                    .background(analysisBackground)
            }
        } else {
            VStack(spacing: compactSpacing) {
                main
                analysis
            }
        }
    }
}

// MARK: - 展开态双栏按比例布局 (iOS 16 Layout 协议)
//
// 不用 GeometryReader：外层 ScrollView 场景下 GeometryReader 会把容器高度
// 钉死在视口高度，导致较高的分析内容被裁切且无法滚动；自定义 Layout 以
// 两栏理想高度的最大值作为容器高度，整屏固定高度与 ScrollView 自然高度
// 两种场景均正确，并按 mainColumnRatio 精确分配左右栏宽度。
// 模块内共享：ARVisionView 折叠态是全屏取景 + HUD 悬浮布局（不适用
// FoldableTwoPane 的纵排折叠分支），其展开态直接复用本 Layout。
struct ProportionalTwoPaneLayout: Layout {
    let mainRatio: CGFloat

    private func paneWidths(total: CGFloat) -> (main: CGFloat, analysis: CGFloat) {
        let divider: CGFloat = 1
        let mainW = max(0, total * mainRatio - divider / 2)
        let analysisW = max(0, total - mainW - divider)
        return (mainW, analysisW)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else {
            // 调用方必须传"主栏 + 1pt 分隔线 + 分析栏"三元组；子视图数不对时
            // Debug 构建直接断言暴露，Release 静默返回零尺寸（不崩溃）。
            assertionFailure("ProportionalTwoPaneLayout 需要恰好 3 个子视图：主栏、分隔线、分析栏")
            return .zero
        }
        let width = proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }
        let (mainW, analysisW) = paneWidths(total: width)
        let mainH = subviews[0].sizeThatFits(ProposedViewSize(width: mainW, height: proposal.height)).height
        let analysisH = subviews[2].sizeThatFits(ProposedViewSize(width: analysisW, height: proposal.height)).height
        return CGSize(width: width, height: max(mainH, analysisH))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else {
            assertionFailure("ProportionalTwoPaneLayout 需要恰好 3 个子视图：主栏、分隔线、分析栏")
            return
        }
        let (mainW, analysisW) = paneWidths(total: bounds.width)
        let paneHeight = proposal.height ?? bounds.height
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: ProposedViewSize(width: mainW, height: paneHeight)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + mainW, y: bounds.minY),
            proposal: ProposedViewSize(width: 1, height: paneHeight)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.minX + mainW + 1, y: bounds.minY),
            proposal: ProposedViewSize(width: analysisW, height: paneHeight)
        )
    }
}


// MARK: - 天机演象 纯原生 SwiftUI 根视图 (Root Content View - PRD 5.0 标准五大场景)

public struct RootContentView: View {
    private let motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var selectedTab: Int
    // 读取 size class 建立环境依赖：折叠/展开（或 iPad 分屏拖动）切换时本视图
    // 重渲染并级联子视图 body 重算，使 Font.adaptive 的静态查询同步刷新
    //（配合 body 尾部 onChange 一起生效）。
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    public init() {
        var initialTab = 0
        if let tabArgIndex = CommandLine.arguments.firstIndex(of: "-selectedTab"),
           tabArgIndex + 1 < CommandLine.arguments.count,
           let tabValue = Int(CommandLine.arguments[tabArgIndex + 1]) {
            initialTab = tabValue
        }
        _selectedTab = State(initialValue: initialTab)
        
        // 自定义原生 TabBar 深色黑金质感外观（折叠/展开切换时 onChange 会重调以刷新字号）
        Self.applyTabBarAppearance(isLargeLayout: UITraitCollection.current.horizontalSizeClass == .regular)
    }

    /// 构建黑金深色 TabBar 外观：应用到 appearance proxy，并同步刷新
    /// 已挂载的 UITabBar 实例与条目字号（appearance proxy 不影响已创建的 bar）。
    private static func applyTabBarAppearance(isLargeLayout: Bool) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 14/255.0, green: 14/255.0, blue: 17/255.0, alpha: 1.0)

        let itemAppearance = UITabBarItemAppearance()
        let tabFont = UIFont.systemFont(ofSize: isLargeLayout ? 13 : 10, weight: .medium)
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

        // 实时刷新已挂载的 TabBar（SwiftUI TabView 的宿主 UITabBarController 已创建）
        let selectedColor = UIColor(red: 242/255.0, green: 217/255.0, blue: 115/255.0, alpha: 1.0)
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                Self.refreshTabBars(in: window, appearance: appearance, normalFont: tabFont, selectedColor: selectedColor)
            }
        }
    }

    private static func refreshTabBars(in view: UIView,
                                       appearance: UITabBarAppearance,
                                       normalFont: UIFont,
                                       selectedColor: UIColor) {
        if let tabBar = view as? UITabBar {
            tabBar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = appearance
            }
            tabBar.items?.forEach { item in
                item.setTitleTextAttributes(
                    [.foregroundColor: UIColor.systemGray2, .font: normalFont],
                    for: .normal
                )
                item.setTitleTextAttributes(
                    [.foregroundColor: selectedColor, .font: normalFont],
                    for: .selected
                )
            }
        }
        view.subviews.forEach {
            Self.refreshTabBars(in: $0, appearance: appearance, normalFont: normalFont, selectedColor: selectedColor)
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
        .onChange(of: horizontalSizeClass) { newValue in
            // 折叠/展开（或 iPad 分屏拖动）切换：重建 TabBar 外观刷新 Tab 字号；
            // 本视图因依赖 size class 而重渲染，级联子视图 body 重算，
            // 使 Font.adaptive 的静态查询同步更新 1.0x ↔ 1.35x 字号比例。
            Self.applyTabBarAppearance(isLargeLayout: newValue == .regular)
        }
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
