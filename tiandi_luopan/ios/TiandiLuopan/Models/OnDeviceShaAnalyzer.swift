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
        // When AR evidence is available, validate tracking and LiDAR depth
        // quality first, then fuse 3D depth topology into the classifier.
        if let evidence = evidence {
            if !evidence.trackingIsNormal && !evidence.mappingIsUsable {
                DispatchQueue.main.async {
                    completion(.failure(AnalysisError.arTrackingLimited))
                }
                return
            }
            if evidence.lidarAvailable && evidence.depthStreamAvailable && evidence.depthCoverage < 0.08 {
                DispatchQueue.main.async {
                    completion(.failure(AnalysisError.arDepthUnavailable))
                }
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
                let relaxedRect = Self.classify(relaxedRegions, minimumConfidence: 0.60, evidence: evidence)
                let strictRect = Self.classify(strictRegions, minimumConfidence: 0.68, evidence: evidence)
                let contourA = Self.detectContourCandidate(
                    cgImage: analysisCGImage,
                    orientation: handlerOrientation,
                    contrastAdjustment: 1.4,
                    evidence: evidence
                )
                let contourB = Self.detectContourCandidate(
                    cgImage: analysisCGImage,
                    orientation: handlerOrientation,
                    contrastAdjustment: 2.0,
                    evidence: evidence
                )

                let primaryA: ShaAnalysisResult?
                let primaryB: ShaAnalysisResult?
                if let r = relaxedRect, let s = strictRect, Self.isConsistent(r, s) {
                    primaryA = r
                    primaryB = s
                } else if let cA = contourA, let cB = contourB, Self.isConsistent(cA, cB) {
                    primaryA = cA
                    primaryB = cB
                } else {
                    primaryA = nil
                    primaryB = nil
                }

                guard let relaxed = primaryA, let strict = primaryB else {
                    let hasRegions = !relaxedRegions.isEmpty || !strictRegions.isEmpty || contourA != nil || contourB != nil
                    let error: AnalysisError = hasRegions ? .ambiguousRegion : .noDetectableRegion
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                let contourAgreementBonus = (contourA?.shaID == relaxed.shaID) ? 0.02 : 0.0
                let spatialBonus: Double
                if let evidence = evidence {
                    // Semantic walls/vertical planes and valid LiDAR depth coverage
                    // strengthen the geometry candidate.
                    let meshBonus = (evidence.wallFaceCount > 0 || evidence.verticalPlaneCount > 0) ? 0.03 : 0.0
                    let depthBonus = (evidence.lidarAvailable && evidence.depthCoverage >= 0.40) ? 0.03 : 0.0
                    spatialBonus = meshBonus + depthBonus + contourAgreementBonus
                } else {
                    spatialBonus = contourAgreementBonus
                }
                let result = ShaAnalysisResult(
                    shaID: relaxed.shaID,
                    confidence: min(0.95, (relaxed.confidence + strict.confidence) * 0.5 + spatialBonus),
                    targetX: (relaxed.targetX + strict.targetX) * 0.5,
                    targetY: (relaxed.targetY + strict.targetY) * 0.5,
                    detectedRegions: max(1, min(relaxed.detectedRegions, strict.detectedRegions)),
                    summary: relaxed.summary,
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

    /// Uses `VNDetectContoursRequest` (iOS 14.0+) to detect non-rectangular
    /// architectural silhouettes such as sharp triangular roofs/spires (`huoxing`)
    /// and curved road/overpass arcs (`fangong`) that 4-corner rectangle detection
    /// alone may reject.
    private static func detectContourCandidate(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        contrastAdjustment: Float,
        evidence: ARSceneEvidence?
    ) -> ShaAnalysisResult? {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = contrastAdjustment
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 512
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first as? VNContoursObservation else {
            return nil
        }

        var bestCandidate: ShaAnalysisResult?
        let topCount = min(observation.topLevelContourCount, 18)
        for idx in 0..<topCount {
            guard let contour = try? observation.contour(at: idx),
                  let poly = try? contour.polygonApproximation(epsilon: 0.025) else { continue }
            let pts = poly.normalizedPoints
            guard pts.count >= 3 else { continue }

            var minX: Float = 1.0, maxX: Float = 0.0
            var minY: Float = 1.0, maxY: Float = 0.0
            var arcLength: Double = 0.0
            for i in 0..<pts.count {
                let p = pts[i]
                minX = min(minX, p.x)
                maxX = max(maxX, p.x)
                minY = min(minY, p.y)
                maxY = max(maxY, p.y)
                if i > 0 {
                    let prev = pts[i - 1]
                    arcLength += hypot(Double(p.x - prev.x), Double(p.y - prev.y))
                }
            }
            let width = Double(maxX - minX)
            let height = Double(maxY - minY)
            let area = width * height
            guard area >= 0.025, area <= 0.65 else { continue }

            // (A) Sharp triangular spire / roof corner -> 火形煞 (huoxing)
            if pts.count >= 3 && pts.count <= 5 && height >= 0.18 && Double(minY + maxY) * 0.5 >= 0.35 {
                var minAngleDeg = 180.0
                var apexPoint = pts[0]
                for i in 0..<pts.count {
                    let prev = pts[(i - 1 + pts.count) % pts.count]
                    let curr = pts[i]
                    let next = pts[(i + 1) % pts.count]
                    let v1x = Double(prev.x - curr.x), v1y = Double(prev.y - curr.y)
                    let v2x = Double(next.x - curr.x), v2y = Double(next.y - curr.y)
                    let len1 = hypot(v1x, v1y), len2 = hypot(v2x, v2y)
                    guard len1 > 0.04, len2 > 0.04 else { continue }
                    let cosTheta = max(-1.0, min(1.0, (v1x * v2x + v1y * v2y) / (len1 * len2)))
                    let deg = acos(cosTheta) * 180.0 / .pi
                    if deg < minAngleDeg {
                        minAngleDeg = deg
                        apexPoint = curr
                    }
                }
                if minAngleDeg <= 56.0 {
                    let sharpnessScore = min(1.0, (60.0 - minAngleDeg) / 35.0)
                    let score = min(0.91, 0.72 + sharpnessScore * 0.16)
                    if score > (bestCandidate?.confidence ?? 0) {
                        bestCandidate = ShaAnalysisResult(
                            shaID: "huoxing",
                            confidence: score,
                            targetX: Double(apexPoint.x),
                            targetY: Double(1.0 - apexPoint.y),
                            detectedRegions: topCount,
                            summary: "contour-acute-triangular-apex",
                            horizontalFOVDegrees: evidence?.horizontalFOVDegrees
                        )
                    }
                }
            }

            // (B) Wide curved lower-field arc -> 反弓水 (fangong)
            if pts.count >= 5 && width >= 0.45 && height <= 0.28 && Double(minY + maxY) * 0.5 <= 0.40 {
                let firstPt = pts.first!
                let lastPt = pts.last!
                let chord = hypot(Double(lastPt.x - firstPt.x), Double(lastPt.y - firstPt.y))
                if chord >= 0.38 && arcLength / chord >= 1.15 && arcLength / chord <= 2.10 {
                    let curveBonus = (evidence?.bottomDepthMeters ?? 5.0) <= 3.5 ? 0.04 : 0.0
                    let score = min(0.90, 0.74 + min(0.12, (arcLength / chord - 1.15) * 0.35) + curveBonus)
                    if score > (bestCandidate?.confidence ?? 0) {
                        bestCandidate = ShaAnalysisResult(
                            shaID: "fangong",
                            confidence: score,
                            targetX: Double(minX + maxX) * 0.5,
                            targetY: Double(1.0 - (minY + maxY) * 0.5),
                            detectedRegions: topCount,
                            summary: "contour-curved-bow-arc",
                            horizontalFOVDegrees: evidence?.horizontalFOVDegrees
                        )
                    }
                }
            }
        }
        return bestCandidate
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
        minimumConfidence: Float,
        evidence: ARSceneEvidence? = nil
    ) -> ShaAnalysisResult? {
        let usable = regions.filter { region in
            let box = region.boundingBox
            let area = box.width * box.height
            let touchesWholeFrame = box.minX < 0.02 && box.minY < 0.02 && box.maxX > 0.98 && box.maxY > 0.98
            return region.confidence >= minimumConfidence && area >= 0.020 && area <= 0.65 && !touchesWholeFrame
        }
        guard !usable.isEmpty else { return nil }

        var candidates: [ShaAnalysisResult] = []

        // 1. 天斩煞 (tianzhan) & 白虎煞 (baihu): 成对竖直建筑体量分析 + LiDAR 深度裂缝校验
        let tall = usable.filter { region in
            let box = region.boundingBox
            let aspect = max(box.width, box.height) / max(0.001, min(box.width, box.height))
            let verticality = Self.verticality(of: region)
            return aspect >= 2.2 && box.width <= 0.36 && box.height >= 0.24 &&
                verticality >= 0.85 && box.midX > 0.05 && box.midX < 0.95
        }
        for leftIndex in 0..<tall.count {
            for rightIndex in (leftIndex + 1)..<tall.count {
                let first = tall[leftIndex]
                let second = tall[rightIndex]
                let left = first.boundingBox.midX <= second.boundingBox.midX ? first : second
                let right = first.boundingBox.midX <= second.boundingBox.midX ? second : first
                let leftBox = left.boundingBox
                let rightBox = right.boundingBox
                guard leftBox.midX < 0.52, rightBox.midX > 0.48 else { continue }
                let separation = rightBox.midX - leftBox.midX
                let gap = rightBox.minX - leftBox.maxX
                let overlap = min(leftBox.maxY, rightBox.maxY) - max(leftBox.minY, rightBox.minY)
                let baselineDelta = abs(leftBox.minY - rightBox.minY)
                let heightRatio = min(leftBox.height, rightBox.height) / max(leftBox.height, rightBox.height)

                // (1a) 天斩煞: 左右双高楼夹窄缝，且排斥室内近距离平整门框伪影
                if separation >= 0.24, separation <= 0.78,
                   gap >= 0.06, gap <= 0.45,
                   overlap >= 0.26, baselineDelta <= 0.18, heightRatio >= 0.55,
                   leftBox.width <= 0.24, rightBox.width <= 0.24 {
                    var lidarDepthAdjustment = 0.0
                    var isFlatCloseIndoorSurface = false
                    if let ev = evidence,
                       let centerD = ev.depthSampleMeters,
                       let leftD = ev.leftDepthMeters,
                       let rightD = ev.rightDepthMeters {
                        let flankMean = (leftD + rightD) * 0.5
                        if centerD < 1.8 && flankMean < 1.8 && abs(centerD - flankMean) < 0.12 {
                            // 距离小于 1.8m 且中心与两侧深度几乎处于同一平面（如室内门框或墙饰），拒绝误判为天斩煞
                            isFlatCloseIndoorSurface = true
                        } else if centerD > flankMean + 0.35 || centerD >= 3.5 {
                            // LiDAR 证实中间缝隙深度显著远于两侧立面，或处于远景建筑尺度
                            lidarDepthAdjustment = 0.05
                        }
                    }
                    if !isFlatCloseIndoorSurface {
                        let confidence = Double(left.confidence + right.confidence) * 0.5
                        let heightScore = min(1.0, Double(min(leftBox.height, rightBox.height)) / 0.55)
                        let verticalScore = (Self.verticality(of: left) + Self.verticality(of: right)) * 0.5
                        let gapScore = min(1.0, max(0.0, Double(gap - 0.06) / 0.22))
                        let score = confidence * 0.45 + heightScore * 0.25 + verticalScore * 0.20 + gapScore * 0.10 + lidarDepthAdjustment
                        if score >= 0.72 {
                            let targetX = Double((leftBox.midX + rightBox.midX) * 0.5)
                            let targetY = Double(1.0 - ((leftBox.midY + rightBox.midY) * 0.5))
                            candidates.append(ShaAnalysisResult(
                                shaID: "tianzhan",
                                confidence: min(0.95, score),
                                targetX: targetX,
                                targetY: targetY,
                                detectedRegions: usable.count,
                                summary: "paired-vertical-structures-gap",
                                horizontalFOVDegrees: evidence?.horizontalFOVDegrees
                            ))
                        }
                    }
                }

                // (1b) 白虎煞: 右侧白虎方建筑体量显著高于左侧青龙方 ("虎强龙弱/白虎探头")
                if rightBox.height >= leftBox.height * 1.28,
                   rightBox.maxY > leftBox.maxY + 0.08,
                   baselineDelta <= 0.22 {
                    var lidarBonus = 0.0
                    if let ev = evidence, let rightD = ev.rightDepthMeters, let leftD = ev.leftDepthMeters,
                       rightD <= leftD + 0.5 {
                        lidarBonus = 0.04
                    }
                    let dominance = min(1.0, Double((rightBox.height - leftBox.height) / max(0.1, leftBox.height)))
                    let conf = Double(left.confidence + right.confidence) * 0.5
                    let score = conf * 0.55 + dominance * 0.30 + Self.verticality(of: right) * 0.15 + lidarBonus
                    if score >= 0.72 {
                        candidates.append(ShaAnalysisResult(
                            shaID: "baihu",
                            confidence: min(0.94, score),
                            targetX: Double(rightBox.midX),
                            targetY: Double(1.0 - rightBox.midY),
                            detectedRegions: usable.count,
                            summary: "right-dominant-vertical-mass",
                            horizontalFOVDegrees: evidence?.horizontalFOVDegrees
                        ))
                    }
                }
            }
        }

        // 2. 探头煞 (tantou): 前景主建筑上方探出小型高位结构 ("暗室窥视/探头")
        for base in usable {
            let baseBox = base.boundingBox
            guard baseBox.width >= 0.26, baseBox.height >= 0.20, baseBox.maxY <= 0.78 else { continue }
            for upper in usable where upper !== base {
                let upBox = upper.boundingBox
                guard upBox.width >= 0.06, upBox.width <= baseBox.width * 0.55,
                      upBox.height >= 0.06, upBox.height <= baseBox.height * 0.65,
                      upBox.minY >= baseBox.maxY - 0.06,
                      upBox.minY <= baseBox.maxY + 0.12,
                      upBox.midX >= baseBox.minX + 0.04,
                      upBox.midX <= baseBox.maxX - 0.04 else { continue }
                var depthBonus = 0.0
                if let ev = evidence, let topD = ev.topDepthMeters, let centerD = ev.depthSampleMeters,
                   topD > centerD + 0.25 {
                    depthBonus = 0.05
                }
                let conf = Double(base.confidence + upper.confidence) * 0.5
                let score = conf * 0.65 + Self.verticality(of: upper) * 0.25 + 0.08 + depthBonus
                if score >= 0.72 {
                    candidates.append(ShaAnalysisResult(
                        shaID: "tantou",
                        confidence: min(0.93, score),
                        targetX: Double(upBox.midX),
                        targetY: Double(1.0 - upBox.midY),
                        detectedRegions: usable.count,
                        summary: "upper-peeking-structure",
                        horizontalFOVDegrees: evidence?.horizontalFOVDegrees
                    ))
                }
            }
        }

        // 3. 火形煞 (huoxing)、路冲煞 (luchong)、穿心煞 (chuanxin)、割脚煞 (gejiao)、反弓水 (fangong)
        for region in usable {
            let box = region.boundingBox
            let topWidth = hypot(
                Double(region.topRight.x - region.topLeft.x),
                Double(region.topRight.y - region.topLeft.y)
            )
            let bottomWidth = hypot(
                Double(region.bottomRight.x - region.bottomLeft.x),
                Double(region.bottomRight.y - region.bottomLeft.y)
            )
            let taperRatio = min(topWidth, bottomWidth) / max(0.001, max(topWidth, bottomWidth))
            let vert = Self.verticality(of: region)

            // (3a) 火形煞: 尖角/三角锥或强烈斜边冲射结构
            if taperRatio <= 0.68 && vert < 0.92 && box.height >= 0.18 && box.midY >= 0.35 {
                let sharpness = min(1.0, (0.72 - taperRatio) / 0.40)
                let score = Double(region.confidence) * 0.60 + sharpness * 0.30 + 0.10
                if score >= 0.72 {
                    candidates.append(ShaAnalysisResult(
                        shaID: "huoxing",
                        confidence: min(0.92, score),
                        targetX: Double(box.midX),
                        targetY: Double(1.0 - box.maxY),
                        detectedRegions: usable.count,
                        summary: "sharp-tapered-angular-structure",
                        horizontalFOVDegrees: evidence?.horizontalFOVDegrees
                    ))
                }
            }

            // (3b) 路冲煞 / 穿心煞: 中下部透视收敛通道 (底部宽、上部向中心收敛，且结合 LiDAR 下近中远深度梯度)
            if box.minY <= 0.22, box.maxY >= 0.45,
               abs(box.midX - 0.5) <= 0.22,
               topWidth < bottomWidth * 0.82 {
                var depthGradientBonus = 0.0
                if let ev = evidence, let bottomD = ev.bottomDepthMeters, let centerD = ev.depthSampleMeters,
                   centerD > bottomD + 0.4 {
                    depthGradientBonus = 0.06
                }
                let perspectiveScore = min(1.0, (1.0 - topWidth / max(0.001, bottomWidth)) / 0.45)
                let score = Double(region.confidence) * 0.60 + perspectiveScore * 0.28 + 0.08 + depthGradientBonus
                if score >= 0.72 {
                    // 若通道上方存在横梁/上盖结构体则为穿心煞 (chuanxin)，否则为直冲路冲煞 (luchong)
                    let hasOverheadSpan = usable.contains { other in
                        other !== region &&
                        other.boundingBox.minY >= box.maxY - 0.08 &&
                        other.boundingBox.width >= box.width * 0.85
                    }
                    candidates.append(ShaAnalysisResult(
                        shaID: hasOverheadSpan ? "chuanxin" : "luchong",
                        confidence: min(0.93, score),
                        targetX: Double(box.midX),
                        targetY: Double(1.0 - box.midY),
                        detectedRegions: usable.count,
                        summary: hasOverheadSpan ? "underpass-piercing-corridor" : "converging-road-corridor",
                        horizontalFOVDegrees: evidence?.horizontalFOVDegrees
                    ))
                }
            }

            // (3c) 割脚煞 / 反弓水: 画面下部横向宽幅贴近通道或弧斜切带
            if box.width >= 0.48, box.height <= 0.26, box.midY <= 0.38 {
                let horizontalSlope = abs(Double(region.topRight.y - region.topLeft.y)) / max(0.001, Double(box.width))
                let isCurvedOrSlanted = horizontalSlope >= 0.12 || taperRatio <= 0.82
                var closeFootBonus = 0.0
                if let ev = evidence, let bottomD = ev.bottomDepthMeters, bottomD <= 3.2 {
                    closeFootBonus = 0.05
                }
                let score = Double(region.confidence) * 0.65 + Double(min(1.0, box.width / 0.65)) * 0.25 + closeFootBonus
                if score >= 0.73 {
                    candidates.append(ShaAnalysisResult(
                        shaID: isCurvedOrSlanted ? "fangong" : "gejiao",
                        confidence: min(0.91, score),
                        targetX: Double(box.midX),
                        targetY: Double(1.0 - box.midY),
                        detectedRegions: usable.count,
                        summary: isCurvedOrSlanted ? "slanted-bow-span" : "low-proximate-transverse-band",
                        horizontalFOVDegrees: evidence?.horizontalFOVDegrees
                    ))
                }
            }
        }

        return candidates.max(by: { $0.confidence < $1.confidence })
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
        // The two detector passes must agree on the Sha category and point to
        // almost the same physical location.
        guard first.shaID == second.shaID else { return false }
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
