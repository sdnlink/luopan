import Foundation
import CoreGraphics

// MARK: - 通用几何工具 (多边形面积 / 质心 / 包围盒)
// 供全景形煞档案与户型立极共用：识别与测绘产生的房间/区域边界以
// 多边形表达，面积与质心按真实多边形计算，比矩形近似更精准。

public enum GeometryUtils {

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
