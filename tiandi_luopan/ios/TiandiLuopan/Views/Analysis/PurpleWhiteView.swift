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
    @ObservedObject var retention = RetentionServiceManager.shared
    @State private var showPaywall: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var isUsingCustomDate: Bool = false
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
                let effectiveDate = isUsingCustomDate ? selectedDate : Date()
                // Keep the expensive calendar and annual/monthly star
                // calculation out of hidden sub-tab redraws.
                let chart = cachedChart ?? PurpleWhiteEngine.shared.calculateChart(date: effectiveDate, heading: motion.headingState.facingAngle)
                chartContent(chart: chart)
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
            
            // P0.3 流年/流月时间穿越切换栏
            monthControlBar()
                .padding(.horizontal, 16)

            // P0.2 开放九宫飞星盘面与太岁三煞预警预览（先建立凶吉感知，深度断语再做 VIP 转化）
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
            } analysis: {
            // 选中宫位流年/流月客星详解与宜忌建议（展开态右栏 / 折叠态底部）
            VStack(spacing: 12) {
                if let activeItem = chart.palaceItems.first(where: { $0.palaceId == (selectedPalaceId ?? chart.currentFacingPalace) }) ?? chart.palaceItems.first {
                    palaceDetailCard(item: activeItem, isFacing: activeItem.palaceId == chart.currentFacingPalace)
                        .padding(.horizontal, 16)
                }
                if !iap.hasUnlockedVIP {
                    purpleWhiteVIPPreviewCard()
                        .padding(.horizontal, 16)
                }
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

    private func monthControlBar() -> some View {
        let prevLabel: String
        let nextLabel: String
        let nowLabel: String
        switch lang.effectiveLanguage {
        case .en:
            prevLabel = "-1 Month"; nextLabel = "+1 Month"; nowLabel = "Current"
        case .zhHant:
            prevLabel = "上一節氣月"; nextLabel = "下一節氣月"; nowLabel = "回到當月"
        case .ja:
            prevLabel = "前節気月"; nextLabel = "次節気月"; nowLabel = "今月へ"
        case .ko:
            prevLabel = "이전 절기월"; nextLabel = "다음 절기월"; nowLabel = "이번달"
        case .vi:
            prevLabel = "Tháng trước"; nextLabel = "Tháng sau"; nowLabel = "Tháng này"
        case .th:
            prevLabel = "เดือนก่อน"; nextLabel = "เดือนถัดไป"; nowLabel = "เดือนนี้"
        case .id:
            prevLabel = "-1 Bulan"; nextLabel = "+1 Bulan"; nowLabel = "Bulan Ini"
        case .auto, .zhHans:
            prevLabel = "上一节气月"; nextLabel = "下一节气月"; nowLabel = "回到当月"
        }

        return HStack(spacing: 8) {
            Button(action: {
                let base = isUsingCustomDate ? selectedDate : Date()
                selectedDate = Calendar.current.date(byAdding: .day, value: -30, to: base) ?? base
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

            DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                .labelsHidden()
                .colorScheme(.dark)
                .scaleEffect(0.88)
                .onChange(of: selectedDate) { _ in
                    isUsingCustomDate = true
                    refreshChart(force: true)
                }

            Button(action: {
                let base = isUsingCustomDate ? selectedDate : Date()
                selectedDate = Calendar.current.date(byAdding: .day, value: 30, to: base) ?? base
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
        let effectiveDate = isUsingCustomDate ? selectedDate : Date()
        let sector = facingSector(for: motion.headingState.facingAngle)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: effectiveDate)
        let calendarDayKey = (components.year ?? 0) * 10_000
            + (components.month ?? 0) * 100
            + (components.day ?? 0)
        if !force, lastFacingSector == sector, lastCalendarDayKey == calendarDayKey { return }
        lastFacingSector = sector
        lastCalendarDayKey = calendarDayKey
        cachedChart = PurpleWhiteEngine.shared.calculateChart(date: effectiveDate, heading: motion.headingState.facingAngle)
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
        let isJi = [1, 4, 6, 8, 9].contains(item.yearGuestStar) && !isDanger
        let plainSummary: String = {
            switch lang.effectiveLanguage {
            case .en:
                if isDanger { return "⚠️ Plain Summary: 5-Yellow/2-Black Sha lands in \(item.palaceName). Keep quiet, avoid renovation/drilling, and place metal/brass cures." }
                if isJi { return "✅ Plain Summary: Auspicious Star (\(item.starName)) visits \(item.palaceName). Activate with daily activity, lighting, or water/plants." }
                return "💡 Plain Summary: Watch for petty disputes or drain in \(item.palaceName). Keep tidy and well-lit."
            case .zhHant:
                if isDanger { return "⚠️ 【白話速斷】流年/流月五黃二黑煞星飛臨【\(item.palaceName)】，切忌動土鑽牆或放紅色地墊，宜掛銅錢/銅葫蘆化洩。" }
                if isJi { return "✅ 【白話速斷】流年吉星【\(item.starName)】飛臨【\(item.palaceName)】，主旺財喜文昌，宜常坐臥、開窗納氣或擺放催旺器物。" }
                return "💡 【白話速斷】本宮流年見【\(item.starName)】，注意防口舌是非或小破耗，保持整潔明亮即可。"
            case .ja:
                if isDanger { return "⚠️ 【平易解説】五黄・二黒の凶星が【\(item.palaceName)】に飛来。動土や赤い装飾を避け、銅銭や銅製ひょうたんで化殺してください。" }
                if isJi { return "✅ 【平易解説】吉星【\(item.starName)】が【\(item.palaceName)】に飛来。財運・文昌に吉。換気と採光を良くして活用しましょう。" }
                return "💡 【平易解説】本宮は【\(item.starName)】が巡ります。口論や小出費に注意し、整理整頓を心がけてください。"
            case .ko:
                if isDanger { return "⚠️ [쉬운 해설] 오황·이흑 살성이 【\(item.palaceName)】에 비임했습니다. 공사나 붉은 매트를 피하고 동전/동호리병으로 화살하세요." }
                if isJi { return "✅ [쉬운 해설] 유년 길성 【\(item.starName)】이 【\(item.palaceName)】에 비임해 재물과 문창이 왕성합니다. 자주 머물고 환기하세요." }
                return "💡 [쉬운 해설] 본 궁에 【\(item.starName)】이 비임하여 구설수나 작은 지출을 주의하고 밝고 깨끗이 유지하세요."
            case .vi:
                if isDanger { return "⚠️ [Tóm tắt] Sao Ngũ Hoàng/Nhị Hắc bay vào 【\(item.palaceName)】, kỵ khoan đục hoặc trải thảm đỏ; nên treo tiền đồng/hồ lô đồng hóa giải." }
                if isJi { return "✅ [Tóm tắt] Cát tinh 【\(item.starName)】 đáo 【\(item.palaceName)】, vượng tài và văn xương; nên mở cửa đón khí hoặc sinh hoạt thường xuyên." }
                return "💡 [Tóm tắt] Cung 【\(item.palaceName)】 gặp 【\(item.starName)】, lưu ý tránh thị phi nhỏ, giữ gọn gàng sáng sủa."
            case .th:
                if isDanger { return "⚠️ [สรุปเข้าใจง่าย] ดาวร้าย 5 เหลือง/2 ดำจรเข้า【\(item.palaceName)】 ห้ามเจาะทุบหรือวางพรมแดง แนะนำแขวนเหรียญทองเหลืองแก้เคล็ด" }
                if isJi { return "✅ [สรุปเข้าใจง่าย] ดาวมงคล【\(item.starName)】จรเข้า【\(item.palaceName)】 เสริมโชคลาภและการงาน แนะนำเปิดรับแสงลมและใช้งานบ่อยๆ" }
                return "💡 [สรุปเข้าใจง่าย] วังนี้พบดาว【\(item.starName)】 ระวังปากเสียงเล็กน้อย รักษาความสะอาดและแสงสว่าง"
            case .id:
                if isDanger { return "⚠️ [Ringkasan] Bintang 5-Kuning/2-Hitam di 【\(item.palaceName)】. Hindari renovasi & karpet merah; pasang koin/labu kuningan." }
                if isJi { return "✅ [Ringkasan] Bintang Keberuntungan 【\(item.starName)】 di 【\(item.palaceName)】. Aktifkan dengan pencahayaan & sirkulasi udara." }
                return "💡 [Ringkasan] Sektor 【\(item.palaceName)】 bertemu 【\(item.starName)】. Jaga tetap rapi dan terang untuk menghindari perselisihan kecil."
            case .auto, .zhHans:
                if isDanger { return "⚠️ 【白话速断】流年/流月五黄二黑煞星飞临【\(item.palaceName)】，切忌动土钻墙或放红色地垫，宜挂铜钱/铜葫芦化泄。" }
                if isJi { return "✅ 【白话速断】流年吉星【\(item.starName)】飞临【\(item.palaceName)】，主旺财喜文昌，宜常坐卧、开窗纳气或摆放催旺器物。" }
                return "💡 【白话速断】本宫流年见【\(item.starName)】，注意防口舌是非或小破耗，保持整洁明亮即可。"
            }
        }()

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
                let remedyId = "pw_\(item.palaceId)"
                let inRemedy = retention.remedyTasks.contains(where: { $0.id == remedyId })
                let addRemedyLabel: String = {
                    switch lang.effectiveLanguage {
                    case .en: return inRemedy ? "Tracked" : "+ Track"
                    case .zhHant: return inRemedy ? "已入清單" : "+ 調理打卡"
                    case .ja: return inRemedy ? "登録済" : "+ 化殺記録"
                    case .ko: return inRemedy ? "등록됨" : "+ 비보체크"
                    case .vi: return inRemedy ? "Đã lưu" : "+ Theo dõi"
                    case .th: return inRemedy ? "บันทึกแล้ว" : "+ ติดตาม"
                    case .id: return inRemedy ? "Tersimpan" : "+ Lacak"
                    case .auto, .zhHans: return inRemedy ? "已入清单" : "+ 调理打卡"
                    }
                }()
                Button(action: {
                    retention.toggleRemedyTask(
                        id: remedyId,
                        palaceDirection: item.palaceName,
                        title: item.starName,
                        remedyAction: plainSummary
                    )
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: inRemedy ? "checkmark.circle.fill" : "plus.circle")
                            .adaptiveFont(size: 9)
                        Text(addRemedyLabel)
                            .adaptiveFont(size: 9, weight: .bold)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(inRemedy ? Color.green.opacity(0.22) : Color.yanCyan.opacity(0.18))
                    .foregroundColor(inRemedy ? .green : Color.yanCyan)
                    .cornerRadius(5)
                }
                Text("\(item.yearGuestStar) / \(lang.t("tag_month_prefix"))\(item.monthGuestStar)")
                    .adaptiveFont(size: 11, weight: .bold, design: .monospaced)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }

            Text(plainSummary)
                .adaptiveFont(size: 11, weight: .semibold)
                .foregroundColor(isDanger ? Color.orange : (isJi ? Color.green : Color(red: 0.95, green: 0.85, blue: 0.45)))
                .fixedSize(horizontal: false, vertical: true)

            if iap.hasUnlockedVIP {
                Text(item.advice)
                    .adaptiveFont(size: 12)
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(3)
            }
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
