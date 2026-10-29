import Foundation

// MARK: - 三式绝学 · 时家奇门遁甲全息排盘与出行导航引擎 (PRD 第11章)

public struct QimenDoor {
    public let name: String
    public let palace: Int
    public let isAuspicious: Bool
    public let luckType: String // "吉", "大吉", "平", "凶", "大凶"
    public let lore: String
    
    public init(name: String, palace: Int, isAuspicious: Bool, luckType: String, lore: String) {
        self.name = name
        self.palace = palace
        self.isAuspicious = isAuspicious
        self.luckType = luckType
        self.lore = lore
    }

    public var localizedName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            return ["休门": "Rest Gate", "生门": "Life Gate", "伤门": "Harm Gate", "杜门": "Block Gate", "景门": "View Gate", "死门": "Death Gate", "惊门": "Shock Gate", "开门": "Open Gate"][name] ?? name
        case .zhHant, .ja:
            return ["休门": "休門", "生门": "生門", "伤门": "傷門", "杜门": "杜門", "景门": "景門", "死门": "死門", "惊门": "驚門", "开门": "開門"][name] ?? name
        case .ko:
            return ["休门": "휴문", "生门": "생문", "伤门": "상문", "杜门": "두문", "景门": "경문", "死门": "사문", "惊门": "경문(驚)", "开门": "개문"][name] ?? name
        case .vi:
            return ["休门": "Hưu Môn", "生门": "Sinh Môn", "伤门": "Thương Môn", "杜门": "Đỗ Môn", "景门": "Cảnh Môn", "死门": "Tử Môn", "惊门": "Kinh Môn", "开门": "Khai Môn"][name] ?? name
        case .th:
            return ["休门": "ประตูพัก", "生门": "ประตูเกิด", "伤门": "ประตูเจ็บ", "杜门": "ประตูซ่อน", "景门": "ประตูวิว", "死门": "ประตูตาย", "惊门": "ประตูตกใจ", "开门": "ประตูเปิด"][name] ?? name
        case .id:
            return ["休门": "Gerbang Istirahat", "生门": "Gerbang Kehidupan", "伤门": "Gerbang Luka", "杜门": "Gerbang Rintangan", "景门": "Gerbang Pemandangan", "死门": "Gerbang Kematian", "惊门": "Gerbang Terkejut", "开门": "Gerbang Pembuka"][name] ?? name
        case .zhHans:
            return name
        }
    }

    public var localizedLuckType: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return ["大吉": "Great Luck", "吉": "Auspicious", "凶": "Inauspicious", "大凶": "Major Taboo", "平": "Neutral"][luckType] ?? luckType
        case .zhHant:
            return ["大吉": "大吉", "吉": "吉", "凶": "凶", "大凶": "大凶", "平": "平"][luckType] ?? luckType
        case .ja:
            return ["大吉": "大吉", "吉": "吉", "凶": "凶", "大凶": "大凶", "平": "平"][luckType] ?? luckType
        case .ko:
            return ["大吉": "대길", "吉": "길", "凶": "흉", "大凶": "대흉", "平": "평"][luckType] ?? luckType
        case .vi:
            return ["大吉": "Đại Cát", "吉": "Cát", "凶": "Hung", "大凶": "Đại Hung", "平": "Bình"][luckType] ?? luckType
        case .th:
            return ["大吉": "มงคลยิ่ง", "吉": "มงคล", "凶": "อัปมงคล", "大凶": "อัปมงคลยิ่ง", "平": "ปานกลาง"][luckType] ?? luckType
        case .id:
            return ["大吉": "Sangat Baik", "吉": "Baik", "凶": "Buruk", "大凶": "Sangat Buruk", "平": "Netral"][luckType] ?? luckType
        case .zhHans:
            return luckType
        }
    }

    public var localizedLore: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return [
                "休门": "Favorable for rest, study and quiet pursuits.", "生门": "Excellent for wealth, property and growth.",
                "伤门": "Useful for pursuit, but guard against travel injuries.", "杜门": "Hide and consolidate; keep doors closed.",
                "景门": "Good for documents and examinations; avoid haste.", "死门": "Suitable for mourning rites; avoid travel and construction.",
                "惊门": "Disputes and alarm are possible; useful for catching thieves.", "开门": "Excellent for business, opening and movement."
            ][name] ?? lore
        case .zhHant:
            return [
                "休门": "求名休閒大吉，水清木秀", "生门": "求財置業大吉，土旺金生",
                "伤门": "討債索敵宜，出行防傷災", "杜门": "潛伏隱匿避災，閉藏門戶",
                "景门": "文書考試宴請吉，火炎防急", "死门": "吊喪刑戮宜，出行造葬大凶",
                "惊门": "官非驚恐口舌，捕盜宜", "开门": "經商開業動身，百事通亨"
            ][name] ?? lore
        case .ja:
            return [
                "休门": "休息や学問、名声の獲得に大吉", "生门": "求財や不動産取得に大吉、発展を促す",
                "伤门": "債権回収や討伐に適するが怪我に注意", "杜门": "隠匿や難逃れに適し、戸を閉ざす",
                "景门": "文書作成や試験に吉、焦りは禁物", "死门": "葬儀弔問にのみ適し、出行動土は大凶",
                "惊门": "口論や驚愕を招きやすく盗賊捕縛に吉", "开门": "開業や出発商談に万事通亨の大吉"
            ][name] ?? lore
        case .ko:
            return [
                "休门": "휴식과 명예, 학문에 대길합니다", "生门": "재물 축적과 부동산에 대길합니다",
                "伤门": "추적과 채권 회수에는 좋으나 부상에 주의", "杜门": "은닉과 액막이에 적합하며 문을 닫음",
                "景门": "문서와 시험에 길하며 성급함을 피함", "死门": "조문과 형벌에만 적합, 여행과 토목은 대흉",
                "惊门": "구설수와 놀람을 주의, 도적 체포에 길함", "开门": "개업과 출발, 사업 등 모든 일에 통달대길"
            ][name] ?? lore
        case .vi:
            return [
                "休门": "Cầu danh nghỉ ngơi đại cát, thủy thanh mộc tú", "生门": "Cầu tài mua nhà đất đại cát, sinh sôi phát triển",
                "伤门": "Đòi nợ truy bắt hợp, xuất hành phòng tổn thương", "杜门": "Ẩn nấp lánh nạn, đóng chặt cửa nẻo",
                "景门": "Văn thư thi cử tiệc tùng cát, tránh nóng vội", "死门": "Hợp tang lễ, xuất hành an táng đại hung",
                "惊门": "Dễ gặp thị phi kinh hãi, hợp truy bắt đạo tặc", "开门": "Kinh doanh khai trương xuất hành, trăm sự hanh thông"
            ][name] ?? lore
        case .th:
            return [
                "休门": "เหมาะแก่การพักผ่อน ศึกษาหาความรู้ มงคลยิ่ง", "生门": "ดีที่สุดสำหรับการค้า ซื้ออสังหาฯ และสร้างความมั่งคั่ง",
                "伤门": "เหมาะแก่การทวงหนี้ ติดตาม แต่ระวังบาดเจ็บ", "杜门": "เก็บตัว ซ่อนเร้น หลบภัย ปิดประตูมิดชิด",
                "景门": "ดีต่อการสอบ เอกสารสัญญา หลีกเลี่ยงความใจร้อน", "死门": "เหมาะเฉพาะพิธีศพ ห้ามเดินทางและก่อสร้าง อัปมงคลยิ่ง",
                "惊门": "ระวังข้อพิพาทตกใจ เหมาะแก่การจับขโมย", "开门": "เปิดกิจการ ค้าขาย ออกเดินทาง ราบรื่นทุกประการ"
            ][name] ?? lore
        case .id:
            return [
                "休门": "Sangat baik untuk istirahat, studi, dan ketenangan", "生门": "Sangat baik untuk rezeki, properti, dan pertumbuhan usaha",
                "伤门": "Cocok menagih hak, namun waspadai cedera perjalanan", "杜门": "Menyembunyikan diri dan konsolidasi; tutup pintu rapat",
                "景门": "Baik untuk urusan dokumen & ujian; hindari tergesa-gesa", "死门": "Hanya cocok upacara duka; hindari bepergian/konstruksi",
                "惊门": "Waspadai perselisihan; cocok untuk menangkap pencuri", "开门": "Sangat baik untuk pembukaan bisnis, relokasi & sukses lancar"
            ][name] ?? lore
        case .zhHans:
            return lore
        }
    }
}

