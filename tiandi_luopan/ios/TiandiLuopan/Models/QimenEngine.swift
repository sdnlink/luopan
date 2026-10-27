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

    public var localizedName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            return ["休门": "Rest Gate", "生门": "Life Gate", "伤门": "Harm Gate", "杜门": "Block Gate", "景门": "View Gate", "死门": "Death Gate", "惊门": "Shock Gate", "开门": "Open Gate"][name] ?? name
        }
        if lang == .zhHant { return ["休门": "休門", "生门": "生門", "伤门": "傷門", "杜门": "杜門", "景门": "景門", "死门": "死門", "惊门": "驚門", "开门": "開門"][name] ?? name }
        return name
    }

    public var localizedLuckType: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return ["大吉": "Great Luck", "吉": "Auspicious", "凶": "Inauspicious", "大凶": "Major Taboo", "平": "Neutral"][luckType] ?? luckType
        case .zhHant:
            return ["大吉": "大吉", "吉": "吉", "凶": "凶", "大凶": "大凶", "平": "平"][luckType] ?? luckType
        default:
            return luckType
        }
    }

    public var localizedLore: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return [
                "休门": "Favorable for rest, study and quiet pursuits.", "生门": "Excellent for wealth, property and growth.",
                "伤门": "Useful for pursuit, but guard against travel injuries.", "杜门": "Hide and consolidate; keep doors closed.",
                "景门": "Good for documents and examinations; avoid haste.", "死门": "Suitable for mourning rites; avoid travel and construction.",
                "惊门": "Disputes and alarm are possible; useful for catching thieves.", "开门": "Excellent for business, opening and movement."
            ][name] ?? lore
        case .zhHant:
            return [
                "休门": "求名休閒大吉，水清木秀", "生门": "求財置業大吉，土旺金生",
                "伤门": "討債索敵宜，出行防傷災", "杜门": "潛伏隱匿避災，閉藏門戶",
                "景门": "文書考試宴請吉，火炎防急", "死门": "吊喪刑戮宜，出行造葬大凶",
                "惊门": "官非驚恐口舌，捕盜宜", "开门": "經商開業動身，百事通亨"
            ][name] ?? lore
        default:
            return lore
        }
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

    public var localizedDoorName: String {
        QimenDoor(name: doorName, palace: palaceId, isAuspicious: isDoorAuspicious, luckType: doorLuck, lore: "").localizedName
    }
    public var localizedStarName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en { return ["天蓬": "Tian Peng", "天芮": "Tian Rui", "天冲": "Tian Chong", "天辅": "Tian Fu", "天禽": "Tian Qin", "天心": "Tian Xin", "天柱": "Tian Zhu", "天任": "Tian Ren", "天英": "Tian Ying"][starName] ?? starName }
        if lang == .zhHant { return starName.replacingOccurrences(of: "冲", with: "沖").replacingOccurrences(of: "辅", with: "輔") }
        return starName
    }
    public var localizedGodName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en { return ["值符": "Chief Deity", "螣蛇": "Snake", "太阴": "Great Yin", "六合": "Six Harmony", "白虎": "White Tiger", "玄武": "Black Tortoise", "九地": "Nine Earth", "九天": "Nine Heaven", "元极": "Center Pole"][godName] ?? godName }
        if lang == .zhHant { return godName.replacingOccurrences(of: "阴", with: "陰").replacingOccurrences(of: "极", with: "極") }
        return godName
    }
    public var localizedPalaceName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        let hantMap = ["东南": "東南", "正南": "正南", "西南": "西南", "正东": "正東", "中宫": "中宮", "正西": "正西", "东北": "東北", "正北": "正北", "西北": "西北"]
        if lang == .zhHant {
            let parts = palaceName.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 { return "\(hantMap[parts[0]] ?? parts[0]) \(parts[1].replacingOccurrences(of: "宫", with: "宮"))" }
            return hantMap[palaceName] ?? palaceName.replacingOccurrences(of: "宫", with: "宮")
        }
        guard lang == .en else { return palaceName }
        let map = ["东南": "Southeast", "正南": "South", "西南": "Southwest", "正东": "East", "中宫": "Center", "正西": "West", "东北": "Northeast", "正北": "North", "西北": "Northwest"]
        let parts = palaceName.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 2 { return "\(map[parts[0]] ?? parts[0]) (\(parts[1]))" }
        return map[palaceName] ?? palaceName
    }
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
        let hour = calendar.component(.hour, from: date)
        let solarTermIndex = SolarTimeCalculator.shared.solarTermIndex(for: date)
        
        // 1. 阴遁/阳遁按节气切换：夏至至大雪为阴遁，冬至至芒种为阳遁。
        // 使用太阳黄经而非固定公历日期，覆盖不同年份节气时刻的变化。
        let isYangDun = solarTermIndex < 11 || solarTermIndex >= 23
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
        
        // 2. 拆补定局：按当前节气的前五日、中五日、后五日取上/中/下元。
        // Each row is [upper, middle, lower] for one solar term.  The term
        // index is 0=小寒 ... 22=大雪, 23=冬至.
        let progress = SolarTimeCalculator.shared.solarTermProgress(for: date)
        let yuanIndex = min(2, max(0, Int(progress / 5.0)))
        let yangBureaus: [Int: [Int]] = [
            23: [1, 7, 4], 0: [2, 8, 5], 1: [3, 9, 6],
            2: [8, 5, 2], 3: [9, 6, 3], 4: [1, 7, 4],
            5: [3, 9, 6], 6: [4, 1, 7], 7: [5, 2, 8],
            8: [4, 1, 7], 9: [5, 2, 8], 10: [6, 3, 9]
        ]
        let yinBureaus: [Int: [Int]] = [
            11: [9, 3, 6], 12: [8, 2, 5], 13: [7, 1, 4],
            14: [2, 5, 8], 15: [1, 4, 7], 16: [9, 3, 6],
            17: [7, 1, 4], 18: [6, 9, 3], 19: [5, 8, 2],
            20: [5, 8, 2], 21: [4, 7, 1], 22: [3, 6, 9]
        ]
        let bureauTable = isYangDun ? yangBureaus : yinBureaus
        let juNumber = bureauTable[solarTermIndex]?[yuanIndex] ?? 1
        let title: String
        let yuanName: String
        if isEn {
            yuanName = ["Upper Yuan", "Middle Yuan", "Lower Yuan"][yuanIndex]
        } else if isHant {
            yuanName = ["上元", "中元", "下元"][yuanIndex]
        } else {
            yuanName = ["上元", "中元", "下元"][yuanIndex]
        }
        if isEn {
            title = "【\(dunType) Bureau \(juNumber) · \(yuanName)】"
        } else if isHant {
            title = "【\(dunType)\(juNumber)局 · 拆補\(yuanName)】"
        } else {
            title = "【\(dunType)\(juNumber)局 · 拆补\(yuanName)】"
        }
        
        // 3. 计算八门排布偏移 (结合局数与时支)。
        // `hour / 2` 会把 23:00 算成序号 11，并在每个偶数小时边界
        // 错开一支；奇门按子时 23:00 起，应使用标准十二时辰索引。
        let hourBranch = ((hour + 1) / 2) % 12
        let shift = (juNumber + hourBranch) % 8
        
        var cells: [QimenPalaceCell] = []
        var nonCenterIndex = 0
        var bestDirection: String
        var bestReason: String
        // Keep the absolute bearing of the selected gate so the caller can
        // turn the current device heading into actionable left/right guidance.
        // `heading` is a clockwise magnetic/true bearing in degrees.
        var bestBearing: Double? = nil
        if isEn {
            bestDirection = "Northwest (Qian - Open Gate)"
            bestReason = "Auspicious Open Gate with Chief Deity"
        } else if isHant {
            bestDirection = "西北方 (乾宮開門)"
            bestReason = "開門乘吉神值符，天地德合"
        } else {
            bestDirection = "西北方 (乾宫开门)"
            bestReason = "开门乘吉神值符，天地德合"
        }
        var bestScore = -1
        var tabooDirs: [String] = []
        
        for p in displayPalaceDefs {
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
                // `displayPalaceDefs` includes the center at index 4.  Using
                // the raw grid index here skips door 5 and repeats door 1;
                // keep a separate eight-palace counter so every door appears
                // exactly once.
                let doorIdx = (nonCenterIndex + shift) % 8
                let door = eightDoors[doorIdx]
                let star = nineStars[(nonCenterIndex + juNumber) % 9]
                let god = eightGods[(nonCenterIndex + shift) % 8]
                let tianStem = sixYiStems[(nonCenterIndex + juNumber) % 9]
                let diStem = sixYiStems[(nonCenterIndex + 3) % 9]
                
                if door.name == "生门" || door.name == "开门" {
                    // Prefer Open Gate over Life Gate and keep the first
                    // direction when scores tie. The previous implementation
                    // overwrote the result for every favorable gate, making
                    // the displayed "best" direction depend on grid order.
                    let candidateScore = door.name == "开门" ? 4 : 3
                    if candidateScore > bestScore, isEn {
                        let direction = ["东南": "Southeast", "正南": "South", "西南": "Southwest", "正东": "East", "正西": "West", "东北": "Northeast", "正北": "North", "西北": "Northwest"][p.name] ?? p.name
                        let trigram = ["巽": "Xun", "离": "Li", "坤": "Kun", "震": "Zhen", "兑": "Dui", "艮": "Gen", "坎": "Kan", "乾": "Qian"][p.trigram] ?? p.trigram
                        let localizedDoor = door.localizedName
                        let localizedStar = ["天蓬": "Tian Peng", "天芮": "Tian Rui", "天冲": "Tian Chong", "天辅": "Tian Fu", "天禽": "Tian Qin", "天心": "Tian Xin", "天柱": "Tian Zhu", "天任": "Tian Ren", "天英": "Tian Ying"][star] ?? star
                        let localizedGod = ["值符": "Chief Deity", "螣蛇": "Snake", "太阴": "Great Yin", "六合": "Six Harmony", "白虎": "White Tiger", "玄武": "Black Tortoise", "九地": "Nine Earth", "九天": "Nine Heaven"][god] ?? god
                        bestDirection = "\(direction) (\(trigram) · \(localizedDoor))"
                        bestReason = "Protected by \(localizedStar) & \(localizedGod), \(door.localizedLore)"
                        bestBearing = Self.bearing(for: p.name)
                        bestScore = candidateScore
                    } else if candidateScore > bestScore, isHant {
                        let hantDoor = door.localizedName
                        let hantStar = QimenPalaceCell(
                            palaceId: p.id, palaceName: p.name, trigram: p.trigram,
                            doorName: door.name, doorLuck: door.luckType,
                            starName: star, godName: god, tianStem: "", diStem: "",
                            isTaiJiCenter: false, isDoorAuspicious: door.isAuspicious
                        ).localizedStarName
                        let hantGod = QimenPalaceCell(
                            palaceId: p.id, palaceName: p.name, trigram: p.trigram,
                            doorName: door.name, doorLuck: door.luckType,
                            starName: star, godName: god, tianStem: "", diStem: "",
                            isTaiJiCenter: false, isDoorAuspicious: door.isAuspicious
                        ).localizedGodName
                        bestDirection = "\(p.name)方 (\(p.trigram)宮\(hantDoor))"
                        bestReason = "臨\(hantStar)星與\(hantGod)神，\(door.localizedLore)"
                        bestBearing = Self.bearing(for: p.name)
                        bestScore = candidateScore
                    } else if candidateScore > bestScore {
                        bestDirection = "\(p.name)方 (\(p.trigram)宫\(door.name))"
                        bestReason = "临\(star)星与\(god)神，\(door.lore)"
                        bestBearing = Self.bearing(for: p.name)
                        bestScore = candidateScore
                    }
                }
                if door.name == "死门" || door.name == "惊门" {
                    if isEn {
                        let direction = ["东南": "Southeast", "正南": "South", "西南": "Southwest", "正东": "East", "正西": "West", "东北": "Northeast", "正北": "North", "西北": "Northwest"][p.name] ?? p.name
                        tabooDirs.append("\(direction) · \(door.localizedName)")
                    } else if isHant {
                        tabooDirs.append("\(p.name)\(door.localizedName)")
                    } else {
                        tabooDirs.append("\(p.name)\(door.name)")
                    }
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
                nonCenterIndex += 1
            }
        }

        // Add a turn instruction to the absolute best direction.  This is
        // intentionally kept in the already localized summary string so the
        // existing view and exported report gain the feature without a new
        // API field.  A missing/invalid heading simply omits the instruction.
        if let targetBearing = bestBearing,
           heading.isFinite {
            let turn = Self.shortestTurn(from: heading, to: targetBearing)
            if abs(turn) >= 1.0 {
                let degrees = Int(round(abs(turn)))
                if isEn {
                    bestDirection += turn > 0
                        ? " · turn right \(degrees)°"
                        : " · turn left \(degrees)°"
                } else if isHant {
                    bestDirection += turn > 0
                        ? " · 右轉約\(degrees)°"
                        : " · 左轉約\(degrees)°"
                } else {
                    bestDirection += turn > 0
                        ? " · 右转约\(degrees)°"
                        : " · 左转约\(degrees)°"
                }
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

    /// Compass bearings for the eight Qimen palaces.  The center palace is
    /// deliberately excluded because it is not a travel direction.
    private static func bearing(for direction: String) -> Double? {
        switch direction {
        case "正北": return 0.0
        case "东北": return 45.0
        case "正东": return 90.0
        case "东南": return 135.0
        case "正南": return 180.0
        case "西南": return 225.0
        case "正西": return 270.0
        case "西北": return 315.0
        default: return nil
        }
    }

    /// Returns the signed shortest clockwise turn from the current bearing to
    /// a target bearing. Positive values mean turn right/clockwise; negative
    /// values mean turn left/counter-clockwise.
    private static func shortestTurn(from heading: Double, to target: Double) -> Double {
        var delta = (target - heading).truncatingRemainder(dividingBy: 360.0)
        if delta > 180.0 { delta -= 360.0 }
        if delta < -180.0 { delta += 360.0 }
        return delta
    }
}
