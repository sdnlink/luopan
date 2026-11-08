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
    @State private var showAddFamilyMemberDialog: Bool = false
    @State private var showEditOwnerKuaDialog: Bool = false
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
        .overlay(
            Group {
                if showAddFamilyMemberDialog {
                    AddFamilyMemberDialog(
                        isPresented: $showAddFamilyMemberDialog,
                        ownerBirthYear: kua.birthYear,
                        ownerIsMale: kua.isMale,
                        onConfirm: { role, customName, year, isMale in
                            kua.addFamilyMember(role: role, customName: customName, birthYear: year, isMale: isMale)
                            withAnimation {
                                showFamilySection = true
                            }
                            refreshAnalysis()
                        }
                    )
                } else if showEditOwnerKuaDialog {
                    EditOwnerKuaDialog(
                        isPresented: $showEditOwnerKuaDialog,
                        sittingPalace: state.sittingMountain.palace,
                        onSaved: {
                            refreshAnalysis()
                        }
                    )
                }
            }
        )
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
                .overlay(
                    Group {
                        if retention.showNotificationPermissionDeniedAlert {
                            FloorplanConfirmDialog(
                                title: notificationPermissionDeniedTitle(),
                                message: notificationPermissionDeniedMessage(),
                                confirmTitle: goToSettingsTitle(),
                                cancelTitle: lang.t("cancel"),
                                confirmColor: Color.yanCyan,
                                onConfirm: {
                                    retention.showNotificationPermissionDeniedAlert = false
                                    retention.openSystemNotificationSettings()
                                },
                                onCancel: {
                                    retention.showNotificationPermissionDeniedAlert = false
                                }
                            )
                        }
                    }
                )
        } else {
            ScrollView {
                content
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
            .overlay(
                Group {
                    if retention.showNotificationPermissionDeniedAlert {
                        FloorplanConfirmDialog(
                            title: notificationPermissionDeniedTitle(),
                            message: notificationPermissionDeniedMessage(),
                            confirmTitle: goToSettingsTitle(),
                            cancelTitle: lang.t("cancel"),
                            confirmColor: Color.yanCyan,
                            onConfirm: {
                                retention.showNotificationPermissionDeniedAlert = false
                                retention.openSystemNotificationSettings()
                            },
                            onCancel: {
                                retention.showNotificationPermissionDeniedAlert = false
                            }
                        )
                    }
                }
            )
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

                // 点击修改生辰日期与命卦按钮
                Button(action: {
                    showEditOwnerKuaDialog = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text("\(yearPrefix) \(String(kua.birthYear))")
                        Image(systemName: "pencil")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

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
                .buttonStyle(PlainButtonStyle())
            }

            // 命卦画像展示与配对卡（点击也可直接唤起修改弹窗）
            Button(action: {
                showEditOwnerKuaDialog = true
            }) {
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
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.85))
                }
            }
            .buttonStyle(PlainButtonStyle())

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
        let emptyTitle: String
        let emptySubtitle: String
        switch lang.effectiveLanguage {
        case .en:
            headerTitle = "Family Members Life Gua & Smart Room Fit (\(kua.familyMembers.count))"
            addHint = "+ Add Member"
            emptyTitle = "No Family Members Added Yet"
            emptySubtitle = "Tap to add spouse, parents, or children for life gua and room recommendations"
        case .zhHant:
            headerTitle = "全家成員命卦與智能分房檔案（\(kua.familyMembers.count)人）"
            addHint = "+ 添加家人"
            emptyTitle = "暫未添加家庭成員"
            emptySubtitle = "點擊添加配偶、父母或子女，智能推演全家本命卦與分房吉位"
        case .ja:
            headerTitle = "家族全員の本命卦・部屋割診断（\(kua.familyMembers.count)名）"
            addHint = "+ 家族追加"
            emptyTitle = "家族メンバーが未登録です"
            emptySubtitle = "タップして配偶者・両親・子供を追加し、部屋割を自動診断"
        case .ko:
            headerTitle = "가족 구성원 본명괘 및 방 배정 (\(kua.familyMembers.count)명)"
            addHint = "+ 가족 추가"
            emptyTitle = "등록된 가족 구성원이 없습니다"
            emptySubtitle = "터치하여 배우자, 부모, 자녀를 추가하고 최적의 방 배정을 확인하세요"
        case .vi:
            headerTitle = "Bản Mệnh Gia Đình & Phân Phòng (\(kua.familyMembers.count))"
            addHint = "+ Thêm người"
            emptyTitle = "Chưa có thành viên gia đình"
            emptySubtitle = "Nhấn để thêm vợ/chồng, cha mẹ, con cái và tự động gợi ý phòng"
        case .th:
            headerTitle = "รหัสชีวิตสมาชิกครอบครัว & จัดห้อง (\(kua.familyMembers.count))"
            addHint = "+ เพิ่มสมาชิก"
            emptyTitle = "ยังไม่มีสมาชิกครอบครัว"
            emptySubtitle = "แตะเพื่อเพิ่มคู่สมรส พ่อแม่ หรือบุตร เพื่อจัดห้องมงคล"
        case .id:
            headerTitle = "Gua Anggota Keluarga & Kamar (\(kua.familyMembers.count))"
            addHint = "+ Tambah"
            emptyTitle = "Belum Ada Anggota Keluarga"
            emptySubtitle = "Ketuk untuk menambah pasangan, orang tua, atau anak"
        case .auto, .zhHans:
            headerTitle = "全家成员命卦与智能分房档案（\(kua.familyMembers.count)人）"
            addHint = "+ 添加家人"
            emptyTitle = "暂未添加家庭成员"
            emptySubtitle = "点击添加配偶、父母或子女，智能推演全家本命卦与分房吉位"
        }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) { showFamilySection.toggle() }
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
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: {
                    showAddFamilyMemberDialog = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10))
                        Text(addHint)
                            .adaptiveFont(size: 10, weight: .bold)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.yanCyan.opacity(0.22))
                    .foregroundColor(.yanCyan)
                    .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if kua.familyMembers.isEmpty {
                Button(action: {
                    showAddFamilyMemberDialog = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 18))
                            .foregroundColor(.yanCyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(emptyTitle)
                                .adaptiveFont(size: 11, weight: .bold)
                                .foregroundColor(.white)
                            Text(emptySubtitle)
                                .adaptiveFont(size: 9.5)
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(Color.yanCyan.opacity(0.35))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 2)
            } else if showFamilySection {
                VStack(spacing: 6) {
                    ForEach(kua.familyMembers) { member in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(member.displayName)
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .foregroundColor(.white)
                                Text("【\(member.localizedGuaBadge)】")
                                    .adaptiveFont(size: 10, weight: .bold)
                                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                Spacer()
                                Menu {
                                    ForEach((1930...2026).reversed(), id: \.self) { yr in
                                        Button(action: {
                                            kua.updateFamilyMember(id: member.id, birthYear: yr)
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
                                    kua.updateFamilyMember(id: member.id, isMale: !member.isMale)
                                }) {
                                    Text(member.isMale ? maleLabel : femaleLabel)
                                        .adaptiveFont(size: 10, weight: .bold)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.yanCyan.opacity(0.18))
                                        .foregroundColor(.yanCyan)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: {
                                    withAnimation {
                                        kua.removeFamilyMember(id: member.id)
                                    }
                                }) {
                                    Image(systemName: "trash.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.45))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            Text(member.personalWealthAndStudySummary)
                                .adaptiveFont(size: 10)
                                .foregroundColor(.white.opacity(0.78))
                        }
                        .padding(7)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                    }

                    Button(action: {
                        showAddFamilyMemberDialog = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text(addHint)
                                .adaptiveFont(size: 10, weight: .semibold)
                        }
                        .foregroundColor(.yanCyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.yanCyan.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 2)
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

    private func notificationPermissionDeniedTitle() -> String {
        switch lang.effectiveLanguage {
        case .en: return "Notification Permission Disabled"
        case .zhHant: return "通知權限未開啟"
        case .ja: return "通知が許可されていません"
        case .ko: return "알림 권한이 비활성화됨"
        case .vi: return "Chưa Bật Quyền Thông Báo"
        case .th: return "ยังไม่ได้เปิดการอนุญาตแจ้งเตือน"
        case .id: return "Izin Notifikasi Belum Diaktifkan"
        case .auto, .zhHans: return "通知权限未开启"
        }
    }

    private func notificationPermissionDeniedMessage() -> String {
        switch lang.effectiveLanguage {
        case .en:
            return "You previously chose 'Don't Allow' for notifications. iOS requires you to enable notifications in the Settings app. Please go to Settings to enable alerts for auspicious days."
        case .zhHant:
            return "檢測到您之前點擊了「不允許」通知，iOS 系統限制應用無法再次直接彈窗請求授權。請前往系統「設定」中為「天機演象」開啟通知權限，以便接收黃道吉日提醒。"
        case .ja:
            return "以前「許可しない」を選択されたため、iOSの制約によりアプリ内から再要求できません。「設定」アプリを開き、天地羅盤の通知をオンにして吉日リマインダーを受け取れるようにしてください。"
        case .ko:
            return "이전에 알림을 '허용 안 함'으로 설정하여 iOS 정책상 앱에서 바로 권한을 재요청할 수 없습니다. 시스템 '설정'에서 알림을 허용하시면 황도길일 알림을 받으실 수 있습니다."
        case .vi:
            return "Bạn đã chọn 'Không cho phép' thông báo trước đó. Vui lòng vào 'Cài đặt' của thiết bị để bật thông báo cho Thiên Địa La Bàn nhằm nhận nhắc nhở ngày hoàng đạo."
        case .th:
            return "คุณเคยเลือก 'ไม่อนุญาต' การแจ้งเตือนไว้ ระบบ iOS กำหนดให้ต้องเปิดในแอปการตั้งค่าของเครื่อง โปรดไปที่ 'การตั้งค่า' เพื่อเปิดการแจ้งเตือนสำหรับวันธงชัย"
        case .id:
            return "Anda sebelumnya memilih 'Jangan Izinkan' notifikasi. Silakan buka 'Pengaturan' perangkat dan aktifkan notifikasi untuk menerima pengingat hari baik."
        case .auto, .zhHans:
            return "检测到您之前点击了「不允许」通知，iOS 系统限制应用无法再次直接弹窗请求授权。请前往系统「设置」中为「天机演象」开启通知权限，以便接收黄道吉日提醒。"
        }
    }

    private func goToSettingsTitle() -> String {
        switch lang.effectiveLanguage {
        case .en: return "Go to Settings"
        case .zhHant: return "前往設定"
        case .ja: return "設定へ移動"
        case .ko: return "설정으로 이동"
        case .vi: return "Đi đến Cài Đặt"
        case .th: return "ไปที่การตั้งค่า"
        case .id: return "Buka Pengaturan"
        case .auto, .zhHans: return "前往设置"
        }
    }
}

// MARK: - 添加家庭成员弹窗 (AddFamilyMemberDialog)

struct AddFamilyMemberDialog: View {
    @Binding var isPresented: Bool
    let ownerBirthYear: Int
    let ownerIsMale: Bool
    let onConfirm: (FamilyRole, String?, Int, Bool) -> Void

    @ObservedObject private var lang = LocalizationManager.shared
    @State private var selectedRole: FamilyRole = .spouse
    @State private var customName: String = ""
    @State private var selectedYear: Int = 1990
    @State private var selectedIsMale: Bool = false
    @State private var isInitialized: Bool = false

    private func initDefaults() {
        guard !isInitialized else { return }
        isInitialized = true
        selectedRole = .spouse
        selectedIsMale = !ownerIsMale
        selectedYear = ownerBirthYear
    }

    private func applyRolePreset(_ role: FamilyRole) {
        selectedRole = role
        switch role {
        case .spouse:
            selectedIsMale = !ownerIsMale
            selectedYear = ownerBirthYear
        case .father:
            selectedIsMale = true
            selectedYear = max(1930, ownerBirthYear - 28)
        case .mother:
            selectedIsMale = false
            selectedYear = max(1930, ownerBirthYear - 26)
        case .elder:
            selectedIsMale = true
            selectedYear = max(1930, ownerBirthYear - 28)
        case .son:
            selectedIsMale = true
            selectedYear = min(2026, max(1995, ownerBirthYear + 26))
        case .daughter:
            selectedIsMale = false
            selectedYear = min(2026, max(1995, ownerBirthYear + 28))
        case .child1:
            selectedIsMale = true
            selectedYear = min(2026, max(1995, ownerBirthYear + 26))
        case .child2:
            selectedIsMale = false
            selectedYear = min(2026, max(1995, ownerBirthYear + 28))
        case .other:
            selectedIsMale = true
            selectedYear = ownerBirthYear
        }
    }

    private var previewGuaBadge: String {
        let guaNum = UserKuaProfileManager.calcGuaNumber(birthYear: selectedYear, isMale: selectedIsMale)
        let guaKey = UserKuaProfileManager.guaKey(for: guaNum)
        let isEast = [1, 3, 4, 9].contains(guaNum)
        let guaItem = BaZhaiPalaceItem(id: 0, direction: "", guaName: guaKey, star: .fuWei)
        switch lang.effectiveLanguage {
        case .en:
            return "\(guaItem.localizedGuaName) · \(isEast ? "East 4" : "West 4")"
        case .zhHant, .ja:
            return "\(guaItem.localizedGuaName)命·\(isEast ? "東四命" : "西四命")"
        case .ko:
            return "\(guaItem.localizedGuaName)명·\(isEast ? "동사명" : "서사명")"
        case .vi:
            return "Mệnh \(guaItem.localizedGuaName)·\(isEast ? "Đông Tứ" : "Tây Tứ")"
        case .th:
            return "ดวง\(guaItem.localizedGuaName)·\(isEast ? "ตะวันออก" : "ตะวันตก")"
        case .id:
            return "Gua \(guaItem.localizedGuaName)·\(isEast ? "Timur" : "Barat")"
        case .auto, .zhHans:
            return "\(guaItem.localizedGuaName)命·\(isEast ? "东四命" : "西四命")"
        }
    }

    private var previewDirectionsSummary: String {
        let guaNum = UserKuaProfileManager.calcGuaNumber(birthYear: selectedYear, isMale: selectedIsMale)
        let guaKey = UserKuaProfileManager.guaKey(for: guaNum)
        let chart = BaZhaiEngine.shared.analyze(sittingPalace: guaKey, facingPalace: "离")
        let wDir = chart.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "-"
        let sDir = chart.items.first(where: { $0.star == .fuWei })?.localizedDirection ?? "-"
        let hDir = chart.items.first(where: { $0.star == .tianYi })?.localizedDirection ?? "-"
        switch lang.effectiveLanguage {
        case .en:
            return "Wealth: \(wDir) · Health: \(hDir) · Study: \(sDir)"
        case .zhHant, .ja:
            return "生氣財位:\(wDir) · 天醫康健:\(hDir) · 文昌伏位:\(sDir)"
        case .ko:
            return "생기:\(wDir) · 천의:\(hDir) · 문창:\(sDir)"
        case .vi:
            return "Sinh Khí:\(wDir) · Thiên Y:\(hDir) · Văn Xương:\(sDir)"
        case .th:
            return "โชคลาภ:\(wDir) · สุขภาพ:\(hDir) · การเรียน:\(sDir)"
        case .id:
            return "Rezeki:\(wDir) · Sehat:\(hDir) · Studi:\(sDir)"
        case .auto, .zhHans:
            return "生气财位:\(wDir) · 天医康健:\(hDir) · 文昌伏位:\(sDir)"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 12) {
                // 弹窗顶栏
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 16))
                        .foregroundColor(.yanCyan)
                    Text(dialogTitle)
                        .adaptiveFont(size: 15, weight: .bold)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text(dialogSubtitle)
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 身份关系网格
                VStack(alignment: .leading, spacing: 6) {
                    Text(roleSectionTitle)
                        .adaptiveFont(size: 11, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], spacing: 6) {
                        ForEach(FamilyRole.allCases) { role in
                            Button(action: {
                                applyRolePreset(role)
                            }) {
                                Text(role.localizedTitle)
                                    .adaptiveFont(size: 11, weight: selectedRole == role ? .bold : .medium)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(selectedRole == role ? Color.yanCyan.opacity(0.28) : Color.white.opacity(0.06))
                                    .foregroundColor(selectedRole == role ? .yanCyan : .white.opacity(0.85))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedRole == role ? Color.yanCyan : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // 称呼/姓名（选填）
                VStack(alignment: .leading, spacing: 4) {
                    Text(nameSectionTitle)
                        .adaptiveFont(size: 11, weight: .bold)
                        .foregroundColor(.white.opacity(0.85))
                    TextField(namePlaceholder, text: $customName)
                        .adaptiveFont(size: 12)
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }

                // 生辰年份与性别选择
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(birthYearSectionTitle)
                            .adaptiveFont(size: 11, weight: .bold)
                            .foregroundColor(.white.opacity(0.85))

                        Menu {
                            ForEach((1930...2026).reversed(), id: \.self) { yr in
                                Button(action: { selectedYear = yr }) {
                                    Text("\(String(yr))")
                                }
                            }
                        } label: {
                            HStack {
                                Text("\(String(selectedYear))年")
                                    .adaptiveFont(size: 12, weight: .bold)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(genderSectionTitle)
                            .adaptiveFont(size: 11, weight: .bold)
                            .foregroundColor(.white.opacity(0.85))

                        HStack(spacing: 4) {
                            Button(action: { selectedIsMale = true }) {
                                Text(maleText)
                                    .adaptiveFont(size: 11, weight: selectedIsMale ? .bold : .medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(selectedIsMale ? Color.yanCyan.opacity(0.28) : Color.white.opacity(0.06))
                                    .foregroundColor(selectedIsMale ? .yanCyan : .white.opacity(0.8))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: { selectedIsMale = false }) {
                                Text(femaleText)
                                    .adaptiveFont(size: 11, weight: !selectedIsMale ? .bold : .medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(!selectedIsMale ? Color.pink.opacity(0.28) : Color.white.opacity(0.06))
                                    .foregroundColor(!selectedIsMale ? Color.pink : .white.opacity(0.8))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .frame(width: 100)
                }

                // 实时命卦排盘预览卡
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("【\(previewGuaBadge)】")
                            .adaptiveFont(size: 11, weight: .bold)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Spacer()
                    }
                    Text(previewDirectionsSummary)
                        .adaptiveFont(size: 9.5)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)

                // 底部确认与取消按钮
                HStack(spacing: 10) {
                    Button(action: { isPresented = false }) {
                        Text(cancelText)
                            .adaptiveFont(size: 13, weight: .semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white.opacity(0.85))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onConfirm(selectedRole, trimmed.isEmpty ? nil : trimmed, selectedYear, selectedIsMale)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isPresented = false
                    }) {
                        Text(confirmText)
                            .adaptiveFont(size: 13, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.yanCyan)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: 340)
            .background(Color(red: 0.13, green: 0.13, blue: 0.17))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.yanCyan.opacity(0.35), lineWidth: 1)
            )
        }
        .onAppear {
            initDefaults()
        }
    }

    // 多语言文案辅助
    private var dialogTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Add Family Member"
        case .zhHant: return "添加家庭成員"
        case .ja: return "家族メンバー追加"
        case .ko: return "가족 구성원 추가"
        case .vi: return "Thêm Thành Viên"
        case .th: return "เพิ่มสมาชิกครอบครัว"
        case .id: return "Tambah Keluarga"
        case .auto, .zhHans: return "添加家庭成员"
        }
    }

    private var dialogSubtitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Enter birth details for life gua and room recommendations"
        case .zhHant: return "錄入生辰以推演本命卦吉方與智能分房"
        case .ja: return "生年を登録して本命卦と部屋割を診断"
        case .ko: return "생년을 입력하여 본명괘와 방 배정을 확인하세요"
        case .vi: return "Nhập năm sinh để xem bản mệnh và gợi ý phân phòng"
        case .th: return "กรอกปีเกิดเพื่อตรวจดวงชะตาและจัดห้องมงคล"
        case .id: return "Masukkan tahun lahir untuk cek gua & kamar"
        case .auto, .zhHans: return "录入生辰以推演本命卦吉方与智能分房"
        }
    }

    private var roleSectionTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Family Relationship"
        case .zhHant: return "家庭關係/身份"
        case .ja: return "家族関係・続柄"
        case .ko: return "가족 관계/신분"
        case .vi: return "Mối Quan Hệ"
        case .th: return "ความสัมพันธ์"
        case .id: return "Hubungan Keluarga"
        case .auto, .zhHans: return "家庭关系/身份"
        }
    }

    private var nameSectionTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Nickname / Remark (Optional)"
        case .zhHant: return "稱謂/姓名（選填）"
        case .ja: return "呼び名・名前（任意）"
        case .ko: return "호칭/이름 (선택)"
        case .vi: return "Tên / Xưng hô (tùy chọn)"
        case .th: return "ชื่อ / คำเรียก (ไม่บังคับ)"
        case .id: return "Nama / Panggilan (opsional)"
        case .auto, .zhHans: return "称谓/姓名（选填）"
        }
    }

    private var namePlaceholder: String {
        switch lang.effectiveLanguage {
        case .en: return "e.g. Mom, Alex, Daughter"
        case .zhHant: return "例如：媽媽 / 大寶 / 哥哥"
        case .ja: return "例：母、太郎、長女"
        case .ko: return "예: 어머니, 첫째, 공주"
        case .vi: return "Ví dụ: Mẹ, Bé Bự, Anh Hai"
        case .th: return "เช่น คุณแม่, น้องบอส"
        case .id: return "Misal: Ibu, Kakak, Adik"
        case .auto, .zhHans: return "例如：妈妈 / 大宝 / 哥哥"
        }
    }

    private var birthYearSectionTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Birth Year"
        case .zhHant: return "出生年份"
        case .ja: return "生年"
        case .ko: return "출생연도"
        case .vi: return "Năm sinh"
        case .th: return "ปีเกิด"
        case .id: return "Tahun Lahir"
        case .auto, .zhHans: return "出生年份"
        }
    }

    private var genderSectionTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Gender"
        case .zhHant: return "性別"
        case .ja: return "性別"
        case .ko: return "성별"
        case .vi: return "Giới tính"
        case .th: return "เพศ"
        case .id: return "Jenis Kelamin"
        case .auto, .zhHans: return "性别"
        }
    }

    private var maleText: String {
        switch lang.effectiveLanguage {
        case .en: return "Male"
        case .zhHant, .ja: return "男"
        case .ko: return "남"
        case .vi: return "Nam"
        case .th: return "ชาย"
        case .id: return "Pria"
        case .auto, .zhHans: return "男"
        }
    }

    private var femaleText: String {
        switch lang.effectiveLanguage {
        case .en: return "Female"
        case .zhHant, .ja: return "女"
        case .ko: return "여"
        case .vi: return "Nữ"
        case .th: return "หญิง"
        case .id: return "Wanita"
        case .auto, .zhHans: return "女"
        }
    }

    private var cancelText: String {
        switch lang.effectiveLanguage {
        case .en: return "Cancel"
        case .zhHant: return "取消"
        case .ja: return "キャンセル"
        case .ko: return "취소"
        case .vi: return "Hủy"
        case .th: return "ยกเลิก"
        case .id: return "Batal"
        case .auto, .zhHans: return "取消"
        }
    }

    private var confirmText: String {
        switch lang.effectiveLanguage {
        case .en: return "Confirm Add"
        case .zhHant: return "確認添加"
        case .ja: return "追加する"
        case .ko: return "추가하기"
        case .vi: return "Xác Nhận Thêm"
        case .th: return "ยืนยันการเพิ่ม"
        case .id: return "Tambahkan"
        case .auto, .zhHans: return "确认添加"
        }
    }
}

