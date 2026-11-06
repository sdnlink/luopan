package com.example.yiijingcompass.model

import java.util.Locale
import kotlin.math.abs
import kotlin.math.min

/**
 * 八方基础方位枚举
 */
enum class Direction8(val zhName: String) {
    NORTH("正北"),
    NORTHEAST("东北"),
    EAST("正东"),
    SOUTHEAST("东南"),
    SOUTH("正南"),
    SOUTHWEST("西南"),
    WEST("正西"),
    NORTHWEST("西北");

    val localizedName: String
        get() = when (this) {
            NORTH -> LocalizationManager.shared.t("dir_n")
            NORTHEAST -> LocalizationManager.shared.t("dir_ne")
            EAST -> LocalizationManager.shared.t("dir_e")
            SOUTHEAST -> LocalizationManager.shared.t("dir_se")
            SOUTH -> LocalizationManager.shared.t("dir_s")
            SOUTHWEST -> LocalizationManager.shared.t("dir_sw")
            WEST -> LocalizationManager.shared.t("dir_w")
            NORTHWEST -> LocalizationManager.shared.t("dir_nw")
        }

    val guaName: String
        get() = when (this) {
            NORTH -> "坎一宫"
            SOUTHWEST -> "坤二宫"
            EAST -> "震三宫"
            SOUTHEAST -> "巽四宫"
            NORTHWEST -> "乾六宫"
            WEST -> "兑七宫"
            NORTHEAST -> "艮八宫"
            SOUTH -> "离九宫"
        }

    val localizedGuaName: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN, AppLanguage.ID -> when (this) {
                    NORTH -> "Kan 1st Palace"
                    SOUTHWEST -> "Kun 2nd Palace"
                    EAST -> "Zhen 3rd Palace"
                    SOUTHEAST -> "Xun 4th Palace"
                    NORTHWEST -> "Qian 6th Palace"
                    WEST -> "Dui 7th Palace"
                    NORTHEAST -> "Gen 8th Palace"
                    SOUTH -> "Li 9th Palace"
                }
                AppLanguage.JA -> when (this) {
                    NORTH -> "坎一宮"
                    SOUTHWEST -> "坤二宮"
                    EAST -> "震三宮"
                    SOUTHEAST -> "巽四宮"
                    NORTHWEST -> "乾六宮"
                    WEST -> "兌七宮"
                    NORTHEAST -> "艮八宮"
                    SOUTH -> "離九宮"
                }
                AppLanguage.KO -> when (this) {
                    NORTH -> "감1궁"
                    SOUTHWEST -> "곤2궁"
                    EAST -> "진3궁"
                    SOUTHEAST -> "손4궁"
                    NORTHWEST -> "건6궁"
                    WEST -> "태7궁"
                    NORTHEAST -> "간8궁"
                    SOUTH -> "이9궁"
                }
                AppLanguage.VI -> when (this) {
                    NORTH -> "Cung Khảm 1"
                    SOUTHWEST -> "Cung Khôn 2"
                    EAST -> "Cung Chấn 3"
                    SOUTHEAST -> "Cung Tốn 4"
                    NORTHWEST -> "Cung Càn 6"
                    WEST -> "Cung Đoài 7"
                    NORTHEAST -> "Cung Cấn 8"
                    SOUTH -> "Cung Ly 9"
                }
                AppLanguage.TH -> when (this) {
                    NORTH -> "วังขั่น 1"
                    SOUTHWEST -> "วังคุน 2"
                    EAST -> "วังเจิ้น 3"
                    SOUTHEAST -> "วังซวิ่น 4"
                    NORTHWEST -> "วังเฉียน 6"
                    WEST -> "วังตุ้ย 7"
                    NORTHEAST -> "วังเกิ้น 8"
                    SOUTH -> "วังหลี 9"
                }
                AppLanguage.ZH_HANT -> when (this) {
                    NORTH -> "坎一宮"
                    SOUTHWEST -> "坤二宮"
                    EAST -> "震三宮"
                    SOUTHEAST -> "巽四宮"
                    NORTHWEST -> "乾六宮"
                    WEST -> "兌七宮"
                    NORTHEAST -> "艮八宮"
                    SOUTH -> "離九宮"
                }
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> guaName
            }
        }

    val element: String
        get() = when (this) {
            NORTH -> "水"
            SOUTHWEST, NORTHEAST -> "土"
            EAST, SOUTHEAST -> "木"
            NORTHWEST, WEST -> "金"
            SOUTH -> "火"
        }

    val localizedElement: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> when (this) {
                    NORTH -> "Water"
                    SOUTHWEST, NORTHEAST -> "Earth"
                    EAST, SOUTHEAST -> "Wood"
                    NORTHWEST, WEST -> "Metal"
                    SOUTH -> "Fire"
                }
                AppLanguage.ID -> when (this) {
                    NORTH -> "Air"
                    SOUTHWEST, NORTHEAST -> "Tanah"
                    EAST, SOUTHEAST -> "Kayu"
                    NORTHWEST, WEST -> "Logam"
                    SOUTH -> "Api"
                }
                AppLanguage.KO -> when (this) {
                    NORTH -> "수"
                    SOUTHWEST, NORTHEAST -> "토"
                    EAST, SOUTHEAST -> "목"
                    NORTHWEST, WEST -> "금"
                    SOUTH -> "화"
                }
                AppLanguage.VI -> when (this) {
                    NORTH -> "Thủy"
                    SOUTHWEST, NORTHEAST -> "Thổ"
                    EAST, SOUTHEAST -> "Mộc"
                    NORTHWEST, WEST -> "Kim"
                    SOUTH -> "Hỏa"
                }
                AppLanguage.TH -> when (this) {
                    NORTH -> "น้ำ"
                    SOUTHWEST, NORTHEAST -> "ดิน"
                    EAST, SOUTHEAST -> "ไม้"
                    NORTHWEST, WEST -> "ทอง"
                    SOUTH -> "ไฟ"
                }
                AppLanguage.AUTO, AppLanguage.ZH_HANS, AppLanguage.ZH_HANT, AppLanguage.JA -> element
            }
        }
}

