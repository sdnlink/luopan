import Foundation
import CoreGraphics
import simd

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
        func roomCorners(_ r: SpatialRoom3D) -> [SIMD2<Float>] {
            let hx = r.sizeX * 0.5
            let hz = r.sizeZ * 0.5
            return [
                SIMD2<Float>(r.centerX - hx, r.centerZ - hz),
                SIMD2<Float>(r.centerX + hx, r.centerZ - hz),
                SIMD2<Float>(r.centerX + hx, r.centerZ + hz),
                SIMD2<Float>(r.centerX - hx, r.centerZ + hz)
            ]
        }

        // 房间在房屋局部坐标系的 AABB → 全屋真实开间/进深（OBB 跨度）
        var lMinX: Float = .greatestFiniteMagnitude
        var lMaxX: Float = -.greatestFiniteMagnitude
        var lMinZ: Float = .greatestFiniteMagnitude
        var lMaxZ: Float = -.greatestFiniteMagnitude
        for room in rooms {
            for corner in roomCorners(room) {
                let lc = toLocal(corner)
                lMinX = min(lMinX, lc.x); lMaxX = max(lMaxX, lc.x)
                lMinZ = min(lMinZ, lc.y); lMaxZ = max(lMaxZ, lc.y)
            }
        }
        var obbUsable = lMinX < lMaxX && lMinZ < lMaxZ
        if !obbUsable {
            // 无房间几何时退回墙端点局部包围盒
            for w in walls {
                for corner in [SIMD2<Float>(w.startX, w.startZ), SIMD2<Float>(w.endX, w.endZ)] {
                    let lc = toLocal(corner)
                    lMinX = min(lMinX, lc.x); lMaxX = max(lMaxX, lc.x)
                    lMinZ = min(lMinZ, lc.y); lMaxZ = max(lMaxZ, lc.y)
                }
            }
            obbUsable = lMinX < lMaxX && lMinZ < lMaxZ
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
        if roomAreaRatio < 0.75, let largest = rooms.max(by: { $0.areaSqMeters < $1.areaSqMeters }) {
            cx = largest.centerX
            cz = largest.centerZ
            isCentroidIndirect = true
        }
        let centroid = SIMD3<Float>(cx, 0.0, cz)

        // 4. 全屋形煞体检核心逻辑
        var shaItems: [HouseSpatialShaItem] = []
        var score = 92

        // A. 中宫受污检测 —— 在房屋局部坐标系划分九宫中宫盒 (OBB 九宫)，避免斜房切片
        let centerBoxMinX = lCx - lSpanX / 6.0
        let centerBoxMaxX = lCx + lSpanX / 6.0
        let centerBoxMinZ = lCz - lSpanZ / 6.0
        let centerBoxMaxZ = lCz + lSpanZ / 6.0

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
                    shaItems.append(HouseSpatialShaItem(
                        title: "开门见灶 (财气多耗)",
                        severity: .critical,
                        locationName: "入户大门 ⟷ 厨灶",
                        detail: String(format: "入户门开启正对厨房炉灶 (间距 %.1f 米)，大门纳入门气直冲灶火，主财气虚耗、存蓄不丰。", dist),
                        fengshuiLore: "《阳宅集成》云：'开门见灶，钱财多耗'。灶为一家食禄之源，宜藏不宜露。",
                        solution: "在大门与厨房之间设置玄关柜或挂隔断门帘，平时厨房推拉门常闭以避穿冲。",
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
                    shaItems.append(HouseSpatialShaItem(
                        title: "开门见厕 (秽气迎门)",
                        severity: .warning,
                        locationName: "入户大门 ⟷ 卫生间",
                        detail: String(format: "大门入口正冲卫生间 (间距 %.1f 米)，外来吉气甫入宅即染污秽，主家运退窒、招惹小人。", dist),
                        fengshuiLore: "《八宅明镜》云：'门为气口，厕乃浊泉；气口冲浊，福禄散亡'。",
                        solution: "卫生间门加装闭门器保持常闭，悬挂过膝半透布帘，门内放置水种阔叶绿植净化浊气。",
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
                        title: "厨厕同壁 (水火相战)",
                        severity: .warning,
                        locationName: "厨房 ⟷ 卫生间相隔",
                        detail: "厨房灶台居所与卫生间共用一面实体隔墙，坎水逼近离火，易致家人脾胃不适、情绪焦躁。",
                        fengshuiLore: "孤阳燥火与独阴浊水共处一壁，冷热相激，阴阳失和。",
                        solution: "灶台与马桶避免贴在同一面隔墙的正反两侧，墙面采用土黄色瓷砖以'土'通关化解。",
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
                shaItems.append(HouseSpatialShaItem(
                    title: "床头悬空 (靠山虚浮)",
                    severity: .warning,
                    locationName: "卧床周围空间",
                    detail: String(format: "卧床四周远离实体承重墙 (最近墙体 %.1f 米)，床头悬空无依，主睡眠不实、事业贵人缺乏。", minDistToWall),
                    fengshuiLore: "《撼龙经》云：'人有靠则安，床有靠则稳'。床头紧贴实墙方有踏实依靠。",
                    solution: "将床头移位紧贴实墙；若户型限制无法移位，可加装高大厚实的实木靠背板作人造靠山。",
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
                shaItems.append(HouseSpatialShaItem(
                    title: "暗室无窗 (孤阴凝滞)",
                    severity: .warning,
                    locationName: br.name,
                    detail: "卧室内缺乏采光外窗，自然光线与空气对流匮乏，久居阴气偏盛，易感神疲乏力。",
                    fengshuiLore: "《疑龙经》云：'无窗则气闭，阴盛则阳衰'。起居之所当见曦光，阴阳交泰。",
                    solution: "房门上方加装透光玻璃气窗或百叶排风，室内增加全光谱暖白照明，摆放开光黄玉聚阳阵。",
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
                if room.type == .bathroom && (item.star == .shengQi || item.star == .yanNian || item.star == .tianYi) {
                    shaItems.append(HouseSpatialShaItem(
                        title: "吉位落水 (污秽吉星)",
                        severity: .critical,
                        locationName: "\(room.name) · 落于【\(item.star.name)】大吉方",
                        detail: String(format: "卫生间落在全屋八宅【%@】大吉方，吉星被浊水浸润，易减损屋主财官运势与健康气运。", item.star.name),
                        fengshuiLore: "《八宅明镜》云：'吉星落厕，吉亦成殃'。生气延年宜作卧房书斋，不宜落水。",
                        solution: "卫生间马桶上方摆放一盆金边虎尾兰以木吸水，挂置开光纯铜葫芦收敛秽气护持吉星。",
                        coordinate: room.center
                    ))
                    score -= 12
                } else if (room.type == .masterBedroom || room.type == .secondBedroom) && (item.star == .tianYi || item.star == .yanNian || item.star == .shengQi) {
                    shaItems.append(HouseSpatialShaItem(
                        title: "卧房得位 (吉星拱照)",
                        severity: .auspicious,
                        locationName: "\(room.name) · 居【\(item.star.name)】方",
                        detail: String(format: "卧房安于全屋八宅【%@】吉位，居之安稳祥和、身心康泰、纳吉迎祥。", item.star.name),
                        fengshuiLore: "《阳宅三要》云：'门主灶配，吉星得位，富贵双全'。",
                        solution: "吉位得宜，床头朝向顺合吉方，保持室内整洁明亮即可长保吉运。",
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

            // 1. 五黄大煞 (5) 临门或临床
            if palace.facingStar == 5 || palace.mountainStar == 5 {
                for door in mainDoors {
                    let dRelX = door.posX - cx
                    let dRelZ = door.posZ - cz
                    let dAngle = (atan2(Double(dRelX), Double(-dRelZ)) * 180.0 / Double.pi + compassHeading + 360.0).truncatingRemainder(dividingBy: 360.0)
                    if guaForAngle(dAngle) == pGua {
                        shaItems.append(HouseSpatialShaItem(
                            title: "玄空理气煞 · 五黄到门",
                            severity: .critical,
                            locationName: "入户大门 · 逢【五黄大煞】",
                            detail: String(format: "玄空飞星五黄廉贞大煞飞临大门%@宫 (山向 %d-%d)，门动则煞动，易招滞涩阻碍。", palace.palaceName, palace.mountainStar, palace.facingStar),
                            fengshuiLore: "《玄空秘旨》云：'五黄为毒药，动则招灾'。五黄到门宜化不宜克。",
                            solution: "玄关处悬挂纯铜六字真言风铃或安忍水，以六白金气泄化五黄土煞，忌铺红地毯。",
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
                            title: "玄空理气煞 · 五黄加枕",
                            severity: .critical,
                            locationName: "卧床枕位 · 逢【五黄星】",
                            detail: String(format: "卧床枕位位于玄空五黄大煞飞临之%@宫，久眠易感神疲力绌。", palace.palaceName),
                            fengshuiLore: "《紫白诀》云：'五黄重叠，灾疾并临'。",
                            solution: "床位微调避开五黄正对方位，床头柜放置天然纯铜葫芦化解土煞。",
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
                        shaItems.append(HouseSpatialShaItem(
                            title: "玄空理气煞 · 病符临卧",
                            severity: .warning,
                            locationName: "\(br.name) · 逢【二黑病符】",
                            detail: String(format: "%@坐落于二黑巨门病符星飞临之%@宫 (山向 %d-%d)，久居易致脾胃失调。", br.name, palace.palaceName, palace.mountainStar, palace.facingStar),
                            fengshuiLore: "《飞星赋》云：'二黑逢五，病生胸腹'。二黑主阴浊病符。",
                            solution: "卧房悬挂天然开光晒干葫芦或六帝钱以金泄土，室内避免大红厚毯。",
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
                            title: "玄空旺星纳气 (财路亨通)",
                            severity: .auspicious,
                            locationName: "入户大门 · 逢【当旺向星】",
                            detail: String(format: "入户门迎当前%d运当旺向星飞临%@宫 (山向 %d-%d)，门迎旺气，大旺家业财帛。", curPeriod, palace.palaceName, palace.mountainStar, palace.facingStar),
                            fengshuiLore: "《天玉经》云：'向首一星灾福柄，当旺乘时发万箱'。",
                            solution: "门厅保持明堂整洁开阔，设暖白长明灯引气入宅，生旺气场。",
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
                shaItems.append(HouseSpatialShaItem(
                    title: "玄空出卦 · 空亡破局煞",
                    severity: .critical,
                    locationName: "入户大门 · \(kwLevel.localizedTitle)",
                    detail: isMajor
                        ? String(format: "大门朝向 %.1f° 正踏八卦大卦交界缝（大空亡绝线），五行错乱、阴阳差错，下卦排盘失效，必须以【替卦】重起九宫，属理气极凶出线。", compassHeading)
                        : (isSmall
                            ? String(format: "大门朝向 %.1f° 贴近同宫两山交界（小空亡出卦），气杂不纯、阴差阳错，须以【兼向替卦】排盘化解。", compassHeading)
                            : String(format: "大门朝向 %.1f° 处于兼向（替卦）区间，气场微杂驳纯，建议按替卦挨星排盘校验旺衰。", compassHeading)),
                    fengshuiLore: "堪舆古训：'出卦差错出孤寡，空亡线遇鬼神惊'。正针气场已乱，须以沈氏玄空替卦诀重排九宫飞星。",
                    solution: isMajor
                        ? "此线极凶，宜用实测罗盘复核坐向，优先整体挪门或以玄关斜向引气避开绝线；理气按【三元九运·替卦排盘】断验，忌择此线动土安门。"
                        : (isSmall
                            ? "玄关/门厅设斜向过渡区导气，理气按【三元九运·替卦排盘】校验旺衰，择吉时安门更佳。"
                            : "玄关加设门帘缓气，理气按【三元九运·替卦排盘】校验旺衰即可。"),
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
            s += "40\n0.30\n1\n\(room.name) \(String(format: "%.1f", room.areaSqMeters))m2\n"
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
        // 全屋净距（OBB 跨度值为真实开间/进深，绘图坐标仍取世界系）
        appendAlignedDim(minX, -minZ, maxX, -minZ, "全屋开间 \(String(format: "%.2f", lSpanX))m")
        appendAlignedDim(minX, -maxZ, maxX, -maxZ, "全屋开间 \(String(format: "%.2f", lSpanX))m")
        appendAlignedDim(minX, -minZ, minX, -maxZ, "全屋进深 \(String(format: "%.2f", lSpanZ))m")
        appendAlignedDim(maxX, -minZ, maxX, -maxZ, "全屋进深 \(String(format: "%.2f", lSpanZ))m")
        // 主要房间净距
        for r in rooms.sorted(by: { $0.areaSqMeters > $1.areaSqMeters }).prefix(3) {
            let rMinX = r.centerX - r.sizeX * 0.5
            let rMaxX = r.centerX + r.sizeX * 0.5
            let rMinZ = r.centerZ - r.sizeZ * 0.5
            let rMaxZ = r.centerZ + r.sizeZ * 0.5
            appendAlignedDim(rMinX, -rMinZ, rMaxX, -rMinZ, "\(r.name)开间 \(String(format: "%.2f", r.sizeX))m")
            appendAlignedDim(rMinX, -rMaxZ, rMaxX, -rMaxZ, "\(r.name)开间 \(String(format: "%.2f", r.sizeX))m")
            appendAlignedDim(rMinX, -rMinZ, rMinX, -rMaxZ, "\(r.name)进深 \(String(format: "%.2f", r.sizeZ))m")
            appendAlignedDim(rMaxX, -rMinZ, rMaxX, -rMaxZ, "\(r.name)进深 \(String(format: "%.2f", r.sizeZ))m")
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
