import Foundation

// MARK: - 二十四节气与十二消息卦数据模型 (PRD 6.2 & 罗盘外圈天文气运层)

public struct SolarTermItem: Identifiable {
    public var id: String { name }
    public let name: String            // 如 "立春", "雨水"
    public let angleCenter: Double     // 罗盘对应角度中心
    public let season: String          // "春", "夏", "秋", "冬"
    public let hexagramName: String?   // 十二消息卦/辟卦 (如 "地天泰")
    public let isMajorTerm: Bool       // 是否为分至点 (春分、秋分、夏至、冬至)

    public var localizedName: String {
        let language = LocalizationManager.shared.effectiveLanguage
        if language == .en {
            return ["冬至": "Winter Solstice", "小寒": "Minor Cold", "大寒": "Major Cold", "立春": "Start of Spring", "雨水": "Rain Water", "惊蛰": "Awakening of Insects", "春分": "Spring Equinox", "清明": "Clear and Bright", "谷雨": "Grain Rain", "立夏": "Start of Summer", "小满": "Grain Buds", "芒种": "Grain in Ear", "夏至": "Summer Solstice", "小暑": "Minor Heat", "大暑": "Major Heat", "立秋": "Start of Autumn", "处暑": "End of Heat", "白露": "White Dew", "秋分": "Autumn Equinox", "寒露": "Cold Dew", "霜降": "Frost Descent", "立冬": "Start of Winter", "小雪": "Minor Snow", "大雪": "Major Snow"][name] ?? name
        }
        if language == .zhHant {
            return ["惊蛰": "驚蟄", "小满": "小滿", "芒种": "芒種", "处暑": "處暑"][name] ?? name
        }
        return name
    }

    /// Short label used inside the compact compass ring. It must follow the
    /// selected language instead of exposing the source Chinese hexagram name.
    public var localizedHexagramLabel: String? {
        guard let hexagramName = hexagramName else { return nil }
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return ["地雷复": "Fu", "地泽临": "Lin", "地天泰": "Tai", "雷天大壮": "Da Zhuang", "泽天夬": "Guai", "乾为天": "Qian", "天风姤": "Gou", "天山遁": "Dun", "天地否": "Pi", "风地观": "Guan", "山地剥": "Bo", "坤为地": "Kun"][hexagramName] ?? "Hexagram"
        case .zhHant:
            return hexagramName
                .replacingOccurrences(of: "复", with: "復")
                .replacingOccurrences(of: "泽", with: "澤")
                .replacingOccurrences(of: "壮", with: "壯")
                .replacingOccurrences(of: "遁", with: "遯")
                .replacingOccurrences(of: "观", with: "觀")
                .replacingOccurrences(of: "剥", with: "剝")
        default:
            return hexagramName
        }
    }
}

public class SolarTermsData {
    public static let shared = SolarTermsData()
    
    public let terms: [SolarTermItem]
    
    private init() {
        // 24节气在罗盘上以冬至在正北子山(0°)、夏至在正南午山(180°)顺时针分布，每节气 15°
        self.terms = [
            SolarTermItem(name: "冬至", angleCenter: 0.0, season: "冬", hexagramName: "地雷复", isMajorTerm: true),
            SolarTermItem(name: "小寒", angleCenter: 15.0, season: "冬", hexagramName: nil, isMajorTerm: false),
            SolarTermItem(name: "大寒", angleCenter: 30.0, season: "冬", hexagramName: "地泽临", isMajorTerm: false),
            SolarTermItem(name: "立春", angleCenter: 45.0, season: "春", hexagramName: "地天泰", isMajorTerm: false),
            SolarTermItem(name: "雨水", angleCenter: 60.0, season: "春", hexagramName: nil, isMajorTerm: false),
            SolarTermItem(name: "惊蛰", angleCenter: 75.0, season: "春", hexagramName: "雷天大壮", isMajorTerm: false),
            SolarTermItem(name: "春分", angleCenter: 90.0, season: "春", hexagramName: nil, isMajorTerm: true),
            SolarTermItem(name: "清明", angleCenter: 105.0, season: "春", hexagramName: "泽天夬", isMajorTerm: false),
            SolarTermItem(name: "谷雨", angleCenter: 120.0, season: "春", hexagramName: nil, isMajorTerm: false),
            SolarTermItem(name: "立夏", angleCenter: 135.0, season: "夏", hexagramName: "乾为天", isMajorTerm: false),
            SolarTermItem(name: "小满", angleCenter: 150.0, season: "夏", hexagramName: nil, isMajorTerm: false),
            SolarTermItem(name: "芒种", angleCenter: 165.0, season: "夏", hexagramName: "天风姤", isMajorTerm: false),
            SolarTermItem(name: "夏至", angleCenter: 180.0, season: "夏", hexagramName: nil, isMajorTerm: true),
            SolarTermItem(name: "小暑", angleCenter: 195.0, season: "夏", hexagramName: "天山遁", isMajorTerm: false),
            SolarTermItem(name: "大暑", angleCenter: 210.0, season: "夏", hexagramName: nil, isMajorTerm: false),
            SolarTermItem(name: "立秋", angleCenter: 225.0, season: "秋", hexagramName: "天地否", isMajorTerm: false),
            SolarTermItem(name: "处暑", angleCenter: 240.0, season: "秋", hexagramName: nil, isMajorTerm: false),
            SolarTermItem(name: "白露", angleCenter: 255.0, season: "秋", hexagramName: "风地观", isMajorTerm: false),
            SolarTermItem(name: "秋分", angleCenter: 270.0, season: "秋", hexagramName: nil, isMajorTerm: true),
            SolarTermItem(name: "寒露", angleCenter: 285.0, season: "秋", hexagramName: "山地剥", isMajorTerm: false),
            SolarTermItem(name: "霜降", angleCenter: 300.0, season: "秋", hexagramName: nil, isMajorTerm: false),
            SolarTermItem(name: "立冬", angleCenter: 315.0, season: "冬", hexagramName: "坤为地", isMajorTerm: false),
            SolarTermItem(name: "小雪", angleCenter: 330.0, season: "冬", hexagramName: nil, isMajorTerm: false),
            SolarTermItem(name: "大雪", angleCenter: 345.0, season: "冬", hexagramName: nil, isMajorTerm: false)
        ]
    }
}
