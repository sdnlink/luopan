import SwiftUI

// MARK: - 主罗盘界面 (Compass Main View)

public struct CompassMainView: View {
    public var isActive: Bool = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 布局环境值：iPad 横屏与 Duo 内屏一样走右栏研判工作台，竖屏回底部状态卡。
    @Environment(\.adaptiveLayoutForm) private var layoutForm
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    
    // 弹窗状态
    @State private var showFenjinSheet = false
    @State private var showKongwangSheet = false
    @State private var showPalaceSheet = false
    @State private var showLayerSheet = false
    @State private var showCalibSheet = false
    
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
                        
                        // 2. 罗盘快捷辅助工具条 (锁定朝向 / 分金详勘 / 空亡诊断 / 八方全鉴)
                        compassToolBar()
                            .padding(.top, 2)
                        
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
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(motion.isLocked ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                .foregroundColor(motion.isLocked ? .red : .white)
                .cornerRadius(6)
            }
            
            // 空亡全景诊断
            Button(action: {
                showKongwangSheet = true
            }) {
                HStack(spacing: 3) {
                    Circle().fill(kwColor).frame(width: 5, height: 5)
                    Text(kwStatus)
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(kwColor.opacity(0.15))
                .foregroundColor(kwColor)
                .cornerRadius(6)
            }
            
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
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
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
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
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
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                .cornerRadius(6)
            }
            }
            .padding(.horizontal, 16)
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
                .adaptiveFont(size: 10)
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
                            .adaptiveFont(size: 9, weight: .bold)
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
                            .adaptiveFont(size: 9, weight: .bold)
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
                            .adaptiveFont(size: 9, weight: .bold)
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
                    analysisPanelToolButton(title: lang.t("btn_calib"),
                                            systemImage: "safari.fill",
                                            tint: motion.isDistorted ? Color.orange : Color(red: 0.95, green: 0.82, blue: 0.4)) { showCalibSheet = true }
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
