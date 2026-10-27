import Foundation

// MARK: - 玄空九宫飞星排盘引擎 (XuanKong Flying Stars Engine)

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
        guard LocalizationManager.shared.effectiveLanguage == .en else { return element }
        switch element {
        case "水": return "Water"
        case "木": return "Wood"
        case "火": return "Fire"
        case "土": return "Earth"
        case "金": return "Metal"
        default: return element
        }
    }

    public var localizedEvaluation: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            if mountainStar == activePeriod && facingStar == activePeriod { return "Double Current Stars · Wealth and people prosper" }
            if facingStar == activePeriod { return "Current Wealth Star at Facing · Open and receive qi" }
            if mountainStar == activePeriod { return "Current Mountain Star returns · People prosper" }
            if isShaWuHuang || isShaErHei { return "Five Yellow and Two Black clash · Calm and use Metal remedy" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "One–Six harmony · Clear Water and Wood nourish Wenchang" }
            return "Mixed fortune · Balanced position"
        }
        if lang == .zhHant {
            if mountainStar == activePeriod && facingStar == activePeriod { return "當運雙星會聚 · 財丁兩旺" }
            if facingStar == activePeriod { return "當旺財星照臨 · 宜開門納氣" }
            if mountainStar == activePeriod { return "當運丁星歸位 · 人丁興旺" }
            if isShaWuHuang || isShaErHei { return "五黃二黑交加 · 宜靜安銅化解" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "一六共宗 · 水清木秀催文昌" }
            return "吉凶相參 · 平和之位"
        }
        return evaluation
    }

    public var localizedPalaceName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        if lang == .en {
            let directionMap = [
                "正北": "North", "西南": "Southwest", "正东": "East", "东南": "Southeast",
                "中宫": "Center", "西北": "Northwest", "正西": "West", "东北": "Northeast", "正南": "South"
            ]
            var result = palaceName
            for (source, localized) in directionMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        }
        if lang == .zhHant {
            return palaceName
                .replacingOccurrences(of: "东", with: "東")
                .replacingOccurrences(of: "兑", with: "兌")
                .replacingOccurrences(of: "离", with: "離")
                .replacingOccurrences(of: "宫", with: "宮")
        }
        return palaceName
    }
    
    public var evaluation: String {
        if mountainStar == activePeriod && facingStar == activePeriod {
            return "当运双星会聚 · 财丁两旺"
        } else if facingStar == activePeriod {
            return "当旺财星照临 · 宜开门纳气"
        } else if mountainStar == activePeriod {
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

public struct XuanKongChart {
    public let period: Int                // 所选排盘元运 (1..9)
    public let sittingMountain: String   // 坐山
    public let facingMountain: String    // 向山
    public let patternType: String       // 到山到向 / 上山下水 / 双星到向 / 双星到坐
    public let isSanBanGua: Bool         // 父母三般卦或连珠三般卦
    public let isQiXingDaJie: Bool       // 七星打劫局
    public let palaces: [PalaceCell]     // 九宫格数据
    public let summaryAnalysis: String   // 综合格局断语
    public var patternDesc: String { summaryAnalysis }
    public let periodMeta: PeriodMeta    // 动态历法元信息
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
        
        let isEn = LocalizationManager.shared.effectiveLanguage == .en
        let isHant = LocalizationManager.shared.effectiveLanguage == .zhHant
        
        let yuan: String
        let trigram: String
        let starName: String
        let element: String
        
        switch p {
        case 1:
            yuan = isEn ? "Upper Yuan" : (isHant ? "上元" : "上元")
            trigram = isEn ? "Kan" : "坎"
            starName = isEn ? "1 White TanLang" : (isHant ? "一白貪狼" : "一白贪狼")
            element = isEn ? "Water" : "水"
        case 2:
            yuan = isEn ? "Upper Yuan" : (isHant ? "上元" : "上元")
            trigram = isEn ? "Kun" : "坤"
            starName = isEn ? "2 Black JuMen" : (isHant ? "二黑巨門" : "二黑巨门")
            element = isEn ? "Earth" : "土"
        case 3:
            yuan = isEn ? "Upper Yuan" : (isHant ? "上元" : "上元")
            trigram = isEn ? "Zhen" : "震"
            starName = isEn ? "3 Jade LuCun" : (isHant ? "三碧祿存" : "三碧禄存")
            element = isEn ? "Wood" : "木"
        case 4:
            yuan = isEn ? "Middle Yuan" : (isHant ? "中元" : "中元")
            trigram = isEn ? "Xun" : "巽"
            starName = isEn ? "4 Green WenQu" : (isHant ? "四綠文曲" : "四绿文曲")
            element = isEn ? "Wood" : "木"
        case 5:
            yuan = isEn ? "Middle Yuan" : (isHant ? "中元" : "中元")
            trigram = isEn ? "Center" : "中"
            starName = isEn ? "5 Yellow LianZhen" : (isHant ? "五黃廉貞" : "五黄廉贞")
            element = isEn ? "Earth" : "土"
        case 6:
            yuan = isEn ? "Middle Yuan" : (isHant ? "中元" : "中元")
            trigram = isEn ? "Qian" : "乾"
            starName = isEn ? "6 White WuQu" : (isHant ? "六白武曲" : "六白武曲")
            element = isEn ? "Metal" : "金"
        case 7:
            yuan = isEn ? "Lower Yuan" : (isHant ? "下元" : "下元")
            trigram = isEn ? "Dui" : (isHant ? "兌" : "兑")
            starName = isEn ? "7 Red PoJun" : (isHant ? "七赤破軍" : "七赤破军")
            element = isEn ? "Metal" : "金"
        case 8:
            yuan = isEn ? "Lower Yuan" : (isHant ? "下元" : "下元")
            trigram = isEn ? "Gen" : "艮"
            starName = isEn ? "8 White ZuoFu" : (isHant ? "八白左輔" : "八白左辅")
            element = isEn ? "Earth" : "土"
        case 9:
            yuan = isEn ? "Lower Yuan" : (isHant ? "下元" : "下元")
            trigram = isEn ? "Li" : (isHant ? "離" : "离")
            starName = isEn ? "9 Purple YouBi" : (isHant ? "九紫右弼" : "九紫右弼")
            element = isEn ? "Fire" : "火"
        default:
            yuan = ""
            trigram = ""
            starName = ""
            element = ""
        }
        
        let isCur = (p == curPeriod)
        let label: String
        if isEn {
            label = isCur ? "Current Period \(p) (\(startY)–\(endY), \(yuan) · \(element))" : "Period \(p) (\(startY)–\(endY), \(yuan) · \(element))"
        } else if isHant {
            label = isCur ? "當前\(yuan)\(p)運（\(startY)—\(endY)年，\(starName)\(element)星當令）" : "\(yuan)\(p)運（\(startY)—\(endY)年，\(starName)\(element)星當令）"
        } else {
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
        let month = calendar.component(.month, from: date)
        let termIndex = SolarTimeCalculator.shared.solarTermIndex(for: date)
        // January always belongs to the previous Xuan Kong year. In February
        // use the astronomical Li Chun bucket, avoiding a fixed Feb 4 cutoff.
        let beforeLiChun = month < 2 || (month == 2 && termIndex < 2)
        return beforeLiChun ? year - 1 : year
    }
    
    // 九宫罗书飞布轨迹顺飞步进 (中5 -> 乾6 -> 兑7 -> 艮8 -> 离9 -> 坎1 -> 坤2 -> 震3 -> 巽4)
    private let luoShuOrder = [4, 5, 6, 7, 8, 0, 1, 2, 3]
    
    // 八卦宫位对应的洛书基础数字
    // 坎1, 坤2, 震3, 巽4, 中5, 乾6, 兑7, 艮8, 离9
    private let palaceNames = ["坎一宫 (正北)", "坤二宫 (西南)", "震三宫 (正东)", "巽四宫 (东南)", "天心五 (中宫)", "乾六宫 (西北)", "兑七宫 (正西)", "艮八宫 (东北)", "离九宫 (正南)"]
    private let palaceDirections = ["正北", "西南", "正东", "东南", "中宫", "西北", "正西", "东北", "正南"]
    
    public func calculateChart(period: Int? = nil, sitting: Mountain24Item, facing: Mountain24Item, date: Date = Date()) -> XuanKongChart {
        let activePeriod = period ?? currentPeriod(for: date)
        let meta = periodMeta(period: activePeriod, for: date)
        
        let isEn = LocalizationManager.shared.effectiveLanguage == .en
        let isHant = LocalizationManager.shared.effectiveLanguage == .zhHant
        
        // 1. 排运盘：将当运数字入中顺飞九宫
        var basePeriod = [Int](repeating: 0, count: 9)
        basePeriod[4] = activePeriod
        for step in 1...8 {
            let nextPalace = luoShuOrder[step]
            var star = (activePeriod + step) % 9
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
        
        // 4. 判定四大经典格局 (根据当运星分布，完全动态推导)
        let sittingFacingIdx = facingPalaceIdx
        let sittingMountIdx = sittingPalaceIdx
        
        let facingStarAtFacing = facingStars[sittingFacingIdx]
        let mountainStarAtMount = mountainStars[sittingMountIdx]
        let mountainStarAtFacing = mountainStars[sittingFacingIdx]
        let facingStarAtMount = facingStars[sittingMountIdx]
        
        let pattern: String
        if isEn {
            if facingStarAtFacing == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "Wang Shan Wang Xiang (Supreme Wealth & Health)"
            } else if facingStarAtFacing == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "Double Stars at Facing (Auspicious Wealth)"
            } else if facingStarAtMount == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "Double Stars at Sitting (Auspicious Health)"
            } else if facingStarAtMount == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "Shang Shan Xia Shui (Reverse Chart)"
            } else {
                pattern = "Balanced Harmony Chart"
            }
        } else if isHant {
            if facingStarAtFacing == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "到山到向 (旺丁旺財最吉)"
            } else if facingStarAtFacing == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "雙星到向 (旺財不旺丁 · 宜向前有水後有山)"
            } else if facingStarAtMount == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "雙星到坐 (旺丁不旺財 · 宜向後有水水後有山)"
            } else if facingStarAtMount == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "上山下水 (敗財損丁凶局 · 需借勢顛倒用法)"
            } else {
                pattern = "吉凶平和局"
            }
        } else {
            if facingStarAtFacing == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "到山到向 (旺丁旺财最吉)"
            } else if facingStarAtFacing == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "双星到向 (旺财不旺丁 · 宜向前有水后有山)"
            } else if facingStarAtMount == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "双星到坐 (旺丁不旺财 · 宜向后有水水后有山)"
            } else if facingStarAtMount == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "上山下水 (败财损丁凶局 · 需借势颠倒用法)"
            } else {
                pattern = "吉凶平和局"
            }
        }
        
        // 5. 组合九宫格模型
        var cells: [PalaceCell] = []
        for i in 0..<9 {
            let isWangM = mountainStars[i] == activePeriod
            let isWangF = facingStars[i] == activePeriod
            let isWuHuang = mountainStars[i] == 5 || facingStars[i] == 5
            let isErHei = mountainStars[i] == 2 || facingStars[i] == 2
            
            let pName = isEn ? "Palace \(i + 1) (\(palaceDirections[i]))" : (isHant ? palaceNames[i].replacingOccurrences(of: "宫", with: "宮") : palaceNames[i])
            let trigramStr = isEn ? "Palace \(i + 1)" : palaceNames[i].prefix(1).description
            
            let cell = PalaceCell(
                id: i,
                palaceName: pName,
                trigram: trigramStr,
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
        
        // 6. 综合格局断语：完全根据当前历法元信息动态生成，杜绝任何硬编码
        let summary: String
        if isEn {
            summary = "\(meta.label). Sitting \(sitting.pinyin) Facing \(facing.pinyin) presents [\(pattern)]. Cultivate auspicious Qi at the facing palace, solidify sitting mountain for harmony."
        } else if isHant {
            summary = "\(meta.isCurrent ? "當前正值" : "玄空排盤：")\(meta.yuan)\(activePeriod)運（\(meta.startYear)—\(meta.endYear)年，\(meta.starName)\(meta.element)星當令）。\(sitting.localizedName)山\(facing.localizedName)向在此元運呈現【\(pattern)】。宜重點佈局向首明堂引納\(meta.element)氣，坐後穩實以固人丁。"
        } else {
            summary = "\(meta.isCurrent ? "当前正值" : "玄空排盘：")\(meta.yuan)\(activePeriod)运（\(meta.startYear)—\(meta.endYear)年，\(meta.starName)\(meta.element)星当令）。\(sitting.name)山\(facing.name)向在此元运呈现【\(pattern)】。宜重点布局向首明堂引纳\(meta.element)气，坐后稳实以固人丁。"
        }
        
        return XuanKongChart(
            period: activePeriod,
            sittingMountain: isEn ? sitting.pinyin : (isHant ? sitting.localizedName : sitting.name),
            facingMountain: isEn ? facing.pinyin : (isHant ? facing.localizedName : facing.name),
            patternType: pattern,
            isSanBanGua: false,
            isQiXingDaJie: false,
            palaces: cells,
            summaryAnalysis: summary,
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
}
