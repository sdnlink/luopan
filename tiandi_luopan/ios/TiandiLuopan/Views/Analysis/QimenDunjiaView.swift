import SwiftUI
import UIKit
import Combine

// MARK: - 三式绝学 · 时家奇门遁甲全息排盘与出行导航视图 (PRD 第11章)

public struct QimenDunjiaView: View {
    public var isActive: Bool = true
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var showPaywall: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var isUsingCustomDate: Bool = false
    @State private var cachedChart: QimenChart?
    @State private var selectedPalaceId: Int? = nil
    @State private var selectedScenario: QimenScenarioType = .contract
    @State private var lastChartHeading: Double?
    @State private var lastChartTimeKey: QimenChartTimeKey?

    // Qimen uses the current hour. A low-frequency publisher catches an hour
    // boundary while the phone is stationary; refreshChart's time key keeps
    // the timer from rebuilding the chart during the other 59 ticks.
    private static let chartRefreshTimer = Timer.publish(
        every: 60,
        on: .main,
        in: .common
    ).autoconnect()

    // 两套口径（见 AdaptiveLayout）：isSplitLayout = Duo 内屏 / iPad 横屏左右分栏；
    // isLargeLayout 为宽屏（含 iPad），只放大九宫与内容尺寸。
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.adaptiveLayoutForm) private var layoutForm
    private var isSplitLayout: Bool {
        AdaptiveLayout.isTwoPane(horizontal: horizontalSizeClass,
                                      vertical: verticalSizeClass, form: layoutForm)
    }
    private var isLargeLayout: Bool {
        AdaptiveLayout.isWide(sizeClass: horizontalSizeClass)
    }
    /// 分栏后左栏只有 55~60% 宽，控件尺寸不能沿用「整屏宽屏」的放大档位。
    private var isRoomyLayout: Bool {
        isLargeLayout && !isSplitLayout
    }
    
    public init(isActive: Bool = true) {
        self.isActive = isActive
    }
    
    public var body: some View {
        return Group {
            if isActive {
                let effectiveDate = isUsingCustomDate ? selectedDate : Date()
                // Motion publishes tilt and magnetic-field samples
                // independently of the heading. Reuse the chart across
                // those updates; Qimen only needs a new result when the
                // heading or language changes.
                let chart = cachedChart ?? QimenEngine.shared.calculateChart(date: effectiveDate, heading: motion.headingState.facingAngle)

                // iPhone Duo 展开态双栏：左栏 = 奇门九宫方阵（主交互），
                // 右栏 = 选中宫门星神摘要与出行动身方位导航（分析解释）；折叠态保持原单列纵排。
                FoldableTwoPane(compactSpacing: 12) {
                VStack(spacing: 12) {
            // 局数标题栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(lang.t("qimen_header_title"))
                        .adaptiveFont(size: 14, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                }
                Spacer()
                Text(chart.title)
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 16)

            // P0.3 时辰穿越控制栏（每 2 小时换一局，支持提前推演谈判/出行时辰）
            qimenTimeControlBar()
                .padding(.horizontal, 16)

            // P3.3 奇门遁甲「场景化一事一断」速查向导条
            qimenScenarioSelectorBar(chart: chart)
                .padding(.horizontal, 16)
            
            // P0.2 开放 3x3 奇门九宫方阵预览 (天地人神四盘可点选查看八门九星)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                let rec = QimenEngine.shared.evaluateScenario(selectedScenario, chart: chart, heading: motion.headingState.facingAngle)
                ForEach(chart.cells) { cell in
                    let activeId = selectedPalaceId ?? rec.recommendedPalaceId
                    qimenCellView(cell: cell, isSelected: cell.palaceId == activeId)
                        .onTapGesture {
                            selectedPalaceId = cell.palaceId
                        }
                }
            }
            // 分栏时铺满左栏（两栏已按有效宽度分配），单列宽屏仍 580、手机全宽
            .frame(maxWidth: isSplitLayout ? .infinity : (isLargeLayout ? 580 : .infinity))
            .padding(.horizontal, isLargeLayout ? 0 : 16)
            }
            } analysis: {
            // 选中宫门星神摘要与出行动身方位导航（展开态右栏 / 折叠态底部）
            VStack(spacing: 12) {
                let rec = QimenEngine.shared.evaluateScenario(selectedScenario, chart: chart, heading: motion.headingState.facingAngle)
                qimenScenarioGuideCard(rec: rec)
                    .padding(.horizontal, 16)

                if let activeCell = chart.cells.first(where: { $0.palaceId == (selectedPalaceId ?? rec.recommendedPalaceId) }), !activeCell.isTaiJiCenter {
                    let doorObj = QimenDoor(name: activeCell.doorName, palace: activeCell.palaceId, isAuspicious: activeCell.isDoorAuspicious, luckType: activeCell.doorLuck, lore: "")
                    HStack(spacing: 8) {
                        Text("【\(activeCell.localizedPalaceName)】")
                            .adaptiveFont(size: 11, weight: .bold)
                            .foregroundColor(Color.yanCyan)
                        Text("\(activeCell.localizedDoorName) [\(doorObj.localizedLuckType)] · \(activeCell.localizedGodName) · \(activeCell.localizedStarName)")
                            .adaptiveFont(size: 11, weight: .semibold)
                            .foregroundColor(activeCell.isDoorAuspicious ? .green : (activeCell.isDoorInauspicious ? .red : Color(red: 0.95, green: 0.85, blue: 0.45)))
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                }

                if iap.hasUnlockedVIP {
                    // 出行动身方位导航卡
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "location.north.circle.fill")
                                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                            Text(lang.t("qimen_travel_best"))
                                .adaptiveFont(size: 12, weight: .bold)
                                .foregroundColor(.white)
                            Spacer()
                            Text(lang.t("qimen_pattern_best"))
                                .adaptiveFont(size: 10)
                                .foregroundColor(.green)
                        }
                        
                        Text("\(lang.t("qimen_best_nav"))【\(chart.bestNavDirection)】！\(chart.bestNavReason)")
                            .adaptiveFont(size: 11)
                            .foregroundColor(Color.green)
                            .lineLimit(2)
                        
                        if !chart.tabooDirections.isEmpty {
                            Text("\(lang.t("qimen_taboo_nav"))【\(chart.tabooDirections)】\(lang.t("qimen_taboo_suffix"))")
                                .adaptiveFont(size: 11)
                                .foregroundColor(Color.orange)
                                .lineLimit(2)
                        }
                    }
                    .padding(10)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                } else {
                    qimenVIPPreviewCard()
                        .padding(.horizontal, 16)
                }
            }
            }
            } else {
                Color.clear
            }
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
        .onAppear {
            refreshChart(force: true)
        }
        .onChange(of: motion.headingState.facingAngle) { _ in
            refreshChart()
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            refreshChart(force: true)
        }
        .onChange(of: motion.currentSolarTermName) { _ in
            if !isUsingCustomDate { refreshChart() }
        }
        .onChange(of: isActive) { active in
            if active { refreshChart(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshChart(force: true)
        }
        .onReceive(Self.chartRefreshTimer) { _ in
            refreshChart()
        }
    }

    private func qimenTimeControlBar() -> some View {
        let prevLabel: String
        let nextLabel: String
        let nowLabel: String
        switch lang.effectiveLanguage {
        case .en:
            prevLabel = "-2h"; nextLabel = "+2h"; nowLabel = "Now"
        case .zhHant:
            prevLabel = "上一時辰"; nextLabel = "下一時辰"; nowLabel = "回到此刻"
        case .ja:
            prevLabel = "-2時間(前刻)"; nextLabel = "+2時間(次刻)"; nowLabel = "現在へ"
        case .ko:
            prevLabel = "이전 시진(-2h)"; nextLabel = "다음 시진(+2h)"; nowLabel = "현재"
        case .vi:
            prevLabel = "-2 giờ"; nextLabel = "+2 giờ"; nowLabel = "Hiện tại"
        case .th:
            prevLabel = "-2 ชม."; nextLabel = "+2 ชม."; nowLabel = "ตอนนี้"
        case .id:
            prevLabel = "-2 Jam"; nextLabel = "+2 Jam"; nowLabel = "Sekarang"
        case .auto, .zhHans:
            prevLabel = "上一时辰"; nextLabel = "下一时辰"; nowLabel = "回到此刻"
        }

        return HStack(spacing: 8) {
            Button(action: {
                let base = isUsingCustomDate ? selectedDate : Date()
                selectedDate = Calendar.current.date(byAdding: .hour, value: -2, to: base) ?? base
                isUsingCustomDate = true
                refreshChart(force: true)
            }) {
                Text(prevLabel)
                    .adaptiveFont(size: 10, weight: .semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }

            DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .colorScheme(.dark)
                .scaleEffect(0.88)
                .onChange(of: selectedDate) { _ in
                    isUsingCustomDate = true
                    refreshChart(force: true)
                }

            Button(action: {
                let base = isUsingCustomDate ? selectedDate : Date()
                selectedDate = Calendar.current.date(byAdding: .hour, value: 2, to: base) ?? base
                isUsingCustomDate = true
                refreshChart(force: true)
            }) {
                Text(nextLabel)
                    .adaptiveFont(size: 10, weight: .semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }

            if isUsingCustomDate {
                Button(action: {
                    isUsingCustomDate = false
                    selectedDate = Date()
                    refreshChart(force: true)
                }) {
                    Text(nowLabel)
                        .adaptiveFont(size: 10, weight: .bold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.yanCyan.opacity(0.2))
                        .foregroundColor(Color.yanCyan)
                        .cornerRadius(6)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func refreshChart(force: Bool = false) {
        guard isActive else { return }
        let heading = motion.headingState.facingAngle
        let now = isUsingCustomDate ? selectedDate : Date()
        let timeKey = QimenEngine.shared.chartTimeKey(for: now)
        if !force, let lastHeading = lastChartHeading,
           let lastTimeKey = lastChartTimeKey,
           lastTimeKey == timeKey {
            let rawDelta = abs(heading - lastHeading)
            let delta = min(rawDelta, 360.0 - rawDelta)
            // The chart's actionable turn instruction is displayed in whole
            // degrees. Rebuilding it for sub-degree sensor noise only adds
            // work and causes unnecessary SwiftUI row updates.
            if delta < 1.0 { return }
        }
        lastChartHeading = heading
        lastChartTimeKey = timeKey
        cachedChart = QimenEngine.shared.calculateChart(date: now, heading: heading)
    }
    
    private func qimenCellView(cell: QimenPalaceCell, isSelected: Bool = false) -> some View {
        let isJi = cell.isDoorAuspicious
        let isXiong = cell.isDoorInauspicious
        let borderColor = isSelected ? Color.yanCyan : (isJi ? Color.green.opacity(0.5) : (isXiong ? Color.red.opacity(0.4) : Color.white.opacity(0.12)))
        let bgColor = isJi ? Color.green.opacity(0.08) : (isXiong ? Color.red.opacity(0.06) : Color(red: 0.12, green: 0.13, blue: 0.18))
        
        return VStack {
            // 顶行: 八神 / 九星
            HStack {
                Text(cell.localizedGodName)
                    .adaptiveFont(size: 9, weight: .bold)
                    .foregroundColor(Color.yellow)
                Spacer()
                Text(cell.localizedStarName)
                    .adaptiveFont(size: 9)
                    .foregroundColor(Color.yanCyan)
            }
            
            Spacer(minLength: 2)
            
            // 中行: 八门 (大字显影)
            Text(cell.localizedDoorName)
                .adaptiveFont(size: 15, weight: .bold, design: .serif)
                .foregroundColor(isJi ? Color.green : (isXiong ? Color.red : Color(red: 0.95, green: 0.85, blue: 0.45)))
            
            Spacer(minLength: 2)
            
            // 底行: 宫名 / 天地三奇六仪
            HStack {
                Text(cell.localizedPalaceName)
                    .adaptiveFont(size: 8)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(cell.localizedTianStem)/\(cell.localizedDiStem)")
                    .adaptiveFont(size: 9, weight: .bold, design: .monospaced)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }
        }
        .padding(isRoomyLayout ? 10 : 6)
        .aspectRatio(1.0, contentMode: .fit)
        .background(bgColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    // MARK: - P3.3 奇门场景化一事一断选择器与指南卡
    private func qimenScenarioSelectorBar(chart: QimenChart) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(QimenScenarioType.allCases) { item in
                    let isSelected = selectedScenario == item
                    Button(action: {
                        selectedScenario = item
                        let rec = QimenEngine.shared.evaluateScenario(item, chart: chart, heading: motion.headingState.facingAngle)
                        selectedPalaceId = rec.recommendedPalaceId
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: item.iconName)
                                .adaptiveFont(size: 10)
                            Text(item.localizedTitle)
                                .adaptiveFont(size: 10, weight: .bold)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.08))
                        .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func qimenScenarioGuideCard(rec: QimenScenarioRecommendation) -> some View {
        let badgeLabel: String = {
            switch lang.effectiveLanguage {
            case .en: return "Best Direction"
            case .zhHant: return "一事一斷 · 首選吉方"
            case .ja: return "目的別・最吉方位"
            case .ko: return "목적별 길방"
            case .vi: return "Phương vị ưu tiên"
            case .th: return "ทิศมงคลตามภารกิจ"
            case .id: return "Arah Prioritas"
            case .auto, .zhHans: return "一事一断 · 首选吉方"
            }
        }()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: rec.scenario.iconName)
                    .adaptiveFont(size: 12)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text("\(rec.scenario.localizedTitle) · \(rec.directionTitle)")
                    .adaptiveFont(size: 12, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
                Text(badgeLabel)
                    .adaptiveFont(size: 9, weight: .bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yanCyan.opacity(0.18))
                    .foregroundColor(Color.yanCyan)
                    .cornerRadius(4)
            }
            Text(rec.keyPattern)
                .adaptiveFont(size: 10, weight: .semibold, design: .monospaced)
                .foregroundColor(Color.green)
            Text(rec.actionGuide)
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color(red: 0.11, green: 0.13, blue: 0.18))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - 奇门遁甲 VIP 展开态预览占位卡 (消除展开态双栏右侧留白)
    private func qimenVIPPreviewCard() -> some View {
        let lang = LocalizationManager.shared
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .adaptiveFont(size: 16)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(lang.t("privilege_qimen_title"))
                    .adaptiveFont(size: 14, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
                Text(lang.t("vip_badge_title"))
                    .adaptiveFont(size: 10, weight: .bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.2))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .cornerRadius(4)
            }

            Text(lang.t("privilege_qimen_desc"))
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)

            Divider().background(Color.white.opacity(0.1))

            Text("🧭 \(lang.t("privilege_qm_feature_title"))")
                .adaptiveFont(size: 12, weight: .semibold)
                .foregroundColor(Color.yanCyan)

            VStack(alignment: .leading, spacing: 6) {
                Text("• \(lang.t("privilege_qm_bullet_1"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                Text("• \(lang.t("privilege_qm_bullet_2"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                Text("• \(lang.t("privilege_qm_bullet_3"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer(minLength: 8)

            Button(action: { showPaywall = true }) {
                HStack {
                    Spacer()
                    Image(systemName: "crown.fill")
                    Text(lang.t("unlock_vip_now"))
                    Spacer()
                }
                .adaptiveFont(size: 12, weight: .bold)
                .padding(.vertical, 8)
                .background(Color(red: 0.83, green: 0.68, blue: 0.21))
                .foregroundColor(.black)
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}
