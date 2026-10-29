import Foundation
import CoreGraphics

// MARK: - 基础坐向与方位定义

public enum Direction8: String, CaseIterable, Codable {
    case north = "正北"
    case northeast = "东北"
    case east = "正东"
    case southeast = "东南"
    case south = "正南"
    case southwest = "西南"
    case west = "正西"
    case northwest = "西北"
    
    public var localizedName: String {
        switch self {
        case .north: return LocalizationManager.shared.t("dir_n")
        case .northeast: return LocalizationManager.shared.t("dir_ne")
        case .east: return LocalizationManager.shared.t("dir_e")
        case .southeast: return LocalizationManager.shared.t("dir_se")
        case .south: return LocalizationManager.shared.t("dir_s")
        case .southwest: return LocalizationManager.shared.t("dir_sw")
        case .west: return LocalizationManager.shared.t("dir_w")
        case .northwest: return LocalizationManager.shared.t("dir_nw")
        }
    }
    
    public var guaName: String {
        switch self {
        case .north: return "坎一宫"
        case .southwest: return "坤二宫"
        case .east: return "震三宫"
        case .southeast: return "巽四宫"
        case .northwest: return "乾六宫"
        case .west: return "兑七宫"
        case .northeast: return "艮八宫"
        case .south: return "离九宫"
        }
    }
    
    public var localizedGuaName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en, .id:
            switch self {
            case .north: return "Kan 1st Palace"
            case .southwest: return "Kun 2nd Palace"
            case .east: return "Zhen 3rd Palace"
            case .southeast: return "Xun 4th Palace"
            case .northwest: return "Qian 6th Palace"
            case .west: return "Dui 7th Palace"
            case .northeast: return "Gen 8th Palace"
            case .south: return "Li 9th Palace"
            }
        case .ja:
            switch self {
            case .north: return "坎一宮"
            case .southwest: return "坤二宮"
            case .east: return "震三宮"
            case .southeast: return "巽四宮"
            case .northwest: return "乾六宮"
            case .west: return "兌七宮"
            case .northeast: return "艮八宮"
            case .south: return "離九宮"
            }
        case .ko:
            switch self {
            case .north: return "감1궁"
            case .southwest: return "곤2궁"
            case .east: return "진3궁"
            case .southeast: return "손4궁"
            case .northwest: return "건6궁"
            case .west: return "태7궁"
            case .northeast: return "간8궁"
            case .south: return "이9궁"
            }
        case .vi:
            switch self {
            case .north: return "Cung Khảm 1"
            case .southwest: return "Cung Khôn 2"
            case .east: return "Cung Chấn 3"
            case .southeast: return "Cung Tốn 4"
            case .northwest: return "Cung Càn 6"
            case .west: return "Cung Đoài 7"
            case .northeast: return "Cung Cấn 8"
            case .south: return "Cung Ly 9"
            }
        case .th:
            switch self {
            case .north: return "วังขั่น 1"
            case .southwest: return "วังคุน 2"
            case .east: return "วังเจิ้น 3"
            case .southeast: return "วังซวิ่น 4"
            case .northwest: return "วังเฉียน 6"
            case .west: return "วังตุ้ย 7"
            case .northeast: return "วังเกิ้น 8"
            case .south: return "วังหลี 9"
            }
        case .zhHant:
            switch self {
            case .north: return "坎一宮"
            case .southwest: return "坤二宮"
            case .east: return "震三宮"
            case .southeast: return "巽四宮"
            case .northwest: return "乾六宮"
            case .west: return "兌七宮"
            case .northeast: return "艮八宮"
            case .south: return "離九宮"
            }
        case .auto, .zhHans:
            return guaName
        }
    }
    
    public var element: String {
        switch self {
        case .north: return "水"
        case .southwest, .northeast: return "土"
        case .east, .southeast: return "木"
        case .northwest, .west: return "金"
        case .south: return "火"
        }
    }
    
    public var localizedElement: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch self {
            case .north: return "Water"
            case .southwest, .northeast: return "Earth"
            case .east, .southeast: return "Wood"
            case .northwest, .west: return "Metal"
            case .south: return "Fire"
            }
        case .id:
            switch self {
            case .north: return "Air"
            case .southwest, .northeast: return "Tanah"
            case .east, .southeast: return "Kayu"
            case .northwest, .west: return "Logam"
            case .south: return "Api"
            }
        case .ko:
            switch self {
            case .north: return "수"
            case .southwest, .northeast: return "토"
            case .east, .southeast: return "목"
            case .northwest, .west: return "금"
            case .south: return "화"
            }
        case .vi:
            switch self {
            case .north: return "Thủy"
            case .southwest, .northeast: return "Thổ"
            case .east, .southeast: return "Mộc"
            case .northwest, .west: return "Kim"
            case .south: return "Hỏa"
            }
        case .th:
            switch self {
            case .north: return "น้ำ"
            case .southwest, .northeast: return "ดิน"
            case .east, .southeast: return "ไม้"
            case .northwest, .west: return "ทอง"
            case .south: return "ไฟ"
            }
        default:
            return element
        }
    }
}

