import SwiftUI
import UIKit
import simd

#if canImport(RoomPlan)
import RoomPlan
#endif

#if canImport(RoomPlan)

@available(iOS 16.0, *)
private func stopRoomCaptureSession(_ session: RoomCaptureSession) {
    if #available(iOS 17.0, *) {
        session.stop(pauseARSession: true)
    } else {
        session.stop()
    }
}

@available(iOS 16.0, *)
public final class ARRoomPlanModel: NSObject, ObservableObject, RoomCaptureSessionDelegate {
    @Published public private(set) var wallCount = 0
    @Published public private(set) var doorCount = 0
    @Published public private(set) var windowCount = 0
    @Published public private(set) var openingCount = 0
    @Published public private(set) var objectCount = 0
    @Published public private(set) var estimatedWidthMeters: Float = 0
    @Published public private(set) var estimatedDepthMeters: Float = 0
    @Published public private(set) var estimatedAreaSqMeters: Float = 0
    @Published public private(set) var scannedRoomCount = 0
    @Published public private(set) var spatialFindings: [String] = []
    @Published public private(set) var currentSpatialSurvey: HouseSpatialSurvey?
    @Published public private(set) var isCapturing = false
    @Published public private(set) var didFinish = false
    @Published public private(set) var errorMessage: String?
    /// 结算页罗盘校准旋钮产生的朝向微调量（度），叠加到 initialCompassHeading 上
    @Published public var headingOffsetDegrees: Double = 0.0
    /// 当前生效的大门朝向（初始罗盘读数 + 用户校准微调），供结算页展示
    public var effectiveHeadingForDisplay: Double {
        let h = (initialCompassHeading + headingOffsetDegrees).truncatingRemainder(dividingBy: 360.0)
        return h >= 0 ? h : h + 360.0
    }

    private weak var captureView: RoomCaptureView?
    private var latestRoom: CapturedRoom?
    private var capturedRoomsHistory: [CapturedRoom] = []
    private var initialCompassHeading: Double = 0.0
    private let roomBuilder = RoomBuilder(options: [.beautifyObjects])

    private var activeRooms: [CapturedRoom] {
        if isCapturing, let current = latestRoom {
            return capturedRoomsHistory + [current]
        }
        if !capturedRoomsHistory.isEmpty {
            return capturedRoomsHistory
        }
        return latestRoom.map { [$0] } ?? []
    }

    /// Reports are user-created exports. Keep them in the app's support
    /// directory instead of `temporaryDirectory`, which iOS may purge while
    /// the share sheet is still open or as soon as the app is suspended.
    private static func reportDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ARRoomPlanExportError.storageUnavailable
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

    /// Room reports are exported for sharing and can be generated repeatedly
    /// during a survey. Retain a small rolling history so abandoned exports
    /// cannot grow the app's support directory forever.
    private static func pruneReports(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        var reports = files.filter {
            ($0.pathExtension == "json" || $0.pathExtension == "usdz") &&
            $0.lastPathComponent.hasPrefix("TianJiYanXiang-RoomPlan-")
        }
        .compactMap { url -> (url: URL, date: Date, size: Int)? in
            guard let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                  let date = values.creationDate,
                  let size = values.fileSize else { return nil }
            return (url, date, size)
        }
        .sorted { $0.date < $1.date }
        let maxFiles = 24
        let maxBytes = 40 * 1024 * 1024
        var totalBytes = reports.reduce(0) { $0 + $1.size }
        while reports.count > maxFiles || totalBytes > maxBytes {
            guard let oldest = reports.first else { break }
            try? FileManager.default.removeItem(at: oldest.url)
            totalBytes -= oldest.size
            reports.removeFirst()
        }
    }

