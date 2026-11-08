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
    case mapOrientationUnavailable
}

/// Map and north reference are persisted atomically, so restoration cannot
/// combine an old world coordinate system with the phone's current bearing.
struct SpatialWorldMapArchive: Codable {
    let version: Int
    let mapData: Data
    let coordinateHeading: Double

    init(mapData: Data, coordinateHeading: Double) throws {
        guard !mapData.isEmpty, coordinateHeading.isFinite else {
            throw ARSpatialSurveyError.mapOrientationUnavailable
        }
        self.version = 1
        self.mapData = mapData
        self.coordinateHeading = (coordinateHeading.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    static func decode(_ data: Data) throws -> SpatialWorldMapArchive {
        // Legacy raw ARWorldMaps contain no north reference. Re-scanning is
        // required instead of silently applying a different orientation.
        guard let archive = try? JSONDecoder().decode(Self.self, from: data) else {
            throw ARSpatialSurveyError.mapOrientationUnavailable
        }
        guard archive.version == 1, archive.coordinateHeading.isFinite,
              !archive.mapData.isEmpty else { throw ARSpatialSurveyError.archiveFailed }
        return archive
    }
}

/// Traditional Lu Ban Ruler (门光尺 42.9 cm & 丁兰尺 39.0 cm) evaluation for 3D AR point-to-point measurements.
public struct LubanRulerEvaluation: Equatable {
    public let meters: Float
    public let centimeters: Float
    public let yangGateIndex: Int
    public let yangIsAuspicious: Bool
    public let yinIndex: Int
    public let yinIsAuspicious: Bool

    public var yangSegmentName: String {
        Self.yangNamesHans[yangGateIndex]
    }

    public var localizedYangSegmentName: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .zhHans, .auto: return Self.yangNamesHans[yangGateIndex]
        case .zhHant, .ja: return Self.yangNamesHant[yangGateIndex]
        case .en: return Self.yangNamesEn[yangGateIndex]
        case .vi: return Self.yangNamesVi[yangGateIndex]
        case .th: return Self.yangNamesTh[yangGateIndex]
        case .id: return Self.yangNamesId[yangGateIndex]
        case .ko: return Self.yangNamesKo[yangGateIndex]
        }
    }

    public var yinSegmentName: String {
        Self.yinNamesHans[yinIndex]
    }

    public var localizedYinSegmentName: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .zhHans, .auto: return Self.yinNamesHans[yinIndex]
        case .zhHant, .ja: return Self.yinNamesHant[yinIndex]
        case .en: return Self.yinNamesEn[yinIndex]
        case .vi: return Self.yinNamesVi[yinIndex]
        case .th: return Self.yinNamesTh[yinIndex]
        case .id: return Self.yinNamesId[yinIndex]
        case .ko: return Self.yinNamesKo[yinIndex]
        }
    }

    public static func evaluate(meters: Double) -> LubanRulerEvaluation {
        return evaluate(meters: Float(meters))
    }

    private static let yangNamesHans = ["财", "病", "离", "义", "官", "劫", "害", "本"]
    private static let yangNamesHant = ["財", "病", "離", "義", "官", "劫", "害", "本"]
    private static let yangNamesEn = ["Wealth", "Illness", "Separation", "Righteous", "Official", "Robbery", "Harm", "Origin"]
    private static let yangNamesVi = ["Tài", "Bệnh", "Ly", "Nghĩa", "Quan", "Kiếp", "Hại", "Bổn"]
    private static let yangNamesTh = ["ทรัพย์", "โรค", "พลัดพราก", "คุณธรรม", "ยศ", "สูญเสีย", "ภัย", "รากฐาน"]
    private static let yangNamesId = ["Rezeki", "Sakit", "Pisah", "Kebenaran", "Jabatan", "Rugi", "Bahaya", "Pokok"]
    private static let yangNamesKo = ["재(財)", "병(病)", "리(離)", "의(義)", "관(官)", "겁(劫)", "해(害)", "본(本)"]
    private static let yangAuspiciousFlags = [true, false, false, true, true, false, false, true]

    private static let yinNamesHans = ["财", "失", "兴", "死", "官", "义", "苦", "旺", "害", "丁"]
    private static let yinNamesHant = ["財", "失", "興", "死", "官", "義", "苦", "旺", "害", "丁"]
    private static let yinNamesEn = ["Wealth", "Loss", "Prosper", "Decline", "Official", "Righteous", "Sorrow", "Flourish", "Harm", "Descendant"]
    private static let yinNamesVi = ["Tài", "Thất", "Hưng", "Tử", "Quan", "Nghĩa", "Khổ", "Vượng", "Hại", "Đinh"]
    private static let yinNamesTh = ["ทรัพย์", "เสีย", "รุ่งเรือง", "เสื่อม", "ยศ", "คุณธรรม", "ทุกข์", "เจริญ", "ภัย", "ทายาท"]
    private static let yinNamesId = ["Rezeki", "Hilang", "Makmur", "Surut", "Jabatan", "Kebenaran", "Duka", "Jaya", "Bahaya", "Keturunan"]
    private static let yinNamesKo = ["재(財)", "실(失)", "흥(興)", "사(死)", "관(官)", "의(義)", "고(苦)", "왕(旺)", "해(害)", "정(丁)"]
    private static let yinAuspiciousFlags = [true, false, true, false, true, true, false, true, false, true]

    public static func evaluate(meters: Float) -> LubanRulerEvaluation {
        let cm = max(0.0, meters * 100.0)
        let yangCycle: Float = 42.9
        let yangStep: Float = yangCycle / 8.0
        let yangRem = cm.truncatingRemainder(dividingBy: yangCycle)
        let yIdx = min(7, max(0, Int(yangRem / yangStep)))

        let yinCycle: Float = 39.0
        let yinStep: Float = yinCycle / 10.0
        let yinRem = cm.truncatingRemainder(dividingBy: yinCycle)
        let nIdx = min(9, max(0, Int(yinRem / yinStep)))

        return LubanRulerEvaluation(
            meters: meters,
            centimeters: cm,
            yangGateIndex: yIdx,
            yangIsAuspicious: yangAuspiciousFlags[yIdx],
            yinIndex: nIdx,
            yinIsAuspicious: yinAuspiciousFlags[nIdx]
        )
    }

    public func localizedSummary(for language: AppLanguage) -> String {
        let sourceNote: String
        switch language {
        case .en:
            sourceNote = "Classical source: the Lu Ban ruler formula, ‘Wealth, Righteousness, Official and Origin are auspicious; Illness, Separation, Robbery and Harm are inauspicious.’ ‘Illness’, ‘loss’ and ‘wealth’ are symbolic ruler labels, not medical, safety or financial conclusions."
        case .vi:
            sourceNote = "Nguồn cổ tịch: khẩu quyết thước Lỗ Ban («Tài, Nghĩa, Quan, Bổn là cát; Bệnh, Ly, Kiếp, Hại là hung») kết hợp thước Đinh Lan; các nhãn chỉ mang tính biểu tượng văn hóa, không phải kết luận y tế, an toàn hay tài chính."
        case .th:
            sourceNote = "อ้างอิงตำราหลู่ปานจิง («ทรัพย์ คุณธรรม ยศ รากฐาน เป็นมงคล; โรค พลัดพราก สูญเสีย ภัย เป็นอัปมงคล») ร่วมกับบรรทัดติงหลาน เป็นสัญลักษณ์ทางวัฒนธรรม ไม่ใช่คำวินิจฉัยทางการแพทย์ ความปลอดภัย หรือการเงิน"
        case .id:
            sourceNote = "Sumber klasik: kaidah mistar Lu Ban & Ding Lan; label seperti ‘sakit’, ‘rugi’, dan ‘rezeki’ adalah simbol budaya tradisional, bukan kesimpulan medis, keselamatan, atau keuangan."
        case .ja:
            sourceNote = "出典：『魯班経』尺法訣「財・義・官・本を吉とし、病・離・劫・害を凶とす」および『丁蘭尺』伝統尺法（「病・失・財・旺」は文化象徴であり、医療・安全・財務上の判断ではありません）。"
        case .ko:
            sourceNote = "출전: 『노반경』 척법결(재·의·관·본은 길, 병·리·겁·해는 흉) 및 『정란척』 전통 척법(‘병·실·재·왕’은 문화적 상징이며 의료·안전·재무 판단이 아닙니다)."
        case .zhHant:
            sourceNote = "出處：《魯班經》尺法訣：「財、義、官、本為吉，病、離、劫、害為凶。」兼參《丁蘭尺》傳統尺法；‘病、失、財、旺’是文化象徵標籤，不是醫療、安全或財務判斷。"
        case .auto, .zhHans:
            sourceNote = "出处：《鲁班经》尺法诀：“财、义、官、本为吉，病、离、劫、害为凶。”兼参《丁兰尺》传统尺法；‘病、失、财、旺’是文化象征标签，不是医疗、安全或财务判断。"
        }
        switch language {
        case .en:
            let yName = Self.yangNamesEn[yangGateIndex]
            let yLuck = yangIsAuspicious ? "Auspicious" : "Inauspicious"
            let nName = Self.yinNamesEn[yinIndex]
            let nLuck = yinIsAuspicious ? "Auspicious" : "Inauspicious"
            return String(format: "%.1f cm · LuBan: %@ (%@) · DingLan: %@ (%@)", centimeters, yName, yLuck, nName, nLuck) + " · " + sourceNote
        case .vi:
            let yName = Self.yangNamesVi[yangGateIndex]
            let yLuck = yangIsAuspicious ? "Cát" : "Hung"
            let nName = Self.yinNamesVi[yinIndex]
            let nLuck = yinIsAuspicious ? "Cát" : "Hung"
            return String(format: "%.1f cm · Lỗ Ban: 【%@】(%@) · Đinh Lan: 【%@】(%@)", centimeters, yName, yLuck, nName, nLuck) + " · " + sourceNote
        case .th:
            let yName = Self.yangNamesTh[yangGateIndex]
            let yLuck = yangIsAuspicious ? "มงคล" : "อัปมงคล"
            let nName = Self.yinNamesTh[yinIndex]
            let nLuck = yinIsAuspicious ? "มงคล" : "อัปมงคล"
            return String(format: "%.1f cm · หลู่ปาน: 【%@】(%@) · ติงหลาน: 【%@】(%@)", centimeters, yName, yLuck, nName, nLuck) + " · " + sourceNote
        case .id:
            let yName = Self.yangNamesId[yangGateIndex]
            let yLuck = yangIsAuspicious ? "Baik" : "Buruk"
            let nName = Self.yinNamesId[yinIndex]
            let nLuck = yinIsAuspicious ? "Baik" : "Buruk"
            return String(format: "%.1f cm · LuBan: [%@] (%@) · DingLan: [%@] (%@)", centimeters, yName, yLuck, nName, nLuck) + " · " + sourceNote
        case .ja:
            let yName = Self.yangNamesHant[yangGateIndex]
            let yLuck = yangIsAuspicious ? "吉" : "凶"
            let nName = Self.yinNamesHant[yinIndex]
            let nLuck = yinIsAuspicious ? "吉" : "凶"
            return String(format: "%.1f cm · 魯班門光尺：【%@】(%@) · 丁蘭尺：【%@】(%@)", centimeters, yName, yLuck, nName, nLuck) + " · " + sourceNote
        case .ko:
            let yName = Self.yangNamesKo[yangGateIndex]
            let yLuck = yangIsAuspicious ? "길" : "흉"
            let nName = Self.yinNamesKo[yinIndex]
            let nLuck = yinIsAuspicious ? "길" : "흉"
            return String(format: "%.1f cm · 노반자: [%@](%@) · 정란척: [%@](%@)", centimeters, yName, yLuck, nName, nLuck) + " · " + sourceNote
        case .zhHant:
            let yName = Self.yangNamesHant[yangGateIndex]
            let yLuck = yangIsAuspicious ? "吉" : "凶"
            let nName = Self.yinNamesHant[yinIndex]
            let nLuck = yinIsAuspicious ? "吉" : "凶"
            return String(format: "%.1f cm · 魯班門光尺：【%@】字門(%@) · 丁蘭尺：【%@】字(%@)", centimeters, yName, yLuck, nName, nLuck) + " · " + sourceNote
        case .auto, .zhHans:
            let yName = Self.yangNamesHans[yangGateIndex]
            let yLuck = yangIsAuspicious ? "吉" : "凶"
            let nName = Self.yinNamesHans[yinIndex]
            let nLuck = yinIsAuspicious ? "吉" : "凶"
            return String(format: "%.1f cm · 鲁班门光尺：【%@】字门(%@) · 丁兰尺：【%@】字(%@)", centimeters, yName, yLuck, nName, nLuck) + " · " + sourceNote
        }
    }
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

/// A compact value copy of one exposure's depth data, independent of later AR frames.
struct ARCapturedDepth {
    let width: Int
    let height: Int
    let values: [Float]
    let confidence: [UInt8]?
    let viewToImage: CGAffineTransform

    func sample(at point: CGPoint) -> Float? {
        let imagePoint = point.applying(viewToImage)
        guard width > 0, height > 0, values.count == width * height,
              imagePoint.x >= 0, imagePoint.x <= 1, imagePoint.y >= 0, imagePoint.y <= 1 else { return nil }
        let x = min(width - 1, Int(imagePoint.x * CGFloat(width)))
        let y = min(height - 1, Int(imagePoint.y * CGFloat(height)))
        var samples: [Float] = []
        for dy in -1...1 {
            for dx in -1...1 {
                let index = max(0, min(height - 1, y + dy)) * width + max(0, min(width - 1, x + dx))
                if let confidence, confidence.count == values.count, confidence[index] < 1 { continue }
                let value = values[index]
                if value.isFinite, value > 0.05, value < 60 { samples.append(value) }
            }
        }
        samples.sort()
        return samples.isEmpty ? nil : samples[samples.count / 2]
    }

    static func capture(_ map: CVPixelBuffer?, confidence: CVPixelBuffer?, viewToImage: CGAffineTransform) -> ARCapturedDepth? {
        guard let map else { return nil }
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(map) else { return nil }
        let width = CVPixelBufferGetWidth(map), height = CVPixelBufferGetHeight(map)
        let stride = CVPixelBufferGetBytesPerRow(map)
        var values: [Float] = []
        values.reserveCapacity(width * height)
        for y in 0..<height {
            let row = base.advanced(by: y * stride).assumingMemoryBound(to: Float32.self)
            values.append(contentsOf: UnsafeBufferPointer(start: row, count: width))
        }
        var scores: [UInt8]?
        if let confidence, CVPixelBufferGetWidth(confidence) == width, CVPixelBufferGetHeight(confidence) == height {
            CVPixelBufferLockBaseAddress(confidence, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) }
            if let base = CVPixelBufferGetBaseAddress(confidence) {
                var copied: [UInt8] = []
                let stride = CVPixelBufferGetBytesPerRow(confidence)
                for y in 0..<height {
                    copied.append(contentsOf: UnsafeBufferPointer(start: base.advanced(by: y * stride).assumingMemoryBound(to: UInt8.self), count: width))
                }
                scores = copied
            }
        }
        return ARCapturedDepth(width: width, height: height, values: values, confidence: scores, viewToImage: viewToImage)
    }
}

