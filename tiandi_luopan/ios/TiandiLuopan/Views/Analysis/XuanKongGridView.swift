import SwiftUI

// MARK: - 原生玄空理气与三式绝学全景视图 (XuanKong, BaZhai, PurpleWhite & QiMen View)

public struct XuanKongGridView: View {
    public var isActive: Bool = true
    /// 旧子页索引保留给已有链接；首页与新导航使用功能菜单。
    @Binding public var selectedSubTab: Int
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @ObservedObject private var workspace = FloorplanWorkspaceStore.shared
    @ObservedObject private var surveyStore = ShaSurveyStore.shared
    @State private var analyzeHome = false
    @State private var didChooseSource = false
    @State private var analysisDate = Date()
    @State private var followsToday = true
    @State private var cachedDeepAnalysis: XuanKongDeepAnalysis?
    @State private var lastAnalysisSnapshot: TianJiAnalysisSnapshot?
    private var homeLayout: SavedFloorplanLayout? {
        workspace.snapshot.propertyID == surveyStore.propertyID ? workspace.snapshot.layout : nil
    }
    private var homeFacing: Double? {
        XuanKongHomeContextBuilder.facing(layout: homeLayout, survey: surveyStore.latestInterior)
    }
    private var analysisHeading: CompassHeadingState {
        if analyzeHome, let heading = homeFacing {
            return Mountain24Data.shared.resolveHeadingState(heading: heading, pitch: motion.pitch, roll: motion.roll)
        }
        return motion.headingState
    }
    @State private var selectedPeriod: Int = FlyingStarsEngine.shared.currentPeriod(for: Date())
    // 手动替卦锁定：nil=跟随传感器 isJianXiang；非 nil=用户手动指定，传感器不再覆盖。
    // 换坐/向山后重置回跟随，避免用户已看清的盘被高频传感器样本突然改写。
    @State private var starMode = FlyingStarModeSelection()
    private var useTiGua: Bool { starMode.usesTiGua(automatic: analysisHeading.isJianXiang) }
    @Binding private var featureRequest: AnalysisFeatureRequest?
    @State private var selectedFeature: AnalysisFeature?
    @State private var toolRequest: AnalysisToolRequest?
    @State private var reportSnapshot: TianJiAnalysisSnapshot?
    @State private var showTianJiShuSheet: Bool = false
    @State private var showDailySignSheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showMountainPickerSheet: Bool = false
    @State private var cachedChart: XuanKongChart?
    @State private var selectedPalaceIdx: Int = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    
    public init(isActive: Bool = true, selectedSubTab: Binding<Int> = .constant(0),
                featureRequest: Binding<AnalysisFeatureRequest?> = .constant(nil)) {
        self.isActive = isActive
        self._selectedSubTab = selectedSubTab
        self._featureRequest = featureRequest
    }
    
