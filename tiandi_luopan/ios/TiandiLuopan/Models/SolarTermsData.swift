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
        switch language {
        case .en:
            return ["冬至": "Winter Solstice", "小寒": "Minor Cold", "大寒": "Major Cold", "立春": "Start of Spring", "雨水": "Rain Water", "惊蛰": "Awakening of Insects", "春分": "Spring Equinox", "清明": "Clear and Bright", "谷雨": "Grain Rain", "立夏": "Start of Summer", "小满": "Grain Buds", "芒种": "Grain in Ear", "夏至": "Summer Solstice", "小暑": "Minor Heat", "大暑": "Major Heat", "立秋": "Start of Autumn", "处暑": "End of Heat", "白露": "White Dew", "秋分": "Autumn Equinox", "寒露": "Cold Dew", "霜降": "Frost Descent", "立冬": "Start of Winter", "小雪": "Minor Snow", "大雪": "Major Snow"][name] ?? name
        case .id:
            return ["冬至": "Solstis Dingin", "小寒": "Dingin Kecil", "大寒": "Dingin Hebat", "立春": "Awal Semi", "雨水": "Air Hujan", "惊蛰": "Serangga Bangkit", "春分": "Ekuinoks Semi", "清明": "Cerah Terang", "谷雨": "Hujan Gandum", "立夏": "Awal Panas", "小满": "Tunas Gandum", "芒种": "Gandum Bertunas", "夏至": "Solstis Panas", "小暑": "Panas Kecil", "大暑": "Panas Hebat", "立秋": "Awal Gugur", "处暑": "Akhir Panas", "白露": "Embun Putih", "秋分": "Ekuinoks Gugur", "寒露": "Embun Dingin", "霜降": "Turun Embun Beku", "立冬": "Awal Dingin", "小雪": "Salju Kecil", "大雪": "Salju Lebat"][name] ?? name
        case .ja:
            return ["冬至": "冬至", "小寒": "小寒", "大寒": "大寒", "立春": "立春", "雨水": "雨水", "惊蛰": "啓蟄", "春分": "春分", "清明": "清明", "谷雨": "穀雨", "立夏": "立夏", "小满": "小満", "芒种": "芒種", "夏至": "夏至", "小暑": "小暑", "大暑": "大暑", "立秋": "立秋", "处暑": "処暑", "白露": "白露", "秋分": "秋分", "寒露": "寒露", "霜降": "霜降", "立冬": "立冬", "小雪": "小雪", "大雪": "大雪"][name] ?? name
        case .ko:
            return ["冬至": "동지", "小寒": "소한", "大寒": "대한", "立春": "입춘", "雨水": "우수", "惊蛰": "경칩", "春分": "춘분", "清明": "청명", "谷雨": "곡우", "立夏": "입하", "小满": "소만", "芒种": "망종", "夏至": "하지", "小暑": "소서", "大暑": "대서", "立秋": "입추", "处暑": "처서", "白露": "백로", "秋分": "추분", "寒露": "한로", "霜降": "상강", "立冬": "입동", "小雪": "소설", "大雪": "대설"][name] ?? name
        case .vi:
            return ["冬至": "Đông chí", "小寒": "Tiểu hàn", "大寒": "Đại hàn", "立春": "Lập xuân", "雨水": "Vũ thủy", "惊蛰": "Kinh trập", "春分": "Xuân phân", "清明": "Thanh minh", "谷雨": "Cốc vũ", "立夏": "Lập hạ", "小满": "Tiểu mãn", "芒种": "Mang chủng", "夏至": "Hạ chí", "小暑": "Tiểu thử", "大暑": "Đại thử", "立秋": "Lập thu", "处暑": "Xử thử", "白露": "Bạch lộ", "秋分": "Thu phân", "寒露": "Hàn lộ", "霜降": "Sương giáng", "立冬": "Lập đông", "小雪": "Tiểu tuyết", "大雪": "Đại tuyết"][name] ?? name
        case .th:
            return ["冬至": "เหมายัน", "小寒": "เสี่ยวหาน", "大寒": "ต้าหาน", "立春": "ลี่ชุน", "雨水": "อวี่สุ่ย", "惊蛰": "จิงเจ๋อ", "春分": "ชุนเฟิน", "清明": "ชิงหมิง", "谷雨": "กู่ยวี่", "立夏": "ลี่เซี่ย", "小满": "เสี่ยวหม่าน", "芒种": "หมางจ้ง", "夏至": "ครีษมายัน", "小暑": "เสี่ยวสู่", "大暑": "ต้าสู่", "立秋": "ลี่ชิว", "处暑": "ชู่สู่", "白露": "ไป๋ลู่", "秋分": "ศารทวิษุวัต", "寒露": "หานลู่", "霜降": "ซวงเจี้ยง", "立冬": "ลี่ตง", "小雪": "เสี่ยวเสวี่ย", "大雪": "ต้าเสวี่ย"][name] ?? name
        case .zhHant:
            return ["惊蛰": "驚蟄", "小满": "小滿", "芒种": "芒種", "处暑": "處暑"][name] ?? name
        case .auto, .zhHans:
            return name
        }
    }

    /// Short label used inside the compact compass ring.
    public var localizedHexagramLabel: String? {
        guard let hexagramName = hexagramName else { return nil }
        switch LocalizationManager.shared.effectiveLanguage {
        case .en, .id:
            return ["地雷复": "Fu", "地泽临": "Lin", "地天泰": "Tai", "雷天大壮": "Da Zhuang", "泽天夬": "Guai", "乾为天": "Qian", "天风姤": "Gou", "天山遁": "Dun", "天地否": "Pi", "风地观": "Guan", "山地剥": "Bo", "坤为地": "Kun"][hexagramName] ?? "Hex"
        case .ja:
            return ["地雷复": "復", "地泽临": "臨", "地天泰": "泰", "雷天大壮": "大壮", "泽天夬": "夬", "乾为天": "乾", "天风姤": "姤", "天山遁": "遯", "天地否": "否", "风地观": "観", "山地剥": "剥", "坤为地": "坤"][hexagramName] ?? hexagramName
        case .ko:
            return ["地雷复": "복", "地泽临": "임", "地天泰": "태", "雷天大壮": "대장", "泽天夬": "쾌", "乾为天": "건", "天风姤": "구", "天山遁": "둔", "天地否": "비", "风地观": "관", "山地剥": "박", "坤为地": "곤"][hexagramName] ?? hexagramName
        case .vi:
            return ["地雷复": "Phục", "地泽临": "Lâm", "地天泰": "Thái", "雷天大壮": "Đại Tráng", "泽天夬": "Quải", "乾为天": "Càn", "天风姤": "Cấu", "天山遁": "Độn", "天地否": "Bĩ", "风地观": "Quan", "山地剥": "Bác", "坤为地": "Khôn"][hexagramName] ?? hexagramName
        case .th:
            return ["地雷复": "ฟู่", "地泽临": "หลิน", "地天泰": "ไท่", "雷天大壮": "ต้าจ้วง", "泽天夬": "กว้าย", "乾为天": "เฉียน", "天风姤": "โก้ว", "天山遁": "ตวิ้น", "天地否": "พี", "风地观": "กวน", "山地剥": "โป", "坤为地": "คุน"][hexagramName] ?? hexagramName
        case .zhHant:
            return hexagramName
                .replacingOccurrences(of: "复", with: "復")
                .replacingOccurrences(of: "泽", with: "澤")
                .replacingOccurrences(of: "壮", with: "壯")
                .replacingOccurrences(of: "遁", with: "遯")
                .replacingOccurrences(of: "观", with: "觀")
                .replacingOccurrences(of: "剥", with: "剝")
        case .auto, .zhHans:
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
