package com.example.yiijingcompass.model

import java.io.File
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.math.*

// MARK: - 3D 几何向量结构

data class Vec2f(val x: Float, val y: Float) {
    operator fun plus(other: Vec2f) = Vec2f(x + other.x, y + other.y)
    operator fun minus(other: Vec2f) = Vec2f(x - other.x, y - other.y)
    operator fun times(scalar: Float) = Vec2f(x * scalar, y * scalar)
    operator fun div(scalar: Float) = Vec2f(x / scalar, y / scalar)
    fun length(): Float = sqrt(x * x + y * y)
    fun normalized(): Vec2f {
        val l = length()
        return if (l > 1e-5f) this / l else Vec2f(0f, 0f)
    }
    fun dot(other: Vec2f): Float = x * other.x + y * other.y
    fun distance(other: Vec2f): Float = (this - other).length()
}

data class Vec3f(val x: Float, val y: Float, val z: Float) {
    operator fun plus(other: Vec3f) = Vec3f(x + other.x, y + other.y, z + other.z)
    operator fun minus(other: Vec3f) = Vec3f(x - other.x, y - other.y, z - other.z)
    operator fun times(scalar: Float) = Vec3f(x * scalar, y * scalar, z * scalar)
    operator fun div(scalar: Float) = Vec3f(x / scalar, y / scalar, z / scalar)
    fun length(): Float = sqrt(x * x + y * y + z * z)
    fun normalized(): Vec3f {
        val l = length()
        return if (l > 1e-5f) this / l else Vec3f(0f, 0f, 1f)
    }
    fun dot(other: Vec3f): Float = x * other.x + y * other.y + z * other.z
    fun distance(other: Vec3f): Float = (this - other).length()
    fun toVec2XZ() = Vec2f(x, z)
}

// MARK: - 3D 全屋测绘空间数据模型与全屋形煞引擎 (PRD 5.3 & 第7章)

enum class SpatialShaSeverity(val rawValue: String, val badgeColorHex: String) {
    AUSPICIOUS("吉", "#34C759"),
    WARNING("轻微", "#FF9500"),
    CRITICAL("大凶", "#FF3B30")
}

enum class SpatialOpeningType(val rawValue: String) {
    ENTRANCE_DOOR("入户门"),
    INTERIOR_DOOR("房门"),
    WINDOW("采光窗"),
    OPENING("洞口"),
    BALCONY_DOOR("阳台门")
}

/**
 * 鲁班尺门光吉凶评定 (鲁班尺 42.9 cm 阳尺 & 丁兰尺 39.0 cm 阴尺)
 */
data class LubanRulerEvaluation(
    val meters: Float,
    val centimeters: Float,
    val yangGateIndex: Int,
    val yangIsAuspicious: Boolean,
    val yinIndex: Int,
    val yinIsAuspicious: Boolean
) {
    val yangSegmentName: String
        get() = yangNamesHans[yangGateIndex]

    val yinSegmentName: String
        get() = yinNamesHans[yinIndex]

    companion object {
        private val yangNamesHans = listOf("财", "病", "离", "义", "官", "劫", "害", "本")
        private val yangNamesHant = listOf("財", "病", "離", "義", "官", "劫", "害", "本")
        private val yangNamesEn = listOf("Wealth", "Illness", "Separation", "Righteous", "Official", "Robbery", "Harm", "Origin")
        private val yangAuspiciousFlags = listOf(true, false, false, true, true, false, false, true)

        private val yinNamesHans = listOf("财", "失", "兴", "死", "官", "义", "苦", "旺", "害", "丁")
        private val yinNamesHant = listOf("財", "失", "興", "死", "官", "義", "苦", "旺", "害", "丁")
        private val yinNamesEn = listOf("Wealth", "Loss", "Prosper", "Decline", "Official", "Righteous", "Sorrow", "Flourish", "Harm", "Descendant")
        private val yinAuspiciousFlags = listOf(true, false, true, false, true, true, false, true, false, true)

        fun evaluate(meters: Double): LubanRulerEvaluation = evaluate(meters.toFloat())

        fun evaluate(meters: Float): LubanRulerEvaluation {
            val cm = max(0.0f, meters * 100.0f)
            val yangCycle = 42.9f
            val yangStep = yangCycle / 8.0f
            val yangRem = cm % yangCycle
            val yIdx = min(7, max(0, (yangRem / yangStep).toInt()))

            val yinCycle = 39.0f
            val yinStep = yinCycle / 10.0f
            val yinRem = cm % yinCycle
            val nIdx = min(9, max(0, (yinRem / yinStep).toInt()))

            return LubanRulerEvaluation(
                meters = meters,
                centimeters = cm,
                yangGateIndex = yIdx,
                yangIsAuspicious = yangAuspiciousFlags[yIdx],
                yinIndex = nIdx,
                yinIsAuspicious = yinAuspiciousFlags[nIdx]
            )
        }
    }

    fun localizedSummary(language: AppLanguage): String {
        val sourceNote: String = when (language) {
            AppLanguage.EN ->
                "Classical source: the Lu Ban ruler formula, ‘Wealth, Righteousness, Official and Origin are auspicious; Illness, Separation, Robbery and Harm are inauspicious.’ ‘Illness’, ‘loss’ and ‘wealth’ are symbolic ruler labels, not medical, safety or financial conclusions."
            AppLanguage.ZH_HANT ->
                "出處：《魯班經》尺法訣：「財、義、官、本為吉，病、離、劫、害為凶。」兼參《丁蘭尺》傳統尺法；‘病、失、財、旺’是文化象徵標籤，不是醫療、安全或財務判斷。"
            else ->
                "出处：《鲁班经》尺法诀：“财、义、官、本为吉，病、离、劫、害为凶。”兼参《丁兰尺》传统尺法；‘病、失、财、旺’是文化象征标签，不是医疗、安全或财务判断。"
        }
        return when (language) {
            AppLanguage.EN -> {
                val yName = yangNamesEn[yangGateIndex]
                val yLuck = if (yangIsAuspicious) "Auspicious" else "Inauspicious"
                val nName = yinNamesEn[yinIndex]
                val nLuck = if (yinIsAuspicious) "Auspicious" else "Inauspicious"
                String.format(Locale.US, "%.1f cm · LuBan: %s (%s) · DingLan: %s (%s) · %s", centimeters, yName, yLuck, nName, nLuck, sourceNote)
            }
            AppLanguage.ZH_HANT -> {
                val yName = yangNamesHant[yangGateIndex]
                val yLuck = if (yangIsAuspicious) "吉" else "凶"
                val nName = yinNamesHant[yinIndex]
                val nLuck = if (yinIsAuspicious) "吉" else "凶"
                String.format(Locale.US, "%.1f cm · 魯班門光尺：【%s】字門(%s) · 丁蘭尺：【%s】字(%s) · %s", centimeters, yName, yLuck, nName, nLuck, sourceNote)
            }
            else -> {
                val yName = yangNamesHans[yangGateIndex]
                val yLuck = if (yangIsAuspicious) "吉" else "凶"
                val nName = yinNamesHans[yinIndex]
                val nLuck = if (yinIsAuspicious) "吉" else "凶"
                String.format(Locale.US, "%.1f cm · 鲁班门光尺：【%s】字门(%s) · 丁兰尺：【%s】字(%s) · %s", centimeters, yName, yLuck, nName, nLuck, sourceNote)
            }
        }
    }
}

/**
 * 3D 墙体数据结构
 */
data class SpatialWall3D(
    val id: String = UUID.randomUUID().toString(),
    val startX: Float,
    val startY: Float,
    val startZ: Float,
    val endX: Float,
    val endY: Float,
    val endZ: Float,
    val height: Float = 2.8f,
    val thickness: Float = 0.20f,
    val isLoadBearing: Boolean = false
) {
    val start: Vec3f get() = Vec3f(startX, startY, startZ)
    val end: Vec3f get() = Vec3f(endX, endY, endZ)
    val length: Float
        get() = Vec2f(startX, startZ).distance(Vec2f(endX, endZ))
}

/**
 * 3D 门窗开口结构
 */
