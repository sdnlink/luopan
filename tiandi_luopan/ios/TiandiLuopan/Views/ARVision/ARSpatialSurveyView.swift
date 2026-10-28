import SwiftUI
import ARKit
import SceneKit
import simd

/// The tracking state is kept separate from presentation text so that the
/// survey can be localized without making the AR session depend on UI state.
public enum ARSpatialTrackingState: Equatable {
    case unavailable
    case initializing
    case normal
    case limited
}

/// Owns one AR session and throttles expensive mesh and raycast work.  The
/// existing camera based AR screen and this object are never active together.
public final class ARSpatialSurveyModel: NSObject, ObservableObject, ARSessionDelegate, ARSCNViewDelegate {
    @Published public private(set) var trackingState: ARSpatialTrackingState = .initializing
    @Published public private(set) var planeCount: Int = 0
    @Published public private(set) var distance: Float?
    // Use raw values as keys because ARMeshClassification is imported from an
    // Objective-C enum and is not Hashable on every iOS SDK generation.
    @Published public private(set) var semanticCounts: [Int: Int] = [:]
    @Published public private(set) var lidarAvailable = false

    private weak var sceneView: ARSCNView?
    private var lastMeasurementTimestamp: TimeInterval = 0

    public func attach(to sceneView: ARSCNView) {
        self.sceneView = sceneView
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
        lidarAvailable = false

        if #available(iOS 13.4, *),
           ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
            lidarAvailable = true
        }

        if #available(iOS 13.4, *),
           ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        trackingState = .initializing
        lastMeasurementTimestamp = 0
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    public func stop() {
        sceneView?.session.pause()
        sceneView?.session.delegate = nil
        sceneView?.delegate = nil
        sceneView = nil
        distance = nil
        planeCount = 0
        semanticCounts = [:]
    }

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Mesh classification and raycasting are deliberately sampled at 5 Hz.
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
        DispatchQueue.main.async { [weak self, weak currentSceneView] in
            guard let self = self, let sceneView = currentSceneView else { return }
            self.trackingState = state
            self.updateMeasurements(frame: frame, sceneView: sceneView)
        }
    }

    public func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { [weak self] in
            self?.trackingState = .limited
        }
    }

    public func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    public func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.trackingState = .unavailable
        }
    }

    private func updateMeasurements(frame: ARFrame, sceneView: ARSCNView) {
        let anchors = frame.anchors
        planeCount = anchors.reduce(into: 0) { count, anchor in
            if anchor is ARPlaneAnchor { count += 1 }
        }

        if let query = sceneView.raycastQuery(
            from: CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY),
            allowing: .estimatedPlane,
            alignment: .any
        ), let result = sceneView.session.raycast(query).first {
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
            distance = simd_distance(cameraPosition, hitPosition)
        } else {
            distance = nil
        }

        guard lidarAvailable else {
            semanticCounts = [:]
            return
        }

        var counts: [Int: Int] = [:]
        var inspectedFaces = 0
        for meshAnchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
            let geometry = meshAnchor.geometry
            for faceIndex in 0..<geometry.faceCount {
                // A dense room mesh can contain tens of thousands of faces.
                // A bounded sample is sufficient for a stable category summary.
                if inspectedFaces >= 4000 { break }
                let classification = geometry.classificationOf(faceWithIndex: faceIndex)
                if classification != .none {
                    counts[classification.rawValue, default: 0] += 1
                }
                inspectedFaces += 1
            }
            if inspectedFaces >= 4000 { break }
        }
        semanticCounts = counts
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

/// ARKit powered room survey.  On devices without ARWorldTracking support it
/// keeps the camera based AR experience available and explains the limitation.
public struct ARSpatialSurveyView: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @StateObject private var model = ARSpatialSurveyModel()
    @Environment(\.presentationMode) private var presentationMode

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
        .onDisappear { model.stop() }
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

            HStack {
                Image(systemName: "ruler")
                    .foregroundColor(.yanCyan)
                if let distance = model.distance {
                    Text("\(lang.t("ar_spatial_distance")): \(String(format: "%.2f", distance)) m")
                } else {
                    Text(lang.t("ar_spatial_measure"))
                }
                Spacer()
            }
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(.white)

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

    // Plane outlines provide immediate visual feedback while ARKit builds the
    // world map.  A line material keeps the camera view readable and avoids
    // the heavy translucent surface fill used by many sample applications.
    public func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return nil }
        let node = SCNNode()
        node.geometry = planeGeometry(for: planeAnchor)
        if planeAnchor.alignment == .horizontal {
            node.eulerAngles.x = -.pi / 2
        }
        return node
    }

    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
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
                }
            } else {
                Text(lang.t("ar_spatial_no_depth"))
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.9))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.78))
        .cornerRadius(12)
    }

    private var trackingText: String {
        switch model.trackingState {
        case .normal: return lang.t("ar_spatial_tracking_normal")
        case .limited: return lang.t("ar_spatial_tracking_limited")
        case .unavailable: return lang.t("ar_spatial_tracking_unavailable")
        case .initializing: return lang.t("ar_spatial_tracking_initializing")
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
