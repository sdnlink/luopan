import SwiftUI
import AVFoundation
import ARKit
import UIKit
import Photos

// MARK: - 原生高清相机预览层控制器与视图 (AVCaptureSession Representable)

public final class CameraPreviewController: ObservableObject {
    fileprivate weak var activeView: CameraPreviewView.CameraUIView?
    
    public init() {}
    
    public func stopSession(completion: (() -> Void)? = nil) {
        if let view = activeView {
            view.stopSession(completion: completion)
        } else {
            completion?()
        }
    }
    
    public func pauseSessionForBackground() {
        activeView?.pauseSessionForBackground()
    }
}

public struct CameraPreviewView: UIViewRepresentable {
    public var controller: CameraPreviewController?
    public var cameraPosition: AVCaptureDevice.Position
    public var isActive: Bool
    public var captureTrigger: Int
    public var onPhotoCaptured: ((UIImage?) -> Void)?
    
    public init(
        controller: CameraPreviewController? = nil,
        cameraPosition: AVCaptureDevice.Position = .back,
        isActive: Bool = true,
        captureTrigger: Int = 0,
        onPhotoCaptured: ((UIImage?) -> Void)? = nil
    ) {
        self.controller = controller
        self.cameraPosition = cameraPosition
        self.isActive = isActive
        self.captureTrigger = captureTrigger
        self.onPhotoCaptured = onPhotoCaptured
    }
    
    public class CameraUIView: UIView, AVCapturePhotoCaptureDelegate {
        private var captureSession: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var photoCaptureOutput: AVCapturePhotoOutput?
        private var photoCompletion: ((UIImage?) -> Void)?
        private var currentPosition: AVCaptureDevice.Position = .back
        private var isCapturingPhoto = false
        private var sessionObservers: [NSObjectProtocol] = []
        private let sessionQueue = DispatchQueue(label: "com.yanxiang.compass.camera-session")
        private var wantsRunning = true

        deinit {
            sessionObservers.forEach { NotificationCenter.default.removeObserver($0) }
            sessionObservers.removeAll()
            if let session = captureSession {
                sessionQueue.async {
                    if session.isRunning {
                        session.stopRunning()
                    }
                }
            }
        }
        
        override public func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                stopSession()
            }
        }
        
        override public func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
        
        public func setupSession(position: AVCaptureDevice.Position) {
            currentPosition = position
            wantsRunning = true

            // Reconfiguring the lens cancels any pending still capture.  Make
            // the cancellation observable so an AI scan or snapshot request
            // can leave its loading state instead of waiting forever.
            cancelPendingCapture()
            
            if let sessionToStop = captureSession {
                captureSession = nil
                previewLayer?.removeFromSuperlayer()
                previewLayer = nil
                sessionQueue.async {
                    if sessionToStop.isRunning { sessionToStop.stopRunning() }
                    for input in sessionToStop.inputs { sessionToStop.removeInput(input) }
                    for output in sessionToStop.outputs { sessionToStop.removeOutput(output) }
                }
            }
            photoCaptureOutput = nil
            photoCompletion = nil
            
            let session = AVCaptureSession()
            // The AR page continuously streams frames for preview and the
            // rectangle detector.  720p is sufficient for the on-device
            // geometry analysis and the proof overlay, while materially
            // reducing camera bandwidth, GPU work and device heat. Keep a
            // high-quality fallback for older devices that cannot use it.
            if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
            } else {
                session.sessionPreset = .high
            }
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  session.canAddInput(input) else {
                return
            }

            // The AR overlay and rectangle scan do not require 30/60 fps.
            // Capping a supported format at 24 fps reduces continuous sensor
            // and ISP work while keeping the preview responsive enough for
            // handheld surveying.
            if let frameRateRange = camera.activeFormat.videoSupportedFrameRateRanges.first(where: {
                $0.minFrameRate <= 24.0 && $0.maxFrameRate >= 24.0
            }), frameRateRange.maxFrameRate >= 24.0,
               (try? camera.lockForConfiguration()) != nil {
                let frameDuration = CMTime(value: 1, timescale: 24)
                camera.activeVideoMinFrameDuration = frameDuration
                camera.activeVideoMaxFrameDuration = frameDuration
                camera.unlockForConfiguration()
            }
            
            session.addInput(input)

            let photoOutput = AVCapturePhotoOutput()
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                if #available(iOS 13.0, *) {
                    // AI rectangle detection and the 1080px proof renderer
                    // do not need maximum computational photography quality.
                    // Prefer a faster capture to reduce shutter latency and
                    // the short-lived CPU/ISP power spike.
                    photoOutput.maxPhotoQualityPrioritization = .speed
                }
                self.photoCaptureOutput = photoOutput
            } else {
                self.photoCaptureOutput = nil
            }
            
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = bounds
            layer.addSublayer(preview)
            
            self.captureSession = session
            self.previewLayer = preview

            // A phone call, Control Center camera, or another app can interrupt
            // capture without destroying the preview view. Resume the same
            // session when the interruption ends and rebuild after media-service
            // resets so the AR tab does not remain on a black frame.
            sessionObservers.forEach { NotificationCenter.default.removeObserver($0) }
            sessionObservers.removeAll()
            let center = NotificationCenter.default
            sessionObservers.append(center.addObserver(
                forName: .AVCaptureSessionWasInterrupted,
                object: session,
                queue: .main
            ) { [weak self] _ in
                // A still capture cannot be completed reliably while another
                // app owns the camera. Complete it as cancelled so the AR
                // page does not remain stuck in a loading state.
                self?.cancelPendingCapture()
            })
            sessionObservers.append(center.addObserver(
                forName: .AVCaptureSessionInterruptionEnded,
                object: session,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                guard self.wantsRunning else { return }
                self.sessionQueue.async {
                    guard let current = self.captureSession, current === session,
                          !current.isRunning else { return }
                    current.startRunning()
                }
            })
            sessionObservers.append(center.addObserver(
                forName: .AVCaptureSessionRuntimeError,
                object: session,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                self.cancelPendingCapture()
                let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
                if error != nil, self.wantsRunning {
                    self.sessionQueue.async {
                        guard let current = self.captureSession, current === session else { return }
                        if !current.isRunning { current.startRunning() }
                    }
                }
            })
            sessionObservers.append(center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.pauseSessionForBackground()
            })
            sessionObservers.append(center.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self = self else { return }
                guard self.wantsRunning else { return }
                self.sessionQueue.async {
                    guard let current = self.captureSession, current === session,
                          !current.isRunning else { return }
                    current.startRunning()
                }
            })
            
            sessionQueue.async {
                session.startRunning()
            }
        }

        public func capturePhoto(completion: @escaping (UIImage?) -> Void) {
            guard let photoOutput = photoCaptureOutput, captureSession?.isRunning == true else {
                completion(nil)
                return
            }

            // Always complete a rejected request.  An AI scan sets its
            // pending flag before requesting a frame; dropping the callback
            // while another exposure is in flight would leave the UI stuck in
            // the scanning state forever.
            guard !isCapturingPhoto else {
                completion(nil)
                return
            }

            isCapturingPhoto = true
            photoCompletion = completion
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            if #available(iOS 13.0, *) {
                settings.photoQualityPrioritization = .speed
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        public func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            let image: UIImage?
            if error == nil, let data = photo.fileDataRepresentation() {
                image = UIImage(data: data)
            } else {
                image = nil
            }

            // AVCapturePhotoCaptureDelegate may callback on an internal queue,
            // while cancellation and a new request are driven by SwiftUI on
            // the main thread. Serialize completion ownership on main so a
            // lens switch/interruption cannot deliver the same request twice.
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let completion = self.photoCompletion
                self.photoCompletion = nil
                self.isCapturingPhoto = false
                completion?(image)
            }
        }
        
        public func resumeSessionIfNeeded(position: AVCaptureDevice.Position) {
            wantsRunning = true
            // A running session cannot change cameras by itself. Rebuild it when
            // the user switches between the front and rear lens.
            if currentPosition != position {
                setupSession(position: position)
                return
            }
            if let session = captureSession, session.isRunning {
                return
            }
            setupSession(position: position)
        }
        
        public func stopSession(completion: (() -> Void)? = nil) {
            wantsRunning = false
            cancelPendingCapture()
            sessionObservers.forEach { NotificationCenter.default.removeObserver($0) }
            sessionObservers.removeAll()
            guard let sessionToStop = captureSession else {
                completion?()
                return
            }
            captureSession = nil
            previewLayer?.removeFromSuperlayer()
            previewLayer = nil
            photoCaptureOutput = nil
            sessionQueue.async {
                if sessionToStop.isRunning {
                    sessionToStop.stopRunning()
                }
                for input in sessionToStop.inputs {
                    sessionToStop.removeInput(input)
                }
                for output in sessionToStop.outputs {
                    sessionToStop.removeOutput(output)
                }
                if let completion = completion {
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            }
        }

        public func pauseSessionForBackground() {
            cancelPendingCapture()
            guard let sessionToPause = captureSession else { return }
            sessionQueue.async { [weak self] in
                if let self = self, self.captureSession !== sessionToPause {
                    return
                }
                if sessionToPause.isRunning {
                    sessionToPause.stopRunning()
                }
            }
        }

        private func cancelPendingCapture() {
            let pendingCompletion = photoCompletion
            photoCompletion = nil
            isCapturingPhoto = false
            guard let pendingCompletion = pendingCompletion else { return }
            DispatchQueue.main.async {
                pendingCompletion(nil)
            }
        }
    }
    
    public func makeUIView(context: Context) -> CameraUIView {
        let view = CameraUIView()
        view.backgroundColor = .black
        controller?.activeView = view
        if isActive {
            view.setupSession(position: cameraPosition)
        }
        return view
    }
    
    public func updateUIView(_ uiView: CameraUIView, context: Context) {
        controller?.activeView = uiView
        if !isActive {
            context.coordinator.lastActive = false
            uiView.stopSession()
            return
        }
        
        // 当镜头切换时或重新激活时配置
        if context.coordinator.lastPosition != cameraPosition || context.coordinator.lastActive != isActive {
            context.coordinator.lastPosition = cameraPosition
            context.coordinator.lastActive = isActive
            uiView.resumeSessionIfNeeded(position: cameraPosition)
        }

        if context.coordinator.lastCaptureTrigger != captureTrigger {
            context.coordinator.lastCaptureTrigger = captureTrigger
            uiView.capturePhoto { image in
                onPhotoCaptured?(image)
            }
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(position: cameraPosition, active: isActive, captureTrigger: captureTrigger)
    }
    
    public class Coordinator {
        var lastPosition: AVCaptureDevice.Position
        var lastActive: Bool
        var lastCaptureTrigger: Int

        init(position: AVCaptureDevice.Position, active: Bool, captureTrigger: Int) {
            self.lastPosition = position
            self.lastActive = active
            self.lastCaptureTrigger = captureTrigger
        }
    }
    
    public static func dismantleUIView(_ uiView: CameraUIView, coordinator: Coordinator) {
        uiView.stopSession()
    }
}

