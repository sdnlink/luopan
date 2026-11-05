import SwiftUI
import UIKit

// MARK: - 紫白飞星流年流月客星动态气运与太岁三煞视图 (PRD 第12章)

public struct PurpleWhiteView: View {
    /// Whether the purple-white chart is currently visible.  The parent
    /// analysis page keeps its subviews alive while switching tabs, so this
    /// flag prevents hidden charts from reacting to every compass sample.
    public var isActive: Bool = true
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showPaywall: Bool = false
    @State private var cachedChart: PurpleWhiteChart?
    @State private var selectedPalaceId: Int? = nil
    @State private var lastFacingSector: Int?
    @State private var lastCalendarDayKey: Int?

    // 两套口径（见 AdaptiveLayout）：isSplitLayout = Duo 内屏 / iPad 横屏左右分栏；
    // isLargeLayout 为宽屏（含 iPad），只放大宫格与内容尺寸。
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
        Group {
            if isActive {
                // Keep the expensive calendar and annual/monthly star
                // calculation out of hidden sub-tab redraws.
                let chart = cachedChart ?? PurpleWhiteEngine.shared.calculateChart(heading: motion.headingState.facingAngle)
                chartContent(chart: chart)
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
        .onChange(of: isActive) { active in
            if active {
                refreshChart(force: true)
            }
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            refreshChart(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshChart(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshChart(force: true)
        }
    }

    @ViewBuilder
    private func chartContent(chart: PurpleWhiteChart) -> some View {
        let lang = LocalizationManager.shared
        // iPhone Duo 展开态双栏：左栏 = 太岁三煞警戒与九宫飞星盘（主交互），
        // 右栏 = 选中宫位流年流月客星详解（分析解释）；折叠态保持原单列纵排。
        FoldableTwoPane(compactSpacing: 12) {
        VStack(spacing: 12) {
            // 标题与太岁/三煞摘要栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(lang.t("purplewhite_header_title"))
                        .adaptiveFont(size: 14, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                }
                Spacer()
                let isEn = LocalizationManager.shared.effectiveLanguage == .en
                let dateLabel = isEn
                    ? "\(chart.year) / \(chart.month)"
                    : "\(chart.year)\(lang.t("year_suffix")) · \(chart.month)\(lang.t("month_suffix"))"
                Text(dateLabel)
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 16)
            
            if !iap.hasUnlockedVIP {
                VIPLockCardView(
                    title: lang.t("privilege_purplewhite_title"),
                    featureDesc: lang.t("privilege_purplewhite_desc"),
                    badge: lang.t("vip_badge_title"),
                    targetProductId: .vipYearly,
                    onUnlockTap: { showPaywall = true }
                )
                .sheet(isPresented: $showPaywall) {
                    VIPPaywallSheet(defaultProductId: .vipYearly)
                }
            } else {
                // 太岁、岁破、三煞警戒条
                HStack(spacing: 8) {
                    tagPill(title: lang.t("tai_sui_label"), value: chart.taiSuiDescription, color: Color.red)
                    tagPill(title: lang.t("sui_po_label"), value: chart.suiPoDescription, color: Color.orange)
                    tagPill(title: lang.t("san_sha_label"), value: chart.sanShaDescription, color: Color.purple)
                }
                .padding(.horizontal, 16)
                
                // 3x3 九宫飞星网格 (流年客星与二五交加报警)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(chart.palaceItems) { item in
                        let activeId = selectedPalaceId ?? chart.currentFacingPalace
                        palaceCellView(
                            item: item,
                            isFacing: item.palaceId == chart.currentFacingPalace,
                            isSelected: item.palaceId == activeId
                        )
                        .onTapGesture {
                            selectedPalaceId = item.palaceId
                        }
                    }
                }
                // 分栏时铺满左栏（两栏已按有效宽度分配），单列宽屏仍 580、手机全宽
                .frame(maxWidth: isSplitLayout ? .infinity : (isLargeLayout ? 580 : .infinity))
                .padding(.horizontal, isLargeLayout ? 0 : 16)
                }
                }
                } analysis: {
                // 选中宫位流年/流月客星详解与宜忌建议（展开态右栏 / 折叠态底部）
                if iap.hasUnlockedVIP {
                    if let activeItem = chart.palaceItems.first(where: { $0.palaceId == (selectedPalaceId ?? chart.currentFacingPalace) }) ?? chart.palaceItems.first {
                        palaceDetailCard(item: activeItem, isFacing: activeItem.palaceId == chart.currentFacingPalace)
                            .padding(.horizontal, 16)
                    }
                } else if isSplitLayout {
                    purpleWhiteVIPPreviewCard()
                        .padding(.horizontal, 16)
                }
            }
    }

    // MARK: - 紫白飞星 VIP 展开态预览卡 (消除展开态双栏右侧留白)
    private func purpleWhiteVIPPreviewCard() -> some View {
        let lang = LocalizationManager.shared
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .adaptiveFont(size: 16)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(lang.t("privilege_purplewhite_title"))
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

            Text(lang.t("privilege_purplewhite_desc"))
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)

            Divider().background(Color.white.opacity(0.1))

