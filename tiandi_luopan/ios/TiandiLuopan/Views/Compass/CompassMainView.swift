import SwiftUI

// MARK: - 主罗盘界面 (Compass Main View)

public struct CompassMainView: View {
    public var isActive: Bool = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 布局环境值：iPad 横屏与 Duo 内屏一样走右栏研判工作台，竖屏回底部状态卡。
    @Environment(\.adaptiveLayoutForm) private var layoutForm
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var layers = CompassLayerManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    
    // 弹窗状态
    @State private var showFenjinSheet = false
    @State private var showKongwangSheet = false
    @State private var showPalaceSheet = false
    @State private var showLayerSheet = false
    @State private var showCalibSheet = false
    @State private var showDailySignSheet = false
    
    public init(isActive: Bool = true) {
        self.isActive = isActive
    }
    
    public var body: some View {
        ZStack {
            // 背景渐变
            Color(red: 0.07, green: 0.07, blue: 0.09)
                .ignoresSafeArea()
            
            if isActive {
                // 分栏态（Duo 内屏 / iPad 横屏）：左栏 = 罗盘主交互（仪表/工具条/盘面），
                // 右栏 = 周易分金与八宅提示卡（分析解释）；单列态保持原纵排。
                FoldableTwoPane(compactSpacing: 4) {
                    VStack(spacing: 4) {
                        // 1. 顶部数据仪表
                        CompassHeaderView()
                        
                        // 强磁干扰动态告警条
                        if motion.isDistorted {
                            Button(action: {
                                showCalibSheet = true
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color.orange)
                                    Text("\(lang.t("mag_warning_tap")) (\(String(format: "%.0f", motion.magneticStrengthUT)) μT) · \(lang.t("tap_to_calib"))")
                                        .adaptiveFont(size: 11, weight: .bold)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.65)
                                        .layoutPriority(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .adaptiveFont(size: 10)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.orange.opacity(0.25))
                                .cornerRadius(6)
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // 2. 罗盘快捷辅助工具条 (锁定朝向 / 分金详勘 / 空亡诊断 / 八方全鉴 / 吉方导引)
                        compassToolBar()
                            .padding(.top, 2)
                        
                        if layers.showDailyGodMarkers {
                            dailyDirectionBanner()
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                        }
                        
                        Spacer(minLength: 4)
                        
                        // 3. 核心随动罗盘盘面 (包含 120分金、64卦、24山、八卦、水准仪)
                        CompassDialView()
                            .padding(.horizontal, 8)
                        
                        Spacer(minLength: 4)
                    }
                } analysis: {
                    // 4. 展开态右侧专业研判工作台（独立滚动）/ 单列态底部快捷卡片
                    // Duo 内屏与 iPad 横屏都走右栏；iPad 竖屏保持单列，改用底部状态卡。
                    if AdaptiveLayout.isTwoPane(horizontal: horizontalSizeClass,
                                                vertical: verticalSizeClass,
                                                form: layoutForm) {
                        ScrollView {
                            unfoldedCompassAnalysisPanel()
                                .padding(16)
                                // iOS 27 浮动 TabBar 不占 safe area，会盖住右栏末尾卡片；
                                // 直接给可滚动内容留底部余量，保证最后一张卡能完整滚出。
                                .padding(.bottom, 80)
                        }
                    } else {
                        // 单列宽屏（iPad 竖屏 / Duo 折叠外屏）下底部卡片会被拉得很宽，
                        // 收在 900pt（与户型/设置同一套内容宽度口径）后居中；
                        // iPad 横屏走上面的右栏工作台分支，不会到这里。
                        bottomStatusCard()
                            .frame(maxWidth: 900)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .sheet(isPresented: $showFenjinSheet) {
            FenjinDetailSheet(fenjin: Fenjin120Data.shared.resolveFenjin(for: motion.headingState.facingAngle))
        }
        .sheet(isPresented: $showKongwangSheet) {
            KongWangDetailSheet(heading: motion.headingState.facingAngle)
        }
        .sheet(isPresented: $showPalaceSheet) {
            FengshuiPalaceDetailSheet()
        }
        .sheet(isPresented: $showLayerSheet) {
            LayerSettingsSheet()
        }
        .sheet(isPresented: $showCalibSheet) {
            CalibrationSheet()
        }
        .sheet(isPresented: $showDailySignSheet) {
            DailyAuspiciousCardSheet(sittingMountain: motion.headingState.sittingMountain)
        }
        .onAppear {
            motion.refreshTimeAndSolarTerm()
        }
        .onChange(of: isActive) { active in
            if active {
                motion.refreshTimeAndSolarTerm()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            motion.refreshTimeAndSolarTerm()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            motion.refreshTimeAndSolarTerm()
        }
    }
    
    // MARK: - 罗盘工具条
    private func compassToolBar() -> some View {
        // 判级复用 Mountain24.kongWangLevel 统一口径（与详勘 sheet 一致）：
        // 大空亡 ≥6.8°+子午卯酉缝 / 小空亡 ≥6.5° / 兼向 ≥1.5° / 其余纯清
        let kwLevel = motion.headingState.kongWangLevel
        let kwStatus = kwLevel.localizedTitle
        let kwColor: Color
        switch kwLevel {
        case .pure: kwColor = Color.green
        case .jianXiang: kwColor = Color.yellow
        case .smallVoid: kwColor = Color.orange
        case .largeVoid: kwColor = Color.red
        }
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
            // 锁定朝向按钮
            Button(action: {
                motion.toggleLock()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: motion.isLocked ? "lock.fill" : "lock.open")
                    Text(motion.isLocked ? lang.t("locked_heading") : lang.t("lock_heading"))
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(motion.isLocked ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                .foregroundColor(motion.isLocked ? .red : .white)
                .cornerRadius(6)
            }
            .accessibilityLabel(motion.isLocked ? lang.t("locked_heading") : lang.t("lock_heading"))

            // 空亡全景诊断
            Button(action: {
                showKongwangSheet = true
            }) {
                HStack(spacing: 3) {
                    Circle().fill(kwColor).frame(width: 6, height: 6)
                    Text(kwStatus)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(kwColor.opacity(0.15))
                .foregroundColor(kwColor)
                .cornerRadius(6)
            }
            .accessibilityLabel(kwStatus)
            
            Spacer()
            
            // 校准
            Button(action: {
                showCalibSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "safari.fill")
                    Text(lang.t("btn_calib"))
                }
                .adaptiveFont(size: 11, weight: .medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .foregroundColor(motion.isDistorted ? Color.orange : Color(red: 0.95, green: 0.82, blue: 0.4))
                .cornerRadius(6)
            }

            // 图层设置
            Button(action: {
                showLayerSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "square.3.layers.3d")
                    Text(lang.t("btn_layers"))
                }
                .adaptiveFont(size: 11, weight: .medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .foregroundColor(Color.yanCyan)
                .cornerRadius(6)
            }
            
            // 八方全鉴
            Button(action: {
                showPalaceSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "square.grid.2x2")
                    Text(lang.t("btn_palace_all"))
                }
                .adaptiveFont(size: 11, weight: .medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                .cornerRadius(6)
            }
            
            // 今日吉方导引开关 (财神/喜神/奇门吉方 + 盘面金标联动)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    layers.showDailyGodMarkers.toggle()
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "location.north.line.fill")
                    Text(dailyGuideButtonTitle())
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(layers.showDailyGodMarkers ? Color.green.opacity(0.22) : Color.white.opacity(0.08))
                .foregroundColor(layers.showDailyGodMarkers ? .green : Color(red: 0.95, green: 0.85, blue: 0.45))
                .cornerRadius(6)
            }
            
            // 今日吉签海报
            Button(action: {
                showDailySignSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                    Text(dailySignShortTitle())
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.18))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                .cornerRadius(6)
            }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 今日吉方导引条 (财神/喜神/奇门实时比对)
    private func dailyDirectionBanner() -> some View {
        let dirs = ZeRiEngine.shared.dailyCompassDirections(for: Date())
        let currentFacing = motion.headingState.facingAngle
        let qimen = QimenEngine.shared.calculateChart(date: Date(), heading: currentFacing)
        let diffToWealth = abs(shortestAngleDelta(from: currentFacing, to: dirs.wealthAngle))
        let isAlignedWealth = diffToWealth <= 22.5
        
        return HStack(spacing: 8) {
            Image(systemName: isAlignedWealth ? "checkmark.seal.fill" : "safari.fill")
                .adaptiveFont(size: 13)
                .foregroundColor(isAlignedWealth ? .green : Color(red: 0.95, green: 0.85, blue: 0.45))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(wealthLabel()): \(dirs.wealthDirection) (\(Int(dirs.wealthAngle))°)")
                        .adaptiveFont(size: 11, weight: .bold)
                        .foregroundColor(isAlignedWealth ? .green : Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text("\(joyLabel()): \(dirs.joyDirection)")
                        .adaptiveFont(size: 10, weight: .semibold)
                        .foregroundColor(.yanCyan)
                }
                Text("\(qimenBestDoorPrefix()): \(qimen.bestNavDirection) · \(isAlignedWealth ? alignedWealthHint() : turnToWealthHint(deg: dirs.wealthAngle))")
                    .adaptiveFont(size: 10)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 4)
            
            Button(action: {
                motion.lockAtFacingAngle(dirs.wealthAngle)
            }) {
                Text(lockWealthBtnTitle())
                    .adaptiveFont(size: 10, weight: .bold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.22))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .cornerRadius(5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.12, green: 0.13, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isAlignedWealth ? Color.green.opacity(0.5) : Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func shortestAngleDelta(from a: Double, to b: Double) -> Double {
        var diff = (b - a).truncatingRemainder(dividingBy: 360.0)
        if diff > 180.0 { diff -= 360.0 }
        if diff < -180.0 { diff += 360.0 }
        return diff
    }
    
    private func dailyGuideButtonTitle() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "吉方导引"
        case .zhHant: return "吉方導引"
        case .en: return "Lucky Dir"
        case .ja: return "吉方ガイド"
        case .ko: return "길방가이드"
        case .vi: return "Hướng Cát"
        case .th: return "ทิศมงคล"
        case .id: return "Arah Hoki"
        default: return "吉方导引"
        }
    }
    
    private func dailySignShortTitle() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "吉签"
        case .zhHant: return "吉籤"
        case .en: return "Sign"
        case .ja: return "吉籤"
        case .ko: return "길첨"
        case .vi: return "Thẻ Cát"
        case .th: return "เซียมซี"
        case .id: return "Kartu"
        default: return "吉签"
        }
    }
    
    private func wealthLabel() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "今日财神"
        case .zhHant: return "今日財神"
        case .en: return "Wealth"
        case .ja: return "本日財神"
        case .ko: return "오늘 재신"
        case .vi: return "Thần Tài"
        case .th: return "เทพโชคลาภ"
        case .id: return "Arah Rejeki"
        default: return "今日财神"
        }
    }
    
    private func joyLabel() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "喜神"
        case .zhHant: return "喜神"
        case .en: return "Joy"
        case .ja: return "喜神"
        case .ko: return "희신"
        case .vi: return "Hỷ Thần"
        case .th: return "เทพมงคล"
        case .id: return "Sukacita"
        default: return "喜神"
        }
    }
    
