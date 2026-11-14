import SwiftUI
import StoreKit
import Combine

// MARK: - VIP 权限拦截遮罩卡片 (VIP Lock Card View)

public struct VIPLockCardView: View {
    @ObservedObject private var iap = StoreKitIAPManager.shared
    public let title: String
    public let featureDesc: String
    public var badge: String = LocalizationManager.shared.t("vip_badge_title")
    public var targetProductId: IAPProductID = .vipYearly
    public var onUnlockTap: () -> Void
    
    public init(
        title: String,
        featureDesc: String,
        badge: String = LocalizationManager.shared.t("vip_badge_title"),
        targetProductId: IAPProductID = .vipYearly,
        onUnlockTap: @escaping () -> Void
    ) {
        self.title = title
        self.featureDesc = featureDesc
        self.badge = badge
        self.targetProductId = targetProductId
        self.onUnlockTap = onUnlockTap
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // 窄分栏右栏里标题、徽章与图标横排会互相穿插；标题独占一行，
            // 图标与徽章另起一行，长词语言也能完整换行。
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .adaptiveFont(size: 15, weight: .bold)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        .adaptiveFont(size: 20)
                    Text(badge)
                        .adaptiveFont(size: 10, weight: .bold)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(Color.yellow)
                        .cornerRadius(4)
                    Spacer(minLength: 0)
                }
            }
            
            Text(featureDesc)
                .adaptiveFont(size: 12)
                .foregroundColor(.white.opacity(0.75))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                Button(action: onUnlockTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                        Text("\(purchaseActionTitle) (\(iap.localizedBillingPrice(for: targetProductId)))")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .adaptiveFont(size: 12, weight: .bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
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
                
                RestorePurchasesButton()
            }
        }
        .padding(14)
        .background(Color(red: 0.13, green: 0.12, blue: 0.11))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        // iPad 自适应：锁定卡在宽屏（iPad / Duo 内屏）上限制最大宽度并居中，
        // 避免说明文字被拉到 1000pt 宽、单行过长影响可读性；iPhone 上无影响。
        .frame(maxWidth: 640)
        // 外层全宽 frame 负责居中：只写 maxWidth: 640 时，父容器若非居中对齐
        // 会贴边显示，兑现不了上面注释里的「居中」。
        .frame(maxWidth: .infinity)
    }

    private var purchaseActionTitle: String {
        switch targetProductId {
        case .vipYearly, .proLifetime:
            return LocalizationManager.shared.t("unlock_vip_now")
        case .floorplanSingle, .tianjiSingle:
            return LocalizationManager.shared.t("pay_securely")
        }
    }
}

struct RestorePurchasesButton: View {
    enum Style {
        case compact
        case settingsRow
    }

    var presentsResult = true
    var style: Style = .compact
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var resultMessage = ""
    @State private var showResult = false

