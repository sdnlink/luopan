import Foundation

// MARK: - 天星择日与动土安门日课自检引擎 (ZeRi Engine - PRD 动土神煞与日课排盘)

public struct ZeRiAnalysis {
    public let fourPillarsText: String
    /// 两字中文日柱（如 甲子），与 fourPillarsText 同源于本地日历日期 + 23 点子初换日。
    /// 供小组件等调用方显示单一日柱，避免另用真太阳时口径造成矛盾。
    public let dayPillar: String
    public var localizedDayPillar: String {
        SolarTimeCalculator.localizedDayPillar(dayPillar)
    }
    public let overallStatus: String
    public let isAuspicious: Bool
    public let suiPoWarning: String?
    public let yuePoWarning: String?
    /// True day/year/month San Sha calculation is not part of this lightweight
    /// checker yet. Keep this nil rather than labelling a sitting-mountain
    /// clash as San Sha.
    public let sanShaWarning: String?
    /// Day branch clash with the selected sitting mountain.
    public let sittingClashWarning: String?
    public let detailsText: String
    public let yiActivities: [String]
    public let jiActivities: [String]
}

public final class ZeRiEngine {
    public static let shared = ZeRiEngine()
    
    private let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    
    // 地支六冲
    private let clashMap: [String: String] = [
        "子": "午", "午": "子",
        "丑": "未", "未": "丑",
        "寅": "申", "申": "寅",
        "卯": "酉", "酉": "卯",
        "辰": "戌", "戌": "辰",
        "巳": "亥", "亥": "巳"
    ]
    
    public func analyze(sitting: Mountain24Item, date: Date = Date()) -> ZeRiAnalysis {
        return analyze(date: date, sitting: sitting)
    }

    /// 通用日课：不含坐山冲克判定，供小组件等没有现场坐向的场景使用。
    /// 调用方必须在 UI 上标注「未含坐山冲克」，不得把结果解读为某一宅的坐向结论。
    public func analyzeGeneralDay(date: Date = Date()) -> ZeRiAnalysis {
        return analyze(date: date, sitting: nil)
    }

