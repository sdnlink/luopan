package com.example.yiijingcompass.model

enum class ShaSeverity(val rawValue: String, val badgeColorHex: String) {
    CRITICAL("极凶 (大煞破局)", "#ef4444"),
    WARNING("中凶 (损丁耗财)", "#f59e0b"),
    MINOR("轻微 (气场受扰)", "#eab308"),
    NOTICE("吉象 (明堂清秀)", "#10b981")
}

data class ExteriorShaItem(
    val id: String,
    val name: String,              // 形煞名称 (天斩煞、路冲煞、反弓水...)
    val aliases: String,           // 别名/古名
    val visualFeature: String,     // 视觉特征
    val metaphysicsHarm: String,   // 风水危害原理
    val severity: ShaSeverity,     // 严重等级
    val classicalText: String,     // 古籍赋文
    val remedySolution: String     // 大师化解方案与开光法器建议
)

class ExteriorShaEngine private constructor() {
    companion object {
        val instance: ExteriorShaEngine by lazy { ExteriorShaEngine() }
    }

    val database: List<ExteriorShaItem> = listOf(
        ExteriorShaItem(
            id = "tianzhan",
            name = "天斩煞",
            aliases = "天堑煞 · 穿心风",
            visualFeature = "两栋高楼间隙极度狭窄，犹如巨斧凌空劈裂，正对向首或坐山",
            metaphysicsHarm = "气流受文丘里效应加速形成高速风刃，主血光之灾、官非破财、心脑血管突发疾厄",
            severity = ShaSeverity.CRITICAL,
            classicalText = "《雪心赋》云：天斩迎面立，屋裂气难聚。两楼夹一罅，形同剑下劈。",
            remedySolution = "① 挡（先做·免费）：正对楼缝的窗前或阳台，摆一排高过窗台的阔叶绿植（龟背竹、发财树），或加厚纱帘。\n② 隔（低成本）：若大门与对缝窗成一直线，玄关放半高鞋柜或镂空屏风，进门不一眼望穿。\n③ 镇（可选）：正对缝口挂凸面八卦镜或山海镇，镜面朝外、略下倾3-5度，勿照邻家门窗。"
        ),
        ExteriorShaItem(
            id = "luchong",
            name = "路冲煞",
            aliases = "枪煞 · 箭煞",
            visualFeature = "笔直道路或长廊直刺明堂大门、阳台或主卧窗户，车流直逼",
            metaphysicsHarm = "一条直路一条枪，车流动能化作无形猛兽直冲宅气，主破耗连连、意外伤灾、人丁不安",
            severity = ShaSeverity.CRITICAL,
            classicalText = "《堪舆指要》云：直冲门前最难当，暗箭伤人人莫详。",
            remedySolution = "① 挡（先做·免费）：门口放门槛石或门垫，门内挂门帘；正对路的窗台放一盆高绿植。\n② 隔（低成本）：门外加半高绿篱或屏风，让进门动线拐个弯。\n③ 镇（可选）：大门上方挂山海镇或八卦镜，朝路方向微下倾，勿照邻居。"
        ),
        ExteriorShaItem(
            id = "fangong",
            name = "反弓水 / 反弓路",
            aliases = "割脚镰 · 弯刀煞",
            visualFeature = "高架桥、河流或弧形道路如拉满之弓箭，弧顶凸面正对房屋",
            metaphysicsHarm = "离心力将财气与贵人运向外甩离，形成无情冲撞，主子孙叛逆、破大财、官讼缠身",
            severity = ShaSeverity.WARNING,
            classicalText = "《地理五诀》云：反弓无情水，犹如弯刀割。居者难安泰，钱财随水折。",
            remedySolution = "① 挡（先做·免费）：反弓一侧窗外摆弧形绿植或盆栽，形成半圆缓冲。\n② 隔（低成本）：室内反弓方向放圆形茶几、地毯或弧形沙发，避免直角家具直冲。\n③ 镇（可选）：反弓方位放黑曜石、石敢当或五帝钱，面朝弧外。"
        ),
        ExteriorShaItem(
            id = "tantou",
            name = "探头煞",
            aliases = "窥视煞 · 偷窥小人",
            visualFeature = "前方建筑物后方隐隐露出一角或圆顶，犹如有人探首窥视宅内",
            metaphysicsHarm = "暗中窥测，主招引暗室小人、遭盗窃欺诈、婚外暗昧之情或突发名誉受损",
            severity = ShaSeverity.WARNING,
            classicalText = "《撼龙经》云：头低偷窥探，小人暗中乱。纵有万贯财，亦防暗中算。",
            remedySolution = "① 挡（先做·免费）：对探头方向的窗，白天拉上纱帘或百叶。\n② 隔（低成本）：窗台摆高绿植（长春藤、绿萝），遮挡探头角。\n③ 镇（可选）：凸面八卦镜朝探头方挂，勿照邻家门窗。"
        ),
        ExteriorShaItem(
            id = "chuanxin",
            name = "穿心煞",
            aliases = "悬针煞 · 地底贯通",
            visualFeature = "楼宇下方有地铁、隧道、车道贯穿，或正门正对直通后窗",
            metaphysicsHarm = "地气空洞不稳定，泄气极速，主财气不聚、肠胃脾胃虚寒、居者缺乏安全感",
            severity = ShaSeverity.WARNING,
            classicalText = "《青囊经》云：地脉不凝，宅气空腾。穿心走气，贫困无依。",
            remedySolution = "① 隔（先做·免费）：门与后窗成直线时，在动线正中放玄关柜、屏风或挂厚门帘。\n② 挡（低成本）：地面铺地毯、窗台放绿植、重家具靠墙，减缓气流速度。\n③ 镇（可选）：入户门槛内放五帝钱或小号石敢当。"
        ),
        ExteriorShaItem(
            id = "huoxing",
            name = "火形煞",
            aliases = "尖角煞 · 尖峰冲煞",
            visualFeature = "对面大厦屋角、三角形顶棚、加油站、变电站或红色高耸尖塔直刺",
            metaphysicsHarm = "火金相克，火燥生煞，主口舌官非、视力疾厄、皮肤炎肿、脾气暴躁易燃",
            severity = ShaSeverity.WARNING,
            classicalText = "《疑龙经》云：尖角冲克火星飞，灾殃临门人不归。",
            remedySolution = "① 挡（先做·免费）：正对尖角的窗挂纱帘或百叶。\n② 隔（低成本）：窗台摆水养植物（水培绿萝、常春藤），缓解干燥。\n③ 镇（可选）：放黑曜石、水晶或蓝色装饰物压火气；此方位忌红色。"
        ),
        ExteriorShaItem(
            id = "baihu",
            name = "白虎煞",
            aliases = "虎强龙弱 · 白虎抬头",
            visualFeature = "住宅右侧建筑物明显高过左侧（青龙方），或右侧有大型动土施工",
            metaphysicsHarm = "青龙委靡，白虎张狂，主阴盛阳衰、妇人专权暴烈、男丁运势受压抑阻滞",
            severity = ShaSeverity.MINOR,
            classicalText = "《水龙经》云：宁叫青龙高万丈，莫教白虎昂半寸。",
            remedySolution = "① 补（先做·免费）：左侧（青龙方）加落地灯、高大家具或高大绿植，平衡左右视觉高度。\n② 挡（低成本）：右侧若临施工或高楼，靠右窗挂厚窗帘遮挡。\n③ 镇（可选）：左侧放泰山石或麒麟摆件。"
        ),
        ExteriorShaItem(
            id = "gejiao",
            name = "割脚煞",
            aliases = "割脚水 · 贴足急流",
            visualFeature = "高架桥、贴身快速车道或汹涌急流紧挨楼脚，无明堂缓冲地带",
            metaphysicsHarm = "气流疾走拔除地气，财运大起大落，根基虚浮，青年得志但晚运易倾颓",
            severity = ShaSeverity.MINOR,
            classicalText = "《地理正宗》云：水逼楼脚急，根浅风难立。",
            remedySolution = "① 挡（先做·免费）：临路一侧阳台或窗前摆高盆绿植或花坛。\n② 隔（低成本）：临路窗换厚玻璃或加双层窗帘，降低噪音。\n③ 镇（可选）：近路/水方向放貔貅或石敢当。"
        )
    )

    fun find(id: String): ExteriorShaItem? = database.firstOrNull { it.id == id }
}

