import SwiftUI
import Foundation

public enum LegalLinks {
    /// This page contains the service terms, subscription terms and full EULA.
    public static let termsOfUse = URL(string: "https://sdnlink.cn/i18n/zh-CN/subscription-terms.html")!
    public static let privacyPolicy = URL(string: "https://sdnlink.cn/i18n/zh-CN/privacy.html")!
    public static let support = URL(string: "https://sdnlink.cn/i18n/zh-CN/contact.html")!
    /// 正式上架后分配的 App Store 数字 ID（配置后点击评分直接直达 App Store 撰写长评页面）
    public static let appStoreID: String = ""
}


public struct SettingsView: View {
    public var isActive = true
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @State private var paywall = false
    @State private var deleteProfiles = false
    @State private var message: String?
    public init(isActive: Bool = true) { self.isActive = isActive }
    public var body: some View {
        NavigationView {
            Form {
                Section(lang.t("settings")) {
                    Picker(lang.t("language"), selection: $lang.currentSetting) {
                        ForEach(AppLanguage.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Text(lang.t("res_measurement_note")).font(.footnote).foregroundColor(.secondary)
                }
                Section(lang.t("res_membership")) {
                    Text(lang.t(iap.hasUnlockedVIP ? "res_member_active" : "res_member_features"))
                    Button(lang.t("res_membership")) { paywall = true }
                    RestorePurchasesButton(style: .settingsRow)
                    Link(lang.t("res_manage_subscription"), destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    Text(lang.t("res_legacy_credits")).font(.footnote).foregroundColor(.secondary)
                }
                Section(lang.t("res_privacy")) {
                    // Birth profiles are no longer collected or used. Existing
                    // users retain a free deletion path after upgrading.
                    Button(lang.t("profile_data_delete_all"), role: .destructive) { deleteProfiles = true }
                    Link(lang.t("legal_privacy_button"), destination: LegalLinks.privacyPolicy)
                    Link(lang.t("legal_terms_button"), destination: LegalLinks.termsOfUse)
                    Link(lang.t("res_contact"), destination: LegalLinks.support)
                    RestorePurchasesButton(style: .settingsRow)
                }
                Section(lang.t("res_about")) {
                    Text(lang.t("res_app_name"))
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                }
            }
            .navigationTitle(lang.t("settings"))
            .sheet(isPresented: $paywall) { VIPPaywallSheet(defaultProductId: .vipYearly) }
            .confirmationDialog(lang.t("profile_data_delete_all"), isPresented: $deleteProfiles) {
                Button(lang.t("profile_data_delete_all"), role: .destructive) {
                    UserKuaProfileManager.shared.deleteAllPersonalProfiles()
                    message = lang.t("res_deleted")
                }
            }
            .alert(lang.t("res_privacy"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(lang.t("done"), role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }.navigationViewStyle(.stack)
    }
}
