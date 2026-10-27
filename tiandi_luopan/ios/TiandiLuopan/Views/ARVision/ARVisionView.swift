import SwiftUI
import AVFoundation
import UIKit

// MARK: - 原生高清相机预览层 (AVCaptureSession Representable)

public struct CameraPreviewView: UIViewRepresentable {
    public var cameraPosition: AVCaptureDevice.Position
    public var isActive: Bool
    
    public init(cameraPosition: AVCaptureDevice.Position = .back, isActive: Bool = true) {
        self.cameraPosition = cameraPosition
        self.isActive = isActive
    }
    
    public class CameraUIView: UIView {
        private var captureSession: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var currentPosition: AVCaptureDevice.Position = .back
        
        override public func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
        
        public func setupSession(position: AVCaptureDevice.Position) {
            currentPosition = position
            
            if let session = captureSession {
                session.stopRunning()
                captureSession = nil
                previewLayer?.removeFromSuperlayer()
                previewLayer = nil
            }
            
            let session = AVCaptureSession()
            session.sessionPreset = .high
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                return
            }
            
            session.addInput(input)
            
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = bounds
            layer.addSublayer(preview)
            
            self.captureSession = session
            self.previewLayer = preview
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
        
        public func resumeSessionIfNeeded(position: AVCaptureDevice.Position) {
            if let session = captureSession, session.isRunning {
                return
            }
            setupSession(position: position)
        }
        
        public func stopSession() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                if let s = self?.captureSession, s.isRunning {
                    s.stopRunning()
                }
            }
        }
    }
    
    public func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        view.backgroundColor = .black
        if isActive {
            view.setupSession(position: cameraPosition)
        }
        return view
    }
    
    public func updateUIView(_ uiView: CameraUIView, context: Context) {
        if !isActive {
            uiView.stopSession()
            return
        }
        
        // 当镜头切换时或重新激活时配置
        if context.coordinator.lastPosition != cameraPosition || context.coordinator.lastActive != isActive {
            context.coordinator.lastPosition = cameraPosition
            context.coordinator.lastActive = isActive
            uiView.resumeSessionIfNeeded(position: cameraPosition)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(position: cameraPosition, active: isActive)
    }
    
    public class Coordinator {
        var lastPosition: AVCaptureDevice.Position
        var lastActive: Bool
        init(position: AVCaptureDevice.Position, active: Bool) {
            self.lastPosition = position
            self.lastActive = active
        }
    }
    
    public static func dismantleUIView(_ uiView: CameraUIView, coordinator: Coordinator) {
        uiView.stopSession()
    }
}

// MARK: - AR 实景天心透视与形煞智能标注视图 (AR Vision View)

