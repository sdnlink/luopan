import Foundation

// MARK: - 八大经典外环境形煞知识库与智能诊断引擎 (Exterior Sha Engine)

public enum ShaSeverity: String, Codable {
    case critical = "极凶 (大煞破局)"
    case warning  = "中凶 (损丁耗财)"
    case minor    = "轻微 (气场受扰)"
    case notice   = "吉象 (明堂清秀)"
    
    public var badgeColorHex: String {
        switch self {
        case .critical: return "#ef4444"
        case .warning:  return "#f59e0b"
        case .minor:    return "#eab308"
        case .notice:   return "#10b981"
        }
    }
}

public struct ExteriorShaItem: Identifiable, Codable {
    public let id: String
    public let name: String              // 形煞名称 (天斩煞、路冲煞、反弓水...)
    public let aliases: String           // 别名/古名
    public let visualFeature: String     // 视觉特征
    public let metaphysicsHarm: String   // 风水危害原理
    public let severity: ShaSeverity     // 严重等级
    public let classicalText: String     // 古籍赋文
    public let remedySolution: String    // 大师化解方案与开光法器建议
}

public final class ExteriorShaEngine {
    public static let shared = ExteriorShaEngine()
    
    public let database: [ExteriorShaItem] = [
        ExteriorShaItem(
            id: "tianzhan",
            name: "天斩煞",
            aliases: "天堑煞 · 穿心风",
            visualFeature: "两栋高楼间隙极度狭窄，犹如巨斧凌空劈裂，正对向首或坐山",
            metaphysicsHarm: "气流受文丘里效应加速形成高速风刃，主血光之灾、官非破财、心脑血管突发疾厄",
            severity: .critical,
            classicalText: "《雪心赋》云：天斩迎面立，屋裂气难聚。两楼夹一罅，形同剑下劈。",
            remedySolution: "1. 悬挂正品开光纯铜【山海镇】或【九宫八卦凸镜】化解罡风；\n2. 阳台窗前密植阔叶盆栽形成绿色生态挡风屏障；\n3. 室内玄关设双面山水透光屏风阻隔直冲煞气。"
        ),
        ExteriorShaItem(
            id: "luchong",
            name: "路冲煞",
            aliases: "枪煞 · 箭煞",
            visualFeature: "笔直道路或长廊直刺明堂大门、阳台或主卧窗户，车流直逼",
            metaphysicsHarm: "一条直路一条枪，车流动能化作无形猛兽直冲宅气，主破耗连连、意外伤灾、人丁不安",
            severity: .critical,
            classicalText: "《堪舆指要》云：直冲门前最难当，暗箭伤人人莫详。",
            remedySolution: "1. 门前立【泰山石敢当】重器镇宅，稳固地基气场；\n2. 设玄关形成九曲水回流之局，使气直则缓、曲则有情；\n3. 窗内安放一对纯铜【开光麒麟】，头朝路冲方向纳气化煞。"
        ),
        ExteriorShaItem(
            id: "fangong",
            name: "反弓水 / 反弓路",
            aliases: "割脚镰 · 弯刀煞",
            visualFeature: "高架桥、河流或弧形道路如拉满之弓箭，弧顶凸面正对房屋",
            metaphysicsHarm: "离心力将财气与贵人运向外甩离，形成无情冲撞，主子孙叛逆、破大财、官讼缠身",
            severity: .warning,
            classicalText: "《地理五诀》云：反弓无情水，犹如弯刀割。居者难安泰，钱财随水折。",
            remedySolution: "1. 摆放【黑曜石八卦龙龟】背向化解冲煞；\n2. 窗台安置半圆型绿色植被弧阵缓冲离心煞气；\n3. 室内向反弓方挂置【五帝钱金刚杵】镇摄金木交战之刑。"
        ),
        ExteriorShaItem(
            id: "tantou",
            name: "探头煞",
            aliases: "窥视煞 · 偷窥小人",
            visualFeature: "前方建筑物后方隐隐露出一角或圆顶，犹如有人探首窥视宅内",
            metaphysicsHarm: "暗中窥测，主招引暗室小人、遭盗窃欺诈、婚外暗昧之情或突发名誉受损",
            severity: .warning,
            classicalText: "《撼龙经》云：头低偷窥探，小人暗中乱。纵有万贯财，亦防暗中算。",
            remedySolution: "1. 挂置【凸面铜八卦镜】反弹窥测气场；\n2. 室内面向探头方摆放一只昂首纯铜【大号神公鸡】破除阴邪暗窥；\n3. 长期拉上微透光百叶窗帘，阻绝视线交锋。"
        ),
        ExteriorShaItem(
            id: "chuanxin",
            name: "穿心煞",
            aliases: "悬针煞 · 地底贯通",
            visualFeature: "楼宇下方有地铁、隧道、车道贯穿，或正门正对直通后窗",
            metaphysicsHarm: "地气空洞不稳定，泄气极速，主财气不聚、肠胃脾胃虚寒、居者缺乏安全感",
            severity: .warning,
            classicalText: "《青囊经》云：地脉不凝，宅气空腾。穿心走气，贫困无依。",
            remedySolution: "1. 室内地面铺设【黄玉七星阵】聚引大地土气；\n2. 大门入户处设下沉式真铜条门槛压胜稳气；\n3. 摆放厚重实木玄关柜以藏风聚气。"
        ),
        ExteriorShaItem(
            id: "huoxing",
            name: "火形煞",
            aliases: "尖角煞 · 尖峰冲煞",
            visualFeature: "对面大厦屋角、三角形顶棚、加油站、变电站或红色高耸尖塔直刺",
            metaphysicsHarm: "火金相克，火燥生煞，主口舌官非、视力疾厄、皮肤炎肿、脾气暴躁易燃",
            severity: .warning,
            classicalText: "《疑龙经》云：尖角冲克火星飞，灾殃临门人不归。",
            remedySolution: "1. 安放【天然白水晶球】或【黑曜石阵】以水克火化燥气；\n2. 窗边悬挂【特制两串六帝古钱】泄化燥火；\n3. 增加蓝色/水波纹装饰织物调和五行平衡。"
        ),
        ExteriorShaItem(
            id: "baihu",
            name: "白虎煞",
            aliases: "虎强龙弱 · 白虎抬头",
            visualFeature: "住宅右侧建筑物明显高过左侧（青龙方），或右侧有大型动土施工",
            metaphysicsHarm: "青龙委靡，白虎张狂，主阴盛阳衰、妇人专权暴烈、男丁运势受压抑阻滞",
            severity: .minor,
            classicalText: "《水龙经》云：宁叫青龙高万丈，莫教白虎昂半寸。",
            remedySolution: "1. 在左侧（青龙方）高处摆放一尊纯铜【祥龙吐珠】助旺龙气；\n2. 在右方白虎位安置【青玉泰山石】稳稳压伏；\n3. 提升左侧室内灯光照度与高大家具布局。"
        ),
        ExteriorShaItem(
            id: "gejiao",
            name: "割脚煞",
            aliases: "割脚水 · 贴足急流",
            visualFeature: "高架桥、贴身快速车道或汹涌急流紧挨楼脚，无明堂缓冲地带",
            metaphysicsHarm: "气流疾走拔除地气，财运大起大落，根基虚浮，青年得志但晚运易倾颓",
            severity: .minor,
            classicalText: "《地理正宗》云：水逼楼脚急，根浅风难立。",
            remedySolution: "1. 阳台处筑造高盆花坛灌木，构筑人工台座阻滞泄气；\n2. 屋内向急流方供放一对【生肖铜貔貅】咬财纳吉；\n3. 运用厚质隔音挡气Low-E玻璃窗增强气密性。"
        )
    ]
}
