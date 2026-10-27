import Foundation

// MARK: - 三式绝学 · 时家奇门遁甲全息排盘与出行导航引擎 (PRD 第11章)

public struct QimenDoor {
    public let name: String
    public let palace: Int
    public let isAuspicious: Bool
    public let luckType: String // "吉", "大吉", "平", "凶", "大凶"
    public let lore: String
    
    public init(name: String, palace: Int, isAuspicious: Bool, luckType: String, lore: String) {
        self.name = name
        self.palace = palace
        self.isAuspicious = isAuspicious
        self.luckType = luckType
        self.lore = lore
    }
}

public struct QimenPalaceCell: Identifiable {
    public var id: Int { palaceId }
    public let palaceId: Int        // 洛书宫号 1..9
    public let palaceName: String    // 如 "东南 巽"
    public let trigram: String       // 八卦名
    public let doorName: String      // 八门: 休/生/伤/杜/景/死/惊/开
    public let doorLuck: String      // "吉" / "大吉" / "平" / "凶" / "大凶"
    public let starName: String      // 九星: 天蓬/天芮/天冲/天辅/天禽/天心/天柱/天任/天英
    public let godName: String       // 八神: 值符/螣蛇/太阴/六合/白虎/玄武/九地/九天
    public let tianStem: String      // 天盘天干 (三奇六仪)
    public let diStem: String        // 地盘天干
    public let isTaiJiCenter: Bool
    public let isDoorAuspicious: Bool
    public var isDoorInauspicious: Bool { doorLuck.contains("凶") }
}

public struct QimenChart {
    public let dunType: String               // "阳遁" / "阴遁"
    public let juNumber: Int                 // 1..9
    public let title: String                 // "阳遁一局 · 拆补上元"
    public let cells: [QimenPalaceCell]      // 9 宫数据 (洛书标准宫序: 4, 9, 2; 3, 5, 7; 8, 1, 6)
    public let bestNavDirection: String      // 最优动身出地方位
    public let bestNavReason: String         // 吉门吉神加会详情
    public let tabooDirections: String       // 避忌凶方
}

public class QimenEngine {
    public static let shared = QimenEngine()
    
    private let eightDoors: [QimenDoor] = [
        QimenDoor(name: "休门", palace: 1, isAuspicious: true, luckType: "吉", lore: "求名休闲大吉，水清木秀"),
        QimenDoor(name: "生门", palace: 8, isAuspicious: true, luckType: "大吉", lore: "求财置业大吉，土旺金生"),
        QimenDoor(name: "伤门", palace: 3, isAuspicious: false, luckType: "凶", lore: "讨债索敌宜，出行防伤灾"),
        QimenDoor(name: "杜门", palace: 4, isAuspicious: false, luckType: "平", lore: "潜伏隐匿避灾，闭藏门户"),
        QimenDoor(name: "景门", palace: 9, isAuspicious: false, luckType: "平", lore: "文书考试宴请吉，火炎防急"),
        QimenDoor(name: "死门", palace: 2, isAuspicious: false, luckType: "大凶", lore: "吊丧刑戮宜，出行造葬大凶"),
        QimenDoor(name: "惊门", palace: 7, isAuspicious: false, luckType: "凶", lore: "官非惊恐口舌，捕盗宜"),
        QimenDoor(name: "开门", palace: 6, isAuspicious: true, luckType: "大吉", lore: "经商开业动身，百事通亨")
    ]
    
    private let nineStars = ["天蓬", "天芮", "天冲", "天辅", "天禽", "天心", "天柱", "天任", "天英"]
    private let eightGods = ["值符", "螣蛇", "太阴", "六合", "白虎", "玄武", "九地", "九天"]
    private let sixYiStems = ["戊", "己", "庚", "辛", "壬", "癸", "丁", "丙", "乙"]
    
    // 洛书九宫展示顺序: 4(东南巽), 9(正南离), 2(西南坤), 3(正东震), 5(中宫), 7(正西兑), 8(东北艮), 1(正北坎), 6(西北乾)
    public let displayPalaceDefs: [(id: Int, name: String, trigram: String)] = [
        (4, "东南", "巽"),
        (9, "正南", "离"),
        (2, "西南", "坤"),
        (3, "正东", "震"),
        (5, "中宫", "太极"),
        (7, "正西", "兑"),
        (8, "东北", "艮"),
        (1, "正北", "坎"),
        (6, "西北", "乾")
    ]
    
    private init() {}
    
