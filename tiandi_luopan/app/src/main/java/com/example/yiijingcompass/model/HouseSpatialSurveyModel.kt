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
    CRITICAL("严重", "#FF3B30");

    val localizedTitle: String
        get() = when (LocalizationManager.instance.effectiveLanguage) {
            AppLanguage.EN -> when (this) {
                AUSPICIOUS -> "Auspicious"
                WARNING -> "Caution"
                CRITICAL -> "Severe"
            }
            AppLanguage.ZH_HANT -> when (this) {
                AUSPICIOUS -> "吉"
                WARNING -> "輕微"
                CRITICAL -> "嚴重"
            }
            AppLanguage.JA -> when (this) {
                AUSPICIOUS -> "吉"
                WARNING -> "注意"
                CRITICAL -> "重大"
            }
            AppLanguage.KO -> when (this) {
                AUSPICIOUS -> "길"
                WARNING -> "주의"
                CRITICAL -> "심각"
            }
            AppLanguage.VI -> when (this) {
                AUSPICIOUS -> "Cát"
                WARNING -> "Lưu ý"
                CRITICAL -> "Nghiêm trọng"
            }
            AppLanguage.TH -> when (this) {
                AUSPICIOUS -> "มงคล"
                WARNING -> "เฝ้าระวัง"
                CRITICAL -> "รุนแรง"
            }
            AppLanguage.ID -> when (this) {
                AUSPICIOUS -> "Baik"
                WARNING -> "Perhatian"
                CRITICAL -> "Parah"
            }
            AppLanguage.ZH_HANS, AppLanguage.AUTO -> rawValue
        }
}

enum class SpatialOpeningType(val rawValue: String) {
    ENTRANCE_DOOR("入户大门"),
    INTERIOR_DOOR("房间门"),
    WINDOW("主采光窗"),
    OPENING("垭口开口"),
    BALCONY_DOOR("阳台移门");

    val localizedName: String
        get() = when (LocalizationManager.instance.effectiveLanguage) {
            AppLanguage.EN -> when (this) {
                ENTRANCE_DOOR -> "Main Entrance"
                INTERIOR_DOOR -> "Interior Door"
                WINDOW -> "Main Window"
                OPENING -> "Pass-Through Opening"
                BALCONY_DOOR -> "Balcony Sliding Door"
            }
            AppLanguage.ZH_HANT -> when (this) {
                ENTRANCE_DOOR -> "入戶大門"
                INTERIOR_DOOR -> "房間門"
                WINDOW -> "主採光窗"
                OPENING -> "埡口開口"
                BALCONY_DOOR -> "陽台移門"
            }
            AppLanguage.JA -> when (this) {
                ENTRANCE_DOOR -> "玄関ドア"
                INTERIOR_DOOR -> "室内ドア"
                WINDOW -> "採光窓"
                OPENING -> "開口部"
                BALCONY_DOOR -> "バルコニー引き戸"
            }
            AppLanguage.KO -> when (this) {
                ENTRANCE_DOOR -> "현관문"
                INTERIOR_DOOR -> "방문"
                WINDOW -> "채광창"
                OPENING -> "개구부"
                BALCONY_DOOR -> "발코니 미닫이문"
            }
            AppLanguage.VI -> when (this) {
                ENTRANCE_DOOR -> "Cửa chính"
                INTERIOR_DOOR -> "Cửa phòng"
                WINDOW -> "Cửa sổ chính"
                OPENING -> "Lối thông"
                BALCONY_DOOR -> "Cửa trượt ban công"
            }
            AppLanguage.TH -> when (this) {
                ENTRANCE_DOOR -> "ประตูทางเข้าหลัก"
                INTERIOR_DOOR -> "ประตูห้อง"
                WINDOW -> "หน้าต่างหลัก"
                OPENING -> "ช่องทางเชื่อม"
                BALCONY_DOOR -> "ประตูบานเลื่อนระเบียง"
            }
            AppLanguage.ID -> when (this) {
                ENTRANCE_DOOR -> "Pintu Utama"
                INTERIOR_DOOR -> "Pintu Kamar"
                WINDOW -> "Jendela Utama"
                OPENING -> "Bukaan Lorong"
                BALCONY_DOOR -> "Pintu Geser Balkon"
            }
            AppLanguage.ZH_HANS, AppLanguage.AUTO -> rawValue
        }
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

    val localizedYangSegmentName: String
        get() = when (LocalizationManager.instance.effectiveLanguage) {
            AppLanguage.ZH_HANS, AppLanguage.AUTO -> yangNamesHans[yangGateIndex]
            AppLanguage.ZH_HANT, AppLanguage.JA -> yangNamesHant[yangGateIndex]
            AppLanguage.EN -> yangNamesEn[yangGateIndex]
            AppLanguage.VI -> yangNamesVi[yangGateIndex]
            AppLanguage.TH -> yangNamesTh[yangGateIndex]
            AppLanguage.ID -> yangNamesId[yangGateIndex]
            AppLanguage.KO -> yangNamesKo[yangGateIndex]
        }

    val yinSegmentName: String
        get() = yinNamesHans[yinIndex]

    val localizedYinSegmentName: String
        get() = when (LocalizationManager.instance.effectiveLanguage) {
            AppLanguage.ZH_HANS, AppLanguage.AUTO -> yinNamesHans[yinIndex]
            AppLanguage.ZH_HANT, AppLanguage.JA -> yinNamesHant[yinIndex]
            AppLanguage.EN -> yinNamesEn[yinIndex]
            AppLanguage.VI -> yinNamesVi[yinIndex]
            AppLanguage.TH -> yinNamesTh[yinIndex]
            AppLanguage.ID -> yinNamesId[yinIndex]
            AppLanguage.KO -> yinNamesKo[yinIndex]
        }

