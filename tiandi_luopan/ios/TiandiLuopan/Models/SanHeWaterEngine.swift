import Foundation

// MARK: - 三合风水与十二长生水法引擎 (SanHe Water Method & PRD 第13章 杨公八煞黄泉消砂)

public enum ChangShengPhase: String, CaseIterable {
    case changSheng = "长生"
    case muYu       = "沐浴"
    case guanDai    = "冠带"
    case linGuan    = "临官"
    case diWang     = "帝旺"
    case shuai      = "衰"
    case bing       = "病"
    case si         = "死"
    case mu         = "墓"
    case jue        = "绝"
    case tai        = "胎"
    case yang       = "养"
    
    public var localizedName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            switch self {
            case .changSheng: return "Chang Sheng (Birth)"
            case .muYu:       return "Mu Yu (Bath)"
            case .guanDai:    return "Guan Dai (Attire)"
            case .linGuan:    return "Lin Guan (Official)"
            case .diWang:     return "Di Wang (Peak Prosperity)"
            case .shuai:      return "Shuai (Decline)"
            case .bing:       return "Bing (Sickness)"
            case .si:         return "Si (Death)"
            case .mu:         return "Mu (Tomb)"
            case .jue:        return "Jue (Extinction)"
            case .tai:        return "Tai (Conception)"
            case .yang:       return "Yang (Nurture)"
            }
        } else if lang == .zhHant {
            switch self {
            case .changSheng: return "長生"
            case .muYu:       return "沐浴"
            case .guanDai:    return "冠帶"
            case .linGuan:    return "臨官"
            case .diWang:     return "帝旺"
            case .shuai:      return "衰"
            case .bing:       return "病"
            case .si:         return "死"
            case .mu:         return "墓"
            case .jue:        return "絕"
            case .tai:        return "胎"
            case .yang:       return "養"
            }
        }
        return rawValue
    }
    
    public var waterRule: String {
        localizedWaterRule
    }
    
    public var localizedWaterRule: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            switch self {
            case .changSheng, .diWang: return "Inflow brings great wealth; outflow causes losses."
            case .linGuan, .guanDai:   return "Noble benefactor inflow; outflow is unfavorable."
            case .shuai:               return "Jumen water, flexible for inflow/outflow as storage."
            case .mu, .jue:            return "Outflow auspicious; inflow is strictly taboo."
            case .muYu:                return "Peach blossom water; both inflow/outflow cause turbulence."
            case .bing, .si, .tai, .yang: return "Neutral peaceful position; keep calm and gentle."
            }
        } else if lang == .zhHant {
            switch self {
            case .changSheng, .diWang: return "來水吉，大發富貴；去水凶，損丁破財"
            case .linGuan, .guanDai:   return "貴人來水，催官發甲；出水不利"
            case .shuai:               return "巨門水，來去均宜，借庫消水"
            case .mu, .jue:            return "去水吉，化煞為權；來水大凶，黃泉破局"
            case .muYu:                return "桃花水，來去皆忌，主風流蕩產"
            case .bing, .si, .tai, .yang: return "平和之位，宜緩流靜蓄"
            }
        }
        switch self {
        case .changSheng, .diWang: return "来水吉，大发富贵；去水凶，损丁破财"
        case .linGuan, .guanDai:   return "贵人来水，催官发甲；出水不利"
        case .shuai:               return "巨门水，来去均宜，借库消水"
        case .mu, .jue:            return "去水吉，化煞为权；来水大凶，黄泉破局"
        case .muYu:                return "桃花水，来去皆忌，主风流荡产"
        case .bing, .si, .tai, .yang: return "平和之位，宜缓流静蓄"
        }
    }
}

public struct SanHeWaterItem: Identifiable {
    public let id: Int
    public let mountainName: String
    public let phase: ChangShengPhase
    public let isHuangQuanSha: Bool
    
    public var palace: String { mountainName + "山" }
    public var stage: String { phase.localizedName }
    public var lore: String { phase.localizedWaterRule }
    public var isAuspicious: Bool {
        phase == .changSheng || phase == .diWang || phase == .linGuan || phase == .guanDai
    }
    
    public var localizedMountainName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            let mData = Mountain24Data.shared.mountains
            if id < mData.count {
                return mData[id].pinyin
            }
        }
        return mountainName
    }
}