    var body: some View {
        Button {
            if presentsResult {
                iap.restorePurchases { message in
                    resultMessage = message
                    showResult = true
                }
            } else {
                iap.restorePurchases()
            }
        } label: {
            HStack(spacing: 8) {
                if style == .settingsRow { Image(systemName: "arrow.clockwise") }
                if iap.isRestoringPurchases { ProgressView().tint(Color.yanCyan) }
                Text(lang.t(iap.isRestoringPurchases ? "iap_restoring" : "restore_purchases"))
                    .fixedSize(horizontal: false, vertical: true)
                if style == .settingsRow { Spacer() }
            }
            .font(style == .settingsRow ? .body : .system(size: 12, weight: .semibold))
            .foregroundColor(Color.yanCyan)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(iap.isProcessingPurchase)
        .alert(lang.t("restore_purchases"), isPresented: $showResult) {
            Button(lang.t("done"), role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
    }
}

/// Shared by both direct purchase entry points. Keep the full billing details
/// and legal links immediately above the purchase action on every screen size.
struct PurchaseDisclosureView: View {
    let productID: IAPProductID
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared

    init(productID: IAPProductID) { self.productID = productID }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(iap.subscriptionPurchaseTerms(for: productID)?.title ?? productID.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            if productID.includesAllFeatures {
                Text(lang.t("membership_benefits_notice"))
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
            }
            if productID == .vipYearly {
                if let terms = iap.subscriptionPurchaseTerms(for: productID) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang.t("subscription_billing_price"))
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
                        Text(terms.localizedPricePerPeriod)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Color.yanGold)
                        Text(lang.t("subscription_billing_period") + ": " + terms.localizedPeriod)
                            .font(.system(size: 13)).foregroundColor(.white)
                    }
                    .accessibilityIdentifier("purchase.subscription.billing")
                } else {
                    Text(iap.isLoadingProducts ? lang.t("price_loading") : lang.t("subscription_details_unavailable"))
                        .font(.system(size: 13)).foregroundColor(.orange)
                }
                Text(lang.t("vip_legal_agreement"))
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
            } else {
                Text(iap.localizedPrice(for: productID))
                    .font(.system(size: 19, weight: .bold)).foregroundColor(Color.yanGold)
                Text(lang.t("purchase_one_time_notice"))
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
            }
            VStack(alignment: .leading, spacing: 0) {
                Link(destination: LegalLinks.termsOfUse) {
                    Label(lang.t("legal_terms_button"), systemImage: "doc.text")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("purchase.terms")
                Link(destination: LegalLinks.privacyPolicy) {
                    Label(lang.t("legal_privacy_button"), systemImage: "hand.raised")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("purchase.privacy")
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.yanCyan)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 全功能专业版 VIP 收银台弹窗 (VIP Paywall Sheet)

public struct VIPPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @State private var selected: IAPProductID
    @State private var result: String?
    public init(defaultProductId: IAPProductID = .vipYearly) {
        // Retired consumable products remain restorable, but are not sold by the new app.
        _selected = State(initialValue: defaultProductId == .proLifetime ? .proLifetime : .vipYearly)
    }
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    Text(lang.t("res_member_features"))
                    Picker(lang.t("res_membership"), selection: $selected) {
                        Text(lang.t("res_yearly")).tag(IAPProductID.vipYearly)
                        Text(lang.t("res_lifetime")).tag(IAPProductID.proLifetime)
                    }.pickerStyle(.segmented)
                    Text(lang.t("res_purchase_note")).font(.footnote)
                }
                Section {
                    PurchaseDisclosureView(productID: selected)
                    if let reason = iap.purchaseUnavailableMessageKey(for: selected) {
                        Text(lang.t(reason)).foregroundColor(.orange)
                        Button(lang.t("reload_prices")) { iap.refreshProductsIfNeeded() }
                    }
                    Button {
                        iap.purchaseProduct(id: selected.rawValue)
                    } label: {
                        HStack {
                            if iap.isProcessingPurchase { ProgressView() }
                            Text(lang.t("pay_securely") + " · " + iap.localizedBillingPrice(for: selected))
                        }
                    }.disabled(iap.isProcessingPurchase || iap.isLoadingProducts || !iap.canPurchaseProduct(for: selected))
                    RestorePurchasesButton()
                }
                Section { Text(lang.t("res_measurement_note")).font(.footnote) }
            }
            .navigationTitle(lang.t("res_membership"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(lang.t("close")) { dismiss() } } }
            .onAppear { iap.clearTransientMessages(); iap.refreshProductsIfNeeded() }
            .onReceive(iap.$lastErrorMessage.compactMap { $0 }) { result = $0 }
            .onReceive(iap.$lastStatusMessage.compactMap { $0 }) { result = $0 }
            .onChange(of: iap.hasUnlockedVIP) { if $0 { dismiss() } }
            .alert(lang.t("res_membership"), isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
                Button(lang.t("done"), role: .cancel) { result = nil }
            } message: { Text(result ?? "") }
        }.navigationViewStyle(.stack)
    }
}
