import SwiftUI
import ARKit
import SceneKit
import simd
import UIKit
import CoreImage
import CoreVideo

/// The tracking state is kept separate from presentation text so that the
/// survey can be localized without making the AR session depend on UI state.
public enum ARSpatialTrackingState: Equatable {
    case unavailable
    case initializing
    case normal
    case limited
}

public enum ARSpatialMappingState: Equatable {
    case unavailable
    case limited
    case extending
    case mapped
}

public enum ARSpatialSurveyError: Error, Equatable {
    case sessionUnavailable
    case mapUnavailable
    case archiveFailed
    case storageUnavailable
}

/// Evidence captured from the same ARFrame as a Vision image.  It is kept
/// small so the frame can cross into the Vision worker without retaining an
/// ARSession or a large depth buffer.
public struct ARSceneEvidence {
    public let trackingIsNormal: Bool
    public let mappingIsUsable: Bool
    public let lidarAvailable: Bool
    public let depthStreamAvailable: Bool
    public let depthCoverage: Float
    public let horizontalFOVDegrees: Double?
    public let verticalPlaneCount: Int
    public let wallFaceCount: Int
    public let depthSampleMeters: Float?
    public let leftDepthMeters: Float?
    public let rightDepthMeters: Float?
    public let topDepthMeters: Float?
    public let bottomDepthMeters: Float?
    public let timestamp: TimeInterval

    public init(
        trackingIsNormal: Bool,
        mappingIsUsable: Bool,
        lidarAvailable: Bool,
        depthStreamAvailable: Bool,
        depthCoverage: Float,
        horizontalFOVDegrees: Double?,
        verticalPlaneCount: Int,
        wallFaceCount: Int,
        depthSampleMeters: Float?,
        leftDepthMeters: Float? = nil,
        rightDepthMeters: Float? = nil,
        topDepthMeters: Float? = nil,
        bottomDepthMeters: Float? = nil,
        timestamp: TimeInterval
    ) {
        self.trackingIsNormal = trackingIsNormal
        self.mappingIsUsable = mappingIsUsable
        self.lidarAvailable = lidarAvailable
        self.depthStreamAvailable = depthStreamAvailable
        self.depthCoverage = depthCoverage
        self.horizontalFOVDegrees = horizontalFOVDegrees
        self.verticalPlaneCount = verticalPlaneCount
        self.wallFaceCount = wallFaceCount
        self.depthSampleMeters = depthSampleMeters
        self.leftDepthMeters = leftDepthMeters
        self.rightDepthMeters = rightDepthMeters
        self.topDepthMeters = topDepthMeters
        self.bottomDepthMeters = bottomDepthMeters
        self.timestamp = timestamp
    }
}

public struct ARCapturedFrame {
    public let image: UIImage
    public let evidence: ARSceneEvidence?

    public init(image: UIImage, evidence: ARSceneEvidence? = nil) {
        self.image = image
        self.evidence = evidence
    }
}

/// Owns one AR session and throttles expensive mesh and raycast work.  The
/// existing camera based AR screen and this object are never active together.
public final class ARSpatialSurveyModel: NSObject, ObservableObject, ARSessionDelegate, ARSCNViewDelegate {
    @Published public private(set) var trackingState: ARSpatialTrackingState = .initializing
    @Published public private(set) var mappingState: ARSpatialMappingState = .unavailable
    @Published public private(set) var planeCount: Int = 0
    @Published public private(set) var verticalPlaneCount: Int = 0
    @Published public private(set) var meshAnchorCount: Int = 0
    @Published public private(set) var largestPlaneWidth: Float?
    @Published public private(set) var largestPlaneDepth: Float?
    @Published public private(set) var distance: Float?
    // Use raw values as keys because ARMeshClassification is imported from an
    // Objective-C enum and is not Hashable on every iOS SDK generation.
    @Published public private(set) var semanticCounts: [Int: Int] = [:]
    @Published public private(set) var lidarAvailable = false
    @Published public private(set) var hasSavedWorldMap = false

    private weak var sceneView: ARSCNView?
    private var lastMeasurementTimestamp: TimeInterval = 0
    private var lastSemanticUpdateTimestamp: TimeInterval = 0
    private var lastMeshGeometryUpdate: [UUID: TimeInterval] = [:]
    private var lastPlaneGeometryUpdate: [UUID: TimeInterval] = [:]
    private var activeConfiguration: ARWorldTrackingConfiguration?
    private var distanceSamples: [Float] = []
    private var rendersSpatialMesh = true
    private var lastCapturedTimestamp: TimeInterval = 0

