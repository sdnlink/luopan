import SwiftUI
import AVFoundation
import ARKit
import UIKit
import Photos

// MARK: - 原生高清相机预览层控制器与视图 (AVCaptureSession Representable)

public final class CameraPreviewController: ObservableObject {
    fileprivate weak var activeView: CameraPreviewView.CameraUIView?
    
    public init() {}
    var currentCapturePose: ARCapturePose? { activeView?.exposurePose() }
    
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
    @Environment(\.cameraLeaseActive) private var cameraLeaseActive
    public var controller: CameraPreviewController?
    public var cameraPosition: AVCaptureDevice.Position
    public var isActive: Bool
    public var captureTrigger: Int
    public var onPhotoCaptured: ((UIImage?) -> Void)?
    var onFrameCaptured: ((ARCapturedFrame?) -> Void)? = nil
    
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
    
    init(controller: CameraPreviewController?, cameraPosition: AVCaptureDevice.Position,
         isActive: Bool, captureTrigger: Int, onFrameCaptured: @escaping (ARCapturedFrame?) -> Void) {
        self.controller = controller
        self.cameraPosition = cameraPosition
        self.isActive = isActive
        self.captureTrigger = captureTrigger
        self.onFrameCaptured = onFrameCaptured
    }

    public class CameraUIView: UIView, AVCapturePhotoCaptureDelegate {
        private var captureSession: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var photoCaptureOutput: AVCapturePhotoOutput?
        private var photoCompletion: ((ARCapturedFrame?) -> Void)?
        private var photoPose: ARCapturePose?
        private var photoCaptureID: Int64?
        private var photoCaptureDate = Date()
        private var photoViewportSize: CGSize = .zero
        private var cameraDevice: AVCaptureDevice?
        private var currentPosition: AVCaptureDevice.Position = .back
        private var isCapturingPhoto = false
        private var sessionObservers: [NSObjectProtocol] = []
        private let sessionQueue = DispatchQueue(label: "com.yanxiang.compass.camera-session")
        private var wantsRunning = true
        // iPad 声明了四个方向，预览层与照片输出必须跟随界面旋转；
        // iOS 17 用 AVCaptureDevice.RotationCoordinator，iOS 16 用 videoOrientation。
        private var rotationCoordinator: Any?
        private var rotationObservation: NSKeyValueObservation?

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
            syncRotation()
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
            
            cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
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
            startRotationTracking(device: camera, preview: preview)

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

        /// 让预览层与照片输出跟随界面方向。
        /// iPhone 端只支持竖屏，这段代码在 iPhone 上是空转；
        /// iPad 支持四向，缺了它横屏取景会整体旋转 90°、存证照片方向也会错。
        private func startRotationTracking(device: AVCaptureDevice, preview: AVCaptureVideoPreviewLayer) {
            rotationObservation = nil
            rotationCoordinator = nil
            if #available(iOS 17.0, *) {
                let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
                rotationCoordinator = coordinator
                rotationObservation = coordinator.observe(
                    \.videoRotationAngleForHorizonLevelPreview,
                    options: [.initial, .new]
                ) { [weak self] _, _ in
                    DispatchQueue.main.async { self?.syncRotation() }
                }
            }
            syncRotation()
        }

