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
                        Text("\(purchaseActionTitle) (\(iap.localizedPrice(for: targetProductId)))")
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
                
                Button(action: {
                    StoreKitIAPManager.shared.restorePurchases()
                }) {
                    Text(LocalizationManager.shared.t("restore_purchases_btn"))
                        .adaptiveFont(size: 11)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(Color.yanCyan)
                        .cornerRadius(8)
                }
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

// MARK: - 全功能专业版 VIP 收银台弹窗 (VIP Paywall Sheet)

public struct VIPPaywallSheet: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    
    @State private var selectedProductId: String = IAPProductID.vipYearly.rawValue
    @State private var isPurchasing: Bool = false
    @State private var alertMsg: String = ""
    @State private var alertIsError: Bool = false
    @State private var showAlert: Bool = false
    
    public init(defaultProductId: IAPProductID = .vipYearly) {
        _selectedProductId = State(initialValue: defaultProductId.rawValue)
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. 顶部尊贵皇冠 Banner
                        VStack(spacing: 6) {
                            Image(systemName: selectedIsSingleProduct
                                  ? (selectedIAPProduct == .floorplanSingle ? "house.fill" : "scroll.fill")
                                  : "crown.fill")
                                .adaptiveFont(size: 40)
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                .padding(.top, 12)
                            
                            Text(selectedIsSingleProduct
                                 ? selectedIAPProduct.title
                                 : LocalizationManager.shared.t("vip_sheet_title"))
                                .adaptiveFont(size: 18, weight: .bold)
                                .foregroundColor(.white)
                            
                            Text(selectedIsSingleProduct
                                 ? selectedIAPProduct.desc
                                 : LocalizationManager.shared.t("vip_sheet_subtitle"))
                                .adaptiveFont(size: 11)
                                .foregroundColor(.white.opacity(0.65))
                        }
                        
                        // 2. 核心特权清单。单次商品只展示它实际解锁的
                        // 一项服务，避免把一次导出误解成全量 VIP。
                        VStack(spacing: 8) {
                            if selectedIsSingleProduct {
                                privilegeItem(
                                    icon: selectedProductId == IAPProductID.floorplanSingle.rawValue ? "house.fill" : "scroll.fill",
                                    title: selectedIAPProduct.title,
                                    desc: selectedIAPProduct.desc
                                )
                            } else {
                                privilegeItem(icon: "person.2.fill", title: LocalizationManager.shared.t("bz_tool_owner"), desc: LocalizationManager.shared.t("bz_owner_vip_desc"))
                                privilegeItem(icon: "sparkles", title: LocalizationManager.shared.t("privilege_qimen_title"), desc: LocalizationManager.shared.t("privilege_qimen_desc"))
                                privilegeItem(icon: "calendar.badge.clock", title: LocalizationManager.shared.t("privilege_purplewhite_title"), desc: LocalizationManager.shared.t("privilege_purplewhite_desc"))
                                privilegeItem(icon: "drop.triangle.fill", title: LocalizationManager.shared.t("privilege_sanhe_title"), desc: LocalizationManager.shared.t("privilege_sanhe_desc"))
                                privilegeItem(icon: "house.fill", title: LocalizationManager.shared.t("privilege_floorplan_title"), desc: LocalizationManager.shared.t("privilege_floorplan_desc"))
                                privilegeItem(icon: "scroll.fill", title: LocalizationManager.shared.t("privilege_tianji_title"), desc: LocalizationManager.shared.t("privilege_tianji_desc"))
                                privilegeItem(icon: "camera.viewfinder", title: LocalizationManager.shared.t("privilege_ar_title"), desc: LocalizationManager.shared.t("privilege_ar_desc"))
                            }
                        }
                        .padding(12)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        
                        // 3. 四档商品套餐选择
                        VStack(spacing: 8) {
                            productChoiceCard(
                                id: .vipYearly,
                                tag: LocalizationManager.shared.t("product_vip_yearly_tag"),
                                isSelected: selectedProductId == IAPProductID.vipYearly.rawValue
                            )
                            
                            productChoiceCard(
                                id: .proLifetime,
                                tag: LocalizationManager.shared.t("product_pro_lifetime_tag"),
                                isSelected: selectedProductId == IAPProductID.proLifetime.rawValue
                            )
                            
                            productChoiceCard(
                                id: .floorplanSingle,
                                tag: LocalizationManager.shared.t("product_floorplan_single_tag"),
                                isSelected: selectedProductId == IAPProductID.floorplanSingle.rawValue
                            )
                            
                            productChoiceCard(
                                id: .tianjiSingle,
                                tag: LocalizationManager.shared.t("product_tianji_single_tag"),
                                isSelected: selectedProductId == IAPProductID.tianjiSingle.rawValue
                            )
                        }
                        .padding(.horizontal, 16)

                        if !iap.isLoadingProducts && !iap.hasProduct(for: selectedIAPProduct) {
                            HStack(spacing: 8) {
                                Text(LocalizationManager.shared.t("price_unavailable"))
                                    .adaptiveFont(size: 10)
                                    .foregroundColor(.orange.opacity(0.9))
                                Spacer()
                                Button(LocalizationManager.shared.t("reload_prices")) {
                                    iap.refreshProductsIfNeeded(force: true)
                                }
                                .adaptiveFont(size: 11, weight: .semibold)
                                .foregroundColor(.yanCyan)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // 4. 购买与恢复操作按键
                        VStack(spacing: 10) {
                            Button(action: {
                                isPurchasing = true
                                iap.purchase(productId: selectedProductId)
                            }) {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                            .padding(.trailing, 4)
                                    }
                                    Text(isPurchasing ? LocalizationManager.shared.t("vip_connecting_store") : "\(selectedIsSingleProduct ? LocalizationManager.shared.t("pay_securely") : LocalizationManager.shared.t("unlock_vip_now")) (\(getSelectedProductTitle()))")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .adaptiveFont(size: 14, weight: .bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 0.95, green: 0.8, blue: 0.35), Color(red: 0.75, green: 0.55, blue: 0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.black)
                                .cornerRadius(10)
                            }
                            .disabled(iap.isProcessingPurchase || iap.isLoadingProducts || !iap.hasProduct(for: selectedIAPProduct))
                            
                            Button(action: {
                                iap.restorePurchases()
                            }) {
                                Text(LocalizationManager.shared.t("restore_purchases"))
                                    .adaptiveFont(size: 11)
                                    .foregroundColor(Color.yanCyan)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.horizontal, 16)
                        
                        // 5. 自动续期与苹果服务说明
                        VStack(spacing: 4) {
                            Text(LocalizationManager.shared.t("vip_legal_agreement"))
                                .adaptiveFont(size: 10)
                                .foregroundColor(.white.opacity(0.45))
                                .multilineTextAlignment(.center)
                            Text(LocalizationManager.shared.t("settings_safety_disclaimer"))
                                .adaptiveFont(size: 10)
                                .foregroundColor(.orange.opacity(0.75))
                                .multilineTextAlignment(.center)

                            HStack(spacing: 18) {
                                Button {
                                    openURL(LegalLinks.termsOfUse)
                                } label: {
                                    Label(LocalizationManager.shared.t("legal_terms_button"), systemImage: "safari")
                                }
                                .buttonStyle(.plain)
                                Button {
                                    openURL(LegalLinks.privacyPolicy)
                                } label: {
                                    Label(LocalizationManager.shared.t("legal_privacy_button"), systemImage: "safari")
                                }
                                .buttonStyle(.plain)
                                Button {
                                    openURL(LegalLinks.subscriptionInfo)
                                } label: {
                                    Label(LocalizationManager.shared.t("subscription_info_button"), systemImage: "safari")
                                }
                                .buttonStyle(.plain)
                            }
                            .adaptiveFont(size: 10, weight: .semibold)
                            .foregroundColor(.yanCyan)
                            .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitle(LocalizationManager.shared.t("vip_member_center"), displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("close")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            iap.clearTransientMessages()
            iap.refreshProductsIfNeeded()
        }
        .onReceive(iap.$isVIPUser) { isVip in
            if isVip {
                isPurchasing = false
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onReceive(iap.$isLifetimeUser) { isLifetime in
            if isLifetime {
                isPurchasing = false
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onReceive(iap.$floorplanCreditsCount) { count in
            if isPurchasing && count > 0 && selectedProductId == IAPProductID.floorplanSingle.rawValue {
                isPurchasing = false
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onReceive(iap.$tianjiCreditsCount) { count in
            if isPurchasing && count > 0 && selectedProductId == IAPProductID.tianjiSingle.rawValue {
                isPurchasing = false
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onReceive(iap.$isProcessingPurchase) { processing in
            isPurchasing = processing
        }
        .onReceive(iap.$lastErrorMessage.compactMap { $0 }) { message in
            isPurchasing = false
            alertIsError = true
            alertMsg = message
            showAlert = true
            iap.clearTransientMessages()
        }
        .onReceive(iap.$lastStatusMessage.compactMap { $0 }) { message in
            isPurchasing = false
            alertIsError = false
            alertMsg = message
            showAlert = true
            iap.clearTransientMessages()
        }
        .overlay(
            Group {
                if showAlert {
                    FloorplanConfirmDialog(
                        title: alertIsError
                            ? LocalizationManager.shared.t("payment_failed_title")
                            : LocalizationManager.shared.t("payment_status_title"),
                        message: alertMsg,
                        confirmTitle: LocalizationManager.shared.t("done"),
                        cancelTitle: nil,
                        confirmColor: Color(red: 0.83, green: 0.68, blue: 0.21),
                        onConfirm: { showAlert = false },
                        onCancel: { showAlert = false }
                    )
                }
            }
        )
    }
    
    private func getSelectedProductTitle() -> String {
        guard let id = IAPProductID(rawValue: selectedProductId) else {
            return LocalizationManager.shared.t("vip_badge_title")
        }
        return "\(id.title) (\(iap.localizedPrice(for: id)))"
    }

    private var selectedIAPProduct: IAPProductID {
        IAPProductID(rawValue: selectedProductId) ?? .vipYearly
    }

    private var selectedIsSingleProduct: Bool {
        selectedIAPProduct == .floorplanSingle || selectedIAPProduct == .tianjiSingle
    }
    
    private func privilegeItem(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .adaptiveFont(size: 14)
                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                .frame(width: 20)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(.white)
                Text(desc)
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
        }
    }
    
    private func productChoiceCard(id: IAPProductID, tag: String, isSelected: Bool) -> some View {
        Button(action: {
            selectedProductId = id.rawValue
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(id.title)
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(tag)
                            .adaptiveFont(size: 9, weight: .bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(isSelected ? Color.yellow.opacity(0.3) : Color.white.opacity(0.1))
                            .foregroundColor(isSelected ? .yellow : .white.opacity(0.7))
                            .cornerRadius(3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(id.desc)
                        .adaptiveFont(size: 10)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(iap.localizedPrice(for: id))
                    .adaptiveFont(size: 15, weight: .bold, design: .monospaced)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(10)
            .background(isSelected ? Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.15) : Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
