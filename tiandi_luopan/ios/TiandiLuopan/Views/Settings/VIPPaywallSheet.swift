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
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundColor(Color.yellow)
                    .cornerRadius(4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            Text(featureDesc)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.75))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 10) {
                Button(action: onUnlockTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                        Text("\(LocalizationManager.shared.t("unlock_vip_now")) (\(iap.localizedPrice(for: targetProductId)))")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .font(.system(size: 12, weight: .bold))
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
                        .font(.system(size: 11))
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
    }
}

// MARK: - 全功能专业版 VIP 收银台弹窗 (VIP Paywall Sheet)

public struct VIPPaywallSheet: View {
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
                            Image(systemName: "crown.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                .padding(.top, 12)
                            
                            Text(LocalizationManager.shared.t("vip_sheet_title"))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(LocalizationManager.shared.t("vip_sheet_subtitle"))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        
                        // 2. 核心特权清单
                        VStack(spacing: 8) {
                            privilegeItem(icon: "sparkles", title: LocalizationManager.shared.t("privilege_qimen_title"), desc: LocalizationManager.shared.t("privilege_qimen_desc"))
                            privilegeItem(icon: "calendar.badge.clock", title: LocalizationManager.shared.t("privilege_purplewhite_title"), desc: LocalizationManager.shared.t("privilege_purplewhite_desc"))
                            privilegeItem(icon: "drop.triangle.fill", title: LocalizationManager.shared.t("privilege_sanhe_title"), desc: LocalizationManager.shared.t("privilege_sanhe_desc"))
                            privilegeItem(icon: "house.fill", title: LocalizationManager.shared.t("privilege_floorplan_title"), desc: LocalizationManager.shared.t("privilege_floorplan_desc"))
                            privilegeItem(icon: "scroll.fill", title: LocalizationManager.shared.t("privilege_tianji_title"), desc: LocalizationManager.shared.t("privilege_tianji_desc"))
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
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange.opacity(0.9))
                                Spacer()
                                Button(LocalizationManager.shared.t("reload_prices")) {
                                    iap.refreshProductsIfNeeded(force: true)
                                }
                                .font(.system(size: 11, weight: .semibold))
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
                                    Text(isPurchasing ? LocalizationManager.shared.t("vip_connecting_store") : "\(LocalizationManager.shared.t("unlock_vip_now")) (\(getSelectedProductTitle()))")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .font(.system(size: 14, weight: .bold))
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
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.yanCyan)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.horizontal, 16)
                        
                        // 5. 自动续期与苹果服务说明
                        VStack(spacing: 4) {
                            Text(LocalizationManager.shared.t("vip_legal_agreement"))
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.45))
                                .multilineTextAlignment(.center)
                            Text(LocalizationManager.shared.t("settings_safety_disclaimer"))
                                .font(.system(size: 10))
                                .foregroundColor(.orange.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitle(LocalizationManager.shared.t("vip_member_center"), displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("close")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
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
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertIsError
                              ? LocalizationManager.shared.t("payment_failed_title")
                              : LocalizationManager.shared.t("payment_status_title")),
                  message: Text(alertMsg),
                  dismissButton: .default(Text(LocalizationManager.shared.t("done"))))
        }
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
    
    private func privilegeItem(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                .frame(width: 20)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11))
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
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(tag)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(isSelected ? Color.yellow.opacity(0.3) : Color.white.opacity(0.1))
                            .foregroundColor(isSelected ? .yellow : .white.opacity(0.7))
                            .cornerRadius(3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(id.desc)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(iap.localizedPrice(for: id))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
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