    public func attach(to view: RoomCaptureView) {
        captureView = view
        view.captureSession.delegate = self
        latestRoom = nil
        capturedRoomsHistory.removeAll()
        scannedRoomCount = 0
        initialCompassHeading = CompassMotionManager.shared.headingState.facingAngle
        estimatedWidthMeters = 0
        estimatedDepthMeters = 0
        estimatedAreaSqMeters = 0
        isCapturing = true
        didFinish = false
        errorMessage = nil
        view.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    public func startNextRoomSegment() {
        guard let view = captureView, !isCapturing else { return }
        latestRoom = nil
        isCapturing = true
        didFinish = false
        errorMessage = nil
        view.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    public func finishCurrentRoomSegment() {
        if let session = captureView?.captureSession {
            stopRoomCaptureSession(session)
        }
    }

    public func stop() {
        if let session = captureView?.captureSession {
            stopRoomCaptureSession(session)
        }
        captureView = nil
        isCapturing = false
    }

    public func saveSemanticReport() -> Result<[URL], Error> {
        let rooms = activeRooms
        guard didFinish, !rooms.isEmpty else {
            return .failure(ARRoomPlanExportError.captureNotFinished)
        }
        do {
            let directory = try Self.reportDirectory()
            let exportID = UUID().uuidString
            var exportedURLs: [URL] = []

            let surfaceToDict: (CapturedRoom.Surface) -> [String: Any] = { surface in
                let pos = surface.transform.columns.3
                return [
                    "id": surface.identifier.uuidString,
                    "width": Double(surface.dimensions.x),
                    "height": Double(surface.dimensions.y),
                    "depth": Double(surface.dimensions.z),
                    "position": [Double(pos.x), Double(pos.y), Double(pos.z)]
                ]
            }
            let objectToDict: (CapturedRoom.Object) -> [String: Any] = { object in
                let pos = object.transform.columns.3
                return [
                    "id": object.identifier.uuidString,
                    "category": String(describing: object.category),
                    "width": Double(object.dimensions.x),
                    "height": Double(object.dimensions.y),
                    "depth": Double(object.dimensions.z),
                    "position": [Double(pos.x), Double(pos.y), Double(pos.z)]
                ]
            }

            let allWalls = rooms.flatMap { $0.walls }
            let allDoors = rooms.flatMap { $0.doors }
            let allWindows = rooms.flatMap { $0.windows }
            let allOpenings = rooms.flatMap { $0.openings }
            let allObjects = rooms.flatMap { $0.objects }

            let payload: [String: Any] = [
                "source": "RoomPlan",
                "createdAt": ISO8601DateFormatter().string(from: Date()),
                "mergedRoomSegments": rooms.count,
                "walls": wallCount,
                "doors": doorCount,
                "windows": windowCount,
                "openings": openingCount,
                "objects": objectCount,
                "dimensionsMeters": [
                    "width": Double(estimatedWidthMeters),
                    "depth": Double(estimatedDepthMeters),
                    "areaSqMeters": Double(estimatedAreaSqMeters)
                ],
                "wallSurfaces": allWalls.map(surfaceToDict),
                "doorSurfaces": allDoors.map(surfaceToDict),
                "windowSurfaces": allWindows.map(surfaceToDict),
                "openingSurfaces": allOpenings.map(surfaceToDict),
                "detectedObjects": allObjects.map(objectToDict),
                "spatialFengshuiFindings": spatialFindings
            ]

            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            let jsonURL = directory.appendingPathComponent("TianJiYanXiang-RoomPlan-\(exportID).json")
            try data.write(to: jsonURL, options: .atomic)
            exportedURLs.append(jsonURL)

            if let room = rooms.last {
                let usdzURL = directory.appendingPathComponent("TianJiYanXiang-RoomPlan-\(exportID).usdz")
                if (try? room.export(to: usdzURL)) != nil {
                    exportedURLs.append(usdzURL)
                }
            }

            Self.pruneReports(in: directory)
            return .success(exportedURLs)
        } catch {
            return .failure(error)
        }
    }

    /// Converts the 3D CapturedRoom geometry (single or multi-room merged) into a 2D top-down
    /// architectural blueprint image and normalized `[FloorplanRoom]` blocks, then syncs them
    /// directly to Tab 3 (`FloorplanView`) for Nine-Palace / Eight-Mansions audit.
    public func syncToFloorplan() -> Bool {
        let rooms = activeRooms
        guard !rooms.isEmpty,
              let envelope = Self.compute2DEnvelope(for: rooms) else {
            return false
        }
        let spanX = max(0.5, envelope.maxX - envelope.minX)
        let spanZ = max(0.5, envelope.maxZ - envelope.minZ)
        let padding: Float = 0.10

        func normalizeRect(centerX: Float, centerZ: Float, width: Float, depth: Float) -> CGRect {
            let nx = CGFloat((centerX - envelope.minX) / spanX) * CGFloat(1.0 - 2 * padding) + CGFloat(padding)
            let ny = CGFloat((centerZ - envelope.minZ) / spanZ) * CGFloat(1.0 - 2 * padding) + CGFloat(padding)
            let nw = max(0.12, min(0.82, CGFloat(width / spanX) * CGFloat(1.0 - 2 * padding)))
            let nh = max(0.10, min(0.82, CGFloat(depth / spanZ) * CGFloat(1.0 - 2 * padding)))
            return CGRect(
                x: max(0.02, min(0.98 - nw, nx - nw / 2)),
                y: max(0.02, min(0.98 - nh, ny - nh / 2)),
                width: nw,
                height: nh
            )
        }

        var generatedRooms: [FloorplanRoom] = []
        let allDoors = rooms.flatMap { $0.doors }
        let allOpenings = rooms.flatMap { $0.openings }
        let allObjects = rooms.flatMap { $0.objects }
        let allWalls = rooms.flatMap { $0.walls }

        // 1. Map doors (or openings if no doors) to `.door` blocks
        let doorSurfaces = !allDoors.isEmpty ? allDoors : Array(allOpenings.prefix(1))
        for door in doorSurfaces.prefix(2) {
            let pos = door.transform.columns.3
            let rect = normalizeRect(
                centerX: pos.x,
                centerZ: pos.z,
                width: max(0.9, door.dimensions.x),
                depth: max(0.7, door.dimensions.z)
            )
            generatedRooms.append(FloorplanRoom(
                name: FloorplanRoomType.door.localizedName,
                type: .door,
                rect: rect
            ))
        }

        // 2. Map furniture objects into functional room zones
        var assignedTypes = Set<FloorplanRoomType>()
        for object in allObjects {
            let roomType: FloorplanRoomType?
            switch object.category {
            case .toilet, .bathtub:
                roomType = .bathroom
            case .stove, .refrigerator, .oven, .dishwasher:
                roomType = .kitchen
            case .bed:
                roomType = assignedTypes.contains(.masterBedroom) ? .secondBedroom : .masterBedroom
            case .sofa, .television, .fireplace:
                roomType = .livingRoom
            case .table, .storage:
                roomType = assignedTypes.contains(.livingRoom) ? .study : nil
            default:
                roomType = nil
            }
            guard let resolvedType = roomType, !assignedTypes.contains(resolvedType) else { continue }
            assignedTypes.insert(resolvedType)
            let pos = object.transform.columns.3
            let zoneW = max(1.8, object.dimensions.x * 1.8)
            let zoneD = max(1.8, object.dimensions.z * 1.8)
            let rect = normalizeRect(centerX: pos.x, centerZ: pos.z, width: zoneW, depth: zoneD)
            generatedRooms.append(FloorplanRoom(
                name: resolvedType.localizedName,
                type: resolvedType,
                rect: rect
            ))
        }

        // 3. Ensure at least a main living space is present if no furniture objects were classified
        if !assignedTypes.contains(.livingRoom) {
            let centerX = (envelope.minX + envelope.maxX) * 0.5
            let centerZ = (envelope.minZ + envelope.maxZ) * 0.5
            let mainRect = normalizeRect(
                centerX: centerX,
                centerZ: centerZ,
                width: spanX * 0.55,
                depth: spanZ * 0.55
            )
            generatedRooms.append(FloorplanRoom(
                name: FloorplanRoomType.livingRoom.localizedName,
                type: .livingRoom,
                rect: mainRect
            ))
        }

        // 4. Detect recessed/missing corners (.missingCorner) on L-shaped or notched layouts
        let polyMetrics = Self.computeWallPolygonMetrics(for: rooms)
        let boxArea = spanX * spanZ
        if allWalls.count >= 5,
           let poly = polyMetrics,
           poly.areaSqMeters > 1.0,
           poly.areaSqMeters < boxArea * 0.82 {
            let cornerGrid: [(col: Float, row: Float)] = [(0, 0), (2, 0), (0, 2), (2, 2)]
            for corner in cornerGrid {
                let cellMinX = envelope.minX + corner.col * (spanX / 3.0)
                let cellMaxX = cellMinX + (spanX / 3.0)
                let cellMinZ = envelope.minZ + corner.row * (spanZ / 3.0)
                let cellMaxZ = cellMinZ + (spanZ / 3.0)
                let hasCoverage = Self.hasSurfaceOrObjectInCell(
                    rooms: rooms,
                    minX: cellMinX,
                    maxX: cellMaxX,
                    minZ: cellMinZ,
                    maxZ: cellMaxZ
                )
                if !hasCoverage {
                    let cRect = normalizeRect(
                        centerX: (cellMinX + cellMaxX) * 0.5,
                        centerZ: (cellMinZ + cellMaxZ) * 0.5,
                        width: spanX * 0.24,
                        depth: spanZ * 0.24
                    )
                    generatedRooms.append(FloorplanRoom(
                        name: FloorplanRoomType.missingCorner.localizedName,
                        type: .missingCorner,
                        rect: cRect
                    ))
                }
            }
        }

        // 5. Compute geometric centroid (prefer PRD 6.7 wall-polygon Shoelace centroid, fallback to room area-weighted centroid)
        let centroid: CGPoint
        if let poly = polyMetrics {
            let nx = CGFloat((poly.centroidX - envelope.minX) / spanX) * CGFloat(1.0 - 2 * padding) + CGFloat(padding)
            let ny = CGFloat((poly.centroidZ - envelope.minZ) / spanZ) * CGFloat(1.0 - 2 * padding) + CGFloat(padding)
            centroid = CGPoint(x: max(0.15, min(0.85, nx)), y: max(0.15, min(0.85, ny)))
        } else {
            let validRooms = generatedRooms.filter { $0.rect.width > 0 && $0.rect.height > 0 }
            let totalArea = validRooms.reduce(CGFloat(0)) { $0 + $1.rect.width * $1.rect.height }
            if totalArea > 0 {
                let cx = validRooms.reduce(CGFloat(0)) { $0 + $1.rect.midX * ($1.rect.width * $1.rect.height) } / totalArea
                let cy = validRooms.reduce(CGFloat(0)) { $0 + $1.rect.midY * ($1.rect.width * $1.rect.height) } / totalArea
                centroid = CGPoint(x: max(0.15, min(0.85, cx)), y: max(0.15, min(0.85, cy)))
            } else {
                centroid = CGPoint(x: 0.5, y: 0.5)
            }
        }

        let resolvedHeading = resolvedDoorCompassHeading(for: rooms)
        let blueprint = Self.render2DBlueprintImage(rooms: rooms, envelope: envelope)
        FloorplanView.persistRoomPlanImport(
            rooms: generatedRooms,
            centroid: centroid,
            blueprintImage: blueprint,
            compassHeading: resolvedHeading,
            spatialSurvey: currentSpatialSurvey
        )
        return true
    }

    private func resolvedDoorCompassHeading(for rooms: [CapturedRoom]) -> Double? {
        let primaryDoor = rooms.flatMap({ $0.doors }).first ?? rooms.flatMap({ $0.openings }).first
        guard let door = primaryDoor else {
            return nil
        }
        let normal = door.transform.columns.2
        let normLen = hypot(normal.x, normal.z)
        guard normLen > 0.01 else { return nil }
        let localAngleDeg = Double(atan2(normal.x, -normal.z)) * 180.0 / .pi
        let raw = initialCompassHeading + localAngleDeg
        return (raw.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
    }

    /// Computes the true 2D floor polygon area and geometric centroid (PRD 6.7
    /// Shoelace formula) from the captured wall segments across all rooms.
    private static func computeWallPolygonMetrics(
        for rooms: [CapturedRoom]
    ) -> (areaSqMeters: Float, centroidX: Float, centroidZ: Float)? {
        let walls = rooms.flatMap { $0.walls }
        guard walls.count >= 3 else { return nil }
        var points: [SIMD2<Float>] = []
        for wall in walls {
            let c = wall.transform.columns.3
            let ax = wall.transform.columns.0
            let half = wall.dimensions.x * 0.5
            points.append(SIMD2<Float>(c.x - ax.x * half, c.z - ax.z * half))
            points.append(SIMD2<Float>(c.x + ax.x * half, c.z + ax.z * half))
        }
        guard points.count >= 3 else { return nil }
        let mean = points.reduce(SIMD2<Float>(0, 0), +) / Float(points.count)
        let sorted = points.sorted { a, b in
            atan2(a.y - mean.y, a.x - mean.x) < atan2(b.y - mean.y, b.x - mean.x)
        }
        var signedArea2: Float = 0
        var cxAccum: Float = 0
        var czAccum: Float = 0
        let n = sorted.count
        for i in 0..<n {
            let p0 = sorted[i]
            let p1 = sorted[(i + 1) % n]
            let cross = p0.x * p1.y - p1.x * p0.y
            signedArea2 += cross
            cxAccum += (p0.x + p1.x) * cross
            czAccum += (p0.y + p1.y) * cross
        }
        let area = abs(signedArea2) * 0.5
        guard area > 0.25, abs(signedArea2) > 0.001 else { return nil }
        let cx = cxAccum / (3.0 * signedArea2)
        let cz = czAccum / (3.0 * signedArea2)
        guard cx.isFinite, cz.isFinite else { return nil }
        return (area, cx, cz)
    }

    private static func hasSurfaceOrObjectInCell(
        rooms: [CapturedRoom],
        minX: Float,
        maxX: Float,
        minZ: Float,
        maxZ: Float
    ) -> Bool {
        let checkSurface: (CapturedRoom.Surface) -> Bool = { s in
            let c = s.transform.columns.3
            let ax = s.transform.columns.0
            let half = s.dimensions.x * 0.5
            let p1 = SIMD2<Float>(c.x - ax.x * half, c.z - ax.z * half)
            let p2 = SIMD2<Float>(c.x + ax.x * half, c.z + ax.z * half)
            let mid = SIMD2<Float>(c.x, c.z)
            for pt in [p1, mid, p2] {
                if pt.x >= minX && pt.x <= maxX && pt.y >= minZ && pt.y <= maxZ {
                    return true
                }
            }
            return false
        }
        for room in rooms {
            if room.walls.contains(where: checkSurface) { return true }
            if room.doors.contains(where: checkSurface) { return true }
            if room.windows.contains(where: checkSurface) { return true }
            for obj in room.objects {
                let c = obj.transform.columns.3
                if c.x >= minX && c.x <= maxX && c.z >= minZ && c.z <= maxZ {
                    return true
                }
            }
        }
        return false
    }

    private static func compute2DEnvelope(
        for rooms: [CapturedRoom]
    ) -> (minX: Float, maxX: Float, minZ: Float, maxZ: Float)? {
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        var hasPoint = false

        let includeSurface: (CapturedRoom.Surface) -> Void = { surface in
            let center = surface.transform.columns.3
            let axisX = surface.transform.columns.0
            let halfW = surface.dimensions.x * 0.5
            let dx = abs(axisX.x) * halfW + 0.08
            let dz = abs(axisX.z) * halfW + 0.08
            minX = min(minX, center.x - dx)
            maxX = max(maxX, center.x + dx)
            minZ = min(minZ, center.z - dz)
            maxZ = max(maxZ, center.z + dz)
            hasPoint = true
        }
        for room in rooms {
            room.walls.forEach(includeSurface)
            room.doors.forEach(includeSurface)
            room.windows.forEach(includeSurface)
            room.openings.forEach(includeSurface)
            for object in room.objects {
                let center = object.transform.columns.3
                let halfW = object.dimensions.x * 0.5
                let halfD = object.dimensions.z * 0.5
                minX = min(minX, center.x - halfW)
                maxX = max(maxX, center.x + halfW)
                minZ = min(minZ, center.z - halfD)
                maxZ = max(maxZ, center.z + halfD)
                hasPoint = true
            }
        }
        guard hasPoint, maxX > minX, maxZ > minZ else { return nil }
        return (minX, maxX, minZ, maxZ)
    }

    private static func render2DBlueprintImage(
        rooms: [CapturedRoom],
        envelope: (minX: Float, maxX: Float, minZ: Float, maxZ: Float)
    ) -> UIImage {
        let size = CGSize(width: 960, height: 960)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let spanX = max(0.5, envelope.maxX - envelope.minX)
        let spanZ = max(0.5, envelope.maxZ - envelope.minZ)
        let pad: CGFloat = 96.0
        let drawW = size.width - pad * 2
        let drawH = size.height - pad * 2

        let mapPoint: (Float, Float) -> CGPoint = { x, z in
            let nx = CGFloat((x - envelope.minX) / spanX)
            let nz = CGFloat((z - envelope.minZ) / spanZ)
            return CGPoint(x: pad + nx * drawW, y: pad + nz * drawH)
        }

        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            // Draw subtle metric grid
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.06).cgColor)
            cg.setLineWidth(1)
            for idx in 0...8 {
                let offset = pad + CGFloat(idx) * (drawW / 8.0)
                cg.move(to: CGPoint(x: offset, y: pad))
                cg.addLine(to: CGPoint(x: offset, y: size.height - pad))
                cg.move(to: CGPoint(x: pad, y: offset))
                cg.addLine(to: CGPoint(x: size.width - pad, y: offset))
            }
            cg.strokePath()

            let drawSurfaceSegment: (CapturedRoom.Surface, UIColor, CGFloat) -> Void = { surface, color, lineWidth in
                let center = surface.transform.columns.3
                let axisX = surface.transform.columns.0
                let halfLen = surface.dimensions.x * 0.5
                let p1 = mapPoint(center.x - axisX.x * halfLen, center.z - axisX.z * halfLen)
                let p2 = mapPoint(center.x + axisX.x * halfLen, center.z + axisX.z * halfLen)
                cg.setStrokeColor(color.cgColor)
                cg.setLineWidth(lineWidth)
                cg.setLineCap(.round)
                cg.move(to: p1)
                cg.addLine(to: p2)
                cg.strokePath()
            }

            // Walls, windows, doors across all merged rooms
            for room in rooms {
                for wall in room.walls {
                    drawSurfaceSegment(wall, UIColor(red: 0.85, green: 0.90, blue: 0.96, alpha: 0.95), 8.0)
                }
                for window in room.windows {
                    drawSurfaceSegment(window, UIColor(red: 0.0, green: 0.82, blue: 0.95, alpha: 0.95), 6.0)
                }
                for door in room.doors {
                    drawSurfaceSegment(door, UIColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 0.98), 7.0)
                }
                for opening in room.openings {
                    drawSurfaceSegment(opening, UIColor.systemGreen.withAlphaComponent(0.85), 5.0)
                }
            }

            // Dimension caption
            let dimText = String(format: "LiDAR RoomPlan (%d) · %.2f m × %.2f m (%.1f m²)", rooms.count, spanX, spanZ, spanX * spanZ)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor(red: 0.95, green: 0.85, blue: 0.45, alpha: 0.9)
            ]
            dimText.draw(at: CGPoint(x: pad, y: 34), withAttributes: attrs)
        }
    }

    private static func computeSpatialFengshuiFindings(for rooms: [CapturedRoom]) -> [String] {
        var findings: [String] = []
        let allDoors = rooms.flatMap { $0.doors }
        let allWindows = rooms.flatMap { $0.windows }
        let allObjects = rooms.flatMap { $0.objects }

        // 1. 入户门宽鲁班尺吉凶判定 (42.9cm 门光尺)
        if let mainDoor = allDoors.first, Float(mainDoor.dimensions.x) > 0.45 {
            let doorWidth = Float(mainDoor.dimensions.x)
            let eval = LubanRulerEvaluation.evaluate(meters: doorWidth)
            let badge = eval.yangIsAuspicious ? "吉门" : "失度"
            findings.append(String(format: "门宽 %.2fm · 鲁班尺【%@】(%@)", Double(doorWidth), eval.yangSegmentName, badge))
        }

        // 2. 穿堂风煞检测 (门对窗 / 门对门一箭穿心)
        for door in allDoors {
            let dPos = SIMD2<Float>(door.transform.columns.3.x, door.transform.columns.3.z)
            let dNormRaw = SIMD2<Float>(door.transform.columns.2.x, door.transform.columns.2.z)
            let normLen = simd_length(dNormRaw)
            guard normLen > 1e-4 else { continue }
            let dNorm = dNormRaw / normLen

            for win in allWindows {
                let wPos = SIMD2<Float>(win.transform.columns.3.x, win.transform.columns.3.z)
                let delta = wPos - dPos
                let dist = simd_length(delta)
                guard dist >= 1.8 && dist <= 12.0 else { continue }
                let dir = delta / dist
                let alignment = abs(simd_dot(dNorm, dir))
                let lateral = dist * sqrt(max(0, 1.0 - alignment * alignment))
                if alignment >= 0.88 && lateral <= 0.65 {
                    findings.append(String(format: "⚠️ 穿堂煞：门窗对冲直通 (间距 %.1fm)", dist))
                    break
                }
            }
            if findings.count >= 2 { break }
        }

        // 3. 房门冲床检测 (Door normal ray hitting Bed)
        let beds = allObjects.filter { $0.category == .bed }
        for door in allDoors {
            let dPos = SIMD2<Float>(door.transform.columns.3.x, door.transform.columns.3.z)
            let dNormRaw = SIMD2<Float>(door.transform.columns.2.x, door.transform.columns.2.z)
            let normLen = simd_length(dNormRaw)
            guard normLen > 1e-4 else { continue }
            let dNorm = dNormRaw / normLen
            for bed in beds {
                let bPos = SIMD2<Float>(bed.transform.columns.3.x, bed.transform.columns.3.z)
                let delta = bPos - dPos
                let dist = simd_length(delta)
                guard dist >= 0.8 && dist <= 4.8 else { continue }
                let alignment = abs(simd_dot(dNorm, delta / dist))
                let lateral = dist * sqrt(max(0, 1.0 - alignment * alignment))
                if alignment >= 0.85 && lateral <= 0.70 {
                    findings.append(String(format: "⚠️ 门冲床：房门直对卧床 (%.1fm)", dist))
                    break
                }
            }
        }

        // 4. 水火相冲检测 (厨灶与马桶卫浴过近)
        let stoves = allObjects.filter { $0.category == .stove || $0.category == .oven }
        let toilets = allObjects.filter { $0.category == .toilet || $0.category == .bathtub }
        for stove in stoves {
            let sPos = SIMD2<Float>(stove.transform.columns.3.x, stove.transform.columns.3.z)
            for toilet in toilets {
                let tPos = SIMD2<Float>(toilet.transform.columns.3.x, toilet.transform.columns.3.z)
                let dist = simd_distance(sPos, tPos)
                if dist <= 2.1 {
                    findings.append(String(format: "⚠️ 水火冲：厨灶与卫浴紧邻 (%.1fm)", dist))
                    break
                }
            }
        }

        return Array(findings.prefix(3))
    }

    public static func buildSpatialSurvey(from rooms: [CapturedRoom], heading: Double) -> HouseSpatialSurvey? {
        guard !rooms.isEmpty else { return nil }
        var walls3D: [SpatialWall3D] = []
        var openings3D: [SpatialOpening3D] = []
        var objects3D: [SpatialObject3D] = []
        var rooms3D: [SpatialRoom3D] = []
        var beams3D: [SpatialBeam3D] = []

        for room in rooms {
            for wall in room.walls {
                let c = wall.transform.columns.3
                let ax = wall.transform.columns.0
                let half = wall.dimensions.x * 0.5
                let start = SIMD3<Float>(c.x - ax.x * half, c.y - wall.dimensions.y * 0.5, c.z - ax.z * half)
                let end = SIMD3<Float>(c.x + ax.x * half, c.y - wall.dimensions.y * 0.5, c.z + ax.z * half)
                walls3D.append(SpatialWall3D(
                    start: start,
                    end: end,
                    height: wall.dimensions.y,
                    thickness: max(0.10, wall.dimensions.z),
                    isLoadBearing: false
                ))
            }

            for (idx, door) in room.doors.enumerated() {
                let pos = SIMD3<Float>(door.transform.columns.3.x, door.transform.columns.3.y, door.transform.columns.3.z)
                let norm = SIMD3<Float>(door.transform.columns.2.x, door.transform.columns.2.y, door.transform.columns.2.z)
                let isEntrance = (idx == 0 && rooms.first == room)
                openings3D.append(SpatialOpening3D(
                    type: isEntrance ? .entranceDoor : .interiorDoor,
                    position: pos,
                    normal: norm,
                    width: door.dimensions.x,
                    height: door.dimensions.y
                ))
            }

            for win in room.windows {
                let pos = SIMD3<Float>(win.transform.columns.3.x, win.transform.columns.3.y, win.transform.columns.3.z)
                let norm = SIMD3<Float>(win.transform.columns.2.x, win.transform.columns.2.y, win.transform.columns.2.z)
                let isBalcony = win.dimensions.y >= 1.9
                openings3D.append(SpatialOpening3D(
                    type: isBalcony ? .balconyDoor : .window,
                    position: pos,
                    normal: norm,
                    width: win.dimensions.x,
                    height: win.dimensions.y
                ))
            }

            for op in room.openings {
                let pos = SIMD3<Float>(op.transform.columns.3.x, op.transform.columns.3.y, op.transform.columns.3.z)
                let norm = SIMD3<Float>(op.transform.columns.2.x, op.transform.columns.2.y, op.transform.columns.2.z)
                openings3D.append(SpatialOpening3D(
                    type: .opening,
                    position: pos,
                    normal: norm,
                    width: op.dimensions.x,
                    height: op.dimensions.y
                ))
            }

            for obj in room.objects {
                let pos = SIMD3<Float>(obj.transform.columns.3.x, obj.transform.columns.3.y, obj.transform.columns.3.z)
                let size = SIMD3<Float>(obj.dimensions.x, obj.dimensions.y, obj.dimensions.z)
                let catStr = String(describing: obj.category)
                objects3D.append(SpatialObject3D(
                    category: catStr,
                    position: pos,
                    size: size
                ))
            }
        }

        var roomTypeSet = Set<FloorplanRoomType>()
        for obj in objects3D {
            let type: FloorplanRoomType?
            switch obj.category {
            case "bed":
                type = roomTypeSet.contains(.masterBedroom) ? .secondBedroom : .masterBedroom
            case "sofa", "television":
                type = .livingRoom
            case "stove", "oven", "refrigerator":
                type = .kitchen
            case "toilet", "bathtub":
                type = .bathroom
            case "table":
                type = roomTypeSet.contains(.livingRoom) ? .study : nil
            default:
                type = nil
            }
            if let t = type, !roomTypeSet.contains(t) {
                roomTypeSet.insert(t)
                rooms3D.append(SpatialRoom3D(
                    name: t.localizedName,
                    type: t,
                    center: obj.position,
                    size: SIMD3<Float>(max(2.5, obj.size.x * 2.0), 2.8, max(2.5, obj.size.z * 2.0))
                ))
            }
        }

        if roomTypeSet.isEmpty {
            // 毛坯房/空置房冷启动：无家具物象可分类时，按各房间包围盒面积降序启发式预判
            // （客厅 > 主卧 > 次卧 > 书房 > 卫浴 > 厨房），保证卧室/厨卫形煞可触发；
            // 用户可在 3D 查看器点击房间一键修正类型并即时刷新报告。
            let fallbackTypes: [FloorplanRoomType] = [.livingRoom, .masterBedroom, .secondBedroom, .study, .bathroom, .kitchen]
            let roomEnv = rooms.enumerated().compactMap { (_, r) -> (Float, Float, Float, Float)? in
                guard let env = Self.compute2DEnvelope(for: [r]) else { return nil }
                return (env.minX, env.maxX, env.minZ, env.maxZ)
            }
            .sorted { ($0.1 - $0.0) * ($0.3 - $0.2) > ($1.1 - $1.0) * ($1.3 - $1.2) }
            for (order, item) in roomEnv.enumerated() {
                let t = fallbackTypes[min(order, fallbackTypes.count - 1)]
                let (minX, maxX, minZ, maxZ) = item
                let w = max(1.5, maxX - minX)
                let d = max(1.5, maxZ - minZ)
                rooms3D.append(SpatialRoom3D(
                    name: t.localizedName,
                    type: t,
                    center: SIMD3<Float>((minX + maxX) * 0.5, 1.4, (minZ + maxZ) * 0.5),
                    size: SIMD3<Float>(w, 2.8, d)
                ))
            }
        } else if !roomTypeSet.contains(.livingRoom), let env = compute2DEnvelope(for: rooms) {
            let cx = (env.minX + env.maxX) * 0.5
            let cz = (env.minZ + env.maxZ) * 0.5
            let w = max(2.0, (env.maxX - env.minX) * 0.55)
            let d = max(2.0, (env.maxZ - env.minZ) * 0.55)
            rooms3D.append(SpatialRoom3D(
                name: FloorplanRoomType.livingRoom.localizedName,
                type: .livingRoom,
                center: SIMD3<Float>(cx, 1.4, cz),
                size: SIMD3<Float>(w, 2.8, d)
            ))
        }

        return HouseSpatialSurveyEngine.analyzeSpatialHouse(
            scanMethod: "LiDAR RoomPlan 测绘",
            walls: walls3D,
            openings: openings3D,
            beams: beams3D,
            rooms: rooms3D,
            objects: objects3D,
            compassHeading: heading
        )
    }

    private func updateMetrics(from room: CapturedRoom, commitToHistory: Bool = false) {
        let combined = capturedRoomsHistory + [room]
        let wallCount = combined.reduce(0) { $0 + $1.walls.count }
        let doorCount = combined.reduce(0) { $0 + $1.doors.count }
        let windowCount = combined.reduce(0) { $0 + $1.windows.count }
        let openingCount = combined.reduce(0) { $0 + $1.openings.count }
        let objectCount = combined.reduce(0) { $0 + $1.objects.count }
        let envelope = Self.compute2DEnvelope(for: combined)
        let width = envelope.map { max(0, $0.maxX - $0.minX) } ?? 0
        let depth = envelope.map { max(0, $0.maxZ - $0.minZ) } ?? 0
        let polyArea = Self.computeWallPolygonMetrics(for: combined)?.areaSqMeters
        let area = polyArea.map { min(width * depth, max(0.5, $0)) } ?? (width * depth)
        let findings = Self.computeSpatialFengshuiFindings(for: combined)
        let survey = Self.buildSpatialSurvey(from: combined, heading: initialCompassHeading + headingOffsetDegrees)
        if commitToHistory {
            // 仅在正式提交扫描房间时更新全景形煞档案的室内侧
            ShaSurveyStore.shared.updateInterior(survey)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.latestRoom = room
            if commitToHistory {
                self.capturedRoomsHistory.append(room)
                self.scannedRoomCount = self.capturedRoomsHistory.count
            } else {
                self.scannedRoomCount = max(1, self.capturedRoomsHistory.count + 1)
            }
            self.wallCount = wallCount
            self.doorCount = doorCount
            self.windowCount = windowCount
            self.openingCount = openingCount
            self.objectCount = objectCount
            self.estimatedWidthMeters = width
            self.estimatedDepthMeters = depth
            self.estimatedAreaSqMeters = area
            self.spatialFindings = findings
            self.currentSpatialSurvey = survey
        }
    }

    public func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        updateMetrics(from: room, commitToHistory: false)
    }

    /// 结算页罗盘校准旋钮回调：以实测罗盘度数为准微调大门朝向，立即重算报告并同步全景档案
    public func applyHeadingOffset(_ offsetDegrees: Double) {
        headingOffsetDegrees = offsetDegrees
        guard !capturedRoomsHistory.isEmpty else { return }
        let combined = capturedRoomsHistory
        let survey = Self.buildSpatialSurvey(from: combined, heading: initialCompassHeading + headingOffsetDegrees)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentSpatialSurvey = survey
            ShaSurveyStore.shared.updateInterior(survey)
        }
    }

    public func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isCapturing = false
                self.didFinish = !self.capturedRoomsHistory.isEmpty
                self.errorMessage = error.localizedDescription
            }
            return
        }
        Task { [weak self] in
            guard let self = self else { return }
            if let finalRoom = try? await self.roomBuilder.capturedRoom(from: data) {
                self.updateMetrics(from: finalRoom, commitToHistory: true)
            } else if let fallbackRoom = self.latestRoom {
                self.updateMetrics(from: fallbackRoom, commitToHistory: true)
            }
            #if canImport(RoomPlan)
            if #available(iOS 17.0, *), self.capturedRoomsHistory.count > 1 {
                let structureBuilder = StructureBuilder(options: [.beautifyObjects])
                _ = try? await structureBuilder.capturedStructure(from: self.capturedRoomsHistory)
            }
            #endif
            await MainActor.run {
                self.isCapturing = false
                self.didFinish = true
                self.errorMessage = nil
            }
        }
    }
}

