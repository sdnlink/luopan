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
        case .auto, .zhHans:
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
        case .auto, .zhHans:
            return luckType
        }
    }

    /// Keep the traditional door symbolism intact and attach its classical
    /// source and interpretation after the displayed wording.
    public var localizedLore: String {
        baseLocalizedLore + "\n\n" + classicalSourceNote
    }

    private var baseLocalizedLore: String {
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
        case .auto, .zhHans:
            return [
                "休门": "求名休闲大吉，水清木秀", "生门": "求财置业大吉，土旺金生",
                "伤门": "讨债索敌宜，出行防伤灾", "杜门": "潜伏隐匿避灾，闭藏门户",
                "景门": "文书考试宴请吉，火炎防急", "死门": "吊丧刑戮宜，出行造葬大凶",
                "惊门": "官非惊恐口舌，捕盗宜", "开门": "经商开业动身，百事通亨"
            ][name] ?? lore
        }
    }

    private var classicalSourceNote: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return "Classical source: the traditional Eight-Gates mnemonic in Qimen Dunjia texts, ‘Rest, Life and Open are the three auspicious gates; Death, Shock and Harm are the three inauspicious gates; Block and View are intermediate.’ Interpretation: the gate language above is a historical symbolic reading. It does not determine travel safety, health, construction, legal or financial outcomes; verify real-world conditions and consult qualified professionals."
        case .zhHant:
            return "古籍出处：奇門遁甲八門傳統訣：「休、生、開三吉；死、驚、傷三凶；杜、景二門中。」解釋：上文門象為古籍術數的象徵解讀，不決定出行安全、健康、施工、法律或財務結果；請以現場條件及專業意見為準。"
        case .ja:
            return "出典：奇門遁甲の八門訣「休・生・開は三吉、死・驚・傷は三凶、杜・景は中門」。解釈：門の吉凶は古典術数の象徴的な読みであり、旅行の安全、健康、工事、法律・金融の結果を決めるものではありません。"
        case .ko:
            return "출처: 기문둔갑 팔문 전통결 ‘휴·생·개는 삼길, 사·경·상은 삼흉, 두·경은 중문’. 해석: 위 문상은 고전 술수의 상징적 해석이며 여행 안전·건강·공사·법률·재무 결과를 결정하지 않습니다."
        case .vi:
            return "Nguồn cổ: khẩu quyết Bát Môn trong Kỳ Môn Độn Giáp: ‘Hưu, Sinh, Khai là ba cửa cát; Tử, Kinh, Thương là ba cửa hung; Đỗ, Cảnh là cửa trung.’ Giải thích: ngôn ngữ cửa là biểu tượng thuật số cổ, không quyết định an toàn đi lại, sức khỏe, xây dựng, pháp lý hay tài chính."
        case .th:
            return "ที่มาโบราณ: สูตรแปดประตูในฉีเหมินตุ้นเจี่ย ‘ประตูพัก เกิด เปิด เป็นสามประตูมงคล; ตาย ตกใจ บาดเจ็บ เป็นสามประตูอัปมงคล; ซ่อนและทัศน์เป็นประตูกลาง’ คำอธิบาย: ถ้อยคำเรื่องประตูเป็นสัญลักษณ์ของศาสตร์โบราณ ไม่ได้กำหนดความปลอดภัย สุขภาพ งานก่อสร้าง กฎหมาย หรือการเงิน"
        case .id:
            return "Sumber klasik: mnemonik Delapan Gerbang Qimen Dunjia, ‘Istirahat, Kehidupan, dan Pembuka adalah tiga gerbang baik; Kematian, Kejutan, dan Luka adalah tiga gerbang buruk; Blokir dan Pandang adalah gerbang menengah.’ Penjelasan: simbol gerbang ini adalah tafsir sejarah, bukan penentu keselamatan perjalanan, kesehatan, konstruksi, hukum, atau keuangan."
        case .auto, .zhHans:
            return "古籍出处：奇门遁甲八门传统诀：“休、生、开三吉；死、惊、伤三凶；杜、景二门中。”解释：上文门象为古籍术数的象征解读，不决定出行安全、健康、施工、法律或财务结果；请以现场条件及专业意见为准。"
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
    private static func localizeStem(_ stem: String) -> String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en, .id:
            return ["甲": "Jia", "乙": "Yi", "丙": "Bing", "丁": "Ding", "戊": "Wu", "己": "Ji", "庚": "Geng", "辛": "Xin", "壬": "Ren", "癸": "Gui"][stem] ?? stem
        case .ko:
            return ["甲": "갑", "乙": "을", "丙": "병", "丁": "정", "戊": "무", "己": "기", "庚": "경", "辛": "신", "壬": "임", "癸": "계"][stem] ?? stem
        case .vi:
            return ["甲": "Giáp", "乙": "Ất", "丙": "Bính", "丁": "Đinh", "戊": "Mậu", "己": "Kỷ", "庚": "Canh", "辛": "Tân", "壬": "Nhâm", "癸": "Quý"][stem] ?? stem
        case .th:
            return ["甲": "เจี่ย", "乙": "อี้", "丙": "ปิ่ง", "丁": "ติง", "戊": "อู่", "己": "จี่", "庚": "เกิง", "辛": "ซิน", "壬": "เหริน", "癸": "กุ่ย"][stem] ?? stem
        case .auto, .zhHans, .zhHant, .ja:
            return stem
        }
    }
    public var localizedTianStem: String { Self.localizeStem(tianStem) }
    public var localizedDiStem: String { Self.localizeStem(diStem) }
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
        case .auto, .zhHans:
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
        case .auto, .zhHans:
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
        case .auto, .zhHans:
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
    
    // 洛书飞布顺序（阳遁顺、阴遁逆）。洛书外围九宫的环行路径为
    // 1→8→3→4→9→2→7→6；九星/三奇六仪另将中宫 5 作为第九个位置，
    // 八门/八神则跳过中宫。此前按数字升序飞布会把整盘落错宫位。
    private let luoOrderFull = [1, 8, 3, 4, 9, 2, 7, 6, 5]
    private let luoOrderSkip = [1, 8, 3, 4, 9, 2, 7, 6]

    private func stepFull(_ p: Int, forward: Bool) -> Int {
        guard let i = luoOrderFull.firstIndex(of: p) else { return p }
        let n = luoOrderFull.count
        return luoOrderFull[(i + (forward ? 1 : -1) + n) % n]
    }
    private func stepSkip(_ p: Int, forward: Bool) -> Int {
        // 八门/八神不入中宫。若旬首或值符落在中宫，先从环行路径
        // 的起点继续飞布，避免 5 不在 skip 序列时原地重复八次。
        guard let i = luoOrderSkip.firstIndex(of: p) else {
            return forward ? luoOrderSkip[0] : luoOrderSkip[luoOrderSkip.count - 1]
        }
        let n = luoOrderSkip.count
        return luoOrderSkip[(i + (forward ? 1 : -1) + n) % n]
    }
    private func flySkip(start: Int, steps: Int, forward: Bool) -> Int {
        var cur = luoOrderSkip.contains(start)
            ? start
            : (forward ? luoOrderSkip[0] : luoOrderSkip[luoOrderSkip.count - 1])
        let s = ((steps % 8) + 8) % 8
        for _ in 0..<s { cur = stepSkip(cur, forward: forward) }
        return cur
    }
    private func flightFull(from start: Int, forward: Bool) -> [Int] {
        var seq = [Int](); var cur = start
        for _ in 0..<9 { seq.append(cur); cur = stepFull(cur, forward: forward) }
        return seq
    }
    private func flightSkip(from start: Int, forward: Bool) -> [Int] {
        var seq = [Int](); var cur = luoOrderSkip.contains(start)
            ? start
            : (forward ? luoOrderSkip[0] : luoOrderSkip[luoOrderSkip.count - 1])
        for _ in 0..<8 { seq.append(cur); cur = stepSkip(cur, forward: forward) }
        return seq
    }

    /// 日干支序号 (0..59)。与 SolarTimeCalculator 的 (JDN+49)%60 口径一致。
    private func dayGanZhiIndex(for date: Date) -> Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 2000, m = comps.month ?? 1, d = comps.day ?? 1
        let a = Int((14 - m) / 12)
        let yy = y + 4800 - a
        let mm = m + 12 * a - 3
        let jdn = d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045
        return ((jdn + 49) % 60 + 60) % 60
    }

    public func calculateChart(date: Date = Date(), heading: Double = 0.0) -> QimenChart {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let solarTermIndex = SolarTimeCalculator.shared.solarTermIndex(for: date)

        // 1. 阴遁/阳遁按节气切换：夏至至大雪为阴遁，冬至至芒种为阳遁。
        let isYangDun = solarTermIndex < 11 || solarTermIndex >= 23
        let lang = LocalizationManager.shared.effectiveLanguage
        let forward = isYangDun // 阳遁顺飞，阴遁逆飞

        let dunType: String
        switch lang {
        case .en: dunType = isYangDun ? "Yang Dun" : "Yin Dun"
        case .zhHant: dunType = isYangDun ? "陽遁" : "陰遁"
        case .ja: dunType = isYangDun ? "陽遁" : "陰遁"
        case .ko: dunType = isYangDun ? "양둔" : "음둔"
        case .vi: dunType = isYangDun ? "Dương Độn" : "Âm Độn"
        case .th: dunType = isYangDun ? "หยางตุ้น" : "อินตุ้น"
        case .id: dunType = isYangDun ? "Yang Dun" : "Yin Dun"
        case .auto, .zhHans: dunType = isYangDun ? "阳遁" : "阴遁"
        }

        // 2. 拆补法定局：以"符头"（甲/己日）确定上/中/下元。
        //    符头干支 % 15：0→上元，5→下元，10→中元。
        let dayGz = dayGanZhiIndex(for: date)
        let fuHead = dayGz - (dayGz % 5)
        let yuanIndex: Int
        switch fuHead % 15 {
        case 0:  yuanIndex = 0
        case 5:  yuanIndex = 2
        case 10: yuanIndex = 1
        default: yuanIndex = 0
        }
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
        let yuanName: String
        switch lang {
        case .en: yuanName = ["Upper Yuan", "Middle Yuan", "Lower Yuan"][yuanIndex]
        case .zhHant, .ja: yuanName = ["上元", "中元", "下元"][yuanIndex]
        case .ko: yuanName = ["상원", "중원", "하원"][yuanIndex]
        case .vi: yuanName = ["Thượng Nguyên", "Trung Nguyên", "Hạ Nguyên"][yuanIndex]
        case .th: yuanName = ["ง้วนบน", "ง้วนกลาง", "ง้วนล่าง"][yuanIndex]
        case .id: yuanName = ["Yuan Atas", "Yuan Tengah", "Yuan Bawah"][yuanIndex]
        case .auto, .zhHans: yuanName = ["上元", "中元", "下元"][yuanIndex]
        }
        let title: String
        switch lang {
        case .en: title = "【\(dunType) Bureau \(juNumber) · \(yuanName)】"
        case .zhHant: title = "【\(dunType)\(juNumber)局 · 拆補\(yuanName)】"
        case .ja: title = "【\(dunType)\(juNumber)局 · 拆補\(yuanName)】"
        case .ko: title = "【\(dunType) \(juNumber)국 · \(yuanName)】"
        case .vi: title = "【\(dunType) Cục \(juNumber) · \(yuanName)】"
        case .th: title = "【\(dunType) สำนัก \(juNumber) · \(yuanName)】"
        case .id: title = "【\(dunType) Pola \(juNumber) · \(yuanName)】"
        case .auto, .zhHans: title = "【\(dunType)\(juNumber)局 · 拆补\(yuanName)】"
        }

        // 3. 时辰干支（晚子时 23:00 归次日，与八字日柱口径一致）。
        let dayRef = cal.date(byAdding: .hour, value: 1, to: date) ?? date
        let effDayGz = dayGanZhiIndex(for: dayRef)
        let dayStem = effDayGz % 10
        let hourBranch = ((hour + 1) / 2) % 12
        let hourStem = ((dayStem % 5) * 2 + hourBranch) % 10
        let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        let hourStemChar = stems[hourStem]
        let shichenGz = ((effDayGz * 12 + hourBranch) % 60 + 60) % 60
        let xun = shichenGz / 10

        // 4. 地盘（动态）：按局数起戊，阳遁顺飞/阴遁逆飞洛书九宫布三奇六仪。
        //    布干序固定为 戊己庚辛壬癸丁丙乙；阳遁一局即 戊坎、己坤、庚震、辛巽、
        //    壬中(天禽寄)、癸乾、丁兑、丙艮、离乙，其余局数平移起点并翻转飞向。
        var diPanStem: [Int: String] = [:]
        let diPlacement = flightFull(from: juNumber, forward: forward)
        for (i, palace) in diPlacement.enumerated() {
            diPanStem[palace] = sixYiStems[i]
        }
        let stemToPalace = Dictionary(uniqueKeysWithValues: diPanStem.map { ($1, $0) })
        let xunToSixYi = ["戊", "己", "庚", "辛", "壬", "癸"]
        let xunHeadSixYi = xunToSixYi[xun]
        // 值符/值使本宫（旬首六仪所在）。正常盘面一定能找到旬首，
        // 但保留安全回退，避免规则表扩展或异常输入导致整个分析页崩溃。
        let zhiFuPalace = stemToPalace[xunHeadSixYi] ?? diPlacement.first ?? 1
        // 八门本宫：休坎、死坤、伤震、杜巽、景离、生艮、惊兑、开乾（中宫无门）。
        let doorPalaceToName: [Int: String] = [1: "休门", 2: "死门", 3: "伤门", 4: "杜门", 9: "景门", 8: "生门", 7: "惊门", 6: "开门"]
        let doorInfo: [String: (luck: String, ausp: Bool)] = Dictionary(
            uniqueKeysWithValues: eightDoors.map { ($0.name, (luck: $0.luckType, ausp: $0.isAuspicious)) }
        )

        // 5. 值符（天盘九星）落宫 = 地盘时干宫；时干为甲则落旬首本宫。
        let zhiFuStarStart: Int = (hourStemChar == "甲") ? zhiFuPalace : (stemToPalace[hourStemChar] ?? zhiFuPalace)
        // 值使（天盘八门）落宫 = 旬首本宫起，按旬内时辰数顺/逆飞。
        let stepsIntoXun = shichenGz % 10
        let zhiShiStart = flySkip(start: zhiFuPalace, steps: stepsIntoXun, forward: forward)

        // 6. 天盘九星 + 三奇六仪（含中宫）。
        let starOrigin = flightFull(from: zhiFuPalace, forward: forward)
        let starDest = flightFull(from: zhiFuStarStart, forward: forward)
        var tianStar = [Int: String](), tianStem = [Int: String]()
        for k in 0..<9 {
            let dest = starDest[k], origin = starOrigin[k]
            tianStar[dest] = nineStars[origin - 1]
            tianStem[dest] = diPanStem[origin] ?? "戊"
        }

        // 7. 天盘八门（不入中宫）。
        let doorOrigin = flightSkip(from: zhiFuPalace, forward: forward)
        let doorDest = flightSkip(from: zhiShiStart, forward: forward)
        var tianDoor = [Int: String]()
        for k in 0..<8 {
            tianDoor[doorDest[k]] = doorPalaceToName[doorOrigin[k]]
        }

        // 8. 八神（不入中宫）。阳遁顺、阴遁逆（白虎/玄武换位）。
        let godOrder = isYangDun
            ? ["值符", "螣蛇", "太阴", "六合", "白虎", "玄武", "九地", "九天"]
            : ["值符", "螣蛇", "太阴", "六合", "玄武", "白虎", "九地", "九天"]
        let godDest = flightSkip(from: zhiFuStarStart, forward: forward)
        var tianGod = [Int: String]()
        for k in 0..<8 { tianGod[godDest[k]] = godOrder[k] }

        // 9. 组装九宫数据。
        let centerName: String
        switch lang {
        case .en: centerName = "Center"
        case .zhHant, .ja: centerName = "中宮"
        case .ko: centerName = "중궁"
        case .vi: centerName = "Trung Cung"
        case .th: centerName = "จุดศูนย์กลาง"
        case .id: centerName = "Pusat"
        case .auto, .zhHans: centerName = "中宫"
        }
        let centerGod: String
        switch lang {
        case .en: centerGod = "Center"
        case .ko: centerGod = "원극"
        case .vi: centerGod = "Nguyên Cực"
        case .th: centerGod = "ไท่จี๋"
        case .zhHant: centerGod = "太極"
        case .ja: centerGod = "太極"
        case .id: centerGod = "Titik Pusat"
        case .auto, .zhHans: centerGod = "元极"
        }
        var byPalace = [Int: (door: String, luck: String, ausp: Bool, star: String, god: String, tian: String, di: String)]()
        for p in 1...9 {
            if p == 5 {
                byPalace[5] = (door: centerName, luck: LocalizationManager.shared.t("floorplan_level_neutral"), ausp: false,
                               star: tianStar[5] ?? "天禽", god: tianGod[5] ?? centerGod,
                               tian: tianStem[5] ?? "戊", di: diPanStem[5] ?? "壬")
            } else {
                let door = tianDoor[p] ?? "休门"
                let info = doorInfo[door] ?? (luck: "平", ausp: false)
                byPalace[p] = (door: door, luck: info.luck, ausp: info.ausp,
                               star: tianStar[p] ?? nineStars[p - 1], god: tianGod[p] ?? centerGod,
                               tian: tianStem[p] ?? "戊", di: diPanStem[p] ?? "戊")
            }
        }

        // 10. 出行吉方 / 避忌方。
        let defById = Dictionary(uniqueKeysWithValues: displayPalaceDefs.map { ($0.id, $0) })
        var bestScore = -1
        var bestBearing: Double? = nil
        var bestDirection: String
        var bestReason: String
        switch lang {
        case .en:
            bestDirection = "Northwest (Qian - Open Gate)"; bestReason = "Auspicious Open Gate with Chief Deity"
        case .zhHant:
            bestDirection = "西北方 (乾宮開門)"; bestReason = "開門乘吉神值符，天地德合"
        case .ja:
            bestDirection = "北西方 (乾宮 開門)"; bestReason = "開門に直符神が臨み、万事亨通"
        case .ko:
            bestDirection = "북서방 (건궁 개문)"; bestReason = "개문에 직부신이 임하여 천지덕합"
        case .vi:
            bestDirection = "Tây Bắc (Càn Cung Khai Môn)"; bestReason = "Khai Môn thừa cát thần Trực Phù, thiên địa đức hợp"
        case .th:
            bestDirection = "ทิศตะวันตกเฉียงเหนือ (เฉียน - ประตูเปิด)"; bestReason = "ประตูเปิดสถิตร่วมเทพจื่อฝู ราบรื่นมงคลยิ่ง"
        case .id:
            bestDirection = "Barat Laut (Qian - Gerbang Pembuka)"; bestReason = "Gerbang Pembuka dinaungi Panglima Agung"
        case .auto, .zhHans:
            bestDirection = "西北方 (乾宫开门)"; bestReason = "开门乘吉神值符，天地德合"
        }
        var tabooDirs: [String] = []
        for p in 1...9 where p != 5 {
            guard let data = byPalace[p], let def = defById[p] else { continue }
            let door = QimenDoor(name: data.door, palace: p, isAuspicious: data.ausp, luckType: data.luck, lore: "")
            let dName = door.localizedName
            let sName = QimenPalaceCell(palaceId: p, palaceName: "\(def.name) \(def.trigram)", trigram: def.trigram,
                                        doorName: data.door, doorLuck: data.luck, starName: data.star, godName: data.god,
                                        tianStem: data.tian, diStem: data.di, isTaiJiCenter: false, isDoorAuspicious: data.ausp).localizedStarName
            let gName = QimenPalaceCell(palaceId: p, palaceName: "\(def.name) \(def.trigram)", trigram: def.trigram,
                                        doorName: data.door, doorLuck: data.luck, starName: data.star, godName: data.god,
                                        tianStem: data.tian, diStem: data.di, isTaiJiCenter: false, isDoorAuspicious: data.ausp).localizedGodName
            let lore = door.localizedLore
            if data.door == "生门" || data.door == "开门" {
                let candidateScore = data.door == "开门" ? 4 : 3
                if candidateScore > bestScore {
                    switch lang {
                    case .en:
                        bestDirection = "\(def.name) \(def.trigram) · \(dName)"
                        bestReason = "Protected by \(sName) & \(gName), \(lore)"
                    case .zhHant:
                        bestDirection = "\(def.name)\(def.trigram) (\(dName))"
                        bestReason = "臨\(sName)星與\(gName)神，\(lore)"
                    case .ja:
                        bestDirection = "\(def.name)\(def.trigram) (\(dName))"
                        bestReason = "\(sName)星と\(gName)神が臨み、\(lore)"
                    case .ko:
                        bestDirection = "\(def.name) \(def.trigram) (\(dName))"
                        bestReason = "\(sName)성과 \(gName)신이 임하여, \(lore)"
                    case .vi:
                        bestDirection = "\(def.name) \(def.trigram) (\(dName))"
                        bestReason = "Lâm \(sName) tinh cùng \(gName) thần, \(lore)"
                    case .th:
                        bestDirection = "\(def.name) \(def.trigram) (\(dName))"
                        bestReason = "สถิตดาว \(sName) และเทพ \(gName), \(lore)"
                    case .id:
                        bestDirection = "\(def.name) \(def.trigram) (\(dName))"
                        bestReason = "Dinaungi bintang \(sName) & dewa \(gName), \(lore)"
                    case .auto, .zhHans:
                        bestDirection = "\(def.name)方 (\(def.trigram)宫\(data.door))"
                        bestReason = "临\(data.star)星与\(data.god)神，\(lore)"
                    }
                    bestBearing = Self.bearing(for: def.name)
                    bestScore = candidateScore
                }
            }
            if data.door == "死门" || data.door == "惊门" {
                switch lang {
                case .en: tabooDirs.append("\(def.name) \(def.trigram) · \(dName)")
                case .zhHant: tabooDirs.append("\(def.name)\(def.trigram)\(dName)")
                case .ja: tabooDirs.append("\(def.name) \(def.trigram) \(dName)")
                case .ko: tabooDirs.append("\(def.name) \(def.trigram) \(dName)")
                case .vi: tabooDirs.append("\(def.name) \(def.trigram) (\(dName))")
                case .th: tabooDirs.append("\(def.name) \(def.trigram) (\(dName))")
                case .id: tabooDirs.append("\(def.name) \(def.trigram) (\(dName))")
                case .auto, .zhHans: tabooDirs.append("\(def.name)\(data.door)")
                }
            }
        }

        // 11. 生成展示顺序的 cells。
        var cells: [QimenPalaceCell] = []
        for p in displayPalaceDefs {
            guard let data = byPalace[p.id] else { continue }
            cells.append(QimenPalaceCell(
                palaceId: p.id,
                palaceName: "\(p.name) \(p.trigram)",
                trigram: p.trigram,
                doorName: data.door,
                doorLuck: data.luck,
                starName: data.star,
                godName: data.god,
                tianStem: data.tian,
                diStem: data.di,
                isTaiJiCenter: p.id == 5,
                isDoorAuspicious: data.ausp
            ))
        }

        // 12. 在绝对最优方位后附加转向提示。
        if let targetBearing = bestBearing, heading.isFinite {
            let turn = Self.shortestTurn(from: heading, to: targetBearing)
            if abs(turn) >= 1.0 {
                let degrees = Int(round(abs(turn)))
                switch lang {
                case .en: bestDirection += turn > 0 ? " · turn right \(degrees)°" : " · turn left \(degrees)°"
                case .zhHant: bestDirection += turn > 0 ? " · 右轉約\(degrees)°" : " · 左轉約\(degrees)°"
                case .ja: bestDirection += turn > 0 ? " · 右へ約\(degrees)°" : " · 左へ約\(degrees)°"
                case .ko: bestDirection += turn > 0 ? " · 오른쪽으로 약 \(degrees)°" : " · 왼쪽으로 약 \(degrees)°"
                case .vi: bestDirection += turn > 0 ? " · rẽ phải khoảng \(degrees)°" : " · rẽ trái khoảng \(degrees)°"
                case .th: bestDirection += turn > 0 ? " · เลี้ยวขวาประมาณ \(degrees)°" : " · เลี้ยวซ้ายประมาณ \(degrees)°"
                case .id: bestDirection += turn > 0 ? " · belok kanan sekitar \(degrees)°" : " · belok kiri sekitar \(degrees)°"
                case .auto, .zhHans: bestDirection += turn > 0 ? " · 右转约\(degrees)°" : " · 左转约\(degrees)°"
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