// MARK: - 宅主生辰日期与命卦修改弹窗 (EditOwnerKuaDialog)

public struct EditOwnerKuaDialog: View {
    @Binding var isPresented: Bool
    public var sittingPalace: String = "坎"
    public var onSaved: (() -> Void)? = nil

    @ObservedObject var kua = UserKuaProfileManager.shared
    @ObservedObject var lang = LocalizationManager.shared

    @State private var inputMode: Int = 0 // 0: 精确公历日期, 1: 年份快速选择
    @State private var selectedDate: Date = Date()
    @State private var selectedYear: Int = 1990
    @State private var selectedIsMale: Bool = true
    @State private var isInitialized: Bool = false

    public init(isPresented: Binding<Bool>, sittingPalace: String = "坎", onSaved: (() -> Void)? = nil) {
        self._isPresented = isPresented
        self.sittingPalace = sittingPalace
        self.onSaved = onSaved
    }

    private var effectiveFengShuiYear: Int {
        if inputMode == 0 {
            return UserKuaProfileManager.fengShuiYear(for: selectedDate)
        } else {
            return selectedYear
        }
    }

    private var calculatedGuaNumber: Int {
        UserKuaProfileManager.calcGuaNumber(birthYear: effectiveFengShuiYear, isMale: selectedIsMale)
    }

