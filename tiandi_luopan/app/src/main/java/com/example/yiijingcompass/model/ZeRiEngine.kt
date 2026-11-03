package com.example.yiijingcompass.model

import java.util.Calendar
import java.util.Date

data class ZeRiAnalysis(
    val fourPillarsText: String,
    val overallStatus: String,
    val isAuspicious: Boolean,
    val suiPoWarning: String?,
    val yuePoWarning: String?,
    val sanShaWarning: String?,
    val sittingClashWarning: String?,
    val detailsText: String,
    val yiActivities: List<String>,
    val jiActivities: List<String>
)

class ZeRiEngine private constructor() {
    companion object {
        val instance: ZeRiEngine by lazy { ZeRiEngine() }
    }

    private val clashMap: Map<String, String> = mapOf(
        "子" to "午", "午" to "子",
        "丑" to "未", "未" to "丑",
        "寅" to "申", "申" to "寅",
        "卯" to "酉", "酉" to "卯",
        "辰" to "戌", "戌" to "辰",
        "巳" to "亥", "亥" to "巳"
    )

    fun analyze(sitting: Mountain24Item, date: Date = Date()): ZeRiAnalysis {
        val solarResult = SolarTimeCalculator.instance.calculate(date, 120.0)
        val dayPillar = solarResult.dayPillar
        val dayBranch = if (dayPillar.length >= 2) dayPillar.substring(1, 2) else "子"

        val sittingBranch = if (sitting.name.length == 1 && clashMap.containsKey(sitting.name)) sitting.name else null
        val clashBranch = if (sittingBranch != null) clashMap[sittingBranch] else null

        val isSittingClashed = (clashBranch != null && clashBranch == dayBranch)
        val sittingWarning = if (isSittingClashed) "日支【$dayBranch】正冲本宅坐山【${sitting.name}】，犯岁禄冲煞，本日切忌动土开工" else null

        val isAuspicious = !isSittingClashed
        val overallStatus = if (isAuspicious) "吉日良辰 · 宜祈福修造" else "冲克坐山 · 避忌动土破土"

        val yi = if (isAuspicious) listOf("祈福", "安门", "动土", "入宅", "开市") else listOf("祭祀", "清扫", "沐浴", "安神")
        val ji = if (isAuspicious) listOf("安葬", "破土", "伐木") else listOf("动土", "开业", "嫁娶", "远行", "立券")

        return ZeRiAnalysis(
            fourPillarsText = solarResult.baziGanzhi,
            overallStatus = overallStatus,
            isAuspicious = isAuspicious,
            suiPoWarning = null,
            yuePoWarning = null,
            sanShaWarning = null,
            sittingClashWarning = sittingWarning,
            detailsText = "当日真太阳时节律合宜，四柱干支气场流转。选定吉时进场可催动福德。",
            yiActivities = yi,
            jiActivities = ji
        )
    }
}

