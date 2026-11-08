import Foundation
import CoreGraphics
import Combine

// MARK: - 全景形煞数据模型 (外部标注 / 距离判级 / 八宫聚合 / 室内外统一档案)
// 补齐 AR 实景测绘的三大缺口：距离参与严重度分级、结构化标记持久化、
// 360° 全景聚合报告；并将室内体检（HouseSpatialSurvey）与外部标注
// 合并为一份"全景形煞档案"。

/// 外部形煞标注来源
public enum ShaRecordSource: String, Codable {
    case ai        // OnDeviceShaAnalyzer 自动识别
    case manual    // 用户手动拖框锁定
}

/// 单条外部形煞现场标注（结构化记录，Codable 可持久化/导出）
public struct ExteriorShaRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let shaID: String          // ExteriorShaEngine database key（tianzhan/luchong/...）
    public let bearingDegrees: Double // 绝对方位角 0..360
    /// Heading at capture time. Optional for backward-compatible decoding of
    /// records created before capture headings were persisted.
    public let capturedHeadingDegrees: Double?
    public let elevationDegrees: Double // 目标仰角（俯为负，仰为正）
    public let distanceMeters: Float?   // LiDAR/AR 深度；nil = 无深度数据
    public let confidence: Double?      // AI 置信度；手动标注为 nil
    public let capturedAt: Date
    public let source: ShaRecordSource
    public let note: String?

    public init(
        id: UUID = UUID(),
        shaID: String,
        bearingDegrees: Double,
        capturedHeadingDegrees: Double? = nil,
        elevationDegrees: Double = 0,
        distanceMeters: Float? = nil,
        confidence: Double? = nil,
        capturedAt: Date = Date(),
        source: ShaRecordSource = .manual,
        note: String? = nil
    ) {
        self.id = id
        self.shaID = shaID
        self.bearingDegrees = bearingDegrees
        self.capturedHeadingDegrees = capturedHeadingDegrees
        self.elevationDegrees = elevationDegrees
        self.distanceMeters = distanceMeters
        self.confidence = confidence
        self.capturedAt = capturedAt
        self.source = source
        self.note = note
    }

    /// 八宫（八方）索引：绝对方位模式下 0=正北，每 45° 一格。
    /// 全景报告会通过 `palaceIndex(relativeTo:)` 以采集基准朝向分组。
    public var palaceIndex: Int {
        absolutePalaceIndex(for: bearingDegrees)
    }

    /// Eight-palace index relative to a survey baseline heading. This keeps
    /// the report stable when a user turns the phone after taking records.
    public func palaceIndex(relativeTo headingDegrees: Double) -> Int {
        let relative = bearingDegrees - headingDegrees
        return absolutePalaceIndex(for: relative)
    }

    private func absolutePalaceIndex(for bearing: Double) -> Int {
        guard bearing.isFinite else { return 0 }
        let norm = (bearing.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        return Int(norm / 45.0) % 8
    }
}

/// 距离分级：形煞严重度随距离加权（近者愈凶、远者渐轻）
public enum ShaDistanceGrade: String, Codable {
    case criticalNear  // < 30m：加重一级
    case staticLevel   // 30~100m：保持静态等级
    case mitigatedFar  // > 100m：减轻一级
}

public enum ExteriorShaSeverityResolver {

    public static func grade(for distanceMeters: Float?) -> ShaDistanceGrade {
        guard let d = distanceMeters, d > 0, d.isFinite else { return .staticLevel }
        if d < 30.0 { return .criticalNear }
        if d > 100.0 { return .mitigatedFar }
        return .staticLevel
    }

    /// 静态严重度（ExteriorShaEngine 类型固有）+ 实测距离 → 最终判级
    public static func effectiveSeverity(
        staticSeverity: ShaSeverity,
        distanceMeters: Float?
    ) -> ShaSeverity {
        switch grade(for: distanceMeters) {
        case .criticalNear:
            switch staticSeverity {
            case .notice: return .minor
            case .minor: return .warning
            case .warning: return .critical
            case .critical: return .critical
            }
        case .mitigatedFar:
            switch staticSeverity {
            case .critical: return .warning
            case .warning: return .minor
            case .minor: return .minor
            case .notice: return .notice
            }
        case .staticLevel:
            return staticSeverity
        }
    }
}

/// 全景（八宫）外部形煞分布报告：环绕一周采集的多条标注按方位归宫
public struct ShaPanoramaReport: Identifiable, Codable {
    public let id: UUID
    public let capturedAt: Date
    public let headingDegrees: Double     // 采集时的罗盘基准朝向
    public let records: [ExteriorShaRecord]

