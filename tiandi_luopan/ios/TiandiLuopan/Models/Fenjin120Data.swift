import Foundation

// MARK: - 一百二十分金数据库与吉凶分析 (PRD 6.6 & 罗盘核心第三层)

public struct FenjinItem: Identifiable {
    public var id: String { "\(mountainName)-\(index)" }
    public let mountainName: String    // 所属二十四山 (如 "子山")
    public let index: Int              // 1..5
    public let jiaziName: String       // 甲子名称 (如 "甲子", "丙子", "戊子", "庚子", "壬子")
    public let startAngle: Double      // 起始角度
    public let endAngle: Double        // 终止角度
    public let centerAngle: Double     // 中心角度
    public let grade: String           // "旺相大吉", "孤虚差错", "龟甲空亡", "平稳"
    public let isAuspicious: Bool      // 是否为可用吉度
    public let lore: String            // 秘诀断语

    public var localizedMountainName: String {
        if let mountain = Mountain24Data.shared.mountains.first(where: { $0.name == mountainName }) {
            return mountain.localizedName
        }
        return mountainName
    }

    public var localizedGrade: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch grade {
            case "旺相大吉": return "Auspicious Prosperity"
            case "孤虚差错": return "Lone Void Error"
            case "差错退财": return "Error · Wealth Drain"
            case "龟甲空亡": return "Turtle-Shell Void"
            case "差错退气": return "Error · Retreating Qi"
            default: return "Balanced"
            }
        case .zhHant:
            return grade.replacingOccurrences(of: "旺相大吉", with: "旺相大吉")
                .replacingOccurrences(of: "差错", with: "差錯")
                .replacingOccurrences(of: "退财", with: "退財")
                .replacingOccurrences(of: "空亡", with: "空亡")
        default: return grade
        }
    }

    public var localizedLore: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch grade {
            case "旺相大吉": return "Prosperous and well-timed; supports wealth, harmony and lasting fortune."
            case "孤虚差错": return "Lone-void error qi; associated with retreat and wealth loss. Avoid establishing a facing here."
            case "差错退财": return "Excess yin and hidden drain make it difficult to gather qi or retain wealth."
            case "龟甲空亡": return "Turtle-shell void; a depleted degree associated with setbacks and illness. Avoid using it."
            case "差错退气": return "Retreating qi makes it difficult to sustain momentum or responsibility."
            default: return "The qi is balanced; use ordinary orientation judgment."
            }
        case .zhHant:
            return lore.replacingOccurrences(of: "差错", with: "差錯")
                .replacingOccurrences(of: "退财", with: "退財")
                .replacingOccurrences(of: "旺相", with: "旺相")
                .replacingOccurrences(of: "气", with: "氣")
                .replacingOccurrences(of: "煞气", with: "煞氣")
        default: return lore
        }
    }
}

public class Fenjin120Data {
    public static let shared = Fenjin120Data()
    
    public let allFenjin: [FenjinItem]
    
    // 二十四山正针名称与起止角度 (每山 15 度，坎宫子山从 352.5° 至 7.5°)
    // 120 分金每位 3 度
    private let stemTypes: [String: (grade: String, ji: Bool, lore: String)] = [
        "甲": ("孤虚差错", false, "孤虚煞气，主冷退破财，丁口凋零，不宜立向。"),
        "乙": ("差错退财", false, "阴气过重，主暗耗损财，难以聚气。"),
        "丙": ("旺相大吉", true, "正针阳火旺相，招财进宝，富贵绵远，大吉可用。"),
        "丁": ("旺相大吉", true, "阴火得位，丁财两旺，科甲联登，大吉可用。"),
        "戊": ("龟甲空亡", false, "五黄土煞龟甲大空亡，主横祸官非、病榻缠绵，切忌犯之！"),
        "己": ("龟甲空亡", false, "阴土空亡败绝，主绝嗣衰败，地师慎勿轻下！"),
        "庚": ("旺相大吉", true, "阳金生旺，武贵显达，威震四方，大吉可用。"),
        "辛": ("旺相大吉", true, "阴金纯正，文雅富厚，金玉满堂，大吉可用。"),
        "壬": ("孤虚差错", false, "水泛木浮孤虚煞，丁财两空，慎莫相犯。"),
        "癸": ("差错退气", false, "退气之度，难以发皇，难当大任。")
    ]
    
    private init() {
        var items: [FenjinItem] = []
        let mountains = Mountain24Data.shared.mountains
        
        // Each mountain contains five same-branch 120-fen-jin degrees.
        // The previous sequential 60-cycle assigned 子山 as 甲子/乙丑/…,
        // which mixed branches inside one mountain.  Generate the valid five
        // Jiazi combinations from the mountain's three-mountain branch group.
        let branchGroups = [0, 1, 3, 4, 6, 7, 9, 10]
        let branchNames = ["子", "丑", "卯", "辰", "午", "未", "酉", "戌"]
        let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        
        for m in mountains {
            let group = min(max(m.id / 3, 0), branchGroups.count - 1)
            let branchIndex = branchGroups[group]
            let branch = branchNames[group]
            let firstStemIndex = branchIndex % 2
            for i in 0..<5 {
                let jiazi = "\(stems[firstStemIndex + i * 2])\(branch)"
                let startA = (m.startAngle + Double(i) * 3.0).truncatingRemainder(dividingBy: 360)
                let endA = (m.startAngle + Double(i + 1) * 3.0).truncatingRemainder(dividingBy: 360)
                let centerA = (m.startAngle + Double(i) * 3.0 + 1.5).truncatingRemainder(dividingBy: 360)
                
                let firstChar = String(jiazi.prefix(1))
                let meta = stemTypes[firstChar] ?? ("平稳", false, "气场平平")
                
                items.append(FenjinItem(
                    mountainName: m.name,
                    index: i + 1,
                    jiaziName: jiazi,
                    startAngle: startA,
                    endAngle: endA,
                    centerAngle: centerA,
                    grade: meta.grade,
                    isAuspicious: meta.ji,
                    lore: meta.lore
                ))
            }
        }
        self.allFenjin = items
    }
    
    // 根据方位角实时检索匹配当前精确分金
    public func resolveFenjin(for angle: Double) -> FenjinItem {
        let normAngle = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        for item in allFenjin {
            if item.startAngle < item.endAngle {
                if normAngle >= item.startAngle && normAngle < item.endAngle {
                    return item
                }
            } else {
                // 跨越 0°/360° 正北子山分金
                if normAngle >= item.startAngle || normAngle < item.endAngle {
                    return item
                }
            }
        }
        // The table is generated from the fixed 24-mountain data and should
        // never be empty, but keep the lookup total so a future data change
        // cannot crash the compass at runtime.
        return allFenjin.first ?? FenjinItem(
            mountainName: "子",
            index: 1,
            jiaziName: "甲子",
            startAngle: 0,
            endAngle: 3,
            centerAngle: 1.5,
            grade: "平稳",
            isAuspicious: false,
            lore: "气场平平"
        )
    }
}
