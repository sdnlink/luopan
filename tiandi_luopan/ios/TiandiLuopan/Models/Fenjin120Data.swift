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
        
        let jiaziCycle = [
            "甲子","乙丑","丙寅","丁卯","戊辰","己巳","庚午","辛未","壬申","癸酉",
            "甲戌","乙亥","丙子","丁丑","戊寅","己卯","庚辰","辛巳","壬午","癸未",
            "甲申","乙酉","丙戌","丁亥","戊子","己丑","庚寅","辛卯","壬辰","癸巳",
            "甲午","乙未","丙申","丁酉","戊戌","己亥","庚子","辛丑","壬寅","癸卯",
            "甲辰","乙巳","丙午","丁未","戊申","己酉","庚戌","辛亥","壬子","癸丑",
            "甲寅","乙卯","丙辰","丁巳","戊午","己未","庚申","辛酉","壬戌","癸亥"
        ]
        
        var globalIndex = 0
        for m in mountains {
            for i in 0..<5 {
                let jiazi = jiaziCycle[globalIndex % 60]
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
                globalIndex += 1
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
        return allFenjin.first!
    }
}