// MARK: - 八路黄泉水法判定模型
public struct HuangQuanWaterResult {
    public let facingMountain: String
    public let waterDesc: String
    public let isJiuPin: Bool
    public let isDanger: Bool
    public let badgeText: String
    public let quote: String = "庚丁坤上是黄泉，乙丙须防巽水先。甲癸向中休见艮，辛壬水路怕当乾。"

    public var localizedQuote: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en: return "Geng and Ding fear Huangquan in Kun; Yi and Bing guard against Xun water. Jia and Gui avoid Gen; Xin and Ren fear Qian water."
        case .zhHant: return "庚丁坤上是黃泉，乙丙須防巽水先。甲癸向中休見艮，辛壬水路怕當乾。"
        default: return quote
        }
    }
}

// MARK: - 坐山八煞曜位模型
public struct BaShaResult {
    public let sittingMountain: String
    public let sittingPalace: String
    public let shaZhi: String
    public let shaDir: String
    public let lore: String
    public let remedy: String
    public let song: String = "坎龙坤兔震山猴，巽鸡乾马兑蛇头，艮虎离猪为煞曜。"
    public let xiaoShaRule: String = "生我为生砂（催贵），同我为旺砂（旺丁财），克我为煞砂（大凶血光），我克为奴砂（得财帛），我生为泄砂（虚耗脱白）。"

    public var localizedSong: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en: return "Kan Dragon, Kun Rabbit, Zhen Monkey; Xun Rooster, Qian Horse, Dui Snake; Gen Tiger and Li Pig mark the Sha stars."
        case .zhHant: return "坎龍坤兔震山猴，巽雞乾馬兌蛇頭，艮虎離豬為煞曜。"
        default: return song
        }
    }

    public var localizedXiaoShaRule: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en: return "Generating me is Sheng Sha (noble aid); same as me is Wang Sha (people and wealth); overcoming me is Sha (major harm); I overcome is Slave Sha (wealth); I generate is Draining Sha (waste)."
        case .zhHant: return "生我為生砂（催貴），同我為旺砂（旺丁財），克我為煞砂（大凶血光），我克為奴砂（得財帛），我生為洩砂（虛耗脫白）。"
        default: return xiaoShaRule
        }
    }
    
    public var localizedShaDir: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            let zhiEn = ["辰": "Chen", "卯": "Mao", "申": "Shen", "酉": "You", "午": "Wu", "巳": "Si", "寅": "Yin", "亥": "Hai"]
            let dirEn = ["东南": "Southeast", "正东": "East", "西南": "Southwest", "正西": "West", "正南": "South", "东北": "Northeast", "西北": "Northwest"]
            let z = zhiEn[shaZhi] ?? shaZhi
            let d = dirEn[shaDir] ?? shaDir
            return "\(d) (\(z))"
        } else if lang == .zhHant {
            let dirHant = ["东南": "東南", "正东": "正東", "西南": "西南", "正西": "正西", "正南": "正南", "东北": "東北", "西北": "西北"]
            let d = dirHant[shaDir] ?? shaDir
            return "\(d)\(shaZhi)"
        }
        return "\(shaDir)\(shaZhi)"
    }
}

public final class SanHeWaterEngine {
    public static let shared = SanHeWaterEngine()
    
    // 八煞克煞曜位映射表：“坎龙坤兔震山猴，巽鸡乾马兑蛇头，艮虎离猪为煞曜”
    private let baShaMap: [String: (zhi: String, dir: String, lore: String)] = [
        "坎": ("辰", "东南", "坎卦三山(壬/子/癸)煞在辰位。辰方最忌见高压电塔、尖角怪石或破败死水，犯之主肾疾、下元损丁。"),
        "坤": ("卯", "正东", "坤卦三山(未/坤/申)煞在卯位。忌正东见冲射，主脾胃败坏、老母伤损。"),
        "震": ("申", "西南", "震卦三山(甲/卯/乙)煞在申位。忌西南申方突兀尖峰，主长房伤残、足疾官非。"),
        "巽": ("酉", "正西", "巽卦三山(辰/巽/巳)煞在酉位。忌正西酉金直冲，主妇女产厄、风声是非。"),
        "乾": ("午", "正南", "乾卦三山(戌/乾/亥)煞在午位。忌正南离火烈焰反克天门，主心脑血光、损老翁。"),
        "兑": ("巳", "东南", "兑卦三山(庚/酉/辛)煞在巳位。忌东南巳火伤金，主少女不利、肺疾吐血。"),
        "艮": ("寅", "东北", "艮卦三山(丑/艮/寅)煞在寅位。忌东北见破山绝涧，损幼子少男。"),
        "离": ("亥", "西北", "离卦三山(丙/午/丁)煞在亥位。忌西北亥水冲射，主眼疾暗昧、中房受制。")
    ]
    