    /// World maps can be large and are user-created survey data. Store them
    /// in a durable app support directory so a background/suspension cycle or
    /// a later share action does not lose a file written to the temporary
    /// directory.
    private static func worldMapDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ARSpatialSurveyError.storageUnavailable
        }
        let directory = applicationSupport
            .appendingPathComponent("TianJiYanXiang", isDirectory: true)
            .appendingPathComponent("ARExports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory
    }

    /// Keep user exports useful without allowing repeated scans to consume an
    /// unbounded amount of on-device storage. Only files created by this
    /// feature are considered; files shared elsewhere remain untouched.
    private static func pruneWorldMapExports(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        var maps = files.filter { $0.pathExtension == "arworldmap" && $0.lastPathComponent.hasPrefix("TianJiYanXiang-") }
            .compactMap { url -> (url: URL, date: Date, size: Int)? in
                guard let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                      let date = values.creationDate,
                      let size = values.fileSize else { return nil }
                return (url, date, size)
            }
            .sorted { $0.date < $1.date }
        var totalBytes = maps.reduce(0) { $0 + $1.size }
        let maxFiles = 12
        let maxBytes = 80 * 1024 * 1024
        while maps.count > maxFiles || totalBytes > maxBytes {
            guard let oldest = maps.first else { break }
            try? FileManager.default.removeItem(at: oldest.url)
            totalBytes -= oldest.size
            maps.removeFirst()
        }
    }

    public func attach(to sceneView: ARSCNView, renderMesh: Bool = true) {
        self.sceneView = sceneView
        self.rendersSpatialMesh = renderMesh
        sceneView.session.delegate = self
        sceneView.delegate = self
    }

    public func start() {
        guard let sceneView = sceneView else { return }
        guard ARWorldTrackingConfiguration.isSupported else {
            trackingState = .unavailable
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        lidarAvailable = false

        if #available(iOS 13.4, *),
           ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            lidarAvailable = true
        }

        if #available(iOS 14.0, *),
           ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        } else if #available(iOS 13.4, *),
           ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        trackingState = .initializing
        mappingState = .limited
        lastMeasurementTimestamp = 0
        lastSemanticUpdateTimestamp = 0
        lastMeshGeometryUpdate.removeAll()
        lastPlaneGeometryUpdate.removeAll()
        planeCount = 0
        meshAnchorCount = 0
        largestPlaneWidth = nil
        largestPlaneDepth = nil
        distance = nil
        distanceSamples.removeAll(keepingCapacity: true)
        lastCapturedTimestamp = 0
        semanticCounts = [:]
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        activeConfiguration = configuration
        refreshSavedWorldMapState()
    }

    public func refreshSavedWorldMapState() {
        guard let directory = try? Self.worldMapDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: nil,
                  options: [.skipsHiddenFiles]
              ) else {
            hasSavedWorldMap = false
            return
        }
        hasSavedWorldMap = files.contains {
            $0.pathExtension == "arworldmap" && $0.lastPathComponent.hasPrefix("TianJiYanXiang-")
        }
    }

    public func loadLatestWorldMap(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let sceneView = sceneView, let baseConfig = activeConfiguration else {
            completion(.failure(ARSpatialSurveyError.sessionUnavailable))
            return
        }
        do {
            let directory = try Self.worldMapDirectory()
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            let latestURL = files
                .filter { $0.pathExtension == "arworldmap" && $0.lastPathComponent.hasPrefix("TianJiYanXiang-") }
                .compactMap { url -> (url: URL, date: Date)? in
                    guard let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate else { return nil }
                    return (url, date)
                }
                .max(by: { $0.date < $1.date })?.url
            guard let mapURL = latestURL else {
                completion(.failure(ARSpatialSurveyError.mapUnavailable))
                return
            }
            let data = try Data(contentsOf: mapURL)
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                completion(.failure(ARSpatialSurveyError.archiveFailed))
                return
            }
            guard let configuration = baseConfig.copy() as? ARWorldTrackingConfiguration else {
                completion(.failure(ARSpatialSurveyError.sessionUnavailable))
                return
            }
            configuration.initialWorldMap = worldMap
            trackingState = .initializing
            mappingState = .extending
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            activeConfiguration = configuration
            completion(.success(mapURL))
        } catch {
            completion(.failure(error))
        }
    }

    public func resetSurvey() {
        start()
    }

    /// Captures the current AR camera frame and a compact snapshot of the
    /// tracking/semantic state. The image and evidence are from one frame so
    /// a later Vision result cannot accidentally use stale spatial metadata.
    public func captureFrame(completion: @escaping (ARCapturedFrame?) -> Void) {
        captureFrame(completion: completion, attempt: 0)
    }

    private func captureFrame(
        completion: @escaping (ARCapturedFrame?) -> Void,
        attempt: Int
    ) {
        guard let frame = sceneView?.session.currentFrame else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        // AVCapturePhotoOutput naturally waits for a new exposure. ARSession's
        // currentFrame is a live pointer, so explicitly wait when a scan asks
        // for the next sample too quickly; otherwise all three "frames" could
        // be the same ARFrame and temporal consensus would be meaningless.
        if frame.timestamp <= lastCapturedTimestamp + 0.04 {
            guard attempt < 8 else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                guard let self = self else { completion(nil); return }
                self.captureFrame(completion: completion, attempt: attempt + 1)
            }
            return
        }
        lastCapturedTimestamp = frame.timestamp
        guard let image = Self.image(from: frame.capturedImage) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let frameTrackingIsNormal: Bool
        switch frame.camera.trackingState {
        case .normal: frameTrackingIsNormal = true
        case .limited(_), .notAvailable: frameTrackingIsNormal = false
        @unknown default: frameTrackingIsNormal = false
        }
        let frameMappingIsUsable: Bool
        switch frame.worldMappingStatus {
        case .extending, .mapped: frameMappingIsUsable = true
        case .notAvailable, .limited: frameMappingIsUsable = false
        @unknown default: frameMappingIsUsable = false
        }
        let depthMap: CVPixelBuffer?
        if #available(iOS 14.0, *), let smoothed = frame.smoothedSceneDepth?.depthMap {
            depthMap = smoothed
        } else {
            depthMap = frame.sceneDepth?.depthMap
        }
        let evidence = ARSceneEvidence(
            trackingIsNormal: frameTrackingIsNormal,
            mappingIsUsable: frameMappingIsUsable,
            lidarAvailable: lidarAvailable,
            depthStreamAvailable: depthMap != nil,
            depthCoverage: Self.depthCoverage(from: depthMap),
            horizontalFOVDegrees: Self.portraitHorizontalFOV(for: frame),
            verticalPlaneCount: frame.anchors
                .compactMap { $0 as? ARPlaneAnchor }
                .filter { $0.alignment == .vertical }
                .count,
            wallFaceCount: Self.wallFaceCount(in: frame.anchors),
            depthSampleMeters: Self.centerDepthSample(from: depthMap),
            leftDepthMeters: Self.regionalDepthSample(from: depthMap, portraitNormX: 0.25, portraitNormY: 0.5),
            rightDepthMeters: Self.regionalDepthSample(from: depthMap, portraitNormX: 0.75, portraitNormY: 0.5),
            topDepthMeters: Self.regionalDepthSample(from: depthMap, portraitNormX: 0.5, portraitNormY: 0.25),
            bottomDepthMeters: Self.regionalDepthSample(from: depthMap, portraitNormX: 0.5, portraitNormY: 0.78),
            timestamp: frame.timestamp
        )
        DispatchQueue.main.async {
            completion(ARCapturedFrame(image: image, evidence: evidence))
        }
    }

    public func pause() {
        sceneView?.session.pause()
    }

    public func resume() {
        guard let sceneView = sceneView, let configuration = activeConfiguration else { return }
        sceneView.session.run(configuration)
    }

    public func saveWorldMap(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let session = sceneView?.session else {
            completion(.failure(ARSpatialSurveyError.sessionUnavailable))
            return
        }
        guard session.currentFrame?.worldMappingStatus == .mapped else {
            completion(.failure(ARSpatialSurveyError.mapUnavailable))
            return
        }

        session.getCurrentWorldMap { worldMap, error in
            DispatchQueue.main.async {
                guard let worldMap = worldMap, error == nil else {
                    completion(.failure(error ?? ARSpatialSurveyError.mapUnavailable))
                    return
                }
                do {
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: worldMap,
                        requiringSecureCoding: false
                    )
                    let name = "TianJiYanXiang-\(UUID().uuidString).arworldmap"
                    let directory = try Self.worldMapDirectory()
                    let url = directory.appendingPathComponent(name)
                    try data.write(to: url, options: .atomic)
                    Self.pruneWorldMapExports(in: directory)
                    self.refreshSavedWorldMapState()
                    completion(.success(url))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    public func stop() {
        sceneView?.session.pause()
        sceneView?.session.delegate = nil
        sceneView?.delegate = nil
        sceneView = nil
        activeConfiguration = nil
        lastMeasurementTimestamp = 0
        lastSemanticUpdateTimestamp = 0
        lastMeshGeometryUpdate.removeAll()
        lastPlaneGeometryUpdate.removeAll()
        distance = nil
        distanceSamples.removeAll(keepingCapacity: true)
        lastCapturedTimestamp = 0
        mappingState = .unavailable
        planeCount = 0
        verticalPlaneCount = 0
        meshAnchorCount = 0
        largestPlaneWidth = nil
        largestPlaneDepth = nil
        semanticCounts = [:]
    }

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Mesh classification and raycasting are deliberately sampled at a
        // bounded rate.
        // ARKit continues tracking at its native rate while the UI avoids a
        // display-link driven redraw and unnecessary device heat.
        guard frame.timestamp - lastMeasurementTimestamp >= 0.2 else { return }
        lastMeasurementTimestamp = frame.timestamp

        let state: ARSpatialTrackingState
        switch frame.camera.trackingState {
        case .normal:
            state = .normal
        case .limited(_):
            state = .limited
        case .notAvailable:
            state = .unavailable
        @unknown default:
            state = .limited
        }

        let currentSceneView = sceneView
        let update: () -> Void = { [weak self, weak currentSceneView] in
            guard let self = self,
                  let sceneView = currentSceneView,
                  self.sceneView === sceneView else { return }
            self.trackingState = state
            self.updateMeasurements(frame: frame, sceneView: sceneView)
        }
        if Thread.isMainThread {
            // ARSession uses the main queue by default. Processing the sample
            // inline avoids retaining several ARFrame objects when SwiftUI is
            // busy laying out the overlay.
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    public func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { [weak self] in
            self?.trackingState = .limited
        }
    }

    public func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async { [weak self] in
            self?.resume()
        }
    }

    public func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.trackingState = .unavailable
        }
    }

    private func updateMeasurements(frame: ARFrame, sceneView: ARSCNView) {
        let anchors = frame.anchors
        switch frame.worldMappingStatus {
        case .notAvailable: mappingState = .unavailable
        case .limited: mappingState = .limited
        case .extending: mappingState = .extending
        case .mapped: mappingState = .mapped
        @unknown default: mappingState = .limited
        }

        let planes = anchors.compactMap { $0 as? ARPlaneAnchor }
        planeCount = planes.count
        verticalPlaneCount = planes.filter { $0.alignment == .vertical }.count
        if let largest = planes.max(by: { $0.extent.x * $0.extent.z < $1.extent.x * $1.extent.z }) {
            largestPlaneWidth = largest.extent.x
            largestPlaneDepth = largest.extent.z
        } else {
            largestPlaneWidth = nil
            largestPlaneDepth = nil
        }

        let center = CGPoint(
            x: sceneView.bounds.width > 0 ? sceneView.bounds.midX : UIScreen.main.bounds.midX,
            y: sceneView.bounds.height > 0 ? sceneView.bounds.midY : UIScreen.main.bounds.midY
        )

        var measuredDistance: Float? = nil

        // 1. 优先使用 LiDAR 硬件直接测距（Time-of-Flight 激光毫米级点测）
        if lidarAvailable {
            let depthMap: CVPixelBuffer?
            if #available(iOS 14.0, *), let smoothed = frame.smoothedSceneDepth?.depthMap {
                depthMap = smoothed
            } else {
                depthMap = frame.sceneDepth?.depthMap
            }
            if let depthVal = Self.centerDepthSample(from: depthMap), depthVal > 0.05, depthVal < 60.0 {
                measuredDistance = depthVal
            }
        }

        // 2. 若无 LiDAR 硬件直接深度或尚未锁定，通过 ARRaycast 进行平面碰撞测距
        if measuredDistance == nil {
            let target: ARRaycastQuery.Target = lidarAvailable ? .existingPlaneGeometry : .estimatedPlane
            let raycastResult = sceneView.raycastQuery(from: center, allowing: target, alignment: .any)
                .flatMap { sceneView.session.raycast($0).first }
                ?? sceneView.raycastQuery(from: center, allowing: .estimatedPlane, alignment: .any)
                    .flatMap { sceneView.session.raycast($0).first }
            if let result = raycastResult {
                let cameraPosition = SIMD3<Float>(
                    frame.camera.transform.columns.3.x,
                    frame.camera.transform.columns.3.y,
                    frame.camera.transform.columns.3.z
                )
                let hitPosition = SIMD3<Float>(
                    result.worldTransform.columns.3.x,
                    result.worldTransform.columns.3.y,
                    result.worldTransform.columns.3.z
                )
                let dist = simd_distance(cameraPosition, hitPosition)
                if dist.isFinite, dist > 0.05, dist < 60.0 {
                    measuredDistance = dist
                }
            }
        }

        if let d = measuredDistance {
            distanceSamples.append(d)
            if distanceSamples.count > 5 {
                distanceSamples.removeFirst()
            }
            distance = distanceSamples.sorted()[distanceSamples.count / 2]
        } else {
            distanceSamples.removeAll(keepingCapacity: true)
            distance = nil
        }

        guard lidarAvailable else {
            semanticCounts = [:]
            return
        }

        // Mesh classification is considerably more expensive than the
        // distance raycast. Keep tracking and distance responsive at 5 Hz,
        // while updating the semantic summary at 2 Hz to avoid traversing
        // thousands of faces on every sample.
        guard frame.timestamp - lastSemanticUpdateTimestamp >= 0.5 else { return }
        lastSemanticUpdateTimestamp = frame.timestamp

        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        meshAnchorCount = meshAnchors.count
        var counts: [Int: Int] = [:]
        var inspectedFaces = 0
        for meshAnchor in meshAnchors {
            let geometry = meshAnchor.geometry
            for faceIndex in 0..<geometry.faces.count {
                // A dense room mesh can contain tens of thousands of faces.
                // A bounded sample is sufficient for a stable category summary.
                if inspectedFaces >= 4000 { break }
                if let classification = classification(in: geometry, faceIndex: faceIndex),
                   classification != .none {
                    counts[classification.rawValue, default: 0] += 1
                }
                inspectedFaces += 1
            }
            if inspectedFaces >= 4000 { break }
        }
        semanticCounts = counts
    }

    private static func image(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        // The app is portrait-only on iPhone; ARKit's camera buffer is
        // landscape-oriented and needs this display orientation for Vision.
        return UIImage(cgImage: cgImage, scale: 1, orientation: .right)
    }

    private static func centerDepthSample(from depthMap: CVPixelBuffer?) -> Float? {
        return regionalDepthSample(from: depthMap, portraitNormX: 0.5, portraitNormY: 0.5)
    }

    /// Samples a median depth in a 3x3 neighborhood around a portrait-normalized
    /// point `(portraitNormX, portraitNormY) in [0, 1]^2`. Because ARKit's camera
    /// and depth buffers are landscape-right oriented while the UI is portrait,
    /// portrait X maps to buffer Y and portrait Y maps to inverted buffer X.
    private static func regionalDepthSample(
        from depthMap: CVPixelBuffer?,
        portraitNormX: Float,
        portraitNormY: Float
    ) -> Float? {
        guard let depthMap = depthMap else { return nil }
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let bufferX = min(width - 1, max(0, Int(Float(width) * (1.0 - portraitNormY))))
        let bufferY = min(height - 1, max(0, Int(Float(height) * portraitNormX)))
        var samples: [Float] = []
        for dy in -1...1 {
            let y = min(height - 1, max(0, bufferY + dy))
            let row = baseAddress.advanced(by: y * bytesPerRow)
                .assumingMemoryBound(to: Float32.self)
            for dx in -1...1 {
                let x = min(width - 1, max(0, bufferX + dx))
                let val = row[x]
                if val.isFinite && val > 0.05 && val < 60.0 {
                    samples.append(val)
                }
            }
        }
        guard !samples.isEmpty else { return nil }
        samples.sort()
        return samples[samples.count / 2]
    }

    private static func depthCoverage(from depthMap: CVPixelBuffer?) -> Float {
        guard let depthMap = depthMap else { return 0 }
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return 0 }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return 0 }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        var valid = 0
        let total = 25
        for rowIndex in 0..<5 {
            let y = min(height - 1, max(0, height * (rowIndex + 1) / 6))
            let row = baseAddress.advanced(by: y * bytesPerRow)
                .assumingMemoryBound(to: Float32.self)
            for columnIndex in 0..<5 {
                let x = min(width - 1, max(0, width * (columnIndex + 1) / 6))
                let value = row[x]
                if value.isFinite && value > 0 { valid += 1 }
            }
        }
        return Float(valid) / Float(total)
    }

    private static func portraitHorizontalFOV(for frame: ARFrame) -> Double? {
        let pixelHeight = Double(CVPixelBufferGetHeight(frame.capturedImage))
        let focalY = Double(frame.camera.intrinsics.columns.1.y)
        guard pixelHeight > 0, focalY > 0 else { return nil }
        // The app is portrait-only. After rotating ARKit's landscape buffer,
        // the portrait horizontal axis corresponds to the sensor's vertical
        // axis, so use fy rather than an arbitrary fixed field of view.
        let radians = 2.0 * atan(pixelHeight / (2.0 * focalY))
        let degrees = radians * 180.0 / .pi
        return degrees.isFinite && degrees >= 20 && degrees <= 120 ? degrees : nil
    }

    private static func wallFaceCount(in anchors: [ARAnchor]) -> Int {
        var count = 0
        var inspectedFaces = 0
        for anchor in anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
            let geometry = meshAnchor.geometry
            for faceIndex in 0..<geometry.faces.count {
                if inspectedFaces >= 2000 { return count }
                if let source = geometry.classification {
                    let byteOffset = source.offset + faceIndex * source.stride
                    guard byteOffset >= 0, byteOffset < source.buffer.length else { continue }
                    let pointer = source.buffer.contents().advanced(by: byteOffset)
                    if Int(pointer.load(as: UInt8.self)) == ARMeshClassification.wall.rawValue {
                        count += 1
                    }
                }
                inspectedFaces += 1
            }
        }
        return count
    }

    // Plane outlines provide immediate visual feedback while ARKit builds the
    // world map. A line material keeps the camera view readable and avoids
    // the heavy translucent surface fill used by many sample applications.
    public func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard rendersSpatialMesh else { return nil }
        if let meshAnchor = anchor as? ARMeshAnchor {
            guard let geometry = meshGeometry(for: meshAnchor) else { return nil }
            let node = SCNNode(geometry: geometry)
            node.name = "ar-spatial-mesh"
            return node
        }
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return nil }
        let node = SCNNode()
        node.geometry = planeGeometry(for: planeAnchor)
        if planeAnchor.alignment == .horizontal {
            node.eulerAngles.x = -.pi / 2
        }
        return node
    }

    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard rendersSpatialMesh else { return }
        if let meshAnchor = anchor as? ARMeshAnchor {
            let now = ProcessInfo.processInfo.systemUptime
            if let last = lastMeshGeometryUpdate[meshAnchor.identifier], now - last < 0.5 {
                return
            }
            lastMeshGeometryUpdate[meshAnchor.identifier] = now
            if let geometry = meshGeometry(for: meshAnchor) {
                node.geometry = geometry
            }
            return
        }
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastPlaneGeometryUpdate[planeAnchor.identifier], now - last < 0.25 {
            return
        }
        lastPlaneGeometryUpdate[planeAnchor.identifier] = now
        node.geometry = planeGeometry(for: planeAnchor)
        if planeAnchor.alignment == .horizontal {
            node.eulerAngles.x = -.pi / 2
        } else {
            node.eulerAngles.x = 0
        }
    }

    private func planeGeometry(for anchor: ARPlaneAnchor) -> SCNGeometry {
        let plane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemTeal.withAlphaComponent(0.75)
        material.fillMode = .lines
        material.isDoubleSided = true
        plane.materials = [material]
        return plane
    }

    private func meshGeometry(for anchor: ARMeshAnchor) -> SCNGeometry? {
        let mesh = anchor.geometry
        guard mesh.vertices.count > 0, mesh.faces.count > 0 else { return nil }

        let vertices = mesh.vertices
        let vertexData = Data(bytes: vertices.buffer.contents(), count: vertices.buffer.length)
        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: vertices.offset,
            dataStride: vertices.stride
        )

        let faces = mesh.faces
        let faceData = Data(bytes: faces.buffer.contents(), count: faces.count * faces.bytesPerIndex)
        let element = SCNGeometryElement(
            data: faceData,
            primitiveType: .triangles,
            primitiveCount: faces.count,
            bytesPerIndex: faces.bytesPerIndex
        )
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = semanticColor(for: mesh)
        material.lightingModel = .constant
        material.fillMode = .lines
        material.isDoubleSided = true
        geometry.materials = [material]
        return geometry
    }

    private func semanticColor(for geometry: ARMeshGeometry) -> UIColor {
        var classCounts: [Int: Int] = [:]
        let sampleCount = min(geometry.faces.count, 240)
        for index in 0..<sampleCount {
            if let classification = classification(in: geometry, faceIndex: index),
               classification != .none {
                classCounts[classification.rawValue, default: 0] += 1
            }
        }
        guard let rawValue = classCounts.max(by: { $0.value < $1.value })?.key,
              let classification = ARMeshClassification(rawValue: rawValue) else {
            return UIColor.systemTeal.withAlphaComponent(0.55)
        }
        switch classification {
        case .wall: return UIColor.systemBlue.withAlphaComponent(0.7)
        case .floor: return UIColor.systemGreen.withAlphaComponent(0.7)
        case .ceiling: return UIColor.systemPurple.withAlphaComponent(0.7)
        case .window: return UIColor(red: 0.0, green: 0.75, blue: 0.85, alpha: 0.8)
        case .door: return UIColor.systemOrange.withAlphaComponent(0.8)
        case .table, .seat: return UIColor.systemYellow.withAlphaComponent(0.8)
        default: return UIColor.systemTeal.withAlphaComponent(0.55)
        }
    }

    /// Reads one byte from ARKit's per-face classification source. The source
    /// uses its own offset and stride, so indexing it as a tightly packed
    /// array would produce incorrect labels on SDK/device combinations that
    /// add padding between entries.
    private func classification(in geometry: ARMeshGeometry, faceIndex: Int) -> ARMeshClassification? {
        guard faceIndex >= 0,
              faceIndex < geometry.faces.count,
              let source = geometry.classification else {
            return nil
        }
        let byteOffset = source.offset + faceIndex * source.stride
        guard byteOffset >= 0,
              byteOffset < source.buffer.length else {
            return nil
        }
        let pointer = source.buffer.contents().advanced(by: byteOffset)
        return ARMeshClassification(rawValue: Int(pointer.load(as: UInt8.self)))
    }
}