/**
 * 二十四山数据模型
 */
data class Mountain24Item(
    val id: Int,
    val name: String,
    val pinyin: String,
    val angleCenter: Double,
    val element: String,
    val palace: String, // 坎、坤、震、巽、乾、兑、艮、离
    val yuan: String,   // 天元龙、地元龙、人元龙
    val polarity: Int   // +1 为阳，-1 为阴
) {
    val index: Int get() = id
    val subIndex: Int get() = id
    val post: String get() = palace
    val order: Int get() = when (yuan) {
        "天元龙" -> 1
        "地元龙" -> 2
        "人元龙" -> 3
        else -> 1
    }

    val angleStart: Double = (angleCenter - 7.5 + 360.0) % 360.0
    val angleEnd: Double = (angleCenter + 7.5) % 360.0
    val centerAngle: Double get() = angleCenter
    val startAngle: Double get() = angleStart
    val endAngle: Double get() = angleEnd

    val isCardinalOrCorner: Boolean
        get() = angleCenter % 45.0 == 0.0

    val localizedName: String
        get() {
            val language = LocalizationManager.shared.effectiveLanguage
            return when (language) {
                AppLanguage.EN, AppLanguage.ID -> pinyin
                AppLanguage.JA -> name.replace("兑", "兌").replace("离", "離")
                AppLanguage.KO -> {
                    val koNames = mapOf(
                        "壬" to "임", "子" to "자", "癸" to "계", "丑" to "축", "艮" to "간", "寅" to "인",
                        "甲" to "갑", "卯" to "묘", "乙" to "을", "辰" to "진", "巽" to "손", "巳" to "사",
                        "丙" to "병", "午" to "오", "丁" to "정", "未" to "미", "坤" to "곤", "申" to "신",
                        "庚" to "경", "酉" to "유", "辛" to "신", "戌" to "술", "乾" to "건", "亥" to "해"
                    )
                    koNames[name] ?: name
                }
                AppLanguage.VI -> {
                    val viNames = mapOf(
                        "壬" to "Nhâm", "子" to "Tý", "癸" to "Quý", "丑" to "Sửu", "艮" to "Cấn", "寅" to "Dần",
                        "甲" to "Giáp", "卯" to "Mão", "乙" to "Ất", "辰" to "Thìn", "巽" to "Tốn", "巳" to "Tỵ",
                        "丙" to "Bính", "午" to "Ngọ", "丁" to "Đinh", "未" to "Mùi", "坤" to "Khôn", "申" to "Thân",
                        "庚" to "Canh", "酉" to "Dậu", "辛" to "Tân", "戌" to "Tuất", "乾" to "Càn", "亥" to "Hợi"
                    )
                    viNames[name] ?: name
                }
                AppLanguage.TH -> {
                    val thNames = mapOf(
                        "壬" to "เหริน", "子" to "จื่อ", "癸" to "กุ่ย", "丑" to "โฉ่ว", "艮" to "เกิ้น", "寅" to "หยิน",
                        "甲" to "เจี่ย", "卯" to "เหมา", "乙" to "อี้", "辰" to "เฉิน", "巽" to "ซวิ่น", "巳" to "ซื่อ",
                        "丙" to "ปิ่ง", "午" to "อู่", "丁" to "ติง", "未" to "เว่ย", "坤" to "คุน", "申" to "เซิน",
                        "庚" to "เกิง", "酉" to "โหย่ว", "辛" to "ซิน", "戌" to "ซวี", "乾" to "เฉียน", "亥" to "ฮ่าย"
                    )
                    thNames[name] ?: name
                }
                AppLanguage.ZH_HANT -> name.replace("兑", "兌").replace("离", "離")
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> name
            }
        }

    val localizedPalace: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN, AppLanguage.ID -> {
                    val enPalaces = mapOf("坎" to "Kan", "坤" to "Kun", "震" to "Zhen", "巽" to "Xun", "乾" to "Qian", "兑" to "Dui", "艮" to "Gen", "离" to "Li")
                    enPalaces[palace] ?: palace
                }
                AppLanguage.JA -> {
                    val jaPalaces = mapOf("坎" to "坎", "坤" to "坤", "震" to "震", "巽" to "巽", "乾" to "乾", "兑" to "兌", "艮" to "艮", "离" to "離")
                    jaPalaces[palace] ?: palace
                }
                AppLanguage.KO -> {
                    val koPalaces = mapOf("坎" to "감", "坤" to "곤", "震" to "진", "巽" to "손", "乾" to "건", "兑" to "태", "艮" to "간", "离" to "이")
                    koPalaces[palace] ?: palace
                }
                AppLanguage.VI -> {
                    val viPalaces = mapOf("坎" to "Khảm", "坤" to "Khôn", "震" to "Chấn", "巽" to "Tốn", "乾" to "Càn", "兑" to "Đoài", "艮" to "Cấn", "离" to "Ly")
                    viPalaces[palace] ?: palace
                }
                AppLanguage.TH -> {
                    val thPalaces = mapOf("坎" to "ขั่น", "坤" to "คุน", "震" to "เจิ้น", "巽" to "ซวิ่น", "乾" to "เฉียน", "兑" to "ตุ้ย", "艮" to "เกิ้น", "离" to "หลี")
                    thPalaces[palace] ?: palace
                }
                AppLanguage.ZH_HANT -> palace.replace("兑", "兌").replace("离", "離")
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> palace
            }
        }

    val localizedElement: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> when (element) {
                    "水" -> "Water"
                    "木" -> "Wood"
                    "火" -> "Fire"
                    "土" -> "Earth"
                    "金" -> "Metal"
                    else -> element
                }
                AppLanguage.ID -> when (element) {
                    "水" -> "Air"
                    "木" -> "Kayu"
                    "火" -> "Api"
                    "土" -> "Tanah"
                    "金" -> "Logam"
                    else -> element
                }
                AppLanguage.KO -> when (element) {
                    "水" -> "수"
                    "木" -> "목"
                    "火" -> "화"
                    "土" -> "토"
                    "金" -> "금"
                    else -> element
                }
                AppLanguage.VI -> when (element) {
                    "水" -> "Thủy"
                    "木" -> "Mộc"
                    "火" -> "Hỏa"
                    "土" -> "Thổ"
                    "金" -> "Kim"
                    else -> element
                }
                AppLanguage.TH -> when (element) {
                    "水" -> "น้ำ"
                    "木" -> "ไม้"
                    "火" -> "ไฟ"
                    "土" -> "ดิน"
                    "金" -> "ทอง"
                    else -> element
                }
                else -> element
            }
        }
}