public struct QimenPalaceCell: Identifiable {
    public var id: Int { palaceId }
    public let palaceId: Int        // 洛书宫号 1..9
    public let palaceName: String    // 如 "东南 巽"
    public let trigram: String       // 八卦名
    public let doorName: String      // 八门: 休/生/伤/杜/景/死/惊/开
    public let doorLuck: String      // "吉" / "大吉" / "平" / "凶" / "大凶"
    public let starName: String      // 九星: 天蓬/天芮/天冲/天辅/天禽/天心/天柱/天任/天英
    public let godName: String       // 八神: 值符/螣蛇/太阴/六合/白虎/玄武/九地/九天
    public let tianStem: String      // 天盘天干 (三奇六仪)
    public let diStem: String        // 地盘天干
    public let isTaiJiCenter: Bool
    public let isDoorAuspicious: Bool
    public var isDoorInauspicious: Bool { doorLuck.contains("凶") }

    public var localizedDoorName: String {
        QimenDoor(name: doorName, palace: palaceId, isAuspicious: isDoorAuspicious, luckType: doorLuck, lore: "").localizedName
    }
    public var localizedStarName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            return ["天蓬": "Tian Peng", "天芮": "Tian Rui", "天冲": "Tian Chong", "天辅": "Tian Fu", "天禽": "Tian Qin", "天心": "Tian Xin", "天柱": "Tian Zhu", "天任": "Tian Ren", "天英": "Tian Ying"][starName] ?? starName
        case .zhHant, .ja:
            return starName.replacingOccurrences(of: "冲", with: "沖").replacingOccurrences(of: "辅", with: "輔")
        case .ko:
            return ["天蓬": "천봉", "天芮": "천예", "天冲": "천충", "天辅": "천보", "天禽": "천금", "天心": "천심", "天柱": "천주", "天任": "천임", "天英": "천영"][starName] ?? starName
        case .vi:
            return ["天蓬": "Thiên Bồng", "天芮": "Thiên Nhuế", "天冲": "Thiên Xung", "天辅": "Thiên Phụ", "天禽": "Thiên Cầm", "天心": "Thiên Tâm", "天柱": "Thiên Trụ", "天任": "Thiên Nhậm", "天英": "Thiên Anh"][starName] ?? starName
        case .th:
            return ["天蓬": "เทียนเผิง", "天芮": "เทียนรุ่ย", "天冲": "เทียนชง", "天辅": "เทียนฝู่", "天禽": "เทียนฉิน", "天心": "เทียนซิน", "天柱": "เทียนจู้", "天任": "เทียนเยิ่น", "天英": "เทียนอิง"][starName] ?? starName
        case .id:
            return ["天蓬": "Tian Peng", "天芮": "Tian Rui", "天冲": "Tian Chong", "天辅": "Tian Fu", "天禽": "Tian Qin", "天心": "Tian Xin", "天柱": "Tian Zhu", "天任": "Tian Ren", "天英": "Tian Ying"][starName] ?? starName
        case .zhHans:
            return starName
        }
    }
    public var localizedGodName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            return ["值符": "Chief Deity", "螣蛇": "Snake", "太阴": "Great Yin", "六合": "Six Harmony", "白虎": "White Tiger", "玄武": "Black Tortoise", "九地": "Nine Earth", "九天": "Nine Heaven", "元极": "Center Pole"][godName] ?? godName
        case .zhHant:
            return godName.replacingOccurrences(of: "阴", with: "陰").replacingOccurrences(of: "极", with: "極")
        case .ja:
            return ["值符": "直符", "螣蛇": "騰蛇", "太阴": "太陰", "六合": "六合", "白虎": "白虎", "玄武": "玄武", "九地": "九地", "九天": "九天", "元极": "太極"][godName] ?? godName
        case .ko:
            return ["值符": "직부", "螣蛇": "등사", "太阴": "태음", "六合": "육합", "白虎": "백호", "玄武": "현무", "九地": "구지", "九天": "구천", "元极": "원극"][godName] ?? godName
        case .vi:
            return ["值符": "Trực Phù", "螣蛇": "Đằng Xà", "太阴": "Thái Âm", "六合": "Lục Hợp", "白虎": "Bạch Hổ", "玄武": "Huyền Vũ", "九地": "Cửu Địa", "九天": "Cửu Thiên", "元极": "Nguyên Cực"][godName] ?? godName
        case .th:
            return ["值符": "จื่อฝู", "螣蛇": "เถิงเสือ", "太阴": "ไท่อิน", "六合": "ลิ่วเหอ", "白虎": "ไป๋หู่", "玄武": "เสวียนอู่", "九地": "จิ่วตี้", "九天": "จิ่วเทียน", "元极": "ไท่จี๋"][godName] ?? godName
        case .id:
            return ["值符": "Panglima", "螣蛇": "Ular Api", "太阴": "Yin Sejati", "六合": "Enam Harmoni", "白虎": "Harimau Putih", "玄武": "Kura-kura Hitam", "九地": "Sembilan Bumi", "九天": "Sembilan Langit", "元极": "Titik Pusat"][godName] ?? godName
        case .zhHans:
            return godName
        }
    }
    public var localizedPalaceName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        let hantMap = ["东南": "東南", "正南": "正南", "西南": "西南", "正东": "正東", "中宫": "中宮", "正西": "正西", "东北": "東北", "正北": "正北", "西北": "西北"]
        let trigramEnMap = ["巽": "Xun", "离": "Li", "坤": "Kun", "震": "Zhen", "兑": "Dui", "艮": "Gen", "坎": "Kan", "乾": "Qian", "太极": "Taiji"]
        let trigramHantMap = ["巽": "巽", "離": "離", "离": "離", "坤": "坤", "震": "震", "兌": "兌", "兑": "兌", "艮": "艮", "坎": "坎", "乾": "乾", "太極": "太極", "太极": "太極"]
        
        switch lang {
        case .zhHant:
            let parts = palaceName.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let trigram = trigramHantMap[parts[1]] ?? parts[1].replacingOccurrences(of: "宫", with: "宮")
                return "\(hantMap[parts[0]] ?? parts[0]) \(trigram)"
            }
            return hantMap[palaceName] ?? palaceName.replacingOccurrences(of: "宫", with: "宮")
        case .ja:
            let jaMap = ["东南": "南東", "正南": "正南", "西南": "南西", "正东": "正東", "中宫": "中宮", "正西": "正西", "东北": "北東", "正北": "正北", "西北": "北西"]
            let parts = palaceName.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let trigram = trigramHantMap[parts[1]] ?? parts[1]
                return "\(jaMap[parts[0]] ?? parts[0]) (\(trigram))"
            }
            return jaMap[palaceName] ?? palaceName
        case .ko:
            let koMap = ["东南": "동남", "正南": "정남", "西南": "남서", "正东": "정동", "中宫": "중궁", "正西": "정서", "东北": "북동", "正北": "정북", "西北": "북서"]
            let trigramKoMap = ["巽": "손", "离": "이", "坤": "곤", "震": "진", "兑": "태", "艮": "간", "坎": "감", "乾": "건", "太极": "태극"]
            let parts = palaceName.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                return "\(koMap[parts[0]] ?? parts[0]) (\(trigramKoMap[parts[1]] ?? parts[1]))"
            }
            return koMap[palaceName] ?? palaceName
        case .vi:
            let viMap = ["东南": "Đông Nam", "正南": "Chính Nam", "西南": "Tây Nam", "正东": "Chính Đông", "中宫": "Trung Cung", "正西": "Chính Tây", "东北": "Đông Bắc", "正北": "Chính Bắc", "西北": "Tây Bắc"]
            let trigramViMap = ["巽": "Tốn", "离": "Ly", "坤": "Khôn", "震": "Chấn", "兑": "Đoài", "艮": "Cấn", "坎": "Khảm", "乾": "Càn", "太极": "Thái Cực"]
            let parts = palaceName.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                return "\(viMap[parts[0]] ?? parts[0]) (\(trigramViMap[parts[1]] ?? parts[1]))"
            }
            return viMap[palaceName] ?? palaceName
        case .th:
            let thMap = ["东南": "ทิศตะวันออกเฉียงใต้", "正南": "ทิศใต้", "西南": "ทิศตะวันตกเฉียงใต้", "正东": "ทิศตะวันออก", "中宫": "จุดศูนย์กลาง", "正西": "ทิศตะวันตก", "东北": "ทิศตะวันออกเฉียงเหนือ", "正北": "ทิศเหนือ", "西北": "ทิศตะวันตกเฉียงเหนือ"]
            let trigramThMap = ["巽": "ซวิ่น", "离": "หลี", "坤": "คุน", "震": "เจิ้น", "兑": "ตุ้ย", "艮": "เกิ้น", "坎": "ข่าน", "乾": "เฉียน", "太极": "ไท่จี๋"]
            let parts = palaceName.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                return "\(thMap[parts[0]] ?? parts[0]) (\(trigramThMap[parts[1]] ?? parts[1]))"
            }
            return thMap[palaceName] ?? palaceName
        case .id:
            let idMap = ["东南": "Tenggara", "正南": "Selatan", "西南": "Barat Daya", "正东": "Timur", "中宫": "Pusat", "正西": "Barat", "东北": "Timur Laut", "正北": "Utara", "西北": "Barat Laut"]
            let parts = palaceName.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                return "\(idMap[parts[0]] ?? parts[0]) (\(trigramEnMap[parts[1]] ?? parts[1]))"
            }
            return idMap[palaceName] ?? palaceName
        case .en:
            let map = ["东南": "Southeast", "正南": "South", "西南": "Southwest", "正东": "East", "中宫": "Center", "正西": "West", "东北": "Northeast", "正北": "North", "西北": "Northwest"]
            let parts = palaceName.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2 { return "\(map[parts[0]] ?? parts[0]) (\(trigramEnMap[parts[1]] ?? parts[1]))" }
            return map[palaceName] ?? palaceName
        case .zhHans:
            return palaceName
        }
    }
}