    // 1. 八路黄泉水法判定
    public func resolveHuangQuanWater(facing: Mountain24Item) -> HuangQuanWaterResult {
        let name = facing.name
        let pinyin = facing.pinyin
        let lang = LocalizationManager.shared.effectiveLanguage
        
        var desc = ""
        var isJiuPin = false
        var isDanger = false
        var badge = ""
        
        if lang == .en {
            badge = "Pure Needle Auspicious"
            if name == "庚" || name == "丁" {
                desc = "Facing Mountain: [\(pinyin)]. Major Taboo: Water outlet towards Kun is lethal Huangquan sha (harms descendants and fortune). Inflow from Kun brings noble blessings."
                isDanger = true
                badge = "Avoid Kun Water Outlet"
            } else if name == "坤" {
                desc = "Facing Mountain: [Kun]. Yang Gong Rule: Inflow from Geng or Ding is Wealth-Rescue Water (Auspicious, promotes prosperity and noble honors). Direct drainage here is taboo."
                isJiuPin = true
                badge = "Wealth Rescue Facing"
            } else if name == "乙" || name == "丙" {
                desc = "Facing Mountain: [\(pinyin)]. Major Taboo: Water outlet towards Xun is Eight-Sha Huangquan (misfortunes, disputes, fire hazard). Inflow from Xun is favorable."
                isDanger = true
                badge = "Avoid Xun Water Outlet"
            } else if name == "巽" {
                desc = "Facing Mountain: [Xun]. Yang Gong Rule: Inflow from Yi or Bing is Wealth-Rescue Water (Auspicious, boosts academic recognition and lasting prosperity)."
                isJiuPin = true
                badge = "Wealth Rescue Facing"
            } else if name == "甲" || name == "癸" {
                desc = "Facing Mountain: [\(pinyin)]. Major Taboo: Water outlet towards Gen is Huangquan Killing Water (causes financial setbacks and legal troubles)."
                isDanger = true
                badge = "Avoid Gen Water Outlet"
            } else if name == "艮" {
                desc = "Facing Mountain: [Gen]. Yang Gong Rule: Inflow from Jia or Gui is Promotion Water (Auspicious, boosts vitality and eminent accomplishments)."
                isJiuPin = true
                badge = "Wealth Rescue Facing"
            } else if name == "辛" || name == "壬" {
                desc = "Facing Mountain: [\(pinyin)]. Major Taboo: Water outlet towards Qian is Po Jun Huangquan (causes unexpected losses and blood accidents)."
                isDanger = true
                badge = "Avoid Qian Water Outlet"
            } else if name == "乾" {
                desc = "Facing Mountain: [Qian]. Yang Gong Rule: Inflow from Xin or Ren is Wealth-Rescue Water (Auspicious, brings abundance and honor to elders)."
                isJiuPin = true
                badge = "Wealth Rescue Facing"
            } else {
                desc = "Facing Mountain: [\(pinyin)]. Not in the Eight-Road Huangquan taboo; align with Twelve Changsheng water method for optimal fortune."
                badge = "Pure Auspicious Water"
            }
        } else if lang == .zhHant {
            badge = "正針合度純清"
            if name == "庚" || name == "丁" {
                desc = "向首為【\(name)山向】。水法大忌：坤方出水為殺人大黃泉（損人丁、傷小口、敗退產業）；若坤方見來水反為催官水。"
                isDanger = true
                badge = "大忌坤水破局"
            } else if name == "坤" {
                desc = "向首为【坤向】。楊公水法：見庚方或丁方來水為【救貧黃泉水】（大吉，人興財旺、催官進祿）；最忌此兩方水直流破局。"
                isJiuPin = true
                badge = "救貧大吉向首"
            } else if name == "乙" || name == "丙" {
                desc = "向首為【\(name)山向】。水法大忌：巽方出水為八煞黃泉（大凶，官司口舌、火災損丁）；巽方來水則吉。"
                isDanger = true
                badge = "大忌巽方破局"
            } else if name == "巽" {
                desc = "向首為【巽向】。楊公水法：見乙方或丙方來水為【救貧黃泉水】（大吉，利科名文彩、發福綿長）。"
                isJiuPin = true
                badge = "救貧大吉向首"
            } else if name == "甲" || name == "癸" {
                desc = "向首為【\(name)山向】。水法大忌：艮方出水為黃泉殺水（主殘疾退財、官非口舌）。"
                isDanger = true
                badge = "大忌艮水出煞"
            } else if name == "艮" {
                desc = "向首為【艮向】。楊公水法：見甲方或癸方來水為【救貧催官水】（大吉，少男發達、巨富顯達）。"
                isJiuPin = true
                badge = "救貧大吉向首"
            } else if name == "辛" || name == "壬" {
                desc = "向首為【\(name)山向】。水法大忌：乾方出水為破軍黃泉（犯之主吐血、橫禍、少亡破敗）。"
                isDanger = true
                badge = "大忌乾方破局"
            } else if name == "乾" {
                desc = "向首為【乾向】。楊公水法：見辛方或壬方來水為【救貧黃泉水】（大吉，長房顯耀、金玉滿堂）。"
                isJiuPin = true
                badge = "救貧大吉向首"
            } else {
                desc = "向首為【\(name)山向】。不屬八路黃泉正煞位，水法依楊公三合十二長生（養生冠臨旺，生來會旺、拔水入庫）消納即吉。"
                badge = "正針純清納水"
            }
        } else {
            badge = "正针合度纯清"
            if name == "庚" || name == "丁" {
                desc = "向首为【\(name)山向】。水法大忌：坤方出水为杀人大黄泉（损人丁、伤小口、败退产业）；若坤方见来水反为催官水。"
                isDanger = true
                badge = "大忌坤水破局"
            } else if name == "坤" {
                desc = "向首为【坤向】。杨公水法：见庚方或丁方来水为【救贫黄泉水】（大吉，人兴财旺、催官进禄）；最忌此两方水直流破局。"
                isJiuPin = true
                badge = "救贫大吉向首"
            } else if name == "乙" || name == "丙" {
                desc = "向首为【\(name)山向】。水法大忌：巽方出水为八煞黄泉（大凶，官司口舌、火灾损丁）；巽方来水则吉。"
                isDanger = true
                badge = "大忌巽方破局"
            } else if name == "巽" {
                desc = "向首为【巽向】。杨公水法：见乙方或丙方来水为【救贫黄泉水】（大吉，利科名文彩、发福绵长）。"
                isJiuPin = true
                badge = "救贫大吉向首"
            } else if name == "甲" || name == "癸" {
                desc = "向首为【\(name)山向】。水法大忌：艮方出水为黄泉杀水（主残疾退财、官非口舌）。"
                isDanger = true
                badge = "大忌艮水出煞"
            } else if name == "艮" {
                desc = "向首为【艮向】。杨公水法：见甲方或癸方来水为【救贫催官水】（大吉，少男发达、巨富显达）。"
                isJiuPin = true
                badge = "救贫大吉向首"
            } else if name == "辛" || name == "壬" {
                desc = "向首为【\(name)山向】。水法大忌：乾方出水为破军黄泉（犯之主吐血、横祸、少亡破败）。"
                isDanger = true
                badge = "大忌乾方破局"
            } else if name == "乾" {
                desc = "向首为【乾向】。杨公水法：见辛方或壬方来水为【救贫黄泉水】（大吉，长房显耀、金玉满堂）。"
                isJiuPin = true
                badge = "救贫大吉向首"
            } else {
                desc = "向首为【\(name)山向】。不属八路黄泉正煞位，水法依杨公三合十二长生（养生冠临旺，生来会旺、拔水入库）消纳即吉。"
                badge = "正针纯清纳水"
            }
        }
        
        return HuangQuanWaterResult(
            facingMountain: name,
            waterDesc: desc,
            isJiuPin: isJiuPin,
            isDanger: isDanger,
            badgeText: badge
        )
    }
    