public struct ARCapturedFrame {
    public let image: UIImage
    public let evidence: ARSceneEvidence?
    let pose: ARCapturePose?
    let depth: ARCapturedDepth?
    let capturedAt: Date

    public init(image: UIImage, evidence: ARSceneEvidence? = nil) {
        self.init(image: image, evidence: evidence, pose: nil, depth: nil)
    }

    init(image: UIImage, evidence: ARSceneEvidence? = nil, pose: ARCapturePose?, depth: ARCapturedDepth? = nil, capturedAt: Date = Date()) {
        self.image = image
        self.evidence = evidence
        self.pose = pose
        self.depth = depth
        self.capturedAt = capturedAt
    }

    func exteriorRecord(shaID: String, point: CGPoint, confidence: Double?, source: ShaRecordSource, note: String?) -> ExteriorShaRecord? {
        guard let pose else { return nil }
        return ExteriorShaRecord(shaID: shaID,
                                 bearingDegrees: pose.projection.bearing(point: point, cameraHeading: pose.heading),
                                 capturedHeadingDegrees: pose.heading,
                                 elevationDegrees: pose.projection.elevation(point: point, cameraElevation: pose.elevation),
                                 distanceMeters: depth?.sample(at: point), confidence: confidence,
                                 capturedAt: capturedAt, source: source, note: note)
    }