@available(iOS 16.0, *)
private enum ARRoomPlanExportError: Error {
    case captureNotFinished
    case storageUnavailable
}

@available(iOS 16.0, *)
public struct ARRoomPlanPreviewView: UIViewRepresentable {
    @ObservedObject private var model: ARRoomPlanModel

    public init(model: ARRoomPlanModel) {
        self.model = model
    }

    public func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        model.attach(to: view)
        return view
    }

    public func updateUIView(_ uiView: RoomCaptureView, context: Context) {}

    public static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: ()) {
        stopRoomCaptureSession(uiView.captureSession)
    }
}

@available(iOS 16.0, *)
public struct ARRoomPlanSurveyView: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @StateObject private var model = ARRoomPlanModel()
    @Environment(\.presentationMode) private var presentationMode
    @State private var shareItem: ARRoomPlanShareItem?
    @State private var reportMessage: String?
    @State private var show3DViewer: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            ARRoomPlanPreviewView(model: model)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.t("ar_roomplan_title"))
                            .font(.adaptive(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text(model.isCapturing ? lang.t("ar_roomplan_scanning") : "\(lang.t("ar_roomplan_finished")) (\(max(1, model.scannedRoomCount)) 室)")
                            .font(.adaptive(size: 10, weight: .medium))
                            .foregroundColor(model.isCapturing ? .green : .orange)
                    }
                    Spacer()
                    if model.isCapturing {
                        Button(action: { model.finishCurrentRoomSegment() }) {
                            Image(systemName: "checkmark")
                                .font(.adaptive(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .padding(9)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(lang.t("ar_roomplan_finish"))
                    } else if model.didFinish {
                        Button(action: { model.startNextRoomSegment() }) {
                            Image(systemName: "plus.square.on.square")
                                .font(.adaptive(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .padding(9)
                                .background(Color.green.opacity(0.9))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("继续加扫下一间")
                        if model.currentSpatialSurvey != nil {
                            Button(action: { show3DViewer = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "cube.transparent")
                                        .font(.adaptive(size: 13, weight: .bold))
                                    Text("3D空间")
                                        .font(.adaptive(size: 10, weight: .bold))
                                }
                                .foregroundColor(.black)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(Color.yanGold)
                                .cornerRadius(14)
                            }
                            .accessibilityLabel("查看全屋3D空间布局与形煞")
                        }
                        // 大门朝向罗盘校准旋钮：以实测罗盘度数为准微调，立即刷新报告
                        VStack(spacing: 2) {
                            Text(String(format: "大门朝向 %.1f°", model.effectiveHeadingForDisplay))
                                .font(.adaptive(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            HStack(spacing: 3) {
                                Button(action: { model.applyHeadingOffset(model.headingOffsetDegrees - 5.0) }) {
                                    Text("−5°")
                                        .font(.adaptive(size: 9, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                }
                                Button(action: { model.applyHeadingOffset(model.headingOffsetDegrees - 1.0) }) {
                                    Text("−1°")
                                        .font(.adaptive(size: 9, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.85))
                                        .cornerRadius(8)
                                }
                                Button(action: { model.applyHeadingOffset(model.headingOffsetDegrees + 1.0) }) {
                                    Text("+1°")
                                        .font(.adaptive(size: 9, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.85))
                                        .cornerRadius(8)
                                }
                                Button(action: { model.applyHeadingOffset(model.headingOffsetDegrees + 5.0) }) {
                                    Text("+5°")
                                        .font(.adaptive(size: 9, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .accessibilityLabel("大门朝向罗盘校准旋钮")
                        Button(action: syncToFloorplan) {
                            Image(systemName: "scope")
                                .font(.adaptive(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .padding(9)
                                .background(Color.yanCyan)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(lang.t("tab_floorplan"))
                        Button(action: shareReport) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.adaptive(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(9)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(lang.t("ar_roomplan_share"))
                    }
                    Button(action: {
                        model.stop()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.adaptive(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(9)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(lang.t("ar_spatial_close"))
                }
                .padding(10)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding(.horizontal, 14)
                .padding(.top, 10)

                Spacer()

                VStack(alignment: .leading, spacing: 7) {
                    Text(lang.t("ar_roomplan_semantic_note"))
                        .font(.adaptive(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                    if model.estimatedAreaSqMeters > 0 {
                        Text(String(
                            format: "%.2f × %.2f m (%.1f m²)",
                            model.estimatedWidthMeters,
                            model.estimatedDepthMeters,
                            model.estimatedAreaSqMeters
                        ))
                        .font(.adaptive(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.yanCyan)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        semanticCount("ar_spatial_wall", value: model.wallCount, icon: "rectangle.portrait")
                        semanticCount("ar_spatial_door", value: model.doorCount, icon: "door.left.hand.open")
                        semanticCount("ar_spatial_window", value: model.windowCount, icon: "window.vertical.open")
                        semanticCount("ar_roomplan_opening", value: model.openingCount, icon: "rectangle.dashed")
                        semanticCount("ar_roomplan_object", value: model.objectCount, icon: "cube")
                    }
                    if !model.spatialFindings.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(model.spatialFindings, id: \.self) { finding in
                                Text(finding)
                                    .font(.adaptive(size: 10, weight: .bold))
                                    .foregroundColor(finding.contains("⚠️") ? .orange : .green)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                    }
                    if let error = model.errorMessage {
                        Text("\(lang.t("ar_roomplan_failed")): \(error)")
                            .font(.adaptive(size: 10))
                            .foregroundColor(.orange)
                    }
                    if let reportMessage = reportMessage {
                        Text(reportMessage)
                            .font(.adaptive(size: 10, weight: .semibold))
                            .foregroundColor(.yanCyan)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onDisappear { model.stop() }
        .sheet(item: $shareItem) { item in
            ARRoomPlanShareSheet(items: item.urls)
        }
        .sheet(isPresented: $show3DViewer) {
            if let survey = model.currentSpatialSurvey {
                House3DSpaceViewer(survey: survey)
            }
        }
    }

    private func syncToFloorplan() {
        if model.syncToFloorplan() {
            reportMessage = "\(lang.t("tab_floorplan")) · \(lang.t("save_success"))"
        } else {
            reportMessage = lang.t("ar_roomplan_report_unavailable")
        }
    }

    private func shareReport() {
        switch model.saveSemanticReport() {
        case .success(let urls):
            reportMessage = lang.t("ar_roomplan_report_ready")
            shareItem = ARRoomPlanShareItem(urls: urls)
        case .failure:
            reportMessage = lang.t("ar_roomplan_report_unavailable")
        }
    }

    private func semanticCount(_ key: String, value: Int, icon: String) -> some View {
        Label("\(lang.t(key)): \(value)", systemImage: icon)
            .font(.adaptive(size: 11, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 16.0, *)
private struct ARRoomPlanShareItem: Identifiable {
    let id = UUID()
    let urls: [URL]
}

@available(iOS 16.0, *)
private struct ARRoomPlanShareSheet: UIViewControllerRepresentable {
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

#endif
