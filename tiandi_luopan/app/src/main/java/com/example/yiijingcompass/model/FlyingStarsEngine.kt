package com.example.yiijingcompass.model

import java.util.Calendar
import java.util.Date

data class PeriodMeta(
    val period: Int,
    val yuan: String,
    val trigram: String,
    val starName: String,
    val element: String,
    val startYear: Int,
    val endYear: Int,
    val isCurrent: Boolean,
    val label: String
)

data class PalaceCell(
    val id: Int, // 0..8 (0:坎, 1:坤, 2:震, 3:巽, 4:中, 5:乾, 6:兑, 7:艮, 8:离)
    val palaceName: String,
    val trigram: String,
    val direction: String,
    val periodStar: Int,
    val activePeriod: Int,
    val mountainStar: Int,
    val facingStar: Int,
    val isCenter: Boolean,
    val isWangMountain: Boolean,
    val isWangFacing: Boolean,
    val isShaWuHuang: Boolean,
    val isShaErHei: Boolean
) {
    val sittingStar: Int get() = mountainStar
    val guaName: String get() = trigram
    val element: String
        get() = when (id) {
            0 -> "水"
            1, 4, 7 -> "土"
            2, 3 -> "木"
            5, 6 -> "金"
            8 -> "火"
            else -> "土"
        }

    val hasEarthSha: Boolean get() = isShaWuHuang || isShaErHei

    val baseEvaluation: String
        get() {
            if (hasEarthSha) return "五黄／二黑土煞 · 宜静安金属化解"
            if (mountainStar == activePeriod && facingStar == activePeriod) return "当运双星会聚 · 财丁两旺"
            if (facingStar == activePeriod) return "当旺财星照临 · 宜开门纳气"
            if (mountainStar == activePeriod) return "当运丁星归位 · 人丁兴旺"
            if ((mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1)) return "一六共宗 · 水清木秀催文昌"
            return "吉凶相参 · 平和之位"
        }
}

data class XuanKongChart(
    val period: Int,
    val sittingMountain: String,
    val facingMountain: String,
    val patternType: String,
    val isSanBanGua: Boolean,
    val isQiXingDaJie: Boolean,
    val isTiGua: Boolean,
    val chartModeTitle: String,
    val palaces: List<PalaceCell>,
    val summaryAnalysis: String,
    val periodMeta: PeriodMeta
)

class FlyingStarsEngine private constructor() {
    companion object {
        val instance: FlyingStarsEngine by lazy { FlyingStarsEngine() }

        private val tiGuaStarMap: Map<String, Int> = mapOf(
            "子" to 1, "癸" to 1, "甲" to 1, "申" to 1,
            "壬" to 2, "卯" to 2, "乙" to 2, "未" to 2, "坤" to 2,
            "乾" to 6, "戌" to 6, "辰" to 6, "巽" to 6, "巳" to 6, "亥" to 6,
            "艮" to 7, "丙" to 7, "酉" to 7, "辛" to 7, "丑" to 7,
            "寅" to 9, "午" to 9, "庚" to 9, "丁" to 9
        )
    }

    private val luoShuOrder = intArrayOf(4, 5, 6, 7, 8, 0, 1, 2, 3)
    private val palaceNames = arrayOf("坎一宫 (正北)", "坤二宫 (西南)", "震三宫 (正东)", "巽四宫 (东南)", "天心五 (中宫)", "乾六宫 (西北)", "兑七宫 (正西)", "艮八宫 (东北)", "离九宫 (正南)")
    private val palaceTrigrams = arrayOf("坎", "坤", "震", "巽", "中", "乾", "兑", "艮", "离")
    private val palaceDirections = arrayOf("正北", "西南", "正东", "东南", "中宫", "西北", "正西", "东北", "正南")

    fun currentPeriod(date: Date = Date()): Int {
        val offset = effectiveSolarYear(date) - 1864
        val cycleYear = (offset % 180 + 180) % 180
        return (cycleYear / 20) + 1
    }

