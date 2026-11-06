import Foundation

// MARK: - 一百二十分金数据库与吉凶分析 (PRD 6.6 & 罗盘核心第三层)

public struct FenjinItem: Identifiable {
    public var id: String { "\(mountainName)-\(index)" }
    public let mountainName: String    // 所属二十四山 (如 "子山")
    public let index: Int              // 1..5
    public let jiaziName: String       // 甲子名称 (如 "甲子", "丙子", "戊子", "庚子", "壬子")
    public let startAngle: Double      // 起始角度
    public let endAngle: Double        // 终止角度
    public let centerAngle: Double     // 中心角度
    public let grade: String           // "旺相大吉", "孤虚差错", "龟甲空亡", "平稳"
    public let isAuspicious: Bool      // 是否为可用吉度
    public let lore: String            // 秘诀断语

    public var localizedMountainName: String {
        if let mountain = Mountain24Data.shared.mountains.first(where: { $0.name == mountainName }) {
            return mountain.localizedName
        }
        return mountainName
    }

    public var localizedJiaziName: String {
        guard jiaziName.count >= 2 else { return jiaziName }
        let stemChar = String(jiaziName.prefix(1))
        let branchChar = String(jiaziName.suffix(1))
        let lang = LocalizationManager.shared.effectiveLanguage

        let stemMap: [String: [AppLanguage: String]] = [
            "甲": [.en: "Jia", .ja: "甲", .ko: "갑", .vi: "Giáp", .th: "เจี่ย", .id: "Jia"],
            "乙": [.en: "Yi", .ja: "乙", .ko: "을", .vi: "Ất", .th: "อี่", .id: "Yi"],
            "丙": [.en: "Bing", .ja: "丙", .ko: "병", .vi: "Bính", .th: "ปิ่ง", .id: "Bing"],
            "丁": [.en: "Ding", .ja: "丁", .ko: "정", .vi: "Đinh", .th: "ติง", .id: "Ding"],
            "戊": [.en: "Wu", .ja: "戊", .ko: "무", .vi: "Mậu", .th: "อู้", .id: "Wu"],
            "己": [.en: "Ji", .ja: "己", .ko: "기", .vi: "Kỷ", .th: "จี่", .id: "Ji"],
            "庚": [.en: "Geng", .ja: "庚", .ko: "경", .vi: "Canh", .th: "เกิง", .id: "Geng"],
            "辛": [.en: "Xin", .ja: "辛", .ko: "신", .vi: "Tân", .th: "ซิน", .id: "Xin"],
            "壬": [.en: "Ren", .ja: "壬", .ko: "임", .vi: "Nhâm", .th: "เหริน", .id: "Ren"],
            "癸": [.en: "Gui", .ja: "癸", .ko: "계", .vi: "Quý", .th: "กุ่ย", .id: "Gui"]
        ]
        let branchMap: [String: [AppLanguage: String]] = [
            "子": [.en: "Zi", .ja: "子", .ko: "자", .vi: "Tý", .th: "จื่อ", .id: "Zi"],
            "丑": [.en: "Chou", .ja: "丑", .ko: "축", .vi: "Sửu", .th: "โฉ่ว", .id: "Chou"],
            "寅": [.en: "Yin", .ja: "寅", .ko: "인", .vi: "Dần", .th: "อิ๋น", .id: "Yin"],
            "卯": [.en: "Mao", .ja: "卯", .ko: "묘", .vi: "Mão", .th: "เหมา", .id: "Mao"],
            "辰": [.en: "Chen", .ja: "辰", .ko: "진", .vi: "Thìn", .th: "เฉิน", .id: "Chen"],
            "巳": [.en: "Si", .ja: "巳", .ko: "사", .vi: "Tỵ", .th: "ซื่อ", .id: "Si"],
            "午": [.en: "Wu", .ja: "午", .ko: "오", .vi: "Ngọ", .th: "อู่", .id: "Wu"],
            "未": [.en: "Wei", .ja: "未", .ko: "미", .vi: "Mùi", .th: "เว่ย", .id: "Wei"],
            "申": [.en: "Shen", .ja: "申", .ko: "신", .vi: "Thân", .th: "เซิน", .id: "Shen"],
            "酉": [.en: "You", .ja: "酉", .ko: "유", .vi: "Dậu", .th: "โหย่ว", .id: "You"],
            "戌": [.en: "Xu", .ja: "戌", .ko: "술", .vi: "Tuất", .th: "ซีว์", .id: "Xu"],
            "亥": [.en: "Hai", .ja: "亥", .ko: "해", .vi: "Hợi", .th: "ไฮ่", .id: "Hai"]
        ]

        if lang == .zhHans || lang == .zhHant {
            return jiaziName
        }
        let s = stemMap[stemChar]?[lang] ?? stemChar
        let b = branchMap[branchChar]?[lang] ?? branchChar
        switch lang {
        case .en, .id: return "\(s)-\(b)"
        case .vi: return "\(s) \(b)"
        case .ko: return "\(s)\(b) (\(jiaziName))"
        case .ja: return "\(jiaziName) (\(s)\(b))"
        case .th: return "\(s)-\(b)"
        default: return jiaziName
        }
    }

