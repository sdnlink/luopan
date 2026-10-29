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
}

public final class OnDeviceShaAnalyzer {
    public static let shared = OnDeviceShaAnalyzer()
    private init() {}

    public func analyze(image: UIImage, completion: @escaping (Result<ShaAnalysisResult, Error>) -> Void) {
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
            let request = VNDetectRectanglesRequest()
            request.maximumObservations = 20
            request.minimumConfidence = 0.25
            request.minimumAspectRatio = 0.03
            request.maximumAspectRatio = 1.0
            request.quadratureTolerance = 30.0
            do {
                let handlerOrientation: CGImagePropertyOrientation = analysisImage === image ? orientation : .up
                let handler = VNImageRequestHandler(cgImage: analysisCGImage, orientation: handlerOrientation, options: [:])
                try handler.perform([request])
                let regions = (request.results as? [VNRectangleObservation]) ?? []
                guard let result = Self.classify(regions) else {
                    let error: AnalysisError = regions.isEmpty ? .noDetectableRegion : .ambiguousRegion
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
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

    private static func classify(_ regions: [VNRectangleObservation]) -> ShaAnalysisResult? {
        // VNDetectRectanglesRequest finds edges, not objects. A single
        // rectangle cannot tell a road from a floor, a window from a wall, or
        // a tower gap from a door. Reject the common full-frame and low
        // confidence detections instead of turning them into a dramatic Sha
        // diagnosis.
        let usable = regions.filter { region in
            let box = region.boundingBox
            let area = box.width * box.height
            let touchesWholeFrame = box.minX < 0.02 && box.minY < 0.02 && box.maxX > 0.98 && box.maxY > 0.98
            return region.confidence >= 0.55 && area >= 0.025 && area <= 0.55 && !touchesWholeFrame
        }
        guard usable.count >= 2 else { return nil }

        // Only report a possible Tian Zhan when two independently detected,
        // tall structures flank the same central gap. The previous classifier
        // labelled any narrow object (including a door or a lamp post) as this
        // severe Sha. A paired observation is a much safer minimum signal.
        let tall = usable.filter { region in
            let box = region.boundingBox
            let aspect = max(box.width, box.height) / max(0.001, min(box.width, box.height))
            return aspect >= 3.2 && box.width <= 0.24 && box.height >= 0.18 && box.midX > 0.08 && box.midX < 0.92
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
                guard separation >= 0.20, separation <= 0.78 else { continue }
                let overlap = min(leftBox.maxY, rightBox.maxY) - max(leftBox.minY, rightBox.minY)
                guard overlap >= 0.12 else { continue }
                let centralGap = 1.0 - min(1.0, separation)
                let score = Double(left.confidence + right.confidence) * 0.325 +
                    Double(min(leftBox.height, rightBox.height)) * 0.20 +
                    (1.0 - centralGap) * 0.15
                if score > bestPairScore {
                    bestPairScore = score
                    selectedPair = (left, right)
                }
            }
        }
        guard let pair = selectedPair else { return nil }
        let leftBox = pair.0.boundingBox
        let rightBox = pair.1.boundingBox
        let targetX = (leftBox.midX + rightBox.midX) * 0.5
        let targetY = 1.0 - ((leftBox.midY + rightBox.midY) * 0.5)
        let confidence = min(0.90, max(0.60, bestPairScore))
        return ShaAnalysisResult(
            shaID: "tianzhan",
            confidence: confidence,
            targetX: Double(targetX),
            targetY: Double(targetY),
            detectedRegions: usable.count,
            summary: "paired-vertical-structures"
        )
    }

    public enum AnalysisError: LocalizedError {
        case invalidImage
        case noDetectableRegion
        case ambiguousRegion
        public var errorDescription: String? {
            let lang = LocalizationManager.shared
            switch self {
            case .invalidImage: return lang.t("ar_ai_no_frame")
            case .noDetectableRegion: return lang.t("ar_ai_no_region")
            case .ambiguousRegion: return lang.t("ar_ai_ambiguous")
            }
        }
    }
}
