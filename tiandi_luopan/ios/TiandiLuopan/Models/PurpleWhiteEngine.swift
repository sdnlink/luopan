import Foundation

// MARK: - 紫白九星流年流月客星动态气运与太岁三煞引擎 (PRD 第12章)

public struct PurpleWhitePalaceItem: Identifiable {
    public var id: Int { palaceId }
    public let palaceId: Int        // 洛书宫号 1..9
    public let palaceName: String    // "东南 巽"
    public let direction: String     // "东南"
    public let originalStar: Int     // 原旦盘/洛书本宫星
    public let yearGuestStar: Int    // 流年飞临客星 (1..9)
    public let monthGuestStar: Int   // 流月飞临客星 (1..9)
    public let starName: String      // 如 "五黄廉贞星"
    public let isDanger25: Bool      // 是否犯二五交加 / 五黄二黑大煞
    public let isTaiSui: Bool        // 是否为太岁方
    public let isSuiPo: Bool         // 是否为岁破方
    public let isSanSha: Bool        // 是否为三煞方
    public let advice: String        // 化解与催旺指南
}

public struct PurpleWhiteChart {
    public let year: Int
    public let month: Int
    public let yearCentralStar: Int
    public let monthCentralStar: Int
    public let currentFacingPalace: Int // 当前罗盘向首对应的洛书宫号
    public let taiSuiDescription: String
    public let suiPoDescription: String
    public let sanShaDescription: String
    public let palaceItems: [PurpleWhitePalaceItem]
}

public class PurpleWhiteEngine {
    public static let shared = PurpleWhiteEngine()
    
    // 洛书标准轨迹: [坎1, 坤2, 震3, 巽4, 中5, 乾6, 兑7, 艮8, 离9]
    private let luoshuOrder = [5, 6, 7, 8, 9, 1, 2, 3, 4]
    
    // 九宫网格展示次序 (东南4, 正南9, 西南2; 正东3, 中宫5, 正西7; 东北8, 正北1, 西北6)
    public let displayPalaceOrder = [4, 9, 2, 3, 5, 7, 8, 1, 6]
    
    private init() {}
    
