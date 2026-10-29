import Foundation
import CoreGraphics

// MARK: - 户型空间立极与全屋风水体检引擎 (PRD 5.3 & 第7章)

public enum FloorplanRoomType: String, CaseIterable, Identifiable, Codable {
    case door = "大门"
    case livingRoom = "客厅"
    case masterBedroom = "主卧"
    case secondBedroom = "次卧"
    case kitchen = "厨房"
    case bathroom = "卫生间"
    case study = "书房"
    case balcony = "阳台"
    case missingCorner = "户型缺角"
    
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
        case .missingCorner: return "exclamationmark.triangle.fill"
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
            case .missingCorner: return "Missing Corner"
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
            case .missingCorner: return "戶型缺角"
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
            case .missingCorner: return "户型缺角"
            }
        }
    }
}

public struct FloorplanRoom: Identifiable, Codable {
    public var id: String
    public var name: String
    public var type: FloorplanRoomType
    public var rect: CGRect // 相对比例 (0.0 .. 1.0)
    public var palaceName: String // "西北乾宫", "东南巽宫", etc.
    public var inspectionTitle: String
    public var inspectionLevel: String // "吉", "平", "凶", "大凶"
    public var inspectionLore: String
    public var inspectionAdvice: String
    
    public init(id: String = UUID().uuidString, name: String, type: FloorplanRoomType, rect: CGRect, palaceName: String = "", inspectionTitle: String = "", inspectionLevel: String = "平", inspectionLore: String = "", inspectionAdvice: String = "") {
        self.id = id
        self.name = name
        self.type = type
        self.rect = rect
        self.palaceName = palaceName
        self.inspectionTitle = inspectionTitle
        self.inspectionLevel = inspectionLevel
        self.inspectionLore = inspectionLore
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
        
        let isEn = LocalizationManager.shared.effectiveLanguage == .en
        let isHant = LocalizationManager.shared.effectiveLanguage == .zhHant
        let centralRoomID = rooms
            .filter { $0.type != .missingCorner && $0.rect.contains(centroid) }
            .min {
                ($0.rect.width * $0.rect.height) < ($1.rect.width * $1.rect.height)
            }?.id
        let manualMissingGua = Set(rooms.filter { $0.type == .missingCorner }.map {
            palaceForPoint(CGPoint(x: $0.rect.midX, y: $0.rect.midY), centroid: centroid, heading: heading).gua
        })
        
        for room in rooms {
            var r = room
            // A room containing the user-selected Tai Ji point belongs to the
            // central palace.  The previous angle-only resolver could never
            // produce 中宫, so a bathroom or stairwell at the home's center
            // was silently reported as one of the eight outer palaces.
            let palace: (dir: String, gua: String)
            if room.type != .missingCorner && room.id == centralRoomID {
                let language = LocalizationManager.shared.effectiveLanguage
                palace = language == .en ? ("Center", "Center") : (language == .zhHant ? ("中央", "中") : ("中央", "中"))
            } else {
                // 解算八卦宫位: 坎(0°/北), 艮(45°/东北), 震(90°/东), 巽(135°/东南), 离(180°/南), 坤(225°/西南), 兑(270°/西), 乾(315°/西北)
                palace = palaceForPoint(
                    CGPoint(x: room.rect.midX, y: room.rect.midY),
                    centroid: centroid,
                    heading: heading
                )
            }
            if isEn {
                r.palaceName = "\(palace.dir) (\(palace.gua) Palace)"
            } else if isHant {
                r.palaceName = "\(palace.dir) \(palace.gua)宮"
            } else {
                r.palaceName = "\(palace.dir) \(palace.gua)宫"
            }
            
            if r.type == .missingCorner {
                let content = missingCornerContent(gua: palace.gua)
                r.inspectionTitle = content.title
                r.inspectionLevel = "预警"
                r.inspectionLore = content.lore
                r.inspectionAdvice = content.solution
                updatedRooms.append(r)
                auditReport.append(FloorplanAuditItem(
                    id: "manual-missing-corner-\(room.id)",
                    title: "\(r.name) · \(content.title)",
                    palace: r.palaceName,
                    severity: "预警",
                    lore: content.lore,
                    solution: content.solution
                ))
                continue
            }

            // 风水动态研判
            let audit = evaluateRoom(type: r.type, palaceGua: palace.gua, palaceDir: palace.dir)
            r.inspectionTitle = audit.title
            r.inspectionLevel = audit.level
            r.inspectionLore = audit.lore
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

        // Check the four outer corner sectors of the edited footprint. This
        // uses the room rectangles as an approximation of the building shell;
        // it is intentionally reported as a warning so the user can confirm
        // the actual exterior wall before relying on the result.
        auditReport.append(contentsOf: missingCornerAudits(
            rooms: rooms,
            centroid: centroid,
            heading: heading,
            excludingGua: manualMissingGua
        ))
        
        // 增加穿堂煞与中宫检测
        if auditReport.isEmpty {
            let language = LocalizationManager.shared.effectiveLanguage
            let hasValidRoom = rooms.contains {
                $0.type != .missingCorner && $0.rect.width > 0 && $0.rect.height > 0
            }
            let title: String
            let palace: String
            let lore: String
            let solution: String
            if hasValidRoom {
                title = language == .en ? "Balanced Whole-Home Qi" : (language == .zhHant ? "全屋空間氣場中和純清" : "全屋空间气场中和纯清")
                palace = language == .en ? "Whole Home" : "全局"
                lore = language == .en ? "Every functional area is well positioned, with activity separated and yin-yang in harmony." : (language == .zhHant ? "各功能區方位得所，動靜分離，陰陽調和。" : "各功能区方位得所，动静分离，阴阳调和。")
                solution = language == .en ? "Keep the home bright and ventilated, with living plants to support steady family fortune." : (language == .zhHant ? "保持居室明亮通風，綠植點綴，可常保家運昌隆。" : "保持居室内明亮通风，绿植点缀，可常保家运昌隆。")
            } else {
                title = language == .en ? "Floorplan Needs a Valid Room" : (language == .zhHant ? "戶型缺少有效房間" : "户型缺少有效房间")
                palace = language == .en ? "Whole Home" : (language == .zhHant ? "全局" : "全局")
                lore = language == .en ? "Only missing-corner markers remain, or all room rectangles have zero area, so a Tai Ji center and room placement cannot be calculated." : (language == .zhHant ? "目前只剩戶型缺角標記，或所有房間框面積為零，無法計算立極中宮與房間方位。" : "当前只剩户型缺角标记，或所有房间框面积为零，无法计算立极中宫与房间方位。")
                solution = language == .en ? "Add at least one real room with a positive width and height, then place the Tai Ji point and run the audit again." : (language == .zhHant ? "請至少新增一個有實際寬高的房間，再設定立極點並重新體檢。" : "请至少新增一个有实际宽高的房间，再设置立极点并重新体检。")
            }
            auditReport.append(FloorplanAuditItem(
                id: hasValidRoom ? "whole-home-balanced" : "floorplan-missing-valid-room",
                title: title,
                palace: palace,
                severity: hasValidRoom ? "吉" : "预警",
                lore: lore,
                solution: solution
            ))
        }
        
        return (updatedRooms, auditReport)
    }

    private func palaceForPoint(_ point: CGPoint, centroid: CGPoint, heading: Double) -> (dir: String, gua: String) {
        let dx = Double(point.x - centroid.x)
        let dy = Double(point.y - centroid.y)
        var screenAngle = atan2(dx, -dy) * 180.0 / Double.pi
        if screenAngle < 0 { screenAngle += 360.0 }
        let geoAngle = (screenAngle + heading).truncatingRemainder(dividingBy: 360.0)
        return resolvePalace(geoAngle: geoAngle < 0 ? geoAngle + 360.0 : geoAngle)
    }

    private func missingCornerAudits(
        rooms: [FloorplanRoom],
        centroid: CGPoint,
        heading: Double,
        excludingGua: Set<String>
    ) -> [FloorplanAuditItem] {
        let footprintRooms = rooms.filter {
            $0.type != .missingCorner && $0.rect.width > 0 && $0.rect.height > 0
        }
        guard !footprintRooms.isEmpty else { return [] }
        let bounds = footprintRooms.reduce(CGRect.null) { partial, room in
            partial.union(room.rect)
        }
        guard !bounds.isNull, bounds.width > 0.05, bounds.height > 0.05 else { return [] }

        let sectorWidth = bounds.width / 3.0
        let sectorHeight = bounds.height / 3.0
        let sectors: [CGRect] = [
            CGRect(x: bounds.minX, y: bounds.minY, width: sectorWidth, height: sectorHeight),
            CGRect(x: bounds.maxX - sectorWidth, y: bounds.minY, width: sectorWidth, height: sectorHeight),
            CGRect(x: bounds.maxX - sectorWidth, y: bounds.maxY - sectorHeight, width: sectorWidth, height: sectorHeight),
            CGRect(x: bounds.minX, y: bounds.maxY - sectorHeight, width: sectorWidth, height: sectorHeight)
        ]
        let sectorArea = sectorWidth * sectorHeight
        guard sectorArea > 0 else { return [] }

        var results: [FloorplanAuditItem] = []
        // A custom layout can contain several small rooms in one corner and
        // can also have a shifted Tai Ji point that maps two geometric
        // corners to the same eight-gua sector. Keep the emitted gua set
        // stable so a SwiftUI ForEach never receives duplicate report IDs.
        var emittedGua = excludingGua
        for sector in sectors {
            let occupiedArea = coveredArea(of: sector, by: footprintRooms)
            let occupied = occupiedArea / sectorArea >= 0.18
            guard !occupied else { continue }

            let center = CGPoint(x: sector.midX, y: sector.midY)
            let palace = palaceForPoint(center, centroid: centroid, heading: heading)
            guard !emittedGua.contains(palace.gua) else { continue }
            emittedGua.insert(palace.gua)
            let content = missingCornerContent(gua: palace.gua)
            results.append(FloorplanAuditItem(
                id: "missing-corner-\(palace.gua)",
                title: content.title,
                palace: palace.dir,
                severity: "预警",
                lore: content.lore,
                solution: content.solution
            ))
        }
        return results
    }

    /// Returns the exact union area of axis-aligned room rectangles clipped to
    /// one corner sector. Summing each overlap would count overlapping custom
    /// rooms twice, while checking only one room misses a corner assembled from
    /// several smaller rooms. A sweep over the rectangles' x breakpoints keeps
    /// this calculation deterministic and inexpensive (only four sectors).
    private func coveredArea(of sector: CGRect, by rooms: [FloorplanRoom]) -> CGFloat {
        let clipped = rooms.compactMap { room -> CGRect? in
            let intersection = room.rect.intersection(sector)
            guard !intersection.isNull,
                  intersection.width > 0,
                  intersection.height > 0 else { return nil }
            return intersection
        }
        guard !clipped.isEmpty else { return 0 }

        var xBreakpoints: [CGFloat] = [sector.minX, sector.maxX]
        for rect in clipped {
            xBreakpoints.append(rect.minX)
            xBreakpoints.append(rect.maxX)
        }
        xBreakpoints.sort()

        var area: CGFloat = 0
        for index in 0..<(xBreakpoints.count - 1) {
            let x0 = xBreakpoints[index]
            let x1 = xBreakpoints[index + 1]
            let width = x1 - x0
            guard width > 0 else { continue }
            let x = (x0 + x1) / 2
            let yIntervals = clipped.compactMap { rect -> (CGFloat, CGFloat)? in
                guard x > rect.minX, x < rect.maxX else { return nil }
                return (rect.minY, rect.maxY)
            }.sorted { $0.0 < $1.0 }
            guard !yIntervals.isEmpty else { continue }

            var coveredHeight: CGFloat = 0
            var currentStart = yIntervals[0].0
            var currentEnd = yIntervals[0].1
            for interval in yIntervals.dropFirst() {
                if interval.0 <= currentEnd {
                    currentEnd = max(currentEnd, interval.1)
                } else {
                    coveredHeight += currentEnd - currentStart
                    currentStart = interval.0
                    currentEnd = interval.1
                }
            }
            coveredHeight += currentEnd - currentStart
            area += width * coveredHeight
        }
        return area
    }

    private func missingCornerContent(gua: String) -> (title: String, lore: String, solution: String) {
        let language = LocalizationManager.shared.effectiveLanguage
        func tr(_ hans: String, _ hant: String, _ en: String) -> String {
            switch language {
            case .en: return en
            case .zhHant: return hant
            default: return hans
            }
        }
        switch gua {
        case "乾", "Qian":
            return (
                tr("户型缺角 · 西北乾位", "戶型缺角 · 西北乾位", "Missing Corner · Northwest Qian"),
                tr("西北乾位缺角常被用于提示家中长辈、男主人、事业支持和居住稳定性方面需要关注；当前判断基于房间框，需先核对真实外墙。", "西北乾位缺角常被用於提示家中長輩、男主人、事業支持和居住穩定性方面需要關注；當前判斷基於房間框，需先核對真實外牆。", "A northwest Qian gap is traditionally associated with elder support, the male householder, career backing and stability; verify the actual exterior wall because this result is inferred from room boxes."),
                tr("首选补足真实外墙或封闭式储物/设备空间；无法改造时，可用圆形金属灯具、白色或金色圆器、稳固高柜作视觉补足，保持干燥明亮，避免以大型水景或杂物堆积代替。", "首選補足真實外牆或封閉式儲物／設備空間；無法改造時，可用圓形金屬燈具、白色或金色圓器、穩固高櫃作視覺補足，保持乾燥明亮，避免以大型水景或雜物堆積代替。", "Prefer completing the exterior wall or using an enclosed storage/service space. If construction is impossible, use a round metal light, white or gold circular decor, or a stable tall cabinet as a visual countermeasure; keep it dry and bright, and avoid a large water feature or clutter.")
            )
        case "艮", "Gen":
            return (
                tr("户型缺角 · 东北艮位", "戶型缺角 · 東北艮位", "Missing Corner · Northeast Gen"),
                tr("东北艮位缺角常被用于提示家庭稳定、子女成长、学习专注和储藏空间方面需要关注；当前判断基于房间框，需先核对真实外墙。", "東北艮位缺角常被用於提示家庭穩定、子女成長、學習專注和儲藏空間方面需要關注；當前判斷基於房間框，需先核對真實外牆。", "A northeast Gen gap is traditionally associated with household stability, children, study focus and storage; verify the actual exterior wall because this result is inferred from room boxes."),
                tr("首选补足墙体或设置封闭、整洁的储物柜；无法改造时，可放置黄色陶瓷、天然石材、方形地毯或暖色灯光作稳定补足，保持安静干燥，避免潮湿和杂乱。", "首選補足牆體或設置封閉、整潔的儲物櫃；無法改造時，可放置黃色陶瓷、天然石材、方形地毯或暖色燈光作穩定補足，保持安靜乾燥，避免潮濕和雜亂。", "Prefer completing the wall or adding a closed, orderly cabinet. If construction is impossible, use yellow ceramic, natural stone, a square rug or warm lighting to add visual stability; keep the area quiet and dry.")
            )
        case "巽", "Xun":
            return (
                tr("户型缺角 · 东南巽位", "戶型缺角 · 東南巽位", "Missing Corner · Southeast Xun"),
                tr("东南巽位缺角常被用于提示财务规划、资源流动、沟通关系和通风采光方面需要关注；当前判断基于房间框，需先核对真实外墙。", "東南巽位缺角常被用於提示財務規劃、資源流動、溝通關係和通風採光方面需要關注；當前判斷基於房間框，需先核對真實外牆。", "A southeast Xun gap is traditionally associated with financial planning, resource flow, relationships, ventilation and daylight; verify the actual exterior wall because this result is inferred from room boxes."),
                tr("首选补足外墙或设置连续的木质收纳/绿化界面；无法改造时，可用健康阔叶植物、木质柜体、青绿色软装和柔和照明作替代，保持通风，避免尖角、破损和堆物。", "首選補足外牆或設置連續的木質收納／綠化界面；無法改造時，可用健康闊葉植物、木質櫃體、青綠色軟裝和柔和照明作替代，保持通風，避免尖角、破損和堆物。", "Prefer completing the exterior wall or adding a continuous wood storage or planting boundary. If construction is impossible, use healthy broad-leaf plants, wood cabinetry, teal-green textiles and soft lighting; keep ventilation clear and avoid sharp corners, damage and clutter.")
            )
        case "坤", "Kun":
            return (
                tr("户型缺角 · 西南坤位", "戶型缺角 · 西南坤位", "Missing Corner · Southwest Kun"),
                tr("西南坤位缺角常被用于提示家庭照料、伴侣关系、生活承托和居住安定方面需要关注；当前判断基于房间框，需先核对真实外墙。", "西南坤位缺角常被用於提示家庭照料、伴侶關係、生活承托和居住安定方面需要關注；當前判斷基於房間框，需先核對真實外牆。", "A southwest Kun gap is traditionally associated with caregiving, partnership, household support and stability; verify the actual exterior wall because this result is inferred from room boxes."),
                tr("首选补足墙体或设置低矮、稳定的封闭柜体；无法改造时，可用黄色或米色陶瓷、天然石材、方形地垫和暖光作替代，保持整洁稳定，避免空置、漏水和尖锐杂物。", "首選補足牆體或設置低矮、穩定的封閉櫃體；無法改造時，可用黃色或米色陶瓷、天然石材、方形地墊和暖光作替代，保持整潔穩定，避免空置、漏水和尖銳雜物。", "Prefer completing the wall or adding a low, stable closed cabinet. If construction is impossible, use yellow or beige ceramic, natural stone, a square mat and warm light; keep it orderly and stable, avoiding leaks and sharp clutter.")
            )
        case "坎", "Kan":
            return (
                tr("户型缺角 · 正北坎位", "戶型缺角 · 正北坎位", "Missing Corner · North Kan"),
                tr("正北坎位缺角常被用于提示作息安全、情绪压力、财务流动和与水有关的使用空间；当前判断基于房间框，需先核对真实外墙、管线和排水。", "正北坎位缺角常被用於提示作息安全、情緒壓力、財務流動和與水有關的使用空間；當前判斷基於房間框，需先核對真實外牆、管線和排水。", "A north Kan gap is traditionally associated with rest, emotional pressure, financial flow and water-related utilities; verify the exterior wall, pipes and drainage because this result is inferred from room boxes."),
                tr("首选补足外墙并检查防水、排水和采光；无法改造时，可用深色稳重收纳、适度照明和金属/玻璃小件作替代，保持地面干燥，避免漏水、阴暗和大面积镜面。", "首選補足外牆並檢查防水、排水和採光；無法改造時，可用深色穩重收納、適度照明和金屬／玻璃小件作替代，保持地面乾燥，避免漏水、陰暗和大面積鏡面。", "Prefer completing the wall and checking waterproofing, drainage and daylight. If construction is impossible, use stable dark-toned storage, measured lighting and small metal or glass accents; keep floors dry and avoid leaks, darkness and large mirrors.")
            )
        case "震", "Zhen":
            return (
                tr("户型缺角 · 正东震位", "戶型缺角 · 正東震位", "Missing Corner · East Zhen"),
                tr("正东震位缺角常被用于提示家庭行动力、长子成长、启动计划和日常通行；当前判断基于房间框，需先核对真实外墙和门窗。", "正東震位缺角常被用於提示家庭行動力、長子成長、啟動計畫和日常通行；當前判斷基於房間框，需先核對真實外牆和門窗。", "An east Zhen gap is traditionally associated with initiative, the eldest child, new plans and daily movement; verify the exterior wall, doors and windows because this result is inferred from room boxes."),
                tr("首选补足外墙或形成连续的木质界面；无法改造时，可用健康绿植、竖向木柜、木质屏风和充足但不刺眼的照明作替代，保持通道顺畅，避免破损电器、尖角和杂物阻路。", "首選補足外牆或形成連續的木質界面；無法改造時，可用健康綠植、豎向木櫃、木質屏風和充足但不刺眼的照明作替代，保持通道順暢，避免破損電器、尖角和雜物阻路。", "Prefer completing the wall or creating a continuous wood boundary. If construction is impossible, use healthy plants, vertical wood storage, a wood screen and even lighting; keep circulation clear and avoid damaged appliances, sharp corners and blocked paths.")
            )
        case "离", "Li":
            return (
                tr("户型缺角 · 正南离位", "戶型缺角 · 正南離位", "Missing Corner · South Li"),
                tr("正南离位缺角常被用于提示采光、可见度、表达沟通和家庭活力；当前判断基于房间框，需先核对真实外墙、窗户和消防条件。", "正南離位缺角常被用於提示採光、可見度、表達溝通和家庭活力；當前判斷基於房間框，需先核對真實外牆、窗戶和消防條件。", "A south Li gap is traditionally associated with daylight, visibility, communication and household vitality; verify the exterior wall, windows and fire-safety conditions because this result is inferred from room boxes."),
                tr("首选补足外墙并改善自然采光；无法改造时，可用合规的暖色照明、红紫色小面积软装和整洁的开放展示位作替代，避免明火、过热设备、遮挡逃生通道和过度反光。", "首選補足外牆並改善自然採光；無法改造時，可用合規的暖色照明、紅紫色小面積軟裝和整潔的開放展示位作替代，避免明火、過熱設備、遮擋逃生通道和過度反光。", "Prefer completing the wall and improving daylight. If construction is impossible, use code-compliant warm lighting, small red or purple accents and an orderly display area; avoid open flames, overheating devices, blocked exits and excessive glare.")
            )
        case "兑", "Dui":
            return (
                tr("户型缺角 · 正西兑位", "戶型缺角 · 正西兌位", "Missing Corner · West Dui"),
                tr("正西兑位缺角常被用于提示沟通表达、子女互动、收纳秩序和生活愉悦感；当前判断基于房间框，需先核对真实外墙和窗边空间。", "正西兌位缺角常被用於提示溝通表達、子女互動、收納秩序和生活愉悅感；當前判斷基於房間框，需先核對真實外牆和窗邊空間。", "A west Dui gap is traditionally associated with communication, children, storage order and enjoyment of daily life; verify the exterior wall and window-side space because this result is inferred from room boxes."),
                tr("首选补足外墙或设置整洁的封闭收纳；无法改造时，可用白色、金属色圆形物件、柔和灯光和易清洁材质作替代，保持安静整齐，避免尖锐金属、破损物品和噪声源。", "首選補足外牆或設置整潔的封閉收納；無法改造時，可用白色、金屬色圓形物件、柔和燈光和易清潔材質作替代，保持安靜整齊，避免尖銳金屬、破損物品和噪聲源。", "Prefer completing the wall or adding orderly closed storage. If construction is impossible, use white or metallic round objects, soft lighting and easy-clean materials; keep it quiet and orderly, avoiding sharp metal, damaged items and noise sources.")
            )
        default:
            return (
                tr("户型缺角 · 当前方位", "戶型缺角 · 當前方位", "Missing Corner · Indicated Direction"),
                tr("房屋外接轮廓在当前方位出现空缺，可能影响户型边界完整性；当前结果基于房间框近似。", "房屋外接輪廓在當前方位出現空缺，可能影響戶型邊界完整性；當前結果基於房間框近似。", "The inferred footprint is open in the indicated direction; this result is an approximation based on room boxes."),
                tr("核对对应外墙、阳台和附属空间，确认缺角是否真实存在。", "核對對應外牆、陽台和附屬空間，確認缺角是否真實存在。", "Check the corresponding exterior wall, balcony and attached spaces to confirm the actual outline.")
            )
        }
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
