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
    /// 当前前台窗口的 trait collection：字号（Dynamic Type）与尺寸类都取自同一个快照，
    /// 避免同一次 body 求值里两次扫 connectedScenes、且两者读数不一致。
    private static var currentTraits: UITraitCollection? {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
            return window.traitCollection
        }
        return nil
    }

    /// Dynamic Type 额外放大系数（1.0 ... 1.3）。
    /// 取窗口 trait 的 `preferredContentSizeCategory`，用 body 文本样式的 17pt 基准换算出系统要求的放大比例；
    /// 上限 1.3 是刻意的：本工程大量容器是固定尺寸（24 山标签 30/36pt、十二长生表 90/110pt 列、
    /// 顶部 34pt 圆钮），跟随系统到无障碍最大字号（body 约 2.35x）会重新把这些容器撑破。
    /// 固定尺寸容器通过 `Font.dynamicTypeScale` 同步放大，保持"字 / 框"比例不变。
    public static var dynamicTypeScale: CGFloat {
        dynamicTypeScale(for: currentTraits ?? UITraitCollection.current)
    }

    private static func dynamicTypeScale(for traits: UITraitCollection) -> CGFloat {
        guard traits.preferredContentSizeCategory != .unspecified else { return 1.0 }
        let metrics = UIFontMetrics(forTextStyle: .body)
        let scaled = metrics.scaledValue(for: 17, compatibleWith: traits)
        let factor = scaled / 17
        guard factor.isFinite else { return 1.0 }
        return min(max(factor, 1.0), 1.3)
    }

    /// 全景自适应计算最优字体字号：
    /// 在 iPhone 上保持设计原始字号，在 iPad Pro / iPad Air / iPad mini 大屏上自动按 1.35x 比例智能放大，
    /// 确保罗盘刻度、度数、八方吉凶、户型体检、九宫飞星、系统设置等所有界面的文本层次均清晰可辨。
    public static func adaptive(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        // 按“可用空间”而非设备 idiom 决定字体放大：水平尺寸类为 regular 时使用大屏
        // 比例（iPad 全形态、iPhone Duo 展开态内屏），紧凑宽度（常规 iPhone 与
        // iPhone Duo 外屏）保持原字号。苹果 iPhone Duo 适配要求禁用
        // userInterfaceIdiom 做布局决策，改用 size class / 可用空间。
        let traits = currentTraits ?? UITraitCollection.current
        let isLarge = traits.horizontalSizeClass == .regular
        let scale: CGFloat = isLarge ? 1.35 : 1.0
        // 系统字号（Dynamic Type）叠加在大屏比例之上，再按 dynamicTypeScale 的上限收敛。
        let scaledSize = (size * scale * dynamicTypeScale(for: traits)).rounded()
        return Font.system(size: scaledSize, weight: weight, design: design)
    }

    public static func adaptive(size: CGFloat, design: Font.Design) -> Font {
        adaptive(size: size, weight: .regular, design: design)
    }
}

// MARK: - 环境驱动的自适应字号（Environment-driven Adaptive Typography）
//
// 为什么不再用 `Font.adaptive(...)`：
// 它是在 body 求值时**扫 connectedScenes** 取「第一个前台场景 key window」的 trait。
// 单窗口下没问题；但 iPad Stage Manager / 分屏开两个窗口且宽度不同时，
// 字号会以先到的场景为准（另一个窗口的字号与自己的宽度不匹配），而且 500+ 处文本
// 每次求值都要重建 UIFontMetrics。
//
// 现在改为 ViewModifier：水平尺寸类与系统字号都来自**当前视图所在场景**的
// `Environment`，每个窗口各取各的；缩放系数按「尺寸类 × 字号档」缓存，求值零成本。
// 全部调用点已是 `.adaptiveFont(size:weight:design:)`。
public enum AdaptiveFontMetrics {
    /// 宽屏（regular 宽度：iPad 全形态 / Duo 内屏）的大屏放大比例。
    public static let regularWidthScale: CGFloat = 1.35
    /// Dynamic Type 放大比例：直接跟随系统「文字大小」（default 1.0，辅助功能最大约 2.35x）。
    /// 不再人为封顶——各固定尺寸容器（24 山标签、顶部度数、VIP 卡等）已用
    /// `minimumScaleFactor` / 随 dynamicTypeScale 同步放大的 frame 自行兜底，避免溢出。

