import Foundation

// MARK: - 房屋事实与综合方位分析

public enum XuanKongSiteFactKind: String, CaseIterable, Codable, Hashable {
    case openBright, solidBacking, movingWater, noise, glare, blockedAccess

    var titleKey: String {
        switch self {
        case .openBright: return "xkd_fact_open"
        case .solidBacking: return "xkd_fact_backing"
        case .movingWater: return "xkd_fact_water"
        case .noise: return "xkd_fact_noise"
        case .glare: return "xkd_fact_glare"
        case .blockedAccess: return "xkd_fact_blocked"
        }
    }
}

public struct XuanKongSiteFact: Codable, Equatable, Identifiable {
    public let palaceID: Int
    public let kind: XuanKongSiteFactKind
    public var id: String { "\(palaceID)-\(kind.rawValue)" }
    public init(palaceID: Int, kind: XuanKongSiteFactKind) {
        self.palaceID = palaceID
        self.kind = kind
    }
}

enum XuanKongPlaceKind: Equatable {
    case room, entrance, window, bed, stove, interiorDoor
}

struct XuanKongLocatedPlace: Identifiable {
    let id: String
    let palaceID: Int
    let name: String
    let kind: XuanKongPlaceKind
    let roomType: FloorplanRoomType?
    /// Fraction of this room's sampled footprint, never a claim about a bed/stove position.
    var coverage: Int = 100
}

struct XuanKongHomeContext {
    var places: [XuanKongLocatedPlace] = []
    var exterior: [ExteriorShaRecord] = []
    var facts: [XuanKongSiteFact] = []
    var missingKeys: [String] = []
    var warningKeys: [String] = []
}

/// All 81 ordered star pairs have a deterministic elemental relationship.
/// Motifs supplement the relation; they do not turn an observed room into a prediction.
struct XuanKongStarPair {
    enum Relation: CaseIterable, Equatable {
        case same, firstGeneratesSecond, secondGeneratesFirst, firstControlsSecond, secondControlsFirst
        var titleKey: String {
            switch self {
            case .same: return "xkd_pair_same"
            case .firstGeneratesSecond: return "xkd_pair_generate_forward"
            case .secondGeneratesFirst: return "xkd_pair_generate_back"
            case .firstControlsSecond: return "xkd_pair_control_forward"
            case .secondControlsFirst: return "xkd_pair_control_back"
            }
        }
    }
    let first: Int
    let second: Int
    // Generating cycle: Wood, Fire, Earth, Metal, Water.
    private static let elements = [1: 4, 2: 2, 3: 0, 4: 0, 5: 2, 6: 3, 7: 3, 8: 2, 9: 1]
    var relation: Relation {
        let a = Self.elements[first] ?? 2, b = Self.elements[second] ?? 2
        if a == b { return .same }
        if (a + 1) % 5 == b { return .firstGeneratesSecond }
        if (b + 1) % 5 == a { return .secondGeneratesFirst }
        if (a + 2) % 5 == b { return .firstControlsSecond }
        return .secondControlsFirst
    }
    var hasEarthCaution: Bool { [first, second].contains { $0 == 2 || $0 == 5 } }
    var isStudy: Bool { Set([first, second]) == Set([1, 4]) || Set([first, second]) == Set([1, 6]) }
    var isFriction: Bool { Set([first, second]) == Set([3, 7]) }
    var isHeat: Bool { Set([first, second]) == Set([7, 9]) || (first == 9 && second == 9) }
}

enum XuanKongPracticalAction: CaseIterable, Hashable {
    case clearAccess, reduceNoise, reduceGlare, protectSleep, kitchen, window, study, edges, heat
    case wetRoom, verifyCorner, exteriorTraffic, exteriorWind, exteriorPrivacy, exteriorStructure
    case waterReview, workReview, separateUses, rest, everyday, sanban, qixing

    var textKey: String {
        switch self {
        case .clearAccess: return "xkd_action_access"
        case .reduceNoise: return "xkd_action_noise"
        case .reduceGlare: return "xkd_action_glare"
        case .protectSleep: return "xkd_action_sleep"
        case .kitchen: return "xkd_action_kitchen"
        case .window: return "xkd_action_window"
        case .study: return "xkd_action_study"
        case .edges: return "xkd_action_edges"
        case .heat: return "xkd_action_heat"
        case .wetRoom: return "xkd_action_wet"
        case .verifyCorner: return "xkd_action_corner"
        case .exteriorTraffic: return "xkd_action_traffic"
        case .exteriorWind: return "xkd_action_wind"
        case .exteriorPrivacy: return "xkd_action_privacy"
        case .exteriorStructure: return "xkd_action_structure"
        case .waterReview: return "xkd_action_water"
        case .workReview: return "xkd_action_work"
        case .separateUses: return "xkd_action_separate"
        case .rest: return "xkd_action_rest"
        case .everyday: return "xkd_action_everyday"
        case .sanban: return "xkd_action_sanban"
        case .qixing: return "xkd_action_qixing"
        }
    }
}

struct XuanKongSectorAnalysis: Identifiable {
    var id: Int { palaceID }
    let palaceID: Int
    let use: XuanKongSectorUse
    let yearStar: Int
    let monthStar: Int
    let places: [XuanKongLocatedPlace]
    let exterior: [ExteriorShaRecord]
    let facts: [XuanKongSiteFactKind]
    let pairs: [XuanKongStarPair]
    let reasonKeys: [String]
    let actions: [XuanKongPracticalAction]
    /// Lower first: observed disturbance, occupied caution, unoccupied caution, other sectors.
    let priority: Int
}

struct XuanKongPatternCheck: Identifiable {
    let id: String
    let titleKey: String
    let statusKey: String
    let palaceIDs: [Int]
    let actionKey: String
}

struct XuanKongDeepAnalysis {
    let date: Date
    let sectors: [XuanKongSectorAnalysis]
    let patternChecks: [XuanKongPatternCheck]
    let missingKeys: [String]
    let warningKeys: [String]
    var summaryKey: String {
        switch priorities.first?.priority ?? 3 {
        case 0: return "xkd_summary_observed"
        case 1: return "xkd_summary_occupied"
        case 2: return "xkd_summary_quiet"
        default: return "xkd_summary_uses"
        }
    }
    var priorities: [XuanKongSectorAnalysis] {
        sectors.sorted {
            if $0.priority != $1.priority { return $0.priority < $1.priority }
            if $0.use.priority != $1.use.priority { return $0.use.priority < $1.use.priority }
            return $0.palaceID < $1.palaceID
        }
    }
}

enum XuanKongDeepAnalyzer {
    static func qiXingSectorGroups(chart: XuanKongChart) -> [[Int]] {
        guard chart.isQiXingDaJie else { return [] }
        let sets: [Set<Int>] = [Set([1, 4, 7]), Set([2, 5, 8]), Set([3, 6, 9])]
        return [[8, 2, 5], [0, 6, 3]].filter { group in
            sets.contains(Set(group.compactMap { id in chart.palaces.first { $0.id == id }?.facingStar }))
        }
    }
    static func palaceID(bearing: Double) -> Int? {
        guard bearing.isFinite else { return nil }
        let normalized = (bearing.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return [0, 7, 2, 3, 8, 1, 6, 5][Int((normalized + 22.5).truncatingRemainder(dividingBy: 360) / 45)]
    }

    static func analyze(chart: XuanKongChart, date: Date, context: XuanKongHomeContext? = nil,
                        temporal: PurpleWhiteChart? = nil) -> XuanKongDeepAnalysis {
        // PalaceCell IDs are zero based in the same order as PurpleWhite's Luo Shu IDs 1...9.
        let time = temporal ?? PurpleWhiteEngine.shared.calculateChart(date: date)
        let home = context ?? XuanKongHomeContext(missingKeys: ["xkd_missing_home"])
        let qiXingGroups = qiXingSectorGroups(chart: chart)
        let linkedPalaces = Set(qiXingGroups.flatMap { $0 })
        let sectors = chart.palaces.map { cell -> XuanKongSectorAnalysis in
            let guest = time.palaceItems.first { $0.palaceId == cell.id + 1 }
            let year = guest?.yearGuestStar ?? 0, month = guest?.monthGuestStar ?? 0
            let natal = XuanKongStarPair(first: cell.mountainStar, second: cell.facingStar)
            let pairs = [natal,
                         XuanKongStarPair(first: cell.mountainStar, second: year),
                         XuanKongStarPair(first: cell.facingStar, second: year),
                         XuanKongStarPair(first: cell.mountainStar, second: month),
                         XuanKongStarPair(first: cell.facingStar, second: month),
                         XuanKongStarPair(first: year, second: month)]
            let seasonalCaution = [year, month].contains { $0 == 2 || $0 == 5 }
            let caution = natal.hasEarthCaution || seasonalCaution
            var use: XuanKongSectorUse = caution ? .quiet : cell.suggestedUse
            let places = home.places.filter { $0.palaceID == cell.id }
            let outside = home.exterior.filter { palaceID(bearing: $0.bearingDegrees) == cell.id }
            let facts = home.facts.filter { $0.palaceID == cell.id }.map(\.kind)
            var reasons: [String] = []
            var actions: [XuanKongPracticalAction] = []
            func add(_ action: XuanKongPracticalAction) { if !actions.contains(action) { actions.append(action) } }
            let hasBed = places.contains { $0.kind == .bed || $0.roomType == .masterBedroom || $0.roomType == .secondBedroom }
            let hasKitchen = places.contains { $0.kind == .stove || $0.roomType == .kitchen }
            let hasEntrance = places.contains { $0.kind == .entrance || $0.roomType == .door }
            let hasWindow = places.contains { $0.kind == .window }
            let isWetRoom = places.contains { $0.roomType == .bathroom }
            let missingOnly = !places.isEmpty && places.allSatisfy { $0.roomType == .missingCorner }
            let canStudy = !hasBed && !hasKitchen && !isWetRoom
                && places.contains { $0.roomType == .study || $0.roomType == .livingRoom }
            let bedActivityConflict = hasBed && (use == .activity || use == .separateUses)
            if facts.contains(.noise) { use = .quiet }
            else if bedActivityConflict && !caution { use = hasEntrance ? .separateUses : .rest }
            if facts.contains(.blockedAccess) { reasons.append("xkd_reason_blocked"); add(.clearAccess) }
            if facts.contains(.noise) { reasons.append("xkd_reason_noise"); add(.reduceNoise) }
            if facts.contains(.glare) { reasons.append("xkd_reason_glare"); add(.reduceGlare) }
            for record in outside {
                switch record.shaID {
                case "luchong", "fangong", "gejiao": add(.exteriorTraffic)
                case "tianzhan": add(.exteriorWind)
                case "tantou": add(.exteriorPrivacy)
                case "huoxing": add(.heat)
                default: add(.exteriorStructure)
                }
            }
            if !outside.isEmpty { reasons.append("xkd_reason_exterior") }
            if natal.hasEarthCaution { reasons.append("xkd_reason_natal") }
            if seasonalCaution { reasons.append("xkd_reason_season") }
            if caution && facts.contains(.movingWater) { reasons.append("xkd_reason_water"); add(.waterReview) }
            if hasBed {
                reasons.append(bedActivityConflict ? "xkd_reason_bed_active" : "xkd_reason_bed")
                add(.protectSleep)
            }
            if hasKitchen { reasons.append("xkd_reason_kitchen"); add(.kitchen) }
            if hasEntrance { reasons.append("xkd_reason_entrance"); add(.clearAccess); if caution { add(.reduceNoise) } }
            if hasWindow { add(.window) }
            // Elemental control changes the use plan, rather than prescribing purchases or demolition.
            if natal.relation == .firstControlsSecond || natal.relation == .secondControlsFirst {
                reasons.append("xkd_reason_control")
                if !caution && !hasBed && !hasKitchen && !isWetRoom && !missingOnly { add(.separateUses) }
            } else if !caution && canStudy {
                add(.study)
            }
            if places.contains(where: { $0.roomType == .bathroom }) { add(.wetRoom) }
            if places.contains(where: { $0.roomType == .missingCorner }) { add(.verifyCorner) }
            if pairs.contains(where: \.isHeat) { reasons.append("xkd_reason_heat"); if !missingOnly { add(.heat) } }
            if pairs.contains(where: \.isFriction) { reasons.append("xkd_reason_friction"); if !missingOnly { add(.edges) } }
            if pairs.contains(where: \.isStudy) { reasons.append("xkd_reason_study"); if !caution && canStudy { add(.study) } }
            if guest?.isTaiSui == true || guest?.isSuiPo == true || guest?.isSanSha == true {
                reasons.append("xkd_reason_works"); add(.workReview)
            }
            if linkedPalaces.contains(cell.id) { add(.qixing) }
            if chart.isSanBanGua { add(.sanban) }
            if !missingOnly {
                switch use {
                case .quiet: add(.reduceNoise)
                case .separateUses: if !hasKitchen && !isWetRoom { add(.separateUses) }
                case .activity: if !hasBed && !hasKitchen && !isWetRoom { add(.clearAccess) }
                case .rest: if !hasKitchen && !isWetRoom && !hasBed { add(.rest) }
                case .everyday: break
                }
            }
            if actions.isEmpty { add(.everyday) }
            let outsidePriority = outside.map { record -> Int in
                guard let item = ExteriorShaEngine.shared.database.first(where: { $0.id == record.shaID }) else { return 2 }
                switch ExteriorShaSeverityResolver.effectiveSeverity(staticSeverity: item.severity, distanceMeters: record.distanceMeters) {
                case .critical: return 0
                case .warning: return 1
                case .minor: return 2
                case .notice: return 3
                }
            }.min() ?? 3
            let observed = facts.contains(.noise) || facts.contains(.glare) || facts.contains(.blockedAccess)
                || (caution && facts.contains(.movingWater))
            let occupied = hasBed || hasKitchen || hasEntrance
            let roomPriority = observed ? 0 : (caution && occupied ? 1 : (caution ? 2 : (pairs.contains(where: \.isHeat) && hasKitchen ? 1 : 3)))
            let priority = min(outsidePriority, roomPriority)
            return XuanKongSectorAnalysis(palaceID: cell.id, use: use, yearStar: year, monthStar: month,
                places: places, exterior: outside, facts: facts, pairs: pairs, reasonKeys: reasons,
                actions: actions, priority: priority)
        }
        var checks: [XuanKongPatternCheck] = []
        func check(_ id: String, title: String, ids: [Int], action: String) {
            let relevant = sectors.filter { ids.contains($0.id) }
            let conflict = relevant.contains { $0.priority < 2 || ($0.use == .quiet && $0.facts.contains(.movingWater)) }
            let observedConditions = relevant.contains { $0.facts.contains(.openBright) || $0.facts.contains(.solidBacking) }
            let status = conflict ? "xkd_pattern_conflict" : (observedConditions ? "xkd_pattern_partial" : "xkd_pattern_unknown")
            checks.append(XuanKongPatternCheck(id: id, titleKey: title, statusKey: status, palaceIDs: ids, actionKey: action))
        }
        if chart.isSanBanGua {
            check("sanban", title: "xkd_sanban", ids: Array(0...8), action: "xkd_action_sanban")
        }
        if chart.isQiXingDaJie {
            for (index, ids) in qiXingGroups.enumerated() {
                check("qixing-\(index)", title: "xkd_qixing", ids: ids, action: "xkd_action_qixing")
            }
        }
        return XuanKongDeepAnalysis(date: date, sectors: sectors, patternChecks: checks,
                                   missingKeys: home.missingKeys, warningKeys: home.warningKeys)
    }
}

struct FlyingStarModeSelection {
    var manualOverride: Bool?

