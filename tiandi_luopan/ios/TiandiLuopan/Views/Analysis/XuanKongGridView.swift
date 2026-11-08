import SwiftUI

// MARK: - 原生玄空理气与三式绝学全景视图 (XuanKong, BaZhai, PurpleWhite & QiMen View)

public struct XuanKongGridView: View {
    public var isActive: Bool = true
    /// 0: 玄空九星, 1: 八宅三合, 2: 紫白客星, 3: 时家奇门。
    /// 由根视图持有，使小组件深链可以直接落到「八宅三合」里的日课卡。
    @Binding public var selectedSubTab: Int
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var selectedPeriod: Int = FlyingStarsEngine.shared.currentPeriod(for: Date())
    @State private var useTiGua: Bool = false
    // 手动替卦锁定：nil=跟随传感器 isJianXiang；非 nil=用户手动指定，传感器不再覆盖。
    // 换坐/向山后重置回跟随，避免用户已看清的盘被高频传感器样本突然改写。
    @State private var manualTiGuaOverride: Bool? = nil
    @State private var showTianJiShuSheet: Bool = false
    @State private var showDailySignSheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showMountainPickerSheet: Bool = false
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
    // 宽屏（iPad 全形态、iPhone Duo 展开态内屏）启用放大的内容宽度与控件尺寸；
    // 是否左右分栏由 FoldableTwoPane/AdaptiveLayout 决定（iPad 横屏分栏、竖屏单列）。
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 布局环境值：iPad 横屏时九宫排盘进左栏，需按左栏宽度放大而非沿用 580 上限。
    @Environment(\.adaptiveLayoutForm) private var layoutForm
    private var isSplitLayout: Bool {
        AdaptiveLayout.isTwoPane(horizontal: horizontalSizeClass,
                                      vertical: verticalSizeClass, form: layoutForm)
    }
    private var isLargeLayout: Bool {
        AdaptiveLayout.isWide(sizeClass: horizontalSizeClass)
    }
    /// 分栏后左栏只有 55~60% 宽，控件尺寸不能沿用「整屏宽屏」的放大档位。
    /// 字号由 Font.adaptive 统一放大，不受此口径影响。
    private var isRoomyLayout: Bool {
        isLargeLayout && !isSplitLayout
    }
    
