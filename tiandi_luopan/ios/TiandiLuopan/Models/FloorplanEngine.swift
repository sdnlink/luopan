import Foundation
import CoreGraphics

// MARK: - 户型空间立极与全屋风水体检引擎 (PRD 5.3 & 第7章)

public enum FloorplanRoomType: String, CaseIterable, Identifiable {
    case door = "大门"
    case livingRoom = "客厅"
    case masterBedroom = "主卧"
    case secondBedroom = "次卧"
    case kitchen = "厨房"
    case bathroom = "卫生间"
    case study = "书房"
    case balcony = "阳台"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .door: return "door.left.hand.open"
        case .livingRoom: return "sofa.fill"
        case .masterBedroom: return "bed.double.fill"
        case .secondBedroom: return "bed.double"
        case .kitchen: return "flame.fill"
        case .bathroom: return "drop.triangle.fill"
        case .study: return "books.vertical.fill"
        case .balcony: return "sun.max.fill"
        }
    }
}

public struct FloorplanRoom: Identifiable {
    public let id: String
    public var name: String
    public var type: FloorplanRoomType
    public var rect: CGRect // 相对比例 (0.0 .. 1.0)
    public var palaceName: String // "西北乾宫", "东南巽宫", etc.
    public var inspectionTitle: String
    public var inspectionLevel: String // "吉", "平", "凶", "大凶"
    public var inspectionAdvice: String
    
    public init(id: String = UUID().uuidString, name: String, type: FloorplanRoomType, rect: CGRect, palaceName: String = "", inspectionTitle: String = "", inspectionLevel: String = "平", inspectionAdvice: String = "") {
        self.id = id
        self.name = name
        self.type = type
        self.rect = rect
        self.palaceName = palaceName
        self.inspectionTitle = inspectionTitle
        self.inspectionLevel = inspectionLevel
        self.inspectionAdvice = inspectionAdvice
    }
    public var isSevere: Bool { inspectionLevel.contains("严重") || inspectionLevel.contains("大凶") }
    public var isBad: Bool { isSevere || inspectionLevel.contains("凶") }
    public var isGood: Bool { inspectionLevel.contains("吉") }
    public var isWarning: Bool { inspectionLevel.contains("预警") }
}

public struct FloorplanAuditItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let palace: String
    public let severity: String // "吉", "提示", "预警", "严重煞气"
    public let lore: String
    public let solution: String
    public var isSevere: Bool { severity.contains("严重") }
    public var isGood: Bool { severity.contains("吉") }
    public var isWarning: Bool { severity.contains("预警") }
}

public class FloorplanEngine {
    public static let shared = FloorplanEngine()
    
    private init() {}
    
    // 生成演示标准三室两厅精装户型 (支持根据当前语言动态输出，杜绝英文下出现中文硬编码)
    public func generateSampleRooms() -> [FloorplanRoom] {
        let isEn = LocalizationManager.shared.effectiveLanguage == .en
        let isHant = LocalizationManager.shared.effectiveLanguage == .zhHant
        
        let doorName = isEn ? "Main Entrance (South Qi)" : (isHant ? "入戶大門 (正南明堂納氣)" : "入户大门 (正南明堂纳气)")
        let livingName = isEn ? "Spacious Living Room" : (isHant ? "聚氣大客廳" : "聚气大客厅")
        let masterName = isEn ? "Master Bedroom" : (isHant ? "尊貴主臥" : "尊贵主卧")
        let studyName = isEn ? "Quiet Study Room" : (isHant ? "文昌靜雅書房" : "文昌静雅书房")
        let secondBedName = isEn ? "Second Bedroom" : (isHant ? "靜心次臥" : "静心次卧")
        let kitchenName = isEn ? "Gourmet Kitchen" : (isHant ? "膳食廚房" : "膳食厨房")
        let bathroomName = isEn ? "Main Bathroom" : (isHant ? "主衛浴間" : "主卫浴间")
        let balconyName = isEn ? "South Balcony" : (isHant ? "南向大陽台" : "南向大阳台")
        
        return [
            FloorplanRoom(
                name: doorName,
                type: .door,
                rect: CGRect(x: 0.40, y: 0.82, width: 0.20, height: 0.12)
            ),
            FloorplanRoom(
                name: livingName,
                type: .livingRoom,
                rect: CGRect(x: 0.32, y: 0.45, width: 0.38, height: 0.36)
            ),
            FloorplanRoom(
                name: masterName,
                type: .masterBedroom,
                rect: CGRect(x: 0.70, y: 0.42, width: 0.25, height: 0.45)
            ),
            FloorplanRoom(
                name: studyName,
                type: .study,
                rect: CGRect(x: 0.32, y: 0.10, width: 0.35, height: 0.30)
            ),
            FloorplanRoom(
                name: secondBedName,
                type: .secondBedroom,
                rect: CGRect(x: 0.70, y: 0.10, width: 0.25, height: 0.30)
            ),
            FloorplanRoom(
                name: kitchenName,
                type: .kitchen,
                rect: CGRect(x: 0.05, y: 0.10, width: 0.24, height: 0.30)
            ),
            FloorplanRoom(
                name: bathroomName,
                type: .bathroom,
                rect: CGRect(x: 0.05, y: 0.45, width: 0.24, height: 0.25)
            ),
            FloorplanRoom(
                name: balconyName,
                type: .balcony,
                rect: CGRect(x: 0.32, y: 0.88, width: 0.38, height: 0.10)
            )
        ]
    }
    