    companion object {
        private val yangNamesHans = listOf("财", "病", "离", "义", "官", "劫", "害", "本")
        private val yangNamesHant = listOf("財", "病", "離", "義", "官", "劫", "害", "本")
        private val yangNamesEn = listOf("Wealth", "Illness", "Separation", "Righteous", "Official", "Robbery", "Harm", "Origin")
        private val yangNamesVi = listOf("Tài", "Bệnh", "Ly", "Nghĩa", "Quan", "Kiếp", "Hại", "Bổn")
        private val yangNamesTh = listOf("ทรัพย์", "โรค", "พลัดพราก", "คุณธรรม", "ยศ", "สูญเสีย", "ภัย", "รากฐาน")
        private val yangNamesId = listOf("Rezeki", "Sakit", "Pisah", "Kebenaran", "Jabatan", "Rugi", "Bahaya", "Pokok")
        private val yangNamesKo = listOf("재(財)", "병(病)", "리(離)", "의(義)", "관(官)", "겁(劫)", "해(害)", "본(本)")
        private val yangAuspiciousFlags = listOf(true, false, false, true, true, false, false, true)

        private val yinNamesHans = listOf("财", "失", "兴", "死", "官", "义", "苦", "旺", "害", "丁")
        private val yinNamesHant = listOf("財", "失", "興", "死", "官", "義", "苦", "旺", "害", "丁")
        private val yinNamesEn = listOf("Wealth", "Loss", "Prosper", "Decline", "Official", "Righteous", "Sorrow", "Flourish", "Harm", "Descendant")
        private val yinNamesVi = listOf("Tài", "Thất", "Hưng", "Tử", "Quan", "Nghĩa", "Khổ", "Vượng", "Hại", "Đinh")
        private val yinNamesTh = listOf("ทรัพย์", "เสีย", "รุ่งเรือง", "เสื่อม", "ยศ", "คุณธรรม", "ทุกข์", "เจริญ", "ภัย", "ทายาท")
        private val yinNamesId = listOf("Rezeki", "Hilang", "Makmur", "Surut", "Jabatan", "Kebenaran", "Duka", "Jaya", "Bahaya", "Keturunan")
        private val yinNamesKo = listOf("재(財)", "실(失)", "흥(興)", "사(死)", "관(官)", "의(義)", "고(苦)", "왕(旺)", "해(害)", "정(丁)")
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
            AppLanguage.VI ->
                "Nguồn cổ tịch: khẩu quyết thước Lỗ Ban («Tài, Nghĩa, Quan, Bổn là cát; Bệnh, Ly, Kiếp, Hại là hung») kết hợp thước Đinh Lan; các nhãn chỉ mang tính biểu tượng văn hóa, không phải kết luận y tế, an toàn hay tài chính."
            AppLanguage.TH ->
                "อ้างอิงตำราหลู่ปานจิง («ทรัพย์ คุณธรรม ยศ รากฐาน เป็นมงคล; โรค พลัดพราก สูญเสีย ภัย เป็นอัปมงคล») ร่วมกับบรรทัดติงหลาน เป็นสัญลักษณ์ทางวัฒนธรรม ไม่ใช่คำวินิจฉัยทางการแพทย์ ความปลอดภัย หรือการเงิน"
            AppLanguage.ID ->
                "Sumber klasik: kaidah mistar Lu Ban & Ding Lan; label seperti ‘sakit’, ‘rugi’, dan ‘rezeki’ adalah simbol budaya tradisional, bukan kesimpulan medis, keselamatan, atau keuangan."
            AppLanguage.JA ->
                "出典：『魯班経』尺法訣「財・義・官・本を吉とし、病・離・劫・害を凶とす」および『丁蘭尺』伝統尺法（「病・失・財・旺」は文化象徴であり、医療・安全・財務上の判断ではありません）。"
            AppLanguage.KO ->
                "출전: 『노반경』 척법결(재·의·관·본은 길, 병·리·겁·해는 흉) 및 『정란척』 전통 척법(‘병·실·재·왕’은 문화적 상징이며 의료·안전·재무 판단이 아닙니다)."
            AppLanguage.ZH_HANT ->
                "出處：《魯班經》尺法訣：「財、義、官、本為吉，病、離、劫、害為凶。」兼參《丁蘭尺》傳統尺法；‘病、失、財、旺’是文化象徵標籤，不是醫療、安全或財務判斷。"
            AppLanguage.ZH_HANS, AppLanguage.AUTO ->
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
            AppLanguage.VI -> {
                val yName = yangNamesVi[yangGateIndex]
                val yLuck = if (yangIsAuspicious) "Cát" else "Hung"
                val nName = yinNamesVi[yinIndex]
                val nLuck = if (yinIsAuspicious) "Cát" else "Hung"
                String.format(Locale.US, "%.1f cm · Lỗ Ban: 【%s】(%s) · Đinh Lan: 【%s】(%s) · %s", centimeters, yName, yLuck, nName, nLuck, sourceNote)
            }
            AppLanguage.TH -> {
                val yName = yangNamesTh[yangGateIndex]
                val yLuck = if (yangIsAuspicious) "มงคล" else "อัปมงคล"
                val nName = yinNamesTh[yinIndex]
                val nLuck = if (yinIsAuspicious) "มงคล" else "อัปมงคล"
                String.format(Locale.US, "%.1f cm · หลู่ปาน: 【%s】(%s) · ติงหลาน: 【%s】(%s) · %s", centimeters, yName, yLuck, nName, nLuck, sourceNote)
            }
            AppLanguage.ID -> {
                val yName = yangNamesId[yangGateIndex]
                val yLuck = if (yangIsAuspicious) "Baik" else "Buruk"
                val nName = yinNamesId[yinIndex]
                val nLuck = if (yinIsAuspicious) "Baik" else "Buruk"
                String.format(Locale.US, "%.1f cm · LuBan: [%s] (%s) · DingLan: [%s] (%s) · %s", centimeters, yName, yLuck, nName, nLuck, sourceNote)
            }
            AppLanguage.JA -> {
                val yName = yangNamesHant[yangGateIndex]
                val yLuck = if (yangIsAuspicious) "吉" else "凶"
                val nName = yinNamesHant[yinIndex]
                val nLuck = if (yinIsAuspicious) "吉" else "凶"
                String.format(Locale.US, "%.1f cm · 魯班門光尺：【%s】(%s) · 丁蘭尺：【%s】(%s) · %s", centimeters, yName, yLuck, nName, nLuck, sourceNote)
            }
            AppLanguage.KO -> {
                val yName = yangNamesKo[yangGateIndex]
                val yLuck = if (yangIsAuspicious) "길" else "흉"
                val nName = yinNamesKo[yinIndex]
                val nLuck = if (yinIsAuspicious) "길" else "흉"
                String.format(Locale.US, "%.1f cm · 노반자: [%s](%s) · 정란척: [%s](%s) · %s", centimeters, yName, yLuck, nName, nLuck, sourceNote)
            }
            AppLanguage.ZH_HANT -> {
                val yName = yangNamesHant[yangGateIndex]
                val yLuck = if (yangIsAuspicious) "吉" else "凶"
                val nName = yinNamesHant[yinIndex]
                val nLuck = if (yinIsAuspicious) "吉" else "凶"
                String.format(Locale.US, "%.1f cm · 魯班門光尺：【%s】字門(%s) · 丁蘭尺：【%s】字(%s) · %s", centimeters, yName, yLuck, nName, nLuck, sourceNote)
            }
            AppLanguage.ZH_HANS, AppLanguage.AUTO -> {
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
    val localizedName: String get() = type.localizedName
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
            s.append("40\n0.30\n1\n${room.localizedName} ${String.format(Locale.US, "%.1f", room.areaSqMeters)}m2\n")
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
        val lang = LocalizationManager.instance.effectiveLanguage
        val spanXLabel: String
        val spanZLabel: String
        val roomWPrefix: String
        val roomDPrefix: String
        when (lang) {
            AppLanguage.ZH_HANS, AppLanguage.AUTO -> {
                spanXLabel = "全屋开间"; spanZLabel = "全屋进深"; roomWPrefix = "开间"; roomDPrefix = "进深"
            }
            AppLanguage.ZH_HANT -> {
                spanXLabel = "全屋開間"; spanZLabel = "全屋進深"; roomWPrefix = "開間"; roomDPrefix = "進深"
            }
            AppLanguage.EN -> {
                spanXLabel = "Total Width"; spanZLabel = "Total Depth"; roomWPrefix = " W"; roomDPrefix = " D"
            }
            AppLanguage.JA -> {
                spanXLabel = "住戸間口"; spanZLabel = "住戸奥行"; roomWPrefix = "間口"; roomDPrefix = "奥行"
            }
            AppLanguage.KO -> {
                spanXLabel = "전체 전면폭"; spanZLabel = "전체 깊이"; roomWPrefix = " 폭"; roomDPrefix = " 깊이"
            }
            AppLanguage.VI -> {
                spanXLabel = "Rộng toàn nhà"; spanZLabel = "Sâu toàn nhà"; roomWPrefix = " Rộng"; roomDPrefix = " Sâu"
            }
            AppLanguage.TH -> {
                spanXLabel = "ความกว้างรวม"; spanZLabel = "ความลึกรวม"; roomWPrefix = " กว้าง"; roomDPrefix = " ลึก"
            }
            AppLanguage.ID -> {
                spanXLabel = "Lebar Total"; spanZLabel = "Kedalaman Total"; roomWPrefix = " L"; roomDPrefix = " P"
            }
        }
        appendAlignedDim(dMinX, -dMinZ, dMaxX, -dMinZ, "$spanXLabel ${String.format(Locale.US, "%.2f", dSpanX)}m")
        appendAlignedDim(dMinX, -dMaxZ, dMaxX, -dMaxZ, "$spanXLabel ${String.format(Locale.US, "%.2f", dSpanX)}m")
        appendAlignedDim(dMinX, -dMinZ, dMinX, -dMaxZ, "$spanZLabel ${String.format(Locale.US, "%.2f", dSpanZ)}m")
        appendAlignedDim(dMaxX, -dMinZ, dMaxX, -dMaxZ, "$spanZLabel ${String.format(Locale.US, "%.2f", dSpanZ)}m")

        val sortedRooms = rooms.sortedByDescending { it.areaSqMeters }.take(3)
        for (r in sortedRooms) {
            val rMinX = r.centerX - r.sizeX * 0.5f
            val rMaxX = r.centerX + r.sizeX * 0.5f
            val rMinZ = r.centerZ - r.sizeZ * 0.5f
            val rMaxZ = r.centerZ + r.sizeZ * 0.5f
            val rLabel = r.localizedName
            appendAlignedDim(rMinX, -rMinZ, rMaxX, -rMinZ, "$rLabel$roomWPrefix ${String.format(Locale.US, "%.2f", r.sizeX)}m")
            appendAlignedDim(rMinX, -rMaxZ, rMaxX, -rMaxZ, "$rLabel$roomWPrefix ${String.format(Locale.US, "%.2f", r.sizeX)}m")
            appendAlignedDim(rMinX, -rMinZ, rMinX, -rMaxZ, "$rLabel$roomDPrefix ${String.format(Locale.US, "%.2f", r.sizeZ)}m")
            appendAlignedDim(rMaxX, -rMinZ, rMaxX, -rMaxZ, "$rLabel$roomDPrefix ${String.format(Locale.US, "%.2f", r.sizeZ)}m")
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
                val rName = room.localizedName
                if (room.type == FloorplanRoomType.BATHROOM) {
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "中宫受污 (水浸太极)", "中宮受污 (水浸太極)", "Central Palace Water Sha",
                            "中宮水浸殺（太極受汚）", "중궁수침살 (태극 오염)", "Thủy Tẩm Trung Cung (Uế Khí Thái Cực)",
                            "เคราะห์น้ำท่วมจุดศูนย์กลาง (ไท่จี๋อับชื้น)", "Sha Air di Pusat Rumah (Tai Ji Lembap)"
                        ),
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = tr8(
                            "房屋中宫·$rName", "房屋中宮·$rName", "Center Palace · $rName",
                            "中宮・$rName", "주택 중궁 · $rName", "Trung cung · $rName",
                            "จุดศูนย์กลางบ้าน · $rName", "Pusat Rumah · $rName"
                        ),
                        detail = tr8(
                            "《撼龙经》原文有“水浸心包，家门困耗”之说。卫生间位于房屋中心属于该典籍语境下的布局象征，请结合防水、排水、通风、干燥和动线现场复核；古籍语句不等同于现实诊断。",
                            "《撼龍經》原文有「水浸心包，家門困耗」之說。衛生間位於房屋中心屬於該典籍語境下的佈局象徵，請結合防水、排水、通風、乾燥和動線現場複核；古籍語句不等同於現實診斷。",
                            "The Dragon Classic notes that a bathroom at the heart of the home dampens central qi. Please verify waterproofing, drainage, ventilation, and dryness on site; classical symbolism is not a medical diagnosis.",
                            "『撼龍経』では家の中心にある水回りを中宮受汚と記します。防水・排水・換気・乾燥状態を現地で確認してください（古典の象徴表現であり医療診断ではありません）。",
                            "《감룡경》에서는 집 중심의 욕실을 중궁 오염으로 봅니다. 방수·배수·통풍·건조 상태를 현장에서 점검하세요(고전의 상징적 서술이며 의학적 진단이 아닙니다).",
                            "《Hám Long Kinh》 xem phòng vệ sinh ở trung tâm nhà là tượng thủy tẩm trung cung. Vui lòng kiểm tra chống thấm, thoát nước và thông gió thực tế; cổ thư chỉ mang tính biểu trưng.",
                            "คัมภีร์《หานหลงจิง》กล่าวว่าห้องน้ำกลางบ้านทำให้ชี่ส่วนกลางอับชื้น โปรดตรวจสอบระบบกันซึม การระบายน้ำ และการระบายอากาศหน้างาน (เป็นสัญลักษณ์ตามตำรา ไม่ใช่การวินิจฉัยทางการแพทย์)",
                            "Kitab Klasik menyebut kamar mandi di titik pusat rumah melemahkan qi tengah. Harap periksa kedap air, drainase, dan ventilasi di lokasi; simbolisme klasik bukan diagnosis medis."
                        ),
                        fengshuiLore = tr8(
                            "出处：《撼龙经》。解释：古籍以中心落水象征家门困耗，属于传统堪舆叙事，实际房屋问题仍以现场检查为准。",
                            "出處：《撼龍經》。解釋：古籍以中心落水象徵家門困耗，屬於傳統堪輿敘事，實際房屋問題仍以現場檢查為準。",
                            "Source: The Dragon Classic. Traditional geomancy views water at the center as draining household vitality; inspect actual plumbing and ventilation on site.",
                            "出典：『撼龍経』。中心部の水回りは伝統風水における象徴であり、実際の設備状況は現地確認を基準としてください。",
                            "출처: 《감룡경》. 중심부 수기 배치는 전통 풍수의 상징적 해석이며 실제 설비 상태는 현장 점검을 기준으로 합니다.",
                            "Nguồn: 《Hám Long Kinh》. Cổ thư dùng hình tượng nước ở trung tâm để nhắc nhở giữ khô ráo và thông thoáng cho trục giữa nhà.",
                            "ที่มา: 《หานหลงจิง》 ตำราโบราณเปรียบน้ำกลางบ้านเป็นจุดอ่อนของพลังชี่ ควรตรวจสอบระบบท่อและระบายอากาศจริง",
                            "Sumber: Kitab Han Long Jing. Tradisi feng shui memandang area basah di pusat sebagai simbol pelemahan qi; utamakan pemeriksaan teknis di lokasi."
                        ),
                        solution = tr8(
                            "优先检查防水、排水、排风和检修条件，保持地面干燥、通道清晰；改造前咨询具备资质的专业人员。",
                            "優先檢查防水、排水、排風和檢修條件，保持地面乾燥、通道清晰；改造前諮詢具備資質的專業人員。",
                            "Prioritize waterproofing, exhaust ventilation, and dry floors; keep the door closed and consult qualified professionals before any remodeling.",
                            "防水・排水・換気設備を優先点検し、床面を乾燥させドアを常閉に保ってください。改修時は専門家にご相談ください。",
                            "방수·배수·환기 설비를 우선 점검하여 바닥을 건조하게 유지하고 문을 닫아두세요. 개조 시 전문가와 상담하세요.",
                            "Ưu tiên kiểm tra chống thấm, quạt hút ẩm, giữ sàn khô ráo và đóng cửa phòng vệ sinh; tham khảo chuyên gia trước khi cải tạo.",
                            "ตรวจสอบระบบกันซึมและพัดลมดูดอากาศ รักษาพื้นให้แห้งและปิดประตูห้องน้ำเสมอ ปรึกษาช่างผู้เชี่ยวชาญก่อนดัดแปลง",
                            "Utamakan pemeriksaan kedap air dan exhaust fan, jaga lantai tetap kering serta tutup pintu kamar mandi; konsultasikan dengan ahli sebelum renovasi."
                        ),
                        coordinate = room.center
                    ))
                    score -= 16
                } else if (room.type == FloorplanRoomType.KITCHEN) {
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "火烧中宫 (燥火焚心)", "火燒中宮 (燥火焚心)", "Central Palace Fire Sha",
                            "火焼中宮殺（燥火焚心）", "화소중궁살 (중궁 화기)", "Hỏa Thiêu Trung Cung (Táo Hỏa Trung Tâm)",
                            "เคราะห์ไฟเผาจุดศูนย์กลาง", "Sha Api di Pusat Rumah"
                        ),
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = tr8(
                            "房屋中宫·$rName", "房屋中宮·$rName", "Center Palace · $rName",
                            "中宮・$rName", "주택 중궁 · $rName", "Trung cung · $rName",
                            "จุดศูนย์กลางบ้าน · $rName", "Pusat Rumah · $rName"
                        ),
                        detail = tr8(
                            "全屋中心被厨房或灶台占据，属于传统文化中的布局提示，请结合实际通风、动线与安全条件复核。",
                            "全屋中心被廚房或灶台佔據，屬於傳統文化中的佈局提示，請結合實際通風、動線與安全條件複核。",
                            "A kitchen or stove occupying the central Tai Ji is flagged in traditional layout lore; verify exhaust ventilation, circulation, and fire safety on site.",
                            "家の中心にキッチンやコンロがある配置です。伝統風水の参考提示として、換気・動線・防火安全を現地で確認してください。",
                            "집 중심부에 주방이나 화구가 위치한 배치입니다. 환기·동선·화재 안전 조건을 현장에서 점검하세요.",
                            "Bếp nấu đặt tại trung tâm ngôi nhà dễ làm nóng khí trường trung cung; vui lòng kiểm tra hệ thống hút mùi, thông gió và an toàn phòng cháy.",
                            "ห้องครัวหรือเตาไฟอยู่ตรงจุดศูนย์กลางบ้าน ควรตรวจสอบการระบายควัน ทางเดิน และความปลอดภัยด้านอัคคีภัยหน้างาน",
                            "Dapur atau kompor yang berada di pusat rumah memerlukan perhatian khusus pada penghisap asap, ventilasi, dan keselamatan kebakaran."
                        ),
                        fengshuiLore = tr8(
                            "出处：《八宅明镜》原文：“火居天心，病染胸膈”。解释：古籍将中心火象与疾病作象征关联，属于传统文化原文，不是医疗判断。",
                            "出處：《八宅明鏡》原文：「火居天心，病染胸膈」。解釋：古籍將中心火象與疾病作象徵關聯，屬於傳統文化原文，不是醫療判斷。",
                            "Source: Ba Zhai Ming Jing ('Fire at the Heaven Heart'). Classical symbolism links central heat to restlessness; not a medical judgment.",
                            "出典：『八宅明鏡』「火が天心に居れば胸膈を損なう」。古典の象徴的表現であり、医学的判断ではありません。",
                            "출처: 《팔택명경》 ‘화가 천심에 있으면 흉격을 상한다’. 고전의 상징적 서술이며 의학적 판단이 아닙니다.",
                            "Nguồn: 《Bát Trạch Minh Kính》 (“Hỏa cư thiên tâm”). Đây là biểu tượng phong thủy cổ điển, không phải chẩn đoán y khoa.",
                            "ที่มา: 《ปาจ้ายหมิงจิ่ง》 กล่าวถึงไฟกลางใจบ้านในเชิงสัญลักษณ์ทางวัฒนธรรม ไม่ใช่คำวินิจฉัยทางการแพทย์",
                            "Sumber: Ba Zhai Ming Jing. Teks klasik mengaitkan panas di pusat rumah secara simbolis, bukan diagnosis medis."
                        ),
                        solution = tr8(
                            "厨灶移位避开房屋正中心，厨房采用米白或浅黄色地砖引土泄火，灶台下置黄玉石辟火化煞。",
                            "廚灶移位避開房屋正中心，廚房採用米白或淺黃色地磚引土洩火，灶台下置黃玉石辟火化煞。",
                            "Relocate the stove away from the exact center if possible; use beige or warm earth-toned tiles and yellow ceramic/jade accents to drain excess Fire into Earth.",
                            "可能であればコンロを中心からずらし、ベージュや淡黄色のタイル・陶器を用いて土気で火気を和らげてください。",
                            "가능하면 화구를 정중앙에서 비켜 배치하고, 미색·연황색 타일이나 황옥 소품으로 화기를 토(土)로 설기하세요.",
                            "Nên dịch bếp tránh chính giữa nhà, dùng gạch lát màu kem hoặc vàng nhạt và đặt đá hoàng ngọc/gốm vàng để Thổ tiết Hỏa.",
                            "ควรขยับเตาออกจากจุดกึ่งกลางบ้าน ใช้กระเบื้องโทนสีครีมหรือเหลืองอ่อน และวางหยกเหลืองหรือเซรามิกเพื่อใช้ธาตุดินลดความร้อน",
                            "Geser posisi kompor dari titik pusat bila memungkinkan; gunakan ubin krem/kuning muda atau keramik kuning agar unsur Tanah meredam Api."
                        ),
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
                    val winName = win.type.localizedName
                    val distStr = String.format(Locale.US, "%.1f", dist)
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "穿堂穿心煞 (一箭穿心)", "穿堂穿心煞 (一箭穿心)", "Through-Hallway Draft Sha",
                            "穿堂殺（一箭穿心）", "천당살 (문·창 직통)", "Xuyên Đường Sát (Một Mũi Xuyên Tâm)",
                            "เคราะห์ลมทะลุผ่าน (ประตูตรงหน้าต่าง)", "Sha Angin Tembus (Pintu–Jendela Segaris)"
                        ),
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = tr8(
                            "大门 ⟷ $winName (间距 ${distStr}m)", "大門 ⟷ $winName (間距 ${distStr}m)", "Main Door ⟷ $winName (${distStr}m)",
                            "玄関 ⟷ $winName（距離 ${distStr}m）", "현관문 ⟷ $winName (간격 ${distStr}m)", "Cửa chính ⟷ $winName (cách ${distStr}m)",
                            "ประตูใหญ่ ⟷ $winName (ห่าง $distStr ม.)", "Pintu Utama ⟷ $winName (jarak ${distStr}m)"
                        ),
                        detail = tr8(
                            "《葬经》原文有“气乘风则散，界水则止”。入户门与${winName}直线通透（间距 $distStr 米），古籍将其解释为穿堂气散；请结合通风、噪音、视线和通行安全现场复核。",
                            "《葬經》原文有「氣乘風則散，界水則止」。入戶門與${winName}直線通透（間距 $distStr 米），古籍將其解釋為穿堂氣散；請結合通風、噪音、視線和通行安全現場複核。",
                            "The Burial Classic states: 'Qi scatters when riding the wind.' The main entrance aligns directly with $winName ($distStr m apart), creating a straight-through draft; verify airflow, privacy, and noise on site.",
                            "『葬経』に「気は風に乗れば散ず」とあります。玄関と${winName}がほぼ一直線（距離 ${distStr}m）で貫通気流が生じるため、風通し・視線・騒音を現地で確認してください。",
                            "《장경》에 ‘기는 바람을 타면 흩어진다’고 했습니다. 현관문과 $winName 축이 거의 일직선(거리 ${distStr}m)을 이루어 맞바람이 통하니 통풍·시선·소음을 점검하세요.",
                            "《Táng Kinh》 ghi: “Khí thừa phong tắc tán”. Cửa chính và $winName gần như thẳng hàng (cách $distStr m), tạo luồng gió xuyên phòng; hãy kiểm tra thông gió và tầm nhìn thực tế.",
                            "คัมภีร์《จิ้งจิง》กล่าวว่า “ชี่ต้องลมย่อมกระจาย” ประตูทางเข้าตรงกับ$winName (ห่าง $distStr ม.) เกิดลมทะลุผ่านโดยตรง ควรตรวจสอบกระแสลมและแนวสายตาหน้างาน",
                            "Kitab Zang Jing menyebut: 'Qi buyar saat terbawa angin.' Pintu utama segaris dengan $winName (jarak $distStr m), memicu angin tembus langsung; periksa aliran udara dan privasi di lokasi."
                        ),
                        fengshuiLore = tr8(
                            "《葬经》云：'气乘风则散，界水则止'。前通后达直穿门户，宅内藏风聚气之基尽失，所谓'前门进宝后门流'。",
                            "《葬經》云：「氣乘風則散，界水則止」。前通後達直穿門戶，宅內藏風聚氣之基盡失，所謂「前門進寶後門流」。",
                            "The Burial Classic: 'Qi scatters with wind and gathers at water.' A direct front-to-back draft prevents the home from retaining calm, gathered energy.",
                            "『葬経』「気は風に乗れば散じ、水に界すれば止まる」。表から奥へ吹き抜ける構造は蔵風聚気を損なうとされます。",
                            "《장경》 ‘기승풍즉산 계수즉지’. 앞문이 뒷창과 직통하면 집안의 장풍취기(藏風聚氣)가 흩어진다고 봅니다.",
                            "《Táng Kinh》: “Khí thừa phong tắc tán, giới thủy tắc chỉ”. Cửa trước thông thẳng cửa sau khiến nhà khó tụ khí.",
                            "《จิ้งจิง》กล่าวว่า “ชี่ต้องลมย่อมสลาย หยุดเมื่อพบน้ำ” ประตูหน้าทะลุหลังทำให้บ้านเก็บกักพลังงานมงคลไม่อยู่",
                            "Zang Jing: 'Qi buyar tertiup angin dan berhenti di air.' Aliran lurus dari pintu depan ke belakang menyulitkan rumah menghimpun energi tenang."
                        ),
                        solution = tr8(
                            "在大门玄关处设实木屏风、半透磨砂玄关柜阻挡视线，或在阳台处悬挂厚质遮光帘与铜葫芦聚气。",
                            "在大門玄關處設實木屏風、半透磨砂玄關櫃阻擋視線，或在陽台處懸掛厚質遮光簾與銅葫蘆聚氣。",
                            "Place a wooden screen or frosted-glass entry cabinet at the foyer to buffer the sightline, or hang heavy curtains and a brass gourd near the window/balcony.",
                            "玄関に木製屏風やスリガラス付きの収納棚を設けて視線と気流を和らげるか、窓側に厚手のカーテンを掛けて聚気してください。",
                            "현관에 원목 파티션이나 반투명 수납장을 두어 시선과 기류를 완충하거나, 발코니·창가에 두꺼운 커튼을 설치해 기운을 모으세요.",
                            "Đặt bình phong gỗ hoặc tủ huyền quan kính mờ ở lối vào để chắn tầm nhìn, hoặc treo rèm dày và hồ lô đồng ở phía ban công/cửa sổ.",
                            "ติดตั้งฉากกั้นไม้หรือตู้ทางเข้ากระจกฝ้าเพื่อบังสายตา หรือติดม่านทึบและแขวนน้ำเต้าทองเหลืองบริเวณระเบียงเพื่อเก็บกักชี่",
                            "Pasang sekat kayu atau kabinet foyer kaca buram di pintu masuk untuk menahan garis pandang, atau gunakan tirai tebal di sisi balkon/jendela."
                        ),
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
                    val distStr = String.format(Locale.US, "%.1f", dist)
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "门冲对门煞 (两口相对)", "門衝對門煞 (兩口相對)", "Opposing Doors Clash",
                            "対門殺（ドアの対峙）", "대문충살 (문끼리 마주봄)", "Đối Môn Sát (Hai Cửa Đối Nhau)",
                            "เคราะห์ประตูชนกัน (สองประตูปะทะ)", "Sha Pintu Berhadapan"
                        ),
                        severity = SpatialShaSeverity.WARNING,
                        locationName = tr8(
                            "双门对冲·间距 ${distStr}m",
                            "雙門對衝·間距 ${distStr}m",
                            "Facing Doors · ${distStr}m apart",
                            "対向ドア・距離 ${distStr}m",
                            "마주 보는 문 · 간격 ${distStr}m",
                            "Hai cửa đối diện · cách ${distStr}m",
                            "ประตูตรงกัน · ห่าง $distStr ม.",
                            "Pintu Berhadapan · jarak ${distStr}m"
                        ),
                        detail = tr8(
                            "两间居室房门直对，间距过窄产生对流风切，主家人意见相左、易生口角龃龉。",
                            "兩間居室房門直對，間距過窄產生對流風切，主家人意見相左、易生口角齟齬。",
                            "Two room doors face each other across a narrow corridor, creating cross-drafts and privacy overlap; traditionally linked to household friction.",
                            "二つの室内ドアが狭い間隔で正対し、気流の衝突と視線の交差が生じています。家庭内の摩擦を招きやすい配置とされます。",
                            "두 방의 문이 좁은 간격으로 마주 보고 있어 대류 바람과 시선 충돌이 생기며, 가족 간 의견 마찰을 부르기 쉽다고 봅니다.",
                            "Hai cửa phòng đối diện nhau ở khoảng cách hẹp tạo gió đối lưu và giao cắt tầm nhìn, dễ gây bất đồng trong gia đình.",
                            "ประตูสองห้องหันชนกันในระยะแคบทำให้เกิดลมปะทะและขาดความเป็นส่วนตัว ตามตำราว่าอาจทำให้คนในบ้านขัดแย้งกันง่าย",
                            "Dua pintu kamar saling berhadapan dalam jarak sempit sehingga memicu angin silang dan gesekan privasi antarpenghuni."
                        ),
                        fengshuiLore = tr8(
                            "《阳宅十书》云：'两门相对谓相骂，主家不和争相夸'。门户为纳气之口，两口相争则家宅不宁。",
                            "《陽宅十書》云：「兩門相對謂相罵，主家不和爭相誇」。門戶為納氣之口，兩口相爭則家宅不寧。",
                            "Yang Zhai Ten Books: 'Two doors facing each other are called quarreling mouths.' Doors are qi mouths; direct opposition stirs restlessness.",
                            "『陽宅十書』「両門相対するを相罵と謂う」。扉は気の出入り口であり、正対すると気が乱れるとされます。",
                            "《양택십서》 ‘양문상대위상마(兩門相對謂相罵)’. 문은 기를 받아들이는 입이라 서로 마주 보면 가택이 소란해지기 쉽습니다.",
                            "《Dương Trạch Thập Thư》: “Lưỡng môn tương đối vị tương mạ”. Hai cửa đối diện trực tiếp làm xáo trộn khí trường chung.",
                            "《หยางไจ๋สือซู》กล่าวว่า “สองประตูหันชนกันเปรียบเหมือนปากโต้เถียง” ทำให้กระแสชี่ในบ้านไม่สงบ",
                            "Yang Zhai Ten Books menyebut dua pintu yang saling berhadapan sebagai 'dua mulut berdebat' yang mengganggu ketenangan rumah."
                        ),
                        solution = tr8(
                            "门上悬挂过膝布帘，门框两侧可加装五帝钱或中国结以和解气场，平时常保持其中一门常闭。",
                            "門上懸掛過膝布簾，門框兩側可加裝五帝錢或中國結以和解氣場，平時常保持其中一門常閉。",
                            "Hang a knee-length fabric door curtain, add Five-Emperor coins or a decorative knot on the frame, and keep at least one door closed when not in use.",
                            "ドアに丈の長い暖簾を掛け、五帝銭や飾り結びを添えて気を和らげ、普段は片方のドアを閉めておきましょう。",
                            "문에 긴 패브릭 커튼을 달고 문틀에 오제전이나 전통 매듭을 걸어 기운을 중화하며, 평소 한쪽 문을 닫아두세요.",
                            "Treo rèm vải dài qua gối trên cửa, gắn thêm tiền Ngũ Đế hoặc nút thắt cát tường và giữ một cửa đóng khi không sử dụng.",
                            "ติดม่านผ้าความยาวคลุมเข่าที่ประตู แขวนเหรียญห้าจักรพรรดิหรือพู่ถักมงคล และปิดประตูบานใดบานหนึ่งไว้เสมอเมื่อไม่ใช้งาน",
                            "Pasang tirai pintu sepanjang lutut, tambahkan Koin Lima Kaisar atau simpul hias, dan biasakan menutup salah satu pintu."
                        ),
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
                    val isBed = target.category == "bed"
                    val targetName = if (isBed)
                        tr8("睡床", "睡床", "Bed", "ベッド", "침대", "Giường ngủ", "เตียงนอน", "Ranjang")
                    else
                        tr8("主位沙发", "主位沙發", "Main Sofa", "メインソファ", "메인 소파", "Sofa chính", "โซฟาหลัก", "Sofa Utama")
                    val clrStr = String.format(Locale.US, "%.2f", beam.clearanceHeight)
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "横梁压顶煞 (气压沉重)", "橫梁壓頂煞 (氣壓沉重)", "Overhead Beam Pressure Sha",
                            "横梁圧頂殺（頭上の梁）", "횡량압정살 (대들보 압박)", "Xà Ngang Đè Đầu (Áp Lực Trần)",
                            "เคราะห์คานทับศีรษะ", "Sha Balok Gantung di Atas Kepala"
                        ),
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = tr8(
                            "${targetName}正上方 (净高${clrStr}m)",
                            "${targetName}正上方 (淨高${clrStr}m)",
                            "Above $targetName (clearance ${clrStr}m)",
                            "${targetName}の真上（有効高${clrStr}m）",
                            "$targetName 바로 위 (유효높이 ${clrStr}m)",
                            "Phía trên $targetName (cao ${clrStr}m)",
                            "เหนือ$targetName (สูง $clrStr ม.)",
                            "Di atas $targetName (tinggi ${clrStr}m)"
                        ),
                        detail = tr8(
                            "沉重承重横梁横跨在${targetName}上方，下垂气流形成沉降重压，久居易头痛压抑、精神衰弱。",
                            "沉重承重橫梁橫跨在${targetName}上方，下垂氣流形成沉降重壓，久居易頭痛壓抑、精神衰弱。",
                            "A low structural beam runs directly above the $targetName, creating visual pressure and downward draft that can disturb rest and focus.",
                            "構造梁が${targetName}の真上を横切り、下向きの気流と視覚的な圧迫感を生んでいます。休息の質に影響しやすい配置です。",
                            "구조 보가 $targetName 바로 위를 가로질러 하강 기류와 시각적 압박감을 형성하므로 수면과 휴식에 방해가 될 수 있습니다.",
                            "Xà ngang chịu lực nằm ngay phía trên $targetName, tạo cảm giác đè nén thị giác và ảnh hưởng đến giấc ngủ, sự thư giãn.",
                            "คานรับน้ำหนักพาดผ่านเหนือ${targetName}โดยตรง ทำให้เกิดแรงกดทับทางสายตาและรบกวนการพักผ่อน",
                            "Balok struktural melintas tepat di atas $targetName, menimbulkan tekanan visual yang dapat mengganggu kenyamanan istirahat."
                        ),
                        fengshuiLore = tr8(
                            "《鲁班经》云：'横梁压顶若悬斧，身染沉疴气数枯'。横梁下空气受阻下压，人处于其下受气场冲煞。",
                            "《魯班經》云：「橫梁壓頂若懸斧，身染沉疴氣數枯」。橫梁下空氣受阻下壓，人處於其下受氣場衝煞。",
                            "Lu Ban Classic compares an exposed overhead beam to a suspended blade; airflow rebounds downward over the occupant below.",
                            "『魯班経』では頭上の露出梁を忌み、気流が梁に当たって下方に圧力をかけると説かれています。",
                            "《노반경》에서는 머리 위 노출된 보가 기류를 아래로 누르므로 오래 머무는 자리 위를 피하라고 전합니다.",
                            "《Lỗ Ban Kinh》 ví xà ngang lộ thiên đè trên đầu như vật nặng treo lơ lửng, làm dòng khí dội xuống người ngồi hoặc nằm bên dưới.",
                            "คัมภีร์《หลู่ปานจิง》กล่าวว่าคานที่เปลือยอยู่เหนือศีรษะจะกดทับกระแสอากาศและสร้างความอึดอัดแก่ผู้อยู่อาศัย",
                            "Kitab Lu Ban mengibaratkan balok terbuka di atas kepala sebagai beban menggantung yang menekan aliran udara ke bawah."
                        ),
                        solution = tr8(
                            "将床铺或沙发平移挪出横梁投影区；若无法挪位，建议做平吊顶包梁隐藏，或梁两端悬挂开光铜葫芦泄压。",
                            "將床鋪或沙發平移挪出橫梁投影區；若無法挪位，建議做平吊頂包梁隱藏，或梁兩端懸掛開光銅葫蘆洩壓。",
                            "Shift the bed or sofa out from under the beam footprint; if fixed, enclose the beam with a flush false ceiling or hang brass gourds at both ends.",
                            "ベッドやソファを梁の直下から移動するか、天井造作で梁を隠す、または梁の両端に銅瓢箪を掛けて圧迫感を和らげてください。",
                            "침대나 소파를 보 아래에서 벗어나게 이동하거나, 평평한 마감 천장으로 보를 감추고 양 끝에 동호리병을 걸어 압박을 완화하세요.",
                            "Dịch chuyển giường hoặc sofa ra khỏi bóng xà ngang; nếu cố định, nên làm trần phẳng che xà hoặc treo hồ lô đồng ở hai đầu xà.",
                            "เลื่อนเตียงหรือโซฟาออกจากแนวคาน หากย้ายไม่ได้แนะนำให้ทำฝ้าเพดานเรียบปิดคาน หรือแขวนน้ำเต้าทองเหลืองที่ปลายคานทั้งสองด้าน",
                            "Geser ranjang atau sofa keluar dari bawah garis balok; jika tidak memungkinkan, tutup dengan plafon rata atau gantung labu tembaga di kedua ujungnya."
                        ),
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
                    val distStr = String.format(Locale.US, "%.1f", dist)
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "房门冲床 (冲撞身魂)", "房門衝床 (衝撞身魂)", "Door-to-Bed Direct Draft",
                            "門衝床殺（ドアとベッドの直対）", "문충침살 (방문·침대 직충)", "Môn Xung Sàng (Cửa Chiếu Thẳng Giường)",
                            "เคราะห์ประตูพุ่งชนเตียง", "Sha Pintu Menusuk Ranjang"
                        ),
                        severity = SpatialShaSeverity.WARNING,
                        locationName = tr8(
                            "房门 ⟷ 卧床", "房門 ⟷ 臥床", "Room Door ⟷ Bed",
                            "室内ドア ⟷ ベッド", "방문 ⟷ 침대", "Cửa phòng ⟷ Giường ngủ",
                            "ประตูห้อง ⟷ เตียงนอน", "Pintu Kamar ⟷ Ranjang"
                        ),
                        detail = tr8(
                            "房门与床铺形成直线气流（间距 $distStr 米），建议结合实际通风、噪音与动线调整布局。",
                            "房門與床鋪形成直線氣流（間距 $distStr 米），建議結合實際通風、噪音與動線調整佈局。",
                            "The room door opens directly toward the bed ($distStr m apart), exposing the sleeper to drafts, noise, and sudden entry.",
                            "室内ドアとベッドが直線上の気流（距離 ${distStr}m）を形成しています。通風・騒音・プライバシーに合わせて配置を調整してください。",
                            "방문과 침대가 일직선 기류(거리 ${distStr}m)를 이루고 있습니다. 통풍·소음·프라이버시를 고려해 배치를 조정하세요.",
                            "Cửa phòng mở thẳng vào giường ngủ (cách $distStr m), tạo luồng gió trực diện và giảm sự riêng tư khi nghỉ ngơi.",
                            "ประตูห้องเปิดตรงเข้าหาเตียงนอน (ห่าง $distStr ม.) ทำให้รับลมและเสียงรบกวนโดยตรง ควรปรับตำแหน่งเพื่อการพักผ่อนที่ดี",
                            "Pintu kamar membuka lurus ke arah ranjang (jarak $distStr m), menimbulkan aliran angin langsung dan mengurangi privasi tidur."
                        ),
                        fengshuiLore = tr8(
                            "门开气入直射人身，动静失衡，神魂不聚。",
                            "門開氣入直射人身，動靜失衡，神魂不聚。",
                            "When the door opens directly onto the bed, active airflow disturbs the quiet yin environment needed for deep rest.",
                            "扉から入る動気が寝床を直撃すると、動静のバランスが崩れ安眠を妨げるとされます。",
                            "문이 열릴 때 들어오는 동기가 침상을 직격하면 동정의 균형이 깨져 깊은 수면을 방해한다고 봅니다.",
                            "Cửa mở dẫn luồng khí động chiếu thẳng vào giường làm mất cân bằng động tĩnh, khó ngủ sâu.",
                            "เมื่อเปิดประตูแล้วกระแสลมพุ่งเข้าหาตัวโดยตรง จะรบกวนความสงบนิ่งที่จำเป็นต่อการนอนหลับ",
                            "Aliran udara aktif dari pintu yang langsung mengarah ke tempat tidur mengganggu ketenangan yang dibutuhkan untuk istirahat."
                        ),
                        solution = tr8(
                            "微调床头朝向或位置避开门冲直线，若空间受限可在门边设遮挡隔断或门挂长帘缓冲。",
                            "微調床頭朝向或位置避開門衝直線，若空間受限可在門邊設遮擋隔斷或門掛長簾緩衝。",
                            "Shift the bed out of the doorway's direct line, or add a bedside screen / long door curtain if space is tight.",
                            "ベッドの位置をドアの正面からずらすか、スペースが限られる場合は衝立やロング暖簾で緩衝してください。",
                            "침대 위치를 문 정면에서 비켜 배치하거나, 공간이 좁다면 가림막 파티션이나 긴 문커튼으로 완충하세요.",
                            "Dịch giường lệch khỏi trục cửa phòng, hoặc đặt vách ngăn nhẹ / treo rèm dài ở cửa để giảm xung trực diện.",
                            "ขยับเตียงให้พ้นแนวตรงของประตู หรือตั้งฉากบังตา/ติดม่านยาวที่ประตูเพื่อช่วยกรองกระแสลม",
                            "Geser posisi ranjang agar tidak segaris dengan pintu, atau tambahkan sekat/tirai pintu panjang sebagai penyangga."
                        ),
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
                    val distStr = String.format(Locale.US, "%.1f", dist)
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "水火未济 (厨厕相逼)", "水火未濟 (廚廁相逼)", "Water–Fire Proximity Clash",
                            "水火未済殺（厨厠近接）", "수화미제살 (주방·욕실 근접)", "Thủy Hỏa Vị Tế (Bếp & Vệ Sinh Quá Gần)",
                            "เคราะห์น้ำไฟปะทะ (เตาไฟใกล้สุขภัณฑ์)", "Benturan Air–Api (Kompor Dekat Sanitasi)"
                        ),
                        severity = SpatialShaSeverity.WARNING,
                        locationName = tr8(
                            "灶台 ⟷ 卫浴 (间距 ${distStr}m)",
                            "灶台 ⟷ 衛浴 (間距 ${distStr}m)",
                            "Stove ⟷ BathFixture (${distStr}m)",
                            "コンロ ⟷ 水回り（距離 ${distStr}m）",
                            "화구 ⟷ 욕실 설비 (간격 ${distStr}m)",
                            "Bếp nấu ⟷ Thiết bị vệ sinh (cách ${distStr}m)",
                            "เตาไฟ ⟷ สุขภัณฑ์ (ห่าง $distStr ม.)",
                            "Kompor ⟷ Sanitasi (jarak ${distStr}m)"
                        ),
                        detail = tr8(
                            "《催官篇》原文有“水火不相容，宅母病腹痛”。灶台与卫浴距离较近，按古籍象征会被解释为水火相逼；请结合热源距离、通风、防水和使用安全复核。",
                            "《催官篇》原文有「水火不相容，宅母病腹痛」。灶台與衛浴距離較近，按古籍象徵會被解釋為水火相逼；請結合熱源距離、通風、防水和使用安全複核。",
                            "The stove and bathroom fixture are in close proximity; classical texts symbolize this as Water–Fire opposition. Verify hygiene separation, ventilation, and waterproofing on site.",
                            "コンロと浴室設備が近接しており、古典では水火相逼と象徴されます。換気・防水・衛生動線を現地で確認してください。",
                            "화구와 욕실 설비가 가까워 고전에서는 수화상충으로 풀이합니다. 열원 거리·환기·방수·위생 동선을 현장에서 점검하세요.",
                            "Bếp nấu và thiết bị vệ sinh đặt quá gần nhau tạo thế Thủy Hỏa tương xung theo cổ thư; hãy kiểm tra vách ngăn, thông gió và vệ sinh thực tế.",
                            "เตาไฟและสุขภัณฑ์อยู่ใกล้กันเกินไป ตามตำราถือเป็นน้ำปะทะไฟ ควรตรวจสอบการกั้นพื้นที่ การระบายอากาศ และสุขอนามัยหน้างาน",
                            "Kompor dan fasilitas kamar mandi berada sangat dekat; pastikan pemisahan higienis, ventilasi, dan kedap air di lokasi."
                        ),
                        fengshuiLore = tr8(
                            "出处：《催官篇》。解释：原文把水火同宫与腹痛相联系，是传统象征性叙述，不是医疗诊断。",
                            "出處：《催官篇》。解釋：原文把水火同宮與腹痛相聯繫，是傳統象徵性敘述，不是醫療診斷。",
                            "Source: Cui Guan Pian. Traditional symbolism links Water–Fire proximity to digestive discomfort; not a medical diagnosis.",
                            "出典：『催官篇』。水火の近接を消化器の不調に結び付ける伝統的象徴であり、医学的診断ではありません。",
                            "출처: 《최관편》. 수화 근접을 소화기 불편과 연결한 전통 상징 서술이며 의학적 진단이 아닙니다.",
                            "Nguồn: 《Thôi Quan Thiên》. Cổ thư liên hệ Thủy Hỏa xung khắc với tiêu hóa theo nghĩa biểu trưng, không phải chẩn đoán y khoa.",
                            "ที่มา: 《ชุยกวานเพียน》 เป็นคำเปรียบเปรยเชิงสัญลักษณ์ตามตำราโบราณ ไม่ใช่การวินิจฉัยทางการแพทย์",
                            "Sumber: Cui Guan Pian. Teks klasik mengaitkan benturan Air–Api secara simbolis, bukan diagnosis medis."
                        ),
                        solution = tr8(
                            "炉灶与卫生间门错开避对，两者之间摆放常青绿植（木元素）以形成'水生木、木生火'通关调和。",
                            "爐灶與衛生間門錯開避對，兩者之間擺放常青綠植（木元素）以形成「水生木、木生火」通關調和。",
                            "Offset the stove and bathroom door so they do not face each other, and place a leafy green plant (Wood element) between them to bridge Water and Fire.",
                            "コンロと浴室ドアの正対を避け、間に観葉植物（木気）を置いて「水生木・木生火」の通関を図ってください。",
                            "화구와 욕실 문이 마주 보지 않게 어긋나게 두고, 사이에 상록 식물(목 기운)을 배치해 수생목·목생화로 통관시키세요.",
                            "Đặt lệch hướng bếp và cửa phòng vệ sinh, đồng thời bố trí cây xanh (hành Mộc) ở giữa để Thủy sinh Mộc, Mộc sinh Hỏa.",
                            "จัดวางเตาไฟไม่ให้ตรงกับประตูห้องน้ำ และวางต้นไม้ใบเขียว (ธาตุไม้) คั่นกลางเพื่อเชื่อมสมดุลน้ำเกิดไม้และไม้หนุนไฟ",
                            "Hindari posisi kompor berhadapan langsung dengan pintu kamar mandi, dan letakkan tanaman hijau (unsur Kayu) sebagai jembatan elemen."
                        ),
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
            val wStr = String.format(Locale.US, "%.2f", firstMainDoor.width)
            val segName = eval.localizedYangSegmentName
            if (eval.yangIsAuspicious) {
                shaItems.add(HouseSpatialShaItem(
                    title = tr8(
                        "鲁班门光尺 · 大门纳吉", "魯班門光尺 · 大門納吉", "Lu Ban Ruler · Auspicious Entrance",
                        "魯班門光尺・玄関納吉", "노반척 · 대문 납길", "Thước Lỗ Ban · Cửa Chính Nạp Cát",
                        "บรรทัดหลู่ปาน · ประตูมงคล", "Penggaris Lu Ban · Pintu Utama Berkah"
                    ),
                    severity = SpatialShaSeverity.AUSPICIOUS,
                    locationName = tr8(
                        "入户大门 (宽 ${wStr}m)", "入戶大門 (寬 ${wStr}m)", "Main Entrance (width ${wStr}m)",
                        "玄関ドア（幅 ${wStr}m）", "현관문 (폭 ${wStr}m)", "Cửa chính (rộng ${wStr}m)",
                        "ประตูทางเข้าหลัก (กว้าง $wStr ม.)", "Pintu Utama (lebar ${wStr}m)"
                    ),
                    detail = tr8(
                        "入户门开间度量合鲁班门光尺【$segName】字门，迎祥纳福，广纳正气生机。",
                        "入戶門開間度量合魯班門光尺【$segName】字門，迎祥納福，廣納正氣生機。",
                        "The main entrance width aligns with the auspicious [$segName] segment on the Lu Ban Yang-House Ruler, welcoming vibrant qi.",
                        "玄関の開口幅が魯班尺の吉寸【$segName】に合致しており、瑞気を迎え入れる良好な寸法です。",
                        "현관문 개구부 폭이 노반척의 길한 치수인 【$segName】문에 부합하여 상서로운 생기를 받아들입니다.",
                        "Chiều rộng cửa chính ứng với cung tốt 【$segName】 trên thước Lỗ Ban Dương Trạch, đón nhận sinh khí cát tường.",
                        "ความกว้างประตูทางเข้าตรงกับช่องมงคล【$segName】ตามมาตรวัดหลู่ปาน ช่วยเปิดรับพลังชี่ที่ดีเข้าสู่บ้าน",
                        "Lebar pintu utama berada pada segmen baik [$segName] pada penggaris Lu Ban, mendukung masuknya energi positif."
                    ),
                    fengshuiLore = tr8(
                        "鲁班先师制尺定度，八寸循环纳吉，门吉则气正。",
                        "魯班先師制尺定度，八寸循環納吉，門吉則氣正。",
                        "Master Lu Ban's eight-segment cycle measures doorway proportions; an auspicious gate dimension supports balanced entry qi.",
                        "魯班尺の八寸循環において吉門に合致すると、気口が整い家運が安定するとされます。",
                        "노반척 팔문 순환에서 길한 치수에 해당하면 기구(氣口)가 바르게 서서 가운이 안정된다고 봅니다.",
                        "Thước Lỗ Ban chia tám cung tuần hoàn; kích thước cửa hợp cung cát giúp khí khẩu ngay ngắn, vượng trạch.",
                        "บรรทัดหลู่ปานแบ่งรอบแปดช่อง เมื่อขนาดประตูตกช่องมงคลจะช่วยให้ปากทางรับชี่สมดุล",
                        "Siklus delapan segmen penggaris Lu Ban mengukur proporsi pintu; ukuran yang tepat menjaga keseimbangan gerbang qi."
                    ),
                    solution = tr8(
                        "大门尺寸得吉，宜保持玄关整洁明亮，门前不堆杂物，使吉气源源入户。",
                        "大門尺寸得吉，宜保持玄關整潔明亮，門前不堆雜物，使吉氣源源入戶。",
                        "Keep the foyer bright, tidy, and free of clutter so auspicious qi flows smoothly into the home.",
                        "玄関周りを常に明るく清潔に保ち、靴や雑物を溜めないことで吉気がスムーズに巡ります。",
                        "현관을 항상 밝고 청결하게 유지하고 문 앞에 잡동사니를 두지 않으면 길한 기운이 원활히 유입됩니다.",
                        "Giữ khu vực huyền quan sáng sủa, gọn gàng, không chất đồ bừa bộn trước cửa để đón cát khí.",
                        "รักษาบริเวณโถงทางเข้าให้สะอาดสว่าง ไม่วางของเกะกะหน้าประตู เพื่อให้พลังมงคลไหลเวียนสะดวก",
                        "Jaga area foyer tetap terang, rapi, dan bebas tumpukan barang agar energi baik mengalir lancar."
                    ),
                    coordinate = firstMainDoor.position
                ))
                score += 5
            } else {
                shaItems.add(HouseSpatialShaItem(
                    title = tr8(
                        "鲁班门光尺 · 大门失度", "魯班門光尺 · 大門失度", "Lu Ban Ruler · Non-Ideal Door Width",
                        "魯班門光尺・寸法注意", "노반척 · 대문 치수 주의", "Thước Lỗ Ban · Kích Thước Cửa Cần Lưu Ý",
                        "บรรทัดหลู่ปาน · ขนาดประตูควรระวัง", "Penggaris Lu Ban · Lebar Pintu Kurang Ideal"
                    ),
                    severity = SpatialShaSeverity.WARNING,
                    locationName = tr8(
                        "入户大门 (宽 ${wStr}m)", "入戶大門 (寬 ${wStr}m)", "Main Entrance (width ${wStr}m)",
                        "玄関ドア（幅 ${wStr}m）", "현관문 (폭 ${wStr}m)", "Cửa chính (rộng ${wStr}m)",
                        "ประตูทางเข้าหลัก (กว้าง $wStr ม.)", "Pintu Utama (lebar ${wStr}m)"
                    ),
                    detail = tr8(
                        "大门宽度落入鲁班门光尺【$segName】凶度字门，门气略有亏耗。",
                        "大門寬度落入魯班門光尺【$segName】凶度字門，門氣略有虧耗。",
                        "The main entrance width falls in the [$segName] segment on the traditional Lu Ban Ruler; verify actual frame clearance.",
                        "玄関幅が魯班尺の【$segName】門に該当します。実測の内法寸法を再確認してください。",
                        "현관문 폭이 노반척의 【$segName】 구간에 해당합니다. 실제 문틀 안쪽 치수를 확인하세요.",
                        "Chiều rộng cửa chính rơi vào cung 【$segName】 trên thước Lỗ Ban truyền thống; nên đo lại kích thước thông thủy thực tế.",
                        "ความกว้างประตูตกช่อง【$segName】ตามบรรทัดหลู่ปาน แนะนำให้วัดระยะช่องเปิดจริงของวงกบอีกครั้ง",
                        "Lebar pintu utama jatuh pada segmen [$segName] penggaris Lu Ban tradisional; periksa kembali ukuran bersih kusen."
                    ),
                    fengshuiLore = tr8(
                        "门不合度，气散难聚。",
                        "門不合度，氣散難聚。",
                        "Traditional carpentry lore favors adjusting trim or threshold proportions when doorway measurements fall outside auspicious segments.",
                        "伝統木工の尺度論では、内法寸法や敷居・枠見込みで吉寸に整えることが推奨されます。",
                        "전통 목수 척도론에서는 문틀 마감재나 문턱 치수를 조절해 길한 규격으로 맞추는 것을 권장합니다.",
                        "Theo phép đo Lỗ Ban truyền thống, có thể điều chỉnh nẹp khuôn cửa hoặc thảm ngạch cửa để cân đối lại khí khẩu.",
                        "ตามหลักช่างหลู่ปาน สามารถปรับคิ้ววงกบหรือพรมธรณีประตูเพื่อเสริมความสมดุลของช่องทางเข้าได้",
                        "Tradisi Lu Ban menyarankan penyesuaian lis kusen atau keset ambang pintu untuk menyeimbangkan proporsi pintu."
                    ),
                    solution = tr8(
                        "可优先确认门槛、地垫和通道尺寸，保持入口平整防滑；涉及改造时咨询具备资质的专业人员。",
                        "可優先確認門檻、地墊和通道尺寸，保持入口平整防滑；涉及改造時諮詢具備資質的專業人員。",
                        "Verify inner frame clearance, place a Five-Emperor coin threshold mat, and keep the entryway well-lit and slip-free.",
                        "内法寸法や敷居マットを確認し、玄関照明を明るく保ち、五帝銭マット等で気口を補ってください。",
                        "문틀 내측 치수와 문턱 매트를 점검하고, 현관 조명을 밝게 유지하거나 오제전 매트로 기운을 보완하세요.",
                        "Kiểm tra lại kích thước thông thủy, đặt thảm ngạch cửa kèm tiền Ngũ Đế và giữ đèn huyền quan sáng rõ.",
                        "ตรวจสอบระยะช่องไฟจริง วางพรมธรณีประตูหรือเหรียญห้าจักรพรรดิ และเปิดไฟโถงทางเข้าให้สว่าง",
                        "Periksa kembali lebar bersih kusen, gunakan keset ambang pintu yang rapi, dan pastikan pencahayaan foyer terang."
                    ),
                    coordinate = firstMainDoor.position
                ))
                score -= 4
            }
        }

        // H. 户型规整度与开间进深比
        if (dimensions.aspectRatio > 2.2f) {
            val ratioStr = String.format(Locale.US, "%.1f", dimensions.aspectRatio)
            shaItems.add(HouseSpatialShaItem(
                title = tr8(
                    "户型狭长 (深长损明)", "戶型狹長 (深長損明)", "Narrow Elongated Layout",
                    "狭長間取り（奥行き過多）", "협장형 평면 (깊고 좁은 구조)", "Mặt Bằng Hẹp Dài (Sâu Thiếu Sáng)",
                    "ผังบ้านแคบยาว (ลึกอับแสง)", "Denah Memanjang Sempit"
                ),
                severity = SpatialShaSeverity.WARNING,
                locationName = tr8(
                    "整体户型轮廓", "整體戶型輪廓", "Overall Footprint",
                    "住戸全体の輪郭", "전체 평면 윤곽", "Tổng thể mặt bằng",
                    "โครงร่างผังบ้านโดยรวม", "Bentuk Denah Keseluruhan"
                ),
                detail = tr8(
                    "全屋进深是开间的 $ratioStr 倍，形如长巷，中段采光通风弱，阴阳气流失衡。",
                    "全屋進深是開間的 $ratioStr 倍，形如長巷，中段採光通風弱，陰陽氣流失衡。",
                    "Total depth is ${ratioStr}× the width, forming a long corridor-like footprint where middle zones may lack daylight and cross-ventilation.",
                    "奥行きが間口の${ratioStr}倍あり、中間の採光・換気が弱まりやすい細長い形状です。",
                    "전체 깊이가 폭의 ${ratioStr}배에 달해 중간 구역의 채광과 통풍이 약해지기 쉬운 긴 구조입니다.",
                    "Chiều sâu gấp $ratioStr lần chiều rộng, làm khu vực giữa nhà dễ thiếu ánh sáng tự nhiên và đối lưu không khí.",
                    "ความลึกของบ้านมากกว่าความกว้างถึง $ratioStr เท่า ทำให้ช่วงกลางบ้านอาจรับแสงและระบายอากาศได้น้อย",
                    "Kedalaman rumah mencapai ${ratioStr}× lebarnya, sehingga bagian tengah cenderung kurang cahaya alami dan sirkulasi udara."
                ),
                fengshuiLore = tr8(
                    "方正者气厚，狭长者气薄。",
                    "方正者氣厚，狹長者氣薄。",
                    "Square, balanced footprints hold qi steadily; overly narrow layouts benefit from zoned lighting and visual widening.",
                    "方正な間取りは気が充実しやすく、細長い空間は照明と分区で気を整えるのが吉とされます。",
                    "방정한 평면은 기운이 두텁게 모이고, 좁고 긴 구조는 조명과 공간 구획으로 기운을 보완하는 것이 좋습니다.",
                    "Nhà vuông vức thì khí dày, nhà quá hẹp dài cần bổ sung ánh sáng và phân vùng để giữ cân bằng âm dương.",
                    "ผังบ้านที่ได้สัดส่วนจะเก็บพลังชี่ได้ดี ส่วนผังที่แคบยาวควรเสริมแสงสว่างและการแบ่งโซนให้สมดุล",
                    "Denah yang proporsional menahan energi dengan stabil; ruang memanjang perlu didukung pencahayaan yang merata."
                ),
                solution = tr8(
                    "室内中部走道采用镜面扩容与明亮照明，多设绿植增补生旺之气。",
                    "室內中部走道採用鏡面擴容與明亮照明，多設綠植增補生旺之氣。",
                    "Use bright warm lighting, side mirrors to visually widen the middle corridor, and leafy plants to invigorate stagnant zones.",
                    "中央通路に明るい照明や壁面ミラーを用いて広がりを出し、観葉植物を配して生気を補ってください。",
                    "중간 복도에 밝은 조명과 벽면 거울로 공간감을 넓히고, 관엽식물을 배치해 생기를 보충하세요.",
                    "Tăng cường chiếu sáng ấm và gương trang trí dọc hành lang giữa để mở rộng không gian, kết hợp đặt cây xanh tăng sinh khí.",
                    "เพิ่มไฟส่องสว่างและกระจกเงาด้านข้างบริเวณโถงกลางเพื่อขยายมิติสายตา พร้อมวางต้นไม้เพิ่มความสดชื่น",
                    "Gunakan pencahayaan hangat yang terang, cermin samping untuk memperluas kesan ruang di tengah, serta tanaman hijau."
                ),
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
                    val distStr = String.format(Locale.US, "%.1f", dist)
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "开门见灶 (入口视线提示)", "開門見灶 (入口視線提示)", "Entrance Facing Stove",
                            "開門見竈（玄関からコンロ直視）", "개문견조 (현관-가스레인지 직대)", "Khai Môn Kiến Táo (Mở Cửa Thấy Bếp)",
                            "เปิดประตูเห็นเตาไฟ", "Pintu Utama Menghadap Kompor"
                        ),
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = tr8(
                            "入户大门 ⟷ 厨灶", "入戶大門 ⟷ 廚灶", "Main Entrance ⟷ Stove",
                            "玄関ドア ⟷ コンロ", "현관문 ⟷ 조리대", "Cửa chính ⟷ Bếp nấu",
                            "ประตูหน้าบ้าน ⟷ เตาครัว", "Pintu Utama ⟷ Kompor"
                        ),
                        detail = tr8(
                            "《阳宅集成》原文有“开门见灶，钱财多耗”。入户门开启正对厨房炉灶（间距 $distStr 米），古籍将其解释为财耗象征；请关注入口视线、热源距离、通风和防火安全。",
                            "《陽宅集成》原文有「開門見灶，錢財多耗」。入戶門開啟正對廚房爐灶（間距 $distStr 米），古籍將其解釋為財耗象徵；請關注入口視線、熱源距離、通風和防火安全。",
                            "Yang Zhai Compendium notes: 'Seeing the stove upon opening the door scatters wealth.' The main entrance aligns directly with the kitchen stove ($distStr m apart); check entry sightlines, drafts near the burner, ventilation, and fire safety.",
                            "『陽宅集成』に「門を開けて竈を見れば財を耗す」とあります。玄関の正面にキッチンコンロが位置（距離 ${distStr}m）するため、視線・換気・火気安全を確認してください。",
                            "《양택집성》에 ‘문을 열어 부엌 화덕이 보이면 재물이 소모된다’고 했습니다. 현관문이 주방 조리대와 정면으로 마주하므로(거리 ${distStr}m) 시선 차단과 환기·화기 안전을 점검하세요.",
                            "《Dương Trạch Tập Thành》 có câu: “Khai môn kiến táo, tiền tài đa hao”. Cửa chính mở ra nhìn thẳng vào bếp nấu (cách $distStr m); nên lưu ý tầm nhìn, thông gió và an toàn nhiệt.",
                            "คัมภีร์《หยางไจ๋จี๋เฉิง》กล่าวว่า “เปิดประตูเห็นเตาไฟ ทรัพย์สินรั่วไหล” ประตูทางเข้าตรงกับเตาครัว (ห่าง $distStr ม.) ควรตรวจเช็คแนวสายตา การระบายอากาศ และความปลอดภัยจากความร้อน",
                            "Kitab Yang Zhai mencatat bahwa pintu utama yang langsung menghadap kompor (jarak $distStr m) kurang baik bagi penghimpunan rezeki; perhatikan garis pandang, ventilasi, dan keamanan api."
                        ),
                        fengshuiLore = tr8(
                            "出处：《阳宅集成》。解释：原文中的“钱财多耗”是传统文化判断，实际财务事项不由空间测算决定。",
                            "出處：《陽宅集成》。解釋：原文中的「錢財多耗」是傳統文化判斷，實際財務事項不由空間測算決定。",
                            "Source: Yang Zhai Compendium. Traditional residential lore links an exposed stove at the entry to resource drain; evaluate alongside practical kitchen airflow and privacy.",
                            "出典：『陽宅集成』。玄関の気流が火口に直撃することを忌む伝統的解釈であり、実生活では防風・視線配慮に当たります。",
                            "출전: 《양택집성》. 전통 양택론에서 화기 노출을 재물 소모의 상징으로 보며, 실제로는 현관 기류와 시선 차단을 뜻합니다.",
                            "Nguồn: 《Dương Trạch Tập Thành》. Quan niệm truyền thống kỵ gió cửa chính thổi thẳng vào bếp lửa làm tán khí.",
                            "ที่มา: 《หยางไจ๋จี๋เฉิง》 ตามธรรมเนียมโบราณถือว่าลมจากประตูหน้าไม่ควรพัดปะทะเตาไฟโดยตรง",
                            "Sumber: Yang Zhai Compendium. Tradisi feng shui menyarankan agar area memasak tidak langsung terekspos angin dan pandangan dari pintu depan."
                        ),
                        solution = tr8(
                            "在大门与厨房之间设置玄关柜或挂隔断门帘，平时厨房推拉门常闭以避穿冲。",
                            "在大門與廚房之間設置玄關櫃或掛隔斷門簾，平時廚房推拉門常閉以避穿衝。",
                            "Install a foyer cabinet or partition curtain between the entrance and kitchen, and keep the kitchen sliding door closed when not cooking.",
                            "玄関とキッチンの間に目隠し棚や暖簾を設け、普段はキッチンの引き戸を閉めて直衝を避けてください。",
                            "현관과 주방 사이에 파티션 수납장이나 가림 커튼을 설치하고, 평소 주방 슬라이딩 도어를 닫아두세요.",
                            "Đặt tủ huyền quan hoặc treo rèm ngăn giữa cửa chính và bếp, đồng thời đóng cửa trượt phòng bếp khi không nấu nướng.",
                            "ตั้งตู้กั้นทางเข้าหรือติดม่านบังสายตาระหว่างประตูหน้ากับห้องครัว และปิดประตูบานเลื่อนห้องครัวไว้เสมอ",
                            "Pasang kabinet foyer atau tirai penyekat antara pintu utama dan dapur, serta biasakan menutup pintu geser dapur."
                        ),
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
                    val distStr = String.format(Locale.US, "%.1f", dist)
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "开门见厕 (秽气迎门)", "開門見廁 (穢氣迎門)", "Entrance Facing Bathroom",
                            "開門見廁（玄関正面の浴室・トイレ）", "개문견측 (현관-화장실 직대)", "Khai Môn Kiến Xí (Mở Cửa Thấy Nhà Vệ Sinh)",
                            "เปิดประตูเห็นห้องน้ำ", "Pintu Utama Menghadap Kamar Mandi"
                        ),
                        severity = SpatialShaSeverity.WARNING,
                        locationName = tr8(
                            "入户大门 ⟷ 卫生间", "入戶大門 ⟷ 衛生間", "Main Entrance ⟷ Bathroom",
                            "玄関ドア ⟷ トイレ・浴室", "현관문 ⟷ 화장실", "Cửa chính ⟷ Nhà vệ sinh",
                            "ประตูหน้าบ้าน ⟷ ห้องน้ำ", "Pintu Utama ⟷ Kamar Mandi"
                        ),
                        detail = tr8(
                            "《八宅明镜》原文有“门为气口，厕乃浊泉；气口冲浊，福禄散亡”。大门入口正对卫生间（间距 $distStr 米），古籍将其解释为秽气迎门象征；建议关注隐私、通风、异味控制和出入口动线。",
                            "《八宅明鏡》原文有「門為氣口，廁乃濁泉；氣口衝濁，福祿散亡」。大門入口正對衛生間（間距 $distStr 米），古籍將其解釋為穢氣迎門象徵；建議關注隱私、通風、異味控制和出入口動線。",
                            "Eight Mansions Mirror states: 'The door is the qi mouth; when it faces turbid air, auspicious qi scatters.' The main entrance aligns with the bathroom ($distStr m apart); check privacy, ventilation, and odor control.",
                            "『八宅明鏡』では玄関正面のトイレを忌みます。玄関とトイレが正対（距離 ${distStr}m）しているため、視線・換気・防臭対策を確認してください。",
                            "《팔택명경》에서 문은 기의 입구라 탁한 기운과 마주치는 것을 꺼립니다. 현관이 화장실과 정면으로 마주하므로(거리 ${distStr}m) 프라이버시와 환기·방취를 점검하세요.",
                            "《Bát Trạch Minh Kính》 viết: “Môn vi khí khẩu, xí nãi trọc tuyền”. Cửa chính đối diện nhà vệ sinh (cách $distStr m); cần chú ý sự riêng tư, thông gió và khử mùi.",
                            "คัมภีร์《ปาไจ๋หมิงจิ้ง》กล่าวว่าประตูคือปากรับชี่ ไม่ควรปะทะห้องน้ำโดยตรง (ห่าง $distStr ม.) ควรดูแลเรื่องความเป็นส่วนตัว การระบายอากาศ และการป้องกันกลิ่น",
                            "Kitab Ba Zhai Ming Jing mengingatkan agar pintu utama sebagai mulut qi tidak langsung menghadap kamar mandi (jarak $distStr m); perhatikan privasi, ventilasi, dan kontrol kelembapan."
                        ),
                        fengshuiLore = tr8(
                            "《八宅明镜》云：'门为气口，厕乃浊泉；气口冲浊，福禄散亡'。",
                            "《八宅明鏡》云：「門為氣口，廁乃濁泉；氣口衝濁，福祿散亡」。",
                            "Eight Mansions Mirror: 'The main door is the mouth of qi; keep turbid bathroom air from meeting incoming fresh qi.'",
                            "『八宅明鏡』「門は気口なり」。玄関から入る清気が水回りの湿気・臭気と直撃するのを避けます。",
                            "《팔택명경》 ‘문위기구 측내탁천’. 현관으로 들어오는 맑은 기운이 습기·탁기와 정면으로 부딪히는 것을 피합니다.",
                            "《Bát Trạch Minh Kính》: Cửa chính là nơi nạp thanh khí, kỵ đối diện trực tiếp với uế khí nhà vệ sinh.",
                            "《ปาไจ๋หมิงจิ้ง》ระบุว่าประตูหลักคือช่องรับพลังงานบริสุทธิ์ จึงไม่ควรปะทะกับความชื้นและกลิ่นจากห้องน้ำ",
                            "Ba Zhai Ming Jing menekankan bahwa pintu utama adalah jalur masuk energi segar sehingga tidak boleh langsung bertemu udara lembap kamar mandi."
                        ),
                        solution = tr8(
                            "卫生间门加装闭门器保持常闭，悬挂过膝半透布帘，门内放置水种阔叶绿植净化浊气。",
                            "衛生間門加裝閉門器保持常閉，懸掛過膝半透布簾，門內放置水種闊葉綠植淨化濁氣。",
                            "Keep the bathroom door closed with an auto-closer, hang a knee-length fabric curtain, and place a broadleaf plant inside to freshen the air.",
                            "トイレのドアを常時閉め、丈の長い暖簾を掛け、室内に観葉植物や換気設備を整えて空気を浄化してください。",
                            "화장실 문에 도어클로저를 달아 상시 닫아두고, 긴 가림 커튼과 공기정화 식물을 비치하세요.",
                            "Lắp tay co giữ cửa nhà vệ sinh luôn đóng, treo rèm vải dài qua gối và đặt cây lá rộng thủy sinh để thanh lọc không khí.",
                            "ติดโช้คปิดประตูห้องน้ำให้ปิดสนิทเสมอ แขวนม่านผ้าคลุมเข่า และวางต้นไม้ฟอกอากาศในห้องน้ำ",
                            "Pasang penutup pintu otomatis agar kamar mandi selalu tertutup, tambahkan tirai pintu, dan letakkan tanaman daun lebar penyerap lembap."
                        ),
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
                        title = tr8(
                            "厨厕同壁 (水火相战)", "廚廁同壁 (水火相戰)", "Kitchen & Bathroom Shared Wall",
                            "厨廁同壁（水火の隣り合わせ）", "주측동벽 (주방·화장실 수화상전)", "Trù Xí Đồng Bích (Thủy Hỏa Xung Khắc)",
                            "ครัวและห้องน้ำใช้ผนังร่วมกัน (น้ำปะทะไฟ)", "Dapur & Kamar Mandi Berbagi Dinding"
                        ),
                        severity = SpatialShaSeverity.WARNING,
                        locationName = tr8(
                            "厨房 ⟷ 卫生间相隔", "廚房 ⟷ 衛生間相隔", "Kitchen ⟷ Bathroom Partition",
                            "キッチン ⟷ トイレ・浴室の隔壁", "주방 ⟷ 화장실 경계벽", "Vách ngăn Bếp ⟷ Nhà vệ sinh",
                            "ผนังกั้นห้องครัว ⟷ ห้องน้ำ", "Dinding Pembatas Dapur ⟷ Kamar Mandi"
                        ),
                        detail = tr8(
                            "《催官篇》原文有“水火不相容，宅母病腹痛”。厨房灶台与卫生间共用一面实体隔墙，按古籍象征会被解释为坎水逼近离火；请结合热源距离、通风、防水和使用安全复核。此处原文属于传统文化语境，不是医疗诊断。",
                            "《催官篇》原文有「水火不相容，宅母病腹痛」。廚房灶台與衛生間共用一面實體隔牆，按古籍象徵會被解釋為坎水逼近離火；請結合熱源距離、通風、防水和使用安全複核。此處原文屬於傳統文化語境，不是醫療診斷。",
                            "Cui Guan Pian notes: 'Water and Fire should not clash across the same wall.' The kitchen and bathroom share a partition wall, symbolizing Kan Water pressing Li Fire; verify waterproofing, plumbing lines, ventilation, and stove placement.",
                            "『催官篇』では水と火の隣接相克を戒めています。キッチンと浴室・トイレが隔壁を共有しているため、防水・配管・換気およびコンロ位置を確認してください。",
                            "《최관편》에서는 수기(화장실)와 화기(주방)가 한 벽을 사이에 두고 맞닿는 것을 경계합니다. 방수·배관·환기 및 조리대 위치를 점검하세요.",
                            "《Thôi Quan Biên》 nhắc nhở Thủy Hỏa không nên xung sát qua cùng một bức tường. Bếp và nhà vệ sinh chung vách ngăn; hãy kiểm tra chống thấm, đường ống, thông gió và vị trí đặt bếp.",
                            "คัมภีร์《ชุยกวานเพียน》กล่าวถึงพลังน้ำและไฟที่ไม่ควรปะทะกันผ่านผนังเดียว ห้องครัวและห้องน้ำใช้ผนังร่วมกัน ควรตรวจสอบระบบกันซึม ท่อน้ำ และการวางตำแหน่งเตา",
                            "Kitab Cui Guan Pian mengingatkan benturan unsur Air dan Api pada satu dinding. Dapur dan kamar mandi berbagi dinding pembatas; periksa lapisan kedap air, pipa, ventilasi, dan posisi kompor."
                        ),
                        fengshuiLore = tr8(
                            "出处：《催官篇》：“水火不相容，宅母病腹痛”。解释：原文把水火相逼与腹部不适作象征联系，属于传统堪舆文本，不是医疗判断。",
                            "出處：《催官篇》：「水火不相容，宅母病腹痛」。解釋：原文把水火相逼與腹部不適作象徵聯繫，屬於傳統堪輿文本，不是醫療判斷。",
                            "Source: Cui Guan Pian. Traditional Five-Element theory views stove Fire and bathroom Water backing onto the same wall as an elemental clash; Earth tones help mediate Fire and Water.",
                            "出典：『催官篇』。五行論では火（キッチン）と水（浴室）の直接対立を忌み、土気（ベージュ・黄系）で通関させます。",
                            "출전: 《최관편》. 오행상 화(주방)와 수(화장실)가 맞닿으면 수화상전이 되므로 토(土) 기운으로 중화하는 것을 권장합니다.",
                            "Nguồn: 《Thôi Quan Biên》. Theo Ngũ Hành, Hỏa của bếp và Thủy của phòng tắm tựa lưng vào cùng một vách nên dùng hành Thổ để thông quan.",
                            "ที่มา: 《ชุยกวานเพียน》 ตามหลักเบญจธาตุ ไฟของครัวและน้ำของห้องน้ำที่พิงผนังเดียวกันควรใช้ธาตุดินช่วยเชื่อมสมดุล",
                            "Sumber: Cui Guan Pian. Dalam teori Lima Elemen, Api dapur dan Air kamar mandi pada satu dinding dapat diseimbangkan dengan unsur Tanah."
                        ),
                        solution = tr8(
                            "灶台与马桶避免贴在同一面隔墙的正反两侧，墙面采用土黄色瓷砖以'土'通关化解。",
                            "灶台與馬桶避免貼在同一面隔牆的正反兩側，牆面採用土黃色瓷磚以「土」通關化解。",
                            "Avoid placing the stove and toilet directly back-to-back on the same wall, and use warm earth-toned tiles to bridge Fire and Water.",
                            "コンロと便器が同じ壁の表裏で重ならないように配置し、アースカラーのタイル等で「火生土・土克水」の調和を図ってください。",
                            "조리대와 변기가 같은 벽의 앞뒤에 맞닿지 않게 배치하고, 황토색·베이지 톤 타일로 수화 기운을 중화하세요.",
                            "Tránh đặt bếp nấu và bồn cầu tựa lưng trực tiếp vào hai mặt của cùng một bức tường; dùng gạch ốp màu vàng đất để thông quan Thủy Hỏa.",
                            "หลีกเลี่ยงการวางเตาไฟและโถสุขภัณฑ์พิงผนังด้านเดียวกันโดยตรง และใช้กระเบื้องโทนสีเอิร์ธโทนเพื่อเชื่อมสมดุลธาตุ",
                            "Hindari menempatkan kompor dan kloset saling membelakangi pada dinding yang sama, serta gunakan keramik bernuansa warna tanah (krem/kuning hangat)."
                        ),
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
                val wallDistStr = String.format(Locale.US, "%.1f", distToClosestWall)
                shaItems.add(HouseSpatialShaItem(
                    title = tr8(
                        "床头悬空 (靠山虚浮)", "床頭懸空 (靠山虛浮)", "Unbacked Headboard (No Support)",
                        "床頭懸空（ベッドヘッドの壁離れ）", "침두현공 (침대 헤드 무벽)", "Đầu Giường Chơi Vơi (Thiếu Điểm Tựa)",
                        "หัวเตียงลอย (ไร้ผนังพิงหลัง)", "Kepala Ranjang Tanpa Sandaran Dinding"
                    ),
                    severity = SpatialShaSeverity.WARNING,
                    locationName = tr8(
                        "卧床周围空间", "臥床周圍空間", "Around Bed",
                        "ベッド周辺空間", "침대 주변 공간", "Không gian quanh giường",
                        "พื้นที่รอบเตียงนอน", "Area Sekitar Ranjang"
                    ),
                    detail = tr8(
                        "卧床四周远离实体承重墙 (最近墙体 $wallDistStr 米)，床头悬空无依，主睡眠不实、事业贵人缺乏。",
                        "臥床四周遠離實體承重牆 (最近牆體 $wallDistStr 米)，床頭懸空無依，主睡眠不實、事業貴人缺乏。",
                        "The bed is positioned far from any solid wall (nearest wall $wallDistStr m away), leaving the headboard unsupported and reducing the sense of security during sleep.",
                        "ベッドが周囲の実壁から離れており（最短 ${wallDistStr}m）、ヘッドボードの後ろが抜けて落ち着きにくい配置です。",
                        "침대가 주변 실벽에서 떨어져 있어(최근접 벽체 ${wallDistStr}m) 침대 머리가 허공에 떠 있으므로 수면 안정감이 떨어질 수 있습니다.",
                        "Giường ngủ cách xa tường đặc (tường gần nhất $wallDistStr m), đầu giường chơi vơi thiếu điểm tựa khiến giấc ngủ kém sâu.",
                        "เตียงนอนอยู่ห่างจากผนังทึบ (ผนังใกล้สุด $wallDistStr ม.) หัวเตียงไม่มีผนังพิงหลัง ทำให้ขาดความมั่นคงขณะพักผ่อน",
                        "Ranjang berada jauh dari dinding masif (dinding terdekat $wallDistStr m), membuat kepala ranjang tanpa sandaran dan mengurangi rasa tenang saat tidur."
                    ),
                    fengshuiLore = tr8(
                        "《撼龙经》云：'人有靠则安，床有靠则稳'。床头紧贴实墙方有踏实依靠。",
                        "《撼龍經》云：「人有靠則安，床有靠則穩」。床頭緊貼實牆方有踏實依靠。",
                        "Classical lore: 'With a solid backing, rest is steady.' Placing the headboard flush against a solid wall provides acoustic and psychological stability.",
                        "『撼龍経』「人に靠あれば安し、床に靠あれば穏やかなり」。ベッド頭部は実壁につけるのが吉とされます。",
                        "《감룡경》 ‘인유고즉안 침유고즉온’. 침대 머리는 단단한 벽에 밀착해야 기운이 안정됩니다.",
                        "《Hám Long Kinh》: “Nhân hữu kháo tắc an, sàng hữu kháo tắc ổn”. Đầu giường tựa sát tường đặc mới tạo thế vững chãi.",
                        "《ฮั่นหลงจิง》กล่าวว่า “คนมีที่พึ่งจึงอุ่นใจ เตียงมีที่พิงจึงมั่นคง” หัวเตียงควรชิดผนังทึบ",
                        "Han Long Jing menyebutkan bahwa ranjang yang bersandar rapat pada dinding kokoh memberikan ketenangan dan dukungan energi yang stabil."
                    ),
                    solution = tr8(
                        "将床头移位紧贴实墙；若户型限制无法移位，可加装高大厚实的实木靠背板作人造靠山。",
                        "將床頭移位緊貼實牆；若戶型限制無法移位，可加裝高大厚實的實木靠背板作人造靠山。",
                        "Move the headboard flush against a solid wall; if the layout requires an island bed, anchor it with a tall, solid wood headboard or low storage console behind it.",
                        "ベッドヘッドを実壁につけるか、移動できない場合は背の高い木製ヘッドボードやローキャビネットを背後に設けてください。",
                        "침대 머리를 실벽에 붙이거나, 구조상 어렵다면 높고 두꺼운 원목 헤드보드나 낮은 수납장을 뒤에 배치해 의지처를 만드세요.",
                        "Kê sát đầu giường vào tường đặc; nếu không thể dịch chuyển, hãy lắp vách đầu giường gỗ cao dày hoặc tủ thấp phía sau làm điểm tựa.",
                        "เลื่อนหัวเตียงให้ชิดผนังทึบ หากย้ายไม่ได้แนะนำให้ใช้หัวเตียงไม้ทรงสูงที่แข็งแรงหรือวางตู้เตี้ยด้านหลังเป็นฉากพิง",
                        "Geser kepala ranjang agar menempel pada dinding masif, atau gunakan sandaran kepala kayu tebal/kabinet rendah di belakangnya."
                    ),
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
                val roomName = r.localizedName
                shaItems.add(HouseSpatialShaItem(
                    title = tr8(
                        "暗室无窗 (孤阴凝滞)", "暗室無窗 (孤陰凝滯)", "Windowless Room (Stagnant Yin)",
                        "暗室無窓（採光・換気の不足）", "암실무창 (채광·환기 부족)", "Phòng Tối Không Cửa Sổ (Cô Âm Ngưng Trệ)",
                        "ห้องมืดไร้หน้าต่าง (พลังหยินอับทึบ)", "Kamar Tanpa Jendela (Kurang Cahaya Alami)"
                    ),
                    severity = SpatialShaSeverity.WARNING,
                    locationName = roomName,
                    detail = tr8(
                        "卧室内缺乏采光外窗，自然光线与空气对流匮乏，久居阴气偏盛，易感神疲乏力。",
                        "臥室內缺乏採光外窗，自然光線與空氣對流匱乏，久居陰氣偏盛，易感神疲乏力。",
                        "This sleeping area lacks a direct exterior window, limiting natural daylight and fresh air circulation, which can lead to a stuffy, low-energy environment.",
                        "寝室に外窓がなく、自然採光と換気が不足しがちです。気が滞りやすいため照明と換気で陽気を補う必要があります。",
                        "침실에 외창이 부족해 자연 채광과 공기 순환이 원활하지 않으므로 실내 기운이 침체되기 쉽습니다.",
                        "Phòng ngủ thiếu cửa sổ đón nắng và đối lưu không khí tự nhiên, ở lâu dễ gây cảm giác bí bách, mệt mỏi.",
                        "ห้องนอนขาดหน้าต่างรับแสงธรรมชาติและการหมุนเวียนของอากาศ อาจทำให้รู้สึกอึดอัดและอ่อนเพลียได้ง่าย",
                        "Kamar tidur kurang memiliki jendela luar untuk cahaya alami dan sirkulasi udara segar sehingga ruangan terasa pengap."
                    ),
                    fengshuiLore = tr8(
                        "《疑龙经》云：'无窗则气闭，阴盛则阳衰'。起居之所当见曦光，阴阳交泰。",
                        "《疑龍經》云：「無窗則氣閉，陰盛則陽衰」。起居之所當見曦光，陰陽交泰。",
                        "Yi Long Jing: 'Without windows, qi closes in and Yin outweighs Yang.' Living spaces thrive on balanced daylight and fresh air.",
                        "『疑龍経』「窓無ければ気閉ざし、陰盛んなれば陽衰う」。居室には適度な陽光と通風が不可欠とされます。",
                        "《의룡경》 ‘무창즉기폐 음성즉양쇠’. 거처하는 방은 햇빛과 통풍이 조화를 이루어야 음양이 균형을 잡습니다.",
                        "《Nghi Long Kinh》: “Vô song tắc khí bế, âm thịnh tắc dương suy”. Nơi nghỉ ngơi cần ánh sáng và thông khí hài hòa.",
                        "《อี๋หลงจิง》กล่าวว่า “ไร้หน้าต่างชี่อับทึบ หยินมากเกินหยางอ่อนแรง” ห้องพักอาศัยควรได้รับแสงและอากาศที่สมดุล",
                        "Yi Long Jing menyatakan bahwa ruangan tanpa bukaan cahaya membuat udara tertutup dan mengurangi keseimbangan Yin-Yang."
                    ),
                    solution = tr8(
                        "房门上方加装透光玻璃气窗或百叶排风，室内增加全光谱暖白照明，摆放开光黄玉聚阳阵。",
                        "房門上方加裝透光玻璃氣窗或百葉排風，室內增加全光譜暖白照明，擺放開光黃玉聚陽陣。",
                        "Add a transom glass panel or louver vent above the door, use full-spectrum warm-white lighting, and ensure mechanical ventilation.",
                        "ドア上部に採光欄間や換気ルーバーを設け、フルスペクトラムの暖白色照明で陽気を補ってください。",
                        "방문 상단에 채광창이나 환기 루버를 설치하고, 전구색 풀스펙트럼 조명으로 양기를 보충하세요.",
                        "Lắp ô thoáng kính hoặc lam thông gió phía trên cửa, bổ sung đèn ánh sáng trắng ấm toàn phổ để tăng dương khí.",
                        "ติดตั้งช่องแสงกระจกหรือบานเกล็ดระบายอากาศเหนือประตู และเพิ่มไฟแสงขาวอมเหลืองเพื่อเสริมพลังหยาง",
                        "Tambahkan ventilasi kaca atau kisi udara di atas pintu, serta gunakan lampu warm-white spektrum penuh untuk menjaga kesegaran ruang."
                    ),
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
                val rName = room.localizedName
                val starName = item.star.localizedName
                if (room.type == FloorplanRoomType.BATHROOM && (item.star == StarLuckType.SHENG_QI || item.star == StarLuckType.YAN_NIAN || item.star == StarLuckType.TIAN_YI)) {
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "吉位落水 (污秽吉星)", "吉位落水 (污穢吉星)", "Bathroom in Auspicious Sector",
                            "吉位落水（吉方位の水回り）", "길위낙수 (길방에 위치한 화장실)", "Cát Vị Lạc Thủy (Phòng Tắm Ở Cung Cát)",
                            "ตำแหน่งมงคลตกน้ำ (ห้องน้ำทับทิศมงคล)", "Kamar Mandi di Sektor Mujur"
                        ),
                        severity = SpatialShaSeverity.CRITICAL,
                        locationName = tr8(
                            "$rName · 落于【$starName】大吉方",
                            "$rName · 落於【$starName】大吉方",
                            "$rName · in [$starName] Auspicious Sector",
                            "$rName・【$starName】吉方位",
                            "$rName · 【$starName】 대길방",
                            "$rName · thuộc cung đại cát 【$starName】",
                            "$rName · ทับทิศมงคล【$starName】",
                            "$rName · di Sektor Mujur [$starName]"
                        ),
                        detail = tr8(
                            "卫生间落在全屋八宅【$starName】方位，属于传统文化中的布局提示，请结合实际防水、通风和使用情况复核。",
                            "衛生間落在全屋八宅【$starName】方位，屬於傳統文化中的佈局提示，請結合實際防水、通風和使用情況複核。",
                            "The bathroom sits in the house's Eight Mansions [$starName] auspicious sector; keep the space dry, clean, and well-ventilated.",
                            "トイレ・浴室が八宅の【$starName】吉方位に位置しています。防水・換気・清潔を保って吉気の損耗を防いでください。",
                            "화장실이 팔택 【$starName】 길방에 위치해 있습니다. 습기와 냄새가 차지 않도록 환기와 청결을 유지하세요.",
                            "Nhà vệ sinh nằm tại cung cát 【$starName】 theo Bát Trạch; cần giữ khô ráo, thông thoáng để tránh làm suy giảm cát khí.",
                            "ห้องน้ำตั้งอยู่ในทิศมงคล【$starName】ตามหลักปาไจ๋ ควรรักษาความสะอาดและระบายความชื้นอยู่เสมอ",
                            "Kamar mandi berada di sektor baik [$starName] Ba Zhai; jaga kebersihan, kekeringan, dan sirkulasi udara agar energi tetap harmonis."
                        ),
                        fengshuiLore = tr8(
                            "《八宅明镜》云：'吉星落厕，吉亦成殃'。生气延年宜作卧房书斋，不宜落水。",
                            "《八宅明鏡》云：「吉星落廁，吉亦成殃」。生氣延年宜作臥房書齋，不宜落水。",
                            "Eight Mansions Mirror recommends reserving Sheng Qi, Yan Nian, and Tian Yi sectors for bedrooms or studies rather than wet areas.",
                            "『八宅明鏡』では生気・延年・天医の三吉方は寝室や書斎に適し、水回りになる場合は浄化が必要と説きます。",
                            "《팔택명경》에서는 생기·연년·천의 삼길방에 화장실이 오면 목(木) 기운의 식물로 수기를 흡수해 정화하라고 권합니다.",
                            "《Bát Trạch Minh Kính》 khuyên các cung Sinh Khí, Diên Niên, Thiên Y nên ưu tiên làm phòng ngủ hoặc phòng đọc sách.",
                            "《ปาไจ๋หมิงจิ้ง》ระบุว่าทิศเซิงชี่ เหยียนเหนียน และเทียนอี เหมาะสำหรับห้องนอนหรือห้องทำงานมากกว่าห้องน้ำ",
                            "Ba Zhai Ming Jing menganjurkan sektor Sheng Qi, Yan Nian, dan Tian Yi untuk ruang tidur atau kerja; jika ditempati kamar mandi, perlu dijaga tetap kering."
                        ),
                        solution = tr8(
                            "卫生间马桶上方摆放一盆金边虎尾兰以木吸水，挂置开光纯铜葫芦收敛秽气护持吉星。",
                            "衛生間馬桶上方擺放一盆金邊虎尾蘭以木吸水，掛置開光純銅葫蘆收斂穢氣護持吉星。",
                            "Place a snake plant (Wood absorbs Water) in the bathroom, keep the lid and door closed, and hang a brass gourd to preserve auspicious qi.",
                            "トイレ内にサンスベリア等の観葉植物（木気で水気を吸う）を置き、銅瓢箪を掛けて吉気を護持してください。",
                            "화장실 안에 산세베리아 화분(목기로 수기 흡수)을 두고, 동호리병을 걸어 탁기를 거두고 길성을 보호하세요.",
                            "Đặt chậu lưỡi hổ (Mộc hút Thủy) trong nhà vệ sinh và treo hồ lô đồng để thu nạp uế khí, bảo hộ cát tinh.",
                            "วางต้นลิ้นมังกรในห้องน้ำเพื่อใช้ธาตุไม้ดูดซับความชื้น และแขวนน้ำเต้าทองเหลืองเพื่อรักษาพลังงานมงคล",
                            "Letakkan tanaman lidah mertua (unsur Kayu menyerap Air) di kamar mandi dan gantung labu tembaga untuk menjaga energi baik."
                        ),
                        coordinate = room.center
                    ))
                    score -= 12
                } else if ((room.type == FloorplanRoomType.MASTER_BEDROOM || room.type == FloorplanRoomType.SECOND_BEDROOM) && item.star.isAuspicious) {
                    shaItems.add(HouseSpatialShaItem(
                        title = tr8(
                            "卧房得位 (吉星拱照)", "臥房得位 (吉星拱照)", "Bedroom in Auspicious Sector",
                            "臥房得位（吉星方位の寝室）", "침실득위 (길성 방위 안착)", "Phòng Ngủ Đắc Vị (Cát Tinh Chiếu)",
                            "ห้องนอนถูกโฉลก (ดาวมงคลหนุนนำ)", "Kamar Tidur di Sektor Mujur"
                        ),
                        severity = SpatialShaSeverity.AUSPICIOUS,
                        locationName = tr8(
                            "$rName · 居【$starName】方",
                            "$rName · 居【$starName】方",
                            "$rName · in [$starName] Sector",
                            "$rName・【$starName】方位",
                            "$rName · 【$starName】 방위",
                            "$rName · tại cung 【$starName】",
                            "$rName · อยู่ในทิศ【$starName】",
                            "$rName · di Sektor [$starName]"
                        ),
                        detail = tr8(
                            "卧房安于全屋八宅【$starName】吉位，居之安稳祥和、身心康泰、纳吉迎祥。",
                            "臥房安於全屋八宅【$starName】吉位，居之安穩祥和、身心康泰、納吉迎祥。",
                            "The bedroom is situated in the house's Eight Mansions [$starName] auspicious sector, supporting restful sleep, harmony, and vitality.",
                            "寝室が八宅の【$starName】吉方位に位置しており、心身の安定と家庭の和合に恵まれやすい好配置です。",
                            "침실이 팔택 【$starName】 길위에 자리하여 심신의 안정과 화목한 기운을 받는 좋은 배치입니다.",
                            "Phòng ngủ tọa tại cung cát 【$starName】 theo Bát Trạch, hỗ trợ giấc ngủ an ổn, sức khỏe và hòa khí gia đình.",
                            "ห้องนอนตั้งอยู่ในทิศมงคล【$starName】ตามหลักปาไจ๋ ส่งเสริมการพักผ่อนที่ราบรื่น สุขภาพแข็งแรง และความอบอุ่นในครอบครัว",
                            "Kamar tidur terletak di sektor baik [$starName] Ba Zhai, mendukung istirahat berkualitas, kesehatan, dan keharmonisan rumah."
                        ),
                        fengshuiLore = tr8(
                            "《阳宅三要》云：'门主灶配，吉星得位，富贵双全'。",
                            "《陽宅三要》云：「門主灶配，吉星得位，富貴雙全」。",
                            "Three Essentials of Yang Zhai: 'When the main room aligns with an auspicious star, peace and prosperity follow.'",
                            "『陽宅三要』「門・主・竈が調和し、吉星が位を得れば福寿具わる」。",
                            "《양택삼요》 ‘문·주·조가 조화를 이루고 길성이 제자리를 얻으면 복록이 따른다’고 했습니다.",
                            "《Dương Trạch Tam Yếu》: “Môn Chủ Táo phối, cát tinh đắc vị, phú quý song toàn”.",
                            "《หยางไจ๋ซานเย่า》กล่าวว่าเมื่อห้องหลักอยู่ในทิศดาวมงคล ย่อมส่งเสริมความเจริญรุ่งเรืองและความร่มเย็น",
                            "Yang Zhai San Yao menyatakan bahwa ketika kamar utama menempati bintang baik, ketenangan dan keberuntungan keluarga akan terjaga."
                        ),
                        solution = tr8(
                            "吉位得宜，床头朝向顺合吉方，保持室内整洁明亮即可长保吉运。",
                            "吉位得宜，床頭朝向順合吉方，保持室內整潔明亮即可長保吉運。",
                            "Maintain this favorable placement, align the headboard toward a supportive direction, and keep the room bright and uncluttered.",
                            "この良配置を活かし、ベッド頭部を吉方に向け、室内を明るく清潔に保ってください。",
                            "현재의 좋은 배치를 유지하고 침대 머리를 길방으로 맞추며 실내를 밝고 정결하게 관리하세요.",
                            "Giữ nguyên bố cục tốt này, hướng đầu giường thuận theo phương cát và giữ phòng luôn sáng sủa, gọn gàng.",
                            "รักษาการจัดวางที่ดีนี้ไว้ หันหัวเตียงไปทางทิศมงคล และดูแลห้องให้โปร่งโล่งสะอาดตาเสมอ",
                            "Pertahankan tata letak yang baik ini, arahkan kepala ranjang ke arah baik, dan jaga kamar tetap rapi serta terang."
                        ),
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
            val pName = palace.localizedPalaceName

            // 1. 五黄大煞 (5) 临门或临床
            if (palace.facingStar == 5 || palace.mountainStar == 5) {
                for (door in entranceDoors) {
                    val dRelX = door.posX - cx
                    val dRelZ = door.posZ - cz
                    val dAngle = (atan2(dRelX.toDouble(), -dRelZ.toDouble()) * 180.0 / Math.PI + compassHeading + 360.0) % 360.0
                    if (guaForAngle(dAngle) == pGua) {
                        shaItems.add(HouseSpatialShaItem(
                            title = tr8(
                                "玄空理气煞 · 五黄到门", "玄空理氣煞 · 五黃到門", "Xuan Kong · 5-Yellow at Entrance",
                                "玄空理気殺・五黄到門", "현공이기살 · 오황도문", "Huyền Không Lý Khí · Ngũ Hoàng Đáo Môn",
                                "ดาวเหินเสวียนคง · เบญจเหลืองทับประตูหน้า", "Xuan Kong · 5-Kuning di Pintu Utama"
                            ),
                            severity = SpatialShaSeverity.CRITICAL,
                            locationName = tr8(
                                "入户大门 · 逢【五黄大煞】", "入戶大門 · 逢【五黃大煞】", "Main Entrance · [5-Yellow Sha]",
                                "玄関ドア・【五黄大殺】", "현관문 · 【오황대살】", "Cửa chính · Gặp 【Ngũ Hoàng Đại Sát】",
                                "ประตูหน้าบ้าน · พบ【ดาว 5 เหลือง】", "Pintu Utama · [5-Kuning]"
                            ),
                            detail = tr8(
                                "玄空飞星五黄廉贞大煞飞临大门${pName}宫 (山向 ${palace.mountainStar}-${palace.facingStar})，门动则煞动，易招滞涩阻碍。",
                                "玄空飛星五黃廉貞大煞飛臨大門${pName}宮 (山向 ${palace.mountainStar}-${palace.facingStar})，門動則煞動，易招滯澀阻礙。",
                                "Flying Star 5-Yellow lands in the $pName palace at the main entrance (Mountain-Facing ${palace.mountainStar}-${palace.facingStar}); frequent door movement can stir Earth sha unless neutralized with Metal.",
                                "玄空飛星の五黄廉貞星が玄関の${pName}宮（山向 ${palace.mountainStar}-${palace.facingStar}）に飛臨しています。金気の化殺物で土殺を洩らすのが吉です。",
                                "현공비성 오황염정성이 현관 ${pName}궁(산향 ${palace.mountainStar}-${palace.facingStar})에 비림했습니다. 출입이 잦은 곳이므로 금(金) 기운으로 토살을 설기해야 합니다.",
                                "Sao Ngũ Hoàng Liêm Trinh bay đến cung $pName tại cửa chính (Sơn-Hướng ${palace.mountainStar}-${palace.facingStar}); cửa đóng mở thường xuyên nên cần dùng hành Kim để tiết giảm Thổ sát.",
                                "ดาว 5 เหลืองเหินลงเรือน$pName บริเวณประตูทางเข้า (ดาวภูเขา-ดาวหัน ${palace.mountainStar}-${palace.facingStar}) ควรใช้ธาตุทองช่วยสลายพลังดิน",
                                "Bintang Terbang 5-Kuning berada di sektor $pName pada pintu utama (Gunung-Hadap ${palace.mountainStar}-${palace.facingStar}); gunakan unsur Logam untuk meredam energi Tanah."
                            ),
                            fengshuiLore = tr8(
                                "《玄空秘旨》云：'五黄为毒药，动则招灾'。五黄到门宜化不宜克。",
                                "《玄空秘旨》云：「五黃為毒藥，動則招災」。五黃到門宜化不宜克。",
                                "Xuan Kong Secrets: '5-Yellow prefers calm and Metal drainage rather than confrontation.'",
                                "『玄空秘旨』では五黄は静を好み、金気（銅製品）で化殺するのが本義とされます。",
                                "《현공비지》에서는 오황토살을 자극하지 말고 금(金) 기운으로 설기하여 화살하라고 전합니다.",
                                "《Huyền Không Bí Chỉ》 dạy Ngũ Hoàng kỵ động, nên dùng Kim tiết Thổ chứ không nên khắc chế cứng.",
                                "《เสวียนคงมี่จื่อ》ระบุว่าดาว 5 เหลืองชอบความสงบ ควรสลายด้วยธาตุทองแทนการปะทะ",
                                "Xuan Kong Mi Zhi mengajarkan bahwa bintang 5-Kuning sebaiknya diredam dengan unsur Logam, bukan dilawan."
                            ),
                            solution = tr8(
                                "玄关处悬挂纯铜六字真言风铃或安忍水，以六白金气泄化五黄土煞，忌铺红地毯。",
                                "玄關處懸掛純銅六字真言風鈴或安忍水，以六白金氣洩化五黃土煞，忌鋪紅地毯。",
                                "Place a brass windchime, Six-Emperor coins, or an Anren salt-water cure at the foyer to drain 5-Yellow Earth with Metal; avoid red doormats.",
                                "玄関に真鍮風鈴・六帝銭・安忍水（塩水銅貨）を置いて金気で五黄の土気を洩らし、赤いマットは避けてください。",
                                "현관에 순동 풍경이나 육제전·안인수를 두어 금 기운으로 오황토살을 설기하고, 붉은색 매트는 피하세요.",
                                "Treo chuông gió đồng, tiền Lục Đế hoặc đặt bình An Nhẫn Thủy ở huyền quan để dùng Kim tiết Thổ; tránh trải thảm đỏ.",
                                "แขวนกระดิ่งลมทองเหลือง เหรียญหกจักรพรรดิ หรือวางโถน้ำเกลืออันเหรินสุ่ยบริเวณทางเข้า และหลีกเลี่ยงพรมสีแดง",
                                "Gantung lonceng angin kuningan, Koin Enam Kaisar, atau letakkan Anren Shui di foyer untuk meredam unsur Tanah, serta hindari keset merah."
                            ),
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
                            title = tr8(
                                "玄空理气煞 · 五黄加枕", "玄空理氣煞 · 五黃加枕", "Xuan Kong · 5-Yellow at Bed",
                                "玄空理気殺・五黄加枕", "현공이기살 · 오황가침", "Huyền Không Lý Khí · Ngũ Hoàng Lâm Giường",
                                "ดาวเหินเสวียนคง · เบญจเหลืองทับตำแหน่งเตียง", "Xuan Kong · 5-Kuning di Area Ranjang"
                            ),
                            severity = SpatialShaSeverity.CRITICAL,
                            locationName = tr8(
                                "卧床枕位 · 逢【五黄星】", "臥床枕位 · 逢【五黃星】", "Bed Position · [5-Yellow Star]",
                                "ベッド位置・【五黄星】", "침대 위치 · 【오황성】", "Vị trí giường · Gặp 【Sao Ngũ Hoàng】",
                                "ตำแหน่งเตียงนอน · พบ【ดาว 5 เหลือง】", "Posisi Ranjang · [Bintang 5-Kuning]"
                            ),
                            detail = tr8(
                                "《紫白诀》原文有“五黄重叠，灾疾并临”。卧床枕位位于玄空五黄星飞临之${pName}宫，古籍将其解释为灾疾象征，请结合通风、噪音和动线复核。",
                                "《紫白訣》原文有「五黃重疊，災疾並臨」。臥床枕位位於玄空五黃星飛臨之${pName}宮，古籍將其解釋為災疾象徵，請結合通風、噪音和動線複核。",
                                "Purple-White Scroll notes that 5-Yellow in the sleeping sector ($pName palace) calls for stillness and Metal remedies; check bedroom ventilation and noise as well.",
                                "『紫白訣』に基づき、ベッドが玄空五黄星の飛臨する${pName}宮にあります。静穏を保ち、銅製アイテムで土気を和らげてください。",
                                "《자백결》에 따라 침대가 현공 오황성이 비림한 ${pName}궁에 위치합니다. 주변을 정결히 하고 순동 소품으로 토살을 완화하세요.",
                                "Theo 《Tử Bạch Quyết》, vị trí giường ngủ nằm tại cung $pName có sao Ngũ Hoàng bay đến; nên giữ yên tĩnh và dùng vật phẩm đồng để hóa giải.",
                                "ตามคัมภีร์《จื่อไป๋เจวี๋ย》ตำแหน่งเตียงนอนอยู่ในเรือน$pName ที่มีดาว 5 เหลืองเหินลง แนะนำให้จัดพื้นที่ให้สงบและตั้งน้ำเต้าทองเหลือง",
                                "Menurut Zi Bai Jue, posisi ranjang berada di sektor $pName yang ditempati bintang 5-Kuning; jaga ketenangan kamar dan tambahkan ornamen kuningan."
                            ),
                            fengshuiLore = tr8(
                                "出处：《紫白诀》。解释：此处展示古籍原句及其传统含义，不构成健康诊断。",
                                "出處：《紫白訣》。解釋：此處展示古籍原句及其傳統含義，不構成健康診斷。",
                                "Source: Purple-White Scroll (Zi Bai Jue). Traditional Xuan Kong star symbolism for spatial reference.",
                                "出典：『紫白訣』。伝統的な玄空飛星の象意に基づく空間参考です。",
                                "출전: 《자백결》. 전통 현공비성의 상징 해석을 바탕으로 한 공간 참고 안내입니다.",
                                "Nguồn: 《Tử Bạch Quyết》. Biểu trưng truyền thống của Cửu Tinh Huyền Không.",
                                "ที่มา: 《จื่อไป๋เจวี๋ย》 คำอธิบายตามหลักดาวเหินเสวียนคงแบบดั้งเดิม",
                                "Sumber: Zi Bai Jue. Interpretasi simbolis Bintang Terbang Xuan Kong tradisional."
                            ),
                            solution = tr8(
                                "床位微调避开五黄正对方位，床头柜放置天然纯铜葫芦化解土煞。",
                                "床位微調避開五黃正對方位，床頭櫃放置天然純銅葫蘆化解土煞。",
                                "Shift the bed slightly out of the 5-Yellow sector if possible, and place a solid brass gourd on the nightstand.",
                                "可能であればベッド位置を少しずらし、ナイトテーブルに純銅製の瓢箪を置いて土気を洩らしてください。",
                                "가능하면 침대 위치를 약간 조정하고, 협탁 위에 순동 호리병을 두어 토살을 설기하세요.",
                                "Dịch nhẹ vị trí giường khỏi góc Ngũ Hoàng nếu có thể, và đặt hồ lô đồng nguyên chất trên tủ đầu giường.",
                                "ขยับตำแหน่งเตียงเลี่ยงมุมดาว 5 เหลืองเล็กน้อย และวางน้ำเต้าทองเหลืองไว้ที่โต๊ะข้างเตียง",
                                "Geser sedikit posisi ranjang jika memungkinkan, dan letakkan labu kuningan di meja samping tempat tidur."
                            ),
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
                        val roomName = br.localizedName
                        shaItems.add(HouseSpatialShaItem(
                            title = tr8(
                                "玄空理气参考 · 二黑星临卧", "玄空理氣參考 · 二黑星臨臥", "Xuan Kong · 2-Black in Bedroom",
                                "玄空理気参考・二黒星臨臥", "현공이기 참고 · 이흑성 침실 비림", "Huyền Không Lý Khí · Nhị Hắc Lâm Phòng Ngủ",
                                "ดาวเหินเสวียนคง · ดาว 2 ดำในห้องนอน", "Xuan Kong · 2-Hitam di Kamar Tidur"
                            ),
                            severity = SpatialShaSeverity.WARNING,
                            locationName = tr8(
                                "$roomName · 逢【二黑病符】", "$roomName · 逢【二黑病符】", "$roomName · [2-Black Star]",
                                "$roomName・【二黒巨門星】", "$roomName · 【이흑거문성】", "$roomName · Gặp 【Sao Nhị Hắc】",
                                "$roomName · พบ【ดาว 2 ดำ】", "$roomName · [Bintang 2-Hitam]"
                            ),
                            detail = tr8(
                                "《飞星赋》原文有“二黑逢五，病生胸腹”。${roomName}坐落于二黑巨门星飞临之${pName}宫（山向 ${palace.mountainStar}-${palace.facingStar}），古籍将其解释为病符象征，请结合通风、采光、噪音和使用情况复核。",
                                "《飛星賦》原文有「二黑逢五，病生胸腹」。${roomName}坐落於二黑巨門星飛臨之${pName}宮（山向 ${palace.mountainStar}-${palace.facingStar}），古籍將其解釋為病符象徵，請結合通風、採光、噪音和使用情況複核。",
                                "Flying Star Ode notes that $roomName lies in the $pName palace visited by Star 2-Black (Mountain-Facing ${palace.mountainStar}-${palace.facingStar}); keep the room well-ventilated, sunlit, and balanced with Metal accents.",
                                "『飛星賦』に基づき、${roomName}が二黒巨門星の飛臨する${pName}宮（山向 ${palace.mountainStar}-${palace.facingStar}）にあります。換気・採光を良くし、銅製品や瓢箪で土気を和らげてください。",
                                "《비성부》에 따라 ${roomName}이(가) 이흑거문성이 비림한 ${pName}궁(산향 ${palace.mountainStar}-${palace.facingStar})에 자리합니다. 통풍과 채광을 유지하고 동제품이나 호리병으로 토기를 설기하세요.",
                                "Theo 《Phi Tinh Phú》, $roomName nằm tại cung $pName có sao Nhị Hắc Cự Môn bay đến (Sơn-Hướng ${palace.mountainStar}-${palace.facingStar}); nên giữ phòng thông thoáng và treo hồ lô hoặc tiền Lục Đế.",
                                "ตามคัมภีร์《เฟยซิงฟู่》 $roomName ตั้งอยู่ในเรือน$pName ที่มีดาว 2 ดำเหินลง (ดาวภูเขา-ดาวหัน ${palace.mountainStar}-${palace.facingStar}) ควรดูแลการระบายอากาศและแขวนน้ำเต้าหรือเหรียญหกจักรพรรดิ",
                                "Menurut Fei Xing Fu, $roomName berada di sektor $pName yang disinggahi bintang 2-Hitam (Gunung-Hadap ${palace.mountainStar}-${palace.facingStar}); jaga sirkulasi udara dan tambahkan labu kering atau enam koin logam."
                            ),
                            fengshuiLore = tr8(
                                "出处：《飞星赋》。解释：展示二黑星的古籍象征，不构成健康诊断。",
                                "出處：《飛星賦》。解釋：展示二黑星的古籍象徵，不構成健康診斷。",
                                "Source: Flying Star Ode (Fei Xing Fu). Traditional Xuan Kong symbolism for Star 2-Black.",
                                "出典：『飛星賦』。二黒土星に関する伝統的な玄空飛星の象意です。",
                                "출전: 《비성부》. 이흑토성에 관한 전통 현공비성의 상징 해석입니다.",
                                "Nguồn: 《Phi Tinh Phú》. Biểu trưng truyền thống của sao Nhị Hắc Thổ.",
                                "ที่มา: 《เฟยซิงฟู่》 ความหมายเชิงสัญลักษณ์ของดาว 2 ดำตามตำราเสวียนคง",
                                "Sumber: Fei Xing Fu. Makna simbolis bintang 2-Hitam dalam tradisi Xuan Kong."
                            ),
                            solution = tr8(
                                "卧房悬挂天然开光晒干葫芦或六帝钱以金泄土，室内避免大红厚毯。",
                                "臥房懸掛天然開光曬乾葫蘆或六帝錢以金洩土，室內避免大紅厚毯。",
                                "Hang a natural dried gourd or Six-Emperor coins in the bedroom to drain Earth with Metal, and avoid heavy red carpets.",
                                "寝室に天然の乾燥瓢箪や六帝銭を掛けて金気で土気を洩らし、真っ赤な厚手ラグは避けてください。",
                                "침실에 천연 박(호리병)이나 육제전을 걸어 금 기운으로 토기를 설기하고, 붉은색 두꺼운 카펫은 피하세요.",
                                "Treo hồ lô tự nhiên phơi khô hoặc tiền Lục Đế trong phòng ngủ để dùng Kim tiết Thổ, tránh trải thảm đỏ dày.",
                                "แขวนน้ำเต้าธรรมชาติหรือเหรียญหกจักรพรรดิในห้องนอนเพื่อสลายพลังดิน และหลีกเลี่ยงพรมสีแดงจัด",
                                "Gantung labu kering alami atau Koin Enam Kaisar di kamar tidur untuk meredam unsur Tanah, serta hindari karpet merah tebal."
                            ),
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
                            title = tr8(
                                "玄空旺星纳气 (空间参考)", "玄空旺星納氣 (空間參考)", "Xuan Kong · Timely Prosperous Star at Door",
                                "玄空旺星納気（当旺向星の玄関）", "현공왕성납기 (당왕향성 현관 비림)", "Huyền Không Vượng Tinh Nạp Khí",
                                "ดาวเจริญยุคเหินลงประตูหน้า (รับชี่มงคล)", "Xuan Kong · Bintang Makmur di Pintu Utama"
                            ),
                            severity = SpatialShaSeverity.AUSPICIOUS,
                            locationName = tr8(
                                "入户大门 · 逢【当旺向星】", "入戶大門 · 逢【當旺向星】", "Main Entrance · [Timely Facing Star]",
                                "玄関ドア・【当旺向星】", "현관문 · 【당왕향성】", "Cửa chính · Gặp 【Đương Vượng Hướng Tinh】",
                                "ประตูหน้าบ้าน · พบ【ดาวหันประจำยุค】", "Pintu Utama · [Bintang Hadap Makmur]"
                            ),
                            detail = tr8(
                                "入户门迎当前${curPeriod}运当旺向星飞临${pName}宫（山向 ${palace.mountainStar}-${palace.facingStar}），属于传统文化中的方位提示，请结合入口采光、通风、视线和动线复核。",
                                "入戶門迎當前${curPeriod}運當旺向星飛臨${pName}宮（山向 ${palace.mountainStar}-${palace.facingStar}），屬於傳統文化中的方位提示，請結合入口採光、通風、視線和動線複核。",
                                "The main entrance receives the current Period $curPeriod timely facing star in the $pName palace (Mountain-Facing ${palace.mountainStar}-${palace.facingStar}), an auspicious qi mouth when kept bright and open.",
                                "玄関が第${curPeriod}運の当旺向星が飛臨する${pName}宮（山向 ${palace.mountainStar}-${palace.facingStar}）を迎え、旺気を取り込みやすい吉配置です。",
                                "현관문이 현재 ${curPeriod}운의 당왕향성이 비림한 ${pName}궁(산향 ${palace.mountainStar}-${palace.facingStar})을 맞이하여 왕기를 받아들이는 길한 배치입니다.",
                                "Cửa chính đón sao hướng đương vượng Vận $curPeriod bay đến cung $pName (Sơn-Hướng ${palace.mountainStar}-${palace.facingStar}), rất thuận lợi để nạp sinh khí.",
                                "ประตูทางเข้าต้อนรับดาวหันประจำยุคที่ $curPeriod ในเรือน$pName (ดาวภูเขา-ดาวหัน ${palace.mountainStar}-${palace.facingStar}) ส่งเสริมการรับกระแสชี่มงคลเข้าสู่บ้าน",
                                "Pintu utama menyambut bintang hadap makmur Periode $curPeriod di sektor $pName (Gunung-Hadap ${palace.mountainStar}-${palace.facingStar}), sangat baik untuk menyerap energi positif."
                            ),
                            fengshuiLore = tr8(
                                "《天玉经》云：'向首一星灾福柄，当旺乘时发万箱'。",
                                "《天玉經》云：「向首一星災福柄，當旺乘時發萬箱」。",
                                "Jade Mirror Classic (Tian Yu Jing): 'The single star at the facing mouth governs fortune; when timely and prosperous, it brings abundance.'",
                                "『天玉経』「向首の一星は災福の柄、当旺にして時に乗ずれば大いに栄える」。",
                                "《천옥경》 ‘향수일성재복병 당왕승시발만상’. 향수(현관)에 당왕성이 오면 시운을 타서 번창한다고 봅니다.",
                                "《Thiên Ngọc Kinh》: “Hướng thủ nhất tinh tai phúc bính, đương vượng thừa thời phát vạn tương”.",
                                "《เทียนอวี้จิง》กล่าวว่าดาวหันหน้าคือหัวใจของโชคลาภ เมื่อตรงยุคที่รุ่งเรืองย่อมนำความอุดมสมบูรณ์มาให้",
                                "Tian Yu Jing menyebutkan bahwa bintang hadap yang sedang berjaya di pintu masuk membawa kemakmuran."
                            ),
                            solution = tr8(
                                "门厅保持明堂整洁开阔，设暖白长明灯引气入宅，生旺气场。",
                                "門廳保持明堂整潔開闊，設暖白長明燈引氣入宅，生旺氣場。",
                                "Keep the entry foyer (Ming Tang) clean and open, and maintain warm-white entryway lighting to welcome prosperous qi.",
                                "玄関ホール（内明堂）を明るく清潔に保ち、暖白色の照明を灯して旺気を室内に導いてください。",
                                "현관 명당을 깨끗하고 넓게 유지하고, 따뜻한 조명을 밝혀 왕기가 집안으로 잘 들어오게 하세요.",
                                "Giữ tiền sảnh (Minh Đường) luôn gọn gàng, thoáng đãng và bật đèn ánh sáng ấm để dẫn vượng khí vào nhà.",
                                "ดูแลโถงทางเข้า (หมิงถัง) ให้โล่งสะอาด และเปิดไฟแสงอบอุ่นเพื่อดึงดูดพลังงานมงคลเข้าสู่ตัวบ้าน",
                                "Jaga area foyer (Ming Tang) tetap rapi dan lapang, serta nyalakan lampu hangat untuk mengundang energi baik."
                            ),
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
                val degStr = String.format(Locale.US, "%.1f°", compassHeading)
                val kwTitle = kwLevel.localizedTitle
                shaItems.add(HouseSpatialShaItem(
                    title = tr8(
                        "玄空出卦 · 空亡破局煞", "玄空出卦 · 空亡破局煞", "Xuan Kong · Void Line (Kong Wang) Warning",
                        "玄空出卦・空亡破局殺", "현공출괘 · 공망파국살", "Huyền Không Xuất Quái · Không Vong Phá Cục",
                        "เสวียนคงหลุดข่วย · เส้นสูญญากาศ (คงหวง)", "Xuan Kong · Peringatan Garis Kosong (Kong Wang)"
                    ),
                    severity = SpatialShaSeverity.CRITICAL,
                    locationName = tr8(
                        "入户大门 · $kwTitle",
                        "入戶大門 · $kwTitle",
                        "Main Entrance · $kwTitle",
                        "玄関ドア・$kwTitle",
                        "현관문 · $kwTitle",
                        "Cửa chính · $kwTitle",
                        "ประตูหน้าบ้าน · $kwTitle",
                        "Pintu Utama · $kwTitle"
                    ),
                    detail = if (isMajor)
                        tr8(
                            "大门朝向 $degStr 正踏八卦大卦交界缝（大空亡绝线），五行错乱、阴阳差错，下卦排盘失效，必须以【替卦】重起九宫，属理气极凶出线。",
                            "大門朝向 $degStr 正踏八卦大卦交界縫（大空亡絕線），五行錯亂、陰陽差錯，下卦排盤失效，必須以【替卦】重起九宮，屬理氣極凶出線。",
                            "The main entrance heading ($degStr) falls directly on a boundary between two trigrams (Major Void Line / Da Kong Wang), mixing Five-Element qi; re-verify on site and use a Replacement Star (Ti Gua) chart.",
                            "玄関の向き（$degStr）が八卦の境界線（大空亡線）に重なっています。気が乱れやすいため、現地で方位を再確認し【替卦】盤で判断してください。",
                            "현관 향($degStr)이 팔괘 대괘 경계선(대공망선)에 걸쳐 있습니다. 오행 기운이 뒤섞이므로 현장에서 좌향을 재측정하고 【체괘】 반으로 감정해야 합니다.",
                            "Hướng cửa chính ($degStr) rơi đúng vào khe giao giới giữa hai quái lớn (Đại Không Vong), làm khí Ngũ Hành hỗn tạp; cần đo kiểm tra lại và lập bàn theo 【Thế Quái】.",
                            "ทิศประตูหน้าบ้าน ($degStr) ทับเส้นแบ่งเขตข่วยใหญ่ (ต้าคงหวง) ทำให้กระแสธาตุทั้งห้าแปรปรวน ควรวัดสอบทานซ้ำและผูกผังด้วย【ผังดาวแทน (ท่ีข่วย)】",
                            "Arah pintu utama ($degStr) tepat berada pada batas antartrigram (Garis Kosong Besar / Da Kong Wang); ukur ulang di lokasi dan gunakan peta Bintang Pengganti (Ti Gua)."
                        )
                    else if (isSmall)
                        tr8(
                            "大门朝向 $degStr 贴近同宫两山交界（小空亡出卦），气杂不纯、阴差阳错，须以【兼向替卦】排盘化解。",
                            "大門朝向 $degStr 貼近同宮兩山交界（小空亡出卦），氣雜不純、陰差陽錯，須以【兼向替卦】排盤化解。",
                            "The main entrance heading ($degStr) lies near the boundary between two mountains in the same palace (Minor Void / Xiao Kong Wang); evaluate using a Replacement Star (Ti Gua) chart.",
                            "玄関の向き（$degStr）が同宮二山の境界（小空亡）に近いため、【兼向替卦】盤で旺衰を確認してください。",
                            "현관 향($degStr)이 동궁 두 산의 경계(소공망)에 가까우므로 【겸향 체괘】 반으로 왕쇠를 점검하세요.",
                            "Hướng cửa chính ($degStr) sát ranh giới hai sơn đồng cung (Tiểu Không Vong); cần lập bàn theo 【Kiêm Hướng Thế Quái】 để luận giải.",
                            "ทิศประตูหน้าบ้าน ($degStr) อยู่ใกล้เส้นแบ่งสองขุนเขาในเรือนเดียวกัน (เสี่ยวคงหวง) ควรตรวจสอบด้วย【ผังดาวแทน (ท่ีข่วย)】",
                            "Arah pintu utama ($degStr) mendekati batas dua gunung dalam satu sektor (Xiao Kong Wang); gunakan peta Bintang Pengganti (Ti Gua)."
                        )
                    else
                        tr8(
                            "大门朝向 $degStr 处于兼向（替卦）区间，气场微杂驳纯，建议按替卦挨星排盘校验旺衰。",
                            "大門朝向 $degStr 處於兼向（替卦）區間，氣場微雜駁純，建議按替卦挨星排盤校驗旺衰。",
                            "The main entrance heading ($degStr) falls within a Sub-facing (Jian Xiang / Ti Gua) zone; verify star timeliness with a Replacement Star chart.",
                            "玄関の向き（$degStr）が兼向（替卦）区間にあります。替卦挨星盤で旺衰を照合してください。",
                            "현관 향($degStr)이 겸향(체괘) 구간에 해당하므로 체괘 애성반으로 왕쇠를 대조하세요.",
                            "Hướng cửa chính ($degStr) nằm trong vùng Kiêm Hướng (Thế Quái); nên đối chiếu vượng suy bằng bàn Thế Quái.",
                            "ทิศประตูหน้าบ้าน ($degStr) อยู่ในช่วงองศาเจียนเซี่ยง (ท่ีข่วย) แนะนำให้ตรวจสอบความรุ่งเรืองด้วยผังดาวแทน",
                            "Arah pintu utama ($degStr) berada di zona Sub-hadap (Ti Gua); periksa kekuatan bintang dengan peta Bintang Pengganti."
                        ),
                    fengshuiLore = tr8(
                        "堪舆古训：'出卦差错出孤寡，空亡线遇鬼神惊'。正针气场已乱，须以沈氏玄空替卦诀重排九宫飞星。",
                        "堪輿古訓：「出卦差錯出孤寡，空亡線遇鬼神驚」。正針氣場已亂，須以沈氏玄空替卦訣重排九宮飛星。",
                        "Classical Xuan Kong: boundary void lines unsettle pure trigram qi; Shen's Xuan Kong uses Replacement Stars (Ti Gua) when a heading crosses beyond pure bounds.",
                        "古典玄空では空亡線・兼向線を正針の気が交錯する境目とし、沈氏玄空の替卦訣で九宮を再配列します。",
                        "고전 현공에서는 공망선과 겸향선을 정침 기운이 교차하는 경계로 보며, 심씨현공 체괘결로 구궁비성을 재배열합니다.",
                        "Cổ huấn Huyền Không: Đường Không Vong làm lệch khí chính châm, cần dùng phép Thế Quái của Thẩm Thị Huyền Không để an lại Cửu Cung.",
                        "ตำราเสวียนคงโบราณระบุว่าเส้นคงหวงทำให้กระแสชี่แปรปรวน ต้องใช้เคล็ดวิชาดาวแทน (ท่ีข่วย) ของเสิ่นซื่อในการผูกผังเก้าเรือน",
                        "Klasik Xuan Kong mengajarkan bahwa garis batas Kong Wang mencampur energi trigram, sehingga perlu dihitung dengan metode Bintang Pengganti (Ti Gua)."
                    ),
                    solution = if (isMajor)
                        tr8(
                            "此线极凶，宜用实测罗盘复核坐向，优先整体挪门或以玄关斜向引气避开绝线；理气按【三元九运·替卦排盘】断验，忌择此线动土安门。",
                            "此線極凶，宜用實測羅盤複核坐向，優先整體挪門或以玄關斜向引氣避開絕線；理氣按【三元九運·替卦排盤】斷驗，忌擇此線動土安門。",
                            "Re-measure carefully away from metal interference; if confirmed on a Major Void line, adjust the door frame/foyer angle to shift the qi mouth and evaluate using the Ti Gua chart.",
                            "金属干渉を避けて方位を再計測し、大空亡線であれば玄関框や内玄関の角度調整で気口をずらし、【替卦排盤】で判断してください。",
                            "철제 간섭을 피해 좌향을 재측정하고, 대공망선이 확실하면 문틀이나 현관 가벽 각도를 조정해 기구를 틀어주며 【체괘배반】으로 판단하세요.",
                            "Đo kiểm tra lại ở nơi không bị nhiễu kim loại; nếu đúng tuyến Đại Không Vong, nên chỉnh góc khuôn cửa hoặc vách huyền quan để đổi hướng nạp khí và luận theo 【Thế Quái】.",
                            "วัดสอบทานซ้ำโดยห่างจากโลหะรบกวน หากทับเส้นต้าคงหวงจริง แนะนำให้ปรับองศาวงกบประตูหรือทำฉากทางเข้าเฉียงเพื่อเบี่ยงช่องรับชี่ และดูผลตาม【ผังดาวแทน】",
                            "Ukur ulang jauh dari gangguan logam; jika tepat di garis Da Kong Wang, sesuaikan sudut kusen atau sekat foyer untuk menggeser arah masuk qi dan gunakan peta Ti Gua."
                        )
                    else if (isSmall)
                        tr8(
                            "玄关/门厅设斜向过渡区导气，理气按【三元九运·替卦排盘】校验旺衰，择吉时安门更佳。",
                            "玄關/門廳設斜向過渡區導氣，理氣按【三元九運·替卦排盤】校驗旺衰，擇吉時安門更佳。",
                            "Add an angled foyer transition to guide incoming airflow and verify star timeliness with the Replacement Star (Ti Gua) chart.",
                            "玄関ホールに斜めの導入動線を設けて気を整え、【三元九運・替卦排盤】で旺衰を確認してください。",
                            "현관 홀에 완충 구역을 두어 기류를 유도하고 【삼원구운·체괘배반】으로 왕쇠를 점검하세요.",
                            "Bố trí vùng đệm chuyển hướng nhẹ ở huyền quan để dẫn khí và kiểm tra vượng suy theo 【Tam Nguyên Cửu Vận · Thế Quái】.",
                            "จัดโซนโถงทางเข้าช่วยเบี่ยงกระแสชี่ และตรวจสอบความรุ่งเรืองด้วย【ผังดาวแทนยุคทั้งเก้า】",
                            "Gunakan area transisi di foyer untuk mengarahkan aliran udara dan periksa kekuatan bintang pada peta Ti Gua."
                        )
                    else
                        tr8(
                            "玄关加设门帘缓气，理气按【三元九运·替卦排盘】校验旺衰即可。",
                            "玄關加設門簾緩氣，理氣按【三元九運·替卦排盤】校驗旺衰即可。",
                            "Soften entry airflow with a foyer curtain or mat and cross-check star timeliness using the Replacement Star (Ti Gua) chart.",
                            "玄関に暖簾やマットを添えて気を和らげ、【三元九運・替卦排盤】で旺衰を照合してください。",
                            "현관에 커튼이나 매트를 두어 기운을 완충하고 【삼원구운·체괘배반】으로 왕쇠를 확인하세요.",
                            "Treo thêm rèm hoặc thảm huyền quan để điều hòa dòng khí và đối chiếu vượng suy theo 【Thế Quái】.",
                            "เสริมม่านหรือพรมบริเวณทางเข้าเพื่อชะลอกระแสชี่ และตรวจเช็คดาวด้วย【ผังดาวแทน】",
                            "Tambahkan tirai atau keset foyer untuk menghaluskan aliran energi dan periksa peta Bintang Pengganti (Ti Gua)."
                        ),
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

    private fun tr8(
        hans: String,
        hant: String,
        en: String,
        ja: String,
        ko: String,
        vi: String,
        th: String,
        id: String
    ): String {
        return when (LocalizationManager.instance.effectiveLanguage) {
            AppLanguage.ZH_HANS, AppLanguage.AUTO -> hans
            AppLanguage.ZH_HANT -> hant
            AppLanguage.EN -> en
            AppLanguage.JA -> ja
            AppLanguage.KO -> ko
            AppLanguage.VI -> vi
            AppLanguage.TH -> th
            AppLanguage.ID -> id
        }
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