    public func starName(for star: Int) -> String {
        guard star >= 1 && star <= 9 else { return "" }
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            let names = [
                "", "1-White Greedy Wolf", "2-Black Illness Star", "3-Jade Storage Wood", "4-Green Wenqu Wood",
                "5-Yellow Lianzhen Sha", "6-White Martial Metal", "7-Red Army Metal", "8-White Wealth Earth", "9-Purple Vital Fire"
            ]
            return names[star]
        case .zhHant:
            let names = [
                "", "一白貪狼水星", "二黑巨門土星(病符)", "三碧祿存木星", "四綠文曲木星",
                "五黃廉貞土星(大煞)", "六白武曲金星", "七赤破軍金星", "八白左輔土星", "九紫右弼火星"
            ]
            return names[star]
        case .ja:
            let names = [
                "", "一白貪狼水星", "二黒巨門土星(病符)", "三碧禄存木星", "四緑文曲木星",
                "五黄廉貞土星(大煞)", "六白武曲金星", "七赤破軍金星", "八白左輔土星", "九紫右弼火星"
            ]
            return names[star]
        case .ko:
            let names = [
                "", "일백 탐랑 수성", "이흑 거문 토성(병부)", "삼벽 녹존 목성", "사록 문곡 목성",
                "오황 염정 토성(대살)", "육백 무곡 금성", "칠적 파군 금성", "팔백 좌보 토성", "구자 우필 화성"
            ]
            return names[star]
        case .vi:
            let names = [
                "", "Nhất Bạch Tham Lang Thủy Tinh", "Nhị Hắc Cự Môn Thổ Tinh (Bệnh Phù)", "Tam Bích Lộc Tồn Mộc Tinh", "Tứ Lục Văn Khúc Mộc Tinh",
                "Ngũ Hoàng Liêm Trinh Thổ Tinh (Đại Sát)", "Lục Bạch Vũ Khúc Kim Tinh", "Thất Xích Phá Quân Kim Tinh", "Bát Bạch Tả Phụ Thổ Tinh", "Cửu Tử Hữu Bật Hỏa Tinh"
            ]
            return names[star]
        case .th:
            let names = [
                "", "ดาวหนึ่งขาว ทานหลาง ธาตุน้ำ", "ดาวสองดำ จวี้เหมิน ธาตุดิน (ดาวพยาธิ)", "ดาวสามเขียว ลู่ฉุน ธาตุไม้", "ดาวสี่เขียว เหวินชวี ธาตุไม้",
                "ดาวห้าเหลือง เหลียนเจิน ธาตุดิน (เคราะห์ใหญ่)", "ดาวหกขาว อู่ชวี ธาตุทอง", "ดาวเจ็ดแดง โพ่จวิน ธาตุทอง", "ดาวแปดขาว จั่วฝู่ ธาตุดิน", "ดาวเก้าม่วง โยวปี้ ธาตุไฟ"
            ]
            return names[star]
        case .id:
            let names = [
                "", "1-Putih Bintang Serigala Air", "2-Hitam Bintang Penyakit Tanah", "3-Hijau Bintang Kayu Giok", "4-Hijau Bintang Cendekia Kayu",
                "5-Kuning Bintang Petaka Tanah", "6-Putih Bintang Militer Logam", "7-Merah Bintang Tentara Logam", "8-Putih Bintang Rezeki Tanah", "9-Ungu Bintang Semarak Api"
            ]
            return names[star]
        case .auto, .zhHans:
            let names = [
                "", "一白贪狼水星", "二黑巨门土星(病符)", "三碧禄存木星", "四绿文曲木星",
                "五黄廉贞土星(大煞)", "六白武曲金星", "七赤破军金星", "八白左辅土星", "九紫右弼火星"
            ]
            return names[star]
        }
    }
    
    public func palaceDirection(palaceId: Int) -> String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            let dirs = [1: "North", 2: "Southwest", 3: "East", 4: "Southeast", 5: "Center", 6: "Northwest", 7: "West", 8: "Northeast", 9: "South"]
            return dirs[palaceId] ?? "Center"
        case .zhHant:
            let dirs = [1: "正北", 2: "西南", 3: "正東", 4: "東南", 5: "中宮", 6: "西北", 7: "正西", 8: "東北", 9: "正南"]
            return dirs[palaceId] ?? "中宮"
        case .ja:
            let dirs = [1: "正北", 2: "南西", 3: "正東", 4: "南東", 5: "中宮", 6: "北西", 7: "正西", 8: "北東", 9: "正南"]
            return dirs[palaceId] ?? "中宮"
        case .ko:
            let dirs = [1: "정북", 2: "남서", 3: "정동", 4: "동남", 5: "중궁", 6: "북서", 7: "정서", 8: "북동", 9: "정남"]
            return dirs[palaceId] ?? "중궁"
        case .vi:
            let dirs = [1: "Chính Bắc", 2: "Tây Nam", 3: "Chính Đông", 4: "Đông Nam", 5: "Trung Cung", 6: "Tây Bắc", 7: "Chính Tây", 8: "Đông Bắc", 9: "Chính Nam"]
            return dirs[palaceId] ?? "Trung Cung"
        case .th:
            let dirs = [1: "ทิศเหนือ", 2: "ทิศตะวันตกเฉียงใต้", 3: "ทิศตะวันออก", 4: "ทิศตะวันออกเฉียงใต้", 5: "จุดศูนย์กลาง", 6: "ทิศตะวันตกเฉียงเหนือ", 7: "ทิศตะวันตก", 8: "ทิศตะวันออกเฉียงเหนือ", 9: "ทิศใต้"]
            return dirs[palaceId] ?? "จุดศูนย์กลาง"
        case .id:
            let dirs = [1: "Utara", 2: "Barat Daya", 3: "Timur", 4: "Tenggara", 5: "Pusat", 6: "Barat Laut", 7: "Barat", 8: "Timur Laut", 9: "Selatan"]
            return dirs[palaceId] ?? "Pusat"
        case .auto, .zhHans:
            let dirs = [1: "正北", 2: "西南", 3: "正东", 4: "东南", 5: "中宫", 6: "西北", 7: "正西", 8: "东北", 9: "正南"]
            return dirs[palaceId] ?? "中宫"
        }
    }
    
    public func palaceFullName(palaceId: Int) -> String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            let full = [1: "North (Kan)", 2: "Southwest (Kun)", 3: "East (Zhen)", 4: "Southeast (Xun)", 5: "Center (Taiji)", 6: "Northwest (Qian)", 7: "West (Dui)", 8: "Northeast (Gen)", 9: "South (Li)"]
            return full[palaceId] ?? "Center"
        case .zhHant:
            let full = [1: "正北 坎宮", 2: "西南 坤宮", 3: "正東 震宮", 4: "東南 巽宮", 5: "中央 太極", 6: "西北 乾宮", 7: "正西 兌宮", 8: "東北 艮宮", 9: "正南 離宮"]
            return full[palaceId] ?? "中央 太極"
        case .ja:
            let full = [1: "正北 坎宮", 2: "南西 坤宮", 3: "正東 震宮", 4: "南東 巽宮", 5: "中央 太極", 6: "北西 乾宮", 7: "正西 兌宮", 8: "北東 艮宮", 9: "正南 離宮"]
            return full[palaceId] ?? "中央 太極"
        case .ko:
            let full = [1: "정북 감궁", 2: "남서 곤궁", 3: "정동 진궁", 4: "동남 손궁", 5: "중앙 태극", 6: "북서 건궁", 7: "정서 태궁", 8: "북동 간궁", 9: "정남 이궁"]
            return full[palaceId] ?? "중앙 태극"
        case .vi:
            let full = [1: "Chính Bắc (Khảm)", 2: "Tây Nam (Khôn)", 3: "Chính Đông (Chấn)", 4: "Đông Nam (Tốn)", 5: "Trung Cung (Thái Cực)", 6: "Tây Bắc (Càn)", 7: "Chính Tây (Đoài)", 8: "Đông Bắc (Cấn)", 9: "Chính Nam (Ly)"]
            return full[palaceId] ?? "Trung Cung (Thái Cực)"
        case .th:
            let full = [1: "ทิศเหนือ (ข่าน)", 2: "ทิศตะวันตกเฉียงใต้ (คุน)", 3: "ทิศตะวันออก (เจิ้น)", 4: "ทิศตะวันออกเฉียงใต้ (ซวิ่น)", 5: "จุดศูนย์กลาง (ไท่จี๋)", 6: "ทิศตะวันตกเฉียงเหนือ (เฉียน)", 7: "ทิศตะวันตก (ตุ้ย)", 8: "ทิศตะวันออกเฉียงเหนือ (เกิ้น)", 9: "ทิศใต้ (หลี)"]
            return full[palaceId] ?? "จุดศูนย์กลาง (ไท่จี๋)"
        case .id:
            let full = [1: "Utara (Kan)", 2: "Barat Daya (Kun)", 3: "Timur (Zhen)", 4: "Tenggara (Xun)", 5: "Pusat (Taiji)", 6: "Barat Laut (Qian)", 7: "Barat (Dui)", 8: "Timur Laut (Gen)", 9: "Selatan (Li)"]
            return full[palaceId] ?? "Pusat (Taiji)"
        case .auto, .zhHans:
            let full = [1: "正北 坎宫", 2: "西南 坤宫", 3: "正东 震宫", 4: "东南 巽宫", 5: "中央 太极", 6: "西北 乾宫", 7: "正西 兑宫", 8: "东北 艮宫", 9: "正南 离宫"]
            return full[palaceId] ?? "中央 太极"
        }
    }
    
    public func calcYearStar(year: Int) -> Int {
        var num = (11 - (year % 9)) % 9
        if num <= 0 { num += 9 }
        return num
    }
    
    public func calcMonthStar(year: Int, month: Int) -> Int {
        // 年支五虎遁确定月飞星入中
        // Gregorian year % 12 is not the earthly-branch index (for example,
        // 2024 is 甲辰, whose branch index is 4). Normalize from 甲子 4 CE.
        let branchIndex = ((year - 4) % 12 + 12) % 12
        var baseStar = 2
        if [0, 3, 6, 9].contains(branchIndex) { // 子午卯酉年
            baseStar = 8
        } else if [1, 4, 7, 10].contains(branchIndex) { // 辰戌丑未年
            baseStar = 5
        } else { // 寅申巳亥年
            baseStar = 2
        }
        var mStar = (baseStar - (month - 1)) % 9
        if mStar <= 0 { mStar += 9 }
        return mStar
    }
    
    public func flyStars(centralStar: Int) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for (step, targetPalace) in luoshuOrder.enumerated() {
            var s = (centralStar + step) % 9
            if s <= 0 { s += 9 }
            result[targetPalace] = s
        }
        return result
    }
    
    public func calculateChart(date: Date = Date(), heading: Double = 0.0) -> PurpleWhiteChart {
        let calendar = Calendar.current
        let rawYear = calendar.component(.year, from: date)
        let rawMonth = calendar.component(.month, from: date)
        let solarTermIndex = SolarTimeCalculator.shared.solarTermIndex(for: date)
        
        // 立春交岁按太阳黄经判断，避免固定 2 月 4 日在不同年份错位。
        let isBeforeLichun = SolarTimeCalculator.shared.isBeforeLiChun(for: date)
        let effectiveYear = isBeforeLichun ? (rawYear - 1) : rawYear
        
        // 流月按节气月界计算。界面保留公历一月的 1 月显示习惯，避免
        // 冬至桶把整个月标题显示成 12 月；客星计算则使用传统节气月，
        // 以寅月为正月（1），小寒、大寒归丑月（12）。
        let effectiveMonth: Int
        if rawMonth == 1 {
            effectiveMonth = 1
        } else if solarTermIndex < 2 {
            effectiveMonth = max(1, rawMonth - 1)
        } else {
            effectiveMonth = min(12, 2 + (solarTermIndex - 2) / 2)
        }
        let solarMonthForStar = solarTermIndex < 2
            ? 12
            : min(11, 1 + (solarTermIndex - 2) / 2)
        
        let yCenter = calcYearStar(year: effectiveYear)
        let mCenter = calcMonthStar(year: effectiveYear, month: solarMonthForStar)
        
        let yearStarsMap = flyStars(centralStar: yCenter)
        let monthStarsMap = flyStars(centralStar: mCenter)
        
        // 地支年对应太岁/岁破/三煞 (基于立春后真实年支)
        let zhiIndex = ((effectiveYear - 4) % 12 + 12) % 12
        let lang = LocalizationManager.shared.effectiveLanguage
        
        var taiSuiPalace = 9
        var suiPoPalace = 1
        var sanShaPalaces = [1]
        
        var taiSuiDesc = ""
        var suiPoDesc = ""
        var sanShaDesc = ""
        
        let baseConfigs: [Int: (tsP: Int, spP: Int, ssP: [Int])] = [
            0: (1, 9, [9]), 1: (8, 2, [3]), 2: (8, 2, [1]), 3: (3, 7, [7]),
            4: (4, 6, [9]), 5: (4, 6, [3]), 6: (9, 1, [1]), 7: (2, 8, [7]),
            8: (2, 8, [9]), 9: (7, 3, [3]), 10: (6, 4, [1]), 11: (6, 4, [7])
        ]
        let baseConf = baseConfigs[zhiIndex] ?? (9, 1, [1])
        taiSuiPalace = baseConf.tsP
        suiPoPalace = baseConf.spP
        sanShaPalaces = baseConf.ssP
        
        switch lang {
        case .en:
            let enConfig: [Int: (ts: String, sp: String, ss: String)] = [
                0: ("North (Zi)", "South (Wu)", "South (Si-Wu-Wei)"),
                1: ("Northeast (Chou)", "Southwest (Wei)", "East (Yin-Mao-Chen)"),
                2: ("Northeast (Yin)", "Southwest (Shen)", "North (Hai-Zi-Chou)"),
                3: ("East (Mao)", "West (You)", "West (Shen-You-Xu)"),
                4: ("Southeast (Chen)", "Northwest (Xu)", "South (Si-Wu-Wei)"),
                5: ("Southeast (Si)", "Northwest (Hai)", "East (Yin-Mao-Chen)"),
                6: ("South (Wu)", "North (Zi)", "North (Hai-Zi-Chou)"),
                7: ("Southwest (Wei)", "Northeast (Chou)", "West (Shen-You-Xu)"),
                8: ("Southwest (Shen)", "Northeast (Yin)", "South (Si-Wu-Wei)"),
                9: ("West (You)", "East (Mao)", "East (Yin-Mao-Chen)"),
                10: ("Northwest (Xu)", "Southeast (Chen)", "North (Hai-Zi-Chou)"),
                11: ("Northwest (Hai)", "Southeast (Si)", "West (Shen-You-Xu)")
            ]
            let c = enConfig[zhiIndex] ?? ("South", "North", "North")
            taiSuiDesc = c.ts; suiPoDesc = c.sp; sanShaDesc = c.ss
        case .zhHant:
            let hantConfig: [Int: (ts: String, sp: String, ss: String)] = [
                0: ("正北 (子方)", "正南 (午方)", "正南 (巳午未方)"),
                1: ("東北 (丑方)", "西南 (未方)", "正東 (寅卯辰方)"),
                2: ("東北 (寅方)", "西南 (申方)", "正北 (亥子丑方)"),
                3: ("正東 (卯方)", "正西 (酉方)", "正西 (申酉戌方)"),
                4: ("東南 (辰方)", "西北 (戌方)", "正南 (巳午未方)"),
                5: ("東南 (巳方)", "西北 (亥方)", "正東 (寅卯辰方)"),
                6: ("正南 (午方)", "正北 (子方)", "正北 (亥子丑方)"),
                7: ("西南 (未方)", "東北 (丑方)", "正西 (申酉戌方)"),
                8: ("西南 (申方)", "東北 (寅方)", "正南 (巳午未方)"),
                9: ("正西 (酉方)", "正東 (卯方)", "正東 (寅卯辰方)"),
                10: ("西北 (戌方)", "東南 (辰方)", "正北 (亥子丑方)"),
                11: ("西北 (亥方)", "東南 (巳方)", "正西 (申酉戌方)")
            ]
            let c = hantConfig[zhiIndex] ?? ("正南方", "正北方", "正北方")
            taiSuiDesc = c.ts; suiPoDesc = c.sp; sanShaDesc = c.ss
        case .ja:
            let jaConfig: [Int: (ts: String, sp: String, ss: String)] = [
                0: ("正北 (子方)", "正南 (午方)", "正南 (巳午未方)"),
                1: ("北東 (丑方)", "南西 (未方)", "正東 (寅卯辰方)"),
                2: ("北東 (寅方)", "南西 (申方)", "正北 (亥子丑方)"),
                3: ("正東 (卯方)", "正西 (酉方)", "正西 (申酉戌方)"),
                4: ("南東 (辰方)", "北西 (戌方)", "正南 (巳午未方)"),
                5: ("南東 (巳方)", "北西 (亥方)", "正東 (寅卯辰方)"),
                6: ("正南 (午方)", "正北 (子方)", "正北 (亥子丑方)"),
                7: ("南西 (未方)", "北東 (丑方)", "正西 (申酉戌方)"),
                8: ("南西 (申方)", "北東 (寅方)", "正南 (巳午未方)"),
                9: ("正西 (酉方)", "正東 (卯方)", "正東 (寅卯辰方)"),
                10: ("北西 (戌方)", "南東 (辰方)", "正北 (亥子丑方)"),
                11: ("北西 (亥方)", "南東 (巳方)", "正西 (申酉戌方)")
            ]
            let c = jaConfig[zhiIndex] ?? ("正南", "正北", "正北")
            taiSuiDesc = c.ts; suiPoDesc = c.sp; sanShaDesc = c.ss
        case .ko:
            let koConfig: [Int: (ts: String, sp: String, ss: String)] = [
                0: ("정북 (자방)", "정남 (오방)", "정남 (사오미방)"),
                1: ("북동 (축방)", "남서 (미방)", "정동 (인묘진방)"),
                2: ("북동 (인방)", "남서 (신방)", "정북 (해자축방)"),
                3: ("정동 (묘방)", "정서 (유방)", "정서 (신유술방)"),
                4: ("동남 (진방)", "북서 (술방)", "정남 (사오미방)"),
                5: ("동남 (사방)", "북서 (해방)", "정동 (인묘진방)"),
                6: ("정남 (오방)", "정북 (자방)", "정북 (해자축방)"),
                7: ("남서 (미방)", "북동 (축방)", "정서 (신유술방)"),
                8: ("남서 (신방)", "북동 (인방)", "정남 (사오미방)"),
                9: ("정서 (유방)", "정동 (묘방)", "정동 (인묘진방)"),
                10: ("북서 (술방)", "동남 (진방)", "정북 (해자축방)"),
                11: ("북서 (해방)", "동남 (사방)", "정서 (신유술방)")
            ]
            let c = koConfig[zhiIndex] ?? ("정남", "정북", "정북")
            taiSuiDesc = c.ts; suiPoDesc = c.sp; sanShaDesc = c.ss
        case .vi:
            let viConfig: [Int: (ts: String, sp: String, ss: String)] = [
                0: ("Chính Bắc (Tử)", "Chính Nam (Ngọ)", "Chính Nam (Tị Ngọ Mùi)"),
                1: ("Đông Bắc (Sửu)", "Tây Nam (Mùi)", "Chính Đông (Dần Mão Thìn)"),
                2: ("Đông Bắc (Dần)", "Tây Nam (Thân)", "Chính Bắc (Hợi Tý Sửu)"),
                3: ("Chính Đông (Mão)", "Chính Tây (Dậu)", "Chính Tây (Thân Dậu Tuất)"),
                4: ("Đông Nam (Thìn)", "Tây Bắc (Tuất)", "Chính Nam (Tị Ngọ Mùi)"),
                5: ("Đông Nam (Tị)", "Tây Bắc (Hợi)", "Chính Đông (Dần Mão Thìn)"),
                6: ("Chính Nam (Ngọ)", "Chính Bắc (Tử)", "Chính Bắc (Hợi Tý Sửu)"),
                7: ("Tây Nam (Mùi)", "Đông Bắc (Sửu)", "Chính Tây (Thân Dậu Tuất)"),
                8: ("Tây Nam (Thân)", "Đông Bắc (Dần)", "Chính Nam (Tị Ngọ Mùi)"),
                9: ("Chính Tây (Dậu)", "Chính Đông (Mão)", "Chính Đông (Dần Mão Thìn)"),
                10: ("Tây Bắc (Tuất)", "Đông Nam (Thìn)", "Chính Bắc (Hợi Tý Sửu)"),
                11: ("Tây Bắc (Hợi)", "Đông Nam (Tị)", "Chính Tây (Thân Dậu Tuất)")
            ]
            let c = viConfig[zhiIndex] ?? ("Chính Nam", "Chính Bắc", "Chính Bắc")
            taiSuiDesc = c.ts; suiPoDesc = c.sp; sanShaDesc = c.ss
        case .th:
            let thConfig: [Int: (ts: String, sp: String, ss: String)] = [
                0: ("ทิศเหนือ (จื่อ)", "ทิศใต้ (อู่)", "ทิศใต้ (ซื่อ-อู่-เว่ย)"),
                1: ("ทิศตะวันออกเฉียงเหนือ (โฉ่ว)", "ทิศตะวันตกเฉียงใต้ (เว่ย)", "ทิศตะวันออก (อิ๋น-เหม่า-เฉิน)"),
                2: ("ทิศตะวันออกเฉียงเหนือ (อิ๋น)", "ทิศตะวันตกเฉียงใต้ (เซิน)", "ทิศเหนือ (ไฮ่-จื่อ-โฉ่ว)"),
                3: ("ทิศตะวันออก (เหม่า)", "ทิศตะวันตก (โหย่ว)", "ทิศตะวันตก (เซิน-โหย่ว-ซวี)"),
                4: ("ทิศตะวันออกเฉียงใต้ (เฉิน)", "ทิศตะวันตกเฉียงเหนือ (ซวี)", "ทิศใต้ (ซื่อ-อู่-เว่ย)"),
                5: ("ทิศตะวันออกเฉียงใต้ (ซื่อ)", "ทิศตะวันตกเฉียงเหนือ (ไฮ่)", "ทิศตะวันออก (อิ๋น-เหม่า-เฉิน)"),
                6: ("ทิศใต้ (อู่)", "ทิศเหนือ (จื่อ)", "ทิศเหนือ (ไฮ่-จื่อ-โฉ่ว)"),
                7: ("ทิศตะวันตกเฉียงใต้ (เว่ย)", "ทิศตะวันออกเฉียงเหนือ (โฉ่ว)", "ทิศตะวันตก (เซิน-โหย่ว-ซวี)"),
                8: ("ทิศตะวันตกเฉียงใต้ (เซิน)", "ทิศตะวันออกเฉียงเหนือ (อิ๋น)", "ทิศใต้ (ซื่อ-อู่-เว่ย)"),
                9: ("ทิศตะวันตก (โหย่ว)", "ทิศตะวันออก (เหม่า)", "ทิศตะวันออก (อิ๋น-เหม่า-เฉิน)"),
                10: ("ทิศตะวันตกเฉียงเหนือ (ซวี)", "ทิศตะวันออกเฉียงใต้ (เฉิน)", "ทิศเหนือ (ไฮ่-จื่อ-โฉ่ว)"),
                11: ("ทิศตะวันตกเฉียงเหนือ (ไฮ่)", "ทิศตะวันออกเฉียงใต้ (ซื่อ)", "ทิศตะวันตก (เซิน-โหย่ว-ซวี)")
            ]
            let c = thConfig[zhiIndex] ?? ("ทิศใต้", "ทิศเหนือ", "ทิศเหนือ")
            taiSuiDesc = c.ts; suiPoDesc = c.sp; sanShaDesc = c.ss
        case .id:
            let idConfig: [Int: (ts: String, sp: String, ss: String)] = [
                0: ("Utara (Zi)", "Selatan (Wu)", "Selatan (Si-Wu-Wei)"),
                1: ("Timur Laut (Chou)", "Barat Daya (Wei)", "Timur (Yin-Mao-Chen)"),
                2: ("Timur Laut (Yin)", "Barat Daya (Shen)", "Utara (Hai-Zi-Chou)"),
                3: ("Timur (Mao)", "Barat (You)", "Barat (Shen-You-Xu)"),
                4: ("Tenggara (Chen)", "Barat Laut (Xu)", "Selatan (Si-Wu-Wei)"),
                5: ("Tenggara (Si)", "Barat Laut (Hai)", "Timur (Yin-Mao-Chen)"),
                6: ("Selatan (Wu)", "Utara (Zi)", "Utara (Hai-Zi-Chou)"),
                7: ("Barat Daya (Wei)", "Timur Laut (Chou)", "Barat (Shen-You-Xu)"),
                8: ("Barat Daya (Shen)", "Timur Laut (Yin)", "Selatan (Si-Wu-Wei)"),
                9: ("Barat (You)", "Timur (Mao)", "Timur (Yin-Mao-Chen)"),
                10: ("Barat Laut (Xu)", "Tenggara (Chen)", "Utara (Hai-Zi-Chou)"),
                11: ("Barat Laut (Hai)", "Tenggara (Si)", "Barat (Shen-You-Xu)")
            ]
            let c = idConfig[zhiIndex] ?? ("Selatan", "Utara", "Utara")
            taiSuiDesc = c.ts; suiPoDesc = c.sp; sanShaDesc = c.ss
        case .auto, .zhHans:
            let hansConfig: [Int: (ts: String, sp: String, ss: String)] = [
                0: ("正北 (子方)", "正南 (午方)", "正南 (巳午未方)"),
                1: ("东北 (丑方)", "西南 (未方)", "正东 (寅卯辰方)"),
                2: ("东北 (寅方)", "西南 (申方)", "正北 (亥子丑方)"),
                3: ("正东 (卯方)", "正西 (酉方)", "正西 (申酉戌方)"),
                4: ("东南 (辰方)", "西北 (戌方)", "正南 (巳午未方)"),
                5: ("东南 (巳方)", "西北 (亥方)", "正东 (寅卯辰方)"),
                6: ("正南 (午方)", "正北 (子方)", "正北 (亥子丑方)"),
                7: ("西南 (未方)", "东北 (丑方)", "正西 (申酉戌方)"),
                8: ("西南 (申方)", "东北 (寅方)", "正南 (巳午未方)"),
                9: ("正西 (酉方)", "正东 (卯方)", "正东 (寅卯辰方)"),
                10: ("西北 (戌方)", "东南 (辰方)", "正北 (亥子丑方)"),
                11: ("西北 (亥方)", "东南 (巳方)", "正西 (申酉戌方)")
            ]
            let c = hansConfig[zhiIndex] ?? ("正南方", "正北方", "正北方")
            taiSuiDesc = c.ts; suiPoDesc = c.sp; sanShaDesc = c.ss
        }
        
        var palaceItems: [PurpleWhitePalaceItem] = []
        for pId in displayPalaceOrder {
            let yStar = yearStarsMap[pId] ?? 1
            let mStar = monthStarsMap[pId] ?? 1
            let isTaiSui = (pId == taiSuiPalace)
            let isSuiPo = (pId == suiPoPalace)
            let isSanSha = sanShaPalaces.contains(pId)
            
            // 二五交加必须由同一宫的流年、流月客星实际形成 2/5 组合。
            // 仅凭宫位编号为 2 或 5 会把正常星位误报为重煞。
            let isDanger25 = (yStar == 5 && mStar == 2) || (yStar == 2 && mStar == 5)
            let hasFiveYellow = yStar == 5 || mStar == 5
            let hasIllnessStar = yStar == 2 || mStar == 2
            
            var advice = ""
            switch lang {
            case .en:
                if isDanger25 {
                    advice = "[2-5 Double Taboo] Illness Star meets Five Yellow. What to do: Hang a brass gourd or 6-Emperor coins here; no drilling, no red. → Effect: Mainly health and disputes; covers this palace area."
                } else if hasFiveYellow {
                    advice = "[Five Yellow] Avoid drilling or hammering walls. What to do: Place a pacifying water vessel or brass item to settle Earth qi. → Effect: Eases health and financial-loss risk in this direction."
                } else if hasIllnessStar {
                    advice = "[Illness Star] What to do: Place a brass item to drain the energy; keep this area ventilated and dry. → Effect: Health-related; covers this palace."
                } else if yStar == 9 {
                    advice = "[9-Purple Auspicious] What to do: Display red/green plants or warm-toned decor. → Effect: Supports romance, celebrations and new family members; covers this palace."
                } else if yStar == 8 {
                    advice = "[8-White Wealth] What to do: Keep it tidy; place a gathering ornament or cash box. → Effect: Supports property and wealth accumulation."
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "[Noble Stars] What to do: Set up a desk lamp or study area, place a Wen Chang tower or green plant. → Effect: Supports study and career advancement."
                } else {
                    advice = "Balanced energy. What to do: Keep it clean and ventilated as usual. → Effect: No special treatment needed."
                }
            case .zhHant:
                if isDanger25 {
                    advice = "【二五交加】病符逢五黃。做法：此方位掛銅葫蘆或六帝錢；忌動土、忌紅色。→ 影響：主要管健康與是非口舌，覆蓋該宮區域。"
                } else if hasFiveYellow {
                    advice = "【五黃】忌動土鑽牆。做法：放安忍水或銅器壓住土氣。→ 影響：管該方位健康與破財風險。"
                } else if hasIllnessStar {
                    advice = "【病符】做法：放銅制器物洩化，保持該方位通風乾燥。→ 影響：管健康，覆蓋該宮。"
                } else if yStar == 9 {
                    advice = "【九紫喜慶】做法：擺紅/綠植物或暖色裝飾催旺。→ 影響：利姻緣添丁喜慶，覆蓋該宮。"
                } else if yStar == 8 {
                    advice = "【八白財星】做法：保持整潔，放聚氣擺件或錢箱。→ 影響：利田宅聚財。"
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "【文昌吉星】做法：設書桌台燈，放文昌塔或綠植。→ 影響：利學業仕途。"
                } else {
                    advice = "氣場平穩。做法：保持整潔通風即可。→ 影響：無需特別調理。"
                }
            case .ja:
                if isDanger25 {
                    advice = "【二五交加の大煞】病符と五黄が重なる。やり方：この方位に銅製の瓢箪か六帝銭を掛ける。動土・赤は避ける。→ 効果：主に健康とトラブルに作用し、この宮の領域に効果。"
                } else if hasFiveYellow {
                    advice = "【五黄】動土や壁の穴あけを避ける。やり方：安忍水か銅製品で土気を鎮める。→ 効果：この方位の健康と散財リスクを緩和。"
                } else if hasIllnessStar {
                    advice = "【病符】やり方：銅製品を置いて気を泄し、この場所は風通しよく乾燥させる。→ 効果：健康関連。この宮に効果。"
                } else if yStar == 9 {
                    advice = "【九紫喜慶】やり方：赤や緑の植物、暖色の飾りを置く。→ 効果：良縁・慶事・にぎわいに吉。この宮に効果。"
                } else if yStar == 8 {
                    advice = "【八白財星】やり方：整理整頓し、気を集める置物か財布箱を置く。→ 効果：不動産・蓄財に有利。"
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "【文昌吉星】やり方：机とスタンドライトを置き、文昌塔か観葉植物を飾る。→ 効果：学業・出世に吉。"
                } else {
                    advice = "気場は穏やか。やり方：いつも通り清潔で風通しよく保つ。→ 効果：特別な調理は不要。"
                }
            case .ko:
                if isDanger25 {
                    advice = "【이오교가】병부성과 오황이 겹침. 방법: 이 방위에 구리 호리병이나 육제전을 겁니다. 토목·빨간색 금지. → 효과: 주로 건강과 구설에 작용, 이 궁 영역에 효과."
                } else if hasFiveYellow {
                    advice = "【오황】토목 공사나 벽 뚫기를 피합니다. 방법: 안인수나 구리 제품으로 토기를 안정시킵니다. → 효과: 이 방위의 건강과 파재 위험 완화."
                } else if hasIllnessStar {
                    advice = "【병부】방법: 구리 제품을 두어 기운을 빼고, 이곳은 통풍·건조하게 유지합니다. → 효과: 건강 관련. 이 궁에 효과."
                } else if yStar == 9 {
                    advice = "【구자 희경】방법: 빨강/초록 식물이나 따뜻한 색 장식을 둡니다. → 효과: 인연·경사·번영에 길. 이 궁에 효과."
                } else if yStar == 8 {
                    advice = "【팔백 재성】방법: 정리 정돈하고 기를 모으는 장식품이나 돈통을 둡니다. → 효과: 부동산·저축에 유리."
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "【문창 길성】방법: 책상과 스탠드를 두고 문창탑이나 화분을 둡니다. → 효과: 학업·출세에 길."
                } else {
                    advice = "기운이 안정됨. 방법: 평소처럼 청결하고 통풍 잘 유지. → 효과: 특별한 조치 불필요."
                }
            case .vi:
                if isDanger25 {
                    advice = "【Nhị Ngũ Giao Gia】Bệnh Phù gặp Ngũ Hoàng. Cách làm: Treo hồ lô đồng hoặc tiền lục đế ở hướng này; tránh động thổ và màu đỏ. → Ảnh hưởng: Chủ yếu về sức khỏe và thị phi; phủ khu vực cung này."
                } else if hasFiveYellow {
                    advice = "【Ngũ Hoàng】Tránh động thổ khoan tường. Cách làm: Đặt an nhẫn thủy hoặc vật bằng đồng để trấn thổ khí. → Ảnh hưởng: Giảm rủi ro sức khỏe và hao tài ở hướng này."
                } else if hasIllnessStar {
                    advice = "【Bệnh Phù】Cách làm: Đặt vật bằng đồng để tiết khí; giữ nơi này thông thoáng khô ráo. → Ảnh hưởng: Liên quan sức khỏe; phủ cung này."
                } else if yStar == 9 {
                    advice = "【Cửu Tử Hỷ Khánh】Cách làm: Bày cây đỏ/xanh hoặc vật trang trí tông ấm. → Ảnh hưởng: Trợ duyên, tin vui, thêm nhân khẩu; phủ cung này."
                } else if yStar == 8 {
                    advice = "【Bát Bạch Tài Tinh】Cách làm: Giữ gọn gàng, đặt vật tụ khí hoặc hộp tiền. → Ảnh hưởng: Lợi điền sản và tích tài."
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "【Văn Xương Cát Tinh】Cách làm: Đặt bàn học, đèn bàn, tháp Văn Xương hoặc cây xanh. → Ảnh hưởng: Lợi học hành và công danh."
                } else {
                    advice = "Khí trường bình hòa. Cách làm: Giữ sạch sẽ thông thoáng như thường. → Ảnh hưởng: Không cần điều chỉnh đặc biệt."
                }
            case .th:
                if isDanger25 {
                    advice = "【สองห้าประจัน】ดาวพยาธิปะทะดาวห้าเหลือง วิธีทำ: แขวนน้ำเต้าทองเหลืองหรือเหรียญหกจักรพรรดิที่ทิศนี้ ห้ามขุดเจาะและห้ามสีแดง → ผล: หลักเรื่องสุขภาพและปากเสียง ครอบคลุมพื้นที่นั้น"
                } else if hasFiveYellow {
                    advice = "【ดาวห้าเหลือง】ห้ามขุดเจาะผนัง วิธีทำ: ตั้งอ่างน้ำสงบหรือของทองเหลืองระงับพลังดิน → ผล: ลดเสี่ยงสุขภาพและเสียทรัพย์ที่ทิศนี้"
                } else if hasIllnessStar {
                    advice = "【ดาวพยาธิ】วิธีทำ: วางของทองเหลืองระบายพลัง ดูแลที่แห่งนี้โปร่งและแห้ง → ผล: เรื่องสุขภาพ ครอบคลุมพื้นที่นั้น"
                } else if yStar == 9 {
                    advice = "【ดาวเก้าม่วงมงคล】วิธีทำ: วางต้นไม้เขียวหรือของแต่งโทนอุ่น → ผล: เสริมความรัก ข่าวดี และความเจริญ ครอบคลุมพื้นที่นั้น"
                } else if yStar == 8 {
                    advice = "【ดาวแปดขาวทรัพย์】วิธีทำ: เก็บให้เป็นระเบียบ วางของรวมพลังหรือกล่องเงิน → ผล: ส่งเสริมที่ดินและการสะสมทรัพย์"
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "【ดาวมงคลบุ๋นบู๊】วิธีทำ: จัดโต๊ะเรียนโคมไฟ วางหอเวินชางหรือต้นไม้ → ผล: ส่งเสริมการเรียนและความก้าวหน้า"
                } else {
                    advice = "พลังสงบดี วิธีทำ: ดูแลสะอาดโปร่งตามปกติ → ผล: ไม่ต้องปรับพิเศษ"
                }
            case .id:
                if isDanger25 {
                    advice = "【Tabu Ganda 2-5】Bintang Penyakit bertemu 5-Kuning. Cara: Gantung labu kuningan atau koin 6 Kaisar di arah ini; jangan bor, hindari merah. → Efek: Terutama kesehatan dan pertikaian; mencakup area istana ini."
                } else if hasFiveYellow {
                    advice = "【5-Kuning】Hindari bor tembok. Cara: Letakkan wadah air penenang atau benda kuningan untuk menstabilkan energi tanah. → Efek: Mengurangi risiko kesehatan dan kehilangan uang di arah ini."
                } else if hasIllnessStar {
                    advice = "【Bintang Penyakit】Cara: Letakkan benda kuningan untuk menyalurkan energi; jaga area ini berventilasi dan kering. → Efek: Terkait kesehatan; mencakup istana ini."
                } else if yStar == 9 {
                    advice = "【9-Ungu Keberuntungan】Cara: Pajang tanaman merah/hijau atau dekorasi bernada hangat. → Efek: Mendukung asmara, kabar baik, dan tambahan anggota keluarga; mencakup istana ini."
                } else if yStar == 8 {
                    advice = "【8-Putih Rezeki】Cara: Jaga rapi, taruh hiasan pengumpul energi atau kotak uang. → Efek: Mendukung properti dan akumulasi kekayaan."
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "【Bintang Bangsawan】Cara: Siapkan meja belajar dan lampu, taruh menara Wen Chang atau tanaman hijau. → Efek: Mendukung pendidikan dan kemajuan karier."
                } else {
                    advice = "Energi seimbang. Cara: Jaga bersih dan berventilasi seperti biasa. → Efek: Tidak perlu perlakuan khusus."
                }
            case .auto, .zhHans:
                if isDanger25 {
                    advice = "【二五交加】病符逢五黄。做法：此方位挂铜葫芦或六帝钱；忌动土、忌红色。→ 影响：主要管健康与是非口舌，覆盖该宫区域。"
                } else if hasFiveYellow {
                    advice = "【五黄】忌动土钻墙。做法：放安忍水或铜器压住土气。→ 影响：管该方位健康与破财风险。"
                } else if hasIllnessStar {
                    advice = "【病符】做法：放铜制器物泄化，保持该方位通风干燥。→ 影响：管健康，覆盖该宫。"
                } else if yStar == 9 {
                    advice = "【九紫喜庆】做法：摆红/绿植物或暖色装饰催旺。→ 影响：利姻缘添丁喜庆，覆盖该宫。"
                } else if yStar == 8 {
                    advice = "【八白财星】做法：保持整洁，放聚气摆件或钱箱。→ 影响：利田宅聚财。"
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "【文昌吉星】做法：设书桌台灯，放文昌塔或绿植。→ 影响：利学业仕途。"
                } else {
                    advice = "气场平稳。做法：保持整洁通风即可。→ 影响：无需特别调理。"
                }
            }
            
            palaceItems.append(PurpleWhitePalaceItem(
                palaceId: pId,
                palaceName: palaceFullName(palaceId: pId),
                direction: palaceDirection(palaceId: pId),
                originalStar: pId,
                yearGuestStar: yStar,
                monthGuestStar: mStar,
                starName: starName(for: yStar),
                isDanger25: isDanger25,
                isTaiSui: isTaiSui,
                isSuiPo: isSuiPo,
                isSanSha: isSanSha,
                advice: advice
            ))
        }
        
        return PurpleWhiteChart(
            year: effectiveYear,
            month: effectiveMonth,
            yearCentralStar: yCenter,
            monthCentralStar: mCenter,
            currentFacingPalace: palaceID(for: heading),
            taiSuiDescription: taiSuiDesc,
            suiPoDescription: suiPoDesc,
            sanShaDescription: sanShaDesc,
            palaceItems: palaceItems
        )
    }

    /// Map the live compass bearing to the corresponding eight-direction
    /// Luoshu palace. The center palace has no bearing and is not returned.
    private func palaceID(for heading: Double) -> Int {
        let normalized = (heading.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0)
        switch normalized {
        case 337.5..<360.0, 0.0..<22.5: return 1   // North / Kan
        case 22.5..<67.5: return 8                 // Northeast / Gen
        case 67.5..<112.5: return 3                // East / Zhen
        case 112.5..<157.5: return 4               // Southeast / Xun
        case 157.5..<202.5: return 9               // South / Li
        case 202.5..<247.5: return 2               // Southwest / Kun
        case 247.5..<292.5: return 7               // West / Dui
        default: return 6                          // Northwest / Qian
        }
    }
}
