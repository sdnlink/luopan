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
    @State private var cachedChart: QimenChart?
    @State private var selectedPalaceId: Int? = nil
    @State private var lastChartHeading: Double?
    @State private var lastChartTimeKey: Int?

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
    @Environment(\.adaptiveLayoutForm) private var layoutForm
    private var isSplitLayout: Bool {
        AdaptiveLayout.isTwoPane(sizeClass: horizontalSizeClass, form: layoutForm)
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
                // Motion publishes tilt and magnetic-field samples
                // independently of the heading. Reuse the chart across
                // those updates; Qimen only needs a new result when the
                // heading or language changes.
                let chart = cachedChart ?? QimenEngine.shared.calculateChart(heading: motion.headingState.facingAngle)

                // iPhone Duo 展开态双栏：左栏 = 奇门九宫方阵（主交互），
                // 右栏 = 选中宫门星神摘要与出行动身方位导航（分析解释）；折叠态保持原单列纵排。
                FoldableTwoPane(mainColumnRatio: 0.58, compactSpacing: 12) {
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
            
            if !iap.hasUnlockedVIP {
                VIPLockCardView(
                    title: lang.t("privilege_qimen_title"),
                    featureDesc: lang.t("privilege_qimen_desc"),
                    badge: lang.t("vip_badge_title"),
                    targetProductId: .vipYearly,
                    onUnlockTap: { showPaywall = true }
                )
                .sheet(isPresented: $showPaywall) {
                    VIPPaywallSheet(defaultProductId: .vipYearly)
                }
            } else {
                // 3x3 奇门九宫方阵 (天地人神四盘)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(chart.cells) { cell in
                        let defaultId = chart.cells.first(where: { $0.doorName == "开门" || $0.doorName == "生门" })?.palaceId ?? 6
                        let activeId = selectedPalaceId ?? defaultId
                        qimenCellView(cell: cell, isSelected: cell.palaceId == activeId)
                            .onTapGesture {
                                selectedPalaceId = cell.palaceId
                            }
                    }
                }
                // 分栏时按左栏宽度放大（720 上限），单列宽屏仍 580、手机全宽
                .frame(maxWidth: isSplitLayout ? 720 : (isLargeLayout ? 580 : .infinity))
                .padding(.horizontal, isLargeLayout ? 0 : 16)
                }
                }
                } analysis: {
                // 选中宫门星神摘要与出行动身方位导航（展开态右栏 / 折叠态底部）
                if iap.hasUnlockedVIP {
                if let activeCell = chart.cells.first(where: { $0.palaceId == (selectedPalaceId ?? (chart.cells.first(where: { $0.doorName == "开门" || $0.doorName == "生门" })?.palaceId ?? 6)) }), !activeCell.isTaiJiCenter {
                    let doorObj = QimenDoor(name: activeCell.doorName, palace: activeCell.palaceId, isAuspicious: activeCell.isDoorAuspicious, luckType: activeCell.doorLuck, lore: "")
                    HStack(spacing: 8) {
                        Text("【\(activeCell.localizedPalaceName)】")
                            .adaptiveFont(size: 11, weight: .bold)
                            .foregroundColor(Color.yanCyan)
                        Text("\(activeCell.localizedDoorName) [\(doorObj.localizedLuckType)] · \(activeCell.localizedGodName) · \(activeCell.localizedStarName)")
                            .adaptiveFont(size: 11, weight: .semibold)
                            .foregroundColor(activeCell.isDoorAuspicious ? .green : (activeCell.isDoorInauspicious ? .red : Color(red: 0.95, green: 0.85, blue: 0.45)))
                        Spacer()
                        Text(doorObj.localizedLore)
                            .adaptiveFont(size: 10)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                }
                
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
                } else if isSplitLayout {
                    qimenVIPPreviewCard()
                }
            }
            } else {
                Color.clear
            }
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

    private func refreshChart(force: Bool = false) {
        guard isActive else { return }
        let heading = motion.headingState.facingAngle
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: now)
        let timeKey = (components.year ?? 0) * 1_000_000
            + (components.month ?? 0) * 10_000
            + (components.day ?? 0) * 24
            + (components.hour ?? 0)
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
        cachedChart = QimenEngine.shared.calculateChart(heading: heading)
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
                Text("\(cell.tianStem)/\(cell.diStem)")
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