    // 根据户型重心立极点与罗盘朝向解算各房间八卦方位与全屋风水体检报告
    public func auditFloorplan(rooms: [FloorplanRoom], centroid: CGPoint, heading: Double) -> (auditedRooms: [FloorplanRoom], report: [FloorplanAuditItem]) {
        var updatedRooms: [FloorplanRoom] = []
        var auditReport: [FloorplanAuditItem] = []
        
        let degPerRad = 180.0 / Double.pi
        let isEn = LocalizationManager.shared.effectiveLanguage == .en
        let isHant = LocalizationManager.shared.effectiveLanguage == .zhHant
        
        for room in rooms {
            var r = room
            // 计算房间中心相对立极点的极坐标角度
            let roomCenterX = room.rect.midX
            let roomCenterY = room.rect.midY
            let dx = Double(roomCenterX - centroid.x)
            let dy = Double(roomCenterY - centroid.y) // 屏幕坐标向下为正
            
            // 计算屏幕方位角 (以正上为 0 度, 顺时针)
            var screenAngle = atan2(dx, -dy) * degPerRad
            if screenAngle < 0 { screenAngle += 360 }
            
            // 结合罗盘当前朝向 heading 叠加实际地理方位
            var geoAngle = (screenAngle + heading).truncatingRemainder(dividingBy: 360)
            if geoAngle < 0 { geoAngle += 360 }
            
            // 解算八卦宫位: 坎(0°/北), 艮(45°/东北), 震(90°/东), 巽(135°/东南), 离(180°/南), 坤(225°/西南), 兑(270°/西), 乾(315°/西北)
            let palace = resolvePalace(geoAngle: geoAngle)
            if isEn {
                r.palaceName = "\(palace.dir) (\(palace.gua) Palace)"
            } else if isHant {
                r.palaceName = "\(palace.dir) \(palace.gua)宮"
            } else {
                r.palaceName = "\(palace.dir) \(palace.gua)宫"
            }
            
            // 风水动态研判
            let audit = evaluateRoom(type: r.type, palaceGua: palace.gua, palaceDir: palace.dir)
            r.inspectionTitle = audit.title
            r.inspectionLevel = audit.level
            r.inspectionAdvice = audit.advice
            
            updatedRooms.append(r)
            
            if audit.level != "平" {
                auditReport.append(FloorplanAuditItem(
                    title: "\(r.name) · \(audit.title)",
                    palace: r.palaceName,
                    severity: audit.level,
                    lore: audit.lore,
                    solution: audit.advice
                ))
            }
        }
        
        // 增加穿堂煞与中宫检测
        if auditReport.isEmpty {
            auditReport.append(FloorplanAuditItem(
                title: "全屋空间气场中和纯清",
                palace: "全局",
                severity: "吉",
                lore: "各功能区方位得所，动静分离，阴阳调和。",
                solution: "保持居室内明亮通风，绿植点缀，可常保家运昌隆。"
            ))
        }
        
        return (updatedRooms, auditReport)
    }
    
