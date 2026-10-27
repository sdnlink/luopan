import SwiftUI
import AVFoundation
import UIKit

// MARK: - 原生高清相机预览层 (AVCaptureSession Representable)

public struct CameraPreviewView: UIViewRepresentable {
    public var cameraPosition: AVCaptureDevice.Position
    
    public init(cameraPosition: AVCaptureDevice.Position = .back) {
        self.cameraPosition = cameraPosition
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
        view.setupSession(position: cameraPosition)
        return view
    }
    
    public func updateUIView(_ uiView: CameraUIView, context: Context) {
        // 当镜头切换时重新配置
        if context.coordinator.lastPosition != cameraPosition {
            context.coordinator.lastPosition = cameraPosition
            uiView.setupSession(position: cameraPosition)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(position: cameraPosition)
    }
    
    public class Coordinator {
        var lastPosition: AVCaptureDevice.Position
        init(position: AVCaptureDevice.Position) {
            self.lastPosition = position
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
    
    // 激光扫描线动画
    @State private var scanOffset: CGFloat = -180
    @State private var selectedShaIndex: Int = 0
    @State private var targetOffset: CGSize = .zero
    @State private var showRemedySheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var hasCameraPermission: Bool = false
    @State private var showSnapshotToast: Bool = false
    @State private var cameraPosition: AVCaptureDevice.Position = .back
    
    private let shaList = ExteriorShaEngine.shared.database
    
    public init() {}
    
    // 计算靶心拖拽后的相对目标偏角与二十四山
    private var targetCalculatedHeading: Double {
        let angleDelta = Double(targetOffset.width / 8.0)
        let raw = motion.headingState.facingAngle + angleDelta
        return (raw.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
    
    private var targetMountain: Mountain24 {
        return Mountain24Data.shared.mountain(for: targetCalculatedHeading)
    }
    
    public var body: some View {
        ZStack {
            // 1. 真机摄像头实时预览 / 模拟器仿真画板
            if hasCameraPermission {
                CameraPreviewView(cameraPosition: cameraPosition)
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
            ShaRemedyDetailSheet(sha: shaList[selectedShaIndex])
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
                Text("室内 / 模拟实景演练模式")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Text("拖动金黄色锁定框可模拟测煞")
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
        let currentSha = shaList[selectedShaIndex]
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
                    Text("AI 测煞靶心 · \(m.name)山")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow)
                }
                Text(currentSha.name)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                Text("靶向方位: \(String(format: "%.1f", targetCalculatedHeading))° (\(m.palace))")
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
                Text("物理向首: \(motion.headingState.facingMountain.name)山 (\(String(format: "%.1f", motion.headingState.facingAngle))°)")
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
    
    // MARK: - 底部形煞研判卡
    private func bottomShaControlPanel() -> some View {
        let sha = shaList[selectedShaIndex]
        
        return VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<shaList.count, id: \.self) { idx in
                        let item = shaList[idx]
                        Button(action: {
                            selectedShaIndex = idx
                        }) {
                            Text(item.name)
                                .font(.system(size: 11, weight: idx == selectedShaIndex ? .bold : .medium))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(idx == selectedShaIndex ? Color.yanCyan.opacity(0.85) : Color.white.opacity(0.15))
                                .foregroundColor(idx == selectedShaIndex ? .black : .white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("【\(sha.name)】形煞研判:")
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
        
        let currentSha = shaList[selectedShaIndex]
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
            "演象时空罗盘 · AR实地勘测全案存证".draw(at: CGPoint(x: 70, y: size.height - 350), withAttributes: titleAttr)
            
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.white
            ]
            
            let infoText = """
            向首方位: \(mFacing.name)山向首 (实测 \(String(format: "%.1f", currentHeading))°) · \(mFacing.palace)
            识别形煞: 【\(currentSha.name)】(\(currentSha.aliases)) · \(currentSha.severity.rawValue)
            现场经纬: \(coordsStr)
            勘察时间: \(Date().description) · 防伪鉴真: YX-AR-\(Int(Date().timeIntervalSince1970))
            """
            infoText.draw(in: CGRect(x: 70, y: size.height - 290, width: size.width - 260, height: 210), withAttributes: bodyAttr)
            
            // 朱砂印鉴
            let sealRect = CGRect(x: size.width - 190, y: size.height - 230, width: 120, height: 120)
            cg.setStrokeColor(UIColor(red: 178/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0).cgColor)
            cg.setLineWidth(3)
            cg.stroke(sealRect)
            "演象\n鉴真".draw(in: sealRect.insetBy(dx: 18, dy: 18), withAttributes: [
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
                        Text("📐 现场环境辨识特征")
                            .font(.system(size: 15, weight: .bold))
                        Text(sha.visualFeature)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📜 经典古籍赋文")
                            .font(.system(size: 15, weight: .bold))
                        Text(sha.classicalText)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.yanBrown)
                            .padding(10)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("🛡️ 开光法器与空间调理化解锦囊")
                            .font(.system(size: 15, weight: .bold))
                        
                        if !iap.hasUnlockedVIP {
                            VIPLockCardView(
                                title: "杨公化煞绝学锦囊 · VIP 专享",
                                featureDesc: "形峦煞气本物相克生克制化真传、开光法器安放禁忌、鲁班真尺定寸与镇煞秘方，需解锁 VIP 尊享特权。",
                                badge: "👑 VIP 绝学特权",
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
            .navigationBarTitle("形煞诊断报告", displayMode: .inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showPaywall) {
                VIPPaywallSheet(defaultProductId: .vipYearly)
            }
        }
    }
}
