package com.example.yiijingcompass.model

import java.util.Calendar
import java.util.Date

data class QimenDoor(
    val name: String,
    val palace: Int,
    val isAuspicious: Boolean,
    val luckType: String, // "吉", "大吉", "平", "凶", "大凶"
    val lore: String
)

data class QimenPalaceCell(
    val id: Int,
    val palaceName: String,
    val direction: String,
    val angleCenter: Double,
    val doorName: String,
    val starName: String,
    val godName: String,
    val tianPanGan: String,
    val diPanGan: String,
    val isAuspicious: Boolean,
    val luckType: String,
    val isCenter: Boolean,
    val isFacingDirection: Boolean
)

data class QimenChart(
    val title: String,
    val dunType: String,
    val juNumber: Int,
    val shichen: String,
    val bestDirection: String,
    val bestBearing: Double?,
    val bestReason: String,
    val worstDirection: String,
    val worstBearing: Double?,
    val worstReason: String,
    val cells: List<QimenPalaceCell>
)

class QimenEngine private constructor() {
    companion object {
        val instance: QimenEngine by lazy { QimenEngine() }
    }

    private val nineStars = listOf("天蓬", "天芮", "天冲", "天辅", "天禽", "天心", "天柱", "天任", "天英")
    private val sixYiStems = listOf("戊", "己", "庚", "辛", "壬", "癸", "丁", "丙", "乙")
    private val luoShuFull = listOf(1, 2, 3, 4, 5, 6, 7, 8, 9)
    private val luoShuSkip = listOf(1, 8, 3, 4, 9, 2, 7, 6)

    private val eightDoors = listOf(
        QimenDoor("休门", 1, true, "大吉", "求名休闲大吉，水清木秀"),
        QimenDoor("生门", 8, true, "大吉", "求财置业大吉，土旺金生"),
        QimenDoor("伤门", 3, false, "凶", "讨债索敌宜，出行防伤灾"),
        QimenDoor("杜门", 4, false, "平", "潜伏隐匿避灾，闭藏门户"),
        QimenDoor("景门", 9, true, "吉", "文书考试宴请吉，火炎防急"),
        QimenDoor("死门", 2, false, "大凶", "吊丧刑戮宜，出行造葬大凶"),
        QimenDoor("惊门", 7, false, "凶", "捕盗争讼宜，常人动则招惊"),
        QimenDoor("开门", 6, true, "大吉", "开业远行见贵大吉，通达显赫")
    )

    private val displayPalaceDefs = listOf(
        Triple(4, "东南 巽宫", 135.0),
        Triple(9, "正南 离宫", 180.0),
        Triple(2, "西南 坤宫", 225.0),
        Triple(3, "正东 震宫", 90.0),
        Triple(5, "中央 太极", 0.0),
        Triple(7, "正西 兑宫", 270.0),
        Triple(8, "东北 艮宫", 45.0),
        Triple(1, "正北 坎宫", 0.0),
        Triple(6, "西北 乾宫", 315.0)
    )

    private fun flightFull(from: Int, forward: Boolean): List<Int> {
        val startIdx = luoShuFull.indexOf(from).let { if (it >= 0) it else 0 }
        val result = mutableListOf<Int>()
        for (i in 0 until 9) {
            val idx = if (forward) (startIdx + i) % 9 else (startIdx - i + 9) % 9
            result.add(luoShuFull[idx])
        }
        return result
    }

    private fun flightSkip(from: Int, forward: Boolean): List<Int> {
        val startIdx = luoShuSkip.indexOf(from).let { if (it >= 0) it else 0 }
        val result = mutableListOf<Int>()
        for (i in 0 until 8) {
            val idx = if (forward) (startIdx + i) % 8 else (startIdx - i + 8) % 8
            result.add(luoShuSkip[idx])
        }
        return result
    }

    private fun flySkip(start: Int, steps: Int, forward: Boolean): Int {
        val idx = luoShuSkip.indexOf(start).let { if (it >= 0) it else 0 }
        val targetIdx = if (forward) (idx + steps) % 8 else (idx - steps % 8 + 8) % 8
        return luoShuSkip[targetIdx]
    }