    public var localizedGrade: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .auto, .zhHans:
            return grade
        case .zhHant:
            return grade.replacingOccurrences(of: "孤虚", with: "孤虛")
                .replacingOccurrences(of: "差错", with: "差錯")
                .replacingOccurrences(of: "退财", with: "退財")
                .replacingOccurrences(of: "龟", with: "龜")
                .replacingOccurrences(of: "平稳", with: "平穩")
        case .en:
            switch grade {
            case "旺相大吉": return "Auspicious Prosperity"
            case "孤虚差错": return "Lone Void Error"
            case "差错退财": return "Error · Wealth Drain"
            case "龟甲空亡": return "Turtle-Shell Void"
            case "差错退气": return "Error · Retreating Qi"
            default: return "Balanced & Neutral"
            }
        case .ja:
            switch grade {
            case "旺相大吉": return "旺相大吉"
            case "孤虚差错": return "孤虚差錯"
            case "差错退财": return "差錯退財"
            case "龟甲空亡": return "亀甲空亡"
            case "差错退气": return "差錯退気"
            default: return "平穏"
            }
        case .ko:
            switch grade {
            case "旺相大吉": return "왕상대길 (旺相大吉)"
            case "孤虚差错": return "고허착오 (孤虛差錯)"
            case "差错退财": return "착오퇴재 (差錯退財)"
            case "龟甲空亡": return "귀갑공망 (龜甲空亡)"
            case "差错退气": return "착오퇴기 (差錯退氣)"
            default: return "평온 (平穩)"
            }
        case .vi:
            switch grade {
            case "旺相大吉": return "Vượng Tướng Đại Cát"
            case "孤虚差错": return "Cô Hư Sai Thất"
            case "差错退财": return "Sai Thất Thoái Tài"
            case "龟甲空亡": return "Quy Giáp Không Vong"
            case "差错退气": return "Sai Thất Thoái Khí"
            default: return "Bình Ổn"
            }
        case .th:
            switch grade {
            case "旺相大吉": return "มหามงคลรุ่งเรืองยิ่ง"
            case "孤虚差错": return "พลังโดดเดี่ยวว่างเปล่าผิดพลาด"
            case "差错退财": return "ผิดพลาดทรัพย์รั่วไหล"
            case "龟甲空亡": return "ช่องว่างกระดองเต่าอวมงคล"
            case "差错退气": return "ผิดพลาดพลังถดถอย"
            default: return "ราบเรียบสมดุล"
            }
        case .id:
            switch grade {
            case "旺相大吉": return "Sangat Menguntungkan & Makmur"
            case "孤虚差错": return "Kekosongan Terasing & Kekeliruan"
            case "差错退财": return "Kekeliruan Menguras Rezeki"
            case "龟甲空亡": return "Kekosongan Cangkang Kura-kura"
            case "差错退气": return "Kekeliruan Energi Melemah"
            default: return "Stabil & Seimbang"
            }
        default:
            return grade
        }
    }

    /// The traditional 分金口诀 is retained in full.  A source note is added
    /// after it so health, vitality and wealth terms are clearly framed as
    /// historical symbolism rather than professional advice.
    public var localizedLore: String {
        baseLocalizedLore + "\n\n" + classicalSourceNote
    }

    private var baseLocalizedLore: String {
        let firstStem = String(jiaziName.prefix(1))
        let lang = LocalizationManager.shared.effectiveLanguage
        
        if lang == .zhHans {
            return lore
        }
        if lang == .zhHant {
            return lore.replacingOccurrences(of: "差错", with: "差錯")
                .replacingOccurrences(of: "退财", with: "退財")
                .replacingOccurrences(of: "旺相", with: "旺相")
                .replacingOccurrences(of: "气", with: "氣")
                .replacingOccurrences(of: "煞气", with: "煞氣")
                .replacingOccurrences(of: "阴", with: "陰")
                .replacingOccurrences(of: "阳", with: "陽")
                .replacingOccurrences(of: "财", with: "財")
                .replacingOccurrences(of: "龟", with: "龜")
                .replacingOccurrences(of: "针", with: "針")
                .replacingOccurrences(of: "祸", with: "禍")
                .replacingOccurrences(of: "师", with: "師")
                .replacingOccurrences(of: "绝", with: "絕")
                .replacingOccurrences(of: "横", with: "橫")
                .replacingOccurrences(of: "发", with: "發")
        }
        
        switch lang {
        case .en:
            switch firstStem {
            case "甲": return "Lone-void sha qi; indicates financial decline and weakened vitality. Avoid using this facing."
            case "乙": return "Excess yin qi; causes covert wealth drainage and makes qi gathering difficult."
            case "丙": return "True needle yang fire in prosperity; brings wealth and enduring fortune, highly auspicious."
            case "丁": return "Yin fire well-positioned; flourishing prosperity and honor, highly auspicious."
            case "戊": return "Yellow 5 turtle-shell void; brings misfortune and prolonged illness, strictly avoid!"
            case "己": return "Yin earth void; leads to loss and decline, geomancers should never select this line."
            case "庚": return "Yang metal in prosperity; martial nobility and broad authority, highly auspicious."
            case "辛": return "Pure yin metal; refined culture and great abundance, highly auspicious."
            case "壬": return "Floating water lone-void sha; loss of both family vitality and wealth, do not violate."
            case "癸": return "Degree of retreating qi; difficult to prosper or maintain responsibility."
            default: return "Neutral balanced qi; use standard judgment."
            }
        case .ja:
            switch firstStem {
            case "甲": return "孤虚の煞気、冷退破財を招き人丁凋零す。立向に適さず。"
            case "乙": return "陰気過重、密かな損財を招き集気困難なり。"
            case "丙": return "正針陽火旺相、招財進宝にして富貴久遠、大吉として活用可。"
            case "丁": return "陰火得位、人財両旺、科甲連登にして大吉活用可。"
            case "戊": return "五黄土煞亀甲大空亡、横禍官非・病気衰弱を招く。厳禁すべし！"
            case "己": return "陰土空亡衰絶、後継衰退を主る。地師慎んで用いるべからず！"
            case "庚": return "陽金生旺、武貴栄達にして威勢四方に轟く、大吉活用可。"
            case "辛": return "陰金純正、文雅富厚にして金玉満堂、大吉活用可。"
            case "壬": return "水泛木浮の孤虚煞、人財倶に空亡す。慎みて犯すなかれ。"
            case "癸": return "退気の度、発展困難にして大任に耐え難し。"
            default: return "気場平穏にして常規の判定に従う。"
            }
        case .ko:
            switch firstStem {
            case "甲": return "고허살기(孤虛煞氣), 냉퇴파재와 인구 조령을 주관하므로 입향에 불가함."
            case "乙": return "음기가 지나쳐 암암리에 재물을 소모하고 기를 모으기 어려움."
            case "丙": return "정침 양화가 왕상하여 재물을 부르고 부귀가 영원하여 대길함."
            case "丁": return "음화가 득위하여 인재와 재물이 모두 번창하고 과거급제하여 대길함."
            case "戊": return "오황토살 귀갑대공망으로 재화와 관재, 오랜 병환을 부르니 엄히 피할 것!"
            case "己": return "음토 공망패절로 후손 단절과 쇠락을 부르니 지사는 결코 놓지 말 것!"
            case "庚": return "양금이 생왕하여 무귀로 현달하고 사방에 위세를 떨치니 대길함."
            case "辛": return "음금이 순정하여 문아부후하고 금옥이 만당하니 대길함."
            case "壬": return "수범목부 고허살로 인재와 재물이 모두 비니 범하지 말 것."
            case "癸": return "퇴기의 도수로 발전하기 어렵고 큰 책임을 감당하기 어려움."
            default: return "기운이 평온하여 일반적인 판단을 따름."
            }
        case .vi:
            switch firstStem {
            case "甲": return "Sát khí cô hư, chủ thoái tài tổn đinh, suy bại không nên lập hướng."
            case "乙": return "Âm khí quá nặng, chủ hao tán tài lộc, khó tụ khí lành."
            case "丙": return "Chính châm dương hỏa vượng tướng, chiêu tài tiến bảo, phú quý trường cửu, đại cát khả dụng."
            case "丁": return "Âm hỏa đắc vị, đinh tài lưỡng vượng, khoa giáp liên đăng, đại cát khả dụng."
            case "戊": return "Ngũ hoàng thổ sát quy giáp đại không vong, chủ hoạn nạn quan phi, bệnh tật triền miên, tối kỵ!"
            case "己": return "Âm thổ không vong bại tuyệt, chủ tuyệt tự suy bại, thầy phong thủy chớ khinh suất!"
            case "庚": return "Dương kim sinh vượng, võ quý hiển đạt, uy chấn bốn phương, đại cát khả dụng."
            case "辛": return "Âm kim thuần chính, văn nhã phú hậu, kim ngọc mãn đường, đại cát khả dụng."
            case "壬": return "Thủy phiếm mộc phù cô hư sát, đinh tài lưỡng không, cẩn thận chớ phạm."
            case "癸": return "Độ số thoái khí, khó nỗi phát vinh, khó đảm đương việc lớn."
            default: return "Khí trường bình ổn, vận dụng bình thường."
            }
        case .th:
            switch firstStem {
            case "甲": return "ไอพลังโดดเดี่ยวว่างเปล่า นำพาความเสื่อมถอยและสูญเสียทรัพย์ ไม่ควรตั้งทิศ"
            case "乙": return "พลังหยินหนักเกินไป ทำให้ทรัพย์สินรั่วไหลอย่างเงียบๆ กักเก็บพลังยาก"
            case "丙": return "ธาตุไฟหยางเข็มตรงรุ่งเรือง เรียกทรัพย์สินเงินทอง ร่ำรวยยั่งยืน มหามงคลใช้ได้"
            case "丁": return "ธาตุไฟหยินได้ตำแหน่ง ทรัพย์และครอบครัวเจริญรุ่งเรือง มหามงคลใช้ได้"
            case "戊": return "ดาวเบญจดินกระดองเต่าอวมงคล เกิดคดีความและเจ็บป่วยเรื้อรัง ต้องหลีกเลี่ยงเด็ดขาด!"
            case "己": return "ธาตุดินหยินสูญสิ้น ดับสูญและเสื่อมถอย ซินแสพึงระวังอย่าใช้!"
            case "庚": return "ธาตุทองหยางรุ่งเรือง เจริญในยศศักดิ์และอำนาจ มหามงคลใช้ได้"
            case "辛": return "ธาตุทองหยินบริสุทธิ์ สง่างามร่ำรวย เงินทองเต็มเรือน มหามงคลใช้ได้"
            case "壬": return "น้ำพัดไม้ลอยพลังโดดเดี่ยว ทั้งคนและทรัพย์สูญเปล่า ระวังอย่าละเมิด"
            case "癸": return "องศาพลังถดถอย เติบโตยาก ไม่อาจแบกรับภาระใหญ่หลวงได้"
            default: return "พลังงานสมดุล ใช้การประเมินทิศตามปกติ"
            }
        case .id:
            switch firstStem {
            case "甲": return "Energi sha kesepian kosong; menandakan kemunduran rezeki dan kelemahan keluarga. Hindari arah ini."
            case "乙": return "Energi yin berlebihan; menyebabkan kebocoran rezeki tersembunyi dan sulit mengumpulkan qi."
            case "丙": return "Jarum sejati api yang makmur; menarik kemakmuran dan kekayaan abadi, sangat menguntungkan."
            case "丁": return "Api yin pada posisi tepat; keluarga dan rezeki makmur, sangat menguntungkan."
            case "戊": return "Bintang 5 tanah kekosongan kura-kura; membawa musibah dan penyakit berkepanjangan, hindari keras!"
            case "己": return "Tanah yin kehancuran; membawa kepunahan dan kemunduran, geomancer jangan gunakan!"
            case "庚": return "Logam yang makmur; kemuliaan keberanian dan kewibawaan besar, sangat menguntungkan."
            case "辛": return "Logam yin murni; elegan, makmur, dan berlimpah emas permata, sangat menguntungkan."
            case "壬": return "Air banjir sha terasing; kehilangan keluarga dan rezeki, berhati-hatilah."
            case "癸": return "Derajat energi mundur; sulit berkembang dan menanggung tanggung jawab besar."
            default: return "Energi seimbang; gunakan penilaian biasa."
            }
        default:
            return lore
        }
    }

    private var classicalSourceNote: String {
        let original = "\(lore)"
        let originalHant = original
            .replacingOccurrences(of: "财", with: "財")
            .replacingOccurrences(of: "气", with: "氣")
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return "Source: traditional 120 Fenjin compass formula (wording varies by transmitted edition). Original wording recorded for this line: ‘\(original)’. Interpretation: references to illness, vitality, family or wealth belong to traditional geomantic symbolism; they are not medical, safety or financial predictions."
        case .zhHant:
            return "出处：传统罗盘一百二十分金口诀（传本有异文）。本分金收录原文：「\(originalHant)」。解释：其中疾病、元气、丁口与财帛语句属于传统堪舆象征，不是医疗、居住安全或财务预测。"
        case .ja:
            return "出典：伝承本に異文のある伝統羅盤一百二十分金口訣。本線の原文：「\(original)」。解釈：病・活力・家族・財に関する語は伝統風水の象徴であり、医学・安全・金融の予測ではありません。"
        case .ko:
            return "출처: 전승본에 이문이 있는 전통 나침반 120분금 구결. 이 선에 기록된 원문: ‘\(original)’. 해석: 질병·활력·가족·재물 표현은 전통 풍수의 상징이며 의료·안전·재무 예측이 아닙니다."
        case .vi:
            return "Nguồn: khẩu quyết La Bàn Phân Kim 120 truyền thống (các bản truyền có dị văn). Nguyên văn của tuyến này: ‘\(original)’. Giải thích: các từ về bệnh tật, sinh lực, gia đình và tài lộc là biểu tượng phong thủy truyền thống, không phải dự đoán y tế, an toàn hay tài chính."
        case .th:
            return "ที่มา: เคล็ดวิชา 120 เฟินจินของเข็มทิศแบบดั้งเดิม (แต่ละฉบับอาจมีถ้อยคำต่างกัน) ข้อความต้นฉบับของเส้นนี้: ‘\(original)’ คำอธิบาย: ถ้อยคำเรื่องความเจ็บป่วย พลังชีวิต ครอบครัว และทรัพย์สินเป็นสัญลักษณ์ทางฮวงจุ้ย ไม่ใช่การพยากรณ์ทางการแพทย์ ความปลอดภัย หรือการเงิน"
        case .id:
            return "Sumber: rumus kompas Fenjin 120 tradisional (redaksi berbeda menurut naskah). Teks asli untuk garis ini: ‘\(original)’. Penjelasan: istilah penyakit, vitalitas, keluarga, dan rezeki adalah simbolisme geomansi tradisional, bukan prediksi medis, keselamatan, atau keuangan."
        case .auto, .zhHans:
            return "出处：传统罗盘一百二十分金口诀（传本有异文）。本分金收录原文：“\(original)”。解释：其中疾病、元气、丁口与财帛语句属于传统堪舆象征，不是医疗、居住安全或财务预测。"
        }
    }
}

