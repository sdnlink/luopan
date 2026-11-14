package com.example.yiijingcompass.model

import android.graphics.PointF
import android.graphics.RectF
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.*
import java.util.UUID

object GeometryUtils {
    fun bearing(origin: PointF, point: PointF, aspectRatio: Float = 1f): Double {
        val ratio = aspectRatio.takeIf { it.isFinite() && it > 0 } ?: 1f
        return ((atan2(((point.x - origin.x) * ratio).toDouble(), -(point.y - origin.y).toDouble()) * 180 / PI) + 360) % 360
    }

    fun aspectFitRect(aspectRatio: Float, bounds: RectF): RectF {
        if (bounds.width() <= 0 || bounds.height() <= 0) return RectF()
        val ratio = aspectRatio.takeIf { it.isFinite() && it > 0 } ?: 1f
        val width = min(bounds.width(), bounds.height() * ratio)
        val height = width / ratio
        return RectF(bounds.centerX() - width / 2, bounds.centerY() - height / 2,
            bounds.centerX() + width / 2, bounds.centerY() + height / 2)
    }

    fun polygonContains(point: PointF, points: List<PointF>): Boolean {
        if (points.size < 3 || !point.x.isFinite() || !point.y.isFinite() ||
            points.any { !it.x.isFinite() || !it.y.isFinite() } || polygonArea(points) <= 1e-12f) return false
        var inside = false
        points.indices.forEach { i ->
            val a = points[i]; val b = points[(i + 1) % points.size]
            val dx = (b.x - a.x).toDouble(); val dy = (b.y - a.y).toDouble()
            val cross = (point.x - a.x) * dy - (point.y - a.y) * dx
            if (abs(cross) <= 1e-7 * max(1.0, hypot(dx, dy)) && point.x >= min(a.x, b.x) - 1e-7 &&
                point.x <= max(a.x, b.x) + 1e-7 && point.y >= min(a.y, b.y) - 1e-7 && point.y <= max(a.y, b.y) + 1e-7) return true
            if ((a.y > point.y) != (b.y > point.y) && point.x < a.x + (point.y - a.y) * dx / dy) inside = !inside
        }
        return inside
    }

    fun convexHull(points: List<PointF>): List<PointF> {
        val sorted = points.filter { it.x.isFinite() && it.y.isFinite() }.distinctBy { it.x to it.y }
            .sortedWith(compareBy<PointF> { it.x }.thenBy { it.y })
        if (sorted.size < 3) return sorted
        fun cross(a: PointF, b: PointF, c: PointF) = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        fun half(input: List<PointF>): List<PointF> {
            val result = mutableListOf<PointF>()
            input.forEach { p ->
                while (result.size >= 2 && cross(result[result.size - 2], result.last(), p) <= 0) result.removeAt(result.lastIndex)
                result.add(p)
            }
            return result.dropLast(1)
        }
        return half(sorted) + half(sorted.reversed())
    }