    func usesTiGua(automatic: Bool) -> Bool { manualOverride ?? automatic }
    mutating func toggle(automatic: Bool) { manualOverride = !usesTiGua(automatic: automatic) }
    mutating func restoreAutomatic() { manualOverride = nil }
}

// MARK: - 玄空九宫飞星排盘引擎 (XuanKong Flying Stars Engine)

/// Classical source notes shared by palace-level evaluations and chart summaries.
/// Keeping this at file scope prevents localized evaluations from depending on
/// the `XuanKongChart` instance that owns the chart-level advice.
private func flyingStarsTraditionalSourceNote(for language: AppLanguage) -> String {
    switch language {
    case .en:
        return "Classical sources: the Purple-White Formula says, ‘When Five Yellow overlaps, illness and calamity arrive; when Two and Five combine, illness is encountered.’ The traditional Xuan-Kong mountain/facing-star formula preserves the wording ‘Wang Shan Wang Xiang prospers people and wealth; Double Stars at Facing prospers wealth but not people; Double Stars at Sitting prospers people but not wealth; Shang Shan Xia Shui brings loss of wealth and people’ (transmitted versions differ). These wealth, people and health statements are traditional symbolic readings, not medical or financial predictions."
    case .zhHant:
        return "古籍出處：《紫白訣》云：「五黃重疊，災疾並臨；二五交加，罹疾病。」玄空山向星訣（傳本有異文）保留「到山到向，旺丁旺財；雙星到向，旺財不旺丁；雙星到坐，旺丁不旺財；上山下水，敗財損丁」等原文。上文財丁、健康語句屬傳統文化象徵解讀，不是醫療診斷或財務預測。"
    case .ja:
        return "出典：『紫白訣』「五黄が重なれば災疾が臨み、二五が交われば病にかかる」。玄空山向星訣（伝本に異文）は「到山到向は財と人が栄え、双星到向は財、双星到坐は人、上山下水は財と人を損なう」と伝えます。財・人・健康の表現は伝統文化上の象徴であり、医学的・金融的予測ではありません。"
    case .ko:
        return "출처: 《자백결》 ‘오황이 겹치면 재질이 임하고 이오가 교차하면 병이 따른다’. 전통 현공 산향성결은 ‘도산도향 왕정왕재, 쌍성도향 왕재불왕정, 쌍성도좌 왕정불왕재, 동산하수 손재손정’으로 전합니다(전본 이문). 재물·사람·건강 표현은 전통문화의 상징이며 의학적·재무 예측이 아닙니다."
    case .vi:
        return "Nguồn cổ: 《Tử Bạch Quyết》 ghi ‘Ngũ Hoàng chồng lên thì tai bệnh đến; Nhị Ngũ giao nhau thì gặp bệnh’. Quyết tinh sơn hướng Huyền Không truyền câu ‘đáo sơn đáo hướng vượng đinh vượng tài; song tinh đáo hướng vượng tài bất vượng đinh; song tinh đáo tọa vượng đinh bất vượng tài; thượng sơn hạ thủy bại tài tổn đinh’ (bản truyền có dị văn). Đây là biểu tượng truyền thống, không phải dự đoán y khoa hay tài chính."
    case .th:
        return "ที่มาโบราณ: 《จื่อไป๋เจวี๋ย》กล่าวว่า ‘ดาวห้าเหลืองซ้อน ภัยและโรคมาเยือน; สองกับห้าประจัน พบโรคภัย’ ตำราดาวภูเขา-ทิศเสวียนคงสืบคำว่า ‘ถึงเขาถึงทิศรุ่งเรืองคนและทรัพย์; ดาวคู่สู่หน้ารุ่งเรืองทรัพย์แต่ไม่คน; ดาวคู่สู่หลังรุ่งเรืองคนแต่ไม่ทรัพย์; ขึ้นเขาลงน้ำเสียทรัพย์เสียคน’ (ตำราต่างกัน) ถ้อยคำเรื่องทรัพย์ คน และสุขภาพเป็นสัญลักษณ์ดั้งเดิม ไม่ใช่การพยากรณ์ทางการแพทย์หรือการเงิน"
    case .id:
        return "Sumber klasik: 《Zi Bai Jue》 menyebut, ‘Saat Lima Kuning bertumpuk, penyakit dan bencana datang; saat Dua dan Lima berpapasan, penyakit ditemui.’ Rumus bintang gunung/hadap Xuan-Kong mempertahankan ungkapan ‘makmurkan orang dan harta; bintang ganda di hadap memakmurkan harta, bintang ganda di duduk memakmurkan orang, Shang Shan Xia Shui merusak harta dan orang’ (versi tradisi berbeda). Ungkapan rezeki, keluarga, dan kesehatan adalah simbol tradisional, bukan prediksi medis atau keuangan."
    case .auto, .zhHans:
        return "古籍出处：《紫白诀》云：“五黄重叠，灾疾并临；二五交加，罹疾病。”玄空山向星诀（传本有异文）保留“到山到向，旺丁旺财；双星到向，旺财不旺丁；双星到坐，旺丁不旺财；上山下水，败财损丁”等原文。上文财丁、健康语句属于传统文化象征解读，不是医疗诊断或财务预测。"
    }
}

public struct PalaceCell: Identifiable {
    public let id: Int // 0..8 (九宫对应: 0:坎, 1:坤, 2:震, 3:巽, 4:中, 5:乾, 6:兑, 7:艮, 8:离)
    public let palaceName: String
    public let trigram: String
    public let direction: String
    public let periodStar: Int    // 当运星
    public let activePeriod: Int  // 当前排盘所选元运，用于动态判断当令星
    public let mountainStar: Int  // 山星 (坐星)
    public let facingStar: Int    // 向星 (向星)
    public let isCenter: Bool     // 是否中宫
    public let isWangMountain: Bool // 是否旺山
    public let isWangFacing: Bool   // 是否旺向
    public let isShaWuHuang: Bool   // 是否五黄大煞
    public let isShaErHei: Bool     // 是否二黑病符
    
    public var sittingStar: Int { mountainStar }
    public var plainDirectionName: String {
        Direction8(rawValue: direction)?.localizedName ?? LocalizationManager.shared.t("xk_guide_center")
    }

    /// One rule drives the diagram, selected-sector explanation and actions.
    /// A caution always takes priority over the ruling stars, including periods 2/5.
    public var suggestedUse: XuanKongSectorUse {
        if hasEarthSha { return .quiet }
        if mountainStar == activePeriod && facingStar == activePeriod { return .separateUses }
        if facingStar == activePeriod { return .activity }
        if mountainStar == activePeriod { return .rest }
        return .everyday
    }
    public var guaName: String { trigram }
    public var element: String {
        switch id {
        case 0: return "水"
        case 1, 4, 7: return "土"
        case 2, 3: return "木"
        case 5, 6: return "金"
        case 8: return "火"
        default: return "土"
        }
    }

    public var localizedElement: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch element {
            case "水": return "Water"
            case "木": return "Wood"
            case "火": return "Fire"
            case "土": return "Earth"
            case "金": return "Metal"
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
        case .id:
            switch element {
            case "水": return "Air"
            case "木": return "Kayu"
            case "火": return "Api"
            case "土": return "Tanah"
            case "金": return "Logam"
            default: return element
            }
        case .auto, .zhHans, .zhHant, .ja:
            return element
        }
    }

    // Shared by the chart-level advice below when selecting activation
    // palaces. File scope keeps the flag out of the public model API while
    // allowing the chart to apply the same safety rule consistently.
    fileprivate var hasEarthSha: Bool { isShaWuHuang || isShaErHei }