data class SpatialOpening3D(
    val id: String = UUID.randomUUID().toString(),
    val type: SpatialOpeningType,
    val posX: Float,
    val posY: Float,
    val posZ: Float,
    val normalX: Float = 0f,
    val normalY: Float = 0f,
    val normalZ: Float = 1f,
    val width: Float,
    val height: Float,
    val yangGateName: String = "",
    val yangIsAuspicious: Boolean = true
) {
    val position: Vec3f get() = Vec3f(posX, posY, posZ)
    val normal: Vec3f get() = Vec3f(normalX, normalY, normalZ)

    constructor(
        id: String = UUID.randomUUID().toString(),
        type: SpatialOpeningType,
        position: Vec3f,
        normal: Vec3f,
        width: Float,
        height: Float,
        lubanEval: LubanRulerEvaluation? = null
    ) : this(
        id = id,
        type = type,
        posX = position.x,
        posY = position.y,
        posZ = position.z,
        normalX = if (normal.length() > 1e-4f) (normal / normal.length()).x else 0f,
        normalY = if (normal.length() > 1e-4f) (normal / normal.length()).y else 0f,
        normalZ = if (normal.length() > 1e-4f) (normal / normal.length()).z else 1f,
        width = width,
        height = height,
        yangGateName = (lubanEval ?: LubanRulerEvaluation.evaluate(width)).yangSegmentName,
        yangIsAuspicious = (lubanEval ?: LubanRulerEvaluation.evaluate(width)).yangIsAuspicious
    )
}

/**
 * 3D 结构横梁
 */
data class SpatialBeam3D(
    val id: String = UUID.randomUUID().toString(),
    val startX: Float,
    val startY: Float,
    val startZ: Float,
    val endX: Float,
    val endY: Float,
    val endZ: Float,
    val clearanceHeight: Float, // 梁底净高 (米)
    val beamDepth: Float = 0.35f, // 下垂深度 (米)
    val beamWidth: Float = 0.25f  // 梁宽 (米)
) {
    val start: Vec3f get() = Vec3f(startX, startY, startZ)
    val end: Vec3f get() = Vec3f(endX, endY, endZ)
}

/**
 * 3D 房间空间划分
 */
data class SpatialRoom3D(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val type: FloorplanRoomType,
    val centerX: Float,
    val centerY: Float,
    val centerZ: Float,
    val sizeX: Float,
    val sizeY: Float,
    val sizeZ: Float,
    val areaSqMeters: Float = max(1.0f, sizeX * sizeZ),
    val rotationY: Float? = null
) {
    val center: Vec3f get() = Vec3f(centerX, centerY, centerZ)
    val size: Vec3f get() = Vec3f(sizeX, sizeY, sizeZ)
}

/**
 * 3D 家居关键物件
 */
data class SpatialObject3D(
    val id: String = UUID.randomUUID().toString(),
    val category: String,
    val posX: Float,
    val posY: Float,
    val posZ: Float,
    val sizeX: Float,
    val sizeY: Float,
    val sizeZ: Float,
    val rotationY: Float? = null
) {
    val position: Vec3f get() = Vec3f(posX, posY, posZ)
    val size: Vec3f get() = Vec3f(sizeX, sizeY, sizeZ)
}

/**
 * 全屋宏观尺寸
 */
data class HouseDimensions(
    val totalWidth: Float,       // 开间 / 宽度 (米)
    val totalDepth: Float,       // 进深 (米)
    val ceilingHeight: Float,    // 层净高 (米)
    val grossFloorArea: Float,   // 估算建筑面积 (㎡)
    val usableFloorArea: Float,  // 实际测绘净使用面积 (㎡)
    val aspectRatio: Float = if (totalWidth > 0f) totalDepth / totalWidth else 1.0f
)

/**
 * 全屋形煞条目
 */
data class HouseSpatialShaItem(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val severity: SpatialShaSeverity,
    val locationName: String,
    val detail: String,
    val fengshuiLore: String,
    val solution: String,
    val coordinateX: Float? = null,
    val coordinateY: Float? = null,
    val coordinateZ: Float? = null,
    val vectorEndX: Float? = null,
    val vectorEndY: Float? = null,
    val vectorEndZ: Float? = null
) {
    val coordinate: Vec3f?
        get() {
            val x = coordinateX ?: return null
            val y = coordinateY ?: return null
            val z = coordinateZ ?: return null
            return Vec3f(x, y, z)
        }

    val vectorEnd: Vec3f?
        get() {
            val x = vectorEndX ?: return null
            val y = vectorEndY ?: return null
            val z = vectorEndZ ?: return null
            return Vec3f(x, y, z)
        }

    constructor(
        id: String = UUID.randomUUID().toString(),
        title: String,
        severity: SpatialShaSeverity,
        locationName: String,
        detail: String,
        fengshuiLore: String,
        solution: String,
        coordinate: Vec3f? = null,
        vectorEnd: Vec3f? = null
    ) : this(
        id = id,
        title = title,
        severity = severity,
        locationName = locationName,
        detail = detail,
        fengshuiLore = fengshuiLore,
        solution = solution,
        coordinateX = coordinate?.x,
        coordinateY = coordinate?.y,
        coordinateZ = coordinate?.z,
        vectorEndX = vectorEnd?.x,
        vectorEndY = vectorEnd?.y,
        vectorEndZ = vectorEnd?.z
    )
}

/**
 * 全屋 3D 测绘成果综合报告结构
 */