    private var calculatedGuaKey: String {
        UserKuaProfileManager.guaKey(for: calculatedGuaNumber)
    }

    private var isEastLife: Bool {
        [1, 3, 4, 9].contains(calculatedGuaNumber)
    }

    private var houseIsEast: Bool {
        ["坎", "震", "巽", "离"].contains(sittingPalace)
    }

    private var isMatched: Bool {
        isEastLife == houseIsEast
    }

    private var ganzhiAndZodiac: String {
        let y = effectiveFengShuiYear
        let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        let branches = ["子鼠", "丑牛", "寅虎", "卯兔", "辰龙", "巳蛇", "午马", "未羊", "申猴", "酉鸡", "戌狗", "亥猪"]
        let s = stems[((y - 4) % 10 + 10) % 10]
        let b = branches[((y - 4) % 12 + 12) % 12]
        return "\(s)\(b)年"
    }

    private var isDateBeforeLiChun: Bool {
        if inputMode != 0 { return false }
        let cal = Calendar.current
        let m = cal.component(.month, from: selectedDate)
        let d = cal.component(.day, from: selectedDate)
        return m < 2 || (m == 2 && d < 4)
    }

    private var dateRange: ClosedRange<Date> {
        let cal = Calendar.current
        var startComp = DateComponents()
        startComp.year = 1920
        startComp.month = 1
        startComp.day = 1
        let start = cal.date(from: startComp) ?? Date(timeIntervalSince1970: 0)
        var endComp = DateComponents()
        endComp.year = 2030
        endComp.month = 12
        endComp.day = 31
        let end = cal.date(from: endComp) ?? Date()
        return start...end
    }

