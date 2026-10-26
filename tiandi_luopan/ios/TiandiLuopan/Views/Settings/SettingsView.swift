import SwiftUI

// MARK: - 系统设置与专业版激活视图 (Settings View)

public struct SettingsView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @State private var isProUnlocked: Bool = false
    @State private var showCalibrationGuide: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                // 会员尊享卡
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Text("演象·时空罗盘 专业版")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(isProUnlocked ? "已激活" : "永久买断")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isProUnlocked ? Color.green.opacity(0.3) : Color.yellow.opacity(0.3))
                                .foregroundColor(isProUnlocked ? .green : .yellow)
                                .cornerRadius(6)
                        }
                        
                        Text("解锁全套玄空飞星高级兼向排盘、七星打劫局、AR形煞智能测定与大师化解锦囊。")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.75))
                        
                        if !isProUnlocked {
                            Button(action: {
                                StoreKitIAPManager.shared.purchase(productId: "com.tiandiluopan.pro_lifetime")
                            }) {
                                Text("立即激活专业版 (¥68 永久)")
                                    .font(.system(size: 13, weight: .bold))
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
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 硬件传感器与校准
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
                            Image(systemName: "gyroscope")
                                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                            Text("传感器 8 字绕环校准指引")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // 空间与坐标
                Section(header: Text("地理信息与真太阳时")) {
                    HStack {
                        Text("当前定位")
                        Spacer()
                        Text(motion.coordsDesc)
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    
                    HStack {
                        Text("视太阳时偏差")
                        Spacer()
                        Text("高精度经度视太阳时自动同步")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
                
                // 关于与版本
                Section(header: Text("关于演象堪舆")) {
                    HStack {
                        Text("应用架构")
                        Spacer()
                        Text("100% 纯原生 Swift / SwiftUI 现代引擎")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    HStack {
                        Text("版本号")
                        Spacer()
                        Text("v1.3.0 (Pure Swift Edition)")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("系统设置", displayMode: .inline)
            .sheet(isPresented: $showCalibrationGuide) {
                CalibrationGuideSheet()
            }
        }
    }
}

// MARK: - 8字校准指引弹窗
public struct CalibrationGuideSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                    .padding(.top, 40)
                
                Text("罗盘磁场水平校准")
                    .font(.system(size: 20, weight: .bold))
                
                Text("请手持 iPhone，在空中平稳画大「8」字轨迹三次。\n\n避开高压电线、铁质金属护栏与大功率音箱，即可完成地磁传感器高精度校正。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Spacer()
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("我已完成校准")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.83, green: 0.68, blue: 0.21))
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