data class HouseSpatialSurvey(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Date = Date(),
    val scanMethod: String = "AR_LiDAR",
    val dimensions: HouseDimensions,
    val walls: List<SpatialWall3D>,
    val openings: List<SpatialOpening3D>,
    val beams: List<SpatialBeam3D>,
    val rooms: List<SpatialRoom3D>,
    val objects: List<SpatialObject3D>,
    val centroidX: Float,
    val centroidY: Float,
    val centroidZ: Float,
    val compassHeading: Double,
    val shaItems: List<HouseSpatialShaItem>,
    val fengshuiScore: Int,
    val isCentroidIndirect: Boolean? = null
) {
    val centroid: Vec3f get() = Vec3f(centroidX, centroidY, centroidZ)
    val centroidIndirect: Boolean get() = isCentroidIndirect ?: false

    // MARK: - AutoCAD DXF 工程级矢量测绘图生成器 (PRD 专业测绘工具要求)
    fun generateCAD_DXF(): String {
        val s = StringBuilder()
        // 1. DXF 头部
        s.append("0\nSECTION\n2\nHEADER\n9\n\$INSUNITS\n70\n6\n9\n\$ANGBASE\n50\n0.0\n0\nENDSEC\n")

        // 2. 图层表 (LAYERS)
        s.append("0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n8\n")
        val layers = listOf(
            Pair("WALLS_BEARING", 5),      // 蓝色: 承重墙
            Pair("WALLS_PARTITION", 4),    // 青色: 隔断墙
            Pair("DOORS", 2),              // 黄色: 门扇
            Pair("WINDOWS", 3),            // 绿色: 采光窗
            Pair("BEAMS", 1),              // 红色: 结构横梁
            Pair("ROOM_LABELS", 7),        // 白色: 房间空间标注
            Pair("TAIJI_CENTER", 40),      // 橙色: 太极立极中心
            Pair("DIMENSIONS", 6)          // 品红: 净距尺寸线
        )
        for (l in layers) {
            s.append("0\nLAYER\n2\n${l.first}\n70\n0\n62\n${l.second}\n6\nCONTINUOUS\n")
        }
        s.append("0\nENDTAB\n0\nENDSEC\n")

        // 3. 图元区 (ENTITIES)
        s.append("0\nSECTION\n2\nENTITIES\n")

        // 绘制墙体 (3DFACE 包含 3D 厚度与高度)
        for (wall in walls) {
            val layer = if (wall.isLoadBearing) "WALLS_BEARING" else "WALLS_PARTITION"
            val dx = wall.endX - wall.startX
            val dz = wall.endZ - wall.startZ
            val len = sqrt(dx * dx + dz * dz)
            if (len < 1e-4f) continue
            val halfT = wall.thickness * 0.5f
            val nx = -dz / len * halfT
            val nz = dx / len * halfT

            val p1X = wall.startX - nx; val p1Y = -(wall.startZ - nz)
            val p2X = wall.startX + nx; val p2Y = -(wall.startZ + nz)
            val p3X = wall.endX + nx;   val p3Y = -(wall.endZ + nz)
            val p4X = wall.endX - nx;   val p4Y = -(wall.endZ - nz)

            s.append("0\n3DFACE\n8\n$layer\n")
            s.append("10\n${String.format(Locale.US, "%.3f", p1X)}\n20\n${String.format(Locale.US, "%.3f", p1Y)}\n30\n${String.format(Locale.US, "%.3f", wall.startY)}\n")
            s.append("11\n${String.format(Locale.US, "%.3f", p2X)}\n21\n${String.format(Locale.US, "%.3f", p2Y)}\n31\n${String.format(Locale.US, "%.3f", wall.startY)}\n")
            s.append("12\n${String.format(Locale.US, "%.3f", p3X)}\n22\n${String.format(Locale.US, "%.3f", p3Y)}\n32\n${String.format(Locale.US, "%.3f", wall.endY)}\n")
            s.append("13\n${String.format(Locale.US, "%.3f", p4X)}\n23\n${String.format(Locale.US, "%.3f", p4Y)}\n33\n${String.format(Locale.US, "%.3f", wall.endY)}\n")
        }

        // 绘制门窗 (LINE 轴线)
        for (op in openings) {
            val layer = if (op.type == SpatialOpeningType.ENTRANCE_DOOR || op.type == SpatialOpeningType.INTERIOR_DOOR || op.type == SpatialOpeningType.BALCONY_DOOR) "DOORS" else "WINDOWS"
            val halfW = op.width * 0.5f
            val tangentX = -op.normalZ
            val tangentZ = op.normalX
            val p1X = op.posX - tangentX * halfW
            val p1Y = -(op.posZ - tangentZ * halfW)
            val p2X = op.posX + tangentX * halfW
            val p2Y = -(op.posZ + tangentZ * halfW)

            s.append("0\nLINE\n8\n$layer\n")
            s.append("10\n${String.format(Locale.US, "%.3f", p1X)}\n20\n${String.format(Locale.US, "%.3f", p1Y)}\n30\n${String.format(Locale.US, "%.3f", op.posY)}\n")
            s.append("11\n${String.format(Locale.US, "%.3f", p2X)}\n21\n${String.format(Locale.US, "%.3f", p2Y)}\n31\n${String.format(Locale.US, "%.3f", op.posY)}\n")
        }

        // 绘制横梁 (3DFACE 包含下垂厚度)
        for (beam in beams) {
            val bdx = beam.endX - beam.startX
            val bdz = beam.endZ - beam.startZ
            val blen = sqrt(bdx * bdx + bdz * bdz)
            if (blen < 1e-4f) continue
            val bHalfW = beam.beamWidth * 0.5f
            val bnx = -bdz / blen * bHalfW
            val bnz = bdx / blen * bHalfW

            val bp1X = beam.startX - bnx; val bp1Y = -(beam.startZ - bnz)
            val bp2X = beam.startX + bnx; val bp2Y = -(beam.startZ + bnz)
            val bp3X = beam.endX + bnx;   val bp3Y = -(beam.endZ + bnz)
            val bp4X = beam.endX - bnx;   val bp4Y = -(beam.endZ - bnz)

            s.append("0\n3DFACE\n8\nBEAMS\n")
            s.append("10\n${String.format(Locale.US, "%.3f", bp1X)}\n20\n${String.format(Locale.US, "%.3f", bp1Y)}\n30\n${String.format(Locale.US, "%.3f", beam.clearanceHeight)}\n")
            s.append("11\n${String.format(Locale.US, "%.3f", bp2X)}\n21\n${String.format(Locale.US, "%.3f", bp2Y)}\n31\n${String.format(Locale.US, "%.3f", beam.clearanceHeight)}\n")
            s.append("12\n${String.format(Locale.US, "%.3f", bp3X)}\n22\n${String.format(Locale.US, "%.3f", bp3Y)}\n32\n${String.format(Locale.US, "%.3f", beam.clearanceHeight + beam.beamDepth)}\n")
            s.append("13\n${String.format(Locale.US, "%.3f", bp4X)}\n23\n${String.format(Locale.US, "%.3f", bp4Y)}\n33\n${String.format(Locale.US, "%.3f", beam.clearanceHeight + beam.beamDepth)}\n")
        }

        // 绘制太极天心圆与注记 (CIRCLE & TEXT)
        s.append("0\nCIRCLE\n8\nTAIJI_CENTER\n")
        s.append("10\n${String.format(Locale.US, "%.3f", centroidX)}\n20\n${String.format(Locale.US, "%.3f", -centroidZ)}\n30\n0.0\n40\n0.5\n")
        s.append("0\nTEXT\n8\nTAIJI_CENTER\n")
        s.append("10\n${String.format(Locale.US, "%.3f", centroidX + 0.6f)}\n20\n${String.format(Locale.US, "%.3f", -centroidZ)}\n30\n0.0\n")
        s.append("40\n0.35\n1\nTaiJi Center (Centroid)\n")

        // 标注房间文字与面积 (TEXT)
        for (room in rooms) {
            s.append("0\nTEXT\n8\nROOM_LABELS\n")
            s.append("10\n${String.format(Locale.US, "%.3f", room.centerX - 0.4f)}\n20\n${String.format(Locale.US, "%.3f", -room.centerZ)}\n30\n0.0\n")
            s.append("40\n0.30\n1\n${room.name} ${String.format(Locale.US, "%.1f", room.areaSqMeters)}m2\n")
        }

        // 标注主要开间/进深净距尺寸线 (ALIGNED DIMENSION)
        fun appendAlignedDim(x1: Float, y1: Float, x2: Float, y2: Float, label: String) {
            val mx = (x1 + x2) * 0.5f
            val my = (y1 + y2) * 0.5f
            s.append("0\nDIMENSION\n8\nDIMENSIONS\n2\n*D1\n")
            s.append("10\n${String.format(Locale.US, "%.3f", x1)}\n20\n${String.format(Locale.US, "%.3f", y1)}\n30\n0.0\n")
            s.append("11\n${String.format(Locale.US, "%.3f", x2)}\n21\n${String.format(Locale.US, "%.3f", y2)}\n31\n0.0\n")
            s.append("13\n${String.format(Locale.US, "%.3f", mx)}\n23\n${String.format(Locale.US, "%.3f", my)}\n33\n0.0\n")
            s.append("70\n32\n3\nDIMENSIONS\n1\n$label\n")
        }

        var dMinX = Float.MAX_VALUE
        var dMaxX = -Float.MAX_VALUE
        var dMinZ = Float.MAX_VALUE
        var dMaxZ = -Float.MAX_VALUE
        for (w in walls) {
            dMinX = min(dMinX, min(w.startX, w.endX)); dMaxX = max(dMaxX, max(w.startX, w.endX))
            dMinZ = min(dMinZ, min(w.startZ, w.endZ)); dMaxZ = max(dMaxZ, max(w.startZ, w.endZ))
        }
        for (op in openings) {
            dMinX = min(dMinX, op.posX); dMaxX = max(dMaxX, op.posX)
            dMinZ = min(dMinZ, op.posZ); dMaxZ = max(dMaxZ, op.posZ)
        }
        for (r in rooms) {
            dMinX = min(dMinX, r.centerX - r.sizeX * 0.5f); dMaxX = max(dMaxX, r.centerX + r.sizeX * 0.5f)
            dMinZ = min(dMinZ, r.centerZ - r.sizeZ * 0.5f); dMaxZ = max(dMaxZ, r.centerZ + r.sizeZ * 0.5f)
        }
        if (dMinX >= dMaxX) { dMinX = -3.0f; dMaxX = 3.0f }
        if (dMinZ >= dMaxZ) { dMinZ = -3.0f; dMaxZ = 3.0f }
        val dSpanX = max(1.5f, dMaxX - dMinX)
        val dSpanZ = max(1.5f, dMaxZ - dMinZ)
        appendAlignedDim(dMinX, -dMinZ, dMaxX, -dMinZ, "全屋开间 ${String.format(Locale.US, "%.2f", dSpanX)}m")
        appendAlignedDim(dMinX, -dMaxZ, dMaxX, -dMaxZ, "全屋开间 ${String.format(Locale.US, "%.2f", dSpanX)}m")
        appendAlignedDim(dMinX, -dMinZ, dMinX, -dMaxZ, "全屋进深 ${String.format(Locale.US, "%.2f", dSpanZ)}m")
        appendAlignedDim(dMaxX, -dMinZ, dMaxX, -dMaxZ, "全屋进深 ${String.format(Locale.US, "%.2f", dSpanZ)}m")

        val sortedRooms = rooms.sortedByDescending { it.areaSqMeters }.take(3)
        for (r in sortedRooms) {
            val rMinX = r.centerX - r.sizeX * 0.5f
            val rMaxX = r.centerX + r.sizeX * 0.5f
            val rMinZ = r.centerZ - r.sizeZ * 0.5f
            val rMaxZ = r.centerZ + r.sizeZ * 0.5f
            appendAlignedDim(rMinX, -rMinZ, rMaxX, -rMinZ, "${r.name}开间 ${String.format(Locale.US, "%.2f", r.sizeX)}m")
            appendAlignedDim(rMinX, -rMaxZ, rMaxX, -rMaxZ, "${r.name}开间 ${String.format(Locale.US, "%.2f", r.sizeX)}m")
            appendAlignedDim(rMinX, -rMinZ, rMinX, -rMaxZ, "${r.name}进深 ${String.format(Locale.US, "%.2f", r.sizeZ)}m")
            appendAlignedDim(rMaxX, -rMinZ, rMaxX, -rMaxZ, "${r.name}进深 ${String.format(Locale.US, "%.2f", r.sizeZ)}m")
        }

        s.append("0\nENDSEC\n0\nEOF\n")
        return s.toString()
    }

    fun exportDXFToFile(dir: File): File? {
        val dxfString = generateCAD_DXF()
        val file = File(dir, "TianJi-HouseSurvey-${id.take(8)}.dxf")
        return try {
            file.writeText(dxfString, Charsets.UTF_8)
            file
        } catch (e: Exception) {
            null
        }
    }
}

