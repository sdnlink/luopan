import Foundation

// MARK: - 八宅风水与大游年九星吉凶模型 (BaZhai Engine)

public enum StarLuckType: String, Codable {
    case shengQi = "生气 (贪狼大吉)"
    case yanNian = "延年 (武曲大吉)"
    case tianYi  = "天医 (巨门中吉)"
    case fuWei   = "伏位 (辅弼小吉)"
    case jueMing = "绝命 (破军大凶)"
    case wuGui   = "五鬼 (廉贞大凶)"
    case liuSha  = "六煞 (文曲中凶)"
    case huoHai  = "祸害 (禄存小凶)"
    
    public var isAuspicious: Bool {
        switch self {
        case .shengQi, .yanNian, .tianYi, .fuWei: return true
        default: return false
        }
    }
    
    public var actionSuggestion: String {
        switch self {
        case .shengQi: return "最利求财进职、开大门、置主卧、安动气之源"
        case .yanNian: return "利健康长寿、夫妻和睦、人际关系，宜主卧客堂"
        case .tianYi:  return "消灾解厄、身体强健、得贵人相扶，利安床与神位"
        case .fuWei:   return "安稳守成、文昌得利，宜作书房、冥想及儿童房"
        case .jueMing: return "主病痛耗散，严禁作卧房大门，宜作卫生间或储物室"
        case .wuGui:   return "易惹口舌是非、盗贼火灾，宜压以重物或化水局"
        case .liuSha:  return "酒色桃花、心绪不宁，宜化解或设杂物间"
        case .huoHai:  return "官非小人、财帛破耗，宜静不宜动"
        }
    }
}

public struct BaZhaiPalaceItem: Identifiable {
    public let id: Int
    public let direction: String
    public let guaName: String
    public let star: StarLuckType
}

public struct BaZhaiAnalysis {
    public let houseGua: String       // 宅卦 (如: 坎宅、乾宅)
    public let houseType: String      // 东四宅 / 西四宅
    public let gateDirection: String  // 大门开向
    public let gateStar: StarLuckType // 大门纳气吉凶
    public let items: [BaZhaiPalaceItem]
}

public final class BaZhaiEngine {
    public static let shared = BaZhaiEngine()
    
    // 八宅大游年口诀对照表
    // 乾六、坎一、艮八、震三、巽四、离九、坤二、兑七
    private let guaFamilies: [String: String] = [
        "坎": "东四宅", "震": "东四宅", "巽": "东四宅", "离": "东四宅",
        "乾": "西四宅", "坤": "西四宅", "艮": "西四宅", "兑": "西四宅"
    ]
    
    public func analyze(sittingPalace: String, facingPalace: String) -> BaZhaiAnalysis {
        let hType = guaFamilies[sittingPalace] ?? "东四宅"
        let houseName = "\(sittingPalace)宅"
        
        let directions = ["正北 (坎)", "西南 (坤)", "正东 (震)", "东南 (巽)", "西北 (乾)", "正西 (兑)", "东北 (艮)", "正南 (离)"]
        let guas = ["坎", "坤", "震", "巽", "乾", "兑", "艮", "离"]
        
        var list: [BaZhaiPalaceItem] = []
        for i in 0..<8 {
            let targetGua = guas[i]
            let star = calculateStar(from: sittingPalace, to: targetGua)
            list.append(BaZhaiPalaceItem(id: i, direction: directions[i], guaName: targetGua, star: star))
        }
        
        let gateStar = calculateStar(from: sittingPalace, to: facingPalace)
        
        return BaZhaiAnalysis(
            houseGua: houseName,
            houseType: hType,
            gateDirection: facingPalace,
            gateStar: gateStar,
            items: list
        )
    }
    
    private func calculateStar(from base: String, to target: String) -> StarLuckType {
        if base == target { return .fuWei }
        // 简易经典大游年八宅排星算法映射
        let pairs: [String: [String: StarLuckType]] = [
            "坎": ["巽": .shengQi, "离": .yanNian, "震": .tianYi, "坤": .jueMing, "艮": .wuGui, "乾": .liuSha, "兑": .huoHai],
            "离": ["震": .shengQi, "坎": .yanNian, "巽": .tianYi, "乾": .jueMing, "兑": .wuGui, "坤": .liuSha, "艮": .huoHai],
            "震": ["离": .shengQi, "巽": .yanNian, "坎": .tianYi, "兑": .jueMing, "乾": .wuGui, "艮": .liuSha, "坤": .huoHai],
            "巽": ["坎": .shengQi, "震": .yanNian, "离": .tianYi, "艮": .jueMing, "坤": .wuGui, "兑": .liuSha, "乾": .huoHai],
            "乾": ["兑": .shengQi, "坤": .yanNian, "艮": .tianYi, "离": .jueMing, "震": .wuGui, "坎": .liuSha, "巽": .huoHai],
            "坤": ["艮": .shengQi, "乾": .yanNian, "兑": .tianYi, "坎": .jueMing, "巽": .wuGui, "离": .liuSha, "震": .huoHai],
            "艮": ["坤": .shengQi, "兑": .yanNian, "乾": .tianYi, "巽": .jueMing, "坎": .wuGui, "震": .liuSha, "离": .huoHai],
            "兑": ["乾": .shengQi, "艮": .yanNian, "坤": .tianYi, "震": .jueMing, "离": .wuGui, "巽": .liuSha, "坎": .huoHai]
        ]
        return pairs[base]?[target] ?? .fuWei
    }
}