// MARK: - 二十四山数据模型

public struct Mountain24Item: Identifiable, Codable {
    public let id: Int
    public let name: String
    public let pinyin: String
    public let angleCenter: Double
    public let angleStart: Double
    public let angleEnd: Double
    public let element: String
    public let palace: String // 八宫归属
    public let yuan: String   // 天元龙、地元龙、人元龙
    public let polarity: Int  // 阴阳性：+1 为阳，-1 为阴
    
    public init(id: Int, name: String, pinyin: String, angleCenter: Double, element: String, palace: String, yuan: String, polarity: Int) {
        self.id = id
        self.name = name
        self.pinyin = pinyin
        self.angleCenter = angleCenter
        self.angleStart = (angleCenter - 7.5 + 360.0).truncatingRemainder(dividingBy: 360.0)
        self.angleEnd = (angleCenter + 7.5).truncatingRemainder(dividingBy: 360.0)
        self.element = element
        self.palace = palace
        self.yuan = yuan
        self.polarity = polarity
    }
    public var isCardinalOrCorner: Bool {
        return angleCenter.truncatingRemainder(dividingBy: 45.0) == 0.0
    }
    public var centerAngle: Double { angleCenter }
    public var startAngle: Double { angleStart }
    public var endAngle: Double { angleEnd }
    public var subIndex: Int { id }
    public var post: String { palace }
    
    public var localizedName: String {
        let language = LocalizationManager.shared.effectiveLanguage
        switch language {
        case .en, .id:
            return pinyin
        case .ja:
            return name.replacingOccurrences(of: "兑", with: "兌")
                .replacingOccurrences(of: "离", with: "離")
        case .ko:
            let koNames = ["壬": "임", "子": "자", "癸": "계", "丑": "축", "艮": "간", "寅": "인", "甲": "갑", "卯": "묘", "乙": "을", "辰": "진", "巽": "손", "巳": "사", "丙": "병", "午": "오", "丁": "정", "未": "미", "坤": "곤", "申": "신", "庚": "경", "酉": "유", "辛": "신", "戌": "술", "乾": "건", "亥": "해"]
            return koNames[name] ?? name
        case .vi:
            let viNames = ["壬": "Nhâm", "子": "Tý", "癸": "Quý", "丑": "Sửu", "艮": "Cấn", "寅": "Dần", "甲": "Giáp", "卯": "Mão", "乙": "Ất", "辰": "Thìn", "巽": "Tốn", "巳": "Tỵ", "丙": "Bính", "午": "Ngọ", "丁": "Đinh", "未": "Mùi", "坤": "Khôn", "申": "Thân", "庚": "Canh", "酉": "Dậu", "辛": "Tân", "戌": "Tuất", "乾": "Càn", "亥": "Hợi"]
            return viNames[name] ?? name
        case .th:
            let thNames = ["壬": "เหริน", "子": "จื่อ", "癸": "กุ่ย", "丑": "โฉ่ว", "艮": "เกิ้น", "寅": "หยิน", "甲": "เจี่ย", "卯": "เหมา", "乙": "อี้", "辰": "เฉิน", "巽": "ซวิ่น", "巳": "ซื่อ", "丙": "ปิ่ง", "午": "อู่", "丁": "ติง", "未": "เว่ย", "坤": "คุน", "申": "เซิน", "庚": "เกิง", "酉": "โหย่ว", "辛": "ซิน", "戌": "ซวี", "乾": "เฉียน", "亥": "ฮ่าย"]
            return thNames[name] ?? name
        case .zhHant:
            return name.replacingOccurrences(of: "兑", with: "兌")
                .replacingOccurrences(of: "离", with: "離")
        case .auto, .zhHans:
            return name
        }
    }
    