    private func localizedEarthShaEvaluation(_ lang: AppLanguage) -> String {
        switch lang {
        case .en: return "Five Yellow/Two Black earth sha · Keep quiet and use a Metal remedy"
        case .zhHant: return "五黃／二黑土煞 · 宜靜安金屬化解"
        case .ja: return "五黄・二黒土煞 · 静かにして金属で化解"
        case .ko: return "오황·이흑 토살 · 조용히 하고 금속으로 화해"
        case .vi: return "Thổ sát Ngũ Hoàng/Nhị Hắc · Giữ tĩnh và dùng kim loại hóa giải"
        case .th: return "เคราะห์ดินดาวห้าเหลือง/สองดำ · รักษาความสงบและใช้โลหะแก้"
        case .id: return "Sha tanah 5-Kuning/2-Hitam · Jaga ketenangan dan gunakan logam"
        case .auto, .zhHans: return "五黄／二黑土煞 · 宜静安金属化解"
        }
    }

    public var localizedEvaluation: String {
        localizedEvaluationSummary + "\n\n" + flyingStarsTraditionalSourceNote(
            for: LocalizationManager.shared.effectiveLanguage
        )
    }

    public var localizedEvaluationSummary: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if hasEarthSha { return localizedEarthShaEvaluation(lang) }
        switch lang {
        case .en:
            if mountainStar == activePeriod && facingStar == activePeriod { return "Double Current Stars · Wealth and people prosper" }
            if facingStar == activePeriod { return "Current Wealth Star at Facing · Open and receive qi" }
            if mountainStar == activePeriod { return "Current Mountain Star returns · People prosper" }
            if isShaWuHuang || isShaErHei { return "Five Yellow and Two Black clash · Calm and use Metal remedy" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "One–Six harmony · Clear Water and Wood nourish Wenchang" }
            return "Mixed fortune · Balanced position"
        case .zhHant:
            if mountainStar == activePeriod && facingStar == activePeriod { return "當運雙星會聚 · 財丁兩旺" }
            if facingStar == activePeriod { return "當旺財星照臨 · 宜開門納氣" }
            if mountainStar == activePeriod { return "當運丁星歸位 · 人丁興旺" }
            if isShaWuHuang || isShaErHei { return "五黃二黑交加 · 宜靜安銅化解" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "一六共宗 · 水清木秀催文昌" }
            return "吉凶相參 · 平和之位"
        case .ja:
            if mountainStar == activePeriod && facingStar == activePeriod { return "当運の双星会聚 · 財丁両旺" }
            if facingStar == activePeriod { return "当旺の財星照臨 · 開門納気に適す" }
            if mountainStar == activePeriod { return "当運の丁星帰位 · 子孫繁栄" }
            if isShaWuHuang || isShaErHei { return "五黄二黒交加 · 静寂と銅器で化解" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "一六共宗 · 文昌栄達を促す" }
            return "吉凶相半 · 平和の気場"
        case .ko:
            if mountainStar == activePeriod && facingStar == activePeriod { return "당운 쌍성 회취 · 재물과 자손 모두 번창" }
            if facingStar == activePeriod { return "당왕 재성 조림 · 문을 열어 기를 받음" }
            if mountainStar == activePeriod { return "당운 정성 귀위 · 자손 번창" }
            if isShaWuHuang || isShaErHei { return "오황 이흑 교가 · 고요히 동기로 화해" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "일육공종 · 문창 학업 성취" }
            return "길흉 상참 · 평화로운 방위"
        case .vi:
            if mountainStar == activePeriod && facingStar == activePeriod { return "Đương vận song tinh hội tụ · Tài đinh lưỡng vượng" }
            if facingStar == activePeriod { return "Đương vượng tài tinh chiếu lâm · Lợi mở cửa nạp khí" }
            if mountainStar == activePeriod { return "Đương vận đinh tinh quy vị · Nhân đinh hưng vượng" }
            if isShaWuHuang || isShaErHei { return "Ngũ Hoàng Nhị Hắc giao gia · Nên tĩnh an đồng hóa giải" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "Nhất Lục cộng tông · Văn Xương học nghiệp đại cát" }
            return "Cát hung tương tham · Vị trí bình hòa"
        case .th:
            if mountainStar == activePeriod && facingStar == activePeriod { return "สองดาวมงคลชุมนุม · ร่ำรวยและลูกหลานรุ่งเรือง" }
            if facingStar == activePeriod { return "ดาวโชคลาภส่องสว่าง · เปิดรับพลังงานมงคล" }
            if mountainStar == activePeriod { return "ดาวบุญบารมีคืนตำแหน่ง · ลูกหลานเจริญรุ่งเรือง" }
            if isShaWuHuang || isShaErHei { return "ดาวห้าเหลืองปะทะดาวสองดำ · รักษาความสงบใช้โลหะแก้" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "หนึ่งหกเกื้อหนุน · ส่งเสริมสติปัญญาการเรียน" }
            return "ดีร้ายปะปน · ตำแหน่งสมดุลสงบ"
        case .id:
            if mountainStar == activePeriod && facingStar == activePeriod { return "Bintang Kembar Hadir · Kekayaan & keluarga makmur" }
            if facingStar == activePeriod { return "Bintang Rezeki Menyinari · Sambut sirkulasi energi" }
            if mountainStar == activePeriod { return "Bintang Manusia Kembali · Keturunan berkembang pesat" }
            if isShaWuHuang || isShaErHei { return "Benturan 5 Kuning & 2 Hitam · Tenang & gunakan obat logam" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "Harmoni Satu–Enam · Mendukung prestasi akademis" }
            return "Campuran peruntungan · Posisi seimbang"
        case .auto, .zhHans:
            return baseEvaluation
        }
    }

    public var localizedPalaceName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            let directionMap = [
                "正北": "North", "西南": "Southwest", "正东": "East", "东南": "Southeast",
                "中宫": "Center", "西北": "Northwest", "正西": "West", "东北": "Northeast", "正南": "South"
            ]
            var result = palaceName
            for (source, localized) in directionMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        case .zhHant:
            return palaceName
                .replacingOccurrences(of: "东", with: "東")
                .replacingOccurrences(of: "兑", with: "兌")
                .replacingOccurrences(of: "离", with: "離")
                .replacingOccurrences(of: "宫", with: "宮")
        case .ja:
            return palaceName
                .replacingOccurrences(of: "东南", with: "南東")
                .replacingOccurrences(of: "西南", with: "南西")
                .replacingOccurrences(of: "东北", with: "北東")
                .replacingOccurrences(of: "西北", with: "北西")
                .replacingOccurrences(of: "东", with: "東")
                .replacingOccurrences(of: "兑", with: "兌")
                .replacingOccurrences(of: "离", with: "離")
                .replacingOccurrences(of: "宫", with: "宮")
        case .ko:
            let koMap = [
                "正北": "정북", "西南": "남서", "正东": "정동", "东南": "동남",
                "中宫": "중궁", "西北": "북서", "正西": "정서", "东北": "북동", "正南": "정남"
            ]
            var result = palaceName
            for (source, localized) in koMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        case .vi:
            let viMap = [
                "正北": "Chính Bắc", "西南": "Tây Nam", "正东": "Chính Đông", "东南": "Đông Nam",
                "中宫": "Trung Cung", "西北": "Tây Bắc", "正西": "Chính Tây", "东北": "Đông Bắc", "正南": "Chính Nam"
            ]
            var result = palaceName
            for (source, localized) in viMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        case .th:
            let thMap = [
                "正北": "ทิศเหนือ", "西南": "ทิศตะวันตกเฉียงใต้", "正东": "ทิศตะวันออก", "东南": "ทิศตะวันออกเฉียงใต้",
                "中宫": "จุดศูนย์กลาง", "西北": "ทิศตะวันตกเฉียงเหนือ", "正西": "ทิศตะวันตก", "东北": "ทิศตะวันออกเฉียงเหนือ", "正南": "ทิศใต้"
            ]
            var result = palaceName
            for (source, localized) in thMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        case .id:
            let idMap = [
                "正北": "Utara", "西南": "Barat Daya", "正东": "Timur", "东南": "Tenggara",
                "中宫": "Pusat", "西北": "Barat Laut", "正西": "Barat", "东北": "Timur Laut", "正南": "Selatan"
            ]
            var result = palaceName
            for (source, localized) in idMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        case .auto, .zhHans:
            return palaceName
        }
    }
    
    public var evaluation: String {
        baseEvaluation + "\n\n" + flyingStarsTraditionalSourceNote(
            for: LocalizationManager.shared.effectiveLanguage
        )
    }

    private var baseEvaluation: String {
        if hasEarthSha {
            return "五黄／二黑土煞 · 宜静安金属化解"
        } else if mountainStar == activePeriod && facingStar == activePeriod {
            return "当运双星会聚 · 财丁两旺"
        } else if facingStar == activePeriod {
            return "当旺财星照临 · 宜开门纳气"
        } else if mountainStar == activePeriod {
            return "当运丁星归位 · 人丁兴旺"
        } else if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) {
            return "一六共宗 · 水清木秀催文昌"
        } else {
            return "吉凶相参 · 平和之位"
        }
    }
}

public typealias XuanKongPalace = PalaceCell

public struct PeriodMeta {
    public let period: Int
    public let yuan: String
    public let trigram: String
    public let starName: String
    public let element: String
    public let startYear: Int
    public let endYear: Int
    public let isCurrent: Bool
    public let label: String
}

public enum XuanKongPattern: Int, CaseIterable, Equatable {
    case balancedFrontBack, bothAtFacing, bothAtSitting, reversed, distributed

    var titleKey: String {
        switch self {
        case .balancedFrontBack: return "xk_pattern_balanced_title"
        case .bothAtFacing: return "xk_pattern_front_title"
        case .bothAtSitting: return "xk_pattern_back_title"
        case .reversed: return "xk_pattern_reversed_title"
        case .distributed: return "xk_pattern_distributed_title"
        }
    }

    var explanationKey: String {
        switch self {
        case .balancedFrontBack: return "xk_pattern_balanced_body"
        case .bothAtFacing: return "xk_pattern_front_body"
        case .bothAtSitting: return "xk_pattern_back_body"
        case .reversed: return "xk_pattern_reversed_body"
        case .distributed: return "xk_pattern_distributed_body"
        }
    }
}

public enum XuanKongSectorUse: CaseIterable, Equatable {
    case quiet, separateUses, activity, rest, everyday

    var titleKey: String {
        switch self {
        case .quiet: return "xk_use_quiet"
        case .separateUses: return "xk_use_separate"
        case .activity: return "xk_use_activity"
        case .rest: return "xk_use_rest"
        case .everyday: return "xk_use_everyday"
        }
    }

    var reasonKey: String {
        switch self {
        case .quiet: return "xk_reason_quiet"
        case .separateUses: return "xk_reason_separate"
        case .activity: return "xk_reason_activity"
        case .rest: return "xk_reason_rest"
        case .everyday: return "xk_reason_everyday"
        }
    }

    var actionKey: String {
        switch self {
        case .quiet: return "xk_action_quiet"
        case .separateUses: return "xk_action_separate"
        case .activity: return "xk_action_activity"
        case .rest: return "xk_action_rest"
        case .everyday: return "xk_action_everyday"
        }
    }

    var avoidKey: String {
        switch self {
        case .quiet: return "xk_avoid_quiet"
        case .separateUses: return "xk_avoid_separate"
        case .activity: return "xk_avoid_activity"
        case .rest: return "xk_avoid_rest"
        case .everyday: return "xk_avoid_everyday"
        }
    }

    var symbol: String {
        switch self {
        case .quiet: return "hand.raised.fill"
        case .separateUses: return "rectangle.split.2x1"
        case .activity: return "sun.max.fill"
        case .rest: return "moon.fill"
        case .everyday: return "checkmark.circle"
        }
    }

    var priority: Int {
        switch self {
        case .quiet: return 0
        case .separateUses: return 1
        case .activity: return 2
        case .rest: return 3
        case .everyday: return 4
        }
    }
}