    // 2. 坐山八煞曜位
    public func resolveBaSha(sitting: Mountain24Item) -> BaShaResult {
        let palace = sitting.palace
        let lang = LocalizationManager.shared.effectiveLanguage
        let info = baShaMap[palace] ?? ("辰", "东南", "逢坐山煞曜方，不可有尖峰怪石冲穴。")
        
        let remedy: String
        let lore: String
        if lang == .en {
            remedy = "Sha Neutralization: If power towers or sharp wall edges appear in this direction, hang a Mountain-Sea Mirror or Five Sacred Mountains Talisman to shield."
            lore = "Sitting Mountain Sha in \(info.dir) (\(info.zhi)). Strictly avoid high-voltage towers, sharp rocks, or stagnant water in this sector."
        } else if lang == .zhHant {
            remedy = "消砂法則：該方若見高壓電線塔、壁刀尖角，急需懸掛山海鎮或五嶽真形圖予以遮擋化解。"
            lore = info.lore
        } else {
            remedy = "消砂法则：该方若见高压电线塔、壁刀尖角，急需悬挂山海镇或五岳真形图予以遮挡化解。"
            lore = info.lore
        }
        
        return BaShaResult(
            sittingMountain: sitting.name,
            sittingPalace: palace,
            shaZhi: info.zhi,
            shaDir: info.dir,
            lore: lore,
            remedy: remedy
        )
    }
    
