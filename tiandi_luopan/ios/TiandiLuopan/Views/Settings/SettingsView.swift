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
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showCalibrationGuide: Bool = false
    @State private var selectedProductId: String = IAPProductID.vipYearly.rawValue
    @State private var paymentError: String = ""
    @State private var paymentAlertIsError: Bool = true
    @State private var showPaymentError: Bool = false
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
                                .font(.adaptive(size: 16, weight: .bold))
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Spacer()
                            Text(isProUnlocked ? lang.t("vip_user") : lang.t("standard_user"))
                                .font(.adaptive(size: 11, weight: .bold))
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
                                    .font(.adaptive(size: 10))
                                    .foregroundColor(.orange.opacity(0.9))
                                Spacer()
                                Button(lang.t("reload_prices")) {
                                    iap.refreshProductsIfNeeded(force: true)
                                }
                                .font(.adaptive(size: 11, weight: .semibold))
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
                                .font(.adaptive(size: 13, weight: .bold))
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
                                    .font(.adaptive(size: 11))
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
                                .font(.adaptive(size: 11))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        if motion.locationAuthorizationStatus == .denied || motion.locationAuthorizationStatus == .restricted {
                            Button(lang.t("open_system_settings")) {
                                motion.openLocationSettings()
                            }
                            .font(.adaptive(size: 11, weight: .semibold))
                            .foregroundColor(Color.yanCyan)
                        } else if motion.locationAuthorizationStatus == .notDetermined {
                            Button(lang.t("request_location_permission")) {
                                motion.requestLocationPermission()
                            }
                            .font(.adaptive(size: 11, weight: .semibold))
                            .foregroundColor(Color.yanCyan)
                        }
                    }
                    
                    HStack {
                        Text(lang.t("true_solar_time"))
                        Spacer()
                        Text(motion.solarTimeDesc)
                            .foregroundColor(.secondary)
                            .font(.adaptive(size: 11))
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
                            .font(.adaptive(size: 13))
                    }
                    
                    HStack {
                        Text(lang.t("settings_mag_intensity"))
                        Spacer()
                        Text(String(format: "%.1f μT", motion.magneticStrengthUT))
                            .foregroundColor(.secondary)
                            .font(.adaptive(size: 13, design: .monospaced))
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
                                .font(.adaptive(size: 12, weight: .bold))
                                .foregroundColor(motion.isDistorted ? .orange : .green)
                            Image(systemName: "chevron.right")
                                .font(.adaptive(size: 12))
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
                            .font(.adaptive(size: 13))
                    }
                    HStack {
                        Text(lang.t("settings_theory_base"))
                        Spacer()
                        Text(lang.t("settings_theory_desc"))
                            .foregroundColor(.secondary)
                            .font(.adaptive(size: 12))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label(lang.t("settings_safety_title"), systemImage: "exclamationmark.shield.fill")
                            .font(.adaptive(size: 13, weight: .semibold))
                            .foregroundColor(.orange)
                        Text(lang.t("settings_safety_disclaimer"))
                            .font(.adaptive(size: 11))
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }
                    HStack(spacing: 16) {
                        Link(destination: LegalLinks.termsOfUse) {
                            Label(lang.t("legal_terms_button"), systemImage: "safari")
                        }
                        .font(.adaptive(size: 12, weight: .semibold))
                        .foregroundColor(Color.yanCyan)
                        Spacer()
                        Link(destination: LegalLinks.privacyPolicy) {
                            Label(lang.t("legal_privacy_button"), systemImage: "safari")
                        }
                        .font(.adaptive(size: 12, weight: .semibold))
                        .foregroundColor(Color.yanCyan)
                    }
                    HStack {
                        Link(destination: LegalLinks.subscriptionInfo) {
                            Label(lang.t("subscription_info_button"), systemImage: "safari")
                        }
                        .font(.adaptive(size: 12, weight: .semibold))
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
                                .font(.adaptive(size: 10, weight: .semibold))
                        }
                    }
                    .font(.adaptive(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                }
            }
            .listStyle(InsetGroupedListStyle())
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
                            .font(.adaptive(size: 13, weight: .bold))
                            .foregroundColor(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(tag)
                            .font(.adaptive(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.yellow.opacity(0.25))
                            .foregroundColor(Color.yellow)
                            .cornerRadius(3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(id.desc)
                        .font(.adaptive(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(iap.localizedPrice(for: id))
                    .font(.adaptive(size: 15, weight: .bold, design: .monospaced))
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
                .font(.adaptive(size: 13))
                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                .frame(width: 20)
            Text(title)
                .font(.adaptive(size: 12))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Text(lang.t("vip_short"))
                .font(.adaptive(size: 9, weight: .bold))
                .foregroundColor(.yellow)
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
                    .font(.adaptive(size: 13))
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