    private static var cache: [String: CGFloat] = [:]
    private static let cacheLock = NSLock()

    public static func contentSizeCategory(for dynamicType: DynamicTypeSize) -> UIContentSizeCategory {
        switch dynamicType {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        default: return .large
        }
    }

    /// 系统字号要求的放大比例（1.0 ... 1.3），带缓存。
    public static func dynamicTypeScale(for dynamicType: DynamicTypeSize) -> CGFloat {
        let category = contentSizeCategory(for: dynamicType)
        let key = category.rawValue
        cacheLock.lock()
        if let cached = cache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let factor = UIFontMetrics(forTextStyle: .body).scaledValue(for: 17, compatibleWith: traits) / 17
        let scale = factor.isFinite ? max(factor, 1.0) : 1.0

        cacheLock.lock()
        cache[key] = scale
        cacheLock.unlock()
        return scale
    }

    /// 宽屏比例（只由尺寸类决定）。
    public static func layoutScale(sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? regularWidthScale : 1.0
    }

    /// 最终字号 = 设计字号 × 宽屏比例 × 系统字号比例。
    public static func scaledSize(_ size: CGFloat,
                                  sizeClass: UserInterfaceSizeClass?,
                                  dynamicType: DynamicTypeSize) -> CGFloat {
        (size * layoutScale(sizeClass: sizeClass) * dynamicTypeScale(for: dynamicType)).rounded()
    }
}

public struct AdaptiveFontModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    public init(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) {
        self.size = size
        self.weight = weight
        self.design = design
    }

    public func body(content: Content) -> some View {
        let scaled = AdaptiveFontMetrics.scaledSize(size,
                                                    sizeClass: horizontalSizeClass,
                                                    dynamicType: dynamicTypeSize)
        return content.font(.system(size: scaled, weight: weight, design: design))
    }
}

public extension View {
    /// 替代旧的 `.font(.adaptive(size:...))`：
    /// 尺寸类与系统字号取自当前视图所在场景，支持多窗口各取各的。
    func adaptiveFont(size: CGFloat,
                      weight: Font.Weight = .regular,
                      design: Font.Design = .default) -> some View {
        modifier(AdaptiveFontModifier(size: size, weight: weight, design: design))
    }
}


// MARK: - 布局形态判定 (Adaptive Layout Form)
//
// 产品口径：
//   · iPhone Duo 展开内屏（phone 设备族 + regular 宽度）→ 左右双栏
//   · iPad 界面横屏（regular 宽度 + UIWindowScene.interfaceOrientation.isLandscape）
//     → 与 Duo 内屏一致的左右双栏：左栏 = 画板/取景/盘面（按左半屏宽度自适应），
//       右栏 = 解释与研判
//   · iPad 竖屏 / 分屏窄窗 / 常规 iPhone / Duo 折叠外屏 → 上下单列
//
// 口径说明：`userInterfaceIdiom` 在此**只用于区分设备族**（iPad 与 iPhone Duo），
// 不用于决定任何尺寸或布局；尺寸一律由 size class / 窗口尺寸决定。
// 方向取真实界面方向 `UIWindowScene.interfaceOrientation`，不用窗口宽高比猜测：
// Stage Manager 的可调窗口会让「宽 > 高」与「设备横屏」不再对应。
public enum AdaptiveLayout {
    /// 左右双栏：iPhone Duo 展开内屏，或 iPad 界面横屏。
    public static func isTwoPane(sizeClass: UserInterfaceSizeClass?, form: AdaptiveLayoutForm) -> Bool {
        guard sizeClass == .regular else { return false }
        // iPhone Duo 展开内屏：phone 设备族 + regular 宽度
        if form.isPhoneIdiom { return true }
        // iPad：仅界面横屏分栏；900pt 下限排除分屏/侧拉窄窗，避免两栏被压到不可读
        return form.isLandscape && form.size.width >= 900
    }