    private func qimenBestDoorPrefix() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "时家奇门吉方"
        case .zhHant: return "時家奇門吉方"
        case .en: return "Qimen Best"
        case .ja: return "奇門吉方"
        case .ko: return "기문길방"
        case .vi: return "Kỳ Môn Cát"
        case .th: return "ฉีเหมิน"
        case .id: return "Qimen Terbaik"
        default: return "时家奇门吉方"
        }
    }
    
    private func alignedWealthHint() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "当前向首正对今日财神吉位"
        case .zhHant: return "當前向首正對今日財神吉位"
        case .en: return "Aligned with Today's Wealth Direction"
        case .ja: return "現在の向首は本日の財神吉方位と一致"
        case .ko: return "현재 향수가 오늘의 재신 길방과 일치"
        case .vi: return "Đang hướng thẳng về cung Thần Tài hôm nay"
        case .th: return "หันตรงกับทิศเทพโชคลาภวันนี้"
        case .id: return "Sejajar dengan Arah Rejeki Hari Ini"
        default: return "当前向首正对今日财神吉位"
        }
    }
    
    private func turnToWealthHint(deg: Double) -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return String(format: "转向 %.0f° 即对准财神位", deg)
        case .zhHant: return String(format: "轉向 %.0f° 即對準財神位", deg)
        case .en: return String(format: "Turn to %.0f° for Wealth Dir", deg)
        case .ja: return String(format: "%.0f° へ向けると財神方位", deg)
        case .ko: return String(format: "%.0f° 방향으로 돌리면 재신방", deg)
        case .vi: return String(format: "Xoay về %.0f° để đón Thần Tài", deg)
        case .th: return String(format: "หันไปที่ %.0f° เพื่อรับโชคลาภ", deg)
        case .id: return String(format: "Putar ke %.0f° untuk Arah Rejeki", deg)
        default: return String(format: "转向 %.0f° 即对准财神位", deg)
        }
    }
    
    private func lockWealthBtnTitle() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "定位于财神"
        case .zhHant: return "定位於財神"
        case .en: return "Point Wealth"
        case .ja: return "財神へ固定"
        case .ko: return "재신 고정"
        case .vi: return "Khóa Thần Tài"
        case .th: return "ล็อกทิศโชค"
        case .id: return "Kunci Rejeki"
        default: return "定位于财神"
        }
    }
    
    // MARK: - 展开态右侧研判工作台 (iPhone Duo 内屏 / iPad)
    //
    // 展开态右栏（独立滚动）：向首总览、一百二十分金度数跨度与秘传断语、
    // 六十四卦卦象与分金描述、空亡判级与化解指引，并附四个快捷入口。
    // 折叠态不渲染本面板（右栏改用 bottomStatusCard()，见 body 内分支）。
    private func unfoldedCompassAnalysisPanel() -> some View {
        let heading = motion.headingState
        let hex = Hexagram64Data.shared.hexagram(for: heading.facingAngle)
        let fenjin = Fenjin120Data.shared.resolveFenjin(for: heading.facingAngle)
        let kwLevel = heading.kongWangLevel

        // 空亡判级配色与文案 key（四档均有完整多语种文案，避免硬编码）
        let kwColor: Color
        let kwGradeKey: String
        let kwDescKey: String
        let kwRemedyKey: String
        switch kwLevel {
        case .pure:
            kwColor = Color.green
            kwGradeKey = "kw_pure_grade"
            kwDescKey = "kw_pure_desc"
            kwRemedyKey = "kw_pure_remedy"
        case .jianXiang:
            kwColor = Color.yellow
            kwGradeKey = "kw_sub_grade"
            kwDescKey = "kw_sub_desc"
            kwRemedyKey = "kw_sub_remedy"
        case .smallVoid:
            kwColor = Color.orange
            kwGradeKey = "kw_small_grade"
            kwDescKey = "kw_small_desc"
            kwRemedyKey = "kw_small_remedy"
        case .largeVoid:
            kwColor = Color.red
            kwGradeKey = "kw_large_grade"
            kwDescKey = "kw_large_desc"
            kwRemedyKey = "kw_large_remedy"
        }

        return VStack(alignment: .leading, spacing: 12) {
            // 1. 向首总览：实时度数 / 二十四山 / 俯仰横滚 / 磁场强度
            VStack(alignment: .leading, spacing: 8) {
                // 窄右栏（Duo 内屏 / iPad 分栏）里横向 HStack 会把泰语/印尼语
                // 无空格长词与数值、徽章挤成互相穿插；改为纵向堆叠，各占整行。
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.t("kw_heading_prefix"))
                        .adaptiveFont(size: 11, weight: .bold)
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text(String(format: "%.1f°", heading.facingAngle))
                            .adaptiveFont(size: 24, weight: .bold, design: .monospaced)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(fenjin.localizedMountainName)
                            .adaptiveFont(size: 12, weight: .bold)
                            .foregroundColor(Color.yanCyan)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                }
                HStack(spacing: 12) {
                    Text("\(lang.t("pitch_label")) \(String(format: "%.1f°", motion.pitch))")
                    Text("\(lang.t("roll_label")) \(String(format: "%.1f°", motion.roll))")
                    Text(String(format: "%.0f μT", motion.magneticStrengthUT))
                }
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(analysisPanelBackground())

            // 2. 一百二十分金：度数跨度 + 孤虚旺相秘传断语 + 立向指引
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t("fenjin_range_section"))
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(fenjin.localizedJiaziName)
                            .adaptiveFont(size: 13, weight: .bold, design: .serif)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 4)
                        Text(fenjin.localizedGrade)
                            .adaptiveFont(size: 10, weight: .bold)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(fenjin.isAuspicious ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(fenjin.isAuspicious ? Color.green : Color.red)
                            .cornerRadius(4)
                    }
                }
                Text("\(String(format: "%.1f", fenjin.startAngle))° \(lang.t("fenjin_to")) \(String(format: "%.1f", fenjin.endAngle))° · \(lang.t("fenjin_center_deg")) \(String(format: "%.1f", fenjin.centerAngle))°")
                    .adaptiveFont(size: 11, design: .monospaced)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(lang.t("fenjin_lore_section"))
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(fenjin.localizedLore)
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(fenjin.isAuspicious ? lang.t("fenjin_auspicious_advice") : lang.t("fenjin_inauspicious_advice"))
                    .adaptiveFont(size: 10)
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(analysisPanelBackground())

            // 3. 六十四卦：卦名 / 上下卦 / 卦气吉凶 / 穿山透地分金描述
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(hex.localizedName)
                        .adaptiveFont(size: 18, weight: .bold, design: .serif)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(hex.localizedUpperTrigram) · \(hex.localizedLowerTrigram)")
                            .adaptiveFont(size: 11)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Text(hex.localizedLuckDegree)
                            .adaptiveFont(size: 10, weight: .bold)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(hex.isGreatAuspicious ? Color.green.opacity(0.2) : Color.white.opacity(0.08))
                            .foregroundColor(hex.isGreatAuspicious ? Color.green : .white.opacity(0.85))
                            .cornerRadius(4)
                    }
                }
                Text(hex.localizedFenJinDetail)
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(analysisPanelBackground())

            // 4. 空亡判级与化解指引
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t("kw_sheet_title"))
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(lang.t(kwGradeKey))
                            .adaptiveFont(size: 10, weight: .bold)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(kwColor.opacity(0.2))
                            .foregroundColor(kwColor)
                            .cornerRadius(4)
                        Spacer(minLength: 0)
                    }
                }
                Text(kwLevel.localizedTitle)
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(kwColor)
                Text(lang.t(kwDescKey))
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text("\(lang.t("kw_master_remedy_section"))\(lang.t(kwRemedyKey))")
                    .adaptiveFont(size: 10)
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(analysisPanelBackground())

            // 4.5 今日出行吉方导引（财神 / 喜神 / 奇门吉门）
            dailyDirectionBanner()

            // 5. 快捷工具入口
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    analysisPanelToolButton(title: lang.t("btn_fenjin_detail"),
                                            systemImage: "ruler",
                                            tint: Color.yanCyan) { showFenjinSheet = true }
                    analysisPanelToolButton(title: lang.t("kw_sheet_title"),
                                            systemImage: "scope",
                                            tint: kwColor) { showKongwangSheet = true }
                }
                HStack(spacing: 8) {
                    analysisPanelToolButton(title: lang.t("btn_palace_all"),
                                            systemImage: "square.grid.2x2",
                                            tint: Color(red: 0.83, green: 0.68, blue: 0.21)) { showPalaceSheet = true }
                    analysisPanelToolButton(title: dailySignShortTitle(),
                                            systemImage: "sparkles.rectangle.stack.fill",
                                            tint: Color(red: 0.95, green: 0.85, blue: 0.45)) { showDailySignSheet = true }
                }
            }
        }
    }

    /// 研判工作台卡片底：深色圆角 + 淡金描边（与全工程卡片口径一致）
    private func analysisPanelBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.12, green: 0.12, blue: 0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.2), lineWidth: 1)
            )
    }

    /// 研判工作台快捷工具按钮
    private func analysisPanelToolButton(title: String,
                                        systemImage: String,
                                        tint: Color,
                                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .adaptiveFont(size: 11)
                Text(title)
                    .adaptiveFont(size: 11, weight: .bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 底部状态卡
    private func bottomStatusCard() -> some View {
        let hex = Hexagram64Data.shared.hexagram(for: motion.headingState.facingAngle)
        let fenjin = Fenjin120Data.shared.resolveFenjin(for: motion.headingState.facingAngle)
        
        return Button(action: {
            showFenjinSheet = true
        }) {
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 6) {
                        Text(hex.localizedName)
                            .adaptiveFont(size: 15, weight: .bold, design: .serif)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text(fenjin.localizedJiaziName)
                            .adaptiveFont(size: 11, weight: .bold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(fenjin.isAuspicious ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(fenjin.isAuspicious ? Color.green : Color.red)
                            .cornerRadius(4)
                        Text(fenjin.localizedGrade)
                            .adaptiveFont(size: 10)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Text(lang.t("btn_fenjin_detail"))
                            .adaptiveFont(size: 11)
                            .foregroundColor(Color.yanCyan)
                        Image(systemName: "chevron.right")
                            .adaptiveFont(size: 9)
                            .foregroundColor(Color.yanCyan)
                    }
                }
                
                HStack {
                    Text(fenjin.localizedLore)
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
