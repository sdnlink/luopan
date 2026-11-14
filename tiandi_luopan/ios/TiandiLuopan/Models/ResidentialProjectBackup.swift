import Foundation
import CoreGraphics
import simd

/// Public project format contains geometry only; legacy purchase grants,
/// personal profiles, remedies and audit scores stay out of shared files.
struct ResidentialProjectBackup: Codable {
    let format: String
    let version: Int
    let id: String
    let title: String
    let createdAt: Date
    let plan: Plan
    let measuredModel: ResidentialSurveyGeometry?
    let manualModel: ResidentialSurveyGeometry?
    let imageData: Data?

    struct Room: Codable {
        let id: String
        let name: String
        let type: FloorplanRoomType
        let rect: CGRect
        let polygon: [CGPoint]?
        init(_ room: FloorplanRoom) {
            id = room.id; name = room.name; type = room.type; rect = room.rect; polygon = room.polygonPoints
        }
        var restored: FloorplanRoom {
            FloorplanRoom(id: id, name: name, type: type, rect: rect, polygonPoints: polygon, inspectionLevel: "")
        }
    }
    struct Plan: Codable {
        let rooms: [Room]
        let widthMeters: Double?
        let depthMeters: Double?
        let coordinateHeading: Double
        let mapping: FloorplanSurveyMapping?
        var estimateSettings: ResidentialEstimateSettings? = nil
        init(_ layout: SavedFloorplanLayout) {
            rooms = ResidentialGeometry.clean(layout.rooms).map(Room.init)
            widthMeters = layout.widthMeters; depthMeters = layout.depthMeters
            coordinateHeading = layout.compassRotation; mapping = layout.surveyMapping
            estimateSettings = layout.estimateSettings
        }
        var restored: SavedFloorplanLayout {
            SavedFloorplanLayout(rooms: rooms.map(\.restored), centroidX: 0.5, centroidY: 0.5,
                compassRotation: coordinateHeading, isSyncWithCompass: false, hasFloorplanAccess: false,
                floorplanAccessGrantID: nil, floorplanAccessGrantSignature: nil,
                aspectRatio: widthMeters.flatMap { w in depthMeters.flatMap { $0 > 0 ? w / $0 : nil } },
                widthMeters: widthMeters, depthMeters: depthMeters, surveyMapping: mapping, familyRoomAssignments: [],
                estimateSettings: estimateSettings)
        }
    }
    init(record: FloorplanCaseRecord, imageData: Data?) {
        format = "residential-space-project"; version = 2
        id = record.id; title = record.title; createdAt = record.createdAt
        plan = Plan(record.layout)
        measuredModel = record.spatialSurvey.map(ResidentialSurveyGeometry.init)
        manualModel = record.virtualSpatialSurvey.map(ResidentialSurveyGeometry.init)
        self.imageData = imageData
    }
    func restored() throws -> FloorplanCaseRecord {
        guard format == "residential-space-project", version == 2 else { throw CocoaError(.fileReadCorruptFile) }
        try measuredModel?.validate()
        try manualModel?.validate()
        return FloorplanCaseRecord(id: id, title: title, createdAt: createdAt, sittingSummary: "", layout: plan.restored,
            spatialSurvey: measuredModel?.restored, virtualSpatialSurvey: manualModel?.restored, backupImageData: imageData)
    }
    static func validate(_ record: FloorplanCaseRecord) throws {
        let layout = record.layout
        guard layout.estimateSettings?.isValid ?? true else { throw CocoaError(.fileReadCorruptFile) }
        guard layout.rooms.count <= 200, Set(layout.rooms.map(\.id)).count == layout.rooms.count,
              layout.compassRotation.isFinite, layout.rooms.allSatisfy({ room in
                  !room.id.isEmpty && room.rect.origin.x.isFinite && room.rect.origin.y.isFinite
                    && room.rect.width.isFinite && room.rect.height.isFinite && room.rect.width > 0 && room.rect.height > 0
                    && (room.polygonPoints.map { points in
                        (3...128).contains(points.count) && points.allSatisfy { $0.x.isFinite && $0.y.isFinite }
                    } ?? true)
              }), [layout.widthMeters, layout.depthMeters].allSatisfy({ $0.map { $0.isFinite && (0.5...200).contains($0) } ?? true }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        for survey in [record.spatialSurvey, record.virtualSpatialSurvey].compactMap({ $0 }) {
            try ResidentialSurveyGeometry(survey).validate()
        }
    }
}

struct ResidentialSurveyGeometry: Codable {
    struct Opening: Codable {
        let id: UUID
        let type: SpatialOpeningType
        let position: [Float]
        let normal: [Float]
        let width: Float
        let height: Float
        init(_ item: SpatialOpening3D) {
            id = item.id; type = item.type; position = [item.posX, item.posY, item.posZ]
            normal = [item.normalX, item.normalY, item.normalZ]; width = item.width; height = item.height
        }
        var restored: SpatialOpening3D? {
            guard position.count == 3, normal.count == 3 else { return nil }
            return SpatialOpening3D(id: id, type: type, position: SIMD3(position[0], position[1], position[2]),
                normal: SIMD3(normal[0], normal[1], normal[2]), width: width, height: height)
        }
    }
    let id: UUID
    let timestamp: Date
    let source: String
    let coordinateHeading: Double
    let walls: [SpatialWall3D]
    let openings: [Opening]
    let beams: [SpatialBeam3D]
    let rooms: [SpatialRoom3D]
    let objects: [SpatialObject3D]
    init(_ survey: HouseSpatialSurvey) {
        id = survey.id; timestamp = survey.timestamp; source = survey.scanMethod; coordinateHeading = survey.compassHeading
        walls = survey.walls; openings = survey.openings.map(Opening.init); beams = survey.beams
        rooms = survey.rooms.filter { $0.type != .missingCorner }; objects = survey.objects
    }
    func validate() throws {
        guard rooms.count <= 200, walls.count <= 5000, openings.count <= 2000, beams.count <= 2000,
              objects.count <= 5000, coordinateHeading.isFinite,
              rooms.allSatisfy({ $0.sizeX > 0 && $0.sizeY > 0 && $0.sizeZ > 0 }),
              openings.allSatisfy({ $0.position.count == 3 && $0.normal.count == 3 && $0.width > 0 && $0.height > 0 }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var scalars: [Float] = []
        for w in walls { scalars += [w.startX, w.startY, w.startZ, w.endX, w.endY, w.endZ, w.height, w.thickness] }
        for r in rooms { scalars += [r.centerX, r.centerY, r.centerZ, r.sizeX, r.sizeY, r.sizeZ, r.areaSqMeters, r.rotationY ?? 0] }
        for o in openings { scalars += o.position + o.normal + [o.width, o.height] }
        for b in beams { scalars += [b.startX, b.startY, b.startZ, b.endX, b.endY, b.endZ, b.clearanceHeight, b.beamDepth, b.beamWidth] }
        for o in objects { scalars += [o.posX, o.posY, o.posZ, o.sizeX, o.sizeY, o.sizeZ, o.rotationY ?? 0] }
        guard scalars.allSatisfy({ $0.isFinite && abs($0) < 100000 }) else { throw CocoaError(.fileReadCorruptFile) }
    }
    var restored: HouseSpatialSurvey {
        HouseSpatialSurveyEngine.analyzeSpatialHouse(scanMethod: source, walls: walls, openings: openings.compactMap(\.restored),
            beams: beams, rooms: rooms, objects: objects, compassHeading: coordinateHeading, analysisDate: timestamp, surveyID: id)
    }
}