public struct ARSpatialPreviewView: UIViewRepresentable {
    @ObservedObject private var model: ARSpatialSurveyModel

    public init(model: ARSpatialSurveyModel) {
        self.model = model
    }

    public func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = false
        view.rendersMotionBlur = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .none
        model.attach(to: view)
        model.start()
        return view
    }

    public func updateUIView(_ uiView: ARSCNView, context: Context) {}

    public static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
    }
}

/// Lightweight ARKit camera surface used by the live Sha scan. It shares the
/// same tracking/mesh model as the spatial survey, but only exposes captured
/// frames to the caller and keeps the AR overlay in SwiftUI.
public struct ARFusionCaptureView: UIViewRepresentable {
    @ObservedObject private var model: ARSpatialSurveyModel
    public let isActive: Bool
    public let captureTrigger: Int
    public let onFrameCaptured: ((ARCapturedFrame?) -> Void)?

    public init(
        model: ARSpatialSurveyModel,
        isActive: Bool = true,
        captureTrigger: Int = 0,
        onFrameCaptured: ((ARCapturedFrame?) -> Void)? = nil
    ) {
        self.model = model
        self.isActive = isActive
        self.captureTrigger = captureTrigger
        self.onFrameCaptured = onFrameCaptured
    }

    public func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = false
        view.rendersMotionBlur = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .none
        // The live scan only needs tracking, depth and semantic counts. Avoid
        // drawing the full classified mesh here; the dedicated spatial survey
        // screen remains responsible for that heavier visualization.
        model.attach(to: view, renderMesh: false)
        if isActive { model.start() }
        return view
    }

    public func updateUIView(_ uiView: ARSCNView, context: Context) {
        if !isActive {
            if context.coordinator.lastActive {
                context.coordinator.lastActive = false
                model.pause()
            }
            return
        }
        if !context.coordinator.lastActive {
            context.coordinator.lastActive = true
            model.resume()
        }
        if context.coordinator.lastCaptureTrigger != captureTrigger {
            context.coordinator.lastCaptureTrigger = captureTrigger
            model.captureFrame { frame in
                onFrameCaptured?(frame)
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(isActive: isActive, captureTrigger: captureTrigger)
    }

    public final class Coordinator {
        var lastActive: Bool
        var lastCaptureTrigger: Int
        init(isActive: Bool, captureTrigger: Int) {
            self.lastActive = isActive
            self.lastCaptureTrigger = captureTrigger
        }
    }

    public static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }
}