// MARK: - AR 实景天心透视与形煞智能标注视图 (AR Vision View)

public struct ARVisionView: View {
    private enum CapturePurpose {
        case aiScan(Int, Int)
        case snapshot
    }

    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @StateObject private var fusionModel = ARSpatialSurveyModel()
    @StateObject private var cameraModel = CameraPreviewController()
    
    public var isActive: Bool = true
    
    // 激光扫描线动画
    @State private var scanOffset: CGFloat = -180
    @State private var selectedShaIndex: Int = 0
    @State private var isAutoFollowingDirection: Bool = true // 实景朝向智能跟随
    @State private var targetOffset: CGSize = .zero
    @State private var manualTargetNormalizedOffset: Double = 0.0
    @State private var targetNormalizedPoint = CGPoint(x: 0.5, y: 0.5)
    @State private var targetHorizontalFOV: Double = 50.0
    @State private var targetDragStart: CGSize?
    @State private var showRemedySheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var hasCameraPermission: Bool = false
    @State private var showSnapshotToast: Bool = false
    @State private var cameraPosition: AVCaptureDevice.Position = .back
    @State private var isSwitchingCamera: Bool = false
    @State private var captureTrigger: Int = 0
    @State private var isAIScanning: Bool = false
    @State private var pendingCapturePurpose: CapturePurpose?
    @State private var aiResult: ShaAnalysisResult?
    @State private var aiError: String?
    @State private var aiScanGeneration: Int = 0
    @State private var aiScanFrames: [ARCapturedFrame] = []
    @State private var photoPermissionDenied: Bool = false
    @State private var showSpatialSurvey: Bool = false
    @State private var latestSnapshotImage: UIImage?
    @State private var showSnapshotShareSheet: Bool = false
    // Invalidated when the AR page disappears or a newer proof capture starts.
    // Rendering a 1080x1920 proof image is asynchronous; without a generation
    // check a frame captured just before leaving the tab could still be saved
    // to Photos after the user had already moved on.
    @State private var snapshotGeneration: Int = 0
    
    private let shaList = ExteriorShaEngine.shared.database
    
    public init(isActive: Bool = true) {
        self.isActive = isActive
    }
    
