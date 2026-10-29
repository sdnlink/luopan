import SwiftUI
import UIKit

// MARK: - 罗盘双针与地磁传感器校准弹窗 (Calibration Sheet)

public struct CalibrationSheet: View {
    /// Settings disables live sensors while idle. The settings-hosted sheet
    /// opts into a temporary sensor session; the compass-hosted sheet keeps
    /// the parent compass session unchanged.
    public let keepsMotionActive: Bool
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    
    @State private var isCalibrating = false
    @State private var rotateDegree: Double = 0
    
    public init(keepsMotionActive: Bool = false) {
        self.keepsMotionActive = keepsMotionActive
    }
    
    public var body: some View {
        return ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.11)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // 1. 顶部标题栏
                    HStack {
                        Image(systemName: "safari.fill")
                            .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                        Text(lang.t("calib_sheet_title"))
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
                            title: lang.t("calib_precision_title"),
                            value: motion.accuracyLevel >= 2 ? lang.t("calib_precision_high") : lang.t("calib_precision_need"),
                            isOk: motion.accuracyLevel >= 2
                        )
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        statusRow(
                            title: lang.t("calib_env_mag_title"),
                            value: motion.isDistorted ? "\(lang.t("calib_mag_distorted")) (\(String(format: "%.1f", motion.magneticStrengthUT)) μT)" : "\(lang.t("calib_mag_normal")) (\(String(format: "%.1f", motion.magneticStrengthUT)) μT)",
                            isOk: !motion.isDistorted
                        )
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        statusRow(
                            title: lang.t("calib_coords_title"),
                            value: motion.coordsDesc,
                            isOk: true,
                            customColor: Color.yanCyan
                        )
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        statusRow(
                            title: lang.t("calib_declination_title"),
                            value: declinationDisplay,
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
                            Text(lang.t("calib_dual_needle_section"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 4) {
                                Circle().fill(Color.green).frame(width: 6, height: 6).padding(.top, 4)
                                Text(lang.t("calib_magnetic_needle_desc"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(2)
                            }
                            
                            HStack(alignment: .top, spacing: 4) {
                                Circle().fill(Color(red: 0.95, green: 0.82, blue: 0.4)).frame(width: 6, height: 6).padding(.top, 4)
                                Text(lang.t("calib_true_needle_desc"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(2)
                            }
                            
                            HStack(alignment: .top, spacing: 4) {
                                Circle().fill(Color.yanCyan).frame(width: 6, height: 6).padding(.top, 4)
                                Text(lang.t("calib_angle_desc"))
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
                                Text(lang.t("calib_eight_quick"))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text(lang.t("calib_eight_desc"))
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
                            motion.requestSensorCalibration()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                isCalibrating = false
                            }
                        }) {
                            HStack {
                                Image(systemName: isCalibrating ? "arrow.2.circlepath" : "arrow.triangle.2.circlepath")
                                Text(isCalibrating ? lang.t("calibrating_now") : lang.t("recalibrate_btn"))
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
                        .disabled(isCalibrating)
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text(lang.t("i_know"))
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
        .onAppear {
            guard keepsMotionActive else { return }
            motion.setDeviceMotionEnabled(true)
            motion.setHeadingUpdatesEnabled(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard keepsMotionActive else { return }
            motion.setDeviceMotionEnabled(true)
            motion.setHeadingUpdatesEnabled(true)
        }
        .onDisappear {
            guard keepsMotionActive else { return }
            motion.setDeviceMotionEnabled(false)
            motion.setHeadingUpdatesEnabled(false)
        }
    }

    private var declinationDisplay: String {
        let decl = motion.currentDeclination
        let locationDenied = motion.locationAuthorizationStatus == .denied || motion.locationAuthorizationStatus == .restricted
        if motion.hasDeclination {
            return String(format: "%@%.2f°", decl >= 0 ? lang.t("calib_decl_east") : lang.t("calib_decl_west"), abs(decl))
        }
        if locationDenied {
            return lang.t("location_unavailable")
        }
        return lang.t("calib_decl_calculating")
    }
    
    private func statusRow(title: String, value: String, isOk: Bool, customColor: Color? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.75))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((customColor ?? (isOk ? Color.green : Color.red)).opacity(0.15))
                .foregroundColor(customColor ?? (isOk ? Color.green : Color.red))
                .cornerRadius(4)
        }
    }
}