public class Fenjin120Data {
    public static let shared = Fenjin120Data()
    
    public let allFenjin: [FenjinItem]
    
    // 二十四山正针名称与起止角度 (每山 15 度，坎宫子山从 352.5° 至 7.5°)
    // 120 分金每位 3 度
    private let stemTypes: [String: (grade: String, ji: Bool, lore: String)] = [
        "甲": ("孤虚差错", false, "孤虚煞气，主冷退破财，丁口凋零，不宜立向。"),
        "乙": ("差错退财", false, "阴气过重，主暗耗损财，难以聚气。"),
        "丙": ("旺相大吉", true, "正针阳火旺相，招财进宝，富贵绵远，大吉可用。"),
        "丁": ("旺相大吉", true, "阴火得位，丁财两旺，科甲联登，大吉可用。"),
        "戊": ("龟甲空亡", false, "五黄土煞龟甲大空亡，主横祸官非、病榻缠绵，切忌犯之！"),
        "己": ("龟甲空亡", false, "阴土空亡败绝，主绝嗣衰败，地师慎勿轻下！"),
        "庚": ("旺相大吉", true, "阳金生旺，武贵显达，威震四方，大吉可用。"),
        "辛": ("旺相大吉", true, "阴金纯正，文雅富厚，金玉满堂，大吉可用。"),
        "壬": ("孤虚差错", false, "水泛木浮孤虚煞，丁财两空，慎莫相犯。"),
        "癸": ("差错退气", false, "退气之度，难以发皇，难当大任。")
    ]
    
