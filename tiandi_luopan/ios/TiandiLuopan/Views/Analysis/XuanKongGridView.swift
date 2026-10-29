import SwiftUI

// MARK: - 原生玄空理气与三式绝学全景视图 (XuanKong, BaZhai, PurpleWhite & QiMen View)

public struct XuanKongGridView: View {
    public var isActive: Bool = true
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var selectedSubTab: Int = 0 // 0: 玄空九星, 1: 八宅三合, 2: 紫白客星, 3: 时家奇门
    @State private var selectedPeriod: Int = FlyingStarsEngine.shared.currentPeriod(for: Date())
    @State private var showTianJiShuSheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var cachedChart: XuanKongChart?
    
    // 九宫格九个方位的标准九宫排布对应 (从左到右，从上到下：东南4、正南9、西南2；正东3、中宫5、正西7；东北8、正北1、西北6)
    private let gridDisplayOrder = [3, 8, 1, 2, 4, 6, 7, 0, 5]
    
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
                facing: motion.headingState.facingMountain
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
                    BaZhaiView(isEmbedded: true)
                } else if selectedSubTab == 2 {
                    // 板块 3: 紫白飞星流年流月客星与太岁三煞
                    PurpleWhiteView()
                } else {
                    // 板块 4: 三式绝学时家奇门遁甲全息排盘
                    QimenDunjiaView()
                }
            }
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
        .onChange(of: motion.headingState.sittingMountain.id) { _ in
            refreshChart()
        }
        .onChange(of: motion.headingState.facingMountain.id) { _ in
            refreshChart()
        }
        .onChange(of: lang.effectiveLanguage) { _ in
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
            facing: motion.headingState.facingMountain
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
        .padding(.horizontal, 16)
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            selectedSubTab = index
        }) {
            Text(title)
                .font(.system(size: 12, weight: selectedSubTab == index ? .bold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
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
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(lang.t("xuankong_integrated_title"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            Button(action: {
                showTianJiShuSheet = true
            }) {
                Text(lang.t("one_click_export"))
                    .font(.system(size: 11, weight: .bold))
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
    }
    
    // MARK: - 玄空九星排盘内容
    private func xuanKongContent(chart: XuanKongChart) -> some View {
        VStack(spacing: 14) {
            periodPickerBar(chart: chart)
            patternBadgeView(chart: chart)
            ninePalacesGrid(chart: chart)
                .padding(.horizontal, 16)
            analysisCard(chart: chart)
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 元运切换栏 (完全根据天文学与干支历法动态推导，杜绝任何硬编码)
    private func periodPickerBar(chart: XuanKongChart) -> some View {
        let curPeriod = FlyingStarsEngine.shared.currentPeriod(for: Date())
        
        return VStack(spacing: 6) {
            Text(chart.periodMeta.label)
                .font(.system(size: 12, weight: .bold))
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
                                        .font(.system(size: 8))
                                }
                            }
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .frame(width: isLocked ? 52 : 44, height: 32)
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
    
    // MARK: - 格局徽章
    private func patternBadgeView(chart: XuanKongChart) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text("\(chart.sittingMountain)\(lang.t("mountain_suffix"))\(chart.facingMountain)\(lang.t("facing_suffix"))")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(chart.patternType)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(Color.orange)
                    .cornerRadius(6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
            }
        }
    }
    
    private func palaceCellView(cell: XuanKongPalace) -> some View {
        let isDanger25 = (cell.sittingStar == 2 && cell.facingStar == 5) || (cell.sittingStar == 5 && cell.facingStar == 2)
        let isDouble9 = cell.sittingStar == 9 && cell.facingStar == 9
        let borderColor = isDanger25 ? Color.red : (isDouble9 ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.12))
        let bgColor = isDanger25 ? Color.red.opacity(0.1) : Color(red: 0.12, green: 0.12, blue: 0.16)
        
        return VStack(spacing: 4) {
            HStack {
                Text("\(cell.sittingStar)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.yanCyan)
                Spacer()
                Text("\(cell.facingStar)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.orange)
            }
            
            Text("\(cell.periodStar)")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                .padding(.vertical, 2)
            
            HStack {
                Text(cell.localizedPalaceName)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(cell.localizedElement)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(8)
        .frame(minHeight: 74)
        .background(bgColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: (isDanger25 || isDouble9) ? 1.5 : 1)
        )
    }
    
    // MARK: - 深度分析卡
    private func analysisCard(chart: XuanKongChart) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("xuankong_deep_analysis"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            
            Text(chart.patternDesc)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(4)
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lang.t("xuankong_wealth_advice"))
                Text(lang.t("xuankong_health_advice"))
                Text(lang.t("xuankong_remedy_advice"))
            }
            .font(.system(size: 11))
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
}
