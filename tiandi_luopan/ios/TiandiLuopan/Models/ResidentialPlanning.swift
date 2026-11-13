import Foundation
import CoreGraphics

/// Stored with the project, so opening a second plan cannot inherit deductions
/// or room selections from an unrelated property. Strings retain entered precision.
struct ResidentialEstimateSettings: Codable, Equatable {
    var selectedRoomIDs: [String]
    var wallHeight = "2.8"
    var waste = 10.0
    var packCoverage = "1.44"
    var openingArea = "0"
    var coats = 2
    var paintCoverage = "10"

    static func number(_ text: String) -> Double? {
        // Decimal keyboards can use a comma; grouping separators are not used.
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")), value.isFinite else { return nil }
        return value
    }
    var isValid: Bool {
        guard let height = Self.number(wallHeight), let pack = Self.number(packCoverage),
              let openings = Self.number(openingArea), let paint = Self.number(paintCoverage) else { return false }
        return (0.5...10).contains(height) && (0.01...100).contains(pack)
            && openings >= 0 && (0.1...50).contains(paint) && waste.isFinite
            && (0...50).contains(waste) && (1...5).contains(coats)
            && selectedRoomIDs.count <= 200 && Set(selectedRoomIDs).count == selectedRoomIDs.count
    }
    func estimate(metrics: ResidentialPlanMetrics) -> ResidentialMaterialEstimate? {
        guard metrics.canEstimate, isValid, let height = Self.number(wallHeight), let pack = Self.number(packCoverage),
              let openings = Self.number(openingArea), let paint = Self.number(paintCoverage) else { return nil }
        let selected = Set(selectedRoomIDs)
        return ResidentialMaterialEstimate(rooms: metrics.rooms.filter { selected.contains($0.id) },
            wallHeight: height, wastePercent: waste, packCoverage: pack, openingArea: openings, coats: coats, paintCoverage: paint)
    }
}

/// Geometry in metres. Door markers are not floor surfaces. Room totals are
/// deliberately not described as legal, gross or saleable property area.
struct ResidentialRoomMetric: Identifiable {
    let id: String
    let name: String
    let type: FloorplanRoomType
    let points: [CGPoint]
    let area: Double
    let perimeter: Double
    let triangles: [[CGPoint]]
    let bounds: CGRect
}

struct ResidentialPlanMetrics {
    let rooms: [ResidentialRoomMetric]
    let invalidRoomCount: Int
    let outsideRoomCount: Int
    let overlappingRoomIDs: Set<String>
    var totalArea: Double { rooms.reduce(0) { $0 + $1.area } }
    var totalPerimeter: Double { rooms.reduce(0) { $0 + $1.perimeter } }
    var canEstimate: Bool { !rooms.isEmpty && invalidRoomCount == 0 && outsideRoomCount == 0 && overlappingRoomIDs.isEmpty }

    init(layout: SavedFloorplanLayout) {
        guard let width = layout.widthMeters, let depth = layout.depthMeters,
              width.isFinite, depth.isFinite, (0.5...200).contains(width), (0.5...200).contains(depth), layout.rooms.count <= 200 else {
            rooms = []; invalidRoomCount = layout.rooms.count; outsideRoomCount = 0; overlappingRoomIDs = []
            return
        }
        var valid: [ResidentialRoomMetric] = []
        var invalid = 0
        var outside = 0
        for room in layout.rooms where room.type != .door && room.type != .missingCorner {
            let r = room.rect
            let normalized = room.polygonPoints ?? [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY),
                CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY)]
            guard (3...128).contains(normalized.count), normalized.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                invalid += 1; continue
            }
            let points = ResidentialPolygon.clean(normalized.map { CGPoint(x: Double($0.x) * width, y: Double($0.y) * depth) })
            guard points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
                  let triangles = ResidentialPolygon.triangulate(points) else { invalid += 1; continue }
            if normalized.contains(where: { $0.x < -0.000001 || $0.y < -0.000001 || $0.x > 1.000001 || $0.y > 1.000001 }) { outside += 1 }
            let perimeter = points.indices.reduce(0.0) { sum, i in
                let a = points[i], b = points[(i + 1) % points.count]
                return sum + hypot(Double(a.x - b.x), Double(a.y - b.y))
            }
            valid.append(ResidentialRoomMetric(id: room.id, name: room.name, type: room.type,
                points: points, area: abs(ResidentialPolygon.signedArea(points)), perimeter: perimeter,
                triangles: triangles, bounds: ResidentialPolygon.bounds(points)))
        }
        var overlaps: Set<String> = []
        for i in valid.indices {
            for j in valid.indices where j > i {
                let intersection = valid[i].bounds.intersection(valid[j].bounds)
                guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { continue }
                if ResidentialPolygon.overlapArea(valid[i].triangles, valid[j].triangles) > 0.0001 {
                    overlaps.insert(valid[i].id); overlaps.insert(valid[j].id)
                }
            }
        }
        rooms = valid; invalidRoomCount = invalid; outsideRoomCount = outside; overlappingRoomIDs = overlaps
    }
}