    fun periodMeta(period: Int, date: Date = Date()): PeriodMeta {
        val year = effectiveSolarYear(date)
        val curPeriod = currentPeriod(date)
        val p = period.coerceIn(1, 9)
        val offset = year - 1864
        val currentCycleStart = 1864 + if (offset >= 0) (offset / 180) * 180 else ((offset - 179) / 180) * 180
        val startY = currentCycleStart + (p - 1) * 20
        val endY = startY + 19

        val yuans = arrayOf("", "上元", "上元", "上元", "中元", "中元", "中元", "下元", "下元", "下元")
        val trigrams = arrayOf("", "坎", "坤", "震", "巽", "中", "乾", "兑", "艮", "离")
        val stars = arrayOf("", "一白贪狼", "二黑巨门", "三碧禄存", "四绿文曲", "五黄廉贞", "六白武曲", "七赤破军", "八白左辅", "九紫右弼")
        val elements = arrayOf("", "水", "土", "木", "木", "土", "金", "金", "土", "火")

        val yuan = yuans[p]
        val trigram = trigrams[p]
        val starName = stars[p]
        val element = elements[p]
        val isCur = (p == curPeriod)
        val label = if (isCur) "当前${yuan}${p}运（${startY}—${endY}年，${starName}${element}星当令）" else "${yuan}${p}运（${startY}—${endY}年，${starName}${element}星当令）"

        return PeriodMeta(
            period = p,
            yuan = yuan,
            trigram = trigram,
            starName = starName,
            element = element,
            startYear = startY,
            endYear = endY,
            isCurrent = isCur,
            label = label
        )
    }

    private fun effectiveSolarYear(date: Date): Int {
        val cal = Calendar.getInstance()
        cal.time = date
        val year = cal.get(Calendar.YEAR)
        val beforeLiChun = SolarTimeCalculator.instance.isBeforeLiChun(date)
        return if (beforeLiChun) year - 1 else year
    }

    private fun resolveStarAndPolarity(
        periodStarInPalace: Int,
        baseMountain: Mountain24Item,
        useTiGua: Boolean
    ): Pair<Int, Boolean> {
        if (periodStarInPalace == 5) {
            val subStar = if (useTiGua) (tiGuaStarMap[baseMountain.name] ?: 5) else 5
            return Pair(subStar, baseMountain.polarity > 0)
        }
        val palaceNameByStar = mapOf(
            1 to "坎", 2 to "坤", 3 to "震", 4 to "巽",
            6 to "乾", 7 to "兑", 8 to "艮", 9 to "离"
        )
        val homePalace = palaceNameByStar[periodStarInPalace] ?: return Pair(periodStarInPalace, baseMountain.polarity > 0)
        val homeMountains = Mountain24Data.instance.mountains.filter { it.palace == homePalace }
        val matched = homeMountains.firstOrNull { it.yuan == baseMountain.yuan } ?: return Pair(periodStarInPalace, baseMountain.polarity > 0)
        val star = if (useTiGua) (tiGuaStarMap[matched.name] ?: periodStarInPalace) else periodStarInPalace
        val isForward = matched.polarity > 0
        return Pair(star, isForward)
    }