// MARK: - 全屋形煞与 3D 测绘分析引擎 (HouseSpatialSurveyEngine)

object HouseSpatialSurveyEngine {

    fun analyzeSpatialHouse(
        scanMethod: String,
        walls: List<SpatialWall3D>,
        openings: List<SpatialOpening3D>,
        beams: List<SpatialBeam3D>,
        rooms: List<SpatialRoom3D>,
        objects: List<SpatialObject3D>,
        compassHeading: Double,
        centroidOverride: Vec3f? = null
    ): HouseSpatialSurvey {
        // 1. 计算全屋物理边界包围盒
        var minX = Float.MAX_VALUE
        var maxX = -Float.MAX_VALUE
        var minZ = Float.MAX_VALUE
        var maxZ = -Float.MAX_VALUE
        var maxH = 2.8f

        fun roomCorners(r: SpatialRoom3D): List<Vec2f> {
            val hx = r.sizeX * 0.5f
            val hz = r.sizeZ * 0.5f
            val localCorners = listOf(
                Vec2f(r.centerX - hx, r.centerZ - hz),
                Vec2f(r.centerX + hx, r.centerZ - hz),
                Vec2f(r.centerX + hx, r.centerZ + hz),
                Vec2f(r.centerX - hx, r.centerZ + hz)
            )
            val yaw = r.rotationY
            if (yaw == null || !yaw.isFinite() || abs(yaw) <= 1e-5f) {
                return localCorners
            }
            val cosY = cos(yaw)
            val sinY = sin(yaw)
            return localCorners.map { p ->
                val dx = p.x - r.centerX
                val dz = p.y - r.centerZ
                Vec2f(
                    r.centerX + dx * cosY - dz * sinY,
                    r.centerZ + dx * sinY + dz * cosY
                )
            }
        }

        for (w in walls) {
            minX = min(minX, min(w.startX, w.endX))
            maxX = max(maxX, max(w.startX, w.endX))
            minZ = min(minZ, min(w.startZ, w.endZ))
            maxZ = max(maxZ, max(w.startZ, w.endZ))
            maxH = max(maxH, w.height)
        }
        for (o in openings) {
            val halfTangent = o.width * 0.5f
            val tangentX = -o.normalZ
            val tangentZ = o.normalX
            val tangentMinX = o.posX - tangentX * halfTangent
            val tangentMaxX = o.posX + tangentX * halfTangent
            val tangentMinZ = o.posZ - tangentZ * halfTangent
            val tangentMaxZ = o.posZ + tangentZ * halfTangent
            minX = min(minX, min(tangentMinX, tangentMaxX) - abs(o.normalX) * 0.05f)
            maxX = max(maxX, max(tangentMinX, tangentMaxX) + abs(o.normalX) * 0.05f)
            minZ = min(minZ, min(tangentMinZ, tangentMaxZ) - abs(o.normalZ) * 0.05f)
            maxZ = max(maxZ, max(tangentMinZ, tangentMaxZ) + abs(o.normalZ) * 0.05f)
            maxH = max(maxH, o.posY + o.height * 0.5f)
        }
        for (r in rooms) {
            for (corner in roomCorners(r)) {
                minX = min(minX, corner.x)
                maxX = max(maxX, corner.x)
                minZ = min(minZ, corner.y)
                maxZ = max(maxZ, corner.y)
            }
            maxH = max(maxH, r.sizeY)
        }

        if (minX >= maxX) { minX = -4.0f; maxX = 4.0f }
        if (minZ >= maxZ) { minZ = -4.0f; maxZ = 4.0f }

        val spanX = max(1.5f, maxX - minX)
        val spanZ = max(1.5f, maxZ - minZ)
        var rawRoomArea = 0f
        for (room in rooms) {
            if (room.areaSqMeters.isFinite() && room.areaSqMeters > 0f) {
                rawRoomArea += room.areaSqMeters
            }
        }
        val footprintArea = max(1.0f, spanX * spanZ)
        val usableArea = min(rawRoomArea, footprintArea)

        // 2. 拟定房屋主轴方向角与局部坐标包围盒 (OBB)
        val theta = primaryAxisAngle(walls)
        val cosT = cos(theta)
        val sinT = sin(theta)
        fun toLocal(p: Vec2f): Vec2f = Vec2f(p.x * cosT + p.y * sinT, -p.x * sinT + p.y * cosT)
        fun toWorld(p: Vec2f): Vec2f = Vec2f(p.x * cosT - p.y * sinT, p.x * sinT + p.y * cosT)

        var lMinX = Float.MAX_VALUE
        var lMaxX = -Float.MAX_VALUE
        var lMinZ = Float.MAX_VALUE
        var lMaxZ = -Float.MAX_VALUE
        for (wall in walls) {
            for (corner in listOf(Vec2f(wall.startX, wall.startZ), Vec2f(wall.endX, wall.endZ))) {
                val lc = toLocal(corner)
                lMinX = min(lMinX, lc.x); lMaxX = max(lMaxX, lc.x)
                lMinZ = min(lMinZ, lc.y); lMaxZ = max(lMaxZ, lc.y)
            }
        }
        var obbUsable = lMinX < lMaxX && lMinZ < lMaxZ
        if (!obbUsable) {
            lMinX = Float.MAX_VALUE
            lMaxX = -Float.MAX_VALUE
            lMinZ = Float.MAX_VALUE
            lMaxZ = -Float.MAX_VALUE
            for (room in rooms) {
                for (corner in roomCorners(room)) {
                    val lc = toLocal(corner)
                    lMinX = min(lMinX, lc.x); lMaxX = max(lMaxX, lc.x)
                    lMinZ = min(lMinZ, lc.y); lMaxZ = max(lMaxZ, lc.y)
                }
            }
            obbUsable = lMinX < lMaxX && lMinZ < lMaxZ
        }
        if (!obbUsable) {
            lMinX = Float.MAX_VALUE
            lMaxX = -Float.MAX_VALUE
            lMinZ = Float.MAX_VALUE
            lMaxZ = -Float.MAX_VALUE
        }
        val lSpanX = if (obbUsable) max(1.5f, lMaxX - lMinX) else spanX
        val lSpanZ = if (obbUsable) max(1.5f, lMaxZ - lMinZ) else spanZ
        val lCx = if (obbUsable) (lMinX + lMaxX) * 0.5f else 0.0f
        val lCz = if (obbUsable) (lMinZ + lMaxZ) * 0.5f else 0.0f

        val grossArea = max(usableArea * 1.22f, lSpanX * lSpanZ)

        val dimensions = HouseDimensions(
            totalWidth = lSpanX,
            totalDepth = lSpanZ,
            ceilingHeight = maxH,
            grossFloorArea = grossArea,
            usableFloorArea = max(usableArea, lSpanX * lSpanZ * 0.78f)
        )

        // 3. 立极中宫点 (Centroid)
        var cx = (minX + maxX) * 0.5f
        var cz = (minZ + maxZ) * 0.5f
        if (obbUsable) {
            val obbCenter = toWorld(Vec2f(lCx, lCz))
            cx = obbCenter.x
            cz = obbCenter.y
        }
        val roomAreaRatio = usableArea / max(grossArea, 0.01f)
        var isCentroidIndirect = false
        if (centroidOverride != null && centroidOverride.x.isFinite() && centroidOverride.z.isFinite()) {
            if (obbUsable) {
                val local = toLocal(Vec2f(centroidOverride.x, centroidOverride.z))
                val clamped = Vec2f(
                    min(lMaxX, max(lMinX, local.x)),
                    min(lMaxZ, max(lMinZ, local.y))
                )
                val world = toWorld(clamped)
                cx = world.x
                cz = world.y
            } else {
                cx = min(max(centroidOverride.x, minX), maxX)
                cz = min(max(centroidOverride.z, minZ), maxZ)
            }
        } else if (roomAreaRatio < 0.75f) {
            val largest = rooms.maxByOrNull { it.areaSqMeters }
            if (largest != null) {
                cx = largest.centerX
                cz = largest.centerZ
                isCentroidIndirect = true
            }
        }
        val centroid = Vec3f(cx, 0.0f, cz)

        // 4. 全屋形煞体检核心逻辑
        val shaItems = mutableListOf<HouseSpatialShaItem>()
        var score = 92

        // A. 中宫受污检测
        val centerLocal = toLocal(Vec2f(cx, cz))
        val centerBoxMinX = centerLocal.x - lSpanX / 6.0f
        val centerBoxMaxX = centerLocal.x + lSpanX / 6.0f
        val centerBoxMinZ = centerLocal.y - lSpanZ / 6.0f
        val centerBoxMaxZ = centerLocal.y + lSpanZ / 6.0f

        for (room in rooms) {
            var rLMinX = Float.MAX_VALUE
            var rLMaxX = -Float.MAX_VALUE
            var rLMinZ = Float.MAX_VALUE
            var rLMaxZ = -Float.MAX_VALUE
            for (corner in roomCorners(room)) {
                val lc = toLocal(corner)
                rLMinX = min(rLMinX, lc.x); rLMaxX = max(rLMaxX, lc.x)
                rLMinZ = min(rLMinZ, lc.y); rLMaxZ = max(rLMaxZ, lc.y)
            }

            val overlapX = max(0f, min(centerBoxMaxX, rLMaxX) - max(centerBoxMinX, rLMinX))
            val overlapZ = max(0f, min(centerBoxMaxZ, rLMaxZ) - max(centerBoxMinZ, rLMinZ))
            val overlapArea = overlapX * overlapZ

            if (overlapArea > 0.4f) {
                if (room.type == FloorplanRoomType.BATHROOM) {
                    shaItems.add(HouseSpatialShaItem(
                        title = "中宫受污 (水浸太极)",
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = "房屋中宫·${room.name}",
                        detail = "《撼龙经》原文有“水浸心包，家门困耗”之说。卫生间位于房屋中心属于该典籍语境下的布局象征，请结合防水、排水、通风、干燥和动线现场复核；古籍语句不等同于现实诊断。",
                        fengshuiLore = "出处：《撼龙经》。解释：古籍以中心落水象征家门困耗，属于传统堪舆叙事，实际房屋问题仍以现场检查为准。",
                        solution = "优先检查防水、排水、排风和检修条件，保持地面干燥、通道清晰；改造前咨询具备资质的专业人员。",
                        coordinate = room.center
                    ))
                    score -= 16
                } else if (room.type == FloorplanRoomType.KITCHEN) {
                    shaItems.add(HouseSpatialShaItem(
                        title = "火烧中宫 (燥火焚心)",
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = "房屋中宫·${room.name}",
                        detail = "全屋中心被厨房或灶台占据，属于传统文化中的布局提示，请结合实际通风、动线与安全条件复核。",
                        fengshuiLore = "出处：《八宅明镜》原文：“火居天心，病染胸膈”。解释：古籍将中心火象与疾病作象征关联，属于传统文化原文，不是医疗判断。",
                        solution = "厨灶移位避开房屋正中心，厨房采用米白或浅黄色地砖引土泄火，灶台下置黄玉石辟火化煞。",
                        coordinate = room.center
                    ))
                    score -= 14
                }
            }
        }

        // B. 穿堂煞检测
        val entranceDoors = openings.filter { it.type == SpatialOpeningType.ENTRANCE_DOOR }
        val exitOpenings = openings.filter { it.type == SpatialOpeningType.BALCONY_DOOR || it.type == SpatialOpeningType.WINDOW }

        for (door in entranceDoors) {
            val dPos = Vec2f(door.posX, door.posZ)
            val dNormal = Vec2f(door.normalX, door.normalZ)
            val dLen = dNormal.length()
            if (dLen <= 1e-4f) continue
            val dNorm = dNormal / dLen

            for (win in exitOpenings) {
                val wPos = Vec2f(win.posX, win.posZ)
                val toWin = wPos - dPos
                val inward = if (dNorm.dot(if (toWin.length() > 1e-5f) toWin / toWin.length() else dNorm) >= 0f) dNorm else dNorm * -1f
                val startPos = dPos + inward * 0.3f
                val endPos = wPos

                val ray = endPos - startPos
                val dist = ray.length()
                if (dist !in 2.5f..20.0f) continue

                val rayDir = ray / dist
                val angleTolerance = abs(dNorm.dot(rayDir))
                if (angleTolerance < 0.65f) continue

                val isBlockedByWall = walls.any { wall ->
                    val wA = Vec2f(wall.startX, wall.startZ)
                    val wB = Vec2f(wall.endX, wall.endZ)
                    val t = lineIntersectionParam(startPos, endPos, wA, wB)
                    if (t != null) {
                        val hit = startPos + ray * t
                        val openingCovered = openings.any { op ->
                            op.type == SpatialOpeningType.OPENING && Vec2f(op.posX, op.posZ).distance(hit) < max(0.6f, op.width * 0.55f)
                        }
                        !openingCovered
                    } else {
                        false
                    }
                }

                if (!isBlockedByWall) {
                    val exitName = if (win.type == SpatialOpeningType.BALCONY_DOOR) "阳台移门" else "主采光窗"
                    shaItems.add(HouseSpatialShaItem(
                        title = "穿堂穿心煞 (前通后泄)",
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = "入户大门 ⟷ $exitName (间距 ${String.format(Locale.US, "%.1f", dist)}m)",
                        detail = "大门与外门窗直线通透（间距 ${String.format(Locale.US, "%.1f", dist)} 米），古籍有“前通后通，人财两空”之说，请关注风速、视线阻隔与保温隔热。",
                        fengshuiLore = "出处：《阳宅十书》。解释：古籍描述直通风道导致气场散失，属于传统堪舆判断，不是现实经济结论。",
                        solution = "在入户玄关处设立不透光屏风或玄关柜，令进门气流‘曲则有情’回旋蓄纳；阳台悬挂双层厚纱帘常掩化解。",
                        coordinate = door.position,
                        vectorEnd = win.position
                    ))
                    score -= 15
                    break
                }
            }
        }

        // C. 对门煞 (对门相冲·骂门煞)
        val doors = openings.filter { it.type == SpatialOpeningType.ENTRANCE_DOOR || it.type == SpatialOpeningType.INTERIOR_DOOR }
        for (i in doors.indices) {
            val d1 = doors[i]
            val p1 = Vec2f(d1.posX, d1.posZ)
            val n1 = Vec2f(d1.normalX, d1.normalZ).normalized()
            for (j in i + 1 until doors.size) {
                val d2 = doors[j]
                val p2 = Vec2f(d2.posX, d2.posZ)
                val n2 = Vec2f(d2.normalX, d2.normalZ).normalized()

                val delta = p2 - p1
                val dist = delta.length()
                if (dist !in 0.8f..4.5f) continue

                val ray1 = delta / dist
                val align1 = abs(n1.dot(ray1))
                val align2 = abs(n2.dot(ray1))
                val faceScore = n1.dot(n2)
                if (align1 >= 0.82f && align2 >= 0.82f && faceScore <= -0.6f) {
                    val d1Name = if (d1.type == SpatialOpeningType.ENTRANCE_DOOR) "入户大门" else "房门"
                    val d2Name = if (d2.type == SpatialOpeningType.ENTRANCE_DOOR) "入户大门" else "房门"
                    shaItems.add(HouseSpatialShaItem(
                        title = "门门相对 (对门相冲)",
                        severity = SpatialShaSeverity.WARNING,
                        locationName = "$d1Name ⟷ $d2Name (间距 ${String.format(Locale.US, "%.1f", dist)}m)",
                        detail = "两门直对形成穿对气流，属于传统生活经验中对视线干扰与私密性的关照，请结合起居习惯与动线复核。",
                        fengshuiLore = "《鲁班经》云：'两门相对谓相骂，主家不和口舌频'。门对冲气场互斥碰撞，气场不顺。",
                        solution = "各房门悬挂过膝整幅布帘（无缝），两门平时避免同时敞开，或在两门之间摆放阔叶盆栽过渡遮挡。",
                        coordinate = d1.position,
                        vectorEnd = d2.position
                    ))
                    score -= 8
                }
            }
        }

        // D. 横梁压顶检测
        val targets = objects.filter { it.category == "bed" || it.category == "sofa" }
        for (beam in beams) {
            val b1 = Vec2f(beam.startX, beam.startZ)
            val b2 = Vec2f(beam.endX, beam.endZ)
            if (beam.clearanceHeight > 2.35f) continue

            for (target in targets) {
                val tPos = Vec2f(target.posX, target.posZ)
                val distToBeam = distancePointToSegment(tPos, b1, b2)
                if (distToBeam <= 0.85f) {
                    val targetName = if (target.category == "bed") "睡床" else "主位沙发"
                    shaItems.add(HouseSpatialShaItem(
                        title = "横梁压顶煞 (气压沉重)",
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = "${targetName}正上方 (净高${String.format(Locale.US, "%.2f", beam.clearanceHeight)}m)",
                        detail = String.format(Locale.US, "沉重承重横梁横跨在%s上方，下垂气流形成沉降重压，久居易头痛压抑、精神衰弱。", targetName),
                        fengshuiLore = "《鲁班经》云：'横梁压顶若悬斧，身染沉疴气数枯'。横梁下空气受阻下压，人处于其下受气场冲煞。",
                        solution = "将床铺或沙发平移挪出横梁投影区；若无法挪位，建议做平吊顶包梁隐藏，或梁两端悬挂开光铜葫芦泄压。",
                        coordinate = Vec3f(target.posX, beam.clearanceHeight, target.posZ)
                    ))
                    score -= 12
                    break
                }
            }
        }

        // E. 门冲床位检测
        val beds = objects.filter { it.category == "bed" }
        for (door in doors) {
            val dPos = Vec2f(door.posX, door.posZ)
            val dNorm = Vec2f(door.normalX, door.normalZ)
            for (bed in beds) {
                val bPos = Vec2f(bed.posX, bed.posZ)
                val delta = bPos - dPos
                val dist = delta.length()
                if (dist !in 0.8f..3.8f) continue
                val alignment = dNorm.dot(delta / dist)
                val lateral = dist * sqrt(max(0f, 1.0f - alignment * alignment))
                if (alignment >= 0.82f && lateral <= 0.65f) {
                    shaItems.add(HouseSpatialShaItem(
                        title = "房门冲床 (冲撞身魂)",
                        severity = SpatialShaSeverity.WARNING,
                        locationName = "房门 ⟷ 卧床",
                        detail = String.format(Locale.US, "房门与床铺形成直线气流（间距 %.1f 米），建议结合实际通风、噪音与动线调整布局。", dist),
                        fengshuiLore = "门开气入直射人身，动静失衡，神魂不聚。",
                        solution = "微调床头朝向或位置避开门冲直线，若空间受限可在门边设遮挡隔断或门挂长帘缓冲。",
                        coordinate = door.position,
                        vectorEnd = bed.position
                    ))
                    score -= 8
                    break
                }
            }
        }

        // F. 水火相冲 (厨灶与卫浴马桶或水槽近距离对立)
        val stoves = objects.filter { it.category == "stove" || it.category == "oven" }
        val toilets = objects.filter { it.category == "toilet" || it.category == "bathtub" }
        for (stove in stoves) {
            val sPos = Vec2f(stove.posX, stove.posZ)
            for (toilet in toilets) {
                val tPos = Vec2f(toilet.posX, toilet.posZ)
                val dist = sPos.distance(tPos)
                if (dist <= 2.2f) {
                    shaItems.add(HouseSpatialShaItem(
                        title = "水火未济 (厨厕相逼)",
                        severity = SpatialShaSeverity.WARNING,
                        locationName = "灶台 ⟷ 卫浴 (间距 ${String.format(Locale.US, "%.1f", dist)}m)",
                        detail = "《催官篇》原文有“水火不相容，宅母病腹痛”。灶台与卫浴距离较近，按古籍象征会被解释为水火相逼；请结合热源距离、通风、防水和使用安全复核。",
                        fengshuiLore = "出处：《催官篇》。解释：原文把水火同宫与腹痛相联系，是传统象征性叙述，不是医疗诊断。",
                        solution = "炉灶与卫生间门错开避对，两者之间摆放常青绿植（木元素）以形成'水生木、木生火'通关调和。",
                        coordinate = stove.position,
                        vectorEnd = toilet.position
                    ))
                    score -= 7
                    break
                }
            }
        }

        // G. 入户大门鲁班门光吉度评定
        val firstMainDoor = entranceDoors.firstOrNull()
        if (firstMainDoor != null) {
            val eval = LubanRulerEvaluation.evaluate(firstMainDoor.width)
            if (eval.yangIsAuspicious) {
                shaItems.add(HouseSpatialShaItem(
                    title = "鲁班门光尺 · 大门纳吉",
                    severity = SpatialShaSeverity.AUSPICIOUS,
                    locationName = "入户大门 (宽 ${String.format(Locale.US, "%.2f", firstMainDoor.width)}m)",
                    detail = String.format(Locale.US, "入户门开间度量合鲁班门光尺【%s】字门，迎祥纳福，广纳正气生机。", eval.yangSegmentName),
                    fengshuiLore = "鲁班先师制尺定度，八寸循环纳吉，门吉则气正。",
                    solution = "大门尺寸得吉，宜保持玄关整洁明亮，门前不堆杂物，使吉气源源入户。",
                    coordinate = firstMainDoor.position
                ))
                score += 5
            } else {
                shaItems.add(HouseSpatialShaItem(
                    title = "鲁班门光尺 · 大门失度",
                    severity = SpatialShaSeverity.WARNING,
                    locationName = "入户大门 (宽 ${String.format(Locale.US, "%.2f", firstMainDoor.width)}m)",
                    detail = String.format(Locale.US, "大门宽度落入鲁班门光尺【%s】凶度字门，门气略有亏耗。", eval.yangSegmentName),
                    fengshuiLore = "门不合度，气散难聚。",
                    solution = "可优先确认门槛、地垫和通道尺寸，保持入口平整防滑；涉及改造时咨询具备资质的专业人员。",
                    coordinate = firstMainDoor.position
                ))
                score -= 4
            }
        }

        // H. 户型规整度与开间进深比
        if (dimensions.aspectRatio > 2.2f) {
            shaItems.add(HouseSpatialShaItem(
                title = "户型狭长 (深长损明)",
                severity = SpatialShaSeverity.WARNING,
                locationName = "整体户型轮廓",
                detail = String.format(Locale.US, "全屋进深是开间的 %.1f 倍，形如长巷，中段采光通风弱，阴阳气流失衡。", dimensions.aspectRatio),
                fengshuiLore = "方正者气厚，狭长者气薄。",
                solution = "室内中部走道采用镜面扩容与明亮照明，多设绿植增补生旺之气。",
                coordinate = centroid
            ))
            score -= 6
        }

        // I. 进门见灶检测 (开门见灶·钱财多耗)
        for (door in entranceDoors) {
            val dPos = Vec2f(door.posX, door.posZ)
            val dNorm = Vec2f(door.normalX, door.normalZ)
            for (stove in stoves) {
                val sPos = Vec2f(stove.posX, stove.posZ)
                val delta = sPos - dPos
                val dist = delta.length()
                if (dist !in 1.2f..7.0f) continue
                val ray = delta / dist
                val alignment = dNorm.dot(ray)
                val lateral = dist * sqrt(max(0f, 1.0f - alignment * alignment))
                if (alignment >= 0.78f && lateral <= 1.1f) {
                    shaItems.add(HouseSpatialShaItem(
                        title = "开门见灶 (入口视线提示)",
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = "入户大门 ⟷ 厨灶",
                        detail = String.format(Locale.US, "《阳宅集成》原文有“开门见灶，钱财多耗”。入户门开启正对厨房炉灶（间距 %.1f 米），古籍将其解释为财耗象征；请关注入口视线、热源距离、通风和防火安全。", dist),
                        fengshuiLore = "出处：《阳宅集成》。解释：原文中的“钱财多耗”是传统文化判断，实际财务事项不由空间测算决定。",
                        solution = "在大门与厨房之间设置玄关柜或挂隔断门帘，平时厨房推拉门常闭以避穿冲。",
                        coordinate = door.position,
                        vectorEnd = stove.position
                    ))
                    score -= 10
                    break
                }
            }
        }

        // J. 开门见厕检测 (秽气迎门)
        for (door in entranceDoors) {
            val dPos = Vec2f(door.posX, door.posZ)
            val dNorm = Vec2f(door.normalX, door.normalZ)
            for (toilet in toilets) {
                val tPos = Vec2f(toilet.posX, toilet.posZ)
                val delta = tPos - dPos
                val dist = delta.length()
                if (dist !in 1.0f..6.5f) continue
                val ray = delta / dist
                val alignment = dNorm.dot(ray)
                val lateral = dist * sqrt(max(0f, 1.0f - alignment * alignment))
                if (alignment >= 0.78f && lateral <= 1.0f) {
                    shaItems.add(HouseSpatialShaItem(
                        title = "开门见厕 (门迎污秽)",
                        severity = SpatialShaSeverity.WARNING,
                        locationName = "入户大门 ⟷ 卫浴",
                        detail = String.format(Locale.US, "入户大门直对卫生间门（间距 %.1f 米），进门吉气易受秽气冲染，退财损客。", dist),
                        fengshuiLore = "门开纳旺，厕出浊阴。阴阳杂驳，门庭不宁。",
                        solution = "卫生间门常闭，门上加挂及膝长布帘，门内摆放阔叶常青绿植（虎皮兰）净化气场。",
                        coordinate = door.position,
                        vectorEnd = toilet.position
                    ))
                    score -= 8
                    break
                }
            }
        }

        // K. 厨厕同壁 (水火相逼)
        val kitchens = rooms.filter { it.type == FloorplanRoomType.KITCHEN }
        val bathrooms = rooms.filter { it.type == FloorplanRoomType.BATHROOM }
        for (k in kitchens) {
            val kPos = Vec2f(k.centerX, k.centerZ)
            for (b in bathrooms) {
                val bPos = Vec2f(b.centerX, b.centerZ)
                val centerDist = kPos.distance(bPos)
                val boundThreshold = (k.sizeX + b.sizeX) * 0.5f + 0.35f
                if (centerDist <= boundThreshold) {
                    shaItems.add(HouseSpatialShaItem(
                        title = "厨厕同壁 (水火同宫)",
                        severity = SpatialShaSeverity.WARNING,
                        locationName = "${k.name} ⟷ ${b.name} 共用隔墙",
                        detail = "厨房与卫生间共用隔墙，水火气场仅一墙之隔，若灶台贴卫生间马桶排污管同侧尤其不利。",
                        fengshuiLore = "水火交加，阴阳相克。灶贴阴水，家道受挫。",
                        solution = "灶台移离共用隔墙至少 0.5 米；隔墙做防水防潮加厚处理，瓷砖选择黄色或浅咖色土属性调和水火。",
                        coordinate = k.center
                    ))
                    score -= 6
                    break
                }
            }
        }

        // L. 床头悬空无靠 (无靠山煞)
        for (bed in beds) {
            val bPos = Vec2f(bed.posX, bed.posZ)
            val distToClosestWall = walls.map { w ->
                val w1 = Vec2f(w.startX, w.startZ)
                val w2 = Vec2f(w.endX, w.endZ)
                distancePointToSegment(bPos, w1, w2)
            }.minOrNull() ?: 1.0f

            if (distToClosestWall > 0.65f) {
                shaItems.add(HouseSpatialShaItem(
                    title = "床头悬空 (背后无靠)",
                    severity = SpatialShaSeverity.WARNING,
                    locationName = "睡床 (距最近实墙 ${String.format(Locale.US, "%.2f", distToClosestWall)}m)",
                    detail = "睡床四面皆虚、未贴实墙摆放，头部后方气流空荡无实，睡眠易惊悸不宁、少贵人庇护。",
                    fengshuiLore = "靠山稳固，行事有依。虚悬无托，心神不宁。",
                    solution = "将床头平移紧贴实体承重墙或隔断实墙摆放；若户型限制无法移位，务必配置厚重高靠背实木床头板。",
                    coordinate = bed.position
                ))
                score -= 7
            }
        }

        // M. 暗室无窗 (孤阴重闭)
        val habitableRooms = rooms.filter {
            it.type == FloorplanRoomType.MASTER_BEDROOM ||
            it.type == FloorplanRoomType.SECOND_BEDROOM ||
            it.type == FloorplanRoomType.LIVING_ROOM
        }
        val windows = openings.filter { it.type == SpatialOpeningType.WINDOW || it.type == SpatialOpeningType.BALCONY_DOOR }
        for (r in habitableRooms) {
            val rPos = Vec2f(r.centerX, r.centerZ)
            val hasWindow = windows.any { w ->
                val wPos = Vec2f(w.posX, w.posZ)
                rPos.distance(wPos) <= max(r.sizeX, r.sizeZ) * 0.75f + 0.5f
            }
            if (!hasWindow) {
                shaItems.add(HouseSpatialShaItem(
                    title = "暗室无窗 (孤阴不生)",
                    severity = SpatialShaSeverity.WARNING,
                    locationName = "${r.name} (无直接采光外窗)",
                    detail = "主要起居房间缺乏直接对外的采光通风窗，阳气难以入室，阴湿之气易淤积，长居易气滞神疲。",
                    fengshuiLore = "孤阴不生，独阳不长。宅需明堂，室借阳光。",
                    solution = "加装强力新风系统保持空气流通，采用全光谱高显色暖白光源模拟自然日光，室内布置明亮浅色软装。",
                    coordinate = r.center
                ))
                score -= 6
            }
        }

        // N. 八宅吉凶宫位体检 (基于罗盘实测朝向)
        val facingGua = guaForAngle(compassHeading)
        val sittingAngle = (compassHeading + 180.0) % 360.0
        val sittingGua = guaForAngle(sittingAngle)
        val bazhai = BaZhaiEngine.instance.analyze(sittingGua, facingGua)

        for (room in rooms) {
            val relX = room.centerX - cx
            val relZ = room.centerZ - cz
            val angleFromCenterRad = atan2(relX.toDouble(), -relZ.toDouble())
            val angleFromCenterDeg = (angleFromCenterRad * 180.0 / Math.PI + 360.0) % 360.0
            val geoAngle = (angleFromCenterDeg + compassHeading) % 360.0
            val roomGua = guaForAngle(geoAngle)

            val item = bazhai.items.firstOrNull { it.guaName == roomGua }
            if (item != null) {
                if (room.type == FloorplanRoomType.BATHROOM && (item.star == StarLuckType.SHENG_QI || item.star == StarLuckType.YAN_NIAN || item.star == StarLuckType.TIAN_YI)) {
                    shaItems.add(HouseSpatialShaItem(
                        title = "吉位落水 (污秽吉星)",
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = "${room.name} · 落于【${item.star.name}】大吉方",
                        detail = String.format(Locale.US, "卫生间落在全屋八宅【%s】方位，属于传统文化中的布局提示，请结合实际防水、通风和使用情况复核。", item.star.name),
                        fengshuiLore = "《八宅明镜》云：'吉星落厕，吉亦成殃'。生气延年宜作卧房书斋，不宜落水。",
                        solution = "卫生间马桶上方摆放一盆金边虎尾兰以木吸水，挂置开光纯铜葫芦收敛秽气护持吉星。",
                        coordinate = room.center
                    ))
                    score -= 12
                } else if ((room.type == FloorplanRoomType.MASTER_BEDROOM || room.type == FloorplanRoomType.SECOND_BEDROOM) && item.star.isAuspicious) {
                    shaItems.add(HouseSpatialShaItem(
                        title = "卧房得位 · 纳气归真",
                        severity = SpatialShaSeverity.AUSPICIOUS,
                        locationName = "${room.name} · 落于【${item.star.name}】吉方",
                        detail = String.format(Locale.US, "卧房得八宅【%s】吉位气场滋养，身心安宁，元神具足。", item.star.name),
                        fengshuiLore = "居吉方则养浩然，气合于度，夜寐神安。",
                        solution = "床铺宜常保整洁通风，床头配暖黄柔光灯以迎合吉星气象。",
                        coordinate = room.center
                    ))
                    score += 5
                }
            }
        }

        // O. 三元九运玄空飞星理气体检 (形理兼备)
        val facingMountainItem = Mountain24Data.find(compassHeading)
        val sittingMountainItem = Mountain24Data.find(sittingAngle)
        val xkChart = FlyingStarsEngine.instance.calculateChart(
            sitting = sittingMountainItem,
            facing = facingMountainItem
        )
        val curPeriod = xkChart.period

        val bedrooms = rooms.filter { it.type == FloorplanRoomType.MASTER_BEDROOM || it.type == FloorplanRoomType.SECOND_BEDROOM }

        for (palace in xkChart.palaces) {
            if (palace.isCenter) continue
            val pGua = palace.guaName

            // 1. 五黄大煞 (5) 临门或临床
            if (palace.facingStar == 5 || palace.mountainStar == 5) {
                for (door in entranceDoors) {
                    val dRelX = door.posX - cx
                    val dRelZ = door.posZ - cz
                    val dAngle = (atan2(dRelX.toDouble(), -dRelZ.toDouble()) * 180.0 / Math.PI + compassHeading + 360.0) % 360.0
                    if (guaForAngle(dAngle) == pGua) {
                        shaItems.add(HouseSpatialShaItem(
                            title = "玄空理气煞 · 五黄到门",
                            severity = SpatialShaSeverity.CRITICAL,
                            locationName = "入户大门 · 逢【五黄廉贞】",
                            detail = String.format(Locale.US, "入户大门恰逢九运玄空五黄大煞飞临%s宫（山向 %d-%d），门动引煞，动辄招愆，属理气第一重煞。", palace.palaceName, palace.mountainStar, palace.facingStar),
                            fengshuiLore = "《紫白诀》云：'五黄正关，大病连绵；其性最暴，宜静不宜动'。门为气口，动气最烈。",
                            solution = "入户门内悬挂纯铜六帝钱（金泄土煞）或挂开光铜钟，门前避免放置红黄色地垫以防助火生土。",
                            coordinate = door.position
                        ))
                        score -= 15
                        break
                    }
                }
                for (bed in beds) {
                    val bRelX = bed.posX - cx
                    val bRelZ = bed.posZ - cz
                    val bAngle = (atan2(bRelX.toDouble(), -bRelZ.toDouble()) * 180.0 / Math.PI + compassHeading + 360.0) % 360.0
                    if (guaForAngle(bAngle) == pGua) {
                        shaItems.add(HouseSpatialShaItem(
                            title = "玄空理气参考 · 五黄加枕",
                            severity = SpatialShaSeverity.CRITICAL,
                            locationName = "睡床枕位 · 逢【五黄廉贞】",
                            detail = String.format(Locale.US, "《紫白诀》原文有“五黄加临，家多病患”。睡床落入五黄飞临之%s宫（山向 %d-%d），古籍将其解释为病患象征，请结合通风、采光和实际舒适度复核。", palace.palaceName, palace.mountainStar, palace.facingStar),
                            fengshuiLore = "出处：《紫白诀》。解释：此处展示古籍原句及其传统含义，不构成健康诊断。",
                            solution = "床位微调避开五黄正对方位，床头柜放置天然纯铜葫芦化解土煞。",
                            coordinate = bed.position
                        ))
                        score -= 12
                        break
                    }
                }
            }

            // 2. 二黑病符星 (2) 临卧房
            if (palace.mountainStar == 2 || palace.facingStar == 2) {
                for (br in bedrooms) {
                    val brRelX = br.centerX - cx
                    val brRelZ = br.centerZ - cz
                    val brAngle = (atan2(brRelX.toDouble(), -brRelZ.toDouble()) * 180.0 / Math.PI + compassHeading + 360.0) % 360.0
                    if (guaForAngle(brAngle) == pGua) {
                        shaItems.add(HouseSpatialShaItem(
                            title = "玄空理气参考 · 二黑星临卧",
                            severity = SpatialShaSeverity.WARNING,
                            locationName = "${br.name} · 逢【二黑病符】",
                            detail = String.format(Locale.US, "《飞星赋》原文有“二黑逢五，病生胸腹”。%s坐落于二黑巨门星飞临之%s宫（山向 %d-%d），古籍将其解释为病符象征，请结合通风、采光、噪音和使用情况复核。", br.name, palace.palaceName, palace.mountainStar, palace.facingStar),
                            fengshuiLore = "出处：《飞星赋》。解释：展示二黑星的古籍象征，不构成健康诊断。",
                            solution = "卧房悬挂天然开光晒干葫芦或六帝钱以金泄土，室内避免大红厚毯。",
                            coordinate = br.center
                        ))
                        score -= 8
                        break
                    }
                }
            }

            // 3. 当令旺星纳气 (9运向星飞临大门)
            if (palace.facingStar == curPeriod) {
                for (door in entranceDoors) {
                    val dRelX = door.posX - cx
                    val dRelZ = door.posZ - cz
                    val dAngle = (atan2(dRelX.toDouble(), -dRelZ.toDouble()) * 180.0 / Math.PI + compassHeading + 360.0) % 360.0
                    if (guaForAngle(dAngle) == pGua) {
                        shaItems.add(HouseSpatialShaItem(
                            title = "玄空旺星纳气 (空间参考)",
                            severity = SpatialShaSeverity.AUSPICIOUS,
                            locationName = "入户大门 · 逢【当旺向星】",
                            detail = String.format(Locale.US, "入户门迎当前%d运当旺向星飞临%s宫（山向 %d-%d），属于传统文化中的方位提示，请结合入口采光、通风、视线和动线复核。", curPeriod, palace.palaceName, palace.mountainStar, palace.facingStar),
                            fengshuiLore = "《天玉经》云：'向首一星灾福柄，当旺乘时发万箱'。",
                            solution = "门厅保持明堂整洁开阔，设暖白长明灯引气入宅，生旺气场。",
                            coordinate = door.position
                        ))
                        score += 8
                        break
                    }
                }
            }
        }

        // O.1 玄空出卦 · 空亡破局煞
        if (firstMainDoor != null) {
            val probe = CompassHeadingState(
                heading = compassHeading,
                facingAngle = compassHeading,
                facingMountain = Mountain24Data.find(compassHeading),
                sittingMountain = Mountain24Data.find(sittingAngle)
            )
            val kwLevel = probe.kongWangLevel
            if (kwLevel != KongWangLevel.PURE) {
                val isMajor = kwLevel == KongWangLevel.LARGE_VOID
                val isSmall = kwLevel == KongWangLevel.SMALL_VOID
                shaItems.add(HouseSpatialShaItem(
                    title = "玄空出卦 · 空亡破局煞",
                    severity = SpatialShaSeverity.CRITICAL,
                    locationName = "入户大门 · ${kwLevel.title}",
                    detail = if (isMajor)
                        String.format(Locale.US, "大门朝向 %.1f° 正踏八卦大卦交界缝（大空亡绝线），五行错乱、阴阳差错，下卦排盘失效，必须以【替卦】重起九宫，属理气极凶出线。", compassHeading)
                    else if (isSmall)
                        String.format(Locale.US, "大门朝向 %.1f° 贴近同宫两山交界（小空亡出卦），气杂不纯、阴差阳错，须以【兼向替卦】排盘化解。", compassHeading)
                    else
                        String.format(Locale.US, "大门朝向 %.1f° 处于兼向（替卦）区间，气场微杂驳纯，建议按替卦挨星排盘校验旺衰。", compassHeading),
                    fengshuiLore = "堪舆古训：'出卦差错出孤寡，空亡线遇鬼神惊'。正针气场已乱，须以沈氏玄空替卦诀重排九宫飞星。",
                    solution = if (isMajor)
                        "此线极凶，宜用实测罗盘复核坐向，优先整体挪门或以玄关斜向引气避开绝线；理气按【三元九运·替卦排盘】断验，忌择此线动土安门。"
                    else if (isSmall)
                        "玄关/门厅设斜向过渡区导气，理气按【三元九运·替卦排盘】校验旺衰，择吉时安门更佳。"
                    else
                        "玄关加设门帘缓气，理气按【三元九运·替卦排盘】校验旺衰即可。",
                    coordinate = firstMainDoor.position
                ))
                score -= (if (isMajor) 18 else if (isSmall) 12 else 6)
            }
        }

        return HouseSpatialSurvey(
            scanMethod = scanMethod,
            dimensions = dimensions,
            walls = walls,
            openings = openings,
            beams = beams,
            rooms = rooms,
            objects = objects,
            centroidX = centroid.x,
            centroidY = centroid.y,
            centroidZ = centroid.z,
            compassHeading = compassHeading,
            shaItems = shaItems,
            fengshuiScore = max(0, min(100, score)),
            isCentroidIndirect = isCentroidIndirect
        )
    }

