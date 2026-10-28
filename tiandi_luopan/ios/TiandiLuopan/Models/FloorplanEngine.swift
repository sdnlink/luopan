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

    public var localizedName: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch self {
            case .door: return "Main Entrance"
            case .livingRoom: return "Living Room"
            case .masterBedroom: return "Master Bedroom"
            case .secondBedroom: return "Second Bedroom"
            case .kitchen: return "Kitchen"
            case .bathroom: return "Bathroom"
            case .study: return "Study"
            case .balcony: return "Balcony"
            }
        case .zhHant:
            switch self {
            case .door: return "入戶大門"
            case .livingRoom: return "客廳"
            case .masterBedroom: return "主臥"
            case .secondBedroom: return "次臥"
            case .kitchen: return "廚房"
            case .bathroom: return "衛生間"
            case .study: return "書房"
            case .balcony: return "陽台"
            }
        case .zhHans, .auto:
            switch self {
            case .door: return "入户大门"
            case .livingRoom: return "客厅"
            case .masterBedroom: return "主卧"
            case .secondBedroom: return "次卧"
            case .kitchen: return "厨房"
            case .bathroom: return "卫生间"
            case .study: return "书房"
            case .balcony: return "阳台"
            }
        }
    }
}

public struct FloorplanRoom: Identifiable {
    public var id: String
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
    public var isSevere: Bool {
        inspectionLevel.contains("严重") || inspectionLevel.contains("大凶") ||
        inspectionLevel.localizedCaseInsensitiveContains("severe") ||
        inspectionLevel.localizedCaseInsensitiveContains("critical")
    }
    public var isBad: Bool {
        isSevere || inspectionLevel.contains("凶") ||
        inspectionLevel.localizedCaseInsensitiveContains("harm")
    }
    public var isGood: Bool {
        inspectionLevel.contains("吉") || inspectionLevel.localizedCaseInsensitiveContains("auspicious")
    }
    public var isWarning: Bool {
        inspectionLevel.contains("预警") || inspectionLevel.localizedCaseInsensitiveContains("warning")
    }
}

public struct FloorplanAuditItem: Identifiable {
    // The audit is recalculated whenever the compass moves. A generated UUID
    // here makes SwiftUI treat every row as a brand-new view on each update,
    // which resets row layout and can visibly shake the report list. Callers
    // provide a stable room/report key instead.
    public let id: String
    public let title: String
    public let palace: String
    public let severity: String // "吉", "提示", "预警", "严重煞气"
    public let lore: String
    public let solution: String

    public init(id: String, title: String, palace: String, severity: String, lore: String, solution: String) {
        self.id = id
        self.title = title
        self.palace = palace
        self.severity = severity
        self.lore = lore
        self.solution = solution
    }

    public var isSevere: Bool {
        severity.contains("严重") || severity.contains("大凶") ||
        severity.localizedCaseInsensitiveContains("severe") ||
        severity.localizedCaseInsensitiveContains("critical")
    }
    public var isGood: Bool {
        severity.contains("吉") || severity.localizedCaseInsensitiveContains("auspicious")
    }
    public var isWarning: Bool {
        severity.contains("预警") || severity.localizedCaseInsensitiveContains("warning")
    }
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
        let centralRoomID = rooms
            .filter { $0.rect.contains(centroid) }
            .min {
                ($0.rect.width * $0.rect.height) < ($1.rect.width * $1.rect.height)
            }?.id
        
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
            
