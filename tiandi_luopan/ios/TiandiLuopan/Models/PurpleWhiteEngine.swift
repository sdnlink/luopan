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
    public let taiSuiDescription: String
    public let suiPoDescription: String
    public let sanShaDescription: String
    public let palaceItems: [PurpleWhitePalaceItem]
}

public class PurpleWhiteEngine {
    public static let shared = PurpleWhiteEngine()
    
    private let starNames = [
        "", "一白贪狼水星", "二黑巨门土星(病符)", "三碧禄存木星(蚩尤)", "四绿文曲木星",
        "五黄廉贞土星(大煞)", "六白武曲金星", "七赤破军金星", "八白左辅土星", "九紫右弼火星"
    ]
    
    // 洛书标准轨迹: [坎1, 坤2, 震3, 巽4, 中5, 乾6, 兑7, 艮8, 离9]
    // 顺飞公式: palace = (centerStar + step - 1) % 9 + 1
    private let luoshuOrder = [5, 6, 7, 8, 9, 1, 2, 3, 4]
    
    // 九宫网格展示次序 (从上到下，从左到右: 东南4, 正南9, 西南2; 正东3, 中宫5, 正西7; 东北8, 正北1, 西北6)
    public let displayPalaceOrder = [4, 9, 2, 3, 5, 7, 8, 1, 6]
    
    private let palaceNames: [Int: (dir: String, name: String)] = [
        1: ("正北", "正北 坎宫"),
        2: ("西南", "西南 坤宫"),
        3: ("正东", "正东 震宫"),
        4: ("东南", "东南 巽宫"),
        5: ("中宫", "中央 太极"),
        6: ("西北", "西北 乾宫"),
        7: ("正西", "正西 兑宫"),
        8: ("东北", "东北 艮宫"),
        9: ("正南", "正南 离宫")
    ]
    
    private init() {}
    
    public func calcYearStar(year: Int) -> Int {
        var num = (11 - (year % 9)) % 9
        if num <= 0 { num += 9 }
        return num
    }
    