    fun guaForAngle(angleDeg: Double): String {
        val normalized = (angleDeg % 360.0 + 360.0) % 360.0
        return when {
            normalized in 22.5..67.5 -> "艮"
            normalized in 67.5..112.5 -> "震"
            normalized in 112.5..157.5 -> "巽"
            normalized in 157.5..202.5 -> "离"
            normalized in 202.5..247.5 -> "坤"
            normalized in 247.5..292.5 -> "兑"
            normalized in 292.5..337.5 -> "乾"
            else -> "坎"
        }
    }

    private fun lineSegmentIntersection(
        p1: Vec2f, p2: Vec2f,
        p3: Vec2f, p4: Vec2f
    ): Boolean {
        fun ccw(a: Vec2f, b: Vec2f, c: Vec2f): Boolean {
            return (c.y - a.y) * (b.x - a.x) > (b.y - a.y) * (c.x - a.x)
        }
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    private fun lineIntersectionParam(
        p1: Vec2f, p2: Vec2f,
        p3: Vec2f, p4: Vec2f
    ): Float? {
        val r = p2 - p1
        val s = p4 - p3
        val rxs = r.x * s.y - r.y * s.x
        if (abs(rxs) <= 1e-6f || r.length() <= 1e-4f || s.length() <= 1e-4f) return null
        val q = p3 - p1
        val t = (q.x * s.y - q.y * s.x) / rxs
        val u = (q.x * r.y - q.y * r.x) / rxs
        if (t in 0.0f..1.0f && u in 0.0f..1.0f) {
            return t
        }
        return null
    }

    private fun primaryAxisAngle(walls: List<SpatialWall3D>): Float {
        var longestLen = 0f
        var bestAngle = 0f
        for (w in walls) {
            val dx = w.endX - w.startX
            val dz = w.endZ - w.startZ
            val len = sqrt(dx * dx + dz * dz)
            if (len > longestLen) {
                longestLen = len
                var a = atan2(dz, dx)
                while (a < 0f) a += Math.PI.toFloat()
                while (a >= Math.PI.toFloat()) a -= Math.PI.toFloat()
                bestAngle = a
            }
        }
        return bestAngle
    }

    private fun distancePointToSegment(point: Vec2f, segA: Vec2f, segB: Vec2f): Float {
        val ab = segB - segA
        val lenSq = ab.x * ab.x + ab.y * ab.y
        if (lenSq < 1e-6f) return point.distance(segA)
        val ap = point - segA
        val t = max(0f, min(1f, (ap.x * ab.x + ap.y * ab.y) / lenSq))
        val proj = segA + ab * t
        return point.distance(proj)
    }
}