private struct ARSpatialShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ARSpatialShareSheet: UIViewControllerRepresentable {
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

/// ARKit powered room survey.  On devices without ARWorldTracking support it
/// keeps the camera based AR experience available and explains the limitation.
public struct ARSpatialSurveyView: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @StateObject private var model = ARSpatialSurveyModel()
    @Environment(\.presentationMode) private var presentationMode
    @State private var isSavingMap = false
    @State private var shareItem: ARSpatialShareItem?
    @State private var saveMessage: String?
    @State private var showRoomPlan = false

    private static let semanticTypes: [(ARMeshClassification, String, String)] = [
        (.wall, "ar_spatial_wall", "rectangle.portrait"),
        (.floor, "ar_spatial_floor", "square"),
        (.ceiling, "ar_spatial_ceiling", "rectangle"),
        (.window, "ar_spatial_window", "window.vertical.open"),
        (.door, "ar_spatial_door", "door.left.hand.open"),
        (.table, "ar_spatial_table", "table.furniture"),
        (.seat, "ar_spatial_seat", "chair"),
    ]

    public init() {}

    public var body: some View {
        ZStack {
            if ARWorldTrackingConfiguration.isSupported {
                ARSpatialPreviewView(model: model)
                    .ignoresSafeArea()
                centerReticle
            } else {
                CameraPreviewView(isActive: true)
                    .ignoresSafeArea()
                unsupportedOverlay
            }

            VStack(spacing: 0) {
                header
                Spacer()
                measurementPanel
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(Color.black.ignoresSafeArea())
        .onDisappear {
            // Presenting RoomPlan can make the covered view temporarily
            // disappear. Keep the model attached in that case so closing the
            // full-screen capture can resume the same spatial session.
            if !showRoomPlan {
                model.stop()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // ARSCNView does not guarantee that an active session is paused
            // before the app is backgrounded. Stop frame delivery explicitly
            // so the camera/LiDAR cannot continue consuming power while the
            // user is away from the survey.
            model.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Resume only when the survey is still presented. If it was
            // dismissed while the app was backgrounded, stop() cleared the
            // configuration and this call safely becomes a no-op. RoomPlan
            // owns the camera while its full-screen capture is presented, so
            // never resume the spatial session underneath that screen.
            if !showRoomPlan {
                model.resume()
            }
        }
#if canImport(RoomPlan)
        .onChange(of: showRoomPlan) { isPresented in
            if isPresented {
                model.pause()
            } else {
                model.resume()
            }
        }
#endif
#if canImport(RoomPlan)
        .fullScreenCover(isPresented: $showRoomPlan) {
            if #available(iOS 16.0, *) {
                ARRoomPlanSurveyView()
            }
        }
#endif
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("ar_spatial_survey"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(model.lidarAvailable ? lang.t("ar_spatial_lidar_available") : lang.t("ar_spatial_lidar_unavailable"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(model.lidarAvailable ? .green : .orange)
            }
            Spacer()
#if canImport(RoomPlan)
            if #available(iOS 16.0, *),
               ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                Button(action: {
                    model.pause()
                    showRoomPlan = true
                }) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(9)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(Circle())
                }
                .accessibilityLabel(lang.t("ar_roomplan_title"))
            }
#endif
            Button(action: {
                saveMessage = nil
                model.resetSurvey()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(9)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .accessibilityLabel(lang.t("ar_spatial_reset"))
            if model.hasSavedWorldMap {
                Button(action: restoreLatestMap) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.yanCyan)
                        .padding(9)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .disabled(isSavingMap)
                .accessibilityLabel(lang.t("ar_spatial_map_ready"))
            }
            Button(action: saveMap) {
                Image(systemName: isSavingMap ? "hourglass" : "square.and.arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSavingMap ? .orange : .white)
                    .padding(9)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .disabled(isSavingMap)
            .accessibilityLabel(lang.t("ar_spatial_save_map"))
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(9)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .accessibilityLabel(lang.t("ar_spatial_close"))
        }
        .padding(10)
        .background(Color.black.opacity(0.68))
        .cornerRadius(12)
    }

    private var centerReticle: some View {
        ZStack {
            Circle().stroke(Color.yanCyan.opacity(0.9), lineWidth: 1.5).frame(width: 46, height: 46)
            Rectangle().fill(Color.yanCyan).frame(width: 1, height: 68)
            Rectangle().fill(Color.yanCyan).frame(width: 68, height: 1)
        }
        .allowsHitTesting(false)
    }

    private var measurementPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(trackingText, systemImage: trackingIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(trackingColor)
                Spacer()
                Text("\(lang.t("ar_spatial_planes")): \(model.planeCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }

            HStack(spacing: 12) {
                Label(mappingText, systemImage: "map")
                if model.lidarAvailable {
                    Text("\(lang.t("ar_spatial_mesh")): \(model.meshAnchorCount)")
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.75))

            HStack {
                Image(systemName: "ruler")
                    .foregroundColor(.yanCyan)
                if let distance = model.distance {
                    Text("\(lang.t("ar_spatial_distance")): \(String(format: "%.2f", distance)) m")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text(lang.t("ar_spatial_measure"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
            }
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(.white)

            if let width = model.largestPlaneWidth, let depth = model.largestPlaneDepth {
                Text("\(lang.t("ar_spatial_largest_plane")): \(String(format: "%.2f × %.2f m", width, depth))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if model.lidarAvailable {
                Text(lang.t("ar_spatial_semantic_candidate"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                    ForEach(Array(Self.semanticTypes.enumerated()), id: \.offset) { entry in
                        let item = entry.element
                        let count = model.semanticCounts[item.0.rawValue, default: 0]
                        if count > 0 {
                            Label("\(lang.t(item.1)) \(count)", systemImage: item.2)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                }
            } else {
                Text(lang.t("ar_spatial_no_depth"))
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.9))
            }
            if let saveMessage = saveMessage {
                Text(saveMessage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.yanCyan)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.78))
        .cornerRadius(12)
        .sheet(item: $shareItem) { item in
            ARSpatialShareSheet(items: [item.url])
        }
    }

    private func saveMap() {
        guard !isSavingMap else { return }
        isSavingMap = true
        saveMessage = lang.t("ar_spatial_saving")
        model.saveWorldMap { result in
            isSavingMap = false
            switch result {
            case .success(let url):
                saveMessage = lang.t("ar_spatial_map_ready")
                shareItem = ARSpatialShareItem(url: url)
            case .failure(let error):
                if let spatialError = error as? ARSpatialSurveyError,
                   spatialError == .mapUnavailable {
                    saveMessage = lang.t("ar_spatial_mapping_not_ready")
                } else {
                    saveMessage = lang.t("ar_spatial_save_failed")
                }
            }
        }
    }

    private func restoreLatestMap() {
        guard !isSavingMap else { return }
        model.loadLatestWorldMap { result in
            switch result {
            case .success:
                saveMessage = lang.t("ar_spatial_map_ready")
            case .failure:
                saveMessage = lang.t("ar_spatial_save_failed")
            }
        }
    }

    private var trackingText: String {
        switch model.trackingState {
        case .normal: return lang.t("ar_spatial_tracking_normal")
        case .limited: return lang.t("ar_spatial_tracking_limited")
        case .unavailable: return lang.t("ar_spatial_tracking_unavailable")
        case .initializing: return lang.t("ar_spatial_tracking_initializing")
        }
    }

    private var mappingText: String {
        switch model.mappingState {
        case .mapped: return lang.t("ar_spatial_mapping_mapped")
        case .extending: return lang.t("ar_spatial_mapping_extending")
        case .limited: return lang.t("ar_spatial_mapping_limited")
        case .unavailable: return lang.t("ar_spatial_mapping_unavailable")
        }
    }

    private var trackingIcon: String {
        switch model.trackingState {
        case .normal: return "checkmark.circle.fill"
        case .limited: return "exclamationmark.triangle.fill"
        case .unavailable: return "xmark.octagon.fill"
        case .initializing: return "location.north.line"
        }
    }

    private var trackingColor: Color {
        switch model.trackingState {
        case .normal: return .green
        case .limited, .initializing: return .orange
        case .unavailable: return .red
        }
    }

    private var unsupportedOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "arkit")
                .font(.system(size: 42))
                .foregroundColor(.yanCyan)
            Text(lang.t("ar_spatial_no_ar"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(lang.t("ar_spatial_camera_fallback"))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color.black.opacity(0.72))
        .cornerRadius(14)
        .padding(24)
    }
}