            // A room containing the user-selected Tai Ji point belongs to the
            // central palace.  The previous angle-only resolver could never
            // produce 中宫, so a bathroom or stairwell at the home's center
            // was silently reported as one of the eight outer palaces.
            let palace: (dir: String, gua: String)
            if room.id == centralRoomID {
                let language = LocalizationManager.shared.effectiveLanguage
                palace = language == .en ? ("Center", "Center") : (language == .zhHant ? ("中央", "中") : ("中央", "中"))
            } else {
                // 解算八卦宫位: 坎(0°/北), 艮(45°/东北), 震(90°/东), 巽(135°/东南), 离(180°/南), 坤(225°/西南), 兑(270°/西), 乾(315°/西北)
                palace = resolvePalace(geoAngle: geoAngle)
            }
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
                    id: "room-\(room.id)",
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
            let language = LocalizationManager.shared.effectiveLanguage
            let title = language == .en ? "Balanced Whole-Home Qi" : (language == .zhHant ? "全屋空間氣場中和純清" : "全屋空间气场中和纯清")
            let palace = language == .en ? "Whole Home" : "全局"
            let lore = language == .en ? "Every functional area is well positioned, with activity separated and yin-yang in harmony." : (language == .zhHant ? "各功能區方位得所，動靜分離，陰陽調和。" : "各功能区方位得所，动静分离，阴阳调和。")
            let solution = language == .en ? "Keep the home bright and ventilated, with living plants to support steady family fortune." : (language == .zhHant ? "保持居室明亮通風，綠植點綴，可常保家運昌隆。" : "保持居室内明亮通风，绿植点缀，可常保家运昌隆。")
            auditReport.append(FloorplanAuditItem(
                id: "whole-home-balanced",
                title: title,
                palace: palace,
                severity: "吉",
                lore: lore,
                solution: solution
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
        let language = LocalizationManager.shared.effectiveLanguage
        func tr(_ hans: String, _ hant: String, _ en: String) -> String {
            switch language {
            case .en: return en
            case .zhHant: return hant
            default: return hans
            }
        }
        switch (type, palaceGua) {
        case (.kitchen, "乾"), (.kitchen, "Qian"):
            return (
                tr("火烧天门大煞", "火燒天門大煞", "Heaven Gate Fire Sha"),
                "严重煞气",
                tr("乾为天为父为首，灶火克乾金，极不利男主人头部、血压及事业运。", "乾為天為父為首，灶火克乾金，極不利男主人頭部、血壓及事業運。", "Qian represents Heaven and the father; stove fire overcomes Qian Metal, stressing the male head, blood pressure and career."),
                tr("灶台旁安放天然黄色陶瓷罐，或悬挂真品六帝铜钱以土泄火生金。", "灶台旁安放天然黃色陶瓷罐，或懸掛真品六帝銅錢，以土洩火生金。", "Place a natural yellow ceramic vessel beside the stove, or hang Six Emperor coins so Earth can drain Fire and generate Metal.")
            )
        case (.bathroom, "乾"), (.bathroom, "Qian"):
            return (
                tr("水浸天门污秽大煞", "水浸天門污穢大煞", "Heaven Gate Water Pollution Sha"),
                "严重煞气",
                tr("乾为天为父，卫浴设于西北，金水相寒污浊天门，主男主人事业阻滞、脑血管与呼吸道隐患。", "乾為天為父，衛浴設於西北，金水相寒污濁天門，主男主人事業阻滯、腦血管與呼吸道隱患。", "Qian is the father position; a northwest bathroom makes Metal and Water cold and polluted, burdening career, circulation and breathing.") ,
                tr("卫生间门常闭，门槛下安放真品五帝古钱，内置纯铜金蟾或粗盐陶罐吸纳湿浊。", "衛生間門常閉，門檻下安放真品五帝古錢，內置純銅金蟾或粗鹽陶罐吸納濕濁。", "Keep the bathroom door closed; place Five Emperor coins under the threshold and a brass toad or salt vessel inside to absorb damp qi.")
            )
        case (.kitchen, "坎"), (.kitchen, "Kan"):
            return (
                tr("水火相战未济煞", "水火相戰未濟煞", "Water–Fire Clash"),
                "预警",
                tr("北方坎水见烈火，水火不相容，主心肾不交、情绪烦躁与血液循环受损。", "北方坎水見烈火，水火不相容，主心腎不交、情緒煩躁與血液循環受損。", "Kan Water meets strong stove Fire in the north, disturbing balance, mood and circulation."),
                tr("以木通关，厨房内增添绿植或实木厨具，令水生木、木生火，化克为生。", "以木通關，廚房內增添綠植或實木廚具，令水生木、木生火，化克為生。", "Use Wood as a bridge: add plants or wooden utensils so Water feeds Wood and Wood feeds Fire.")
            )
        case (.kitchen, "艮"), (.kitchen, "坤"), (.kitchen, "Gen"), (.kitchen, "Kun"):
            return (
                tr("火燥鬼门伤脾土", "火燥鬼門傷脾土", "Dry Fire in the Ghost Gate"),
                "预警",
                tr("艮坤属土为鬼门，烈火燥土，易致家人口腔上火、脾胃虚热及皮肤过敏。", "艮坤屬土為鬼門，烈火燥土，易致家人口腔上火、脾胃虛熱及皮膚過敏。", "Gen and Kun are Earth Ghost Gates; dry Fire may bring irritability, digestive heat and skin sensitivity."),
                tr("台面摆放白水晶球或黄色陶瓷葫芦化泄烈火，增厚中和地气。", "台面擺放白水晶球或黃色陶瓷葫蘆化洩烈火，增厚中和地氣。", "Place a white crystal sphere or yellow ceramic gourd on the counter to diffuse Fire and steady Earth qi.")
            )
        case (.bathroom, "艮"), (.bathroom, "坤"), (.bathroom, "Gen"), (.bathroom, "Kun"):
            return (
                tr("鬼门卫浴秽气冲射", "鬼門衛浴穢氣衝射", "Ghost Gate Bathroom Sha"),
                "预警",
                tr("东北艮为表鬼门，西南坤为里鬼门，卫浴见水污地气，易损脾胃与人丁健康。", "東北艮為表鬼門，西南坤為裏鬼門，衛浴見水污地氣，易損脾胃與人丁健康。", "Bathrooms in the northeast or southwest pollute Earth qi and may affect digestion and family wellbeing."),
                tr("卫浴常开排风保持干燥，门槛下安放真品五帝钱或粗盐陶罐净化。", "衛浴常開排風保持乾燥，門檻下安放真品五帝錢或粗鹽陶罐淨化。", "Keep ventilation running and the room dry; place Five Emperor coins or a salt vessel under the threshold.")
            )
        case (.bathroom, "中"), (.bathroom, "Center"):
            return (
                tr("水浸中宫大忌", "水浸中宮大忌", "Central Palace Water Sha"),
                "严重煞气",
                tr("房屋心脏太极受污，病气弥漫全屋，主宅运反复、家人腰腹疾厄。", "房屋心臟太極受污，病氣瀰漫全屋，主宅運反覆、家人腰腹疾厄。", "Water pollutes the home's central Tai Ji, spreading stagnant qi and affecting fortune and abdominal wellbeing."),
                tr("门头安放纯铜八卦凸镜，卫浴内常亮暖黄长明灯排浊。", "門頭安放純銅八卦凸鏡，衛浴內常亮暖黃長明燈排濁。", "Mount a brass convex Bagua mirror above the door and keep a warm light on to clear damp qi.")
            )
        case (.study, "巽"), (.study, "坎"), (.study, "Xun"), (.study, "Kan"):
            return (
                tr("文昌生旺大吉位", "文昌生旺大吉位", "Wenchang Scholarly Auspicious Position"),
                "吉",
                tr("巽为四绿文曲木，坎水生文昌，大利考学、升职与名誉构思。", "巽為四綠文曲木，坎水生文昌，大利考學、升職與名譽構思。", "Xun's Wenchang Wood and Kan Water nourish study, promotion and creative reputation."),
                tr("书桌宜设于此方，书架摆放四支水养富贵竹或天然白水晶文昌塔。", "書桌宜設於此方，書架擺放四支水養富貴竹或天然白水晶文昌塔。", "Place the desk here; add four water-grown lucky bamboos or a natural white-crystal Wenchang tower.")
            )
        case (.masterBedroom, "坤"), (.masterBedroom, "延年"), (.masterBedroom, "Kun"), (.masterBedroom, "Yan Nian"):
            return (
                tr("主卧得位气场稳固", "主臥得位氣場穩固", "Master Bedroom in a Stable Position"),
                "吉",
                tr("居于生旺方，身心放松，夫妻和睦，睡眠充盈利于事业蓄力。", "居於生旺方，身心放鬆，夫妻和睦，睡眠充盈利於事業蓄力。", "A prosperous position supports rest, harmony, sleep and renewed career energy."),
                tr("床头宜靠实墙，忌上方横梁压顶或正冲镜面。", "床頭宜靠實牆，忌上方橫梁壓頂或正衝鏡面。", "Keep the headboard against a solid wall; avoid overhead beams and mirrors facing the bed.")
            )
        case (.door, "离"), (.door, "Li"):
            return (
                tr("南向明堂纳阳吉向", "南向明堂納陽吉向", "South-Facing Bright Hall"),
                "吉",
                tr("离火纳气，采光充沛，主热情光明与远见名望。", "離火納氣，採光充沛，主熱情光明與遠見名望。", "Li Fire gathers bright qi and daylight, supporting warmth, vision and reputation."),
                tr("玄关保持整洁开阔，点亮暖金射灯迎祥纳福。", "玄關保持整潔開闊，點亮暖金射燈迎祥納福。", "Keep the entry clean and open, with warm lighting to welcome auspicious qi.")
            )
        default:
            return (
                tr("方位得所气场安和", "方位得所氣場安和", "Balanced Spatial Qi"),
                "平",
                tr("空间阴阳协调，无明显形理相克。", "空間陰陽協調，無明顯形理相克。", "Yin and yang are balanced with no obvious form or element conflict."),
                tr("按日常居住动线与洁净要求维护即可。", "按日常居住動線與潔淨要求維護即可。", "Maintain normal circulation, cleanliness and ventilation.")
            )
        }
    }
}