    public init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        headingDegrees: Double,
        records: [ExteriorShaRecord]
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.headingDegrees = headingDegrees
        self.records = records
    }

    /// 按采集基准朝向的八宫分组（0=基准朝向…7=其余方位），未扫描宫位为空数组。
    public var palacesByIndex: [[ExteriorShaRecord]] {
        var result = Array(repeating: [ExteriorShaRecord](), count: 8)
        for record in records {
            result[record.palaceIndex(relativeTo: headingDegrees)].append(record)
        }
        return result
    }

    /// 已覆盖的宫位数
    public var scannedPalaceCount: Int {
        palacesByIndex.filter { !$0.isEmpty }.count
    }

    /// 按最终判级统计（结合距离加权）
    public func severityCounts(staticSeverityLookup: (String) -> ShaSeverity) -> [ShaSeverity: Int] {
        var counts: [ShaSeverity: Int] = [:]
        for record in records {
            let base = staticSeverityLookup(record.shaID)
            let effective = ExteriorShaSeverityResolver.effectiveSeverity(
                staticSeverity: base,
                distanceMeters: record.distanceMeters
            )
            counts[effective, default: 0] += 1
        }
        return counts
    }
}

/// 全景形煞统一档案：罗盘朝向 + 室内体检 + 外部标注聚合
/// —— 打通"室内外两张皮"，一次输出全景形煞分析结论
public struct PanoramaFengShuiArchive: Identifiable, Codable {
    public let id: UUID
    public let createdAt: Date
    public let compassHeading: Double
    public let interior: HouseSpatialSurvey?    // 室内体检（RoomPlan/LiDAR/户型图）
    public let exterior: [ExteriorShaRecord]    // 外部形煞标注

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        compassHeading: Double,
        interior: HouseSpatialSurvey?,
        exterior: [ExteriorShaRecord]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.compassHeading = compassHeading
        self.interior = interior
        self.exterior = exterior
    }

    /// 室内检出条目数
    public var interiorShaCount: Int { interior?.shaItems.count ?? 0 }

    /// 外部标注数
    public var exteriorShaCount: Int { exterior.count }

    /// 形煞总条数（室内条目 + 外部标注）
    public var totalShaCount: Int { interiorShaCount + exteriorShaCount }
}

// MARK: - 全景形煞档案共享存储 (室内体检与外部标注的单一消费入口)
// ARVisionView（外部标注）与 ARSpatialSurveyView / ARRoomPlanCaptureView
// （室内体检）分别写入，报告页统一读取，打通"室内外两张皮"。

public final class ShaSurveyStore: ObservableObject {
    public static let shared = ShaSurveyStore()

    /// 外部形煞标注（按采集顺序）
    @Published public private(set) var records: [ExteriorShaRecord] = []
    /// 最近一次室内体检（RoomPlan/LiDAR/户型图路径）
    @Published public private(set) var latestInterior: HouseSpatialSurvey?

    private let storageKey = "tianji.sha_survey_store.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        records = snapshot.records
        latestInterior = snapshot.latestInterior
    }

    private struct Snapshot: Codable {
        let records: [ExteriorShaRecord]
        let latestInterior: HouseSpatialSurvey?
    }

    private func persist() {
        let snapshot = Snapshot(records: records, latestInterior: latestInterior)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }

    /// A property switch replaces the entire archive, including empty slots.
    /// Updating one slot in isolation would retain another property's model.
    public func replaceProperty(measured: HouseSpatialSurvey?, virtual: HouseSpatialSurvey?, exterior: [ExteriorShaRecord]) {
        defaults.set(measured.flatMap { try? JSONEncoder().encode($0) }, forKey: SpatialSurveyArchiveKeys.measured)
        defaults.set(virtual.flatMap { try? JSONEncoder().encode($0) }, forKey: SpatialSurveyArchiveKeys.virtual)
        records = exterior
        latestInterior = measured ?? virtual
        persist()
    }

    public func addRecord(_ record: ExteriorShaRecord) {
        records.append(record)
        persist()
    }

    public func updateInterior(_ survey: HouseSpatialSurvey?) {
        latestInterior = survey
        persist()
    }

    public func clearRecords() {
        records.removeAll()
        persist()
    }

    public func removeRecord(id: UUID) {
        records.removeAll(where: { $0.id == id })
        persist()
    }

    public func removeLastRecord() {
        guard !records.isEmpty else { return }
        records.removeLast()
        persist()
    }

    /// 室内外统一档案（任一侧有数据即非空）
    public var archive: PanoramaFengShuiArchive? {
        guard !records.isEmpty || latestInterior != nil else { return nil }
        let capturedHeading = records.lazy
            .compactMap { $0.capturedHeadingDegrees }
            .first(where: { $0.isFinite })
        let interiorHeading = latestInterior?.compassHeading
        let fallbackHeading = CompassMotionManager.shared.headingState.facingAngle
        let heading = [capturedHeading, interiorHeading, fallbackHeading]
            .compactMap { $0 }
            .first(where: { $0.isFinite }) ?? 0.0
        return PanoramaFengShuiArchive(
            compassHeading: heading,
            interior: latestInterior,
            exterior: records
        )
    }
}
