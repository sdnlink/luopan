import Foundation

// MARK: - 三合风水与十二长生水法引擎 (SanHe Water Method)

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
}

public final class SanHeWaterEngine {
    public static let shared = SanHeWaterEngine()
    
    // 四大局长生对照：火局(寅午戌)、水局(申子辰)、木局(亥卯未)、金局(巳酉丑)
    public func resolveWaterMethod(sitting: Mountain24Item) -> [SanHeWaterItem] {
        // 简要以二十四山生旺墓绝分布
        let phases = ChangShengPhase.allCases
        var list: [SanHeWaterItem] = []
        
        let mData = Mountain24Data.shared.mountains
        for (idx, m) in mData.enumerated() {
            let p = phases[(idx + sitting.id) % 12]
            // 八煞黄泉口诀简例：坎龙坤兔震山猴...
            let isHQ = (sitting.name == "庚" && m.name == "坤") || (sitting.name == "丁" && m.name == "坤")
            list.append(SanHeWaterItem(id: idx, mountainName: m.name, phase: p, isHuangQuanSha: isHQ))
        }
        return list
    }
}