    /// Vision sees the same aspect-fill crop as the live camera viewport.
    static func viewportImage(_ image: UIImage, size: CGSize) -> UIImage {
        guard size.width > 0, size.height > 0 else { return image }
        let sourceSize: CGSize
        if let cg = image.cgImage {
            let swapped = [UIImage.Orientation.left, .right, .leftMirrored, .rightMirrored].contains(image.imageOrientation)
            sourceSize = CGSize(width: CGFloat(swapped ? cg.height : cg.width), height: CGFloat(swapped ? cg.width : cg.height))
        } else { sourceSize = image.size }
        guard sourceSize.width > 0, sourceSize.height > 0 else { return image }
        let resolutionScale = min(1, 1280 / max(size.width, size.height))
        let output = CGSize(width: size.width * resolutionScale, height: size.height * resolutionScale)
        let scale = max(output.width / sourceSize.width, output.height / sourceSize.height)
        let drawn = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: output, format: format).image { _ in
            image.draw(in: CGRect(x: (output.width - drawn.width) / 2, y: (output.height - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
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
    @Published public private(set) var meshVisible = true
    @Published public private(set) var lubanPointA: SIMD3<Float>?
    @Published public private(set) var lubanPointB: SIMD3<Float>?
    @Published public private(set) var lubanSpanMeters: Float?
    @Published public private(set) var lubanEvaluation: LubanRulerEvaluation?
    @Published public private(set) var savedAnchorCount: Int = 0
    @Published public private(set) var cameraElevationDegrees: Double = 0.0
    @Published public private(set) var cameraHorizontalFOVDegrees: Double?
    @Published private(set) var currentCameraPose: ARCapturePose?
    @Published public private(set) var cameraRollDegrees: Double = 0.0
    @Published public private(set) var groundBaguaProjected: Bool = false
    @Published public private(set) var currentStandingPalace: String?
    @Published public private(set) var estimatedRoomHeightMeters: Float?
    @Published public private(set) var hasLowBeamWarning: Bool = false
    /// 手动角落打点测绘（Corner-pin Polygon）：弱纹理墙面辅助精准房间
    @Published public var cornerPinActive: Bool = false
    @Published public private(set) var cornerPoints: [SIMD3<Float>] = []
    @Published public private(set) var cornerRoomCount: Int = 0

    private weak var sceneView: ARSCNView?
    private var cornerRoomAnchors: [ARAnchor] = []
    private var lubanAnchors: [ARAnchor] = []
    private var cornerPinNodes: [SCNNode] = []
    private var cornerRooms: [SpatialRoom3D] = []
    private var surveyHeadingDegrees: Double?
    @Published public private(set) var hasHeadingReference = false
    private var sessionGeneration = 0
    private var lastMeasurementTimestamp: TimeInterval = 0
    private var lastSemanticUpdateTimestamp: TimeInterval = 0
    private var lastMeshGeometryUpdate: [UUID: TimeInterval] = [:]
    private var lastPlaneGeometryUpdate: [UUID: TimeInterval] = [:]
    private var activeConfiguration: ARWorldTrackingConfiguration?
    private var distanceSamples: [Float] = []
    private var rendersSpatialMesh = true
    private var lastCapturedTimestamp: TimeInterval = 0
    private var retryCount: Int = 0
    private var lubanNodeA: SCNNode?
    private var lubanNodeB: SCNNode?
    private var lubanLineNode: SCNNode?
    private var groundBaguaNode: SCNNode?
    private var groundBaguaCenter: SIMD3<Float>?
    private var groundBaguaSpan: Float = 2.4
    private var groundBaguaNorthYawRadians: Float = 0.0

    /// AR 命中检测使用的屏幕中心点。优先取 AR 视图自身 bounds —— 该值随
    /// iPhone Duo 折叠/展开实时变化，与窗口尺寸保持一致；仅当视图尚未完成
    /// 首次布局时回退到所属 window 的 bounds。不使用 UIScreen.main：在折叠
    /// 屏上应用尺寸随窗口变化，主屏尺寸会失真（苹果 iPhone Duo 适配要求）。
    private func projectionCenter(of view: ARSCNView) -> CGPoint {
        if view.bounds.width > 0, view.bounds.height > 0 {
            return CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        }
        if let window = view.window {
            return CGPoint(x: window.bounds.midX, y: window.bounds.midY)
        }
        return .zero
    }

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
        while (maps.count > maxFiles || totalBytes > maxBytes) && maps.count > 1 {
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

    /// 设备是否具备 LiDAR 勘舆能力（sceneReconstruction 依赖 LiDAR 硬件）。
    /// 无 LiDAR 的设备不启动持续扫描：场景重建/深度语义均不可用，持续
    /// 平面扫描同样持续占用相机与算力，页面应降级为提示引导。
    public static var isLiDARSupported: Bool {
        if #available(iOS 13.4, *) {
            return ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
        }
        return false
    }

    public func start() {
        guard let sceneView = sceneView else { return }
        guard ARWorldTrackingConfiguration.isSupported else {
            trackingState = .unavailable
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
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
        savedAnchorCount = 0
        estimatedRoomHeightMeters = nil
        hasLowBeamWarning = false
        sessionGeneration += 1
        surveyHeadingDegrees = nil
        currentCameraPose = nil
        cameraHorizontalFOVDegrees = nil
        hasHeadingReference = false
        clearLubanPoints()
        clearCornerRooms()
        clearGroundBaguaOverlay()
        sceneView.session.pause()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        activeConfiguration = configuration
        retryCount = 0
        refreshSavedWorldMapState()
    }

    /// Delayed AR start on a specific view.  The camera hardware is exclusive:
    /// when the user flips back from the plain camera (AVCaptureSession) to AR,
    /// the old session's stop is asynchronous, and running the AR session
    /// immediately would fail with a busy camera and leave a black frame.
    /// Deferring the start gives the previous session time to release the
    /// camera; if the view was already replaced (another flip) meanwhile, the
    /// deferred start is abandoned.
    public func startOn(_ view: ARSCNView, afterDelay delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak view] in
            guard let self = self, let view = view, self.sceneView === view else { return }
            self.start()
        }
    }

    public func clearGroundBaguaOverlay() {
        groundBaguaProjected = false
        currentStandingPalace = nil
        groundBaguaNode?.removeFromParentNode()
        groundBaguaNode = nil
        groundBaguaCenter = nil
    }

    /// Projects or removes a 3D True-North-aligned Nine-Palace Bagua & Luopan
    /// holographic array on the detected floor plane.
    @discardableResult
    public func toggleGroundBaguaOverlay() -> Bool {
        if groundBaguaProjected {
            clearGroundBaguaOverlay()
            return false
        }
        guard let sceneView = sceneView,
              let frame = sceneView.session.currentFrame else { return false }

        let center = projectionCenter(of: sceneView)

        var floorPos: SIMD3<Float>?
        var resolvedSpan: Float = 2.4

        if let hit = sceneView.raycastQuery(from: center, allowing: .existingPlaneGeometry, alignment: .horizontal)
            .flatMap({ sceneView.session.raycast($0).first })
            ?? sceneView.raycastQuery(from: center, allowing: .estimatedPlane, alignment: .horizontal)
                .flatMap({ sceneView.session.raycast($0).first }) {
            let col = hit.worldTransform.columns.3
            floorPos = SIMD3<Float>(col.x, col.y, col.z)
            if let plane = hit.anchor as? ARPlaneAnchor {
                resolvedSpan = min(4.2, max(1.8, min(plane.planeExtent.width, plane.planeExtent.height) * 0.92))
            }
        } else if let largestHoriz = frame.anchors
            .compactMap({ $0 as? ARPlaneAnchor })
            .filter({ $0.alignment == .horizontal })
            .max(by: { $0.planeExtent.width * $0.planeExtent.height < $1.planeExtent.width * $1.planeExtent.height }) {
            let col = largestHoriz.transform.columns.3
            floorPos = SIMD3<Float>(col.x, col.y, col.z)
            resolvedSpan = min(4.2, max(1.8, min(largestHoriz.planeExtent.width, largestHoriz.planeExtent.height) * 0.92))
        } else {
            let cam = frame.camera.transform
            let camPos = SIMD3<Float>(cam.columns.3.x, cam.columns.3.y, cam.columns.3.z)
            let forward = -SIMD3<Float>(cam.columns.2.x, 0, cam.columns.2.z)
            let horizDir = simd_length(forward) > 0.01 ? simd_normalize(forward) : SIMD3<Float>(0, 0, -1)
            floorPos = SIMD3<Float>(camPos.x + horizDir.x * 1.6, camPos.y - 1.25, camPos.z + horizDir.z * 1.6)
        }

        guard let centerPos = floorPos else { return false }

        guard let coordinateHeading = surveyHeadingDegrees else { return false }
        let northYaw = -Float(coordinateHeading * .pi / 180)

        let plane = SCNPlane(width: CGFloat(resolvedSpan), height: CGFloat(resolvedSpan))
        let mat = SCNMaterial()
        mat.diffuse.contents = Self.renderGroundBaguaTexture()
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.name = "ar-ground-bagua"
        node.position = SCNVector3(centerPos.x, centerPos.y + 0.008, centerPos.z)
        node.eulerAngles = SCNVector3(-Float.pi / 2.0, northYaw, 0)
        sceneView.scene.rootNode.addChildNode(node)

        groundBaguaNode = node
        groundBaguaCenter = centerPos
        groundBaguaSpan = resolvedSpan
        groundBaguaNorthYawRadians = northYaw
        groundBaguaProjected = true
        updateStandingPalace(cameraTransform: frame.camera.transform)
        return true
    }

    private func updateStandingPalace(cameraTransform: simd_float4x4) {
        guard groundBaguaProjected, let center = groundBaguaCenter else {
            currentStandingPalace = nil
            return
        }
        let camPos = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let dx = camPos.x - center.x
        let dz = camPos.z - center.z
        let cosY = cos(-groundBaguaNorthYawRadians)
        let sinY = sin(-groundBaguaNorthYawRadians)
        let localX = dx * cosY - dz * sinY
        let localZ = dx * sinY + dz * cosY
        let halfSpan = max(0.5, groundBaguaSpan * 0.5)
        let normX = localX / halfSpan
        let normZ = localZ / halfSpan
        let lang = LocalizationManager.shared.effectiveLanguage

        if abs(normX) <= 0.33 && abs(normZ) <= 0.33 {
            switch lang {
            case .en: currentStandingPalace = "Center Palace · 9 Purple (Auspicious)"
            case .vi: currentStandingPalace = "Trung Cung Lập Cực · Cửu Tử Đương Lệnh (Đại Cát)"
            case .th: currentStandingPalace = "จงกง (จุดศูนย์กลาง) · ดาว 9 ม่วงประจำยุค (มงคลยิ่ง)"
            case .id: currentStandingPalace = "Istana Pusat · 9 Ungu Berkuasa (Sangat Baik)"
            case .ja: currentStandingPalace = "中宮立極 · 九紫右弼当令（大吉）"
            case .ko: currentStandingPalace = "중궁 입극 · 구자우필 당령 (대길)"
            case .zhHant: currentStandingPalace = "中宮立極 · 九紫右弼當令（大吉）"
            case .auto, .zhHans: currentStandingPalace = "中宫立极 · 九紫右弼当令（大吉）"
            }
            return
        }
        // Standard South-at-top / North-at-bottom Lo Shu orientation:
        // local -Z is North (Kan), +Z is South (Li), +X is East (Zhen), -X is West (Dui)
        let angleDeg = (Double(atan2(localX, -localZ)) * 180.0 / .pi + 360.0).truncatingRemainder(dividingBy: 360.0)
        let index = Int(((angleDeg + 22.5).truncatingRemainder(dividingBy: 360.0)) / 45.0)
        let labelsHans = [
            "正北坎宫 · 五黄廉贞（宜静不宜动）",
            "东北艮宫 · 三碧禄存（是非位）",
            "正东震宫 · 七赤破军（退气位）",
            "东南巽宫 · 八白左辅（次财位·吉）",
            "正南离宫 · 四绿文昌（功名位·吉）",
            "西南坤宫 · 六白武曲（偏财权印·吉）",
            "正西兑宫 · 二黑巨门（病符象征·《紫白诀》）",
            "西北乾宫 · 一白贪狼（未来生气·大吉）"
        ]
        let labelsHant = [
            "正北坎宮 · 五黃廉貞（宜靜不宜動）",
            "東北艮宮 · 三碧祿存（是非位）",
            "正東震宮 · 七赤破軍（退氣位）",
            "東南巽宮 · 八白左輔（次財位·吉）",
            "正南離宮 · 四綠文昌（功名位·吉）",
            "西南坤宮 · 六白武曲（偏財權印·吉）",
            "正西兌宮 · 二黑巨門（病符象徵·《紫白訣》）",
            "西北乾宮 · 一白貪狼（未來生氣·大吉）"
        ]
        let labelsEn = [
            "North (Kan) · 5 Yellow",
            "Northeast (Gen) · 3 Jade",
            "East (Zhen) · 7 Red",
            "Southeast (Xun) · 8 White (Wealth)",
            "South (Li) · 4 Green (Academic)",
            "Southwest (Kun) · 6 White (Career)",
            "West (Dui) · 2 Black (classical illness symbol · Zi Bai Jue)",
            "Northwest (Qian) · 1 White (Noble)"
        ]
        let labelsVi = [
            "Chính Bắc (Khảm) · Ngũ Hoàng Liêm Trinh (Nên tĩnh)",
            "Đông Bắc (Cấn) · Tam Bích Lộc Tồn (Thị phi)",
            "Chính Đông (Chấn) · Thất Xích Phá Quân (Thoái khí)",
            "Đông Nam (Tốn) · Bát Bạch Tả Phù (Tài vị · Cát)",
            "Chính Nam (Ly) · Tứ Lục Văn Xương (Công danh · Cát)",
            "Tây Nam (Khôn) · Lục Bạch Vũ Khúc (Quyền ấn · Cát)",
            "Chính Tây (Đoài) · Nhị Hắc Cự Môn (Biểu tượng bệnh phù)",
            "Tây Bắc (Càn) · Nhất Bạch Tham Lang (Sinh khí · Đại Cát)"
        ]
        let labelsTh = [
            "ทิศเหนือ (ข่าน) · ดาว 5 เหลือง (ควรสงบนิ่ง)",
            "ทิศตะวันออกเฉียงเหนือ (เกิ้น) · ดาว 3 เขียว (ระวังปากเสียง)",
            "ทิศตะวันออก (เจิ้น) · ดาว 7 แดง (พลังถดถอย)",
            "ทิศตะวันออกเฉียงใต้ (ซวิ่น) · ดาว 8 ขาว (โชคลาภ · มงคล)",
            "ทิศใต้ (หลี) · ดาว 4 เขียวเหวินชาง (การเรียน/ชื่อเสียง · มงคล)",
            "ทิศตะวันตกเฉียงใต้ (คุน) · ดาว 6 ขาว (บารมี/การงาน · มงคล)",
            "ทิศตะวันตก (ตุ้ย) · ดาว 2 ดำ (สัญลักษณ์สุขภาพตามตำรา)",
            "ทิศตะวันตกเฉียงเหนือ (เฉียน) · ดาว 1 ขาว (พลังรุ่งเรือง · มงคลยิ่ง)"
        ]
        let labelsId = [
            "Utara (Kan) · 5 Kuning (Jaga Ketenangan)",
            "Timur Laut (Gen) · 3 Giok (Rawan Selisih)",
            "Timur (Zhen) · 7 Merah (Energi Surut)",
            "Tenggara (Xun) · 8 Putih (Rezeki · Baik)",
            "Selatan (Li) · 4 Hijau WenChang (Akademik · Baik)",
            "Barat Daya (Kun) · 6 Putih (Karier/Wibawa · Baik)",
            "Barat (Dui) · 2 Hitam (Simbol klasik Zi Bai Jue)",
            "Barat Laut (Qian) · 1 Putih (Energi Maju · Sangat Baik)"
        ]
        let labelsJa = [
            "正北坎宮 · 五黄廉貞（静を宜しとす）",
            "北東艮宮 · 三碧禄存（是非位）",
            "正東震宮 · 七赤破軍（退気位）",
            "南東巽宮 · 八白左輔（次財位・吉）",
            "正南離宮 · 四緑文昌（功名位・吉）",
            "南西坤宮 · 六白武曲（偏財権印・吉）",
            "正西兌宮 · 二黒巨門（病符象徴・『紫白訣』）",
            "北西乾宮 · 一白貪狼（未来生気・大吉）"
        ]
        let labelsKo = [
            "정북 감궁 · 오황염정 (정숙 권장)",
            "북동 간궁 · 삼벽록존 (시비위)",
            "정동 진궁 · 칠적파군 (퇴기위)",
            "남동 손궁 · 팔백좌보 (차재위·길)",
            "정남 리궁 · 사록문창 (공명위·길)",
            "남서 곤궁 · 육백무곡 (편재권인·길)",
            "정서 태궁 · 이흑거문 (병부 상징·『자백결』)",
            "북서 건궁 · 일백탐랑 (미래생기·대길)"
        ]
        let safeIdx = min(7, max(0, index))
        switch lang {
        case .en: currentStandingPalace = labelsEn[safeIdx]
        case .vi: currentStandingPalace = labelsVi[safeIdx]
        case .th: currentStandingPalace = labelsTh[safeIdx]
        case .id: currentStandingPalace = labelsId[safeIdx]
        case .ja: currentStandingPalace = labelsJa[safeIdx]
        case .ko: currentStandingPalace = labelsKo[safeIdx]
        case .zhHant: currentStandingPalace = labelsHant[safeIdx]
        case .auto, .zhHans: currentStandingPalace = labelsHans[safeIdx]
        }
    }

    private static func renderGroundBaguaTexture() -> UIImage {
        let size = CGSize(width: 768, height: 768)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)
            cg.clear(rect)

            // Outer translucent dark gold disk
            let insetRect = rect.insetBy(dx: 12, dy: 12)
            cg.setFillColor(UIColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 0.58).cgColor)
            cg.fillEllipse(in: insetRect)

            cg.setStrokeColor(UIColor(red: 0.95, green: 0.80, blue: 0.30, alpha: 0.88).cgColor)
            cg.setLineWidth(4)
            cg.strokeEllipse(in: insetRect)
            cg.strokeEllipse(in: rect.insetBy(dx: 64, dy: 64))

            // 3x3 Nine-Palace grid inside the circle
            let gridBox = rect.insetBy(dx: 128, dy: 128)
            cg.setStrokeColor(UIColor(red: 0.0, green: 0.85, blue: 0.96, alpha: 0.78).cgColor)
            cg.setLineWidth(2.5)
            cg.stroke(gridBox)

            let cellW = gridBox.width / 3.0
            let cellH = gridBox.height / 3.0
            for idx in 1...2 {
                let x = gridBox.minX + CGFloat(idx) * cellW
                let y = gridBox.minY + CGFloat(idx) * cellH
                cg.move(to: CGPoint(x: x, y: gridBox.minY))
                cg.addLine(to: CGPoint(x: x, y: gridBox.maxY))
                cg.move(to: CGPoint(x: gridBox.minX, y: y))
                cg.addLine(to: CGPoint(x: gridBox.maxX, y: y))
            }
            cg.strokePath()

            // Draw Period 9 Lo Shu cells (North at top of texture so -Z aligns with North)
            // Row 0 (North): NW(一白乾), N(五黄坎), NE(三碧艮)
            // Row 1 (Center): W(二黑兑), Center(九紫中), E(七赤震)
            // Row 2 (South): SW(六白坤), S(四绿离), SE(八白巽)
            let cGreen = UIColor(red: 0.35, green: 0.95, blue: 0.65, alpha: 0.95)
            let cRed = UIColor(red: 1.0, green: 0.45, blue: 0.40, alpha: 0.95)
            let cAmber = UIColor(red: 0.95, green: 0.75, blue: 0.35, alpha: 0.95)
            let cOrange = UIColor(red: 1.0, green: 0.55, blue: 0.35, alpha: 0.95)
            let cGold = UIColor(red: 1.0, green: 0.88, blue: 0.35, alpha: 1.0)
            let cSilver = UIColor(red: 0.85, green: 0.85, blue: 0.92, alpha: 0.95)
            let cells: [[(title: String, sub: String, color: UIColor)]]
            switch LocalizationManager.shared.effectiveLanguage {
            case .zhHans, .auto:
                cells = [
                    [("乾 · 一白", "西北生旺", cGreen), ("坎 · 五黄", "正北廉贞", cRed), ("艮 · 三碧", "东北禄存", cAmber)],
                    [("兑 · 二黑", "正西病符", cOrange), ("中宫 · 九紫", "天心太极", cGold), ("震 · 七赤", "正东破军", cSilver)],
                    [("坤 · 六白", "西南武曲", cGreen), ("离 · 四绿", "正南文昌", cGreen), ("巽 · 八白", "东南左辅", cGreen)]
                ]
            case .zhHant:
                cells = [
                    [("乾 · 一白", "西北生旺", cGreen), ("坎 · 五黃", "正北廉貞", cRed), ("艮 · 三碧", "東北祿存", cAmber)],
                    [("兌 · 二黑", "正西病符", cOrange), ("中宮 · 九紫", "天心太極", cGold), ("震 · 七赤", "正東破軍", cSilver)],
                    [("坤 · 六白", "西南武曲", cGreen), ("離 · 四綠", "正南文昌", cGreen), ("巽 · 八白", "東南左輔", cGreen)]
                ]
            case .en:
                cells = [
                    [("Qian · 1W", "NW Future Qi", cGreen), ("Kan · 5Y", "N 5-Yellow", cRed), ("Gen · 3J", "NE 3-Jade", cAmber)],
                    [("Dui · 2B", "W 2-Black", cOrange), ("Center · 9P", "Taiji Heart", cGold), ("Zhen · 7R", "E 7-Red", cSilver)],
                    [("Kun · 6W", "SW 6-White", cGreen), ("Li · 4G", "S Wenchang", cGreen), ("Xun · 8W", "SE Wealth", cGreen)]
                ]
            case .ja:
                cells = [
                    [("乾・一白", "北西生旺", cGreen), ("坎・五黄", "正北廉貞", cRed), ("艮・三碧", "北東禄存", cAmber)],
                    [("兌・二黒", "正西病符", cOrange), ("中宮・九紫", "天心太極", cGold), ("震・七赤", "正東破軍", cSilver)],
                    [("坤・六白", "南西武曲", cGreen), ("離・四緑", "正南文昌", cGreen), ("巽・八白", "南東左輔", cGreen)]
                ]
            case .ko:
                cells = [
                    [("건 · 일백", "서북 생왕", cGreen), ("감 · 오황", "정북 염정", cRed), ("간 · 삼벽", "동북 녹존", cAmber)],
                    [("태 · 이흑", "정서 병부", cOrange), ("중궁 · 구자", "천심 태극", cGold), ("진 · 칠적", "정동 파군", cSilver)],
                    [("곤 · 육백", "서남 무곡", cGreen), ("리 · 사록", "정남 문창", cGreen), ("손 · 팔백", "동남 좌보", cGreen)]
                ]
            case .vi:
                cells = [
                    [("Càn · 1 Bạch", "Tây Bắc Sinh Khí", cGreen), ("Khảm · 5 Hoàng", "Chính Bắc Ngũ Hoàng", cRed), ("Cấn · 3 Bích", "Đông Bắc Lộc Tồn", cAmber)],
                    [("Đoài · 2 Hắc", "Chính Tây Nhị Hắc", cOrange), ("Trung Cung · 9 Tử", "Thiên Tâm Thái Cực", cGold), ("Chấn · 7 Xích", "Chính Đông Phá Quân", cSilver)],
                    [("Khôn · 6 Bạch", "Tây Nam Vũ Khúc", cGreen), ("Ly · 4 Lục", "Chính Nam Văn Xương", cGreen), ("Tốn · 8 Bạch", "Đông Nam Tả Phụ", cGreen)]
                ]
            case .th:
                cells = [
                    [("เฉียน · 1 ขาว", "พายัพเจริญ", cGreen), ("ข่าน · 5 เหลือง", "เหนือเบญจเหลือง", cRed), ("เกิ้น · 3 เขียว", "อีสานลู่ฉุน", cAmber)],
                    [("ตุ้ย · 2 ดำ", "ตะวันตกดาวสองดำ", cOrange), ("กลาง · 9 ม่วง", "ศูนย์กลางไท่จี๋", cGold), ("เจิ้น · 7 แดง", "ตะวันออกโพ่จวิน", cSilver)],
                    [("คุน · 6 ขาว", "หรดีอู่ชวี", cGreen), ("หลี · 4 เขียว", "ใต้เหวินชาง", cGreen), ("ซวิ่น · 8 ขาว", "อาคเนย์โชคลาภ", cGreen)]
                ]
            case .id:
                cells = [
                    [("Qian · 1-Putih", "BL Energi Maju", cGreen), ("Kan · 5-Kuning", "U 5-Kuning", cRed), ("Gen · 3-Giok", "TL 3-Giok", cAmber)],
                    [("Dui · 2-Hitam", "B 2-Hitam", cOrange), ("Pusat · 9-Ungu", "Jantung Taiji", cGold), ("Zhen · 7-Merah", "T 7-Merah", cSilver)],
                    [("Kun · 6-Putih", "BD 6-Putih", cGreen), ("Li · 4-Hijau", "S Wenchang", cGreen), ("Xun · 8-Putih", "TG Rezeki", cGreen)]
                ]
            }

            for r in 0..<3 {
                for c in 0..<3 {
                    let item = cells[r][c]
                    let cellRect = CGRect(
                        x: gridBox.minX + CGFloat(c) * cellW,
                        y: gridBox.minY + CGFloat(r) * cellH,
                        width: cellW,
                        height: cellH
                    )
                    let pStyle = NSMutableParagraphStyle()
                    pStyle.alignment = .center
                    item.title.draw(
                        in: CGRect(x: cellRect.minX + 6, y: cellRect.midY - 28, width: cellW - 12, height: 32),
                        withAttributes: [
                            .font: UIFont.boldSystemFont(ofSize: 24),
                            .foregroundColor: item.color,
                            .paragraphStyle: pStyle
                        ]
                    )
                    item.sub.draw(
                        in: CGRect(x: cellRect.minX + 6, y: cellRect.midY + 6, width: cellW - 12, height: 26),
                        withAttributes: [
                            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                            .paragraphStyle: pStyle
                        ]
                    )
                }
            }
        }
    }

    public func toggleMeshVisibility() {
        meshVisible.toggle()
        guard let root = sceneView?.scene.rootNode else { return }
        root.enumerateChildNodes { node, _ in
            if node.name == "ar-spatial-mesh" || node.name == "ar-spatial-plane" {
                node.isHidden = !self.meshVisible
            }
        }
    }

