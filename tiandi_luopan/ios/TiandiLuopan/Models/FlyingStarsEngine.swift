import Foundation

// MARK: - 玄空九宫飞星排盘引擎 (XuanKong Flying Stars Engine)

public struct PalaceCell: Identifiable {
    public let id: Int // 0..8 (九宫对应: 0:坎, 1:坤, 2:震, 3:巽, 4:中, 5:乾, 6:兑, 7:艮, 8:离)
    public let palaceName: String
    public let trigram: String
    public let direction: String
    public let periodStar: Int    // 当运星
    public let mountainStar: Int  // 山星 (坐星)
    public let facingStar: Int    // 向星 (向星)
    public let isCenter: Bool     // 是否中宫
    public let isWangMountain: Bool // 是否旺山
    public let isWangFacing: Bool   // 是否旺向
    public let isShaWuHuang: Bool   // 是否五黄大煞
    public let isShaErHei: Bool     // 是否二黑病符
    
    public var sittingStar: Int { mountainStar }
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
    
    public var evaluation: String {
        if mountainStar == 9 && facingStar == 9 {
            return "九运双星会向 · 财源广聚"
        } else if facingStar == 9 {
            return "当旺财星照临 · 宜开门纳气"
        } else if mountainStar == 9 {
            return "当运丁星归位 · 人丁兴旺"
        } else if isShaWuHuang || isShaErHei {
            return "五黄二黑交加 · 宜静安铜化解"
        } else if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) {
            return "一六共宗 · 水清木秀催文昌"
        } else {
            return "吉凶相参 · 平和之位"
        }
    }
}

public typealias XuanKongPalace = PalaceCell

public struct XuanKongChart {
    public let period: Int                // 当前元运 (1..9, 现为九运 2024-2043)
    public let sittingMountain: String   // 坐山
    public let facingMountain: String    // 向山
    public let patternType: String       // 到山到向 / 上山下水 / 双星到向 / 双星到坐
    public let isSanBanGua: Bool         // 父母三般卦或连珠三般卦
    public let isQiXingDaJie: Bool       // 七星打劫局
    public let palaces: [PalaceCell]     // 九宫格数据
    public let summaryAnalysis: String   // 综合格局断语
    public var patternDesc: String { summaryAnalysis }
}

public final class FlyingStarsEngine {
    public static let shared = FlyingStarsEngine()
    
    // 九宫罗书飞布轨迹顺飞步进 (中5 -> 乾6 -> 兑7 -> 艮8 -> 离9 -> 坎1 -> 坤2 -> 震3 -> 巽4)
    private let luoShuOrder = [4, 5, 6, 7, 8, 0, 1, 2, 3]
    
    // 八卦宫位对应的洛书基础数字
    // 坎1, 坤2, 震3, 巽4, 中5, 乾6, 兑7, 艮8, 离9
    private let palaceNames = ["坎一宫 (正北)", "坤二宫 (西南)", "震三宫 (正东)", "巽四宫 (东南)", "天心五 (中宫)", "乾六宫 (西北)", "兑七宫 (正西)", "艮八宫 (东北)", "离九宫 (正南)"]
    private let palaceDirections = ["正北", "西南", "正东", "东南", "中宫", "西北", "正西", "东北", "正南"]
    
    public func calculateChart(period: Int = 9, sitting: Mountain24Item, facing: Mountain24Item) -> XuanKongChart {
        // 1. 排运盘：将当运数字入中顺飞九宫
        var basePeriod = [Int](repeating: 0, count: 9)
        basePeriod[4] = period
        for step in 1...8 {
            let nextPalace = luoShuOrder[step]
            var star = (period + step) % 9
            if star == 0 { star = 9 }
            basePeriod[nextPalace] = star
        }
        
        // 2. 查坐山与向山所在宫位的运盘星，定山星与向星入中
        let sittingPalaceIdx = palaceIndex(for: sitting.palace)
        let facingPalaceIdx = palaceIndex(for: facing.palace)
        
        let sittingInCentral = basePeriod[sittingPalaceIdx]
        let facingInCentral = basePeriod[facingPalaceIdx]
        
        // 3. 判断山星与向星顺飞/逆飞性 (根据坐向元龙阳顺阴逆)
        let sittingIsForward = sitting.polarity > 0
        let facingIsForward = facing.polarity > 0
        
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
        
        // 4. 判定四大经典格局
        // 查找当运旺星(如九运中为9)落在向方和坐方的分布
        let sittingFacingIdx = facingPalaceIdx
        let sittingMountIdx = sittingPalaceIdx
        
        let facingStarAtFacing = facingStars[sittingFacingIdx]
        let mountainStarAtMount = mountainStars[sittingMountIdx]
        let mountainStarAtFacing = mountainStars[sittingFacingIdx]
        let facingStarAtMount = facingStars[sittingMountIdx]
        
        var pattern = "吉凶平和局"
        if facingStarAtFacing == period && mountainStarAtMount == period {
            pattern = "到山到向 (旺丁旺财最吉)"
        } else if facingStarAtFacing == period && mountainStarAtFacing == period {
            pattern = "双星到向 (旺财不旺丁 · 宜向前有水后有山)"
        } else if facingStarAtMount == period && mountainStarAtMount == period {
            pattern = "双星到坐 (旺丁不旺财 · 宜向后有水水后有山)"
        } else if facingStarAtMount == period && mountainStarAtFacing == period {
            pattern = "上山下水 (败财损丁凶局 · 需借势颠倒用法)"
        }
        
        // 5. 组合九宫格模型
        var cells: [PalaceCell] = []
        for i in 0..<9 {
            let isWangM = mountainStars[i] == period
            let isWangF = facingStars[i] == period
            let isWuHuang = mountainStars[i] == 5 || facingStars[i] == 5
            let isErHei = mountainStars[i] == 2 || facingStars[i] == 2
            
            let cell = PalaceCell(
                id: i,
                palaceName: palaceNames[i],
                trigram: palaceNames[i].prefix(1).description,
                direction: palaceDirections[i],
                periodStar: basePeriod[i],
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
        
        let summary = "当前正值下元九运（2024—2043年，九紫离火当令）。\(sitting.name)山\(facing.name)向在此元运呈现【\(pattern)】。宜重点布局向首明堂引纳九紫吉气，坐后稳实以固人丁。"
        
        return XuanKongChart(
            period: period,
            sittingMountain: sitting.name,
            facingMountain: facing.name,
            patternType: pattern,
            isSanBanGua: false,
            isQiXingDaJie: false,
            palaces: cells,
            summaryAnalysis: summary
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
}
