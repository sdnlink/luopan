import SwiftUI

// MARK: - 罗盘双针与地磁传感器校准弹窗 (Calibration Sheet)

public struct CalibrationSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var motion = CompassMotionManager.shared
    
    @State private var isCalibrating = false
    @State private var rotateDegree: Double = 0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.11)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // 1. 顶部标题栏
                    HStack {
                        Image(systemName: "safari.fill")
                            .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                        Text("罗盘双针与地磁偏角校准")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.top, 16)
                    
                    // 2. 传感器实时健康度指标卡
                    VStack(spacing: 10) {
                        statusRow(
                            title: "传感器测量精度",
                            value: motion.accuracyLevel >= 2 ? "✓ 极高 (已自动校准)" : "需轻晃校准",
                            isOk: motion.accuracyLevel >= 2
                        )
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        statusRow(
                            title: "环境磁场状态",
                            value: motion.isDistorted ? "⚠️ 强磁干扰 (\(String(format: "%.1f", motion.magneticStrengthUT)) μT)" : "✓ 均匀正常 (\(String(format: "%.1f", motion.magneticStrengthUT)) μT)",
                            isOk: !motion.isDistorted
                        )
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        statusRow(
                            title: "当前经纬坐标",
                            value: String(format: "%.4f°N, %.4f°E", motion.latitude, motion.longitude),
                            isOk: true,
                            customColor: Color.yanCyan
                        )
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        let decl = motion.currentDeclination
                        let declStr = motion.hasDeclination ? String(format: "%@%.2f°", decl >= 0 ? "东偏 " : "西偏 ", abs(decl)) : "GPS测算中…"
                        statusRow(
                            title: "当地地磁偏角",
                            value: declStr,
                            isOk: true,
                            customColor: Color(red: 0.95, green: 0.82, blue: 0.4)
                        )
                    }
                    .padding(14)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                    .cornerRadius(12)
                    
                    // 3. 双针系统与易学考据说明卡
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("🧭")
                            Text("双针系统与易学考据")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6).padding(.top, 4)
                                Text("绿色“磁”针：地磁北（地盘正针），物理磁场实测，传统立向格龙之准绳。")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(2)
                            }
                            
                            HStack(alignment: .top, spacing: 4) {
                                Circle().fill(Color(red: 0.95, green: 0.82, blue: 0.4)).frame(width: 6, height: 6).padding(.top, 4)
                                Text("金色“真”针：地理真北（对应现代地图北向），经全球地磁模型(WMM)与GPS精确实时校正。")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(2)
                            }
                            
                            HStack(alignment: .top, spacing: 4) {
                                Circle().fill(Color.yanCyan).frame(width: 6, height: 6).padding(.top, 4)
                                Text("两针夹角：即为您所在地的真实地磁偏角。")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                    .cornerRadius(12)
                    
                    // 4. “8”字形翻转校准引导卡
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "infinity")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                                .rotationEffect(.degrees(rotateDegree))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text("传感器快速“8”字校准")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text("若遇指针微抖或强磁干扰，拿起手机在空中按“8”字形翻转挥动 2~3 次，内置地磁传感器将自动完成多轴空间偏移校正并恢复最佳精度。")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(red: 0.13, green: 0.12, blue: 0.11))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.3), lineWidth: 1)
                    )
                    
                    // 5. 操作按键
                    VStack(spacing: 10) {
                        Button(action: {
                            isCalibrating = true
                            withAnimation(Animation.linear(duration: 1.5).repeatCount(2, autoreverses: false)) {
                                rotateDegree += 360
                            }
                            motion.resetManualOffset()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                isCalibrating = false
                            }
                        }) {
                            HStack {
                                Image(systemName: isCalibrating ? "arrow.2.circlepath" : "arrow.triangle.2.circlepath")
                                Text(isCalibrating ? "正在校准地磁传感器…" : "重新校准传感器")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
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
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("我知道了")
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func statusRow(title: String, value: String, isOk: Bool, customColor: Color? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.75))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((customColor ?? (isOk ? Color.green : Color.red)).opacity(0.15))
                .foregroundColor(customColor ?? (isOk ? Color.green : Color.red))
                .cornerRadius(4)
        }
    }
}