    public func calcMonthStar(year: Int, month: Int) -> Int {
        // 年支五虎遁确定月飞星入中
        let yRem = year % 12
        var baseStar = 2
        if [4, 7, 10, 1].contains(yRem) { // 子午卯酉年
            baseStar = 8
        } else if [2, 5, 8, 11].contains(yRem) { // 辰戌丑未年
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
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        
        let yCenter = calcYearStar(year: year)
        let mCenter = calcMonthStar(year: year, month: month)
        
        let yearStarsMap = flyStars(centralStar: yCenter)
        let monthStarsMap = flyStars(centralStar: mCenter)
        
        // 地支年对应太岁/岁破/三煞
        let zhiIndex = (year - 4) % 12 // 0:子, 1:丑, 2:寅, 3:卯, 4:辰, 5:巳, 6:午, 7:未, 8:申, 9:酉, 10:戌, 11:亥
        let zhiNames = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
        let curZhi = zhiNames[max(0, min(11, zhiIndex))]
        
        var taiSuiPalace = 9
        var suiPoPalace = 1
        var sanShaPalaces = [1]
        var taiSuiDesc = "\(curZhi)方"
        var suiPoDesc = "对冲方"
        var sanShaDesc = "北方"
        
        // 太岁与三煞宫位对应
        switch zhiIndex {
        case 0: // 子
            taiSuiPalace = 1; suiPoPalace = 9; sanShaPalaces = [9]; taiSuiDesc = "正北子方"; suiPoDesc = "正南午方"; sanShaDesc = "正南巳午未方"
        case 1: // 丑
            taiSuiPalace = 8; suiPoPalace = 2; sanShaPalaces = [3]; taiSuiDesc = "东北丑方"; suiPoDesc = "西南未方"; sanShaDesc = "正东寅卯辰方"
        case 2: // 寅
            taiSuiPalace = 8; suiPoPalace = 2; sanShaPalaces = [1]; taiSuiDesc = "东北寅方"; suiPoDesc = "西南申方"; sanShaDesc = "正北亥子丑方"
        case 3: // 卯
            taiSuiPalace = 3; suiPoPalace = 7; sanShaPalaces = [7]; taiSuiDesc = "正东卯方"; suiPoDesc = "正西酉方"; sanShaDesc = "正西申酉戌方"
        case 4: // 辰
            taiSuiPalace = 4; suiPoPalace = 6; sanShaPalaces = [9]; taiSuiDesc = "东南辰方"; suiPoDesc = "西北戌方"; sanShaDesc = "正南巳午未方"
        case 5: // 巳
            taiSuiPalace = 4; suiPoPalace = 6; sanShaPalaces = [3]; taiSuiDesc = "东南巳方"; suiPoDesc = "西北亥方"; sanShaDesc = "正东寅卯辰方"
        case 6: // 午
            taiSuiPalace = 9; suiPoPalace = 1; sanShaPalaces = [1]; taiSuiDesc = "正南午方"; suiPoDesc = "正北子方"; sanShaDesc = "正北亥子丑方"
        case 7: // 未
            taiSuiPalace = 2; suiPoPalace = 8; sanShaPalaces = [7]; taiSuiDesc = "西南未方"; suiPoDesc = "东北丑方"; sanShaDesc = "正西申酉戌方"
        case 8: // 申
            taiSuiPalace = 2; suiPoPalace = 8; sanShaPalaces = [9]; taiSuiDesc = "西南申方"; suiPoDesc = "东北寅方"; sanShaDesc = "正南巳午未方"
        case 9: // 酉
            taiSuiPalace = 7; suiPoPalace = 3; sanShaPalaces = [3]; taiSuiDesc = "正西酉方"; suiPoDesc = "正东卯方"; sanShaDesc = "正东寅卯辰方"
        case 10: // 戌
            taiSuiPalace = 6; suiPoPalace = 4; sanShaPalaces = [1]; taiSuiDesc = "西北戌方"; suiPoDesc = "东南辰方"; sanShaDesc = "正北亥子丑方"
        case 11: // 亥
            taiSuiPalace = 6; suiPoPalace = 4; sanShaPalaces = [7]; taiSuiDesc = "西北亥方"; suiPoDesc = "东南巳方"; sanShaDesc = "正西申酉戌方"
        default:
            break
        }
        
        var palaceItems: [PurpleWhitePalaceItem] = []
        for pId in displayPalaceOrder {
            let info = palaceNames[pId] ?? ("方位", "宫位")
            let yStar = yearStarsMap[pId] ?? 1
            let mStar = monthStarsMap[pId] ?? 1
            let isTaiSui = (pId == taiSuiPalace)
            let isSuiPo = (pId == suiPoPalace)
            let isSanSha = sanShaPalaces.contains(pId)
            
            // 二五交加判断
            let isDanger25 = (yStar == 5 && mStar == 2) || (yStar == 2 && mStar == 5) || (yStar == 5 && pId == 2) || (yStar == 2 && pId == 5)
            
            var advice = ""
            if isDanger25 {
                advice = "【二五交加重煞】病符逢五黄，宜悬挂六帝古钱与铜葫芦化解"
            } else if yStar == 5 {
                advice = "【岁煞五黄】不宜动土钻墙，宜安放安忍水安抚土气"
            } else if yStar == 2 {
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
            
            palaceItems.append(PurpleWhitePalaceItem(
                palaceId: pId,
                palaceName: info.name,
                direction: info.dir,
                originalStar: pId,
                yearGuestStar: yStar,
                monthGuestStar: mStar,
                starName: starNames[yStar],
                isDanger25: isDanger25,
                isTaiSui: isTaiSui,
                isSuiPo: isSuiPo,
                isSanSha: isSanSha,
                advice: advice
            ))
        }
        
        return PurpleWhiteChart(
            year: year,
            month: month,
            yearCentralStar: yCenter,
            monthCentralStar: mCenter,
            taiSuiDescription: taiSuiDesc,
            suiPoDescription: suiPoDesc,
            sanShaDescription: sanShaDesc,
            palaceItems: palaceItems
        )
    }
}
