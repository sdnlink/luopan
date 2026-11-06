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
        case .ja:
            switch self {
            case .door: return "玄関"
            case .livingRoom: return "リビング"
            case .masterBedroom: return "主寝室"
            case .secondBedroom: return "寝室"
            case .kitchen: return "キッチン"
            case .bathroom: return "浴室・トイレ"
            case .study: return "書斎"
            case .balcony: return "バルコニー"
            case .missingCorner: return "間取りの欠け"
            }
        case .ko:
            switch self {
            case .door: return "현관문"
            case .livingRoom: return "거실"
            case .masterBedroom: return "안방 (주침실)"
            case .secondBedroom: return "작은방 (침실)"
            case .kitchen: return "주방"
            case .bathroom: return "욕실"
            case .study: return "서재"
            case .balcony: return "발코니"
            case .missingCorner: return "평면 결손"
            }
        case .vi:
            switch self {
            case .door: return "Cửa chính"
            case .livingRoom: return "Phòng khách"
            case .masterBedroom: return "Phòng ngủ chính"
            case .secondBedroom: return "Phòng ngủ phụ"
            case .kitchen: return "Nhà bếp"
            case .bathroom: return "Phòng vệ sinh"
            case .study: return "Phòng đọc sách"
            case .balcony: return "Ban công"
            case .missingCorner: return "Khuyết góc nhà"
            }
        case .th:
            switch self {
            case .door: return "ประตูใหญ่"
            case .livingRoom: return "ห้องรับแขก"
            case .masterBedroom: return "ห้องนอนใหญ่"
            case .secondBedroom: return "ห้องนอนเล็ก"
            case .kitchen: return "ห้องครัว"
            case .bathroom: return "ห้องน้ำ"
            case .study: return "ห้องหนังสือ"
            case .balcony: return "ระเบียง"
            case .missingCorner: return "มุมเว้าแหว่ง"
            }
        case .id:
            switch self {
            case .door: return "Pintu Utama"
            case .livingRoom: return "Ruang Tamu"
            case .masterBedroom: return "Kamar Tidur Utama"
            case .secondBedroom: return "Kamar Tidur Kedua"
            case .kitchen: return "Dapur"
            case .bathroom: return "Kamar Mandi"
            case .study: return "Ruang Belajar"
            case .balcony: return "Balkon"
            case .missingCorner: return "Sudut Hilang"
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
    public var polygonPoints: [CGPoint]? // 可选：识别出的真实房间轮廓（相对比例），nil 时退化为矩形
    public var palaceName: String // "西北乾宫", "东南巽宫", etc.
    public var inspectionTitle: String
    public var inspectionLevel: String // "吉", "平", "凶", "大凶"
    public var inspectionLore: String
    public var inspectionAdvice: String
    
    public init(id: String = UUID().uuidString, name: String, type: FloorplanRoomType, rect: CGRect, polygonPoints: [CGPoint]? = nil, palaceName: String = "", inspectionTitle: String = "", inspectionLevel: String = "平", inspectionLore: String = "", inspectionAdvice: String = "") {
        self.id = id
        self.name = name
        self.type = type
        self.rect = rect
        self.polygonPoints = polygonPoints
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
    public var localizedSeverity: String {
        let lang = LocalizationManager.shared
        if isSevere { return lang.t("floorplan_level_severe") }
        if isGood { return lang.t("floorplan_level_auspicious") }
        if isWarning { return lang.t("floorplan_level_warning") }
        return lang.t("floorplan_level_neutral")
    }
}

/// Latest in-session floorplan audit consumed by the TianJi export. The
/// report is intentionally kept as value data; it is refreshed after every
/// audit and is not treated as a durable source of truth.
public final class FloorplanAuditStore {
    public static let shared = FloorplanAuditStore()
    private init() {}

    public private(set) var latestReport: [FloorplanAuditItem] = []

    public func update(_ report: [FloorplanAuditItem]) {
        latestReport = report
    }

    public func clear() {
        latestReport.removeAll()
    }
}

public class FloorplanEngine {
    public static let shared = FloorplanEngine()
    
    private init() {}
    
    // 生成演示标准三室两厅精装户型 (支持根据当前语言动态输出，杜绝英文下出现中文硬编码)
    public func generateSampleRooms() -> [FloorplanRoom] {
        let lang = LocalizationManager.shared.effectiveLanguage
        let doorName: String
        let livingName: String
        let masterName: String
        let studyName: String
        let secondBedName: String
        let kitchenName: String
        let bathroomName: String
        let balconyName: String
        
        switch lang {
        case .en:
            doorName = "Main Entrance (South Qi)"
            livingName = "Spacious Living Room"
            masterName = "Master Bedroom"
            studyName = "Quiet Study Room"
            secondBedName = "Second Bedroom"
            kitchenName = "Gourmet Kitchen"
            bathroomName = "Main Bathroom"
            balconyName = "South Balcony"
        case .zhHant:
            doorName = "入戶大門 (正南明堂納氣)"
            livingName = "聚氣大客廳"
            masterName = "尊貴主臥"
            studyName = "文昌靜雅書房"
            secondBedName = "靜心次臥"
            kitchenName = "膳食廚房"
            bathroomName = "主衛浴間"
            balconyName = "南向大陽台"
        case .ja:
            doorName = "正面玄関（正南明堂納気）"
            livingName = "集気リビング"
            masterName = "主寝室"
            studyName = "文昌書斎"
            secondBedName = "静心寝室"
            kitchenName = "キッチン"
            bathroomName = "主浴室・トイレ"
            balconyName = "南向きバルコニー"
        case .ko:
            doorName = "현관문 (남향 명당 납기)"
            livingName = "거실"
            masterName = "안방 (주침실)"
            studyName = "문창 서재"
            secondBedName = "작은방 (침실)"
            kitchenName = "주방"
            bathroomName = "주욕실"
            balconyName = "남향 발코니"
        case .vi:
            doorName = "Cửa chính (Nam minh đường nạp khí)"
            livingName = "Phòng khách tụ khí"
            masterName = "Phòng ngủ chính"
            studyName = "Phòng đọc sách Văn Xương"
            secondBedName = "Phòng ngủ phụ"
            kitchenName = "Nhà bếp"
            bathroomName = "Phòng tắm chính"
            balconyName = "Ban công hướng Nam"
        case .th:
            doorName = "ประตูใหญ่ (รับชี่ทิศใต้)"
            livingName = "ห้องรับแขกเปิดกว้าง"
            masterName = "ห้องนอนใหญ่"
            studyName = "ห้องหนังสือ"
            secondBedName = "ห้องนอนเล็ก"
            kitchenName = "ห้องครัว"
            bathroomName = "ห้องน้ำหลัก"
            balconyName = "ระเบียงทิศใต้"
        case .id:
            doorName = "Pintu Utama (Penerima Qi Selatan)"
            livingName = "Ruang Tamu Lapang"
            masterName = "Kamar Tidur Utama"
            studyName = "Ruang Belajar Tenang"
            secondBedName = "Kamar Tidur Kedua"
            kitchenName = "Dapur Bersih"
            bathroomName = "Kamar Mandi Utama"
            balconyName = "Balkon Menghadap Selatan"
        case .zhHans, .auto:
            doorName = "入户大门 (正南明堂纳气)"
            livingName = "聚气大客厅"
            masterName = "尊贵主卧"
            studyName = "文昌静雅书房"
            secondBedName = "静心次卧"
            kitchenName = "膳食厨房"
            bathroomName = "主卫浴间"
            balconyName = "南向大阳台"
        }
        
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
                // 右下角阳台：与左下大门 (0.40-0.60)×(0.82-0.94) 保持 x 向不重叠
                rect: CGRect(x: 0.62, y: 0.88, width: 0.30, height: 0.10)
            )
        ]
    }
    
    // MARK: - 多边形识别辅助（识别管线升级：真实轮廓优先，矩形退化）

    /// 房间实际面积（优先多边形轮廓，退化回矩形）
    public static func roomArea(_ room: FloorplanRoom) -> CGFloat {
        if let pts = room.polygonPoints, pts.count >= 3 {
            return GeometryUtils.polygonArea(pts)
        }
        return room.rect.width * room.rect.height
    }

    /// 房间几何质心（优先多边形质心，退化回矩形中心）
    public static func roomCentroid(_ room: FloorplanRoom) -> CGPoint {
        if let pts = room.polygonPoints, pts.count >= 3 {
            let c = GeometryUtils.polygonCentroid(pts)
            return CGPoint(x: max(0, min(1, c.x)), y: max(0, min(1, c.y)))
        }
        return CGPoint(x: room.rect.midX, y: room.rect.midY)
    }

    /// 全屋面积加权质心（立极中宫）：各房间真实面积 × 房间质心
    public static func roomsCentroid(_ rooms: [FloorplanRoom]) -> CGPoint {
        var totalArea: CGFloat = 0
        var weightedX: CGFloat = 0
        var weightedY: CGFloat = 0
        for room in rooms where room.type != .missingCorner {
            let area = roomArea(room)
            guard area > 0 else { continue }
            let c = roomCentroid(room)
            totalArea += area
            weightedX += c.x * area
            weightedY += c.y * area
        }
        guard totalArea > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(
            x: max(0.05, min(0.95, weightedX / totalArea)),
            y: max(0.05, min(0.95, weightedY / totalArea))
        )
    }

    /// 规则式房间类型推断：依据相对面积与纵横比 + 已用类型，给出最可能类型
    /// - Parameters:
    ///   - areaRatio: 候选面积占画布面积比例 (0..1)
    ///   - aspectRatio: 候选宽高比（>1 表示横向）
    ///   - existing: 当前已确认房间（避免重复分配主卧/客厅等唯一类型）
    public static func inferRoomType(areaRatio: CGFloat, aspectRatio: CGFloat, existing: [FloorplanRoom]) -> FloorplanRoomType? {
        let used = Set(existing.map { $0.type })
        // 细长区域（长走廊/阳台）优先判为阳台
        if aspectRatio > 2.6 && !used.contains(.balcony) {
            return .balcony
        }
        // 极小面积优先卫浴/书房
        if areaRatio < 0.06 {
            if !used.contains(.bathroom) { return .bathroom }
            if !used.contains(.study) { return .study }
        }
        // 其余按常见户型主次分配第一个未占用类型
        let candidateOrder: [FloorplanRoomType] = [
            .livingRoom, .masterBedroom, .secondBedroom, .study, .kitchen, .bathroom, .balcony, .door
        ]
        for type in candidateOrder where !used.contains(type) {
            return type
        }
        return nil
    }

    // 根据户型重心立极点与罗盘朝向解算各房间八卦方位与全屋风水体检报告
    public func auditFloorplan(rooms: [FloorplanRoom], centroid: CGPoint, heading: Double) -> (auditedRooms: [FloorplanRoom], report: [FloorplanAuditItem]) {
        var updatedRooms: [FloorplanRoom] = []
        var auditReport: [FloorplanAuditItem] = []
        
        let language = LocalizationManager.shared.effectiveLanguage
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
            let palace: (dir: String, gua: String)
            if room.type != .missingCorner && room.id == centralRoomID {
                switch language {
                case .en: palace = ("Center", "Center")
                case .zhHant: palace = ("中央", "中")
                case .ja: palace = ("中央", "中")
                case .ko: palace = ("중앙", "중")
                case .vi: palace = ("Trung tâm", "Trung")
                case .th: palace = ("จุดศูนย์กลาง", "กลาง")
                case .id: palace = ("Pusat", "Tengah")
                case .auto, .zhHans: palace = ("中央", "中")
                }
            } else {
                palace = palaceForPoint(
                    CGPoint(x: room.rect.midX, y: room.rect.midY),
                    centroid: centroid,
                    heading: heading
                )
            }
            switch language {
            case .en: r.palaceName = "\(palace.dir) (\(palace.gua) Palace)"
            case .zhHant, .ja: r.palaceName = "\(palace.dir) \(palace.gua)宮"
            case .ko: r.palaceName = "\(palace.dir) \(palace.gua)궁"
            case .vi: r.palaceName = "\(palace.dir) Cung \(palace.gua)"
            case .th: r.palaceName = "\(palace.dir) วัง\(palace.gua)"
            case .id: r.palaceName = "\(palace.dir) (Istana \(palace.gua))"
            default: r.palaceName = "\(palace.dir) \(palace.gua)宫"
            }
            
            if r.type == .missingCorner {
                let content = missingCornerContent(gua: palace.gua)
                r.name = r.type.localizedName
                r.inspectionTitle = content.title
                r.inspectionLevel = "预警"
                let lore = missingCornerLoreWithSource(gua: palace.gua, lore: content.lore)
                r.inspectionLore = lore
                r.inspectionAdvice = content.solution
                updatedRooms.append(r)
                auditReport.append(FloorplanAuditItem(
                    id: "manual-missing-corner-\(room.id)",
                    title: "\(r.type.localizedName) · \(content.title)",
                    palace: r.palaceName,
                    severity: "预警",
                    lore: lore,
                    solution: content.solution
                ))
                continue
            }

            // 风水动态研判
            let audit = evaluateRoom(type: r.type, palaceGua: palace.gua, palaceDir: palace.dir)
            r.name = r.type.localizedName
            r.inspectionTitle = audit.title
            r.inspectionLevel = audit.level
            r.inspectionLore = audit.lore
            r.inspectionAdvice = audit.advice
            
            updatedRooms.append(r)
            
            // Keep balanced rooms in the report as well. Their explanatory
            // text and maintenance advice are part of the complete floorplan
            // snapshot and must be available to the long-scroll export; the
            // previous warning-only filter silently dropped those remedies.
            auditReport.append(FloorplanAuditItem(
                id: "room-\(room.id)",
                title: "\(r.type.localizedName) · \(audit.title)",
                palace: r.palaceName,
                severity: audit.level,
                lore: audit.lore,
                solution: audit.advice
            ))
        }

        auditReport.append(contentsOf: missingCornerAudits(
            rooms: rooms,
            centroid: centroid,
            heading: heading,
            excludingGua: manualMissingGua
        ))
        
        // 增加穿堂煞与中宫检测
        if auditReport.isEmpty {
            let hasValidRoom = rooms.contains {
                $0.type != .missingCorner && $0.rect.width > 0 && $0.rect.height > 0
            }
            let title: String
            let palace: String
            let lore: String
            let solution: String
            if hasValidRoom {
                switch language {
                case .en:
                    title = "Balanced Whole-Home Qi"
                    palace = "Whole Home"
                    lore = "Every functional area is well positioned, with activity separated and yin-yang in harmony."
                    solution = "Keep the home bright and ventilated, with living plants to support steady family fortune."
                case .zhHant:
                    title = "全屋空間氣場中和純清"
                    palace = "全局"
                    lore = "各功能區方位得所，動靜分離，陰陽調和。"
                    solution = "保持居室明亮通風，綠植點綴，可常保家運昌隆。"
                case .ja:
                    title = "全室の空間エネルギーの調和"
                    palace = "全般"
                    lore = "各部屋の配置が調和し、動と静が分かれ、陰陽のバランスが保たれています。"
                    solution = "明るく風通しの良い環境を保ち、観葉植物を飾ることで家庭運を安定させます。"
                case .ko:
                    title = "주택 전체 기운의 균형"
                    palace = "전체"
                    lore = "각 기능 구역의 방위가 조화를 이루고, 동선과 정숙함이 분리되어 음양이 화합합니다."
                    solution = "실내를 밝고 통풍이 잘 되게 유지하며, 화분을 배치하여 가운을 번창시키세요."
                case .vi:
                    title = "Sinh khí toàn gia hài hòa thanh tịnh"
                    palace = "Toàn cục"
                    lore = "Các khu vực chức năng được bố trí hợp cách, động tĩnh phân minh, âm dương hòa hợp."
                    solution = "Giữ nhà cửa sáng sủa thông thoáng, điểm xuyết cây xanh để gia vận hưng thịnh."
                case .th:
                    title = "ชี่ทั่วบ้านสมดุลและบริสุทธิ์"
                    palace = "ภาพรวม"
                    lore = "ทุกพื้นที่การใช้งานอยู่ในทิศทางที่เหมาะสม แยกโซนเงียบสงบและเคลื่อนไหวอย่างสมดุล"
                    solution = "รักษาบ้านให้สว่างและระบายอากาศได้ดี ตกแต่งด้วยต้นไม้เพื่อเสริมความรุ่งเรือง"
                case .id:
                    title = "Energi Seluruh Rumah Seimbang dan Harmonis"
                    palace = "Keseluruhan"
                    lore = "Setiap area fungsional berada di posisi yang baik, terpisah dengan rapi, dan yin-yang selaras."
                    solution = "Jaga rumah tetap terang dan berventilasi baik, hiasi tanaman hijau untuk rezeki stabil."
                case .auto, .zhHans:
                    title = "全屋空间气场中和纯清"
                    palace = "全局"
                    lore = "各功能区方位得所，动静分离，阴阳调和。"
                    solution = "保持居室内明亮通风，绿植点缀，可常保家运昌隆。"
                }
            } else {
                switch language {
                case .en:
                    title = "Floorplan Needs a Valid Room"
                    palace = "Whole Home"
                    lore = "Only missing-corner markers remain, or all room rectangles have zero area, so a Tai Ji center and room placement cannot be calculated."
                    solution = "Add at least one real room with a positive width and height, then place the Tai Ji point and run the audit again."
                case .zhHant:
                    title = "戶型缺少有效房間"
                    palace = "全局"
                    lore = "目前只剩戶型缺角標記，或所有房間框面積為零，無法計算立極中宮與房間方位。"
                    solution = "請至少新增一個有實際寬高的房間，再設定立極點並重新體檢。"
                case .ja:
                    title = "有効な部屋の配置が必要です"
                    palace = "全般"
                    lore = "部屋の面積がゼロであるか欠けのみのため、太極中宮を算出できません。"
                    solution = "少なくとも1つの部屋を追加してから立極点を設定してください。"
                case .ko:
                    title = "유효한 방 배치가 필요합니다"
                    palace = "전체"
                    lore = "방 면적이 0이거나 결손 표기만 있어 태극 중궁을 계산할 수 없습니다."
                    solution = "최소 하나의 방을 추가한 후 입극점을 설정하여 다시 검진하세요."
                case .vi:
                    title = "Bản vẽ cần phòng hợp lệ"
                    palace = "Toàn cục"
                    lore = "Hiện chỉ có đánh dấu khuyết góc hoặc diện tích bằng 0, không thể tính trung cung."
                    solution = "Vui lòng thêm ít nhất một phòng có diện tích thực tế để thẩm định lại."
                case .th:
                    title = "ผังบ้านต้องการห้องที่ถูกต้อง"
                    palace = "ภาพรวม"
                    lore = "มีเพียงเครื่องหมายมุมแหว่งหรือไม่ระบุขนาดห้อง จึงไม่สามารถคำนวณจุดศูนย์กลางได้"
                    solution = "โปรดเพิ่มห้องจริงอย่างน้อยหนึ่งห้อง จากนั้นตั้งจุดศูนย์กลางแล้วตรวจใหม่อีกครั้ง"
                case .id:
                    title = "Denah Memerlukan Ruangan yang Valid"
                    palace = "Keseluruhan"
                    lore = "Hanya tersisa penanda sudut hilang atau luas area nol, sehingga pusat Tai Ji tidak dapat dihitung."
                    solution = "Tambahkan minimal satu ruangan nyata, lalu tentukan titik Tai Ji dan periksa kembali."
                case .auto, .zhHans:
                    title = "户型缺少有效房间"
                    palace = "全局"
                    lore = "当前只剩户型缺角标记，或所有房间框面积为零，无法计算立极中宫与房间方位。"
                    solution = "请至少新增一个有实际宽高的房间，再设置立极点并重新体检。"
                }
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
        // Check every outer cell of the 3×3 bagua grid. The previous
        // implementation only inspected the four corners, so a recessed
        // middle section on the east/south/west/north edge was silently
        // treated as a complete footprint.
        var sectors: [CGRect] = []
        for row in 0..<3 {
            for column in 0..<3 {
                guard row != 1 || column != 1 else { continue }
                sectors.append(CGRect(
                    x: bounds.minX + CGFloat(column) * sectorWidth,
                    y: bounds.minY + CGFloat(row) * sectorHeight,
                    width: sectorWidth,
                    height: sectorHeight
                ))
            }
        }
        let sectorArea = sectorWidth * sectorHeight
        guard sectorArea > 0 else { return [] }

        var results: [FloorplanAuditItem] = []
        // A custom layout can contain several small rooms in one sector and
        // can also have a shifted Tai Ji point that maps two geometric
        // sectors to the same eight-gua sector. Keep the emitted gua set
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
            let lore = missingCornerLoreWithSource(gua: palace.gua, lore: content.lore)
            results.append(FloorplanAuditItem(
                id: "missing-corner-\(palace.gua)",
                title: content.title,
                palace: palace.dir,
                severity: "预警",
                lore: lore,
                solution: content.solution
            ))
        }
        return results
    }

    /// Returns the exact union area of axis-aligned room rectangles clipped to
    /// one grid sector. Summing each overlap would count overlapping custom
    /// rooms twice, while checking only one room misses a sector assembled from
    /// several smaller rooms. A sweep over the rectangles' x breakpoints keeps
    /// this calculation deterministic and inexpensive (only eight sectors).
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

    private func tr8(
        _ hans: String,
        _ hant: String,
        _ en: String,
        _ ja: String,
        _ ko: String,
        _ vi: String,
        _ th: String,
        _ id: String
    ) -> String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .zhHant: return hant
        case .en: return en
        case .ja: return ja
        case .ko: return ko
        case .vi: return vi
        case .th: return th
        case .id: return id
        case .auto, .zhHans: return hans
        }
    }

    /// Adds the classical source and plain-language context to the two
    /// missing-corner sectors whose traditional interpretation includes
    /// wealth or water-flow language. The Chinese strings already contain
    /// their citations; this keeps the other localized reports equally
    /// explicit without replacing the original judgment.
    private func missingCornerLoreWithSource(gua: String, lore: String) -> String {
        let isXun = ["巽", "Xun", "손", "Tốn", "ซวิ่น"].contains(gua)
        let isKan = ["坎", "Kan", "감", "Khảm", "ข่าน"].contains(gua)
        guard isXun || isKan else { return lore }
        let language = LocalizationManager.shared.effectiveLanguage
        let source: String
        if isXun {
            switch language {
            case .en: source = "Classical source: the Book of Changes, Discussion of the Trigrams, says ‘Xun is Wood, Wind, the eldest daughter and entering.’ Later yang-house traditions extend this to wealth and networks."
            case .ja: source = "出典：『易経・説卦伝』「巽は木、風、長女、入」。後世の陽宅論では財・人脈・資源の流れに引き継ぎます。"
            case .ko: source = "출처: 《주역·설괘전》 ‘손은 나무·바람·장녀·들어감’이라 하며, 후대 양택론은 이를 재물·인맥·자원 흐름으로 풀이합니다."
            case .vi: source = "Nguồn: 《Kinh Dịch·Thuyết Quái》 ghi ‘Tốn là Mộc, là Gió, con gái trưởng và sự đi vào’; dương trạch hậu thế diễn giải thêm về tài lộc, quan hệ và dòng nguồn lực."
            case .th: source = "แหล่งที่มา: 《อี้จิง·ซัวกว้า》กล่าวว่า ‘ซวิ่นคือไม้ ลม บุตรสาวคนโต และการเข้า’; ตำราหยางไจ๋ภายหลังขยายความเป็นทรัพย์ เครือข่าย และการไหลของทรัพยากร"
            case .id: source = "Sumber klasik: 《I Ching·Shuo Gua》 menyebut ‘Xun adalah Kayu, Angin, putri sulung dan memasuki’; tradisi yang zhai kemudian mengaitkannya dengan rezeki, jaringan dan arus sumber daya."
            case .zhHant, .zhHans, .auto: source = ""
            }
        } else {
            switch language {
            case .en: source = "Classical source: the Book of Changes, Discussion of the Trigrams, says ‘Kan is Water, channels and concealment.’ Later yang-house traditions extend this to wealth flow and drainage."
            case .ja: source = "出典：『易経・説卦伝』「坎は水、溝瀆、隠伏」。後世の陽宅論では財の流れと水回りに引き継ぎます。"
            case .ko: source = "출처: 《주역·설괘전》 ‘감은 물·도랑·숨음’이라 하며, 후대 양택론은 이를 재물 흐름과 배수로 풀이합니다."
            case .vi: source = "Nguồn: 《Kinh Dịch·Thuyết Quái》 ghi ‘Khảm là Nước, mương rãnh và ẩn phục’; dương trạch hậu thế diễn giải thêm về dòng tài lộc và thoát nước."
            case .th: source = "แหล่งที่มา: 《อี้จิง·ซัวกว้า》กล่าวว่า ‘ข่านคือน้ำ คูคลอง และการซ่อนเร้น’; ตำราหยางไจ๋ภายหลังขยายความเป็นกระแสทรัพย์และทางระบายน้ำ"
            case .id: source = "Sumber klasik: 《I Ching·Shuo Gua》 menyebut ‘Kan adalah Air, saluran dan tersembunyi’; tradisi yang zhai kemudian mengaitkannya dengan arus rezeki dan drainase."
            case .zhHant, .zhHans, .auto: source = ""
            }
        }
        guard !source.isEmpty else { return lore }
        return "\(lore) \(source)"
    }

    private func missingCornerContent(gua: String) -> (title: String, lore: String, solution: String) {
        switch gua {
        case "乾", "Qian", "건", "Càn", "เฉียน":
            return (
                tr8(
                    "户型缺角 · 西北乾位", "戶型缺角 · 西北乾位", "Missing Corner · Northwest Qian",
                    "間取りの欠け・北西乾位", "평면 결손 · 서북 건위", "Khuyết góc nhà · Tây Bắc Càn vị",
                    "มุมเว้าแหว่ง · ทิศตะวันตกเฉียงเหนือเฉียน", "Sudut Hilang · Barat Laut Qian"
                ),
                tr8(
                    "西北乾位缺角常被用于提示家中长辈、男主人、事业支持和居住稳定性方面需要关注；当前判断基于房间框，需先核对真实外墙。",
                    "西北乾位缺角常被用於提示家中長輩、男主人、事業支持和居住穩定性方面需要關注；當前判斷基於房間框，需先核對真實外牆。",
                    "A northwest Qian gap is traditionally associated with elder support, the male householder, career backing and stability; verify the actual exterior wall because this result is inferred from room boxes.",
                    "北西の乾位の欠けは家長、父親、事業の後援および居住の安定性に留意が必要とされます。外壁の現況をご確認ください。",
                    "서북 건위 결손은 집안 어른, 가장, 사업적 후원 및 주거 안정성과 연관됩니다. 실제 외벽 상태를 먼저 확인하세요.",
                    "Khuyết góc Tây Bắc Càn vị thường báo hiệu cần chú ý đến người lớn tuổi, gia chủ nam, vận thế sự nghiệp và sự ổn định gia trạch.",
                    "มุมเว้าแหว่งทิศตะวันตกเฉียงเหนือเฉียน บ่งชี้ถึงสุขภาพผู้นำครอบครัว การเกื้อหนุนในหน้าที่การงาน และความมั่นคง ควรตรวจสอบผนังจริง อ้างอิงตำราฮวงจุ้ยโบราณ; ถ้อยคำเรื่องสุขภาพเป็นสัญลักษณ์ทางวัฒนธรรม ไม่ใช่การวินิจฉัยทางการแพทย์",
                    "Kekurangan sudut barat laut Qian dikaitkan dengan dukungan tetua, kepala keluarga, stabilitas karir dan rumah tangga."
                ),
                tr8(
                    "首选补足真实外墙或封闭式储物/设备空间；无法改造时，可用圆形金属灯具、白色或金色圆器、稳固高柜作视觉补足，保持干燥明亮，避免以大型水景或杂物堆积代替。",
                    "首選補足真實外牆或封閉式儲物／設備空間；無法改造時，可用圓形金屬燈具、白色或金色圓器、穩固高櫃作視覺補足，保持乾燥明亮，避免以大型水景或雜物堆積代替。",
                    "Prefer completing the exterior wall or using an enclosed storage/service space. If construction is impossible, use a round metal light, white or gold circular decor, or a stable tall cabinet as a visual countermeasure; keep it dry and bright, and avoid a large water feature or clutter.",
                    "外壁の補修や収納スペースの増設を推奨します。改造できない場合は丸型金属照明や安定感のある家具で補い、明るく保ちます。",
                    "외벽 보완이나 수납공간 배치를 권장합니다. 시공이 어려울 경우 원형 금속 조명, 금색 원형 소품, 견고한 수납장으로 보완하세요.",
                    "Ưu tiên hoàn thiện tường ngoài hoặc bố trí tủ chứa đồ kín. Nếu không thể cải tạo, dùng đèn kim loại tròn, vật phẩm tròn màu trắng kim.",
                    "แนะนำให้ปิดผนังให้สมบูรณ์ หรือใช้ตู้เก็บของแบบทึบ หากแก้ไขไม่ได้ ให้ใช้โคมไฟโลหะทรงกลม ของตกแต่งสีทองหรือขาวเพื่อเสริมพลัง",
                    "Lengkapi dinding luar atau pasang lemari tertutup; jika tidak memungkinkan, gunakan lampu logam bundar, dekorasi emas/putih bulat, atau kabinet kokoh."
                )
            )
        case "艮", "Gen", "간", "Cấn", "เกิ่น":
            return (
                tr8(
                    "户型缺角 · 东北艮位", "戶型缺角 · 東北艮位", "Missing Corner · Northeast Gen",
                    "間取りの欠け・北東艮位", "평면 결손 · 동북 간위", "Khuyết góc nhà · Đông Bắc Cấn vị",
                    "มุมเว้าแหว่ง · ทิศตะวันออกเฉียงเหนือเกิ่น", "Sudut Hilang · Timur Laut Gen"
                ),
                tr8(
                    "东北艮位缺角常被用于提示家庭稳定、子女成长、学习专注和储藏空间方面需要关注；当前判断基于房间框，需先核对真实外墙。",
                    "東北艮位缺角常被用於提示家庭穩定、子女成長、學習專注和儲藏空間方面需要關注；當前判斷基於房間框，需先核對真實外牆。",
                    "A northeast Gen gap is traditionally associated with household stability, children, study focus and storage; verify the actual exterior wall because this result is inferred from room boxes.",
                    "北東の艮位の欠けは家庭の安定、子どもの学業や成長、保管空間に留意が必要とされます。",
                    "동북 간위 결손은 가족의 안정, 자녀의 성장 및 학업 집중도와 연관됩니다. 실제 외벽 구조를 점검하세요.",
                    "Khuyết góc Đông Bắc Cấn vị liên quan đến sự ổn định gia đình, sự phát triển học tập của con cái và không gian tích trữ.",
                    "มุมเว้าแหว่งทิศตะวันออกเฉียงเหนือเกิ่น ส่งผลต่อความมั่นคงในครอบครัว การเติบโตและการเรียนรู้ของบุตรหลาน",
                    "Kekurangan sudut timur laut Gen dikaitkan dengan kestabilan rumah, tumbuh kembang anak, dan fokus belajar."
                ),
                tr8(
                    "首选补足墙体或设置封闭、整洁的储物柜；无法改造时，可放置黄色陶瓷、天然石材、方形地毯或暖色灯光作稳定补足，保持安静干燥，避免潮湿和杂乱。",
                    "首選補足牆體或設置封閉、整潔的儲物櫃；無法改造時，可放置黃色陶瓷、天然石材、方形地毯或暖色燈光作穩定補足，保持安靜乾燥，避免潮濕和雜亂。",
                    "Prefer completing the wall or adding a closed, orderly cabinet. If construction is impossible, use yellow ceramic, natural stone, a square rug or warm lighting to add visual stability; keep the area quiet and dry.",
                    "収納棚の設置を推奨します。黄色い陶器や天然石、四角いラグマットを配置して気を安定させます。",
                    "벽체를 보강하거나 수납장을 배치하세요. 노란색 도자기, 천연석, 사각형 러그나 따뜻한 조명으로 안정감을 보강하세요.",
                    "Nên bổ sung tường hoặc kê tủ kín gọn gàng. Có thể dùng gốm sứ màu vàng, đá tự nhiên, thảm vuông hoặc đèn ánh sáng ấm.",
                    "กั้นผนังหรือวางตู้เก็บของให้เป็นระเบียบ หรือจัดวางแจกันเซรามิกสีเหลือง หินธรรมชาติ พรมทรงสี่เหลี่ยม และไฟโทนอุ่น",
                    "Lengkapi dinding atau pasang lemari tertutup; gunakan keramik kuning, batu alam, karpet persegi, atau lampu hangat untuk stabilitas."
                )
            )
        case "巽", "Xun", "손", "Tốn", "ซวิ่น":
            return (
                tr8(
                    "户型缺角 · 东南巽位", "戶型缺角 · 東南巽位", "Missing Corner · Southeast Xun",
                    "間取りの欠け・南東巽位", "평면 결손 · 동남 손위", "Khuyết góc nhà · Đông Nam Tốn vị",
                    "มุมเว้าแหว่ง · ทิศตะวันออกเฉียงใต้ซวิ่น", "Sudut Hilang · Tenggara Xun"
                ),
                tr8(
                    "东南巽位缺角常被用于提示财务规划、资源流动、沟通关系和通风采光方面需要关注；出处：《易经·说卦传》：“巽为木，为风，为长女，为入。”传统阳宅缺角论将巽位引申为财帛、人脉与资源流动。解释：以上是古籍方位象征，当前判断基于房间框，需先核对真实外墙，财务事项请独立核实。",
                    "東南巽位缺角常被用於提示財務規劃、資源流動、溝通關係和通風採光方面需要關注；出處：《易經·說卦傳》：「巽為木，為風，為長女，為入。」傳統陽宅缺角論將巽位引申為財帛、人脈與資源流動。解釋：以上是古籍方位象徵，當前判斷基於房間框，需先核對真實外牆，財務事項請獨立核實。",
                    "A southeast Xun gap is traditionally associated with financial planning, resource flow, relationships, ventilation and daylight. The Book of Changes, Discussion of the Trigrams, says: ‘Xun is Wood, Wind, the eldest daughter and entering.’ Later yang-house traditions extend this to wealth and networks. Verify the actual exterior wall; check financial decisions independently.",
                    "南東の巽位の欠けは財政計画、人脈関係、風通しや日当たりに留意が必要とされます。",
                    "동남 손위 결손은 재정 계획, 자원 순환, 대인관계 및 채광·통풍에 주의가 필요함을 나타냅니다.",
                    "Khuyết góc Đông Nam Tốn vị liên quan đến tài chính, lưu thông của cải, giao tiếp xã hội và độ thông thoáng.",
                    "มุมเว้าแหว่งทิศตะวันออกเฉียงใต้ซวิ่น ส่งผลต่อการวางแผนการเงิน ความสัมพันธ์ และการระบายอากาศรับแสงแดด",
                    "Kekurangan sudut tenggara Xun dikaitkan dengan perencanaan keuangan, relasi sosial, serta ventilasi dan pencahayaan."
                ),
                tr8(
                    "首选补足外墙或设置连续的木质收纳/绿化界面；无法改造时，可用易养阔叶植物、木质柜体、青绿色软装和柔和照明作替代，保持通风，避免尖角、破损和堆物。",
                    "首選補足外牆或設置連續的木質收納／綠化界面；無法改造時，可用易養闊葉植物、木質櫃體、青綠色軟裝和柔和照明作替代，保持通風，避免尖角、破損和堆物。",
                    "Prefer completing the exterior wall or adding a continuous wood storage or planting boundary. If construction is impossible, use easy-care broad-leaf plants, wood cabinetry, teal-green textiles and soft lighting; keep ventilation clear and avoid sharp corners, damage and clutter.",
                    "木製キャビネットや観葉植物の設置を推奨します。青緑系のインテリアや柔らかな照明で補いましょう。",
                    "외벽 보강 또는 원목 수납장 배치를 권장합니다. 넓은 잎 식물, 청록색 패브릭, 부드러운 조명으로 기운을 북돋우세요.",
                    "Nên bổ sung tường hoặc vách gỗ. Có thể đặt cây xanh lá rộng, tủ gỗ, nội thất tông xanh lá và ánh sáng dịu nhẹ.",
                    "แนะนำให้ตกแต่งด้วยตู้ไม้ ต้นไม้ใบเขียวชอุ่ม ของตกแต่งโทนสีเขียว และแสงไฟนุ่มนวล ระบายอากาศให้โปร่งสบาย",
                    "Gunakan dinding kayu atau tanaman berdaun lebar, perabot kayu, dekorasi bernuansa hijau, dan pencahayaan lembut."
                )
            )
        case "坤", "Kun", "곤", "Khôn", "คุน":
            return (
                tr8(
                    "户型缺角 · 西南坤位", "戶型缺角 · 西南坤位", "Missing Corner · Southwest Kun",
                    "間取りの欠け・南西坤位", "평면 결손 · 서남 곤위", "Khuyết góc nhà · Tây Nam Khôn vị",
                    "มุมเว้าแหว่ง · ทิศตะวันตกเฉียงใต้คุน", "Sudut Hilang · Barat Daya Kun"
                ),
                tr8(
                    "西南坤位缺角常被用于提示家庭照料、伴侣关系、生活承托和居住安定方面需要关注；当前判断基于房间框，需先核对真实外墙。",
                    "西南坤位缺角常被用於提示家庭照料、伴侶關係、生活承托和居住安定方面需要關注；當前判斷基於房間框，需先核對真實外牆。",
                    "A southwest Kun gap is traditionally associated with caregiving, partnership, household support and stability; verify the actual exterior wall because this result is inferred from room boxes.",
                    "南西の坤位の欠けは家庭内のケア、夫婦関係、生活基盤の安定に留意が必要とされます。",
                    "서남 곤위 결손은 가족 돌봄, 부부 관계, 생활의 지지력 및 거주 안정성과 연관됩니다.",
                    "Khuyết góc Tây Nam Khôn vị nhắc nhở cần chú trọng đến tình cảm vợ chồng, sự bao dung và ổn định đời sống.",
                    "มุมเว้าแหว่งทิศตะวันตกเฉียงใต้คุน ส่งผลต่อความอบอุ่นในครอบครัว ความสัมพันธ์คู่ครอง และความมั่นคงในชีวิต",
                    "Kekurangan sudut barat daya Kun dikaitkan dengan keharmonisan pasangan, dukungan domestik, dan ketenangan hidup."
                ),
                tr8(
                    "首选补足墙体或设置低矮、稳定的封闭柜体；无法改造时，可用黄色或米色陶瓷、天然石材、方形地垫和暖光作替代，保持整洁稳定，避免空置、漏水和尖锐杂物。",
                    "首選補足牆體或設置低矮、穩定的封閉櫃體；無法改造時，可用黃色或米色陶瓷、天然石材、方形地墊和暖光作替代，保持整潔穩定，避免空置、漏水和尖銳雜物。",
                    "Prefer completing the wall or adding a low, stable closed cabinet. If construction is impossible, use yellow or beige ceramic, natural stone, a square mat and warm light; keep it orderly and stable, avoiding leaks and sharp clutter.",
                    "安定感のあるローキャビネットの設置を推奨します。黄色やベージュの陶器、天然石、角型マットで気を補いましょう。",
                    "낮고 안정된 수납장을 배치하세요. 황색이나 베이지색 도자기, 천연석, 사각 매트와 따뜻한 조명으로 보완하세요.",
                    "Nên bố trí tủ thấp vững chãi. Có thể đặt gốm sứ màu vàng/kem, đá tự nhiên, thảm vuông và đèn ánh sáng ấm.",
                    "จัดวางตู้ทึบทรงเตี้ยที่มั่นคง หรือใช้เครื่องปั้นดินเผาสีครีม/เหลือง หินธรรมชาติ พรมสี่เหลี่ยม และไฟโทนอบอุ่น",
                    "Gunakan lemari rendah yang stabil, keramik krem/kuning, batu alam, keset persegi, dan pencahayaan hangat."
                )
            )
        case "坎", "Kan", "감", "Khảm", "ข่าน":
            return (
                tr8(
                    "户型缺角 · 正北坎位", "戶型缺角 · 正北坎位", "Missing Corner · North Kan",
                    "間取りの欠け・正北坎位", "평면 결손 · 정북 감위", "Khuyết góc nhà · Chính Bắc Khảm vị",
                    "มุมเว้าแหว่ง · ทิศเหนือข่าน", "Sudut Hilang · Utara Kan"
                ),
                tr8(
                    "正北坎位缺角常被用于提示作息安全、情绪压力、财务流动和与水有关的使用空间；出处：《易经·说卦传》：“坎为水，为沟渎，为隐伏。”传统阳宅缺角论将坎位引申为财源、流动与水路。解释：以上是古籍方位象征，当前判断基于房间框，需先核对真实外墙、管线和排水，财务事项请独立核实。",
                    "正北坎位缺角常被用於提示作息安全、情緒壓力、財務流動和與水有關的使用空間；出處：《易經·說卦傳》：「坎為水，為溝瀆，為隱伏。」傳統陽宅缺角論將坎位引申為財源、流動與水路。解釋：以上是古籍方位象徵，當前判斷基於房間框，需先核對真實外牆、管線和排水，財務事項請獨立核實。",
                    "A north Kan gap is traditionally associated with rest, emotional pressure, financial flow and water-related utilities. The Book of Changes, Discussion of the Trigrams, says: ‘Kan is Water, channels and concealment.’ Later yang-house traditions extend this to wealth flow and drainage. Verify the exterior wall, pipes and drainage; check financial decisions independently.",
                    "北の坎位の欠けは休息の質、精神的ストレス、財の循環や配管・水回りの安全に留意が必要とされます。",
                    "정북 감위 결손은 휴식의 질, 감정적 스트레스, 재정 유동성 및 배수 상태와 연관됩니다.",
                    "Khuyết góc Chính Bắc Khảm vị nhắc nhở lưu ý đến giấc ngủ, áp lực tinh thần, dòng chảy tài chính và hệ thống cấp thoát nước.",
                    "มุมเว้าแหว่งทิศเหนือข่าน สัมพันธ์กับการพักผ่อน ความเครียด การหมุนเวียนของเงิน และระบบประปา",
                    "Kekurangan sudut utara Kan dikaitkan dengan kualitas istirahat, tekanan emosional, arus kas, dan saluran air."
                ),
                tr8(
                    "首选补足外墙并检查防水、排水和采光；无法改造时，可用深色稳重收纳、适度照明和金属/玻璃小件作替代，保持地面干燥，避免漏水、阴暗和大面积镜面。",
                    "首選補足外牆並檢查防水、排水和採光；無法改造時，可用深色穩重收納、適度照明和金屬／玻璃小件作替代，保持地面乾燥，避免漏水、陰暗和大面積鏡面。",
                    "Prefer completing the wall and checking waterproofing, drainage and daylight. If construction is impossible, use stable dark-toned storage, measured lighting and small metal or glass accents; keep floors dry and avoid leaks, darkness and large mirrors.",
                    "防水や排水を点検し壁を補強します。ダークトーンの落ち着いた収納棚や適切な照明で乾燥を保ちましょう。",
                    "외벽 및 방수·배수를 점검하세요. 짙은 색상의 안정감 있는 수납장, 적절한 조명과 금속 장식으로 건조하고 밝게 유지하세요.",
                    "Kiểm tra chống thấm thoát nước; dùng tủ lưu trữ màu sẫm vững chắc, bổ sung ánh sáng, giữ sàn nhà khô ráo thông thoáng.",
                    "ตรวจเช็กระบบกันซึมและทางระบายน้ำ ตกแต่งด้วยตู้โทนสีเข้ม ไฟส่องสว่างพอเหมาะ รักษาพื้นให้แห้งเสมอ",
                    "Periksa drainase dan kebocoran; gunakan tempat penyimpanan berwarna gelap, pencahayaan cukup, dan jaga lantai tetap kering."
                )
            )
        case "震", "Zhen", "진", "Chấn", "เจิ้น":
            return (
                tr8(
                    "户型缺角 · 正东震位", "戶型缺角 · 正東震位", "Missing Corner · East Zhen",
                    "間取りの欠け・正東震位", "평면 결손 · 정동 진위", "Khuyết góc nhà · Chính Đông Chấn vị",
                    "มุมเว้าแหว่ง · ทิศตะวันออกเจิ้น", "Sudut Hilang · Timur Zhen"
                ),
                tr8(
                    "正东震位缺角常被用于提示家庭行动力、长子成长、启动计划和日常通行；当前判断基于房间框，需先核对真实外墙和门窗。",
                    "正東震位缺角常被用於提示家庭行動力、長子成長、啟動計畫和日常通行；當前判斷基於房間框，需先核對真實外牆和門窗。",
                    "An east Zhen gap is traditionally associated with initiative, the eldest child, new plans and daily movement; verify the exterior wall, doors and windows because this result is inferred from room boxes.",
                    "東の震位の欠けは行動力、長男の成長、新たな計画の立ち上げや日常の動線に留意が必要とされます。",
                    "정동 진위 결손은 가족의 실행력, 장남의 성장, 새로운 계획의 추진력과 연관됩니다.",
                    "Khuyết góc Chính Đông Chấn vị liên quan đến sức sống, tính hành động, sự phát triển của trưởng nam và các kế hoạch mới.",
                    "มุมเว้าแหว่งทิศตะวันออกเจิ้น สัมพันธ์กับพลังขับเคลื่อน ความก้าวหน้าของบุตรชายคนโต และการเริ่มต้นสิ่งใหม่",
                    "Kekurangan sudut timur Zhen dikaitkan dengan inisiatif, putra sulung, dan permulaan rencana baru."
                ),
                tr8(
                    "首选补足外墙或形成连续的木质界面；无法改造时，可用易养绿植、竖向木柜、木质屏风和充足但不刺眼的照明作替代，保持通道顺畅，避免破损电器、尖角和杂物阻路。",
                    "首選補足外牆或形成連續的木質界面；無法改造時，可用易養綠植、豎向木櫃、木質屏風和充足但不刺眼的照明作替代，保持通道順暢，避免破損電器、尖角和雜物阻路。",
                    "Prefer completing the wall or creating a continuous wood boundary. If construction is impossible, use easy-care plants, vertical wood storage, a wood screen and even lighting; keep circulation clear and avoid damaged appliances, sharp corners and blocked paths.",
                    "木製の壁やパーテーションの増設を推奨します。観葉植物や木製家具、柔らかな照明で気の通りを良くします。",
                    "원목 파티션이나 수납장을 권장합니다. 싱싱한 식물, 키 큰 원목 가구, 충분한 조명으로 통로를 원활히 유지하세요.",
                    "Bổ sung tường hoặc vách ngăn gỗ. Bố trí cây xanh tươi tốt, tủ đứng bằng gỗ, bình phong gỗ và ánh sáng hài hòa.",
                    "เสริมแนวผนังไม้หรือระแนงไม้ ตกแต่งด้วยต้นไม้เขียวสดใส ตู้ไม้แนวตั้ง ฉากกั้นไม้ และเปิดทางเดินให้โล่งสบาย",
                    "Lengkapi dengan panel kayu atau sekat; tempatkan tanaman segar, lemari kayu vertikal, dan pencahayaan yang cukup."
                )
            )
        case "离", "Li", "이", "Ly", "หลี":
            return (
                tr8(
                    "户型缺角 · 正南离位", "戶型缺角 · 正南離位", "Missing Corner · South Li",
                    "間取りの欠け・正南離位", "평면 결손 · 정남 이위", "Khuyết góc nhà · Chính Nam Ly vị",
                    "มุมเว้าแหว่ง · ทิศใต้หลี", "Sudut Hilang · Selatan Li"
                ),
                tr8(
                    "正南离位缺角常被用于提示采光、可见度、表达沟通和家庭活力；当前判断基于房间框，需先核对真实外墙、窗户和消防条件。",
                    "正南離位缺角常被用於提示採光、可見度、表達溝通和家庭活力；當前判斷基於房間框，需先核對真實外牆、窗戶和消防條件。",
                    "A south Li gap is traditionally associated with daylight, visibility, communication and household vitality; verify the exterior wall, windows and fire-safety conditions because this result is inferred from room boxes.",
                    "南の離位の欠けは採光、自己表現、コミュニケーションや家庭の活気に留意が必要とされます。",
                    "정남 이위 결손은 채광, 대외적 명성, 소통 및 가족의 활력과 연관됩니다.",
                    "Khuyết góc Chính Nam Ly vị liên quan đến ánh sáng, danh tiếng, khả năng biểu đạt và sức sống của gia đình.",
                    "มุมเว้าแหว่งทิศใต้หลี สัมพันธ์กับแสงสว่าง ชื่อเสียง การสื่อสาร และความมีชีวิตชีวาของครอบครัว",
                    "Kekurangan sudut selatan Li dikaitkan dengan pencahayaan alami, reputasi, komunikasi, dan vitalitas keluarga."
                ),
                tr8(
                    "首选补足外墙并改善自然采光；无法改造时，可用合规的暖色照明、红紫色小面积软装和整洁的开放展示位作替代，避免明火、过热设备、遮挡逃生通道和过度反光。",
                    "首選補足外牆並改善自然採光；無法改造時，可用合規的暖色照明、紅紫色小面積軟裝和整潔的開放展示位作替代，避免明火、過熱設備、遮擋逃生通道和過度反光。",
                    "Prefer completing the wall and improving daylight. If construction is impossible, use code-compliant warm lighting, small red or purple accents and an orderly display area; avoid open flames, overheating devices, blocked exits and excessive glare.",
                    "採光を改善し壁を補完します。暖色系の照明やアクセントとしての赤・紫系のインテリアを活用します。",
                    "채광을 개선하고 벽을 보강하세요. 규격에 맞는 따뜻한 조명, 붉은색 계열 소품 및 깔끔한 장식 공간으로 보완하세요.",
                    "Cải thiện ánh sáng tự nhiên; dùng đèn ấm, điểm xuyết một chút sắc đỏ tím trang nhã và giữ khu vực gọn gàng.",
                    "ปรับปรุงการรับแสงธรรมชาติ ติดตั้งไฟโทนอุ่น ตกแต่งด้วยโทนสีแดงอมม่วงเล็กน้อย และจัดพื้นที่ให้โปร่งโล่งปลอดภัย",
                    "Tingkatkan pencahayaan; gunakan lampu hangat, aksen dekorasi merah/ungu kecil, dan tata area pajangan dengan rapi."
                )
            )
        case "兑", "Dui", "태", "Đoài", "ตุ้ย":
            return (
                tr8(
                    "户型缺角 · 正西兑位", "戶型缺角 · 正西兌位", "Missing Corner · West Dui",
                    "間取りの欠け・正西兌位", "평면 결손 · 정서 태위", "Khuyết góc nhà · Chính Tây Đoài vị",
                    "มุมเว้าแหว่ง · ทิศตะวันตกตุ้ย", "Sudut Hilang · Barat Dui"
                ),
                tr8(
                    "正西兑位缺角常被用于提示沟通表达、子女互动、收纳秩序和生活愉悦感；当前判断基于房间框，需先核对真实外墙和窗边空间。",
                    "正西兌位缺角常被用於提示溝通表達、子女互動、收納秩序和生活愉悅感；當前判斷基於房間框，需先核對真實外牆和窗邊空間。",
                    "A west Dui gap is traditionally associated with communication, children, storage order and enjoyment of daily life; verify the exterior wall and window-side space because this result is inferred from room boxes.",
                    "西の兌位の欠けは人間関係の調和、会話、収容秩序や生活の楽しみに留意が必要とされます。",
                    "정서 태위 결손은 원활한 대화, 자녀와의 교감, 수납 질서 및 생활의 기쁨과 연관됩니다.",
                    "Khuyết góc Chính Tây Đoài vị liên quan đến giao tiếp, tương tác với con cái, trật tự lưu trữ và niềm vui cuộc sống.",
                    "มุมเว้าแหว่งทิศตะวันตกตุ้ย ส่งผลต่อการพูดคุยสื่อสาร ปฏิสัมพันธ์กับลูกหลาน และความสุขในชีวิตประจำวัน",
                    "Kekurangan sudut barat Dui dikaitkan dengan komunikasi, keakraban anak, dan kerapian penyimpanan."
                ),
                tr8(
                    "首选补足外墙或设置整洁的封闭收纳；无法改造时，可用白色、金属色圆形物件、柔和灯光和易清洁材质作替代，保持安静整齐，避免尖锐金属、破损物品和噪声源。",
                    "首選補足外牆或設置整潔的封閉收納；無法改造時，可用白色、金屬色圓形物件、柔和燈光和易清潔材質作替代，保持安靜整齊，避免尖銳金屬、破損物品和噪聲源。",
                    "Prefer completing the wall or adding orderly closed storage. If construction is impossible, use white or metallic round objects, soft lighting and easy-clean materials; keep it quiet and orderly, avoiding sharp metal, damaged items and noise sources.",
                    "整然とした収納の設置を推奨します。白色やメタリックな丸型アイテム、優しい照明で整えましょう。",
                    "깔끔한 밀폐형 수납장을 배치하세요. 흰색 또는 메탈 원형 소품, 은은한 조명과 청결한 소재로 정돈하세요.",
                    "Bổ sung tường hoặc tủ chứa đồ gọn gàng. Có thể dùng đồ vật tròn màu trắng/ánh kim, ánh sáng êm dịu, giữ yên tĩnh sạch sẽ.",
                    "กั้นผนังหรือวางตู้เก็บของแบบมิดชิด ตกแต่งด้วยของทรงกลมสีขาวหรือสีเมทัลลิก แสงไฟนุ่มนวล และรักษาความสะอาดเงียบสงบ",
                    "Lengkapi dinding atau pasang lemari tertutup; gunakan dekorasi bundar putih/logam, lampu lembut, dan jaga ketenangan."
                )
            )
        default:
            return (
                tr8(
                    "户型缺角 · 当前方位", "戶型缺角 · 當前方位", "Missing Corner · Indicated Direction",
                    "間取りの欠け・該当方位", "평면 결손 · 해당 방위", "Khuyết góc nhà · Phương vị hiện tại",
                    "มุมเว้าแหว่ง · ทิศทางปัจจุบัน", "Sudut Hilang · Arah Terkait"
                ),
                tr8(
                    "房屋外接轮廓在当前方位出现空缺，可能影响户型边界完整性；当前结果基于房间框近似。",
                    "房屋外接輪廓在當前方位出現空缺，可能影響戶型邊界完整性；當前結果基於房間框近似。",
                    "The inferred footprint is open in the indicated direction; this result is an approximation based on room boxes.",
                    "建物の外郭輪郭に該当方位の欠けがあり、間取りの完全性に影響する可能性があります。",
                    "외곽 윤곽선의 해당 방위에 결손이 있어 평면의 완전성에 영향을 줄 수 있습니다.",
                    "Đường bao công trình ở phương vị này có khoảng trống, có thể ảnh hưởng đến sự vuông vức toàn diện.",
                    "ขอบเขตตัวอาคารในทิศทางนี้มีช่องเว้าแหว่ง อาจส่งผลต่อความสมบูรณ์ของรูปทรงบ้าน",
                    "Garis luar bangunan terbuka di arah ini, dapat mempengaruhi keutuhan bentuk rumah."
                ),
                tr8(
                    "核对对应外墙、阳台和附属空间，确认缺角是否真实存在。",
                    "核對對應外牆、陽台和附屬空間，確認缺角是否真實存在。",
                    "Check the corresponding exterior wall, balcony and attached spaces to confirm the actual outline.",
                    "外壁やベランダ、付帯空間を確認し、欠けの有無を実地でご確認ください。",
                    "해당 외벽, 발코니 및 부속 공간을 대조하여 실제 결손 여부를 확인하세요.",
                    "Đối chiếu tường ngoài, ban công và các không gian phụ để xác nhận góc khuyết thực tế.",
                    "ตรวจสอบแนวผนัง ระเบียง และพื้นที่ต่อเนื่อง เพื่อยืนยันว่ามีมุมแหว่งจริงหรือไม่",
                    "Periksa dinding luar, balkon, dan area tambahan untuk memastikan bentuk nyata."
                )
            )
        }
    }
    
    private func resolvePalace(geoAngle: Double) -> (dir: String, gua: String) {
        let lang = LocalizationManager.shared.effectiveLanguage
        let norm = geoAngle.truncatingRemainder(dividingBy: 360.0)
        let angle = norm < 0 ? norm + 360.0 : norm
        
        let index: Int
        if angle >= 337.5 || angle < 22.5 { index = 0 }       // North Kan
        else if angle >= 22.5 && angle < 67.5 { index = 1 }   // Northeast Gen
        else if angle >= 67.5 && angle < 112.5 { index = 2 }  // East Zhen
        else if angle >= 112.5 && angle < 157.5 { index = 3 } // Southeast Xun
        else if angle >= 157.5 && angle < 202.5 { index = 4 } // South Li
        else if angle >= 202.5 && angle < 247.5 { index = 5 } // Southwest Kun
        else if angle >= 247.5 && angle < 292.5 { index = 6 } // West Dui
        else { index = 7 }                                    // Northwest Qian
        
        switch lang {
        case .en:
            let dirs = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
            let guas = ["Kan", "Gen", "Zhen", "Xun", "Li", "Kun", "Dui", "Qian"]
            return (dirs[index], guas[index])
        case .zhHant:
            let dirs = ["正北", "東北", "正東", "東南", "正南", "西南", "正西", "西北"]
            let guas = ["坎", "艮", "震", "巽", "離", "坤", "兌", "乾"]
            return (dirs[index], guas[index])
        case .ja:
            let dirs = ["北", "北東", "東", "南東", "南", "南西", "西", "北西"]
            let guas = ["坎", "艮", "震", "巽", "離", "坤", "兌", "乾"]
            return (dirs[index], guas[index])
        case .ko:
            let dirs = ["북", "북동", "동", "동남", "남", "남서", "서", "북서"]
            let guas = ["감", "간", "진", "손", "이", "곤", "태", "건"]
            return (dirs[index], guas[index])
        case .vi:
            let dirs = ["Bắc", "Đông Bắc", "Đông", "Đông Nam", "Nam", "Tây Nam", "Tây", "Tây Bắc"]
            let guas = ["Khảm", "Cấn", "Chấn", "Tốn", "Ly", "Khôn", "Đoài", "Càn"]
            return (dirs[index], guas[index])
        case .th:
            let dirs = ["ทิศเหนือ", "ตะวันออกเฉียงเหนือ", "ทิศตะวันออก", "ตะวันออกเฉียงใต้", "ทิศใต้", "ตะวันตกเฉียงใต้", "ทิศตะวันตก", "ตะวันตกเฉียงเหนือ"]
            let guas = ["ข่าน", "เกิ่น", "เจิ้น", "ซวิ่น", "หลี", "คุน", "ตุ้ย", "เฉียน"]
            return (dirs[index], guas[index])
        case .id:
            let dirs = ["Utara", "Timur Laut", "Timur", "Tenggara", "Selatan", "Barat Daya", "Barat", "Barat Laut"]
            let guas = ["Kan", "Gen", "Zhen", "Xun", "Li", "Kun", "Dui", "Qian"]
            return (dirs[index], guas[index])
        case .zhHans, .auto:
            let dirs = ["正北", "东北", "正东", "东南", "正南", "西南", "正西", "西北"]
            let guas = ["坎", "艮", "震", "巽", "离", "坤", "兑", "乾"]
            return (dirs[index], guas[index])
        }
    }
    
    private func evaluateRoom(type: FloorplanRoomType, palaceGua: String, palaceDir: String) -> (title: String, level: String, lore: String, advice: String) {
        switch (type, palaceGua) {
        case (.kitchen, "乾"), (.kitchen, "Qian"), (.kitchen, "건"), (.kitchen, "Càn"), (.kitchen, "เฉียน"):
            return (
                tr8("火烧天门大煞", "火燒天門大煞", "Heaven Gate Fire Sha", "火焼天門殺", "화소천문살", "Hỏa Thiêu Thiên Môn Đại Sát", "เคราะห์ไฟเผาประตูสวรรค์", "Sha Api Membakar Gerbang Surga"),
                "严重煞气",
                tr8(
                    "《阳宅十书》原文有“乾为天为父为首，灶火克乾金，极不利男主人头部、血压及事业运”。此句属于古籍象征性判断，请现场核对通风、热源距离与消防安全。",
                    "《陽宅十書》原文有「乾為天為父為首，灶火克乾金，極不利男主人頭部、血壓及事業運」。此句屬於古籍象徵性判斷，請現場核對通風、熱源距離與消防安全。",
                    "The Yang Zhai Ten Books states, “Qian represents Heaven, the father and the head; stove fire overcomes Qian Metal and is highly unfavorable to the male head, blood pressure and career.” This is a historical text reference; verify ventilation, heat clearance and fire safety on site.",
                    "乾は天、父親、首座を象徴します。キッチンの火気と空間配置についての伝統文化上の参考提示です。換気と安全を現場で確認してください。",
                    "건위는 하늘과 가장을 상징합니다. 주방의 화기가 건금을 극하여 가장의 두부, 혈압 및 사업운에 불리합니다.",
                    "《Dương Trạch Thập Thư》ghi: “Càn tượng trưng cho Trời, người cha và người đứng đầu; hỏa bếp khắc Càn Kim, bất lợi cho đầu, huyết áp và sự nghiệp của gia chủ nam”. Đây là trích dẫn cổ thư; hãy kiểm tra thông gió, khoảng cách nhiệt và an toàn cháy nổ tại chỗ.",
                    "《หยางไจ๋สือซู》กล่าวว่า “เฉียนคือสวรรค์ บิดา และผู้นำ ไฟจากเตาชนะทองเฉียน ส่งผลไม่ดีต่อศีรษะ ความดันโลหิต และการงานของเจ้าบ้านชาย” นี่เป็นข้อความอ้างอิงโบราณ โปรดตรวจสอบการระบายอากาศ ระยะห่างจากความร้อน และความปลอดภัยจากไฟหน้างาน",
                    "《Yang Zhai Ten Books》menyatakan, “Qian melambangkan Surga, ayah, dan kepala rumah; api dapur mengalahkan Logam Qian dan tidak menguntungkan kepala, tekanan darah, serta karier kepala rumah.” Ini kutipan klasik; periksa ventilasi, jarak panas, dan keselamatan kebakaran di lokasi."
                ),
                tr8(
                    "灶台旁安放天然黄色陶瓷罐，或悬挂真品六帝铜钱以土泄火生金。",
                    "灶台旁安放天然黃色陶瓷罐，或懸掛真品六帝銅錢，以土洩火生金。",
                    "Place a natural yellow ceramic vessel beside the stove, or hang Six Emperor coins so Earth can drain Fire and generate Metal.",
                    "コンロの横に黄色の陶器瓶を置くか、六帝銭を吊るして土気で火を和らげ金を助けます。",
                    "가스레인지 옆에 황색 도자기를 두거나 육제전을 걸어 토로 화기를 설기하고 금을 생조하세요.",
                    "Đặt bình gốm màu vàng cạnh bếp, hoặc treo chuỗi tiền Lục Đế để dùng Thổ tiết Hỏa sinh Kim.",
                    "วางโถเซรามิกสีเหลืองธรรมชาติไว้ข้างเตา หรือแขวนเหรียญหกจักรพรรดิเพื่อใช้ธาตุดินถ่ายเทพลังไฟหนุนธาตุทอง",
                    "Letakkan wadah keramik kuning di dekat kompor atau gantung Koin Enam Kaisar agar Tanah dapat meredam Api dan menghasilkan Logam."
                )
            )
        case (.bathroom, "乾"), (.bathroom, "Qian"), (.bathroom, "건"), (.bathroom, "Càn"), (.bathroom, "เฉียน"):
            return (
                tr8("水浸天门污秽大煞", "水浸天門污穢大煞", "Heaven Gate Water Pollution Sha", "水浸天門殺", "수침천문살", "Thủy Tẩm Thiên Môn Ô Uế Đại Sát", "เคราะห์น้ำท่วมประตูสวรรค์", "Sha Air Mencemari Gerbang Surga"),
                "严重煞气",
                tr8(
                    "乾为天为父，卫浴设于西北，金水相寒污浊天门，主男主人事业阻滞、脑血管与呼吸道隐患。出处：《阳宅十书》相关“水浸天门”论。解释：此为古籍传统象征，请结合防水、通风、干燥和动线现场复核。",
                    "乾為天為父，衛浴設於西北，金水相寒污濁天門，主男主人事業阻滯、腦血管與呼吸道隱患。出處：《陽宅十書》相關「水浸天門」論。解釋：此為古籍傳統象徵，請結合防水、通風、乾燥和動線現場複核。",
                    "The Yang Zhai Ten Books describes a northwest bathroom as “water immersing the Heaven Gate,” traditionally associated with the male householder's career, circulation and breathing. This is a historical quotation; verify waterproofing, ventilation, dryness and circulation on site.",
                    "『陽宅十書』は北西の浴室を「天門に水が浸る」と表現し、家長の事業、循環器・呼吸器の不調に結び付けます。古典の引用として示し、防水、換気、乾燥、動線を現地で確認してください。",
                    "《양택십서》는 서북 욕실을 ‘천문에 물이 잠긴다’고 하며 가장의 사업과 뇌혈관·호흡기 문제에 연결합니다. 고전 인용으로 제시하며 방수·환기·건조·동선을 현장에서 확인하세요.",
                    "Càn là vị trí của người cha; vệ sinh ở Tây Bắc làm Kim Thủy thêm lạnh và ô nhiễm thiên môn, gây trắc trở sự nghiệp và hô hấp.",
                    "《หยางไจ๋สือซู》เรียกห้องน้ำตะวันตกเฉียงเหนือว่า “น้ำท่วมประตูสวรรค์” และเชื่อมโยงกับการงานของผู้นำบ้าน ระบบไหลเวียนและการหายใจ นี่เป็นการอ้างอิงคัมภีร์ โปรดตรวจสอบการกันน้ำ การระบายอากาศ ความแห้ง และทางเดินหน้างาน",
                    "Kamar mandi di barat laut mencemari gerbang surga, melemahkan sirkulasi pernapasan dan menghambat kemajuan karir pria."
                ),
                tr8(
                    "卫生间门常闭，门槛下安放真品五帝古钱，内置纯铜金蟾或粗盐陶罐吸纳湿浊。",
                    "衛生間門常閉，門檻下安放真品五帝古錢，內置純銅金蟾或粗鹽陶罐吸納濕濁。",
                    "Keep the bathroom door closed; place Five Emperor coins under the threshold and a brass toad or salt vessel inside to absorb damp qi.",
                    "浴室のドアを常に閉め、敷居に五帝銭を配置し、室内に粗塩や銅製の置物を置いて湿気を浄化します。",
                    "욕실 문을 항상 닫아두고, 문턱 아래에 오제전을 배치하며 굵은 소금 단지를 두어 습기를 정화하세요.",
                    "Thường xuyên đóng cửa phòng vệ sinh, đặt tiền Ngũ Đế dưới ngạch cửa, đặt hũ muối thô hoặc cóc đồng để hút ẩm.",
                    "ปิดประตูห้องน้ำเสมอ วางเหรียญห้าจักรพรรดิใต้ธรณีประตู และตั้งโถเกลือเม็ดหรือคางคกทองเหลืองเพื่อดูดซับความชื้น",
                    "Tutup pintu kamar mandi; letakkan Koin Lima Kaisar di bawah ambang pintu dan wadah garam kasar di dalam untuk menyerap kelembapan."
                )
            )
        case (.kitchen, "坎"), (.kitchen, "Kan"), (.kitchen, "감"), (.kitchen, "Khảm"), (.kitchen, "ข่าน"):
            return (
                tr8("水火相战未济煞", "水火相戰未濟煞", "Water–Fire Clash", "水火相剋殺", "수화상전 미제살", "Thủy Hỏa Tương Chiến Vị Tế Sát", "เคราะห์น้ำไฟปะทะ", "Sha Benturan Air dan Api"),
                "预警",
                tr8(
                    "北方坎水见烈火，水火不相容，主心肾不交、情绪烦躁与血液循环受损。出处：《易经》“水火不相容”。解释：此为古籍传统象征，请现场核对热源距离、通风、用电与消防安全。",
                    "北方坎水見烈火，水火不相容，主心腎不交、情緒煩躁與血液循環受損。出處：《易經》「水火不相容」。解釋：此為古籍傳統象徵，請現場核對熱源距離、通風、用電與消防安全。",
                    "The I Ching uses “Water and Fire do not coexist” for Kan Water meeting strong Fire; traditional interpretation mentions heart-kidney balance, mood and circulation. This is a historical text reference; verify heat clearance, ventilation, power and fire safety on site.",
                    "北方の坎水とコンロの烈火が対立し、心身のバランスの乱れや情緒不安定を招きます。",
                    "북방 감수와 주방의 화기가 상충하여 심신 불균형, 정서 불안 및 혈액순환 장애를 부를 수 있습니다.",
                    "Khảm Thủy phương Bắc gặp Hỏa của bếp dẫn đến thủy hỏa tương khắc, tâm thần bất an, ảnh hưởng tuần hoàn máu.",
                    "น้ำทิศเหนือปะทะไฟจากเตา น้ำและไฟเข้ากันไม่ได้ ส่งผลต่ออารมณ์ฉุนเฉียวและระบบไหลเวียนโลหิต",
                    "Air Kan di utara berbenturan dengan Api kompor, mengganggu ketenangan emosi dan sirkulasi peredaran darah."
                ),
                tr8(
                    "以木通关，厨房内增添绿植或实木厨具，令水生木、木生火，化克为生。",
                    "以木通關，廚房內增添綠植或實木廚具，令水生木、木生火，化克為生。",
                    "Use Wood as a bridge: add plants or wooden utensils so Water feeds Wood and Wood feeds Fire.",
                    "木気を取り入れ、観葉植物や木製調理器具を配置して水生木・木生火の調和を図ります。",
                    "목 기운으로 중재하세요. 주방에 녹색 식물이나 원목 조리도구를 두어 수생목, 목생화로 화합하게 하세요.",
                    "Dùng Mộc thông quan: thêm cây xanh nhỏ hoặc dụng cụ bằng gỗ để Thủy sinh Mộc, Mộc sinh Hỏa hóa giải xung khắc.",
                    "ใช้ธาตุไม้เป็นสะพานเชื่อม เพิ่มต้นไม้กระถางเล็กหรือเครื่องครัวไม้ เพื่อให้ธาตุน้ำหล่อเลี้ยงไม้และไม้หนุนไฟ",
                    "Gunakan Elemen Kayu sebagai jembatan: tambahkan tanaman hijau atau perkakas kayu agar Air menghidupkan Kayu dan Kayu menghidupkan Api."
                )
            )
        case (.kitchen, "艮"), (.kitchen, "坤"), (.kitchen, "Gen"), (.kitchen, "Kun"),
             (.kitchen, "간"), (.kitchen, "곤"), (.kitchen, "Cấn"), (.kitchen, "Khôn"),
             (.kitchen, "เกิ่น"), (.kitchen, "คุน"):
            return (
                tr8("火燥鬼门伤脾土", "火燥鬼門傷脾土", "Dry Fire in the Ghost Gate", "火燥鬼門殺", "화조귀문살", "Hỏa Táo Quỷ Môn Thương Tỳ Thổ", "เคราะห์ไฟแผดเผาประตูปิศาจ", "Sha Api Membakar Gerbang Roh"),
                "预警",
                tr8(
                    "艮坤属土为鬼门，烈火燥土，易致家人口腔上火、脾胃虚热及皮肤过敏。出处：《阳宅十书》相关火土论。解释：艮坤是传统方位称谓，以上为古籍象征，请核对通风、热源距离和消防安全。",
                    "艮坤屬土為鬼門，烈火燥土，易致家人口腔上火、脾胃虛熱及皮膚過敏。出處：《陽宅十書》相關火土論。解釋：艮坤是傳統方位稱謂，以上為古籍象徵，請核對通風、熱源距離和消防安全。",
                    "The Yang Zhai Ten Books says, “Dry Fire scorches Earth and may bring oral heat, digestive heat and skin sensitivity.” Gen and Kun are traditional direction names; this is a historical text reference. Verify ventilation, heat clearance and fire safety.",
                    "艮・坤は土に属し鬼門とされます。火気が土を焼き、胃腸の不調や肌トラブルを招きやすくなります。",
                    "《양택십서》는 ‘열화가 토를 건조하게 하여 구강·비위·피부에 영향을 준다’고 기록합니다. 간·곤은 전통 귀문 방위 명칭이며, 환기·열원 거리·화재 안전을 현장에서 확인하세요.",
                    "Cấn Khôn thuộc Thổ là Quỷ môn; hỏa nhiệt làm khô đất, dễ khiến tỳ vị suy yếu, nóng trong và dị ứng da.",
                    "เกิ่นและคุนเป็นธาตุดินและทิศประตูปิศาจ ไฟที่รุนแรงทำให้ดินแห้งผาก กระทบระบบย่อยอาหารและผิวหนัง",
                    "Gen dan Kun adalah Gerbang Tanah; api yang kering memicu gangguan pencernaan dan sensitivitas kulit."
                ),
                tr8(
                    "台面摆放白水晶球或黄色陶瓷葫芦化泄烈火，增厚中和地气。",
                    "台面擺放白水晶球或黃色陶瓷葫蘆化洩烈火，增厚中和地氣。",
                    "Place a white crystal sphere or yellow ceramic gourd on the counter to diffuse Fire and steady Earth qi.",
                    "調理台に白水晶球や黄色い陶器の瓢箪を置き、火気を和らげて地の気を安定させます。",
                    "조리대 위에 백수정구나 황색 세라믹 호리병을 두어 화기를 설기하고 지기를 안정시키세요.",
                    "Đặt quả cầu thạch anh trắng hoặc hồ lô gốm màu vàng trên kệ bếp để tiêu trừ hỏa khí, làm dày địa khí.",
                    "วางลูกแก้วควอตซ์ขาวหรือน้ำเต้าเซรามิกสีเหลืองบนเคาน์เตอร์เพื่อระบายพลังไฟและสร้างสมดุลให้พลังดิน",
                    "Letakkan bola kristal kuarsa putih atau labu keramik kuning di meja dapur untuk meredam api dan menenangkan tanah."
                )
            )
        case (.bathroom, "艮"), (.bathroom, "坤"), (.bathroom, "Gen"), (.bathroom, "Kun"),
             (.bathroom, "간"), (.bathroom, "곤"), (.bathroom, "Cấn"), (.bathroom, "Khôn"),
             (.bathroom, "เกิ่น"), (.bathroom, "คุน"):
            return (
                tr8("鬼门卫浴秽气冲射", "鬼門衛浴穢氣衝射", "Ghost Gate Bathroom Sha", "鬼門水濁殺", "귀문욕실 오기살", "Quỷ Môn Vệ Sinh Uế Khí Xung", "เคราะห์ห้องน้ำประตูปิศาจ", "Sha Kamar Mandi Gerbang Roh"),
                "预警",
                tr8(
                    "东北艮为表鬼门，西南坤为里鬼门，卫浴见水污地气，易损脾胃与人丁健康。出处：传统阳宅鬼门论（传本有异文）。解释：这是古籍对艮坤卫浴的象征性判断，请结合防水、通风与使用安全复核。",
                    "東北艮為表鬼門，西南坤為裏鬼門，衛浴見水污地氣，易損脾胃與人丁健康。出處：傳統陽宅鬼門論（傳本有異文）。解釋：這是古籍對艮坤衛浴的象徵性判斷，請結合防水、通風與使用安全複核。",
                    "Bathrooms in the northeast or southwest pollute Earth qi and may affect digestion and family wellbeing.",
                    "北東は表鬼門、南西は裏鬼門。水回りと空間配置についての伝統文化上の参考提示です。防水と換気を現場で確認してください。",
                    "동북과 서남은 전통 방위 명칭입니다. 욕실 배치에 대해 방수·환기·건조·사용 안전을 현장에서 확인하세요.",
                    "Đông Bắc Cấn là biểu Quỷ môn, Tây Nam Khôn là lý Quỷ môn; nhà vệ sinh ẩm ướt làm ô uế địa khí, theo truyền thống ảnh hưởng đến tỳ vị và sức khỏe gia đình. Hãy kiểm tra chống thấm, thông gió và độ khô ráo tại hiện trường.",
                    "ทิศตะวันออกเฉียงเหนือและตะวันตกเฉียงใต้เป็นประตูปิศาจ ห้องน้ำที่ชื้นแฉะทำลายพลังดิน กระทบระบบย่อยอาหาร",
                    "Kamar mandi di timur laut atau barat daya adalah referensi tata ruang budaya tradisional; periksa kedap air, ventilasi, kekeringan, dan keselamatan penggunaan di lokasi."
                ),
                tr8(
                    "卫浴常开排风保持干燥，门槛下安放真品五帝钱或粗盐陶罐净化。",
                    "衛浴常開排風保持乾燥，門檻下安放真品五帝錢或粗鹽陶罐淨化。",
                    "Keep ventilation running and the room dry; place Five Emperor coins or a salt vessel under the threshold.",
                    "換気扇を常時回して乾燥を保ち、敷居に五帝銭や粗塩の壺を配置して浄化します。",
                    "환기팬을 가동해 건조함을 유지하고, 문턱 아래에 오제전이나 굵은 소금 단지를 두어 정화하세요.",
                    "Thường xuyên bật quạt thông gió giữ khô ráo; đặt tiền Ngũ Đế hoặc hũ muối thô dưới ngạch cửa để thanh lọc.",
                    "เปิดพัดลมระบายอากาศเพื่อรักษาความแห้ง แขวนเหรียญห้าจักรพรรดิหรือวางโถเกลือเพื่อขจัดพลังลบ",
                    "Jaga ventilasi tetap menyala dan ruangan tetap kering; pasang Koin Lima Kaisar atau wadah garam di bawah ambang pintu."
                )
            )
        case (.bathroom, "中"), (.bathroom, "Center"), (.bathroom, "중"), (.bathroom, "Trung"), (.bathroom, "กลาง"), (.bathroom, "Tengah"):
            return (
                tr8("水浸中宫大忌", "水浸中宮大忌", "Central Palace Water Sha", "水浸中宮大忌", "수침중궁대기", "Thủy Tẩm Trung Cung Đại Kỵ", "เคราะห์น้ำท่วมจุดศูนย์กลาง", "Sha Air Merendam Pusat Rumah"),
                "严重煞气",
                tr8(
                    "房屋心脏太极受污，病气弥漫全屋，主宅运反复、家人腰腹疾厄。出处：《阳宅十书》“太极受污，病气弥漫全屋”。解释：此为古籍病气象征，请结合防水、通风、干燥、排水和动线现场复核。",
                    "房屋心臟太極受污，病氣瀰漫全屋，主宅運反覆、家人腰腹疾厄。出處：《陽宅十書》「太極受污，病氣瀰漫全屋」。解釋：此為古籍病氣象徵，請結合防水、通風、乾燥、排水和動線現場複核。",
                    "Water pollutes the home's central Tai Ji, spreading stagnant qi and affecting fortune and abdominal wellbeing.",
                    "家の中心部の水回り配置についての伝統文化上の参考提示です。防水と換気を現場で確認してください。",
                    "《양택십서》는 ‘태극이 오염되면 병기가 집 전체에 퍼진다’고 기록합니다. 집 중앙 욕실은 고전의 병기 상징으로 설명되며 방수·환기·건조·배수·동선을 현장에서 확인하세요.",
                    "Trung cung là trái tim của ngôi nhà; nhà vệ sinh ở giữa nhà làm tán khí, gia vận bất ổn, dễ đau lưng bụng.",
                    "คัมภีร์โบราณกล่าวว่า “ไท่จี๋เปื้อนมลทิน พลังโรคกระจายทั่วบ้าน” ตำแหน่งห้องน้ำกลางบ้านเป็นสัญลักษณ์ตามคัมภีร์ โปรดตรวจสอบการกันน้ำ การระบายอากาศ ความแห้ง การระบายน้ำ และทางเดินหน้างาน",
                    "Kitab klasik menyebut, “Saat Tai Ji rumah tercemar, qi penyakit menyebar ke seluruh rumah.” Kamar mandi di tengah adalah simbol dalam teks tradisional; periksa kedap air, ventilasi, kekeringan, drainase, dan sirkulasi di lokasi."
                ),
                tr8(
                    "门头安放纯铜八卦凸镜，卫浴内常亮暖黄长明灯排浊。",
                    "門頭安放純銅八卦凸鏡，衛浴內常亮暖黃長明燈排濁。",
                    "Mount a brass convex Bagua mirror above the door and keep a warm light on to clear damp qi.",
                    "ドアの上に八卦凸面鏡を設置し、浴室内に暖色系の常夜灯を灯して濁気を排します。",
                    "문 위에 황동 볼록 팔괘경을 걸고 욕실 내에 따뜻한 조명을 켜두어 탁기를 몰아내세요.",
                    "Treo gương Bát Quái lồi bằng đồng trên cửa, thắp đèn vàng ấm thường xuyên để hóa giải xú khí.",
                    "ติดกระจกนูนแปดทิศทองเหลืองเหนือประตู และเปิดไฟโทนสีเหลืองอุ่นไว้ตลอดเพื่อสลายพลังหมองหม่น",
                    "Pasang cermin cembung Bagua di atas pintu dan nyalakan lampu kuning hangat untuk mengusir qi lembap."
                )
            )
        case (.study, "巽"), (.study, "坎"), (.study, "Xun"), (.study, "Kan"),
             (.study, "손"), (.study, "감"), (.study, "Tốn"), (.study, "Khảm"),
             (.study, "ซวิ่น"), (.study, "ข่าน"):
            return (
                tr8("文昌生旺大吉位", "文昌生旺大吉位", "Wenchang Scholarly Auspicious Position", "文昌吉位", "문창생왕 대길위", "Văn Xương Sinh Vượng Đại Cát Vị", "ทิศมงคลส่งเสริมการเรียนรู้", "Posisi Wenchang Sangat Menguntungkan"),
                "吉",
                tr8(
                    "巽为四绿文曲木，坎水生文昌，大利考学、升职与名誉构思。",
                    "巽為四綠文曲木，坎水生文昌，大利考學、升職與名譽構思。",
                    "Xun's Wenchang Wood and Kan Water nourish study, promotion and creative reputation.",
                    "巽の木気と坎の水気が文昌を養い、学業成就や昇進、創作活動に大きな力を授けます。",
                    "손위의 사록 문곡목과 감수의 조화로 문창을 생조하여 시험 합격, 승진 및 명예에 크게 길합니다.",
                    "Tốn là Tứ Lục Văn Khúc Mộc, Khảm Thủy sinh Văn Xương, rất có lợi cho học vấn thi cử, thăng chức và danh tiếng.",
                    "ธาตุไม้ทิศซวิ่นและธาตุน้ำทิศข่านส่งเสริมดาวเหวินชางอย่างยิ่ง หนุนนำการสอบ การเลื่อนตำแหน่ง และความคิดสร้างสรรค์",
                    "Kayu Xun dan Air Kan memelihara Wenchang, sangat mendukung keberhasilan ujian, promosi kerja, dan reputasi kreatif."
                ),
                tr8(
                    "书桌宜设于此方，书架摆放四支水养富贵竹或天然白水晶文昌塔。",
                    "書桌宜設於此方，書架擺放四支水養富貴竹或天然白水晶文昌塔。",
                    "Place the desk here; add four water-grown lucky bamboos or a natural white-crystal Wenchang tower.",
                    "机をこの方位に配置し、本棚に水耕栽培の竹や水晶の置物を飾るのが理想的です。",
                    "책상을 이 방위에 배치하고 서가에 수경재배 개운죽 네 줄기나 천연 백수정 문창탑을 두세요.",
                    "Nên đặt bàn học ở đây; trên giá sách cắm bốn cành trúc phát tài thủy sinh hoặc tháp Văn Xương thạch anh trắng.",
                    "ควรตั้งโต๊ะทำงานในทิศนี้ วางต้นไผ่กวนอิมสี่กิ่งหรือเจดีย์บุ๋นเชียงคริสตัลเพื่อส่งเสริมสติปัญญา",
                    "Letakkan meja kerja di sini; letakkan empat batang bambu hoki air atau pagoda kristal kuarsa putih di rak buku."
                )
            )
        case (.masterBedroom, "坤"), (.masterBedroom, "延年"), (.masterBedroom, "Kun"), (.masterBedroom, "Yan Nian"),
             (.masterBedroom, "곤"), (.masterBedroom, "Khôn"), (.masterBedroom, "คุน"):
            return (
                tr8("主卧得位气场稳固", "主臥得位氣場穩固", "Master Bedroom in a Stable Position", "主寝室得位吉", "주침실 득위 기장안정", "Phòng Ngủ Chính Đắc Vị Khí Trường Vững Chắc", "ห้องนอนใหญ่ตำแหน่งมงคลมั่นคง", "Kamar Tidur Utama di Posisi Sangat Stabil"),
                "吉",
                tr8(
                    "居于生旺方，身心放松，夫妻和睦，睡眠充盈利于事业蓄力。",
                    "居於生旺方，身心放鬆，夫妻和睦，睡眠充盈利於事業蓄力。",
                    "A prosperous position supports rest, harmony, sleep and renewed career energy.",
                    "吉方に位置し、心身がくつろぎ、夫婦円満と良好な睡眠でエネルギーを蓄えられます。",
                    "길방에 위치하여 심신이 편안해지고 부부 화합과 숙면을 도와 일상의 활력을 충전합니다.",
                    "An ngự ở phương sinh vượng giúp thân tâm thư thái, vợ chồng hòa thuận, giấc ngủ sâu tích lũy năng lượng cho sự nghiệp.",
                    "ตั้งอยู่ในทิศมงคล ช่วยให้ผ่อนคลาย สามีภรรยาปรองดอง หลับสบายฟื้นฟูพลังงาน",
                    "Posisi yang makmur mendukung istirahat yang dalam, keharmonisan pasangan, dan mengumpulkan tenaga untuk kesuksesan karir."
                ),
                tr8(
                    "床头宜靠实墙，忌上方横梁压顶或正冲镜面。",
                    "床頭宜靠實牆，忌上方橫梁壓頂或正衝鏡面。",
                    "Keep the headboard against a solid wall; avoid overhead beams and mirrors facing the bed.",
                    "ベッドヘッドはしっかりした壁に付け、頭上の梁や鏡の映り込みを避けてください。",
                    "침대 머리는 견고한 벽에 기대고, 머리 위 대들보나 거울이 침대를 마주 보지 않도록 하세요.",
                    "Đầu giường nên tựa vào tường vững chắc, tránh xà ngang đè đầu hoặc gương chiếu thẳng vào giường.",
                    "หัวเตียงควรชิดผนังทึบ หลีกเลี่ยงคานทับศีรษะหรือกระจกเงาส่องตรงที่นอน",
                    "Sandarkan kepala tempat tidur ke dinding kokoh; hindari balok gantung di atas kepala dan cermin yang langsung menghadap ranjang."
                )
            )
        case (.door, "离"), (.door, "Li"), (.door, "이"), (.door, "Ly"), (.door, "หลี"):
            return (
                tr8("南向明堂纳阳吉向", "南向明堂納陽吉向", "South-Facing Bright Hall", "南向明堂納気吉", "남향 명당 납양길향", "Nam Hướng Minh Đường Nạp Dương Cát Hướng", "ลานหน้าบ้านหันทิศใต้รับแสงมงคล", "Lobi Menghadap Selatan Sangat Berkah"),
                "吉",
                tr8(
                    "离火纳气，采光充沛，主热情光明与远见名望。",
                    "離火納氣，採光充沛，主熱情光明與遠見名望。",
                    "Li Fire gathers bright qi and daylight, supporting warmth, vision and reputation.",
                    "南方の離火の気を取り込み、陽光に恵まれ、前向きな活力と名声を育みます。",
                    "이화의 기운을 받아 채광이 풍부하며, 온화함과 진취적인 명성을 복돋웁니다.",
                    "Ly Hỏa nạp khí, ánh sáng dồi dào, chủ nhiệt huyết quang minh và uy tín danh vọng vươn xa.",
                    "เปิดรับพลังชี่แห่งทิศใต้ แสงแดดส่องสว่าง เสริมสร้างบารมี ความอบอุ่น และชื่อเสียงเกียรติยศ",
                    "Api Li menyerap energi terang dan limpahan sinar matahari, membina kehangatan, visi masa depan, dan reputasi."
                ),
                tr8(
                    "玄关保持整洁开阔，点亮暖金射灯迎祥纳福。",
                    "玄關保持整潔開闊，點亮暖金射燈迎祥納福。",
                    "Keep the entry clean and open, with warm lighting to welcome auspicious qi.",
                    "玄関を常に広く清潔に保ち、暖色系の照明で吉気を迎え入れましょう。",
                    "현관을 청결하고 넓게 유지하며, 따뜻한 금빛 조명으로 상서로운 기운을 맞이하세요.",
                    "Huyền quan cần giữ sạch sẽ thông thoáng, thắp đèn ánh vàng ấm áp để nghênh đón cát tường.",
                    "รักษาบริเวณโถงทางเข้าให้สะอาดกว้างขวาง เปิดไฟโทนสีทองอบอุ่นเพื่อต้อนรับสิริมงคล",
                    "Jaga area masuk tetap bersih dan lapang, nyalakan lampu keemasan hangat untuk menyambut qi keberkahan."
                )
            )
        default:
            return (
                tr8("方位得所气场安和", "方位得所氣場安和", "Balanced Spatial Qi", "方位調和安穏", "방위 득소 기장안화", "Phương Vị Đắc Sở Khí Trường An Hòa", "ทิศทางเหมาะสมชี่ราบรื่น", "Posisi Selaras dan Energi Tenang"),
                "平",
                tr8(
                    "空间阴阳协调，无明显形理相克。",
                    "空間陰陽協調，無明顯形理相克。",
                    "Yin and yang are balanced with no obvious form or element conflict.",
                    "陰陽の調和が取れており、目立った五行の衝突は見られません。",
                    "음양이 조화롭고 뚜렷한 상극 충돌이 없습니다.",
                    "Không gian âm dương điều hòa, không có hình thế hay ngũ hành tương khắc rõ rệt.",
                    "หยินและหยางสมดุลกันดี ไม่มีจุดขัดแย้งของธาตุอย่างเห็นได้ชัด",
                    "Yin dan yang seimbang tanpa ada benturan elemen yang mengganggu."
                ),
                tr8(
                    "按日常居住动线与洁净要求维护即可。",
                    "按日常居住動線與潔淨要求維護即可。",
                    "Maintain normal circulation, cleanliness and ventilation.",
                    "通常の清掃や風通しを心掛けることで良好な状態を維持できます。",
                    "일상적인 청결과 통풍을 유지하며 편안하게 생활하시면 됩니다.",
                    "Chỉ cần duy trì nếp sinh hoạt sạch sẽ, thông thoáng thường ngày.",
                    "ดูแลรักษาความสะอาดและการระบายอากาศตามการใช้งานประจำวัน",
                    "Cukup jaga kebersihan, sirkulasi yang teratur, dan ventilasi harian yang baik."
                )
            )
        }
    }
}
