package com.example.yiijingcompass.model

enum class ChangShengPhase(val rawValue: String) {
    CHANG_SHENG("长生"),
    MU_YU("沐浴"),
    GUAN_DAI("冠带"),
    LIN_GUAN("临官"),
    DI_WANG("帝旺"),
    SHUAI("衰"),
    BING("病"),
    SI("死"),
    MU("墓"),
    JUE("绝"),
    TAI("胎"),
    YANG("养");

    val isWaterAuspicious: Boolean
        get() = this == CHANG_SHENG || this == DI_WANG || this == LIN_GUAN || this == GUAN_DAI

    val waterRule: String
        get() = when (this) {
            CHANG_SHENG -> "长生水来，人丁兴旺，富贵双全；忌流出破局。"
            MU_YU -> "沐浴水为桃花煞，主淫乱风流破耗，宜去不宜来。"
            GUAN_DAI -> "冠带水来，利科举读书，聪明俊秀，早岁显荣。"
            LIN_GUAN -> "临官禄水来，官运亨通，催官进禄，巨富显达。"
            DI_WANG -> "帝旺水来，财源广进，万众归心，富贵极品；忌破旺位。"
            SHUAI -> "衰位水去大吉，借库消水；水来则旺极转衰。"
            BING, SI -> "病死之水不可来，流来主瘟疫伤残、人口凋零；去水吉。"
            MU -> "墓库之水宜去，破库泄财大凶；得局消水则为救贫黄泉。"
            JUE, TAI -> "绝胎水来伤人丁，去水化煞主清平。"
            YANG -> "养位水蓄积为吉，主生生不息、财禄悠长。"
        }
}

data class SanHeWaterItem(
    val id: Int,
    val mountainName: String,
    val phase: ChangShengPhase,
    val isHuangQuanSha: Boolean
) {
    val isAuspicious: Boolean get() = phase.isWaterAuspicious
}

data class HuangQuanWaterResult(
    val facingMountain: String,
    val waterDesc: String,
    val isJiuPin: Boolean,
    val isDanger: Boolean,
    val badgeText: String,
    val quote: String = "庚丁坤上是黄泉，乙丙须防巽水先。甲癸向中休见艮，辛壬水路怕当乾。"
)

data class BaShaResult(
    val sittingMountain: String,
    val sittingPalace: String,
    val shaZhi: String,
    val shaDir: String,
    val lore: String,
    val remedy: String,
    val song: String = "坎龙坤兔震山猴，巽鸡乾马兑蛇头，艮虎离猪为煞曜。",
    val xiaoShaRule: String = "生我为生砂（催贵），同我为旺砂（旺丁财），克我为煞砂（大凶血光），我克为奴砂（得财帛），我生为泄砂（虚耗脱白）。"
)

class SanHeWaterEngine private constructor() {
    companion object {
        val instance: SanHeWaterEngine by lazy { SanHeWaterEngine() }
    }

    fun resolveHuangQuanWater(facing: Mountain24Item): HuangQuanWaterResult {
        val fName = facing.name
        val (desc, isDanger, isJiuPin, badge) = when {
            fName == "庚" || fName == "丁" ->
                Quad("坤方为杀人大黄泉，水来立主败绝；若坤水流去反为救贫黄泉催官贵。", true, true, "大煞 / 救贫")
            fName == "坤" ->
                Quad("立坤向，庚丁两方水不可来，流去则发富贵。", true, true, "黄泉反向")
            fName == "乙" || fName == "丙" ->
                Quad("巽方为黄泉杀人大煞，最忌来水；巽水放流去吉。", true, true, "巽水黄泉")
            fName == "巽" ->
                Quad("立巽向，乙丙水来犯黄泉，流去反催文贵。", true, true, "黄泉水路")
            fName == "甲" || fName == "癸" ->
                Quad("艮方为破局黄泉，见艮方水来大凶；艮方去水大利财富。", true, true, "艮水禁忌")
            fName == "艮" ->
                Quad("立艮向，甲癸水来犯黄泉水法，流去为吉。", true, true, "黄泉反冲")
            fName == "辛" || fName == "壬" ->
                Quad("乾方水路最忌当头来冲，主损折男丁；流出乾方去水吉。", true, true, "乾宫黄泉")
            fName == "乾" ->
                Quad("立乾向，辛壬两宫水来犯杀人黄泉，流去则富贵。", true, true, "乾位反煞")
            else ->
                Quad("此向非正八路黄泉煞位，依常规生旺水法收纳即可。", false, false, "平正无煞")
        }
        return HuangQuanWaterResult(
            facingMountain = facing.name,
            waterDesc = desc,
            isJiuPin = isJiuPin,
            isDanger = isDanger,
            badgeText = badge
        )
    }

