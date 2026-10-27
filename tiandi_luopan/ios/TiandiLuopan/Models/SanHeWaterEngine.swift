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
    
    public var waterRule: String {
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
    public var stage: String { phase.rawValue }
    public var lore: String { phase.waterRule }
    public var isAuspicious: Bool {
        phase == .changSheng || phase == .diWang || phase == .linGuan || phase == .guanDai
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
        var desc = ""
        var isJiuPin = false
        var isDanger = false
        var badge = "正针合度纯清"
        
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
        let info = baShaMap[palace] ?? ("辰", "东南", "逢坐山煞曜方，不可有尖峰怪石冲穴。")
        
        let remedy = "消砂法则：该方若见高压电线塔、壁刀尖角，急需悬挂山海镇或五岳真形图予以遮挡化解。"
        
        return BaShaResult(
            sittingMountain: sitting.name,
            sittingPalace: palace,
            shaZhi: info.zhi,
            shaDir: info.dir,
            lore: info.lore,
            remedy: remedy
        )
    }
    
    // 3. 四大局长生对照与十二长生水法
    public func resolveWaterMethod(sitting: Mountain24Item) -> [SanHeWaterItem] {
        let phases = ChangShengPhase.allCases
        var list: [SanHeWaterItem] = []
        
        let mData = Mountain24Data.shared.mountains
        for (idx, m) in mData.enumerated() {
            let p = phases[(idx + sitting.id) % 12]
            let isHQ = (sitting.name == "庚" && m.name == "坤") || (sitting.name == "丁" && m.name == "坤") ||
                       (sitting.name == "乙" && m.name == "巽") || (sitting.name == "丙" && m.name == "巽") ||
                       (sitting.name == "甲" && m.name == "艮") || (sitting.name == "癸" && m.name == "艮") ||
                       (sitting.name == "辛" && m.name == "乾") || (sitting.name == "壬" && m.name == "乾")
            list.append(SanHeWaterItem(id: idx, mountainName: m.name, phase: p, isHuangQuanSha: isHQ))
        }
        return list
    }
}
