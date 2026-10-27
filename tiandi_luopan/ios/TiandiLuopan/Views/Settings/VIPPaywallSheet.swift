import SwiftUI
import StoreKit

// MARK: - VIP 权限拦截遮罩卡片 (VIP Lock Card View)

public struct VIPLockCardView: View {
    public let title: String
    public let featureDesc: String
    public var badge: String = "👑 VIP 绝学特权"
    public var targetProductId: IAPProductID = .vipYearly
    public var onUnlockTap: () -> Void
    
    public init(
        title: String,
        featureDesc: String,
        badge: String = "👑 VIP 绝学特权",
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
                Spacer()
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundColor(Color.yellow)
                    .cornerRadius(4)
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
                        Text("立即解锁特权 (\(targetProductId.priceText))")
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
                    Text("恢复购买")
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
    
    @State private var selectedProductId: String = IAPProductID.vipYearly.rawValue
    @State private var isPurchasing: Bool = false
    @State private var alertMsg: String = ""
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
                            
                            Text("演象·时空罗盘 VIP 尊享特权")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("传承正统三元玄空、三式奇门与杨公形气风水绝学")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        
                        // 2. 核心特权清单
                        VStack(spacing: 8) {
                            privilegeItem(icon: "sparkles", title: "时家奇门全息排盘", desc: "九星八门八神三奇六仪转盘与大吉出行方位导航")
                            privilegeItem(icon: "calendar.badge.clock", title: "紫白客星与太岁三煞", desc: "流年流月客星飞临与二五交加凶煞动态布防")
                            privilegeItem(icon: "drop.triangle.fill", title: "杨公八路黄泉与消砂", desc: "救贫水法判据、二十四山坐山克煞曜位精准辨识")
                            privilegeItem(icon: "house.fill", title: "户型立极全屋体检", desc: "空间几何重心立极、火烧天门/水浸中宫全案体检")
                            privilegeItem(icon: "scroll.fill", title: "福宅天机书宣纸长卷", desc: "高清无水印古典宣纸朱丝栏大师全案长卷导出与打印")
                        }
                        .padding(12)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        
                        // 3. 四档商品套餐选择
                        VStack(spacing: 8) {
                            productChoiceCard(
                                id: .vipYearly,
                                tag: "推荐 · 最具性价比",
                                isSelected: selectedProductId == IAPProductID.vipYearly.rawValue
                            )
                            
                            productChoiceCard(
                                id: .proLifetime,
                                tag: "一次买断 · 终身享用",
                                isSelected: selectedProductId == IAPProductID.proLifetime.rawValue
                            )
                            
                            productChoiceCard(
                                id: .floorplanSingle,
                                tag: "单套户型全屋体检",
                                isSelected: selectedProductId == IAPProductID.floorplanSingle.rawValue
                            )
                            
                            productChoiceCard(
                                id: .tianjiSingle,
                                tag: "单次高清长卷导出",
                                isSelected: selectedProductId == IAPProductID.tianjiSingle.rawValue
                            )
                        }
                        .padding(.horizontal, 16)
                        
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
                                    Text(isPurchasing ? "正在连接 App Store 安全支付…" : "立即开通 \(getSelectedProductTitle())")
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
                            
                            Button(action: {
                                iap.restorePurchases()
                            }) {
                                Text("恢复已有购买 (Restore Purchases)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.yanCyan)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.horizontal, 16)
                        
                        // 5. 自动续期与苹果服务说明
                        VStack(spacing: 4) {
                            Text("购买即代表同意《用户协议》与《隐私政策》。订阅款项将通过您的 Apple ID 账户扣除。")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.45))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitle("会员特权与收银台", displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
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
            if count > 0 && selectedProductId == IAPProductID.floorplanSingle.rawValue {
                isPurchasing = false
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onReceive(iap.$tianjiCreditsCount) { count in
            if count > 0 && selectedProductId == IAPProductID.tianjiSingle.rawValue {
                isPurchasing = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func getSelectedProductTitle() -> String {
        switch selectedProductId {
        case IAPProductID.vipYearly.rawValue: return "年度 VIP (¥198)"
        case IAPProductID.proLifetime.rawValue: return "大师终身版 (¥298)"
        case IAPProductID.floorplanSingle.rawValue: return "单套体检 (¥19.9)"
        case IAPProductID.tianjiSingle.rawValue: return "单次天机书 (¥9.9)"
        default: return "VIP 特权"
        }
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
                        Text(tag)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(isSelected ? Color.yellow.opacity(0.3) : Color.white.opacity(0.1))
                            .foregroundColor(isSelected ? .yellow : .white.opacity(0.7))
                            .cornerRadius(3)
                    }
                    Text(id.desc)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(id.priceText)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
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
