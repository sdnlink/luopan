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
            completion(.failure(AnalysisError.invalidImage))
            return
        }
        let orientation = Self.cgOrientation(for: image.imageOrientation)
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNDetectRectanglesRequest()
            request.maximumObservations = 20
            request.minimumConfidence = 0.25
            request.minimumAspectRatio = 0.03
            request.maximumAspectRatio = 1.0
            request.quadratureTolerance = 30.0
            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                try handler.perform([request])
                let regions = (request.results as? [VNRectangleObservation]) ?? []
                guard let result = Self.classify(regions) else {
                    DispatchQueue.main.async { completion(.failure(AnalysisError.noDetectableRegion)) }
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
        guard let region = regions.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else {
            // A no-detection frame must not be presented as a low-confidence
            // Fire Shape result; that would turn “no evidence” into a
            // potentially alarming on-site diagnosis.
            return nil
        }
        let box = region.boundingBox
        let area = box.width * box.height
        // Ignore tiny edge artifacts returned by rectangle detection. They
        // are not a usable scene region and otherwise get promoted to a
        // confident-looking Sha diagnosis.
        guard area >= 0.01, region.confidence >= 0.25 else { return nil }
        let aspect = max(box.width, box.height) / max(0.001, min(box.width, box.height))
        let centerX = box.midX
        let centerY = box.midY
        let id: String
        // Narrow vertical gap between structures.
        if aspect > 3.0 && box.width < 0.28 && centerX > 0.25 && centerX < 0.75 {
            id = "tianzhan"
        // Long low region near the lower edge: road/water/bridge signature.
        } else if box.width > box.height * 2.2 && centerY < 0.48 {
            id = "gejiao"
        // Strong right-side mass suggests the right building is higher.
        } else if centerX > 0.68 && area > 0.12 {
            id = "baihu"
        // A small upper-corner region is consistent with a peeking roof/corner.
        } else if area < 0.12 && centerY > 0.68 {
            id = "tantou"
        // A broad central obstruction is the most conservative road/axis result.
        } else if area > 0.35 {
            id = "luchong"
        } else {
            id = "huoxing"
        }
        let confidence = min(0.98, max(0.35, 0.42 + Double(region.confidence) * 0.30 + min(area, 0.5) * 0.35))
        return ShaAnalysisResult(
            shaID: id,
            confidence: confidence,
            targetX: centerX,
            targetY: 1.0 - centerY,
            detectedRegions: regions.count,
            summary: "vision-rectangles"
        )
    }

    public enum AnalysisError: LocalizedError {
        case invalidImage
        case noDetectableRegion
        public var errorDescription: String? {
            switch self {
            case .invalidImage: return "Unable to read the camera image."
            case .noDetectableRegion: return "No clear geometric region was detected. Try pointing at the scene again."
            }
        }
    }
}
