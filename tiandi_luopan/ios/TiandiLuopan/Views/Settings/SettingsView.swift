import SwiftUI
import Foundation

/// Public HTTPS pages used by the purchase flow and App Store metadata.
/// Keep these URLs stable so the links shown in Settings and the paywall
/// always point at the currently published legal pages.
public enum LegalLinks {
    // Escape the slashes so the repository's lightweight Swift checker does
    // not mistake the URL for a source comment.
    public static let termsOfUse = URL(string: "https:\u{2F}\u{2F}yulintao.github.io/tiandiluopan-support/")!
    public static let privacyPolicy = URL(string: "https:\u{2F}\u{2F}yulintao.github.io/tiandiluopan-privacy/")!
    public static let subscriptionInfo = URL(string: "https:\u{2F}\u{2F}yulintao.github.io/tiandiluopan-subscription/")!
    /// 正式上架后分配的 App Store 数字 ID（配置后点击评分直接直达 App Store 撰写长评页面）
    public static let appStoreID: String = ""
}

private enum LegalDocument: String, Identifiable {
    case terms
    case privacy
    case compliance

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .terms: return "legal_terms_title"
        case .privacy: return "legal_privacy_title"
        case .compliance: return "legal_compliance_title"
        }
    }

    var bodyKey: String {
        switch self {
        case .terms: return "legal_terms_body"
        case .privacy: return "legal_privacy_body"
        case .compliance: return "legal_compliance_body"
        }
    }
}

// MARK: - 系统设置与专业版会员中心视图 (Settings & Member Center View)

public struct SettingsView: View {
    public var isActive: Bool = true
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @ObservedObject var kuaProfile = UserKuaProfileManager.shared
    @ObservedObject var retention = RetentionServiceManager.shared
    @State private var showCalibrationGuide: Bool = false
    @State private var showOnboardingGuide: Bool = false
    @State private var selectedProductId: String = IAPProductID.vipYearly.rawValue
    @State private var paymentError: String = ""
    @State private var paymentAlertIsError: Bool = true
    @State private var showPaymentError: Bool = false
    @State private var showTestFlightRateTip: Bool = false
    @State private var legalDocument: LegalDocument?

    private static let appearanceConfigured: Void = {
        UITableView.appearance().backgroundColor = UIColor(red: 18/255.0, green: 18/255.0, blue: 22/255.0, alpha: 1.0)
    }()
    
    public init(isActive: Bool = true) {
        self.isActive = isActive
        _ = Self.appearanceConfigured
    }
    
    private var isProUnlocked: Bool {
        return iap.hasUnlockedVIP
    }
    