public struct XuanKongChart {
    public let period: Int                // 所选排盘元运 (1..9)
    public let sittingMountain: String   // 坐山
    public let facingMountain: String    // 向山
    public let patternType: String       // 到山到向 / 上山下水 / 双星到向 / 双星到坐
    public let pattern: XuanKongPattern
    public let sittingPalaceID: Int
    public let facingPalaceID: Int
    public let isSanBanGua: Bool         // 父母三般卦或连珠三般卦
    public let isQiXingDaJie: Bool       // 七星打劫局
    public let isTiGua: Bool             // 是否为兼向替卦排盘
    public let chartModeTitle: String    // 排盘模式 (下卦 / 替卦)
    public let palaces: [PalaceCell]     // 九宫格数据
    public let summaryAnalysis: String   // 综合格局断语
    public let patternDesc: String       // 卡片正文；共用出处由卡片统一展示
    public let periodMeta: PeriodMeta    // 动态历法元信息

    public var priorityPalaces: [PalaceCell] {
        palaces.sorted {
            if $0.suggestedUse.priority != $1.suggestedUse.priority {
                return $0.suggestedUse.priority < $1.suggestedUse.priority
            }
            let firstCautions = ($0.mountainStar == 2 || $0.mountainStar == 5 ? 1 : 0)
                + ($0.facingStar == 2 || $0.facingStar == 5 ? 1 : 0)
            let secondCautions = ($1.mountainStar == 2 || $1.mountainStar == 5 ? 1 : 0)
                + ($1.facingStar == 2 || $1.facingStar == 5 ? 1 : 0)
            if firstCautions != secondCautions { return firstCautions > secondCautions }
            return $0.id < $1.id
        }
    }
    
    /// 基于九宫飞星排盘动态推导的【催财旺气建议】
    public var wealthAdvice: String {
        wealthAdviceSummary + "\n\n" + wealthSourceNote
    }

    public var wealthAdviceSummary: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        // Never recommend activation in a 5-Yellow/2-Black palace. The
        // current-period star does not override an earth-sha warning.
        let wangPalace = palaces.first(where: { $0.facingStar == period && !$0.hasEarthSha })
        let nextStar = (period % 9) + 1
        let shengQiPalace = palaces.first(where: { !$0.isCenter && $0.facingStar == nextStar && !$0.hasEarthSha })
            ?? palaces.first(where: { $0.facingStar == nextStar && !$0.hasEarthSha })
        let wenchangPalace = palaces.first(where: { !$0.isCenter && (($0.mountainStar == 1 && $0.facingStar == 4) || ($0.mountainStar == 4 && $0.facingStar == 1) || ($0.mountainStar == 1 && $0.facingStar == 6) || ($0.mountainStar == 6 && $0.facingStar == 1)) })

        let wangName = wangPalace?.localizedPalaceName ?? ""
        let wangCombo = wangPalace.map { "\($0.mountainStar)-\($0.facingStar)" } ?? "\(period)"
        let sqName = shengQiPalace?.localizedPalaceName ?? ""
        let sqCombo = shengQiPalace.map { "\($0.mountainStar)-\($0.facingStar)" } ?? "\(nextStar)"
        let wcName = wenchangPalace?.localizedPalaceName

