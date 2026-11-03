package com.example.yiijingcompass.model

enum class StarLuckType(val rawValue: String) {
    SHENG_QI("生气 (贪狼大吉)"),
    YAN_NIAN("延年 (武曲大吉)"),
    TIAN_YI("天医 (巨门中吉)"),
    FU_WEI("伏位 (辅弼小吉)"),
    JUE_MING("绝命 (破军大凶)"),
    WU_GUI("五鬼 (廉贞大凶)"),
    LIU_SHA("六煞 (文曲中凶)"),
    HUO_HAI("祸害 (禄存小凶)");

    val isAuspicious: Boolean
        get() = this == SHENG_QI || this == YAN_NIAN || this == TIAN_YI || this == FU_WEI

    val starName: String
        get() = when (this) {
            SHENG_QI -> "生气"
            YAN_NIAN -> "延年"
            TIAN_YI -> "天医"
            FU_WEI -> "伏位"
            JUE_MING -> "绝命"
            WU_GUI -> "五鬼"
            LIU_SHA -> "六煞"
            HUO_HAI -> "祸害"
        }
}

data class BaZhaiPalaceItem(
    val id: Int,
    val direction: String,
    val guaName: String,
    val star: StarLuckType
)

data class BaZhaiAnalysis(
    val houseGua: String,
    val houseType: String,
    val gateDirection: String,
    val gateStar: StarLuckType,
    val items: List<BaZhaiPalaceItem>
)

class BaZhaiEngine private constructor() {
    companion object {
        val instance: BaZhaiEngine by lazy { BaZhaiEngine() }
    }

    private val guaFamilies: Map<String, String> = mapOf(
        "坎" to "东四宅", "震" to "东四宅", "巽" to "东四宅", "离" to "东四宅",
        "乾" to "西四宅", "坤" to "西四宅", "艮" to "西四宅", "兑" to "西四宅"
    )

    fun analyze(sittingPalace: String, facingPalace: String): BaZhaiAnalysis {
        val hType = guaFamilies[sittingPalace] ?: "东四宅"
        val houseName = "${sittingPalace}宅"

        val directions = arrayOf("正北 (坎)", "西南 (坤)", "正东 (震)", "东南 (巽)", "西北 (乾)", "正西 (兑)", "东北 (艮)", "正南 (离)")
        val guas = arrayOf("坎", "坤", "震", "巽", "乾", "兑", "艮", "离")

        val list = mutableListOf<BaZhaiPalaceItem>()
        for (i in 0 until 8) {
            val targetGua = guas[i]
            val star = calculateStar(sittingPalace, targetGua)
            list.add(BaZhaiPalaceItem(id = i, direction = directions[i], guaName = targetGua, star = star))
        }

        val gateStar = calculateStar(sittingPalace, facingPalace)

        return BaZhaiAnalysis(
            houseGua = houseName,
            houseType = hType,
            gateDirection = facingPalace,
            gateStar = gateStar,
            items = list
        )
    }

    private fun calculateStar(base: String, target: String): StarLuckType {
        if (base == target) return StarLuckType.FU_WEI
        val pairs: Map<String, Map<String, StarLuckType>> = mapOf(
            "坎" to mapOf("巽" to StarLuckType.SHENG_QI, "离" to StarLuckType.YAN_NIAN, "震" to StarLuckType.TIAN_YI, "坤" to StarLuckType.JUE_MING, "艮" to StarLuckType.WU_GUI, "乾" to StarLuckType.LIU_SHA, "兑" to StarLuckType.HUO_HAI),
            "离" to mapOf("震" to StarLuckType.SHENG_QI, "坎" to StarLuckType.YAN_NIAN, "巽" to StarLuckType.TIAN_YI, "乾" to StarLuckType.JUE_MING, "兑" to StarLuckType.WU_GUI, "坤" to StarLuckType.LIU_SHA, "艮" to StarLuckType.HUO_HAI),
            "震" to mapOf("离" to StarLuckType.SHENG_QI, "巽" to StarLuckType.YAN_NIAN, "坎" to StarLuckType.TIAN_YI, "兑" to StarLuckType.JUE_MING, "乾" to StarLuckType.WU_GUI, "艮" to StarLuckType.LIU_SHA, "坤" to StarLuckType.HUO_HAI),
            "巽" to mapOf("坎" to StarLuckType.SHENG_QI, "震" to StarLuckType.YAN_NIAN, "离" to StarLuckType.TIAN_YI, "艮" to StarLuckType.JUE_MING, "坤" to StarLuckType.WU_GUI, "兑" to StarLuckType.LIU_SHA, "乾" to StarLuckType.HUO_HAI),
            "乾" to mapOf("兑" to StarLuckType.SHENG_QI, "坤" to StarLuckType.YAN_NIAN, "艮" to StarLuckType.TIAN_YI, "离" to StarLuckType.JUE_MING, "震" to StarLuckType.WU_GUI, "坎" to StarLuckType.LIU_SHA, "巽" to StarLuckType.HUO_HAI),
            "坤" to mapOf("艮" to StarLuckType.SHENG_QI, "乾" to StarLuckType.YAN_NIAN, "兑" to StarLuckType.TIAN_YI, "坎" to StarLuckType.JUE_MING, "巽" to StarLuckType.WU_GUI, "离" to StarLuckType.LIU_SHA, "震" to StarLuckType.HUO_HAI),
            "艮" to mapOf("坤" to StarLuckType.SHENG_QI, "兑" to StarLuckType.YAN_NIAN, "乾" to StarLuckType.TIAN_YI, "巽" to StarLuckType.JUE_MING, "坎" to StarLuckType.WU_GUI, "震" to StarLuckType.LIU_SHA, "离" to StarLuckType.HUO_HAI),
            "兑" to mapOf("乾" to StarLuckType.SHENG_QI, "艮" to StarLuckType.YAN_NIAN, "坤" to StarLuckType.TIAN_YI, "震" to StarLuckType.JUE_MING, "离" to StarLuckType.WU_GUI, "巽" to StarLuckType.LIU_SHA, "坎" to StarLuckType.HUO_HAI)
        )
        return pairs[base]?.get(target) ?: StarLuckType.FU_WEI
    }
}