            Text("🌟 \(lang.t("privilege_pw_feature_title"))")
                .adaptiveFont(size: 12, weight: .semibold)
                .foregroundColor(Color.yanCyan)

            VStack(alignment: .leading, spacing: 6) {
                Text("• \(lang.t("privilege_pw_bullet_1"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                Text("• \(lang.t("privilege_pw_bullet_2"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                Text("• \(lang.t("privilege_pw_bullet_3"))")
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

    private func refreshChart(force: Bool = false) {
        guard isActive else { return }
        let sector = facingSector(for: motion.headingState.facingAngle)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let calendarDayKey = (components.year ?? 0) * 10_000
            + (components.month ?? 0) * 100
            + (components.day ?? 0)
        if !force, lastFacingSector == sector, lastCalendarDayKey == calendarDayKey { return }
        lastFacingSector = sector
        lastCalendarDayKey = calendarDayKey
        cachedChart = PurpleWhiteEngine.shared.calculateChart(heading: motion.headingState.facingAngle)
    }

    private func facingSector(for heading: Double) -> Int {
        let normalized = (heading.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0)
        switch normalized {
        case 337.5..<360.0, 0.0..<22.5: return 1
        case 22.5..<67.5: return 8
        case 67.5..<112.5: return 3
        case 112.5..<157.5: return 4
        case 157.5..<202.5: return 9
        case 202.5..<247.5: return 2
        case 247.5..<292.5: return 7
        default: return 6
        }
    }
    
    private func tagPill(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .adaptiveFont(size: 10, weight: .bold)
                .foregroundColor(.black)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(color)
                .cornerRadius(4)
            Text(value)
                .adaptiveFont(size: 10, weight: .medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }
    
    private func palaceDetailCard(item: PurpleWhitePalaceItem, isFacing: Bool) -> some View {
        let isDanger = item.isDanger25 || item.yearGuestStar == 5 || item.monthGuestStar == 5
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: isDanger ? "exclamationmark.triangle.fill" : "sparkles")
                    .foregroundColor(isDanger ? .red : Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(item.palaceName)
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(.white)
                Text("· \(item.starName)")
                    .adaptiveFont(size: 12, weight: .semibold)
                    .foregroundColor(isDanger ? .red : Color.yanCyan)
                Spacer()
                Text("\(item.yearGuestStar) / \(lang.t("tag_month_prefix"))\(item.monthGuestStar)")
                    .adaptiveFont(size: 11, weight: .bold, design: .monospaced)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }
            Text(item.advice)
                .adaptiveFont(size: 12)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)
        }
        .padding(12)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isDanger ? Color.red.opacity(0.5) : (isFacing ? Color.yanCyan.opacity(0.5) : Color.white.opacity(0.1)), lineWidth: 1)
        )
    }
    
    private func palaceCellView(item: PurpleWhitePalaceItem, isFacing: Bool, isSelected: Bool = false) -> some View {
        // Both annual and monthly Five Yellow can affect the current palace;
        // the chart's advice uses the same rule so the visual warning cannot
        // disagree with the detail text.
        let isDanger = item.isDanger25 || item.yearGuestStar == 5 || item.monthGuestStar == 5
        let isJi = [1, 4, 6, 8, 9].contains(item.yearGuestStar)
        let strokeColor = isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : (isFacing ? Color.yanCyan : (isDanger ? Color.red : (isJi ? Color.green.opacity(0.5) : Color.white.opacity(0.12))))
        let bgColor = isDanger ? Color.red.opacity(0.12) : (isJi ? Color.green.opacity(0.06) : Color(red: 0.12, green: 0.13, blue: 0.18))
        
        return VStack {
            // 顶行: 宫位名 + 冲犯标签
            HStack {
                Text(item.direction)
                    .adaptiveFont(size: 10, weight: .bold)
                    .foregroundColor(.white)
                Spacer()
                if item.isTaiSui {
                    Text(lang.t("tag_taisui"))
                        .adaptiveFont(size: 8, weight: .bold)
                        .foregroundColor(.red)
                } else if item.isSanSha {
                    Text(lang.t("tag_sansha"))
                        .adaptiveFont(size: 8, weight: .bold)
                        .foregroundColor(.purple)
                }
                if isFacing {
                    Image(systemName: "location.north.fill")
                        .adaptiveFont(size: 8, weight: .bold)
                        .foregroundColor(.yanCyan)
                }
            }
            
            Spacer(minLength: 2)
            
            // 中行: 年飞星数字 (大字显影)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(item.yearGuestStar)")
                    .adaptiveFont(size: 20, weight: .bold, design: .serif)
                    .foregroundColor(isDanger ? Color.red : (isJi ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.7)))
                
                Text("\(lang.t("tag_month_prefix"))\(item.monthGuestStar)")
                    .adaptiveFont(size: 9)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer(minLength: 2)
            
            // 底行: 星名与化解提示
            Text(item.starName)
                .adaptiveFont(size: 8)
                .foregroundColor(isDanger ? Color.red : Color.white.opacity(0.65))
                .lineLimit(1)
        }
        .padding(isRoomyLayout ? 10 : 6)
        .aspectRatio(1.0, contentMode: .fit)
        .background(bgColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(strokeColor, lineWidth: isDanger ? 1.5 : 1)
        )
    }
}