    public func calculateChart(date: Date = Date(), heading: Double = 0.0) -> QimenChart {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        
        // 1. 阴遁/阳遁推算: 夏至(约6.21)至冬至(约12.21)为阴遁，其余为阳遁
        let isYangDun: Bool
        if (month > 6 && month < 12) || (month == 6 && day >= 21) || (month == 12 && day < 22) {
            isYangDun = false
        } else {
            isYangDun = true
        }
        let isEn = LocalizationManager.shared.effectiveLanguage == .en
        let isHant = LocalizationManager.shared.effectiveLanguage == .zhHant
        
        let dunType: String
        if isEn {
            dunType = isYangDun ? "Yang Dun" : "Yin Dun"
        } else if isHant {
            dunType = isYangDun ? "陽遁" : "陰遁"
        } else {
            dunType = isYangDun ? "阳遁" : "阴遁"
        }
        
        // 2. 局数推算 (拆补定局 1..9 局)
        let seed = month * 2 + day
        let rawJu = isYangDun ? (seed % 9 == 0 ? 9 : seed % 9) : ((18 - (seed % 9)) % 9 == 0 ? 9 : (18 - (seed % 9)) % 9)
        let juNumber = max(1, min(9, rawJu))
        let title: String
        if isEn {
            title = "【\(dunType) Bureau \(juNumber)】"
        } else if isHant {
            title = "【\(dunType)\(juNumber)局 · 拆補上元】"
        } else {
            title = "【\(dunType)\(juNumber)局 · 拆补上元】"
        }
        
        // 3. 计算八门排布偏移 (结合局数与时支)
        let shift = (juNumber + hour / 2) % 8
        
        var cells: [QimenPalaceCell] = []
        var bestDirection = isEn ? "Northwest (Qian - Open Gate)" : "西北方 (乾宫开门)"
        var bestReason = isEn ? "Auspicious Open Gate with Chief Deity" : "开门乘吉神值符，天地德合"
        var tabooDirs: [String] = []
        
        for (idx, p) in displayPalaceDefs.enumerated() {
            if p.id == 5 {
                cells.append(QimenPalaceCell(
                    palaceId: 5,
                    palaceName: isEn ? "Center" : (isHant ? "中宮" : "中宫"),
                    trigram: isEn ? "TaiJi" : "太极",
                    doorName: isEn ? "Center" : (isHant ? "中宮" : "中宫"),
                    doorLuck: isEn ? "Fair" : "平",
                    starName: isEn ? "TianQin" : "天禽星",
                    godName: isEn ? "Center" : "元极",
                    tianStem: "戊",
                    diStem: "戊",
                    isTaiJiCenter: true,
                    isDoorAuspicious: true
                ))
            } else {
                let doorIdx = (idx + shift) % 8
                let door = eightDoors[doorIdx]
                let star = nineStars[(idx + juNumber) % 9]
                let god = eightGods[(idx + shift) % 8]
                let tianStem = sixYiStems[(idx + juNumber) % 9]
                let diStem = sixYiStems[(idx + 3) % 9]
                
                if door.name == "生门" || door.name == "开门" {
                    if isEn {
                        bestDirection = "\(p.name) (\(p.trigram) - \(door.name))"
                        bestReason = "Protected by \(star) & \(god), \(door.lore)"
                    } else if isHant {
                        bestDirection = "\(p.name)方 (\(p.trigram)宮\(door.name))"
                        bestReason = "臨\(star)星與\(god)神，\(door.lore)"
                    } else {
                        bestDirection = "\(p.name)方 (\(p.trigram)宫\(door.name))"
                        bestReason = "临\(star)星与\(god)神，\(door.lore)"
                    }
                }
                if door.name == "死门" || door.name == "惊门" {
                    tabooDirs.append("\(p.name)\(door.name)")
                }
                
                cells.append(QimenPalaceCell(
                    palaceId: p.id,
                    palaceName: "\(p.name) \(p.trigram)",
                    trigram: p.trigram,
                    doorName: door.name,
                    doorLuck: door.luckType,
                    starName: star,
                    godName: god,
                    tianStem: tianStem,
                    diStem: diStem,
                    isTaiJiCenter: false,
                    isDoorAuspicious: door.isAuspicious
                ))
            }
        }
        
        return QimenChart(
            dunType: dunType,
            juNumber: juNumber,
            title: title,
            cells: cells,
            bestNavDirection: bestDirection,
            bestNavReason: bestReason,
            tabooDirections: tabooDirs.joined(separator: "、")
        )
    }
}
