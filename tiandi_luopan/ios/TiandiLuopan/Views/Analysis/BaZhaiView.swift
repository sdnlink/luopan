import SwiftUI
import UIKit

// MARK: - 八宅明镜与三合水法全景研判视图 (BaZhai & SanHe Water View)

public struct BaZhaiView: View {
    public var isActive: Bool = true
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @ObservedObject var kua = UserKuaProfileManager.shared
    @ObservedObject var retention = RetentionServiceManager.shared
    @State private var selectedSubTab: Int = 0 // 0: 八宅明镜, 1: 三合水法
    @State private var showPaywall: Bool = false
    @State private var showDailySignSheet: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var isUsingCustomDate: Bool = false
    @State private var showUpcomingDays: Bool = false
    @State private var showShichenTable: Bool = true
    @State private var showFamilySection: Bool = false
    @State private var selectedZeRiCategory: ZeRiEngine.ZeRiActivityCategory = .all
    @State private var cachedAnalysis: BaZhaiAnalysis?
    @State private var cachedWaterItems: [SanHeWaterItem]?
    @State private var cachedZeRi: ZeRiAnalysis?
    public var isEmbedded: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 布局环境值：iPad 横屏与 Duo 内屏一样分栏，竖屏回单列。
    @Environment(\.adaptiveLayoutForm) private var layoutForm
    /// 左右双栏形态（Duo 内屏 / iPad 横屏）—— 右栏展示三合 VIP 预览卡。
    private var isSplitLayout: Bool {
        AdaptiveLayout.isTwoPane(horizontal: horizontalSizeClass,
                                      vertical: verticalSizeClass, form: layoutForm)
    }
    private static let clockRefreshTimer = Timer.publish(
        every: 60,
        on: .main,
        in: .common
    ).autoconnect()
    
    public init(isEmbedded: Bool = false, isActive: Bool = true) {
        self.isEmbedded = isEmbedded
        self.isActive = isActive
    }
    