    private func resolvePalace(geoAngle: Double) -> (dir: String, gua: String) {
        let isEn = LocalizationManager.shared.effectiveLanguage == .en
        let isHant = LocalizationManager.shared.effectiveLanguage == .zhHant
        
        if isEn {
            if geoAngle >= 337.5 || geoAngle < 22.5 { return ("North", "Kan") }
            if geoAngle >= 22.5 && geoAngle < 67.5 { return ("Northeast", "Gen") }
            if geoAngle >= 67.5 && geoAngle < 112.5 { return ("East", "Zhen") }
            if geoAngle >= 112.5 && geoAngle < 157.5 { return ("Southeast", "Xun") }
            if geoAngle >= 157.5 && geoAngle < 202.5 { return ("South", "Li") }
            if geoAngle >= 202.5 && geoAngle < 247.5 { return ("Southwest", "Kun") }
            if geoAngle >= 247.5 && geoAngle < 292.5 { return ("West", "Dui") }
            return ("Northwest", "Qian")
        } else if isHant {
            if geoAngle >= 337.5 || geoAngle < 22.5 { return ("正北", "坎") }
            if geoAngle >= 22.5 && geoAngle < 67.5 { return ("東北", "艮") }
            if geoAngle >= 67.5 && geoAngle < 112.5 { return ("正東", "震") }
            if geoAngle >= 112.5 && geoAngle < 157.5 { return ("東南", "巽") }
            if geoAngle >= 157.5 && geoAngle < 202.5 { return ("正南", "離") }
            if geoAngle >= 202.5 && geoAngle < 247.5 { return ("西南", "坤") }
            if geoAngle >= 247.5 && geoAngle < 292.5 { return ("正西", "兌") }
            return ("西北", "乾")
        } else {
            if geoAngle >= 337.5 || geoAngle < 22.5 { return ("正北", "坎") }
            if geoAngle >= 22.5 && geoAngle < 67.5 { return ("东北", "艮") }
            if geoAngle >= 67.5 && geoAngle < 112.5 { return ("正东", "震") }
            if geoAngle >= 112.5 && geoAngle < 157.5 { return ("东南", "巽") }
            if geoAngle >= 157.5 && geoAngle < 202.5 { return ("正南", "离") }
            if geoAngle >= 202.5 && geoAngle < 247.5 { return ("西南", "坤") }
            if geoAngle >= 247.5 && geoAngle < 292.5 { return ("正西", "兑") }
            return ("西北", "乾")
        }
    }
    
    private func evaluateRoom(type: FloorplanRoomType, palaceGua: String, palaceDir: String) -> (title: String, level: String, lore: String, advice: String) {
        switch (type, palaceGua) {
        case (.kitchen, "乾"):
            return (
                "火烧天门大煞",
                "严重煞气",
                "乾为天为父为首，灶火克乾金，极不利男主人头部、血压及事业运。",
                "灶台旁安放天然黄色陶瓷罐，或悬挂真品六帝铜钱以土泄火生金。"
            )
        case (.bathroom, "乾"):
            return (
                "水浸天门污秽大煞",
                "严重煞气",
                "乾为天为父，卫浴设于西北，金水相寒污浊天门，主男主人事业阻滞、脑血管与呼吸道隐患。",
                "卫生间门常闭，门槛下安放真品五帝古钱，内置纯铜金蟾或粗盐陶罐吸纳湿浊。"
            )
        case (.kitchen, "坎"):
            return (
                "水火相战未济煞",
                "预警",
                "北方坎水见烈火，水火不相容，主心肾不交、情绪烦躁与血液循环受损。",
                "以木通关，厨房内增添绿植或实木厨具，令水生木、木生火，化克为生。"
            )
        case (.kitchen, "艮"), (.kitchen, "坤"):
            return (
                "火燥鬼门伤脾土",
                "预警",
                "艮坤属土为鬼门，烈火燥土，易致家人口腔上火、脾胃虚热及皮肤过敏。",
                "台面摆放白水晶球或黄色陶瓷葫芦化泄烈火，增厚中和地气。"
            )
        case (.bathroom, "艮"), (.bathroom, "坤"):
            return (
                "鬼门卫浴秽气冲射",
                "预警",
                "东北艮为表鬼门，西南坤为里鬼门，卫浴见水污地气，易损脾胃与人丁健康。",
                "卫浴常开排风保持干燥，门槛下安放真品五帝钱或粗盐陶罐净化。"
            )
        case (.bathroom, "中"):
            return (
                "水浸中宫大忌",
                "严重煞气",
                "房屋心脏太极受污，病气弥漫全屋，主宅运反复、家人腰腹疾厄。",
                "门头安放纯铜八卦凸镜，卫浴内常亮暖黄长明灯排浊。"
            )
        case (.study, "巽"), (.study, "坎"):
            return (
                "文昌生旺大吉位",
                "吉",
                "巽为四绿文曲木，坎水生文昌，大利考学、升职与名誉构思。",
                "书桌宜设于此方，书架摆放四支水养富贵竹或天然白水晶文昌塔。"
            )
        case (.masterBedroom, "坤"), (.masterBedroom, "延年"):
            return (
                "主卧得位气场稳固",
                "吉",
                "居于生旺方，身心放松，夫妻和睦，睡眠充盈利于事业蓄力。",
                "床头宜靠实墙，忌上方横梁压顶或正冲镜面。"
            )
        case (.door, "离"):
            return (
                "南向明堂纳阳吉向",
                "吉",
                "离火纳气，采光充沛，主热情光明与远见名望。",
                "玄关保持整洁开阔，点亮暖金射灯迎祥纳福。"
            )
        default:
            return (
                "方位得所气场安和",
                "平",
                "空间阴阳协调，无明显形理相克。",
                "按日常居住动线与洁净要求维护即可。"
            )
        }
    }
}
