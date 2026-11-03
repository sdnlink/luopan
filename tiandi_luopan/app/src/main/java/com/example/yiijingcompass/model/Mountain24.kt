package com.example.yiijingcompass.model

import java.util.Locale

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

    val element: String
        get() = when (this) {
            NORTH -> "水"
            SOUTHWEST, NORTHEAST -> "土"
            EAST, SOUTHEAST -> "木"
            NORTHWEST, WEST -> "金"
            SOUTH -> "火"
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
    val localizedName: String get() = "${name}山"
    val angleStart: Double = (angleCenter - 7.5 + 360.0) % 360.0
    val angleEnd: Double = (angleCenter + 7.5) % 360.0
    val centerAngle: Double get() = angleCenter
    val startAngle: Double get() = angleStart
    val endAngle: Double get() = angleEnd

    val isCardinalOrCorner: Boolean
        get() = angleCenter % 45.0 == 0.0
}

/**
 * 百二十分金数据项
 */
data class FenjinItem(
    val mountainName: String,
    val index: Int,              // 1..5
    val jiaziName: String,       // 如 "丙子", "庚子"
    val startAngle: Double,
    val endAngle: Double,
    val centerAngle: Double,
    val grade: String,           // "旺相大吉", "孤虚差错", "龟甲空亡", "平稳"
    val isAuspicious: Boolean,
    val lore: String
)

/**
 * 空亡判定等级 (正针纯清、兼针替卦、小空亡、大空亡)
 */
enum class KongWangLevel(val title: String, val desc: String) {
    PURE("正向纯清", "磁针居中，气场纯清，最利立向消砂纳水。"),
    JIAN_XIANG("兼针兼向", "偏心超度，需依替卦排星，阴阳互用。"),
    SMALL_VOID("差错小空亡", "贴近山界交线，气场杂驳，进退两难。"),
    LARGE_VOID("出卦大空亡", "逼近八宫卦界缝，阴阳驳杂，为大凶之线。");

    val description: String get() = desc
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
    val kongWangLevel: KongWangLevel
        get() {
            val a = (facingAngle % 360.0 + 360.0) % 360.0
            val center = (facingMountain.centerAngle % 360.0 + 360.0) % 360.0
            var rawDelta = Math.abs(a - center)
            if (rawDelta > 180.0) rawDelta = 360.0 - rawDelta
            val delta = rawDelta

            if (delta >= 6.5) {
                var minGapToChuGua = 180.0
                for (k in 0 until 8) {
                    val line = 22.5 + 45.0 * k
                    var d = Math.abs(a - line)
                    if (d > 180.0) d = 360.0 - d
                    minGapToChuGua = Math.min(minGapToChuGua, d)
                }
                return if (minGapToChuGua <= 0.7) KongWangLevel.LARGE_VOID else KongWangLevel.SMALL_VOID
            } else if (delta >= 1.5) {
                return KongWangLevel.JIAN_XIANG
            }
            return KongWangLevel.PURE
        }
}

/**
 * 二十四山标准静态数据库
 */
object Mountain24Data {
    val instance: Mountain24Data = this

    val mountains: List<Mountain24Item> = listOf(
        Mountain24Item(0,  "壬", "Ren",  345.0, "水", "坎", "地元龙", +1),
        Mountain24Item(1,  "子", "Zi",   0.0,   "水", "坎", "天元龙", -1),
        Mountain24Item(2,  "癸", "Gui",  15.0,  "水", "坎", "人元龙", -1),
        Mountain24Item(3,  "丑", "Chou", 30.0,  "土", "艮", "地元龙", -1),
        Mountain24Item(4,  "艮", "Gen",  45.0,  "土", "艮", "天元龙", +1),
        Mountain24Item(5,  "寅", "Yin",  60.0,  "木", "艮", "人元龙", +1),
        Mountain24Item(6,  "甲", "Jia",  75.0,  "木", "震", "地元龙", +1),
        Mountain24Item(7,  "卯", "Mao",  90.0,  "木", "震", "天元龙", -1),
        Mountain24Item(8,  "乙", "Yi",   105.0, "木", "震", "人元龙", -1),
        Mountain24Item(9,  "辰", "Chen", 120.0, "土", "巽", "地元龙", -1),
        Mountain24Item(10, "巽", "Xun",  135.0, "木", "巽", "天元龙", +1),
        Mountain24Item(11, "巳", "Si",   150.0, "火", "巽", "人元龙", +1),
        Mountain24Item(12, "丙", "Bing", 165.0, "火", "离", "地元龙", +1),
        Mountain24Item(13, "午", "Wu",   180.0, "火", "离", "天元龙", -1),
        Mountain24Item(14, "丁", "Ding", 195.0, "火", "离", "人元龙", -1),
        Mountain24Item(15, "未", "Wei",  210.0, "土", "坤", "地元龙", -1),
        Mountain24Item(16, "坤", "Kun",  225.0, "土", "坤", "天元龙", +1),
        Mountain24Item(17, "申", "Shen", 240.0, "金", "坤", "人元龙", +1),
        Mountain24Item(18, "庚", "Geng", 255.0, "金", "兑", "地元龙", +1),
        Mountain24Item(19, "酉", "You",  270.0, "金", "兑", "天元龙", -1),
        Mountain24Item(20, "辛", "Xin",  285.0, "金", "兑", "人元龙", -1),
        Mountain24Item(21, "戌", "Xu",   300.0, "土", "乾", "地元龙", -1),
        Mountain24Item(22, "乾", "Qian", 315.0, "金", "乾", "天元龙", +1),
        Mountain24Item(23, "亥", "Hai",  330.0, "水", "乾", "人元龙", +1)
    )