    public var body: some View {
        let state = motion.headingState
        return Group {
            if isActive {
                activeContent(state: state)
            } else {
                Color.clear
            }
        }

        .onAppear {
            refreshAnalysis()
        }
        .onChange(of: state.sittingMountain.id) { _ in
            refreshAnalysis()
        }
        .onChange(of: state.facingMountain.id) { _ in
            refreshAnalysis()
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            refreshAnalysis()
        }
        .onChange(of: isActive) { active in
            if active { refreshAnalysis() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshAnalysis()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshAnalysis()
        }
        .onReceive(Self.clockRefreshTimer) { _ in
            // ZeRi includes the current hour pillar. Refresh at a low rate so
            // an open page crosses an hour boundary without showing stale
            // recommendations, while hidden tabs do no calendar work.
            guard isActive else { return }
            refreshAnalysis()
        }
    }

    /// Build the expensive analysis only while the embedded sub-tab is
    /// visible. SwiftUI keeps sibling tabs alive, so doing this work at the
    /// top of `body` used to recalculate the calendar and water method on
    /// every compass sample even when the user was viewing another tab.
    @ViewBuilder
    private func activeContent(state: CompassHeadingState) -> some View {
        let effectiveDate = isUsingCustomDate ? selectedDate : Date()
        let bz = cachedAnalysis ?? BaZhaiEngine.shared.analyze(
            sittingPalace: state.sittingMountain.palace,
            facingPalace: state.facingMountain.palace
        )
        let shItems = cachedWaterItems ?? SanHeWaterEngine.shared.resolveWaterMethod(sitting: state.sittingMountain, facing: state.facingMountain)
        let zeri = cachedZeRi ?? ZeRiEngine.shared.analyze(sitting: state.sittingMountain, date: effectiveDate)

        let content = VStack(spacing: 16) {
            subTabBar()

            if selectedSubTab == 0 {
                baZhaiContent(bz: bz, zeri: zeri, state: state)
            } else {
                sanHeContent(shItems: shItems, state: state)
            }
        }
        .padding(.top, isEmbedded ? 0 : 12)
        .padding(.bottom, isEmbedded ? 0 : 24)
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
        .sheet(isPresented: $showDailySignSheet) {
            DailyAuspiciousCardSheet(targetDate: effectiveDate)
        }
        .onChange(of: selectedDate) { _ in
            isUsingCustomDate = true
            refreshAnalysis()
        }

        if isEmbedded {
            content
        } else {
            ScrollView {
                content
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
        }
    }

    private func refreshAnalysis() {
        guard isActive else { return }
        let state = motion.headingState
        let effectiveDate = isUsingCustomDate ? selectedDate : Date()
        cachedAnalysis = BaZhaiEngine.shared.analyze(
            sittingPalace: state.sittingMountain.palace,
            facingPalace: state.facingMountain.palace
        )
        cachedWaterItems = SanHeWaterEngine.shared.resolveWaterMethod(sitting: state.sittingMountain, facing: state.facingMountain)
        cachedZeRi = ZeRiEngine.shared.analyze(sitting: state.sittingMountain, date: effectiveDate)
    }
    
    // MARK: - 子 Tab 切换栏
    private func subTabBar() -> some View {
        let lang = LocalizationManager.shared
        return HStack(spacing: 0) {
            Button(action: { selectedSubTab = 0 }) {
                Text(lang.t("bazhai_tab_title"))
                    .adaptiveFont(size: 13, weight: selectedSubTab == 0 ? .bold : .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedSubTab == 0 ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.clear)
                    .foregroundColor(selectedSubTab == 0 ? .black : .white.opacity(0.7))
            }
            
            Button(action: { selectedSubTab = 1 }) {
                Text(lang.t("sanhe_tab_title"))
                    .adaptiveFont(size: 13, weight: selectedSubTab == 1 ? .bold : .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedSubTab == 1 ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.clear)
                    .foregroundColor(selectedSubTab == 1 ? .black : .white.opacity(0.7))
            }
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }
    
    // MARK: - 八宅明镜内容
    private func baZhaiContent(bz: BaZhaiAnalysis, zeri: ZeRiAnalysis, state: CompassHeadingState) -> some View {
        // iPhone Duo 展开态双栏：左栏 = 宅型概览与八方游年星（命盘核心），
        // 右栏 = 天星择日日课（分析解释）；折叠态保持原单列纵排。
        FoldableTwoPane(compactSpacing: 12) {
        VStack(spacing: 12) {
            // 宅型概览卡
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(bz.localizedHouseGua)
                            .adaptiveFont(size: 20, weight: .bold, design: .serif)
                            .foregroundColor(.white)
                        Text(bz.localizedHouseType)
                            .adaptiveFont(size: 12, weight: .bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(Color.orange)
                            .cornerRadius(4)
                    }
                    Text("\(lang.t("gate_facing_prefix"))：\(bz.localizedGateDirection) · \(lang.t("na_qi_prefix"))【\(bz.gateStar.localizedName)】")
                        .adaptiveFont(size: 13)
                        .foregroundColor(bz.gateStar.isAuspicious ? Color.green : Color.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer()
            }
            .padding(14)
            .background(Color(red: 0.12, green: 0.12, blue: 0.16))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            
            // 宅主命卦与人宅合一配对卡 (P1.1 + 全家成员命卦分房)
            ownerKuaCard(sittingPalace: state.sittingMountain.palace)

            // 21天气场调理打卡追踪清单
            if !retention.remedyTasks.isEmpty {
                remedyTrackerCard()
            }

            // 八方游年星列表
            VStack(spacing: 8) {
                ForEach(bz.items) { item in
                    let taskID = "bazhai-\(state.sittingMountain.palace)-\(item.guaName)"
                    let isSavedTask = retention.remedyTasks.contains(where: { $0.id == taskID })
                    // 固定 120pt 的方向列会把建议文字挤成竖排单字；改为纵向堆叠，
                    // 方向/星名一行、建议说明整行，所有语言都能完整换行。
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(item.localizedDirection)
                                .adaptiveFont(size: 14, weight: .bold)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.star.localizedName)
                                .adaptiveFont(size: 12, weight: .semibold)
                                .foregroundColor(item.star.isAuspicious ? Color(red: 0.4, green: 0.85, blue: 0.4) : Color(red: 0.95, green: 0.4, blue: 0.4))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Button(action: {
                                retention.toggleRemedyTask(
                                    id: taskID,
                                    palaceDirection: item.localizedDirection,
                                    title: item.star.localizedName,
                                    remedyAction: item.star.plainLanguageSummary
                                )
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: isSavedTask ? "checkmark.circle.fill" : "plus.circle")
                                        .font(.system(size: 10))
                                    Text(remedyButtonLabel(isSaved: isSavedTask))
                                        .adaptiveFont(size: 10, weight: .bold)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(isSavedTask ? Color.green.opacity(0.22) : Color.white.opacity(0.08))
                                .foregroundColor(isSavedTask ? .green : .white.opacity(0.8))
                                .cornerRadius(5)
                            }
                        }
                        // 顶置白话吉凶速断 (P2.1)
                        Text(item.star.plainLanguageSummary)
                            .adaptiveFont(size: 11, weight: .semibold)
                            .foregroundColor(item.star.isAuspicious ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.orange)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(item.star.localizedSuggestion)
                            .adaptiveFont(size: 12)
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            }
            } analysis: {
            // 天星择日 · 动土安门日课自检卡（展开态右栏 / 折叠态底部）
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text(lang.t("zeri_title"))
                            .adaptiveFont(size: 14, weight: .bold)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(zeri.overallStatus)
                        .adaptiveFont(size: 11, weight: .bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(zeri.isAuspicious ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .foregroundColor(zeri.isAuspicious ? Color.green : Color.red)
                        .cornerRadius(4)
                }

                // P0.3 日期/时辰穿越拨盘
                zeRiDateControlBar()
                
                Text("\(lang.t("current_four_pillars"))：\(zeri.fourPillarsText)")
                    .adaptiveFont(size: 12, weight: .semibold, design: .serif)
                    .foregroundColor(Color.yanCyan)
                
                Text(zeri.detailsText)
                    .adaptiveFont(size: 12)
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(2)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text(lang.t("auspicious_fit"))
                            .adaptiveFont(size: 10, weight: .bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(3)
                        Text(zeri.yiActivities.joined(separator: " · "))
                            .adaptiveFont(size: 11)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text(lang.t("inauspicious_avoid"))
                            .adaptiveFont(size: 10, weight: .bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(3)
                        Text(zeri.jiActivities.joined(separator: " · "))
                            .adaptiveFont(size: 11)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }

                Divider().background(Color.white.opacity(0.1))

                // 当日十二时辰黄黑道吉凶表
                shichenTableSection()

                Divider().background(Color.white.opacity(0.1))

                // 未来 30 天黄道吉日一键筛选与提醒 (P0.3 & P1.3)
                upcomingAuspiciousDaysSection(state: state)
            }
            .padding(12)
            .background(Color(red: 0.12, green: 0.12, blue: 0.16))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 三合与杨公八煞黄泉消砂内容
    private func sanHeContent(shItems: [SanHeWaterItem], state: CompassHeadingState) -> some View {
        let hq = SanHeWaterEngine.shared.resolveHuangQuanWater(facing: state.facingMountain)
        let basha = SanHeWaterEngine.shared.resolveBaSha(sitting: state.sittingMountain)
        
        let lang = LocalizationManager.shared
        // iPhone Duo 展开态双栏：左栏 = 黄泉水法判据与曜煞消砂（判据核心），
        // 右栏 = 十二长生水法总纲与流派列表（分析解释）；折叠态保持原单列纵排。
        return FoldableTwoPane(compactSpacing: 12) {
        VStack(spacing: 12) {
            if !iap.hasUnlockedVIP {
                VIPLockCardView(
                    title: lang.t("privilege_sanhe_title"),
                    featureDesc: lang.t("privilege_sanhe_desc"),
                    badge: lang.t("vip_badge_title"),
                    targetProductId: .vipYearly,
                    onUnlockTap: { showPaywall = true }
                )
            } else {
                // 1. 八路黄泉水法判据卡
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "drop.triangle.fill")
                                .foregroundColor(Color.yanCyan)
                            Text(lang.t("yang_gong_water_title"))
                                .adaptiveFont(size: 14, weight: .bold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text(hq.badgeText)
                            .adaptiveFont(size: 11, weight: .bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(hq.isJiuPin ? Color.green.opacity(0.2) : (hq.isDanger ? Color.red.opacity(0.2) : Color.blue.opacity(0.2)))
                            .foregroundColor(hq.isJiuPin ? Color.green : (hq.isDanger ? Color.red : Color.yanCyan))
                            .cornerRadius(4)
                    }
                    
                    Text(hq.waterDesc)
                        .adaptiveFont(size: 12)
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(3)
                    
                    Text("\(lang.t("song_quote"))：“\(hq.localizedQuote)”")
                        .adaptiveFont(size: 10, design: .serif)
                        .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                }
                .padding(12)
                .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                
                // 2. 坐山曜煞消峰消砂卡
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "triangle.fill")
                                .foregroundColor(Color.orange)
                            Text(lang.t("sitting_mountain_clash"))
                                .adaptiveFont(size: 14, weight: .bold)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text("\(lang.t("clash_at"))【\(basha.localizedShaDir)】")
                            .adaptiveFont(size: 11, weight: .bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(Color.orange)
                            .cornerRadius(4)
                    }
                    
                    Text(basha.lore)
                        .adaptiveFont(size: 12)
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(2)
                    
                    Text(basha.remedy)
                        .adaptiveFont(size: 11)
                        .foregroundColor(Color.yellow.opacity(0.9))
                        .lineSpacing(2)
                    
                    Text("\(lang.t("song_quote"))：“\(basha.localizedSong)”\n\(basha.localizedXiaoShaRule)")
                        .adaptiveFont(size: 10, design: .serif)
                        .foregroundColor(.white.opacity(0.6))
                        .lineSpacing(2)
                }
                .padding(12)
                .background(Color(red: 0.13, green: 0.11, blue: 0.11))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                }
                }
                } analysis: {
                // 3. 三合十二长生水法总纲卡 + 4. 十二长生流派列表（展开态右栏 / 折叠态底部）
                if iap.hasUnlockedVIP {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(lang.t("water_rule_12")): \(state.sittingMountain.localizedName)\(lang.t("mountain_suffix"))")
                            .adaptiveFont(size: 14, weight: .bold)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text(lang.t("water_rule_desc"))
                            .adaptiveFont(size: 11)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                
                // 4. 十二长生流派列表
                VStack(spacing: 8) {
                    ForEach(Array(shItems.prefix(12))) { item in
                        HStack {
                            Text(item.localizedMountainName + lang.t("mountain_suffix"))
                                .adaptiveFont(size: 15, weight: .bold, design: .serif)
                                .foregroundColor(.white)
                                // iPad regular 宽度下字号放大 1.35x，固定 60pt 会让英文/泰文山名挤成竖排；
                                // 改成最小宽度 + 最多两行，并跟随系统字号一起放宽。
                                .frame(minWidth: (horizontalSizeClass == .regular ? 90 : 60)
                                       * AdaptiveFontMetrics.dynamicTypeScale(for: dynamicTypeSize),
                                       alignment: .leading)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Text("【\(item.phase.localizedName)】")
                                .adaptiveFont(size: 13, weight: .bold)
                                .foregroundColor(item.phase == .changSheng || item.phase == .diWang ? Color.green : (item.phase == .mu || item.phase == .jue ? Color.orange : Color.white.opacity(0.8)))
                                .frame(minWidth: (horizontalSizeClass == .regular ? 110 : 80)
                                       * AdaptiveFontMetrics.dynamicTypeScale(for: dynamicTypeSize),
                                       alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            
                            Text(item.phase.localizedWaterRule)
                                .adaptiveFont(size: 12)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            if item.isHuangQuanSha {
                                Text(lang.t("huangquan_sha"))
                                    .adaptiveFont(size: 9, weight: .bold)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.3))
                                    .foregroundColor(.red)
                                    .cornerRadius(3)
                            }
                        }
                        .padding(10)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                } else if isSplitLayout {
                    sanHeVIPPreviewCard()
                }
            }
    }
    // MARK: - 三合水法 VIP 展开态预览占位卡 (消除展开态双栏右侧留白)
    private func sanHeVIPPreviewCard() -> some View {
        let lang = LocalizationManager.shared
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .adaptiveFont(size: 16)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(lang.t("privilege_sanhe_title"))
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

            Text(lang.t("privilege_sanhe_desc"))
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)

            Divider().background(Color.white.opacity(0.1))

            Text("💡 \(lang.t("water_rule_12")) · \(lang.t("privilege_sh_feature_title"))")
                .adaptiveFont(size: 12, weight: .semibold)
                .foregroundColor(Color.yanCyan)

            VStack(alignment: .leading, spacing: 6) {
                Text("• \(lang.t("privilege_sh_bullet_1"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                Text("• \(lang.t("privilege_sh_bullet_2"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                Text("• \(lang.t("privilege_sh_bullet_3"))")
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
        .padding(.horizontal, 16)
    }

    // MARK: - P1.1 宅主命卦画像与「人宅合一」配对卡
    private func ownerKuaCard(sittingPalace: String) -> some View {
        let compat = kua.evaluateCompatibility(sittingPalace: sittingPalace)
        let titleLabel: String
        let yearPrefix: String
        let maleLabel: String
        let femaleLabel: String
        let wealthLabel: String
        let studyLabel: String
        switch lang.effectiveLanguage {
        case .en:
            titleLabel = "Owner Life Gua & House Match"
            yearPrefix = "Born"
            maleLabel = "M"
            femaleLabel = "F"
            wealthLabel = "Wealth"
            studyLabel = "Study"
        case .zhHant:
            titleLabel = "宅主本命卦 · 人宅合一配對"
            yearPrefix = "生辰"
            maleLabel = "男"
            femaleLabel = "女"
            wealthLabel = "本命財位"
            studyLabel = "本命文昌"
        case .ja:
            titleLabel = "家主本命卦・宅命相配診断"
            yearPrefix = "生年"
            maleLabel = "男"
            femaleLabel = "女"
            wealthLabel = "本命財位"
            studyLabel = "本命文昌"
        case .ko:
            titleLabel = "건축주 본명괘 · 택명상배"
            yearPrefix = "생년"
            maleLabel = "남"
            femaleLabel = "여"
            wealthLabel = "본명재위"
            studyLabel = "본명문창"
        case .vi:
            titleLabel = "Bản Mệnh Trạch Chủ & Phối Quẻ"
            yearPrefix = "Sinh"
            maleLabel = "Nam"
            femaleLabel = "Nữ"
            wealthLabel = "Tài Vị"
            studyLabel = "Văn Xương"
        case .th:
            titleLabel = "รหัสชีวิตเจ้าของบ้าน & สมดุลบ้าน"
            yearPrefix = "ปีเกิด"
            maleLabel = "ชาย"
            femaleLabel = "หญิง"
            wealthLabel = "ทิศโชคลาภ"
            studyLabel = "ทิศการศึกษา"
        case .id:
            titleLabel = "Gua Pemilik & Keselarasan Rumah"
            yearPrefix = "Lahir"
            maleLabel = "P"
            femaleLabel = "W"
            wealthLabel = "Arah Rezeki"
            studyLabel = "Arah Studi"
        case .auto, .zhHans:
            titleLabel = "宅主本命卦 · 人宅合一配对"
            yearPrefix = "生辰"
            maleLabel = "男"
            femaleLabel = "女"
            wealthLabel = "本命财位"
            studyLabel = "本命文昌"
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.text.rectangle.fill")
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(titleLabel)
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()

                // 出生年份下拉选择
                Menu {
                    ForEach((1940...2025).reversed(), id: \.self) { yr in
                        Button(action: {
                            kua.birthYear = yr
                            refreshAnalysis()
                        }) {
                            HStack {
                                Text("\(String(yr))")
                                if yr == kua.birthYear { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text("\(yearPrefix) \(String(kua.birthYear))")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }

                // 性别切换
                Button(action: {
                    kua.isMale.toggle()
                    refreshAnalysis()
                }) {
                    Text(kua.isMale ? maleLabel : femaleLabel)
                        .adaptiveFont(size: 11, weight: .bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yanCyan.opacity(0.2))
                        .foregroundColor(Color.yanCyan)
                        .cornerRadius(6)
                }
            }

            HStack(spacing: 8) {
                Text("【\(compat.localizedOwnerGuaName) · \(compat.localizedLifeGroup) · \(compat.localizedZodiacName)】")
                    .adaptiveFont(size: 12, weight: .bold)
                    .foregroundColor(Color.yanCyan)
                Spacer()
                Text(compat.matchBadgeTitle)
                    .adaptiveFont(size: 10, weight: .bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((compat.isMatchedWithHouse ? Color.green : Color.orange).opacity(0.2))
                    .foregroundColor(compat.isMatchedWithHouse ? Color.green : Color.orange)
                    .cornerRadius(4)
            }

            Text(compat.matchAdvice)
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text("💰 \(wealthLabel): \(compat.wealthDirection)")
                    .adaptiveFont(size: 11, weight: .semibold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
                Text("📚 \(studyLabel): \(compat.studyDirection)")
                    .adaptiveFont(size: 11, weight: .semibold)
                    .foregroundColor(.white.opacity(0.85))
            }

            Divider().background(Color.white.opacity(0.1))

            // 全家成员命卦与智能分房档案
            familyMembersSection(maleLabel: maleLabel, femaleLabel: femaleLabel)
        }
        .padding(12)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func familyMembersSection(maleLabel: String, femaleLabel: String) -> some View {
        let headerTitle: String
        let addHint: String
        switch lang.effectiveLanguage {
        case .en:
            headerTitle = "Family Members Life Gua & Smart Room Fit (\(kua.familyMembers.count))"
            addHint = "+ Add Member"
        case .zhHant:
            headerTitle = "全家成員命卦與智能分房檔案（\(kua.familyMembers.count)人）"
            addHint = "+ 添加家人"
        case .ja:
            headerTitle = "家族全員の本命卦・部屋割診断（\(kua.familyMembers.count)名）"
            addHint = "+ 家族追加"
        case .ko:
            headerTitle = "가족 구성원 본명괘 및 방 배정 (\(kua.familyMembers.count)명)"
            addHint = "+ 가족 추가"
        case .vi:
            headerTitle = "Bản Mệnh Gia Đình & Phân Phòng (\(kua.familyMembers.count))"
            addHint = "+ Thêm người"
        case .th:
            headerTitle = "รหัสชีวิตสมาชิกครอบครัว & จัดห้อง (\(kua.familyMembers.count))"
            addHint = "+ เพิ่มสมาชิก"
        case .id:
            headerTitle = "Gua Anggota Keluarga & Kamar (\(kua.familyMembers.count))"
            addHint = "+ Tambah"
        case .auto, .zhHans:
            headerTitle = "全家成员命卦与智能分房档案（\(kua.familyMembers.count)人）"
            addHint = "+ 添加家人"
        }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: {
                    withAnimation { showFamilySection.toggle() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yanCyan)
                        Text(headerTitle)
                            .adaptiveFont(size: 11, weight: .bold)
                            .foregroundColor(.yanCyan)
                        Image(systemName: showFamilySection ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                Spacer()
                Menu {
                    ForEach(FamilyRole.allCases) { role in
                        Button(action: {
                            let defaultYear = (role == .elder) ? 1965 : ((role == .spouse) ? kua.birthYear : 2015)
                            kua.addOrUpdateFamilyMember(role: role, birthYear: defaultYear, isMale: role.defaultIsMale)
                            showFamilySection = true
                        }) {
                            Text(role.localizedTitle)
                        }
                    }
                } label: {
                    Text(addHint)
                        .adaptiveFont(size: 10, weight: .bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.yanCyan.opacity(0.18))
                        .foregroundColor(.yanCyan)
                        .cornerRadius(4)
                }
            }

            if showFamilySection && !kua.familyMembers.isEmpty {
                VStack(spacing: 6) {
                    ForEach(kua.familyMembers) { member in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(member.role.localizedTitle)
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .foregroundColor(.white)
                                Text("【\(member.localizedGuaBadge)】")
                                    .adaptiveFont(size: 10, weight: .bold)
                                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                Spacer()
                                Menu {
                                    ForEach((1935...2026).reversed(), id: \.self) { yr in
                                        Button(action: {
                                            kua.addOrUpdateFamilyMember(role: member.role, birthYear: yr, isMale: member.isMale)
                                        }) {
                                            Text("\(String(yr))")
                                        }
                                    }
                                } label: {
                                    Text("\(String(member.birthYear))▾")
                                        .adaptiveFont(size: 10, weight: .semibold)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                Button(action: {
                                    kua.addOrUpdateFamilyMember(role: member.role, birthYear: member.birthYear, isMale: !member.isMale)
                                }) {
                                    Text(member.isMale ? maleLabel : femaleLabel)
                                        .adaptiveFont(size: 10, weight: .bold)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.yanCyan.opacity(0.18))
                                        .foregroundColor(.yanCyan)
                                        .cornerRadius(4)
                                }
                                Button(action: {
                                    kua.removeFamilyMember(role: member.role)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.45))
                                }
                            }
                            Text(member.personalWealthAndStudySummary)
                                .adaptiveFont(size: 10)
                                .foregroundColor(.white.opacity(0.78))
                        }
                        .padding(7)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }

    private func remedyButtonLabel(isSaved: Bool) -> String {
        switch lang.effectiveLanguage {
        case .en: return isSaved ? "Tracked" : "+ Track"
        case .zhHant: return isSaved ? "已入清單" : "+ 調理打卡"
        case .ja: return isSaved ? "登録済" : "+ 対策記録"
        case .ko: return isSaved ? "등록됨" : "+ 조리체크"
        case .vi: return isSaved ? "Đã lưu" : "+ Theo dõi"
        case .th: return isSaved ? "บันทึกแล้ว" : "+ ติดตาม"
        case .id: return isSaved ? "Tersimpan" : "+ Lacak"
        case .auto, .zhHans: return isSaved ? "已入清单" : "+ 调理打卡"
        }
    }

    private func remedyDayCycleBadge(days: Int) -> String {
        switch lang.effectiveLanguage {
        case .en: return "Day \(days)/21"
        case .zhHant, .ja: return "第\(days)/21天"
        case .ko: return "\(days)/21일차"
        case .vi: return "Ngày \(days)/21"
        case .th: return "วันที่ \(days)/21"
        case .id: return "Hari \(days)/21"
        case .auto, .zhHans: return "第\(days)/21天"
        }
    }

    // MARK: - 21天气场调理与化煞催旺打卡清单
    private func remedyTrackerCard() -> some View {
        let title: String
        switch lang.effectiveLanguage {
        case .en: title = "My Fengshui Remedy & Activation Tracker (\(retention.remedyTasks.count))"
        case .zhHant: title = "我家化煞催旺調理打卡清單（\(retention.remedyTasks.count)項 · 換月複盤）"
        case .ja: title = "我が家の風水対策・催旺チェックリスト（\(retention.remedyTasks.count)件）"
        case .ko: title = "우리집 풍수 비보·최왕 실천 체크리스트 (\(retention.remedyTasks.count)건)"
        case .vi: title = "Danh Sách Hóa Sát & Kích Tài Lộc Gia Đình (\(retention.remedyTasks.count))"
        case .th: title = "รายการปรับฮวงจุ้ยและเสริมมงคลประจำบ้าน (\(retention.remedyTasks.count))"
        case .id: title = "Daftar Pelacak Solusi Fengshui Rumah (\(retention.remedyTasks.count))"
        case .auto, .zhHans: title = "我家化煞催旺调理打卡清单（\(retention.remedyTasks.count)项 · 换月复盘）"
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist.checked")
                    .foregroundColor(.green)
                Text(title)
                    .adaptiveFont(size: 12, weight: .bold)
                    .foregroundColor(.green)
                Spacer()
            }

            ForEach(retention.remedyTasks) { task in
                let elapsedDays = max(1, min(21, (Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0) + 1))
                HStack(alignment: .top, spacing: 8) {
                    Button(action: {
                        retention.toggleRemedyCompletion(id: task.id)
                    }) {
                        Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                            .foregroundColor(task.isCompleted ? .green : .white.opacity(0.6))
                            .font(.system(size: 14))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("\(task.palaceDirection) · \(task.title)")
                                .adaptiveFont(size: 11, weight: .bold)
                                .foregroundColor(task.isCompleted ? .white.opacity(0.5) : .white)
                                .strikethrough(task.isCompleted)
                            Text(remedyDayCycleBadge(days: elapsedDays))
                                .adaptiveFont(size: 9, weight: .bold, design: .monospaced)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.18))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                        Text(task.remedyAction)
                            .adaptiveFont(size: 10)
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Button(action: {
                        retention.removeRemedyTask(id: task.id)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                .padding(7)
                .background(Color.white.opacity(0.04))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Color(red: 0.11, green: 0.13, blue: 0.12))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }

    // MARK: - P0.3 择日日期与时辰穿越拨盘
    private func zeRiDateControlBar() -> some View {
        let prevLabel: String
        let nextLabel: String
        let nowLabel: String
        let signBtn: String
        switch lang.effectiveLanguage {
        case .en:
            prevLabel = "-1d"; nextLabel = "+1d"; nowLabel = "Now"; signBtn = "Sign Card"
        case .zhHant:
            prevLabel = "前一日"; nextLabel = "後一日"; nowLabel = "回到今日"; signBtn = "生成吉籤"
        case .ja:
            prevLabel = "前日"; nextLabel = "翌日"; nowLabel = "今日へ"; signBtn = "吉籤作成"
        case .ko:
            prevLabel = "-1일"; nextLabel = "+1일"; nowLabel = "오늘"; signBtn = "길첨카드"
        case .vi:
            prevLabel = "-1 ngày"; nextLabel = "+1 ngày"; nowLabel = "Hôm nay"; signBtn = "Thẻ Cát"
        case .th:
            prevLabel = "-1 วัน"; nextLabel = "+1 วัน"; nowLabel = "วันนี้"; signBtn = "การ์ดมงคล"
        case .id:
            prevLabel = "-1 hr"; nextLabel = "+1 hr"; nowLabel = "Hari Ini"; signBtn = "Kartu Hoki"
        case .auto, .zhHans:
            prevLabel = "前一日"; nextLabel = "后一日"; nowLabel = "回到今日"; signBtn = "生成吉签"
        }

        return HStack(spacing: 6) {
            Button(action: {
                let base = isUsingCustomDate ? selectedDate : Date()
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: base) ?? base
                isUsingCustomDate = true
                refreshAnalysis()
            }) {
                Text(prevLabel)
                    .adaptiveFont(size: 10, weight: .semibold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }

            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .colorScheme(.dark)
            .scaleEffect(0.88)

            Button(action: {
                let base = isUsingCustomDate ? selectedDate : Date()
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: base) ?? base
                isUsingCustomDate = true
                refreshAnalysis()
            }) {
                Text(nextLabel)
                    .adaptiveFont(size: 10, weight: .semibold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(5)
            }

            if isUsingCustomDate {
                Button(action: {
                    isUsingCustomDate = false
                    selectedDate = Date()
                    refreshAnalysis()
                }) {
                    Text(nowLabel)
                        .adaptiveFont(size: 10, weight: .bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.yanCyan.opacity(0.2))
                        .foregroundColor(Color.yanCyan)
                        .cornerRadius(5)
                }
            }

            Spacer(minLength: 0)

            Button(action: {
                showDailySignSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 9, weight: .bold))
                    Text(signBtn)
                        .adaptiveFont(size: 10, weight: .bold)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.2))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                .cornerRadius(5)
            }
        }
    }

    // MARK: - 当日十二时辰黄黑道吉凶表
    private func shichenTableSection() -> some View {
        let effectiveDate = isUsingCustomDate ? selectedDate : Date()
        let shichenList = ZeRiEngine.shared.calculateTwelveShichen(
            for: effectiveDate,
            ownerBirthYear: kua.isProfileEnabled ? kua.birthYear : nil
        )
        let currentHour = Calendar.current.component(.hour, from: effectiveDate)
        let currentBranchIdx = ((currentHour + 1) / 2) % 12

        let titleText: String
        let auspiciousTag: String
        let inauspiciousTag: String
        let clashTag: String
        switch lang.effectiveLanguage {
        case .en:
            titleText = "12 Two-Hour Periods (Yellow/Black Path Auspicious Hours)"
            auspiciousTag = "Good"
            inauspiciousTag = "Avoid"
            clashTag = "Clash"
        case .zhHant:
            titleText = "當日十二時辰黃黑道吉凶表（點擊切換時辰）"
            auspiciousTag = "吉"
            inauspiciousTag = "凶"
            clashTag = "沖主"
        case .ja:
            titleText = "当日十二時辰・黄黒道吉凶表（タップで時辰切替）"
            auspiciousTag = "吉"
            inauspiciousTag = "凶"
            clashTag = "沖"
        case .ko:
            titleText = "당일 십이시진 황흑도 길흉표 (탭하여 시간 변경)"
            auspiciousTag = "길"
            inauspiciousTag = "흉"
            clashTag = "충"
        case .vi:
            titleText = "Bảng 12 Canh Giờ Hoàng Hắc Đạo Trong Ngày"
            auspiciousTag = "Cát"
            inauspiciousTag = "Hung"
            clashTag = "Xung"
        case .th:
            titleText = "ตาราง 12 ยามมงคลประจำวัน (แตะเพื่อเปลี่ยนเวลา)"
            auspiciousTag = "ดี"
            inauspiciousTag = "เลี่ยง"
            clashTag = "ชง"
        case .id:
            titleText = "Tabel 12 Jam Keberuntungan Harian (Ketuk Jam)"
            auspiciousTag = "Baik"
            inauspiciousTag = "Hindari"
            clashTag = "Bentrok"
        case .auto, .zhHans:
            titleText = "当日十二时辰黄黑道吉凶表（点击切换时辰）"
            auspiciousTag = "吉"
            inauspiciousTag = "凶"
            clashTag = "冲主"
        }

        let columns = [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6)
        ]

        return VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation { showShichenTable.toggle() }
            }) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(Color.yanCyan)
                    Text(titleText)
                        .adaptiveFont(size: 11, weight: .bold)
                        .foregroundColor(Color.yanCyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer()
                    Image(systemName: showShichenTable ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            if showShichenTable {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(shichenList) { item in
                        let isSelectedHour = item.branchIndex == currentBranchIdx
                        Button(action: {
                            var cal = Calendar.current
                            cal.timeZone = .current
                            var comps = cal.dateComponents([.year, .month, .day], from: effectiveDate)
                            comps.hour = item.branchIndex == 0 ? 0 : (item.branchIndex * 2 - 1)
                            comps.minute = 30
                            if let newDate = cal.date(from: comps) {
                                selectedDate = newDate
                                isUsingCustomDate = true
                                refreshAnalysis()
                            }
                        }) {
                            VStack(spacing: 2) {
                                HStack(spacing: 3) {
                                    Text(item.localizedPillar)
                                        .adaptiveFont(size: 11, weight: .bold)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    Text(item.clashesOwner ? clashTag : (item.isAuspicious ? auspiciousTag : inauspiciousTag))
                                        .adaptiveFont(size: 9, weight: .bold)
                                        .padding(.horizontal, 3.5)
                                        .padding(.vertical, 1)
                                        .background((item.isAuspicious ? Color.green : Color.red).opacity(0.22))
                                        .foregroundColor(item.isAuspicious ? Color.green : Color.red)
                                        .cornerRadius(3)
                                }
                                Text(item.localizedGodName)
                                    .adaptiveFont(size: 9, weight: .medium)
                                    .foregroundColor(item.isAuspicious ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white.opacity(0.6))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(item.timeRange)
                                    .adaptiveFont(size: 8, design: .monospaced)
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 4)
                            .background(
                                isSelectedHour
                                    ? Color.yanCyan.opacity(0.18)
                                    : (item.isAuspicious ? Color.green.opacity(0.06) : Color.white.opacity(0.04))
                            )
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        isSelectedHour ? Color.yanCyan : (item.isAuspicious ? Color.green.opacity(0.25) : Color.clear),
                                        lineWidth: isSelectedHour ? 1.2 : 0.8
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - P0.3 & P1.3 未来 30 天黄道吉日一键速查与本地提醒
    private func upcomingAuspiciousDaysSection(state: CompassHeadingState) -> some View {
        let toggleTitle: String
        let remindLabel: String
        let remindedLabel: String
        switch lang.effectiveLanguage {
        case .en:
            toggleTitle = "Upcoming 30-Day Auspicious Calendar (No Clash)"
            remindLabel = "Remind"
            remindedLabel = "Scheduled"
        case .zhHant:
            toggleTitle = "未來30天動土/入宅黃道吉日速查（避歲破月破衝山及宅主生肖）"
            remindLabel = "吉日提醒"
            remindedLabel = "已設提醒"
        case .ja:
            toggleTitle = "今後30日間の動土・引越し吉日速見表（歳破・月破・坐山衝回避）"
            remindLabel = "通知登録"
            remindedLabel = "登録済"
        case .ko:
            toggleTitle = "향후 30일 동토·입택 황도길일 속람 (세파·월파·충산 회피)"
            remindLabel = "길일알림"
            remindedLabel = "알림설정됨"
        case .vi:
            toggleTitle = "Lịch Ngày Hoàng Đạo 30 Ngày Tới (Tránh Tuế Phá & Xung Sơn)"
            remindLabel = "Nhắc lịch"
            remindedLabel = "Đã hẹn"
        case .th:
            toggleTitle = "ปฏิทินฤกษ์มงคล 30 วันข้างหน้า (เลี่ยงวันชงทิศบ้านและปีเกิด)"
            remindLabel = "แจ้งเตือน"
            remindedLabel = "ตั้งเตือนแล้ว"
        case .id:
            toggleTitle = "Kalender Hari Baik 30 Hari ke Depan (Bebas Benturan)"
            remindLabel = "Ingatkan"
            remindedLabel = "Terjadwal"
        case .auto, .zhHans:
            toggleTitle = "未来30天动土/入宅黄道吉日速查（避岁破月破冲山及宅主生肖）"
            remindLabel = "吉日提醒"
            remindedLabel = "已设提醒"
        }

        return VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation { showUpcomingDays.toggle() }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(toggleTitle)
                        .adaptiveFont(size: 11, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Image(systemName: showUpcomingDays ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            if showUpcomingDays {
                // 事由分类筛选栏 (全部 / 入宅乔迁 / 动土修造 / 开业求财 / 安床嫁娶)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ZeRiEngine.ZeRiActivityCategory.allCases) { cat in
                            let isSelected = selectedZeRiCategory == cat
                            Button(action: {
                                selectedZeRiCategory = cat
                            }) {
                                Text(cat.localizedTitle)
                                    .adaptiveFont(size: 10, weight: isSelected ? .bold : .medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        isSelected
                                            ? Color(red: 0.95, green: 0.85, blue: 0.45)
                                            : Color.white.opacity(0.08)
                                    )
                                    .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                let upcoming = ZeRiEngine.shared.findUpcomingAuspiciousDays(
                    sitting: state.sittingMountain,
                    from: Date(),
                    days: 30,
                    ownerBirthYear: kua.isProfileEnabled ? kua.birthYear : nil,
                    category: selectedZeRiCategory,
                    limit: 6
                )
                VStack(spacing: 6) {
                    ForEach(upcoming) { day in
                        let isScheduled = retention.scheduledDayIDs.contains(day.id)
                        HStack(spacing: 8) {
                            Button(action: {
                                selectedDate = day.date
                                isUsingCustomDate = true
                                refreshAnalysis()
                            }) {
                                HStack(spacing: 6) {
                                    Text(day.dateLabel)
                                        .adaptiveFont(size: 12, weight: .bold, design: .monospaced)
                                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                    Text("【\(day.localizedDayPillar)】")
                                        .adaptiveFont(size: 12, weight: .bold)
                                        .foregroundColor(.green)
                                    Text(day.dayOfficerBadge)
                                        .adaptiveFont(size: 10, weight: .bold)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.yanCyan.opacity(0.18))
                                        .foregroundColor(Color.yanCyan)
                                        .cornerRadius(3)
                                    Text(day.yiSummary)
                                        .adaptiveFont(size: 11)
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Button(action: {
                                retention.toggleAuspiciousDayReminder(
                                    day: day,
                                    sittingName: "\(state.sittingMountain.localizedName)\(lang.t("mountain_suffix"))"
                                )
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: isScheduled ? "bell.badge.fill" : "bell")
                                        .font(.system(size: 10))
                                    Text(isScheduled ? remindedLabel : remindLabel)
                                        .adaptiveFont(size: 10, weight: .bold)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(isScheduled ? Color.green.opacity(0.22) : Color.white.opacity(0.1))
                                .foregroundColor(isScheduled ? Color.green : .white.opacity(0.85))
                                .cornerRadius(5)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
}