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
        self.yangGateName = ""
        self.yangIsAuspicious = false
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

    public var localizedCategoryName: String {
        let key = category.lowercased()
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .zhHans, .auto:
            switch key {
            case "bed": return "卧床"
            case "sofa": return "沙发"
            case "chair": return "座椅"
            case "table", "desk": return "桌台"
            case "television": return "电视"
            case "stove": return "炉灶"
            case "oven": return "烤箱"
            case "refrigerator": return "冰箱"
            case "toilet": return "马桶"
            case "bathtub": return "浴缸"
            case "sink": return "水槽"
            case "washerdryer": return "洗烘机"
            case "dishwasher": return "洗碗机"
            case "storage": return "收纳柜"
            case "fireplace": return "壁炉"
            case "stairs": return "楼梯"
            default: return category
            }
        case .zhHant:
            switch key {
            case "bed": return "臥床"
            case "sofa": return "沙發"
            case "chair": return "座椅"
            case "table", "desk": return "桌台"
            case "television": return "電視"
            case "stove": return "爐灶"
            case "oven": return "烤箱"
            case "refrigerator": return "冰箱"
            case "toilet": return "馬桶"
            case "bathtub": return "浴缸"
            case "sink": return "水槽"
            case "washerdryer": return "洗烘機"
            case "dishwasher": return "洗碗機"
            case "storage": return "收納櫃"
            case "fireplace": return "壁爐"
            case "stairs": return "樓梯"
            default: return category
            }
        case .en:
            switch key {
            case "bed": return "Bed"
            case "sofa": return "Sofa"
            case "chair": return "Chair"
            case "table", "desk": return "Table"
            case "television": return "TV"
            case "stove": return "Stove"
            case "oven": return "Oven"
            case "refrigerator": return "Refrigerator"
            case "toilet": return "Toilet"
            case "bathtub": return "Bathtub"
            case "sink": return "Sink"
            case "washerdryer": return "Washer/Dryer"
            case "dishwasher": return "Dishwasher"
            case "storage": return "Cabinet"
            case "fireplace": return "Fireplace"
            case "stairs": return "Stairs"
            default: return category
            }
        case .ja:
            switch key {
            case "bed": return "ベッド"
            case "sofa": return "ソファ"
            case "chair": return "椅子"
            case "table", "desk": return "テーブル"
            case "television": return "テレビ"
            case "stove": return "コンロ"
            case "oven": return "オーブン"
            case "refrigerator": return "冷蔵庫"
            case "toilet": return "トイレ"
            case "bathtub": return "浴槽"
            case "sink": return "シンク"
            case "washerdryer": return "洗濯乾燥機"
            case "dishwasher": return "食洗機"
            case "storage": return "収納棚"
            case "fireplace": return "暖炉"
            case "stairs": return "階段"
            default: return category
            }
        case .ko:
            switch key {
            case "bed": return "침대"
            case "sofa": return "소파"
            case "chair": return "의자"
            case "table", "desk": return "테이블"
            case "television": return "TV"
            case "stove": return "조리대/가스레인지"
            case "oven": return "오븐"
            case "refrigerator": return "냉장고"
            case "toilet": return "변기"
            case "bathtub": return "욕조"
            case "sink": return "싱크대"
            case "washerdryer": return "세탁건조기"
            case "dishwasher": return "식기세척기"
            case "storage": return "수납장"
            case "fireplace": return "벽난로"
            case "stairs": return "계단"
            default: return category
            }
        case .vi:
            switch key {
            case "bed": return "Giường"
            case "sofa": return "Sofa"
            case "chair": return "Ghế"
            case "table", "desk": return "Bàn"
            case "television": return "TV"
            case "stove": return "Bếp nấu"
            case "oven": return "Lò nướng"
            case "refrigerator": return "Tủ lạnh"
            case "toilet": return "Bồn cầu"
            case "bathtub": return "Bồn tắm"
            case "sink": return "Bồn rửa"
            case "washerdryer": return "Máy giặt/sấy"
            case "dishwasher": return "Máy rửa bát"
            case "storage": return "Tủ kệ"
            case "fireplace": return "Lò sưởi"
            case "stairs": return "Cầu thang"
            default: return category
            }
        case .th:
            switch key {
            case "bed": return "เตียงนอน"
            case "sofa": return "โซฟา"
            case "chair": return "เก้าอี้"
            case "table", "desk": return "โต๊ะ"
            case "television": return "ทีวี"
            case "stove": return "เตาไฟ"
            case "oven": return "เตาอบ"
            case "refrigerator": return "ตู้เย็น"
            case "toilet": return "โถสุขภัณฑ์"
            case "bathtub": return "อ่างอาบน้ำ"
            case "sink": return "อ่างล้าง"
            case "washerdryer": return "เครื่องซัก/อบผ้า"
            case "dishwasher": return "เครื่องล้างจาน"
            case "storage": return "ตู้เก็บของ"
            case "fireplace": return "เตาผิง"
            case "stairs": return "บันได"
            default: return category
            }
        case .id:
            switch key {
            case "bed": return "Tempat Tidur"
            case "sofa": return "Sofa"
            case "chair": return "Kursi"
            case "table", "desk": return "Meja"
            case "television": return "TV"
            case "stove": return "Kompor"
            case "oven": return "Oven"
            case "refrigerator": return "Kulkas"
            case "toilet": return "Kloset"
            case "bathtub": return "Bak Mandi"
            case "sink": return "Wastafel"
            case "washerdryer": return "Mesin Cuci"
            case "dishwasher": return "Mesin Cuci Piring"
            case "storage": return "Lemari"
            case "fireplace": return "Perapian"
            case "stairs": return "Tangga"
            default: return category
            }
        }
    }

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
    /// Azimuth of world -Z, used only to convert model coordinates to bearings.
    public let compassHeading: Double
    /// Actual house facing; independent of the AR session's starting direction.
    public let houseFacingDegrees: Double?
    public let houseFacingWasExplicit: Bool?
    public let centroidWasExplicit: Bool?

    /// An automatically derived bearing must be recomputed after editing doors.
    public var fixedHouseFacing: Double? {
        if let houseFacingWasExplicit { return houseFacingWasExplicit ? houseFacingDegrees : nil }
        // Older engines persisted the derived angle without its source. A
        // matching entrance bearing is the only evidence available to migrate.
        if let saved = houseFacingDegrees,
           let derived = HouseSpatialSurveyEngine.resolveHouseFacing(openings: openings, centroid: centroid,
                                                                      coordinateHeading: compassHeading) {
            let delta = abs(saved - derived).truncatingRemainder(dividingBy: 360)
            if min(delta, 360 - delta) < 0.01 { return nil }
        }
        return houseFacingDegrees
    }

    public var resolvedHouseFacing: Double? {
        HouseSpatialSurveyEngine.resolveHouseFacing(openings: openings, centroid: centroid,
                                                   coordinateHeading: compassHeading,
                                                   explicitFacing: houseFacingDegrees)
    }
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
        isCentroidIndirect: Bool? = nil,
        houseFacingDegrees: Double? = nil,
        houseFacingWasExplicit: Bool? = nil,
        centroidWasExplicit: Bool? = nil
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
        self.houseFacingDegrees = houseFacingDegrees
        self.houseFacingWasExplicit = houseFacingWasExplicit
        self.centroidWasExplicit = centroidWasExplicit
        self.shaItems = shaItems
        self.fengshuiScore = max(0, min(100, fengshuiScore))
        self.isCentroidIndirect = isCentroidIndirect
    }
}