    fun find(degree: Double): Mountain24Item {
        val norm = (degree % 360.0 + 360.0) % 360.0
        for (m in mountains) {
            val s = (m.angleCenter - 7.5 + 360.0) % 360.0
            val e = (m.angleCenter + 7.5) % 360.0
            if (s > e) {
                if (norm >= s || norm < e) return m
            } else {
                if (norm >= s && norm < e) return m
            }
        }
        return mountains[1] // 子山兜底
    }

    fun getOpposite(m: Mountain24Item): Mountain24Item {
        val oppAngle = (m.angleCenter + 180.0) % 360.0
        return find(oppAngle)
    }

    fun resolveFenjin(degree: Double): FenjinItem {
        val norm = (degree % 360.0 + 360.0) % 360.0
        val m = find(norm)
        val s = (m.angleCenter - 7.5 + 360.0) % 360.0
        var diff = norm - s
        if (diff < 0) diff += 360.0
        val subIndex = Math.min(4, Math.max(0, (diff / 3.0).toInt()))
        val stems = listOf("甲", "丙", "戊", "庚", "壬")
        val stem = stems[subIndex]
        val (grade, isAuspicious, lore) = when (subIndex) {
            1 -> Triple("旺相大吉", true, "正针阳火得令，招财进宝，富贵长久。")
            3 -> Triple("旺相大吉", true, "阳金生旺，武贵显达，威权四海。")
            2 -> Triple("龟甲空亡", false, "戊己土煞龟甲空亡，冷退损丁，横祸官非。")
            else -> Triple("孤虚差错", false, "孤虚煞气，财源破散，气场杂驳。")
        }
        val fenjinStart = (s + subIndex * 3.0) % 360.0
        val fenjinEnd = (fenjinStart + 3.0) % 360.0
        val fenjinCenter = (fenjinStart + 1.5) % 360.0
        return FenjinItem(
            mountainName = m.localizedName,
            index = subIndex + 1,
            jiaziName = "${stem}${m.name}",
            startAngle = fenjinStart,
            endAngle = fenjinEnd,
            centerAngle = fenjinCenter,
            grade = grade,
            isAuspicious = isAuspicious,
            lore = lore
        )
    }

    fun resolveHeadingState(heading: Double): CompassHeadingState {
        val normHeading = (heading % 360.0 + 360.0) % 360.0
        val facingM = find(normHeading)
        val sittingM = getOpposite(facingM)
        val sittingAngle = (normHeading + 180.0) % 360.0

        val facingFj = resolveFenjin(normHeading)
        val sittingFj = resolveFenjin(sittingAngle)

        val centerDelta = Math.abs(normHeading - facingM.centerAngle)
        val isJian = centerDelta >= 1.5

        return CompassHeadingState(
            heading = normHeading,
            trueHeading = normHeading,
            sittingAngle = sittingAngle,
            facingAngle = normHeading,
            facingMountain = facingM,
            sittingMountain = sittingM,
            facingFenjin = facingFj,
            sittingFenjin = sittingFj,
            isJianXiang = isJian,
            jianXiangDegree = centerDelta,
            fenJinDesc = facingFj.jiaziName + "分金 · " + facingFj.grade
        )
    }
}