        switch lang {
        case .en:
            let wcNote = wcName.map { " Wenchang/Harmony star gathers at [\($0)]." } ?? ""
            return "• Wealth & Prosperity: Current Period-\(period) facing star lands at [\(wangName)] (Star \(wangCombo)), and future Sheng-Qi Star \(nextStar) reaches [\(sqName)] (Star \(sqCombo)). Keep these sectors bright, open, or place moving water to activate wealth.\(wcNote)"
        case .zhHant:
            let wcNote = wcName.map { "另【\($0)】逢文昌吉星會聚，利書房策劃。" } ?? ""
            return "• 催財旺位：當令\(period)運向星飛臨【\(wangName)】（山向\(wangCombo)），生氣\(nextStar)星到【\(sqName)】（山向\(sqCombo)），宜在此保持明堂開闊、安設動水或長明燈催旺財源。\(wcNote)"
        case .ja:
            let wcNote = wcName.map { "また【\($0)】は文昌吉星が会聚し書斎に吉。" } ?? ""
            return "• 催財旺位：当令\(period)運の向星が【\(wangName)】（山向\(wangCombo)）に飛臨し、生気\(nextStar)星が【\(sqName)】（山向\(sqCombo)）に到ります。採光や動水を設けて財気を催旺してください。\(wcNote)"
        case .ko:
            let wcNote = wcName.map { " 또한 【\($0)】에 문창 길성이 모여 서재·기획 공간에 길합니다." } ?? ""
            return "• 재물 발복 방위: 당령 \(period)운 향성이 【\(wangName)】(산향 \(wangCombo))에 비림하고 생기 \(nextStar)성이 【\(sqName)】(산향 \(sqCombo))에 이르니, 채광을 밝히고 동수(물)를 배치하여 재원을 활성화하십시오.\(wcNote)"
        case .vi:
            let wcNote = wcName.map { " Ngoài ra 【\($0)】 hội tụ sao Văn Xương, rất lợi cho phòng đọc sách và hoạch định." } ?? ""
            return "• Cung kích tài: Hướng tinh đương vận \(period) bay tới 【\(wangName)】 (Sơn Hướng \(wangCombo)), sinh khí tinh \(nextStar) đáo 【\(sqName)】 (Sơn Hướng \(sqCombo)), nên mở thoáng, tăng ánh sáng hoặc đặt thủy động kích hoạt tài lộc.\(wcNote)"
        case .th:
            let wcNote = wcName.map { " ส่วนทิศ【\($0)】มีดาวเหวินชางชุมนุม เหมาะจัดเป็นห้องทำงานหรือห้องหนังสือ" } ?? ""
            return "• ตำแหน่งเรียกทรัพย์: ดาวหันประจำยุค \(period) สถิตที่ 【\(wangName)】 (ดาว \(wangCombo)) และดาวพลังเซิงชี่ \(nextStar) อยู่ที่ 【\(sqName)】 (ดาว \(sqCombo)) ควรเปิดโล่งรับแสงหรือตั้งน้ำพุกระตุ้นโชคลาภ\(wcNote)"
        case .id:
            let wcNote = wcName.map { " Sektor [\($0)] juga dinaungi bintang Wenchang, baik untuk ruang kerja atau belajar." } ?? ""
            return "• Sektor Rezeki: Bintang hadap periode \(period) berada di [\(wangName)] (Bintang \(wangCombo)) & bintang Sheng-Qi \(nextStar) di [\(sqName)] (Bintang \(sqCombo)); buka sirkulasi cahaya atau letakkan air mengalir untuk mengaktifkan rezeki.\(wcNote)"
        case .auto, .zhHans:
            let wcNote = wcName.map { "另【\($0)】逢文昌吉星会聚，利书房策划。" } ?? ""
            return "• 催财旺位：当令\(period)运向星飞临【\(wangName)】（山向\(wangCombo)），生气\(nextStar)星到【\(sqName)】（山向\(sqCombo)），宜在此保持明堂开阔、安设动水或长明灯催旺财源。\(wcNote)"
        }
    }

    /// 基于九宫飞星排盘动态推导的空间环境复核建议。
    public var healthAdvice: String {
        healthAdviceSummary + "\n\n" + healthSourceNote
    }

    public var healthAdviceSummary: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        let clash25Palace = palaces.first(where: { ($0.mountainStar == 2 && $0.facingStar == 5) || ($0.mountainStar == 5 && $0.facingStar == 2) || ($0.mountainStar == 5 && $0.facingStar == 5) })
        let wuHuangPalace = palaces.first(where: { $0.facingStar == 5 }) ?? palaces.first(where: { $0.mountainStar == 5 })
        let erHeiPalace = palaces.first(where: { $0.facingStar == 2 }) ?? palaces.first(where: { $0.mountainStar == 2 })
        
        let wuName = wuHuangPalace?.localizedPalaceName ?? ""
        let wuCombo = wuHuangPalace.map { "\($0.mountainStar)-\($0.facingStar)" } ?? "5"
        let erName = erHeiPalace?.localizedPalaceName ?? ""
        let erCombo = erHeiPalace.map { "\($0.mountainStar)-\($0.facingStar)" } ?? "2"
        
        switch lang {
        case .en:
            if let clash = clash25Palace {
                return "• Health & Sha Caution: Critical 2–5 / Double-5 Earth Sha converges at [\(clash.localizedPalaceName)] (Star \(clash.mountainStar)-\(clash.facingStar)), with 5-Yellow at [\(wuName)] and 2-Black at [\(erName)]. Keep quiet, avoid renovation or red items, and place a copper gourd or 6-coin Metal cure."
            }
            return "• Health & Sha Caution: 5-Yellow Sha lands at [\(wuName)] (Star \(wuCombo)) and 2-Black Sickness Star at [\(erName)] (Star \(erCombo)). Avoid loud noise, drilling, or fire elements here; use copper/Metal ornaments to drain Earth Sha."
        case .zhHant:
            if let clash = clash25Palace {
                return "• 病符防煞：【\(clash.localizedPalaceName)】逢山向\(clash.mountainStar)-\(clash.facingStar)二五交加/五黃疊臨重煞（五黃位【\(wuName)】、二黑位【\(erName)】），切忌動土裝修與紅紫火物，務必安放銅葫蘆或六帝錢洩土化煞。"
            }
            return "• 病符防煞：五黃廉貞煞飛臨【\(wuName)】（山向\(wuCombo)），二黑病符星到【\(erName)】（山向\(erCombo)），此二宮宜靜不宜動，忌見紅火動土，宜掛銅葫蘆或六帝銅錢化洩凶性。"
        case .ja:
            if let clash = clash25Palace {
                return "• 病符防煞：【\(clash.localizedPalaceName)】に山向\(clash.mountainStar)-\(clash.facingStar)の二五交加・五黄重煞が集結（五黄【\(wuName)】・二黒【\(erName)】）。改修や赤色物を避け、銅瓢箪や六帝銭で土煞を泄化してください。"
            }
            return "• 病符防煞：五黄廉貞煞が【\(wuName)】（山向\(wuCombo)）、二黒病符星が【\(erName)】（山向\(erCombo)）に飛臨。静寂を保ち、銅瓢箪や金属置物で凶気を化泄すると吉。"
        case .ko:
            if let clash = clash25Palace {
                return "• 병부 방살: 【\(clash.localizedPalaceName)】에 산향 \(clash.mountainStar)-\(clash.facingStar) 이오교가/오황중살이 모입니다(오황 【\(wuName)】, 이흑 【\(erName)】). 공사와 붉은색 배치를 삼가고 동호리병이나 육제전으로 토살을 설기하십시오."
            }
            return "• 병부 방살: 오황살이 【\(wuName)】(산향 \(wuCombo))에, 이흑 병부성이 【\(erName)】(산향 \(erCombo))에 위치합니다. 공사와 붉은색 배치를 피하고 동호리병이나 육제전(금속)으로 토살을 설기하십시오."
        case .vi:
            if let clash = clash25Palace {
                return "• Phòng bệnh hóa sát: 【\(clash.localizedPalaceName)】 gặp Sơn Hướng \(clash.mountainStar)-\(clash.facingStar) Nhị Ngũ giao gia / Ngũ Hoàng trùng sát (Ngũ Hoàng tại 【\(wuName)】, Nhị Hắc tại 【\(erName)】). Tuyệt đối kỵ động thổ và sắc đỏ, nên đặt hồ lô đồng hoặc tiền Lục Đế để tiết Thổ hóa sát."
            }
            return "• Phòng bệnh hóa sát: Ngũ Hoàng sát lâm 【\(wuName)】 (Sơn Hướng \(wuCombo)), Nhị Hắc bệnh phù đáo 【\(erName)】 (Sơn Hướng \(erCombo)). Kỵ động thổ và vật màu đỏ, nên treo hồ lô đồng hoặc lục đế tiền để tiết thổ hóa sát."
        case .th:
            if let clash = clash25Palace {
                return "• ป้องกันโรคและเคราะห์: ทิศ【\(clash.localizedPalaceName)】เกิดเกณฑ์ดาว \(clash.mountainStar)-\(clash.facingStar) สองห้าปะทะ/ห้าเหลืองซ้อนทับ (ห้าเหลืองที่【\(wuName)】 สองดำที่【\(erName)】) งดการเจาะทุบและของสีแดง แนะนำวางน้ำเต้าทองเหลืองหรือเหรียญหกจักรพรรดิเพื่อสลายพลังดินร้าย"
            }
            return "• ป้องกันโรคและเคราะห์: ดาวห้าเหลืองอยู่ที่ 【\(wuName)】 (ดาว \(wuCombo)) และดาวสองดำโรคภัยอยู่ที่ 【\(erName)】 (ดาว \(erCombo)) หลีกเลี่ยงการต่อเติมและสีแดง แนะนำแขวนน้ำเต้าทองเหลืองหรือเหรียญจีน 6 เหรียญแก้เคล็ด"
        case .id:
            if let clash = clash25Palace {
                return "• Kesehatan & Penangkal Sha: Kombinasi berat 2–5 / 5-Ganda berkumpul di [\(clash.localizedPalaceName)] (Bintang \(clash.mountainStar)-\(clash.facingStar); 5-Kuning di [\(wuName)], 2-Hitam di [\(erName)]). Hindari renovasi dan unsur merah; letakkan labu tembaga atau 6 koin logam untuk meredam Sha Tanah."
            }
            return "• Kesehatan & Penangkal Sha: Bintang 5-Kuning berada di [\(wuName)] (Bintang \(wuCombo)) & 2-Hitam di [\(erName)] (Bintang \(erCombo)); hindari renovasi atau warna merah menyala, gunakan labu tembaga/logam untuk menetralkan."
        case .auto, .zhHans:
            if let clash = clash25Palace {
                return "• 病符防煞：【\(clash.localizedPalaceName)】逢山向\(clash.mountainStar)-\(clash.facingStar)二五交加/五黄叠临重煞（五黄位【\(wuName)】、二黑位【\(erName)】），切忌动土装修与红紫火物，务必安放铜葫芦或六帝钱泄土化煞。"
            }
            return "• 病符防煞：五黄廉贞煞飞临【\(wuName)】（山向\(wuCombo)），二黑病符星到【\(erName)】（山向\(erCombo)），此二宫宜静不宜动，忌见红火动土，宜挂铜葫芦或六帝铜钱化泄凶性。"
        }
    }
    
    /// 基于九宫飞星排盘动态推导的空间布局复核建议。
    public var remedyAdvice: String {
        remedyAdviceSummary + "\n\n" + healthSourceNote
    }

    public var remedyAdviceSummary: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        let dingPalace = palaces.first(where: { $0.mountainStar == period })
        let caiPalace = palaces.first(where: { $0.facingStar == period })
        let clash37Palace = palaces.first(where: { !$0.isCenter && (($0.mountainStar == 3 && $0.facingStar == 7) || ($0.mountainStar == 7 && $0.facingStar == 3)) })
        let clash79Palace = palaces.first(where: { !$0.isCenter && (($0.mountainStar == 7 && $0.facingStar == 9) || ($0.mountainStar == 9 && $0.facingStar == 7)) })
        
        let dingName = dingPalace?.localizedPalaceName ?? ""
        let caiName = caiPalace?.localizedPalaceName ?? ""
        let samePalace = (dingPalace?.id != nil && dingPalace?.id == caiPalace?.id)
        
        switch lang {
        case .en:
            var extra = ""
            if let c37 = clash37Palace {
                extra = " At [\(c37.localizedPalaceName)] (3–7 Metal-Wood clash), place still water to harmonize."
            } else if let c79 = clash79Palace {
                extra = " At [\(c79.localizedPalaceName)] (7–9 Fire-Metal clash), place ceramic/earth decor to balance."
            }
            if samePalace {
                return "• Spatial Remedy: Both Period-\(period) Mountain & Facing stars converge at [\(caiName)]. Place an aquarium or water feature in front to activate wealth, and set a solid tall cabinet or decorative stone behind to anchor family health. → Scope: Supports household income, career momentum, and family vitality across [\(caiName)].\(extra)"
            }
            return "• Spatial Remedy: The Period-\(period) Facing wealth star resides at [\(caiName)]—keep it bright, open, and paired with water or mirror accents to gather prosperity. The Mountain vitality star at [\(dingName)] favors a tall cabinet or stone ornament for calm stability. → Scope: [\(caiName)] governs career and income; [\(dingName)] supports family health and children's constitution.\(extra)"
        case .zhHant:
            var extra = ""
            if let c37 = clash37Palace {
                extra = "【\(c37.localizedPalaceName)】見三七交劍煞，宜設靜水通關金木。"
            } else if let c79 = clash79Palace {
                extra = "【\(c79.localizedPalaceName)】見七九火金相戰，宜置黃玉陶瓷洩火生金。"
            }
            if samePalace {
                return "白話：當運山向雙\(period)星同聚【\(caiName)】，此方位前宜見水（魚缸/水景）納財、後宜立高櫃或山石固丁。→ 影響：財丁同管——財管男主人及經營家人的正財事業、丁管全家健康與小孩體質，覆蓋【\(caiName)】區域。\(extra)"
            }
            return "白話：當運財星在【\(caiName)】，此方位宜敞亮見水（魚缸、水景或鏡面）聚財；當運丁星在【\(dingName)】，宜放高櫃或山石穩住健康人丁。→ 影響：財位管家中的正財與事業進帳（男主人與經營家人）、丁位管家人健康與人丁（小孩體質、長輩康健），分別覆蓋【\(caiName)】【\(dingName)】區域。\(extra)"
        case .ja:
            var extra = ""
            if let c37 = clash37Palace {
                extra = "【\(c37.localizedPalaceName)】の三七交剣煞には静水で金木を通関。"
            } else if let c79 = clash79Palace {
                extra = "【\(c79.localizedPalaceName)】の七九火金相克には陶器・土器で調和。"
            }
            if samePalace {
                return "• 空間配置の要点：当運の山向双\(period)星が【\(caiName)】に同聚しています。前方に水槽や水景を置いて財気を集め、後方に背の高い家具や山石を据えて人丁を固めます。→ 作用範囲：一家の収入・事業運および家族の健康・子供の体質を支え、【\(caiName)】全域に作用します。\(extra)"
            }
            return "• 空間配置の要点：当運の財星が宿る【\(caiName)】は明るく開放し、水槽・水景・鏡を配して財気を集めます。当運の丁星が宿る【\(dingName)】は背の高い家具や山石で健康・人丁を安定させます。→ 作用範囲：財位【\(caiName)】は収入と仕事運、丁位【\(dingName)】は家族の健康と子供の体質を司ります。\(extra)"
        case .ko:
            var extra = ""
            if let c37 = clash37Palace {
                extra = " 【\(c37.localizedPalaceName)】의 3·7 교검살은 정수(물)를 두어 금목 상전을 통관하세요."
            } else if let c79 = clash79Palace {
                extra = " 【\(c79.localizedPalaceName)】의 7·9 화금 상전은 도자기나 황옥 소품으로 화기를 설기하세요."
            }
            if samePalace {
                return "• 공간 비보 요점: 당운 산향 쌍\(period)성이 【\(caiName)】에 함께 모입니다. 앞쪽에는 어항·수경을 두어 재물을 모으고, 뒤쪽에는 높은 수납장이나 산석을 배치해 인정을 굳히세요. → 작용 범위: 가계의 정재·사업운과 온 가족의 건강·자녀 체질을 함께 관장하며 【\(caiName)】 구역에 작용합니다.\(extra)"
            }
            return "• 공간 비보 요점: 당운 재성이 자리한 【\(caiName)】은 밝고 트이게 두고 어항·수경·거울로 재기를 모으고, 당운 정성이 자리한 【\(dingName)】은 높은 가구나 산석으로 건강과 인정을 안정시키세요. → 작용 범위: 재위 【\(caiName)】은 수입과 사업운을, 정위 【\(dingName)】은 가족 건강과 자녀 체질을 관장합니다.\(extra)"
        case .vi:
            var extra = ""
            if let c37 = clash37Palace {
                extra = " Tại 【\(c37.localizedPalaceName)】 gặp Tam Thất giao kiếm sát, nên đặt nước tĩnh để thông quan Kim Mộc."
            } else if let c79 = clash79Palace {
                extra = " Tại 【\(c79.localizedPalaceName)】 gặp Thất Cửu Hỏa Kim tương chiến, nên đặt đồ gốm sứ vàng để tiết Hỏa sinh Kim."
            }
            if samePalace {
                return "• Bố cục hóa giải: Song tinh Sơn Hướng vận \(period) cùng tụ tại 【\(caiName)】. Phía trước nên đặt bể cá hoặc thủy cảnh để nạp tài, phía sau kê tủ cao hoặc đá phong thủy để vững nhân đinh. → Phạm vi: Quản lý đồng thời tài lộc, sự nghiệp của trụ cột và sức khỏe cả gia đình tại khu vực 【\(caiName)】.\(extra)"
            }
            return "• Bố cục hóa giải: Sao Tài đương vận ở 【\(caiName)】 nên giữ sáng thoáng, kết hợp bể cá, thủy cảnh hoặc gương để tụ tài; sao Đinh đương vận ở 【\(dingName)】 nên kê tủ cao hoặc đá phong thủy để dưỡng sức khỏe và nhân khẩu. → Phạm vi: Cung Tài 【\(caiName)】 chủ về thu nhập và sự nghiệp, cung Đinh 【\(dingName)】 chủ về sức khỏe gia đạo và thể chất trẻ nhỏ.\(extra)"
        case .th:
            var extra = ""
            if let c37 = clash37Palace {
                extra = " ส่วนทิศ【\(c37.localizedPalaceName)】มีเกณฑ์ 3–7 ทองปะทะไม้ ควรวางน้ำนิ่งเพื่อเชื่อมสมดุลธาตุ"
            } else if let c79 = clash79Palace {
                extra = " ส่วนทิศ【\(c79.localizedPalaceName)】มีเกณฑ์ 7–9 ไฟปะทะทอง ควรวางเครื่องปั้นดินเผาหรือเซรามิกเพื่อลดไฟหนุนทอง"
            }
            if samePalace {
                return "• การจัดวางเสริมมงคล: ดาวคู่ภูเขาและทิศหันประจำยุค \(period) รวมอยู่ที่【\(caiName)】 ด้านหน้าควรตั้งตู้ปลาหรือน้ำพุเพื่อรับทรัพย์ ด้านหลังวางตู้สูงหรือหินประดับเพื่อเสริมความมั่นคงของคนในบ้าน → ขอบเขตผลลัพธ์: ดูแลทั้งรายได้ การงานของผู้นำครอบครัว และสุขภาพของสมาชิกทุกคนในบริเวณ【\(caiName)】\(extra)"
            }
            return "• การจัดวางเสริมมงคล: ดาวโชคลาภประจำยุค \(period) อยู่ที่【\(caiName)】 ควรจัดให้โปร่งสว่างและมีตู้ปลา น้ำพุ หรือกระจกเพื่อรวมทรัพย์ ส่วนดาวสุขภาพและบริวารที่【\(dingName)】 ควรตั้งตู้สูงหรือหินประดับเพื่อความมั่นคง → ขอบเขตผลลัพธ์: ทิศ【\(caiName)】ส่งเสริมรายได้และการงาน ทิศ【\(dingName)】ดูแลสุขภาพครอบครัวและบุตรหลาน\(extra)"
        case .id:
            var extra = ""
            if let c37 = clash37Palace {
                extra = " Di [\(c37.localizedPalaceName)] (benturan 3–7 Logam-Kayu), letakkan air tenang untuk menyelaraskan elemen."
            } else if let c79 = clash79Palace {
                extra = " Di [\(c79.localizedPalaceName)] (benturan 7–9 Api-Logam), letakkan keramik atau unsur tanah sebagai penyeimbang."
            }
            if samePalace {
                return "• Penataan Ruang: Bintang Gunung & Hadap periode \(period) berkumpul di [\(caiName)]. Tempatkan akuarium atau fitur air di bagian depan untuk menghimpun rezeki, serta lemari tinggi atau batu hias di bagian belakang untuk menopang kesehatan keluarga. → Cakupan: Menunjang pendapatan, karier, dan kebugaran seluruh anggota keluarga di area [\(caiName)].\(extra)"
            }
            return "• Penataan Ruang: Bintang rezeki periode \(period) berada di [\(caiName)]—biarkan terang, lapang, dan tambahkan elemen air atau cermin untuk menarik kemakmuran; bintang kesehatan di [\(dingName)] diperkuat dengan lemari tinggi atau ornamen batu. → Cakupan: Sektor [\(caiName)] mendukung pendapatan & karier, sedangkan [\(dingName)] menjaga kesehatan keluarga dan daya tahan anak.\(extra)"
        case .auto, .zhHans:
            var extra = ""
            if let c37 = clash37Palace {
                extra = "【\(c37.localizedPalaceName)】见三七交剑煞，宜设静水通关金木。"
            } else if let c79 = clash79Palace {
                extra = "【\(c79.localizedPalaceName)】见七九火金相战，宜置黄玉陶瓷泄火生金。"
            }
            if samePalace {
                return "白话：当运山向双\(period)星同聚【\(caiName)】，此方位前宜见水（鱼缸/水景）纳财、后宜立高柜或山石固丁。→ 影响：财丁同管——财管男主人及经营家人的正财事业、丁管全家健康与小孩体质，覆盖【\(caiName)】区域。\(extra)"
            }
            return "白话：当运财星在【\(caiName)】，此方位宜敞亮见水（鱼缸、水景或镜面）聚财；当运丁星在【\(dingName)】，宜放高柜或山石稳住健康人丁。→ 影响：财位管家中正财与事业进账（男主人与经营家人）、丁位管家人健康与人丁（小孩体质、长辈康健），分别覆盖【\(caiName)】【\(dingName)】区域。\(extra)"
        }
    }

    private var traditionalSourceNote: String {
        flyingStarsTraditionalSourceNote(
            for: LocalizationManager.shared.effectiveLanguage
        )
    }

    /// The analysis card displays the shared source and explanation once.
    public var analysisNote: String { healthSourceNote }

    private var wealthSourceNote: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return "Classical source: the transmitted Xuan-Kong mountain/facing-star formula (wording varies by edition) uses ‘Wang Shan Wang Xiang prospers people and wealth’, ‘Double Stars at Facing prospers wealth’, and ‘Shang Shan Xia Shui loses wealth and people’. Explanation: wealth, income and prosperity are traditional metaphysical symbols; verify real budgets and decisions independently."
        case .zhHant:
            return "古籍出處：玄空山向星訣（傳本有異文）有「到山到向，旺丁旺財；雙星到向，旺財不旺丁；上山下水，敗財損丁」等原文。解釋：財源、收入與旺財是傳統術數象徵，實際預算及決策請獨立核對。"
        case .ja:
            return "出典：玄空山向星訣（伝本に異文）には「到山到向は財と人が栄え、双星到向は財、上山下水は財と人を損なう」とあります。解釈：財・収入・繁栄は伝統術数の象徴であり、実際の予算と判断は独立に確認してください。"
        case .ko:
            return "출처: 전통 현공 산향성결(전본 이문)은 ‘도산도향 왕정왕재, 쌍성도향 왕재, 동산하수 손재손정’이라 전합니다. 설명: 재물·수입·번영은 전통 술수의 상징이며 실제 예산과 결정은 별도로 확인하세요."
        case .vi:
            return "Nguồn: Quyết tinh sơn hướng Huyền Không truyền câu ‘đáo sơn đáo hướng vượng đinh vượng tài; song tinh đáo hướng vượng tài; thượng sơn hạ thủy bại tài tổn đinh’ (bản truyền có dị văn). Giải thích: tài lộc, thu nhập và thịnh vượng là biểu tượng thuật số; hãy tự kiểm tra ngân sách và quyết định thực tế."
        case .th:
            return "แหล่งที่มา: ตำราดาวภูเขา-ทิศเสวียนคงสืบคำว่า ‘ถึงเขาถึงทิศรุ่งเรืองคนและทรัพย์; ดาวคู่สู่หน้ารุ่งเรืองทรัพย์; ขึ้นเขาลงน้ำเสียทรัพย์เสียคน’ (ตำราต่างกัน) คำอธิบาย: ทรัพย์ รายได้ และความรุ่งเรืองเป็นสัญลักษณ์ทางโหราศาสตร์ ควรตรวจสอบงบประมาณและการตัดสินใจจริงแยกต่างหาก"
        case .id:
            return "Sumber: rumus bintang gunung/hadap Xuan-Kong (versi tradisi berbeda) memuat ‘makmurkan orang dan harta; bintang ganda di hadap memakmurkan harta; Shang Shan Xia Shui merusak harta dan orang’. Penjelasan: rezeki, pendapatan, dan kemakmuran adalah simbol metafisika tradisional; periksa anggaran dan keputusan nyata secara mandiri."
        case .auto, .zhHans:
            return "古籍出处：玄空山向星诀（传本有异文）有“到山到向，旺丁旺财；双星到向，旺财不旺丁；上山下水，败财损丁”等原文。解释：财源、收入与旺财是传统术数象征，实际预算及决策请独立核对。"
        }
    }

    private var healthSourceNote: String {
        let note: String
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            note = "Interpretation: Please verify ventilation, daylight, noise, drainage, and structural safety on site; consult qualified professionals for medical or financial matters."
        case .zhHant:
            note = "解釋：請結合通風、採光、噪音、排水和結構安全現場複核；涉及健康或財務事項應諮詢相應專業人士。"
        case .ja:
            note = "解釈：換気・採光・騒音・排水・構造安全を現地で確認してください。健康や財務に関する事項は専門家にご相談ください。"
        case .ko:
            note = "해석: 통풍, 채광, 소음, 배수 및 구조 안전을 현장에서 함께 점검하시고, 건강이나 재무 관련 사항은 전문가와 상담하십시오."
        case .vi:
            note = "Giải thích: Vui lòng kết hợp kiểm tra thông gió, ánh sáng, tiếng ồn, thoát nước và an toàn kết cấu tại hiện trường; các vấn đề sức khỏe hoặc tài chính nên tham khảo chuyên gia."
        case .th:
            note = "คำอธิบาย: โปรดตรวจสอบการระบายอากาศ แสงสว่าง เสียงรบกวน การระบายน้ำ และความปลอดภัยของโครงสร้างหน้างาน สำหรับเรื่องสุขภาพหรือการเงินควรปรึกษาผู้เชี่ยวชาญ"
        case .id:
            note = "Penjelasan: Harap periksa ventilasi, pencahayaan, kebisingan, drainase, dan keamanan struktur di lokasi; konsultasikan masalah kesehatan atau keuangan dengan profesional terkait."
        case .auto, .zhHans:
            note = "解释：请结合通风、采光、噪音、排水和结构安全现场复核；涉及健康或财务事项应咨询相应专业人士。"
        }
        return traditionalSourceNote + "\n" + note
    }

}