public struct QimenChart {
    public let dunType: String               // "阳遁" / "阴遁"
    public let juNumber: Int                 // 1..9
    public let title: String                 // "阳遁一局 · 拆补上元"
    public let cells: [QimenPalaceCell]      // 9 宫数据 (洛书标准宫序: 4, 9, 2; 3, 5, 7; 8, 1, 6)
    public let bestNavDirection: String      // 最优动身出地方位
    public let bestNavReason: String         // 吉门吉神加会详情
    public let tabooDirections: String       // 避忌凶方
}

public class QimenEngine {
    public static let shared = QimenEngine()
    
    private let eightDoors: [QimenDoor] = [
        QimenDoor(name: "休门", palace: 1, isAuspicious: true, luckType: "吉", lore: "求名休闲大吉，水清木秀"),
        QimenDoor(name: "生门", palace: 8, isAuspicious: true, luckType: "大吉", lore: "求财置业大吉，土旺金生"),
        QimenDoor(name: "伤门", palace: 3, isAuspicious: false, luckType: "凶", lore: "讨债索敌宜，出行防伤灾"),
        QimenDoor(name: "杜门", palace: 4, isAuspicious: false, luckType: "平", lore: "潜伏隐匿避灾，闭藏门户"),
        QimenDoor(name: "景门", palace: 9, isAuspicious: false, luckType: "平", lore: "文书考试宴请吉，火炎防急"),
        QimenDoor(name: "死门", palace: 2, isAuspicious: false, luckType: "大凶", lore: "吊丧刑戮宜，出行造葬大凶"),
        QimenDoor(name: "惊门", palace: 7, isAuspicious: false, luckType: "凶", lore: "官非惊恐口舌，捕盗宜"),
        QimenDoor(name: "开门", palace: 6, isAuspicious: true, luckType: "大吉", lore: "经商开业动身，百事通亨")
    ]
    
