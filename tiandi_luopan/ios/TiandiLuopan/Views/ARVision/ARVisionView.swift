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
    @ObservedObject private var shaStore = ShaSurveyStore.shared
    @State private var showPanoramaReport: Bool = false
    @State private var showClearShaAlert: Bool = false
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

    /// 目标仰角：相机光轴俯仰角 + 目标在画面中的纵向偏移角（俯为负、仰为正）。
    /// 竖向 FOV 按横向 FOV 的 9/16 近似折算；手动拖框的垂直增量幅度小（约
    /// ±1.5°），不并入，避免引入屏幕尺寸魔法常数。
    private var targetElevationDegrees: Double {
        let verticalFOVDeg = targetHorizontalFOV * 9.0 / 16.0
        let yFraction = (Double(targetNormalizedPoint.y) - 0.5) * 2.0
        let delta = atan(yFraction * tan(verticalFOVDeg * .pi / 360.0)) * 180.0 / .pi
        return fusionModel.cameraElevationDegrees + delta
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
                            .font(.adaptive(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        if latestSnapshotImage != nil {
                            Button(action: {
                                showSnapshotShareSheet = true
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text(lang.t("share_and_print"))
                                }
                                .font(.adaptive(size: 11, weight: .bold))
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
        .sheet(isPresented: $showPanoramaReport) {
            ShaPanoramaReportSheet(
                records: shaStore.records,
                heading: shaStore.archive?.compassHeading ?? motion.headingState.facingAngle,
                shaList: shaList
            )
        }
        .alert(isPresented: $showClearShaAlert) {
            Alert(
                title: Text(lang.t("ar_panorama_clear_confirm_title")),
                message: Text(lang.t("ar_panorama_clear_confirm_msg")),
                primaryButton: .destructive(Text(lang.t("ar_panorama_clear_confirm_btn"))) {
                    shaStore.clearRecords()
                },
                secondaryButton: .cancel(Text(lang.t("cancel")))
            )
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
                    .font(.adaptive(size: 40))
                    .foregroundColor(Color.yanCyan.opacity(0.5))
                let cameraDenied = AVCaptureDevice.authorizationStatus(for: .video) == .denied ||
                    AVCaptureDevice.authorizationStatus(for: .video) == .restricted
                Text(cameraDenied ? lang.t("camera_permission_denied") : lang.t("simulation_mode"))
                    .font(.adaptive(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                if cameraDenied {
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        Text(lang.t("open_system_settings"))
                            .font(.adaptive(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.yanCyan.opacity(0.25))
                            .foregroundColor(.yanCyan)
                            .cornerRadius(8)
                    }
                } else {
                    Text(lang.t("ar_drag_hint"))
                        .font(.adaptive(size: 11))
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
                .font(.adaptive(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isHorizontalLevel ? .yanCyan : .orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: true, vertical: false)
                .offset(y: -50)

            if cameraPosition == .back, let dist = fusionModel.distance {
                Text("\(fusionModel.lidarAvailable ? "LiDAR" : "AR") · \(String(format: "%.2f m", dist))")
                    .font(.adaptive(size: 10, weight: .bold, design: .monospaced))
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
                            .font(.adaptive(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    Text(currentSha.localizedName)
                        .font(.adaptive(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                    Text("\(lang.t("ar_target_bearing")): \(String(format: "%.1f", targetCalculatedHeading))° (\(m.localizedPalace))")
                        .font(.adaptive(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if let water = waterItem {
                        let statusTag = hitBaSha
                            ? "⚠️ 犯坐山八煞"
                            : (water.isHuangQuanSha ? "⚠️ 犯八路黄泉" : "水法: \(water.stage)")
                        Text(statusTag)
                            .font(.adaptive(size: 9, weight: .bold))
                            .foregroundColor((hitBaSha || water.isHuangQuanSha) ? .red : (water.isAuspicious ? .green : .yanCyan))
                            .lineLimit(1)
                    }
                    if let d = targetDist {
                        Text("\(fusionModel.lidarAvailable ? "LiDAR" : "AR") \(String(format: "%.2f m", d))")
                            .font(.adaptive(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    Text(currentSha.localizedAliases)
                        .font(.adaptive(size: 9))
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
                        .font(.adaptive(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text("\(lang.t("ar_physical_facing")): \(motion.headingState.facingMountain.localizedName)\(lang.t("mountain_suffix")) (\(String(format: "%.1f", motion.headingState.facingAngle))°)")
                        .font(.adaptive(size: 11))
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
                        // 完全释放 AR 会话（pause 只挂起，ARSession/ARSCNView 在
                        // 视图移除时仍可能同步等待底层会话，主线程被卡死）。
                        // stop() 摘除 delegate、清空 sceneView 与配置，视图移除
                        // 时无活跃 AR 资源，再延迟切换让相机硬件完全释放。
                        fusionModel.stop()
                        isSwitchingCamera = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [nextPosition] in
                            cameraPosition = nextPosition
                            isSwitchingCamera = false
                        }
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
                        .font(.adaptive(size: 13))
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
                        .font(.adaptive(size: 11, weight: .bold))
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
                        .font(.adaptive(size: 11, weight: .bold))
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
                        .font(.adaptive(size: 11, weight: .bold))
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
                        .font(.adaptive(size: 11, weight: .bold))
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
                        .font(.adaptive(size: isCenter ? 11 : 10, weight: .bold))
                        .foregroundColor(isCenter ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white)
                    if let water = water {
                        Text((isBaSha || isHQ) ? "\(shaPrefix)\(water.stage)" : water.stage)
                            .font(.adaptive(size: 8, weight: .semibold))
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
                    .font(.adaptive(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isAutoFollowingDirection ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
                    .foregroundColor(isAutoFollowingDirection ? .green : .orange)
                    .cornerRadius(6)
                }
                
                Spacer()
                
                Text("\(lang.t("ar_current_facing")): \(targetMountain.localizedPalace) · \(targetMountain.localizedName)\(lang.t("mountain_suffix"))")
                    .font(.adaptive(size: 10, weight: .medium))
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
                                .font(.adaptive(size: 11, weight: isSelected ? .bold : .medium))
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
                        .font(.adaptive(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Spacer()
                }
                .padding(.horizontal, 8)
                Text(lang.t("ar_ai_disclaimer"))
                    .font(.adaptive(size: 9))
                    .foregroundColor(.orange.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            } else if let aiError = aiError {
                VStack(alignment: .leading, spacing: 5) {
                    Text(aiError)
                        .font(.adaptive(size: 10))
                        .foregroundColor(.orange)
                    if photoPermissionDenied {
                        Button(lang.t("open_system_settings")) {
                            guard let url = URL(string: UIApplication.openSettingsURLString),
                                  UIApplication.shared.canOpenURL(url) else { return }
                            UIApplication.shared.open(url)
                        }
                        .font(.adaptive(size: 10, weight: .semibold))
                        .foregroundColor(.yanCyan)
                    }
                }
                .padding(.horizontal, 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("【\(sha.localizedName)】\(aiResult == nil ? lang.t("ar_manual_analysis") : lang.t("ar_ai_candidate")):")
                        .font(.adaptive(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Spacer()
                    Text(sha.severity.localizedTitle)
                        .font(.adaptive(size: 10, weight: .bold))
                        .foregroundColor(sha.severity == .critical ? Color.red : Color.orange)
                }
                Text(sha.localizedMetaphysicsHarm)
                    .font(.adaptive(size: 11))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            .padding(8)
            .background(Color.black.opacity(0.75))
            .cornerRadius(8)

            // 现场标注与全景报告入口
            HStack(spacing: 8) {
                Button(action: markCurrentSha) {
                    Label("\(lang.t("ar_mark_sha")) (\(shaStore.records.count))", systemImage: "mappin.and.ellipse")
                        .font(.adaptive(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yanCyan.opacity(0.25))
                        .foregroundColor(Color.yanCyan)
                        .cornerRadius(6)
                }
                Button(action: { showPanoramaReport = true }) {
                    Label(lang.t("ar_panorama_report"), systemImage: "gauge")
                        .font(.adaptive(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                }
                if !shaStore.records.isEmpty {
                    Menu {
                        Button(action: {
                            shaStore.removeLastRecord()
                        }) {
                            Label(lang.t("ar_panorama_undo"), systemImage: "arrow.uturn.backward")
                        }
                        Button(role: .destructive, action: {
                            showClearShaAlert = true
                        }) {
                            Label(lang.t("ar_panorama_clear"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.adaptive(size: 11, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.18))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 4)
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
            // AI 三帧共识即一次带置信度的方位标注，自动并入全景档案
            let sample = CGPoint(
                x: min(max(Double(targetNormalizedPoint.x), 0.02), 0.98),
                y: min(max(Double(targetNormalizedPoint.y), 0.02), 0.98)
            )
            let dist = (cameraPosition == .back) ? fusionModel.sampleDepth(atPortraitNormalizedPoint: sample) : nil
            shaStore.addRecord(ExteriorShaRecord(
                shaID: analysis.shaID,
                bearingDegrees: targetCalculatedHeading,
                capturedHeadingDegrees: motion.headingState.facingAngle,
                elevationDegrees: targetElevationDegrees,
                distanceMeters: dist,
                confidence: analysis.confidence,
                source: .ai,
                note: "three-frame-temporal-consensus"
            ))
        }
    }

    // MARK: - 外部形煞现场标注（结构化记录：类型/方位/仰角/距离，并入全景报告）

    /// 当前锁定框在画面中的归一化采样点（并入 AI 目标点与手动水平拖动）
    private var currentTargetSamplePoint: CGPoint {
        let x = min(max(Double(targetNormalizedPoint.x) + manualTargetNormalizedOffset, 0.02), 0.98)
        let y = min(max(Double(targetNormalizedPoint.y), 0.02), 0.98)
        return CGPoint(x: x, y: y)
    }

    /// 把当前目标锁定框记入全景形煞档案（手动/AI 统一入口）
    private func markCurrentSha() {
        let sha = shaList[activeShaIndex]
        let sample = currentTargetSamplePoint
        let dist = (cameraPosition == .back) ? fusionModel.sampleDepth(atPortraitNormalizedPoint: sample) : nil
        let record = ExteriorShaRecord(
            shaID: sha.id,
            bearingDegrees: targetCalculatedHeading,
            capturedHeadingDegrees: motion.headingState.facingAngle,
            elevationDegrees: targetElevationDegrees,
            distanceMeters: dist,
            confidence: aiResult?.confidence,
            source: aiResult == nil ? .manual : .ai,
            note: aiResult == nil ? nil : "three-frame-temporal-consensus"
        )
        shaStore.addRecord(record)
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
                    
                    // 3. 化解三步走（免费核心：方法 + 影响范围）
                    remedyStepsCard
                    
                    // 4. 进阶调理参考（免费：玄空避忌 + 择日安放）
                    advancedTipsCard
                    
                    // 5. 进阶法物参考（VIP 可选）
                    vipRemedyCard
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
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - 1. 八大形煞快速切换栏
    private var shaPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(lang.t("ar_sha_analysis_prefix"))
                    .font(.adaptive(size: 13, weight: .semibold))
                    .foregroundColor(Color.yanCyan)
                Spacer()
                Text("8大经典形煞锦囊库")
                    .font(.adaptive(size: 11))
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
                                    .font(.adaptive(size: 12, weight: isSelected ? .bold : .medium))
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
                        .font(.adaptive(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(Color(red: 0.96, green: 0.88, blue: 0.55))
                    Text(currentSha.localizedAliases)
                        .font(.adaptive(size: 12))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer()
                Text(currentSha.severity.localizedTitle)
                    .font(.adaptive(size: 11, weight: .bold))
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
                    .font(.adaptive(size: 12, weight: .semibold))
                    .foregroundColor(Color.yanCyan)
                Text(currentSha.localizedVisualFeature)
                    .font(.adaptive(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(2)
            }
            
            // 玄学危害机理
            VStack(alignment: .leading, spacing: 4) {
                Label("⚡ 玄学危害机理剖析", systemImage: "bolt.trianglebranch.fill")
                    .font(.adaptive(size: 12, weight: .semibold))
                    .foregroundColor(Color.orange)
                Text(currentSha.localizedMetaphysicsHarm)
                    .font(.adaptive(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(2)
            }
            
            // 古籍赋文
            VStack(alignment: .leading, spacing: 4) {
                Label(lang.t("ar_classic_lore"), systemImage: "book.closed.fill")
                    .font(.adaptive(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.9, green: 0.75, blue: 0.35))
                Text(currentSha.localizedClassicalText)
                    .font(.adaptive(size: 12, weight: .medium, design: .serif))
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
    
    // MARK: - 3. 化解三步走（免费核心卡：直接可做的方法 + 影响范围）
    private var remedyStepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("🛠 化解三步走 · 直接可做", systemImage: "checkmark.circle.fill")
                    .font(.adaptive(size: 14, weight: .bold))
                    .foregroundColor(.green)
                Spacer()
                Text("先做① → 再②③")
                    .font(.adaptive(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.18))
                    .foregroundColor(.green)
                    .cornerRadius(6)
            }
            
            Text("① 立即可做（免费）→ ② 低成本改造 → ③ 可选强化。每一步都标明影响范围，按需执行即可。")
                .font(.adaptive(size: 11))
                .foregroundColor(.white.opacity(0.7))
            
            Text(currentSha.localizedRemedySolution)
                .font(.adaptive(size: 12))
                .foregroundColor(.white.opacity(0.95))
                .lineSpacing(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.12, green: 0.15, blue: 0.13))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
        }
        .padding(14)
        .background(Color(red: 0.10, green: 0.13, blue: 0.12))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.25), lineWidth: 1))
    }
    
    // MARK: - 4. 进阶调理参考（免费：玄空避忌 + 择日安放）
    private var advancedTipsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("📋 进阶调理参考", systemImage: "text.book.closed.fill")
                    .font(.adaptive(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.0, green: 1.0, blue: 1.0))
                Spacer()
                Text("免费")
                    .font(.adaptive(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.18))
                    .foregroundColor(Color(red: 0.0, green: 1.0, blue: 1.0))
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                timingPointRow(
                    tag: "玄空避忌",
                    content: "冲煞方若逢二黑病符或五黄廉贞位，忌动土、忌红色暖光；可挂铜葫芦或六帝钱泄土气。"
                )
                timingPointRow(
                    tag: "择日建议",
                    content: "安放法物选天德、月德、天赦吉日，避开岁破、月破日；上午7-13点（辰巳午时）为佳。"
                )
                timingPointRow(
                    tag: "安放要点",
                    content: "净手后安置于指定方位；镜面朝外、微下倾3-5度，勿照邻家门窗。"
                )
            }
        }
        .padding(14)
        .background(Color(red: 0.10, green: 0.13, blue: 0.16))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.0, green: 1.0, blue: 1.0).opacity(0.3), lineWidth: 1))
    }
    
    // MARK: - 5. 进阶法物参考（VIP 可选：材质规格与挂法）
    private var vipRemedyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("🛡 进阶法物参考", systemImage: "shield.checkered")
                    .font(.adaptive(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.3))
                Spacer()
                Text("VIP 可选")
                    .font(.adaptive(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.15))
                    .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.3))
                    .cornerRadius(6)
            }
            
            if !iap.hasUnlockedVIP {
                VIPLockCardView(
                    title: lang.t("ar_vip_remedy_title"),
                    featureDesc: "常用化煞法物的材质、规格与悬挂要领，配合方位实操细节，解锁 VIP 查看完整参考。",
                    badge: lang.t("vip_badge_title"),
                    targetProductId: .vipYearly,
                    onUnlockTap: { showPaywall = true }
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    talismanItemRow(
                        title: "常用法物与挂法",
                        content: currentSha.localizedRemedySolution
                    )
                    
                    talismanItemRow(
                        title: "材质参考",
                        content: "优先选用纯铜、天然黑曜石、黄玉等天然材质器物；避免塑料电镀仿品。"
                    )
                    
                    talismanItemRow(
                        title: "悬挂要领",
                        content: "镜面朝外、微下倾3-5度；八卦镜、山海镇等避免直照邻家门窗，保持邻里和睦。"
                    )
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.16, green: 0.14, blue: 0.10))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.85, green: 0.7, blue: 0.25).opacity(0.35), lineWidth: 1))
    }
    
    // MARK: - 辅助子组件
    private func talismanItemRow(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.adaptive(size: 12, weight: .bold))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            Text(content)
                .font(.adaptive(size: 11))
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
                .font(.adaptive(size: 10, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.18))
                .cornerRadius(4)
            Text(content)
                .font(.adaptive(size: 11))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2)
        }
    }
}

// MARK: - 全景形煞分布报告 (八宫聚合 + 距离判级 + 仰角/距离明细)
private struct ShaPanoramaReportSheet: View {
    @ObservedObject private var shaStore = ShaSurveyStore.shared
    let heading: Double
    let shaList: [ExteriorShaItem]
    @ObservedObject var lang = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirmAlert = false

    init(records: [ExteriorShaRecord]? = nil, heading: Double, shaList: [ExteriorShaItem]) {
        self.heading = heading
        self.shaList = shaList
    }

    private var records: [ExteriorShaRecord] {
        shaStore.records
    }

    private var grouped: [[ExteriorShaRecord]] {
        ShaPanoramaReport(headingDegrees: heading, records: records).palacesByIndex
    }

    private func effectiveSeverity(for record: ExteriorShaRecord) -> ShaSeverity? {
        guard let item = shaList.first(where: { $0.id == record.shaID }) else { return nil }
        return ExteriorShaSeverityResolver.effectiveSeverity(
            staticSeverity: item.severity,
            distanceMeters: record.distanceMeters
        )
    }

    private func shaName(for record: ExteriorShaRecord) -> String {
        shaList.first(where: { $0.id == record.shaID })?.localizedName ?? record.shaID
    }

    private func palaceRange(_ index: Int) -> String {
        String(format: "%d°–%d°", index * 45, (index + 1) * 45)
    }

    private func severityColor(for record: ExteriorShaRecord) -> Color {
        guard let sev = effectiveSeverity(for: record) else { return .gray }
        switch sev {
        case .critical: return .red
        case .warning: return .orange
        case .minor: return .yellow
        case .notice: return .green
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 顶部统计：标注数 / 覆盖宫位 / 极凶数
                    HStack {
                        VStack {
                            Text("\(records.count)")
                                .font(.system(size: 26, weight: .bold))
                            Text(lang.t("ar_panorama_records"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack {
                            Text("\(grouped.filter { !$0.isEmpty }.count)/8")
                                .font(.system(size: 26, weight: .bold))
                            Text(lang.t("ar_panorama_palaces"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack {
                            Text("\(records.filter { effectiveSeverity(for: $0) == .critical }.count)")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.red)
                            Text(lang.t("ar_panorama_critical"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(10)

                    Text("\(lang.t("ar_panorama_heading")): \(String(format: "%.1f", heading))°")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    // 室内外统一档案：室内体检条目与外部标注合计
                    if let interior = ShaSurveyStore.shared.latestInterior {
                        HStack(spacing: 8) {
                            Image(systemName: "house.and.flag.fill")
                                .foregroundColor(.brown)
                            Text("\(lang.t("ar_panorama_interior")): \(interior.shaItems.count) · \(lang.t("ar_panorama_total")): \(records.count + interior.shaItems.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.brown.opacity(0.08))
                        .cornerRadius(8)
                    }

                    if records.isEmpty {
                        Text(lang.t("ar_panorama_none"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(0..<8, id: \.self) { idx in
                            let palaceRecords = grouped[idx]
                            if !palaceRecords.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(lang.t("ar_panorama_palace"))
                                            .font(.caption.weight(.bold))
                                        Text(palaceRange(idx))
                                            .font(.caption.weight(.bold).monospaced())
                                        Spacer()
                                        Text("\(palaceRecords.count)")
                                            .font(.caption.weight(.bold))
                                    }
                                    .foregroundColor(.brown)
                                    ForEach(palaceRecords) { record in
                                        HStack(spacing: 8) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(severityColor(for: record))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(shaName(for: record))
                                                    .font(.subheadline.weight(.semibold))
                                                Text("\(String(format: "%.1f", record.bearingDegrees))° · \(lang.t("ar_panorama_elevation")) \(String(format: "%.0f", record.elevationDegrees))° · \(record.source == .ai ? lang.t("ar_panorama_ai") : lang.t("ar_panorama_manual"))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            if let d = record.distanceMeters {
                                                Text(String(format: "%.1f m", d))
                                                    .font(.caption.monospaced())
                                                    .foregroundColor(.secondary)
                                            }
                                            if let sev = effectiveSeverity(for: record) {
                                                Text(sev.localizedTitle)
                                                    .font(.caption2.weight(.bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(sev == .critical ? Color.red.opacity(0.15) : (sev == .warning ? Color.orange.opacity(0.15) : (sev == .minor ? Color.yellow.opacity(0.15) : Color.green.opacity(0.15))))
                                                    .cornerRadius(6)
                                            }
                                            Button(action: {
                                                shaStore.removeRecord(id: record.id)
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.red.opacity(0.75))
                                                    .padding(6)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                        .padding(8)
                                        .background(Color.black.opacity(0.04))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(lang.t("ar_panorama_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !records.isEmpty {
                        Button(role: .destructive, action: {
                            showClearConfirmAlert = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text(lang.t("ar_panorama_clear"))
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("ar_panorama_close")) { dismiss() }
                }
            }
            .alert(isPresented: $showClearConfirmAlert) {
                Alert(
                    title: Text(lang.t("ar_panorama_clear_confirm_title")),
                    message: Text(lang.t("ar_panorama_clear_confirm_msg")),
                    primaryButton: .destructive(Text(lang.t("ar_panorama_clear_confirm_btn"))) {
                        shaStore.clearRecords()
                    },
                    secondaryButton: .cancel(Text(lang.t("cancel")))
                )
            }
        }
    }
}
