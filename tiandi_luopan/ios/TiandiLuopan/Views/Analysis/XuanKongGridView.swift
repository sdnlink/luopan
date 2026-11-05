import SwiftUI

// MARK: - 原生玄空理气与三式绝学全景视图 (XuanKong, BaZhai, PurpleWhite & QiMen View)

public struct XuanKongGridView: View {
    public var isActive: Bool = true
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var selectedSubTab: Int = 0 // 0: 玄空九星, 1: 八宅三合, 2: 紫白客星, 3: 时家奇门
    @State private var selectedPeriod: Int = FlyingStarsEngine.shared.currentPeriod(for: Date())
    @State private var useTiGua: Bool = false
    // 手动替卦锁定：nil=跟随传感器 isJianXiang；非 nil=用户手动指定，传感器不再覆盖。
    // 换坐/向山后重置回跟随，避免用户已看清的盘被高频传感器样本突然改写。
    @State private var manualTiGuaOverride: Bool? = nil
    @State private var showTianJiShuSheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var cachedChart: XuanKongChart?
    @State private var selectedPalaceIdx: Int = 4
    @State private var lastCurrentPeriod: Int = FlyingStarsEngine.shared.currentPeriod(for: Date())
    private static let periodRefreshTimer = Timer.publish(
        every: 60,
        on: .main,
        in: .common
    ).autoconnect()
    
    // 九宫格九个方位的标准九宫排布对应 (从左到右，从上到下：东南4、正南9、西南2；正东3、中宫5、正西7；东北8、正北1、西北6)
    private let gridDisplayOrder = [3, 8, 1, 2, 4, 6, 7, 0, 5]

    // 布局按“可用空间”而非设备 idiom 决策（苹果 iPhone Duo 适配要求）：
    // regular 宽度（iPad、iPhone Duo 展开态内屏）启用大屏布局。
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isLargeLayout: Bool {
        horizontalSizeClass == .regular
    }
    
    public init(isActive: Bool = true) {
        self.isActive = isActive
    }
    