    /// 宽屏（iPad 全形态 + Duo 内屏）：只决定“更大”，不决定“是否分栏”。
    public static func isWide(sizeClass: UserInterfaceSizeClass?) -> Bool {
        sizeClass == .regular
    }
}

// MARK: - 布局环境值 (Adaptive Layout Form)
//
// 取代全局可变单例：全部由 SwiftUI Environment 同步注入。
// 好处：旋转时不滞后一帧、非活动 Tab 不会被全局对象强制重绘、
// 方向与设备族随窗口一起刷新（不再在 body 里查 UIDevice 全局状态）。
public struct AdaptiveLayoutForm: Equatable {
    /// 根视图可用窗口尺寸（来自 GeometryReader）
    public let size: CGSize
    /// 真实界面方向；`interfaceOrientation == .unknown` 时回退宽高比
    public let isLandscape: Bool
    /// 设备族：仅用于区分 iPhone Duo 内屏与 iPad，不参与尺寸决策
    public let isPhoneIdiom: Bool

    public init(size: CGSize = .zero, isLandscape: Bool = false, isPhoneIdiom: Bool = false) {
        self.size = size
        self.isLandscape = isLandscape
        self.isPhoneIdiom = isPhoneIdiom
    }

    /// 从当前 UIWindowScene 读取方向、设备族与窗口尺寸。
    /// - Parameter size: GeometryReader 给出的根视图尺寸（优先使用）。
    public static func current(size: CGSize = .zero) -> AdaptiveLayoutForm {
        var windowSize = size
        var isLandscape = false
        var isPhoneIdiom = false

        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive
                            || $0.activationState == .foregroundInactive }),
           let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            if windowSize == .zero { windowSize = window.bounds.size }
            let orientation = scene.interfaceOrientation
            isLandscape = orientation.isLandscape
            if orientation == .unknown {
                // 启动瞬间方向尚未上报：用宽高比兜底
                isLandscape = windowSize.width > windowSize.height
            }
            isPhoneIdiom = window.traitCollection.userInterfaceIdiom == .phone
        } else {
            isLandscape = windowSize.width > windowSize.height
        }

        // CI 截图兜底：Xcode 27 的 Device Hub 常不响应 AppleScript 旋转，
        // 此时用启动参数强制按「横屏分栏」渲染，以便仍能验证双栏布局。
        // 正常启动不带该参数，App Store 包行为完全不受影响。
        let forcedLandscape = CommandLine.arguments.contains("-forceLandscapeLayout")
        if forcedLandscape {
            // 设备像素仍是竖屏，但布局要按横屏可用空间计算（两栏高度、宽度上限等），
            // 交换宽高后 -forceLandscapeLayout 的截图与真旋转结果一致。
            windowSize = CGSize(width: windowSize.height, height: windowSize.width)
        }
        return AdaptiveLayoutForm(size: windowSize,
                                  isLandscape: forcedLandscape || isLandscape,
                                  isPhoneIdiom: isPhoneIdiom)
    }
}

private struct AdaptiveLayoutFormKey: EnvironmentKey {
    static let defaultValue = AdaptiveLayoutForm()
}

public extension EnvironmentValues {
    var adaptiveLayoutForm: AdaptiveLayoutForm {
        get { self[AdaptiveLayoutFormKey.self] }
        set { self[AdaptiveLayoutFormKey.self] = newValue }
    }
}

