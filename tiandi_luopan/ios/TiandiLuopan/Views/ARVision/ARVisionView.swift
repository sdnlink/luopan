import SwiftUI
import AVFoundation

// MARK: - 原生高清相机预览层 (AVCaptureSession Representable)

public struct CameraPreviewView: UIViewRepresentable {
    public class CameraUIView: UIView {
        private var captureSession: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?
        
        override public func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
        
        public func setupSession() {
            guard captureSession == nil else { return }
            
            let session = AVCaptureSession()
            session.sessionPreset = .high
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
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
                self?.captureSession?.stopRunning()
            }
        }
    }
    
    public func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        view.backgroundColor = .black
        view.setupSession()
        return view
    }
    
    public func updateUIView(_ uiView: CameraUIView, context: Context) {}
}

// MARK: - AR 实景天心透视与形煞智能标注视图 (AR Vision View)

public struct ARVisionView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    
    // 激光扫描线动画
    @State private var scanOffset: CGFloat = -180
    @State private var selectedShaIndex: Int = 0
    @State private var targetOffset: CGSize = .zero
    @State private var showRemedySheet: Bool = false
    @State private var hasCameraPermission: Bool = false
    
    private let shaList = ExteriorShaEngine.shared.database
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // 1. 真机摄像头实时预览
            CameraPreviewView()
                .ignoresSafeArea()
            
            // 若在模拟器或无相机权限时提供优雅深色网格底
            if !hasCameraPermission {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
            }
            
            // 2. 激光天心扫描光束 (动态往返扫掠)
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.cyan.opacity(0.6), Color.cyan, Color.clear],
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
            
            // 4. 可拖拽目标物实景锁定框
            targetBoundingBoxLayer()
            
            // 5. 顶部实时坐向与相机信息悬浮栏
            VStack {
                topStatusBar()
                Spacer()
                // 6. 底部形煞智能研判卡与切换条
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
    
    // MARK: - 十字天心准星
    private func crosshairCenterLayer() -> some View {
        ZStack {
            // 外圈绿/金刻度准星
            Circle()
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1.5)
                .frame(width: 140, height: 140)
            
            Circle()
                .stroke(Color.cyan.opacity(0.8), lineWidth: 1)
                .frame(width: 40, height: 40)
            
            // 十字线
            Rectangle()
                .fill(Color.cyan.opacity(0.6))
                .frame(width: 1, height: 180)
            Rectangle()
                .fill(Color.cyan.opacity(0.6))
                .frame(width: 180, height: 1)
            
            // 方位角角标
            Text("\(String(format: "%.1f", motion.headingState.facingAngle))°")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
                .offset(y: -50)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - 可拖拽形煞目标锁定框
    private func targetBoundingBoxLayer() -> some View {
        let currentSha = shaList[selectedShaIndex]
        
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 160, height: 110)
                .background(Color.yellow.opacity(0.12))
            
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    Text("AI 形煞锁定")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow)
                }
                Text(currentSha.name)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(.white)
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
    
    // MARK: - 顶栏信息
    private func topStatusBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AR 实景天心透视")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text("物理坐向: \(motion.headingState.sittingMountain.name)山\(motion.headingState.facingMountain.name)向")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            
            Button(action: {
                showRemedySheet = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "shield.lefthalf.fill")
                    Text("大师化解锦囊")
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(red: 0.83, green: 0.68, blue: 0.21))
                .foregroundColor(.black)
                .cornerRadius(16)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
    }
    
    // MARK: - 底部形煞研判卡
    private func bottomShaControlPanel() -> some View {
        let sha = shaList[selectedShaIndex]
        
        return VStack(spacing: 8) {
            // 形煞快速轮播切换
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<shaList.count, id: \.self) { idx in
                        let item = shaList[idx]
                        Button(action: {
                            selectedShaIndex = idx
                        }) {
                            Text(item.name)
                                .font(.system(size: 12, weight: idx == selectedShaIndex ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(idx == selectedShaIndex ? Color.cyan.opacity(0.8) : Color.white.opacity(0.15))
                                .foregroundColor(idx == selectedShaIndex ? .black : .white)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // 当前形煞危害与古籍赋文
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("【\(sha.name)】危害原理:")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Spacer()
                    Text(sha.severity.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(sha.severity == .critical ? Color.red : Color.orange)
                }
                Text(sha.metaphysicsHarm)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            .padding(10)
            .background(Color.black.opacity(0.75))
            .cornerRadius(8)
        }
    }
}

// MARK: - 形煞深度剖析与化解弹窗
public struct ShaRemedyDetailSheet: View {
    public let sha: ExteriorShaItem
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 标题与严重度
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
                    
                    // 视觉特征
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📐 现场环境辨识特征")
                            .font(.system(size: 15, weight: .bold))
                        Text(sha.visualFeature)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                    }
                    
                    // 堪舆古籍渊源
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📜 经典古籍赋文")
                            .font(.system(size: 15, weight: .bold))
                        Text(sha.classicalText)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(.brown)
                            .padding(10)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // 大师专业化解方案
                    VStack(alignment: .leading, spacing: 6) {
                        Text("🛡️ 开光法器与空间调理化解锦囊")
                            .font(.system(size: 15, weight: .bold))
                        Text(sha.remedySolution)
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationBarTitle("形煞诊断报告", displayMode: .inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