typealias Mountain24 = Mountain24Item

/**
 * 百二十分金数据项 (与 Fenjin120Item 统一对齐)
 */
typealias FenjinItem = Fenjin120Item

/**
 * 空亡判定等级 (正针纯清、兼针替卦、小空亡、大空亡)
 */
enum class KongWangLevel(val title: String, val desc: String) {
    PURE("正向纯清", "磁针居中，气场纯清，最利立向消砂纳水。"),
    JIAN_XIANG("兼针兼向", "偏心超度，需依替卦排星，阴阳互用。"),
    SMALL_VOID("差错小空亡", "贴近山界交线，气场杂驳，进退两难。"),
    LARGE_VOID("出卦大空亡", "逼近八宫卦界缝，阴阳驳杂，为大凶之线。");

    val description: String get() = desc

    val localizedTitle: String
        get() = when (this) {
            PURE -> LocalizationManager.shared.t("kw_pure_title")
            JIAN_XIANG -> LocalizationManager.shared.t("kw_sub_title")
            SMALL_VOID -> LocalizationManager.shared.t("kw_small_title")
            LARGE_VOID -> LocalizationManager.shared.t("kw_large_title")
        }

    val localizedDescription: String
        get() = when (this) {
            PURE -> LocalizationManager.shared.t("kw_pure_desc")
            JIAN_XIANG -> LocalizationManager.shared.t("kw_sub_desc")
            SMALL_VOID -> LocalizationManager.shared.t("kw_small_desc")
            LARGE_VOID -> LocalizationManager.shared.t("kw_large_desc")
        }
}

