import Foundation
import CoreGraphics

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
        self.elevationDegrees = elevationDegrees
        self.distanceMeters = distanceMeters
        self.confidence = confidence
        self.capturedAt = capturedAt
        self.source = source
        self.note = note
    }

    /// 八宫（八方）索引：0=正北，每 45° 一格，随罗盘方位旋转
    public var palaceIndex: Int {
        let norm = (bearingDegrees.truncatingRemainder(dividingBy: 360) + 360)
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

    /// 按八宫分组（0=正北…7=西北），未扫描宫位为空数组
    public var palacesByIndex: [[ExteriorShaRecord]] {
        var result = Array(repeating: [ExteriorShaRecord](), count: 8)
        for record in records {
            result[record.palaceIndex].append(record)
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
