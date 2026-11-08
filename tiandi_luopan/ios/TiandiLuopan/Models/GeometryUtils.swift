import Foundation
import CoreGraphics

// MARK: - 通用几何工具 (多边形面积 / 质心 / 包围盒)
// 供全景形煞档案与户型立极共用：识别与测绘产生的房间/区域边界以
// 多边形表达，面积与质心按真实多边形计算，比矩形近似更精准。

/// The blueprint axes and the house facing are separate geographic bearings.
struct FloorplanOrientation: Equatable {
    let coordinateHeading: Double
    let houseFacingDegrees: Double?

    var relativeFacing: Double? {
        guard let houseFacingDegrees, houseFacingDegrees.isFinite, coordinateHeading.isFinite else { return nil }
        return (houseFacingDegrees - coordinateHeading + 360).truncatingRemainder(dividingBy: 360)
    }

    func facing(afterCalibratingTo heading: Double) -> Double? {
        relativeFacing.map { (heading + $0 + 360).truncatingRemainder(dividingBy: 360) }
    }
}

/// Azimuth of world -Z from a physical camera bearing and its AR-world ray.
/// Locked chart bearings are deliberately not an input.
struct SurveyCoordinateReference {
    static func heading(cameraHeading: Double?, cameraForward: SIMD3<Float>) -> Double? {
        guard let cameraHeading, cameraHeading.isFinite,
              cameraForward.x.isFinite, cameraForward.z.isFinite,
              cameraForward.x * cameraForward.x + cameraForward.z * cameraForward.z > 0.0001 else { return nil }
        let worldYaw = atan2(Double(cameraForward.x), Double(-cameraForward.z)) * 180 / .pi
        return (cameraHeading - worldYaw + 720).truncatingRemainder(dividingBy: 360)
    }
}

struct SpatialEntranceCandidate {
    let id: UUID
    let position: SIMD2<Float>
    let width: Float
}

struct ARTargetProjection: Equatable {
    let horizontalFOVDegrees: Double
    let aspectRatio: Double

    var verticalFOVDegrees: Double {
        2 * atan(tan(horizontalFOVDegrees * .pi / 360) / max(0.01, aspectRatio)) * 180 / .pi
    }

    func bearing(point: CGPoint, cameraHeading: Double) -> Double {
        let offset = atan((Double(point.x) - 0.5) * 2 * tan(horizontalFOVDegrees * .pi / 360)) * 180 / .pi
        return (cameraHeading + offset + 720).truncatingRemainder(dividingBy: 360)
    }

    func elevation(point: CGPoint, cameraElevation: Double) -> Double {
        // Screen Y points down; the physical elevation axis points up.
        cameraElevation + atan((0.5 - Double(point.y)) * 2 * tan(verticalFOVDegrees * .pi / 360)) * 180 / .pi
    }

    static func targetPoint(detected: CGPoint, normalizedDrag: CGSize, viewport: CGSize, marker: CGSize) -> CGPoint {
        let insetX = viewport.width > 0 ? min(0.5, marker.width / (2 * viewport.width)) : 0.02
        let insetY = viewport.height > 0 ? min(0.5, marker.height / (2 * viewport.height)) : 0.02
        return CGPoint(x: min(1 - insetX, max(insetX, detected.x + normalizedDrag.width)),
                       y: min(1 - insetY, max(insetY, detected.y + normalizedDrag.height)))
    }
}

struct ARCapturePose: Equatable {
    let heading: Double
    let elevation: Double
    let projection: ARTargetProjection

    func isCompatible(with other: ARCapturePose) -> Bool {
        let delta = abs(heading - other.heading).truncatingRemainder(dividingBy: 360)
        return min(delta, 360 - delta) <= 3 && abs(elevation - other.elevation) <= 3
            && abs(projection.aspectRatio - other.projection.aspectRatio) < 0.02
            && abs(projection.horizontalFOVDegrees - other.projection.horizontalFOVDegrees) < 0.5
    }
}

public enum GeometryUtils {