    public var localizedPalace: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en, .id:
            let enPalaces = ["坎": "Kan", "坤": "Kun", "震": "Zhen", "巽": "Xun", "乾": "Qian", "兑": "Dui", "艮": "Gen", "离": "Li"]
            return enPalaces[palace] ?? palace
        case .ja:
            let jaPalaces = ["坎": "坎", "坤": "坤", "震": "震", "巽": "巽", "乾": "乾", "兑": "兌", "艮": "艮", "离": "離"]
            return jaPalaces[palace] ?? palace
        case .ko:
            let koPalaces = ["坎": "감", "坤": "곤", "震": "진", "巽": "손", "乾": "건", "兑": "태", "艮": "간", "离": "이"]
            return koPalaces[palace] ?? palace
        case .vi:
            let viPalaces = ["坎": "Khảm", "坤": "Khôn", "震": "Chấn", "巽": "Tốn", "乾": "Càn", "兑": "Đoài", "艮": "Cấn", "离": "Ly"]
            return viPalaces[palace] ?? palace
        case .th:
            let thPalaces = ["坎": "ขั่น", "坤": "คุน", "震": "เจิ้น", "巽": "ซวิ่น", "乾": "เฉียน", "兑": "ตุ้ย", "艮": "เกิ้น", "离": "หลี"]
            return thPalaces[palace] ?? palace
        case .zhHant:
            return ["兑": "兌", "离": "離"][palace] ?? palace
        case .auto, .zhHans:
            return palace
        }
    }

    public var localizedElement: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch element {
            case "水": return "Water"
            case "木": return "Wood"
            case "火": return "Fire"
            case "土": return "Earth"
            case "金": return "Metal"
            default: return element
            }
        case .id:
            switch element {
            case "水": return "Air"
            case "木": return "Kayu"
            case "火": return "Api"
            case "土": return "Tanah"
            case "金": return "Logam"
            default: return element
            }
        case .ko:
            switch element {
            case "水": return "수"
            case "木": return "목"
            case "火": return "화"
            case "土": return "토"
            case "金": return "금"
            default: return element
            }
        case .vi:
            switch element {
            case "水": return "Thủy"
            case "木": return "Mộc"
            case "火": return "Hỏa"
            case "土": return "Thổ"
            case "金": return "Kim"
            default: return element
            }
        case .th:
            switch element {
            case "水": return "น้ำ"
            case "木": return "ไม้"
            case "火": return "ไฟ"
            case "土": return "ดิน"
            case "金": return "ทอง"
            default: return element
            }
        default:
            return element
        }
    }
}

public typealias Mountain24 = Mountain24Item

// MARK: - 坐向全景分析结果

public struct CompassHeadingState {
    public var heading: Double = 0.0          // 当前正北指向角度 (0 ~ 359.9°)
    public var trueHeading: Double = 0.0      // 真北指向
    public var sittingAngle: Double = 180.0   // 坐山角度
    public var facingAngle: Double = 0.0      // 向山角度
    
    public var facingMountain: Mountain24Item // 向山
    public var sittingMountain: Mountain24Item// 坐山
    
    public var isJianXiang: Bool = false       // 是否兼向 (偏差 > 3 度)
    public var jianXiangDegree: Double = 0.0  // 偏度
    public var fenJinDesc: String = ""        // 分金描述 (如: 丁巳丁亥分金)
    
    public var pitch: Double = 0.0            // 俯仰角
    public var roll: Double = 0.0             // 横滚角
    public var isLevel: Bool = true           // 是否水平 (< 2°)
    
    public init(
        heading: Double = 0.0,
        trueHeading: Double = 0.0,
        sittingAngle: Double = 180.0,
        facingAngle: Double = 0.0,
        facingMountain: Mountain24Item,
        sittingMountain: Mountain24Item,
        isJianXiang: Bool = false,
        jianXiangDegree: Double = 0.0,
        fenJinDesc: String = "",
        pitch: Double = 0.0,
        roll: Double = 0.0,
        isLevel: Bool = true
    ) {
        self.heading = heading
        self.trueHeading = trueHeading
        self.sittingAngle = sittingAngle
        self.facingAngle = facingAngle
        self.facingMountain = facingMountain
        self.sittingMountain = sittingMountain
        self.isJianXiang = isJianXiang
        self.jianXiangDegree = jianXiangDegree
        self.fenJinDesc = fenJinDesc
        self.pitch = pitch
        self.roll = roll
        self.isLevel = isLevel
    }
}

public final class Mountain24Data {
    public static let shared = Mountain24Data()
    
