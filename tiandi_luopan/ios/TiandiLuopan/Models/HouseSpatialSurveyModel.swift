import Foundation
import CoreGraphics
import simd

extension Notification.Name {
    /// Posted when a completed VR correction replaces the latest spatial
    /// archive. This is intentionally separate from the floorplan
    /// import notification: importing a floorplan also restores its room
    /// layout, while editing a VR report must not overwrite that layout.
    public static let didUpdateHouseSpatialSurvey = Notification.Name("com.yanxiang.compass.didUpdateHouseSpatialSurvey")
    public static let didUpdateMeasuredSpatialSurvey = Notification.Name("com.yanxiang.compass.didUpdateMeasuredSpatialSurvey")
}

/// Separate persistence slots prevent a hand-authored VR correction from
/// replacing the latest hardware measurement. The legacy measured key remains
/// unchanged so existing archives decode without migration.
public enum SpatialSurveyArchiveKeys {
    public static let measured = "latest_house_spatial_survey"
    public static let virtual = "latest_vr_house_spatial_survey"
}

// MARK: - 3D 全屋测绘空间数据模型与全屋形煞引擎 (PRD 5.3 & 第7章)

/// 形煞危害严重程度
public enum SpatialShaSeverity: String, Codable {
    case auspicious = "吉"
    case warning = "轻微"
    case critical = "严重"
    
    public var badgeColorHex: String {
        switch self {
        case .auspicious: return "#34C759"
        case .warning: return "#FF9500"
        case .critical: return "#FF3B30"
        }
    }

    public var localizedTitle: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch self {
            case .auspicious: return "Auspicious"
            case .warning:    return "Caution"
            case .critical:   return "Severe"
            }
        case .zhHant:
            switch self {
            case .auspicious: return "吉"
            case .warning:    return "輕微"
            case .critical:   return "嚴重"
            }
        case .ja:
            switch self {
            case .auspicious: return "吉"
            case .warning:    return "注意"
            case .critical:   return "重大"
            }
        case .ko:
            switch self {
            case .auspicious: return "길"
            case .warning:    return "주의"
            case .critical:   return "심각"
            }
        case .vi:
            switch self {
            case .auspicious: return "Cát"
            case .warning:    return "Lưu ý"
            case .critical:   return "Nghiêm trọng"
            }
        case .th:
            switch self {
            case .auspicious: return "มงคล"
            case .warning:    return "เฝ้าระวัง"
            case .critical:   return "รุนแรง"
            }
        case .id:
            switch self {
            case .auspicious: return "Baik"
            case .warning:    return "Perhatian"
            case .critical:   return "Parah"
            }
        case .auto, .zhHans:
            return rawValue
        }
    }
}

/// 门窗开孔类型
public enum SpatialOpeningType: String, Codable {
    case entranceDoor = "入户大门"
    case interiorDoor = "房间门"
    case window = "主采光窗"
    case opening = "垭口开口"
    case balconyDoor = "阳台移门"

    public var localizedName: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch self {
            case .entranceDoor: return "Main Entrance"
            case .interiorDoor: return "Interior Door"
            case .window:       return "Main Window"
            case .opening:      return "Pass-Through Opening"
            case .balconyDoor:  return "Balcony Sliding Door"
            }
        case .zhHant:
            switch self {
            case .entranceDoor: return "入戶大門"
            case .interiorDoor: return "房間門"
            case .window:       return "主採光窗"
            case .opening:      return "埡口開口"
            case .balconyDoor:  return "陽台移門"
            }
        case .ja:
            switch self {
            case .entranceDoor: return "玄関ドア"
            case .interiorDoor: return "室内ドア"
            case .window:       return "採光窓"
            case .opening:      return "開口部"
            case .balconyDoor:  return "バルコニー引き戸"
            }
        case .ko:
            switch self {
            case .entranceDoor: return "현관문"
            case .interiorDoor: return "방문"
            case .window:       return "채광창"
            case .opening:      return "개구부"
            case .balconyDoor:  return "발코니 미닫이문"
            }
        case .vi:
            switch self {
            case .entranceDoor: return "Cửa chính"
            case .interiorDoor: return "Cửa phòng"
            case .window:       return "Cửa sổ chính"
            case .opening:      return "Lối thông"
            case .balconyDoor:  return "Cửa trượt ban công"
            }
        case .th:
            switch self {
            case .entranceDoor: return "ประตูทางเข้าหลัก"
            case .interiorDoor: return "ประตูห้อง"
            case .window:       return "หน้าต่างหลัก"
            case .opening:      return "ช่องทางเชื่อม"
            case .balconyDoor:  return "ประตูบานเลื่อนระเบียง"
            }
        case .id:
            switch self {
            case .entranceDoor: return "Pintu Utama"
            case .interiorDoor: return "Pintu Kamar"
            case .window:       return "Jendela Utama"
            case .opening:      return "Bukaan Lorong"
            case .balconyDoor:  return "Pintu Geser Balkon"
            }
        case .auto, .zhHans:
            return rawValue
        }
    }
}

/// 3D 墙体测绘数据
public struct SpatialWall3D: Identifiable, Codable {
    public let id: UUID
    public let startX: Float
    public let startY: Float
    public let startZ: Float
    public let endX: Float
    public let endY: Float
    public let endZ: Float
    public let height: Float
    public let thickness: Float
    public let isLoadBearing: Bool

    public var start: SIMD3<Float> { SIMD3<Float>(startX, startY, startZ) }
    public var end: SIMD3<Float> { SIMD3<Float>(endX, endY, endZ) }
    public var length: Float {
        simd_distance(SIMD2<Float>(startX, startZ), SIMD2<Float>(endX, endZ))
    }

    public init(
        id: UUID = UUID(),
        start: SIMD3<Float>,
        end: SIMD3<Float>,
        height: Float = 2.8,
        thickness: Float = 0.20,
        isLoadBearing: Bool = false
    ) {
        self.id = id
        self.startX = start.x
        self.startY = start.y
        self.startZ = start.z
        self.endX = end.x
        self.endY = end.y
        self.endZ = end.z
        self.height = height
        self.thickness = thickness
        self.isLoadBearing = isLoadBearing
    }
}

/// 3D 门窗开孔测绘数据
public struct SpatialOpening3D: Identifiable, Codable {
    public let id: UUID
    public let type: SpatialOpeningType
    public let posX: Float
    public let posY: Float
    public let posZ: Float
    public let normalX: Float
    public let normalY: Float
    public let normalZ: Float
    public let width: Float
    public let height: Float
    public let yangGateName: String
    public let yangIsAuspicious: Bool

    public var position: SIMD3<Float> { SIMD3<Float>(posX, posY, posZ) }
    public var normal: SIMD3<Float> { SIMD3<Float>(normalX, normalY, normalZ) }

    public init(
        id: UUID = UUID(),
        type: SpatialOpeningType,
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        width: Float,
        height: Float,
        lubanEval: LubanRulerEvaluation? = nil
    ) {
        self.id = id
        self.type = type
        self.posX = position.x
        self.posY = position.y
        self.posZ = position.z
        let nLen = simd_length(normal)
        let safeNormal = nLen > 1e-4 ? normal / nLen : SIMD3<Float>(0, 0, 1)
        self.normalX = safeNormal.x
        self.normalY = safeNormal.y
        self.normalZ = safeNormal.z
        self.width = width
        self.height = height
        let eval = lubanEval ?? LubanRulerEvaluation.evaluate(meters: width)
        self.yangGateName = eval.yangSegmentName
        self.yangIsAuspicious = eval.yangIsAuspicious
    }
}

/// 3D 横梁与立柱测绘数据 (用于横梁压顶诊断)
public struct SpatialBeam3D: Identifiable, Codable {
    public let id: UUID
    public let startX: Float
    public let startY: Float
    public let startZ: Float
    public let endX: Float
    public let endY: Float
    public let endZ: Float
    public let clearanceHeight: Float // 梁底净高 (米)
    public let beamDepth: Float       // 梁下垂深度 (米)
    public let beamWidth: Float       // 梁面宽 (米)

    public var start: SIMD3<Float> { SIMD3<Float>(startX, startY, startZ) }
    public var end: SIMD3<Float> { SIMD3<Float>(endX, endY, endZ) }

    public init(
        id: UUID = UUID(),
        start: SIMD3<Float>,
        end: SIMD3<Float>,
        clearanceHeight: Float,
        beamDepth: Float = 0.35,
        beamWidth: Float = 0.25
    ) {
        self.id = id
        self.startX = start.x
        self.startY = start.y
        self.startZ = start.z
        self.endX = end.x
        self.endY = end.y
        self.endZ = end.z
        self.clearanceHeight = clearanceHeight
        self.beamDepth = beamDepth
        self.beamWidth = beamWidth
    }
}

/// 3D 房间空间划分数据
public struct SpatialRoom3D: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let type: FloorplanRoomType
    public let centerX: Float
    public let centerY: Float
    public let centerZ: Float
    public let sizeX: Float
    public let sizeY: Float
    public let sizeZ: Float
    public let areaSqMeters: Float
    /// Optional yaw of the room's local rectangle. Older archives omit this
    /// field and decode as zero rotation.
    public let rotationY: Float?

    public var center: SIMD3<Float> { SIMD3<Float>(centerX, centerY, centerZ) }
    public var size: SIMD3<Float> { SIMD3<Float>(sizeX, sizeY, sizeZ) }

    /// Localized room label. `name` is normally derived from the room type's
    /// localized name, so the type provides the authoritative localization.
    public var localizedName: String { type.localizedName }

    public init(
        id: UUID = UUID(),
        name: String,
        type: FloorplanRoomType,
        center: SIMD3<Float>,
        size: SIMD3<Float>,
        areaSqMeters: Float? = nil,
        rotationY: Float? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.centerX = center.x
        self.centerY = center.y
        self.centerZ = center.z
        self.sizeX = size.x
        self.sizeY = size.y
        self.sizeZ = size.z
        self.areaSqMeters = areaSqMeters ?? max(1.0, size.x * size.z)
        self.rotationY = rotationY
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, type, centerX, centerY, centerZ, sizeX, sizeY, sizeZ,
             areaSqMeters, rotationY
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.type = try c.decode(FloorplanRoomType.self, forKey: .type)
        self.centerX = try c.decode(Float.self, forKey: .centerX)
        self.centerY = try c.decode(Float.self, forKey: .centerY)
        self.centerZ = try c.decode(Float.self, forKey: .centerZ)
        self.sizeX = try c.decode(Float.self, forKey: .sizeX)
        self.sizeY = try c.decode(Float.self, forKey: .sizeY)
        self.sizeZ = try c.decode(Float.self, forKey: .sizeZ)
        self.areaSqMeters = try c.decodeIfPresent(Float.self, forKey: .areaSqMeters)
            ?? max(1.0, sizeX * sizeZ)
        self.rotationY = try c.decodeIfPresent(Float.self, forKey: .rotationY)
    }
}

/// 3D 家具与关键物象数据
public struct SpatialObject3D: Identifiable, Codable {
    public let id: UUID
    public let category: String
    public let posX: Float
    public let posY: Float
    public let posZ: Float
    public let sizeX: Float
    public let sizeY: Float
    public let sizeZ: Float
    /// Y-axis rotation captured from RoomPlan. Optional keeps older survey
    /// archives decodable and allows synthetic/VR objects without orientation.
    public let rotationY: Float?

    public var position: SIMD3<Float> { SIMD3<Float>(posX, posY, posZ) }
    public var size: SIMD3<Float> { SIMD3<Float>(sizeX, sizeY, sizeZ) }

    public init(
        id: UUID = UUID(),
        category: String,
        position: SIMD3<Float>,
        size: SIMD3<Float>,
        rotationY: Float? = nil
    ) {
        self.id = id
        self.category = category
        self.posX = position.x
        self.posY = position.y
        self.posZ = position.z
        self.sizeX = size.x
        self.sizeY = size.y
        self.sizeZ = size.z
        self.rotationY = rotationY
    }
}

/// 房屋整体宏观测绘尺寸
public struct HouseDimensions: Codable {
    public let totalWidth: Float       // 面宽 / 开间 (米)
    public let totalDepth: Float       // 进深 (米)
    public let ceilingHeight: Float    // 室内净层高 (米)
    public let grossFloorArea: Float   // 估算建筑面积 (㎡)
    public let usableFloorArea: Float  // 套内实测净面积 (㎡)
    public let aspectRatio: Float      // 进深与开间比例 (进深 / 面宽)

    public init(
        totalWidth: Float,
        totalDepth: Float,
        ceilingHeight: Float,
        grossFloorArea: Float,
        usableFloorArea: Float
    ) {
        self.totalWidth = max(0.5, totalWidth)
        self.totalDepth = max(0.5, totalDepth)
        self.ceilingHeight = max(2.0, ceilingHeight)
        self.grossFloorArea = max(1.0, grossFloorArea)
        self.usableFloorArea = max(1.0, usableFloorArea)
        self.aspectRatio = self.totalDepth / self.totalWidth
    }
}

/// 全屋形煞体检条目
public struct HouseSpatialShaItem: Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let severity: SpatialShaSeverity
    public let locationName: String
    public let detail: String
    public let fengshuiLore: String
    public let solution: String
    public let coordinateX: Float?
    public let coordinateY: Float?
    public let coordinateZ: Float?
    public let vectorEndX: Float?
    public let vectorEndY: Float?
    public let vectorEndZ: Float?

    public var coordinate: SIMD3<Float>? {
        guard let x = coordinateX, let y = coordinateY, let z = coordinateZ else { return nil }
        return SIMD3<Float>(x, y, z)
    }

    public var vectorEnd: SIMD3<Float>? {
        guard let x = vectorEndX, let y = vectorEndY, let z = vectorEndZ else { return nil }
        return SIMD3<Float>(x, y, z)
    }

    public init(
        id: UUID = UUID(),
        title: String,
        severity: SpatialShaSeverity,
        locationName: String,
        detail: String,
        fengshuiLore: String,
        solution: String,
        coordinate: SIMD3<Float>? = nil,
        vectorEnd: SIMD3<Float>? = nil
    ) {
        self.id = id
        self.title = title
        self.severity = severity
        self.locationName = locationName
        self.detail = detail
        self.fengshuiLore = fengshuiLore
        self.solution = solution
        self.coordinateX = coordinate?.x
        self.coordinateY = coordinate?.y
        self.coordinateZ = coordinate?.z
        self.vectorEndX = vectorEnd?.x
        self.vectorEndY = vectorEnd?.y
        self.vectorEndZ = vectorEnd?.z
    }
}

/// 全屋 3D 测绘总成果结构体
public struct HouseSpatialSurvey: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let scanMethod: String
    public let dimensions: HouseDimensions
    public let walls: [SpatialWall3D]
    public let openings: [SpatialOpening3D]
    public let beams: [SpatialBeam3D]
    public let rooms: [SpatialRoom3D]
    public let objects: [SpatialObject3D]
    public let centroidX: Float
    public let centroidY: Float
    public let centroidZ: Float
    public let compassHeading: Double
    public let shaItems: [HouseSpatialShaItem]
    public let fengshuiScore: Int
    /// 立极中宫是否采用回退口径（严重凹凸户型时落到主功能区/最大房间中心）。
    /// 可选值以保证旧存档 JSON 解码兼容。
    public let isCentroidIndirect: Bool?

    public var centroid: SIMD3<Float> {
        SIMD3<Float>(centroidX, centroidY, centroidZ)
    }

    /// 立极中宫是否落空回退（安全解包）
    public var centroidIndirect: Bool { isCentroidIndirect ?? false }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        scanMethod: String,
        dimensions: HouseDimensions,
        walls: [SpatialWall3D],
        openings: [SpatialOpening3D],
        beams: [SpatialBeam3D],
        rooms: [SpatialRoom3D],
        objects: [SpatialObject3D],
        centroid: SIMD3<Float>,
        compassHeading: Double,
        shaItems: [HouseSpatialShaItem],
        fengshuiScore: Int,
        isCentroidIndirect: Bool? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.scanMethod = scanMethod
        self.dimensions = dimensions
        self.walls = walls
        self.openings = openings
        self.beams = beams
        self.rooms = rooms
        self.objects = objects
        self.centroidX = centroid.x
        self.centroidY = centroid.y
        self.centroidZ = centroid.z
        self.compassHeading = compassHeading
        self.shaItems = shaItems
        self.fengshuiScore = max(0, min(100, fengshuiScore))
        self.isCentroidIndirect = isCentroidIndirect
    }
}

// MARK: - 全屋形煞与 3D 测绘分析引擎 (HouseSpatialSurveyEngine)

public enum HouseSpatialSurveyEngine {