public struct ARVisionView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    
    public var isActive: Bool = true
    
    // 激光扫描线动画
    @State private var scanOffset: CGFloat = -180
    @State private var selectedShaIndex: Int = 0
    @State private var isAutoFollowingDirection: Bool = true // 实景朝向智能跟随
    @State private var targetOffset: CGSize = .zero
    @State private var showRemedySheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var hasCameraPermission: Bool = false
    @State private var showSnapshotToast: Bool = false
    @State private var cameraPosition: AVCaptureDevice.Position = .back
    
    private let shaList = ExteriorShaEngine.shared.database
    
    public init(isActive: Bool = true) {
        self.isActive = isActive
    }
    
    // 计算靶心拖拽后的相对目标偏角与二十四山
    private var targetCalculatedHeading: Double {
        let angleDelta = Double(targetOffset.width / 8.0)
        let raw = motion.headingState.facingAngle + angleDelta
        return (raw.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
    
    private var targetMountain: Mountain24 {
        return Mountain24Data.shared.mountain(for: targetCalculatedHeading)
    }
    
    // 八宫方位与主应形煞对应模型 (随镜头旋转自动联动推演)
    private func resolvedShaIndex(for heading: Double) -> Int {
        let norm = (heading.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        if norm >= 337.5 || norm < 22.5 {
            return 4 // 正北 坎水: 穿心煞 (玄武失靠/地下贯通)
        } else if norm >= 22.5 && norm < 67.5 {
            return 7 // 东北 艮土: 割脚煞 (急流贴足/鬼门阴煞)
        } else if norm >= 67.5 && norm < 112.5 {
            return 1 // 正东 震木: 路冲煞 (直枪冲射/青龙折损)
        } else if norm >= 112.5 && norm < 157.5 {
            return 2 // 东南 巽木: 反弓水 (弯刀割脚/甩气破财)
        } else if norm >= 157.5 && norm < 202.5 {
            return 5 // 正南 离火: 火形煞 (尖峰燥角/火曜克金)
        } else if norm >= 202.5 && norm < 247.5 {
            return 0 // 西南 坤土: 天斩煞 (坤为死门/两楼天堑穿心)
        } else if norm >= 247.5 && norm < 292.5 {
            return 6 // 正西 兑金: 白虎煞 (白虎探头/虎强龙弱)
        } else {
            return 3 // 西北 乾金: 探头煞 (火烧天门/暗室窥视)
        }
    }
    
    private var activeShaIndex: Int {
        if isAutoFollowingDirection {
            return resolvedShaIndex(for: targetCalculatedHeading)
        }
        return min(max(selectedShaIndex, 0), shaList.count - 1)
    }
    
    public var body: some View {
        ZStack {
            // 1. 真机摄像头实时预览 / 模拟器仿真画板 (仅在 AR Tab 激活时工作，后台休眠避免发烫)
            if hasCameraPermission && isActive {
                CameraPreviewView(cameraPosition: cameraPosition, isActive: isActive)
                    .ignoresSafeArea()
            } else {
                simulationCanvasLayer()
                    .ignoresSafeArea()
            }
            
            // 2. 激光天心扫描光束 (动态往返扫掠)
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.yanCyan.opacity(0.6), Color.yanCyan, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 2)
                    .offset(y: scanOffset)
            }
            .allowsHitTesting(false)
            
            // 3. 屏幕中心天心透视十字准星
            crosshairCenterLayer()
            
            // 4. 可拖拽形煞目标物实景锁定框 (结合动态偏角解算)
            targetBoundingBoxLayer()
            
            // 5. 顶栏悬浮与拍照存证控制栏
            VStack {
                topStatusBar()
                
                Spacer()
                
                // 截图存证保存提示
                if showSnapshotToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(lang.t("save_success"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // 6. 底部形煞智能研判卡与操作栏
                bottomShaControlPanel()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .onAppear {
            checkCameraPermission()
            withAnimation(Animation.linear(duration: 2.5).repeatForever(autoreverses: true)) {
                scanOffset = 180
            }
        }
        .sheet(isPresented: $showRemedySheet) {
            ShaRemedyDetailSheet(sha: shaList[activeShaIndex])
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.hasCameraPermission = granted
                }
            }
        default:
            hasCameraPermission = false
        }
    }
    
    // MARK: - 模拟器或无相机时的实景演练仿真画板
    private func simulationCanvasLayer() -> some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.12)
            
            // 仿真网格与室外建筑剪影
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 20) {
                    Rectangle().fill(Color.white.opacity(0.06)).frame(width: 80, height: 260)
                    Rectangle().fill(Color.white.opacity(0.08)).frame(width: 120, height: 380)
                    Rectangle().fill(Color.white.opacity(0.05)).frame(width: 90, height: 310)
                }
                .padding(.bottom, 80)
            }
            
            VStack(spacing: 8) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 40))
                    .foregroundColor(Color.yanCyan.opacity(0.5))
                Text(lang.t("simulation_mode"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Text(lang.t("ar_drag_hint"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
    
    // MARK: - 十字天心准星
    private func crosshairCenterLayer() -> some View {
        ZStack {
            Circle()
                .stroke(Color.yanCyan.opacity(0.5), lineWidth: 1.5)
                .frame(width: 140, height: 140)
            
            Circle()
                .stroke(Color.yanCyan.opacity(0.8), lineWidth: 1)
                .frame(width: 40, height: 40)
            
            // 十字准星
            Rectangle()
                .fill(Color.yanCyan.opacity(0.6))
                .frame(width: 1, height: 180)
            Rectangle()
                .fill(Color.yanCyan.opacity(0.6))
                .frame(width: 180, height: 1)
            
            Text("\(String(format: "%.1f", motion.headingState.facingAngle))°")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.yanCyan)
                .offset(y: -50)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - 可拖拽形煞目标锁定框 (动态解算偏角与对应二十四山)
    private func targetBoundingBoxLayer() -> some View {
        let currentSha = shaList[activeShaIndex]
        let m = targetMountain
        
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 180, height: 115)
                .background(Color.yellow.opacity(0.12))
            
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("\(lang.t("ar_target_center")) · \(m.name)\(lang.t("mountain_suffix"))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow)
                }
                Text(currentSha.name)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text("\(lang.t("ar_target_bearing")): \(String(format: "%.1f", targetCalculatedHeading))° (\(m.palace))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(currentSha.aliases)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .offset(targetOffset)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    targetOffset = gesture.translation
                }
        )
    }
    
    // MARK: - 顶栏信息与镜头翻转控制
    private func topStatusBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("ar_title"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text("\(lang.t("ar_physical_facing")): \(motion.headingState.facingMountain.name)\(lang.t("mountain_suffix")) (\(String(format: "%.1f", motion.headingState.facingAngle))°)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            
            // 翻转镜头按钮
            Button(action: {
                cameraPosition = (cameraPosition == .back) ? .front : .back
            }) {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 13))
                    .padding(8)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            
            // 勘测存证快照拍照按钮
            Button(action: {
                if !iap.hasUnlockedVIP {
                    showPaywall = true
                } else {
                    captureAndSaveSnapshot()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                    Text(lang.t("capture_proof"))
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.8))
                .foregroundColor(.black)
                .cornerRadius(14)
            }
            
            // 大师化解锦囊
            Button(action: {
                showRemedySheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "shield.lefthalf.fill")
                    Text(lang.t("remedy_guide"))
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color(red: 0.83, green: 0.68, blue: 0.21))
                .foregroundColor(.black)
                .cornerRadius(14)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.65))
        .cornerRadius(10)
    }
    
    // MARK: - 底部形煞研判卡 (支持朝向智能跟随与手动点选)
    private func bottomShaControlPanel() -> some View {
        let currentIdx = activeShaIndex
        let sha = shaList[currentIdx]
        
        return VStack(spacing: 8) {
            HStack {
                Button(action: {
                    isAutoFollowingDirection.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isAutoFollowingDirection ? "location.fill" : "lock.fill")
                        Text(isAutoFollowingDirection ? "实景朝向跟随" : "手动锁定形煞")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isAutoFollowingDirection ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
                    .foregroundColor(isAutoFollowingDirection ? .green : .orange)
                    .cornerRadius(6)
                }
                
                Spacer()
                
                Text("当前主应：\(targetMountain.palace) · \(targetMountain.name)山")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }
            .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<shaList.count, id: \.self) { idx in
                        let item = shaList[idx]
                        let isSelected = (idx == currentIdx)
                        Button(action: {
                            isAutoFollowingDirection = false
                            selectedShaIndex = idx
                        }) {
                            Text(item.name)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(isSelected ? Color.yanCyan.opacity(0.85) : Color.white.opacity(0.15))
                                .foregroundColor(isSelected ? .black : .white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("【\(sha.name)】\(lang.t("ar_sha_analysis_prefix")):")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Spacer()
                    Text(sha.severity.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(sha.severity == .critical ? Color.red : Color.orange)
                }
                Text(sha.metaphysicsHarm)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            .padding(8)
            .background(Color.black.opacity(0.75))
            .cornerRadius(8)
        }
    }
    
    // MARK: - 绘制并保存带水印防伪印章的现场勘测存证快照
    private func captureAndSaveSnapshot() {
        let size = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let currentSha = shaList[activeShaIndex]
        let currentHeading = motion.headingState.facingAngle
        let mFacing = motion.headingState.facingMountain
        let coordsStr = motion.coordsDesc
        
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            
            // 底色
            cg.setFillColor(UIColor(red: 18/255.0, green: 18/255.0, blue: 24/255.0, alpha: 1.0).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            
            // 十字天心
            cg.setStrokeColor(UIColor(red: 0.0, green: 0.82, blue: 0.95, alpha: 0.6).cgColor)
            cg.setLineWidth(3)
            cg.move(to: CGPoint(x: size.width / 2, y: 0))
            cg.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            cg.move(to: CGPoint(x: 0, y: size.height / 2))
            cg.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            cg.strokePath()
            
            // 水印卡片
            let cardRect = CGRect(x: 40, y: size.height - 380, width: size.width - 80, height: 320)
            cg.setFillColor(UIColor(red: 12/255.0, green: 12/255.0, blue: 16/255.0, alpha: 0.9).cgColor)
            cg.fill(cardRect)
            cg.setStrokeColor(UIColor(red: 212/255.0, green: 175/255.0, blue: 55/255.0, alpha: 0.8).cgColor)
            cg.setLineWidth(2)
            cg.stroke(cardRect)
            
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 36),
                .foregroundColor: UIColor(red: 242/255.0, green: 217/255.0, blue: 115/255.0, alpha: 1.0)
            ]
            lang.t("ar_watermark_title").draw(at: CGPoint(x: 70, y: size.height - 350), withAttributes: titleAttr)
            
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.white
            ]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timeStr = dateFormatter.string(from: Date())
            
            let isEn = LocalizationManager.shared.effectiveLanguage == .en
            let isHant = LocalizationManager.shared.effectiveLanguage == .zhHant
            
            let infoText: String
            if isEn {
                infoText = """
                Facing Orientation: Mountain \(mFacing.pinyin) (Measured \(String(format: "%.1f", currentHeading))°)
                Identified Sha: [\(currentSha.name)] (\(currentSha.aliases)) · \(currentSha.severity.rawValue)
                Coordinates: \(coordsStr)
                Audit Time: \(timeStr) · SN: YX-AR-\(Int(Date().timeIntervalSince1970))
                """
            } else if isHant {
                infoText = """
                向首方位: \(mFacing.name)山向首 (實測 \(String(format: "%.1f", currentHeading))°) · \(mFacing.palace)
                識別形煞: 【\(currentSha.name)】(\(currentSha.aliases)) · \(currentSha.severity.rawValue)
                現場經緯: \(coordsStr)
                勘察時間: \(timeStr) · 防偽鑒真: YX-AR-\(Int(Date().timeIntervalSince1970))
                """
            } else {
                infoText = """
                向首方位: \(mFacing.name)山向首 (实测 \(String(format: "%.1f", currentHeading))°) · \(mFacing.palace)
                识别形煞: 【\(currentSha.name)】(\(currentSha.aliases)) · \(currentSha.severity.rawValue)
                现场经纬: \(coordsStr)
                勘察时间: \(timeStr) · 防伪鉴真: YX-AR-\(Int(Date().timeIntervalSince1970))
                """
            }
            infoText.draw(in: CGRect(x: 70, y: size.height - 290, width: size.width - 260, height: 210), withAttributes: bodyAttr)
            
            // 朱砂印鉴
            let sealRect = CGRect(x: size.width - 190, y: size.height - 230, width: 120, height: 120)
            cg.setStrokeColor(UIColor(red: 178/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0).cgColor)
            cg.setLineWidth(3)
            cg.stroke(sealRect)
            lang.t("ar_watermark_stamp").draw(in: sealRect.insetBy(dx: 18, dy: 18), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 26),
                .foregroundColor: UIColor(red: 178/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0)
            ])
        }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation {
            showSnapshotToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showSnapshotToast = false
            }
        }
    }
}

