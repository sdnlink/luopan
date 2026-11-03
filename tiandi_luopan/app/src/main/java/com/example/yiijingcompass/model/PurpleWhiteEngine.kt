package com.example.yiijingcompass.model

import java.util.Calendar
import java.util.Date

data class PurpleWhitePalaceItem(
    val palaceId: Int,        // 洛书宫号 1..9
    val palaceName: String,    // "东南 巽"
    val direction: String,     // "东南"
    val originalStar: Int,     // 原旦盘/洛书本宫星
    val yearGuestStar: Int,    // 流年飞临客星 (1..9)
    val monthGuestStar: Int,   // 流月飞临客星 (1..9)
    val starName: String,      // 如 "五黄廉贞星"
    val isDanger25: Boolean,   // 是否犯二五交加 / 五黄二黑大煞
    val isTaiSui: Boolean,     // 是否为太岁方
    val isSuiPo: Boolean,      // 是否为岁破方
    val isSanSha: Boolean,     // 是否为三煞方
    val advice: String         // 化解与催旺指南
) {
    val id: Int get() = palaceId
}

data class PurpleWhiteChart(
    val year: Int,
    val month: Int,
    val yearCentralStar: Int,
    val monthCentralStar: Int,
    val currentFacingPalace: Int,
    val taiSuiDescription: String,
    val suiPoDescription: String,
    val sanShaDescription: String,
    val palaceItems: List<PurpleWhitePalaceItem>
)

class PurpleWhiteEngine private constructor() {
    companion object {
        val instance: PurpleWhiteEngine by lazy { PurpleWhiteEngine() }
    }

    private val luoshuOrder = intArrayOf(5, 6, 7, 8, 9, 1, 2, 3, 4)
    val displayPalaceOrder = intArrayOf(4, 9, 2, 3, 5, 7, 8, 1, 6)

    fun starName(star: Int): String {
        if (star !in 1..9) return ""
        val names = arrayOf(
            "", "一白贪狼水星", "二黑巨门土星(病符)", "三碧禄存木星", "四绿文曲木星",
            "五黄廉贞土星(大煞)", "六白武曲金星", "七赤破军金星", "八白左辅土星", "九紫右弼火星"
        )
        return names[star]
    }

    fun palaceDirection(palaceId: Int): String {
        val dirs = mapOf(1 to "正北", 2 to "西南", 3 to "正东", 4 to "东南", 5 to "中宫", 6 to "西北", 7 to "正西", 8 to "东北", 9 to "正南")
        return dirs[palaceId] ?: "中宫"
    }

    fun palaceFullName(palaceId: Int): String {
        val full = mapOf(1 to "正北 坎宫", 2 to "西南 坤宫", 3 to "正东 震宫", 4 to "东南 巽宫", 5 to "中央 太极", 6 to "西北 乾宫", 7 to "正西 兑宫", 8 to "东北 艮宫", 9 to "正南 离宫")
        return full[palaceId] ?: "中央 太极"
    }

    fun calcYearStar(year: Int): Int {
        var num = (11 - (year % 9)) % 9
        if (num <= 0) num += 9
        return num
    }

    fun calcMonthStar(year: Int, month: Int): Int {
        val branchIndex = ((year - 4) % 12 + 12) % 12
        val baseStar = when {
            branchIndex in listOf(0, 3, 6, 9) -> 8
            branchIndex in listOf(1, 4, 7, 10) -> 5
            else -> 2
        }
        var mStar = (baseStar - (month - 1)) % 9
        if (mStar <= 0) mStar += 9
        return mStar
    }

    fun flyStars(centralStar: Int): Map<Int, Int> {
        val result = mutableMapOf<Int, Int>()
        for ((step, targetPalace) in luoshuOrder.withIndex()) {
            var s = (centralStar + step) % 9
            if (s <= 0) s += 9
            result[targetPalace] = s
        }
        return result
    }