/**
 * 罗盘朝向全景状态
 */
data class CompassHeadingState(
    var heading: Double = 0.0,
    var trueHeading: Double = 0.0,
    var sittingAngle: Double = 180.0,
    var facingAngle: Double = 0.0,
    var facingMountain: Mountain24Item = Mountain24Data.mountains[1],   // 默认子山
    var sittingMountain: Mountain24Item = Mountain24Data.mountains[13], // 默认午山
    var facingFenjin: FenjinItem = Mountain24Data.resolveFenjin(0.0),
    var sittingFenjin: FenjinItem = Mountain24Data.resolveFenjin(180.0),
    var isJianXiang: Boolean = false,
    var jianXiangDegree: Double = 0.0,
    var fenJinDesc: String = "",
    var pitch: Double = 0.0,
    var roll: Double = 0.0,
    var isLevel: Boolean = true
) {
    /**
     * 空亡等级判级，与 iOS 保持 100% 算法对齐
     */
    val kongWangLevel: KongWangLevel
        get() {
            val a = (facingAngle % 360.0 + 360.0) % 360.0
            val center = (facingMountain.centerAngle % 360.0 + 360.0) % 360.0
            var rawDelta = abs(a - center)
            if (rawDelta > 180.0) rawDelta = 360.0 - rawDelta
            val delta = rawDelta

            if (delta >= 6.5) {
                var minGapToChuGua = 180.0
                for (k in 0 until 8) {
                    val line = 22.5 + 45.0 * k.toDouble()
                    var d = abs(a - line)
                    if (d > 180.0) d = 360.0 - d
                    minGapToChuGua = min(minGapToChuGua, d)
                }
                return if (minGapToChuGua <= 0.7) {
                    KongWangLevel.LARGE_VOID
                } else {
                    KongWangLevel.SMALL_VOID
                }
            } else if (delta >= 1.5) {
                return KongWangLevel.JIAN_XIANG
            }
            return KongWangLevel.PURE
        }
}