    public var body: some View {
        // The other three sub-tabs have their own engines. Avoid rebuilding
        // the complete nine-palace flying-star chart for every compass sample
        // while one of those tabs is active.
        let chart: XuanKongChart? = isActive && selectedSubTab == 0
            ? (cachedChart ?? FlyingStarsEngine.shared.calculateChart(
                period: selectedPeriod,
                sitting: motion.headingState.sittingMountain,
                facing: motion.headingState.facingMountain,
                useTiGua: useTiGua
            ))
            : nil
        
        ScrollView {
            if isActive {
                VStack(spacing: 14) {
                // 1. 四大学派理气子 Tab 切换条
                subTabBar()
                
                // 2. 天机书长卷一键生成入口 Banner
                tianJiShuBanner()
                    .padding(.horizontal, 16)
                
                if selectedSubTab == 0, let chart = chart {
                    // 板块 1: 玄空九星三元九运排盘
                    xuanKongContent(chart: chart)
                } else if selectedSubTab == 1 {
                    // 板块 2: 八宅明镜与三合水法
                    BaZhaiView(isEmbedded: true, isActive: isActive && selectedSubTab == 1)
                } else if selectedSubTab == 2 {
                    // 板块 3: 紫白飞星流年流月客星与太岁三煞
                    PurpleWhiteView(isActive: isActive && selectedSubTab == 2)
                } else {
                    // 板块 4: 三式绝学时家奇门遁甲全息排盘
                    QimenDunjiaView(isActive: isActive && selectedSubTab == 3)
                }
            }
            .frame(maxWidth: isLargeLayout ? 1100 : .infinity)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 24)
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
        .sheet(isPresented: $showTianJiShuSheet) {
            TianJiShuView()
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
        .onAppear {
            refreshChart()
        }
        .onChange(of: isActive) { _ in
            refreshChart()
        }
        .onChange(of: selectedSubTab) { _ in
            refreshChart()
        }
        .onChange(of: selectedPeriod) { _ in
            refreshChart()
        }
        .onChange(of: useTiGua) { _ in
            refreshChart()
        }
        .onChange(of: motion.headingState.isJianXiang) { isJian in
            // 仅跟随模式（用户未手动锁定）下才随传感器切换下卦/替卦。
            guard manualTiGuaOverride == nil else { return }
            useTiGua = isJian
            refreshChart()
        }
        .onChange(of: motion.headingState.sittingMountain.id) { _ in
            manualTiGuaOverride = nil
            refreshChart()
        }
        .onChange(of: motion.headingState.facingMountain.id) { _ in
            manualTiGuaOverride = nil
            refreshChart()
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            refreshChart()
        }
        .onReceive(Self.periodRefreshTimer) { _ in
            guard isActive else { return }
            let currentPeriod = FlyingStarsEngine.shared.currentPeriod(for: Date())
            // If the user was following the previously current period, keep
            // following it across the Li Chun/20-year boundary. A deliberate
            // historical-period selection remains untouched.
            if selectedPeriod == lastCurrentPeriod, selectedPeriod != currentPeriod {
                selectedPeriod = currentPeriod
            }
            lastCurrentPeriod = currentPeriod
            refreshChart()
        }
    }

    private func refreshChart() {
        guard isActive, selectedSubTab == 0 else {
            cachedChart = nil
            return
        }
        cachedChart = FlyingStarsEngine.shared.calculateChart(
            period: selectedPeriod,
            sitting: motion.headingState.sittingMountain,
            facing: motion.headingState.facingMountain,
            useTiGua: useTiGua
        )
    }
    
    // MARK: - 子 Tab 切换栏
    private func subTabBar() -> some View {
        HStack(spacing: 0) {
            tabButton(title: lang.t("xuankong_stars"), index: 0)
            tabButton(title: lang.t("bazhai_sanhe"), index: 1)
            tabButton(title: lang.t("purple_white"), index: 2)
            tabButton(title: lang.t("qimen_dunjia"), index: 3)
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
        .padding(.horizontal, isLargeLayout ? 0 : 16)
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            selectedSubTab = index
        }) {
            Text(title)
                .font(.adaptive(size: 12, weight: selectedSubTab == index ? .bold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isLargeLayout ? 10 : 8)
                .background(selectedSubTab == index ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.clear)
                .foregroundColor(selectedSubTab == index ? .black : .white.opacity(0.75))
        }
    }
    
    // MARK: - 天机书宣纸长卷 Banner
    private func tianJiShuBanner() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "scroll.fill")
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(lang.t("tianji_scroll"))
                        .font(.adaptive(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(lang.t("xuankong_integrated_title"))
                    .font(.adaptive(size: 10))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            Button(action: {
                showTianJiShuSheet = true
            }) {
                Text(lang.t("one_click_export"))
                    .font(.adaptive(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.8, blue: 0.35), Color(red: 0.75, green: 0.55, blue: 0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
            }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.14, green: 0.12, blue: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, isLargeLayout ? 0 : 16)
    }
    
    // MARK: - 玄空九星排盘内容
    private func xuanKongContent(chart: XuanKongChart) -> some View {
        // iPhone Duo 展开态双栏：左栏 = 元运切换/格局徽章/九宫飞星排盘（主交互），
        // 右栏 = 格局评析与财富/健康/化解建议（分析解释）；折叠态保持原单列纵排。
        FoldableTwoPane(mainColumnRatio: 0.56, compactSpacing: 14) {
            VStack(spacing: 14) {
                periodPickerBar(chart: chart)
                patternBadgeView(chart: chart)
                ninePalacesGrid(chart: chart)
            }
        } analysis: {
            VStack(spacing: 12) {
                analysisCard(chart: chart)
            }
            .padding(.horizontal, isLargeLayout ? 0 : 16)
        }
    }
    
    // MARK: - 元运切换栏 (完全根据天文学与干支历法动态推导，杜绝任何硬编码)
    private func periodPickerBar(chart: XuanKongChart) -> some View {
        let curPeriod = FlyingStarsEngine.shared.currentPeriod(for: Date())
        
        return VStack(spacing: 6) {
            Text(chart.periodMeta.label)
                .font(.adaptive(size: 12, weight: .bold))
                .foregroundColor(chart.periodMeta.isCurrent ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.75))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...9, id: \.self) { p in
                        let isCur = (p == curPeriod)
                        let isSelected = (p == selectedPeriod)
                        let isLocked = (!isCur && !iap.hasUnlockedVIP)
                        
                        Button(action: {
                            if isLocked {
                                showPaywall = true
                            } else {
                                selectedPeriod = p
                            }
                        }) {
                            HStack(spacing: 2) {
                                Text("\(p)\(lang.t("xuankong_period_unit"))")
                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.adaptive(size: 8))
                                }
                            }
                            .font(.adaptive(size: 13, weight: isSelected ? .bold : .medium))
                            .frame(width: isLocked ? (isLargeLayout ? 62 : 52) : (isLargeLayout ? 52 : 44), height: isLargeLayout ? 36 : 32)
                            .background(isSelected ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.white.opacity(0.1))
                            .foregroundColor(isSelected ? .black : .white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - 格局徽章与下卦/替卦切换
    private func patternBadgeView(chart: XuanKongChart) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("\(chart.sittingMountain)\(lang.t("mountain_suffix"))\(chart.facingMountain)\(lang.t("facing_suffix"))")
                    .font(.adaptive(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(chart.patternType)
                    .font(.adaptive(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(Color.orange)
                    .cornerRadius(6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Button(action: {
                    useTiGua.toggle()
                    // 手动切换后锁定该选择，传感器 isJianXiang 不再覆盖；
                    // 换坐/向山后自动回到跟随模式。
                    manualTiGuaOverride = useTiGua
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.adaptive(size: 9, weight: .bold))
                        Text(chart.chartModeTitle)
                            .font(.adaptive(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(useTiGua ? Color.purple.opacity(0.25) : Color.blue.opacity(0.2))
                    .foregroundColor(useTiGua ? Color(red: 0.85, green: 0.65, blue: 1.0) : Color.yanCyan)
                    .cornerRadius(6)
                }
            }
            if chart.isSanBanGua || chart.isQiXingDaJie {
                HStack(spacing: 6) {
                    if chart.isSanBanGua {
                        Text(sanBanGuaBadgeText())
                            .font(.adaptive(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(Color.green)
                            .cornerRadius(4)
                    }
                    if chart.isQiXingDaJie {
                        Text(qiXingDaJieBadgeText())
                            .font(.adaptive(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.22))
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    // MARK: - 3x3 九宫飞星网格
    private func ninePalacesGrid(chart: XuanKongChart) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(gridDisplayOrder, id: \.self) { idx in
                let cell = chart.palaces[idx]
                palaceCellView(cell: cell)
                    .onTapGesture {
                        selectedPalaceIdx = cell.id
                    }
            }
        }
        .frame(maxWidth: isLargeLayout ? 580 : .infinity)
        .padding(.horizontal, isLargeLayout ? 0 : 16)
    }
    
    private func palaceCellView(cell: XuanKongPalace) -> some View {
        let isDanger25 = (cell.sittingStar == 2 && cell.facingStar == 5) || (cell.sittingStar == 5 && cell.facingStar == 2)
        let isDouble9 = cell.sittingStar == cell.activePeriod && cell.facingStar == cell.activePeriod
        let isSelected = cell.id == selectedPalaceIdx
        let borderColor = isSelected ? Color.yanCyan : (isDanger25 ? Color.red : (isDouble9 ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.12)))
        let bgColor = isDanger25 ? Color.red.opacity(0.1) : Color(red: 0.12, green: 0.12, blue: 0.16)
        
        return VStack {
            HStack {
                Text("\(cell.sittingStar)")
                    .font(.adaptive(size: 13, weight: .bold))
                    .foregroundColor(Color.yanCyan)
                Spacer()
                Text("\(cell.facingStar)")
                    .font(.adaptive(size: 13, weight: .bold))
                    .foregroundColor(Color.orange)
            }
            
            Spacer(minLength: 2)
            
            Text("\(cell.periodStar)")
                .font(.adaptive(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            
            Spacer(minLength: 2)
            
            HStack {
                Text(cell.localizedPalaceName)
                    .font(.adaptive(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(cell.localizedElement)
                    .font(.adaptive(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(isLargeLayout ? 12 : 8)
        .aspectRatio(1.0, contentMode: .fit)
        .background(bgColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: (isSelected || isDanger25 || isDouble9) ? 1.5 : 1)
        )
    }
    
    // MARK: - 深度分析卡
    private func analysisCard(chart: XuanKongChart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("xuankong_deep_analysis"))
                .font(.adaptive(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            
            Text(chart.patternDesc)
                .font(.adaptive(size: 13))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
            
            Divider().background(Color.white.opacity(0.1))
            
            if chart.palaces.indices.contains(selectedPalaceIdx) {
                let sel = chart.palaces[selectedPalaceIdx]
                HStack(spacing: 6) {
                    Text("【\(sel.localizedPalaceName)】")
                        .font(.adaptive(size: 12, weight: .bold))
                        .foregroundColor(Color.yanCyan)
                    Text("\(sel.sittingStar)-\(sel.facingStar) · \(sel.periodStar)")
                        .font(.adaptive(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Spacer()
                    Text(sel.localizedEvaluation)
                        .font(.adaptive(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chart.wealthAdvice)
                Text(chart.healthAdvice)
                Text(chart.remedyAdvice)
            }
            .font(.adaptive(size: 11))
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(14)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func sanBanGuaBadgeText() -> String {
        switch lang.effectiveLanguage {
        case .en: return "San Ban Gua (Auspicious Triad)"
        case .zhHant, .ja: return "三般卦吉格 · 通氣連珠"
        case .ko: return "삼반괘 길격"
        case .vi: return "Tam Ban Quái Cát Cách"
        case .th: return "ซานปานกั้ว (ผังมงคลสามประสาน)"
        case .id: return "Pola San Ban Gua"
        case .auto, .zhHans: return "三般卦吉格 · 通气连珠"
        }
    }
    
    private func qiXingDaJieBadgeText() -> String {
        switch lang.effectiveLanguage {
        case .en: return "Qi Xing Da Jie (Seven-Star Robbery)"
        case .zhHant, .ja: return "七星打劫大吉局"
        case .ko: return "칠성타겁 대길국"
        case .vi: return "Thất Tinh Đả Kiếp Đại Cát Cục"
        case .th: return "ชีซิงต่าเจี๋ย (ผังเจ็ดดาวมงคลใหญ่)"
        case .id: return "Formasi Qi Xing Da Jie"
        case .auto, .zhHans: return "七星打劫大吉局"
        }
    }
}
