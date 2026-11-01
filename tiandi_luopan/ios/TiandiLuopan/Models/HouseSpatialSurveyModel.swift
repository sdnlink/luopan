import Foundation
import CoreGraphics
import simd

// MARK: - 3D 全屋测绘空间数据模型与全屋形煞引擎 (PRD 5.3 & 第7章)

/// 形煞危害严重程度
public enum ShaSeverity: String, Codable {
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
}

/// 门窗开孔类型
public enum SpatialOpeningType: String, Codable {
    case entranceDoor = "入户大门"
    case interiorDoor = "房间门"
    case window = "主采光窗"
    case opening = "垭口开口"
    case balconyDoor = "阳台移门"
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

    public var center: SIMD3<Float> { SIMD3<Float>(centerX, centerY, centerZ) }
    public var size: SIMD3<Float> { SIMD3<Float>(sizeX, sizeY, sizeZ) }

    public init(
        id: UUID = UUID(),
        name: String,
        type: FloorplanRoomType,
        center: SIMD3<Float>,
        size: SIMD3<Float>,
        areaSqMeters: Float? = nil
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

    public var position: SIMD3<Float> { SIMD3<Float>(posX, posY, posZ) }
    public var size: SIMD3<Float> { SIMD3<Float>(sizeX, sizeY, sizeZ) }

    public init(
        id: UUID = UUID(),
        category: String,
        position: SIMD3<Float>,
        size: SIMD3<Float>
    ) {
        self.id = id
        self.category = category
        self.posX = position.x
        self.posY = position.y
        self.posZ = position.z
        self.sizeX = size.x
        self.sizeY = size.y
        self.sizeZ = size.z
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
    public let severity: ShaSeverity
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
        severity: ShaSeverity,
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

    public var centroid: SIMD3<Float> {
        SIMD3<Float>(centroidX, centroidY, centroidZ)
    }

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
        fengshuiScore: Int
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
        compassHeading: Double
    ) -> HouseSpatialSurvey {
        // 1. 计算全屋物理边界包围盒
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        var maxH: Float = 2.8

        for w in walls {
            minX = min(minX, min(w.startX, w.endX))
            maxX = max(maxX, max(w.startX, w.endX))
            minZ = min(minZ, min(w.startZ, w.endZ))
            maxZ = max(maxZ, max(w.startZ, w.endZ))
            maxH = max(maxH, w.height)
        }
        for o in openings {
            minX = min(minX, o.posX - o.width * 0.5)
            maxX = max(maxX, o.posX + o.width * 0.5)
            minZ = min(minZ, o.posZ - o.width * 0.5)
            maxZ = max(maxZ, o.posZ + o.width * 0.5)
            maxH = max(maxH, o.posY + o.height * 0.5)
        }
        for r in rooms {
            minX = min(minX, r.centerX - r.sizeX * 0.5)
            maxX = max(maxX, r.centerX + r.sizeX * 0.5)
            minZ = min(minZ, r.centerZ - r.sizeZ * 0.5)
            maxZ = max(maxZ, r.centerZ + r.sizeZ * 0.5)
            maxH = max(maxH, r.sizeY)
        }

        if minX >= maxX { minX = -4.0; maxX = 4.0 }
        if minZ >= maxZ { minZ = -4.0; maxZ = 4.0 }

        let spanX = max(1.5, maxX - minX)
        let spanZ = max(1.5, maxZ - minZ)
        let usableArea = rooms.reduce(Float(0)) { $0 + $1.areaSqMeters }
        let grossArea = max(usableArea * 1.22, spanX * spanZ)

        let dimensions = HouseDimensions(
            totalWidth: spanX,
            totalDepth: spanZ,
            ceilingHeight: maxH,
            grossFloorArea: grossArea,
            usableFloorArea: max(usableArea, spanX * spanZ * 0.78)
        )

        // 2. 确定立极中宫点 (Centroid)
        let cx = (minX + maxX) * 0.5
        let cz = (minZ + maxZ) * 0.5
        let centroid = SIMD3<Float>(cx, 0.0, cz)

        // 3. 全屋形煞体检核心逻辑
        var shaItems: [HouseSpatialShaItem] = []
        var score = 92

        // A. 中宫受污检测 (卫生间/厨房占据房屋中心立极九宫中宫)
        let centerBoxMinX = cx - spanX / 6.0
        let centerBoxMaxX = cx + spanX / 6.0
        let centerBoxMinZ = cz - spanZ / 6.0
        let centerBoxMaxZ = cz + spanZ / 6.0

        for room in rooms {
            let rMinX = room.centerX - room.sizeX * 0.5
            let rMaxX = room.centerX + room.sizeX * 0.5
            let rMinZ = room.centerZ - room.sizeZ * 0.5
            let rMaxZ = room.centerZ + room.sizeZ * 0.5

            let overlapX = max(0, min(centerBoxMaxX, rMaxX) - max(centerBoxMinX, rMinX))
            let overlapZ = max(0, min(centerBoxMaxZ, rMaxZ) - max(centerBoxMinZ, rMinZ))
            let overlapArea = overlapX * overlapZ

            if overlapArea > 0.4 {
                if room.type == .bathroom {
                    shaItems.append(HouseSpatialShaItem(
                        title: "中宫受污 (水浸太极)",
                        severity: .critical,
                        locationName: "房屋中宫·\(room.name)",
                        detail: "全屋太极立极中心被卫生间占据，排污秽气直冲中宫枢纽，主宅运滞涩、心肾不交。",
                        fengshuiLore: "《撼龙经》云：'水浸心包，家门困耗'。房屋中心为皇极太极之位，宜静宜洁，不宜落水溺污。",
                        solution: "中宫卫生间务必保持干爽排风，悬挂天然开光桃木兽头或葫芦收煞，并常点暖黄长明灯生土克水。",
                        coordinate: room.center
                    ))
                    score -= 16
                } else if room.type == .kitchen {
                    shaItems.append(HouseSpatialShaItem(
                        title: "火烧中宫 (燥火焚心)",
                        severity: .critical,
                        locationName: "房屋中宫·\(room.name)",
                        detail: "全屋太极中心被厨房或灶台占据，燥火烈焰焚烤中轴，易致心脑烦躁、家运起伏。",
                        fengshuiLore: "《八宅明镜》云：'火居天心，病染胸膈'。太极属阴阳平衡之枢纽，纯火久煅则元气耗散。",
                        solution: "厨灶移位避开房屋正中心，厨房采用米白或浅黄色地砖引土泄火，灶台下置黄玉石辟火化煞。",
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
                let delta = wPos - dPos
                let dist = simd_length(delta)
                guard dist >= 2.0 && dist <= 14.0 else { continue }

                let rayDir = delta / dist
                let alignment = abs(simd_dot(dNorm, rayDir))
                let lateralDist = dist * sqrt(max(0, 1.0 - alignment * alignment))

                if alignment >= 0.86 && lateralDist <= 0.90 {
                    // 检查两点之间是否有隔断墙阻隔
                    let isBlockedByWall = walls.contains { wall in
                        lineSegmentIntersection(
                            p1: dPos, p2: wPos,
                            p3: SIMD2<Float>(wall.startX, wall.startZ),
                            p4: SIMD2<Float>(wall.endX, wall.endZ)
                        )
                    }

                    if !isBlockedByWall {
                        shaItems.append(HouseSpatialShaItem(
                            title: "穿堂穿心煞 (一箭穿心)",
                            severity: .critical,
                            locationName: "大门 ⟷ \(win.type.rawValue)",
                            detail: String(format: "入户门与%@轴线近乎共线直冲 (间距 %.1f 米，偏角 %.0f°)，气流直来直去不聚气，主财帛财散难聚、气场动荡。", win.type.rawValue, dist, Double(acos(min(Float(1.0), alignment))) * 180.0 / Double.pi),
                            fengshuiLore: "《葬经》云：'气乘风则散，界水则止'。前通后达直穿门户，宅内藏风聚气之基尽失，所谓'前门进宝后门流'。",
                            solution: "在大门玄关处设实木屏风、半透磨砂玄关柜阻挡视线，或在阳台处悬挂厚质遮光帘与铜葫芦聚气。",
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
                        title: "门冲对门煞 (两口相对)",
                        severity: .warning,
                        locationName: "双门对冲·间距 \(String(format: "%.1f", dist))m",
                        detail: "两间居室房门直对，间距过窄产生对流风切，主家人意见相左、易生口角龃龉。",
                        fengshuiLore: "《阳宅十书》云：'两门相对谓相骂，主家不和争相夸'。门户为纳气之口，两口相争则家宅不宁。",
                        solution: "门上悬挂过膝布帘，门框两侧可加装五帝钱或中国结以和解气场，平时常保持其中一门常闭。",
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
                    let targetName = target.category == "bed" ? "睡床" : "主位沙发"
                    shaItems.append(HouseSpatialShaItem(
                        title: "横梁压顶煞 (气压沉重)",
                        severity: .critical,
                        locationName: "\(targetName)正上方 (净高\(String(format: "%.2f", beam.clearanceHeight))m)",
                        detail: String(format: "沉重承重横梁横跨在%@上方，下垂气流形成沉降重压，久居易头痛压抑、精神衰弱。", targetName),
                        fengshuiLore: "《鲁班经》云：'横梁压顶若悬斧，身染沉疴气数枯'。横梁下空气受阻下压，人处于其下受气场冲煞。",
                        solution: "将床铺或沙发平移挪出横梁投影区；若无法挪位，建议做平吊顶包梁隐藏，或梁两端悬挂开光铜葫芦泄压。",
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
                        title: "房门冲床 (冲撞身魂)",
                        severity: .warning,
                        locationName: "房门 ⟷ 卧床",
                        detail: String(format: "房门开启气流直冲床铺 (间距 %.1f 米)，睡眠中受冷热气流对流冲刷，不利安眠与筋骨健康。", dist),
                        fengshuiLore: "门开气入直射人身，动静失衡，神魂不聚。",
                        solution: "微调床头朝向或位置避开门冲直线，若空间受限可在门边设遮挡隔断或门挂长帘缓冲。",
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
                    shaItems.append(HouseSpatialShaItem(
                        title: "水火未济 (厨厕相逼)",
                        severity: .warning,
                        locationName: "灶台 ⟷ 卫浴 (间距 \(String(format: "%.1f", dist))m)",
                        detail: "灶台五行属独火，马桶卫浴五行属坎水，水火直冲相逼，主肠胃失和、家眷情绪易燥。",
                        fengshuiLore: "《催官篇》云：'水火不相容，宅母病腹痛'。水火同宫激荡，气脉杂乱。",
                        solution: "炉灶与卫生间门错开避对，两者之间摆放常青绿植（木元素）以形成'水生木、木生火'通关调和。",
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
            if eval.yangIsAuspicious {
                shaItems.append(HouseSpatialShaItem(
                    title: "鲁班门光尺 · 大门纳吉",
                    severity: .auspicious,
                    locationName: "入户大门 (宽 \(String(format: "%.2f", mainDoor.width))m)",
                    detail: String(format: "入户门开间度量合鲁班门光尺【%@】字门，迎祥纳福，广纳正气生机。", eval.yangSegmentName),
                    fengshuiLore: "鲁班先师制尺定度，八寸循环纳吉，门吉则气正。",
                    solution: "大门尺寸得吉，宜保持玄关整洁明亮，门前不堆杂物，使吉气源源入户。",
                    coordinate: mainDoor.position
                ))
                score += 5
            } else {
                shaItems.append(HouseSpatialShaItem(
                    title: "鲁班门光尺 · 大门失度",
                    severity: .warning,
                    locationName: "入户大门 (宽 \(String(format: "%.2f", mainDoor.width))m)",
                    detail: String(format: "大门宽度落入鲁班门光尺【%@】凶度字门，门气略有亏耗。", eval.yangSegmentName),
                    fengshuiLore: "门不合度，气散难聚。",
                    solution: "可于入户门槛下方安置六帝钱或开运地垫，在精神尺寸上进行微调化解。",
                    coordinate: mainDoor.position
                ))
                score -= 4
            }
        }

        // H. 户型规整度与开间进深比
        if dimensions.aspectRatio > 2.2 {
            shaItems.append(HouseSpatialShaItem(
                title: "户型狭长 (深长损明)",
                severity: .warning,
                locationName: "整体户型轮廓",
                detail: String(format: "全屋进深是开间的 %.1f 倍，形如长巷，中段采光通风弱，阴阳气流失衡。", dimensions.aspectRatio),
                fengshuiLore: "方正者气厚，狭长者气薄。",
                solution: "室内中部走道采用镜面扩容与明亮照明，多设绿植增补生旺之气。",
                coordinate: centroid
            ))
            score -= 6
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
            fengshuiScore: score
        )
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