class Mountain24Data private constructor() {
    val mountains: List<Mountain24Item> get() = Companion.mountains
    fun mountain(angle: Double): Mountain24Item = resolveMountain(angle)
    fun resolveMountain(angle: Double): Mountain24Item = Companion.resolveMountain(angle)
    companion object {
        val instance: Mountain24Data by lazy { Mountain24Data() }
        val shared: Mountain24Data get() = instance

        val mountains: List<Mountain24Item> = listOf(
            Mountain24Item(0, "壬", "Ren", 345.0, "水", "坎", "地元龙", +1),
            Mountain24Item(1, "子", "Zi", 0.0, "水", "坎", "天元龙", -1),
            Mountain24Item(2, "癸", "Gui", 15.0, "水", "坎", "人元龙", -1),
            Mountain24Item(3, "丑", "Chou", 30.0, "土", "艮", "地元龙", -1),
            Mountain24Item(4, "艮", "Gen", 45.0, "土", "艮", "天元龙", +1),
            Mountain24Item(5, "寅", "Yin", 60.0, "木", "艮", "人元龙", +1),
            Mountain24Item(6, "甲", "Jia", 75.0, "木", "震", "地元龙", +1),
            Mountain24Item(7, "卯", "Mao", 90.0, "木", "震", "天元龙", -1),
            Mountain24Item(8, "乙", "Yi", 105.0, "木", "震", "人元龙", -1),
            Mountain24Item(9, "辰", "Chen", 120.0, "土", "巽", "地元龙", -1),
            Mountain24Item(10, "巽", "Xun", 135.0, "木", "巽", "天元龙", +1),
            Mountain24Item(11, "巳", "Si", 150.0, "火", "巽", "人元龙", +1),
            Mountain24Item(12, "丙", "Bing", 165.0, "火", "离", "地元龙", +1),
            Mountain24Item(13, "午", "Wu", 180.0, "火", "离", "天元龙", -1),
            Mountain24Item(14, "丁", "Ding", 195.0, "火", "离", "人元龙", -1),
            Mountain24Item(15, "未", "Wei", 210.0, "土", "坤", "地元龙", -1),
            Mountain24Item(16, "坤", "Kun", 225.0, "土", "坤", "天元龙", +1),
            Mountain24Item(17, "申", "Shen", 240.0, "金", "坤", "人元龙", +1),
            Mountain24Item(18, "庚", "Geng", 255.0, "金", "兑", "地元龙", +1),
            Mountain24Item(19, "酉", "You", 270.0, "金", "兑", "天元龙", -1),
            Mountain24Item(20, "辛", "Xin", 285.0, "金", "兑", "人元龙", -1),
            Mountain24Item(21, "戌", "Xu", 300.0, "土", "乾", "地元龙", -1),
            Mountain24Item(22, "乾", "Qian", 315.0, "金", "乾", "天元龙", +1),
            Mountain24Item(23, "亥", "Hai", 330.0, "水", "乾", "人元龙", +1)
        )

        fun mountain(angle: Double): Mountain24Item = resolveMountain(angle)
        fun find(angle: Double): Mountain24Item = resolveMountain(angle)
        fun find(name: String): Mountain24Item? = mountains.firstOrNull { it.name == name }

        fun resolveMountain(angle: Double): Mountain24Item {
            val norm = (angle % 360.0 + 360.0) % 360.0
            for (m in mountains) {
                val start = (m.angleCenter - 7.5 + 360.0) % 360.0
                val end = (m.angleCenter + 7.5) % 360.0
                if (start > end) {
                    if (norm >= start || norm < end) return m
                } else {
                    if (norm in start..end) return m
                }
            }
            return mountains[1]
        }

        fun resolveFenjin(angle: Double): FenjinItem {
            return Fenjin120Data.instance.resolveFenjin(angle)
        }
    }

