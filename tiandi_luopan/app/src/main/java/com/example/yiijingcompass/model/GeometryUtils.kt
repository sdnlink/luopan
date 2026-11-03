package com.example.yiijingcompass.model

import android.graphics.PointF
import android.graphics.RectF
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

object GeometryUtils {

    fun polygonArea(points: List<PointF>): Float {
        if (points.size < 3) return 0f
        var sum = 0f
        for (i in points.indices) {
            val p = points[i]
            val q = points[(i + 1) % points.size]
            sum += p.x * q.y - q.x * p.y
        }
        return abs(sum) * 0.5f
    }

    fun polygonCentroid(points: List<PointF>): PointF {
        if (points.size < 3) {
            if (points.isEmpty()) return PointF(0f, 0f)
            var sx = 0f
            var sy = 0f
            for (p in points) {
                sx += p.x
                sy += p.y
            }
            return PointF(sx / points.size, sy / points.size)
        }
        var areaSum = 0f
        var cx = 0f
        var cy = 0f
        for (i in points.indices) {
            val p = points[i]
            val q = points[(i + 1) % points.size]
            val cross = p.x * q.y - q.x * p.y
            areaSum += cross
            cx += (p.x + q.x) * cross
            cy += (p.y + q.y) * cross
        }
        if (abs(areaSum) <= 1e-6f) {
            var sx = 0f
            var sy = 0f
            for (p in points) {
                sx += p.x
                sy += p.y
            }
            return PointF(sx / points.size, sy / points.size)
        }
        return PointF(cx / (3f * areaSum), cy / (3f * areaSum))
    }

    fun polygonBounds(points: List<PointF>): RectF? {
        if (points.size < 3) return null
        var minX = Float.MAX_VALUE
        var maxX = -Float.MAX_VALUE
        var minY = Float.MAX_VALUE
        var maxY = -Float.MAX_VALUE
        for (p in points) {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        val rect = RectF(minX, minY, maxX, maxY)
        if (rect.width() <= 0f || rect.height() <= 0f) return null
        return rect
    }

    fun polygonRectIOU(polygon: List<PointF>, rect: RectF): Float {
        val bounds = polygonBounds(polygon) ?: return 0f
        val inter = RectF()
        if (!inter.setIntersect(bounds, rect)) return 0f
        val polyArea = polygonArea(polygon)
        val rectArea = rect.width() * rect.height()
        val union = polyArea + rectArea - inter.width() * inter.height()
        if (union <= 0f) return 0f
        return (inter.width() * inter.height()) / union
    }
}

