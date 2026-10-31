import SwiftUI

// MARK: - 罗盘顶部数据仪表盘与天心十道状态视图 (Compass Header View)

public struct CompassHeaderView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    
    public init() {}
    
    public var body: some View {
        let state = motion.headingState
        
        VStack(spacing: 8) {
            // 顶栏 1: 核心度数与坐向徽章
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                // 实时度数 (大字体)
                HStack(alignment: .top, spacing: 2) {
                    Text(String(format: "%.1f", state.facingAngle))
                        .font(.adaptive(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("°")
                        .font(.adaptive(size: 17, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.8))
                }
                
                // 坐向与二十四山
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                    Text("\(state.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(state.facingMountain.localizedName)\(lang.t("facing_suffix"))")
                            .font(.adaptive(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        
                        Text(state.facingMountain.localizedPalace + lang.t("palace_suffix"))
                            .font(.adaptive(size: 11, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.25))
                            .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.4))
                            .cornerRadius(4)
                    }
                    
                    Text(state.fenJinDesc)
                        .font(.adaptive(size: 12, weight: .medium))
                        .foregroundColor(state.isJianXiang ? Color.orange : Color(red: 0.8, green: 0.8, blue: 0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                Spacer()
                
                // 锁盘与回正快捷按键
                HStack(spacing: 8) {
                    Button(action: {
                        motion.resetManualOffset()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.adaptive(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        motion.toggleLock()
                    }) {
                        Image(systemName: motion.isLocked ? "lock.fill" : "lock.open")
                            .font(.adaptive(size: 13, weight: .bold))
                            .foregroundColor(motion.isLocked ? Color.yellow : Color.white)
                            .frame(width: 32, height: 32)
                            .background(motion.isLocked ? Color.yellow.opacity(0.25) : Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // 顶栏 2: 真太阳时、经纬度与双轴倾角
            HStack(spacing: 12) {
                // 真太阳时
                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.adaptive(size: 11))
                        .foregroundColor(Color.orange)
                    Text("\(lang.t("true_solar_time_prefix")) \(motion.trueSolarTimeStr)")
                        .font(.adaptive(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                // 水平倾角状态
                HStack(spacing: 5) {
                    Circle()
                        .fill(motion.isLevel ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text("\(lang.t("pitch_label")) \(String(format: "%.1f", motion.pitch))° / \(lang.t("roll_label")) \(String(format: "%.1f", motion.roll))°")
                        .font(.adaptive(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.35))
            .cornerRadius(8)
            .padding(.horizontal, 12)
        }
        .padding(.top, 6)
    }
}