    /// Distance to the outer convex envelope is invariant under rigid rotation.
    /// Concave entrances remain user-confirmable in the RoomPlan result.
    static func entranceDoorID(wallEndpoints: [SIMD2<Float>], doors: [SpatialEntranceCandidate]) -> UUID? {
        let points = wallEndpoints.filter { $0.x.isFinite && $0.y.isFinite }
            .map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        let hull = convexHull(points)
        let candidates = doors.filter { $0.width.isFinite && $0.position.x.isFinite && $0.position.y.isFinite }
        guard !candidates.isEmpty else { return nil }
        func boundaryDistance(_ door: SpatialEntranceCandidate) -> CGFloat {
            guard hull.count >= 3 else { return 0 }
            let p = CGPoint(x: CGFloat(door.position.x), y: CGFloat(door.position.y))
            return hull.indices.map { i -> CGFloat in
                let a = hull[i], b = hull[(i + 1) % hull.count]
                let dx = b.x - a.x, dy = b.y - a.y
                let lengthSquared = dx * dx + dy * dy
                let t = lengthSquared > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared)) : 0
                return hypot(p.x - a.x - t * dx, p.y - a.y - t * dy)
            }.min() ?? 0
        }
        let scored = candidates.map { (door: $0, distance: boundaryDistance($0)) }
        let nearest = scored.map { $0.distance }.min() ?? 0
        let nearBoundary = scored.filter { $0.distance <= nearest + 0.05 }.map { $0.door }
        let widest = nearBoundary.map(\.width).max() ?? 0
        return nearBoundary.filter { $0.width >= widest - 0.001 }
            .map(\.id).min { $0.uuidString < $1.uuidString }
    }

    static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        var unique: [CGPoint] = []
        for point in sorted where unique.last != point { unique.append(point) }
        guard unique.count >= 3 else { return unique }
        func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        }
        var lower: [CGPoint] = [], upper: [CGPoint] = []
        for point in unique {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 { lower.removeLast() }
            lower.append(point)
        }
        for point in unique.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 { upper.removeLast() }
            upper.append(point)
        }
        return Array(lower.dropLast()) + Array(upper.dropLast())
    }

    /// A normalized x/y pair has different units on a rectangular plan.
    /// Restore its aspect ratio before resolving a clockwise bearing.
    public static func bearing(from origin: CGPoint, to point: CGPoint, aspectRatio: CGFloat = 1) -> Double {
        let ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1
        let dx = Double((point.x - origin.x) * ratio)
        let dy = Double(point.y - origin.y)
        let angle = atan2(dx, -dy) * 180.0 / .pi
        return (angle + 360.0).truncatingRemainder(dividingBy: 360.0)
    }

    public static func aspectFitRect(aspectRatio: CGFloat, in bounds: CGRect) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        let ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1
        let width = min(bounds.width, bounds.height * ratio)
        let height = width / ratio
        return CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2,
                      width: width, height: height)
    }

    /// 多边形有向面积（鞋带公式，单位与输入一致；逆时针为正）。
    public static func polygonArea(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var sum: CGFloat = 0
        for i in 0..<points.count {
            let p = points[i]
            let q = points[(i + 1) % points.count]
            sum += p.x * q.y - q.x * p.y
        }
        return abs(sum) * 0.5
    }

    /// 多边形面积质心（鞋带公式加权；退化多边形回退到顶点平均）。
    public static func polygonCentroid(_ points: [CGPoint]) -> CGPoint {
        guard points.count >= 3 else {
            return points.isEmpty ? .zero : points.reduce(CGPoint.zero) { acc, p in
                CGPoint(x: acc.x + p.x / CGFloat(points.count), y: acc.y + p.y / CGFloat(points.count))
            }
        }
        var areaSum: CGFloat = 0
        var cx: CGFloat = 0
        var cy: CGFloat = 0
        for i in 0..<points.count {
            let p = points[i]
            let q = points[(i + 1) % points.count]
            let cross = p.x * q.y - q.x * p.y
            areaSum += cross
            cx += (p.x + q.x) * cross
            cy += (p.y + q.y) * cross
        }
        guard abs(areaSum) > 1e-6 else {
            return points.reduce(CGPoint.zero) { acc, p in
                CGPoint(x: acc.x + p.x / CGFloat(points.count), y: acc.y + p.y / CGFloat(points.count))
            }
        }
        return CGPoint(x: cx / (3 * areaSum), y: cy / (3 * areaSum))
    }

    /// 多边形最小包围盒；不足三个点或面积为零时返回 nil。
    public static func polygonBounds(_ points: [CGPoint]) -> CGRect? {
        guard points.count >= 3 else { return nil }
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for p in points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        let rect = CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
        guard rect.width > 0, rect.height > 0 else { return nil }
        return rect
    }

    /// 闭合多边形与矩形区域的 IoU（归一化坐标直接可算）。
    public static func polygonRectIOU(_ polygon: [CGPoint], _ rect: CGRect) -> CGFloat {
        guard let bounds = polygonBounds(polygon), !bounds.isNull else { return 0 }
        let inter = bounds.intersection(rect)
        guard !inter.isNull else { return 0 }
        let polygonAreaValue = polygonArea(polygon)
        let rectArea = rect.width * rect.height
        let union = polygonAreaValue + rectArea - inter.width * inter.height
        guard union > 0 else { return 0 }
        return (inter.width * inter.height) / union
    }
}