    public init(isActive: Bool = true, selectedSubTab: Binding<Int> = .constant(0)) {
        self.isActive = isActive
        self._selectedSubTab = selectedSubTab
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

                // 1.5 常驻坐向锁定与 24 山手动选山控制栏 (P0.1 解决跨 Tab 看盘传感器晃动跳变痛点)
                sittingControlHeader()
                    .padding(.horizontal, isLargeLayout ? 0 : 16)
                
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
            // 分栏态不设固定上限：两栏已按当前有效宽度分配，画板铺满左栏；
            // 单列宽屏仍 1100，合上外屏 / 普通 iPhone 全宽（与手机一致）。
            .frame(maxWidth: isSplitLayout ? .infinity : (isLargeLayout ? 1100 : .infinity))
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 24)
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
        .sheet(isPresented: $showTianJiShuSheet) {
            TianJiShuView()
        }
        .sheet(isPresented: $showDailySignSheet) {
            DailyAuspiciousCardSheet()
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
        .sheet(isPresented: $showMountainPickerSheet) {
            Mountain24PickerSheet(isPresented: $showMountainPickerSheet)
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
                .adaptiveFont(size: 12, weight: selectedSubTab == index ? .bold : .medium)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isRoomyLayout ? 10 : 8)
                .background(selectedSubTab == index ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.clear)
                .foregroundColor(selectedSubTab == index ? .black : .white.opacity(0.75))
        }
    }
    
    // MARK: - P0.1 常驻立极坐向锁定与 24 山手选控制栏 + 今日吉签入口
    private func sittingControlHeader() -> some View {
        let state = motion.headingState
        let pickLabel: String
        let signLabel: String
        switch lang.effectiveLanguage {
        case .en:
            pickLabel = "Pick 24 Mountains"
            signLabel = "Daily Sign"
        case .zhHant:
            pickLabel = "手選24山"
            signLabel = "今日吉籤"
        case .ja:
            pickLabel = "24山選択"
            signLabel = "本日吉籤"
        case .ko:
            pickLabel = "24산 선택"
            signLabel = "오늘 길첨"
        case .vi:
            pickLabel = "Chọn 24 Sơn"
            signLabel = "Thẻ Cát"
        case .th:
            pickLabel = "เลือก 24 ขุนเขา"
            signLabel = "เซียมซี"
        case .id:
            pickLabel = "Pilih 24 Gunung"
            signLabel = "Kartu Hoki"
        case .auto, .zhHans:
            pickLabel = "手选24山"
            signLabel = "今日吉签"
        }

        return HStack(spacing: 8) {
            // 当前坐山朝向与度数（支持点击直接调出 24 山选向弹窗）
            Button(action: {
                showMountainPickerSheet = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: motion.isLocked ? "lock.fill" : "location.north.line.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(motion.isLocked ? Color.red : Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text("\(state.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(state.facingMountain.localizedName)\(lang.t("facing_suffix")) · \(String(format: "%.1f°", state.facingAngle))")
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer(minLength: 4)

            // 锁定 / 解锁盘面按钮
            Button(action: {
                motion.toggleLock()
            }) {
                Text(motion.isLocked ? lang.t("locked_heading") : lang.t("lock_heading"))
                    .adaptiveFont(size: 11, weight: .bold)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(motion.isLocked ? Color.red.opacity(0.22) : Color.white.opacity(0.1))
                    .foregroundColor(motion.isLocked ? .red : .white)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())

            // 24 山手选快速选向按钮（打开 24 山专业选向面板，彻底解决手选无法点击选定问题）
            Button(action: {
                showMountainPickerSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "dial.medium.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(pickLabel)
                        .adaptiveFont(size: 11, weight: .semibold)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.yanCyan.opacity(0.18))
                .foregroundColor(Color.yanCyan)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())

            // 今日吉方日签海报按钮
            Button(action: {
                showDailySignSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(signLabel)
                        .adaptiveFont(size: 11, weight: .semibold)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.2))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(8)
    }

    // MARK: - 天机书宣纸长卷 Banner
    private func tianJiShuBanner() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "scroll.fill")
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(lang.t("tianji_scroll"))
                        .adaptiveFont(size: 13, weight: .bold)
                        .foregroundColor(.white)
                }
                Text(lang.t("xuankong_integrated_title"))
                    .adaptiveFont(size: 10)
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            Button(action: {
                showTianJiShuSheet = true
            }) {
                Text(lang.t("one_click_export"))
                    .adaptiveFont(size: 11, weight: .bold)
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
        // 分栏态（Duo 内屏 / iPad 横屏）：左栏 = 元运切换/格局徽章/九宫飞星排盘，
        // 右栏 = 格局评析与财富/健康/化解建议。independentScroll 让两栏各自滚动，
        // 避免右栏长解释把整页撑长、左栏画板跟着一起滚；折叠态保持原单列纵排。
        FoldableTwoPane(compactSpacing: 14,
                        independentScroll: true) {
            VStack(spacing: 14) {
                periodPickerBar(chart: chart)
                patternBadgeView(chart: chart)
                ninePalacesGrid(chart: chart)
            }
        } analysis: {
            VStack(spacing: 12) {
                analysisCard(chart: chart)
            }
            .padding(.horizontal, isSplitLayout ? 12 : (isLargeLayout ? 0 : 16))
        }
    }
    
    // MARK: - 元运切换栏 (完全根据天文学与干支历法动态推导，杜绝任何硬编码)
    private func periodPickerBar(chart: XuanKongChart) -> some View {
        let curPeriod = FlyingStarsEngine.shared.currentPeriod(for: Date())
        
        return VStack(spacing: 6) {
            Text(chart.periodMeta.label)
                .adaptiveFont(size: 12, weight: .bold)
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
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .fixedSize(horizontal: true, vertical: false)
                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .adaptiveFont(size: 8)
                                }
                            }
                            .adaptiveFont(size: 13, weight: isSelected ? .bold : .medium)
                            // 用最小宽度 + 横向 padding 代替钉死的 44/52/62pt：
                            // 泰语「ยุค」、越南语「vận」等长单位不再被裁成竖排。
                            .frame(minWidth: isLocked ? 62 : 52,
                                   minHeight: isRoomyLayout ? 36 : 32)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
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
                    .adaptiveFont(size: 18, weight: .bold, design: .serif)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(chart.patternType)
                    .adaptiveFont(size: 12, weight: .bold)
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
                            .adaptiveFont(size: 9, weight: .bold)
                        Text(chart.chartModeTitle)
                            .adaptiveFont(size: 11, weight: .semibold)
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
                            .adaptiveFont(size: 10, weight: .bold)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(Color.green)
                            .cornerRadius(4)
                    }
                    if chart.isQiXingDaJie {
                        Text(qiXingDaJieBadgeText())
                            .adaptiveFont(size: 10, weight: .bold)
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
        // 分栏时铺满左栏（两栏已按有效宽度分配），单列宽屏仍 580、手机全宽
        .frame(maxWidth: isSplitLayout ? .infinity : (isLargeLayout ? 580 : .infinity))
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
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(Color.yanCyan)
                Spacer()
                Text("\(cell.facingStar)")
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(Color.orange)
            }
            
            Spacer(minLength: 2)
            
            Text("\(cell.periodStar)")
                .adaptiveFont(size: 22, weight: .bold, design: .serif)
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            
            Spacer(minLength: 2)
            
            HStack {
                Text(cell.localizedPalaceName)
                    .adaptiveFont(size: 9)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(cell.localizedElement)
                    .adaptiveFont(size: 9)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(isRoomyLayout ? 12 : 8)
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
                .adaptiveFont(size: 14, weight: .bold)
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            
            Text(chart.patternDesc)
                .adaptiveFont(size: 13)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
            
            Divider().background(Color.white.opacity(0.1))
            
            if chart.palaces.indices.contains(selectedPalaceIdx) {
                let sel = chart.palaces[selectedPalaceIdx]
                let isDanger25 = (sel.sittingStar == 2 && sel.facingStar == 5) || (sel.sittingStar == 5 && sel.facingStar == 2) || sel.sittingStar == 5 || sel.facingStar == 5
                let isWang = (sel.sittingStar == sel.activePeriod || sel.facingStar == sel.activePeriod || sel.facingStar == 1 || sel.facingStar == 8 || sel.facingStar == 9)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("【\(sel.localizedPalaceName)】")
                            .adaptiveFont(size: 12, weight: .bold)
                            .foregroundColor(Color.yanCyan)
                        Text("\(sel.sittingStar)-\(sel.facingStar) · \(sel.periodStar)")
                            .adaptiveFont(size: 11, weight: .semibold, design: .monospaced)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Spacer()
                        Text(sel.localizedEvaluation)
                            .adaptiveFont(size: 11, weight: .medium)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Text(plainXuanKongSummary(sel: sel, isDanger25: isDanger25, isWang: isWang))
                        .adaptiveFont(size: 11, weight: .semibold)
                        .foregroundColor(isDanger25 ? Color.orange : (isWang ? Color.green : Color.white.opacity(0.85)))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chart.wealthAdvice)
                Text(chart.healthAdvice)
                Text(chart.remedyAdvice)
            }
            .adaptiveFont(size: 11)
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

    private func plainXuanKongSummary(sel: XuanKongPalace, isDanger25: Bool, isWang: Bool) -> String {
        switch lang.effectiveLanguage {
        case .en:
            if isDanger25 {
                return "⚠️ Plain Summary: 2-Black/5-Yellow Sha present here. Keep quiet, avoid red decor or drilling, and hang a 6-coin brass cure."
            } else if isWang {
                return "✅ Plain Summary: Prosperous Mountain/Facing stars (\(sel.sittingStar)-\(sel.facingStar)). Ideal for main door, master bed, or work desk."
            } else {
                return "💡 Plain Summary: Balanced sector (\(sel.sittingStar)-\(sel.facingStar)). Keep bright, ventilated, and tidy."
            }
        case .zhHant:
            if isDanger25 {
                return "⚠️ 【白話速斷】本宮見二黑/五黃煞氣（山\(sel.sittingStar)向\(sel.facingStar)），宜靜不宜動，忌放紅色或動土，建議懸掛六帝銅錢或銅葫蘆化煞。"
            } else if isWang {
                return "✅ 【白話速斷】本宮得當令旺生吉星（山\(sel.sittingStar)向\(sel.facingStar)），氣場生旺，極宜設為入戶門、主臥安床或書桌財位。"
            } else {
                return "💡 【白話速斷】本宮星氣平穩（山\(sel.sittingStar)向\(sel.facingStar)），日常保持採光通風與整潔即可。"
            }
        case .ja:
            if isDanger25 {
                return "⚠️ 【平易解説】二黒・五黄の凶星（山\(sel.sittingStar)・向\(sel.facingStar)）が巡っています。動土や赤い装飾を避け、六帝古銭や銅製ひょうたんで化殺してください。"
            } else if isWang {
                return "✅ 【平易解説】当運の旺星（山\(sel.sittingStar)・向\(sel.facingStar)）が巡る大吉方位です。玄関・主寝室・書斎デスクの配置に最適です。"
            } else {
                return "💡 【平易解説】気場が安定した方位（山\(sel.sittingStar)・向\(sel.facingStar)）です。採光と風通しを良くし清潔に保ちましょう。"
            }
        case .ko:
            if isDanger25 {
                return "⚠️ [쉬운 해설] 이흑·오황 살기(산\(sel.sittingStar)·향\(sel.facingStar))가 비임했습니다. 공사와 붉은색 장식을 피하고 육제동전이나 동호리병으로 화살하세요."
            } else if isWang {
                return "✅ [쉬운 해설] 당령 왕성 길성(산\(sel.sittingStar)·향\(sel.facingStar))이 모인 대길 방위입니다. 현관문, 안방 침대, 책상 재물자리로 매우 좋습니다."
            } else {
                return "💡 [쉬운 해설] 기운이 평온한 방위(산\(sel.sittingStar)·향\(sel.facingStar))입니다. 채광과 환기를 유지하고 정돈해 두세요."
            }
        case .vi:
            if isDanger25 {
                return "⚠️ [Tóm tắt dễ hiểu] Cung này gặp Nhị Hắc/Ngũ Hoàng sát (Sơn \(sel.sittingStar) Hướng \(sel.facingStar)), kỵ động thổ hoặc đồ màu đỏ; nên treo tiền đồng Lục Đế hoặc hồ lô đồng."
            } else if isWang {
                return "✅ [Tóm tắt dễ hiểu] Cung này đón sao đương vượng (Sơn \(sel.sittingStar) Hướng \(sel.facingStar)), rất tốt để đặt cửa chính, giường ngủ hoặc bàn làm việc."
            } else {
                return "💡 [Tóm tắt dễ hiểu] Khí trường bình ổn (Sơn \(sel.sittingStar) Hướng \(sel.facingStar)), chỉ cần giữ thoáng sáng và gọn gàng."
            }
        case .th:
            if isDanger25 {
                return "⚠️ [สรุปเข้าใจง่าย] วังนี้มีดาวร้าย ٢ดำ/٥เหลือง (เขา\(sel.sittingStar)-หน้า\(sel.facingStar)) งดเจาะทุบหรือใช้สีแดง แนะนำแขวนเหรียญจีน ٦ จักรพรรดิหรือน้ำเต้าทองเหลือง"
            } else if isWang {
                return "✅ [สรุปเข้าใจง่าย] วังนี้ได้ดาวมงคลประจำยุค (เขา\(sel.sittingStar)-หน้า\(sel.facingStar)) เหมาะตั้งประตูหลัก เตียงนอน หรือโต๊ะทำงาน"
            } else {
                return "💡 [สรุปเข้าใจง่าย] พลังดาวสมดุล (เขา\(sel.sittingStar)-หน้า\(sel.facingStar)) เพียงรักษาความสะอาดและเปิดรับแสงลม"
            }
        case .id:
            if isDanger25 {
                return "⚠️ [Ringkasan] Sektor ini terkena Sha 2-Hitam/5-Kuning (\(sel.sittingStar)-\(sel.facingStar)). Hindari renovasi & warna merah; gunakan 6 koin logam/labu kuningan."
            } else if isWang {
                return "✅ [Ringkasan] Bintang makmur (\(sel.sittingStar)-\(sel.facingStar)) hadir di sini. Sangat baik untuk pintu utama, ranjang utama, atau meja kerja."
            } else {
                return "💡 [Ringkasan] Energi sektor stabil (\(sel.sittingStar)-\(sel.facingStar)). Jaga tetap terang, rapi, dan berventilasi baik."
            }
        case .auto, .zhHans:
            if isDanger25 {
                return "⚠️ 【白话速断】本宫见二黑/五黄煞气（山\(sel.sittingStar)向\(sel.facingStar)），宜静不宜动，忌放红色或动土，建议悬挂六帝铜钱或铜葫芦化煞。"
            } else if isWang {
                return "✅ 【白话速断】本宫得当令旺生吉星（山\(sel.sittingStar)向\(sel.facingStar)），气场生旺，极宜设为入户门、主卧安床或书桌财位。"
            } else {
                return "💡 【白话速断】本宫星气平稳（山\(sel.sittingStar)向\(sel.facingStar)），日常保持采光通风与整洁即可。"
            }
        }
    }
}