    public var body: some View {
        // The other three sub-tabs have their own engines. Avoid rebuilding
        // the complete nine-palace flying-star chart for every compass sample
        // while one of those tabs is active.
        let chart: XuanKongChart? = isActive && selectedFeature == .xuanKong
            ? (cachedChart ?? FlyingStarsEngine.shared.calculateChart(
                period: selectedPeriod,
                sitting: analysisHeading.sittingMountain,
                facing: analysisHeading.facingMountain,
                useTiGua: useTiGua, date: analysisDate
            ))
            : nil
        
        ScrollViewReader { scroll in
        ScrollView {
            if isActive {
                VStack(spacing: 14) {
                Color.clear.frame(height: 1).id("analysisRootTop")
                if let feature = selectedFeature {
                    HStack {
                        Button(action: { selectedFeature = nil; cachedChart = nil }) {
                            Label(lang.t("analysis_back_menu"), systemImage: "chevron.left")
                                .adaptiveFont(size: 13, weight: .semibold)
                                .foregroundColor(Color.yanCyan)
                                .frame(minHeight: 44)
                        }
                        Spacer()
                        Text(lang.t(feature.titleKey))
                            .adaptiveFont(size: 15, weight: .bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    if feature == .xuanKong { analysisSourceBar().padding(.horizontal, 16) }
                    sittingControlHeader()
                        .padding(.horizontal, isLargeLayout ? 0 : 16)
                    switch feature {
                    case .xuanKong:
                        if let chart { xuanKongContent(chart: chart) }
                    case .baZhai, .sanHe:
                        BaZhaiView(isEmbedded: true, isActive: isActive,
                                   section: feature == .sanHe ? .water : .house, showsSectionPicker: false)
                            .id(feature)
                    case .purpleWhite:
                        PurpleWhiteView(isActive: isActive)
                    case .qimen:
                        QimenDunjiaView(isActive: isActive)
                    case .owner, .dates:
                        EmptyView()
                    }
                } else {
                    analysisMenu()
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
        .onChange(of: selectedFeature) { _ in
            scroll.scrollTo("analysisRootTop", anchor: .top)
        }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
        .sheet(isPresented: $showTianJiShuSheet) {
            if let reportSnapshot { TianJiShuView(analysis: reportSnapshot) }
        }
        .sheet(isPresented: $showDailySignSheet) {
            DailyAuspiciousCardSheet(targetDate: selectedFeature == .xuanKong ? analysisDate : Date(),
                                    headingState: analysisHeading)
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
        .sheet(isPresented: $showMountainPickerSheet) {
            Mountain24PickerSheet(isPresented: $showMountainPickerSheet)
        }
        .sheet(item: $toolRequest) { item in
            switch item.tool {
            case .owner: OwnerLifeGuaView(context: item.context)
            case .dates: CelestialDateSelectionView(context: item.context, propertyKey: item.propertyKey)
            }
        }
        .onAppear {
            if followsToday { analysisDate = Date() }
            consumeFeatureRequest()
            refreshChart()
        }
        .onChange(of: featureRequest?.id) { _ in consumeFeatureRequest() }
        .onChange(of: isActive) { _ in
            if isActive && followsToday { analysisDate = Date() }
            consumeFeatureRequest()
            refreshChart()
        }
        .onChange(of: selectedSubTab) { _ in
            refreshChart()
        }
        .onChange(of: selectedPeriod) { _ in
            refreshChart()
        }
        .onChange(of: analyzeHome) { _ in starMode.restoreAutomatic(); refreshChart() }
        .onChange(of: analysisDate) { _ in refreshChart() }
        .onChange(of: workspace.snapshot.revision) { _ in refreshChart() }
        .onChange(of: surveyStore.propertyID) { _ in
            lastAnalysisSnapshot = nil
            if homeFacing == nil { analyzeHome = false }
            cachedChart = nil
            starMode.restoreAutomatic()
            refreshChart()
        }
        .onReceive(surveyStore.objectWillChange) { _ in
            // @Published emits before the value changes. Read one coherent property snapshot next run loop.
            DispatchQueue.main.async { refreshChart() }
        }
        .onChange(of: useTiGua) { _ in
            refreshChart()
        }
        .onChange(of: analysisHeading.isJianXiang) { isJian in
            // 仅跟随模式（用户未手动锁定）下才随传感器切换下卦/替卦。
            guard starMode.manualOverride == nil else { return }
            refreshChart()
        }
        .onChange(of: analysisHeading.sittingMountain.id) { _ in
            starMode.restoreAutomatic()
            refreshChart()
        }
        .onChange(of: analysisHeading.facingMountain.id) { _ in
            starMode.restoreAutomatic()
            refreshChart()
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            refreshChart()
        }
        .onReceive(Self.periodRefreshTimer) { _ in
            guard isActive else { return }
            if followsToday { analysisDate = Date() }
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
        guard isActive, selectedFeature == .xuanKong else {
            cachedChart = nil
            cachedDeepAnalysis = nil
            return
        }
        let isFirstChart = cachedChart == nil
        let snapshot = captureAnalysis()
        let updated = snapshot.flyingStarsChart()
        let deep = snapshot.deepAnalysis(chart: updated)
        lastAnalysisSnapshot = snapshot
        if isFirstChart { selectedPalaceIdx = deep.priorities.first?.id ?? 4 }
        cachedDeepAnalysis = deep
        cachedChart = updated
    }

    private func captureAnalysis() -> TianJiAnalysisSnapshot {
        let usesHome = analyzeHome && homeFacing != nil
        let heading = usesHome ? (homeFacing ?? motion.headingState.facingAngle) : motion.headingState.facingAngle
        let headingState = Mountain24Data.shared.resolveHeadingState(heading: heading)
        let context = analyzeHome && homeFacing != nil
            ? XuanKongHomeContextBuilder.build(layout: homeLayout, survey: surveyStore.latestInterior,
                exterior: surveyStore.records, facts: surveyStore.siteFacts) : nil
        let report = usesHome ? homeLayout.map { layout in
            FloorplanEngine.shared.auditFloorplan(rooms: layout.rooms,
                centroid: CGPoint(x: layout.centroidX, y: layout.centroidY), heading: layout.compassRotation,
                aspectRatio: CGFloat(layout.aspectRatio ?? 1), date: analysisDate).report
        } ?? [] : []
        return TianJiAnalysisSnapshot(heading: heading, period: selectedPeriod,
            useTiGua: starMode.usesTiGua(automatic: headingState.isJianXiang), reportDate: analysisDate)
            .capturing(context: context, propertyKey: usesHome ? surveyStore.propertyKey : nil,
                floorplanReport: report, panoramaArchive: usesHome ? surveyStore.archive : nil)
    }
    
    private func consumeFeatureRequest() {
        guard isActive, let request = featureRequest else { return }
        featureRequest = nil
        openFeature(request.feature)
    }

    private func openFeature(_ feature: AnalysisFeature) {
        if feature == .owner || feature == .dates {
            toolRequest = AnalysisToolRequest(tool: feature == .owner ? .owner : .dates, context: analysisHeading)
        } else {
            if feature == .xuanKong && !didChooseSource {
                analyzeHome = homeFacing != nil
                didChooseSource = true
            }
            selectedFeature = feature
            selectedSubTab = feature.legacySubTab ?? 0
            refreshChart()
        }
    }

    private func analysisMenu() -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(lang.t("analysis_menu_title"))
                    .adaptiveFont(size: 25, weight: .bold)
                    .foregroundColor(.white)
            }
            sittingControlHeader()
            menuGroup(title: lang.t("analysis_group_house"), features: [.xuanKong, .baZhai, .sanHe])
            menuGroup(title: lang.t("analysis_group_people"), features: [.owner])
            menuGroup(title: lang.t("analysis_group_time"), features: [.dates, .purpleWhite, .qimen])
            Text(lang.t("analysis_group_report"))
                .adaptiveFont(size: 14, weight: .bold)
                .foregroundColor(Color.yanGold)
            tianJiShuBanner()
        }
        .padding(.horizontal, 16)
    }

    private func menuGroup(title: String, features: [AnalysisFeature]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .adaptiveFont(size: 14, weight: .bold)
                .foregroundColor(Color.yanGold)
            ForEach(features) { feature in
                Button(action: { openFeature(feature) }) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 22))
                            .foregroundColor(Color.yanCyan)
                            .frame(width: 30)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(lang.t(feature.titleKey))
                                .adaptiveFont(size: 15, weight: .bold)
                                .foregroundColor(.white)
                            Text(lang.t(feature.subtitleKey))
                                .adaptiveFont(size: 12)
                                .foregroundColor(.white.opacity(0.65))
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if feature.requiresVIP {
                            Label(lang.t("vip_badge_title"), systemImage: iap.hasUnlockedVIP ? "crown.fill" : "lock.fill")
                                .adaptiveFont(size: 10, weight: .bold)
                                .foregroundColor(Color.yanGold)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - P0.1 常驻立极坐向锁定与 24 山手选控制栏 + 今日吉签入口
    private func sittingControlHeader() -> some View {
        let usesHome = (selectedFeature == .xuanKong || selectedFeature == nil) && analyzeHome && homeFacing != nil
        let state = usesHome ? analysisHeading : motion.headingState
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
                if usesHome { AppNavigationRouter.shared.requestRoute(tab: 2) }
                else { showMountainPickerSheet = true }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: usesHome ? "house.fill" : (motion.isLocked ? "lock.fill" : "location.north.line.fill"))
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

            if !usesHome {
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
                    analyzeHome = false
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
            }

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
                reportSnapshot = lastAnalysisSnapshot ?? captureAnalysis()
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
                if isSplitLayout {
                    ninePalacesGrid(chart: chart)
                } else {
                    DisclosureGroup(lang.t("xkd_chart")) {
                        ninePalacesGrid(chart: chart).padding(.top, 8)
                    }
                    .adaptiveFont(size: 12)
                    .foregroundColor(Color.yanCyan)
                    .padding(.horizontal, 16)
                }
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
                
                Text(chart.patternType.components(separatedBy: " (").first ?? chart.patternType)
                    .adaptiveFont(size: 12, weight: .bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(Color.orange)
                    .cornerRadius(6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Button(action: {
                    starMode.toggle(automatic: analysisHeading.isJianXiang)
                    // 手动切换后锁定该选择，传感器 isJianXiang 不再覆盖；
                    // 换坐/向山后自动回到跟随模式。
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
                Button(action: { selectGuidancePalace(cell.id) }) {
                    palaceCellView(cell: cell)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cell.plainDirectionName + ", " + lang.t(cell.suggestedUse.titleKey))
                .accessibilityAddTraits(cell.id == selectedPalaceIdx ? .isSelected : [])
            }
        }
        // 分栏时铺满左栏（两栏已按有效宽度分配），单列宽屏仍 580、手机全宽
        .frame(maxWidth: isSplitLayout ? .infinity : (isLargeLayout ? 580 : .infinity))
        .padding(.horizontal, isLargeLayout ? 0 : 16)
    }
    
    private func palaceCellView(cell: XuanKongPalace) -> some View {
        let use = cell.suggestedUse
        let isSelected = cell.id == selectedPalaceIdx
        let borderColor = isSelected ? Color.yanCyan : (use == .quiet ? Color.orange : (use == .separateUses ? Color.yanGold : Color.white.opacity(0.12)))
        let bgColor = use == .quiet ? Color.orange.opacity(0.1) : Color(red: 0.12, green: 0.12, blue: 0.16)
        
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
                .stroke(borderColor, lineWidth: (isSelected || use == .quiet || use == .separateUses) ? 1.5 : 1)
        )
    }
    
    private func analysisSourceBar() -> some View {
        VStack(spacing: 8) {
            Picker(lang.t("xkd_source"), selection: $analyzeHome) {
                Text(lang.t("xkd_source_compass")).tag(false)
                if homeFacing != nil { Text(lang.t("xkd_source_home")).tag(true) }
            }
            .pickerStyle(.segmented)
            HStack {
                DatePicker(lang.t("xkd_date"), selection: Binding(get: { analysisDate }, set: {
                    followsToday = false
                    analysisDate = $0
                }), displayedComponents: [.date, .hourAndMinute])
                .adaptiveFont(size: 12)
                Button(lang.t("xkd_today")) { followsToday = true; analysisDate = Date() }
                    .foregroundColor(followsToday ? Color.yanGold : Color.yanCyan)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .foregroundColor(.white)
        }
    }

    // MARK: - 结论、位置、行动；依据按需展开
    private func analysisCard(chart: XuanKongChart) -> some View {
        let analysis = cachedDeepAnalysis ?? XuanKongDeepAnalyzer.analyze(chart: chart, date: analysisDate)
        return VStack(alignment: .leading, spacing: 14) {
            Text(lang.t(analysis.summaryKey))
                .adaptiveFont(size: 18, weight: .bold)
                .foregroundColor(.white)
            VStack(alignment: .leading, spacing: 8) {
                Text(lang.t("xk_guide_priority"))
                    .adaptiveFont(size: 11, weight: .semibold)
                    .foregroundColor(.white.opacity(0.7))
                HStack(spacing: 8) {
                    ForEach(Array(analysis.priorities.prefix(3))) { sector in
                        Button(action: { selectGuidancePalace(sector.id) }) {
                            Label(chart.palaces.first { $0.id == sector.id }?.plainDirectionName ?? "",
                                  systemImage: sector.use.symbol)
                                .adaptiveFont(size: 11, weight: .bold)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.horizontal, 4)
                                .background(guidanceColor(sector.use).opacity(0.15))
                                .foregroundColor(guidanceColor(sector.use))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            guidanceMap(chart: chart, analysis: analysis)
            if let selected = chart.palaces.first(where: { $0.id == selectedPalaceIdx }),
               let sector = analysis.sectors.first(where: { $0.id == selected.id }) {
                sectorActionCard(cell: selected, sector: sector)
                if analyzeHome { siteFactsEditor(palaceID: selected.id) }
            }
            ForEach(analysis.patternChecks) { check in
                DisclosureGroup {
                    Text(check.palaceIDs.compactMap { id in chart.palaces.first { $0.id == id }?.plainDirectionName }.joined(separator: " · "))
                    Text(lang.t(check.actionKey)).padding(.top, 6)
                } label: {
                    Text(lang.t(check.titleKey) + " · " + lang.t(check.statusKey))
                }
                .adaptiveFont(size: 12)
                .foregroundColor(Color.yanCyan)
            }
            if !analysis.missingKeys.isEmpty || !analysis.warningKeys.isEmpty {
                homeDataLinks(analysis: analysis)
            }
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    Text(lang.t(chart.pattern.titleKey)).bold()
                    Text(lang.t(chart.pattern.explanationKey))
                    Text(lang.t("xk_guide_terms"))
                    if let cell = chart.palaces.first(where: { $0.id == selectedPalaceIdx }),
                       let sector = analysis.sectors.first(where: { $0.id == cell.id }) {
                        sectorEvidence(cell: cell, sector: sector)
                        sourceEvidence(chart: chart, cell: cell, sector: sector)
                    }
                    Text(lang.t("ref_scope_note"))
                        .foregroundColor(.white.opacity(0.55))
                }
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
            } label: {
                Text(lang.t("xkd_evidence"))
                    .adaptiveFont(size: 12, weight: .medium)
                    .foregroundColor(Color.yanCyan)
            }
            .accentColor(Color.yanCyan)
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func homeDataLinks(analysis: XuanKongDeepAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(analysis.warningKeys, id: \.self) { key in
                Text(lang.t(key)).foregroundColor(.orange)
            }
            if !analysis.missingKeys.isEmpty {
                Text(lang.t("xkd_missing") + analysis.missingKeys.map { lang.t($0) }.joined(separator: " / "))
                    .foregroundColor(.white.opacity(0.6))
            }
            HStack {
                Button(lang.t("xkd_edit_home")) { AppNavigationRouter.shared.requestRoute(tab: 2) }
                Spacer()
                Button(lang.t("xkd_edit_exterior")) { AppNavigationRouter.shared.requestRoute(tab: 1) }
            }
            .foregroundColor(Color.yanCyan)
            .frame(minHeight: 44)
        }
        .adaptiveFont(size: 11)
    }

    private func siteFactsEditor(palaceID: Int) -> some View {
        let propertyID = surveyStore.propertyID
        return DisclosureGroup {
            Text(lang.t("xkd_facts_hint"))
                .adaptiveFont(size: 11).foregroundColor(.white.opacity(0.55))
            ForEach(XuanKongSiteFactKind.allCases, id: \.self) { kind in
                Toggle(lang.t(kind.titleKey), isOn: Binding(get: {
                    surveyStore.siteFacts.contains { $0.palaceID == palaceID && $0.kind == kind }
                }, set: { present in
                    surveyStore.setSiteFact(kind, palaceID: palaceID, present: present, propertyID: propertyID)
                }))
                .tint(Color.yanCyan)
                .frame(minHeight: 44)
            }
        } label: {
            Text(lang.t("xkd_facts"))
        }
        .adaptiveFont(size: 12)
        .foregroundColor(.white.opacity(0.85))
    }

    private func sectorEvidence(cell: PalaceCell, sector: XuanKongSectorAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(lang.t("xkd_natal")) \(cell.periodStar) · \(cell.mountainStar) / \(cell.facingStar)")
            Text("\(lang.t("xkd_annual")) \(sector.yearStar) · \(lang.t("xkd_monthly")) \(sector.monthStar)")
            ForEach(Array(sector.pairs.enumerated()), id: \.offset) { index, pair in
                Text(lang.t(["xkd_pair_natal", "xkd_pair_m_year", "xkd_pair_f_year", "xkd_pair_m_month", "xkd_pair_f_month", "xkd_pair_guests"][index])
                     + " \(pair.first) / \(pair.second) · " + lang.t(pair.relation.titleKey))
            }
            ForEach(sector.reasonKeys, id: \.self) { Text(lang.t($0)) }
            ForEach(sector.places) { place in
                Text(place.name + (place.kind == .room ? " · \(place.coverage)%" : ""))
            }
            ForEach(sector.exterior) { record in
                Text((ExteriorShaEngine.shared.database.first { $0.id == record.shaID }?.localizedName ?? record.shaID)
                     + " · " + String(format: "%.0f°", record.bearingDegrees)
                     + (record.distanceMeters.map { String(format: " · %.1fm", Double($0)) } ?? ""))
            }
            Text(lang.t("xkd_coverage_hint"))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func sourceEvidence(chart: XuanKongChart, cell: PalaceCell, sector: XuanKongSectorAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(chart.sourceReferences(palaceID: cell.id, yearStar: sector.yearStar, monthStar: sector.monthStar)) { reference in
                VStack(alignment: .leading, spacing: 4) {
                    Text(reference.localizedText)
                    if let sourceURL = reference.sourceURL {
                        Link(lang.t("ref_read_original"), destination: sourceURL)
                            .foregroundColor(Color.yanCyan)
                    }
                }
            }
        }
    }

    private func selectGuidancePalace(_ id: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            selectedPalaceIdx = id
        }
    }

    private func guidanceColor(_ use: XuanKongSectorUse) -> Color {
        switch use {
        case .quiet: return .orange
        case .separateUses: return Color(red: 0.8, green: 0.67, blue: 1)
        case .activity: return .yanGold
        case .rest: return .yanCyan
        case .everyday: return .white.opacity(0.7)
        }
    }

    private func guidanceMap(chart: XuanKongChart, analysis: XuanKongDeepAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(lang.t("xk_guide_map"), systemImage: "square.grid.3x3.fill")
                .adaptiveFont(size: 13, weight: .bold)
                .foregroundColor(.white)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(gridDisplayOrder, id: \.self) { id in
                    if let cell = chart.palaces.first(where: { $0.id == id }),
                       let sector = analysis.sectors.first(where: { $0.id == id }) {
                        guidanceMapCell(cell: cell, chart: chart, sector: sector)
                    }
                }
            }
        }
    }

    private func guidanceMapCell(cell: PalaceCell, chart: XuanKongChart, sector: XuanKongSectorAnalysis) -> some View {
        let use = sector.use
        let selected = selectedPalaceIdx == cell.id
        let color = guidanceColor(use)
        return Button(action: { selectGuidancePalace(cell.id) }) {
            VStack(spacing: 5) {
                Text(cell.plainDirectionName)
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(.white)
                Image(systemName: use.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
                    .accessibilityHidden(true)
                Text(lang.t(use.titleKey))
                    .adaptiveFont(size: 10, weight: .semibold)
                    .foregroundColor(color)
                    .fixedSize(horizontal: false, vertical: true)
                if let place = sector.places.first(where: { $0.kind == .bed || $0.kind == .stove || $0.kind == .entrance })
                    ?? sector.places.first {
                    Text(place.name)
                        .adaptiveFont(size: 9)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                }
                if cell.id == chart.facingPalaceID || cell.id == chart.sittingPalaceID {
                    Text(lang.t(cell.id == chart.facingPalaceID ? "xk_guide_front" : "xk_guide_back"))
                        .adaptiveFont(size: 9)
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 105)
            .background(color.opacity(selected ? 0.2 : 0.08))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? color : Color.white.opacity(0.08), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cell.plainDirectionName + ", " + lang.t(use.titleKey))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func sectorActionCard(cell: PalaceCell, sector: XuanKongSectorAnalysis) -> some View {
        let use = sector.use
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: use.symbol)
                    .foregroundColor(guidanceColor(use))
                    .font(.system(size: 22))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(cell.plainDirectionName)
                        .adaptiveFont(size: 17, weight: .bold)
                        .foregroundColor(.white)
                    Text(lang.t(use.titleKey))
                        .adaptiveFont(size: 12, weight: .semibold)
                        .foregroundColor(guidanceColor(use))
                }
                Spacer(minLength: 0)
            }
            if !sector.places.isEmpty {
                Text(Array(Set(sector.places.map(\.name))).sorted().joined(separator: " · "))
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.65))
            }
            ForEach(Array(sector.actions.prefix(3)), id: \.self) { action in
                Label(lang.t(action.textKey), systemImage: "checkmark.circle.fill")
                    .adaptiveFont(size: 12)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if sector.actions.count > 3 {
                DisclosureGroup(lang.t("xkd_more_actions")) {
                    ForEach(Array(sector.actions.dropFirst(3)), id: \.self) { action in
                        Text(lang.t(action.textKey)).padding(.top, 6)
                    }
                }
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(guidanceColor(use).opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(guidanceColor(use).opacity(0.35), lineWidth: 1))
    }

    private func sanBanGuaBadgeText() -> String { lang.t("xkd_sanban") }
    private func qiXingDaJieBadgeText() -> String { lang.t("xkd_qixing") }


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