    public let mountains: [Mountain24Item] = [
        Mountain24Item(id: 0,  name: "壬", pinyin: "Ren",  angleCenter: 345.0, element: "水", palace: "坎", yuan: "地元龙", polarity: +1),
        Mountain24Item(id: 1,  name: "子", pinyin: "Zi",   angleCenter: 0.0,   element: "水", palace: "坎", yuan: "天元龙", polarity: -1),
        Mountain24Item(id: 2,  name: "癸", pinyin: "Gui",  angleCenter: 15.0,  element: "水", palace: "坎", yuan: "人元龙", polarity: -1),
        Mountain24Item(id: 3,  name: "丑", pinyin: "Chou", angleCenter: 30.0,  element: "土", palace: "艮", yuan: "地元龙", polarity: -1),
        Mountain24Item(id: 4,  name: "艮", pinyin: "Gen",  angleCenter: 45.0,  element: "土", palace: "艮", yuan: "天元龙", polarity: +1),
        Mountain24Item(id: 5,  name: "寅", pinyin: "Yin",  angleCenter: 60.0,  element: "木", palace: "艮", yuan: "人元龙", polarity: +1),
        Mountain24Item(id: 6,  name: "甲", pinyin: "Jia",  angleCenter: 75.0,  element: "木", palace: "震", yuan: "地元龙", polarity: +1),
        Mountain24Item(id: 7,  name: "卯", pinyin: "Mao",  angleCenter: 90.0,  element: "木", palace: "震", yuan: "天元龙", polarity: -1),
        Mountain24Item(id: 8,  name: "乙", pinyin: "Yi",   angleCenter: 105.0, element: "木", palace: "震", yuan: "人元龙", polarity: -1),
        Mountain24Item(id: 9,  name: "辰", pinyin: "Chen", angleCenter: 120.0, element: "土", palace: "巽", yuan: "地元龙", polarity: -1),
        Mountain24Item(id: 10, name: "巽", pinyin: "Xun",  angleCenter: 135.0, element: "木", palace: "巽", yuan: "天元龙", polarity: +1),
        Mountain24Item(id: 11, name: "巳", pinyin: "Si",   angleCenter: 150.0, element: "火", palace: "巽", yuan: "人元龙", polarity: +1),
        Mountain24Item(id: 12, name: "丙", pinyin: "Bing", angleCenter: 165.0, element: "火", palace: "离", yuan: "地元龙", polarity: +1),
        Mountain24Item(id: 13, name: "午", pinyin: "Wu",   angleCenter: 180.0, element: "火", palace: "离", yuan: "天元龙", polarity: -1),
        Mountain24Item(id: 14, name: "丁", pinyin: "Ding", angleCenter: 195.0, element: "火", palace: "离", yuan: "人元龙", polarity: -1),
        Mountain24Item(id: 15, name: "未", pinyin: "Wei",  angleCenter: 210.0, element: "土", palace: "坤", yuan: "地元龙", polarity: -1),
        Mountain24Item(id: 16, name: "坤", pinyin: "Kun",  angleCenter: 225.0, element: "土", palace: "坤", yuan: "天元龙", polarity: +1),
        Mountain24Item(id: 17, name: "申", pinyin: "Shen", angleCenter: 240.0, element: "金", palace: "坤", yuan: "人元龙", polarity: +1),
        Mountain24Item(id: 18, name: "庚", pinyin: "Geng", angleCenter: 255.0, element: "金", palace: "兑", yuan: "地元龙", polarity: +1),
        Mountain24Item(id: 19, name: "酉", pinyin: "You",  angleCenter: 270.0, element: "金", palace: "兑", yuan: "天元龙", polarity: -1),
        Mountain24Item(id: 20, name: "辛", pinyin: "Xin",  angleCenter: 285.0, element: "金", palace: "兑", yuan: "人元龙", polarity: -1),
        Mountain24Item(id: 21, name: "戌", pinyin: "Xu",   angleCenter: 300.0, element: "土", palace: "乾", yuan: "地元龙", polarity: -1),
        Mountain24Item(id: 22, name: "乾", pinyin: "Qian", angleCenter: 315.0, element: "金", palace: "乾", yuan: "天元龙", polarity: +1),
        Mountain24Item(id: 23, name: "亥", pinyin: "Hai",  angleCenter: 330.0, element: "水", palace: "乾", yuan: "人元龙", polarity: +1)
    ]
    