    /// Exports all scanned ARPlaneAnchors (floors and walls) and Lu Ban measurement
    /// points in gravityAndHeading world coordinates into a 2D top-down blueprint
    /// and syncs them directly to `FloorplanView`, enabling AR-to-Floorplan mapping
    /// even on iOS 14/15 or non-RoomPlan devices.
    public func buildSpatialSurvey() -> HouseSpatialSurvey? {
        guard let frame = sceneView?.session.currentFrame else { return nil }
        let planes = frame.anchors.compactMap { $0 as? ARPlaneAnchor }
        guard !planes.isEmpty else { return nil }

        var walls3D: [SpatialWall3D] = []
        let openings3D: [SpatialOpening3D] = []
        var beams3D: [SpatialBeam3D] = []
        var rooms3D: [SpatialRoom3D] = []
        let objects3D: [SpatialObject3D] = []

        let vertPlanes = planes.filter { $0.alignment == .vertical }
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude

        for plane in vertPlanes {
            let halfW = max(Float(0.4), plane.planeExtent.width * 0.5)
            let h = max(Float(2.0), plane.planeExtent.height)
            let p1 = plane.transform * SIMD4<Float>(plane.center.x - halfW, plane.center.y, plane.center.z, 1.0)
            let p2 = plane.transform * SIMD4<Float>(plane.center.x + halfW, plane.center.y, plane.center.z, 1.0)
            walls3D.append(SpatialWall3D(
                start: SIMD3<Float>(p1.x, p1.y, p1.z),
                end: SIMD3<Float>(p2.x, p2.y, p2.z),
                height: h,
                thickness: 0.18,
                isLoadBearing: false
            ))
            minX = min(minX, min(p1.x, p2.x))
            maxX = max(maxX, max(p1.x, p2.x))
            minZ = min(minZ, min(p1.z, p2.z))
            maxZ = max(maxZ, max(p1.z, p2.z))
        }

        if minX >= maxX { minX = -3.0; maxX = 3.0 }
        if minZ >= maxZ { minZ = -3.0; maxZ = 3.0 }

        guard let heading = surveyHeadingDegrees else { return nil }

        // 不再硬编码门/窗占位：AR 平面测绘不提供真实门扇与窗洞，虚构会
        // 误导鲁班门光/开门见灶/玄空旺星等下游检测。门/窗数据由
        // RoomPlan 测绘或户型图识别路径提供，AR 平面路径如实降级。
        let roomH = estimatedRoomHeightMeters ?? 2.8
        if hasLowBeamWarning {
            beams3D.append(SpatialBeam3D(
                start: SIMD3<Float>(minX, roomH - 0.25, (minZ + maxZ) * 0.5),
                end: SIMD3<Float>(maxX, roomH - 0.25, (minZ + maxZ) * 0.5),
                clearanceHeight: max(1.8, roomH - 0.35),
                beamDepth: 0.35,
                beamWidth: 0.28
            ))
        }

        let spanX = max(Float(2.0), maxX - minX)
        let spanZ = max(Float(2.0), maxZ - minZ)
        let cx = (minX + maxX) * 0.5
        let cz = (minZ + maxZ) * 0.5

        // 房间按水平平面（地板）推导：每个水平面 → 一个房间，类型按面积
        // 顺序规则分配（与 syncPlanesToFloorplan 降级口径一致）。
        struct HorizontalCandidate {
            var centerX: Float
            var centerZ: Float
            var minX: Float
            var maxX: Float
            var minZ: Float
            var maxZ: Float
            var y: Float
        }
        let rawHorizontal = planes.filter { $0.alignment == .horizontal }
        let floorY = rawHorizontal.map {
            let c = $0.transform * SIMD4<Float>($0.center.x, $0.center.y, $0.center.z, 1.0)
            return c.y
        }.min()
        var horizontalCandidates: [HorizontalCandidate] = []
        for plane in rawHorizontal {
            let center = plane.transform * SIMD4<Float>(plane.center.x, plane.center.y, plane.center.z, 1.0)
            if let floorY, center.y > floorY + 0.35 { continue }
            let corners = planeWorldCorners(for: plane)
            let xs = corners.map(\.x)
            let zs = corners.map(\.z)
            guard let minX = xs.min(), let maxX = xs.max(), let minZ = zs.min(), let maxZ = zs.max() else { continue }
            horizontalCandidates.append(HorizontalCandidate(
                centerX: center.x, centerZ: center.z,
                minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ, y: center.y
            ))
        }
        horizontalCandidates.sort { ($0.maxX - $0.minX) * ($0.maxZ - $0.minZ) > ($1.maxX - $1.minX) * ($1.maxZ - $1.minZ) }
        func boxesOverlap(_ lhs: HorizontalCandidate, _ rhs: HorizontalCandidate, gap: Float) -> Bool {
            lhs.maxX + gap >= rhs.minX && rhs.maxX + gap >= lhs.minX &&
            lhs.maxZ + gap >= rhs.minZ && rhs.maxZ + gap >= lhs.minZ
        }
        var mergedHorizontal: [HorizontalCandidate] = []
        for candidate in horizontalCandidates {
            guard let index = mergedHorizontal.firstIndex(where: { boxesOverlap($0, candidate, gap: 0.25) }) else {
                mergedHorizontal.append(candidate)
                continue
            }
            let existing = mergedHorizontal[index]
            let minX = min(existing.minX, candidate.minX)
            let maxX = max(existing.maxX, candidate.maxX)
            let minZ = min(existing.minZ, candidate.minZ)
            let maxZ = max(existing.maxZ, candidate.maxZ)
            mergedHorizontal[index] = HorizontalCandidate(
                centerX: (minX + maxX) * 0.5, centerZ: (minZ + maxZ) * 0.5,
                minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ,
                y: min(existing.y, candidate.y)
            )
        }
        for (idx, candidate) in mergedHorizontal.prefix(8).enumerated() {
            let roomType: FloorplanRoomType = (idx == 0) ? .livingRoom : ((idx == 1) ? .masterBedroom : .study)
            rooms3D.append(SpatialRoom3D(
                name: roomType.localizedName,
                type: roomType,
                center: SIMD3<Float>(candidate.centerX, roomH * 0.5, candidate.centerZ),
                size: SIMD3<Float>(max(Float(1.5), candidate.maxX - candidate.minX), roomH, max(Float(1.5), candidate.maxZ - candidate.minZ))
            ))
        }
        // 无水平平面（未扫描地板）时退化为单一客厅，并如实标注无房间分割
        if rooms3D.isEmpty {
            rooms3D.append(SpatialRoom3D(
                name: FloorplanRoomType.livingRoom.localizedName,
                type: .livingRoom,
                center: SIMD3<Float>(cx, roomH * 0.5, cz),
                size: SIMD3<Float>(spanX, roomH, spanZ)
            ))
        }
        // 合并手动角落打点生成的精准房间（Corner-pin Polygon）
        rooms3D.append(contentsOf: cornerRooms)

        let scanMethodTitle: String
        switch LocalizationManager.shared.effectiveLanguage {
        case .zhHans, .auto: scanMethodTitle = "AR 平面测绘（基础）"
        case .zhHant: scanMethodTitle = "AR 平面測繪（基礎）"
        case .en:     scanMethodTitle = "AR Plane Survey (Basic)"
        case .ja:     scanMethodTitle = "AR 平面測距（基本）"
        case .ko:     scanMethodTitle = "AR 평면 측량 (기본)"
        case .vi:     scanMethodTitle = "Khảo sát mặt phẳng AR"
        case .th:     scanMethodTitle = "สำรวจระนาบ AR (พื้นฐาน)"
        case .id:     scanMethodTitle = "Survei Bidang AR (Dasar)"
        }
        let survey = HouseSpatialSurveyEngine.analyzeSpatialHouse(
            scanMethod: scanMethodTitle,
            walls: walls3D,
            openings: openings3D,
            beams: beams3D,
            rooms: rooms3D,
            objects: objects3D,
            compassHeading: heading
        )
        // 汇入全景形煞档案（与外部标注同源消费）
        ShaSurveyStore.shared.updateInterior(survey)
        // Keep the ordinary AR result available to 户型立极 after this page
        // closes. VR corrections use a separate archive slot and must not
        // replace this measured snapshot.
        if let data = try? JSONEncoder().encode(survey) {
            UserDefaults.standard.set(data, forKey: SpatialSurveyArchiveKeys.measured)
            NotificationCenter.default.post(name: .didUpdateMeasuredSpatialSurvey, object: nil)
        }
        return survey
    }

