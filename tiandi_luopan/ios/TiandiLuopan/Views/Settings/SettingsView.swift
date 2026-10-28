import SwiftUI

// MARK: - 系统设置与专业版会员中心视图 (Settings & Member Center View)

public struct SettingsView: View {
    public var isActive: Bool = true
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showCalibrationGuide: Bool = false
    @State private var selectedProductId: String = IAPProductID.vipYearly.rawValue
    @State private var paymentError: String = ""
    @State private var showPaymentError: Bool = false

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
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Spacer()
                            Text(isProUnlocked ? lang.t("vip_user") : lang.t("standard_user"))
                                .font(.system(size: 11, weight: .bold))
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
                        
                        // 购买与恢复按钮
                        if !isProUnlocked {
                            Button(action: {
                                iap.purchase(productId: selectedProductId)
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "applelogo")
                                    Text(lang.t("pay_securely"))
                                    Spacer()
                                }
                                .font(.system(size: 13, weight: .bold))
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
                            .disabled(iap.isProcessingPurchase || iap.isLoadingProducts)
                            
                            Button(action: {
                                iap.restorePurchases()
                            }) {
                                HStack {
                                    Spacer()
                                    Text(lang.t("restore_purchases"))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.yanCyan)
                                    Spacer()
                                }
                            }
                            .padding(.top, 2)
                        }
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
                    
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(lang.t("gps_coords"))
                            Spacer()
                            Text(motion.coordsDesc)
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                                .lineLimit(1)
                        }
                        if motion.locationAuthorizationStatus == .denied || motion.locationAuthorizationStatus == .restricted {
                            Button(lang.t("open_system_settings")) {
                                motion.openLocationSettings()
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.yanCyan)
                        } else if motion.locationAuthorizationStatus == .notDetermined {
                            Button(lang.t("request_location_permission")) {
                                motion.requestLocationPermission()
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.yanCyan)
                        }
                    }
                    
                    HStack {
                        Text(lang.t("true_solar_time"))
                        Spacer()
                        Text(motion.solarTimeDesc)
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                }
                
                // 4. 硬件传感器与校准
                Section(header: Text(lang.t("settings_calib_title"))) {
                    HStack {
                        Text(lang.t("mag_distortion"))
                        Spacer()
                        Text(motion.isDistorted ? lang.t("settings_mag_field_warning") : lang.t("settings_mag_field_normal"))
                            .foregroundColor(motion.isDistorted ? .red : .green)
                            .font(.system(size: 13))
                    }
                    
                    HStack {
                        Text(lang.t("settings_mag_intensity"))
                        Spacer()
                        Text(String(format: "%.1f μT", motion.magneticStrengthUT))
                            .foregroundColor(.secondary)
                            .font(.system(size: 13, design: .monospaced))
                    }
                    
                    Button(action: {
                        showCalibrationGuide = true
                    }) {
                        HStack {
                            Text(lang.t("compass_calib"))
                            Spacer()
                            Text(motion.isDistorted ? lang.t("settings_calib_status_need") : lang.t("settings_calib_status_high"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(motion.isDistorted ? .orange : .green)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
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
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text(lang.t("settings_theory_base"))
                        Spacer()
                        Text(lang.t("settings_theory_desc"))
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle(lang.t("tab_settings"), displayMode: .inline)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showCalibrationGuide) {
                CalibrationSheet()
            }
        .onReceive(iap.$lastErrorMessage) { message in
            if let message = message {
                paymentError = message
                showPaymentError = true
            }
        }
        .alert(isPresented: $showPaymentError) {
            Alert(title: Text(lang.t("payment_failed_title")), message: Text(paymentError), dismissButton: .default(Text(lang.t("done"))))
        }
        }

                .preferredColorScheme(.dark)
            } else {
                Color.clear.ignoresSafeArea()
            }
        }
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
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white)
                        Text(tag)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.yellow.opacity(0.25))
                            .foregroundColor(Color.yellow)
                            .cornerRadius(3)
                    }
                    Text(id.desc)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(iap.localizedPrice(for: id))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
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
    
    private func privilegeRow(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                .frame(width: 20)
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Text(lang.t("vip_short"))
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.yellow)
        }
    }
}

// MARK: - 8字校准指南弹窗
public struct CalibrationGuideSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var lang = LocalizationManager.shared
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                    .padding(.top, 30)
                
                Text(lang.t("settings_calib_guide_title"))
                    .font(.system(size: 18, weight: .bold))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(lang.t("settings_calib_guide_1"))
                    Text(lang.t("settings_calib_guide_2"))
                    Text(lang.t("settings_calib_guide_3"))
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .navigationBarTitle(lang.t("settings_calib_guide_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("i_know")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