    public var body: some View {
        Group {
            if isActive {
                NavigationView {
            List {
                // 1. 会员中心与多档位收银台
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Text(lang.t("vip_member_center"))
                                .adaptiveFont(size: 16, weight: .bold)
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Spacer()
                            Text(isProUnlocked ? lang.t("vip_user") : lang.t("standard_user"))
                                .adaptiveFont(size: 11, weight: .bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isProUnlocked ? Color.green.opacity(0.3) : Color.yellow.opacity(0.3))
                                .foregroundColor(isProUnlocked ? .green : .yellow)
                                .cornerRadius(6)
                        }
                        
                        // 四档商品卡片选择
                        VStack(spacing: 8) {
                            productRow(id: .vipYearly, tag: lang.t("product_vip_yearly_tag"))
                            productRow(id: .proLifetime, tag: lang.t("product_pro_lifetime_tag"))
                            productRow(id: .floorplanSingle, tag: lang.t("product_floorplan_single_tag"))
                            productRow(id: .tianjiSingle, tag: lang.t("product_tianji_single_tag"))
                        }
                        .padding(.vertical, 4)

                        if !iap.isLoadingProducts,
                           let selectedProduct = IAPProductID(rawValue: selectedProductId),
                           !iap.hasProduct(for: selectedProduct) {
                            HStack(spacing: 8) {
                                Text(lang.t("price_unavailable"))
                                    .adaptiveFont(size: 10)
                                    .foregroundColor(.orange.opacity(0.9))
                                Spacer()
                                Button(lang.t("reload_prices")) {
                                    iap.refreshProductsIfNeeded(force: true)
                                }
                                .adaptiveFont(size: 11, weight: .semibold)
                                .foregroundColor(.yanCyan)
                            }
                        }
                        
                        // 购买与恢复按钮（支持未解锁用户购买，以及年度 VIP 升级至终身版）
                        if !iap.isLifetimeUser && (!isProUnlocked || selectedProductId == IAPProductID.proLifetime.rawValue) {
                            Button(action: {
                                iap.purchase(productId: selectedProductId)
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "applelogo")
                                    Text(lang.t("pay_securely"))
                                    Spacer()
                                }
                                .adaptiveFont(size: 13, weight: .bold)
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
                            .disabled(iap.isProcessingPurchase || iap.isLoadingProducts || !selectedProductIsAvailable)
                        }
                        
                        Button(action: {
                            iap.restorePurchases()
                        }) {
                            HStack {
                                Spacer()
                                Text(lang.t("restore_purchases"))
                                    .adaptiveFont(size: 11)
                                    .foregroundColor(Color.yanCyan)
                                Spacer()
                            }
                        }
                        .disabled(iap.isProcessingPurchase)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
                
                // 2. VIP 尊享特权矩阵
                Section(header: Text(lang.t("vip_privilege_header"))) {
                    privilegeRow(icon: "sparkles", title: lang.t("privilege_qimen_title"))
                    privilegeRow(icon: "calendar.badge.clock", title: lang.t("privilege_purplewhite_title"))
                    privilegeRow(icon: "house.fill", title: lang.t("privilege_floorplan_title"))
                    privilegeRow(icon: "scroll.fill", title: lang.t("privilege_tianji_title"))
                    privilegeRow(icon: "camera.viewfinder", title: lang.t("ar_title"))
                }
                
                // 2.5 宅主本命卦档案与节气吉日提醒
                Section(header: Text(profileAndReminderSectionTitle())) {
                    Toggle(ownerProfileEnableTitle(), isOn: $kuaProfile.isProfileEnabled)
                    
                    if kuaProfile.isProfileEnabled {
                        HStack {
                            Text(ownerBirthYearTitle())
                            Spacer()
                            Menu {
                                ForEach((1930...2026).reversed(), id: \.self) { yr in
                                    Button("\(yr)") {
                                        kuaProfile.birthYear = yr
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text("\(kuaProfile.birthYear) · \(kuaProfile.localizedZodiac(language: lang.effectiveLanguage)) · \(kuaProfile.localizedLifeKuaName(language: lang.effectiveLanguage))")
                                        .adaptiveFont(size: 12, weight: .bold)
                                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                    Image(systemName: "chevron.up.chevron.down")
                                        .adaptiveFont(size: 10)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Picker(ownerGenderTitle(), selection: $kuaProfile.isMale) {
                            Text(maleLabel()).tag(true)
                            Text(femaleLabel()).tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Toggle(solarTermNotifyTitle(), isOn: Binding(
                        get: { retention.solarTermNotificationsEnabled },
                        set: { retention.setSolarTermNotifications(enabled: $0) }
                    ))
                    
                    Button(action: {
                        showOnboardingGuide = true
                    }) {
                        HStack {
                            Label(onboardingReplayTitle(), systemImage: "book.pages.fill")
                                .foregroundColor(Color.yanCyan)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .adaptiveFont(size: 11)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        handleRateAppTap()
                    }) {
                        HStack {
                            Label(rateAppTitle(), systemImage: "star.bubble.fill")
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .adaptiveFont(size: 11)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 3. 专业罗盘与偏好设置
                Section(header: Text(lang.t("app_language"))) {
                    Toggle(lang.t("haptic_feedback"), isOn: $motion.isHapticEnabled)
                    
                    Picker(lang.t("app_language"), selection: $lang.currentSetting) {
                        ForEach(AppLanguage.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }

                    Picker(lang.t("heading_reference"), selection: $motion.northReference) {
                        Text(lang.t("heading_reference_true")).tag(CompassNorthReference.trueNorth)
                        Text(lang.t("heading_reference_magnetic")).tag(CompassNorthReference.magneticNorth)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(lang.t("gps_coords"))
                            Spacer()
                            Text(motion.coordsDesc)
                                .foregroundColor(.secondary)
                                .adaptiveFont(size: 11)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        if motion.locationAuthorizationStatus == .denied || motion.locationAuthorizationStatus == .restricted {
                            Button(lang.t("open_system_settings")) {
                                motion.openLocationSettings()
                            }
                            .adaptiveFont(size: 11, weight: .semibold)
                            .foregroundColor(Color.yanCyan)
                        } else if motion.locationAuthorizationStatus == .notDetermined {
                            Button(lang.t("request_location_permission")) {
                                motion.requestLocationPermission()
                            }
                            .adaptiveFont(size: 11, weight: .semibold)
                            .foregroundColor(Color.yanCyan)
                        }
                    }
                    
                    HStack {
                        Text(lang.t("true_solar_time"))
                        Spacer()
                        Text(motion.solarTimeDesc)
                            .foregroundColor(.secondary)
                            .adaptiveFont(size: 11)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                
                // 4. 硬件传感器与校准
                Section(header: Text(lang.t("settings_calib_title"))) {
                    HStack {
                        Text(lang.t("mag_distortion"))
                        Spacer()
                        Text(motion.isDistorted ? lang.t("settings_mag_field_warning") : lang.t("settings_mag_field_normal"))
                            .foregroundColor(motion.isDistorted ? .red : .green)
                            .adaptiveFont(size: 13)
                    }
                    
                    HStack {
                        Text(lang.t("settings_mag_intensity"))
                        Spacer()
                        Text(String(format: "%.1f μT", motion.magneticStrengthUT))
                            .foregroundColor(.secondary)
                            .adaptiveFont(size: 13, design: .monospaced)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    
                    Button(action: {
                        showCalibrationGuide = true
                    }) {
                        HStack {
                            Text(lang.t("compass_calib"))
                            Spacer()
                            Text(motion.isDistorted ? lang.t("settings_calib_status_need") : lang.t("settings_calib_status_high"))
                                .adaptiveFont(size: 12, weight: .bold)
                                .foregroundColor(motion.isDistorted ? .orange : .green)
                            Image(systemName: "chevron.right")
                                .adaptiveFont(size: 12)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 5. 关于与版本信息
                Section(header: Text(lang.t("settings_about_title"))) {
                    HStack {
                        Text(lang.t("settings_app_version"))
                        Spacer()
                        Text(lang.t("settings_version_value"))
                            .foregroundColor(.secondary)
                            .adaptiveFont(size: 13)
                    }
                    HStack {
                        Text(lang.t("settings_theory_base"))
                        Spacer()
                        Text(lang.t("settings_theory_desc"))
                            .foregroundColor(.secondary)
                            .adaptiveFont(size: 12)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label(lang.t("settings_safety_title"), systemImage: "exclamationmark.shield.fill")
                            .adaptiveFont(size: 13, weight: .semibold)
                            .foregroundColor(.orange)
                        Text(lang.t("settings_safety_disclaimer"))
                            .adaptiveFont(size: 11)
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }
                    HStack(spacing: 16) {
                        Button {
                            openURL(LegalLinks.termsOfUse)
                        } label: {
                            Label(lang.t("legal_terms_button"), systemImage: "safari")
                        }
                        .buttonStyle(.plain)
                        .adaptiveFont(size: 12, weight: .semibold)
                        .foregroundColor(Color.yanCyan)
                        Spacer()
                        Button {
                            openURL(LegalLinks.privacyPolicy)
                        } label: {
                            Label(lang.t("legal_privacy_button"), systemImage: "safari")
                        }
                        .buttonStyle(.plain)
                        .adaptiveFont(size: 12, weight: .semibold)
                        .foregroundColor(Color.yanCyan)
                    }
                    HStack {
                        Button {
                            openURL(LegalLinks.subscriptionInfo)
                        } label: {
                            Label(lang.t("subscription_info_button"), systemImage: "safari")
                        }
                        .buttonStyle(.plain)
                        .adaptiveFont(size: 12, weight: .semibold)
                        .foregroundColor(Color.yanCyan)
                        Spacer()
                    }
                    Button {
                        legalDocument = .compliance
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield.fill")
                            Text(lang.t("legal_compliance_button"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .adaptiveFont(size: 10, weight: .semibold)
                        }
                    }
                    .adaptiveFont(size: 12, weight: .semibold)
                    .foregroundColor(.orange)
                }
            }
            .listStyle(InsetGroupedListStyle())
            // iPad 自适应：设置项内容限制最大宽度并居中，避免整行被拉到 1000pt
            // 以上（阅读距离过长）；iPhone 宽度远小于上限，行为完全不变。
            // 外层全宽 frame 铺与 InsetGroupedList 分组背景一致的底色
            //（App 固定 dark，systemGroupedBackground == black），
            // 避免内容宽度之外露出不同底色形成色块。
            // regular（iPad）放宽到 900pt：700pt 在 1032pt 竖屏上两侧留白过大。
            .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
            .frame(maxWidth: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitle(lang.t("tab_settings"), displayMode: .inline)
            .preferredColorScheme(.dark)
            .onAppear {
                guard isActive else { return }
                showPaymentError = false
                iap.clearTransientMessages()
                iap.refreshProductsIfNeeded()
            }
            .sheet(isPresented: $showCalibrationGuide) {
                CalibrationSheet(keepsMotionActive: true)
            }
            .sheet(isPresented: $showOnboardingGuide) {
                OnboardingGuideSheet()
            }
            .sheet(item: $legalDocument) { document in
                LegalDocumentSheet(
                    title: lang.t(document.titleKey),
                    bodyText: lang.t(document.bodyKey)
                )
            }
        .onReceive(iap.$lastErrorMessage) { message in
            guard isActive else { return }
            if let message = message {
                paymentAlertIsError = true
                paymentError = message
                showPaymentError = true
                iap.clearTransientMessages()
            }
        }
        .onReceive(iap.$lastStatusMessage) { message in
            guard isActive else { return }
            if let message = message {
                paymentAlertIsError = false
                paymentError = message
                showPaymentError = true
                iap.clearTransientMessages()
            }
        }
        }

                .navigationViewStyle(StackNavigationViewStyle())
                .preferredColorScheme(.dark)
            } else {
                Color.clear.ignoresSafeArea()
            }
        }
        // Settings re-renders with every sensor sample; a system alert
        // attached to the list was torn down and its button stopped
        // responding, so payment results use a stable overlay.
        .overlay(
            Group {
                if showPaymentError {
                    FloorplanConfirmDialog(
                        title: paymentAlertIsError ? lang.t("payment_failed_title") : lang.t("payment_status_title"),
                        message: paymentError,
                        confirmTitle: lang.t("done"),
                        cancelTitle: nil,
                        confirmColor: Color(red: 0.83, green: 0.68, blue: 0.21),
                        onConfirm: { showPaymentError = false },
                        onCancel: { showPaymentError = false }
                    )
                } else if showTestFlightRateTip {
                    FloorplanConfirmDialog(
                        title: testFlightRateAlertTitle(),
                        message: testFlightRateAlertMessage(),
                        confirmTitle: lang.t("done"),
                        cancelTitle: nil,
                        confirmColor: Color(red: 0.83, green: 0.68, blue: 0.21),
                        onConfirm: { showTestFlightRateTip = false },
                        onCancel: { showTestFlightRateTip = false }
                    )
                } else if retention.showNotificationPermissionDeniedAlert {
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
    
    private func productRow(id: IAPProductID, tag: String) -> some View {
        let isSelected = selectedProductId == id.rawValue
        
        return Button(action: {
            selectedProductId = id.rawValue
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(id.title)
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(tag)
                            .adaptiveFont(size: 9, weight: .bold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.yellow.opacity(0.25))
                            .foregroundColor(Color.yellow)
                            .cornerRadius(3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(id.desc)
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(iap.localizedPrice(for: id))
                    .adaptiveFont(size: 15, weight: .bold, design: .monospaced)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(10)
            .background(isSelected ? Color(red: 0.22, green: 0.19, blue: 0.12) : Color(red: 0.12, green: 0.13, blue: 0.17))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var selectedProductIsAvailable: Bool {
        guard let product = IAPProductID(rawValue: selectedProductId) else { return false }
        return iap.hasProduct(for: product)
    }
    
    private func privilegeRow(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .adaptiveFont(size: 13)
                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                .frame(width: 20)
            Text(title)
                .adaptiveFont(size: 12)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Text(lang.t("vip_short"))
                .adaptiveFont(size: 9, weight: .bold)
                .foregroundColor(.yellow)
        }
    }
    
    private func profileAndReminderSectionTitle() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "宅主命卦与节气提醒"
        case .zhHant: return "宅主命卦與節氣提醒"
        case .en: return "Owner Life Gua & Solar Term Alerts"
        case .ja: return "家主本命卦と節気リマインダー"
        case .ko: return "건축주 본명괘 및 절기 알림"
        case .vi: return "Bản Mệnh Trạch Chủ & Nhắc Tiết Khí"
        case .th: return "รหัสชีวิตเจ้าของบ้านและการแจ้งเตือนสารท"
        case .id: return "Gua Pemilik & Pengingat Musim"
        default: return "宅主命卦与节气提醒"
        }
    }
    
    private func ownerProfileEnableTitle() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "启用宅主本命卦人宅配卦"
        case .zhHant: return "啟用宅主本命卦人宅配卦"
        case .en: return "Enable Owner Life Gua Matching"
        case .ja: return "家主本命卦マッチングを有効化"
        case .ko: return "본명괘 매칭 활성화"
        case .vi: return "Bật Phối Quẻ Trạch Chủ"
        case .th: return "เปิดใช้การจับคู่รหัสชีวิต"
        case .id: return "Aktifkan Pencocokan Gua Pemilik"
        default: return "启用宅主本命卦人宅配卦"
        }
    }
    
    private func ownerBirthYearTitle() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "出生年份与本命卦"
        case .zhHant: return "出生年份與本命卦"
        case .en: return "Birth Year & Life Gua"
        case .ja: return "生年と本命卦"
        case .ko: return "출생연도 및 본명괘"
        case .vi: return "Năm Sinh & Bản Mệnh Quái"
        case .th: return "ปีเกิดและรหัสชีวิต"
        case .id: return "Tahun Lahir & Gua"
        default: return "出生年份与本命卦"
        }
    }
    
    private func ownerGenderTitle() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "性别"
        case .zhHant, .ja: return "性別"
        case .en: return "Gender"
        case .ko: return "성별"
        case .vi: return "Giới tính"
        case .th: return "เพศ"
        case .id: return "Jenis Kelamin"
        default: return "性别"
        }
    }
    
    private func maleLabel() -> String {
        switch lang.effectiveLanguage {
        case .zhHans, .zhHant, .ja: return "乾造 (男)"
        case .en: return "Male"
        case .ko: return "남성"
        case .vi: return "Nam"
        case .th: return "ชาย"
        case .id: return "Pria"
        default: return "乾造 (男)"
        }
    }
    
    private func femaleLabel() -> String {
        switch lang.effectiveLanguage {
        case .zhHans, .zhHant, .ja: return "坤造 (女)"
        case .en: return "Female"
        case .ko: return "여성"
        case .vi: return "Nữ"
        case .th: return "หญิง"
        case .id: return "Wanita"
        default: return "坤造 (女)"
        }
    }
    
    private func solarTermNotifyTitle() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "二十四节气交节与九星换月提醒"
        case .zhHant: return "二十四節氣交節與九星換月提醒"
        case .en: return "Solar Term & Monthly Star Alerts"
        case .ja: return "二十四節気・月盤切替通知"
        case .ko: return "24절기 및 월반 교체 알림"
        case .vi: return "Nhắc Giao Tiết & Đổi Sao Tháng"
        case .th: return "แจ้งเตือนวันเปลี่ยนสารทและดาวประจำเดือน"
        case .id: return "Pengingat Pergantian Musim & Bintang"
        default: return "二十四节气交节与九星换月提醒"
        }
    }
    
    private func onboardingReplayTitle() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "新手 3 步快速立向教学指南"
        case .zhHant: return "新手 3 步快速立向教學指南"
        case .en: return "3-Step Quick Compass Guide"
        case .ja: return "3ステップ立向クイックガイド"
        case .ko: return "3단계 나침반 빠른 가이드"
        case .vi: return "Hướng Dẫn Lập Hướng 3 Bước"
        case .th: return "คู่มือการวัดทิศ 3 ขั้นตอน"
        case .id: return "Panduan Cepat 3 Langkah"
        default: return "新手 3 步快速立向教学指南"
        }
    }
    
    private func rateAppTitle() -> String {
        switch lang.effectiveLanguage {
        case .zhHans: return "为「天机演象」评分鼓励"
        case .zhHant: return "為「天機演象」評分鼓勵"
        case .en: return "Rate Tiandi Luopan"
        case .ja: return "アプリを評価して応援する"
        case .ko: return "앱 평가하기"
        case .vi: return "Đánh Giá Ứng Dụng"
        case .th: return "ให้คะแนนแอป"
        case .id: return "Beri Nilai Aplikasi"
        default: return "为「天机演象」评分鼓励"
        }
    }

    private func handleRateAppTap() {
        if !LegalLinks.appStoreID.isEmpty,
           let url = URL(string: "https://apps.apple.com/app/id\(LegalLinks.appStoreID)?action=write-review"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }

        if RetentionServiceManager.isTestFlightOrDebug {
            showTestFlightRateTip = true
        }
        retention.requestImmediateReview()
    }

    private func testFlightRateAlertTitle() -> String {
        switch lang.effectiveLanguage {
        case .en: return "TestFlight Beta Notice"
        case .zhHant: return "TestFlight 測試版提示"
        case .ja: return "TestFlight ベータ版のご案内"
        case .ko: return "TestFlight 베타 안내"
        case .vi: return "Thông Báo TestFlight Beta"
        case .th: return "ข้อความแจ้งเตือน TestFlight"
        case .id: return "Pemberitahuan Beta TestFlight"
        case .auto, .zhHans: return "TestFlight 测试版提示"
        }
    }

    private func testFlightRateAlertMessage() -> String {
        switch lang.effectiveLanguage {
        case .en:
            return "You are currently running a TestFlight beta build. Under Apple's rules, the 'Submit' button in rating dialogs is disabled in TestFlight and sandbox environments. Reviews will be fully active once released on the App Store! To submit feedback now, please use the 'Send Beta Feedback' option in the TestFlight app."
        case .zhHant:
            return "當前處於 TestFlight 測試環境。依蘋果官方規則，測試版應用評分彈窗中的「提交」按鈕會被系統強制置灰，無法向 App Store 提交公開評分。正式上架後將全面開放評價！您可在 TestFlight 中點擊「發送反饋」向我們提出建議。"
        case .ja:
            return "現在 TestFlight ベータテスト環境をご利用中です。Apple の仕様により、テスト版では評価ダイアログの「送信」ボタンが無効化されており、App Store に公開評価を投稿することはできません。正式リリース後に評価が可能となります。ご意見は TestFlight の「フィードバックを送信」よりお寄せください。"
        case .ko:
            return "현재 TestFlight 베타 환경입니다. Apple의 정책에 따라 테스트 버전에서는 평가 팝업의 '제출' 버튼이 비활성화되어 App Store에 공개 평가를 등록할 수 없습니다. 정식 출시 후 평가가 가능하며, 의견은 TestFlight 앱의 '피드백 보내기'를 이용해 주시기 바랍니다."
        case .vi:
            return "Bạn đang sử dụng phiên bản thử nghiệm TestFlight. Theo quy định của Apple, nút 'Gửi' trong hộp thoại đánh giá sẽ bị vô hiệu hóa trong môi trường thử nghiệm. Đánh giá sẽ hoạt động bình thường sau khi phát hành chính thức! Bạn có thể gửi ý kiến qua mục 'Gửi phản hồi Beta' trong ứng dụng TestFlight."
        case .th:
            return "ขณะนี้คุณกำลังใช้งานเวอร์ชันทดสอบ TestFlight ตามนโยบายของ Apple ปุ่ม 'ส่ง' ในหน้าต่างให้คะแนนจะถูกปิดใช้งานในเวอร์ชันทดสอบ เมื่อเปิดตัวอย่างเป็นทางการจะสามารถส่งคะแนนได้ตามปกติ หากมีข้อเสนอแนะโปรดใช้ตัวเลือก 'ส่งความคิดเห็น' ในแอป TestFlight"
        case .id:
            return "Anda saat ini menggunakan versi beta TestFlight. Berdasarkan kebijakan Apple, tombol 'Kirim' dinonaktifkan pada versi beta. Ulasan akan dibuka penuh setelah rilis resmi di App Store. Untuk memberikan saran, silakan gunakan 'Kirim Masukan' di aplikasi TestFlight."
        case .auto, .zhHans:
            return "当前处于 TestFlight 测试环境。按苹果官方规则，测试版应用弹出的评分弹窗中「提交」按钮会被系统强制置灰，无法向 App Store 提交公开评分。正式上架后将全面开放评价！您可在 TestFlight 中点击「发送反馈」向我们提出宝贵建议。"
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
            return "You previously chose 'Don't Allow' for notifications. iOS requires you to enable notifications in the Settings app. Please go to Settings to enable alerts for 24 solar terms and monthly Flying Stars."
        case .zhHant:
            return "檢測到您之前點擊了「不允許」通知，iOS 系統限制應用無法再次直接彈窗請求授權。請前往系統「設定」中為「天機演象」開啟通知權限，以便及時接收二十四節氣交節與九星換月提醒。"
        case .ja:
            return "以前「許可しない」を選択されたため、iOSの制約によりアプリ内から再要求できません。「設定」アプリを開き、天地羅盤の通知をオンにして節気交節や九星換月の通知を受け取れるようにしてください。"
        case .ko:
            return "이전에 알림을 '허용 안 함'으로 설정하여 iOS 정책상 앱에서 바로 권한을 재요청할 수 없습니다. 시스템 '설정'에서 알림을 허용하시면 24절기 교절 및 자백구성 환월 알림을 받으실 수 있습니다."
        case .vi:
            return "Bạn đã chọn 'Không cho phép' thông báo trước đó. Vui lòng vào 'Cài đặt' của thiết bị để bật thông báo cho Thiên Địa La Bàn nhằm nhận nhắc nhở giao tiết khí và Cửu Tinh đổi cục."
        case .th:
            return "คุณเคยเลือก 'ไม่อนุญาต' การแจ้งเตือนไว้ ระบบ iOS กำหนดให้ต้องเปิดในแอปการตั้งค่าของเครื่อง โปรดไปที่ 'การตั้งค่า' เพื่อเปิดการแจ้งเตือนสำหรับสารท 24 절기 และดาวบินรายเดือน"
        case .id:
            return "Anda sebelumnya memilih 'Jangan Izinkan' notifikasi. Silakan buka 'Pengaturan' perangkat dan aktifkan notifikasi untuk menerima pengingat pergantian musim dan Bintang Terbang."
        case .auto, .zhHans:
            return "检测到您之前点击了「不允许」通知，iOS 系统限制应用无法再次直接弹窗请求授权。请前往系统「设置」中为「天机演象」开启通知权限，以便及时接收二十四节气交节与九星换月提醒。"
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

// MARK: - 用户协议与隐私说明
public struct LegalDocumentSheet: View {
    public let title: String
    public let bodyText: String
    @Environment(\.presentationMode) private var presentationMode

    public init(title: String, bodyText: String) {
        self.title = title
        self.bodyText = bodyText
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                Text(bodyText)
                    .adaptiveFont(size: 13)
                    .foregroundColor(.primary)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