    public func mountain(for angle: Double) -> Mountain24Item {
        let norm = (angle.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        for m in mountains {
            if m.name == "子" {
                if norm >= 352.5 || norm < 7.5 { return m }
            } else {
                if norm >= (m.angleCenter - 7.5) && norm < (m.angleCenter + 7.5) {
                    return m
                }
            }
        }
        return mountains[1] // 默认子山
    }
    
    public func resolveHeadingState(heading: Double, pitch: Double = 0.0, roll: Double = 0.0, trueHeading: Double? = nil) -> CompassHeadingState {
        let normHeading = (heading.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let facingAngle = normHeading
        let sittingAngle = (normHeading + 180.0).truncatingRemainder(dividingBy: 360.0)
        
        let facingM = mountain(for: facingAngle)
        let sittingM = mountain(for: sittingAngle)
        
        // 兼向判定：距离山中心线绝对值 > 3度即为兼向 (替卦)，<=3度为下卦正向
        var diff = facingAngle - facingM.angleCenter
        if diff > 180 { diff -= 360 }
        if diff < -180 { diff += 360 }
        let jianDeg = abs(diff)
        let isJian = jianDeg > 3.0
        
        let lang = LocalizationManager.shared.effectiveLanguage
        let neighborAngle = diff > 0 ? (facingM.angleCenter + 15) : (facingM.angleCenter - 15)
        let neighborM = mountain(for: neighborAngle)
        let degStr = String(format: "%.1f", jianDeg)
        let fenJin: String
        
        switch lang {
        case .en:
            if isJian {
                fenJin = "Sit \(sittingM.pinyin) Face \(facingM.pinyin) · Sub \(neighborM.pinyin) (offset \(degStr)°)"
            } else {
                fenJin = "Sit \(sittingM.pinyin) Face \(facingM.pinyin) · Direct Alignment"
            }
        case .id:
            if isJian {
                fenJin = "Duduk \(sittingM.pinyin) Hadap \(facingM.pinyin) · Condong \(neighborM.pinyin) (deviasi \(degStr)°)"
            } else {
                fenJin = "Duduk \(sittingM.pinyin) Hadap \(facingM.pinyin) · Arah Lurus"
            }
        case .ja:
            if isJian {
                fenJin = "\(sittingM.localizedName)山\(facingM.localizedName)向 兼 \(neighborM.localizedName) (偏\(degStr)°)"
            } else {
                fenJin = "\(sittingM.localizedName)山\(facingM.localizedName)向 正針下卦"
            }
        case .ko:
            if isJian {
                fenJin = "\(sittingM.localizedName)산\(facingM.localizedName)향 겸 \(neighborM.localizedName) (편\(degStr)°)"
            } else {
                fenJin = "\(sittingM.localizedName)산\(facingM.localizedName)향 정침하괘"
            }
        case .vi:
            if isJian {
                fenJin = "Tọa \(sittingM.localizedName) Hướng \(facingM.localizedName) · Kiêm \(neighborM.localizedName) (lệch \(degStr)°)"
            } else {
                fenJin = "Tọa \(sittingM.localizedName) Hướng \(facingM.localizedName) · Chính Châm"
            }
        case .th:
            if isJian {
                fenJin = "นั่ง \(sittingM.localizedName) หัน \(facingM.localizedName) · เอียง \(neighborM.localizedName) (เบี่ยง \(degStr)°)"
            } else {
                fenJin = "นั่ง \(sittingM.localizedName) หัน \(facingM.localizedName) · ทิศตรง"
            }
        case .zhHant:
            if isJian {
                fenJin = "\(sittingM.localizedName)山\(facingM.localizedName)向 兼 \(neighborM.localizedName) (偏\(degStr)°)"
            } else {
                fenJin = "\(sittingM.localizedName)山\(facingM.localizedName)向 正針下卦"
            }
        case .auto, .zhHans:
            if isJian {
                fenJin = "\(sittingM.name)山\(facingM.name)向 兼 \(neighborM.name) (偏\(degStr)°)"
            } else {
                fenJin = "\(sittingM.name)山\(facingM.name)向 正针下卦"
            }
        }
        
        let isLevel = abs(pitch) < 2.5 && abs(roll) < 2.5
        
        return CompassHeadingState(
            heading: normHeading,
            trueHeading: trueHeading.map { ($0.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0) } ?? normHeading,
            sittingAngle: sittingAngle,
            facingAngle: facingAngle,
            facingMountain: facingM,
            sittingMountain: sittingM,
            isJianXiang: isJian,
            jianXiangDegree: jianDeg,
            fenJinDesc: fenJin,
            pitch: pitch,
            roll: roll,
            isLevel: isLevel
        )
    }
}
