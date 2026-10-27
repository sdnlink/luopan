import SwiftUI

// MARK: - 主罗盘界面 (Compass Main View)

public struct CompassMainView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    
    // 弹窗状态
    @State private var showFenjinSheet = false
    @State private var showKongwangSheet = false
    @State private var showPalaceSheet = false
    @State private var showLayerSheet = false
    @State private var showCalibSheet = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 背景渐变
            Color(red: 0.07, green: 0.07, blue: 0.09)
                .ignoresSafeArea()
            
            VStack(spacing: 4) {
                // 1. 顶部数据仪表
                CompassHeaderView()
                
                // 强磁干扰动态告警条
                if motion.isDistorted {
                    Button(action: {
                        showCalibSheet = true
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color.orange)
                            Text("\(lang.t("mag_warning_tap")) (\(String(format: "%.0f", motion.magneticStrengthUT)) μT) · \(lang.t("tap_to_calib"))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.25))
                        .cornerRadius(6)
                        .padding(.horizontal, 16)
                    }
                }
                
                // 2. 罗盘快捷辅助工具条 (锁定朝向 / 分金详勘 / 空亡诊断 / 八方全鉴)
                compassToolBar()
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                
                Spacer(minLength: 4)
                
                // 3. 核心随动罗盘盘面 (包含 120分金、64卦、24山、八卦、水准仪)
                CompassDialView()
                    .padding(.horizontal, 8)
                
                Spacer(minLength: 4)
                
                // 4. 底部快捷周易分金与八宅提示卡 (可点击调起详细诊断)
                bottomStatusCard()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showFenjinSheet) {
            FenjinDetailSheet(fenjin: Fenjin120Data.shared.resolveFenjin(for: motion.headingState.facingAngle))
        }
        .sheet(isPresented: $showKongwangSheet) {
            KongWangDetailSheet(heading: motion.headingState.facingAngle)
        }
        .sheet(isPresented: $showPalaceSheet) {
            FengshuiPalaceDetailSheet()
        }
        .sheet(isPresented: $showLayerSheet) {
            LayerSettingsSheet()
        }
        .sheet(isPresented: $showCalibSheet) {
            CalibrationSheet()
        }
    }
    
    // MARK: - 罗盘工具条
    private func compassToolBar() -> some View {
        let m = motion.headingState.facingMountain
        let delta = abs(motion.headingState.facingAngle - m.centerAngle)
        let kwStatus = delta < 1.5 ? lang.t("pure_alignment") : (delta < 4.5 ? lang.t("sub_mountain") : lang.t("small_void"))
        let kwColor = delta < 1.5 ? Color.green : (delta < 4.5 ? Color.yellow : Color.orange)
        
        return HStack(spacing: 8) {
            // 锁定朝向按钮
            Button(action: {
                withAnimation {
                    motion.isLocked.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: motion.isLocked ? "lock.fill" : "lock.open")
                    Text(motion.isLocked ? lang.t("locked_heading") : lang.t("lock_heading"))
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(motion.isLocked ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                .foregroundColor(motion.isLocked ? .red : .white)
                .cornerRadius(6)
            }
            
            // 空亡全景诊断
            Button(action: {
                showKongwangSheet = true
            }) {
                HStack(spacing: 3) {
                    Circle().fill(kwColor).frame(width: 5, height: 5)
                    Text(kwStatus)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(kwColor.opacity(0.15))
                .foregroundColor(kwColor)
                .cornerRadius(6)
            }
            
            Spacer()
            
            // 校准
            Button(action: {
                showCalibSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "safari.fill")
                    Text(lang.t("btn_calib"))
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .foregroundColor(motion.isDistorted ? Color.orange : Color(red: 0.95, green: 0.82, blue: 0.4))
                .cornerRadius(6)
            }
            
            // 图层设置
            Button(action: {
                showLayerSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "square.3.layers.3d")
                    Text(lang.t("btn_layers"))
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .foregroundColor(Color.yanCyan)
                .cornerRadius(6)
            }
            
            // 八方全鉴
            Button(action: {
                showPalaceSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "square.grid.2x2")
                    Text(lang.t("btn_palace_all"))
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                .cornerRadius(6)
            }
        }
    }
    
    // MARK: - 底部状态卡
    private func bottomStatusCard() -> some View {
        let hex = Hexagram64Data.shared.hexagram(for: motion.headingState.facingAngle)
        let fenjin = Fenjin120Data.shared.resolveFenjin(for: motion.headingState.facingAngle)
        
        return Button(action: {
            showFenjinSheet = true
        }) {
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 6) {
                        Text(hex.name)
                            .font(.system(size: 15, weight: .bold, design: .serif))
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text(fenjin.jiaziName)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(fenjin.isAuspicious ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(fenjin.isAuspicious ? Color.green : Color.red)
                            .cornerRadius(4)
                        Text(fenjin.grade)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Text(lang.t("btn_fenjin_detail"))
                            .font(.system(size: 11))
                            .foregroundColor(Color.yanCyan)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(Color.yanCyan)
                    }
                }
                
                HStack {
                    Text(fenjin.lore)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