// MARK: - 形煞深度剖析与化解弹窗
public struct ShaRemedyDetailSheet: View {
    public let sha: ExteriorShaItem
    @ObservedObject var iap = StoreKitIAPManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var showPaywall: Bool = false
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(sha.name)
                                .font(.system(size: 24, weight: .bold, design: .serif))
                            Text(sha.aliases)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(sha.severity.rawValue)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizationManager.shared.t("ar_env_features"))
                            .font(.system(size: 15, weight: .bold))
                        Text(sha.visualFeature)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizationManager.shared.t("ar_classic_lore"))
                            .font(.system(size: 15, weight: .bold))
                        Text(sha.classicalText)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.yanBrown)
                            .padding(10)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizationManager.shared.t("ar_remedy_title"))
                            .font(.system(size: 15, weight: .bold))
                        
                        if !iap.hasUnlockedVIP {
                            VIPLockCardView(
                                title: LocalizationManager.shared.t("ar_vip_remedy_title"),
                                featureDesc: LocalizationManager.shared.t("ar_vip_remedy_desc"),
                                badge: LocalizationManager.shared.t("vip_badge_title"),
                                targetProductId: .vipYearly,
                                onUnlockTap: { showPaywall = true }
                            )
                        } else {
                            Text(sha.remedySolution)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                                .padding(10)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle(LocalizationManager.shared.t("sha_report"), displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showPaywall) {
                VIPPaywallSheet(defaultProductId: .vipYearly)
            }
        }
    }
}