    /// sitting 传 nil 时只按岁破 / 月破与四柱判读，跳过坐山冲克。
    public func analyze(date: Date, sitting: Mountain24Item?) -> ZeRiAnalysis {
        var calendar = Calendar(identifier: .gregorian)
        // Date is an absolute instant; all selectable-day pillars must use
        // the user's civil time zone so a late-night local date is not shifted
        // to the previous/next day by a GMT calendar.
        calendar.timeZone = .current
        let comp = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let now = Date()
        let year = comp.year ?? calendar.component(.year, from: now)
        let month = comp.month ?? calendar.component(.month, from: now)
        let day = comp.day ?? calendar.component(.day, from: now)
        let hour = comp.hour ?? calendar.component(.hour, from: now)

        // 子初 begins at 23:00 in the traditional day-pillar convention.
        // Keep year/month pillars on the original solar-term date, while the
        // day pillar advances at 子初 instead of waiting until civil midnight.
        let dayPillarDate = hour >= 23 ? (calendar.date(byAdding: .day, value: 1, to: date) ?? date) : date
        let dayPillarComp = calendar.dateComponents([.year, .month, .day], from: dayPillarDate)
        
        let lang = LocalizationManager.shared.effectiveLanguage
        
        // 1. 年柱干支 (严格遵循立春交岁天干地支更迭法则)
        let termIndex = SolarTimeCalculator.shared.solarTermIndex(for: date)
        let isBeforeLiChun = SolarTimeCalculator.shared.isBeforeLiChun(for: date)
        let gzYear = isBeforeLiChun ? (year - 1) : year
        let yOffset = (gzYear - 4) % 60
        let yearStem = stems[((yOffset % 10) + 10) % 10]
        let yearBranch = branches[((yOffset % 12) + 12) % 12]
        
        // 2. 月柱干支 (五虎遁年起月诀)。月界按节气切换，不能直接用
        // 公历月份；例如立春前仍属丑月，惊蛰后才进入卯月。
        let mBranchIdx: Int
        if termIndex < 2 {
            mBranchIdx = 1 // 小寒、大寒：丑月
        } else {
            mBranchIdx = (2 + (termIndex - 2) / 2) % 12
        }
        let mBranch = branches[mBranchIdx]
        let stemIdx = stems.firstIndex(of: yearStem) ?? 0
        let mStemStart = (stemIdx % 5) * 2 + 2
        let mStem = stems[(mStemStart + (mBranchIdx - 2 + 12) % 12) % 10]
        
        // 3. 日柱干支 (高精度儒略日算法)
        let pillarYear = dayPillarComp.year ?? year
        let pillarMonth = dayPillarComp.month ?? month
        let pillarDay = dayPillarComp.day ?? day
        let a = (14 - pillarMonth) / 12
        let y = pillarYear + 4800 - a
        let m = pillarMonth + 12 * a - 3
        let jdn = pillarDay + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
        let dayGZIndex = (jdn + 49) % 60
        let dayStem = stems[dayGZIndex % 10]
        let dayBranch = branches[dayGZIndex % 12]
        
        // 4. 时柱干支 (五鼠遁日起时诀)
        let hBranchIdx = ((hour + 1) / 2) % 12
        let hBranch = branches[hBranchIdx]
        let dStemIdx = stems.firstIndex(of: dayStem) ?? 0
        let hStemStart = (dStemIdx % 5) * 2
        let hStem = stems[(hStemStart + hBranchIdx) % 10]
        
        let pillars: String
        switch lang {
        case .en:
            let pinyinStems = ["甲": "Jia", "乙": "Yi", "丙": "Bing", "丁": "Ding", "戊": "Wu", "己": "Ji", "庚": "Geng", "辛": "Xin", "壬": "Ren", "癸": "Gui"]
            let pinyinBranches = ["子": "Zi", "丑": "Chou", "寅": "Yin", "卯": "Mao", "辰": "Chen", "巳": "Si", "午": "Wu", "未": "Wei", "申": "Shen", "酉": "You", "戌": "Xu", "亥": "Hai"]
            let yStr = "\(pinyinStems[yearStem] ?? yearStem)-\(pinyinBranches[yearBranch] ?? yearBranch)"
            let mStr = "\(pinyinStems[mStem] ?? mStem)-\(pinyinBranches[mBranch] ?? mBranch)"
            let dStr = "\(pinyinStems[dayStem] ?? dayStem)-\(pinyinBranches[dayBranch] ?? dayBranch)"
            let hStr = "\(pinyinStems[hStem] ?? hStem)-\(pinyinBranches[hBranch] ?? hBranch)"
            pillars = "\(yStr) Year · \(mStr) Month · \(dStr) Day · \(hStr) Hour"
        case .zhHant, .ja:
            pillars = "\(yearStem)\(yearBranch)年 \(mStem)\(mBranch)月 \(dayStem)\(dayBranch)日 \(hStem)\(hBranch)時"
        case .ko:
            let koStems = ["甲": "갑", "乙": "을", "丙": "병", "丁": "정", "戊": "무", "己": "기", "庚": "경", "辛": "신", "壬": "임", "癸": "계"]
            let koBranches = ["子": "자", "丑": "축", "寅": "인", "卯": "묘", "辰": "진", "巳": "사", "午": "오", "未": "미", "申": "신", "酉": "유", "戌": "술", "亥": "해"]
            let yStr = "\(koStems[yearStem] ?? yearStem)\(koBranches[yearBranch] ?? yearBranch)년"
            let mStr = "\(koStems[mStem] ?? mStem)\(koBranches[mBranch] ?? mBranch)월"
            let dStr = "\(koStems[dayStem] ?? dayStem)\(koBranches[dayBranch] ?? dayBranch)일"
            let hStr = "\(koStems[hStem] ?? hStem)\(koBranches[hBranch] ?? hBranch)시"
            pillars = "\(yStr) \(mStr) \(dStr) \(hStr)"
        case .vi:
            let viStems = ["甲": "Giáp", "乙": "Ất", "丙": "Bính", "丁": "Đinh", "戊": "Mậu", "己": "Kỷ", "庚": "Canh", "辛": "Tân", "壬": "Nhâm", "癸": "Quý"]
            let viBranches = ["子": "Tý", "丑": "Sửu", "寅": "Dần", "卯": "Mão", "辰": "Thìn", "巳": "Tỵ", "午": "Ngọ", "未": "Mùi", "申": "Thân", "酉": "Dậu", "戌": "Tuất", "亥": "Hợi"]
            let yStr = "\(viStems[yearStem] ?? yearStem) \(viBranches[yearBranch] ?? yearBranch) năm"
            let mStr = "\(viStems[mStem] ?? mStem) \(viBranches[mBranch] ?? mBranch) tháng"
            let dStr = "\(viStems[dayStem] ?? dayStem) \(viBranches[dayBranch] ?? dayBranch) ngày"
            let hStr = "\(viStems[hStem] ?? hStem) \(viBranches[hBranch] ?? hBranch) giờ"
            pillars = "\(yStr) · \(mStr) · \(dStr) · \(hStr)"
        case .th:
            let thStems = ["甲": "เจี่ย", "乙": "อี้", "丙": "ปิ่ง", "丁": "ติง", "戊": "อู่", "己": "จี่", "庚": "เกิง", "辛": "ซิน", "壬": "เหริน", "癸": "กุ่ย"]
            let thBranches = ["子": "จื่อ", "丑": "โฉ่ว", "寅": "หยิน", "卯": "เหมา", "辰": "เฉิน", "巳": "ซื่อ", "午": "อู่", "未": "เว่ย", "申": "เซิน", "酉": "โหย่ว", "戌": "ซวี", "亥": "ฮ่าย"]
            let yStr = "ปี \(thStems[yearStem] ?? yearStem)-\(thBranches[yearBranch] ?? yearBranch)"
            let mStr = "เดือน \(thStems[mStem] ?? mStem)-\(thBranches[mBranch] ?? mBranch)"
            let dStr = "วัน \(thStems[dayStem] ?? dayStem)-\(thBranches[dayBranch] ?? dayBranch)"
            let hStr = "ยาม \(thStems[hStem] ?? hStem)-\(thBranches[hBranch] ?? hBranch)"
            pillars = "\(yStr) · \(mStr) · \(dStr) · \(hStr)"
        case .id:
            let pinyinStems = ["甲": "Jia", "乙": "Yi", "丙": "Bing", "丁": "Ding", "戊": "Wu", "己": "Ji", "庚": "Geng", "辛": "Xin", "壬": "Ren", "癸": "Gui"]
            let pinyinBranches = ["子": "Zi", "丑": "Chou", "寅": "Yin", "卯": "Mao", "辰": "Chen", "巳": "Si", "午": "Wu", "未": "Wei", "申": "Shen", "酉": "You", "戌": "Xu", "亥": "Hai"]
            let yStr = "Thn \(pinyinStems[yearStem] ?? yearStem)-\(pinyinBranches[yearBranch] ?? yearBranch)"
            let mStr = "Bln \(pinyinStems[mStem] ?? mStem)-\(pinyinBranches[mBranch] ?? mBranch)"
            let dStr = "Hr \(pinyinStems[dayStem] ?? dayStem)-\(pinyinBranches[dayBranch] ?? dayBranch)"
            let hStr = "Jam \(pinyinStems[hStem] ?? hStem)-\(pinyinBranches[hBranch] ?? hBranch)"
            pillars = "\(yStr) · \(mStr) · \(dStr) · \(hStr)"
        case .auto, .zhHans:
            pillars = "\(yearStem)\(yearBranch)年 \(mStem)\(mBranch)月 \(dayStem)\(dayBranch)日 \(hStem)\(hBranch)时"
        }
        
        // 5. 神煞冲克判定
        var warnings: [String] = []
        var suiPo: String? = nil
        var yuePo: String? = nil
        var sittingClash: String? = nil

        let enBranches = ["子": "Zi", "丑": "Chou", "寅": "Yin", "卯": "Mao", "辰": "Chen", "巳": "Si", "午": "Wu", "未": "Wei", "申": "Shen", "酉": "You", "戌": "Xu", "亥": "Hai"]
        let koBranchesMap = ["子": "자", "丑": "축", "寅": "인", "卯": "묘", "辰": "진", "巳": "사", "午": "오", "未": "미", "申": "신", "酉": "유", "戌": "술", "亥": "해"]
        let viBranchesMap = ["子": "Tý", "丑": "Sửu", "寅": "Dần", "卯": "Mão", "辰": "Thìn", "巳": "Tỵ", "午": "Ngọ", "未": "Mùi", "申": "Thân", "酉": "Dậu", "戌": "Tuất", "亥": "Hợi"]
        let thBranchesMap = ["子": "จื่อ", "丑": "โฉ่ว", "寅": "หยิน", "卯": "เหมา", "辰": "เฉิน", "巳": "ซื่อ", "午": "อู่", "未": "เว่ย", "申": "เซิน", "酉": "โหย่ว", "戌": "ซวี", "亥": "ฮ่าย"]
        
        // 岁破冲煞：日支冲太岁年支
        if clashMap[dayBranch] == yearBranch {
            switch lang {
            case .en:
                suiPo = "Day branch (\(enBranches[dayBranch] ?? dayBranch)) clashes with Year Grand Duke (\(enBranches[yearBranch] ?? yearBranch)); Year Clash Taboo."
            case .zhHant:
                suiPo = "今日【\(dayBranch)日】直衝年支太歲【\(yearBranch)位】，犯【歲破大煞】，主百事不利。"
            case .ja:
                suiPo = "本日【\(dayBranch)日】が太歳【\(yearBranch)位】と直衝し、【歳破大煞】となります。"
            case .ko:
                suiPo = "오늘【\(koBranchesMap[dayBranch] ?? dayBranch)일】이 세차 태세【\(koBranchesMap[yearBranch] ?? yearBranch)위】와 직충하여 【세파대살】을 범합니다."
            case .vi:
                suiPo = "Hôm nay ngày 【\(viBranchesMap[dayBranch] ?? dayBranch)】 trực xung Thái Tuế năm 【\(viBranchesMap[yearBranch] ?? yearBranch)】, phạm 【Tuế Phá Đại Sát】."
            case .th:
                suiPo = "วันนี้กิ่งดินวัน【\(thBranchesMap[dayBranch] ?? dayBranch)】ปะทะไท่ส่วยประจำปี【\(thBranchesMap[yearBranch] ?? yearBranch)】 ติดขัดเคราะห์【ส่วยพั่ว】"
            case .id:
                suiPo = "Cabang hari (\(enBranches[dayBranch] ?? dayBranch)) bentrok dengan Tai Sui tahunan (\(enBranches[yearBranch] ?? yearBranch)); Tabu Benturan Tahun."
            case .auto, .zhHans:
                suiPo = "今日【\(dayBranch)日】直冲年支太岁【\(yearBranch)位】，犯【岁破大煞】，主百事不利。"
            }
            if let suiPo = suiPo { warnings.append(suiPo) }
        }
        
        // 月破冲煞：日支冲当令月支
        if clashMap[dayBranch] == mBranch {
            switch lang {
            case .en:
                yuePo = "Day branch (\(enBranches[dayBranch] ?? dayBranch)) clashes with Month Commander (\(enBranches[mBranch] ?? mBranch)); Month Clash Taboo."
            case .zhHant:
                yuePo = "今日【\(dayBranch)日】直衝月令月建【\(mBranch)位】，犯【月破大耗】，凡事避忌。"
            case .ja:
                yuePo = "本日【\(dayBranch)日】が月建【\(mBranch)位】と直衝し、【月破大耗】となります。"
            case .ko:
                yuePo = "오늘【\(koBranchesMap[dayBranch] ?? dayBranch)일】이 월령 월건【\(koBranchesMap[mBranch] ?? mBranch)위】과 직충하여 【월파대모】를 범합니다."
            case .vi:
                yuePo = "Hôm nay ngày 【\(viBranchesMap[dayBranch] ?? dayBranch)】 trực xung Nguyệt Lệnh 【\(viBranchesMap[mBranch] ?? mBranch)】, phạm 【Nguyệt Phá Đại Hao】."
            case .th:
                yuePo = "วันนี้กิ่งดินวัน【\(thBranchesMap[dayBranch] ?? dayBranch)】ปะทะประจำเดือน【\(thBranchesMap[mBranch] ?? mBranch)】 ติดขัดเคราะห์【เยว่พั่ว】"
            case .id:
                yuePo = "Cabang hari (\(enBranches[dayBranch] ?? dayBranch)) bentrok dengan Penguasa Bulan (\(enBranches[mBranch] ?? mBranch)); Tabu Benturan Bulan."
            case .auto, .zhHans:
                yuePo = "今日【\(dayBranch)日】直冲月令月建【\(mBranch)位】，犯【月破大耗】，凡事避忌。"
            }
            if let yuePo = yuePo { warnings.append(yuePo) }
        }
        
        // 坐山冲犯：二十四山归并到对应十二地支。
        // 地元山用本支；天元山(乾坤艮巽)归本宫地元(戌/未/丑/辰)；
        // 人元山用自身地支(癸→子、寅→寅、乙→卯、巳→巳、丁→午、申→申、辛→酉、亥→亥)。
        let mountainBranch: [String: String] = [
            "壬": "子", "子": "子", "癸": "子",
            "丑": "丑", "艮": "丑", "寅": "寅",
            "甲": "卯", "卯": "卯", "乙": "卯",
            "辰": "辰", "巽": "辰", "巳": "巳",
            "丙": "午", "午": "午", "丁": "午",
            "未": "未", "坤": "未", "申": "申",
            "庚": "酉", "酉": "酉", "辛": "酉",
            "戌": "戌", "乾": "戌", "亥": "亥"
        ]
        let sittingBranch = mountainBranch[sitting?.name ?? ""] ?? ""
        if let sitting = sitting, let sClash = clashMap[sittingBranch], sClash == dayBranch {
            switch lang {
            case .en:
                sittingClash = "Day branch (\(enBranches[dayBranch] ?? dayBranch)) clashes with House Sitting Mountain (\(sitting.localizedName)); Sitting Clash Taboo."
            case .zhHant:
                sittingClash = "今日日支【\(dayBranch)】直衝本宅坐山【\(sitting.localizedName)山】，犯【衝山大忌】，切勿動土安門！"
            case .ja:
                sittingClash = "本日の日支【\(dayBranch)】が坐山【\(sitting.localizedName)山】と直衝し、【衝山大忌】に該当します。"
            case .ko:
                sittingClash = "오늘 일진【\(koBranchesMap[dayBranch] ?? dayBranch)】이 좌산【\(sitting.localizedName)산】과 직충하여 【충산대기】를 범하니 동토와 안문을 피하세요!"
            case .vi:
                sittingClash = "Hôm nay chi ngày 【\(viBranchesMap[dayBranch] ?? dayBranch)】 trực xung Tọa sơn 【\(sitting.localizedName)】 phạm 【Xung Sơn Đại Kỵ】!"
            case .th:
                sittingClash = "กิ่งดินวัน【\(thBranchesMap[dayBranch] ?? dayBranch)】ปะทะทิศพิงบ้าน【\(sitting.localizedName)】 ต้องห้ามการลงเสาเอกตั้งประตูเด็ดขาด!"
            case .id:
                sittingClash = "Cabang hari (\(enBranches[dayBranch] ?? dayBranch)) bentrok dengan Gunung Sandaran (\(sitting.localizedName)); Hindari renovasi dan pasang pintu!"
            case .auto, .zhHans:
                sittingClash = "今日日支【\(dayBranch)】直冲本宅坐山【\(sitting.name)山】，犯【冲山大忌】，切勿动土安门！"
            }
            if let sittingClash = sittingClash { warnings.append(sittingClash) }
        }
        
        let isAuspicious = warnings.isEmpty
        let status: String
        switch lang {
        case .en:
            status = isAuspicious ? "Auspicious Day" : "Clash Detected"
        case .zhHant:
            status = isAuspicious ? "今日日課吉" : "動土神煞有衝"
        case .ja:
            status = isAuspicious ? "本日吉日" : "神煞の衝あり"
        case .ko:
            status = isAuspicious ? "오늘의 일과 길" : "신살 충돌 감지"
        case .vi:
            status = isAuspicious ? "Nhật khóa cát lợi" : "Thần sát tương xung"
        case .th:
            status = isAuspicious ? "ฤกษ์วันนี้เป็นมงคล" : "มีดาวเทพปะทะ"
        case .id:
            status = isAuspicious ? "Hari Ini Menguntungkan" : "Benturan Sha Terdeteksi"
        case .auto, .zhHans:
            status = isAuspicious ? "今日日课吉" : "动土神煞有冲"
        }
        
        let details: String
        if isAuspicious {
            switch lang {
            case .en:
                details = "Sitting Mountain Sha: Free from Year/Month clash. Harmonious Four Pillars, ideal for construction and door installation."
            case .zhHant:
                details = "坐向神煞：無歲破、無月破、無坐向衝克。四柱比和合化，宜修造動土、安門立向。"
            case .ja:
                details = "坐向神煞：歳破・月破・坐向の衝克なし。四柱が調和し、改修や動土、門の設置に好適です。"
            case .ko:
                details = "좌향신살: 세파, 월파, 좌향 충극이 없습니다. 사주가 조화로워 동토, 안문, 수리에 이상적입니다."
            case .vi:
                details = "Thần sát tọa hướng: Không phạm Tuế Phá, Nguyệt Phá, Tọa Hướng tương xung. Tứ trụ hòa hợp, cát lợi cho động thổ an môn."
            case .th:
                details = "เทพดาวทิศพิง: ไร้เคราะห์ส่วยพั่วและเยว่พั่ว สี่เสาประสานกลมกลืน เหมาะแก่การลงเสาเอกและตั้งประตู"
            case .id:
                details = "Sha Gunung Sandaran: Bebas dari benturan tahun/bulan. Empat Pilar selaras, ideal untuk renovasi dan pasang pintu."
            case .auto, .zhHans:
                details = "坐向神煞：无岁破、无月破、无坐向冲克。四柱比和合化，宜修造动土、安门立向。"
            }
        } else {
            details = warnings.joined(separator: " ")
        }
        
        let yi: [String]
        let ji: [String]
        switch lang {
        case .en:
            yi = isAuspicious ? ["Groundbreaking", "Door Installation", "Housewarming", "Business Opening"] : ["Meditation", "Spiritual Cultivation"]
            ji = isAuspicious ? ["Excavation near graves", "Aggressive Acts"] : ["Construction", "Door Installation", "Moving In"]
        case .zhHant:
            yi = isAuspicious ? ["動土起造", "安門修方", "入宅安香", "開業祈福"] : ["靜思祈禱", "祭祀修心"]
            ji = isAuspicious ? ["破土開生墳", "暴烈行事"] : ["修造動土", "安門立向", "入宅開張"]
        case .ja:
            yi = isAuspicious ? ["地鎮祭・動土", "門の設置", "引越し入宅", "開店・祈福"] : ["静思・瞑想", "祭祀・修養"]
            ji = isAuspicious ? ["墓地造成", "激しい争い"] : ["修繕・動土", "門の設置", "入宅・開業"]
        case .ko:
            yi = isAuspicious ? ["동토 기공", "안문 수방", "입택 안향", "개업 기복"] : ["정사 기도", "제사 수심"]
            ji = isAuspicious ? ["파토 생분", "과격한 행동"] : ["수조 동토", "안문 입향", "입택 개업"]
        case .vi:
            yi = isAuspicious ? ["Động thổ khởi tạo", "An môn tu phương", "Nhập trạch an hương", "Khai trương cầu phúc"] : ["Tĩnh tâm cầu nguyện", "Tế tự tu tâm"]
            ji = isAuspicious ? ["Phá thổ khai phần", "Hành sự bạo liệt"] : ["Tu tạo động thổ", "An môn lập hướng", "Nhập trạch khai trương"]
        case .th:
            yi = isAuspicious ? ["ลงเสาเอกก่อสร้าง", "ตั้งประตูมงคล", "ขึ้นบ้านใหม่", "เปิดกิจการ"] : ["สงบจิตทำสมาธิ", "ไหว้พระขอพร"]
            ji = isAuspicious ? ["ขุดหลุมฝังศพ", "วิวาทรุนแรง"] : ["ก่อสร้างซ่อมแซม", "ตั้งประตู", "ย้ายเข้าอยู่"]
        case .id:
            yi = isAuspicious ? ["Peletakan Batu Pertama", "Pemasangan Pintu", "Pindah Rumah", "Pembukaan Usaha"] : ["Meditasi Tenang", "Ibadah Doa"]
            ji = isAuspicious ? ["Gali Makam", "Tindakan Kasar"] : ["Konstruksi Rumah", "Pasang Pintu", "Pindah Masuk"]
        case .auto, .zhHans:
            yi = isAuspicious ? ["动土起造", "安门修方", "入宅安香", "开业祈福"] : ["静思祈祷", "祭祀修心"]
            ji = isAuspicious ? ["破土开生坟", "暴烈行事"] : ["修造动土", "安门立向", "入宅开张"]
        }
        
        return ZeRiAnalysis(
            fourPillarsText: pillars,
            dayPillar: "\(dayStem)\(dayBranch)",
            overallStatus: status,
            isAuspicious: isAuspicious,
            suiPoWarning: suiPo,
            yuePoWarning: yuePo,
            sanShaWarning: nil,
            sittingClashWarning: sittingClash,
            detailsText: details,
            yiActivities: yi,
            jiActivities: ji
        )
    }
}