    public func syncPlanesToFloorplan() -> Bool {
        guard surveyHeadingDegrees != nil else { return false }
        guard let frame = sceneView?.session.currentFrame else { return false }
        let planes = frame.anchors.compactMap { $0 as? ARPlaneAnchor }
        guard !planes.isEmpty else { return false }

        struct PlaneBox2D {
            let centerX: CGFloat
            let centerZ: CGFloat
            let width: CGFloat
            let depth: CGFloat
            let isVertical: Bool
        }

        var boxes: [PlaneBox2D] = []
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minZ = CGFloat.greatestFiniteMagnitude
        var maxZ = -CGFloat.greatestFiniteMagnitude

        for plane in planes {
            let worldCenter = plane.transform * SIMD4<Float>(plane.center.x, plane.center.y, plane.center.z, 1.0)
            let cx = CGFloat(worldCenter.x)
            let cz = CGFloat(worldCenter.z)
            let corners = planeWorldCorners(for: plane)
            let xs = corners.map { CGFloat($0.x) }
            let zs = corners.map { CGFloat($0.z) }
            let w = max(CGFloat(0.25), (xs.max() ?? CGFloat(worldCenter.x)) - (xs.min() ?? CGFloat(worldCenter.x)))
            let d = max(CGFloat(0.25), (zs.max() ?? CGFloat(worldCenter.z)) - (zs.min() ?? CGFloat(worldCenter.z)))
            let isVert = (plane.alignment == .vertical)
            boxes.append(PlaneBox2D(centerX: cx, centerZ: cz, width: w, depth: d, isVertical: isVert))
            minX = min(minX, cx - w * 0.5)
            maxX = max(maxX, cx + w * 0.5)
            minZ = min(minZ, cz - d * 0.5)
            maxZ = max(maxZ, cz + d * 0.5)
        }

        let spanX = max(1.2, maxX - minX)
        let spanZ = max(1.2, maxZ - minZ)
        let padX = spanX * 0.12
        let padZ = spanZ * 0.12
        let totalX = spanX + padX * 2
        let totalZ = spanZ + padZ * 2
        let originX = minX - padX
        let originZ = minZ - padZ

        var floorplanRooms: [FloorplanRoom] = []
        let horizontalBoxes = boxes.filter { !$0.isVertical }
        let sourceBoxes = horizontalBoxes.isEmpty ? boxes : horizontalBoxes
        for (idx, box) in sourceBoxes.prefix(8).enumerated() {
            let nx = max(0.05, min(0.88, (box.centerX - box.width * 0.5 - originX) / totalX))
            let ny = max(0.05, min(0.88, (box.centerZ - box.depth * 0.5 - originZ) / totalZ))
            let nw = max(0.12, min(0.90 - nx, box.width / totalX))
            let nh = max(0.12, min(0.90 - ny, box.depth / totalZ))
            let roomType: FloorplanRoomType = (idx == 0) ? .livingRoom : ((idx == 1) ? .masterBedroom : .study)
            floorplanRooms.append(
                FloorplanRoom(
                    name: roomType.localizedName,
                    type: roomType,
                    rect: CGRect(x: nx, y: ny, width: nw, height: nh)
                )
            )
        }

        // Render top-down blueprint image of all scanned horizontal & vertical planes
        let canvasSize = GeometryUtils.aspectFitRect(aspectRatio: totalX / totalZ,
                                                    in: CGRect(x: 0, y: 0, width: 900, height: 900)).size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let blueprint = renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 1.0).setFill()
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            // Subtle grid
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.06).cgColor)
            cg.setLineWidth(1)
            for step in 1..<15 {
                let x = CGFloat(step) * canvasSize.width / 15
                let y = CGFloat(step) * canvasSize.height / 15
                cg.move(to: CGPoint(x: x, y: 0))
                cg.addLine(to: CGPoint(x: x, y: canvasSize.height))
                cg.move(to: CGPoint(x: 0, y: y))
                cg.addLine(to: CGPoint(x: canvasSize.width, y: y))
            }
            cg.strokePath()

            for box in boxes {
                let rx = ((box.centerX - box.width * 0.5 - originX) / totalX) * canvasSize.width
                let ry = ((box.centerZ - box.depth * 0.5 - originZ) / totalZ) * canvasSize.height
                let rw = max(6, (box.width / totalX) * canvasSize.width)
                let rh = max(6, (box.depth / totalZ) * canvasSize.height)
                let rect = CGRect(x: rx, y: ry, width: rw, height: rh)
                if box.isVertical {
                    UIColor(red: 0.95, green: 0.78, blue: 0.30, alpha: 0.85).setStroke()
                    cg.setLineWidth(4)
                    cg.stroke(rect)
                } else {
                    UIColor(red: 0.0, green: 0.88, blue: 0.96, alpha: 0.18).setFill()
                    cg.fill(rect)
                    UIColor(red: 0.0, green: 0.88, blue: 0.96, alpha: 0.65).setStroke()
                    cg.setLineWidth(2)
                    cg.stroke(rect)
                }
            }
        }

        let weightedX = floorplanRooms.reduce(0.0) { $0 + Double($1.rect.midX) } / Double(max(1, floorplanRooms.count))
        let weightedY = floorplanRooms.reduce(0.0) { $0 + Double($1.rect.midY) } / Double(max(1, floorplanRooms.count))
        let currentSurvey = buildSpatialSurvey()
        return FloorplanView.persistRoomPlanImport(
            rooms: floorplanRooms,
            centroid: CGPoint(x: weightedX, y: weightedY),
            blueprintImage: blueprint,
            compassHeading: surveyHeadingDegrees,
            spatialSurvey: currentSurvey
        )
    }

    /// Captures a 1080×1920 holographic AR survey report image combining the live
    /// `ARSCNView` 3D scene (LiDAR mesh, 3D Lu Ban ruler, ground Bagua array) with
    /// full compass & spatial fengshui telemetry.
    public func captureSurveySnapshotReport() -> UIImage? {
        guard let view = sceneView else { return nil }
        let baseSnapshot = view.snapshot()
        guard baseSnapshot.size.width > 0, baseSnapshot.size.height > 0 else { return nil }

        let size = CGSize(width: 1080, height: 1920)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let motion = CompassMotionManager.shared
        let state = motion.headingState
        let lang = LocalizationManager.shared

        return renderer.image { ctx in
            let cg = ctx.cgContext
            let scale = max(size.width / baseSnapshot.size.width, size.height / baseSnapshot.size.height)
            let drawW = baseSnapshot.size.width * scale
            let drawH = baseSnapshot.size.height * scale
            baseSnapshot.draw(in: CGRect(x: (size.width - drawW) * 0.5, y: (size.height - drawH) * 0.5, width: drawW, height: drawH))

            let cardRect = CGRect(x: 40, y: size.height - 420, width: size.width - 80, height: 360)
            UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.88).setFill()
            UIBezierPath(roundedRect: cardRect, cornerRadius: 18).fill()
            UIColor(red: 0.85, green: 0.70, blue: 0.24, alpha: 0.85).setStroke()
            let border = UIBezierPath(roundedRect: cardRect, cornerRadius: 18)
            border.lineWidth = 2.5
            border.stroke()

            let curLang = lang.effectiveLanguage
            let imgTitle: String
            switch curLang {
            case .zhHans, .auto: imgTitle = "演象 · AR 三维全息空间与 LiDAR 勘舆存证"
            case .zhHant: imgTitle = "演象 · AR 三維全息空間與 LiDAR 勘輿存證"
            case .en:     imgTitle = "TianJi · 3D AR & LiDAR Spatial Survey Certificate"
            case .ja:     imgTitle = "天機演象・AR 3D空間＆LiDAR風水計測証憑"
            case .ko:     imgTitle = "천기연상 · AR 3D 공간 및 LiDAR 풍수 측량 증빙"
            case .vi:     imgTitle = "Thiên Cơ · Chứng Thực Đo Đạc Không Gian 3D AR & LiDAR"
            case .th:     imgTitle = "เทียนจี · หลักฐานการสำรวจมิติ 3D AR & LiDAR"
            case .id:     imgTitle = "TianJi · Bukti Survei Ruang 3D AR & LiDAR"
            }
            imgTitle.draw(
                at: CGPoint(x: 70, y: size.height - 392),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 32),
                    .foregroundColor: UIColor(red: 0.96, green: 0.86, blue: 0.45, alpha: 1.0)
                ]
            )

            var lines: [String] = []
            let sitM = state.sittingMountain.localizedName
            let facM = state.facingMountain.localizedName
            let degS = String(format: "%.1f°", state.facingAngle)
            let kwS = state.kongWangLevel.localizedTitle
            switch curLang {
            case .zhHans, .auto:
                lines.append("坐向山度: \(sitM)\(lang.t("mountain_suffix"))\(facM)\(lang.t("facing_suffix")) (\(degS)) · \(kwS)")
            case .zhHant:
                lines.append("坐向山度: \(sitM)\(lang.t("mountain_suffix"))\(facM)\(lang.t("facing_suffix")) (\(degS)) · \(kwS)")
            case .en:
                lines.append("Orientation: Sit \(sitM) Face \(facM) (\(degS)) · \(kwS)")
            case .ja:
                lines.append("座向角度: \(sitM)山\(facM)向 (\(degS)) ・ \(kwS)")
            case .ko:
                lines.append("좌향 각도: \(sitM)산 \(facM)향 (\(degS)) · \(kwS)")
            case .vi:
                lines.append("Tọa hướng: Tọa \(sitM) Hướng \(facM) (\(degS)) · \(kwS)")
            case .th:
                lines.append("ทิศนั่ง-หัน: พิง\(sitM) หัน\(facM) (\(degS)) · \(kwS)")
            case .id:
                lines.append("Orientasi: Duduk \(sitM) Hadap \(facM) (\(degS)) · \(kwS)")
            }
            if let d = distance {
                let sensorTag = lidarAvailable ? "LiDAR" : "AR"
                let dStr = String(format: "%.2f m", d)
                switch curLang {
                case .zhHans, .auto: lines.append("天心测距: \(sensorTag) \(dStr) · 识别平面: \(planeCount) 处 (网格 \(meshAnchorCount))")
                case .zhHant: lines.append("天心測距: \(sensorTag) \(dStr) · 識別平面: \(planeCount) 處 (網格 \(meshAnchorCount))")
                case .en:     lines.append("Center Range: \(sensorTag) \(dStr) · Planes: \(planeCount) (Mesh \(meshAnchorCount))")
                case .ja:     lines.append("天心測距: \(sensorTag) \(dStr) ・ 検出平面: \(planeCount)箇所 (メッシュ \(meshAnchorCount))")
                case .ko:     lines.append("천심 거리: \(sensorTag) \(dStr) · 감지 평면: \(planeCount)곳 (메시 \(meshAnchorCount))")
                case .vi:     lines.append("Đo tâm: \(sensorTag) \(dStr) · Mặt phẳng: \(planeCount) (Lưới \(meshAnchorCount))")
                case .th:     lines.append("ระยะจุดกลาง: \(sensorTag) \(dStr) · ระนาบ: \(planeCount) จุด (เมช \(meshAnchorCount))")
                case .id:     lines.append("Jarak Pusat: \(sensorTag) \(dStr) · Bidang: \(planeCount) (Mesh \(meshAnchorCount))")
                }
            }
            if let standing = currentStandingPalace {
                switch curLang {
                case .zhHans, .auto: lines.append("九宫踏勘: \(standing)")
                case .zhHant: lines.append("九宮踏勘: \(standing)")
                case .en:     lines.append("9-Palace Sector: \(standing)")
                case .ja:     lines.append("九宮踏査: \(standing)")
                case .ko:     lines.append("구궁 답사: \(standing)")
                case .vi:     lines.append("Cửu cung hiện tại: \(standing)")
                case .th:     lines.append("ตำแหน่งเก้าเรือน: \(standing)")
                case .id:     lines.append("Sektor 9-Istana: \(standing)")
                }
            }
            if let eval = lubanEvaluation {
                let evalStr = eval.localizedSummary(for: lang.effectiveLanguage)
                switch curLang {
                case .zhHans, .auto: lines.append("三维鲁班: \(evalStr)")
                case .zhHant: lines.append("三維魯班: \(evalStr)")
                case .en:     lines.append("3D Lu Ban: \(evalStr)")
                case .ja:     lines.append("3D魯班尺: \(evalStr)")
                case .ko:     lines.append("3D 노반척: \(evalStr)")
                case .vi:     lines.append("Lỗ Ban 3D: \(evalStr)")
                case .th:     lines.append("หลู่ปาน 3D: \(evalStr)")
                case .id:     lines.append("Lu Ban 3D: \(evalStr)")
                }
            }
            if let h = estimatedRoomHeightMeters {
                let beamTag = hasLowBeamWarning ? lang.t("ar_spatial_beam_warning") : lang.t("ar_spatial_ceiling_good")
                let hStr = String(format: "%.2f m", h)
                switch curLang {
                case .zhHans, .auto: lines.append("空间净高: \(hStr) (\(beamTag))")
                case .zhHant: lines.append("空間淨高: \(hStr) (\(beamTag))")
                case .en:     lines.append("Clear Height: \(hStr) (\(beamTag))")
                case .ja:     lines.append("有効天井高: \(hStr) (\(beamTag))")
                case .ko:     lines.append("실내 유효 층고: \(hStr) (\(beamTag))")
                case .vi:     lines.append("Cao thông thủy: \(hStr) (\(beamTag))")
                case .th:     lines.append("ความสูงเพดาน: \(hStr) (\(beamTag))")
                case .id:     lines.append("Tinggi Plafon: \(hStr) (\(beamTag))")
                }
            }
            switch curLang {
            case .zhHans, .auto: lines.append("定位与真太阳时: \(motion.coordsDesc) · \(motion.trueSolarTimeStr)")
            case .zhHant: lines.append("定位與真太陽時: \(motion.coordsDesc) · \(motion.trueSolarTimeStr)")
            case .en:     lines.append("GPS & True Solar Time: \(motion.coordsDesc) · \(motion.trueSolarTimeStr)")
            case .ja:     lines.append("測位・真太陽時: \(motion.coordsDesc) ・ \(motion.trueSolarTimeStr)")
            case .ko:     lines.append("위치 및 진태양시: \(motion.coordsDesc) · \(motion.trueSolarTimeStr)")
            case .vi:     lines.append("Tọa độ & Giờ Mặt Trời: \(motion.coordsDesc) · \(motion.trueSolarTimeStr)")
            case .th:     lines.append("พิกัดและเวลาสุริยะจริง: \(motion.coordsDesc) · \(motion.trueSolarTimeStr)")
            case .id:     lines.append("GPS & Waktu Surya Sejati: \(motion.coordsDesc) · \(motion.trueSolarTimeStr)")
            }

            let bodyText = lines.joined(separator: "\n")
            bodyText.draw(
                in: CGRect(x: 70, y: size.height - 336, width: size.width - 140, height: 260),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 22, weight: .semibold),
                    .foregroundColor: UIColor.white
                ]
            )
            _ = cg
        }
    }

    public func clearLubanPoints() {
        lubanPointA = nil
        lubanPointB = nil
        lubanSpanMeters = nil
        lubanEvaluation = nil
        lubanNodeA?.removeFromParentNode()
        lubanNodeB?.removeFromParentNode()
        lubanLineNode?.removeFromParentNode()
        lubanNodeA = nil
        lubanNodeB = nil
        lubanLineNode = nil
        for anchor in lubanAnchors {
            sceneView?.session.remove(anchor: anchor)
        }
        lubanAnchors.removeAll()
    }

    /// Places a 3D Lu Ban ruler endpoint at the current center reticle hit position
    /// and persists a corresponding ARAnchor so saved ARWorldMaps retain the survey point.
    @discardableResult
    public func placeLubanPoint() -> Bool {
        guard let sceneView = sceneView,
              let frame = sceneView.session.currentFrame else { return false }
        let center = projectionCenter(of: sceneView)

        var resolvedWorldPos: SIMD3<Float>?
        let target: ARRaycastQuery.Target = lidarAvailable ? .existingPlaneGeometry : .estimatedPlane
        if let result = sceneView.raycastQuery(from: center, allowing: target, alignment: .any)
            .flatMap({ sceneView.session.raycast($0).first })
            ?? sceneView.raycastQuery(from: center, allowing: .estimatedPlane, alignment: .any)
                .flatMap({ sceneView.session.raycast($0).first }) {
            let col = result.worldTransform.columns.3
            resolvedWorldPos = SIMD3<Float>(col.x, col.y, col.z)
        } else if let dist = distance, dist > 0.05, dist < 30.0 {
            let camTransform = frame.camera.transform
            let camPos = SIMD3<Float>(camTransform.columns.3.x, camTransform.columns.3.y, camTransform.columns.3.z)
            let forward = -SIMD3<Float>(camTransform.columns.2.x, camTransform.columns.2.y, camTransform.columns.2.z)
            resolvedWorldPos = camPos + simd_normalize(forward) * dist
        }

        guard let worldPos = resolvedWorldPos else { return false }

        let isNewMeasurement = lubanPointA == nil || (lubanPointA != nil && lubanPointB != nil)
        if isNewMeasurement {
            clearLubanPoints()
        }

        var anchorTransform = matrix_identity_float4x4
        anchorTransform.columns.3 = SIMD4<Float>(worldPos.x, worldPos.y, worldPos.z, 1.0)
        let anchor = ARAnchor(name: "luban-anchor", transform: anchorTransform)
        sceneView.session.add(anchor: anchor)
        lubanAnchors.append(anchor)

        if isNewMeasurement {
            lubanPointA = worldPos
        } else if let pointA = lubanPointA {
            lubanPointB = worldPos

            let span = simd_distance(pointA, worldPos)
            lubanSpanMeters = span
            let eval = LubanRulerEvaluation.evaluate(meters: span)
            lubanEvaluation = eval

            let lineColor = eval.yangIsAuspicious
                ? UIColor(red: 0.18, green: 0.88, blue: 0.48, alpha: 0.92)
                : UIColor(red: 0.96, green: 0.32, blue: 0.28, alpha: 0.92)
            let lineNode = Self.makeLineNode(from: pointA, to: worldPos, color: lineColor)
            sceneView.scene.rootNode.addChildNode(lineNode)
            lubanLineNode = lineNode
        }
        return true
    }

    // MARK: - 手动角落打点连续测绘 (Corner-pin Polygon)
    /// 在屏幕中央准星处落一个墙角点。弱纹理墙面（纯白乳胶漆）平面检测易漂移，
    /// 用户依次点出 ≥3 个墙角可快速拉出精准房间，弥补 ARPlaneAnchor 拼接断裂。
    @discardableResult
    public func pinCornerPoint() -> Bool {
        guard cornerPinActive else { return false }
        guard let sceneView = sceneView, let frame = sceneView.session.currentFrame else { return false }
        let center = projectionCenter(of: sceneView)
        var worldPos: SIMD3<Float>?
        if let result = sceneView.raycastQuery(from: center, allowing: .estimatedPlane, alignment: .any)
            .flatMap({ sceneView.session.raycast($0).first })
            ?? sceneView.raycastQuery(from: center, allowing: .existingPlaneGeometry, alignment: .any)
                .flatMap({ sceneView.session.raycast($0).first }) {
            let col = result.worldTransform.columns.3
            worldPos = SIMD3<Float>(col.x, col.y, col.z)
        } else if let dist = distance, dist > 0.05, dist < 30.0 {
            let camTransform = frame.camera.transform
            let camPos = SIMD3<Float>(camTransform.columns.3.x, camTransform.columns.3.y, camTransform.columns.3.z)
            let forward = -SIMD3<Float>(camTransform.columns.2.x, camTransform.columns.2.y, camTransform.columns.2.z)
            worldPos = camPos + simd_normalize(forward) * dist
        }
        guard let pos = worldPos else { return false }

        var anchorTransform = matrix_identity_float4x4
        anchorTransform.columns.3 = SIMD4<Float>(pos.x, pos.y, pos.z, 1.0)
        let anchor = ARAnchor(name: "corner-pin", transform: anchorTransform)
        sceneView.session.add(anchor: anchor)
        cornerRoomAnchors.append(anchor)

        cornerPoints.append(pos)
        return true
    }

    /// 完成当前打点房间：角点数 ≥3 时以多边形包围盒生成一个精准房间并重跑报告
    @discardableResult
    public func finishCornerRoom() -> Bool {
        guard cornerPoints.count >= 3 else { return false }
        let meanX = cornerPoints.reduce(Float(0)) { $0 + $1.x } / Float(cornerPoints.count)
        let meanZ = cornerPoints.reduce(Float(0)) { $0 + $1.z } / Float(cornerPoints.count)
        var covarianceXX: Float = 0
        var covarianceXZ: Float = 0
        var covarianceZZ: Float = 0
        for point in cornerPoints {
            let dx = point.x - meanX
            let dz = point.z - meanZ
            covarianceXX += dx * dx
            covarianceXZ += dx * dz
            covarianceZZ += dz * dz
        }
        // Principal-axis OBB keeps a diagonal or rotated hand-pinned room
        // aligned with the measured corners. An axis-aligned AABB inflated
        // the room and moved its 九宫 position whenever the user walked a
        // diagonal wall.
        let rotation = 0.5 * atan2(2.0 * covarianceXZ, covarianceXX - covarianceZZ)
        let cosR = cos(rotation)
        let sinR = sin(rotation)
        var minLocalX: Float = .greatestFiniteMagnitude
        var maxLocalX: Float = -.greatestFiniteMagnitude
        var minLocalZ: Float = .greatestFiniteMagnitude
        var maxLocalZ: Float = -.greatestFiniteMagnitude
        for point in cornerPoints {
            let dx = point.x - meanX
            let dz = point.z - meanZ
            let localX = dx * cosR + dz * sinR
            let localZ = -dx * sinR + dz * cosR
            minLocalX = min(minLocalX, localX); maxLocalX = max(maxLocalX, localX)
            minLocalZ = min(minLocalZ, localZ); maxLocalZ = max(maxLocalZ, localZ)
        }
        guard maxLocalX - minLocalX >= 1.0, maxLocalZ - minLocalZ >= 1.0 else {
            clearCornerPins()
            return false
        }
        let localCenterX = (minLocalX + maxLocalX) * 0.5
        let localCenterZ = (minLocalZ + maxLocalZ) * 0.5
        let centerX = meanX + localCenterX * cosR - localCenterZ * sinR
        let centerZ = meanZ + localCenterX * sinR + localCenterZ * cosR
        let roomH = estimatedRoomHeightMeters ?? 2.8
        let room = SpatialRoom3D(
            name: FloorplanRoomType.livingRoom.localizedName,
            type: .livingRoom,
            center: SIMD3<Float>(centerX, roomH * 0.5, centerZ),
            size: SIMD3<Float>(maxLocalX - minLocalX, roomH, maxLocalZ - minLocalZ),
            rotationY: rotation
        )
        cornerRooms.append(room)
        clearCornerPins()
        cornerRoomCount = cornerRooms.count
        _ = buildSpatialSurvey()
        return true
    }

    /// 清空当前未完成的打点（含 3D 标记与 ARAnchor）
    public func clearCornerPins() {
        for node in cornerPinNodes { node.removeFromParentNode() }
        cornerPinNodes.removeAll()
        for anchor in cornerRoomAnchors { sceneView?.session.remove(anchor: anchor) }
        cornerRoomAnchors.removeAll()
        cornerPoints.removeAll()
    }

    private func clearCornerRooms() {
        clearCornerPins()
        cornerRooms.removeAll()
        cornerRoomCount = 0
    }

    private func planeWorldCorners(for plane: ARPlaneAnchor) -> [SIMD3<Float>] {
        let hx = plane.planeExtent.width * 0.5
        let hz = plane.planeExtent.height * 0.5
        return [
            SIMD3<Float>((plane.transform * SIMD4<Float>(plane.center.x - hx, plane.center.y, plane.center.z - hz, 1.0)).x,
                         (plane.transform * SIMD4<Float>(plane.center.x - hx, plane.center.y, plane.center.z - hz, 1.0)).y,
                         (plane.transform * SIMD4<Float>(plane.center.x - hx, plane.center.y, plane.center.z - hz, 1.0)).z),
            SIMD3<Float>((plane.transform * SIMD4<Float>(plane.center.x + hx, plane.center.y, plane.center.z - hz, 1.0)).x,
                         (plane.transform * SIMD4<Float>(plane.center.x + hx, plane.center.y, plane.center.z - hz, 1.0)).y,
                         (plane.transform * SIMD4<Float>(plane.center.x + hx, plane.center.y, plane.center.z - hz, 1.0)).z),
            SIMD3<Float>((plane.transform * SIMD4<Float>(plane.center.x + hx, plane.center.y, plane.center.z + hz, 1.0)).x,
                         (plane.transform * SIMD4<Float>(plane.center.x + hx, plane.center.y, plane.center.z + hz, 1.0)).y,
                         (plane.transform * SIMD4<Float>(plane.center.x + hx, plane.center.y, plane.center.z + hz, 1.0)).z),
            SIMD3<Float>((plane.transform * SIMD4<Float>(plane.center.x - hx, plane.center.y, plane.center.z + hz, 1.0)).x,
                         (plane.transform * SIMD4<Float>(plane.center.x - hx, plane.center.y, plane.center.z + hz, 1.0)).y,
                         (plane.transform * SIMD4<Float>(plane.center.x - hx, plane.center.y, plane.center.z + hz, 1.0)).z)
        ]
    }

    /// 采样界面归一化坐标处的 LiDAR 深度或射线距离。
    /// `point` 是**当前界面方向**下的 0~1 归一化坐标（与 SwiftUI 视图坐标系同向），
    /// 内部用 ARKit 的 `displayTransform` 反投影回相机图像坐标，
    /// 因此 iPhone 竖屏、iPad 横屏/倒竖共用同一套逻辑，不再手写方向映射。
    public func sampleDepth(atViewNormalizedPoint point: CGPoint) -> Float? {
        guard let sceneView = sceneView,
              let frame = sceneView.session.currentFrame else {
            return distance
        }
        let nx = Float(min(max(point.x, 0.02), 0.98))
        let ny = Float(min(max(point.y, 0.02), 0.98))
        let viewSize = sceneView.bounds.size
        if lidarAvailable {
            let depthMap: CVPixelBuffer?
            let confidenceMap: CVPixelBuffer?
            if #available(iOS 14.0, *), let smoothed = frame.smoothedSceneDepth {
                depthMap = smoothed.depthMap
                confidenceMap = smoothed.confidenceMap
            } else {
                depthMap = frame.sceneDepth?.depthMap
                confidenceMap = frame.sceneDepth?.confidenceMap
            }
            if viewSize.width > 0, viewSize.height > 0 {
                let orientation = sceneView.window?.windowScene?.interfaceOrientation ?? .portrait
                let viewPoint = CGPoint(x: CGFloat(nx), y: CGFloat(ny))
                let imagePoint = viewPoint.applying(
                    frame.displayTransform(for: orientation, viewportSize: viewSize).inverted()
                )
                let imageX = Float(min(max(imagePoint.x, 0), 1))
                let imageY = Float(min(max(imagePoint.y, 0), 1))
                if let sampled = Self.depthSample(
                    from: depthMap,
                    confidenceMap: confidenceMap,
                    imageNormX: imageX,
                    imageNormY: imageY
                ) {
                    return sampled
                }
            }
        }
        if sceneView.bounds.width > 0, sceneView.bounds.height > 0 {
            let screenPt = CGPoint(
                x: CGFloat(nx) * sceneView.bounds.width,
                y: CGFloat(ny) * sceneView.bounds.height
            )
            if let result = sceneView.raycastQuery(from: screenPt, allowing: .estimatedPlane, alignment: .any)
                .flatMap({ sceneView.session.raycast($0).first }) {
                let cam = frame.camera.transform.columns.3
                let hit = result.worldTransform.columns.3
                let d = simd_distance(SIMD3<Float>(cam.x, cam.y, cam.z), SIMD3<Float>(hit.x, hit.y, hit.z))
                if d.isFinite, d > 0.05, d < 60.0 {
                    return d
                }
            }
        }
        return distance
    }

    private static func makeMarkerNode(position: SIMD3<Float>, color: UIColor) -> SCNNode {
        let sphere = SCNSphere(radius: 0.016)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .constant
        sphere.materials = [mat]
        let node = SCNNode(geometry: sphere)
        node.position = SCNVector3(position.x, position.y, position.z)
        return node
    }

    private static func makeLineNode(from start: SIMD3<Float>, to end: SIMD3<Float>, color: UIColor) -> SCNNode {
        let indices: [Int32] = [0, 1]
        let vertices = [SCNVector3(start.x, start.y, start.z), SCNVector3(end.x, end.y, end.z)]
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        geometry.materials = [mat]
        return SCNNode(geometry: geometry)
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
            let archive = try SpatialWorldMapArchive.decode(Data(contentsOf: mapURL))
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: archive.mapData) else {
                completion(.failure(ARSpatialSurveyError.archiveFailed))
                return
            }
            guard let configuration = baseConfig.copy() as? ARWorldTrackingConfiguration else {
                completion(.failure(ARSpatialSurveyError.sessionUnavailable))
                return
            }
            clearLubanPoints()
            clearCornerRooms()
            clearGroundBaguaOverlay()
            sessionGeneration += 1
            surveyHeadingDegrees = archive.coordinateHeading
            hasHeadingReference = true
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
        let interfaceOrientation = sceneView?.window?.windowScene?.interfaceOrientation ?? .portrait
        guard let fullImage = Self.image(from: frame.capturedImage, interfaceOrientation: interfaceOrientation) else {
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
        let confidenceMap: CVPixelBuffer?
        if #available(iOS 14.0, *), let smoothed = frame.smoothedSceneDepth {
            depthMap = smoothed.depthMap
            confidenceMap = smoothed.confidenceMap
        } else {
            depthMap = frame.sceneDepth?.depthMap
            confidenceMap = frame.sceneDepth?.confidenceMap
        }
        let viewport = sceneView?.bounds.size ?? fullImage.size
        let image = ARCapturedFrame.viewportImage(fullImage, size: viewport)
        let projection = Self.viewportProjection(for: frame, orientation: interfaceOrientation, size: viewport)
        let forward = -SIMD3<Float>(frame.camera.transform.columns.2.x, frame.camera.transform.columns.2.y, frame.camera.transform.columns.2.z)
        let worldYaw = atan2(Double(forward.x), Double(-forward.z)) * 180 / .pi
        let pose: ARCapturePose? = (frameTrackingIsNormal ? surveyHeadingDegrees : nil).flatMap { baseline in
            projection.map { ARCapturePose(heading: (baseline + worldYaw + 720).truncatingRemainder(dividingBy: 360),
                                          elevation: asin(max(-1, min(1, Double(forward.y)))) * 180 / .pi,
                                          projection: $0) }
        }
        let capturedDepth = ARCapturedDepth.capture(depthMap, confidence: confidenceMap,
            viewToImage: frame.displayTransform(for: interfaceOrientation, viewportSize: viewport).inverted())
        let evidence = ARSceneEvidence(
            trackingIsNormal: frameTrackingIsNormal,
            mappingIsUsable: frameMappingIsUsable,
            lidarAvailable: lidarAvailable,
            depthStreamAvailable: depthMap != nil,
            depthCoverage: Self.depthCoverage(from: depthMap, confidenceMap: confidenceMap),
            horizontalFOVDegrees: projection?.horizontalFOVDegrees,
            verticalPlaneCount: frame.anchors
                .compactMap { $0 as? ARPlaneAnchor }
                .filter { $0.alignment == .vertical }
                .count,
            wallFaceCount: Self.wallFaceCount(in: frame.anchors),
            depthSampleMeters: capturedDepth?.sample(at: CGPoint(x: 0.5, y: 0.5)),
            leftDepthMeters: capturedDepth?.sample(at: CGPoint(x: 0.25, y: 0.5)),
            rightDepthMeters: capturedDepth?.sample(at: CGPoint(x: 0.75, y: 0.5)),
            topDepthMeters: capturedDepth?.sample(at: CGPoint(x: 0.5, y: 0.25)),
            bottomDepthMeters: capturedDepth?.sample(at: CGPoint(x: 0.5, y: 0.78)),
            timestamp: frame.timestamp
        )
        DispatchQueue.main.async {
            completion(ARCapturedFrame(image: image, evidence: evidence, pose: pose, depth: capturedDepth))
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

        guard let coordinateHeading = surveyHeadingDegrees, coordinateHeading.isFinite else {
            completion(.failure(ARSpatialSurveyError.mapOrientationUnavailable))
            return
        }
        let generation = sessionGeneration
        session.getCurrentWorldMap { worldMap, error in
            DispatchQueue.main.async {
                guard self.sessionGeneration == generation else {
                    completion(.failure(ARSpatialSurveyError.sessionUnavailable))
                    return
                }
                guard let worldMap = worldMap, error == nil else {
                    completion(.failure(error ?? ARSpatialSurveyError.mapUnavailable))
                    return
                }
                do {
                    let mapData = try NSKeyedArchiver.archivedData(
                        withRootObject: worldMap,
                        requiringSecureCoding: true
                    )
                    let archive = try SpatialWorldMapArchive(mapData: mapData, coordinateHeading: coordinateHeading)
                    let data = try JSONEncoder().encode(archive)
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
        sessionGeneration += 1
        clearLubanPoints()
        clearCornerRooms()
        clearGroundBaguaOverlay()
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
        estimatedRoomHeightMeters = nil
        hasLowBeamWarning = false
        surveyHeadingDegrees = nil
        currentCameraPose = nil
        cameraHorizontalFOVDegrees = nil
        hasHeadingReference = false
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
            self.retryCount = 0
            self.trackingState = state
            if state == .normal, self.surveyHeadingDegrees == nil {
                let forward = -SIMD3<Float>(frame.camera.transform.columns.2.x,
                                           frame.camera.transform.columns.2.y,
                                           frame.camera.transform.columns.2.z)
                self.surveyHeadingDegrees = SurveyCoordinateReference.heading(
                    cameraHeading: CompassMotionManager.shared.physicalHeading(), cameraForward: forward)
                self.hasHeadingReference = self.surveyHeadingDegrees != nil
            }
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
            self?.retryStart(failedSession: session)
        }
    }

    /// Recovers the AR session after a start failure (e.g. the camera was
    /// briefly held by the plain camera session during a fast lens flip), so
    /// the live preview does not stay black forever.
    private func retryStart(failedSession: ARSession) {
        guard let sceneView = sceneView, sceneView.session === failedSession,
              let configuration = activeConfiguration else { return }
        // Give up after 3 attempts for this session.  Do NOT reset the counter
        // here: a persistent failure (e.g. camera stays busy) would otherwise
        // restart the retry ladder on every didFailWithError, resetting
        // tracking on the main thread forever and freezing the UI.  A fresh
        // start() resets the counter, so the next lens flip gets full retries.
        guard retryCount < 3 else { return }
        retryCount += 1
        let delay = Double(retryCount) * 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, let current = self.sceneView,
                  current.session === failedSession else { return }
            self.trackingState = .initializing
            if configuration.initialWorldMap == nil {
                self.surveyHeadingDegrees = nil
                self.hasHeadingReference = false
            }
            current.session.pause()
            current.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
    }

    private func updateMeasurements(frame: ARFrame, sceneView: ARSCNView) {
        let anchors = frame.anchors
        let orientation = sceneView.window?.windowScene?.interfaceOrientation ?? .portrait
        if let projection = Self.viewportProjection(for: frame, orientation: orientation, size: sceneView.bounds.size),
           abs((cameraHorizontalFOVDegrees ?? 0) - projection.horizontalFOVDegrees) > 0.1 {
            cameraHorizontalFOVDegrees = projection.horizontalFOVDegrees
        }
        let forwardY = min(1.0, max(-1.0, Double(-frame.camera.transform.columns.2.y)))
        let rightY = min(1.0, max(-1.0, Double(-frame.camera.transform.columns.1.y)))
        cameraElevationDegrees = asin(forwardY) * 180.0 / .pi
        cameraRollDegrees = asin(rightY) * 180.0 / .pi
        if trackingState == .normal, let baseline = surveyHeadingDegrees,
           let projection = Self.viewportProjection(for: frame, orientation: orientation, size: sceneView.bounds.size) {
            let forward = -frame.camera.transform.columns.2
            let yaw = atan2(Double(forward.x), Double(-forward.z)) * 180 / .pi
            currentCameraPose = ARCapturePose(heading: (baseline + yaw + 720).truncatingRemainder(dividingBy: 360),
                                             elevation: cameraElevationDegrees, projection: projection)
        } else { currentCameraPose = nil }
        if groundBaguaProjected {
            updateStandingPalace(cameraTransform: frame.camera.transform)
        }

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
        savedAnchorCount = anchors.filter { $0.name?.hasPrefix("luban-anchor") == true }.count
        let horizontalPlanes = planes.filter { $0.alignment == .horizontal }
        let ys = horizontalPlanes.map { $0.transform.columns.3.y }.sorted()
        if let minY = ys.first, let maxY = ys.last, maxY - minY >= 1.75 && maxY - minY <= 5.5 {
            let h = maxY - minY
            estimatedRoomHeightMeters = h
            hasLowBeamWarning = (h < 2.42)
        } else if let maxVertH = planes.filter({ $0.alignment == .vertical }).map({ $0.planeExtent.height }).max(),
                  maxVertH >= 1.85 && maxVertH <= 5.2 {
            estimatedRoomHeightMeters = maxVertH
            hasLowBeamWarning = (maxVertH < 2.42)
        }
        if let largest = planes.max(by: { $0.planeExtent.width * $0.planeExtent.height < $1.planeExtent.width * $1.planeExtent.height }) {
            largestPlaneWidth = largest.planeExtent.width
            largestPlaneDepth = largest.planeExtent.height
        } else {
            largestPlaneWidth = nil
            largestPlaneDepth = nil
        }

        let center = projectionCenter(of: sceneView)

        var measuredDistance: Float? = nil

        // 1. 优先使用 LiDAR 硬件直接测距（Time-of-Flight 激光毫米级点测 + 置信度过滤）
        if lidarAvailable {
            let depthMap: CVPixelBuffer?
            let confidenceMap: CVPixelBuffer?
            if #available(iOS 14.0, *), let smoothed = frame.smoothedSceneDepth {
                depthMap = smoothed.depthMap
                confidenceMap = smoothed.confidenceMap
            } else {
                depthMap = frame.sceneDepth?.depthMap
                confidenceMap = frame.sceneDepth?.confidenceMap
            }
            if let depthVal = Self.centerDepthSample(from: depthMap, confidenceMap: confidenceMap), depthVal > 0.05, depthVal < 60.0 {
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

    private static func image(from pixelBuffer: CVPixelBuffer,
                             interfaceOrientation: UIInterfaceOrientation = .portrait) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        // ARKit 的 `capturedImage` 恒为 landscape-right 像素缓冲：界面在竖屏时要转 90° 才正立，
        // 界面在横屏时只需 0°/180°。写死 .right 会让 iPad 横屏（以及 Duo 展开）拍出的
        // 存证照片与 AI 取帧整张歪 90°。
        return UIImage(cgImage: cgImage, scale: 1,
                       orientation: pixelBufferOrientation(for: interfaceOrientation))
    }

    /// 界面方向 → 横向像素缓冲的显示朝向。
    /// 竖屏 / 倒竖沿用久经验证的 .right / .left；横屏两个方向互为 180°，
    /// 若真机上 iPad 横屏取帧上下颠倒，只需把 .landscapeLeft / .landscapeRight 的返回值对调。
    private static func pixelBufferOrientation(for orientation: UIInterfaceOrientation) -> UIImage.Orientation {
        switch orientation {
        case .portrait: return .right
        case .portraitUpsideDown: return .left
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        default: return .right
        }
    }

    private static func centerDepthSample(from depthMap: CVPixelBuffer?, confidenceMap: CVPixelBuffer? = nil) -> Float? {
        return regionalDepthSample(from: depthMap, confidenceMap: confidenceMap, portraitNormX: 0.5, portraitNormY: 0.5)
    }

    /// 区域扫描使用的竖屏归一化采样点。
    /// ARKit 的相机与深度缓冲区是 landscape-right，竖屏 UI 下 X 对应 buffer Y、
    /// Y 对应反向 buffer X；这里只做坐标换算，实际采样统一走 `depthSample`。
    /// 传入 LiDAR `confidenceMap` 时会丢弃低置信度（< 1）像素，避免玻璃反射与边缘噪声。
    private static func regionalDepthSample(
        from depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer? = nil,
        portraitNormX: Float,
        portraitNormY: Float
    ) -> Float? {
        depthSample(
            from: depthMap,
            confidenceMap: confidenceMap,
            imageNormX: 1.0 - portraitNormY,
            imageNormY: portraitNormX
        )
    }

    /// 在**图像归一化坐标**（0~1，右为 +X、下为 +Y）处取 3×3 邻域深度中位数。
    /// 坐标由 `ARFrame.displayTransform` 反投影得到，所以横屏、竖屏、倒竖都正确，
    /// 不再依赖"UI 一定是竖屏"这一假设。
    private static func depthSample(
        from depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer? = nil,
        imageNormX: Float,
        imageNormY: Float
    ) -> Float? {
        guard let depthMap = depthMap else { return nil }
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        var confBase: UnsafeMutableRawPointer? = nil
        var confBytesPerRow = 0
        if let confidenceMap = confidenceMap,
           CVPixelBufferGetWidth(confidenceMap) == width,
           CVPixelBufferGetHeight(confidenceMap) == height {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            confBase = CVPixelBufferGetBaseAddress(confidenceMap)
            confBytesPerRow = CVPixelBufferGetBytesPerRow(confidenceMap)
        }
        defer {
            if let confidenceMap = confidenceMap, confBase != nil {
                CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
            }
        }

        let bufferX = min(width - 1, max(0, Int(Float(width) * imageNormX)))
        let bufferY = min(height - 1, max(0, Int(Float(height) * imageNormY)))
        var samples: [Float] = []
        for dy in -1...1 {
            let y = min(height - 1, max(0, bufferY + dy))
            let row = baseAddress.advanced(by: y * bytesPerRow)
                .assumingMemoryBound(to: Float32.self)
            let confRow = confBase?.advanced(by: y * confBytesPerRow)
                .assumingMemoryBound(to: UInt8.self)
            for dx in -1...1 {
                let x = min(width - 1, max(0, bufferX + dx))
                if let confRow = confRow, confRow[x] < 1 {
                    continue
                }
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

    private static func depthCoverage(from depthMap: CVPixelBuffer?, confidenceMap: CVPixelBuffer? = nil) -> Float {
        guard let depthMap = depthMap else { return 0 }
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return 0 }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard width > 0, height > 0 else { return 0 }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        var confBase: UnsafeMutableRawPointer? = nil
        var confBytesPerRow = 0
        if let confidenceMap = confidenceMap,
           CVPixelBufferGetWidth(confidenceMap) == width,
           CVPixelBufferGetHeight(confidenceMap) == height {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            confBase = CVPixelBufferGetBaseAddress(confidenceMap)
            confBytesPerRow = CVPixelBufferGetBytesPerRow(confidenceMap)
        }
        defer {
            if let confidenceMap = confidenceMap, confBase != nil {
                CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
            }
        }

        var valid = 0
        let total = 25
        for rowIndex in 0..<5 {
            let y = min(height - 1, max(0, height * (rowIndex + 1) / 6))
            let row = baseAddress.advanced(by: y * bytesPerRow)
                .assumingMemoryBound(to: Float32.self)
            let confRow = confBase?.advanced(by: y * confBytesPerRow)
                .assumingMemoryBound(to: UInt8.self)
            for columnIndex in 0..<5 {
                let x = min(width - 1, max(0, width * (columnIndex + 1) / 6))
                if let confRow = confRow, confRow[x] < 1 {
                    continue
                }
                let value = row[x]
                if value.isFinite && value > 0.05 && value < 60.0 { valid += 1 }
            }
        }
        return Float(valid) / Float(total)
    }

    private static func viewportProjection(for frame: ARFrame, orientation: UIInterfaceOrientation, size: CGSize) -> ARTargetProjection? {
        guard size.width > 0, size.height > 0 else { return nil }
        let portrait = orientation == .portrait || orientation == .portraitUpsideDown
        let width = Double(portrait ? frame.camera.imageResolution.height : frame.camera.imageResolution.width)
        let height = Double(portrait ? frame.camera.imageResolution.width : frame.camera.imageResolution.height)
        let focal = Double(portrait ? frame.camera.intrinsics.columns.1.y : frame.camera.intrinsics.columns.0.x)
        guard width > 0, height > 0, focal > 0 else { return nil }
        let scale = max(Double(size.width) / width, Double(size.height) / height)
        let visibleWidth = Double(size.width) / scale
        return ARTargetProjection(horizontalFOVDegrees: 2 * atan(visibleWidth / (2 * focal)) * 180 / .pi,
                                  aspectRatio: Double(size.width / size.height))
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
        if anchor.name?.hasPrefix("luban-anchor") == true {
            let sphere = SCNSphere(radius: 0.014)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor(red: 0.95, green: 0.80, blue: 0.25, alpha: 0.90)
            mat.lightingModel = .constant
            sphere.materials = [mat]
            let node = SCNNode(geometry: sphere)
            node.name = "ar-luban-anchor"
            return node
        }
        if anchor.name?.hasPrefix("corner-pin") == true {
            let sphere = SCNSphere(radius: 0.016)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 0.95)
            mat.lightingModel = .constant
            sphere.materials = [mat]
            let node = SCNNode(geometry: sphere)
            node.name = "ar-corner-pin"
            return node
        }
        guard rendersSpatialMesh else { return nil }
        if let meshAnchor = anchor as? ARMeshAnchor {
            guard let geometry = meshGeometry(for: meshAnchor) else { return nil }
            let node = SCNNode(geometry: geometry)
            node.name = "ar-spatial-mesh"
            node.isHidden = !meshVisible
            return node
        }
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return nil }
        let node = SCNNode()
        node.name = "ar-spatial-plane"
        node.geometry = planeGeometry(for: planeAnchor)
        node.isHidden = !meshVisible
        // ARSCNView supplies the anchor transform to this node; center is
        // therefore applied in the anchor's local frame (the same convention
        // used by ARPlaneAnchor's extent), rather than transformed a second
        // time into world coordinates.
        node.position = SCNVector3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        // SCNPlane lies in local XY. Horizontal AR planes expose their second
        // extent along local Z, so rotate the outline onto XZ. Vertical planes
        // already use the anchor's upright frame and must retain zero roll;
        // applying the horizontal rotation here made wall outlines lie flat.
        node.eulerAngles.x = planeAnchor.alignment == .horizontal ? -.pi / 2 : 0
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
        node.position = SCNVector3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        node.eulerAngles.x = planeAnchor.alignment == .horizontal ? -.pi / 2 : 0
    }

    private func planeGeometry(for anchor: ARPlaneAnchor) -> SCNGeometry {
        let plane = SCNPlane(width: CGFloat(anchor.planeExtent.width), height: CGFloat(anchor.planeExtent.height))
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
        let indexCount = faces.count * 3
        let faceByteCount = indexCount * faces.bytesPerIndex
        // ARGeometryElement exposes the index buffer from its first index;
        // unlike SCNGeometryElement it has no public offset property. Each
        // triangle contributes three indices, so size the data accordingly.
        guard faceByteCount <= faces.buffer.length else { return nil }
        let faceData = Data(bytes: faces.buffer.contents(), count: faceByteCount)
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
        // 分栏左栏由 SwiftUI 的 .clipped() 裁剪；UIViewRepresentable 的宿主视图
        // 不受 SwiftUI 裁剪保证，这里在 CALayer 层再兜一层，避免取景画面出血到右栏。
        view.clipsToBounds = true
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
        // 分栏左栏由 SwiftUI 的 .clipped() 裁剪；UIViewRepresentable 的宿主视图
        // 不受 SwiftUI 裁剪保证，这里在 CALayer 层再兜一层，避免取景画面出血到右栏。
        view.clipsToBounds = true
        view.scene = SCNScene()
        view.automaticallyUpdatesLighting = false
        view.rendersMotionBlur = false
        view.preferredFramesPerSecond = 30
        view.antialiasingMode = .none
        // The live scan only needs tracking, depth and semantic counts. Avoid
        // drawing the full classified mesh here; the dedicated spatial survey
        // screen remains responsible for that heavier visualization.
        model.attach(to: view, renderMesh: false)
        if isActive {
            // Camera hardware is exclusive: the plain camera session released
            // on a lens flip stops asynchronously, so starting AR immediately
            // would fail and leave a black frame. Defer to let it release.
            model.startOn(view, afterDelay: 0.25)
        }
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
    let item: Any
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
    @StateObject private var fallbackCameraModel = CameraPreviewController()
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @State private var showPaywall = false
    @State private var isSavingMap = false
    @State private var shareItem: ARSpatialShareItem?
    @State private var saveMessage: String?
    @State private var showRoomPlan = false
    @State private var show3DSpaceViewer = false
    @State private var currentSurveyReport: HouseSpatialSurvey? = nil
    @State private var showVRSurvey = false

    private var latestSurveyForVR: HouseSpatialSurvey? {
        if let currentSurveyReport { return currentSurveyReport }
        let keys = [SpatialSurveyArchiveKeys.measured, SpatialSurveyArchiveKeys.virtual]
        for key in keys {
            if let data = UserDefaults.standard.data(forKey: key),
               let survey = try? JSONDecoder().decode(HouseSpatialSurvey.self, from: data) {
                return survey
            }
        }
        return nil
    }

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
                CameraPreviewView(controller: fallbackCameraModel, isActive: !showRoomPlan)
                    .ignoresSafeArea()
                unsupportedOverlay
            }

            GeometryReader { geo in
                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 8)
                    // 面板含追踪、建图、测距、鲁班尺、评估、最大平面、净高、语义网格等 8~10 行，
                    // iPhone SE 667pt 高时可占掉一半屏幕；限高 42% 并允许内部滚动，
                    // 让 AR 取景区在任何机型上都保留足够可视面积。
                    ScrollView(.vertical, showsIndicators: false) {
                        measurementPanel
                    }
                    .frame(maxHeight: geo.size.height * 0.42)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onDisappear {
            // Presenting RoomPlan can make the covered view temporarily
            // disappear. Keep the model attached in that case so closing the
            // full-screen capture can resume the same spatial session.
            if !showRoomPlan {
                fallbackCameraModel.stopSession()
                model.stop()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // ARSCNView does not guarantee that an active session is paused
            // before the app is backgrounded. Stop frame delivery explicitly
            // so the camera/LiDAR cannot continue consuming power while the
            // user is away from the survey.
            fallbackCameraModel.pauseSessionForBackground()
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
                CameraExclusiveGate {
                    ARRoomPlanSurveyView()
                }
            }
        }
#endif
    }

    private var header: some View {
        VStack(spacing: 8) {
            // 第一行：标题与状态 + 常驻关闭按钮
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t("ar_spatial_survey"))
                        .adaptiveFont(size: 16, weight: .bold)
                        .foregroundColor(.white)
                    Text(model.lidarAvailable ? lang.t("ar_spatial_lidar_available") : lang.t("ar_spatial_ar_mode"))
                        .adaptiveFont(size: 10, weight: .medium)
                        .foregroundColor(model.lidarAvailable ? .green : .orange)
                }
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .adaptiveFont(size: 13, weight: .bold)
                        .foregroundColor(.white)
                        .padding(9)
                        .background(Color.black.opacity(0.55))
                        .clipShape(Circle())
                }
                .accessibilityLabel(lang.t("ar_spatial_close"))
            }

            // 第二行：功能图标按钮组（小屏横向滚动兜底，避免挤压标题竖排）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