    // 计算靶心拖拽后的相对目标偏角与二十四山
    private var targetCalculatedHeading: Double {
        // Vision returns a normalized horizontal location. Keep that
        // location in the bearing calculation even before the overlay knows
        // its concrete pixel size; a manual drag adds a screen-space delta.
        let normalizedHorizontalOffset = (targetNormalizedPoint.x + manualTargetNormalizedOffset - 0.5) * 2.0
        let halfFOVRadians = targetHorizontalFOV * .pi / 360.0
        let detectedAngleDelta = atan(normalizedHorizontalOffset * tan(halfFOVRadians)) * 180.0 / .pi
        let raw = motion.headingState.facingAngle + detectedAngleDelta
        return (raw.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
    
    private var targetMountain: Mountain24 {
        return Mountain24Data.shared.mountain(for: targetCalculatedHeading)
    }

    private var targetSanHeWater: SanHeWaterItem? {
        let sitting = motion.headingState.sittingMountain
        let mTarget = targetMountain
        let waterItems = SanHeWaterEngine.shared.resolveWaterMethod(sitting: sitting, facing: mTarget)
        return waterItems.first(where: { $0.mountainName == mTarget.name })
    }

    private var isTargetHitBaSha: Bool {
        let baSha = SanHeWaterEngine.shared.resolveBaSha(sitting: motion.headingState.sittingMountain)
        return targetMountain.name == baSha.shaZhi
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
            if isActive {
            // 1. 真机摄像头实时预览 / ARKit+LiDAR融合流 / 模拟器仿真画板 (仅在 AR Tab 激活时工作，后台休眠避免发烫)
            if hasCameraPermission && isActive && !showSpatialSurvey {
                if cameraPosition == .back && ARWorldTrackingConfiguration.isSupported {
                    ARFusionCaptureView(
                        model: fusionModel,
                        isActive: isActive && !showSpatialSurvey,
                        captureTrigger: captureTrigger,
                        onFrameCaptured: { frame in
                            handleCapturedFrame(frame)
                        }
                    )
                    .id("ar_fusion_back")
                    .ignoresSafeArea()
                } else {
                    CameraPreviewView(
                        controller: cameraModel,
                        cameraPosition: cameraPosition,
                        isActive: isActive && !showSpatialSurvey,
                        captureTrigger: captureTrigger,
                        onPhotoCaptured: { image in
                            handleCapturedFrame(image.map { ARCapturedFrame(image: $0) })
                        }
                    )
                    .id("camera_preview_\(cameraPosition.rawValue)")
                    .ignoresSafeArea()
                }
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
            VStack(spacing: 6) {
                topStatusBar()
                horizonCompassRibbon()
                
                Spacer()
                
                // 截图存证保存提示 + 一键分享
                if showSnapshotToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(lang.t("save_success"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        if latestSnapshotImage != nil {
                            Button(action: {
                                showSnapshotShareSheet = true
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text(lang.t("share_and_print"))
                                }
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.yanCyan)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                        }
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
        }
        .onAppear {
            guard isActive else { return }
            checkCameraPermission()
            startScanAnimation()
        }
        .onChange(of: isActive) { active in
            if active {
                checkCameraPermission()
                startScanAnimation()
            } else {
                stopScanAnimation()
                cameraModel.stopSession()
                fusionModel.pause()
                showSpatialSurvey = false
                pendingCapturePurpose = nil
                isAIScanning = false
                aiScanGeneration &+= 1
                aiScanFrames.removeAll(keepingCapacity: true)
                aiResult = nil
                targetNormalizedPoint = CGPoint(x: 0.5, y: 0.5)
                targetHorizontalFOV = 50.0
                targetOffset = .zero
                manualTargetNormalizedOffset = 0.0
                targetDragStart = nil
                snapshotGeneration += 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if isActive { checkCameraPermission() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            cameraModel.pauseSessionForBackground()
            fusionModel.pause()
            guard isActive else { return }
            pendingCapturePurpose = nil
            isAIScanning = false
            aiScanGeneration &+= 1
            aiScanFrames.removeAll(keepingCapacity: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard isActive, !showSpatialSurvey else { return }
            checkCameraPermission()
        }
        .sheet(isPresented: $showRemedySheet) {
            ShaRemedyDetailSheet(sha: shaList[activeShaIndex])
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
        .sheet(isPresented: $showSnapshotShareSheet) {
            if let snapshot = latestSnapshotImage {
                ARProofShareSheet(items: [snapshot])
            }
        }
        .fullScreenCover(isPresented: $showSpatialSurvey) {
            ARSpatialSurveyView()
        }
        .onDisappear {
            cameraModel.stopSession()
            fusionModel.pause()
            showSpatialSurvey = false
            snapshotGeneration += 1
            pendingCapturePurpose = nil
            isAIScanning = false
            aiScanGeneration &+= 1
            aiScanFrames.removeAll(keepingCapacity: true)
            aiResult = nil
            targetNormalizedPoint = CGPoint(x: 0.5, y: 0.5)
            targetHorizontalFOV = 50.0
            targetOffset = .zero
            manualTargetNormalizedOffset = 0.0
            targetDragStart = nil
            isSwitchingCamera = false
        }
    }

    private func startScanAnimation() {
        guard isActive else { return }
        // Reset before starting a new cycle so returning to the AR tab always
        // begins at the same edge and does not retain an off-screen animation.
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            scanOffset = -180
        }
        withAnimation(Animation.linear(duration: 2.5).repeatForever(autoreverses: true)) {
            scanOffset = 180
        }
    }

    private func stopScanAnimation() {
        // A non-animated state write cancels the repeatForever transaction and
        // prevents an inactive TabView child from driving display-link redraws.
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            scanOffset = -180
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) != nil
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.hasCameraPermission = granted && AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.cameraPosition) != nil
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
                let cameraDenied = AVCaptureDevice.authorizationStatus(for: .video) == .denied ||
                    AVCaptureDevice.authorizationStatus(for: .video) == .restricted
                Text(cameraDenied ? lang.t("camera_permission_denied") : lang.t("simulation_mode"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                if cameraDenied {
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        Text(lang.t("open_system_settings"))
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.yanCyan.opacity(0.25))
                            .foregroundColor(.yanCyan)
                            .cornerRadius(8)
                    }
                } else {
                    Text(lang.t("ar_drag_hint"))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }

    }
    
    // MARK: - 十字天心准星 (含双轴微型电子水准珠与仰俯倾角指示)
    private func crosshairCenterLayer() -> some View {
        let rollDeg = fusionModel.cameraRollDegrees
        let elevDeg = fusionModel.cameraElevationDegrees
        let isHorizontalLevel = abs(rollDeg) <= 3.0
        let bubbleOffsetX = CGFloat(min(max(rollDeg * 1.2, -16.0), 16.0))
        let bubbleOffsetY = CGFloat(min(max(-elevDeg * 0.4, -12.0), 12.0))

        return ZStack {
            Circle()
                .stroke(Color.yanCyan.opacity(0.5), lineWidth: 1.5)
                .frame(width: 140, height: 140)
            
            Circle()
                .stroke(isHorizontalLevel ? Color.green.opacity(0.85) : Color.orange.opacity(0.85), lineWidth: 1.2)
                .frame(width: 40, height: 40)

            // 电子水准珠 (倾斜 ≤ 3° 为绿，超过 3° 变橙提醒端平)
            Circle()
                .fill(isHorizontalLevel ? Color.green.opacity(0.75) : Color.orange.opacity(0.85))
                .frame(width: 9, height: 9)
                .offset(x: bubbleOffsetX, y: bubbleOffsetY)
            
            // 十字准星
            Rectangle()
                .fill(Color.yanCyan.opacity(0.6))
                .frame(width: 1, height: 180)
            Rectangle()
                .fill(Color.yanCyan.opacity(0.6))
                .frame(width: 180, height: 1)
            
            Text("\(String(format: "%.1f", motion.headingState.facingAngle))° · \(String(format: "%+.1f°", elevDeg))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isHorizontalLevel ? .yanCyan : .orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: true, vertical: false)
                .offset(y: -50)

            if cameraPosition == .back, let dist = fusionModel.distance {
                Text("\(fusionModel.lidarAvailable ? "LiDAR" : "AR") · \(String(format: "%.2f m", dist))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(fusionModel.lidarAvailable ? .green : .yanCyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(6)
                    .offset(y: 52)
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - 可拖拽形煞目标锁定框 (动态解算偏角、二十四山与目标点 LiDAR 距离)
    private func targetBoundingBoxLayer() -> some View {
        let currentSha = shaList[activeShaIndex]
        let m = targetMountain
        
        return GeometryReader { proxy in
            let detectedOffset = CGSize(
                width: (targetNormalizedPoint.x - 0.5) * proxy.size.width,
                height: (targetNormalizedPoint.y - 0.5) * proxy.size.height
            )
            let rawOffset = CGSize(
                width: detectedOffset.width + targetOffset.width,
                height: detectedOffset.height + targetOffset.height
            )
            // Keep the target card inside the camera viewport on every
            // iPhone/iPad aspect ratio, including split-screen layouts.
            let maxX = max(0, proxy.size.width / 2 - 92)
            let maxY = max(0, proxy.size.height / 2 - 62)
            let clampedOffset = CGSize(
                width: min(max(rawOffset.width, -maxX), maxX),
                height: min(max(rawOffset.height, -maxY), maxY)
            )
            let normPoint = CGPoint(
                x: min(max(0.5 + clampedOffset.width / max(proxy.size.width, 1), 0.02), 0.98),
                y: min(max(0.5 + clampedOffset.height / max(proxy.size.height, 1), 0.02), 0.98)
            )
            let targetDist = (cameraPosition == .back) ? fusionModel.sampleDepth(atPortraitNormalizedPoint: normPoint) : nil

            let waterItem = targetSanHeWater
            let hitBaSha = isTargetHitBaSha

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke((hitBaSha || waterItem?.isHuangQuanSha == true) ? Color.red : Color.yellow, lineWidth: 2)
                    .frame(width: 192, height: 132)
                    .background(Color.yellow.opacity(0.12))

                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                        Text("\(lang.t("ar_target_center")) · \(m.localizedName)\(lang.t("mountain_suffix"))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    Text(currentSha.localizedName)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                    Text("\(lang.t("ar_target_bearing")): \(String(format: "%.1f", targetCalculatedHeading))° (\(m.localizedPalace))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let water = waterItem {
                        let statusTag = hitBaSha
                            ? "⚠️ 犯坐山八煞"
                            : (water.isHuangQuanSha ? "⚠️ 犯八路黄泉" : "水法: \(water.stage)")
                        Text(statusTag)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor((hitBaSha || water.isHuangQuanSha) ? .red : (water.isAuspicious ? .green : .yanCyan))
                            .lineLimit(1)
                    }
                    if let d = targetDist {
                        Text("\(fusionModel.lidarAvailable ? "LiDAR" : "AR") \(String(format: "%.2f m", d))")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    Text(currentSha.localizedAliases)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .position(
                x: proxy.size.width / 2 + clampedOffset.width,
                y: proxy.size.height / 2 + clampedOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if targetDragStart == nil {
                            targetDragStart = targetOffset
                        }
                        let start = targetDragStart ?? .zero
                        let proposed = CGSize(width: start.width + gesture.translation.width,
                                              height: start.height + gesture.translation.height)
                        let maxX = max(0, proxy.size.width / 2 - 92)
                        let maxY = max(0, proxy.size.height / 2 - 62)
                        let clamped = CGSize(
                            width: min(max(proposed.width, -maxX), maxX),
                            height: min(max(proposed.height, -maxY), maxY)
                        )
                        targetOffset = clamped
                        manualTargetNormalizedOffset = Double(
                            clamped.width / max(proxy.size.width, 1)
                        )
                    }
                    .onEnded { _ in
                        targetDragStart = nil
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 顶栏信息与镜头翻转控制
    private func topStatusBar() -> some View {
        VStack(spacing: 8) {
            // 第一行：标题与朝向信息 + 常驻镜头翻转
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t("ar_title"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text("\(lang.t("ar_physical_facing")): \(motion.headingState.facingMountain.localizedName)\(lang.t("mountain_suffix")) (\(String(format: "%.1f", motion.headingState.facingAngle))°)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .layoutPriority(1)
                }
                Spacer()
                // 翻转镜头按钮
                Button(action: {
                    guard !isSwitchingCamera else { return }
                    let nextPosition: AVCaptureDevice.Position = (cameraPosition == .back) ? .front : .back
                    guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: nextPosition) != nil else {
                        aiError = lang.t("ar_ai_camera_required")
                        return
                    }
                    let isCurrentAR = (cameraPosition == .back && ARWorldTrackingConfiguration.isSupported)
                    if isCurrentAR {
                        fusionModel.pause()
                        cameraPosition = nextPosition
                    } else {
                        isSwitchingCamera = true
                        var hasSwitched = false
                        let performSwitch = {
                            guard !hasSwitched else { return }
                            hasSwitched = true
                            cameraPosition = nextPosition
                            isSwitchingCamera = false
                        }
                        // Safety timeout: Ensure UI never stays locked if camera hardware takes long
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            performSwitch()
                        }
                        cameraModel.stopSession {
                            performSwitch()
                        }
                    }
                }) {
                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 13))
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .disabled(isAIScanning || pendingCapturePurpose != nil || isSwitchingCamera)
            }

            // 第二行：功能按钮组（小屏横向滚动兜底，避免挤压标题换行竖排）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: runAIScan) {
                        HStack(spacing: 4) {
                            Image(systemName: isAIScanning ? "hourglass" : "sparkles")
                            Text(isAIScanning ? lang.t("ar_ai_scanning") : lang.t("ar_ai_scan"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.yanCyan.opacity(0.85))
                        .foregroundColor(.black)
                        .cornerRadius(14)
                    }
                    .disabled(isAIScanning || pendingCapturePurpose != nil)

                    Button(action: {
                        guard hasCameraPermission else {
                            aiError = lang.t("ar_ai_camera_required")
                            return
                        }
                        showSpatialSurvey = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arkit")
                            Text(lang.t("ar_spatial_survey"))
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.82))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isAIScanning || pendingCapturePurpose != nil)

                    // 勘测存证快照拍照按钮
                    Button(action: {
                        if !iap.hasUnlockedVIP {
                            showPaywall = true
                        } else {
                            guard pendingCapturePurpose == nil else { return }
                            if hasCameraPermission && isActive {
                                pendingCapturePurpose = .snapshot
                                captureTrigger += 1
                            } else {
                                // A dark fallback image must never be presented as an
                                // on-site proof. Ask the user to restore camera access
                                // and only save a snapshot after a real frame arrives.
                                aiError = lang.t("ar_ai_camera_required")
                            }
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
                    .disabled(isAIScanning || pendingCapturePurpose != nil)

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
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.65))
        .cornerRadius(10)
    }

    // MARK: - 全景天际二十四山与杨公十二长生消砂纳水标尺 (PRD 5.2 & 13)
    private func horizonCompassRibbon() -> some View {
        let baseHeading = motion.headingState.facingAngle
        let sitting = motion.headingState.sittingMountain
        let waterItems = SanHeWaterEngine.shared.resolveWaterMethod(sitting: sitting, facing: motion.headingState.facingMountain)
        let baShaZhi = SanHeWaterEngine.shared.resolveBaSha(sitting: sitting).shaZhi
        let offsets: [Double] = [-30.0, -15.0, 0.0, 15.0, 30.0]

        // 煞位前缀按语言本地化：中文 煞·、日文 煞・、韩文 살·，
        // 其余语言用风水术语拼音音译 Sha ·（避免非中文环境显示中文硬编码）。
        let shaPrefix: String
        switch lang.effectiveLanguage {
        case .zhHant, .zhHans: shaPrefix = "煞·"
        case .ja: shaPrefix = "煞・"
        case .ko: shaPrefix = "살·"
        default: shaPrefix = "Sha · "
        }

        return HStack(spacing: 6) {
            ForEach(offsets, id: \.self) { delta in
                let angle = ((baseHeading + delta).truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
                let m = Mountain24Data.shared.mountain(for: angle)
                let water = waterItems.first(where: { $0.mountainName == m.name })
                let isCenter = abs(delta) < 0.1
                let isBaSha = (m.name == baShaZhi)
                let isHQ = (water?.isHuangQuanSha == true)

                VStack(spacing: 1) {
                    Text("\(m.localizedName)\(isCenter ? "▲" : "")")
                        .font(.system(size: isCenter ? 11 : 10, weight: .bold))
                        .foregroundColor(isCenter ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white)
                    if let water = water {
                        Text((isBaSha || isHQ) ? "\(shaPrefix)\(water.stage)" : water.stage)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor((isBaSha || isHQ) ? .red : (water.isAuspicious ? .green : .white.opacity(0.72)))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(isCenter ? Color.yanCyan.opacity(0.22) : Color.white.opacity(0.06))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCenter ? Color.yanCyan.opacity(0.75) : Color.clear, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.58))
        .cornerRadius(9)
        .allowsHitTesting(false)
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
                        Text(isAutoFollowingDirection ? lang.t("ar_auto_follow") : lang.t("ar_manual_lock"))
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isAutoFollowingDirection ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
                    .foregroundColor(isAutoFollowingDirection ? .green : .orange)
                    .cornerRadius(6)
                }
                
                Spacer()
                
                Text("\(lang.t("ar_current_facing")): \(targetMountain.localizedPalace) · \(targetMountain.localizedName)\(lang.t("mountain_suffix"))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
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
                            // Manual selection supersedes any prior AI
                            // candidate. Keeping the old candidate label here
                            // would associate the user's choice with a stale
                            // frame and could mislead the scene assessment.
                            aiResult = nil
                            aiError = nil
                            targetNormalizedPoint = CGPoint(x: 0.5, y: 0.5)
                            targetHorizontalFOV = 50.0
                            targetOffset = .zero
                            manualTargetNormalizedOffset = 0.0
                        }) {
                            Text(item.localizedName)
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
            
            if let aiResult = aiResult {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("\(lang.t("ar_ai_result")): \(String(format: "%.0f", aiResult.confidence * 100))% · \(aiResult.detectedRegions)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Spacer()
                }
                .padding(.horizontal, 8)
                Text(lang.t("ar_ai_disclaimer"))
                    .font(.system(size: 9))
                    .foregroundColor(.orange.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            } else if let aiError = aiError {
                VStack(alignment: .leading, spacing: 5) {
                    Text(aiError)
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    if photoPermissionDenied {
                        Button(lang.t("open_system_settings")) {
                            guard let url = URL(string: UIApplication.openSettingsURLString),
                                  UIApplication.shared.canOpenURL(url) else { return }
                            UIApplication.shared.open(url)
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.yanCyan)
                    }
                }
                .padding(.horizontal, 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("【\(sha.localizedName)】\(aiResult == nil ? lang.t("ar_manual_analysis") : lang.t("ar_ai_candidate")):")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Spacer()
                    Text(sha.severity.localizedTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(sha.severity == .critical ? Color.red : Color.orange)
                }
                Text(sha.localizedMetaphysicsHarm)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            .padding(8)
            .background(Color.black.opacity(0.75))
            .cornerRadius(8)
        }
    }

    private func runAIScan() {
        guard pendingCapturePurpose == nil, hasCameraPermission && isActive else {
            aiError = lang.t("ar_ai_camera_required")
            return
        }
        aiError = nil
        photoPermissionDenied = false
        aiResult = nil
        // Clear the previous candidate while the new frame is being checked;
        // a stale marker can otherwise look like a fresh detection.
        targetNormalizedPoint = CGPoint(x: 0.5, y: 0.5)
        targetHorizontalFOV = 50.0
        targetOffset = .zero
        manualTargetNormalizedOffset = 0.0
        aiScanFrames.removeAll(keepingCapacity: true)
        isAIScanning = true
        aiScanGeneration &+= 1
        pendingCapturePurpose = .aiScan(aiScanGeneration, 0)
        captureTrigger += 1
    }

    private func handleCapturedFrame(_ frame: ARCapturedFrame?) {
        switch pendingCapturePurpose {
        case .aiScan(let generation, let frameIndex):
            pendingCapturePurpose = nil
            collectAIScanFrame(frame, generation: generation, frameIndex: frameIndex)
        case .snapshot:
            pendingCapturePurpose = nil
            guard let frame = frame else {
                aiError = lang.t("ar_ai_no_frame")
                return
            }
            captureAndSaveSnapshot(baseImage: frame.image)
        case .none:
            // A capture can finish after the AR tab was dismissed or the
            // request was superseded. Do not turn that stale frame into an
            // unexpected save.
            return
        }
    }

    private func collectAIScanFrame(_ frame: ARCapturedFrame?, generation: Int, frameIndex: Int) {
        guard isActive, generation == aiScanGeneration else { return }
        guard let frame = frame else {
            isAIScanning = false
            aiScanFrames.removeAll(keepingCapacity: true)
            aiError = lang.t("ar_ai_no_frame")
            return
        }
        aiScanFrames.append(frame)
        let requiredFrames = 3
        if frameIndex + 1 < requiredFrames {
            // Give AVCapturePhotoOutput one run-loop turn between exposures so
            // the sensor can settle. Each frame must independently support the
            // same geometry before the UI receives an AI candidate.
            DispatchQueue.main.async {
                guard self.isActive, generation == self.aiScanGeneration else { return }
                self.pendingCapturePurpose = .aiScan(generation, frameIndex + 1)
                self.captureTrigger += 1
            }
            return
        }
        let frames = aiScanFrames
        aiScanFrames.removeAll(keepingCapacity: true)
        pendingCapturePurpose = nil
        analyzeFrames(frames, generation: generation)
    }

    private func analyzeFrames(_ images: [ARCapturedFrame], generation: Int) {
        guard !images.isEmpty else {
            isAIScanning = false
            aiError = lang.t("ar_ai_no_frame")
            return
        }
        // Vision work is intentionally serialized. Running three full image
        // requests at once creates a short CPU/memory spike on older phones
        // and can make the preview stutter or heat up.
        analyzeNextFrame(
            images,
            index: 0,
            generation: generation,
            results: [],
            failures: 0,
            firstFailure: nil
        )
    }

    private func analyzeNextFrame(
        _ images: [ARCapturedFrame],
        index: Int,
        generation: Int,
        results: [ShaAnalysisResult],
        failures: Int,
        firstFailure: OnDeviceShaAnalyzer.AnalysisError?
    ) {
        guard isActive, generation == aiScanGeneration, index < images.count else { return }
        let frame = images[index]
        OnDeviceShaAnalyzer.shared.analyze(image: frame.image, evidence: frame.evidence) { result in
            guard self.isActive, generation == self.aiScanGeneration else { return }
            var nextResults = results
            var nextFailures = failures
            var nextFailure = firstFailure
            switch result {
            case .success(let analysis):
                nextResults.append(analysis)
            case .failure(let error):
                nextFailures += 1
                if nextFailure == nil {
                    nextFailure = error as? OnDeviceShaAnalyzer.AnalysisError
                }
            }
            let nextIndex = index + 1
            if nextIndex < images.count {
                self.analyzeNextFrame(
                    images,
                    index: nextIndex,
                    generation: generation,
                    results: nextResults,
                    failures: nextFailures,
                    firstFailure: nextFailure
                )
            } else {
                self.finishAIScan(
                    results: nextResults,
                    failures: nextFailures,
                    generation: generation,
                    firstFailure: nextFailure
                )
            }
        }
    }

    private func finishAIScan(
        results: [ShaAnalysisResult],
        failures: Int,
        generation: Int,
        firstFailure: OnDeviceShaAnalyzer.AnalysisError?
    ) {
        guard generation == aiScanGeneration else { return }
        isAIScanning = false
        // Require every captured frame to produce the same candidate. A single
        // inconsistent frame is treated as environmental motion/occlusion,
        // never as confirmation.
        if let firstFailure = firstFailure {
            aiResult = nil
            targetNormalizedPoint = CGPoint(x: 0.5, y: 0.5)
            targetHorizontalFOV = 50.0
            targetOffset = .zero
            manualTargetNormalizedOffset = 0.0
            aiError = firstFailure.localizedDescription
            return
        }
        guard failures == 0, results.count == 3,
              let first = results.first,
              results.dropFirst().allSatisfy({ candidate in
                  candidate.shaID == first.shaID &&
                  hypot(candidate.targetX - first.targetX, candidate.targetY - first.targetY) <= 0.08 &&
                  abs(candidate.confidence - first.confidence) <= 0.12
              }) else {
            aiResult = nil
            targetNormalizedPoint = CGPoint(x: 0.5, y: 0.5)
            targetHorizontalFOV = 50.0
            targetOffset = .zero
            manualTargetNormalizedOffset = 0.0
            aiError = lang.t("ar_ai_temporal_ambiguous")
            return
        }
        let confidence = results.map { $0.confidence }.reduce(0, +) / Double(results.count)
        let targetX = results.map { $0.targetX }.reduce(0, +) / Double(results.count)
        let targetY = results.map { $0.targetY }.reduce(0, +) / Double(results.count)
        let candidate = ShaAnalysisResult(
            shaID: first.shaID,
            confidence: confidence,
            targetX: targetX,
            targetY: targetY,
            detectedRegions: results.map { $0.detectedRegions }.min() ?? first.detectedRegions,
            summary: "three-frame-temporal-consensus",
            horizontalFOVDegrees: results.compactMap { $0.horizontalFOVDegrees }.first
        )
        applyAIScanResult(candidate)
    }

    private func applyAIScanResult(_ analysis: ShaAnalysisResult) {
        aiResult = analysis
        if let index = shaList.firstIndex(where: { $0.id == analysis.shaID }) {
            selectedShaIndex = index
            isAutoFollowingDirection = false
            // Keep Vision's normalized location separate from the manual drag
            // offset. The overlay maps it to its actual container size, so the
            // marker stays anchored on every iPhone/iPad aspect ratio.
            targetNormalizedPoint = CGPoint(
                x: min(max(analysis.targetX, 0.0), 1.0),
                y: min(max(analysis.targetY, 0.0), 1.0)
            )
            if let fov = analysis.horizontalFOVDegrees,
               fov.isFinite, fov >= 20, fov <= 120 {
                targetHorizontalFOV = fov
            }
            targetOffset = .zero
            manualTargetNormalizedOffset = 0.0
        }
    }
    
    // MARK: - 绘制并保存带水印防伪印章的现场勘测存证快照
    private func captureAndSaveSnapshot(baseImage: UIImage) {
        snapshotGeneration += 1
        let generation = snapshotGeneration
        let size = CGSize(width: 1080, height: 1920)
        // Keep the proof image at its declared pixel dimensions instead of
        // inheriting a 2x/3x Retina scale and allocating a much larger bitmap.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        let currentSha = shaList[activeShaIndex]
        let currentHeading = motion.headingState.facingAngle
        let mFacing = motion.headingState.facingMountain
        let coordsStr = motion.coordsDesc
        let language = lang.effectiveLanguage
        let watermarkTitle = lang.t("ar_watermark_title")
        let watermarkStamp = lang.t("ar_watermark_stamp")
        let shaName = currentSha.localizedName
        let shaAliases = currentSha.localizedAliases
        let shaSeverity = currentSha.severity.localizedTitle
        let facingPinyin = mFacing.pinyin
        let facingName = mFacing.localizedName
        let facingPalace = mFacing.localizedPalace
        let targetHeading = targetCalculatedHeading
        let targetMtn = targetMountain
        let targetMtnName = targetMtn.localizedName
        let targetPalace = targetMtn.localizedPalace
        let normTargetX = min(max(Double(targetNormalizedPoint.x) + manualTargetNormalizedOffset, 0.08), 0.92)
        let normTargetY = min(max(Double(targetNormalizedPoint.y), 0.12), 0.72)
        let sampledDist = (cameraPosition == .back)
            ? fusionModel.sampleDepth(atPortraitNormalizedPoint: CGPoint(x: normTargetX, y: normTargetY))
            : nil
        let isLidar = fusionModel.lidarAvailable
        let solarTimeStr = motion.trueSolarTimeStr
        let auditDate = Date()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let image = renderer.image { ctx in
                let cg = ctx.cgContext
            
            // Only a real camera frame can become an on-site proof image.
            let imageSize = baseImage.size
            let fillScale = max(size.width / imageSize.width, size.height / imageSize.height)
            let drawSize = CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
            let drawRect = CGRect(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            baseImage.draw(in: drawRect)

            // HUD 在相机帧上保持可读性。
            cg.setFillColor(UIColor.black.withAlphaComponent(0.12).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            
            // 十字天心
            cg.setStrokeColor(UIColor(red: 0.0, green: 0.82, blue: 0.95, alpha: 0.6).cgColor)
            cg.setLineWidth(3)
            cg.move(to: CGPoint(x: size.width / 2, y: 0))
            cg.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            cg.move(to: CGPoint(x: 0, y: size.height / 2))
            cg.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            cg.strokePath()

            // 形煞锁定目标框绘入存证图
            let boxW: CGFloat = 420
            let boxH: CGFloat = 220
            let boxCenter = CGPoint(x: CGFloat(normTargetX) * size.width, y: CGFloat(normTargetY) * size.height)
            let targetBoxRect = CGRect(
                x: max(40, min(size.width - boxW - 40, boxCenter.x - boxW / 2)),
                y: max(120, min(size.height - 440 - boxH, boxCenter.y - boxH / 2)),
                width: boxW,
                height: boxH
            )
            cg.setFillColor(UIColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 0.16).cgColor)
            cg.fill(targetBoxRect)
            cg.setStrokeColor(UIColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 0.95).cgColor)
            cg.setLineWidth(4)
            cg.stroke(targetBoxRect)

            let boxHeader = "\(shaName) · \(targetMtnName) (\(String(format: "%.1f°", targetHeading)))"
            boxHeader.draw(
                in: CGRect(x: targetBoxRect.minX + 20, y: targetBoxRect.minY + 24, width: boxW - 40, height: 60),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 30),
                    .foregroundColor: UIColor(red: 1.0, green: 0.92, blue: 0.35, alpha: 1.0)
                ]
            )
            let distLine: String
            if let d = sampledDist {
                distLine = "\(targetPalace) · \(isLidar ? "LiDAR" : "AR") \(String(format: "%.2f m", d))"
            } else {
                distLine = "\(targetPalace) · \(shaSeverity)"
            }
            distLine.draw(
                in: CGRect(x: targetBoxRect.minX + 20, y: targetBoxRect.minY + 92, width: boxW - 40, height: 50),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
            )
            shaAliases.draw(
                in: CGRect(x: targetBoxRect.minX + 20, y: targetBoxRect.minY + 148, width: boxW - 40, height: 48),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 22),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.85)
                ]
            )
            
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
            watermarkTitle.draw(at: CGPoint(x: 70, y: size.height - 350), withAttributes: titleAttr)
            
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.white
            ]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timeStr = dateFormatter.string(from: auditDate)
            let distSuffix = sampledDist.map { String(format: " · %@ %.2fm", isLidar ? "LiDAR" : "AR", $0) } ?? ""
            
            let isEn = language == .en
            let isHant = language == .zhHant
            
            let infoText: String
            if isEn {
                infoText = """
                Facing Orientation: Mountain \(facingPinyin) (Measured \(String(format: "%.1f", currentHeading))°)\(distSuffix)
                Identified Sha: [\(shaName)] (\(shaAliases)) · \(shaSeverity)
                Coordinates: \(coordsStr) · Solar: \(solarTimeStr)
                Audit Time: \(timeStr) · SN: YX-AR-\(Int(auditDate.timeIntervalSince1970))
                """
            } else if isHant {
                infoText = """
                向首方位: \(facingName)山向首 (實測 \(String(format: "%.1f", currentHeading))°) · \(facingPalace)\(distSuffix)
                識別形煞: 【\(shaName)】(\(shaAliases)) · \(shaSeverity)
                現場經緯: \(coordsStr) · 真太陽時: \(solarTimeStr)
                勘察時間: \(timeStr) · 防偽鑒真: YX-AR-\(Int(auditDate.timeIntervalSince1970))
                """
            } else {
                infoText = """
                向首方位: \(facingName)山向首 (实测 \(String(format: "%.1f", currentHeading))°) · \(facingPalace)\(distSuffix)
                识别形煞: 【\(shaName)】(\(shaAliases)) · \(shaSeverity)
                现场经纬: \(coordsStr) · 真太阳时: \(solarTimeStr)
                勘察时间: \(timeStr) · 防伪鉴真: YX-AR-\(Int(auditDate.timeIntervalSince1970))
                """
            }
            infoText.draw(in: CGRect(x: 70, y: size.height - 290, width: size.width - 260, height: 210), withAttributes: bodyAttr)
            
            // 朱砂印鉴
            let sealRect = CGRect(x: size.width - 190, y: size.height - 230, width: 120, height: 120)
            cg.setStrokeColor(UIColor(red: 178/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0).cgColor)
            cg.setLineWidth(3)
            cg.stroke(sealRect)
            watermarkStamp.draw(in: sealRect.insetBy(dx: 18, dy: 18), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 26),
                .foregroundColor: UIColor(red: 178/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0)
            ])
            }
        
            DispatchQueue.main.async {
                guard self.isActive, self.snapshotGeneration == generation else { return }
                self.latestSnapshotImage = image
                self.saveSnapshotToPhotoLibrary(image)
            }
        }
    }

    private func saveSnapshotToPhotoLibrary(_ image: UIImage) {
        photoPermissionDenied = false
        let save: () -> Void = {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if !success {
                        aiError = error?.localizedDescription ?? lang.t("save_failed")
                        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
                        photoPermissionDenied = status == .denied || status == .restricted
                    }
                    withAnimation { showSnapshotToast = success }
                    if success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            withAnimation { showSnapshotToast = false }
                        }
                    }
                }
            }
        }
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            save()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                if status == .authorized || status == .limited { save() }
                else {
                    DispatchQueue.main.async {
                        aiError = lang.t("save_failed")
                        photoPermissionDenied = true
                    }
                }
            }
        default:
            aiError = lang.t("save_failed")
            photoPermissionDenied = true
        }
    }
}

private struct ARProofShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(
                x: controller.view.bounds.midX,
                y: controller.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 大师化解锦囊深度剖析与全案实操
public struct ShaRemedyDetailSheet: View {
    public let initialSha: ExteriorShaItem
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedShaId: String
    @State private var showPaywall: Bool = false
    
    private let database = ExteriorShaEngine.shared.database
    
    public init(sha: ExteriorShaItem) {
        self.initialSha = sha
        _selectedShaId = State(initialValue: sha.id)
    }
    
    private var currentSha: ExteriorShaItem {
        database.first(where: { $0.id == selectedShaId }) ?? initialSha
    }
    
    public var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. 八大形煞快速切换横向选择栏
                    shaPickerSection
                    
                    // 2. 煞气核心诊断与古典赋文卡片
                    shaDiagnosisCard
                    
                    // 3. 锦囊第一策：生态屏障与玄关动线调和（免费开放 · 立即见效）
                    ecoBarrierRemedyCard
                    
                    // 4. 锦囊第二策：镇宅开光法物秘宝与方位要领（VIP专属 / 核心真传）
                    talismanRemedyCard
                    
                    // 5. 锦囊第三策：玄空理气与五行生克调化（形理兼治）
                    xuanKongElementsRemedyCard
                    
                    // 6. 锦囊第四策：杨公择日安放良辰秘法（全套安放仪轨）
                    auspiciousTimingRemedyCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.1).ignoresSafeArea())
            .navigationBarTitle(lang.t("remedy_guide"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showPaywall) {
                VIPPaywallSheet(defaultProductId: .vipYearly)
            }
        }
    }
    
    // MARK: - 1. 八大形煞快速切换栏
    private var shaPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(lang.t("ar_sha_analysis_prefix"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.yanCyan)
                Spacer()
                Text("8大经典形煞锦囊库")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(database) { item in
                        let isSelected = item.id == currentSha.id
                        Button(action: {
                            selectedShaId = item.id
                        }) {
                            HStack(spacing: 4) {
                                if isSelected {
                                    Circle()
                                        .fill(Color(red: 0.95, green: 0.8, blue: 0.3))
                                        .frame(width: 5, height: 5)
                                }
                                Text(item.localizedName)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isSelected ? Color(red: 0.85, green: 0.7, blue: 0.2).opacity(0.25) : Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(isSelected ? Color(red: 0.95, green: 0.8, blue: 0.3) : Color.clear, lineWidth: 1)
                            )
                            .foregroundColor(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white.opacity(0.8))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 2. 煞气核心诊断与古典赋文卡片
    private var shaDiagnosisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(currentSha.localizedName)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(Color(red: 0.96, green: 0.88, blue: 0.55))
                    Text(currentSha.localizedAliases)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer()
                Text(currentSha.severity.localizedTitle)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.4), lineWidth: 1))
            }
            
            Divider().background(Color.white.opacity(0.12))
            
            // 现场特征
            VStack(alignment: .leading, spacing: 4) {
                Label(lang.t("ar_env_features"), systemImage: "eye.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.yanCyan)
                Text(currentSha.localizedVisualFeature)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(2)
            }
            
            // 玄学危害机理
            VStack(alignment: .leading, spacing: 4) {
                Label("⚡ 玄学危害机理剖析", systemImage: "bolt.trianglebranch.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.orange)
                Text(currentSha.localizedMetaphysicsHarm)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(2)
            }
            
            // 古籍赋文
            VStack(alignment: .leading, spacing: 4) {
                Label(lang.t("ar_classic_lore"), systemImage: "book.closed.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.9, green: 0.75, blue: 0.35))
                Text(currentSha.localizedClassicalText)
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.65))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.22, green: 0.17, blue: 0.08).opacity(0.6))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.8, green: 0.65, blue: 0.25).opacity(0.35), lineWidth: 1))
            }
        }
        .padding(14)
        .background(Color(red: 0.13, green: 0.13, blue: 0.16))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    // MARK: - 3. 锦囊第一策：生态屏障与玄关动线调和（免费开放）
    private var ecoBarrierRemedyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("🌿 第一策 · 绿色生态与玄关屏风法", systemImage: "leaf.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                Spacer()
                Text("即刻落地 · 全员免费")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.18))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }
            
            Text("无需动土破土，通过环境植被与室内动线重塑，以柔克刚化解外部冲击气场：")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
            
            VStack(alignment: .leading, spacing: 8) {
                ecoDetailRow(
                    icon: "tree.fill",
                    title: "阳台与窗前植被防护林",
                    desc: ecoPlantDesc(for: currentSha.id)
                )
                
                ecoDetailRow(
                    icon: "rectangle.split.2x1.fill",
                    title: "室内玄关九曲回流格局",
                    desc: "正对冲煞方向设立双面透光山水屏风或半高玄关隔断柜，将直冲强气转化为'曲折有情'之徐缓生气，藏风聚气而不阻滞光线。"
                )
                
                ecoDetailRow(
                    icon: "curtains.closed",
                    title: "双层Low-E隔音透光布艺",
                    desc: "窗边配置双层厚质隔音透光窗帘或百叶帘，物理阻绝外部视线与急煞风刃直透宅心，保全家中私密安稳气场。"
                )
            }
        }
        .padding(14)
        .background(Color(red: 0.12, green: 0.15, blue: 0.13))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }
    
    // MARK: - 4. 锦囊第二策：镇宅开光法物秘宝（VIP专属/核心真传）
    private var talismanRemedyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("🛡️ 第二策 · 镇宅开光法物秘宝", systemImage: "shield.checkered")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.3))
                Spacer()
                Text("开光真品 · 形煞克星")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.15))
                    .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.3))
                    .cornerRadius(6)
            }
            
            if !iap.hasUnlockedVIP {
                VIPLockCardView(
                    title: lang.t("ar_vip_remedy_title"),
                    featureDesc: "形煞本物克制真传、特选纯铜开光重器规制、悬挂倾角严训与邻里相合禁忌，解锁 VIP 尊享完整全案。",
                    badge: lang.t("vip_badge_title"),
                    targetProductId: .vipYearly,
                    onUnlockTap: { showPaywall = true }
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    talismanItemRow(
                        title: "核心克制法物推荐",
                        content: currentSha.localizedRemedySolution
                    )
                    
                    talismanItemRow(
                        title: "法器材质规制要求",
                        content: "必须选用正品高密度压铸纯铜（镇金辟阴）、天然黑曜石（化煞纳水）或纯天然黄玉石（厚德载物）。严禁使用塑料电镀仿品，仿制品不仅无抗煞磁场，反招邪气反噬。"
                    )
                    
                    talismanItemRow(
                        title: "悬挂朝向与邻里和睦禁忌",
                        content: "八卦镜或山海镇务必镜面朝外，向煞源微仰3至5度纳气消峰；严禁正对对面邻家门窗，遵循堪舆大师'化己之灾、莫害他人'的慈悲守和法则。"
                    )
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.16, green: 0.14, blue: 0.10))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.85, green: 0.7, blue: 0.25).opacity(0.35), lineWidth: 1))
    }
    
    // MARK: - 5. 锦囊第三策：玄空理气与五行飞星调治
    private var xuanKongElementsRemedyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("🧭 第三策 · 玄空理气与五行飞星调化", systemImage: "safari.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 1.0, blue: 1.0))
                Spacer()
                Text("形理兼治")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.18))
                    .foregroundColor(Color(red: 0.0, green: 1.0, blue: 1.0))
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 7) {
                Text("“峦头无理气不灵，理气无峦头不验”。形峦凶煞若逢二黑病符星或五黄廉贞大煞飞临，凶应加倍：")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                    .lineSpacing(2)
                
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow)
                    Text("【避煞要诀】冲煞方若为二黑巨门或五黄廉贞位，严禁动土穿凿与安放红色暖光灯，宜挂一具纯铜静安风铃或特制铜葫芦，以金泄土化解燥烈之气。")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.0, green: 1.0, blue: 1.0))
                    Text("【借势生旺】配合罗盘实测向首，若当运一白贪狼水星或八白左辅、九紫右弼当令吉星飞临，可在此方布置水生植物或紫水晶洞，化煞气为权柄，转凶为大吉。")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.10, green: 0.13, blue: 0.16))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.3), lineWidth: 1))
    }
    
    // MARK: - 6. 锦囊第四策：杨公择日安放良辰秘法
    private var auspiciousTimingRemedyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("📅 第四策 · 杨公择日安放良辰秘法", systemImage: "calendar.badge.clock")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.3))
                Spacer()
                Text("天时吉课")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.18))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                timingPointRow(
                    tag: "择日避忌",
                    content: "严禁岁破日、月破日、四废四绝日安放，且吉日地支不得与本宅坐向或户主本命生肖直冲（如子午相冲、丑未相冲）。"
                )
                
                timingPointRow(
                    tag: "推荐良辰",
                    content: "首选【天德】、【月德】、【天赦】、【青龙】吉日。时辰宜选辰时（7:00-9:00 朝阳升腾）、巳时（9:00-11:00 阳火得令）或午时（11:00-13:00 至阳化阴）。"
                )
                
                timingPointRow(
                    tag: "安放净仪",
                    content: "1. 净手焚一柱天然降真香或檀香熏沐法器；\n2. 法物原用红布严密封裹，至所选吉时良辰面向煞源启封揭彩；\n3. 端正放置于指定点位，心中默诵吉祥安康、家宅平顺之善念。"
                )
            }
        }
        .padding(14)
        .background(Color(red: 0.16, green: 0.12, blue: 0.10))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.35), lineWidth: 1))
    }
    
    // MARK: - 辅助子组件
    private func ecoDetailRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.green)
                .frame(width: 18)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(2)
            }
        }
    }
    
    private func talismanItemRow(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            Text(content)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
    
    private func timingPointRow(tag: String, content: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(tag)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.18))
                .cornerRadius(4)
            Text(content)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2)
        }
    }
    
    private func ecoPlantDesc(for id: String) -> String {
        switch id {
        case "tianzhan", "chuanxin":
            return "在阳台或对冲窗台排布茂密的阔叶常绿植物（如大叶散尾葵、琴叶榕、龟背竹），枝叶彼此交叠形成天然生态气盾，软化高速风刃。"
        case "luchong":
            return "在门前或对正路冲的窗下放置圆叶富贵竹或发财树盆景，使外部车流直冲之气化作回环温润之风。"
        case "fangong":
            return "在窗台安置半圆型绿色植被弧阵，顺应离心力缓冲向外甩甩的煞气，守住财水不失。"
        case "tantou":
            return "在视线对冲窗口种植长春藤或常青绿植阻断窥视，辅以常闭微透光百叶帘化解阴邪暗窥。"
        case "huoxing":
            return "窗台摆设水培常春藤或小型水养植物，借水生木、木生火之循环，以水润燥调和火煞燥烈。"
        case "baihu":
            return "在住宅左侧青龙方多摆放茂盛高大植物（如富贵椰子、绿宝），以青翠生机助旺青龙，压制白虎张扬。"
        case "gejiao":
            return "在阳台下沿筑造厚重高盆花坛灌木，构筑人工厚实台座，阻绝急流与贴地快速车道下拔地气。"
        default:
            return "窗台排布阔叶常绿盆景，构建绿色生态缓冲屏障，调和外部急煞气流。"
        }
    }
}