// MARK: - 展开态双栏容器 (Foldable Two-Pane Adaptive Layout)
//
// 分栏形态（iPhone Duo 展开内屏 / iPad 横屏，判据见 AdaptiveLayout.isTwoPane）：
//   左栏 = 主交互区（罗盘盘面 / AR 取景 / 户型画布 / 九宫排盘），宽度 ≈ 全宽 55~60%，
//          盘面/画布按左栏可用尺寸自适应（不再按整屏尺寸计算）。
//   右栏 = 分析解释区（分金歌诀 / 形煞研判 / 体检报告 / 格局评析），中间细分隔线。
// 单列形态（常规 iPhone、Duo 折叠外屏、iPad 竖屏 / 分屏窄窗）：
//   保持上下单列，分析区紧随主区之后，画布/内容按宽屏尺寸放大
//   （尺寸口径由各页 isLargeLayout 控制）。
public struct FoldableTwoPane<Main: View, Analysis: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// 布局环境值：界面方向 / 窗口尺寸 / 设备族，随旋转同步刷新。
    @Environment(\.adaptiveLayoutForm) private var layoutForm

    /// 展开态左栏（主交互区）占整宽比例，收敛到 0.5 ~ 0.7。
    private let mainColumnRatio: CGFloat
    /// 折叠态纵向排布间距（须与调用方原布局 VStack spacing 一致）。
    private let compactSpacing: CGFloat
    /// 展开态右栏底色（与各 Tab 深色底一致）。
    private let analysisBackground: Color
    /// 展开态右栏内容的纵向对齐（默认顶部，符合阅读习惯；不影响折叠态）。
    private let analysisAlignment: Alignment
    /// 外层为 ScrollView 的长报告页：两栏各自独立滚动（见 independentScrollPanes）。
    private let independentScroll: Bool

    private let main: Main
    private let analysis: Analysis

    public init(mainColumnRatio: CGFloat = 0.6,
                compactSpacing: CGFloat = 8,
                analysisBackground: Color = Color(red: 0.07, green: 0.07, blue: 0.09),
                analysisAlignment: Alignment = .top,
                independentScroll: Bool = false,
                @ViewBuilder main: () -> Main,
                @ViewBuilder analysis: () -> Analysis) {
        self.mainColumnRatio = min(max(mainColumnRatio, 0.5), 0.7)
        self.compactSpacing = compactSpacing
        self.analysisBackground = analysisBackground
        self.analysisAlignment = analysisAlignment
        self.independentScroll = independentScroll
        self.main = main()
        self.analysis = analysis()
    }

    public var body: some View {
        if AdaptiveLayout.isTwoPane(sizeClass: horizontalSizeClass, form: layoutForm) {
            if independentScroll {
                independentScrollPanes
            } else {
                standardPanes
            }
        } else {
            VStack(spacing: compactSpacing) {
                main
                analysis
            }
        }
    }

    /// 常规分栏：用于整屏/固定高度场景（罗盘、AR、户型），调用方自行给右栏滚动能力。
    private var standardPanes: some View {
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
    }

    /// 独立滚动分栏：外层是 ScrollView 时，用窗口高度给两栏确定高度并各包 ScrollView，
    /// 避免「右栏解释内容把整页撑长、两栏只能一起滚」。
    /// 不用 GeometryReader：ScrollView 内它拿不到确定高度（会塌缩）。
    private var independentScrollPanes: some View {
        // 扣掉子 Tab 栏与上下留白，保证两栏落在可视区内
        let paneHeight = max(320, layoutForm.size.height - 140)
        return ProportionalTwoPaneLayout(mainRatio: mainColumnRatio) {
            ScrollView {
                main
            }
            .frame(maxWidth: .infinity)
            .frame(height: paneHeight)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1, height: paneHeight)

            ScrollView {
                analysis
            }
            .frame(maxWidth: .infinity)
            .frame(height: paneHeight)
            .background(analysisBackground)
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
    // 读取 Dynamic Type 环境值建立依赖：系统「文字大小」变化时根视图重算 body，
    // 级联刷新 Font.adaptive（它按窗口 trait 计算，不读环境值，需要这里触发）。
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 注入给所有子视图的布局环境值（窗口尺寸 / 界面方向 / 设备族）。
    @State private var layoutForm = AdaptiveLayoutForm.current()
    
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

    /// 同步刷新布局环境值：只在值真正变化时写 @State，避免无谓重绘。
    private func refreshLayoutForm(size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let next = AdaptiveLayoutForm.current(size: size)
        if next != layoutForm { layoutForm = next }
    }

    /// 构建黑金深色 TabBar 外观：应用到 appearance proxy，并同步刷新
    /// 已挂载的 UITabBar 实例与条目字号（appearance proxy 不影响已创建的 bar）。
    private static func applyTabBarAppearance(isLargeLayout: Bool) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 14/255.0, green: 14/255.0, blue: 17/255.0, alpha: 1.0)

        let itemAppearance = UITabBarItemAppearance()
        // Tab 标签是 UIKit 固定字号，不会自动跟随 Dynamic Type：用 UIFontMetrics 补齐，
        // 并给 maximumPointSize = 1.3x 上限，避免放大后撑出 49pt 的 TabBar 高度。
        let baseTabFontSize: CGFloat = isLargeLayout ? 13 : 10
        let tabFont = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: UIFont.systemFont(ofSize: baseTabFontSize, weight: .medium),
                        maximumPointSize: baseTabFontSize * 1.3)
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
        // 采集真实窗口尺寸并同步注入 Environment：iPad 旋转不改变 size class，
        // 各页靠 interfaceOrientation + 尺寸切换「横屏双栏 / 竖屏单列」。
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { refreshLayoutForm(size: geo.size) }
                    .onChange(of: geo.size) { newSize in
                        refreshLayoutForm(size: newSize)
                    }
            }
        )
        .environment(\.adaptiveLayoutForm, layoutForm)
        .onChange(of: horizontalSizeClass) { newValue in
            // 折叠/展开（或 iPad 分屏拖动）切换：重建 TabBar 外观刷新 Tab 字号；
            // 本视图因依赖 size class 而重渲染，级联子视图 body 重算，
            // 使 Font.adaptive 的静态查询同步更新 1.0x ↔ 1.35x 字号比例。
            Self.applyTabBarAppearance(isLargeLayout: newValue == .regular)
        }
        .onChange(of: dynamicTypeSize) { _ in
            // 系统「文字大小」变化：本视图已因读取该环境值而重渲染，
            // 这里再把 UIKit 侧已挂载的 TabBar 字号刷新一遍（UITabBar 不跟随 Dynamic Type）。
            Self.applyTabBarAppearance(isLargeLayout: horizontalSizeClass == .regular)
        }
        .onAppear {
            // init 阶段 UITraitCollection.current 尚未进入真实窗口环境，
            // 取不到 regular 宽度 → iPad 首帧 Tab 字号会停在 10pt；而
            // onChange(of:) 只在尺寸类“变化”时触发，不会补首帧。此处用
            // 已建立的 environment 值重新应用一次，保证 iPad 启动即为 13pt。
            Self.applyTabBarAppearance(isLargeLayout: horizontalSizeClass == .regular)
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
        // 多窗口：传感器开关是全局单例，两个窗口各按自己的 Tab 置位会互相覆盖
        // （窗口 A 停在罗盘、窗口 B 停在设置时，B 会把 A 的 device motion 关掉）。
        // 只要同时存在多个前台场景，就统一保持开启，宁可多耗一点电，也不让另一个窗口的罗盘停摆。
        let activeSceneCount = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .count
        let multipleActiveScenes = activeSceneCount > 1
        UIApplication.shared.isIdleTimerDisabled = multipleActiveScenes || selectedTab == 0 || selectedTab == 1
        motion.setDeviceMotionEnabled(multipleActiveScenes || selectedTab == 0)
        motion.setHeadingUpdatesEnabled(multipleActiveScenes || selectedTab != 4)
        motion.resumeIfSensorsEnabled()
    }
}

