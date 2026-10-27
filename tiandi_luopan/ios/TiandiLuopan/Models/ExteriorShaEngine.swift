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
    
    public var localizedTitle: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch self {
        case .critical:
            return lang == .en ? "Critical (Major Harm)" : (lang == .zhHant ? "極凶 (大煞破局)" : "极凶 (大煞破局)")
        case .warning:
            return lang == .en ? "Warning (Severe Harm)" : (lang == .zhHant ? "中凶 (損丁耗財)" : "中凶 (损丁耗财)")
        case .minor:
            return lang == .en ? "Minor (Disturbed Qi)" : (lang == .zhHant ? "輕微 (氣場受擾)" : "轻微 (气场受扰)")
        case .notice:
            return lang == .en ? "Auspicious (Bright Hall)" : (lang == .zhHant ? "吉象 (明堂清秀)" : "吉象 (明堂清秀)")
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
    
    public var localizedName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch id {
        case "tianzhan": return lang == .en ? "Sky Severing Sha" : (lang == .zhHant ? "天斬煞" : name)
        case "luchong":  return lang == .en ? "Road Rush Sha" : (lang == .zhHant ? "路衝煞" : name)
        case "fangong":  return lang == .en ? "Reverse Bow Water" : (lang == .zhHant ? "反弓水" : name)
        case "tantou":   return lang == .en ? "Peeking Sha" : (lang == .zhHant ? "探頭煞" : name)
        case "chuanxin": return lang == .en ? "Heart Piercing Sha" : (lang == .zhHant ? "穿心煞" : name)
        case "huoxing":  return lang == .en ? "Fire Shape Sha" : (lang == .zhHant ? "火形煞" : name)
        case "baihu":    return lang == .en ? "White Tiger Sha" : (lang == .zhHant ? "白虎煞" : name)
        case "gejiao":   return lang == .en ? "Feet Cutting Sha" : (lang == .zhHant ? "割腳煞" : name)
        default: return name
        }
    }
    
    public var localizedAliases: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            switch id {
            case "tianzhan": return "Wind Blade Gap · Split House"
            case "luchong":  return "Spear Sha · Arrow Sha"
            case "fangong":  return "Sickle Sha · Curved Knife"
            case "tantou":   return "Peeping Tom Sha · Hidden Observer"
            case "chuanxin": return "Hanging Needle · Hollow Qi"
            case "huoxing":  return "Sharp Angle · Transformer Sha"
            case "baihu":    return "Dominant Right · Tiger Head"
            case "gejiao":   return "Foot Scraper · Rapid Stream"
            default: return aliases
            }
        } else if lang == .zhHant {
            switch id {
            case "tianzhan": return "天塹煞 · 穿心風"
            case "luchong":  return "槍煞 · 箭煞"
            case "fangong":  return "割腳鐮 · 彎刀煞"
            case "tantou":   return "窺視煞 · 偷窺小人"
            case "chuanxin": return "懸針煞 · 地底貫通"
            case "huoxing":  return "尖角煞 · 尖峰衝煞"
            case "baihu":    return "虎強龍弱 · 白虎抬頭"
            case "gejiao":   return "割腳水 · 貼足急流"
            default: return aliases
            }
        }
        return aliases
    }
    
    public var localizedVisualFeature: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            switch id {
            case "tianzhan": return "Extremely narrow gap between two high-rise buildings directly facing the property."
            case "luchong":  return "A straight road, alley, or corridor pointing directly at the main entrance or window."
            case "fangong":  return "An elevated bridge, highway, or curved road bending outward like an arched bow."
            case "tantou":   return "A roof corner, dome, or structure peering from behind a frontal building."
            case "chuanxin": return "Subway, tunnel, or busy roadway passing directly underneath the building."
            case "huoxing":  return "Sharp roof corners, triangular towers, gas stations, or electrical substations."
            case "baihu":    return "Right-side building is noticeably taller than the left (Azure Dragon) side."
            case "gejiao":   return "High-speed road or turbulent waterway running directly against building foundations."
            default: return visualFeature
            }
        }
        if lang == .zhHant {
            switch id {
            case "tianzhan": return "兩棟高樓間隙極度狹窄，如巨斧凌空劈裂，正對向首或坐山。"
            case "luchong": return "筆直道路或長廊直刺明堂大門、陽台或主臥窗戶，車流直逼。"
            case "fangong": return "高架橋、河流或弧形道路如拉滿之弓箭，弧頂凸面正對房屋。"
            case "tantou": return "前方建築物後方隱隱露出一角或圓頂，如有人探首窺視宅內。"
            case "chuanxin": return "樓宇下方有地鐵、隧道、車道貫穿，或正門正對直通後窗。"
            case "huoxing": return "對面大廈屋角、三角形頂棚、加油站、變電站或紅色尖塔直刺。"
            case "baihu": return "住宅右側建築物明顯高過左側青龍方，或右側有大型動土施工。"
            case "gejiao": return "高架橋、貼身快速車道或洶湧急流緊挨樓腳，沒有明堂緩衝地帶。"
            default: return visualFeature
            }
        }
        return visualFeature
    }
    
    public var localizedRemedySolution: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            switch id {
            case "tianzhan": return "1. Hang an authentic Mountain-Sea Mirror or convex Bagua mirror;\n2. Plant broad-leaved evergreen plants on the balcony as a wind buffer;\n3. Install an opaque porch screen to break direct incoming wind."
            case "luchong":  return "1. Place a Taishan Stone Shi Gandang monument at the entrance;\n2. Design a winding entryway to slow and harmonize incoming qi flow;\n3. Position a pair of consecrated pure brass Qilin facing the road."
            case "fangong":  return "1. Position an Obsidian Dragon Turtle facing outward;\n2. Place curved lush greenery along window ledges as an energetic buffer;\n3. Hang Five Emperor Coins with Vajra pestle indoors."
            case "tantou":   return "1. Hang a convex brass Bagua mirror to reflect peering energy;\n2. Place a pure brass rooster facing the corner to dispel stealth disturbance;\n3. Keep translucent venetian blinds closed during daylight."
            case "chuanxin": return "1. Lay yellow jade Seven-Star array on the floor to ground Earth qi;\n2. Install a sunken solid brass threshold at the entrance;\n3. Place a heavy solid-wood cabinet at the foyer to retain qi."
            case "huoxing":  return "1. Place natural white quartz crystal sphere or obsidian array to counter Fire;\n2. Hang two strings of Six Emperor brass coins near the window;\n3. Integrate ocean blue decorative textiles to balance Five Elements."
            case "baihu":    return "1. Place a consecrated pure brass Dragon holding a pearl on the left side;\n2. Position a heavy green jade Taishan stone on the right to subdue the Tiger;\n3. Increase lighting intensity and tall furniture placement on the left."
            case "gejiao":   return "1. Build tall planter boxes and shrubs on the balcony as a buffer;\n2. Place a pair of brass Pixiu facing the waterway to guard wealth;\n3. Install thick soundproofing laminated Low-E double glazing."
            default: return remedySolution
            }
        }
        if lang == .zhHant {
            switch id {
            case "tianzhan": return "1. 懸掛正品開光純銅山海鎮或九宮八卦凸鏡；\n2. 陽台密植闊葉盆栽形成擋風屏障；\n3. 玄關設山水屏風阻隔直衝煞氣。"
            case "luchong": return "1. 門前安置泰山石敢當；\n2. 設曲折玄關使直氣轉緩；\n3. 窗內安放開光麒麟朝向路衝。"
            case "fangong": return "1. 擺放黑曜石八卦龍龜；\n2. 窗台以弧形綠植緩衝；\n3. 室內懸掛五帝錢金剛杵。"
            case "tantou": return "1. 掛凸面銅八卦鏡反彈窺視；\n2. 擺放昂首純銅公雞；\n3. 白天關閉百葉窗簾。"
            case "chuanxin": return "1. 地面鋪黃玉七星陣聚土氣；\n2. 大門設真銅門檻；\n3. 玄關擺厚重實木櫃藏風聚氣。"
            case "huoxing": return "1. 安放白水晶球或黑曜石陣；\n2. 窗邊懸掛六帝古錢；\n3. 以藍色水波紋織物調和五行。"
            case "baihu": return "1. 左側擺純銅祥龍吐珠；\n2. 右方白虎位安置青玉泰山石；\n3. 增強左側燈光與家具高度。"
            case "gejiao": return "1. 陽台築高盆花壇與灌木；\n2. 向急流方供放銅貔貅；\n3. 安裝厚質隔音 Low-E 玻璃。"
            default: return remedySolution
            }
        }
        return remedySolution
    }

    /// Localized explanation shown in the AR result card.  The source data is
    /// intentionally kept in Simplified Chinese for the knowledge base, while
    /// these computed values keep the UI language consistent.
    public var localizedMetaphysicsHarm: String {
        guard LocalizationManager.shared.effectiveLanguage != .zhHans else { return metaphysicsHarm }
        let en: [String: String] = [
            "tianzhan": "Venturi acceleration turns the gap into a high-speed wind blade, associated with accidents, disputes, financial loss and sudden cardiovascular strain.",
            "luchong": "A straight road behaves like a spear: traffic momentum rushes into the home, bringing repeated loss, accidents and family unrest.",
            "fangong": "Centrifugal force pulls wealth and support outward, creating an unfeeling collision associated with rebellion, major loss and litigation.",
            "tantou": "A hidden gaze invites back-room trouble, theft, deceit, secret affairs and sudden damage to reputation.",
            "chuanxin": "Unstable ground qi leaks rapidly, weakening wealth retention, digestion and the occupants' sense of security.",
            "huoxing": "Fire clashes with Metal, bringing arguments, legal trouble, eye and skin complaints, and an irritable temper.",
            "baihu": "A weakened Azure Dragon and dominant White Tiger can suppress yang energy, authority and the family's progress.",
            "gejiao": "Fast moving qi strips the foundation, causing volatile finances, a weak base and a tendency for later decline."
        ]
        let hant: [String: String] = [
            "tianzhan": "氣流受文丘裏效應加速形成高速風刃，主血光之災、官非破財及心腦血管突發疾厄。",
            "luchong": "直路如槍，車流動能直衝宅氣，主破耗連連、意外傷災及人丁不安。",
            "fangong": "離心力將財氣與貴人運向外甩離，形成無情衝撞，主子孫叛逆、破大財及官訟纏身。",
            "tantou": "暗中窺測，主招引暗室小人、盜竊欺詐、婚外暗昧或突發名譽受損。",
            "chuanxin": "地氣空洞不穩定，洩氣極速，主財氣不聚、脾胃虛寒及居者缺乏安全感。",
            "huoxing": "火金相克、火燥生煞，主口舌官非、視力疾厄、皮膚炎腫及脾氣暴躁。",
            "baihu": "青龍委靡、白虎張狂，主陰盛陽衰、男丁運勢受壓抑阻滯。",
            "gejiao": "氣流疾走拔除地氣，財運大起大落、根基虛浮，青年得志而晚運易傾頹。"
        ]
        let values = LocalizationManager.shared.effectiveLanguage == .zhHant ? hant : en
        return values[id] ?? metaphysicsHarm
    }

    public var localizedClassicalText: String {
        guard LocalizationManager.shared.effectiveLanguage != .zhHans else { return classicalText }
        let en: [String: String] = [
            "tianzhan": "The Snow Heart Ode says: A sky-cleaving gap before the house splits the qi; two towers leave a cleft like a sword descending.",
            "luchong": "The Essentials of Form says: A direct road before the gate is hardest to withstand; a hidden arrow wounds without warning.",
            "fangong": "The Five Geographic Secrets says: An unfeeling reverse-bow stream cuts like a curved blade; wealth follows the water away.",
            "tantou": "The Dragon Classic says: A lowered head peering from behind stirs hidden trouble; even great wealth must guard against secret schemes.",
            "chuanxin": "The Green Satchel Classic says: When the earth vein is not gathered, house qi rises and escapes through the heart, leaving poverty and insecurity.",
            "huoxing": "The Doubting Dragon Classic says: A sharp corner strikes like a flying fire star; calamity reaches the door and people fail to return.",
            "baihu": "The Water Dragon Classic says: Let the Azure Dragon rise ten thousand yards; never let the White Tiger lift its head even half an inch.",
            "gejiao": "The Orthodox Geography says: When water presses urgently at the building's feet, shallow roots cannot stand against the wind."
        ]
        let hant: [String: String] = [
            "tianzhan": "《雪心賦》云：天斬迎面立，屋裂氣難聚。兩樓夾一罅，形同劍下劈。",
            "luchong": "《堪輿指要》云：直衝門前最難當，暗箭傷人人莫詳。",
            "fangong": "《地理五訣》云：反弓無情水，猶如彎刀割。居者難安泰，錢財隨水折。",
            "tantou": "《撼龍經》云：頭低窺視探，小人暗中亂。縱有萬貫財，亦防暗中算。",
            "chuanxin": "《青囊經》云：地脈不凝，宅氣空騰。穿心走氣，貧困無依。",
            "huoxing": "《疑龍經》云：尖角衝克火星飛，災殃臨門人不歸。",
            "baihu": "《水龍經》云：寧叫青龍高萬丈，莫教白虎昂半寸。",
            "gejiao": "《地理正宗》云：水逼樓腳急，根淺風難立。"
        ]
        let values = LocalizationManager.shared.effectiveLanguage == .zhHant ? hant : en
        return values[id] ?? classicalText
    }
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