    fun entranceDoorID(wallEndpoints: List<Vec2f>, doors: List<SpatialEntranceCandidate>): String? {
        val hull = convexHull(wallEndpoints.map { PointF(it.x, it.y) })
        val candidates = doors.filter { it.width.isFinite() && it.position.x.isFinite() && it.position.y.isFinite() }
        fun distance(door: SpatialEntranceCandidate): Double = if (hull.size < 3) 0.0 else hull.indices.minOf { i ->
            val a = hull[i]; val b = hull[(i + 1) % hull.size]
            val dx = b.x - a.x; val dy = b.y - a.y
            val length = dx * dx + dy * dy
            val t = if (length > 0) (((door.position.x - a.x) * dx + (door.position.y - a.y) * dy) / length).coerceIn(0f, 1f) else 0f
            hypot((door.position.x - a.x - t * dx).toDouble(), (door.position.y - a.y - t * dy).toDouble())
        }
        val scores = candidates.map { it to distance(it) }
        val nearest = scores.minOfOrNull { it.second } ?: return null
        val boundary = scores.filter { it.second <= nearest + 0.05 }.map { it.first }
        val widest = boundary.maxOf { it.width }
        return boundary.filter { it.width >= widest - 0.001f }.minByOrNull { it.id }?.id
    }

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

data class FloorplanOrientation(val coordinateHeading: Double, val houseFacingDegrees: Double?) {
    val houseHeadingState get() = Mountain24Data.instance.resolveHeadingState(houseFacingDegrees?.takeIf { it.isFinite() } ?: coordinateHeading)
    val relativeFacing: Double? get() = houseFacingDegrees?.takeIf { it.isFinite() && coordinateHeading.isFinite() }
        ?.let { (it - coordinateHeading + 720) % 360 }
    fun facingAfterCalibratingTo(heading: Double) = relativeFacing?.let { (heading + it + 720) % 360 }
}

data class FloorplanSurveyMapping(val surveyID: String, val minX: Double, val minZ: Double,
    val spanX: Double, val spanZ: Double, val padding: Double) {
    fun point(x: Float, z: Float, surveyID: String): PointF? {
        if (this.surveyID != surveyID || !x.isFinite() || !z.isFinite() ||
            listOf(minX, minZ, spanX, spanZ, padding).any { !it.isFinite() } || spanX <= 0 || spanZ <= 0 || padding < 0 || padding >= 0.5) return null
        val scale = 1 - 2 * padding
        return PointF(((x - minX) / spanX * scale + padding).toFloat(), ((z - minZ) / spanZ * scale + padding).toFloat())
    }
}

object SurveyCoordinateReference {
    fun heading(cameraHeading: Double?, cameraForward: Vec3f): Double? {
        if (cameraHeading == null || !cameraHeading.isFinite() || !cameraForward.x.isFinite() ||
            !cameraForward.z.isFinite() || cameraForward.x * cameraForward.x + cameraForward.z * cameraForward.z <= 0.0001f) return null
        val yaw = atan2(cameraForward.x.toDouble(), -cameraForward.z.toDouble()) * 180 / PI
        return (cameraHeading - yaw + 720) % 360
    }
}

data class SpatialEntranceCandidate(val id: String, val position: Vec2f, val width: Float)

data class ARTargetProjection(val horizontalFOVDegrees: Double, val aspectRatio: Double) {
    val verticalFOVDegrees get() = 2 * atan(tan(horizontalFOVDegrees * PI / 360) / max(0.01, aspectRatio)) * 180 / PI
    fun bearing(point: PointF, cameraHeading: Double) = (cameraHeading + atan((point.x - 0.5) * 2 * tan(horizontalFOVDegrees * PI / 360)) * 180 / PI + 720) % 360
    fun elevation(point: PointF, cameraElevation: Double) = cameraElevation + atan((0.5 - point.y) * 2 * tan(verticalFOVDegrees * PI / 360)) * 180 / PI
    companion object {
        fun targetPoint(detected: PointF, drag: PointF, viewport: PointF, marker: PointF): PointF {
            val insetX = if (viewport.x > 0) min(0.5f, marker.x / (2 * viewport.x)) else 0.02f
            val insetY = if (viewport.y > 0) min(0.5f, marker.y / (2 * viewport.y)) else 0.02f
            return PointF((detected.x + drag.x).coerceIn(insetX, 1 - insetX), (detected.y + drag.y).coerceIn(insetY, 1 - insetY))
        }
    }
}

class ARCapturePose(heading: Double, elevation: Double, val projection: ARTargetProjection, roll: Double = 0.0) {
    var heading=heading;private set
    var elevation=elevation;private set
    private var forward: Vec3f
    private var right: Vec3f
    private var up: Vec3f
    init {
        val h = heading * PI / 180; val e = elevation * PI / 180; val r = roll * PI / 180
        forward = Vec3f((sin(h) * cos(e)).toFloat(), sin(e).toFloat(), (-cos(h) * cos(e)).toFloat())
        val horizontalRight = Vec3f(cos(h).toFloat(), 0f, sin(h).toFloat())
        val verticalUp = Vec3f((-sin(h) * sin(e)).toFloat(), cos(e).toFloat(), (cos(h) * sin(e)).toFloat())
        right = horizontalRight * cos(r).toFloat() - verticalUp * sin(r).toFloat()
        up = horizontalRight * sin(r).toFloat() + verticalUp * cos(r).toFloat()
    }
    constructor(worldFromCamera:FloatArray,coordinateHeading:Double,projection:ARTargetProjection):this(0.0,0.0,projection){
        require(worldFromCamera.size==16&&worldFromCamera.all {it.isFinite()}&&coordinateHeading.isFinite())
        val angle=coordinateHeading*PI/180
        fun geographic(column:Int):Vec3f {val x=worldFromCamera[column*4];val y=worldFromCamera[column*4+1];val z=worldFromCamera[column*4+2]
            return Vec3f((x*cos(angle)-z*sin(angle)).toFloat(),y,(x*sin(angle)+z*cos(angle)).toFloat()).normalized()}
        right=geographic(0);up=geographic(1);forward=geographic(2)* -1f
        this.heading=(atan2(forward.x.toDouble(),-forward.z.toDouble())*180/PI+720)%360
        this.elevation=asin(forward.y.toDouble().coerceIn(-1.0,1.0))*180/PI
    }
    fun direction(point: PointF): Vec3f {
        val x = ((point.x - 0.5) * 2 * tan(projection.horizontalFOVDegrees * PI / 360)).toFloat()
        val y = ((0.5 - point.y) * 2 * tan(projection.verticalFOVDegrees * PI / 360)).toFloat()
        return (forward + right * x + up * y).normalized()
    }
    fun bearing(point: PointF): Double { val ray = direction(point); return (atan2(ray.x.toDouble(), -ray.z.toDouble()) * 180 / PI + 720) % 360 }
    fun elevation(point: PointF) = asin(direction(point).y.toDouble().coerceIn(-1.0, 1.0)) * 180 / PI
    fun isCompatible(other: ARCapturePose): Boolean {
        val cosine = (right.dot(other.right) + up.dot(other.up) + forward.dot(other.forward) - 1) / 2
        return acos(cosine.toDouble().coerceIn(-1.0, 1.0)) * 180 / PI <= 3 &&
            abs(projection.aspectRatio - other.projection.aspectRatio) < 0.02 && abs(projection.horizontalFOVDegrees - other.projection.horizontalFOVDegrees) < 0.5
    }
}