// MARK: - 二十四山专业选向与排盘锁定面板 (Mountain24PickerSheet)

public struct Mountain24PickerSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    
    // 八宫快速分类选择器：0=全部八宫, 1=坎, 2=艮, 3=震, 4=巽, 5=离, 6=坤, 7=兑, 8=乾
    @State private var selectedPalaceFilter: Int = 0

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    private struct PalaceMeta: Identifiable {
        let id: Int
        let name: String
        let directionName: String
        let element: String
        let mountainIndices: [Int]
    }

    private var palaceList: [PalaceMeta] {
        switch lang.effectiveLanguage {
        case .en:
            return [
                PalaceMeta(id: 1, name: "Kan Palace", directionName: "North", element: "Water", mountainIndices: [0, 1, 2]),
                PalaceMeta(id: 2, name: "Gen Palace", directionName: "Northeast", element: "Earth", mountainIndices: [3, 4, 5]),
                PalaceMeta(id: 3, name: "Zhen Palace", directionName: "East", element: "Wood", mountainIndices: [6, 7, 8]),
                PalaceMeta(id: 4, name: "Xun Palace", directionName: "Southeast", element: "Wood", mountainIndices: [9, 10, 11]),
                PalaceMeta(id: 5, name: "Li Palace", directionName: "South", element: "Fire", mountainIndices: [12, 13, 14]),
                PalaceMeta(id: 6, name: "Kun Palace", directionName: "Southwest", element: "Earth", mountainIndices: [15, 16, 17]),
                PalaceMeta(id: 7, name: "Dui Palace", directionName: "West", element: "Metal", mountainIndices: [18, 19, 20]),
                PalaceMeta(id: 8, name: "Qian Palace", directionName: "Northwest", element: "Metal", mountainIndices: [21, 22, 23])
            ]
        case .zhHant:
            return [
                PalaceMeta(id: 1, name: "坎宮", directionName: "正北", element: "水", mountainIndices: [0, 1, 2]),
                PalaceMeta(id: 2, name: "艮宮", directionName: "東北", element: "土", mountainIndices: [3, 4, 5]),
                PalaceMeta(id: 3, name: "震宮", directionName: "正東", element: "木", mountainIndices: [6, 7, 8]),
                PalaceMeta(id: 4, name: "巽宮", directionName: "東南", element: "木", mountainIndices: [9, 10, 11]),
                PalaceMeta(id: 5, name: "離宮", directionName: "正南", element: "火", mountainIndices: [12, 13, 14]),
                PalaceMeta(id: 6, name: "坤宮", directionName: "西南", element: "土", mountainIndices: [15, 16, 17]),
                PalaceMeta(id: 7, name: "兌宮", directionName: "正西", element: "金", mountainIndices: [18, 19, 20]),
                PalaceMeta(id: 8, name: "乾宮", directionName: "西北", element: "金", mountainIndices: [21, 22, 23])
            ]
        case .ja:
            return [
                PalaceMeta(id: 1, name: "坎宮", directionName: "正北", element: "水", mountainIndices: [0, 1, 2]),
                PalaceMeta(id: 2, name: "艮宮", directionName: "北東", element: "土", mountainIndices: [3, 4, 5]),
                PalaceMeta(id: 3, name: "震宮", directionName: "正東", element: "木", mountainIndices: [6, 7, 8]),
                PalaceMeta(id: 4, name: "巽宮", directionName: "南東", element: "木", mountainIndices: [9, 10, 11]),
                PalaceMeta(id: 5, name: "離宮", directionName: "正南", element: "火", mountainIndices: [12, 13, 14]),
                PalaceMeta(id: 6, name: "坤宮", directionName: "南西", element: "土", mountainIndices: [15, 16, 17]),
                PalaceMeta(id: 7, name: "兌宮", directionName: "正西", element: "金", mountainIndices: [18, 19, 20]),
                PalaceMeta(id: 8, name: "乾宮", directionName: "北西", element: "金", mountainIndices: [21, 22, 23])
            ]
        case .ko:
            return [
                PalaceMeta(id: 1, name: "감궁", directionName: "정북", element: "수", mountainIndices: [0, 1, 2]),
                PalaceMeta(id: 2, name: "간궁", directionName: "동북", element: "토", mountainIndices: [3, 4, 5]),
                PalaceMeta(id: 3, name: "진궁", directionName: "정동", element: "목", mountainIndices: [6, 7, 8]),
                PalaceMeta(id: 4, name: "손궁", directionName: "동남", element: "목", mountainIndices: [9, 10, 11]),
                PalaceMeta(id: 5, name: "이궁", directionName: "정남", element: "화", mountainIndices: [12, 13, 14]),
                PalaceMeta(id: 6, name: "곤궁", directionName: "남서", element: "토", mountainIndices: [15, 16, 17]),
                PalaceMeta(id: 7, name: "태궁", directionName: "정서", element: "금", mountainIndices: [18, 19, 20]),
                PalaceMeta(id: 8, name: "건궁", directionName: "북서", element: "금", mountainIndices: [21, 22, 23])
            ]
        case .vi:
            return [
                PalaceMeta(id: 1, name: "Cung Khảm", directionName: "Chính Bắc", element: "Thủy", mountainIndices: [0, 1, 2]),
                PalaceMeta(id: 2, name: "Cung Cấn", directionName: "Đông Bắc", element: "Thổ", mountainIndices: [3, 4, 5]),
                PalaceMeta(id: 3, name: "Cung Chấn", directionName: "Chính Đông", element: "Mộc", mountainIndices: [6, 7, 8]),
                PalaceMeta(id: 4, name: "Cung Tốn", directionName: "Đông Nam", element: "Mộc", mountainIndices: [9, 10, 11]),
                PalaceMeta(id: 5, name: "Cung Ly", directionName: "Chính Nam", element: "Hỏa", mountainIndices: [12, 13, 14]),
                PalaceMeta(id: 6, name: "Cung Khôn", directionName: "Tây Nam", element: "Thổ", mountainIndices: [15, 16, 17]),
                PalaceMeta(id: 7, name: "Cung Đoài", directionName: "Chính Tây", element: "Kim", mountainIndices: [18, 19, 20]),
                PalaceMeta(id: 8, name: "Cung Càn", directionName: "Tây Bắc", element: "Kim", mountainIndices: [21, 22, 23])
            ]
        default:
            return [
                PalaceMeta(id: 1, name: "坎宫", directionName: "正北", element: "水", mountainIndices: [0, 1, 2]),
                PalaceMeta(id: 2, name: "艮宫", directionName: "东北", element: "土", mountainIndices: [3, 4, 5]),
                PalaceMeta(id: 3, name: "震宫", directionName: "正东", element: "木", mountainIndices: [6, 7, 8]),
                PalaceMeta(id: 4, name: "巽宫", directionName: "东南", element: "木", mountainIndices: [9, 10, 11]),
                PalaceMeta(id: 5, name: "离宫", directionName: "正南", element: "火", mountainIndices: [12, 13, 14]),
                PalaceMeta(id: 6, name: "坤宫", directionName: "西南", element: "土", mountainIndices: [15, 16, 17]),
                PalaceMeta(id: 7, name: "兑宫", directionName: "正西", element: "金", mountainIndices: [18, 19, 20]),
                PalaceMeta(id: 8, name: "乾宫", directionName: "西北", element: "金", mountainIndices: [21, 22, 23])
            ]
        }
    }

    private var displayedPalaces: [PalaceMeta] {
        if selectedPalaceFilter == 0 {
            return palaceList
        }
        return palaceList.filter { $0.id == selectedPalaceFilter }
    }

    public var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.15)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    // 1. 顶栏标题与关闭按钮
                    HStack(spacing: 8) {
                        Image(systemName: "dial.medium.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text(dialogTitle)
                            .adaptiveFont(size: 15, weight: .bold)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Text(dialogSubtitle)
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 2. 当前坐山朝向与锁盘状态卡片
                    currentSittingCard

                    // 3. 向首度数微调控制 (支持正向/兼向测试)
                    fineTuningSection

                    // 4. 八宫分类快捷标签栏
                    palaceFilterBar

                    // 5. 二十四山宫位网格
                    VStack(spacing: 12) {
                        ForEach(displayedPalaces) { palace in
                            palaceSection(palace: palace)
                        }
                    }

                    // 6. 底部确认与关闭按钮
                    Button(action: {
                        isPresented = false
                    }) {
                        Text(confirmButtonText)
                            .adaptiveFont(size: 14, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.8, blue: 0.35), Color(red: 0.75, green: 0.55, blue: 0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.black)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                }
                .padding(16)
                .frame(maxWidth: 520)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var palaceFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterPill(id: 0, title: allPalacesText)
                ForEach(palaceList) { p in
                    filterPill(id: p.id, title: "\(p.name) · \(p.directionName)")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterPill(id: Int, title: String) -> some View {
        let isSelected = selectedPalaceFilter == id
        return Button(action: {
            selectedPalaceFilter = id
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(title)
                .adaptiveFont(size: 11, weight: isSelected ? .bold : .medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.yanCyan.opacity(0.28) : Color.white.opacity(0.08))
                .foregroundColor(isSelected ? .yanCyan : .white.opacity(0.85))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.yanCyan : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func palaceSection(palace: PalaceMeta) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(elementColor(for: palace.element))
                    .frame(width: 6, height: 6)
                Text("\(palace.name) （\(palace.directionName) · 五行属\(palace.element)）")
                    .adaptiveFont(size: 12, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(palace.mountainIndices, id: \.self) { idx in
                    let m = Mountain24Data.shared.mountains[idx]
                    mountainTile(mountain: m)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }

    private func mountainTile(mountain m: Mountain24Item) -> some View {
        let facingIdx = (m.id + 12) % 24
        let facingM = Mountain24Data.shared.mountains[facingIdx]
        let isSelected = motion.isLocked && motion.headingState.sittingMountain.id == m.id

        return Button(action: {
            motion.selectSittingMountain(m)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }) {
            VStack(spacing: 3) {
                HStack(spacing: 2) {
                    Text("\(m.localizedName)山\(facingM.localizedName)向")
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                Text("坐\(Int(m.centerAngle))° 向\(Int(facingM.centerAngle))°")
                    .adaptiveFont(size: 9.5)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                Text("\(m.yuan) · \(m.polarity == 1 ? "阳" : "阴")")
                    .adaptiveFont(size: 9)
                    .foregroundColor(isSelected ? Color.yanCyan : .white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.2) : Color.white.opacity(0.06))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func elementColor(for elem: String) -> Color {
        switch elem {
        case "水": return Color.blue
        case "木": return Color.green
        case "火": return Color.red
        case "土": return Color(red: 0.8, green: 0.6, blue: 0.3)
        case "金": return Color(red: 0.95, green: 0.85, blue: 0.45)
        default: return Color.white
        }
    }

    private var currentSittingCard: some View {
        let state = motion.headingState
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: motion.isLocked ? "lock.fill" : "location.north.line.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(motion.isLocked ? Color.red : Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(motion.isLocked ? lockedStatusText : liveSensorStatusText)
                        .adaptiveFont(size: 11, weight: .bold)
                        .foregroundColor(motion.isLocked ? Color.red : Color(red: 0.95, green: 0.85, blue: 0.45))
                }
                Spacer()
                if motion.isLocked {
                    Button(action: {
                        motion.toggleLock()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text(restoreSensorText)
                                .adaptiveFont(size: 10.5, weight: .semibold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .cornerRadius(5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("【\(state.sittingMountain.localizedName)山\(state.facingMountain.localizedName)向】")
                    .adaptiveFont(size: 18, weight: .bold, design: .serif)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))

                Text(state.isJianXiang ? state.fenJinDesc : directAlignmentText)
                    .adaptiveFont(size: 11.5, weight: .medium)
                    .foregroundColor(state.isJianXiang ? Color.orange : Color.green)

                Spacer()

                Text("向首 \(String(format: "%.1f°", state.facingAngle))")
                    .adaptiveFont(size: 14, weight: .bold)
                    .foregroundColor(.white)
            }

            Text("坐山方位: \(state.sittingMountain.localizedPalace)宫 · \(String(format: "%.1f°", state.sittingAngle)) · 对应八宅【\(state.sittingMountain.palace)宅】等智能分房与玄空盘")
                .adaptiveFont(size: 10.5)
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(12)
        .background(Color(red: 0.13, green: 0.14, blue: 0.19))
        .cornerRadius(10)
    }

    private var fineTuningSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text(fineTuneTitle)
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("向首: \(String(format: "%.1f°", motion.headingState.facingAngle))")
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(Color.yanCyan)
            }

            HStack(spacing: 6) {
                fineTuneButton(delta: -5, label: "-5°")
                fineTuneButton(delta: -1, label: "-1°")
                fineTuneButton(delta: -0.5, label: "-0.5°")
                fineTuneButton(delta: +0.5, label: "+0.5°")
                fineTuneButton(delta: +1, label: "+1°")
                fineTuneButton(delta: +5, label: "+5°")
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private func fineTuneButton(delta: Double, label: String) -> some View {
        Button(action: {
            motion.adjustLockedAngle(delta: delta)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            Text(label)
                .adaptiveFont(size: 11, weight: .bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white.opacity(0.9))
                .cornerRadius(5)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var dialogTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Pick 24 Mountains · Static Chart"
        case .zhHant: return "二十四山精確選向 · 靜態排盤"
        case .ja: return "24山・坐向指定（静的排盤）"
        case .ko: return "24산 지정 및 정적 배반"
        case .vi: return "Chọn 24 Sơn · Khóa Hướng"
        case .th: return "เลือก 24 ขุนเขา · จัดฮวงจุ้ย"
        case .id: return "Pilih 24 Gunung · Kunci Arah"
        case .auto, .zhHans: return "二十四山精确选向 · 静态排盘"
        }
    }

    private var dialogSubtitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Select any sitting mountain to lock heading for static analysis across Xuan Kong, Ba Zhai, Purple White and Qi Men."
        case .zhHant: return "點擊任意坐向直接鎖定盤面。無論是勘察遠方戶型還是靜態推演，均可精準核算八宅明鏡、玄空九星、紫白飛星與奇門遁甲。"
        case .ja: return "任意の坐向を選択して盤面を固定。玄空飛星・八宅・紫白・奇門遁甲を静的に診断できます。"
        case .ko: return "좌향을 선택하여 나침반을 고정하고 현공구성, 팔택, 자백비성 및 기문둔갑을 분석하세요."
        case .vi: return "Chọn tọa hướng bất kỳ để khóa la bàn, giải đoán Huyền Không, Bát Trạch, Tử Bạch và Kỳ Môn."
        case .th: return "เลือกรหัส 24 ขุนเขาเพื่อล็อคทิศทาง วิเคราะห์ดาวบิน ฮวงจุ้ยแปดทิศ และฉีเหมิน"
        case .id: return "Pilih arah 24 gunung untuk mengunci kompas dan menganalisis Xuan Kong, Ba Zhai, dan Qi Men."
        case .auto, .zhHans: return "点击任意坐向直接锁定盘面。无论是勘察远方户型还是静态推演，均可精准核算八宅明镜、玄空九星、紫白飞星与奇门遁甲。"
        }
    }

    private var lockedStatusText: String {
        switch lang.effectiveLanguage {
        case .en: return "Locked Static Chart"
        case .zhHant: return "已鎖定靜態排盤"
        case .ja: return "静的排盤固定中"
        case .ko: return "정적 배반 고정됨"
        case .vi: return "Đã Khóa Tĩnh"
        case .th: return "ล็อคทิศทางแล้ว"
        case .id: return "Terkunci Statis"
        case .auto, .zhHans: return "已锁定静态排盘"
        }
    }

    private var liveSensorStatusText: String {
        switch lang.effectiveLanguage {
        case .en: return "Live Sensor Active"
        case .zhHant: return "傳感器實時聯動中"
        case .ja: return "センサー連動中"
        case .ko: return "센서 실시간 연동 중"
        case .vi: return "Đang theo cảm biến"
        case .th: return "เชื่อมต่อเซนเซอร์"
        case .id: return "Sensor Aktif"
        case .auto, .zhHans: return "传感器实时联动中"
        }
    }

    private var restoreSensorText: String {
        switch lang.effectiveLanguage {
        case .en: return "Restore Sensor"
        case .zhHant: return "恢復實時聯動"
        case .ja: return "センサーに戻す"
        case .ko: return "센서 연동 복구"
        case .vi: return "Mở khóa cảm biến"
        case .th: return "คืนค่าเซนเซอร์"
        case .id: return "Buka Kunci Sensor"
        case .auto, .zhHans: return "恢复实时联动"
        }
    }

    private var directAlignmentText: String {
        switch lang.effectiveLanguage {
        case .en: return "Direct Alignment"
        case .zhHant, .ja: return "正針下卦"
        case .ko: return "정침하괘"
        case .vi: return "Chính Châm Hạ Quái"
        case .th: return "ทิศตรงหลัก"
        case .id: return "Arah Lurus"
        case .auto, .zhHans: return "正针下卦"
        }
    }

    private var fineTuneTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Facing Angle Fine-Tuning"
        case .zhHant: return "向首度數微調（正針下卦/兼向替卦測試）"
        case .ja: return "向首角度の微調整（下卦・替卦テスト）"
        case .ko: return "향수 각도 미세조정 (하괘/겸향 테스트)"
        case .vi: return "Vi chỉnh góc hướng (Hạ quái / Thế quái)"
        case .th: return "ปรับองศาอย่างละเอียด"
        case .id: return "Penyesuaian Sudut Hadap"
        case .auto, .zhHans: return "向首度数微调（正针下卦/兼向替卦测试）"
        }
    }

    private var allPalacesText: String {
        switch lang.effectiveLanguage {
        case .en: return "All 24 Mountains"
        case .zhHant: return "全部（24山）"
        case .ja: return "全24山"
        case .ko: return "전체 (24산)"
        case .vi: return "Tất cả (24 Sơn)"
        case .th: return "ทั้งหมด (24 ขุนเขา)"
        case .id: return "Semua (24 Gunung)"
        case .auto, .zhHans: return "全部（24山）"
        }
    }

    private var confirmButtonText: String {
        switch lang.effectiveLanguage {
        case .en: return "Confirm & View Charts"
        case .zhHant: return "選定坐向並返回排盤"
        case .ja: return "決定して排盤を確認"
        case .ko: return "좌향 선택 및 배반 확인"
        case .vi: return "Xác Nhận & Xem 排 Bàn"
        case .th: return "ยืนยันและดูผลวิเคราะห์"
        case .id: return "Konfirmasi & Lihat Bagan"
        case .auto, .zhHans: return "选定坐向并返回排盘"
        }
    }
}