enum ResidentialPolygon {
    static func bounds(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    static func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        Double((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))
    }
    static func signedArea(_ points: [CGPoint]) -> Double {
        guard points.count >= 3 else { return 0 }
        return points.indices.reduce(0.0) { sum, i in
            let a = points[i], b = points[(i + 1) % points.count]
            return sum + Double(a.x * b.y - b.x * a.y) / 2
        }
    }
    static func clean(_ points: [CGPoint]) -> [CGPoint] {
        var result: [CGPoint] = []
        for p in points where result.last.map({ hypot($0.x - p.x, $0.y - p.y) > 1e-8 }) ?? true { result.append(p) }
        if let first = result.first, let last = result.last, hypot(first.x - last.x, first.y - last.y) < 1e-8 { result.removeLast() }
        var changed = true
        while changed && result.count > 3 {
            changed = false
            for i in result.indices {
                let a = result[(i + result.count - 1) % result.count], b = result[i], c = result[(i + 1) % result.count]
                let between = (b.x - a.x) * (b.x - c.x) + (b.y - a.y) * (b.y - c.y) <= 1e-10
                if abs(cross(a, b, c)) < 1e-10 && between {
                    result.remove(at: i); changed = true; break
                }
            }
        }
        return result
    }
    static func triangulate(_ input: [CGPoint]) -> [[CGPoint]]? {
        guard input.count >= 3, abs(signedArea(input)) > 1e-8 else { return nil }
        // Reject self-crossing paths rather than return plausible material quantities.
        for i in input.indices {
            for j in input.indices where j > i + 1 && !(i == 0 && j == input.count - 1) {
                let a = input[i], b = input[(i + 1) % input.count], c = input[j], d = input[(j + 1) % input.count]
                if cross(a, b, c) * cross(a, b, d) <= 0 && cross(c, d, a) * cross(c, d, b) <= 0 {
                    let boxA = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y)).insetBy(dx: -1e-9, dy: -1e-9)
                    let boxB = CGRect(x: min(c.x, d.x), y: min(c.y, d.y), width: abs(c.x - d.x), height: abs(c.y - d.y)).insetBy(dx: -1e-9, dy: -1e-9)
                    if boxA.intersects(boxB) { return nil }
                }
            }
        }
        var points = signedArea(input) > 0 ? input : Array(input.reversed())
        var triangles: [[CGPoint]] = []
        while points.count > 3 {
            var removed = false
            for i in points.indices {
                let previous = (i + points.count - 1) % points.count, next = (i + 1) % points.count
                let a = points[previous], b = points[i], c = points[next]
                guard cross(a, b, c) > 1e-10 else { continue }
                let occupied = points.indices.contains { j in
                    j != previous && j != i && j != next && cross(a, b, points[j]) >= -1e-10
                        && cross(b, c, points[j]) >= -1e-10 && cross(c, a, points[j]) >= -1e-10
                }
                if !occupied { triangles.append([a, b, c]); points.remove(at: i); removed = true; break }
            }
            guard removed else { return nil }
        }
        triangles.append(points)
        return triangles
    }
    static func overlapArea(_ first: [[CGPoint]], _ second: [[CGPoint]]) -> Double {
        var total = 0.0
        for a in first {
            for b in second {
                let intersection = bounds(a).intersection(bounds(b))
                guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { continue }
                var clipped = a
                for i in b.indices {
                    let start = b[i], end = b[(i + 1) % b.count]
                    let input = clipped; clipped = []
                    guard var previous = input.last else { break }
                    for current in input {
                        let p = cross(start, end, previous), c = cross(start, end, current)
                        if (p >= 0) != (c >= 0), abs(p - c) > 1e-12 {
                            let t = CGFloat(p / (p - c))
                            clipped.append(CGPoint(x: previous.x + t * (current.x - previous.x), y: previous.y + t * (current.y - previous.y)))
                        }
                        if c >= 0 { clipped.append(current) }
                        previous = current
                    }
                }
                total += abs(signedArea(clipped))
            }
        }
        return total
    }
}

struct ResidentialMaterialEstimate {
    let flooringArea: Double
    let flooringPacks: Int
    let paintArea: Double
    let paintLitres: Double

    init?(rooms: [ResidentialRoomMetric], wallHeight: Double, wastePercent: Double,
          packCoverage: Double, openingArea: Double, coats: Int, paintCoverage: Double) {
        let values = [wallHeight, wastePercent, packCoverage, openingArea, paintCoverage]
        guard !rooms.isEmpty, values.allSatisfy(\.isFinite), (0.5...10).contains(wallHeight),
              (0...50).contains(wastePercent), (0.01...100).contains(packCoverage), openingArea >= 0,
              (1...5).contains(coats), (0.1...50).contains(paintCoverage) else { return nil }
        let wallArea = rooms.reduce(0) { $0 + $1.perimeter * wallHeight }
        guard openingArea <= wallArea else { return nil }
        let factor = 1 + wastePercent / 100
        flooringArea = rooms.reduce(0) { $0 + $1.area } * factor
        let packs = ceil(flooringArea / packCoverage)
        guard packs.isFinite, packs < Double(Int.max) else { return nil }
        flooringPacks = Int(packs)
        paintArea = wallArea - openingArea
        paintLitres = paintArea * Double(coats) / paintCoverage * factor
    }
}