// MARK: - 相机独占租约（多窗口互斥）
//
// 问题：iPad Stage Manager / 分屏同时开两个窗口并都停在相机页面时，两路
// AVCaptureSession / ARSession / RoomCaptureSession 会争用系统独占的摄像头，
// 后开的一路表现为「起不来 / 反复重连 / 黑屏」，且系统不给任何可读错误。
//
// 方案：应用层租约。
//   · **同一窗口内允许接管**：相机页之间本来就是互斥关系（后开的会把前一个停掉，
//     见 ARSpatialSurveyModel 里 "existing camera based AR screen and this object are
//     never active together"），若同窗口也拒绝，会把「相机页 + 测绘全屏页」这种正常
//     用法挡在门外。
//   · **跨窗口则拒绝**：另一个窗口正用着相机时，本窗口不启动任何采集会话，
//     改为显示一张提示卡；对方释放后自动接管。
public final class CameraExclusivity: ObservableObject {
    public static let shared = CameraExclusivity()

    /// 当前占用者所在窗口场景（UI 侧只读镜像，用于判断提示卡什么时候该撤掉）。
    @Published public private(set) var holderSceneID: ObjectIdentifier?

    private weak var holder: AnyObject?
    private var holderScene: ObjectIdentifier?
    private let lock = NSLock()

