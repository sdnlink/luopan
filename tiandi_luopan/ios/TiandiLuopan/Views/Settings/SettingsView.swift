import SwiftUI

// MARK: - 系统设置与专业版会员中心视图 (Settings & Member Center View)

public struct SettingsView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showCalibrationGuide: Bool = false
    @State private var selectedProductId: String = IAPProductID.vipYearly.rawValue
    
    public init() {}
    
    private var isProUnlocked: Bool {
        return iap.isLifetimeUser || iap.isVIPUser
    }
    
    public var body: some View {
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
                                .foregroundColor(.white)
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
                            productRow(id: .vipYearly, tag: "超值推荐")
                            productRow(id: .proLifetime, tag: "一次买断")
                            productRow(id: .floorplanSingle, tag: "单套全案")
                            productRow(id: .tianjiSingle, tag: "单次导出")
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
                                    Text("Apple Pay 一键开通所选服务")
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
                            
                            Button(action: {
                                iap.restorePurchases()
                            }) {
                                HStack {
                                    Spacer()
                                    Text("恢复已有购买 (Restore Purchases)")
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
                Section(header: Text("VIP 尊享专业特权清单")) {
                    privilegeRow(icon: "sparkles", title: "三式绝学 · 时家奇门遁甲全息排盘与出行导航")
                    privilegeRow(icon: "calendar.badge.clock", title: "紫白飞星 · 流年流月动态气运布防与太岁三煞自检")
                    privilegeRow(icon: "house.fill", title: "户型空间立极 · 户型图布盘与全屋火烧天门风水体检")
                    privilegeRow(icon: "scroll.fill", title: "福宅天机书 · 古典宣纸朱丝栏大师勘测长卷导出")
                    privilegeRow(icon: "camera.viewfinder", title: "AR 实景天心透视与八大经典形煞智能研判")
                }
                
                // 3. 专业罗盘与偏好设置
                Section(header: Text(lang.t("app_language"))) {
                    Toggle(lang.t("haptic_feedback"), isOn: $motion.isHapticEnabled)
                    
                    Picker(lang.t("app_language"), selection: $lang.currentSetting) {
                        ForEach(AppLanguage.allCases) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    
                    HStack {
                        Text("GPS 实时经纬坐标")
                        Spacer()
                        Text(motion.coordsDesc)
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    
                    HStack {
                        Text("真太阳时 Spencer 均时差")
                        Spacer()
                        Text(motion.solarTimeDesc)
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                }
                
                // 4. 硬件传感器与校准
                Section(header: Text("硬件传感器与指南针校准")) {
                    HStack {
                        Text("磁场干扰状态")
                        Spacer()
                        Text(motion.isDistorted ? "检测到强磁干扰 ⚠️" : "磁场正常 (无干扰)")
                            .foregroundColor(motion.isDistorted ? .red : .green)
                            .font(.system(size: 13))
                    }
                    
                    HStack {
                        Text("磁场感应强度")
                        Spacer()
                        Text(String(format: "%.1f μT", motion.magneticStrengthUT))
                            .foregroundColor(.secondary)
                            .font(.system(size: 13, design: .monospaced))
                    }
                    
                    Button(action: {
                        showCalibrationGuide = true
                    }) {
                        HStack {
                            Text("罗盘双针与地磁偏角校准")
                            Spacer()
                            Text(motion.isDistorted ? "需校准 ⚠️" : "极高 ✓")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(motion.isDistorted ? .orange : .green)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 5. 关于与版本信息
                Section(header: Text("关于演象")) {
                    HStack {
                        Text("软件版本")
                        Spacer()
                        Text("v1.3.0 (SwiftUI Native 2.0)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    HStack {
                        Text("易学理论基础")
                        Spacer()
                        Text("沈氏玄空 · 杨公水法 · 时家奇门")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("系统设置与会员", displayMode: .inline)
            .sheet(isPresented: $showCalibrationGuide) {
                CalibrationSheet()
            }
        }
    }
    
    private func productRow(id: IAPProductID, tag: String) -> some View {
        let isSelected = selectedProductId == id.rawValue
        
        return Button(action: {
            selectedProductId = id.rawValue
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(id.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        Text(tag)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.yellow.opacity(0.2))
                            .foregroundColor(Color.yellow)
                            .cornerRadius(3)
                    }
                    Text(id.desc)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer()
                Text(id.priceText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }
            .padding(8)
            .background(isSelected ? Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.15) : Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.clear, lineWidth: 1.5)
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
            Text("VIP")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.yellow)
        }
    }
}

// MARK: - 8字校准指南弹窗
public struct CalibrationGuideSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                    .padding(.top, 30)
                
                Text("指南针与磁场 8 字校准法")
                    .font(.system(size: 18, weight: .bold))
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. 请远离强磁性金属、电脑主机、音箱及大型变压设备；")
                    Text("2. 手握手机，在空中沿空间三维方向划出流畅的「∞」字形轨迹；")
                    Text("3. 重复划动 3 至 5 次，直至罗盘顶部磁场状态恢复为绿色正常状态。")
                }
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .navigationBarTitle("校准指引", displayMode: .inline)
            .navigationBarItems(trailing: Button("知道了") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