        private func syncRotation() {
            guard let connection = previewLayer?.connection else { return }
            if #available(iOS 17.0, *) {
                if let coordinator = rotationCoordinator as? AVCaptureDevice.RotationCoordinator {
                    // isVideoRotationAngleSupported 是方法（传入角度），不是 Bool 属性。
                    let previewAngle = coordinator.videoRotationAngleForHorizonLevelPreview
                    if connection.isVideoRotationAngleSupported(previewAngle) {
                        connection.videoRotationAngle = previewAngle
                    }
                    let captureAngle = coordinator.videoRotationAngleForHorizonLevelCapture
                    if let photoConnection = photoCaptureOutput?.connection(with: .video),
                       photoConnection.isVideoRotationAngleSupported(captureAngle) {
                        photoConnection.videoRotationAngle = captureAngle
                    }
                    return
                }
            }
            // iOS 16 兼容分支：界面方向与 AVCaptureVideoOrientation 的横屏命名相反，
            // 竖屏 UI 下两者一致，横屏需要互换左右，否则 iPad 横屏会得到 180° 倒像。
            let captureOrientation = (window?.windowScene?.interfaceOrientation ?? .portrait).avCaptureOrientation
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = captureOrientation
            }
            if let photoConnection = photoCaptureOutput?.connection(with: .video),
               photoConnection.isVideoOrientationSupported {
                photoConnection.videoOrientation = captureOrientation
            }
        }

        public func capturePhoto(completion: @escaping (UIImage?) -> Void) {
            captureFrame { completion($0?.image) }
        }

        fileprivate func exposurePose() -> ARCapturePose? {
            let motion = CompassMotionManager.shared
            guard let heading = motion.physicalHeading(),
                  let elevation = motion.physicalCameraElevation(front: currentPosition == .front),
                  bounds.width > 0, bounds.height > 0 else { return nil }
            let rawFOV = Double(cameraDevice?.activeFormat.videoFieldOfView ?? 60)
            let dimensions = cameraDevice.map { CMVideoFormatDescriptionGetDimensions($0.activeFormat.formatDescription) }
            let width = Double(dimensions?.width ?? 1920), height = Double(dimensions?.height ?? 1080)
            let focal = width / (2 * tan(rawFOV * .pi / 360))
            let portrait = (window?.windowScene?.interfaceOrientation ?? .portrait).isPortrait
            let orientedWidth = portrait ? height : width, orientedHeight = portrait ? width : height
            let scale = max(Double(bounds.width) / orientedWidth, Double(bounds.height) / orientedHeight)
            let fov = 2 * atan((Double(bounds.width) / scale) / (2 * focal)) * 180 / .pi
            return ARCapturePose(heading: (heading + (currentPosition == .front ? 180 : 0)).truncatingRemainder(dividingBy: 360),
                                 elevation: elevation,
                                 projection: ARTargetProjection(horizontalFOVDegrees: fov, aspectRatio: Double(bounds.width / bounds.height)))
        }

        public func captureFrame(completion: @escaping (ARCapturedFrame?) -> Void) {
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
            photoPose = exposurePose()
            photoCaptureDate = Date()
            photoViewportSize = bounds.size
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            if #available(iOS 13.0, *) {
                settings.photoQualityPrioritization = .speed
            }
            photoCaptureID = settings.uniqueID
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        public func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.photoCaptureID == resolvedSettings.uniqueID else { return }
                self.photoPose = self.exposurePose()
                self.photoCaptureDate = Date()
                self.photoViewportSize = self.bounds.size
            }
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
                guard self.photoCaptureID == photo.resolvedSettings.uniqueID else { return }
                let completion = self.photoCompletion
                let pose = self.photoPose
                let date = self.photoCaptureDate
                let viewport = self.photoViewportSize
                self.photoCaptureID = nil
                self.photoCompletion = nil
                self.isCapturingPhoto = false
                completion?(image.map { ARCapturedFrame(image: ARCapturedFrame.viewportImage($0, size: viewport), pose: pose, capturedAt: date) })
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
            rotationObservation = nil
            rotationCoordinator = nil
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
            photoCaptureID = nil
            photoPose = nil
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
        // 同 ARSCNView：SwiftUI .clipped() 对 UIViewRepresentable 不保证生效，
        // 分栏左栏时在 UIView 层自行裁剪，确保预览层不越界。
        view.clipsToBounds = true
        controller?.activeView = view
        if isActive && cameraLeaseActive {
            view.setupSession(position: cameraPosition)
        }
        return view
    }
    
    public func updateUIView(_ uiView: CameraUIView, context: Context) {
        controller?.activeView = uiView
        if !isActive || !cameraLeaseActive {
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
            uiView.captureFrame { frame in
                if let onFrameCaptured { onFrameCaptured(frame) }
                else { onPhotoCaptured?(frame?.image) }
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

