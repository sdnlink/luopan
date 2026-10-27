import Foundation

// MARK: - 天星择日与动土安门日课自检引擎 (ZeRi Engine - PRD 动土神煞与日课排盘)

public struct ZeRiAnalysis {
    public let fourPillarsText: String
    public let overallStatus: String
    public let isAuspicious: Bool
    public let suiPoWarning: String?
    public let yuePoWarning: String?
    public let sanShaWarning: String?
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
    
    public func analyze(date: Date = Date(), sitting: Mountain24Item) -> ZeRiAnalysis {
        let calendar = Calendar(identifier: .gregorian)
        let comp = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let now = Date()
        let year = comp.year ?? calendar.component(.year, from: now)
        let month = comp.month ?? calendar.component(.month, from: now)
        let day = comp.day ?? calendar.component(.day, from: now)
        let hour = comp.hour ?? calendar.component(.hour, from: now)
        
        let lang = LocalizationManager.shared.effectiveLanguage
        
        // 1. 年柱干支 (严格遵循立春交岁天干地支更迭法则)
        let isBeforeLiChun = (month < 2 || (month == 2 && day < 4))
        let gzYear = isBeforeLiChun ? (year - 1) : year
        let yOffset = (gzYear - 4) % 60
        let yearStem = stems[((yOffset % 10) + 10) % 10]
        let yearBranch = branches[((yOffset % 12) + 12) % 12]
        
        // 2. 月柱干支 (五虎遁年起月诀)
        let mBranchIdx = (month + 1) % 12
        let mBranch = branches[mBranchIdx]
        let stemIdx = stems.firstIndex(of: yearStem) ?? 0
        let mStemStart = (stemIdx % 5) * 2 + 2
        let mStem = stems[(mStemStart + month - 1) % 10]
        
        // 3. 日柱干支 (高精度儒略日算法)
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        let jdn = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
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
        if lang == .en {
            let pinyinStems = ["甲": "Jia", "乙": "Yi", "丙": "Bing", "丁": "Ding", "戊": "Wu", "己": "Ji", "庚": "Geng", "辛": "Xin", "壬": "Ren", "癸": "Gui"]
            let pinyinBranches = ["子": "Zi", "丑": "Chou", "寅": "Yin", "卯": "Mao", "辰": "Chen", "巳": "Si", "午": "Wu", "未": "Wei", "申": "Shen", "酉": "You", "戌": "Xu", "亥": "Hai"]
            let yStr = "\(pinyinStems[yearStem] ?? yearStem)-\(pinyinBranches[yearBranch] ?? yearBranch)"
            let mStr = "\(pinyinStems[mStem] ?? mStem)-\(pinyinBranches[mBranch] ?? mBranch)"
            let dStr = "\(pinyinStems[dayStem] ?? dayStem)-\(pinyinBranches[dayBranch] ?? dayBranch)"
            let hStr = "\(pinyinStems[hStem] ?? hStem)-\(pinyinBranches[hBranch] ?? hBranch)"
            pillars = "\(yStr) Year · \(mStr) Month · \(dStr) Day · \(hStr) Hour"
        } else {
            pillars = "\(yearStem)\(yearBranch)年 \(mStem)\(mBranch)月 \(dayStem)\(dayBranch)日 \(hStem)\(hBranch)时"
        }
        
        // 5. 神煞冲克判定
        var warnings: [String] = []
        var suiPo: String? = nil
        var yuePo: String? = nil
        var sanSha: String? = nil
        
        // 岁破冲煞：日支冲太岁年支
        if clashMap[dayBranch] == yearBranch {
            if lang == .en {
                suiPo = "Day branch clashes with Year Grand Duke (\(yearBranch)); Year Clash Taboo."
            } else if lang == .zhHant {
                suiPo = "今日【\(dayBranch)日】直衝年支太歲【\(yearBranch)位】，犯【歲破大煞】，主百事不利。"
            } else {
                suiPo = "今日【\(dayBranch)日】直冲年支太岁【\(yearBranch)位】，犯【岁破大煞】，主百事不利。"
            }
            warnings.append(suiPo!)
        }
        
        // 月破冲煞：日支冲当令月支
        if clashMap[dayBranch] == mBranch {
            if lang == .en {
                yuePo = "Day branch clashes with Month Commander (\(mBranch)); Month Clash Taboo."
            } else if lang == .zhHant {
                yuePo = "今日【\(dayBranch)日】直衝月令月建【\(mBranch)位】，犯【月破大耗】，凡事避忌。"
            } else {
                yuePo = "今日【\(dayBranch)日】直冲月令月建【\(mBranch)位】，犯【月破大耗】，凡事避忌。"
            }
            warnings.append(yuePo!)
        }
        
        // 坐山冲犯：日支直冲房屋坐山地支
        if let sClash = clashMap[sitting.name], sClash == dayBranch {
            if lang == .en {
                sanSha = "Day branch clashes with House Sitting Mountain (\(sitting.pinyin)); Sitting Clash Taboo."
            } else if lang == .zhHant {
                sanSha = "今日日支【\(dayBranch)】直衝本宅坐山【\(sitting.name)山】，犯【衝山大忌】，切勿動土安門！"
            } else {
                sanSha = "今日日支【\(dayBranch)】直冲本宅坐山【\(sitting.name)山】，犯【冲山大忌】，切勿动土安门！"
            }
            warnings.append(sanSha!)
        }
        
        let isAuspicious = warnings.isEmpty
        let status: String
        if lang == .en {
            status = isAuspicious ? "Auspicious Day" : "Clash Detected"
        } else if lang == .zhHant {
            status = isAuspicious ? "今日日課吉" : "動土神煞有衝"
        } else {
            status = isAuspicious ? "今日日课吉" : "动土神煞有冲"
        }
        
        let details: String
        if isAuspicious {
            if lang == .en {
                details = "Sitting Mountain Sha: Free from Year/Month clash. Harmonious Four Pillars, ideal for construction and door installation."
            } else if lang == .zhHant {
                details = "坐向神煞：無歲破、無月破、無坐向衝克。四柱比和合化，宜修造動土、安門立向。"
            } else {
                details = "坐向神煞：无岁破、无月破、无坐向冲克。四柱比和合化，宜修造动土、安门立向。"
            }
        } else {
            details = warnings.joined(separator: " ")
        }
        
        let yi: [String]
        let ji: [String]
        if lang == .en {
            yi = isAuspicious ? ["Groundbreaking", "Door Installation", "Housewarming", "Business Opening"] : ["Meditation", "Spiritual Cultivation"]
            ji = isAuspicious ? ["Excavation near graves", "Aggressive Acts"] : ["Construction", "Door Installation", "Moving In"]
        } else if lang == .zhHant {
            yi = isAuspicious ? ["動土起造", "安門修方", "入宅安香", "開業祈福"] : ["靜思祈禱", "祭祀修心"]
            ji = isAuspicious ? ["破土開生墳", "暴烈行事"] : ["修造動土", "安門立向", "入宅開張"]
        } else {
            yi = isAuspicious ? ["动土起造", "安门修方", "入宅安香", "开业祈福"] : ["静思祈祷", "祭祀修心"]
            ji = isAuspicious ? ["破土开生坟", "暴烈行事"] : ["修造动土", "安门立向", "入宅开张"]
        }
        
        return ZeRiAnalysis(
            fourPillarsText: pillars,
            overallStatus: status,
            isAuspicious: isAuspicious,
            suiPoWarning: suiPo,
            yuePoWarning: yuePo,
            sanShaWarning: sanSha,
            detailsText: details,
            yiActivities: yi,
            jiActivities: ji
        )
    }
}