    private init() {
        var items: [FenjinItem] = []
        let mountains = Mountain24Data.shared.mountains
        
        // Each mountain contains five same-branch 120-fen-jin degrees.
        // The previous sequential 60-cycle assigned 子山 as 甲子/乙丑/…,
        // which mixed branches inside one mountain.  Generate the valid five
        // Jiazi combinations from the mountain's three-mountain branch group.
        let branchGroups = [0, 1, 3, 4, 6, 7, 9, 10]
        let branchNames = ["子", "丑", "卯", "辰", "午", "未", "酉", "戌"]
        let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        
        for m in mountains {
            let group = min(max(m.id / 3, 0), branchGroups.count - 1)
            let branchIndex = branchGroups[group]
            let branch = branchNames[group]
            let firstStemIndex = branchIndex % 2
            for i in 0..<5 {
                let jiazi = "\(stems[firstStemIndex + i * 2])\(branch)"
                let startA = (m.startAngle + Double(i) * 3.0).truncatingRemainder(dividingBy: 360)
                let endA = (m.startAngle + Double(i + 1) * 3.0).truncatingRemainder(dividingBy: 360)
                let centerA = (m.startAngle + Double(i) * 3.0 + 1.5).truncatingRemainder(dividingBy: 360)
                
                let firstChar = String(jiazi.prefix(1))
                let meta = stemTypes[firstChar] ?? ("平稳", false, "气场平平")
                
                items.append(FenjinItem(
                    mountainName: m.name,
                    index: i + 1,
                    jiaziName: jiazi,
                    startAngle: startA,
                    endAngle: endA,
                    centerAngle: centerA,
                    grade: meta.grade,
                    isAuspicious: meta.ji,
                    lore: meta.lore
                ))
            }
        }
        self.allFenjin = items
    }
    
    // 根据方位角实时检索匹配当前精确分金
    public func resolveFenjin(for angle: Double) -> FenjinItem {
        let normAngle = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        for item in allFenjin {
            if item.startAngle < item.endAngle {
                if normAngle >= item.startAngle && normAngle < item.endAngle {
                    return item
                }
            } else {
                // 跨越 0°/360° 正北子山分金
                if normAngle >= item.startAngle || normAngle < item.endAngle {
                    return item
                }
            }
        }
        // The table is generated from the fixed 24-mountain data and should
        // never be empty, but keep the lookup total so a future data change
        // cannot crash the compass at runtime.
        return allFenjin.first ?? FenjinItem(
            mountainName: "子",
            index: 1,
            jiaziName: "甲子",
            startAngle: 0,
            endAngle: 3,
            centerAngle: 1.5,
            grade: "平稳",
            isAuspicious: false,
            lore: "气场平平"
        )
    }
}
