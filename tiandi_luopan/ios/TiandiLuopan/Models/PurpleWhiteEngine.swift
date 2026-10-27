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
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            let names = [
                "", "1-White Greedy Wolf", "2-Black Illness Star", "3-Jade Storage Wood", "4-Green Wenqu Wood",
                "5-Yellow Lianzhen Sha", "6-White Martial Metal", "7-Red Army Metal", "8-White Wealth Earth", "9-Purple Vital Fire"
            ]
            return (star >= 1 && star <= 9) ? names[star] : ""
        } else if lang == .zhHant {
            let names = [
                "", "一白貪狼水星", "二黑巨門土星(病符)", "三碧祿存木星", "四綠文曲木星",
                "五黃廉貞土星(大煞)", "六白武曲金星", "七赤破軍金星", "八白左輔土星", "九紫右弼火星"
            ]
            return (star >= 1 && star <= 9) ? names[star] : ""
        } else {
            let names = [
                "", "一白贪狼水星", "二黑巨门土星(病符)", "三碧禄存木星", "四绿文曲木星",
                "五黄廉贞土星(大煞)", "六白武曲金星", "七赤破军金星", "八白左辅土星", "九紫右弼火星"
            ]
            return (star >= 1 && star <= 9) ? names[star] : ""
        }
    }
    
    public func palaceDirection(palaceId: Int) -> String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            let dirs = [1: "North", 2: "Southwest", 3: "East", 4: "Southeast", 5: "Center", 6: "Northwest", 7: "West", 8: "Northeast", 9: "South"]
            return dirs[palaceId] ?? "Center"
        } else if lang == .zhHant {
            let dirs = [1: "正北", 2: "西南", 3: "正東", 4: "東南", 5: "中宮", 6: "西北", 7: "正西", 8: "東北", 9: "正南"]
            return dirs[palaceId] ?? "中宮"
        } else {
            let dirs = [1: "正北", 2: "西南", 3: "正东", 4: "东南", 5: "中宫", 6: "西北", 7: "正西", 8: "东北", 9: "正南"]
            return dirs[palaceId] ?? "中宫"
        }
    }
    
    public func palaceFullName(palaceId: Int) -> String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            let full = [1: "North (Kan)", 2: "Southwest (Kun)", 3: "East (Zhen)", 4: "Southeast (Xun)", 5: "Center (Taiji)", 6: "Northwest (Qian)", 7: "West (Dui)", 8: "Northeast (Gen)", 9: "South (Li)"]
            return full[palaceId] ?? "Center"
        } else if lang == .zhHant {
            let full = [1: "正北 坎宮", 2: "西南 坤宮", 3: "正東 震宮", 4: "東南 巽宮", 5: "中央 太極", 6: "西北 乾宮", 7: "正西 兌宮", 8: "東北 艮宮", 9: "正南 離宮"]
            return full[palaceId] ?? "中央 太極"
        } else {
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
        let isBeforeLichun = rawMonth < 2 || (rawMonth == 2 && solarTermIndex < 2)
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
        
        if lang == .en {
            let enConfig: [Int: (tsP: Int, spP: Int, ssP: [Int], ts: String, sp: String, ss: String)] = [
                0: (1, 9, [9], "North (Zi)", "South (Wu)", "South (Si-Wu-Wei)"),
                1: (8, 2, [3], "Northeast (Chou)", "Southwest (Wei)", "East (Yin-Mao-Chen)"),
                2: (8, 2, [1], "Northeast (Yin)", "Southwest (Shen)", "North (Hai-Zi-Chou)"),
                3: (3, 7, [7], "East (Mao)", "West (You)", "West (Shen-You-Xu)"),
                4: (4, 6, [9], "Southeast (Chen)", "Northwest (Xu)", "South (Si-Wu-Wei)"),
                5: (4, 6, [3], "Southeast (Si)", "Northwest (Hai)", "East (Yin-Mao-Chen)"),
                6: (9, 1, [1], "South (Wu)", "North (Zi)", "North (Hai-Zi-Chou)"),
                7: (2, 8, [7], "Southwest (Wei)", "Northeast (Chou)", "West (Shen-You-Xu)"),
                8: (2, 8, [9], "Southwest (Shen)", "Northeast (Yin)", "South (Si-Wu-Wei)"),
                9: (7, 3, [3], "West (You)", "East (Mao)", "East (Yin-Mao-Chen)"),
                10: (6, 4, [1], "Northwest (Xu)", "Southeast (Chen)", "North (Hai-Zi-Chou)"),
                11: (6, 4, [7], "Northwest (Hai)", "Southeast (Si)", "West (Shen-You-Xu)")
            ]
            let c = enConfig[zhiIndex] ?? (9, 1, [1], "South", "North", "North")
            taiSuiPalace = c.tsP; suiPoPalace = c.spP; sanShaPalaces = c.ssP
            taiSuiDesc = c.ts; suiPoDesc = c.sp; sanShaDesc = c.ss
        } else if lang == .zhHant {
            let hantConfig: [Int: (tsP: Int, spP: Int, ssP: [Int], ts: String, sp: String, ss: String)] = [
                0: (1, 9, [9], "正北 (子方)", "正南 (午方)", "正南 (巳午未方)"),
                1: (8, 2, [3], "東北 (丑方)", "西南 (未方)", "正東 (寅卯辰方)"),
                2: (8, 2, [1], "東北 (寅方)", "西南 (申方)", "正北 (亥子丑方)"),
                3: (3, 7, [7], "正東 (卯方)", "正西 (酉方)", "正西 (申酉戌方)"),
                4: (4, 6, [9], "東南 (辰方)", "西北 (戌方)", "正南 (巳午未方)"),
                5: (4, 6, [3], "東南 (巳方)", "西北 (亥方)", "正東 (寅卯辰方)"),
                6: (9, 1, [1], "正南 (午方)", "正北 (子方)", "正北 (亥子丑方)"),
                7: (2, 8, [7], "西南 (未方)", "東北 (丑方)", "正西 (申酉戌方)"),
                8: (2, 8, [9], "西南 (申方)", "東北 (寅方)", "正南 (巳午未方)"),
                9: (7, 3, [3], "正西 (酉方)", "正東 (卯方)", "正東 (寅卯辰方)"),
                10: (6, 4, [1], "西北 (戌方)", "東南 (辰方)", "正北 (亥子丑方)"),
                11: (6, 4, [7], "西北 (亥方)", "東南 (巳方)", "正西 (申酉戌方)")
            ]
            let c = hantConfig[zhiIndex] ?? (9, 1, [1], "正南方", "正北方", "正北方")
            taiSuiPalace = c.tsP; suiPoPalace = c.spP; sanShaPalaces = c.ssP
            taiSuiDesc = c.ts; suiPoDesc = c.sp; sanShaDesc = c.ss
        } else {
            let hansConfig: [Int: (tsP: Int, spP: Int, ssP: [Int], ts: String, sp: String, ss: String)] = [
                0: (1, 9, [9], "正北 (子方)", "正南 (午方)", "正南 (巳午未方)"),
                1: (8, 2, [3], "东北 (丑方)", "西南 (未方)", "正东 (寅卯辰方)"),
                2: (8, 2, [1], "东北 (寅方)", "西南 (申方)", "正北 (亥子丑方)"),
                3: (3, 7, [7], "正东 (卯方)", "正西 (酉方)", "正西 (申酉戌方)"),
                4: (4, 6, [9], "东南 (辰方)", "西北 (戌方)", "正南 (巳午未方)"),
                5: (4, 6, [3], "东南 (巳方)", "西北 (亥方)", "正东 (寅卯辰方)"),
                6: (9, 1, [1], "正南 (午方)", "正北 (子方)", "正北 (亥子丑方)"),
                7: (2, 8, [7], "西南 (未方)", "东北 (丑方)", "正西 (申酉戌方)"),
                8: (2, 8, [9], "西南 (申方)", "东北 (寅方)", "正南 (巳午未方)"),
                9: (7, 3, [3], "正西 (酉方)", "正东 (卯方)", "正东 (寅卯辰方)"),
                10: (6, 4, [1], "西北 (戌方)", "东南 (辰方)", "正北 (亥子丑方)"),
                11: (6, 4, [7], "西北 (亥方)", "东南 (巳方)", "正西 (申酉戌方)")
            ]
            let c = hansConfig[zhiIndex] ?? (9, 1, [1], "正南方", "正北方", "正北方")
            taiSuiPalace = c.tsP; suiPoPalace = c.spP; sanShaPalaces = c.ssP
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
            if lang == .en {
                if isDanger25 {
                    advice = "[2-5 Severe Taboo] Illness Star meets Five Yellow. Hang 6-Emperor coins & brass gourd."
                } else if hasFiveYellow {
                    advice = "[Five Yellow Taboo] Annual or monthly Earth sha; avoid drilling and place a pacifying cure."
                } else if hasIllnessStar {
                    advice = "[Illness Star] Guard digestion & health; utilize copper feng shui items."
                } else if yStar == 9 {
                    advice = "[Auspicious Star] 9-Purple brings joy & vitality; display fresh plants."
                } else if yStar == 8 {
                    advice = "[Wealth Star] Favors real estate and prosperity accumulation."
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "[Noble Stars] Favors scholarly achievements and career advancement."
                } else {
                    advice = "Balanced energy; maintain regular harmonious arrangement."
                }
            } else if lang == .zhHant {
                if isDanger25 {
                    advice = "【二五交加重煞】病符逢五黃，宜懸掛六帝古錢與銅葫蘆化解"
                } else if hasFiveYellow {
                    advice = "【歲月五黃】不宜動土鑽牆，宜安放安忍水安撫土氣"
                } else if hasIllnessStar {
                    advice = "【病符臨門】注意脾胃與婦科，宜用銅制風水法物化洩"
                } else if yStar == 9 {
                    advice = "【當令吉星】九紫喜慶星飛臨，宜擺放紅綠綠植催旺姻緣添丁"
                } else if yStar == 8 {
                    advice = "【左輔財星】利田宅田莊，聚氣生財"
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "【吉星臨宮】文昌與武貴齊聚，利學業仕途升遷"
                } else {
                    advice = "氣場安平，按日常居家格局調理即可"
                }
            } else {
                if isDanger25 {
                    advice = "【二五交加重煞】病符逢五黄，宜悬挂六帝古钱与铜葫芦化解"
                } else if hasFiveYellow {
                    advice = "【岁月五黄】不宜动土钻墙，宜安放安忍水安抚土气"
                } else if hasIllnessStar {
                    advice = "【病符临门】注意脾胃与妇科，宜用铜制风水法物化泄"
                } else if yStar == 9 {
                    advice = "【当令吉星】九紫喜庆星飞临，宜摆放红绿绿植催旺姻缘添丁"
                } else if yStar == 8 {
                    advice = "【左辅财星】利田宅田庄，聚气生财"
                } else if yStar == 1 || yStar == 4 || yStar == 6 {
                    advice = "【吉星临宫】文昌与武贵齐聚，利学业仕途升迁"
                } else {
                    advice = "气场安平，按日常居家格局调理即可"
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