    fun resolveHeadingState(heading: Double): CompassHeadingState {
        val norm = (heading % 360.0 + 360.0) % 360.0
        val sittingAngle = (norm + 180.0) % 360.0
        val facingM = resolveMountain(norm)
        val sittingM = resolveMountain(sittingAngle)

        var delta = abs(norm - facingM.angleCenter)
        if (delta > 180.0) delta = 360.0 - delta
        val isJian = delta > 3.0

        val fFenjin = resolveFenjin(norm)
        val sFenjin = resolveFenjin(sittingAngle)
        val lang = LocalizationManager.shared.effectiveLanguage
        val degStr = String.format(Locale.US, "%.1f°", delta)
        val fenJinDesc = when (lang) {
            AppLanguage.EN -> {
                val jianText = if (isJian) "Sub-alignment ($degStr)" else "Direct"
                "${fFenjin.localizedJiaziName} · ${sFenjin.localizedJiaziName} ($jianText)"
            }
            AppLanguage.ZH_HANT -> {
                val jianText = if (isJian) "兼向 (偏$degStr)" else "正向"
                "${fFenjin.localizedJiaziName}分金 · ${sFenjin.localizedJiaziName}分金 ($jianText)"
            }
            AppLanguage.JA -> {
                val jianText = if (isJian) "兼向 (偏$degStr)" else "正針"
                "${fFenjin.localizedJiaziName}分金・${sFenjin.localizedJiaziName}分金 ($jianText)"
            }
            AppLanguage.KO -> {
                val jianText = if (isJian) "겸향 (편$degStr)" else "정향"
                "${fFenjin.localizedJiaziName}분금 · ${sFenjin.localizedJiaziName}분금 ($jianText)"
            }
            AppLanguage.VI -> {
                val jianText = if (isJian) "Kiêm hướng (lệch $degStr)" else "Chính hướng"
                "Phân kim ${fFenjin.localizedJiaziName} · ${sFenjin.localizedJiaziName} ($jianText)"
            }
            AppLanguage.TH -> {
                val jianText = if (isJian) "เฉียง ($degStr)" else "ตรงทิศ"
                "เฟินจิน ${fFenjin.localizedJiaziName} · ${sFenjin.localizedJiaziName} ($jianText)"
            }
            AppLanguage.ID -> {
                val jianText = if (isJian) "Condong ($degStr)" else "Arah Lurus"
                "Fenjin ${fFenjin.localizedJiaziName} · ${sFenjin.localizedJiaziName} ($jianText)"
            }
            AppLanguage.AUTO, AppLanguage.ZH_HANS -> {
                val jianText = if (isJian) "兼向 (偏$degStr)" else "正向"
                "${fFenjin.jiaziName}分金 · ${sFenjin.jiaziName}分金 ($jianText)"
            }
        }

        return CompassHeadingState(
            heading = norm,
            trueHeading = norm,
            sittingAngle = sittingAngle,
            facingAngle = norm,
            facingMountain = facingM,
            sittingMountain = sittingM,
            facingFenjin = fFenjin,
            sittingFenjin = sFenjin,
            isJianXiang = isJian,
            jianXiangDegree = delta,
            fenJinDesc = fenJinDesc
        )
    }
}