    fun calculateChart(date: Date = Date(), heading: Double = 0.0): PurpleWhiteChart {
        val cal = Calendar.getInstance()
        cal.time = date
        val rawYear = cal.get(Calendar.YEAR)
        val rawMonth = cal.get(Calendar.MONTH) + 1
        val solarTermIndex = SolarTimeCalculator.instance.solarTermIndex(date)

        val isBeforeLichun = SolarTimeCalculator.instance.isBeforeLiChun(date)
        val effectiveYear = if (isBeforeLichun) rawYear - 1 else rawYear

        val effectiveMonth = if (rawMonth == 1) 1 else if (solarTermIndex < 2) maxOf(1, rawMonth - 1) else minOf(12, 2 + (solarTermIndex - 2) / 2)
        val solarMonthForStar = if (solarTermIndex < 2) 12 else minOf(11, 1 + (solarTermIndex - 2) / 2)

        val yCenter = calcYearStar(effectiveYear)
        val mCenter = calcMonthStar(effectiveYear, solarMonthForStar)

        val yearStarsMap = flyStars(yCenter)
        val monthStarsMap = flyStars(mCenter)

        val zhiIndex = ((effectiveYear - 4) % 12 + 12) % 12
        val baseConfigs = mapOf(
            0 to Triple(1, 9, listOf(9)), 1 to Triple(8, 2, listOf(3)), 2 to Triple(8, 2, listOf(1)),
            3 to Triple(3, 7, listOf(7)), 4 to Triple(4, 6, listOf(9)), 5 to Triple(4, 6, listOf(3)),
            6 to Triple(9, 1, listOf(1)), 7 to Triple(2, 8, listOf(7)), 8 to Triple(2, 8, listOf(9)),
            9 to Triple(7, 3, listOf(3)), 10 to Triple(6, 4, listOf(1)), 11 to Triple(6, 4, listOf(7))
        )
        val baseConf = baseConfigs[zhiIndex] ?: Triple(9, 1, listOf(1))
        val taiSuiPalace = baseConf.first
        val suiPoPalace = baseConf.second
        val sanShaPalaces = baseConf.third

        val branches = listOf("子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥")
        val taiSuiDesc = "太岁临${palaceDirection(taiSuiPalace)}${branches[zhiIndex]}方，宜静不宜动土"
        val suiPoDesc = "岁破在${palaceDirection(suiPoPalace)}${branches[(zhiIndex + 6) % 12]}方，冲动有损"
        val sanShaDesc = "三煞在${palaceDirection(sanShaPalaces[0])}方，切忌修造破土"

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

        val items = mutableListOf<PurpleWhitePalaceItem>()
        for (pId in 1..9) {
            val yStar = yearStarsMap[pId] ?: 5
            val mStar = monthStarsMap[pId] ?: 5
            val is25 = (yStar == 5 || yStar == 2) || (mStar == 5 || mStar == 2)
            val isTs = (pId == taiSuiPalace)
            val isSp = (pId == suiPoPalace)
            val isSs = sanShaPalaces.contains(pId)

            val advice = when {
                yStar == 5 -> "五黄大煞飞临，宜安放铜制六帝钱化解，忌动土与红色物品"
                yStar == 2 -> "二黑病符星飞临，注意健康脾胃，宜悬挂铜葫芦化解"
                yStar == 9 -> "九紫喜庆吉星飞临，宜摆放红绿绿植或长明灯催旺姻缘贵人"
                yStar == 1 -> "一白贪狼吉星照临，催旺文昌桃花，宜置文昌塔或水生植物"
                yStar == 8 -> "八白正财吉星坐镇，利田宅财富，宜摆放黄水晶聚宝盆"
                yStar == 6 -> "六白武曲偏财星临，利权威升迁与武职偏财"
                yStar == 4 -> "四绿文昌木星到位，利学业考运，宜置四支文竹或毛笔"
                yStar == 7 -> "七赤破军贼星临门，防口舌是非盗贼，宜用水化解金气"
                else -> "三碧禄存争斗星临，注意口舌官非，宜置红地毯化木生火"
            }

            items.add(
                PurpleWhitePalaceItem(
                    palaceId = pId,
                    palaceName = palaceFullName(pId),
                    direction = palaceDirection(pId),
                    originalStar = pId,
                    yearGuestStar = yStar,
                    monthGuestStar = mStar,
                    starName = starName(yStar),
                    isDanger25 = is25,
                    isTaiSui = isTs,
                    isSuiPo = isSp,
                    isSanSha = isSs,
                    advice = advice
                )
            )
        }

        return PurpleWhiteChart(
            year = effectiveYear,
            month = effectiveMonth,
            yearCentralStar = yCenter,
            monthCentralStar = mCenter,
            currentFacingPalace = currentFacingPalace,
            taiSuiDescription = taiSuiDesc,
            suiPoDescription = suiPoDesc,
            sanShaDescription = sanShaDesc,
            palaceItems = items
        )
    }
}