    private func setupInitialValues() {
        guard !isInitialized else { return }
        isInitialized = true
        selectedYear = kua.birthYear
        selectedIsMale = kua.isMale
        selectedDate = kua.birthDate
        let cal = Calendar.current
        if cal.component(.year, from: selectedDate) != selectedYear {
            var comp = cal.dateComponents([.year, .month, .day], from: selectedDate)
            comp.year = selectedYear
            if let valid = cal.date(from: comp) {
                selectedDate = valid
            }
        }
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 12) {
                // 1. 顶栏标题与关闭按钮
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 16))
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

                // 2. 模式切换：精确公历日期 / 年份快速选择
                Picker("", selection: $inputMode) {
                    Text(modeDateLabel).tag(0)
                    Text(modeYearLabel).tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())

                // 3. 日期或年份选择内容
                if inputMode == 0 {
                    // 精确公历日期选择器
                    VStack(spacing: 6) {
                        HStack {
                            Text(datePickerHint)
                                .adaptiveFont(size: 12, weight: .semibold)
                                .foregroundColor(.white.opacity(0.85))
                            Spacer()
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                in: dateRange,
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                            .colorScheme(.dark)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)

                        // 立春换年解释或流年确认卡
                        HStack(spacing: 6) {
                            Image(systemName: isDateBeforeLiChun ? "info.circle.fill" : "sparkles")
                                .font(.system(size: 11))
                                .foregroundColor(isDateBeforeLiChun ? .orange : Color.yanCyan)
                            Text(liChunExplanationText)
                                .adaptiveFont(size: 10.5)
                                .foregroundColor(isDateBeforeLiChun ? .orange : .white.opacity(0.8))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                } else {
                    // 年份快速选择器
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Button(action: {
                                selectedYear = max(1920, selectedYear - 10)
                            }) {
                                Text("-10")
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white.opacity(0.9))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                selectedYear = max(1920, selectedYear - 1)
                            }) {
                                Text("-1")
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white.opacity(0.9))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Spacer()

                            Menu {
                                ForEach((1920...2026).reversed(), id: \.self) { yr in
                                    Button(action: { selectedYear = yr }) {
                                        HStack {
                                            Text("\(String(yr))年")
                                            if yr == selectedYear {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("\(String(selectedYear))年")
                                        .adaptiveFont(size: 14, weight: .bold)
                                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Spacer()

                            Button(action: {
                                selectedYear = min(2026, selectedYear + 1)
                            }) {
                                Text("+1")
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white.opacity(0.9))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                selectedYear = min(2026, selectedYear + 10)
                            }) {
                                Text("+10")
                                    .adaptiveFont(size: 11, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundColor(.white.opacity(0.9))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                }

                // 4. 乾造 (男) / 坤造 (女) 选择
                HStack(spacing: 10) {
                    Button(action: { selectedIsMale = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.stand")
                            Text(maleTitle)
                        }
                        .adaptiveFont(size: 12, weight: selectedIsMale ? .bold : .medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedIsMale ? Color.yanCyan.opacity(0.28) : Color.white.opacity(0.06))
                        .foregroundColor(selectedIsMale ? .yanCyan : .white.opacity(0.75))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedIsMale ? Color.yanCyan : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { selectedIsMale = false }) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.stand.dress")
                            Text(femaleTitle)
                        }
                        .adaptiveFont(size: 12, weight: !selectedIsMale ? .bold : .medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(!selectedIsMale ? Color(red: 0.95, green: 0.5, blue: 0.7).opacity(0.28) : Color.white.opacity(0.06))
                        .foregroundColor(!selectedIsMale ? Color(red: 0.95, green: 0.5, blue: 0.7) : .white.opacity(0.75))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(!selectedIsMale ? Color(red: 0.95, green: 0.5, blue: 0.7) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 5. 实时命卦与人宅合一配对卡
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("【\(calculatedGuaKey)卦 · \(isEastLife ? eastLifeText : westLifeText) · \(ganzhiAndZodiac)】")
                            .adaptiveFont(size: 12, weight: .bold)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Spacer()
                        Text(isMatched ? matchedBadgeText : unmatchedBadgeText)
                            .adaptiveFont(size: 10, weight: .bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((isMatched ? Color.green : Color.orange).opacity(0.25))
                            .foregroundColor(isMatched ? .green : .orange)
                            .cornerRadius(4)
                    }

                    Text(isMatched ? matchedAdviceText : unmatchedAdviceText)
                        .adaptiveFont(size: 10.5)
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider().background(Color.white.opacity(0.1))

                    // 四大吉方与四大凶方方位速查
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auspiciousHeader)
                                .adaptiveFont(size: 9.5, weight: .semibold)
                                .foregroundColor(.green.opacity(0.9))
                            Text(auspiciousSummary)
                                .adaptiveFont(size: 10)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(inauspiciousHeader)
                                .adaptiveFont(size: 9.5, weight: .semibold)
                                .foregroundColor(.red.opacity(0.9))
                            Text(inauspiciousSummary)
                                .adaptiveFont(size: 10)
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                .padding(10)
                .background(Color(red: 0.12, green: 0.13, blue: 0.18))
                .cornerRadius(8)

                // 6. 底部操作按钮
                HStack(spacing: 10) {
                    Button(action: { isPresented = false }) {
                        Text(cancelTitle)
                            .adaptiveFont(size: 13)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white.opacity(0.85))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        if inputMode == 0 {
                            kua.updateOwnerBirth(date: selectedDate, isMale: selectedIsMale)
                        } else {
                            kua.updateOwnerBirthYear(selectedYear, isMale: selectedIsMale)
                        }
                        onSaved?()
                        isPresented = false
                    }) {
                        Text(saveButtonTitle)
                            .adaptiveFont(size: 13, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.8, blue: 0.35), Color(red: 0.75, green: 0.55, blue: 0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.black)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .background(Color(red: 0.14, green: 0.14, blue: 0.19))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.35), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .frame(maxWidth: 480)
        }
        .onAppear {
            setupInitialValues()
        }
    }

    private var auspiciousSummary: String {
        let chart = BaZhaiEngine.shared.analyze(sittingPalace: calculatedGuaKey, facingPalace: sittingPalace)
        let shengQi = chart.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "-"
        let yanNian = chart.items.first(where: { $0.star == .yanNian })?.localizedDirection ?? "-"
        let tianYi = chart.items.first(where: { $0.star == .tianYi })?.localizedDirection ?? "-"
        let fuWei = chart.items.first(where: { $0.star == .fuWei })?.localizedDirection ?? "-"
        switch lang.effectiveLanguage {
        case .en:
            return "Wealth:\(shengQi) · Health:\(tianYi) · Harmony:\(yanNian)"
        default:
            return "财位:\(shengQi) · 康健:\(tianYi) · 合谐:\(yanNian) · 文昌:\(fuWei)"
        }
    }

    private var inauspiciousSummary: String {
        let chart = BaZhaiEngine.shared.analyze(sittingPalace: calculatedGuaKey, facingPalace: sittingPalace)
        let jueMing = chart.items.first(where: { $0.star == .jueMing })?.localizedDirection ?? "-"
        let wuGui = chart.items.first(where: { $0.star == .wuGui })?.localizedDirection ?? "-"
        let liuSha = chart.items.first(where: { $0.star == .liuSha })?.localizedDirection ?? "-"
        let huoHai = chart.items.first(where: { $0.star == .huoHai })?.localizedDirection ?? "-"
        switch lang.effectiveLanguage {
        case .en:
            return "Fatal:\(jueMing) · Ghost:\(wuGui) · Mishap:\(huoHai)"
        default:
            return "绝命:\(jueMing) · 五鬼:\(wuGui) · 六煞:\(liuSha) · 祸害:\(huoHai)"
        }
    }

    private var liChunExplanationText: String {
        let y = effectiveFengShuiYear
        if isDateBeforeLiChun {
            switch lang.effectiveLanguage {
            case .en:
                return "Born before Li Chun (Feb 4). Life Gua calculated using previous Feng Shui year (\(y))."
            case .zhHant, .ja:
                return "公曆立春（約2月4日）前出生，依風水歲首以立春前一年【\(ganzhiAndZodiac)】（\(y)年）核算命卦。"
            default:
                return "公历立春（约2月4日）前出生，依风水岁首以立春前一年【\(ganzhiAndZodiac)】（\(y)年）核算命卦。"
            }
        } else {
            switch lang.effectiveLanguage {
            case .en:
                return "Feng Shui year: \(ganzhiAndZodiac) (\(y))."
            default:
                return "对应风水流年：\(ganzhiAndZodiac)（\(y)年）。"
            }
        }
    }

    private var dialogTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Edit House Master Life Gua & Birth Date"
        case .zhHant: return "修改宅主生辰日期與命卦"
        case .ja: return "家主の生年月日・本命卦を変更"
        case .ko: return "건축주 생년월일 및 본명괘 수정"
        case .vi: return "Sửa Ngày Sinh & Bản Mệnh Trạch Chủ"
        case .th: return "แก้ไขวันเกิดและรหัสชีวิตเจ้าของบ้าน"
        case .id: return "Ubah Tanggal Lahir & Gua Pemilik"
        case .auto, .zhHans: return "修改宅主生辰日期与命卦"
        }
    }

    private var modeDateLabel: String {
        switch lang.effectiveLanguage {
        case .en: return "Exact Birth Date"
        case .zhHant: return "公曆年月日"
        case .ja: return "生年月日"
        case .ko: return "생년월일"
        case .vi: return "Ngày sinh"
        case .th: return "วันเกิด"
        case .id: return "Tanggal Lahir"
        case .auto, .zhHans: return "公历年月日"
        }
    }

    private var modeYearLabel: String {
        switch lang.effectiveLanguage {
        case .en: return "Birth Year"
        case .zhHant: return "出生年份"
        case .ja: return "生まれ年"
        case .ko: return "출생연도"
        case .vi: return "Năm sinh"
        case .th: return "ปีเกิด"
        case .id: return "Tahun Lahir"
        case .auto, .zhHans: return "出生年份"
        }
    }

    private var datePickerHint: String {
        switch lang.effectiveLanguage {
        case .en: return "Select Birthday:"
        case .zhHant: return "選擇公曆生日："
        case .ja: return "誕生日を選択："
        case .ko: return "생년월일 선택:"
        case .vi: return "Chọn ngày sinh:"
        case .th: return "เลือกวันเกิด:"
        case .id: return "Pilih Tanggal Lahir:"
        case .auto, .zhHans: return "选择公历生日："
        }
    }

    private var maleTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Male"
        case .zhHant, .ja: return "乾造 (男)"
        case .ko: return "건조 (남)"
        case .vi: return "Càn Tạo (Nam)"
        case .th: return "ชาย"
        case .id: return "Pria"
        case .auto, .zhHans: return "乾造 (男)"
        }
    }

    private var femaleTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Female"
        case .zhHant, .ja: return "坤造 (女)"
        case .ko: return "곤조 (여)"
        case .vi: return "Khôn Tạo (Nữ)"
        case .th: return "หญิง"
        case .id: return "Wanita"
        case .auto, .zhHans: return "坤造 (女)"
        }
    }

    private var eastLifeText: String {
        switch lang.effectiveLanguage {
        case .en: return "East 4 Life"
        case .zhHant, .ja: return "東四命"
        case .ko: return "동사명"
        case .vi: return "Đông Tứ Mệnh"
        case .th: return "ดวงตะวันออก"
        case .id: return "Gua Timur"
        case .auto, .zhHans: return "东四命"
        }
    }

    private var westLifeText: String {
        switch lang.effectiveLanguage {
        case .en: return "West 4 Life"
        case .zhHant, .ja: return "西四命"
        case .ko: return "서사명"
        case .vi: return "Tây Tứ Mệnh"
        case .th: return "ดวงตะวันตก"
        case .id: return "Gua Barat"
        case .auto, .zhHans: return "西四命"
        }
    }

    private var matchedBadgeText: String {
        switch lang.effectiveLanguage {
        case .en: return "House & Master Matched"
        case .zhHant: return "宅命相配 · 人宅合一"
        case .ja: return "宅命相配・人宅合一"
        case .ko: return "택명상배 · 인택합일"
        case .vi: return "Trạch Mệnh Tương Phối"
        case .th: return "สมดุลคนและบ้าน"
        case .id: return "Selaras Manusia & Rumah"
        case .auto, .zhHans: return "宅命相配 · 人宅合一"
        }
    }

    private var unmatchedBadgeText: String {
        switch lang.effectiveLanguage {
        case .en: return "Different Groups"
        case .zhHant: return "宅命不同組 · 宜起吉方"
        case .ja: return "宅命異組・吉方調候"
        case .ko: return "택명상이 · 길방조후"
        case .vi: return "Khác Cung · Dùng Cát Phương"
        case .th: return "คนละกลุ่ม · ปรับทิศมงคล"
        case .id: return "Beda Kelompok · Gunakan Arah Baik"
        case .auto, .zhHans: return "宅命不同组 · 宜起吉方"
        }
    }

    private var matchedAdviceText: String {
        switch lang.effectiveLanguage {
        case .en:
            return "Auspicious! The owner's life group matches the house's sitting energy, producing harmonious qi and fortune."
        case .zhHant:
            return "大吉！宅主命卦與宅盤五行同組相生，同氣相求，宅氣與人氣和諧共振，人宅兩旺。"
        case .ja:
            return "大吉！家主の本命卦と建物の座向が同組となり、人と家の気が調和して繁栄をもたらします。"
        case .ko:
            return "대길! 건축주의 본명괘와 건물의 좌향이 동조를 이루어 사람과 집의 기운이 조화롭게 번영합니다."
        case .vi:
            return "Đại cát! Mệnh quái trạch chủ đồng khí với trạch quái, nhân trạch hòa hợp, tài vận hanh thông."
        case .th:
            return "มงคลยิ่ง! รหัสชีวิตเจ้าของบ้านสมดุลกับทิศบ้าน พลังคนและบ้านสอดคล้อง นำพาความเจริญ"
        case .id:
            return "Sangat menguntungkan! Energi pemilik selaras dengan energi rumah, menghasilkan harmoni dan rezeki."
        case .auto, .zhHans:
            return "大吉！宅主命卦与宅盘五行同组相生，同气相求，宅气与人气和谐共振，人宅两旺。"
        }
    }

    private var unmatchedAdviceText: String {
        switch lang.effectiveLanguage {
        case .en:
            return "The owner and house belong to different groups. Prioritize placing the master bedroom and study in the owner's auspicious directions to balance the energy."
        case .zhHant:
            return "宅主與宅盤分屬不同組。建議將主臥室、辦公桌或書房安放於宅主本命之吉方（生氣、延年、天醫），以本命真氣調候宅氣。"
        case .ja:
            return "家主と建物が異なる組です。主寝室や書斎を家主の本命吉方位（生気・延年・天医）に配置して気を調和させましょう。"
        case .ko:
            return "건축주와 건물이 다른 조에 속합니다. 안방이나 서재를 본명 길방(생기·연년·천의)에 배치하여 기운을 조화롭게 다스리십시오."
        case .vi:
            return "Trạch chủ và nhà khác nhóm. Nên bố trí phòng ngủ chính hoặc bàn làm việc tại phương vị cát của bản mệnh để điều hòa."
        case .th:
            return "เจ้าของบ้านและบ้านอยู่คนละกลุ่ม แนะนำจัดห้องนอนหรือโต๊ะทำงานในทิศมงคลของเจ้าของบ้านเพื่อปรับสมดุลพลัง"
        case .id:
            return "Pemilik dan rumah berbeda kelompok. Tempatkan kamar utama atau ruang kerja di arah keberuntungan pemilik untuk menyeimbangkan energi."
        case .auto, .zhHans:
            return "宅主与宅盘分属不同组。建议将主卧室、办公桌或书房安放于宅主本命之吉方（生气、延年、天医），以本命真气调候宅气。"
        }
    }

    private var auspiciousHeader: String {
        switch lang.effectiveLanguage {
        case .en: return "Auspicious Directions"
        case .zhHant, .ja: return "四大吉方"
        case .ko: return "4대 길방"
        case .vi: return "Tứ Đại Cát Phương"
        case .th: return "4 ทิศมงคล"
        case .id: return "4 Arah Baik"
        case .auto, .zhHans: return "四大吉方"
        }
    }

    private var inauspiciousHeader: String {
        switch lang.effectiveLanguage {
        case .en: return "Inauspicious Directions"
        case .zhHant, .ja: return "四大凶方"
        case .ko: return "4대 흉방"
        case .vi: return "Tứ Đại Hung Phương"
        case .th: return "4 ทิศอัปมงคล"
        case .id: return "4 Arah Buruk"
        case .auto, .zhHans: return "四大凶方"
        }
    }

    private var cancelTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Cancel"
        case .zhHant: return "取消"
        case .ja: return "キャンセル"
        case .ko: return "취소"
        case .vi: return "Hủy"
        case .th: return "ยกเลิก"
        case .id: return "Batal"
        case .auto, .zhHans: return "取消"
        }
    }

    private var saveButtonTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Save & Update Life Gua"
        case .zhHant: return "保存生辰並更新命卦"
        case .ja: return "保存して本命卦を更新"
        case .ko: return "저장 및 본명괘 업데이트"
        case .vi: return "Lưu & Cập nhật Bản mệnh"
        case .th: return "บันทึกและอัปเดตรหัสชีวิต"
        case .id: return "Simpan & Perbarui Gua"
        case .auto, .zhHans: return "保存生辰并更新命卦"
        }
    }
}