    private fun dayGanZhiIndex(date: Date): Int {
        val cal = Calendar.getInstance()
        cal.time = date
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        val a = (14 - m) / 12
        val yy = y + 4800 - a
        val mm = m + 12 * a - 3
        val jdn = d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045
        return ((jdn + 49) % 60 + 60) % 60
    }

    fun calculateChart(date: Date = Date(), heading: Double = 0.0): QimenChart {
        val cal = Calendar.getInstance()
        cal.time = date
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val solarTermIndex = SolarTimeCalculator.instance.solarTermIndex(date)

        val isYangDun = solarTermIndex < 11 || solarTermIndex >= 23
        val forward = isYangDun
        val dunType = if (isYangDun) "阳遁" else "阴遁"

        val dayGz = dayGanZhiIndex(date)
        val fuHead = dayGz - (dayGz % 5)
        val yuanIndex = when (fuHead % 15) {
            0 -> 0
            5 -> 2
            10 -> 1
            else -> 0
        }

        val yangBureaus = mapOf(
            23 to listOf(1, 7, 4), 0 to listOf(2, 8, 5), 1 to listOf(3, 9, 6),
            2 to listOf(8, 5, 2), 3 to listOf(9, 6, 3), 4 to listOf(1, 7, 4),
            5 to listOf(3, 9, 6), 6 to listOf(4, 1, 7), 7 to listOf(5, 2, 8),
            8 to listOf(4, 1, 7), 9 to listOf(5, 2, 8), 10 to listOf(6, 3, 9)
        )
        val yinBureaus = mapOf(
            11 to listOf(9, 3, 6), 12 to listOf(8, 2, 5), 13 to listOf(7, 1, 4),
            14 to listOf(2, 5, 8), 15 to listOf(1, 4, 7), 16 to listOf(9, 3, 6),
            17 to listOf(7, 1, 4), 18 to listOf(6, 9, 3), 19 to listOf(5, 8, 2),
            20 to listOf(5, 8, 2), 21 to listOf(4, 7, 1), 22 to listOf(3, 6, 9)
        )
        val bureauTable = if (isYangDun) yangBureaus else yinBureaus
        val juNumber = bureauTable[solarTermIndex]?.get(yuanIndex) ?: 1
        val yuanName = listOf("上元", "中元", "下元")[yuanIndex]
        val title = "【${dunType}${juNumber}局 · 拆补${yuanName}】"

        val dayRef = Date(date.time + 3600000L)
        val effDayGz = dayGanZhiIndex(dayRef)
        val dayStem = effDayGz % 10
        val hourBranch = ((hour + 1) / 2) % 12
        val hourStem = ((dayStem % 5) * 2 + hourBranch) % 10
        val stems = listOf("甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸")
        val branches = listOf("子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥")
        val hourStemChar = stems[hourStem]
        val shichenStr = "${hourStemChar}${branches[hourBranch]}时"

        val shichenGz = ((effDayGz * 12 + hourBranch) % 60 + 60) % 60
        val xun = shichenGz / 10

        val diPanStem = mutableMapOf<Int, String>()
        val diPlacement = flightFull(juNumber, forward)
        for ((i, palace) in diPlacement.withIndex()) {
            diPanStem[palace] = sixYiStems[i]
        }
        val stemToPalace = diPanStem.entries.associate { (k, v) -> v to k }
        val xunToSixYi = listOf("戊", "己", "庚", "辛", "壬", "癸")
        val xunHeadSixYi = xunToSixYi[xun]
        val zhiFuPalace = stemToPalace[xunHeadSixYi] ?: (diPlacement.firstOrNull() ?: 1)

        val doorPalaceToName = mapOf(1 to "休门", 2 to "死门", 3 to "伤门", 4 to "杜门", 9 to "景门", 8 to "生门", 7 to "惊门", 6 to "开门")
        val doorInfo = eightDoors.associate { it.name to Pair(it.luckType, it.isAuspicious) }

        val zhiFuStarStart = if (hourStemChar == "甲") zhiFuPalace else (stemToPalace[hourStemChar] ?: zhiFuPalace)
        val stepsIntoXun = shichenGz % 10
        val zhiShiStart = flySkip(zhiFuPalace, stepsIntoXun, forward)

        val starOrigin = flightFull(zhiFuPalace, forward)
        val starDest = flightFull(zhiFuStarStart, forward)
        val tianStar = mutableMapOf<Int, String>()
        val tianStem = mutableMapOf<Int, String>()
        for (k in 0 until 9) {
            val dest = starDest[k]
            val origin = starOrigin[k]
            tianStar[dest] = nineStars[origin - 1]
            tianStem[dest] = diPanStem[origin] ?: "戊"
        }

        val doorOrigin = flightSkip(zhiFuPalace, forward)
        val doorDest = flightSkip(zhiShiStart, forward)
        val tianDoor = mutableMapOf<Int, String>()
        for (k in 0 until 8) {
            tianDoor[doorDest[k]] = doorPalaceToName[doorOrigin[k]] ?: "休门"
        }

        val godOrder = if (isYangDun)
            listOf("值符", "螣蛇", "太阴", "六合", "白虎", "玄武", "九地", "九天")
        else
            listOf("值符", "螣蛇", "太阴", "六合", "玄武", "白虎", "九地", "九天")
        val godDest = flightSkip(zhiFuStarStart, forward)
        val tianGod = mutableMapOf<Int, String>()
        for (k in 0 until 8) {
            tianGod[godDest[k]] = godOrder[k]
        }

        val normHeading = (heading % 360.0 + 360.0) % 360.0
        val currentFacingPalace = when (normHeading) {
            in 22.5..67.5 -> 8
            in 67.5..112.5 -> 3
            in 112.5..157.5 -> 4
            in 157.5..202.5 -> 9
            in 202.5..247.5 -> 2
            in 247.5..292.5 -> 7
            in 292.5..337.5 -> 6
            else -> 1
        }

        val cells = mutableListOf<QimenPalaceCell>()
        for (def in displayPalaceDefs) {
            val p = def.first
            val name = def.second
            val angle = def.third
            val isCenter = (p == 5)
            val isFacing = (p == currentFacingPalace)

            val door = if (isCenter) "中宫" else (tianDoor[p] ?: "休门")
            val star = if (isCenter) (tianStar[5] ?: "天禽") else (tianStar[p] ?: nineStars[p - 1])
            val god = if (isCenter) "元极" else (tianGod[p] ?: "元极")
            val tian = tianStem[p] ?: "戊"
            val di = diPanStem[p] ?: "戊"

            val info = doorInfo[door] ?: Pair("平", false)
            val luck = if (isCenter) "平" else info.first
            val ausp = if (isCenter) false else info.second

            cells.add(
                QimenPalaceCell(
                    id = p,
                    palaceName = name,
                    direction = name.substringBefore(" "),
                    angleCenter = angle,
                    doorName = door,
                    starName = star,
                    godName = god,
                    tianPanGan = tian,
                    diPanGan = di,
                    isAuspicious = ausp,
                    luckType = luck,
                    isCenter = isCenter,
                    isFacingDirection = isFacing
                )
            )
        }

        val bestPalace = cells.filter { !it.isCenter && it.isAuspicious }.maxByOrNull {
            if (it.luckType == "大吉") 3 else if (it.luckType == "吉") 2 else 1
        } ?: cells.first { !it.isCenter }

        val worstPalace = cells.filter { !it.isCenter && !it.isAuspicious }.minByOrNull {
            if (it.luckType == "大凶") 0 else if (it.luckType == "凶") 1 else 2
        } ?: cells.last { !it.isCenter }

        return QimenChart(
            title = title,
            dunType = dunType,
            juNumber = juNumber,
            shichen = shichenStr,
            bestDirection = "${bestPalace.direction} (${bestPalace.doorName})",
            bestBearing = bestPalace.angleCenter,
            bestReason = "三吉门生旺之方，利于开拓洽商、求财出行",
            worstDirection = "${worstPalace.direction} (${worstPalace.doorName})",
            worstBearing = worstPalace.angleCenter,
            worstReason = "落入凶门闭塞，不利远行修造，宜静守避忌",
            cells = cells
        )
    }
}