    /// 申请相机使用权。同窗口的申请会接管；跨窗口返回 false。
    public func acquire(_ owner: AnyObject, sceneID: ObjectIdentifier?) -> Bool {
        lock.lock()
        if let current = holder, current !== owner,
           let currentScene = holderScene, let targetScene = sceneID,
           currentScene != targetScene {
            lock.unlock()
            return false
        }
        holder = owner
        holderScene = sceneID
        let scene = sceneID
        lock.unlock()

        if Thread.isMainThread {
            holderSceneID = scene
        } else {
            DispatchQueue.main.async { self.holderSceneID = scene }
        }
        return true
    }

    public func release(_ owner: AnyObject) {
        lock.lock()
        guard let current = holder, current === owner else {
            lock.unlock()
            return
        }
        holder = nil
        holderScene = nil
        lock.unlock()

        if Thread.isMainThread {
            holderSceneID = nil
        } else {
            DispatchQueue.main.async { self.holderSceneID = nil }
        }
    }

    /// 相机是否被**别的窗口**占着。
    public func isBusy(for sceneID: ObjectIdentifier?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let currentScene = holderScene, let target = sceneID else { return false }
        return currentScene != target
    }
}

/// 只用来当租约 owner 的占位对象：SwiftUI 的 @State 里保持稳定引用，
/// 视图销毁时自动 dealloc，租约的 weak 引用也随之失效。
public final class CameraLeaseToken {}

/// 读出当前视图所在的 UIWindowScene（SwiftUI 没有直接给出场景标识的环境值）。
private struct WindowSceneIDProbe: UIViewRepresentable {
    @Binding var sceneID: ObjectIdentifier?

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let windowScene = uiView.window?.windowScene else { return }
        let identifier = ObjectIdentifier(windowScene)
        guard identifier != sceneID else { return }
        DispatchQueue.main.async { self.sceneID = identifier }
    }
}

/// 相机页闸门：拿不到跨窗口租约时，用提示卡替代内容，
/// 从根上不构造采集会话（而不是构造了再失败重连）。
public struct CameraExclusiveGate<Content: View>: View {
    private enum Phase {
        case pending
        case granted
        case denied
    }

    @ObservedObject private var exclusivity = CameraExclusivity.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var phase: Phase = .pending
    @State private var sceneID: ObjectIdentifier?
    @State private var token = CameraLeaseToken()

    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        Group {
            switch phase {
            case .granted:
                content()
            case .denied:
                deniedCard
            case .pending:
                // 等窗口场景标识的一帧：用与相机页一致的深色底，避免闪白。
                Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
            }
        }
        .background(
            WindowSceneIDProbe(sceneID: $sceneID)
                .frame(width: 0, height: 0)
        )
        .onAppear {
            tryAcquire()
            // 兜底：极端情况下探针拿不到窗口（例如视图在离屏层级里），
            // 300ms 后按「无场景标识」放行，宁可回到多窗口的老行为，也不锁死功能。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if phase == .pending {
                    phase = .granted
                }
            }
        }
        .onDisappear {
            CameraExclusivity.shared.release(token)
        }
        .onReceive(exclusivity.$holderSceneID) { _ in
            tryAcquire()
        }
        .onChange(of: sceneID) { _ in
            tryAcquire()
        }
    }

    private var deniedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.slash")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.55))
            Text(lang.t("ar_camera_busy"))
                .adaptiveFont(size: 13)
                .multilineTextAlignment(.center)
                .foregroundColor(Color.white.opacity(0.8))
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
    }

    private func tryAcquire() {
        guard phase != .granted else { return }
        guard let windowSceneID = sceneID else { return }
        if CameraExclusivity.shared.acquire(token, sceneID: windowSceneID) {
            phase = .granted
        } else {
            phase = .denied
        }
    }
}