    private let nineStars = ["天蓬", "天芮", "天冲", "天辅", "天禽", "天心", "天柱", "天任", "天英"]
    private let eightGods = ["值符", "螣蛇", "太阴", "六合", "白虎", "玄武", "九地", "九天"]
    private let sixYiStems = ["戊", "己", "庚", "辛", "壬", "癸", "丁", "丙", "乙"]
    
    // 洛书九宫展示顺序: 4(东南巽), 9(正南离), 2(西南坤), 3(正东震), 5(中宫), 7(正西兑), 8(东北艮), 1(正北坎), 6(西北乾)
    public let displayPalaceDefs: [(id: Int, name: String, trigram: String)] = [
        (4, "东南", "巽"),
        (9, "正南", "离"),
        (2, "西南", "坤"),
        (3, "正东", "震"),
        (5, "中宫", "太极"),
        (7, "正西", "兑"),
        (8, "东北", "艮"),
        (1, "正北", "坎"),
        (6, "西北", "乾")
    ]
    
    private init() {}
    
    public func calculateChart(date: Date = Date(), heading: Double = 0.0) -> QimenChart {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let solarTermIndex = SolarTimeCalculator.shared.solarTermIndex(for: date)
        
        // 1. 阴遁/阳遁按节气切换：夏至至大雪为阴遁，冬至至芒种为阳遁。
        // 使用太阳黄经而非固定公历日期，覆盖不同年份节气时刻的变化。
        let isYangDun = solarTermIndex < 11 || solarTermIndex >= 23
        let lang = LocalizationManager.shared.effectiveLanguage
        
        let dunType: String
        switch lang {
        case .en: dunType = isYangDun ? "Yang Dun" : "Yin Dun"
        case .zhHant: dunType = isYangDun ? "陽遁" : "陰遁"
        case .ja: dunType = isYangDun ? "陽遁" : "陰遁"
        case .ko: dunType = isYangDun ? "양둔" : "음둔"
        case .vi: dunType = isYangDun ? "Dương Độn" : "Âm Độn"
        case .th: dunType = isYangDun ? "หยางตุ้น" : "อินตุ้น"
        case .id: dunType = isYangDun ? "Yang Dun" : "Yin Dun"
        case .zhHans: dunType = isYangDun ? "阳遁" : "阴遁"
        }
        
        // 2. 拆补定局：按当前节气的前五日、中五日、后五日取上/中/下元。
        // Each row is [upper, middle, lower] for one solar term.  The term
        // index is 0=小寒 ... 22=大雪, 23=冬至.
        let progress = SolarTimeCalculator.shared.solarTermProgress(for: date)
        let yuanIndex = min(2, max(0, Int(progress / 5.0)))
        let yangBureaus: [Int: [Int]] = [
            23: [1, 7, 4], 0: [2, 8, 5], 1: [3, 9, 6],
            2: [8, 5, 2], 3: [9, 6, 3], 4: [1, 7, 4],
            5: [3, 9, 6], 6: [4, 1, 7], 7: [5, 2, 8],
            8: [4, 1, 7], 9: [5, 2, 8], 10: [6, 3, 9]
        ]
        let yinBureaus: [Int: [Int]] = [
            11: [9, 3, 6], 12: [8, 2, 5], 13: [7, 1, 4],
            14: [2, 5, 8], 15: [1, 4, 7], 16: [9, 3, 6],
            17: [7, 1, 4], 18: [6, 9, 3], 19: [5, 8, 2],
            20: [5, 8, 2], 21: [4, 7, 1], 22: [3, 6, 9]
        ]
        let bureauTable = isYangDun ? yangBureaus : yinBureaus
        let juNumber = bureauTable[solarTermIndex]?[yuanIndex] ?? 1
        let title: String
        let yuanName: String
        switch lang {
        case .en: yuanName = ["Upper Yuan", "Middle Yuan", "Lower Yuan"][yuanIndex]
        case .zhHant, .ja: yuanName = ["上元", "中元", "下元"][yuanIndex]
        case .ko: yuanName = ["상원", "중원", "하원"][yuanIndex]
        case .vi: yuanName = ["Thượng Nguyên", "Trung Nguyên", "Hạ Nguyên"][yuanIndex]
        case .th: yuanName = ["ง้วนบน", "ง้วนกลาง", "ง้วนล่าง"][yuanIndex]
        case .id: yuanName = ["Yuan Atas", "Yuan Tengah", "Yuan Bawah"][yuanIndex]
        case .zhHans: yuanName = ["上元", "中元", "下元"][yuanIndex]
        }
        
        switch lang {
        case .en: title = "【\(dunType) Bureau \(juNumber) · \(yuanName)】"
        case .zhHant: title = "【\(dunType)\(juNumber)局 · 拆補\(yuanName)】"
        case .ja: title = "【\(dunType)\(juNumber)局 · 拆補\(yuanName)】"
        case .ko: title = "【\(dunType) \(juNumber)국 · \(yuanName)】"
        case .vi: title = "【\(dunType) Cục \(juNumber) · \(yuanName)】"
        case .th: title = "【\(dunType) สำนัก \(juNumber) · \(yuanName)】"
        case .id: title = "【\(dunType) Pola \(juNumber) · \(yuanName)】"
        case .zhHans: title = "【\(dunType)\(juNumber)局 · 拆补\(yuanName)】"
        }
        
        // 3. 计算八门排布偏移 (结合局数与时支)。
        // `hour / 2` 会把 23:00 算成序号 11，并在每个偶数小时边界
        // 错开一支；奇门按子时 23:00 起，应使用标准十二时辰索引。
        let hourBranch = ((hour + 1) / 2) % 12
        let shift = (juNumber + hourBranch) % 8
        
        var cells: [QimenPalaceCell] = []
        var nonCenterIndex = 0
        var bestDirection: String
        var bestReason: String
        // Keep the absolute bearing of the selected gate so the caller can
        // turn the current device heading into actionable left/right guidance.
        // `heading` is a clockwise magnetic/true bearing in degrees.
        var bestBearing: Double? = nil
        switch lang {
        case .en:
            bestDirection = "Northwest (Qian - Open Gate)"
            bestReason = "Auspicious Open Gate with Chief Deity"
        case .zhHant:
            bestDirection = "西北方 (乾宮開門)"
            bestReason = "開門乘吉神值符，天地德合"
        case .ja:
            bestDirection = "北西方 (乾宮 開門)"
            bestReason = "開門に直符神が臨み、万事亨通"
        case .ko:
            bestDirection = "북서방 (건궁 개문)"
            bestReason = "개문에 직부신이 임하여 천지덕합"
        case .vi:
            bestDirection = "Tây Bắc (Càn Cung Khai Môn)"
            bestReason = "Khai Môn thừa cát thần Trực Phù, thiên địa đức hợp"
        case .th:
            bestDirection = "ทิศตะวันตกเฉียงเหนือ (เฉียน - ประตูเปิด)"
            bestReason = "ประตูเปิดสถิตร่วมเทพจื่อฝู ราบรื่นมงคลยิ่ง"
        case .id:
            bestDirection = "Barat Laut (Qian - Gerbang Pembuka)"
            bestReason = "Gerbang Pembuka dinaungi Panglima Agung"
        case .zhHans:
            bestDirection = "西北方 (乾宫开门)"
            bestReason = "开门乘吉神值符，天地德合"
        }
        var bestScore = -1
        var tabooDirs: [String] = []
        
        for p in displayPalaceDefs {
            if p.id == 5 {
                let centerName: String
                let centerTrigram: String
                switch lang {
                case .en: centerName = "Center"; centerTrigram = "TaiJi"
                case .zhHant, .ja: centerName = "中宮"; centerTrigram = "太極"
                case .ko: centerName = "중궁"; centerTrigram = "태극"
                case .vi: centerName = "Trung Cung"; centerTrigram = "Thái Cực"
                case .th: centerName = "จุดศูนย์กลาง"; centerTrigram = "ไท่จี๋"
                case .id: centerName = "Pusat"; centerTrigram = "Taiji"
                case .zhHans: centerName = "中宫"; centerTrigram = "太极"
                }
                cells.append(QimenPalaceCell(
                    palaceId: 5,
                    palaceName: centerName,
                    trigram: centerTrigram,
                    doorName: centerName,
                    doorLuck: lang == .en ? "Fair" : (lang == .zhHans ? "平" : "平"),
                    starName: lang == .en ? "TianQin" : (lang == .ko ? "천금성" : (lang == .vi ? "Thiên Cầm" : "天禽星")),
                    godName: lang == .en ? "Center" : (lang == .ko ? "원극" : (lang == .vi ? "Nguyên Cực" : "元极")),
                    tianStem: "戊",
                    diStem: "戊",
                    isTaiJiCenter: true,
                    // The center palace has no door. Mark it neutral so the
                    // grid does not render the placeholder as an auspicious
                    // travel gate.
                    isDoorAuspicious: false
                ))
            } else {
                // `displayPalaceDefs` includes the center at index 4.  Using
                // the raw grid index here skips door 5 and repeats door 1;
                // keep a separate eight-palace counter so every door appears
                // exactly once.
                let doorIdx = (nonCenterIndex + shift) % 8
                let door = eightDoors[doorIdx]
                let star = nineStars[(nonCenterIndex + juNumber) % 9]
                let god = eightGods[(nonCenterIndex + shift) % 8]
                let tianStem = sixYiStems[(nonCenterIndex + juNumber) % 9]
                let diStem = sixYiStems[(nonCenterIndex + 3) % 9]
                
                let cellProbe = QimenPalaceCell(
                    palaceId: p.id, palaceName: "\(p.name) \(p.trigram)", trigram: p.trigram,
                    doorName: door.name, doorLuck: door.luckType,
                    starName: star, godName: god, tianStem: "", diStem: "",
                    isTaiJiCenter: false, isDoorAuspicious: door.isAuspicious
                )
                let pName = cellProbe.localizedPalaceName
                let dName = door.localizedName
                let sName = cellProbe.localizedStarName
                let gName = cellProbe.localizedGodName
                let lore = door.localizedLore

                if door.name == "生门" || door.name == "开门" {
                    let candidateScore = door.name == "开门" ? 4 : 3
                    if candidateScore > bestScore {
                        switch lang {
                        case .en:
                            bestDirection = "\(pName) · \(dName)"
                            bestReason = "Protected by \(sName) & \(gName), \(lore)"
                        case .zhHant:
                            bestDirection = "\(pName) (\(dName))"
                            bestReason = "臨\(sName)星與\(gName)神，\(lore)"
                        case .ja:
                            bestDirection = "\(pName) (\(dName))"
                            bestReason = "\(sName)星と\(gName)神が臨み、\(lore)"
                        case .ko:
                            bestDirection = "\(pName) (\(dName))"
                            bestReason = "\(sName)성과 \(gName)신이 임하여, \(lore)"
                        case .vi:
                            bestDirection = "\(pName) (\(dName))"
                            bestReason = "Lâm \(sName) tinh cùng \(gName) thần, \(lore)"
                        case .th:
                            bestDirection = "\(pName) (\(dName))"
                            bestReason = "สถิตดาว \(sName) และเทพ \(gName), \(lore)"
                        case .id:
                            bestDirection = "\(pName) (\(dName))"
                            bestReason = "Dinaungi bintang \(sName) & dewa \(gName), \(lore)"
                        case .zhHans:
                            bestDirection = "\(p.name)方 (\(p.trigram)宫\(door.name))"
                            bestReason = "临\(star)星与\(god)神，\(door.lore)"
                        }
                        bestBearing = Self.bearing(for: p.name)
                        bestScore = candidateScore
                    }
                }
                if door.name == "死门" || door.name == "惊门" {
                    switch lang {
                    case .en: tabooDirs.append("\(pName) · \(dName)")
                    case .zhHant: tabooDirs.append("\(pName)\(dName)")
                    case .ja: tabooDirs.append("\(pName) \(dName)")
                    case .ko: tabooDirs.append("\(pName) \(dName)")
                    case .vi: tabooDirs.append("\(pName) (\(dName))")
                    case .th: tabooDirs.append("\(pName) (\(dName))")
                    case .id: tabooDirs.append("\(pName) (\(dName))")
                    case .zhHans: tabooDirs.append("\(p.name)\(door.name)")
                    }
                }
                
                cells.append(QimenPalaceCell(
                    palaceId: p.id,
                    palaceName: "\(p.name) \(p.trigram)",
                    trigram: p.trigram,
                    doorName: door.name,
                    doorLuck: door.luckType,
                    starName: star,
                    godName: god,
                    tianStem: tianStem,
                    diStem: diStem,
                    isTaiJiCenter: false,
                    isDoorAuspicious: door.isAuspicious
                ))
                nonCenterIndex += 1
            }
        }

        // Add a turn instruction to the absolute best direction.
        if let targetBearing = bestBearing,
           heading.isFinite {
            let turn = Self.shortestTurn(from: heading, to: targetBearing)
            if abs(turn) >= 1.0 {
                let degrees = Int(round(abs(turn)))
                switch lang {
                case .en:
                    bestDirection += turn > 0 ? " · turn right \(degrees)°" : " · turn left \(degrees)°"
                case .zhHant:
                    bestDirection += turn > 0 ? " · 右轉約\(degrees)°" : " · 左轉約\(degrees)°"
                case .ja:
                    bestDirection += turn > 0 ? " · 右へ約\(degrees)°" : " · 左へ約\(degrees)°"
                case .ko:
                    bestDirection += turn > 0 ? " · 오른쪽으로 약 \(degrees)°" : " · 왼쪽으로 약 \(degrees)°"
                case .vi:
                    bestDirection += turn > 0 ? " · rẽ phải khoảng \(degrees)°" : " · rẽ trái khoảng \(degrees)°"
                case .th:
                    bestDirection += turn > 0 ? " · เลี้ยวขวาประมาณ \(degrees)°" : " · เลี้ยวซ้ายประมาณ \(degrees)°"
                case .id:
                    bestDirection += turn > 0 ? " · belok kanan sekitar \(degrees)°" : " · belok kiri sekitar \(degrees)°"
                case .zhHans:
                    bestDirection += turn > 0 ? " · 右转约\(degrees)°" : " · 左转约\(degrees)°"
                }
            }
        }
        
        return QimenChart(
            dunType: dunType,
            juNumber: juNumber,
            title: title,
            cells: cells,
            bestNavDirection: bestDirection,
            bestNavReason: bestReason,
            tabooDirections: tabooDirs.joined(separator: "、")
        )
    }

    /// Compass bearings for the eight Qimen palaces.  The center palace is
    /// deliberately excluded because it is not a travel direction.
    private static func bearing(for direction: String) -> Double? {
        switch direction {
        case "正北": return 0.0
        case "东北": return 45.0
        case "正东": return 90.0
        case "东南": return 135.0
        case "正南": return 180.0
        case "西南": return 225.0
        case "正西": return 270.0
        case "西北": return 315.0
        default: return nil
        }
    }

    /// Returns the signed shortest clockwise turn from the current bearing to
    /// a target bearing. Positive values mean turn right/clockwise; negative
    /// values mean turn left/counter-clockwise.
    private static func shortestTurn(from heading: Double, to target: Double) -> Double {
        var delta = (target - heading).truncatingRemainder(dividingBy: 360.0)
        if delta > 180.0 { delta -= 360.0 }
        if delta < -180.0 { delta += 360.0 }
        return delta
    }
}
