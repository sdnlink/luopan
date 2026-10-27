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
    
    public var element: String {
        switch self {
        case .north: return "水"
        case .southwest, .northeast: return "土"
        case .east, .southeast: return "木"
        case .northwest, .west: return "金"
        case .south: return "火"
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
}

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
    
    public func resolveHeadingState(heading: Double, pitch: Double = 0.0, roll: Double = 0.0) -> CompassHeadingState {
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
        
        var fenJin = "\(sittingM.name)山\(facingM.name)向"
        if isJian {
            let neighborAngle = diff > 0 ? (facingM.angleCenter + 15) : (facingM.angleCenter - 15)
            let neighborM = mountain(for: neighborAngle)
            fenJin += " 兼 \(neighborM.name) (偏\(String(format: "%.1f", jianDeg))°)"
        } else {
            fenJin += " 正针下卦"
        }
        
        let isLevel = abs(pitch) < 2.5 && abs(roll) < 2.5
        
        return CompassHeadingState(
            heading: normHeading,
            trueHeading: normHeading,
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