    // 3. 四大局长生对照与十二长生水法
    public func resolveWaterMethod(sitting: Mountain24Item) -> [SanHeWaterItem] {
        let phases = ChangShengPhase.allCases
        var list: [SanHeWaterItem] = []

        // The twelve phases are anchored by the four San-He bureaus rather
        // than by the array index of a mountain.  The bureau of the sitting
        // mountain follows the project's double-mountain rule:
        // 火局 = 艮丙辛, 水局 = 坤壬乙, 金局 = 巽庚癸,
        // 木局 = 乾甲丁 (with their corresponding earthly branches).
        // This is different from simply assigning every mountain to its
        // nearest earthly branch; doing that misclassifies 乙、辛、癸、丁.
        let branchByMountain: [String: Int] = [
            "壬": 0, "子": 0, "癸": 0,
            "丑": 1, "艮": 2, "寅": 2,
            "甲": 3, "卯": 3, "乙": 3,
            "辰": 4, "巽": 5, "巳": 5,
            "丙": 6, "午": 6, "丁": 6,
            "未": 7, "坤": 8, "申": 8,
            "庚": 9, "酉": 9, "辛": 9,
            "戌": 10, "乾": 11, "亥": 11
        ]
        let branchIndexForMountain: (Mountain24Item) -> Int = { mountain in
            branchByMountain[mountain.name] ?? 0
        }
        let bureauStart: Int
        switch sitting.name {
        case "申", "子", "辰", "坤", "壬", "乙":
            // 申子辰水局，长生在申
            bureauStart = 8
        case "亥", "卯", "未", "乾", "甲", "丁":
            // 亥卯未木局，长生在亥
            bureauStart = 11
        case "寅", "午", "戌", "艮", "丙", "辛":
            // 寅午戌火局，长生在寅
            bureauStart = 2
        default:
            // 巳酉丑金局，长生在巳
            bureauStart = 5
        }

        let mData = Mountain24Data.shared.mountains
        for (idx, m) in mData.enumerated() {
            let targetBranch = branchIndexForMountain(m)
            let phaseOffset = (targetBranch - bureauStart + 12) % 12
            let p = phases[phaseOffset]
            let isHQ = (sitting.name == "庚" && m.name == "坤") || (sitting.name == "丁" && m.name == "坤") ||
                       (sitting.name == "乙" && m.name == "巽") || (sitting.name == "丙" && m.name == "巽") ||
                       (sitting.name == "甲" && m.name == "艮") || (sitting.name == "癸" && m.name == "艮") ||
                       (sitting.name == "辛" && m.name == "乾") || (sitting.name == "壬" && m.name == "乾")
            list.append(SanHeWaterItem(id: idx, mountainName: m.name, phase: p, isHuangQuanSha: isHQ))
        }
        return list
    }
}
