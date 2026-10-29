import Foundation
import UIKit
import Vision
import ImageIO

/// Result of the on-device visual scan. The scan is deliberately local: no
/// image leaves the device and no network/API key is required.
public struct ShaAnalysisResult {
    public let shaID: String
    public let confidence: Double
    public let targetX: Double
    public let targetY: Double
    public let detectedRegions: Int
    public let summary: String
    public let horizontalFOVDegrees: Double?
}

public final class OnDeviceShaAnalyzer {
    public static let shared = OnDeviceShaAnalyzer()
    private init() {}

    public func analyze(
        image: UIImage,
        evidence: ARSceneEvidence? = nil,
        completion: @escaping (Result<ShaAnalysisResult, Error>) -> Void
    ) {
        if let evidence = evidence {
            guard evidence.trackingIsNormal else {
                DispatchQueue.main.async { completion(.failure(AnalysisError.arTrackingLimited)) }
                return
            }
            if evidence.lidarAvailable &&
                (!evidence.depthStreamAvailable || evidence.depthCoverage < 0.15) {
                DispatchQueue.main.async { completion(.failure(AnalysisError.arDepthUnavailable)) }
                return
            }
            let hasSpatialStructure = evidence.mappingIsUsable ||
                evidence.verticalPlaneCount > 0 || evidence.wallFaceCount > 0
            if !hasSpatialStructure {
                DispatchQueue.main.async { completion(.failure(AnalysisError.arSceneUnmapped)) }
                return
            }
        }
        guard let cgImage = image.cgImage else {
            DispatchQueue.main.async {
                completion(.failure(AnalysisError.invalidImage))
            }
            return
        }
        let orientation = Self.cgOrientation(for: image.imageOrientation)
        DispatchQueue.global(qos: .userInitiated).async {
            // Still capture output can be several megapixels even when the
            // preview session is 720p. Rectangle detection does not need that
            // resolution; downsample before Vision to reduce peak memory and
            // CPU/GPU work during an AI scan.
            let analysisImage: UIImage
            let maxDimension = 1280.0
            if max(CGFloat(cgImage.width), CGFloat(cgImage.height)) > maxDimension {
                let scale = maxDimension / max(CGFloat(cgImage.width), CGFloat(cgImage.height))
                let targetSize = CGSize(
                    width: CGFloat(cgImage.width) * scale,
                    height: CGFloat(cgImage.height) * scale
                )
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
                analysisImage = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: targetSize))
                }
            } else {
                analysisImage = image
            }
            guard let analysisCGImage = analysisImage.cgImage else {
                DispatchQueue.main.async { completion(.failure(AnalysisError.invalidImage)) }
                return
            }
            do {
                let handlerOrientation: CGImagePropertyOrientation = analysisImage === image ? orientation : .up

                // A single rectangle pass is too sensitive to thresholds and
                // perspective. Run two deliberately different passes and
                // require the same pair to survive both. This is still local
                // and lightweight, but prevents one lucky edge detection from
                // being presented as a scene judgement.
                let relaxedRegions = try Self.detectRegions(
                    cgImage: analysisCGImage,
                    orientation: handlerOrientation,
                    minimumConfidence: 0.45,
                    quadratureTolerance: 25.0
                )
                let strictRegions = try Self.detectRegions(
                    cgImage: analysisCGImage,
                    orientation: handlerOrientation,
                    minimumConfidence: 0.70,
                    quadratureTolerance: 18.0
                )
                guard let relaxed = Self.classify(relaxedRegions, minimumConfidence: 0.60),
                      let strict = Self.classify(strictRegions, minimumConfidence: 0.68),
                      Self.isConsistent(relaxed, strict) else {
                    let hasRegions = !relaxedRegions.isEmpty || !strictRegions.isEmpty
                    let error: AnalysisError = hasRegions ? .ambiguousRegion : .noDetectableRegion
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                let spatialBonus: Double
                if let evidence = evidence {
                    // Semantic walls/vertical planes strengthen the geometry
                    // candidate, but never create one by themselves.
                    spatialBonus = (evidence.wallFaceCount > 0 || evidence.verticalPlaneCount > 0) ? 0.03 : 0
                } else {
                    spatialBonus = 0
                }
                let result = ShaAnalysisResult(
                    shaID: relaxed.shaID,
                    confidence: min(0.95, (relaxed.confidence + strict.confidence) * 0.5 + spatialBonus),
                    targetX: (relaxed.targetX + strict.targetX) * 0.5,
                    targetY: (relaxed.targetY + strict.targetY) * 0.5,
                    detectedRegions: min(relaxed.detectedRegions, strict.detectedRegions),
                    summary: "multi-pass-paired-vertical-structures",
                    horizontalFOVDegrees: evidence?.horizontalFOVDegrees
                )
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    private static func detectRegions(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        minimumConfidence: Float,
        quadratureTolerance: Float
    ) throws -> [VNRectangleObservation] {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 24
        request.minimumConfidence = minimumConfidence
        request.minimumAspectRatio = 0.04
        request.maximumAspectRatio = 1.0
        request.quadratureTolerance = quadratureTolerance
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])
        return (request.results as? [VNRectangleObservation]) ?? []
    }

    private static func cgOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private static func classify(
        _ regions: [VNRectangleObservation],
        minimumConfidence: Float
    ) -> ShaAnalysisResult? {
        // VNDetectRectanglesRequest finds edges, not objects. A single
        // rectangle cannot tell a road from a floor, a window from a wall, or
        // a tower gap from a door. Reject the common full-frame and low
        // confidence detections instead of turning them into a dramatic Sha
        // diagnosis.
        let usable = regions.filter { region in
            let box = region.boundingBox
            let area = box.width * box.height
            let touchesWholeFrame = box.minX < 0.02 && box.minY < 0.02 && box.maxX > 0.98 && box.maxY > 0.98
            return region.confidence >= minimumConfidence && area >= 0.025 && area <= 0.45 && !touchesWholeFrame
        }
        guard usable.count >= 2 else { return nil }

        // Only report a possible Tian Zhan when two independently detected,
        // tall structures flank the same central gap. The previous classifier
        // labelled any narrow object (including a door or a lamp post) as this
        // severe Sha. A paired observation is a much safer minimum signal.
        let tall = usable.filter { region in
            let box = region.boundingBox
            let aspect = max(box.width, box.height) / max(0.001, min(box.width, box.height))
            let verticality = Self.verticality(of: region)
            return aspect >= 4.0 && box.width <= 0.22 && box.height >= 0.28 &&
                verticality >= 0.90 && box.midX > 0.08 && box.midX < 0.92
        }
        var selectedPair: (VNRectangleObservation, VNRectangleObservation)?
        var bestPairScore = -Double.infinity
        for leftIndex in 0..<tall.count {
            for rightIndex in (leftIndex + 1)..<tall.count {
                let left = tall[leftIndex]
                let right = tall[rightIndex]
                let leftBox = left.boundingBox
                let rightBox = right.boundingBox
                guard leftBox.midX < 0.5, rightBox.midX > 0.5 else { continue }
                let separation = rightBox.midX - leftBox.midX
                let gap = rightBox.minX - leftBox.maxX
                guard separation >= 0.24, separation <= 0.78,
                      gap >= 0.08, gap <= 0.45 else { continue }
                let overlap = min(leftBox.maxY, rightBox.maxY) - max(leftBox.minY, rightBox.minY)
                let baselineDelta = abs(leftBox.minY - rightBox.minY)
                let heightRatio = min(leftBox.height, rightBox.height) / max(leftBox.height, rightBox.height)
                guard overlap >= 0.28, baselineDelta <= 0.18, heightRatio >= 0.55 else { continue }

                // A candidate must look like two comparable vertical masses
                // with a real gap, rather than two unrelated narrow objects.
                let confidence = Double(left.confidence + right.confidence) * 0.5
                let heightScore = min(1.0, Double(min(leftBox.height, rightBox.height)) / 0.55)
                let verticalScore = (Self.verticality(of: left) + Self.verticality(of: right)) * 0.5
                let gapScore = min(1.0, max(0.0, Double(gap - 0.08) / 0.22))
                let score = confidence * 0.45 + heightScore * 0.25 + verticalScore * 0.20 + gapScore * 0.10
                if score > bestPairScore {
                    bestPairScore = score
                    selectedPair = (left, right)
                }
            }
        }
        guard let pair = selectedPair, bestPairScore >= 0.72 else { return nil }
        let leftBox = pair.0.boundingBox
        let rightBox = pair.1.boundingBox
        let targetX = (leftBox.midX + rightBox.midX) * 0.5
        let targetY = 1.0 - ((leftBox.midY + rightBox.midY) * 0.5)
        let confidence = min(0.95, max(0.72, bestPairScore))
        return ShaAnalysisResult(
            shaID: "tianzhan",
            confidence: confidence,
            targetX: Double(targetX),
            targetY: Double(targetY),
            detectedRegions: usable.count,
            summary: "paired-vertical-structures",
            horizontalFOVDegrees: nil
        )
    }

    private static func verticality(of region: VNRectangleObservation) -> Double {
        func sideScore(_ a: CGPoint, _ b: CGPoint) -> Double {
            let dx = Double(b.x - a.x)
            let dy = Double(b.y - a.y)
            let length = hypot(dx, dy)
            guard length > 0 else { return 0 }
            return abs(dy) / length
        }
        let left = sideScore(region.bottomLeft, region.topLeft)
        let right = sideScore(region.bottomRight, region.topRight)
        return (left + right) * 0.5
    }

    private static func isConsistent(_ first: ShaAnalysisResult, _ second: ShaAnalysisResult) -> Bool {
        // The two detector passes must point to almost the same physical gap.
        // A loose threshold tolerates small Vision changes while rejecting
        // unrelated rectangles returned by different thresholds.
        let dx = first.targetX - second.targetX
        let dy = first.targetY - second.targetY
        return hypot(dx, dy) <= 0.10 && abs(first.confidence - second.confidence) <= 0.18
    }

    public enum AnalysisError: LocalizedError {
        case invalidImage
        case noDetectableRegion
        case ambiguousRegion
        case arTrackingLimited
        case arDepthUnavailable
        case arSceneUnmapped
        public var errorDescription: String? {
            let lang = LocalizationManager.shared
            switch self {
            case .invalidImage: return lang.t("ar_ai_no_frame")
            case .noDetectableRegion: return lang.t("ar_ai_no_region")
            case .ambiguousRegion: return lang.t("ar_ai_ambiguous")
            case .arTrackingLimited: return lang.t("ar_ai_tracking_limited")
            case .arDepthUnavailable: return lang.t("ar_ai_depth_unavailable")
            case .arSceneUnmapped: return lang.t("ar_ai_scene_unmapped")
            }
        }
    }
}