    /// 对全屋 3D 空间进行全方位形煞审计与结构测算
    public static func analyzeSpatialHouse(
        scanMethod: String,
        walls: [SpatialWall3D],
        openings: [SpatialOpening3D],
        beams: [SpatialBeam3D],
        rooms: [SpatialRoom3D],
        objects: [SpatialObject3D],
        compassHeading: Double,
        centroidOverride: SIMD3<Float>? = nil
    ) -> HouseSpatialSurvey {
        // 1. 计算全屋物理边界包围盒
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        var maxH: Float = 2.8

        func roomCorners(_ r: SpatialRoom3D) -> [SIMD2<Float>] {
            let hx = r.sizeX * 0.5
            let hz = r.sizeZ * 0.5
            let localCorners = [
                SIMD2<Float>(r.centerX - hx, r.centerZ - hz),
                SIMD2<Float>(r.centerX + hx, r.centerZ - hz),
                SIMD2<Float>(r.centerX + hx, r.centerZ + hz),
                SIMD2<Float>(r.centerX - hx, r.centerZ + hz)
            ]
            guard let yaw = r.rotationY, yaw.isFinite, abs(yaw) > 1e-5 else {
                return localCorners
            }
            let cosY = cos(yaw)
            let sinY = sin(yaw)
            return localCorners.map { p in
                let dx = p.x - r.centerX
                let dz = p.y - r.centerZ
                return SIMD2<Float>(
                    r.centerX + dx * cosY - dz * sinY,
                    r.centerZ + dx * sinY + dz * cosY
                )
            }
        }

        for w in walls {
            minX = min(minX, min(w.startX, w.endX))
            maxX = max(maxX, max(w.startX, w.endX))
            minZ = min(minZ, min(w.startZ, w.endZ))
            maxZ = max(maxZ, max(w.startZ, w.endZ))
            maxH = max(maxH, w.height)
        }
        for o in openings {
            // Opening width runs along the wall tangent, not along both
            // world axes. Applying it to X and Z inflated the envelope for a
            // side-wall window and shifted the fallback centre in wall-only
            // or opening-only surveys.
            let halfTangent = o.width * 0.5
            let tangentX = -o.normalZ
            let tangentZ = o.normalX
            let tangentMinX = o.posX - tangentX * halfTangent
            let tangentMaxX = o.posX + tangentX * halfTangent
            let tangentMinZ = o.posZ - tangentZ * halfTangent
            let tangentMaxZ = o.posZ + tangentZ * halfTangent
            minX = min(minX, min(tangentMinX, tangentMaxX) - abs(o.normalX) * 0.05)
            maxX = max(maxX, max(tangentMinX, tangentMaxX) + abs(o.normalX) * 0.05)
            minZ = min(minZ, min(tangentMinZ, tangentMaxZ) - abs(o.normalZ) * 0.05)
            maxZ = max(maxZ, max(tangentMinZ, tangentMaxZ) + abs(o.normalZ) * 0.05)
            maxH = max(maxH, o.posY + o.height * 0.5)
        }
        for r in rooms {
            for corner in roomCorners(r) {
                minX = min(minX, corner.x)
                maxX = max(maxX, corner.x)
                minZ = min(minZ, corner.y)
                maxZ = max(maxZ, corner.y)
            }
            maxH = max(maxH, r.sizeY)
        }

        if minX >= maxX { minX = -4.0; maxX = 4.0 }
        if minZ >= maxZ { minZ = -4.0; maxZ = 4.0 }

        let spanX = max(1.5, maxX - minX)
        let spanZ = max(1.5, maxZ - minZ)
        let rawRoomArea = rooms.reduce(Float(0)) { total, room in
            guard room.areaSqMeters.isFinite, room.areaSqMeters > 0 else { return total }
            return total + room.areaSqMeters
        }
        // RoomPlan/VR room rectangles can overlap. Cap the summed area by the
        // measured footprint so duplicate shared rooms cannot inflate the
        // report's usable area, aspect ratio and score.
        let footprintArea = max(1.0, spanX * spanZ)
        let usableArea = min(rawRoomArea, footprintArea)

        // 2. 房屋主轴定向包围盒 (OBB)：以最长墙走向为基准建立房屋局部坐标系。
        //    斜向房屋（非正南正北）若用世界坐标 AABB 取中宫，九宫会切成斜切片，
        //    此处统一转到局部坐标（Local Space）分宫，再转回世界坐标。
        let axisAngle = primaryAxisAngle(walls: walls)
        let cosA = cos(axisAngle)
        let sinA = sin(axisAngle)

        func toLocal(_ p: SIMD2<Float>) -> SIMD2<Float> {
            SIMD2<Float>(p.x * cosA + p.y * sinA, -p.x * sinA + p.y * cosA)
        }
        func toWorld(_ p: SIMD2<Float>) -> SIMD2<Float> {
            SIMD2<Float>(p.x * cosA - p.y * sinA, p.x * sinA + p.y * cosA)
        }
        // 先用墙体端点投影到局部坐标系。此前只要存在一个“房间推断框”
        // 就完全忽略墙体，RoomPlan 的房间框会把整屋尺寸缩小或平移；而把
        // 两类数据简单合并又会让家具推断框把实测墙体撑大。墙体是实测外壳
        // 的优先证据，只有墙体不能形成二维边界时才使用房间框补全 VR/简化路径。
        var lMinX: Float = .greatestFiniteMagnitude
        var lMaxX: Float = -.greatestFiniteMagnitude
        var lMinZ: Float = .greatestFiniteMagnitude
        var lMaxZ: Float = -.greatestFiniteMagnitude
        for wall in walls {
            for corner in [
                SIMD2<Float>(wall.startX, wall.startZ),
                SIMD2<Float>(wall.endX, wall.endZ)
            ] {
                let lc = toLocal(corner)
                lMinX = min(lMinX, lc.x); lMaxX = max(lMaxX, lc.x)
                lMinZ = min(lMinZ, lc.y); lMaxZ = max(lMaxZ, lc.y)
            }
        }
        var obbUsable = lMinX < lMaxX && lMinZ < lMaxZ
        if !obbUsable {
            // 墙体只有一条边或完全缺失时，才回退到房间框。
            lMinX = .greatestFiniteMagnitude
            lMaxX = -.greatestFiniteMagnitude
            lMinZ = .greatestFiniteMagnitude
            lMaxZ = -.greatestFiniteMagnitude
            for room in rooms {
                for corner in roomCorners(room) {
                    let lc = toLocal(corner)
                    lMinX = min(lMinX, lc.x); lMaxX = max(lMaxX, lc.x)
                    lMinZ = min(lMinZ, lc.y); lMaxZ = max(lMaxZ, lc.y)
                }
            }
            obbUsable = lMinX < lMaxX && lMinZ < lMaxZ
        }
        if !obbUsable {
            // 没有任何可用几何时才退回世界坐标 AABB。
            lMinX = .greatestFiniteMagnitude
            lMaxX = -.greatestFiniteMagnitude
            lMinZ = .greatestFiniteMagnitude
            lMaxZ = -.greatestFiniteMagnitude
        }
        let lSpanX = obbUsable ? max(1.5, lMaxX - lMinX) : spanX
        let lSpanZ = obbUsable ? max(1.5, lMaxZ - lMinZ) : spanZ
        let lCx = obbUsable ? (lMinX + lMaxX) * 0.5 : 0.0
        let lCz = obbUsable ? (lMinZ + lMaxZ) * 0.5 : 0.0

        let grossArea = max(usableArea * 1.22, lSpanX * lSpanZ)

        let dimensions = HouseDimensions(
            totalWidth: lSpanX,
            totalDepth: lSpanZ,
            ceilingHeight: maxH,
            grossFloorArea: grossArea,
            usableFloorArea: max(usableArea, lSpanX * lSpanZ * 0.78)
        )

        // 3. 立极中宫点 (Centroid)：优先 OBB 局部中心转回世界坐标；
        //    严重凹凸缺角（面积比 < 75%）时采用"主功能区重心法"（面积最大房间中心），
        //    避免立极点落到屋外走廊/天井，并标记落空回退供 3D 视图警示。
        var cx = (minX + maxX) * 0.5
        var cz = (minZ + maxZ) * 0.5
        if obbUsable {
            let obbCenter = toWorld(SIMD2<Float>(lCx, lCz))
            cx = obbCenter.x
            cz = obbCenter.y
        }
        let roomAreaRatio = usableArea / max(grossArea, 0.01)
        var isCentroidIndirect = false
        if let override = centroidOverride,
           override.x.isFinite, override.z.isFinite {
            // A floorplan editor may expose an explicit user-selected Tai Ji
            // point. Use it for both the pillar and relative sha coordinates
            // so the 3D result cannot drift back to the envelope midpoint.
            if obbUsable {
                let local = toLocal(SIMD2<Float>(override.x, override.z))
                let clamped = SIMD2<Float>(
                    min(lMaxX, max(lMinX, local.x)),
                    min(lMaxZ, max(lMinZ, local.y))
                )
                let world = toWorld(clamped)
                cx = world.x
                cz = world.y
            } else {
                cx = min(max(override.x, minX), maxX)
                cz = min(max(override.z, minZ), maxZ)
            }
        } else if roomAreaRatio < 0.75, let largest = rooms.max(by: { $0.areaSqMeters < $1.areaSqMeters }) {
            cx = largest.centerX
            cz = largest.centerZ
            isCentroidIndirect = true
        }
        let centroid = SIMD3<Float>(cx, 0.0, cz)

        // 4. 全屋形煞体检核心逻辑
        var shaItems: [HouseSpatialShaItem] = []
        var score = 92

        // A. 中宫受污检测 —— 在房屋局部坐标系划分九宫中宫盒 (OBB 九宫)，避免斜房切片
        // Use the resolved centroid (including a floorplan user's explicit
        // override) for the central-palace box. Keeping lCx/lCz here made the
        // 3D pillar move while the “中宫受污/火烧中宫” checks stayed at the
        // old envelope centre.
        let centerLocal = toLocal(SIMD2<Float>(cx, cz))
        let centerBoxMinX = centerLocal.x - lSpanX / 6.0
        let centerBoxMaxX = centerLocal.x + lSpanX / 6.0
        let centerBoxMinZ = centerLocal.y - lSpanZ / 6.0
        let centerBoxMaxZ = centerLocal.y + lSpanZ / 6.0

        for room in rooms {
            // 房间 4 角点旋转到局部坐标后取 AABB，与局部中宫盒求重叠
            var rLMinX: Float = .greatestFiniteMagnitude
            var rLMaxX: Float = -.greatestFiniteMagnitude
            var rLMinZ: Float = .greatestFiniteMagnitude
            var rLMaxZ: Float = -.greatestFiniteMagnitude
            for corner in roomCorners(room) {
                let lc = toLocal(corner)
                rLMinX = min(rLMinX, lc.x); rLMaxX = max(rLMaxX, lc.x)
                rLMinZ = min(rLMinZ, lc.y); rLMaxZ = max(rLMaxZ, lc.y)
            }

            let overlapX = max(0, min(centerBoxMaxX, rLMaxX) - max(centerBoxMinX, rLMinX))
            let overlapZ = max(0, min(centerBoxMaxZ, rLMaxZ) - max(centerBoxMinZ, rLMinZ))
            let overlapArea = overlapX * overlapZ

            if overlapArea > 0.4 {
                if room.type == .bathroom {
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "中宫受污 (水浸太极)", "中宮受污 (水浸太極)", "Central Palace Water Sha",
                            "中宮水浸殺（太極受汚）", "중궁수침살 (태극 오염)", "Thủy Tẩm Trung Cung (Uế Khí Thái Cực)",
                            "เคราะห์น้ำท่วมจุดศูนย์กลาง (ไท่จี๋อับชื้น)", "Sha Air di Pusat Rumah (Tai Ji Lembap)"
                        ),
                        severity: .critical,
                        locationName: tr8(
                            "房屋中宫·\(room.name)", "房屋中宮·\(room.name)", "Center Palace · \(room.name)",
                            "中宮・\(room.name)", "주택 중궁 · \(room.name)", "Trung cung · \(room.name)",
                            "จุดศูนย์กลางบ้าน · \(room.name)", "Pusat Rumah · \(room.name)"
                        ),
                        detail: tr8(
                            "《撼龙经》原文有“水浸心包，家门困耗”之说。卫生间位于房屋中心属于该典籍语境下的布局象征，请结合防水、排水、通风、干燥和动线现场复核；古籍语句不等同于现实诊断。",
                            "《撼龍經》原文有「水浸心包，家門困耗」之說。衛生間位於房屋中心屬於該典籍語境下的佈局象徵，請結合防水、排水、通風、乾燥和動線現場複核；古籍語句不等同於現實診斷。",
                            "The Dragon Classic notes that a bathroom at the heart of the home dampens central qi. Please verify waterproofing, drainage, ventilation, and dryness on site; classical symbolism is not a medical diagnosis.",
                            "『撼龍経』では家の中心にある水回りを中宮受汚と記します。防水・排水・換気・乾燥状態を現地で確認してください（古典の象徴表現であり医療診断ではありません）。",
                            "《감룡경》에서는 집 중심의 욕실을 중궁 오염으로 봅니다. 방수·배수·통풍·건조 상태를 현장에서 점검하세요(고전의 상징적 서술이며 의학적 진단이 아닙니다).",
                            "《Hám Long Kinh》 xem phòng vệ sinh ở trung tâm nhà là tượng thủy tẩm trung cung. Vui lòng kiểm tra chống thấm, thoát nước và thông gió thực tế; cổ thư chỉ mang tính biểu trưng.",
                            "คัมภีร์《หานหลงจิง》กล่าวว่าห้องน้ำกลางบ้านทำให้ชี่ส่วนกลางอับชื้น โปรดตรวจสอบระบบกันซึม การระบายน้ำ และการระบายอากาศหน้างาน (เป็นสัญลักษณ์ตามตำรา ไม่ใช่การวินิจฉัยทางการแพทย์)",
                            "Kitab Klasik menyebut kamar mandi di titik pusat rumah melemahkan qi tengah. Harap periksa kedap air, drainase, dan ventilasi di lokasi; simbolisme klasik bukan diagnosis medis."
                        ),
                        fengshuiLore: tr8(
                            "出处：《撼龙经》。解释：古籍以中心落水象征家门困耗，属于传统堪舆叙事，实际房屋问题仍以现场检查为准。",
                            "出處：《撼龍經》。解釋：古籍以中心落水象徵家門困耗，屬於傳統堪輿敘事，實際房屋問題仍以現場檢查為準。",
                            "Source: The Dragon Classic. Traditional geomancy views water at the center as draining household vitality; inspect actual plumbing and ventilation on site.",
                            "出典：『撼龍経』。中心部の水回りは伝統風水における象徴であり、実際の設備状況は現地確認を基準としてください。",
                            "출처: 《감룡경》. 중심부 수기 배치는 전통 풍수의 상징적 해석이며 실제 설비 상태는 현장 점검을 기준으로 합니다.",
                            "Nguồn: 《Hám Long Kinh》. Cổ thư dùng hình tượng nước ở trung tâm để nhắc nhở giữ khô ráo và thông thoáng cho trục giữa nhà.",
                            "ที่มา: 《หานหลงจิง》 ตำราโบราณเปรียบน้ำกลางบ้านเป็นจุดอ่อนของพลังชี่ ควรตรวจสอบระบบท่อและระบายอากาศจริง",
                            "Sumber: Kitab Han Long Jing. Tradisi feng shui memandang area basah di pusat sebagai simbol pelemahan qi; utamakan pemeriksaan teknis di lokasi."
                        ),
                        solution: tr8(
                            "优先检查防水、排水、排风和检修条件，保持地面干燥、通道清晰；改造前咨询具备资质的专业人员。",
                            "優先檢查防水、排水、排風和檢修條件，保持地面乾燥、通道清晰；改造前諮詢具備資質的專業人員。",
                            "Prioritize waterproofing, exhaust ventilation, and dry floors; keep the door closed and consult qualified professionals before any remodeling.",
                            "防水・排水・換気設備を優先点検し、床面を乾燥させドアを常閉に保ってください。改修時は専門家にご相談ください。",
                            "방수·배수·환기 설비를 우선 점검하여 바닥을 건조하게 유지하고 문을 닫아두세요. 개조 시 전문가와 상담하세요.",
                            "Ưu tiên kiểm tra chống thấm, quạt hút ẩm, giữ sàn khô ráo và đóng cửa phòng vệ sinh; tham khảo chuyên gia trước khi cải tạo.",
                            "ตรวจสอบระบบกันซึมและพัดลมดูดอากาศ รักษาพื้นให้แห้งและปิดประตูห้องน้ำเสมอ ปรึกษาช่างผู้เชี่ยวชาญก่อนดัดแปลง",
                            "Utamakan pemeriksaan kedap air dan exhaust fan, jaga lantai tetap kering serta tutup pintu kamar mandi; konsultasikan dengan ahli sebelum renovasi."
                        ),
                        coordinate: room.center
                    ))
                    score -= 16
                } else if room.type == .kitchen {
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "火烧中宫 (燥火焚心)", "火燒中宮 (燥火焚心)", "Central Palace Fire Sha",
                            "火焼中宮殺（燥火焚心）", "화소중궁살 (중궁 화기)", "Hỏa Thiêu Trung Cung (Táo Hỏa Trung Tâm)",
                            "เคราะห์ไฟเผาจุดศูนย์กลาง", "Sha Api di Pusat Rumah"
                        ),
                        severity: .critical,
                        locationName: tr8(
                            "房屋中宫·\(room.name)", "房屋中宮·\(room.name)", "Center Palace · \(room.name)",
                            "中宮・\(room.name)", "주택 중궁 · \(room.name)", "Trung cung · \(room.name)",
                            "จุดศูนย์กลางบ้าน · \(room.name)", "Pusat Rumah · \(room.name)"
                        ),
                        detail: tr8(
                            "全屋中心被厨房或灶台占据，属于传统文化中的布局提示，请结合实际通风、动线与安全条件复核。",
                            "全屋中心被廚房或灶台佔據，屬於傳統文化中的佈局提示，請結合實際通風、動線與安全條件複核。",
                            "A kitchen or stove occupying the central Tai Ji is flagged in traditional layout lore; verify exhaust ventilation, circulation, and fire safety on site.",
                            "家の中心にキッチンやコンロがある配置です。伝統風水の参考提示として、換気・動線・防火安全を現地で確認してください。",
                            "집 중심부에 주방이나 화구가 위치한 배치입니다. 환기·동선·화재 안전 조건을 현장에서 점검하세요.",
                            "Bếp nấu đặt tại trung tâm ngôi nhà dễ làm nóng khí trường trung cung; vui lòng kiểm tra hệ thống hút mùi, thông gió và an toàn phòng cháy.",
                            "ห้องครัวหรือเตาไฟอยู่ตรงจุดศูนย์กลางบ้าน ควรตรวจสอบการระบายควัน ทางเดิน และความปลอดภัยด้านอัคคีภัยหน้างาน",
                            "Dapur atau kompor yang berada di pusat rumah memerlukan perhatian khusus pada penghisap asap, ventilasi, dan keselamatan kebakaran."
                        ),
                        fengshuiLore: tr8(
                            "出处：《八宅明镜》原文：“火居天心，病染胸膈”。解释：古籍将中心火象与疾病作象征关联，属于传统文化原文，不是医疗判断。",
                            "出處：《八宅明鏡》原文：「火居天心，病染胸膈」。解釋：古籍將中心火象與疾病作象徵關聯，屬於傳統文化原文，不是醫療判斷。",
                            "Source: Ba Zhai Ming Jing ('Fire at the Heaven Heart'). Classical symbolism links central heat to restlessness; not a medical judgment.",
                            "出典：『八宅明鏡』「火が天心に居れば胸膈を損なう」。古典の象徴的表現であり、医学的判断ではありません。",
                            "출처: 《팔택명경》 ‘화가 천심에 있으면 흉격을 상한다’. 고전의 상징적 서술이며 의학적 판단이 아닙니다.",
                            "Nguồn: 《Bát Trạch Minh Kính》 (“Hỏa cư thiên tâm”). Đây là biểu tượng phong thủy cổ điển, không phải chẩn đoán y khoa.",
                            "ที่มา: 《ปาจ้ายหมิงจิ่ง》 กล่าวถึงไฟกลางใจบ้านในเชิงสัญลักษณ์ทางวัฒนธรรม ไม่ใช่คำวินิจฉัยทางการแพทย์",
                            "Sumber: Ba Zhai Ming Jing. Teks klasik mengaitkan panas di pusat rumah secara simbolis, bukan diagnosis medis."
                        ),
                        solution: tr8(
                            "厨灶移位避开房屋正中心，厨房采用米白或浅黄色地砖引土泄火，灶台下置黄玉石辟火化煞。",
                            "廚灶移位避開房屋正中心，廚房採用米白或淺黃色地磚引土洩火，灶台下置黃玉石辟火化煞。",
                            "Relocate the stove away from the exact center if possible; use beige or warm earth-toned tiles and yellow ceramic/jade accents to drain excess Fire into Earth.",
                            "可能であればコンロを中心からずらし、ベージュや淡黄色のタイル・陶器を用いて土気で火気を和らげてください。",
                            "가능하면 화구를 정중앙에서 비켜 배치하고, 미색·연황색 타일이나 황옥 소품으로 화기를 토(土)로 설기하세요.",
                            "Nên dịch bếp tránh chính giữa nhà, dùng gạch lát màu kem hoặc vàng nhạt và đặt đá hoàng ngọc/gốm vàng để Thổ tiết Hỏa.",
                            "ควรขยับเตาออกจากจุดกึ่งกลางบ้าน ใช้กระเบื้องโทนสีครีมหรือเหลืองอ่อน และวางหยกเหลืองหรือเซรามิกเพื่อใช้ธาตุดินลดความร้อน",
                            "Geser posisi kompor dari titik pusat bila memungkinkan; gunakan ubin krem/kuning muda atau keramik kuning agar unsur Tanah meredam Api."
                        ),
                        coordinate: room.center
                    ))
                    score -= 14
                }
            }
        }

        // B. 穿堂煞检测 (入户大门直对阳台移门或主采光大窗，一箭穿心)
        let entranceDoors = openings.filter { $0.type == .entranceDoor }
        let exitOpenings = openings.filter { $0.type == .balconyDoor || $0.type == .window }

        for door in entranceDoors {
            let dPos = SIMD2<Float>(door.posX, door.posZ)
            let dNormal = SIMD2<Float>(door.normalX, door.normalZ)
            let dLen = simd_length(dNormal)
            guard dLen > 1e-4 else { continue }
            let dNorm = dNormal / dLen

            for win in exitOpenings {
                let wPos = SIMD2<Float>(win.posX, win.posZ)
                // 大门出发点：从门内侧（进门方向）偏移 0.3m 起射，规避端点粘连误判
                let inward = simd_dot(dNorm, (wPos - dPos) / max(simd_length(wPos - dPos), 1e-5)) >= 0 ? dNorm : -dNorm
                let startPos = dPos + inward * 0.3
                let delta = wPos - startPos
                let dist = simd_length(delta)
                guard dist >= 2.0 && dist <= 14.0 else { continue }

                let rayDir = delta / dist
                let alignment = abs(simd_dot(dNorm, rayDir))
                let lateralDist = dist * sqrt(max(0, 1.0 - alignment * alignment))

                if alignment >= 0.86 && lateralDist <= 0.90 {
                    // 检查两点之间是否有隔断墙阻隔；墙段交点落在任一开口（门/窗/垭口）
                    // 宽度范围内视为畅通（Opening 豁免），避免过道垭口漏诊穿堂
                    let isBlockedByWall = walls.contains { wall in
                        guard let t = lineIntersectionParam(
                            p1: startPos, p2: wPos,
                            p3: SIMD2<Float>(wall.startX, wall.startZ),
                            p4: SIMD2<Float>(wall.endX, wall.endZ)
                        ), t > 0.001, t < 0.999 else { return false }
                        let hit = startPos + delta * t
                        let isWithinOpening = openings.contains { op in
                            let opPos = SIMD2<Float>(op.posX, op.posZ)
                            let opN = SIMD2<Float>(op.normalX, op.normalZ)
                            let nLen = simd_length(opN)
                            guard nLen > 1e-4 else { return false }
                            let on = opN / nLen
                            let d = hit - opPos
                            // 沿开口走向的横向距离 ≤ 开口半宽 + 容差；沿法线深度 ≤ 墙厚容差
                            let lateral = abs(simd_dot(d, SIMD2<Float>(-on.y, on.x)))
                            let depth = abs(simd_dot(d, on))
                            return lateral <= op.width * 0.5 + 0.05 && depth <= 0.4
                        }
                        return !isWithinOpening
                    }

                    if !isBlockedByWall {
                        let angleOff = Double(acos(min(Float(1.0), alignment))) * 180.0 / Double.pi
                        let winName = win.type.localizedName
                        shaItems.append(HouseSpatialShaItem(
                            title: tr8(
                                "穿堂穿心煞 (一箭穿心)", "穿堂穿心煞 (一箭穿心)", "Through-Hallway Draft Sha",
                                "穿堂殺（一箭穿心）", "천당살 (문·창 직통)", "Xuyên Đường Sát (Một Mũi Xuyên Tâm)",
                                "เคราะห์ลมทะลุผ่าน (ประตูตรงหน้าต่าง)", "Sha Angin Tembus (Pintu–Jendela Segaris)"
                            ),
                            severity: .critical,
                            locationName: tr8(
                                "大门 ⟷ \(winName)", "大門 ⟷ \(winName)", "Main Door ⟷ \(winName)",
                                "玄関 ⟷ \(winName)", "현관문 ⟷ \(winName)", "Cửa chính ⟷ \(winName)",
                                "ประตูใหญ่ ⟷ \(winName)", "Pintu Utama ⟷ \(winName)"
                            ),
                            detail: tr8(
                                String(format: "《葬经》原文有“气乘风则散，界水则止”。入户门与%@轴线近乎共线（间距 %.1f 米，偏角 %.0f°），古籍将其解释为穿堂气散；请结合通风、噪音、视线和通行安全现场复核。", winName, dist, angleOff),
                                String(format: "《葬經》原文有「氣乘風則散，界水則止」。入戶門與%@軸線近乎共線（間距 %.1f 米，偏角 %.0f°），古籍將其解釋為穿堂氣散；請結合通風、噪音、視線和通行安全現場複核。", winName, dist, angleOff),
                                String(format: "The Burial Classic states: 'Qi scatters when riding the wind.' The main entrance aligns directly with %@ (%.1f m apart, %.0f° offset), creating a straight-through draft; verify airflow, privacy, and noise on site.", winName, dist, angleOff),
                                String(format: "『葬経』に「気は風に乗れば散ず」とあります。玄関と%@がほぼ一直線（距離 %.1fm、偏角 %.0f°）で貫通気流が生じるため、風通し・視線・騒音を現地で確認してください。", winName, dist, angleOff),
                                String(format: "《장경》에 ‘기는 바람을 타면 흩어진다’고 했습니다. 현관문과 %@ 축이 거의 일직선(거리 %.1fm, 편각 %.0f°)을 이루어 맞바람이 통하니 통풍·시선·소음을 점검하세요.", winName, dist, angleOff),
                                String(format: "《Táng Kinh》 ghi: “Khí thừa phong tắc tán”. Cửa chính và %@ gần như thẳng hàng (cách %.1f m, lệch %.0f°), tạo luồng gió xuyên phòng; hãy kiểm tra thông gió và tầm nhìn thực tế.", winName, dist, angleOff),
                                String(format: "คัมภีร์《จิ้งจิง》กล่าวว่า “ชี่ต้องลมย่อมกระจาย” ประตูทางเข้าตรงกับ%@ (ห่าง %.1f ม. มุมเยื้อง %.0f°) เกิดลมทะลุผ่านโดยตรง ควรตรวจสอบกระแสลมและแนวสายตาหน้างาน", winName, dist, angleOff),
                                String(format: "Kitab Zang Jing menyebut: 'Qi buyar saat terbawa angin.' Pintu utama segaris dengan %@ (jarak %.1f m, sudut %.0f°), memicu angin tembus langsung; periksa aliran udara dan privasi di lokasi.", winName, dist, angleOff)
                            ),
                            fengshuiLore: tr8(
                                "《葬经》云：'气乘风则散，界水则止'。前通后达直穿门户，宅内藏风聚气之基尽失，所谓'前门进宝后门流'。",
                                "《葬經》云：「氣乘風則散，界水則止」。前通後達直穿門戶，宅內藏風聚氣之基盡失，所謂「前門進寶後門流」。",
                                "The Burial Classic: 'Qi scatters with wind and gathers at water.' A direct front-to-back draft prevents the home from retaining calm, gathered energy.",
                                "『葬経』「気は風に乗れば散じ、水に界すれば止まる」。表から奥へ吹き抜ける構造は蔵風聚気を損なうとされます。",
                                "《장경》 ‘기승풍즉산 계수즉지’. 앞문이 뒷창과 직통하면 집안의 장풍취기(藏風聚氣)가 흩어진다고 봅니다.",
                                "《Táng Kinh》: “Khí thừa phong tắc tán, giới thủy tắc chỉ”. Cửa trước thông thẳng cửa sau khiến nhà khó tụ khí.",
                                "《จิ้งจิง》กล่าวว่า “ชี่ต้องลมย่อมสลาย หยุดเมื่อพบน้ำ” ประตูหน้าทะลุหลังทำให้บ้านเก็บกักพลังงานมงคลไม่อยู่",
                                "Zang Jing: 'Qi buyar tertiup angin dan berhenti di air.' Aliran lurus dari pintu depan ke belakang menyulitkan rumah menghimpun energi tenang."
                            ),
                            solution: tr8(
                                "在大门玄关处设实木屏风、半透磨砂玄关柜阻挡视线，或在阳台处悬挂厚质遮光帘与铜葫芦聚气。",
                                "在大門玄關處設實木屏風、半透磨砂玄關櫃阻擋視線，或在陽台處懸掛厚質遮光簾與銅葫蘆聚氣。",
                                "Place a wooden screen or frosted-glass entry cabinet at the foyer to buffer the sightline, or hang heavy curtains and a brass gourd near the window/balcony.",
                                "玄関に木製屏風やスリガラス付きの収納棚を設けて視線と気流を和らげるか、窓側に厚手のカーテンを掛けて聚気してください。",
                                "현관에 원목 파티션이나 반투명 수납장을 두어 시선과 기류를 완충하거나, 발코니·창가에 두꺼운 커튼을 설치해 기운을 모으세요.",
                                "Đặt bình phong gỗ hoặc tủ huyền quan kính mờ ở lối vào để chắn tầm nhìn, hoặc treo rèm dày và hồ lô đồng ở phía ban công/cửa sổ.",
                                "ติดตั้งฉากกั้นไม้หรือตู้ทางเข้ากระจกฝ้าเพื่อบังสายตา หรือติดม่านทึบและแขวนน้ำเต้าทองเหลืองบริเวณระเบียงเพื่อเก็บกักชี่",
                                "Pasang sekat kayu atau kabinet foyer kaca buram di pintu masuk untuk menahan garis pandang, atau gunakan tirai tebal di sisi balkon/jendela."
                            ),
                            coordinate: door.position,
                            vectorEnd: win.position
                        ))
                        score -= 15
                        break
                    }
                }
            }
        }

        // C. 对门煞 (对门相冲·骂门煞)
        let doors = openings.filter { $0.type == .interiorDoor || $0.type == .entranceDoor }
        for i in 0..<doors.count {
            for j in (i + 1)..<doors.count {
                let d1 = doors[i]
                let d2 = doors[j]
                let p1 = SIMD2<Float>(d1.posX, d1.posZ)
                let p2 = SIMD2<Float>(d2.posX, d2.posZ)
                let dist = simd_distance(p1, p2)
                guard dist > 0.6 && dist < 2.5 else { continue }

                let n1 = SIMD2<Float>(d1.normalX, d1.normalZ)
                let n2 = SIMD2<Float>(d2.normalX, d2.normalZ)
                let faceScore = simd_dot(n1, n2) // 相向面对面时法线夹角反向，dot 接近 -1
                if faceScore < -0.70 {
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "门冲对门煞 (两口相对)", "門衝對門煞 (兩口相對)", "Opposing Doors Clash",
                            "対門殺（ドアの対峙）", "대문충살 (문끼리 마주봄)", "Đối Môn Sát (Hai Cửa Đối Nhau)",
                            "เคราะห์ประตูชนกัน (สองประตูปะทะ)", "Sha Pintu Berhadapan"
                        ),
                        severity: .warning,
                        locationName: tr8(
                            "双门对冲·间距 \(String(format: "%.1f", dist))m",
                            "雙門對衝·間距 \(String(format: "%.1f", dist))m",
                            "Facing Doors · \(String(format: "%.1f", dist))m apart",
                            "対向ドア・距離 \(String(format: "%.1f", dist))m",
                            "마주 보는 문 · 간격 \(String(format: "%.1f", dist))m",
                            "Hai cửa đối diện · cách \(String(format: "%.1f", dist))m",
                            "ประตูตรงกัน · ห่าง \(String(format: "%.1f", dist)) ม.",
                            "Pintu Berhadapan · jarak \(String(format: "%.1f", dist))m"
                        ),
                        detail: tr8(
                            "两间居室房门直对，间距过窄产生对流风切，主家人意见相左、易生口角龃龉。",
                            "兩間居室房門直對，間距過窄產生對流風切，主家人意見相左、易生口角齟齬。",
                            "Two room doors face each other across a narrow corridor, creating cross-drafts and privacy overlap; traditionally linked to household friction.",
                            "二つの室内ドアが狭い間隔で正対し、気流の衝突と視線の交差が生じています。家庭内の摩擦を招きやすい配置とされます。",
                            "두 방의 문이 좁은 간격으로 마주 보고 있어 대류 바람과 시선 충돌이 생기며, 가족 간 의견 마찰을 부르기 쉽다고 봅니다.",
                            "Hai cửa phòng đối diện nhau ở khoảng cách hẹp tạo gió đối lưu và giao cắt tầm nhìn, dễ gây bất đồng trong gia đình.",
                            "ประตูสองห้องหันชนกันในระยะแคบทำให้เกิดลมปะทะและขาดความเป็นส่วนตัว ตามตำราว่าอาจทำให้คนในบ้านขัดแย้งกันง่าย",
                            "Dua pintu kamar saling berhadapan dalam jarak sempit sehingga memicu angin silang dan gesekan privasi antarpenghuni."
                        ),
                        fengshuiLore: tr8(
                            "《阳宅十书》云：'两门相对谓相骂，主家不和争相夸'。门户为纳气之口，两口相争则家宅不宁。",
                            "《陽宅十書》云：「兩門相對謂相罵，主家不和爭相誇」。門戶為納氣之口，兩口相爭則家宅不寧。",
                            "Yang Zhai Ten Books: 'Two doors facing each other are called quarreling mouths.' Doors are qi mouths; direct opposition stirs restlessness.",
                            "『陽宅十書』「両門相対するを相罵と謂う」。扉は気の出入り口であり、正対すると気が乱れるとされます。",
                            "《양택십서》 ‘양문상대위상마(兩門相對謂相罵)’. 문은 기를 받아들이는 입이라 서로 마주 보면 가택이 소란해지기 쉽습니다.",
                            "《Dương Trạch Thập Thư》: “Lưỡng môn tương đối vị tương mạ”. Hai cửa đối diện trực tiếp làm xáo trộn khí trường chung.",
                            "《หยางไจ๋สือซู》กล่าวว่า “สองประตูหันชนกันเปรียบเหมือนปากโต้เถียง” ทำให้กระแสชี่ในบ้านไม่สงบ",
                            "Yang Zhai Ten Books menyebut dua pintu yang saling berhadapan sebagai 'dua mulut berdebat' yang mengganggu ketenangan rumah."
                        ),
                        solution: tr8(
                            "门上悬挂过膝布帘，门框两侧可加装五帝钱或中国结以和解气场，平时常保持其中一门常闭。",
                            "門上懸掛過膝布簾，門框兩側可加裝五帝錢或中國結以和解氣場，平時常保持其中一門常閉。",
                            "Hang a knee-length fabric door curtain, add Five-Emperor coins or a decorative knot on the frame, and keep at least one door closed when not in use.",
                            "ドアに丈の長い暖簾を掛け、五帝銭や飾り結びを添えて気を和らげ、普段は片方のドアを閉めておきましょう。",
                            "문에 긴 패브릭 커튼을 달고 문틀에 오제전이나 전통 매듭을 걸어 기운을 중화하며, 평소 한쪽 문을 닫아두세요.",
                            "Treo rèm vải dài qua gối trên cửa, gắn thêm tiền Ngũ Đế hoặc nút thắt cát tường và giữ một cửa đóng khi không sử dụng.",
                            "ติดม่านผ้าความยาวคลุมเข่าที่ประตู แขวนเหรียญห้าจักรพรรดิหรือพู่ถักมงคล และปิดประตูบานใดบานหนึ่งไว้เสมอเมื่อไม่ใช้งาน",
                            "Pasang tirai pintu sepanjang lutut, tambahkan Koin Lima Kaisar atau simpul hias, dan biasakan menutup salah satu pintu."
                        ),
                        coordinate: d1.position,
                        vectorEnd: d2.position
                    ))
                    score -= 8
                    break
                }
            }
        }

        // D. 横梁压顶检测 (Beam Clearance < 2.35m 且下方有床或沙发)
        let bedsAndSofas = objects.filter { $0.category == "bed" || $0.category == "sofa" }
        for beam in beams {
            guard beam.clearanceHeight < 2.45 else { continue }
            let b1 = SIMD2<Float>(beam.startX, beam.startZ)
            let b2 = SIMD2<Float>(beam.endX, beam.endZ)

            for target in bedsAndSofas {
                let tPos = SIMD2<Float>(target.posX, target.posZ)
                let distToBeam = distancePointToSegment(point: tPos, segA: b1, segB: b2)
                if distToBeam <= 0.85 {
                    let isBed = target.category == "bed"
                    let targetName = isBed
                        ? tr8("睡床", "睡床", "Bed", "ベッド", "침대", "Giường ngủ", "เตียงนอน", "Ranjang")
                        : tr8("主位沙发", "主位沙發", "Main Sofa", "メインソファ", "메인 소파", "Sofa chính", "โซฟาหลัก", "Sofa Utama")
                    let clrStr = String(format: "%.2f", beam.clearanceHeight)
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "横梁压顶煞 (气压沉重)", "橫梁壓頂煞 (氣壓沉重)", "Overhead Beam Pressure Sha",
                            "横梁圧頂殺（頭上の梁）", "횡량압정살 (대들보 압박)", "Xà Ngang Đè Đầu (Áp Lực Trần)",
                            "เคราะห์คานทับศีรษะ", "Sha Balok Gantung di Atas Kepala"
                        ),
                        severity: .critical,
                        locationName: tr8(
                            "\(targetName)正上方 (净高\(clrStr)m)",
                            "\(targetName)正上方 (淨高\(clrStr)m)",
                            "Above \(targetName) (clearance \(clrStr)m)",
                            "\(targetName)の真上（有効高\(clrStr)m）",
                            "\(targetName) 바로 위 (유효높이 \(clrStr)m)",
                            "Phía trên \(targetName) (cao \(clrStr)m)",
                            "เหนือ\(targetName) (สูง \(clrStr) ม.)",
                            "Di atas \(targetName) (tinggi \(clrStr)m)"
                        ),
                        detail: tr8(
                            String(format: "沉重承重横梁横跨在%@上方，下垂气流形成沉降重压，久居易头痛压抑、精神衰弱。", targetName),
                            String(format: "沉重承重橫梁橫跨在%@上方，下垂氣流形成沉降重壓，久居易頭痛壓抑、精神衰弱。", targetName),
                            String(format: "A low structural beam runs directly above the %@, creating visual pressure and downward draft that can disturb rest and focus.", targetName),
                            String(format: "構造梁が%@の真上を横切り、下向きの気流と視覚的な圧迫感を生んでいます。休息の質に影響しやすい配置です。", targetName),
                            String(format: "구조 보가 %@ 바로 위를 가로질러 하강 기류와 시각적 압박감을 형성하므로 수면과 휴식에 방해가 될 수 있습니다.", targetName),
                            String(format: "Xà ngang chịu lực nằm ngay phía trên %@, tạo cảm giác đè nén thị giác và ảnh hưởng đến giấc ngủ, sự thư giãn.", targetName),
                            String(format: "คานรับน้ำหนักพาดผ่านเหนือ%@โดยตรง ทำให้เกิดแรงกดทับทางสายตาและรบกวนการพักผ่อน", targetName),
                            String(format: "Balok struktural melintas tepat di atas %@, menimbulkan tekanan visual yang dapat mengganggu kenyamanan istirahat.", targetName)
                        ),
                        fengshuiLore: tr8(
                            "《鲁班经》云：'横梁压顶若悬斧，身染沉疴气数枯'。横梁下空气受阻下压，人处于其下受气场冲煞。",
                            "《魯班經》云：「橫梁壓頂若懸斧，身染沉疴氣數枯」。橫梁下空氣受阻下壓，人處於其下受氣場衝煞。",
                            "Lu Ban Classic compares an exposed overhead beam to a suspended blade; airflow rebounds downward over the occupant below.",
                            "『魯班経』では頭上の露出梁を忌み、気流が梁に当たって下方に圧力をかけると説かれています。",
                            "《노반경》에서는 머리 위 노출된 보가 기류를 아래로 누르므로 오래 머무는 자리 위를 피하라고 전합니다.",
                            "《Lỗ Ban Kinh》 ví xà ngang lộ thiên đè trên đầu như vật nặng treo lơ lửng, làm dòng khí dội xuống người ngồi hoặc nằm bên dưới.",
                            "คัมภีร์《หลู่ปานจิง》กล่าวว่าคานที่เปลือยอยู่เหนือศีรษะจะกดทับกระแสอากาศและสร้างความอึดอัดแก่ผู้อยู่อาศัย",
                            "Kitab Lu Ban mengibaratkan balok terbuka di atas kepala sebagai beban menggantung yang menekan aliran udara ke bawah."
                        ),
                        solution: tr8(
                            "将床铺或沙发平移挪出横梁投影区；若无法挪位，建议做平吊顶包梁隐藏，或梁两端悬挂开光铜葫芦泄压。",
                            "將床鋪或沙發平移挪出橫梁投影區；若無法挪位，建議做平吊頂包梁隱藏，或梁兩端懸掛開光銅葫蘆洩壓。",
                            "Shift the bed or sofa out from under the beam footprint; if fixed, enclose the beam with a flush false ceiling or hang brass gourds at both ends.",
                            "ベッドやソファを梁の直下から移動するか、天井造作で梁を隠す、または梁の両端に銅瓢箪を掛けて圧迫感を和らげてください。",
                            "침대나 소파를 보 아래에서 벗어나게 이동하거나, 평평한 마감 천장으로 보를 감추고 양 끝에 동호리병을 걸어 압박을 완화하세요.",
                            "Dịch chuyển giường hoặc sofa ra khỏi bóng xà ngang; nếu cố định, nên làm trần phẳng che xà hoặc treo hồ lô đồng ở hai đầu xà.",
                            "เลื่อนเตียงหรือโซฟาออกจากแนวคาน หากย้ายไม่ได้แนะนำให้ทำฝ้าเพดานเรียบปิดคาน หรือแขวนน้ำเต้าทองเหลืองที่ปลายคานทั้งสองด้าน",
                            "Geser ranjang atau sofa keluar dari bawah garis balok; jika tidak memungkinkan, tutup dengan plafon rata atau gantung labu tembaga di kedua ujungnya."
                        ),
                        coordinate: SIMD3<Float>(target.posX, beam.clearanceHeight, target.posZ)
                    ))
                    score -= 12
                    break
                }
            }
        }

        // E. 门冲床位检测
        let beds = objects.filter { $0.category == "bed" }
        for door in doors {
            let dPos = SIMD2<Float>(door.posX, door.posZ)
            let dNorm = SIMD2<Float>(door.normalX, door.normalZ)
            for bed in beds {
                let bPos = SIMD2<Float>(bed.posX, bed.posZ)
                let delta = bPos - dPos
                let dist = simd_length(delta)
                guard dist >= 0.8 && dist <= 3.8 else { continue }
                let alignment = simd_dot(dNorm, delta / dist)
                let lateral = dist * sqrt(max(0, 1.0 - alignment * alignment))
                if alignment >= 0.82 && lateral <= 0.65 {
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "房门冲床 (冲撞身魂)", "房門衝床 (衝撞身魂)", "Door-to-Bed Direct Draft",
                            "門衝床殺（ドアとベッドの直対）", "문충침살 (방문·침대 직충)", "Môn Xung Sàng (Cửa Chiếu Thẳng Giường)",
                            "เคราะห์ประตูพุ่งชนเตียง", "Sha Pintu Menusuk Ranjang"
                        ),
                        severity: .warning,
                        locationName: tr8(
                            "房门 ⟷ 卧床", "房門 ⟷ 臥床", "Room Door ⟷ Bed",
                            "室内ドア ⟷ ベッド", "방문 ⟷ 침대", "Cửa phòng ⟷ Giường ngủ",
                            "ประตูห้อง ⟷ เตียงนอน", "Pintu Kamar ⟷ Ranjang"
                        ),
                        detail: tr8(
                            String(format: "房门与床铺形成直线气流（间距 %.1f 米），建议结合实际通风、噪音与动线调整布局。", dist),
                            String(format: "房門與床鋪形成直線氣流（間距 %.1f 米），建議結合實際通風、噪音與動線調整佈局。", dist),
                            String(format: "The room door opens directly toward the bed (%.1f m apart), exposing the sleeper to drafts, noise, and sudden entry.", dist),
                            String(format: "室内ドアとベッドが直線上の気流（距離 %.1fm）を形成しています。通風・騒音・プライバシーに合わせて配置を調整してください。", dist),
                            String(format: "방문과 침대가 일직선 기류(거리 %.1fm)를 이루고 있습니다. 통풍·소음·프라이버시를 고려해 배치를 조정하세요.", dist),
                            String(format: "Cửa phòng mở thẳng vào giường ngủ (cách %.1f m), tạo luồng gió trực diện và giảm sự riêng tư khi nghỉ ngơi.", dist),
                            String(format: "ประตูห้องเปิดตรงเข้าหาเตียงนอน (ห่าง %.1f ม.) ทำให้รับลมและเสียงรบกวนโดยตรง ควรปรับตำแหน่งเพื่อการพักผ่อนที่ดี", dist),
                            String(format: "Pintu kamar membuka lurus ke arah ranjang (jarak %.1f m), menimbulkan aliran angin langsung dan mengurangi privasi tidur.", dist)
                        ),
                        fengshuiLore: tr8(
                            "门开气入直射人身，动静失衡，神魂不聚。",
                            "門開氣入直射人身，動靜失衡，神魂不聚。",
                            "When the door opens directly onto the bed, active airflow disturbs the quiet yin environment needed for deep rest.",
                            "扉から入る動気が寝床を直撃すると、動静のバランスが崩れ安眠を妨げるとされます。",
                            "문이 열릴 때 들어오는 동기가 침상을 직격하면 동정의 균형이 깨져 깊은 수면을 방해한다고 봅니다.",
                            "Cửa mở dẫn luồng khí động chiếu thẳng vào giường làm mất cân bằng động tĩnh, khó ngủ sâu.",
                            "เมื่อเปิดประตูแล้วกระแสลมพุ่งเข้าหาตัวโดยตรง จะรบกวนความสงบนิ่งที่จำเป็นต่อการนอนหลับ",
                            "Aliran udara aktif dari pintu yang langsung mengarah ke tempat tidur mengganggu ketenangan yang dibutuhkan untuk istirahat."
                        ),
                        solution: tr8(
                            "微调床头朝向或位置避开门冲直线，若空间受限可在门边设遮挡隔断或门挂长帘缓冲。",
                            "微調床頭朝向或位置避開門衝直線，若空間受限可在門邊設遮擋隔斷或門掛長簾緩衝。",
                            "Shift the bed out of the doorway's direct line, or add a bedside screen / long door curtain if space is tight.",
                            "ベッドの位置をドアの正面からずらすか、スペースが限られる場合は衝立やロング暖簾で緩衝してください。",
                            "침대 위치를 문 정면에서 비켜 배치하거나, 공간이 좁다면 가림막 파티션이나 긴 문커튼으로 완충하세요.",
                            "Dịch giường lệch khỏi trục cửa phòng, hoặc đặt vách ngăn nhẹ / treo rèm dài ở cửa để giảm xung trực diện.",
                            "ขยับเตียงให้พ้นแนวตรงของประตู หรือตั้งฉากบังตา/ติดม่านยาวที่ประตูเพื่อช่วยกรองกระแสลม",
                            "Geser posisi ranjang agar tidak segaris dengan pintu, atau tambahkan sekat/tirai pintu panjang sebagai penyangga."
                        ),
                        coordinate: door.position,
                        vectorEnd: bed.position
                    ))
                    score -= 8
                    break
                }
            }
        }

        // F. 水火相冲 (厨灶与卫浴马桶或水槽近距离对立)
        let stoves = objects.filter { $0.category == "stove" || $0.category == "oven" }
        let toilets = objects.filter { $0.category == "toilet" || $0.category == "bathtub" }
        for stove in stoves {
            let sPos = SIMD2<Float>(stove.posX, stove.posZ)
            for toilet in toilets {
                let tPos = SIMD2<Float>(toilet.posX, toilet.posZ)
                let dist = simd_distance(sPos, tPos)
                if dist <= 2.2 {
                    let distStr = String(format: "%.1f", dist)
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "水火未济 (厨厕相逼)", "水火未濟 (廚廁相逼)", "Water–Fire Proximity Clash",
                            "水火未済殺（厨厠近接）", "수화미제살 (주방·욕실 근접)", "Thủy Hỏa Vị Tế (Bếp & Vệ Sinh Quá Gần)",
                            "เคราะห์น้ำไฟปะทะ (เตาไฟใกล้สุขภัณฑ์)", "Benturan Air–Api (Kompor Dekat Sanitasi)"
                        ),
                        severity: .warning,
                        locationName: tr8(
                            "灶台 ⟷ 卫浴 (间距 \(distStr)m)",
                            "灶台 ⟷ 衛浴 (間距 \(distStr)m)",
                            "Stove ⟷ BathFixture (\(distStr)m)",
                            "コンロ ⟷ 水回り（距離 \(distStr)m）",
                            "화구 ⟷ 욕실 설비 (간격 \(distStr)m)",
                            "Bếp nấu ⟷ Thiết bị vệ sinh (cách \(distStr)m)",
                            "เตาไฟ ⟷ สุขภัณฑ์ (ห่าง \(distStr) ม.)",
                            "Kompor ⟷ Sanitasi (jarak \(distStr)m)"
                        ),
                        detail: tr8(
                            "《催官篇》原文有“水火不相容，宅母病腹痛”。灶台与卫浴距离较近，按古籍象征会被解释为水火相逼；请结合热源距离、通风、防水和使用安全复核。",
                            "《催官篇》原文有「水火不相容，宅母病腹痛」。灶台與衛浴距離較近，按古籍象徵會被解釋為水火相逼；請結合熱源距離、通風、防水和使用安全複核。",
                            "The stove and bathroom fixture are in close proximity; classical texts symbolize this as Water–Fire opposition. Verify hygiene separation, ventilation, and waterproofing on site.",
                            "コンロと浴室設備が近接しており、古典では水火相逼と象徴されます。換気・防水・衛生動線を現地で確認してください。",
                            "화구와 욕실 설비가 가까워 고전에서는 수화상충으로 풀이합니다. 열원 거리·환기·방수·위생 동선을 현장에서 점검하세요.",
                            "Bếp nấu và thiết bị vệ sinh đặt quá gần nhau tạo thế Thủy Hỏa tương xung theo cổ thư; hãy kiểm tra vách ngăn, thông gió và vệ sinh thực tế.",
                            "เตาไฟและสุขภัณฑ์อยู่ใกล้กันเกินไป ตามตำราถือเป็นน้ำปะทะไฟ ควรตรวจสอบการกั้นพื้นที่ การระบายอากาศ และสุขอนามัยหน้างาน",
                            "Kompor dan fasilitas kamar mandi berada sangat dekat; pastikan pemisahan higienis, ventilasi, dan kedap air di lokasi."
                        ),
                        fengshuiLore: tr8(
                            "出处：《催官篇》。解释：原文把水火同宫与腹痛相联系，是传统象征性叙述，不是医疗诊断。",
                            "出處：《催官篇》。解釋：原文把水火同宮與腹痛相聯繫，是傳統象徵性敘述，不是醫療診斷。",
                            "Source: Cui Guan Pian. Traditional symbolism links Water–Fire proximity to digestive discomfort; not a medical diagnosis.",
                            "出典：『催官篇』。水火の近接を消化器の不調に結び付ける伝統的象徴であり、医学的診断ではありません。",
                            "출처: 《최관편》. 수화 근접을 소화기 불편과 연결한 전통 상징 서술이며 의학적 진단이 아닙니다.",
                            "Nguồn: 《Thôi Quan Thiên》. Cổ thư liên hệ Thủy Hỏa xung khắc với tiêu hóa theo nghĩa biểu trưng, không phải chẩn đoán y khoa.",
                            "ที่มา: 《ชุยกวานเพียน》 เป็นคำเปรียบเปรยเชิงสัญลักษณ์ตามตำราโบราณ ไม่ใช่การวินิจฉัยทางการแพทย์",
                            "Sumber: Cui Guan Pian. Teks klasik mengaitkan benturan Air–Api secara simbolis, bukan diagnosis medis."
                        ),
                        solution: tr8(
                            "炉灶与卫生间门错开避对，两者之间摆放常青绿植（木元素）以形成'水生木、木生火'通关调和。",
                            "爐灶與衛生間門錯開避對，兩者之間擺放常青綠植（木元素）以形成「水生木、木生火」通關調和。",
                            "Offset the stove and bathroom door so they do not face each other, and place a leafy green plant (Wood element) between them to bridge Water and Fire.",
                            "コンロと浴室ドアの正対を避け、間に観葉植物（木気）を置いて「水生木・木生火」の通関を図ってください。",
                            "화구와 욕실 문이 마주 보지 않게 어긋나게 두고, 사이에 상록 식물(목 기운)을 배치해 수생목·목생화로 통관시키세요.",
                            "Đặt lệch hướng bếp và cửa phòng vệ sinh, đồng thời bố trí cây xanh (hành Mộc) ở giữa để Thủy sinh Mộc, Mộc sinh Hỏa.",
                            "จัดวางเตาไฟไม่ให้ตรงกับประตูห้องน้ำ และวางต้นไม้ใบเขียว (ธาตุไม้) คั่นกลางเพื่อเชื่อมสมดุลน้ำเกิดไม้และไม้หนุนไฟ",
                            "Hindari posisi kompor berhadapan langsung dengan pintu kamar mandi, dan letakkan tanaman hijau (unsur Kayu) sebagai jembatan elemen."
                        ),
                        coordinate: stove.position,
                        vectorEnd: toilet.position
                    ))
                    score -= 7
                    break
                }
            }
        }

        // G. 入户大门鲁班门光吉度评定
        if let mainDoor = entranceDoors.first {
            let eval = LubanRulerEvaluation.evaluate(meters: mainDoor.width)
            let wStr = String(format: "%.2f", mainDoor.width)
            let segName = eval.localizedYangSegmentName
            if eval.yangIsAuspicious {
                shaItems.append(HouseSpatialShaItem(
                    title: tr8(
                        "鲁班门光尺 · 大门纳吉", "魯班門光尺 · 大門納吉", "Lu Ban Ruler · Auspicious Entrance",
                        "魯班門光尺・玄関納吉", "노반척 · 대문 납길", "Thước Lỗ Ban · Cửa Chính Nạp Cát",
                        "บรรทัดหลู่ปาน · ประตูมงคล", "Penggaris Lu Ban · Pintu Utama Berkah"
                    ),
                    severity: .auspicious,
                    locationName: tr8(
                        "入户大门 (宽 \(wStr)m)", "入戶大門 (寬 \(wStr)m)", "Main Entrance (width \(wStr)m)",
                        "玄関ドア（幅 \(wStr)m）", "현관문 (폭 \(wStr)m)", "Cửa chính (rộng \(wStr)m)",
                        "ประตูทางเข้าหลัก (กว้าง \(wStr) ม.)", "Pintu Utama (lebar \(wStr)m)"
                    ),
                    detail: tr8(
                        String(format: "入户门开间度量合鲁班门光尺【%@】字门，迎祥纳福，广纳正气生机。", segName),
                        String(format: "入戶門開間度量合魯班門光尺【%@】字門，迎祥納福，廣納正氣生機。", segName),
                        String(format: "The main entrance width aligns with the auspicious [%@] segment on the Lu Ban Yang-House Ruler, welcoming vibrant qi.", segName),
                        String(format: "玄関の開口幅が魯班尺の吉寸【%@】に合致しており、瑞気を迎え入れる良好な寸法です。", segName),
                        String(format: "현관문 개구부 폭이 노반척의 길한 치수인 【%@】문에 부합하여 상서로운 생기를 받아들입니다.", segName),
                        String(format: "Chiều rộng cửa chính ứng với cung tốt 【%@】 trên thước Lỗ Ban Dương Trạch, đón nhận sinh khí cát tường.", segName),
                        String(format: "ความกว้างประตูทางเข้าตรงกับช่องมงคล【%@】ตามมาตรวัดหลู่ปาน ช่วยเปิดรับพลังชี่ที่ดีเข้าสู่บ้าน", segName),
                        String(format: "Lebar pintu utama berada pada segmen baik [%@] pada penggaris Lu Ban, mendukung masuknya energi positif.", segName)
                    ),
                    fengshuiLore: tr8(
                        "鲁班先师制尺定度，八寸循环纳吉，门吉则气正。",
                        "魯班先師制尺定度，八寸循環納吉，門吉則氣正。",
                        "Master Lu Ban's eight-segment cycle measures doorway proportions; an auspicious gate dimension supports balanced entry qi.",
                        "魯班尺の八寸循環において吉門に合致すると、気口が整い家運が安定するとされます。",
                        "노반척 팔문 순환에서 길한 치수에 해당하면 기구(氣口)가 바르게 서서 가운이 안정된다고 봅니다.",
                        "Thước Lỗ Ban chia tám cung tuần hoàn; kích thước cửa hợp cung cát giúp khí khẩu ngay ngắn, vượng trạch.",
                        "บรรทัดหลู่ปานแบ่งรอบแปดช่อง เมื่อขนาดประตูตกช่องมงคลจะช่วยให้ปากทางรับชี่สมดุล",
                        "Siklus delapan segmen penggaris Lu Ban mengukur proporsi pintu; ukuran yang tepat menjaga keseimbangan gerbang qi."
                    ),
                    solution: tr8(
                        "大门尺寸得吉，宜保持玄关整洁明亮，门前不堆杂物，使吉气源源入户。",
                        "大門尺寸得吉，宜保持玄關整潔明亮，門前不堆雜物，使吉氣源源入戶。",
                        "Keep the foyer bright, tidy, and free of clutter so auspicious qi flows smoothly into the home.",
                        "玄関周りを常に明るく清潔に保ち、靴や雑物を溜めないことで吉気がスムーズに巡ります。",
                        "현관을 항상 밝고 청결하게 유지하고 문 앞에 잡동사니를 두지 않으면 길한 기운이 원활히 유입됩니다.",
                        "Giữ khu vực huyền quan sáng sủa, gọn gàng, không chất đồ bừa bộn trước cửa để đón cát khí.",
                        "รักษาบริเวณโถงทางเข้าให้สะอาดสว่าง ไม่วางของเกะกะหน้าประตู เพื่อให้พลังมงคลไหลเวียนสะดวก",
                        "Jaga area foyer tetap terang, rapi, dan bebas tumpukan barang agar energi baik mengalir lancar."
                    ),
                    coordinate: mainDoor.position
                ))
                score += 5
            } else {
                shaItems.append(HouseSpatialShaItem(
                    title: tr8(
                        "鲁班门光尺 · 大门失度", "魯班門光尺 · 大門失度", "Lu Ban Ruler · Non-Ideal Door Width",
                        "魯班門光尺・寸法注意", "노반척 · 대문 치수 주의", "Thước Lỗ Ban · Kích Thước Cửa Cần Lưu Ý",
                        "บรรทัดหลู่ปาน · ขนาดประตูควรระวัง", "Penggaris Lu Ban · Lebar Pintu Kurang Ideal"
                    ),
                    severity: .warning,
                    locationName: tr8(
                        "入户大门 (宽 \(wStr)m)", "入戶大門 (寬 \(wStr)m)", "Main Entrance (width \(wStr)m)",
                        "玄関ドア（幅 \(wStr)m）", "현관문 (폭 \(wStr)m)", "Cửa chính (rộng \(wStr)m)",
                        "ประตูทางเข้าหลัก (กว้าง \(wStr) ม.)", "Pintu Utama (lebar \(wStr)m)"
                    ),
                    detail: tr8(
                        String(format: "大门宽度落入鲁班门光尺【%@】凶度字门，门气略有亏耗。", segName),
                        String(format: "大門寬度落入魯班門光尺【%@】凶度字門，門氣略有虧耗。", segName),
                        String(format: "The main entrance width falls in the [%@] segment on the traditional Lu Ban Ruler; verify actual frame clearance.", segName),
                        String(format: "玄関幅が魯班尺の【%@】門に該当します。実測の内法寸法を再確認してください。", segName),
                        String(format: "현관문 폭이 노반척의 【%@】 구간에 해당합니다. 실제 문틀 안쪽 치수를 확인하세요.", segName),
                        String(format: "Chiều rộng cửa chính rơi vào cung 【%@】 trên thước Lỗ Ban truyền thống; nên đo lại kích thước thông thủy thực tế.", segName),
                        String(format: "ความกว้างประตูตกช่อง【%@】ตามบรรทัดหลู่ปาน แนะนำให้วัดระยะช่องเปิดจริงของวงกบอีกครั้ง", segName),
                        String(format: "Lebar pintu utama jatuh pada segmen [%@] penggaris Lu Ban tradisional; periksa kembali ukuran bersih kusen.", segName)
                    ),
                    fengshuiLore: tr8(
                        "门不合度，气散难聚。",
                        "門不合度，氣散難聚。",
                        "Traditional carpentry lore favors adjusting trim or threshold proportions when doorway measurements fall outside auspicious segments.",
                        "伝統木工の尺度論では、内法寸法や敷居・枠見込みで吉寸に整えることが推奨されます。",
                        "전통 목수 척도론에서는 문틀 마감재나 문턱 치수를 조절해 길한 규격으로 맞추는 것을 권장합니다.",
                        "Theo phép đo Lỗ Ban truyền thống, có thể điều chỉnh nẹp khuôn cửa hoặc thảm ngạch cửa để cân đối lại khí khẩu.",
                        "ตามหลักช่างหลู่ปาน สามารถปรับคิ้ววงกบหรือพรมธรณีประตูเพื่อเสริมความสมดุลของช่องทางเข้าได้",
                        "Tradisi Lu Ban menyarankan penyesuaian lis kusen atau keset ambang pintu untuk menyeimbangkan proporsi pintu."
                    ),
                    solution: tr8(
                        "可优先确认门槛、地垫和通道尺寸，保持入口平整防滑；涉及改造时咨询具备资质的专业人员。",
                        "可優先確認門檻、地墊和通道尺寸，保持入口平整防滑；涉及改造時諮詢具備資質的專業人員。",
                        "Verify inner frame clearance, place aFive-Emperor coin threshold mat, and keep the entryway well-lit and slip-free.",
                        "内法寸法や敷居マットを確認し、玄関照明を明るく保ち、五帝銭マット等で気口を補ってください。",
                        "문틀 내측 치수와 문턱 매트를 점검하고, 현관 조명을 밝게 유지하거나 오제전 매트로 기운을 보완하세요.",
                        "Kiểm tra lại kích thước thông thủy, đặt thảm ngạch cửa kèm tiền Ngũ Đế và giữ đèn huyền quan sáng rõ.",
                        "ตรวจสอบระยะช่องไฟจริง วางพรมธรณีประตูหรือเหรียญห้าจักรพรรดิ และเปิดไฟโถงทางเข้าให้สว่าง",
                        "Periksa kembali lebar bersih kusen, gunakan keset ambang pintu yang rapi, dan pastikan pencahayaan foyer terang."
                    ),
                    coordinate: mainDoor.position
                ))
                score -= 4
            }
        }

        // H. 户型规整度与开间进深比
        if dimensions.aspectRatio > 2.2 {
            let ratioStr = String(format: "%.1f", dimensions.aspectRatio)
            shaItems.append(HouseSpatialShaItem(
                title: tr8(
                    "户型狭长 (深长损明)", "戶型狹長 (深長損明)", "Narrow Elongated Layout",
                    "狭長間取り（奥行き過多）", "협장형 평면 (깊고 좁은 구조)", "Mặt Bằng Hẹp Dài (Sâu Thiếu Sáng)",
                    "ผังบ้านแคบยาว (ลึกอับแสง)", "Denah Memanjang Sempit"
                ),
                severity: .warning,
                locationName: tr8(
                    "整体户型轮廓", "整體戶型輪廓", "Overall Footprint",
                    "住戸全体の輪郭", "전체 평면 윤곽", "Tổng thể mặt bằng",
                    "โครงร่างผังบ้านโดยรวม", "Bentuk Denah Keseluruhan"
                ),
                detail: tr8(
                    String(format: "全屋进深是开间的 %@ 倍，形如长巷，中段采光通风弱，阴阳气流失衡。", ratioStr),
                    String(format: "全屋進深是開間的 %@ 倍，形如長巷，中段採光通風弱，陰陽氣流失衡。", ratioStr),
                    String(format: "Total depth is %@× the width, forming a long corridor-like footprint where middle zones may lack daylight and cross-ventilation.", ratioStr),
                    String(format: "奥行きが間口の%@倍あり、中間の採光・換気が弱まりやすい細長い形状です。", ratioStr),
                    String(format: "전체 깊이가 폭의 %@배에 달해 중간 구역의 채광과 통풍이 약해지기 쉬운 긴 구조입니다.", ratioStr),
                    String(format: "Chiều sâu gấp %@ lần chiều rộng, làm khu vực giữa nhà dễ thiếu ánh sáng tự nhiên và đối lưu không khí.", ratioStr),
                    String(format: "ความลึกของบ้านมากกว่าความกว้างถึง %@ เท่า ทำให้ช่วงกลางบ้านอาจรับแสงและระบายอากาศได้น้อย", ratioStr),
                    String(format: "Kedalaman rumah mencapai %@× lebarnya, sehingga bagian tengah cenderung kurang cahaya alami dan sirkulasi udara.", ratioStr)
                ),
                fengshuiLore: tr8(
                    "方正者气厚，狭长者气薄。",
                    "方正者氣厚，狹長者氣薄。",
                    "Square, balanced footprints hold qi steadily; overly narrow layouts benefit from zoned lighting and visual widening.",
                    "方正な間取りは気が充実しやすく、細長い空間は照明と分区で気を整えるのが吉とされます。",
                    "방정한 평면은 기운이 두텁게 모이고, 좁고 긴 구조는 조명과 공간 구획으로 기운을 보완하는 것이 좋습니다.",
                    "Nhà vuông vức thì khí dày, nhà quá hẹp dài cần bổ sung ánh sáng và phân vùng để giữ cân bằng âm dương.",
                    "ผังบ้านที่ได้สัดส่วนจะเก็บพลังชี่ได้ดี ส่วนผังที่แคบยาวควรเสริมแสงสว่างและการแบ่งโซนให้สมดุล",
                    "Denah yang proporsional menahan energi dengan stabil; ruang memanjang perlu didukung pencahayaan yang merata."
                ),
                solution: tr8(
                    "室内中部走道采用镜面扩容与明亮照明，多设绿植增补生旺之气。",
                    "室內中部走道採用鏡面擴容與明亮照明，多設綠植增補生旺之氣。",
                    "Use bright warm lighting, side mirrors to visually widen the middle corridor, and leafy plants to invigorate stagnant zones.",
                    "中央通路に明るい照明や壁面ミラーを用いて広がりを出し、観葉植物を配して生気を補ってください。",
                    "중간 복도에 밝은 조명과 벽면 거울로 공간감을 넓히고, 관엽식물을 배치해 생기를 보충하세요.",
                    "Tăng cường chiếu sáng ấm và gương trang trí dọc hành lang giữa để mở rộng không gian, kết hợp đặt cây xanh tăng sinh khí.",
                    "เพิ่มไฟส่องสว่างและกระจกเงาด้านข้างบริเวณโถงกลางเพื่อขยายมิติสายตา พร้อมวางต้นไม้เพิ่มความสดชื่น",
                    "Gunakan pencahayaan hangat yang terang, cermin samping untuk memperluas kesan ruang di tengah, serta tanaman hijau."
                ),
                coordinate: centroid
            ))
            score -= 6
        }


        // I. 进门见灶检测 (开门见灶·钱财多耗)
        let mainDoors = openings.filter { $0.type == .entranceDoor }
        for door in mainDoors {
            let dPos = SIMD2<Float>(door.posX, door.posZ)
            let dNorm = SIMD2<Float>(door.normalX, door.normalZ)
            for stove in stoves {
                let sPos = SIMD2<Float>(stove.posX, stove.posZ)
                let delta = sPos - dPos
                let dist = simd_length(delta)
                guard dist >= 1.2 && dist <= 7.0 else { continue }
                let ray = delta / dist
                let alignment = simd_dot(dNorm, ray)
                let lateral = dist * sqrt(max(0, 1.0 - alignment * alignment))
                if alignment >= 0.78 && lateral <= 1.1 {
                    let distStr = String(format: "%.1f", dist)
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "开门见灶 (入口视线提示)", "開門見灶 (入口視線提示)", "Entrance Facing Stove",
                            "開門見竈（玄関からコンロ直視）", "개문견조 (현관-가스레인지 직대)", "Khai Môn Kiến Táo (Mở Cửa Thấy Bếp)",
                            "เปิดประตูเห็นเตาไฟ", "Pintu Utama Menghadap Kompor"
                        ),
                        severity: .critical,
                        locationName: tr8(
                            "入户大门 ⟷ 厨灶", "入戶大門 ⟷ 廚灶", "Main Entrance ⟷ Stove",
                            "玄関ドア ⟷ コンロ", "현관문 ⟷ 조리대", "Cửa chính ⟷ Bếp nấu",
                            "ประตูหน้าบ้าน ⟷ เตาครัว", "Pintu Utama ⟷ Kompor"
                        ),
                        detail: tr8(
                            String(format: "《阳宅集成》原文有“开门见灶，钱财多耗”。入户门开启正对厨房炉灶（间距 %@ 米），古籍将其解释为财耗象征；请关注入口视线、热源距离、通风和防火安全。", distStr),
                            String(format: "《陽宅集成》原文有「開門見灶，錢財多耗」。入戶門開啟正對廚房爐灶（間距 %@ 米），古籍將其解釋為財耗象徵；請關注入口視線、熱源距離、通風和防火安全。", distStr),
                            String(format: "Yang Zhai Compendium notes: 'Seeing the stove upon opening the door scatters wealth.' The main entrance aligns directly with the kitchen stove (%@ m apart); check entry sightlines, drafts near the burner, ventilation, and fire safety.", distStr),
                            String(format: "『陽宅集成』に「門を開けて竈を見れば財を耗す」とあります。玄関の正面にキッチンコンロが位置（距離 %@m）するため、視線・換気・火気安全を確認してください。", distStr),
                            String(format: "《양택집성》에 ‘문을 열어 부엌 화덕이 보이면 재물이 소모된다’고 했습니다. 현관문이 주방 조리대와 정면으로 마주하므로(거리 %@m) 시선 차단과 환기·화기 안전을 점검하세요.", distStr),
                            String(format: "《Dương Trạch Tập Thành》 có câu: “Khai môn kiến táo, tiền tài đa hao”. Cửa chính mở ra nhìn thẳng vào bếp nấu (cách %@ m); nên lưu ý tầm nhìn, thông gió và an toàn nhiệt.", distStr),
                            String(format: "คัมภีร์《หยางไจ๋จี๋เฉิง》กล่าวว่า “เปิดประตูเห็นเตาไฟ ทรัพย์สินรั่วไหล” ประตูทางเข้าตรงกับเตาครัว (ห่าง %@ ม.) ควรตรวจเช็คแนวสายตา การระบายอากาศ และความปลอดภัยจากความร้อน", distStr),
                            String(format: "Kitab Yang Zhai mencatat bahwa pintu utama yang langsung menghadap kompor (jarak %@ m) kurang baik bagi penghimpunan rezeki; perhatikan garis pandang, ventilasi, dan keamanan api.", distStr)
                        ),
                        fengshuiLore: tr8(
                            "出处：《阳宅集成》。解释：原文中的“钱财多耗”是传统文化判断，实际财务事项不由空间测算决定。",
                            "出處：《陽宅集成》。解釋：原文中的「錢財多耗」是傳統文化判斷，實際財務事項不由空間測算決定。",
                            "Source: Yang Zhai Compendium. Traditional residential lore links an exposed stove at the entry to resource drain; evaluate alongside practical kitchen airflow and privacy.",
                            "出典：『陽宅集成』。玄関の気流が火口に直撃することを忌む伝統的解釈であり、実生活では防풍・視線配慮に当たります。",
                            "출전: 《양택집성》. 전통 양택론에서 화기 노출을 재물 소모의 상징으로 보며, 실제로는 현관 기류와 시선 차단을 뜻합니다.",
                            "Nguồn: 《Dương Trạch Tập Thành》. Quan niệm truyền thống kỵ gió cửa chính thổi thẳng vào bếp lửa làm tán khí.",
                            "ที่มา: 《หยางไจ๋จี๋เฉิง》 ตามธรรมเนียมโบราณถือว่าลมจากประตูหน้าไม่ควรพัดปะทะเตาไฟโดยตรง",
                            "Sumber: Yang Zhai Compendium. Tradisi feng shui menyarankan agar area memasak tidak langsung terekspos angin dan pandangan dari pintu depan."
                        ),
                        solution: tr8(
                            "在大门与厨房之间设置玄关柜或挂隔断门帘，平时厨房推拉门常闭以避穿冲。",
                            "在大門與廚房之間設置玄關櫃或掛隔斷門簾，平時廚房推拉門常閉以避穿衝。",
                            "Install a foyer cabinet or partition curtain between the entrance and kitchen, and keep the kitchen sliding door closed when not cooking.",
                            "玄関とキッチンの間に目隠し棚や暖簾を設け、普段はキッチンの引き戸を閉めて直衝を避けてください。",
                            "현관과 주방 사이에 파티션 수납장이나 가림 커튼을 설치하고, 평소 주방 슬라이딩 도어를 닫아두세요.",
                            "Đặt tủ huyền quan hoặc treo rèm ngăn giữa cửa chính và bếp, đồng thời đóng cửa trượt phòng bếp khi không nấu nướng.",
                            "ตั้งตู้กั้นทางเข้าหรือติดม่านบังสายตาระหว่างประตูหน้ากับห้องครัว และปิดประตูบานเลื่อนห้องครัวไว้เสมอ",
                            "Pasang kabinet foyer atau tirai penyekat antara pintu utama dan dapur, serta biasakan menutup pintu geser dapur."
                        ),
                        coordinate: door.position,
                        vectorEnd: stove.position
                    ))
                    score -= 10
                    break
                }
            }
        }

        // J. 开门见厕检测 (秽气迎门)
        let bathroomRooms = rooms.filter { $0.type == .bathroom }
        for door in mainDoors {
            let dPos = SIMD2<Float>(door.posX, door.posZ)
            let dNorm = SIMD2<Float>(door.normalX, door.normalZ)
            for bRoom in bathroomRooms {
                let bPos = SIMD2<Float>(bRoom.centerX, bRoom.centerZ)
                let delta = bPos - dPos
                let dist = simd_length(delta)
                guard dist >= 1.2 && dist <= 6.5 else { continue }
                let ray = delta / dist
                let alignment = simd_dot(dNorm, ray)
                let lateral = dist * sqrt(max(0, 1.0 - alignment * alignment))
                if alignment >= 0.80 && lateral <= 1.2 {
                    let distStr = String(format: "%.1f", dist)
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "开门见厕 (秽气迎门)", "開門見廁 (穢氣迎門)", "Entrance Facing Bathroom",
                            "開門見廁（玄関正面の浴室・トイレ）", "개문견측 (현관-화장실 직대)", "Khai Môn Kiến Xí (Mở Cửa Thấy Nhà Vệ Sinh)",
                            "เปิดประตูเห็นห้องน้ำ", "Pintu Utama Menghadap Kamar Mandi"
                        ),
                        severity: .warning,
                        locationName: tr8(
                            "入户大门 ⟷ 卫生间", "入戶大門 ⟷ 衛生間", "Main Entrance ⟷ Bathroom",
                            "玄関ドア ⟷ トイレ・浴室", "현관문 ⟷ 화장실", "Cửa chính ⟷ Nhà vệ sinh",
                            "ประตูหน้าบ้าน ⟷ ห้องน้ำ", "Pintu Utama ⟷ Kamar Mandi"
                        ),
                        detail: tr8(
                            String(format: "《八宅明镜》原文有“门为气口，厕乃浊泉；气口冲浊，福禄散亡”。大门入口正对卫生间（间距 %@ 米），古籍将其解释为秽气迎门象征；建议关注隐私、通风、异味控制和出入口动线。", distStr),
                            String(format: "《八宅明鏡》原文有「門為氣口，廁乃濁泉；氣口衝濁，福祿散亡」。大門入口正對衛生間（間距 %@ 米），古籍將其解釋為穢氣迎門象徵；建議關注隱私、通風、異味控制和出入口動線。", distStr),
                            String(format: "Eight Mansions Mirror states: 'The door is the qi mouth; when it faces turbid air, auspicious qi scatters.' The main entrance aligns with the bathroom (%@ m apart); check privacy, ventilation, and odor control.", distStr),
                            String(format: "『八宅明鏡』では玄関正面のトイレを忌みます。玄関とトイレが正対（距離 %@m）しているため、視線・換気・防臭対策を確認してください。", distStr),
                            String(format: "《팔택명경》에서 문은 기의 입구라 탁한 기운과 마주치는 것을 꺼립니다. 현관이 화장실과 정면으로 마주하므로(거리 %@m) 프라이버시와 환기·방취를 점검하세요.", distStr),
                            String(format: "《Bát Trạch Minh Kính》 viết: “Môn vi khí khẩu, xí nãi trọc tuyền”. Cửa chính đối diện nhà vệ sinh (cách %@ m); cần chú ý sự riêng tư, thông gió và khử mùi.", distStr),
                            String(format: "คัมภีร์《ปาไจ๋หมิงจิ้ง》กล่าวว่าประตูคือปากรับชี่ ไม่ควรปะทะห้องน้ำโดยตรง (ห่าง %@ ม.) ควรดูแลเรื่องความเป็นส่วนตัว การระบายอากาศ และการป้องกันกลิ่น", distStr),
                            String(format: "Kitab Ba Zhai Ming Jing mengingatkan agar pintu utama sebagai mulut qi tidak langsung menghadap kamar mandi (jarak %@ m); perhatikan privasi, ventilasi, dan kontrol kelembapan.", distStr)
                        ),
                        fengshuiLore: tr8(
                            "《八宅明镜》云：'门为气口，厕乃浊泉；气口冲浊，福禄散亡'。",
                            "《八宅明鏡》云：「門為氣口，廁乃濁泉；氣口衝濁，福祿散亡」。",
                            "Eight Mansions Mirror: 'The main door is the mouth of qi; keep turbid bathroom air from meeting incoming fresh qi.'",
                            "『八宅明鏡』「門は気口なり」。玄関から入る清気が水回りの湿気・臭気と直撃するのを避けます。",
                            "《팔택명경》 ‘문위기구 측내탁천’. 현관으로 들어오는 맑은 기운이 습기·탁기와 정면으로 부딪히는 것을 피합니다.",
                            "《Bát Trạch Minh Kính》: Cửa chính là nơi nạp thanh khí, kỵ đối diện trực tiếp với uế khí nhà vệ sinh.",
                            "《ปาไจ๋หมิงจิ้ง》ระบุว่าประตูหลักคือช่องรับพลังงานบริสุทธิ์ จึงไม่ควรปะทะกับความชื้นและกลิ่นจากห้องน้ำ",
                            "Ba Zhai Ming Jing menekankan bahwa pintu utama adalah jalur masuk energi segar sehingga tidak boleh langsung bertemu udara lembap kamar mandi."
                        ),
                        solution: tr8(
                            "卫生间门加装闭门器保持常闭，悬挂过膝半透布帘，门内放置水种阔叶绿植净化浊气。",
                            "衛生間門加裝閉門器保持常閉，懸掛過膝半透布簾，門內放置水種闊葉綠植淨化濁氣。",
                            "Keep the bathroom door closed with an auto-closer, hang a knee-length fabric curtain, and place a broadleaf plant inside to freshen the air.",
                            "トイレのドアを常時閉め、丈の長い暖簾を掛け、室内に観葉植物や換気設備を整えて空気を浄化してください。",
                            "화장실 문에 도어클로저를 달아 상시 닫아두고, 긴 가림 커튼과 공기정화 식물을 비치하세요.",
                            "Lắp tay co giữ cửa nhà vệ sinh luôn đóng, treo rèm vải dài qua gối và đặt cây lá rộng thủy sinh để thanh lọc không khí.",
                            "ติดโช้คปิดประตูห้องน้ำให้ปิดสนิทเสมอ แขวนม่านผ้าคลุมเข่า และวางต้นไม้ฟอกอากาศในห้องน้ำ",
                            "Pasang penutup pintu otomatis agar kamar mandi selalu tertutup, tambahkan tirai pintu, dan letakkan tanaman daun lebar penyerap lembap."
                        ),
                        coordinate: door.position,
                        vectorEnd: bRoom.center
                    ))
                    score -= 8
                    break
                }
            }
        }

        // K. 厨厕贴壁相克 (水火同壁)
        let kitchenRooms = rooms.filter { $0.type == .kitchen }
        for k in kitchenRooms {
            for b in bathroomRooms {
                let dist = simd_distance(SIMD2<Float>(k.centerX, k.centerZ), SIMD2<Float>(b.centerX, b.centerZ))
                let minAllowedDist = (k.sizeX + b.sizeX) * 0.45
                if dist <= minAllowedDist + 0.35 {
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "厨厕同壁 (水火相战)", "廚廁同壁 (水火相戰)", "Kitchen & Bathroom Shared Wall",
                            "厨廁同壁（水火の隣り合わせ）", "주측동벽 (주방·화장실 수화상전)", "Trù Xí Đồng Bích (Thủy Hỏa Xung Khắc)",
                            "ครัวและห้องน้ำใช้ผนังร่วมกัน (น้ำปะทะไฟ)", "Dapur & Kamar Mandi Berbagi Dinding"
                        ),
                        severity: .warning,
                        locationName: tr8(
                            "厨房 ⟷ 卫生间相隔", "廚房 ⟷ 衛生間相隔", "Kitchen ⟷ Bathroom Partition",
                            "キッチン ⟷ トイレ・浴室の隔壁", "주방 ⟷ 화장실 경계벽", "Vách ngăn Bếp ⟷ Nhà vệ sinh",
                            "ผนังกั้นห้องครัว ⟷ ห้องน้ำ", "Dinding Pembatas Dapur ⟷ Kamar Mandi"
                        ),
                        detail: tr8(
                            "《催官篇》原文有“水火不相容，宅母病腹痛”。厨房灶台与卫生间共用一面实体隔墙，按古籍象征会被解释为坎水逼近离火；请结合热源距离、通风、防水和使用安全复核。此处原文属于传统文化语境，不是医疗诊断。",
                            "《催官篇》原文有「水火不相容，宅母病腹痛」。廚房灶台與衛生間共用一面實體隔牆，按古籍象徵會被解釋為坎水逼近離火；請結合熱源距離、通風、防水和使用安全複核。此處原文屬於傳統文化語境，不是醫療診斷。",
                            "Cui Guan Pian notes: 'Water and Fire should not clash across the same wall.' The kitchen and bathroom share a partition wall, symbolizing Kan Water pressing Li Fire; verify waterproofing, plumbing lines, ventilation, and stove placement.",
                            "『催官篇』では水と火の隣接相克を戒めています。キッチンと浴室・トイレが隔壁を共有しているため、防水・配管・換気およびコンロ位置を確認してください。",
                            "《최관편》에서는 수기(화장실)와 화기(주방)가 한 벽을 사이에 두고 맞닿는 것을 경계합니다. 방수·배관·환기 및 조리대 위치를 점검하세요.",
                            "《Thôi Quan Biên》 nhắc nhở Thủy Hỏa không nên xung sát qua cùng một bức tường. Bếp và nhà vệ sinh chung vách ngăn; hãy kiểm tra chống thấm, đường ống, thông gió và vị trí đặt bếp.",
                            "คัมภีร์《ชุยกวานเพียน》กล่าวถึงพลังน้ำและไฟที่ไม่ควรปะทะกันผ่านผนังเดียว ห้องครัวและห้องน้ำใช้ผนังร่วมกัน ควรตรวจสอบระบบกันซึม ท่อน้ำ และการวางตำแหน่งเตา",
                            "Kitab Cui Guan Pian mengingatkan benturan unsur Air dan Api pada satu dinding. Dapur dan kamar mandi berbagi dinding pembatas; periksa lapisan kedap air, pipa, ventilasi, dan posisi kompor."
                        ),
                        fengshuiLore: tr8(
                            "出处：《催官篇》：“水火不相容，宅母病腹痛”。解释：原文把水火相逼与腹部不适作象征联系，属于传统堪舆文本，不是医疗判断。",
                            "出處：《催官篇》：「水火不相容，宅母病腹痛」。解釋：原文把水火相逼與腹部不適作象徵聯繫，屬於傳統堪輿文本，不是醫療判斷。",
                            "Source: Cui Guan Pian. Traditional Five-Element theory views stove Fire and bathroom Water backing onto the same wall as an elemental clash; Earth tones help mediate Fire and Water.",
                            "出典：『催官篇』。五行論では火（キッチン）と水（浴室）の直接対立を忌み、土気（ベージュ・黄系）で通関させます。",
                            "출전: 《최관편》. 오행상 화(주방)와 수(화장실)가 맞닿으면 수화상전이 되므로 토(土) 기운으로 중화하는 것을 권장합니다.",
                            "Nguồn: 《Thôi Quan Biên》. Theo Ngũ Hành, Hỏa của bếp và Thủy của phòng tắm tựa lưng vào cùng một vách nên dùng hành Thổ để thông quan.",
                            "ที่มา: 《ชุยกวานเพียน》 ตามหลักเบญจธาตุ ไฟของครัวและน้ำของห้องน้ำที่พิงผนังเดียวกันควรใช้ธาตุดินช่วยเชื่อมสมดุล",
                            "Sumber: Cui Guan Pian. Dalam teori Lima Elemen, Api dapur dan Air kamar mandi pada satu dinding dapat diseimbangkan dengan unsur Tanah."
                        ),
                        solution: tr8(
                            "灶台与马桶避免贴在同一面隔墙的正反两侧，墙面采用土黄色瓷砖以'土'通关化解。",
                            "灶台與馬桶避免貼在同一面隔牆的正反兩側，牆面採用土黃色瓷磚以「土」通關化解。",
                            "Avoid placing the stove and toilet directly back-to-back on the same wall, and use warm earth-toned tiles to bridge Fire and Water.",
                            "コンロと便器が同じ壁の表裏で重ならないように配置し、アースカラーのタイル等で「火生土・土克水」の調和を図ってください。",
                            "조리대와 변기가 같은 벽의 앞뒤에 맞닿지 않게 배치하고, 황토색·베이지 톤 타일로 수화 기운을 중화하세요.",
                            "Tránh đặt bếp nấu và bồn cầu tựa lưng trực tiếp vào hai mặt của cùng một bức tường; dùng gạch ốp màu vàng đất để thông quan Thủy Hỏa.",
                            "หลีกเลี่ยงการวางเตาไฟและโถสุขภัณฑ์พิงผนังด้านเดียวกันโดยตรง และใช้กระเบื้องโทนสีเอิร์ธโทนเพื่อเชื่อมสมดุลธาตุ",
                            "Hindari menempatkan kompor dan kloset saling membelakangi pada dinding yang sama, serta gunakan keramik bernuansa warna tanah (krem/kuning hangat)."
                        ),
                        coordinate: k.center,
                        vectorEnd: b.center
                    ))
                    score -= 6
                    break
                }
            }
        }

        // L. 床头悬空无靠 (无靠山煞)
        for bed in beds {
            let bPos = SIMD2<Float>(bed.posX, bed.posZ)
            var minDistToWall: Float = .greatestFiniteMagnitude
            for w in walls {
                let w1 = SIMD2<Float>(w.startX, w.startZ)
                let w2 = SIMD2<Float>(w.endX, w.endZ)
                let d = distancePointToSegment(point: bPos, segA: w1, segB: w2)
                minDistToWall = min(minDistToWall, d)
            }
            if minDistToWall > 1.35 {
                let wallDistStr = String(format: "%.1f", minDistToWall)
                shaItems.append(HouseSpatialShaItem(
                    title: tr8(
                        "床头悬空 (靠山虚浮)", "床頭懸空 (靠山虛浮)", "Unbacked Headboard (No Support)",
                        "床頭懸空（ベッドヘッドの壁離れ）", "침두현공 (침대 헤드 무벽)", "Đầu Giường Chơi Vơi (Thiếu Điểm Tựa)",
                        "หัวเตียงลอย (ไร้ผนังพิงหลัง)", "Kepala Ranjang Tanpa Sandaran Dinding"
                    ),
                    severity: .warning,
                    locationName: tr8(
                        "卧床周围空间", "臥床周圍空間", "Around Bed",
                        "ベッド周辺空間", "침대 주변 공간", "Không gian quanh giường",
                        "พื้นที่รอบเตียงนอน", "Area Sekitar Ranjang"
                    ),
                    detail: tr8(
                        String(format: "卧床四周远离实体承重墙 (最近墙体 %@ 米)，床头悬空无依，主睡眠不实、事业贵人缺乏。", wallDistStr),
                        String(format: "臥床四周遠離實體承重牆 (最近牆體 %@ 米)，床頭懸空無依，主睡眠不實、事業貴人缺乏。", wallDistStr),
                        String(format: "The bed is positioned far from any solid wall (nearest wall %@ m away), leaving the headboard unsupported and reducing the sense of security during sleep.", wallDistStr),
                        String(format: "ベッドが周囲の実壁から離れており（最短 %@m）、ヘッドボードの後ろが抜けて落ち着きにくい配置です。", wallDistStr),
                        String(format: "침대가 주변 실벽에서 떨어져 있어(최근접 벽체 %@m) 침대 머리가 허공에 떠 있으므로 수면 안정감이 떨어질 수 있습니다.", wallDistStr),
                        String(format: "Giường ngủ cách xa tường đặc (tường gần nhất %@ m), đầu giường chơi vơi thiếu điểm tựa khiến giấc ngủ kém sâu.", wallDistStr),
                        String(format: "เตียงนอนอยู่ห่างจากผนังทึบ (ผนังใกล้สุด %@ ม.) หัวเตียงไม่มีผนังพิงหลัง ทำให้ขาดความมั่นคงขณะพักผ่อน", wallDistStr),
                        String(format: "Ranjang berada jauh dari dinding masif (dinding terdekat %@ m), membuat kepala ranjang tanpa sandaran dan mengurangi rasa tenang saat tidur.", wallDistStr)
                    ),
                    fengshuiLore: tr8(
                        "《撼龙经》云：'人有靠则安，床有靠则稳'。床头紧贴实墙方有踏实依靠。",
                        "《撼龍經》云：「人有靠則安，床有靠則穩」。床頭緊貼實牆方有踏實依靠。",
                        "Classical lore: 'With a solid backing, rest is steady.' Placing the headboard flush against a solid wall provides acoustic and psychological stability.",
                        "『撼龍経』「人に靠あれば安し、床に靠あれば穏やかなり」。ベッド頭部は実壁につけるのが吉とされます。",
                        "《감룡경》 ‘인유고즉안 침유고즉온’. 침대 머리는 단단한 벽에 밀착해야 기운이 안정됩니다.",
                        "《Hám Long Kinh》: “Nhân hữu kháo tắc an, sàng hữu kháo tắc ổn”. Đầu giường tựa sát tường đặc mới tạo thế vững chãi.",
                        "《ฮั่นหลงจิง》กล่าวว่า “คนมีที่พึ่งจึงอุ่นใจ เตียงมีที่พิงจึงมั่นคง” หัวเตียงควรชิดผนังทึบ",
                        "Han Long Jing menyebutkan bahwa ranjang yang bersandar rapat pada dinding kokoh memberikan ketenangan dan dukungan energi yang stabil."
                    ),
                    solution: tr8(
                        "将床头移位紧贴实墙；若户型限制无法移位，可加装高大厚实的实木靠背板作人造靠山。",
                        "將床頭移位緊貼實牆；若戶型限制無法移位，可加裝高大厚實的實木靠背板作人造靠山。",
                        "Move the headboard flush against a solid wall; if the layout requires an island bed, anchor it with a tall, solid wood headboard or low storage console behind it.",
                        "ベッドヘッドを実壁につけるか、移動できない場合は背の高い木製ヘッドボードやローキャビネットを背後に設けてください。",
                        "침대 머리를 실벽에 붙이거나, 구조상 어렵다면 높고 두꺼운 원목 헤드보드나 낮은 수납장을 뒤에 배치해 의지처를 만드세요.",
                        "Kê sát đầu giường vào tường đặc; nếu không thể dịch chuyển, hãy lắp vách đầu giường gỗ cao dày hoặc tủ thấp phía sau làm điểm tựa.",
                        "เลื่อนหัวเตียงให้ชิดผนังทึบ หากย้ายไม่ได้แนะนำให้ใช้หัวเตียงไม้ทรงสูงที่แข็งแรงหรือวางตู้เตี้ยด้านหลังเป็นฉากพิง",
                        "Geser kepala ranjang agar menempel pada dinding masif, atau gunakan sandaran kepala kayu tebal/kabinet rendah di belakangnya."
                    ),
                    coordinate: bed.position
                ))
                score -= 7
                break
            }
        }

        // M. 暗室无窗 (孤阴重闭)
        let bedrooms = rooms.filter { $0.type == .masterBedroom || $0.type == .secondBedroom }
        let windows = openings.filter { $0.type == .window || $0.type == .balconyDoor }
        for br in bedrooms {
            let bPos = SIMD2<Float>(br.centerX, br.centerZ)
            var nearestWindowDist: Float = .greatestFiniteMagnitude
            for win in windows {
                let wPos = SIMD2<Float>(win.posX, win.posZ)
                nearestWindowDist = min(nearestWindowDist, simd_distance(bPos, wPos))
            }
            if nearestWindowDist > 4.5 && windows.count > 0 {
                let roomName = br.localizedName
                shaItems.append(HouseSpatialShaItem(
                    title: tr8(
                        "暗室无窗 (孤阴凝滞)", "暗室無窗 (孤陰凝滯)", "Windowless Room (Stagnant Yin)",
                        "暗室無窓（採光・換気の不足）", "암실무창 (채광·환기 부족)", "Phòng Tối Không Cửa Sổ (Cô Âm Ngưng Trệ)",
                        "ห้องมืดไร้หน้าต่าง (พลังหยินอับทึบ)", "Kamar Tanpa Jendela (Kurang Cahaya Alami)"
                    ),
                    severity: .warning,
                    locationName: roomName,
                    detail: tr8(
                        "卧室内缺乏采光外窗，自然光线与空气对流匮乏，久居阴气偏盛，易感神疲乏力。",
                        "臥室內缺乏採光外窗，自然光線與空氣對流匱乏，久居陰氣偏盛，易感神疲乏力。",
                        "This sleeping area lacks a direct exterior window, limiting natural daylight and fresh air circulation, which can lead to a stuffy, low-energy environment.",
                        "寝室に外窓がなく、自然採光と換気が不足しがちです。気が滞りやすいため照明と換気で陽気を補う必要があります。",
                        "침실에 외창이 부족해 자연 채광과 공기 순환이 원활하지 않으므로 실내 기운이 침체되기 쉽습니다.",
                        "Phòng ngủ thiếu cửa sổ đón nắng và đối lưu không khí tự nhiên, ở lâu dễ gây cảm giác bí bách, mệt mỏi.",
                        "ห้องนอนขาดหน้าต่างรับแสงธรรมชาติและการหมุนเวียนของอากาศ อาจทำให้รู้สึกอึดอัดและอ่อนเพลียได้ง่าย",
                        "Kamar tidur kurang memiliki jendela luar untuk cahaya alami dan sirkulasi udara segar sehingga ruangan terasa pengap."
                    ),
                    fengshuiLore: tr8(
                        "《疑龙经》云：'无窗则气闭，阴盛则阳衰'。起居之所当见曦光，阴阳交泰。",
                        "《疑龍經》云：「無窗則氣閉，陰盛則陽衰」。起居之所當見曦光，陰陽交泰。",
                        "Yi Long Jing: 'Without windows, qi closes in and Yin outweighs Yang.' Living spaces thrive on balanced daylight and fresh air.",
                        "『疑龍経』「窓無ければ気閉ざし、陰盛んなれば陽衰う」。居室には適度な陽光と通風が不可欠とされます。",
                        "《의룡경》 ‘무창즉기폐 음성즉양쇠’. 거처하는 방은 햇빛과 통풍이 조화를 이루어야 음양이 균형을 잡습니다.",
                        "《Nghi Long Kinh》: “Vô song tắc khí bế, âm thịnh tắc dương suy”. Nơi nghỉ ngơi cần ánh sáng và thông khí hài hòa.",
                        "《อี๋หลงจิง》กล่าวว่า “ไร้หน้าต่างชี่อับทึบ หยินมากเกินหยางอ่อนแรง” ห้องพักอาศัยควรได้รับแสงและอากาศที่สมดุล",
                        "Yi Long Jing menyatakan bahwa ruangan tanpa bukaan cahaya membuat udara tertutup dan mengurangi keseimbangan Yin-Yang."
                    ),
                    solution: tr8(
                        "房门上方加装透光玻璃气窗或百叶排风，室内增加全光谱暖白照明，摆放开光黄玉聚阳阵。",
                        "房門上方加裝透光玻璃氣窗或百葉排風，室內增加全光譜暖白照明，擺放開光黃玉聚陽陣。",
                        "Add a transom glass panel or louver vent above the door, use full-spectrum warm-white lighting, and ensure mechanical ventilation.",
                        "ドア上部に採光欄間や換気ルーバーを設け、フルスペクトラムの暖白色照明で陽気を補ってください。",
                        "방문 상단에 채광창이나 환기 루버를 설치하고, 전구색 풀스펙트럼 조명으로 양기를 보충하세요.",
                        "Lắp ô thoáng kính hoặc lam thông gió phía trên cửa, bổ sung đèn ánh sáng trắng ấm toàn phổ để tăng dương khí.",
                        "ติดตั้งช่องแสงกระจกหรือบานเกล็ดระบายอากาศเหนือประตู และเพิ่มไฟแสงขาวอมเหลืองเพื่อเสริมพลังหยาง",
                        "Tambahkan ventilasi kaca atau kisi udara di atas pintu, serta gunakan lampu warm-white spektrum penuh untuk menjaga kesegaran ruang."
                    ),
                    coordinate: br.center
                ))
                score -= 6
                break
            }
        }

        // N. 八宅吉凶宫位体检 (基于罗盘实测朝向)
        let facingGua = guaForAngle(compassHeading)
        let sittingAngle = (compassHeading + 180.0).truncatingRemainder(dividingBy: 360.0)
        let sittingGua = guaForAngle(sittingAngle)
        let bazhai = BaZhaiEngine.shared.analyze(sittingPalace: sittingGua, facingPalace: facingGua)

        for room in rooms {
            let relX = room.centerX - cx
            let relZ = room.centerZ - cz
            let angleFromCenterRad = atan2(Double(relX), Double(-relZ))
            let angleFromCenterDeg = (angleFromCenterRad * 180.0 / Double.pi + 360.0).truncatingRemainder(dividingBy: 360.0)
            let geoAngle = (angleFromCenterDeg + compassHeading).truncatingRemainder(dividingBy: 360.0)
            let roomGua = guaForAngle(geoAngle)

            if let item = bazhai.items.first(where: { $0.guaName == roomGua }) {
                let rName = room.localizedName
                let starName = item.star.localizedName
                if room.type == .bathroom && (item.star == .shengQi || item.star == .yanNian || item.star == .tianYi) {
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "吉位落水 (污秽吉星)", "吉位落水 (污穢吉星)", "Bathroom in Auspicious Sector",
                            "吉位落水（吉方位の水回り）", "길위낙수 (길방에 위치한 화장실)", "Cát Vị Lạc Thủy (Phòng Tắm Ở Cung Cát)",
                            "ตำแหน่งมงคลตกน้ำ (ห้องน้ำทับทิศมงคล)", "Kamar Mandi di Sektor Mujur"
                        ),
                        severity: .critical,
                        locationName: tr8(
                            "\(rName) · 落于【\(starName)】大吉方",
                            "\(rName) · 落於【\(starName)】大吉方",
                            "\(rName) · in [\(starName)] Auspicious Sector",
                            "\(rName)・【\(starName)】吉方位",
                            "\(rName) · 【\(starName)】 대길방",
                            "\(rName) · thuộc cung đại cát 【\(starName)】",
                            "\(rName) · ทับทิศมงคล【\(starName)】",
                            "\(rName) · di Sektor Mujur [\(starName)]"
                        ),
                        detail: tr8(
                            String(format: "卫生间落在全屋八宅【%@】方位，属于传统文化中的布局提示，请结合实际防水、通风和使用情况复核。", starName),
                            String(format: "衛生間落在全屋八宅【%@】方位，屬於傳統文化中的佈局提示，請結合實際防水、通風和使用情況複核。", starName),
                            String(format: "The bathroom sits in the house's Eight Mansions [%@] auspicious sector; keep the space dry, clean, and well-ventilated.", starName),
                            String(format: "トイレ・浴室が八宅の【%@】吉方位に位置しています。防水・換気・清潔を保って吉気の損耗を防いでください。", starName),
                            String(format: "화장실이 팔택 【%@】 길방에 위치해 있습니다. 습기와 냄새가 차지 않도록 환기와 청결을 유지하세요.", starName),
                            String(format: "Nhà vệ sinh nằm tại cung cát 【%@】 theo Bát Trạch; cần giữ khô ráo, thông thoáng để tránh làm suy giảm cát khí.", starName),
                            String(format: "ห้องน้ำตั้งอยู่ในทิศมงคล【%@】ตามหลักปาไจ๋ ควรรักษาความสะอาดและระบายความชื้นอยู่เสมอ", starName),
                            String(format: "Kamar mandi berada di sektor baik [%@] Ba Zhai; jaga kebersihan, kekeringan, dan sirkulasi udara agar energi tetap harmonis.", starName)
                        ),
                        fengshuiLore: tr8(
                            "《八宅明镜》云：'吉星落厕，吉亦成殃'。生气延年宜作卧房书斋，不宜落水。",
                            "《八宅明鏡》云：「吉星落廁，吉亦成殃」。生氣延年宜作臥房書齋，不宜落水。",
                            "Eight Mansions Mirror recommends reserving Sheng Qi, Yan Nian, and Tian Yi sectors for bedrooms or studies rather than wet areas.",
                            "『八宅明鏡』では生気・延年・天医の三吉方は寝室や書斎に適し、水回りになる場合は浄化が必要と説きます。",
                            "《팔택명경》에서는 생기·연년·천의 삼길방에 화장실이 오면 목(木) 기운의 식물로 수기를 흡수해 정화하라고 권합니다.",
                            "《Bát Trạch Minh Kính》 khuyên các cung Sinh Khí, Diên Niên, Thiên Y nên ưu tiên làm phòng ngủ hoặc phòng đọc sách.",
                            "《ปาไจ๋หมิงจิ้ง》ระบุว่าทิศเซิงชี่ เหยียนเหนียน และเทียนอี เหมาะสำหรับห้องนอนหรือห้องทำงานมากกว่าห้องน้ำ",
                            "Ba Zhai Ming Jing menganjurkan sektor Sheng Qi, Yan Nian, dan Tian Yi untuk ruang tidur atau kerja; jika ditempati kamar mandi, perlu dijaga tetap kering."
                        ),
                        solution: tr8(
                            "卫生间马桶上方摆放一盆金边虎尾兰以木吸水，挂置开光纯铜葫芦收敛秽气护持吉星。",
                            "衛生間馬桶上方擺放一盆金邊虎尾蘭以木吸水，掛置開光純銅葫蘆收斂穢氣護持吉星。",
                            "Place a snake plant (Wood absorbs Water) in the bathroom, keep the lid and door closed, and hang a brass gourd to preserve auspicious qi.",
                            "トイレ内にサンスベリア等の観葉植物（木気で水気を吸う）を置き、銅瓢箪を掛けて吉気を護持してください。",
                            "화장실 안에 산세베리아 화분(목기로 수기 흡수)을 두고, 동호리병을 걸어 탁기를 거두고 길성을 보호하세요.",
                            "Đặt chậu lưỡi hổ (Mộc hút Thủy) trong nhà vệ sinh và treo hồ lô đồng để thu nạp uế khí, bảo hộ cát tinh.",
                            "วางต้นลิ้นมังกรในห้องน้ำเพื่อใช้ธาตุไม้ดูดซับความชื้น และแขวนน้ำเต้าทองเหลืองเพื่อรักษาพลังงานมงคล",
                            "Letakkan tanaman lidah mertua (unsur Kayu menyerap Air) di kamar mandi dan gantung labu tembaga untuk menjaga energi baik."
                        ),
                        coordinate: room.center
                    ))
                    score -= 12
                } else if (room.type == .masterBedroom || room.type == .secondBedroom) && (item.star == .tianYi || item.star == .yanNian || item.star == .shengQi) {
                    shaItems.append(HouseSpatialShaItem(
                        title: tr8(
                            "卧房得位 (吉星拱照)", "臥房得位 (吉星拱照)", "Bedroom in Auspicious Sector",
                            "臥房得位（吉星方位の寝室）", "침실득위 (길성 방위 안착)", "Phòng Ngủ Đắc Vị (Cát Tinh Chiếu)",
                            "ห้องนอนถูกโฉลก (ดาวมงคลหนุนนำ)", "Kamar Tidur di Sektor Mujur"
                        ),
                        severity: .auspicious,
                        locationName: tr8(
                            "\(rName) · 居【\(starName)】方",
                            "\(rName) · 居【\(starName)】方",
                            "\(rName) · in [\(starName)] Sector",
                            "\(rName)・【\(starName)】方位",
                            "\(rName) · 【\(starName)】 방위",
                            "\(rName) · tại cung 【\(starName)】",
                            "\(rName) · อยู่ในทิศ【\(starName)】",
                            "\(rName) · di Sektor [\(starName)]"
                        ),
                        detail: tr8(
                            String(format: "卧房安于全屋八宅【%@】吉位，居之安稳祥和、身心康泰、纳吉迎祥。", starName),
                            String(format: "臥房安於全屋八宅【%@】吉位，居之安穩祥和、身心康泰、納吉迎祥。", starName),
                            String(format: "The bedroom is situated in the house's Eight Mansions [%@] auspicious sector, supporting restful sleep, harmony, and vitality.", starName),
                            String(format: "寝室が八宅の【%@】吉方位に位置しており、心身の安定と家庭の和合に恵まれやすい好配置です。", starName),
                            String(format: "침실이 팔택 【%@】 길위에 자리하여 심신의 안정과 화목한 기운을 받는 좋은 배치입니다.", starName),
                            String(format: "Phòng ngủ tọa tại cung cát 【%@】 theo Bát Trạch, hỗ trợ giấc ngủ an ổn, sức khỏe và hòa khí gia đình.", starName),
                            String(format: "ห้องนอนตั้งอยู่ในทิศมงคล【%@】ตามหลักปาไจ๋ ส่งเสริมการพักผ่อนที่ราบรื่น สุขภาพแข็งแรง และความอบอุ่นในครอบครัว", starName),
                            String(format: "Kamar tidur terletak di sektor baik [%@] Ba Zhai, mendukung istirahat berkualitas, kesehatan, dan keharmonisan rumah.", starName)
                        ),
                        fengshuiLore: tr8(
                            "《阳宅三要》云：'门主灶配，吉星得位，富贵双全'。",
                            "《陽宅三要》云：「門主灶配，吉星得位，富貴雙全」。",
                            "Three Essentials of Yang Zhai: 'When the main room aligns with an auspicious star, peace and prosperity follow.'",
                            "『陽宅三要』「門・主・竈が調和し、吉星が位を得れば福寿具わる」。",
                            "《양택삼요》 ‘문·주·조가 조화를 이루고 길성이 제자리를 얻으면 복록이 따른다’고 했습니다.",
                            "《Dương Trạch Tam Yếu》: “Môn Chủ Táo phối, cát tinh đắc vị, phú quý song toàn”.",
                            "《หยางไจ๋ซานเย่า》กล่าวว่าเมื่อห้องหลักอยู่ในทิศดาวมงคล ย่อมส่งเสริมความเจริญรุ่งเรืองและความร่มเย็น",
                            "Yang Zhai San Yao menyatakan bahwa ketika kamar utama menempati bintang baik, ketenangan dan keberuntungan keluarga akan terjaga."
                        ),
                        solution: tr8(
                            "吉位得宜，床头朝向顺合吉方，保持室内整洁明亮即可长保吉运。",
                            "吉位得宜，床頭朝向順合吉方，保持室內整潔明亮即可長保吉運。",
                            "Maintain this favorable placement, align the headboard toward a supportive direction, and keep the room bright and uncluttered.",
                            "この良配置を活かし、ベッド頭部を吉方に向け、室内を明るく清潔に保ってください。",
                            "현재의 좋은 배치를 유지하고 침대 머리를 길방으로 맞추며 실내를 밝고 정결하게 관리하세요.",
                            "Giữ nguyên bố cục tốt này, hướng đầu giường thuận theo phương cát và giữ phòng luôn sáng sủa, gọn gàng.",
                            "รักษาการจัดวางที่ดีนี้ไว้ หันหัวเตียงไปทางทิศมงคล และดูแลห้องให้โปร่งโล่งสะอาดตาเสมอ",
                            "Pertahankan tata letak yang baik ini, arahkan kepala ranjang ke arah baik, dan jaga kamar tetap rapi serta terang."
                        ),
                        coordinate: room.center
                    ))
                    score += 5
                }
            }
        }

        // O. 三元九运玄空飞星理气体检 (形理兼备)
        let facingMountainItem = Mountain24Data.shared.mountain(for: compassHeading)
        let sittingMountainItem = Mountain24Data.shared.mountain(for: sittingAngle)
        let xkChart = FlyingStarsEngine.shared.calculateChart(sitting: sittingMountainItem, facing: facingMountainItem)
        let curPeriod = xkChart.period

        for palace in xkChart.palaces {
            guard !palace.isCenter else { continue }
            let pGua = palace.guaName
            let pName = palace.localizedPalaceName

            // 1. 五黄大煞 (5) 临门或临床
            if palace.facingStar == 5 || palace.mountainStar == 5 {
                for door in mainDoors {
                    let dRelX = door.posX - cx
                    let dRelZ = door.posZ - cz
                    let dAngle = (atan2(Double(dRelX), Double(-dRelZ)) * 180.0 / Double.pi + compassHeading + 360.0).truncatingRemainder(dividingBy: 360.0)
                    if guaForAngle(dAngle) == pGua {
                        shaItems.append(HouseSpatialShaItem(
                            title: tr8(
                                "玄空理气煞 · 五黄到门", "玄空理氣煞 · 五黃到門", "Xuan Kong · 5-Yellow at Entrance",
                                "玄空理気殺・五黄到門", "현공이기살 · 오황도문", "Huyền Không Lý Khí · Ngũ Hoàng Đáo Môn",
                                "ดาวเหินเสวียนคง · เบญจเหลืองทับประตูหน้า", "Xuan Kong · 5-Kuning di Pintu Utama"
                            ),
                            severity: .critical,
                            locationName: tr8(
                                "入户大门 · 逢【五黄大煞】", "入戶大門 · 逢【五黃大煞】", "Main Entrance · [5-Yellow Sha]",
                                "玄関ドア・【五黄大殺】", "현관문 · 【오황대살】", "Cửa chính · Gặp 【Ngũ Hoàng Đại Sát】",
                                "ประตูหน้าบ้าน · พบ【ดาว 5 เหลือง】", "Pintu Utama · [5-Kuning]"
                            ),
                            detail: tr8(
                                String(format: "玄空飞星五黄廉贞大煞飞临大门%@宫 (山向 %d-%d)，门动则煞动，易招滞涩阻碍。", pName, palace.mountainStar, palace.facingStar),
                                String(format: "玄空飛星五黃廉貞大煞飛臨大門%@宮 (山向 %d-%d)，門動則煞動，易招滯澀阻礙。", pName, palace.mountainStar, palace.facingStar),
                                String(format: "Flying Star 5-Yellow lands in the %@ palace at the main entrance (Mountain-Facing %d-%d); frequent door movement can stir Earth sha unless neutralized with Metal.", pName, palace.mountainStar, palace.facingStar),
                                String(format: "玄空飛星の五黄廉貞星が玄関の%@宮（山向 %d-%d）に飛臨しています。金気の化殺物で土殺を洩らすのが吉です。", pName, palace.mountainStar, palace.facingStar),
                                String(format: "현공비성 오황염정성이 현관 %@궁(산향 %d-%d)에 비림했습니다. 출입이 잦은 곳이므로 금(金) 기운으로 토살을 설기해야 합니다.", pName, palace.mountainStar, palace.facingStar),
                                String(format: "Sao Ngũ Hoàng Liêm Trinh bay đến cung %@ tại cửa chính (Sơn-Hướng %d-%d); cửa đóng mở thường xuyên nên cần dùng hành Kim để tiết giảm Thổ sát.", pName, palace.mountainStar, palace.facingStar),
                                String(format: "ดาว 5 เหลืองเหินลงเรือน%@ บริเวณประตูทางเข้า (ดาวภูเขา-ดาวหัน %d-%d) ควรใช้ธาตุทองช่วยสลายพลังดิน", pName, palace.mountainStar, palace.facingStar),
                                String(format: "Bintang Terbang 5-Kuning berada di sektor %@ pada pintu utama (Gunung-Hadap %d-%d); gunakan unsur Logam untuk meredam energi Tanah.", pName, palace.mountainStar, palace.facingStar)
                            ),
                            fengshuiLore: tr8(
                                "《玄空秘旨》云：'五黄为毒药，动则招灾'。五黄到门宜化不宜克。",
                                "《玄空秘旨》云：「五黃為毒藥，動則招災」。五黃到門宜化不宜克。",
                                "Xuan Kong Secrets: '5-Yellow prefers calm and Metal drainage rather than Fire or loud renovation.'",
                                "『玄空秘旨』では五黄土星は動かせば凶意が強まるため、剋すのではなく金気で化泄するのを原則とします。",
                                "《현공비지》에서 오황토성은 극하기보다 금(金) 기운으로 부드럽게 설기(화살)하는 것이 원칙입니다.",
                                "《Huyền Không Bí Chỉ》: Ngũ Hoàng thuộc Thổ, đến cửa nên dùng Kim để hóa giải chứ không nên khắc.",
                                "《เสวียนคงมี่จื่อ》ระบุว่าดาว 5 เหลืองเป็นธาตุดิน เมื่อทับประตูควรใช้ธาตุทองสลายพลัง ไม่ควรใช้สีแดงกระตุ้น",
                                "Xuan Kong Mi Zhi mengajarkan bahwa bintang 5-Kuning (Tanah) di pintu masuk sebaiknya diredam dengan Logam dan hindari warna merah."
                            ),
                            solution: tr8(
                                "玄关处悬挂纯铜六字真言风铃或安忍水，以六白金气泄化五黄土煞，忌铺红地毯。",
                                "玄關處懸掛純銅六字真言風鈴或安忍水，以六白金氣洩化五黃土煞，忌鋪紅地毯。",
                                "Place a brass windchime, Six-Emperor coins, or an Anren salt-water cure at the foyer to drain 5-Yellow Earth with Metal; avoid red doormats.",
                                "玄関に真鍮風鈴・六帝銭・安忍水（塩水銅貨）を置いて金気で五黄の土気を洩らし、赤いマットは避けてください。",
                                "현관에 순동 풍경이나 육제전·안인수를 두어 금 기운으로 오황토살을 설기하고, 붉은색 매트는 피하세요.",
                                "Treo chuông gió đồng, tiền Lục Đế hoặc đặt bình An Nhẫn Thủy ở huyền quan để dùng Kim tiết Thổ; tránh trải thảm đỏ.",
                                "แขวนกระดิ่งลมทองเหลือง เหรียญหกจักรพรรดิ หรือวางโถน้ำเกลืออันเหรินสุ่ยบริเวณทางเข้า และหลีกเลี่ยงพรมสีแดง",
                                "Gantung lonceng angin kuningan, Koin Enam Kaisar, atau letakkan Anren Shui di foyer untuk meredam unsur Tanah, serta hindari keset merah."
                            ),
                            coordinate: door.position
                        ))
                        score -= 15
                        break
                    }
                }

                for bed in beds {
                    let bRelX = bed.posX - cx
                    let bRelZ = bed.posZ - cz
                    let bAngle = (atan2(Double(bRelX), Double(-bRelZ)) * 180.0 / Double.pi + compassHeading + 360.0).truncatingRemainder(dividingBy: 360.0)
                    if guaForAngle(bAngle) == pGua {
                        shaItems.append(HouseSpatialShaItem(
                            title: tr8(
                                "玄空理气煞 · 五黄加枕", "玄空理氣煞 · 五黃加枕", "Xuan Kong · 5-Yellow at Bed",
                                "玄空理気殺・五黄加枕", "현공이기살 · 오황가침", "Huyền Không Lý Khí · Ngũ Hoàng Lâm Giường",
                                "ดาวเหินเสวียนคง · เบญจเหลืองทับตำแหน่งเตียง", "Xuan Kong · 5-Kuning di Area Ranjang"
                            ),
                            severity: .critical,
                            locationName: tr8(
                                "卧床枕位 · 逢【五黄星】", "臥床枕位 · 逢【五黃星】", "Bed Position · [5-Yellow Star]",
                                "ベッド位置・【五黄星】", "침대 위치 · 【오황성】", "Vị trí giường · Gặp 【Sao Ngũ Hoàng】",
                                "ตำแหน่งเตียงนอน · พบ【ดาว 5 เหลือง】", "Posisi Ranjang · [Bintang 5-Kuning]"
                            ),
                            detail: tr8(
                                String(format: "《紫白诀》原文有“五黄重叠，灾疾并临”。卧床枕位位于玄空五黄星飞临之%@宫，古籍将其解释为灾疾象征，请结合通风、噪音和动线复核。", pName),
                                String(format: "《紫白訣》原文有「五黃重疊，災疾並臨」。臥床枕位位於玄空五黃星飛臨之%@宮，古籍將其解釋為災疾象徵，請結合通風、噪音和動線複核。", pName),
                                String(format: "Purple-White Scroll notes that 5-Yellow in the sleeping sector (%@ palace) calls for stillness and Metal remedies; check bedroom ventilation and noise as well.", pName),
                                String(format: "『紫白訣』に基づき、ベッドが玄空五黄星の飛臨する%@宮にあります。静穏を保ち、銅製アイテムで土気を和らげてください。", pName),
                                String(format: "《자백결》에 따라 침대가 현공 오황성이 비림한 %@궁에 위치합니다. 주변을 정결히 하고 순동 소품으로 토살을 완화하세요.", pName),
                                String(format: "Theo 《Tử Bạch Quyết》, vị trí giường ngủ nằm tại cung %@ có sao Ngũ Hoàng bay đến; nên giữ yên tĩnh và dùng vật phẩm đồng để hóa giải.", pName),
                                String(format: "ตามคัมภีร์《จื่อไป๋เจวี๋ย》ตำแหน่งเตียงนอนอยู่ในเรือน%@ ที่มีดาว 5 เหลืองเหินลง แนะนำให้จัดพื้นที่ให้สงบและตั้งน้ำเต้าทองเหลือง", pName),
                                String(format: "Menurut Zi Bai Jue, posisi ranjang berada di sektor %@ yang ditempati bintang 5-Kuning; jaga ketenangan kamar dan tambahkan ornamen kuningan.", pName)
                            ),
                            fengshuiLore: tr8(
                                "出处：《紫白诀》。解释：此处展示古籍原句及其传统含义，不构成健康诊断。",
                                "出處：《紫白訣》。解釋：此處展示古籍原句及其傳統含義，不構成健康診斷。",
                                "Source: Purple-White Scroll (Zi Bai Jue). Traditional Xuan Kong star symbolism for spatial reference.",
                                "出典：『紫白訣』。伝統的な玄空飛星の象意に基づく空間参考です。",
                                "출전: 《자백결》. 전통 현공비성의 상징 해석을 바탕으로 한 공간 참고 안내입니다.",
                                "Nguồn: 《Tử Bạch Quyết》. Biểu trưng truyền thống của Cửu Tinh Huyền Không.",
                                "ที่มา: 《จื่อไป๋เจวี๋ย》 คำอธิบายตามหลักดาวเหินเสวียนคงแบบดั้งเดิม",
                                "Sumber: Zi Bai Jue. Interpretasi simbolis Bintang Terbang Xuan Kong tradisional."
                            ),
                            solution: tr8(
                                "床位微调避开五黄正对方位，床头柜放置天然纯铜葫芦化解土煞。",
                                "床位微調避開五黃正對方位，床頭櫃放置天然純銅葫蘆化解土煞。",
                                "Shift the bed slightly out of the 5-Yellow sector if possible, and place a solid brass gourd on the nightstand.",
                                "可能であればベッド位置を少しずらし、ナイトテーブルに純銅製の瓢箪を置いて土気を洩らしてください。",
                                "가능하면 침대 위치를 약간 조정하고, 협탁 위에 순동 호리병을 두어 토살을 설기하세요.",
                                "Dịch nhẹ vị trí giường khỏi góc Ngũ Hoàng nếu có thể, và đặt hồ lô đồng nguyên chất trên tủ đầu giường.",
                                "ขยับตำแหน่งเตียงเลี่ยงมุมดาว 5 เหลืองเล็กน้อย และวางน้ำเต้าทองเหลืองไว้ที่โต๊ะข้างเตียง",
                                "Geser sedikit posisi ranjang jika memungkinkan, dan letakkan labu kuningan di meja samping tempat tidur."
                            ),
                            coordinate: bed.position
                        ))
                        score -= 12
                        break
                    }
                }
            }

            // 2. 二黑病符星 (2) 临卧房
            if palace.mountainStar == 2 || palace.facingStar == 2 {
                for br in bedrooms {
                    let brRelX = br.centerX - cx
                    let brRelZ = br.centerZ - cz
                    let brAngle = (atan2(Double(brRelX), Double(-brRelZ)) * 180.0 / Double.pi + compassHeading + 360.0).truncatingRemainder(dividingBy: 360.0)
                    if guaForAngle(brAngle) == pGua {
                        let roomName = br.localizedName
                        shaItems.append(HouseSpatialShaItem(
                            title: tr8(
                                "玄空理气参考 · 二黑星临卧", "玄空理氣參考 · 二黑星臨臥", "Xuan Kong · 2-Black in Bedroom",
                                "玄空理気参考・二黒星臨臥", "현공이기 참고 · 이흑성 침실 비림", "Huyền Không Lý Khí · Nhị Hắc Lâm Phòng Ngủ",
                                "ดาวเหินเสวียนคง · ดาว 2 ดำในห้องนอน", "Xuan Kong · 2-Hitam di Kamar Tidur"
                            ),
                            severity: .warning,
                            locationName: tr8(
                                "\(roomName) · 逢【二黑病符】", "\(roomName) · 逢【二黑病符】", "\(roomName) · [2-Black Star]",
                                "\(roomName)・【二黒巨門星】", "\(roomName) · 【이흑거문성】", "\(roomName) · Gặp 【Sao Nhị Hắc】",
                                "\(roomName) · พบ【ดาว 2 ดำ】", "\(roomName) · [Bintang 2-Hitam]"
                            ),
                            detail: tr8(
                                String(format: "《飞星赋》原文有“二黑逢五，病生胸腹”。%@坐落于二黑巨门星飞临之%@宫（山向 %d-%d），古籍将其解释为病符象征，请结合通风、采光、噪音和使用情况复核。", roomName, pName, palace.mountainStar, palace.facingStar),
                                String(format: "《飛星賦》原文有「二黑逢五，病生胸腹」。%@坐落於二黑巨門星飛臨之%@宮（山向 %d-%d），古籍將其解釋為病符象徵，請結合通風、採光、噪音和使用情況複核。", roomName, pName, palace.mountainStar, palace.facingStar),
                                String(format: "Flying Star Ode notes that %@ lies in the %@ palace visited by Star 2-Black (Mountain-Facing %d-%d); keep the room well-ventilated, sunlit, and balanced with Metal accents.", roomName, pName, palace.mountainStar, palace.facingStar),
                                String(format: "『飛星賦』に基づき、%@が二黒巨門星の飛臨する%@宮（山向 %d-%d）にあります。換気・採光を良くし、銅製品や瓢箪で土気を和らげてください。", roomName, pName, palace.mountainStar, palace.facingStar),
                                String(format: "《비성부》에 따라 %@이(가) 이흑거문성이 비림한 %@궁(산향 %d-%d)에 자리합니다. 통풍과 채광을 유지하고 동제품이나 호리병으로 토기를 설기하세요.", roomName, pName, palace.mountainStar, palace.facingStar),
                                String(format: "Theo 《Phi Tinh Phú》, %@ nằm tại cung %@ có sao Nhị Hắc Cự Môn bay đến (Sơn-Hướng %d-%d); nên giữ phòng thông thoáng và treo hồ lô hoặc tiền Lục Đế.", roomName, pName, palace.mountainStar, palace.facingStar),
                                String(format: "ตามคัมภีร์《เฟยซิงฟู่》 %@ตั้งอยู่ในเรือน%@ ที่มีดาว 2 ดำเหินลง (ดาวภูเขา-ดาวหัน %d-%d) ควรดูแลการระบายอากาศและแขวนน้ำเต้าหรือเหรียญหกจักรพรรดิ", roomName, pName, palace.mountainStar, palace.facingStar),
                                String(format: "Menurut Fei Xing Fu, %@ berada di sektor %@ yang disinggahi bintang 2-Hitam (Gunung-Hadap %d-%d); jaga sirkulasi udara dan tambahkan labu kering atau enam koin logam.", roomName, pName, palace.mountainStar, palace.facingStar)
                            ),
                            fengshuiLore: tr8(
                                "出处：《飞星赋》。解释：展示二黑星的古籍象征，不构成健康诊断。",
                                "出處：《飛星賦》。解釋：展示二黑星的古籍象徵，不構成健康診斷。",
                                "Source: Flying Star Ode (Fei Xing Fu). Traditional Xuan Kong symbolism for Star 2-Black.",
                                "出典：『飛星賦』。二黒土星に関する伝統的な玄空飛星の象意です。",
                                "출전: 《비성부》. 이흑토성에 관한 전통 현공비성의 상징 해석입니다.",
                                "Nguồn: 《Phi Tinh Phú》. Biểu trưng truyền thống của sao Nhị Hắc Thổ.",
                                "ที่มา: 《เฟยซิงฟู่》 ความหมายเชิงสัญลักษณ์ของดาว 2 ดำตามตำราเสวียนคง",
                                "Sumber: Fei Xing Fu. Makna simbolis bintang 2-Hitam dalam tradisi Xuan Kong."
                            ),
                            solution: tr8(
                                "卧房悬挂天然开光晒干葫芦或六帝钱以金泄土，室内避免大红厚毯。",
                                "臥房懸掛天然開光曬乾葫蘆或六帝錢以金洩土，室內避免大紅厚毯。",
                                "Hang a natural dried gourd or Six-Emperor coins in the bedroom to drain Earth with Metal, and avoid heavy red carpets.",
                                "寝室に天然の乾燥瓢箪や六帝銭を掛けて金気で土気を洩らし、真っ赤な厚手ラグは避けてください。",
                                "침실에 천연 박(호리병)이나 육제전을 걸어 금 기운으로 토기를 설기하고, 붉은색 두꺼운 카펫은 피하세요.",
                                "Treo hồ lô tự nhiên phơi khô hoặc tiền Lục Đế trong phòng ngủ để dùng Kim tiết Thổ, tránh trải thảm đỏ dày.",
                                "แขวนน้ำเต้าธรรมชาติหรือเหรียญหกจักรพรรดิในห้องนอนเพื่อสลายพลังดิน และหลีกเลี่ยงพรมสีแดงจัด",
                                "Gantung labu kering alami atau Koin Enam Kaisar di kamar tidur untuk meredam unsur Tanah, serta hindari karpet merah tebal."
                            ),
                            coordinate: br.center
                        ))
                        score -= 8
                        break
                    }
                }
            }

            // 3. 当令旺星纳气 (9运向星飞临大门)
            if palace.facingStar == curPeriod {
                for door in mainDoors {
                    let dRelX = door.posX - cx
                    let dRelZ = door.posZ - cz
                    let dAngle = (atan2(Double(dRelX), Double(-dRelZ)) * 180.0 / Double.pi + compassHeading + 360.0).truncatingRemainder(dividingBy: 360.0)
                    if guaForAngle(dAngle) == pGua {
                        shaItems.append(HouseSpatialShaItem(
                            title: tr8(
                                "玄空旺星纳气 (空间参考)", "玄空旺星納氣 (空間參考)", "Xuan Kong · Timely Prosperous Star at Door",
                                "玄空旺星納気（当旺向星の玄関）", "현공왕성납기 (당왕향성 현관 비림)", "Huyền Không Vượng Tinh Nạp Khí",
                                "ดาวเจริญยุคเหินลงประตูหน้า (รับชี่มงคล)", "Xuan Kong · Bintang Makmur di Pintu Utama"
                            ),
                            severity: .auspicious,
                            locationName: tr8(
                                "入户大门 · 逢【当旺向星】", "入戶大門 · 逢【當旺向星】", "Main Entrance · [Timely Facing Star]",
                                "玄関ドア・【当旺向星】", "현관문 · 【당왕향성】", "Cửa chính · Gặp 【Đương Vượng Hướng Tinh】",
                                "ประตูหน้าบ้าน · พบ【ดาวหันประจำยุค】", "Pintu Utama · [Bintang Hadap Makmur]"
                            ),
                            detail: tr8(
                                String(format: "入户门迎当前%d运当旺向星飞临%@宫（山向 %d-%d），属于传统文化中的方位提示，请结合入口采光、通风、视线和动线复核。", curPeriod, pName, palace.mountainStar, palace.facingStar),
                                String(format: "入戶門迎當前%d運當旺向星飛臨%@宮（山向 %d-%d），屬於傳統文化中的方位提示，請結合入口採光、通風、視線和動線複核。", curPeriod, pName, palace.mountainStar, palace.facingStar),
                                String(format: "The main entrance receives the current Period %d timely facing star in the %@ palace (Mountain-Facing %d-%d), an auspicious qi mouth when kept bright and open.", curPeriod, pName, palace.mountainStar, palace.facingStar),
                                String(format: "玄関が第%d運の当旺向星が飛臨する%@宮（山向 %d-%d）を迎え、旺気を取り込みやすい吉配置です。", curPeriod, pName, palace.mountainStar, palace.facingStar),
                                String(format: "현관문이 현재 %d운의 당왕향성이 비림한 %@궁(산향 %d-%d)을 맞이하여 왕기를 받아들이는 길한 배치입니다.", curPeriod, pName, palace.mountainStar, palace.facingStar),
                                String(format: "Cửa chính đón sao hướng đương vượng Vận %d bay đến cung %@ (Sơn-Hướng %d-%d), rất thuận lợi để nạp sinh khí.", curPeriod, pName, palace.mountainStar, palace.facingStar),
                                String(format: "ประตูทางเข้าต้อนรับดาวหันประจำยุคที่ %d ในเรือน%@ (ดาวภูเขา-ดาวหัน %d-%d) ส่งเสริมการรับกระแสชี่มงคลเข้าสู่บ้าน", curPeriod, pName, palace.mountainStar, palace.facingStar),
                                String(format: "Pintu utama menyambut bintang hadap makmur Periode %d di sektor %@ (Gunung-Hadap %d-%d), sangat baik untuk menyerap energi positif.", curPeriod, pName, palace.mountainStar, palace.facingStar)
                            ),
                            fengshuiLore: tr8(
                                "《天玉经》云：'向首一星灾福柄，当旺乘时发万箱'。",
                                "《天玉經》云：「向首一星災福柄，當旺乘時發萬箱」。",
                                "Jade Mirror Classic (Tian Yu Jing): 'The single star at the facing mouth governs fortune; when timely and prosperous, it brings abundance.'",
                                "『天玉経』「向首の一星は災福の柄、当旺にして時に乗ずれば大いに栄える」。",
                                "《천옥경》 ‘향수일성재복병 당왕승시발만상’. 향수(현관)에 당왕성이 오면 시운을 타서 번창한다고 봅니다.",
                                "《Thiên Ngọc Kinh》: “Hướng thủ nhất tinh tai phúc bính, đương vượng thừa thời phát vạn tương”.",
                                "《เทียนอวี้จิง》กล่าวว่าดาวหันหน้าคือหัวใจของโชคลาภ เมื่อตรงยุคที่รุ่งเรืองย่อมนำความอุดมสมบูรณ์มาให้",
                                "Tian Yu Jing menyebutkan bahwa bintang hadap yang sedang berjaya di pintu masuk membawa kemakmuran."
                            ),
                            solution: tr8(
                                "门厅保持明堂整洁开阔，设暖白长明灯引气入宅，生旺气场。",
                                "門廳保持明堂整潔開闊，設暖白長明燈引氣入宅，生旺氣場。",
                                "Keep the entry foyer (Ming Tang) clean and open, and maintain warm-white entryway lighting to welcome prosperous qi.",
                                "玄関ホール（内明堂）を明るく清潔に保ち、暖白色の照明を灯して旺気を室内に導いてください。",
                                "현관 명당을 깨끗하고 넓게 유지하고, 따뜻한 조명을 밝혀 왕기가 집안으로 잘 들어오게 하세요.",
                                "Giữ tiền sảnh (Minh Đường) luôn gọn gàng, thoáng đãng và bật đèn ánh sáng ấm để dẫn vượng khí vào nhà.",
                            "ดูแลโถงทางเข้า (หมิงถัง) ให้โล่งสะอาด และเปิดไฟแสงอบอุ่นเพื่อดึงดูดพลังงานมงคลเข้าสู่ตัวบ้าน",
                                "Jaga area foyer (Ming Tang) tetap rapi dan lapang, serta nyalakan lampu hangat untuk mengundang energi baik."
                            ),
                            coordinate: door.position
                        ))
                        score += 8
                        break
                    }
                }
            }
        }

        // O.1 玄空出卦 · 空亡破局煞 (理气最高危)：大门朝向落入大/小空亡线时自动警示并提示替卦
        if let mainDoor = mainDoors.first {
            var probe = CompassHeadingState(
                heading: compassHeading,
                facingAngle: compassHeading,
                facingMountain: Mountain24Data.shared.mountain(for: compassHeading),
                sittingMountain: Mountain24Data.shared.mountain(for: sittingAngle)
            )
            probe.heading = compassHeading
            let kwLevel = probe.kongWangLevel
            if kwLevel != .pure {
                let isMajor = kwLevel == .largeVoid
                let isSmall = kwLevel == .smallVoid
                let degStr = String(format: "%.1f°", compassHeading)
                shaItems.append(HouseSpatialShaItem(
                    title: tr8(
                        "玄空出卦 · 空亡破局煞", "玄空出卦 · 空亡破局煞", "Xuan Kong · Void Line (Kong Wang) Warning",
                        "玄空出卦・空亡破局殺", "현공출괘 · 공망파국살", "Huyền Không Xuất Quái · Không Vong Phá Cục",
                        "เสวียนคงหลุดข่วย · เส้นสูญญากาศ (คงหวง)", "Xuan Kong · Peringatan Garis Kosong (Kong Wang)"
                    ),
                    severity: .critical,
                    locationName: tr8(
                        "入户大门 · \(kwLevel.localizedTitle)",
                        "入戶大門 · \(kwLevel.localizedTitle)",
                        "Main Entrance · \(kwLevel.localizedTitle)",
                        "玄関ドア・\(kwLevel.localizedTitle)",
                        "현관문 · \(kwLevel.localizedTitle)",
                        "Cửa chính · \(kwLevel.localizedTitle)",
                        "ประตูหน้าบ้าน · \(kwLevel.localizedTitle)",
                        "Pintu Utama · \(kwLevel.localizedTitle)"
                    ),
                    detail: isMajor
                        ? tr8(
                            String(format: "大门朝向 %@ 正踏八卦大卦交界缝（大空亡绝线），五行错乱、阴阳差错，下卦排盘失效，必须以【替卦】重起九宫，属理气极凶出线。", degStr),
                            String(format: "大門朝向 %@ 正踏八卦大卦交界縫（大空亡絕線），五行錯亂、陰陽差錯，下卦排盤失效，必須以【替卦】重起九宮，屬理氣極凶出線。", degStr),
                            String(format: "The main entrance heading (%@) falls directly on a boundary between two trigrams (Major Void Line / Da Kong Wang), mixing Five-Element qi; re-verify on site and use a Replacement Star (Ti Gua) chart.", degStr),
                            String(format: "玄関の向き（%@）が八卦の境界線（大空亡線）に重なっています。気が乱れやすいため、現地で方位を再確認し【替卦】盤で判断してください。", degStr),
                            String(format: "현관 향(%@)이 팔괘 대괘 경계선(대공망선)에 걸쳐 있습니다. 오행 기운이 뒤섞이므로 현장에서 좌향을 재측정하고 【체괘】 반으로 감정해야 합니다.", degStr),
                            String(format: "Hướng cửa chính (%@) rơi đúng vào khe giao giới giữa hai quái lớn (Đại Không Vong), làm khí Ngũ Hành hỗn tạp; cần đo kiểm tra lại và lập bàn theo 【Thế Quái】.", degStr),
                            String(format: "ทิศประตูหน้าบ้าน (%@) ทับเส้นแบ่งเขตข่วยใหญ่ (ต้าคงหวง) ทำให้กระแสธาตุทั้งห้าแปรปรวน ควรวัดสอบทานซ้ำและผูกผังด้วย【ผังดาวแทน (ท่ีข่วย)】", degStr),
                            String(format: "Arah pintu utama (%@) tepat berada pada batas antartrigram (Garis Kosong Besar / Da Kong Wang); ukur ulang di lokasi dan gunakan peta Bintang Pengganti (Ti Gua).", degStr)
                        )
                        : (isSmall
                            ? tr8(
                                String(format: "大门朝向 %@ 贴近同宫两山交界（小空亡出卦），气杂不纯、阴差阳错，须以【兼向替卦】排盘化解。", degStr),
                                String(format: "大門朝向 %@ 貼近同宮兩山交界（小空亡出卦），氣雜不純、陰差陽錯，須以【兼向替卦】排盤化解。", degStr),
                                String(format: "The main entrance heading (%@) lies near the boundary between two mountains in the same palace (Minor Void / Xiao Kong Wang); evaluate using a Replacement Star (Ti Gua) chart.", degStr),
                                String(format: "玄関の向き（%@）が同宮二山の境界（小空亡）に近いため、【兼向替卦】盤で旺衰を確認してください。", degStr),
                                String(format: "현관 향(%@)이 동궁 두 산의 경계(소공망)에 가까우므로 【겸향 체괘】 반으로 왕쇠를 점검하세요.", degStr),
                                String(format: "Hướng cửa chính (%@) sát ranh giới hai sơn đồng cung (Tiểu Không Vong); cần lập bàn theo 【Kiêm Hướng Thế Quái】 để luận giải.", degStr),
                                String(format: "ทิศประตูหน้าบ้าน (%@) อยู่ใกล้เส้นแบ่งสองขุนเขาในเรือนเดียวกัน (เสี่ยวคงหวง) ควรตรวจสอบด้วย【ผังดาวแทน (ท่ีข่วย)】", degStr),
                                String(format: "Arah pintu utama (%@) mendekati batas dua gunung dalam satu sektor (Xiao Kong Wang); gunakan peta Bintang Pengganti (Ti Gua).", degStr)
                            )
                            : tr8(
                                String(format: "大门朝向 %@ 处于兼向（替卦）区间，气场微杂驳纯，建议按替卦挨星排盘校验旺衰。", degStr),
                                String(format: "大門朝向 %@ 處於兼向（替卦）區間，氣場微雜駁純，建議按替卦挨星排盤校驗旺衰。", degStr),
                                String(format: "The main entrance heading (%@) falls within a Sub-facing (Jian Xiang / Ti Gua) zone; verify star timeliness with a Replacement Star chart.", degStr),
                                String(format: "玄関の向き（%@）が兼向（替卦）区間にあります。替卦挨星盤で旺衰を照合してください。", degStr),
                                String(format: "현관 향(%@)이 겸향(체괘) 구간에 해당하므로 체괘 애성반으로 왕쇠를 대조하세요.", degStr),
                                String(format: "Hướng cửa chính (%@) nằm trong vùng Kiêm Hướng (Thế Quái); nên đối chiếu vượng suy bằng bàn Thế Quái.", degStr),
                                String(format: "ทิศประตูหน้าบ้าน (%@) อยู่ในช่วงองศาเจียนเซี่ยง (ท่ีข่วย) แนะนำให้ตรวจสอบความรุ่งเรืองด้วยผังดาวแทน", degStr),
                                String(format: "Arah pintu utama (%@) berada di zona Sub-hadap (Ti Gua); periksa kekuatan bintang dengan peta Bintang Pengganti.", degStr)
                            )),
                    fengshuiLore: tr8(
                        "堪舆古训：'出卦差错出孤寡，空亡线遇鬼神惊'。正针气场已乱，须以沈氏玄空替卦诀重排九宫飞星。",
                        "堪輿古訓：「出卦差錯出孤寡，空亡線遇鬼神驚」。正針氣場已亂，須以沈氏玄空替卦訣重排九宮飛星。",
                        "Classical Xuan Kong: boundary void lines unsettle pure trigram qi; Shen's Xuan Kong uses Replacement Stars (Ti Gua) when a heading crosses beyond pure bounds.",
                        "古典玄空では空亡線・兼向線を正針の気が交錯する境目とし、沈氏玄空の替卦訣で九宮を再配列します。",
                        "고전 현공에서는 공망선과 겸향선을 정침 기운이 교차하는 경계로 보며, 심씨현공 체괘결로 구궁비성을 재배열합니다.",
                        "Cổ huấn Huyền Không: Đường Không Vong làm lệch khí chính châm, cần dùng phép Thế Quái của Thẩm Thị Huyền Không để an lại Cửu Cung.",
                        "ตำราเสวียนคงโบราณระบุว่าเส้นคงหวงทำให้กระแสชี่แปรปรวน ต้องใช้เคล็ดวิชาดาวแทน (ท่ีข่วย) ของเสิ่นซื่อในการผูกผังเก้าเรือน",
                        "Klasik Xuan Kong mengajarkan bahwa garis batas Kong Wang mencampur energi trigram, sehingga perlu dihitung dengan metode Bintang Pengganti (Ti Gua)."
                    ),
                    solution: isMajor
                        ? tr8(
                            "此线极凶，宜用实测罗盘复核坐向，优先整体挪门或以玄关斜向引气避开绝线；理气按【三元九运·替卦排盘】断验，忌择此线动土安门。",
                            "此線極凶，宜用實測羅盤複核坐向，優先整體挪門或以玄關斜向引氣避開絕線；理氣按【三元九運·替卦排盤】斷驗，忌擇此線動土安門。",
                            "Re-measure carefully away from metal interference; if confirmed on a Major Void line, adjust the door frame/foyer angle to shift the qi mouth and evaluate using the Ti Gua chart.",
                            "金属干渉を避けて方位を再計測し、大空亡線であれば玄関框や内玄関の角度調整で気口をずらし、【替卦排盤】で判断してください。",
                            "철제 간섭을 피해 좌향을 재측정하고, 대공망선이 확실하면 문틀이나 현관 가벽 각도를 조정해 기구를 틀어주며 【체괘배반】으로 판단하세요.",
                            "Đo kiểm tra lại ở nơi không bị nhiễu kim loại; nếu đúng tuyến Đại Không Vong, nên chỉnh góc khuôn cửa hoặc vách huyền quan để đổi hướng nạp khí và luận theo 【Thế Quái】.",
                            "วัดสอบทานซ้ำโดยห่างจากโลหะรบกวน หากทับเส้นต้าคงหวงจริง แนะนำให้ปรับองศาวงกบประตูหรือทำฉากทางเข้าเฉียงเพื่อเบี่ยงช่องรับชี่ และดูผลตาม【ผังดาวแทน】",
                            "Ukur ulang jauh dari gangguan logam; jika tepat di garis Da Kong Wang, sesuaikan sudut kusen atau sekat foyer untuk menggeser arah masuk qi dan gunakan peta Ti Gua."
                        )
                        : (isSmall
                            ? tr8(
                                "玄关/门厅设斜向过渡区导气，理气按【三元九运·替卦排盘】校验旺衰，择吉时安门更佳。",
                                "玄關/門廳設斜向過渡區導氣，理氣按【三元九運·替卦排盤】校驗旺衰，擇吉時安門更佳。",
                                "Add an angled foyer transition to guide incoming airflow and verify star timeliness with the Replacement Star (Ti Gua) chart.",
                                "玄関ホールに斜めの導入動線を設けて気を整え、【三元九運・替卦排盤】で旺衰を確認してください。",
                                "현관 홀에 완충 구역을 두어 기류를 유도하고 【삼원구운·체괘배반】으로 왕쇠를 점검하세요.",
                                "Bố trí vùng đệm chuyển hướng nhẹ ở huyền quan để dẫn khí và kiểm tra vượng suy theo 【Tam Nguyên Cửu Vận · Thế Quái】.",
                                "จัดโซนโถงทางเข้าช่วยเบี่ยงกระแสชี่ และตรวจสอบความรุ่งเรืองด้วย【ผังดาวแทนยุคทั้งเก้า】",
                                "Gunakan area transisi di foyer untuk mengarahkan aliran udara dan periksa kekuatan bintang pada peta Ti Gua."
                            )
                            : tr8(
                                "玄关加设门帘缓气，理气按【三元九运·替卦排盘】校验旺衰即可。",
                                "玄關加設門簾緩氣，理氣按【三元九運·替卦排盤】校驗旺衰即可。",
                                "Soften entry airflow with a foyer curtain or mat and cross-check star timeliness using the Replacement Star (Ti Gua) chart.",
                                "玄関に暖簾やマットを添えて気を和らげ、【三元九運・替卦排盤】で旺衰を照合してください。",
                                "현관에 커튼이나 매트를 두어 기운을 완충하고 【삼원구운·체괘배반】으로 왕쇠를 확인하세요.",
                                "Treo thêm rèm hoặc thảm huyền quan để điều hòa dòng khí và đối chiếu vượng suy theo 【Thế Quái】.",
                                "เสริมม่านหรือพรมบริเวณทางเข้าเพื่อชะลอกระแสชี่ และตรวจเช็คดาวด้วย【ผังดาวแทน】",
                                "Tambahkan tirai atau keset foyer untuk menghaluskan aliran energi dan periksa peta Bintang Pengganti (Ti Gua)."
                            )),
                    coordinate: mainDoor.position
                ))
                score -= (isMajor ? 18 : (isSmall ? 12 : 6))
            }
        }

                return HouseSpatialSurvey(
            scanMethod: scanMethod,
            dimensions: dimensions,
            walls: walls,
            openings: openings,
            beams: beams,
            rooms: rooms,
            objects: objects,
            centroid: centroid,
            compassHeading: compassHeading,
            shaItems: shaItems,
            fengshuiScore: score,
            isCentroidIndirect: isCentroidIndirect
        )
    }

    private static func tr8(
        _ hans: String,
        _ hant: String,
        _ en: String,
        _ ja: String,
        _ ko: String,
        _ vi: String,
        _ th: String,
        _ id: String
    ) -> String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .zhHans, .auto: return hans
        case .zhHant: return hant
        case .en:     return en
        case .ja:     return ja
        case .ko:     return ko
        case .vi:     return vi
        case .th:     return th
        case .id:     return id
        }
    }


    /// 罗盘度数对应的八卦方位
    public static func guaForAngle(_ angleDeg: Double) -> String {
        let normalized = (angleDeg.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        switch normalized {
        case 22.5..<67.5: return "艮"
        case 67.5..<112.5: return "震"
        case 112.5..<157.5: return "巽"
        case 157.5..<202.5: return "离"
        case 202.5..<247.5: return "坤"
        case 247.5..<292.5: return "兑"
        case 292.5..<337.5: return "乾"
        default: return "坎"
        }
    }

        // MARK: - 几何辅助计算

    private static func lineSegmentIntersection(
        p1: SIMD2<Float>, p2: SIMD2<Float>,
        p3: SIMD2<Float>, p4: SIMD2<Float>
    ) -> Bool {
        func ccw(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Bool {
            return (c.y - a.y) * (b.x - a.x) > (b.y - a.y) * (c.x - a.x)
        }
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 线段求交参数：返回 [p1→p2] 上的交点参数 t ∈ (0,1)，未相交/共线返回 nil。
    /// 用于穿堂射线与墙体求交后进一步做开口（垭口）豁免判断。
    private static func lineIntersectionParam(
        p1: SIMD2<Float>, p2: SIMD2<Float>,
        p3: SIMD2<Float>, p4: SIMD2<Float>
    ) -> Float? {
        let r = p2 - p1
        let s = p4 - p3
        let rxs = r.x * s.y - r.y * s.x
        guard abs(rxs) > 1e-6, simd_length(r) > 1e-4, simd_length(s) > 1e-4 else { return nil }
        let q = p3 - p1
        let t = (q.x * s.y - q.y * s.x) / rxs
        let u = (q.x * r.y - q.y * r.x) / rxs
        if t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0 {
            return t
        }
        return nil
    }

    /// 房屋主轴方向角（radian，归一化到 [0, π)）：以最长墙线段走向为基准。
    /// 无有效墙时返回 0（退回世界轴对齐），保证 OBB 计算始终可退。
    private static func primaryAxisAngle(walls: [SpatialWall3D]) -> Float {
        var bestLen: Float = 0
        var bestAngle: Float = 0
        for w in walls {
            let dx = w.endX - w.startX
            let dz = w.endZ - w.startZ
            let len = simd_length(SIMD2<Float>(dx, dz))
            guard len > 0.3 else { continue }
            var ang = atan2(dz, dx)
            if ang < 0 { ang += .pi }
            if ang >= .pi { ang -= .pi }
            if len > bestLen { bestLen = len; bestAngle = ang }
        }
        return bestAngle
    }

    private static func distancePointToSegment(
        point: SIMD2<Float>,
        segA: SIMD2<Float>,
        segB: SIMD2<Float>
    ) -> Float {
        let seg = segB - segA
        let l2 = simd_length_squared(seg)
        if l2 == 0 { return simd_distance(point, segA) }
        let t = max(0.0, min(1.0, simd_dot(point - segA, seg) / l2))
        let projection = segA + t * seg
        return simd_distance(point, projection)
    }
}

// MARK: - AutoCAD DXF 工程级矢量测绘图生成器 (PRD 专业测绘工具要求)

extension HouseSpatialSurvey {
    /// 生成符合工业标准的 AutoCAD ASCII DXF (Release 12/2000) 格式矢量图数据
    public func generateCAD_DXF() -> String {
        var s = ""
        
        // 1. DXF 头部
        s += "0\nSECTION\n2\nHEADER\n"
        s += "9\n$INSUNITS\n70\n6\n" // 米为单位 (Meters)
        s += "9\n$ANGBASE\n50\n0.0\n"
        s += "0\nENDSEC\n"
        
        // 2. TABLES 区域 (图层定义)
        s += "0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n6\n"
        
        let layers: [(name: String, color: Int)] = [
            ("WALLS_BEARING", 5),    // 蓝色
            ("WALLS_PARTITION", 4),  // 青色
            ("DOORS", 2),            // 黄色
            ("WINDOWS", 3),          // 绿色
            ("BEAMS", 1),            // 红色
            ("ROOM_LABELS", 7),      // 白色
            ("TAIJI_CENTER", 40),    // 金色
            ("DIMENSIONS", 6)        // 品红：净距尺寸标注线
        ]
        
        for lyr in layers {
            s += "0\nLAYER\n2\n\(lyr.name)\n70\n0\n62\n\(lyr.color)\n6\nCONTINUOUS\n"
        }
        s += "0\nENDTAB\n0\nENDSEC\n"
        
        // 3. ENTITIES 区域 (绘图实体)
        s += "0\nSECTION\n2\nENTITIES\n"
        
        // 绘制墙体线条 (LINE)
        for wall in walls {
            let layer = wall.isLoadBearing ? "WALLS_BEARING" : "WALLS_PARTITION"
            s += "0\nLINE\n8\n\(layer)\n"
            s += "10\n\(String(format: "%.3f", wall.startX))\n20\n\(String(format: "%.3f", -wall.startZ))\n30\n0.0\n"
            s += "11\n\(String(format: "%.3f", wall.endX))\n21\n\(String(format: "%.3f", -wall.endZ))\n31\n0.0\n"
        }
        
        // 绘制门与窗 (LINE)
        for op in openings {
            let layer = (op.type == .entranceDoor || op.type == .interiorDoor) ? "DOORS" : "WINDOWS"
            let halfW = op.width * 0.5
            // 沿门法线垂直方向画开孔线
            let p1X = op.posX - op.normalZ * halfW
            let p1Y = -(op.posZ + op.normalX * halfW)
            let p2X = op.posX + op.normalZ * halfW
            let p2Y = -(op.posZ - op.normalX * halfW)
            
            s += "0\nLINE\n8\n\(layer)\n"
            s += "10\n\(String(format: "%.3f", p1X))\n20\n\(String(format: "%.3f", p1Y))\n30\n0.0\n"
            s += "11\n\(String(format: "%.3f", p2X))\n21\n\(String(format: "%.3f", p2Y))\n31\n0.0\n"
        }
        
        // 绘制结构横梁 (LINE)
        for beam in beams {
            s += "0\nLINE\n8\nBEAMS\n"
            s += "10\n\(String(format: "%.3f", beam.startX))\n20\n\(String(format: "%.3f", -beam.startZ))\n30\n0.0\n"
            s += "11\n\(String(format: "%.3f", beam.endX))\n21\n\(String(format: "%.3f", -beam.endZ))\n31\n0.0\n"
        }
        
        // 绘制立极中宫点 (CIRCLE + 十字标)
        s += "0\nCIRCLE\n8\nTAIJI_CENTER\n"
        s += "10\n\(String(format: "%.3f", centroidX))\n20\n\(String(format: "%.3f", -centroidZ))\n30\n0.0\n40\n0.5\n"
        s += "0\nTEXT\n8\nTAIJI_CENTER\n"
        s += "10\n\(String(format: "%.3f", centroidX + 0.6))\n20\n\(String(format: "%.3f", -centroidZ))\n30\n0.0\n"
        s += "40\n0.35\n1\nTaiJi Center (Centroid)\n"
        
        // 标注房间文字与面积 (TEXT)
        for room in rooms {
            s += "0\nTEXT\n8\nROOM_LABELS\n"
            s += "10\n\(String(format: "%.3f", room.centerX - 0.4))\n20\n\(String(format: "%.3f", -room.centerZ))\n30\n0.0\n"
            s += "40\n0.30\n1\n\(room.localizedName) \(String(format: "%.1f", room.areaSqMeters))m2\n"
        }

        // 标注主要开间/进深净距尺寸线 (ALIGNED DIMENSION)
        // 全屋外框 X/Z 净距 + 面积最大的前 3 个房间各自开间/进深净距，
        // 供施工与设计人员直接量尺，无需手工重测。
        func appendAlignedDim(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float, _ label: String) {
            let mx = (x1 + x2) * 0.5
            let my = (y1 + y2) * 0.5
            s += "0\nDIMENSION\n8\nDIMENSIONS\n2\n*D1\n"
            s += "10\n\(String(format: "%.3f", x1))\n20\n\(String(format: "%.3f", y1))\n30\n0.0\n"
            s += "11\n\(String(format: "%.3f", x2))\n21\n\(String(format: "%.3f", y2))\n31\n0.0\n"
            s += "13\n\(String(format: "%.3f", mx))\n23\n\(String(format: "%.3f", my))\n33\n0.0\n"
            s += "70\n32\n3\nDIMENSIONS\n1\n\(label)\n"
        }
        // 全屋净距：在导出器内独立求全屋外框 AABB（墙/开口/房间端点），
        // 不依赖 analyzeSpatialHouse 局部变量作用域。
        var dMinX: Float = .greatestFiniteMagnitude
        var dMaxX: Float = -.greatestFiniteMagnitude
        var dMinZ: Float = .greatestFiniteMagnitude
        var dMaxZ: Float = -.greatestFiniteMagnitude
        for w in walls {
            dMinX = min(dMinX, min(w.startX, w.endX)); dMaxX = max(dMaxX, max(w.startX, w.endX))
            dMinZ = min(dMinZ, min(w.startZ, w.endZ)); dMaxZ = max(dMaxZ, max(w.startZ, w.endZ))
        }
        for op in openings {
            dMinX = min(dMinX, op.posX); dMaxX = max(dMaxX, op.posX)
            dMinZ = min(dMinZ, op.posZ); dMaxZ = max(dMaxZ, op.posZ)
        }
        for r in rooms {
            dMinX = min(dMinX, r.centerX - r.sizeX * 0.5); dMaxX = max(dMaxX, r.centerX + r.sizeX * 0.5)
            dMinZ = min(dMinZ, r.centerZ - r.sizeZ * 0.5); dMaxZ = max(dMaxZ, r.centerZ + r.sizeZ * 0.5)
        }
        if dMinX >= dMaxX { dMinX = -3.0; dMaxX = 3.0 }
        if dMinZ >= dMaxZ { dMinZ = -3.0; dMaxZ = 3.0 }
        let dSpanX = max(1.5, dMaxX - dMinX)
        let dSpanZ = max(1.5, dMaxZ - dMinZ)
        let lang = LocalizationManager.shared.effectiveLanguage
        let spanXLabel: String
        let spanZLabel: String
        let roomWPrefix: String
        let roomDPrefix: String
        switch lang {
        case .zhHans, .auto:
            spanXLabel = "全屋开间"; spanZLabel = "全屋进深"; roomWPrefix = "开间"; roomDPrefix = "进深"
        case .zhHant:
            spanXLabel = "全屋開間"; spanZLabel = "全屋進深"; roomWPrefix = "開間"; roomDPrefix = "進深"
        case .en:
            spanXLabel = "Total Width"; spanZLabel = "Total Depth"; roomWPrefix = " W"; roomDPrefix = " D"
        case .ja:
            spanXLabel = "住戸間口"; spanZLabel = "住戸奥行"; roomWPrefix = "間口"; roomDPrefix = "奥行"
        case .ko:
            spanXLabel = "전체 전면폭"; spanZLabel = "전체 깊이"; roomWPrefix = " 폭"; roomDPrefix = " 깊이"
        case .vi:
            spanXLabel = "Rộng toàn nhà"; spanZLabel = "Sâu toàn nhà"; roomWPrefix = " Rộng"; roomDPrefix = " Sâu"
        case .th:
            spanXLabel = "ความกว้างรวม"; spanZLabel = "ความลึกรวม"; roomWPrefix = " กว้าง"; roomDPrefix = " ลึก"
        case .id:
            spanXLabel = "Lebar Total"; spanZLabel = "Kedalaman Total"; roomWPrefix = " L"; roomDPrefix = " P"
        }
        appendAlignedDim(dMinX, -dMinZ, dMaxX, -dMinZ, "\(spanXLabel) \(String(format: "%.2f", dSpanX))m")
        appendAlignedDim(dMinX, -dMaxZ, dMaxX, -dMaxZ, "\(spanXLabel) \(String(format: "%.2f", dSpanX))m")
        appendAlignedDim(dMinX, -dMinZ, dMinX, -dMaxZ, "\(spanZLabel) \(String(format: "%.2f", dSpanZ))m")
        appendAlignedDim(dMaxX, -dMinZ, dMaxX, -dMaxZ, "\(spanZLabel) \(String(format: "%.2f", dSpanZ))m")
        // 主要房间净距
        for r in rooms.sorted(by: { $0.areaSqMeters > $1.areaSqMeters }).prefix(3) {
            let rMinX = r.centerX - r.sizeX * 0.5
            let rMaxX = r.centerX + r.sizeX * 0.5
            let rMinZ = r.centerZ - r.sizeZ * 0.5
            let rMaxZ = r.centerZ + r.sizeZ * 0.5
            let rLabel = r.localizedName
            appendAlignedDim(rMinX, -rMinZ, rMaxX, -rMinZ, "\(rLabel)\(roomWPrefix) \(String(format: "%.2f", r.sizeX))m")
            appendAlignedDim(rMinX, -rMaxZ, rMaxX, -rMaxZ, "\(rLabel)\(roomWPrefix) \(String(format: "%.2f", r.sizeX))m")
            appendAlignedDim(rMinX, -rMinZ, rMinX, -rMaxZ, "\(rLabel)\(roomDPrefix) \(String(format: "%.2f", r.sizeZ))m")
            appendAlignedDim(rMaxX, -rMinZ, rMaxX, -rMaxZ, "\(rLabel)\(roomDPrefix) \(String(format: "%.2f", r.sizeZ))m")
        }
        
        // 4. 结尾
        s += "0\nENDSEC\n0\nEOF\n"
        return s
    }

    /// 导出为本地临时 DXF 文件以供 CAD 软件打开或分享
    public func exportDXFFileURL() -> URL? {
        let dxfString = generateCAD_DXF()
        let fileName = "TianJi-HouseSurvey-\(id.uuidString.prefix(8)).dxf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try dxfString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }
}