// MARK: - 全屋形煞与 3D 测绘分析引擎 (HouseSpatialSurveyEngine)

public enum HouseSpatialSurveyEngine {
    /// Use the outward entrance normal when no explicit facing was supplied.
    /// The coordinate baseline alone cannot establish a house's facing.
    public static func resolveHouseFacing(
        openings: [SpatialOpening3D], centroid: SIMD3<Float>,
        coordinateHeading: Double, explicitFacing: Double? = nil
    ) -> Double? {
        func normalized(_ angle: Double) -> Double {
            (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        }
        if let explicitFacing, explicitFacing.isFinite { return normalized(explicitFacing) }
        guard coordinateHeading.isFinite,
              let door = openings.first(where: { $0.type == .entranceDoor }) else { return nil }
        var normal = SIMD2<Float>(door.normalX, door.normalZ)
        guard normal.x.isFinite, normal.y.isFinite, simd_length(normal) > 0.001 else { return nil }
        let outward = SIMD2<Float>(door.posX - centroid.x, door.posZ - centroid.z)
        if simd_dot(normal, outward) < 0 { normal = -normal }
        return normalized(atan2(Double(normal.x), Double(-normal.y)) * 180 / .pi + coordinateHeading)
    }

    /// 对全屋 3D 空间进行全方位形煞审计与结构测算
    public static func analyzeSpatialHouse(
        scanMethod: String,
        walls: [SpatialWall3D],
        openings: [SpatialOpening3D],
        beams: [SpatialBeam3D],
        rooms: [SpatialRoom3D],
        objects: [SpatialObject3D],
        compassHeading: Double,
        centroidOverride: SIMD3<Float>? = nil,
        houseFacingDegrees: Double? = nil,
        houseFacingWasExplicit: Bool? = nil,
        analysisDate: Date = Date(),
        surveyID: UUID = UUID()
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

        let grossArea = lSpanX * lSpanZ

        let dimensions = HouseDimensions(
            totalWidth: lSpanX,
            totalDepth: lSpanZ,
            ceilingHeight: maxH,
            grossFloorArea: grossArea,
            usableFloorArea: min(usableArea, grossArea)
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
        let centroid = SIMD3<Float>(cx, 0, cz)
        let resolvedFacing = resolveHouseFacing(openings: openings, centroid: centroid, coordinateHeading: compassHeading, explicitFacing: houseFacingDegrees)

        return HouseSpatialSurvey(
            id: surveyID,
            timestamp: analysisDate,
            scanMethod: scanMethod,
            dimensions: dimensions,
            walls: walls,
            openings: openings.map { SpatialOpening3D(id: $0.id, type: $0.type,
                position: $0.position, normal: $0.normal, width: $0.width, height: $0.height) },
            beams: beams,
            rooms: rooms,
            objects: objects,
            centroid: centroid,
            compassHeading: compassHeading,
            shaItems: [],
            fengshuiScore: 0,
            isCentroidIndirect: isCentroidIndirect,
            houseFacingDegrees: resolvedFacing,
            houseFacingWasExplicit: houseFacingWasExplicit ?? (houseFacingDegrees?.isFinite == true),
            centroidWasExplicit: centroidOverride != nil
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