    fun calculateChart(
        period: Int? = null,
        sitting: Mountain24Item,
        facing: Mountain24Item,
        useTiGua: Boolean = false,
        date: Date = Date()
    ): XuanKongChart {
        val activePeriod = period ?: currentPeriod(date)
        val meta = periodMeta(activePeriod, date)

        val basePeriod = IntArray(9)
        basePeriod[4] = activePeriod
        for (step in 1..8) {
            val nextPalace = luoShuOrder[step]
            var star = (activePeriod + step) % 9
            if (star == 0) star = 9
            basePeriod[nextPalace] = star
        }

        val sittingPalaceIdx = palaceIndex(sitting.palace)
        val facingPalaceIdx = palaceIndex(facing.palace)
        val sittingPeriodStar = basePeriod[sittingPalaceIdx]
        val facingPeriodStar = basePeriod[facingPalaceIdx]

        val sittingResult = resolveStarAndPolarity(sittingPeriodStar, sitting, useTiGua)
        val facingResult = resolveStarAndPolarity(facingPeriodStar, facing, useTiGua)

        val sittingInCentral = sittingResult.first
        val sittingIsForward = sittingResult.second
        val facingInCentral = facingResult.first
        val facingIsForward = facingResult.second

        val mountainStars = IntArray(9)
        val facingStars = IntArray(9)
        mountainStars[4] = sittingInCentral
        facingStars[4] = facingInCentral

        for (step in 1..8) {
            val pIdx = luoShuOrder[step]
            var mStar = if (sittingIsForward) (sittingInCentral + step) % 9 else (sittingInCentral - step + 9) % 9
            if (mStar <= 0) mStar += 9
            mountainStars[pIdx] = mStar

            var fStar = if (facingIsForward) (facingInCentral + step) % 9 else (facingInCentral - step + 9) % 9
            if (fStar <= 0) fStar += 9
            facingStars[pIdx] = fStar
        }

        val sittingFacingIdx = facingPalaceIdx
        val sittingMountIdx = sittingPalaceIdx
        val facingStarAtFacing = facingStars[sittingFacingIdx]
        val mountainStarAtMount = mountainStars[sittingMountIdx]
        val mountainStarAtFacing = mountainStars[sittingFacingIdx]
        val facingStarAtMount = facingStars[sittingMountIdx]

        val pattern = when {
            facingStarAtFacing == activePeriod && mountainStarAtMount == activePeriod ->
                "到山到向 (旺丁旺财最吉)"
            facingStarAtFacing == activePeriod && mountainStarAtFacing == activePeriod ->
                "双星到向 (旺财不旺丁 · 宜向前有水后有山)"
            facingStarAtMount == activePeriod && mountainStarAtMount == activePeriod ->
                "双星到坐 (旺丁不旺财 · 宜向后有水水后有山)"
            facingStarAtMount == activePeriod && mountainStarAtFacing == activePeriod ->
                "上山下水 (败财损丁凶局 · 需借势颠倒用法)"
            else ->
                "吉凶平和局"
        }

        val cells = mutableListOf<PalaceCell>()
        for (i in 0 until 9) {
            val isWangM = mountainStars[i] == activePeriod
            val isWangF = facingStars[i] == activePeriod
            val isWuHuang = mountainStars[i] == 5 || facingStars[i] == 5
            val isErHei = mountainStars[i] == 2 || facingStars[i] == 2

            cells.add(
                PalaceCell(
                    id = i,
                    palaceName = palaceNames[i],
                    trigram = palaceTrigrams[i],
                    direction = palaceDirections[i],
                    periodStar = basePeriod[i],
                    activePeriod = activePeriod,
                    mountainStar = mountainStars[i],
                    facingStar = facingStars[i],
                    isCenter = i == 4,
                    isWangMountain = isWangM,
                    isWangFacing = isWangF,
                    isShaWuHuang = isWuHuang,
                    isShaErHei = isErHei
                )
            )
        }

        val sittingName = sitting.localizedName
        val facingName = facing.localizedName
        val summary = "玄空排盘：${meta.yuan}${activePeriod}运（${meta.startYear}—${meta.endYear}年，${meta.starName}${meta.element}星当令）。${sittingName}山${facingName}向在此元运呈现【$pattern】。宜重点布局向首明堂引纳${meta.element}气，坐后稳实以固人丁。"
        val modeTitle = if (useTiGua) "兼向替卦" else "正向下卦"

        return XuanKongChart(
            period = activePeriod,
            sittingMountain = sittingName,
            facingMountain = facingName,
            patternType = pattern,
            isSanBanGua = checkSanBanGua(cells),
            isQiXingDaJie = checkQiXingDaJie(cells, activePeriod, sittingFacingIdx),
            isTiGua = useTiGua,
            chartModeTitle = modeTitle,
            palaces = cells,
            summaryAnalysis = summary,
            periodMeta = meta
        )
    }

    private fun palaceIndex(palaceName: String): Int {
        return when (palaceName) {
            "坎" -> 0
            "坤" -> 1
            "震" -> 2
            "巽" -> 3
            "乾" -> 5
            "兑" -> 6
            "艮" -> 7
            "离" -> 8
            else -> 4
        }
    }

    private fun checkSanBanGua(cells: List<PalaceCell>): Boolean {
        val fumuSets = listOf(setOf(1, 4, 7), setOf(2, 5, 8), setOf(3, 6, 9))
        val lianzhuSets = listOf(
            setOf(1, 2, 3), setOf(2, 3, 4), setOf(3, 4, 5),
            setOf(4, 5, 6), setOf(5, 6, 7), setOf(6, 7, 8),
            setOf(7, 8, 9), setOf(8, 9, 1), setOf(9, 1, 2)
        )
        val allFumu = cells.all { c -> fumuSets.contains(setOf(c.periodStar, c.mountainStar, c.facingStar)) }
        if (allFumu) return true
        return cells.all { c -> lianzhuSets.contains(setOf(c.periodStar, c.mountainStar, c.facingStar)) }
    }

    private fun checkQiXingDaJie(cells: List<PalaceCell>, activePeriod: Int, facingPalaceIdx: Int): Boolean {
        if (cells.size != 9 || cells[facingPalaceIdx].facingStar != activePeriod) return false
        val fumuSets = listOf(setOf(1, 4, 7), setOf(2, 5, 8), setOf(3, 6, 9))
        val zhenQiSet = setOf(cells[8].facingStar, cells[2].facingStar, cells[5].facingStar)
        val jiaQiSet = setOf(cells[0].facingStar, cells[6].facingStar, cells[3].facingStar)
        return fumuSets.contains(zhenQiSet) || fumuSets.contains(jiaQiSet)
    }
}

