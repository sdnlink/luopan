import Foundation

// MARK: - 六十四卦与易经三百八十四爻分金模型

public struct HexagramItem: Identifiable, Codable {
    public let id: Int
    public let name: String           // 卦名 (如: 乾为天、坤为地、水火既济)
    public let upperTrigram: String   // 上卦
    public let lowerTrigram: String   // 下卦
    public let binaryCode: String     // 6位二进制 (1阳0阴)
    public let angleCenter: Double    // 中心度数 (360 / 64 = 5.625°)
    public let elementNumber: Int     // 卦气五行生成数 (一水二火三木四金五土...)
    public let luckDegree: String     // 吉凶分级 (大吉、中吉、平、凶)
    public let fenJinDetail: String   // 穿山透地七十二龙/易经分金描述
    
    public init(id: Int, name: String, upperTrigram: String, lowerTrigram: String, binaryCode: String, angleCenter: Double, elementNumber: Int, luckDegree: String, fenJinDetail: String) {
        self.id = id
        self.name = name
        self.upperTrigram = upperTrigram
        self.lowerTrigram = lowerTrigram
        self.binaryCode = binaryCode
        self.angleCenter = angleCenter
        self.elementNumber = elementNumber
        self.luckDegree = luckDegree
        self.fenJinDetail = fenJinDetail
    }
    public var isGreatAuspicious: Bool { luckDegree == "大吉" }

    public var localizedName: String {
        let language = LocalizationManager.shared.effectiveLanguage
        if language == .en { return "Hexagram \(id + 1)" }
        if language == .zhHant {
            return name
                .replacingOccurrences(of: "剥", with: "剝")
                .replacingOccurrences(of: "风", with: "風")
                .replacingOccurrences(of: "观", with: "觀")
                .replacingOccurrences(of: "晋", with: "晉")
                .replacingOccurrences(of: "泽", with: "澤")
                .replacingOccurrences(of: "谦", with: "謙")
                .replacingOccurrences(of: "渐", with: "漸")
                .replacingOccurrences(of: "过", with: "過")
                .replacingOccurrences(of: "遁", with: "遯")
                .replacingOccurrences(of: "师", with: "師")
                .replacingOccurrences(of: "涣", with: "渙")
                .replacingOccurrences(of: "讼", with: "訟")
                .replacingOccurrences(of: "蛊", with: "蠱")
                .replacingOccurrences(of: "恒", with: "恆")
                .replacingOccurrences(of: "复", with: "復")
                .replacingOccurrences(of: "颐", with: "頤")
                .replacingOccurrences(of: "随", with: "隨")
                .replacingOccurrences(of: "无", with: "無")
                .replacingOccurrences(of: "贲", with: "賁")
                .replacingOccurrences(of: "既济", with: "既濟")
                .replacingOccurrences(of: "离", with: "離")
                .replacingOccurrences(of: "临", with: "臨")
                .replacingOccurrences(of: "损", with: "損")
                .replacingOccurrences(of: "节", with: "節")
                .replacingOccurrences(of: "归妹", with: "歸妹")
                .replacingOccurrences(of: "兑", with: "兌")
                .replacingOccurrences(of: "壮", with: "壯")
        }
        return name
    }

    public var localizedLuckDegree: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch luckDegree {
            case "大吉": return "Great Auspicious"
            case "中吉": return "Auspicious"
            case "慎用": return "Use with Care"
            default: return "Neutral"
            }
        case .zhHant:
            return luckDegree.replacingOccurrences(of: "慎用", with: "慎用")
        default: return luckDegree
        }
    }

    public var localizedUpperTrigram: String {
        if LocalizationManager.shared.effectiveLanguage == .en {
            return ["坤": "Kun", "艮": "Gen", "坎": "Kan", "巽": "Xun", "震": "Zhen", "离": "Li", "兑": "Dui", "乾": "Qian"][upperTrigram] ?? upperTrigram
        }
        if LocalizationManager.shared.effectiveLanguage == .zhHant {
            return upperTrigram.replacingOccurrences(of: "离", with: "離").replacingOccurrences(of: "兑", with: "兌")
        }
        return upperTrigram
    }

    public var localizedLowerTrigram: String {
        if LocalizationManager.shared.effectiveLanguage == .en {
            return ["坤": "Kun", "艮": "Gen", "坎": "Kan", "巽": "Xun", "震": "Zhen", "离": "Li", "兑": "Dui", "乾": "Qian"][lowerTrigram] ?? lowerTrigram
        }
        if LocalizationManager.shared.effectiveLanguage == .zhHant {
            return lowerTrigram.replacingOccurrences(of: "离", with: "離").replacingOccurrences(of: "兑", with: "兌")
        }
        return lowerTrigram
    }
}

public final class Hexagram64Data {
    public static let shared = Hexagram64Data()
    
    public let hexagrams: [HexagramItem]
    
    private init() {
        // 圆周64卦按先天圆图顺布生成
        let names = [
            "坤为地", "山地剥", "水地比", "风地观", "雷地豫", "火地晋", "泽地萃", "天地否",
            "地山谦", "艮为山", "水山蹇", "风山渐", "雷山小过", "火山旅", "泽山咸", "天山遁",
            "地水师", "山水蒙", "坎为水", "风水涣", "雷水解", "火水未济", "泽水困", "天水讼",
            "地风升", "山风蛊", "水风井", "巽为风", "雷风恒", "火风鼎", "泽风大过", "天风姤",
            "地雷复", "山雷颐", "水雷屯", "风雷益", "震为雷", "火雷噬嗑", "泽雷随", "天雷无妄",
            "地火明夷", "山火贲", "水火既济", "风火家人", "雷火丰", "离为火", "泽火革", "天火同人",
            "地泽临", "山泽损", "水泽节", "风泽中孚", "雷泽归妹", "火泽睽", "兑为泽", "天泽履",
            "地天泰", "山天大畜", "水天需", "风天小畜", "雷天大壮", "火天大有", "泽天夬", "乾为天"
        ]
        
        var list: [HexagramItem] = []
        let step = 360.0 / 64.0 // 5.625°
        
        let trigrams = ["坤", "艮", "坎", "巽", "震", "离", "兑", "乾"]
        for i in 0..<64 {
            let angle = Double(i) * step
            let name = names[i % names.count]
            let luck: String
            let detail: String
            
            // 易经分金吉凶判定：旺相孤虚煞曜
            switch i % 8 {
            case 0, 7:
                luck = "大吉"
                detail = "旺相得令 · 丁财两旺 · 纳气纯清"
            case 1, 3, 5:
                luck = "中吉"
                detail = "合十通关 · 文昌显贵 · 催官生贵"
            case 2:
                luck = "平"
                detail = "平常平和 · 宜静不宜动 · 平稳发展"
            default:
                luck = "慎用"
                detail = "孤虚出煞 · 空亡差错 · 需抽爻换象化解"
            }
            
            let item = HexagramItem(
                id: i,
                name: name,
                upperTrigram: trigrams[i % 8],
                lowerTrigram: trigrams[i / 8],
                binaryCode: String(repeating: "0", count: max(0, 6 - String(i, radix: 2).count)) + String(i, radix: 2),
                angleCenter: angle,
                elementNumber: (i % 9) + 1,
                luckDegree: luck,
                fenJinDetail: detail
            )
            list.append(item)
        }
        self.hexagrams = list
    }
    
    public func hexagram(for angle: Double) -> HexagramItem {
        let norm = (angle.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let step = 360.0 / 64.0
        let idx = Int((norm + step / 2.0) / step) % 64
        return hexagrams[idx]
    }
}