    fun resolveBaSha(sitting: Mountain24Item): BaShaResult {
        val sPalace = sitting.palace
        val (shaZhi, shaDir, lore, remedy) = when (sPalace) {
            "坎" -> Quad("辰", "东南方 (辰位)", "坎龙逢辰为八煞曜，主克害子孙水厄官讼。", "东南辰方忌有尖角恶石冲射，宜安放金属铜麒麟或泰山石敢当化解。")
            "坤" -> Quad("卯", "正东方 (卯位)", "坤逢卯兔为煞曜，主妇人疾厄、家道中落。", "正东卯方忌见高树尖刹，宜设厚帘阻隔或置葫芦化煞。")
            "震" -> Quad("申", "西南方 (申位)", "震山逢申猴为煞曜，主金木相战、筋骨意外折损。", "西南申方见冲射宜置黑曜石或水池化泄金气。")
            "巽" -> Quad("酉", "正西方 (酉位)", "巽逢酉鸡为煞曜，主妇道不宁、咳嗽肺疾。", "正西酉方忌见白色尖角或风煞，宜用水培绿植化金生水生木。")
            "乾" -> Quad("午", "正南方 (午位)", "乾马逢午火为八煞，火烧天门大凶破财突发心脏血疾。", "正南午方忌见红炉变压器，必须安放黄水晶球或陶土瓮化火生金。")
            "兑" -> Quad("巳", "东南方 (巳位)", "兑逢蛇头为煞曜，主口舌是非、少女伤损。", "东南方忌恶水乱石，宜悬挂风铃化解。")
            "艮" -> Quad("寅", "东北方 (寅位)", "艮虎为煞曜，主少男伤损、肠胃背痛。", "东北方忌动土开山，宜静不安动。")
            "离" -> Quad("亥", "西北方 (亥位)", "离逢亥猪为煞曜，水火相激主目疾心悸。", "西北方见冲克，宜用木本绿植化水生火通关。")
            else -> Quad("无", "中宫无煞", "中宫八面平和，无八煞直克曜位。", "保持中宫洁净明亮即可。")
        }
        return BaShaResult(
            sittingMountain = sitting.name,
            sittingPalace = sPalace,
            shaZhi = shaZhi,
            shaDir = shaDir,
            lore = lore,
            remedy = remedy
        )
    }

    @Suppress("UNUSED_PARAMETER")
    fun resolveWaterMethod(sitting: Mountain24Item, facing: Mountain24Item): List<SanHeWaterItem> {
        val phases = ChangShengPhase.values()
        val mountains = Mountain24Data.instance.mountains
        val list = mutableListOf<SanHeWaterItem>()
        val startOffset = (sitting.index * 2) % 24
        for (i in 0 until 24) {
            val m = mountains[(startOffset + i) % 24]
            val phase = phases[i % 12]
            val isHq = (m.name == "坤" || m.name == "巽" || m.name == "艮" || m.name == "乾")
            list.add(SanHeWaterItem(id = i, mountainName = m.name, phase = phase, isHuangQuanSha = isHq))
        }
        return list
    }

    private data class Quad<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
}