#if canImport(RoomPlan)
                    if #available(iOS 16.0, *),
                       ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                        Button(action: {
                            model.pause()
                            showRoomPlan = true
                        }) {
                            Image(systemName: "house.fill")
                                .adaptiveFont(size: 13, weight: .bold)
                                .foregroundColor(.white)
                                .padding(9)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(lang.t("ar_roomplan_title"))
                    }
#endif
                    Button(action: {
                        if let survey = model.buildSpatialSurvey() {
                            currentSurveyReport = survey
                            show3DSpaceViewer = true
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "cube.transparent")
                                .adaptiveFont(size: 13, weight: .bold)
                            Text(lang.t("floorplan_3d_recent_actual"))
                                .adaptiveFont(size: 10, weight: .bold)
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.yanGold)
                        .cornerRadius(14)
                    }
                    .accessibilityLabel(lang.t("floorplan_3d_recent_actual"))
                    Button(action: {
                        if !iap.hasUnlockedVIP {
                            showPaywall = true
                            return
                        }
                        showVRSurvey = true
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "view.3d")
                                .adaptiveFont(size: 13, weight: .bold)
                            Text(lang.t("vr_survey_title"))
                                .adaptiveFont(size: 10, weight: .bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.8))
                        .cornerRadius(14)
                    }
                    .accessibilityLabel(lang.t("vr_survey_title"))
                    Button(action: {
                        _ = model.toggleGroundBaguaOverlay()
                    }) {
                        Image(systemName: "square.grid.3x3.fill")
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(model.groundBaguaProjected ? .black : .white)
                            .padding(9)
                            .background(model.groundBaguaProjected ? Color(red: 0.95, green: 0.80, blue: 0.25) : Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(lang.t("xuankong_stars"))
                    Button(action: {
                        _ = model.placeLubanPoint()
                    }) {
                        Image(systemName: "ruler.fill")
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(model.lubanPointA != nil ? .black : .white)
                            .padding(9)
                            .background(model.lubanPointA != nil ? Color.yanCyan : Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(lang.t("ar_spatial_measure"))
                    // 手动角落打点连续测绘（Corner-pin Polygon）：弱纹理墙面防拼接漂移
                    Button(action: {
                        model.cornerPinActive.toggle()
                        if !model.cornerPinActive { model.clearCornerPins() }
                    }) {
                        Image(systemName: model.cornerPinActive ? "hand.draw.fill" : "hand.draw")
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(model.cornerPinActive ? .black : .white)
                            .padding(9)
                            .background(model.cornerPinActive ? Color.orange : Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(lang.t("ar_spatial_measure"))
                    if model.cornerPinActive {
                        Button(action: { _ = model.pinCornerPoint() }) {
                            VStack(spacing: 1) {
                                Image(systemName: "plus")
                                    .adaptiveFont(size: 11, weight: .bold)
                                Text("\(model.cornerPoints.count)")
                                    .adaptiveFont(size: 9, weight: .bold, design: .monospaced)
                            }
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.orange.opacity(0.85))
                            .clipShape(Circle())
                        }
                        .accessibilityLabel(lang.t("ar_luban_point_a"))
                        Button(action: { _ = model.finishCornerRoom() }) {
                            Text(lang.t("done"))
                                .adaptiveFont(size: 10, weight: .bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(Color.yanGold)
                                .cornerRadius(12)
                        }
                        .disabled(model.cornerPoints.count < 3)
                        .opacity(model.cornerPoints.count < 3 ? 0.4 : 1.0)
                        .accessibilityLabel(lang.t("done"))
                        Button(action: { model.clearCornerPins() }) {
                            Image(systemName: "trash")
                                .adaptiveFont(size: 11, weight: .bold)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.red.opacity(0.75))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(lang.t("ar_panorama_clear"))
                    }
                    Button(action: {
                        model.toggleMeshVisibility()
                    }) {
                        Image(systemName: model.meshVisible ? "eye.fill" : "eye.slash.fill")
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(model.meshVisible ? .yanCyan : .white.opacity(0.75))
                            .padding(9)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(lang.t("ar_spatial_mesh"))
                    Button(action: {
                        saveMessage = nil
                        model.resetSurvey()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(.white)
                            .padding(9)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(lang.t("ar_spatial_reset"))
                    if model.hasSavedWorldMap {
                        Button(action: restoreLatestMap) {
                            Image(systemName: "arrow.down.doc.fill")
                                .adaptiveFont(size: 13, weight: .bold)
                                .foregroundColor(.yanCyan)
                                .padding(9)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Circle())
                        }
                        .disabled(isSavingMap)
                        .accessibilityLabel(lang.t("ar_spatial_map_ready"))
                    }
                    Button(action: {
                        if let img = model.captureSurveySnapshotReport() {
                            shareItem = ARSpatialShareItem(item: img)
                        }
                    }) {
                        Image(systemName: "camera.viewfinder")
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(.green)
                            .padding(9)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(lang.t("capture_proof"))
                    Button(action: saveMap) {
                        Image(systemName: isSavingMap ? "hourglass" : "square.and.arrow.up")
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(isSavingMap ? .orange : .white)
                            .padding(9)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .disabled(isSavingMap)
                    .accessibilityLabel(lang.t("ar_spatial_save_map"))
                }
            }
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
            if !model.hasHeadingReference {
                Text(lang.t("ar_survey_heading_pending"))
                    .adaptiveFont(size: 11).foregroundColor(.orange)
            }
            HStack {
                Label(trackingText, systemImage: trackingIcon)
                    .adaptiveFont(size: 11, weight: .semibold)
                    .foregroundColor(trackingColor)
                Spacer()
                Text("\(lang.t("ar_spatial_planes")): \(model.planeCount)")
                    .adaptiveFont(size: 11, weight: .medium)
                    .foregroundColor(.white.opacity(0.85))
            }

            HStack(spacing: 12) {
                Label(mappingText, systemImage: "map")
                if false, let h = model.estimatedRoomHeightMeters {
                let beamWarning = model.hasLowBeamWarning
                Text(String(format: "%@: %.2f m · %@", lang.t("3d_metric_ceiling"), h, beamWarning ? lang.t("ar_spatial_beam_warning") : lang.t("ar_spatial_ceiling_good")))
                    .adaptiveFont(size: 10, weight: .bold, design: .monospaced)
                    .foregroundColor(beamWarning ? .orange : .green)
            }
            if model.lidarAvailable {
                    Text("\(lang.t("ar_spatial_mesh")): \(model.meshAnchorCount)")
                }
                if model.savedAnchorCount > 0 {
                    Label("\(model.savedAnchorCount)", systemImage: "mappin.and.ellipse")
                        .foregroundColor(.yanCyan)
                }
            }
            .adaptiveFont(size: 10, weight: .medium)
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
                Button(action: { _ = model.placeLubanPoint() }) {
                    Text(lubanActionTitle)
                        .adaptiveFont(size: 10, weight: .bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yanCyan.opacity(0.85))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
            }
            .adaptiveFont(size: 13, weight: .bold, design: .monospaced)
            .foregroundColor(.white)

            if let standing = model.currentStandingPalace {
                HStack(spacing: 6) {
                    Image(systemName: "safari.fill")
                        .foregroundColor(Color(red: 0.95, green: 0.80, blue: 0.25))
                        .adaptiveFont(size: 11)
                    Text(standing)
                        .adaptiveFont(size: 10, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            }

            if let eval = model.lubanEvaluation {
                HStack(spacing: 6) {
                    Image(systemName: eval.yangIsAuspicious ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(eval.yangIsAuspicious ? .green : .orange)
                        .adaptiveFont(size: 11)
                    Text(eval.localizedSummary(for: lang.effectiveLanguage))
                        .adaptiveFont(size: 10, weight: .bold, design: .monospaced)
                        .foregroundColor(eval.yangIsAuspicious ? .green : .orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Spacer()
                    Button(action: { model.clearLubanPoints() }) {
                        Image(systemName: "xmark.circle.fill")
                            .adaptiveFont(size: 12)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
            } else if model.lubanPointA != nil {
                Text(lubanPendingHint)
                    .adaptiveFont(size: 10, weight: .medium)
                    .foregroundColor(.yanCyan)
            }

            if let width = model.largestPlaneWidth, let depth = model.largestPlaneDepth {
                HStack {
                    Text("\(lang.t("ar_spatial_largest_plane")): \(String(format: "%.2f × %.2f m", width, depth))")
                        .adaptiveFont(size: 10, weight: .medium, design: .monospaced)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Button(action: {
                        if model.syncPlanesToFloorplan() {
                            saveMessage = lang.t("ar_roomplan_synced_floorplan")
                        }
                    }) {
                        Label(lang.t("tab_floorplan"), systemImage: "scope")
                            .adaptiveFont(size: 10, weight: .bold)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.95, green: 0.80, blue: 0.25).opacity(0.9))
                            .foregroundColor(.black)
                            .cornerRadius(6)
                    }
                }
            }

            if let h = model.estimatedRoomHeightMeters {
                let beamWarning = model.hasLowBeamWarning
                Text(String(format: "%@: %.2f m · %@", lang.t("3d_metric_ceiling"), h, beamWarning ? lang.t("ar_spatial_beam_warning") : lang.t("ar_spatial_ceiling_good")))
                    .adaptiveFont(size: 10, weight: .bold, design: .monospaced)
                    .foregroundColor(beamWarning ? .orange : .green)
            }
            if model.lidarAvailable {
                Text(lang.t("ar_spatial_semantic_candidate"))
                    .adaptiveFont(size: 10, weight: .medium)
                    .foregroundColor(.white.opacity(0.65))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                    ForEach(Array(Self.semanticTypes.enumerated()), id: \.offset) { entry in
                        let item = entry.element
                        let count = model.semanticCounts[item.0.rawValue, default: 0]
                        if count > 0 {
                            Label("\(lang.t(item.1)) \(count)", systemImage: item.2)
                                .adaptiveFont(size: 10, weight: .medium)
                                .foregroundColor(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                }
            } else {
                Text(lang.t("ar_spatial_no_depth"))
                    .adaptiveFont(size: 10)
                    .foregroundColor(.orange.opacity(0.9))
            }
            if let saveMessage = saveMessage {
                Text(saveMessage)
                    .adaptiveFont(size: 10, weight: .semibold)
                    .foregroundColor(.yanCyan)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.78))
        .cornerRadius(12)
        .sheet(item: $shareItem) { item in
            ARSpatialShareSheet(items: [item.item])
        }
        .sheet(isPresented: $show3DSpaceViewer) {
            if let survey = currentSurveyReport {
                VStack(spacing: 0) {
                    if survey.scanMethod.contains("基础") || survey.scanMethod.contains("基礎") || survey.scanMethod.contains("基本") || survey.scanMethod.contains("기본") || survey.scanMethod.localizedCaseInsensitiveContains("Basic") || survey.scanMethod.localizedCaseInsensitiveContains("Dasar") || survey.scanMethod.localizedCaseInsensitiveContains("พื้นฐาน") || survey.scanMethod.localizedCaseInsensitiveContains("mặt phẳng") {
                        Text(lang.t("ar_spatial_basic_notice"))
                            .adaptiveFont(size: 10, weight: .semibold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1))
                    }
                    House3DSpaceViewer(survey: survey)
                }
            }
        }
        .fullScreenCover(isPresented: $showVRSurvey) {
            // If a spatial scan already exists, let the VR editor start from
            // that measured geometry so users can correct/complete it. An
            // empty simulation is only used before the first scan.
            VRSpatialSurveyView(initialSurvey: latestSurveyForVR)
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
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
                shareItem = ARSpatialShareItem(item: url)
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
            case .failure(let error):
                if error as? ARSpatialSurveyError == .mapOrientationUnavailable {
                    saveMessage = lang.t("ar_spatial_map_orientation_missing")
                } else {
                    saveMessage = lang.t("ar_spatial_save_failed")
                }
            }
        }
    }

    private var lubanActionTitle: String {
        let isWaitingSecond = (model.lubanPointA != nil && model.lubanPointB == nil)
        return isWaitingSecond ? lang.t("ar_luban_point_b") : lang.t("ar_luban_point_a")
    }

    private var lubanPendingHint: String {
        return lang.t("ar_luban_pending_hint")
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
                .adaptiveFont(size: 42)
                .foregroundColor(.yanCyan)
            Text(lang.t("ar_spatial_no_ar"))
                .adaptiveFont(size: 14, weight: .bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(lang.t("ar_spatial_camera_fallback"))
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color.black.opacity(0.72))
        .cornerRadius(14)
        .padding(24)
    }
}