public final class FlyingStarsEngine {
    public static let shared = FlyingStarsEngine()
    
    // 历法推算当前所处三元九运 (以公元1864年甲子上元一运为基准，180年为一大元，20年为一运)
    public func currentPeriod(for date: Date = Date()) -> Int {
        let offset = effectiveSolarYear(for: date) - 1864
        let cycleYear = (offset % 180 + 180) % 180
        return (cycleYear / 20) + 1
    }
    
    // 获取指定运数的完整天文学与干支历法信息 (根据给定日期所属的180年大周期推导对应年限区间)
    public func periodMeta(period: Int, for date: Date = Date()) -> PeriodMeta {
        let year = effectiveSolarYear(for: date)
        let curPeriod = currentPeriod(for: date)
        
        let p = max(1, min(9, period))
        let offset = year - 1864
        let currentCycleStart = 1864 + (offset >= 0 ? (offset / 180) * 180 : ((offset - 179) / 180) * 180)
        let startY = currentCycleStart + (p - 1) * 20
        let endY = startY + 19
        
        let lang = LocalizationManager.shared.effectiveLanguage
        
        let yuan: String
        let trigram: String
        let starName: String
        let element: String
        
        switch lang {
        case .en:
            let yuans = ["", "Upper Yuan", "Upper Yuan", "Upper Yuan", "Middle Yuan", "Middle Yuan", "Middle Yuan", "Lower Yuan", "Lower Yuan", "Lower Yuan"]
            let trigrams = ["", "Kan", "Kun", "Zhen", "Xun", "Center", "Qian", "Dui", "Gen", "Li"]
            let stars = ["", "1 White TanLang", "2 Black JuMen", "3 Jade LuCun", "4 Green WenQu", "5 Yellow LianZhen", "6 White WuQu", "7 Red PoJun", "8 White ZuoFu", "9 Purple YouBi"]
            let elements = ["", "Water", "Earth", "Wood", "Wood", "Earth", "Metal", "Metal", "Earth", "Fire"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .zhHant:
            let yuans = ["", "上元", "上元", "上元", "中元", "中元", "中元", "下元", "下元", "下元"]
            let trigrams = ["", "坎", "坤", "震", "巽", "中", "乾", "兌", "艮", "離"]
            let stars = ["", "一白貪狼", "二黑巨門", "三碧祿存", "四綠文曲", "五黃廉貞", "六白武曲", "七赤破軍", "八白左輔", "九紫右弼"]
            let elements = ["", "水", "土", "木", "木", "土", "金", "金", "土", "火"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .ja:
            let yuans = ["", "上元", "上元", "上元", "中元", "中元", "中元", "下元", "下元", "下元"]
            let trigrams = ["", "坎", "坤", "震", "巽", "中", "乾", "兌", "艮", "離"]
            let stars = ["", "一白貪狼", "二黒巨門", "三碧禄存", "四緑文曲", "五黄廉貞", "六白武曲", "七赤破軍", "八白左輔", "九紫右弼"]
            let elements = ["", "水", "土", "木", "木", "土", "金", "金", "土", "火"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .ko:
            let yuans = ["", "상원", "상원", "상원", "중원", "중원", "중원", "하원", "하원", "하원"]
            let trigrams = ["", "감", "곤", "진", "손", "중", "건", "태", "간", "이"]
            let stars = ["", "일백탐랑", "이흑거문", "삼벽녹존", "사록문곡", "오황염정", "육백무곡", "칠적파군", "팔백좌보", "구자우필"]
            let elements = ["", "수", "토", "목", "목", "토", "금", "금", "토", "화"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .vi:
            let yuans = ["", "Thượng Nguyên", "Thượng Nguyên", "Thượng Nguyên", "Trung Nguyên", "Trung Nguyên", "Trung Nguyên", "Hạ Nguyên", "Hạ Nguyên", "Hạ Nguyên"]
            let trigrams = ["", "Khảm", "Khôn", "Chấn", "Tốn", "Trung", "Càn", "Đoài", "Cấn", "Ly"]
            let stars = ["", "Nhất Bạch Tham Lang", "Nhị Hắc Cự Môn", "Tam Bích Lộc Tồn", "Tứ Lục Văn Khúc", "Ngũ Hoàng Liêm Trinh", "Lục Bạch Vũ Khúc", "Thất Xích Phá Quân", "Bát Bạch Tả Phụ", "Cửu Tử Hữu Bật"]
            let elements = ["", "Thủy", "Thổ", "Mộc", "Mộc", "Thổ", "Kim", "Kim", "Thổ", "Hỏa"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .th:
            let yuans = ["", "ง้วนบน", "ง้วนบน", "ง้วนบน", "ง้วนกลาง", "ง้วนกลาง", "ง้วนกลาง", "ง้วนล่าง", "ง้วนล่าง", "ง้วนล่าง"]
            let trigrams = ["", "ข่าน", "คุน", "เจิ้น", "ซวิ่น", "กลาง", "เฉียน", "ตุ้ย", "เกิ้น", "หลี"]
            let stars = ["", "หนึ่งขาว ทานหลาง", "สองดำ จวี้เหมิน", "สามเขียว ลู่ฉุน", "สี่เขียว เหวินชวี", "ห้าเหลือง เหลียนเจิน", "หกขาว อู่ชวี", "เจ็ดแดง โพ่จวิน", "แปดขาว จั่วฝู่", "เก้าม่วง โยวปี้"]
            let elements = ["", "น้ำ", "ดิน", "ไม้", "ไม้", "ดิน", "ทอง", "ทอง", "ดิน", "ไฟ"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .id:
            let yuans = ["", "Yuan Atas", "Yuan Atas", "Yuan Atas", "Yuan Tengah", "Yuan Tengah", "Yuan Tengah", "Yuan Bawah", "Yuan Bawah", "Yuan Bawah"]
            let trigrams = ["", "Kan", "Kun", "Zhen", "Xun", "Pusat", "Qian", "Dui", "Gen", "Li"]
            let stars = ["", "1 Putih TanLang", "2 Hitam JuMen", "3 Giok LuCun", "4 Hijau WenQu", "5 Kuning LianZhen", "6 Putih WuQu", "7 Merah PoJun", "8 Putih ZuoFu", "9 Ungu YouBi"]
            let elements = ["", "Air", "Tanah", "Kayu", "Kayu", "Tanah", "Logam", "Logam", "Tanah", "Api"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .auto, .zhHans:
            let yuans = ["", "上元", "上元", "上元", "中元", "中元", "中元", "下元", "下元", "下元"]
            let trigrams = ["", "坎", "坤", "震", "巽", "中", "乾", "兑", "艮", "离"]
            let stars = ["", "一白贪狼", "二黑巨门", "三碧禄存", "四绿文曲", "五黄廉贞", "六白武曲", "七赤破军", "八白左辅", "九紫右弼"]
            let elements = ["", "水", "土", "木", "木", "土", "金", "金", "土", "火"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        }
        
        let isCur = (p == curPeriod)
        let label: String
        switch lang {
        case .en:
            label = isCur ? "Current Period \(p) (\(startY)–\(endY), \(yuan) · \(element))" : "Period \(p) (\(startY)–\(endY), \(yuan) · \(element))"
        case .zhHant:
            label = isCur ? "當前\(yuan)\(p)運（\(startY)—\(endY)年，\(starName)\(element)星當令）" : "\(yuan)\(p)運（\(startY)—\(endY)年，\(starName)\(element)星當令）"
        case .ja:
            label = isCur ? "現在\(yuan)\(p)運（\(startY)—\(endY)年、\(starName)\(element)星当令）" : "\(yuan)\(p)運（\(startY)—\(endY)年、\(starName)\(element)星当令）"
        case .ko:
            label = isCur ? "현재 \(yuan) \(p)운 (\(startY)—\(endY)년, \(starName) \(element)성 당령)" : "\(yuan) \(p)운 (\(startY)—\(endY)년, \(starName) \(element)성 당령)"
        case .vi:
            label = isCur ? "Hiện tại \(yuan) Vận \(p) (\(startY)—\(endY), \(starName) \(element) tinh đương lệnh)" : "\(yuan) Vận \(p) (\(startY)—\(endY), \(starName) \(element) tinh đương lệnh)"
        case .th:
            label = isCur ? "ปัจจุบันยุค \(p) \(yuan) (\(startY)—\(endY), ดาว\(starName) ธาตุ\(element))" : "ยุค \(p) \(yuan) (\(startY)—\(endY), ดาว\(starName) ธาตุ\(element))"
        case .id:
            label = isCur ? "Periode Saat Ini \(p) (\(startY)–\(endY), \(yuan) · \(element))" : "Periode \(p) (\(startY)–\(endY), \(yuan) · \(element))"
        case .auto, .zhHans:
            label = isCur ? "当前\(yuan)\(p)运（\(startY)—\(endY)年，\(starName)\(element)星当令）" : "\(yuan)\(p)运（\(startY)—\(endY)年，\(starName)\(element)星当令）"
        }
        
        return PeriodMeta(
            period: p,
            yuan: yuan,
            trigram: trigram,
            starName: starName,
            element: element,
            startYear: startY,
            endYear: endY,
            isCurrent: isCur,
            label: label
        )
    }

    /// The Xuan Kong period changes at Li Chun, rather than on January 1.
    private func effectiveSolarYear(for date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let year = calendar.component(.year, from: date)
        // Use the shared astronomical boundary, including the wrapped winter
        // solstice bucket that occurs in January before Li Chun.
        let beforeLiChun = SolarTimeCalculator.shared.isBeforeLiChun(for: date)
        return beforeLiChun ? year - 1 : year
    }
    
    // 九宫罗书飞布轨迹顺飞步进 (中5 -> 乾6 -> 兑7 -> 艮8 -> 离9 -> 坎1 -> 坤2 -> 震3 -> 巽4)
    private let luoShuOrder = [4, 5, 6, 7, 8, 0, 1, 2, 3]
    
    // 八卦宫位对应的洛书基础数字
    // 坎1, 坤2, 震3, 巽4, 中5, 乾6, 兑7, 艮8, 离9
    private let palaceNames = ["坎一宫 (正北)", "坤二宫 (西南)", "震三宫 (正东)", "巽四宫 (东南)", "天心五 (中宫)", "乾六宫 (西北)", "兑七宫 (正西)", "艮八宫 (东北)", "离九宫 (正南)"]
    private let palaceTrigrams = ["坎", "坤", "震", "巽", "中", "乾", "兑", "艮", "离"]
    private let palaceDirections = ["正北", "西南", "正东", "东南", "中宫", "西北", "正西", "东北", "正南"]
    
    /// 24山正统替卦口诀映射表 (沈氏玄空替卦诀)：
    /// 子癸并甲申，贪狼一路行 (1)；壬卯乙未坤，五位为巨门 (2)；
    /// 乾戌辰巽巳亥，尽是武曲位 (6)；艮丙酉辛丑，全归破军位 (7)；
    /// 寅午庚丁上，右弼九星迎 (9)。
    private static let tiGuaStarMap: [String: Int] = [
        "子": 1, "癸": 1, "甲": 1, "申": 1,
        "壬": 2, "卯": 2, "乙": 2, "未": 2, "坤": 2,
        "乾": 6, "戌": 6, "辰": 6, "巽": 6, "巳": 6, "亥": 6,
        "艮": 7, "丙": 7, "酉": 7, "辛": 7, "丑": 7,
        "寅": 9, "午": 9, "庚": 9, "丁": 9
    ]

    /// 计算入中之星与顺逆飞性（支持正向下卦与兼向替卦）：
    /// - 下卦：运星直接入中，依坐向山元龙查运星本宫同元龙之山阴阳定顺逆。
    /// - 替卦：查运星本宫同元龙之山，依替卦口诀取替星入中；顺逆仍以原所对应之山阴阳判定。
    private func resolveStarAndPolarity(
        periodStarInPalace: Int,
        baseMountain: Mountain24Item,
        useTiGua: Bool
    ) -> (starInCentral: Int, isForward: Bool) {
        if periodStarInPalace == 5 {
            // 五黄到宫：无替，随坐向本山之元龙阴阳顺逆
            let subStar = useTiGua ? (Self.tiGuaStarMap[baseMountain.name] ?? 5) : 5
            return (subStar, baseMountain.polarity > 0)
        }
        
        let palaceNameByStar: [Int: String] = [
            1: "坎", 2: "坤", 3: "震", 4: "巽",
            6: "乾", 7: "兑", 8: "艮", 9: "离"
        ]
        guard let homePalace = palaceNameByStar[periodStarInPalace] else {
            return (periodStarInPalace, baseMountain.polarity > 0)
        }
        let homeMountains = Mountain24Data.shared.mountains.filter { $0.palace == homePalace }
        guard let matched = homeMountains.first(where: { $0.yuan == baseMountain.yuan }) else {
            return (periodStarInPalace, baseMountain.polarity > 0)
        }
        
        let star = useTiGua ? (Self.tiGuaStarMap[matched.name] ?? periodStarInPalace) : periodStarInPalace
        let isForward = matched.polarity > 0
        return (star, isForward)
    }

    public func calculateChart(
        period: Int? = nil,
        sitting: Mountain24Item,
        facing: Mountain24Item,
        useTiGua: Bool = false,
        date: Date = Date()
    ) -> XuanKongChart {
        let activePeriod = period ?? currentPeriod(for: date)
        let meta = periodMeta(period: activePeriod, for: date)
        let lang = LocalizationManager.shared.effectiveLanguage
        
        // 1. 排运盘：将当运数字入中顺飞九宫
        var basePeriod = [Int](repeating: 0, count: 9)
        basePeriod[4] = activePeriod
        for step in 1...8 {
            let nextPalace = luoShuOrder[step]
            var star = (activePeriod + step) % 9
            if star == 0 { star = 9 }
            basePeriod[nextPalace] = star
        }
        
        // 2. 查坐山与向山所在宫位的运盘星，定山星与向星入中 (支持正向下卦与兼向替卦)
        let sittingPalaceIdx = palaceIndex(for: sitting.palace)
        let facingPalaceIdx = palaceIndex(for: facing.palace)
        
        let sittingPeriodStar = basePeriod[sittingPalaceIdx]
        let facingPeriodStar = basePeriod[facingPalaceIdx]
        
        // 3. 计算山向星入中数字与顺逆飞性 (下卦正针 vs 兼向替卦)
        let sittingResult = resolveStarAndPolarity(periodStarInPalace: sittingPeriodStar, baseMountain: sitting, useTiGua: useTiGua)
        let facingResult = resolveStarAndPolarity(periodStarInPalace: facingPeriodStar, baseMountain: facing, useTiGua: useTiGua)
        let sittingInCentral = sittingResult.starInCentral
        let sittingIsForward = sittingResult.isForward
        let facingInCentral = facingResult.starInCentral
        let facingIsForward = facingResult.isForward
        
        var mountainStars = [Int](repeating: 0, count: 9)
        var facingStars = [Int](repeating: 0, count: 9)
        
        mountainStars[4] = sittingInCentral
        facingStars[4] = facingInCentral
        
        for step in 1...8 {
            let pIdx = luoShuOrder[step]
            // 山星飞布
            var mStar = sittingIsForward ? (sittingInCentral + step) % 9 : (sittingInCentral - step + 9) % 9
            if mStar <= 0 { mStar += 9 }
            mountainStars[pIdx] = mStar
            
            // 向星飞布
            var fStar = facingIsForward ? (facingInCentral + step) % 9 : (facingInCentral - step + 9) % 9
            if fStar <= 0 { fStar += 9 }
            facingStars[pIdx] = fStar
        }
        
        // 4. 判定四大经典格局 (根据当运星分布，完全动态推导)
        let sittingFacingIdx = facingPalaceIdx
        let sittingMountIdx = sittingPalaceIdx
        
        let facingStarAtFacing = facingStars[sittingFacingIdx]
        let mountainStarAtMount = mountainStars[sittingMountIdx]
        let mountainStarAtFacing = mountainStars[sittingFacingIdx]
        let facingStarAtMount = facingStars[sittingMountIdx]
        
        let patternKind: XuanKongPattern
        if facingStarAtFacing == activePeriod && mountainStarAtMount == activePeriod {
            patternKind = .balancedFrontBack
        } else if facingStarAtFacing == activePeriod && mountainStarAtFacing == activePeriod {
            patternKind = .bothAtFacing
        } else if facingStarAtMount == activePeriod && mountainStarAtMount == activePeriod {
            patternKind = .bothAtSitting
        } else if facingStarAtMount == activePeriod && mountainStarAtFacing == activePeriod {
            patternKind = .reversed
        } else {
            patternKind = .distributed
        }
        let pattern: String
        switch lang {
        case .en:
            pattern = ["Wang Shan Wang Xiang (Supreme Wealth & Health)", "Double Stars at Facing (Auspicious Wealth)", "Double Stars at Sitting (Auspicious Health)", "Shang Shan Xia Shui (Reverse Chart)", "Balanced Harmony Chart"][patternKind.rawValue]
        case .zhHant:
            pattern = ["到山到向 (旺丁旺財最吉)", "雙星到向 (旺財不旺丁 · 宜向前有水後有山)", "雙星到坐 (旺丁不旺財 · 宜向後有水水後有山)", "上山下水 (敗財損丁凶局 · 需借勢顛倒用法)", "吉凶平和局"][patternKind.rawValue]
        case .ja:
            pattern = ["到山到向 (旺丁旺財の大吉)", "双星到向 (旺財不旺丁 · 前方に水、後方に山が吉)", "双星到坐 (旺丁不旺財 · 後方に水、その奥に山が吉)", "上山下水 (敗財損丁の凶局 · 顛倒勢の借用が必要)", "吉凶相半の平和局"][patternKind.rawValue]
        case .ko:
            pattern = ["도산도향 (왕정왕재 대길)", "쌍성도향 (재물 번창 · 앞에 물 뒤에 산이 길함)", "쌍성도좌 (자손 번창 · 뒤에 물과 산이 길함)", "동산하수 (손재패가 흉국 · 전도법 응용 필요)", "길흉 평화국"][patternKind.rawValue]
        case .vi:
            pattern = ["Đáo Sơn Đáo Hướng (Vượng đinh vượng tài đại cát)", "Song Tinh Đáo Hướng (Vượng tài · Trước có nước sau có núi)", "Song Tinh Đáo Tọa (Vượng đinh · Sau có nước sau nước có núi)", "Thượng Sơn Hạ Thủy (Bại tài tổn đinh hung cục · Cần phép điên đảo)", "Cát hung bình hòa cục"][patternKind.rawValue]
        case .th:
            pattern = ["ถึงเขาถึงทิศ (เจริญทั้งคนและทรัพย์ มงคลยิ่ง)", "สองดาวสู่ทิศหน้า (รุ่งเรืองทรัพย์สิน · หน้าควรมีน้ำหลังมีเขา)", "สองดาวสู่หลังพิง (ลูกหลานรุ่งเรือง · หลังควรมีน้ำและมีเขา)", "ขึ้นเขาลงน้ำ (สูญเสียทรัพย์และคน เคราะห์ร้าย · ต้องกลับทิศแก้เคล็ด)", "สมดุลปานกลาง"][patternKind.rawValue]
        case .id:
            pattern = ["Wang Shan Wang Xiang (Makmur Keluarga & Harta)", "Bintang Kembar di Hadap (Kaya Harta · Air di Depan, Gunung di Belakang)", "Bintang Kembar di Duduk (Banyak Keturunan · Air & Gunung di Belakang)", "Shang Shan Xia Shui (Peta Terbalik · Rawan Kerugian Harta & Fisik)", "Peta Harmonis Seimbang"][patternKind.rawValue]
        case .auto, .zhHans:
            pattern = ["到山到向 (旺丁旺财最吉)", "双星到向 (旺财不旺丁 · 宜向前有水后有山)", "双星到坐 (旺丁不旺财 · 宜向后有水水后有山)", "上山下水 (败财损丁凶局 · 需借势颠倒用法)", "吉凶平和局"][patternKind.rawValue]
        }
        
        // 5. 组合九宫格模型
        var cells: [PalaceCell] = []
        for i in 0..<9 {
            let isWangM = mountainStars[i] == activePeriod
            let isWangF = facingStars[i] == activePeriod
            let isWuHuang = mountainStars[i] == 5 || facingStars[i] == 5
            let isErHei = mountainStars[i] == 2 || facingStars[i] == 2
            
            let cell = PalaceCell(
                id: i,
                palaceName: palaceNames[i],
                trigram: palaceTrigrams[i],
                direction: palaceDirections[i],
                periodStar: basePeriod[i],
                activePeriod: activePeriod,
                mountainStar: mountainStars[i],
                facingStar: facingStars[i],
                isCenter: i == 4,
                isWangMountain: isWangM,
                isWangFacing: isWangF,
                isShaWuHuang: isWuHuang,
                isShaErHei: isErHei
            )
            cells.append(cell)
        }
        
        // 6. 综合格局说明。仅描述计算出的盘面，不对现实结果作承诺。
        let summary: String
        let sittingName = sitting.localizedName
        let facingName = facing.localizedName
        let sourceNote = flyingStarsTraditionalSourceNote(for: lang)
        switch lang {
        case .en:
            summary = "\(meta.label). Sitting \(sittingName) Facing \(facingName) presents [\(pattern)]. Cultivate auspicious Qi at the facing palace, solidify sitting mountain for harmony."
        case .zhHant:
            summary = "\(meta.isCurrent ? "當前正值" : "玄空排盤：")\(meta.yuan)\(activePeriod)運（\(meta.startYear)—\(meta.endYear)年，\(meta.starName)\(meta.element)星當令）。\(sittingName)山\(facingName)向在此元運呈現【\(pattern)】。宜重點佈局向首明堂引納\(meta.element)氣，坐後穩實以固人丁。"
        case .ja:
            summary = "\(meta.isCurrent ? "現在は" : "玄空飛星：")\(meta.yuan)\(activePeriod)運（\(meta.startYear)—\(meta.endYear)年、\(meta.starName)\(meta.element)星当令）。\(sittingName)山\(facingName)向はこの元運で【\(pattern)】となります。向首明堂に吉気を引込み、坐後を堅固にして子孫健康を守ると吉。"
        case .ko:
            summary = "\(meta.isCurrent ? "현재는 " : "현공 비성: ")\(meta.yuan) \(activePeriod)운 (\(meta.startYear)—\(meta.endYear)년, \(meta.starName) \(meta.element)성 당령). \(sittingName)산 \(facingName)향은 이 원운에서 【\(pattern)】을 이룹니다. 향수 명당에 기운을 받아들이고 좌산을 든든히 하여 인정을 보존함이 길합니다."
        case .vi:
            summary = "\(meta.isCurrent ? "Hiện tại chính là " : "Huyền Không bài bàn: ")\(meta.yuan) Vận \(activePeriod) (\(meta.startYear)—\(meta.endYear), \(meta.starName) \(meta.element) tinh đương lệnh). \(sittingName) sơn \(facingName) hướng trong nguyên vận này biểu hiện 【\(pattern)】. Nên bố trí minh đường nạp khí, tọa sơn vững chãi vượng nhân đinh."
        case .th:
            summary = "\(meta.isCurrent ? "ปัจจุบันเข้าสู่ " : "ผังเหวินคง: ")\(meta.yuan) ยุค \(activePeriod) (\(meta.startYear)—\(meta.endYear), ดาว\(meta.starName) ธาตุ\(meta.element)). \(sittingName)พิง \(facingName)หัน ในยุคนี้ปรากฏเป็น 【\(pattern)】 ควรจัดหมุนเวียนพลังงานด้านหน้า และรักษาความมั่นคงด้านหลังเพื่อเสริมสิริมงคล"
        case .id:
            summary = "\(meta.isCurrent ? "Saat ini berada pada " : "Bagan Xuan Kong: ")\(meta.yuan) Periode \(activePeriod) (\(meta.startYear)—\(meta.endYear), Bintang \(meta.starName) Unsur \(meta.element)). Posisi Duduk \(sittingName) Hadap \(facingName) membentuk [\(pattern)]. Atur tata ruang hadap untuk menyerap energi positif dan perkuat posisi duduk demi ketentraman keluarga."
        case .auto, .zhHans:
            summary = "\(meta.isCurrent ? "当前正值" : "玄空排盘：")\(meta.yuan)\(activePeriod)运（\(meta.startYear)—\(meta.endYear)年，\(meta.starName)\(meta.element)星当令）。\(sittingName)山\(facingName)向在此元运呈现【\(pattern)】。宜重点布局向首明堂引纳\(meta.element)气，坐后稳实以固人丁。"
        }
        
        let modeTitle = useTiGua
            ? LocalizationManager.shared.t("chart_mode_tigua")
            : LocalizationManager.shared.t("chart_mode_xiagua")

        return XuanKongChart(
            period: activePeriod,
            sittingMountain: sittingName,
            facingMountain: facingName,
            patternType: pattern,
            pattern: patternKind,
            sittingPalaceID: sittingPalaceIdx,
            facingPalaceID: facingPalaceIdx,
            isSanBanGua: Self.checkSanBanGua(cells: cells),
            isQiXingDaJie: Self.checkQiXingDaJie(cells: cells, activePeriod: activePeriod, facingPalaceIdx: sittingFacingIdx),
            isTiGua: useTiGua,
            chartModeTitle: modeTitle,
            palaces: cells,
            summaryAnalysis: summary + "\n\n" + sourceNote,
            patternDesc: summary,
            periodMeta: meta
        )
    }
    
    private func palaceIndex(for palaceName: String) -> Int {
        switch palaceName {
        case "坎": return 0
        case "坤": return 1
        case "震": return 2
        case "巽": return 3
        case "乾": return 5
        case "兑": return 6
        case "艮": return 7
        case "离": return 8
        default: return 4
        }
    }
    
    /// 判定是否为父母三般卦（各宫运、山、向星均属 147 / 258 / 369）或连珠三般卦
    private static func checkSanBanGua(cells: [PalaceCell]) -> Bool {
        let fumuSets: [Set<Int>] = [Set([1, 4, 7]), Set([2, 5, 8]), Set([3, 6, 9])]
        let lianzhuSets: [Set<Int>] = [
            Set([1, 2, 3]), Set([2, 3, 4]), Set([3, 4, 5]),
            Set([4, 5, 6]), Set([5, 6, 7]), Set([6, 7, 8]),
            Set([7, 8, 9]), Set([8, 9, 1]), Set([9, 1, 2])
        ]
        let allFumu = cells.allSatisfy { c in
            let s = Set([c.periodStar, c.mountainStar, c.facingStar])
            return fumuSets.contains(s)
        }
        if allFumu { return true }
        return cells.allSatisfy { c in
            let s = Set([c.periodStar, c.mountainStar, c.facingStar])
            return lianzhuSets.contains(s)
        }
    }
    
    /// 判定是否构成七星打劫局（离震乾或坎兑巽三宫向星合成 147 / 258 / 369 且当旺向星到向）
    private static func checkQiXingDaJie(cells: [PalaceCell], activePeriod: Int, facingPalaceIdx: Int) -> Bool {
        guard cells.count == 9, cells[facingPalaceIdx].facingStar == activePeriod else { return false }
        let fumuSets: [Set<Int>] = [Set([1, 4, 7]), Set([2, 5, 8]), Set([3, 6, 9])]
        let zhenQiSet = Set([cells[8].facingStar, cells[2].facingStar, cells[5].facingStar]) // 离9、震3、乾6
        let jiaQiSet = Set([cells[0].facingStar, cells[6].facingStar, cells[3].facingStar])  // 坎1、兑7、巽4
        return fumuSets.contains(zhenQiSet) || fumuSets.contains(jiaQiSet)
    }
}
