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
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch element {
            case "水": return "Water"
            case "木": return "Wood"
            case "火": return "Fire"
            case "土": return "Earth"
            case "金": return "Metal"
            default: return element
            }
        case .ko:
            switch element {
            case "水": return "수"
            case "木": return "목"
            case "火": return "화"
            case "土": return "토"
            case "金": return "금"
            default: return element
            }
        case .vi:
            switch element {
            case "水": return "Thủy"
            case "木": return "Mộc"
            case "火": return "Hỏa"
            case "土": return "Thổ"
            case "金": return "Kim"
            default: return element
            }
        case .th:
            switch element {
            case "水": return "น้ำ"
            case "木": return "ไม้"
            case "火": return "ไฟ"
            case "土": return "ดิน"
            case "金": return "ทอง"
            default: return element
            }
        case .id:
            switch element {
            case "水": return "Air"
            case "木": return "Kayu"
            case "火": return "Api"
            case "土": return "Tanah"
            case "金": return "Logam"
            default: return element
            }
        case .zhHans, .zhHant, .ja:
            return element
        }
    }

    public var localizedEvaluation: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            if mountainStar == activePeriod && facingStar == activePeriod { return "Double Current Stars · Wealth and people prosper" }
            if facingStar == activePeriod { return "Current Wealth Star at Facing · Open and receive qi" }
            if mountainStar == activePeriod { return "Current Mountain Star returns · People prosper" }
            if isShaWuHuang || isShaErHei { return "Five Yellow and Two Black clash · Calm and use Metal remedy" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "One–Six harmony · Clear Water and Wood nourish Wenchang" }
            return "Mixed fortune · Balanced position"
        case .zhHant:
            if mountainStar == activePeriod && facingStar == activePeriod { return "當運雙星會聚 · 財丁兩旺" }
            if facingStar == activePeriod { return "當旺財星照臨 · 宜開門納氣" }
            if mountainStar == activePeriod { return "當運丁星歸位 · 人丁興旺" }
            if isShaWuHuang || isShaErHei { return "五黃二黑交加 · 宜靜安銅化解" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "一六共宗 · 水清木秀催文昌" }
            return "吉凶相參 · 平和之位"
        case .ja:
            if mountainStar == activePeriod && facingStar == activePeriod { return "当運の双星会聚 · 財丁両旺" }
            if facingStar == activePeriod { return "当旺の財星照臨 · 開門納気に適す" }
            if mountainStar == activePeriod { return "当運の丁星帰位 · 子孫繁栄" }
            if isShaWuHuang || isShaErHei { return "五黄二黒交加 · 静寂と銅器で化解" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "一六共宗 · 文昌栄達を促す" }
            return "吉凶相半 · 平和の気場"
        case .ko:
            if mountainStar == activePeriod && facingStar == activePeriod { return "당운 쌍성 회취 · 재물과 자손 모두 번창" }
            if facingStar == activePeriod { return "당왕 재성 조림 · 문을 열어 기를 받음" }
            if mountainStar == activePeriod { return "당운 정성 귀위 · 자손 번창" }
            if isShaWuHuang || isShaErHei { return "오황 이흑 교가 · 고요히 동기로 화해" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "일육공종 · 문창 학업 성취" }
            return "길흉 상참 · 평화로운 방위"
        case .vi:
            if mountainStar == activePeriod && facingStar == activePeriod { return "Đương vận song tinh hội tụ · Tài đinh lưỡng vượng" }
            if facingStar == activePeriod { return "Đương vượng tài tinh chiếu lâm · Lợi mở cửa nạp khí" }
            if mountainStar == activePeriod { return "Đương vận đinh tinh quy vị · Nhân đinh hưng vượng" }
            if isShaWuHuang || isShaErHei { return "Ngũ Hoàng Nhị Hắc giao gia · Nên tĩnh an đồng hóa giải" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "Nhất Lục cộng tông · Văn Xương học nghiệp đại cát" }
            return "Cát hung tương tham · Vị trí bình hòa"
        case .th:
            if mountainStar == activePeriod && facingStar == activePeriod { return "สองดาวมงคลชุมนุม · ร่ำรวยและลูกหลานรุ่งเรือง" }
            if facingStar == activePeriod { return "ดาวโชคลาภส่องสว่าง · เปิดรับพลังงานมงคล" }
            if mountainStar == activePeriod { return "ดาวบุญบารมีคืนตำแหน่ง · ลูกหลานเจริญรุ่งเรือง" }
            if isShaWuHuang || isShaErHei { return "ดาวห้าเหลืองปะทะดาวสองดำ · รักษาความสงบใช้โลหะแก้" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "หนึ่งหกเกื้อหนุน · ส่งเสริมสติปัญญาการเรียน" }
            return "ดีร้ายปะปน · ตำแหน่งสมดุลสงบ"
        case .id:
            if mountainStar == activePeriod && facingStar == activePeriod { return "Bintang Kembar Hadir · Kekayaan & keluarga makmur" }
            if facingStar == activePeriod { return "Bintang Rezeki Menyinari · Sambut sirkulasi energi" }
            if mountainStar == activePeriod { return "Bintang Manusia Kembali · Keturunan berkembang pesat" }
            if isShaWuHuang || isShaErHei { return "Benturan 5 Kuning & 2 Hitam · Tenang & gunakan obat logam" }
            if (mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1) { return "Harmoni Satu–Enam · Mendukung prestasi akademis" }
            return "Campuran peruntungan · Posisi seimbang"
        case .zhHans:
            return evaluation
        }
    }

    public var localizedPalaceName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            let directionMap = [
                "正北": "North", "西南": "Southwest", "正东": "East", "东南": "Southeast",
                "中宫": "Center", "西北": "Northwest", "正西": "West", "东北": "Northeast", "正南": "South"
            ]
            var result = palaceName
            for (source, localized) in directionMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        case .zhHant:
            return palaceName
                .replacingOccurrences(of: "东", with: "東")
                .replacingOccurrences(of: "兑", with: "兌")
                .replacingOccurrences(of: "离", with: "離")
                .replacingOccurrences(of: "宫", with: "宮")
        case .ja:
            return palaceName
                .replacingOccurrences(of: "东南", with: "南東")
                .replacingOccurrences(of: "西南", with: "南西")
                .replacingOccurrences(of: "东北", with: "北東")
                .replacingOccurrences(of: "西北", with: "北西")
                .replacingOccurrences(of: "东", with: "東")
                .replacingOccurrences(of: "兑", with: "兌")
                .replacingOccurrences(of: "离", with: "離")
                .replacingOccurrences(of: "宫", with: "宮")
        case .ko:
            let koMap = [
                "正北": "정북", "西南": "남서", "正东": "정동", "东南": "동남",
                "中宫": "중궁", "西北": "북서", "正西": "정서", "东北": "북동", "正南": "정남"
            ]
            var result = palaceName
            for (source, localized) in koMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        case .vi:
            let viMap = [
                "正北": "Chính Bắc", "西南": "Tây Nam", "正东": "Chính Đông", "东南": "Đông Nam",
                "中宫": "Trung Cung", "西北": "Tây Bắc", "正西": "Chính Tây", "东北": "Đông Bắc", "正南": "Chính Nam"
            ]
            var result = palaceName
            for (source, localized) in viMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        case .th:
            let thMap = [
                "正北": "ทิศเหนือ", "西南": "ทิศตะวันตกเฉียงใต้", "正东": "ทิศตะวันออก", "东南": "ทิศตะวันออกเฉียงใต้",
                "中宫": "จุดศูนย์กลาง", "西北": "ทิศตะวันตกเฉียงเหนือ", "正西": "ทิศตะวันตก", "东北": "ทิศตะวันออกเฉียงเหนือ", "正南": "ทิศใต้"
            ]
            var result = palaceName
            for (source, localized) in thMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        case .id:
            let idMap = [
                "正北": "Utara", "西南": "Barat Daya", "正东": "Timur", "东南": "Tenggara",
                "中宫": "Pusat", "西北": "Barat Laut", "正西": "Barat", "东北": "Timur Laut", "正南": "Selatan"
            ]
            var result = palaceName
            for (source, localized) in idMap {
                result = result.replacingOccurrences(of: source, with: localized)
            }
            return result
        case .zhHans:
            return palaceName
        }
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
        
        let lang = LocalizationManager.shared.effectiveLanguage
        
        let yuan: String
        let trigram: String
        let starName: String
        let element: String
        
        switch lang {
        case .en:
            let yuans = ["", "Upper Yuan", "Upper Yuan", "Upper Yuan", "Middle Yuan", "Middle Yuan", "Middle Yuan", "Lower Yuan", "Lower Yuan", "Lower Yuan"]
            let trigrams = ["", "Kan", "Kun", "Zhen", "Xun", "Center", "Qian", "Dui", "Gen", "Li"]
            let stars = ["", "1 White TanLang", "2 Black JuMen", "3 Jade LuCun", "4 Green WenQu", "5 Yellow LianZhen", "6 White WuQu", "7 Red PoJun", "8 White ZuoFu", "9 Purple YouBi"]
            let elements = ["", "Water", "Earth", "Wood", "Wood", "Earth", "Metal", "Metal", "Earth", "Fire"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .zhHant:
            let yuans = ["", "上元", "上元", "上元", "中元", "中元", "中元", "下元", "下元", "下元"]
            let trigrams = ["", "坎", "坤", "震", "巽", "中", "乾", "兌", "艮", "離"]
            let stars = ["", "一白貪狼", "二黑巨門", "三碧祿存", "四綠文曲", "五黃廉貞", "六白武曲", "七赤破軍", "八白左輔", "九紫右弼"]
            let elements = ["", "水", "土", "木", "木", "土", "金", "金", "土", "火"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .ja:
            let yuans = ["", "上元", "上元", "上元", "中元", "中元", "中元", "下元", "下元", "下元"]
            let trigrams = ["", "坎", "坤", "震", "巽", "中", "乾", "兌", "艮", "離"]
            let stars = ["", "一白貪狼", "二黒巨門", "三碧禄存", "四緑文曲", "五黄廉貞", "六白武曲", "七赤破軍", "八白左輔", "九紫右弼"]
            let elements = ["", "水", "土", "木", "木", "土", "金", "金", "土", "火"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .ko:
            let yuans = ["", "상원", "상원", "상원", "중원", "중원", "중원", "하원", "하원", "하원"]
            let trigrams = ["", "감", "곤", "진", "손", "중", "건", "태", "간", "이"]
            let stars = ["", "일백탐랑", "이흑거문", "삼벽녹존", "사록문곡", "오황염정", "육백무곡", "칠적파군", "팔백좌보", "구자우필"]
            let elements = ["", "수", "토", "목", "목", "토", "금", "금", "토", "화"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .vi:
            let yuans = ["", "Thượng Nguyên", "Thượng Nguyên", "Thượng Nguyên", "Trung Nguyên", "Trung Nguyên", "Trung Nguyên", "Hạ Nguyên", "Hạ Nguyên", "Hạ Nguyên"]
            let trigrams = ["", "Khảm", "Khôn", "Chấn", "Tốn", "Trung", "Càn", "Đoài", "Cấn", "Ly"]
            let stars = ["", "Nhất Bạch Tham Lang", "Nhị Hắc Cự Môn", "Tam Bích Lộc Tồn", "Tứ Lục Văn Khúc", "Ngũ Hoàng Liêm Trinh", "Lục Bạch Vũ Khúc", "Thất Xích Phá Quân", "Bát Bạch Tả Phụ", "Cửu Tử Hữu Bật"]
            let elements = ["", "Thủy", "Thổ", "Mộc", "Mộc", "Thổ", "Kim", "Kim", "Thổ", "Hỏa"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .th:
            let yuans = ["", "ง้วนบน", "ง้วนบน", "ง้วนบน", "ง้วนกลาง", "ง้วนกลาง", "ง้วนกลาง", "ง้วนล่าง", "ง้วนล่าง", "ง้วนล่าง"]
            let trigrams = ["", "ข่าน", "คุน", "เจิ้น", "ซวิ่น", "กลาง", "เฉียน", "ตุ้ย", "เกิ้น", "หลี"]
            let stars = ["", "หนึ่งขาว ทานหลาง", "สองดำ จวี้เหมิน", "สามเขียว ลู่ฉุน", "สี่เขียว เหวินชวี", "ห้าเหลือง เหลียนเจิน", "หกขาว อู่ชวี", "เจ็ดแดง โพ่จวิน", "แปดขาว จั่วฝู่", "เก้าม่วง โยวปี้"]
            let elements = ["", "น้ำ", "ดิน", "ไม้", "ไม้", "ดิน", "ทอง", "ทอง", "ดิน", "ไฟ"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .id:
            let yuans = ["", "Yuan Atas", "Yuan Atas", "Yuan Atas", "Yuan Tengah", "Yuan Tengah", "Yuan Tengah", "Yuan Bawah", "Yuan Bawah", "Yuan Bawah"]
            let trigrams = ["", "Kan", "Kun", "Zhen", "Xun", "Pusat", "Qian", "Dui", "Gen", "Li"]
            let stars = ["", "1 Putih TanLang", "2 Hitam JuMen", "3 Giok LuCun", "4 Hijau WenQu", "5 Kuning LianZhen", "6 Putih WuQu", "7 Merah PoJun", "8 Putih ZuoFu", "9 Ungu YouBi"]
            let elements = ["", "Air", "Tanah", "Kayu", "Kayu", "Tanah", "Logam", "Logam", "Tanah", "Api"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        case .zhHans:
            let yuans = ["", "上元", "上元", "上元", "中元", "中元", "中元", "下元", "下元", "下元"]
            let trigrams = ["", "坎", "坤", "震", "巽", "中", "乾", "兑", "艮", "离"]
            let stars = ["", "一白贪狼", "二黑巨门", "三碧禄存", "四绿文曲", "五黄廉贞", "六白武曲", "七赤破军", "八白左辅", "九紫右弼"]
            let elements = ["", "水", "土", "木", "木", "土", "金", "金", "土", "火"]
            yuan = yuans[p]; trigram = trigrams[p]; starName = stars[p]; element = elements[p]
        }
        
        let isCur = (p == curPeriod)
        let label: String
        switch lang {
        case .en:
            label = isCur ? "Current Period \(p) (\(startY)–\(endY), \(yuan) · \(element))" : "Period \(p) (\(startY)–\(endY), \(yuan) · \(element))"
        case .zhHant:
            label = isCur ? "當前\(yuan)\(p)運（\(startY)—\(endY)年，\(starName)\(element)星當令）" : "\(yuan)\(p)運（\(startY)—\(endY)年，\(starName)\(element)星當令）"
        case .ja:
            label = isCur ? "現在\(yuan)\(p)運（\(startY)—\(endY)年、\(starName)\(element)星当令）" : "\(yuan)\(p)運（\(startY)—\(endY)年、\(starName)\(element)星当令）"
        case .ko:
            label = isCur ? "현재 \(yuan) \(p)운 (\(startY)—\(endY)년, \(starName) \(element)성 당령)" : "\(yuan) \(p)운 (\(startY)—\(endY)년, \(starName) \(element)성 당령)"
        case .vi:
            label = isCur ? "Hiện tại \(yuan) Vận \(p) (\(startY)—\(endY), \(starName) \(element) tinh đương lệnh)" : "\(yuan) Vận \(p) (\(startY)—\(endY), \(starName) \(element) tinh đương lệnh)"
        case .th:
            label = isCur ? "ปัจจุบันยุค \(p) \(yuan) (\(startY)—\(endY), ดาว\(starName) ธาตุ\(element))" : "ยุค \(p) \(yuan) (\(startY)—\(endY), ดาว\(starName) ธาตุ\(element))"
        case .id:
            label = isCur ? "Periode Saat Ini \(p) (\(startY)–\(endY), \(yuan) · \(element))" : "Periode \(p) (\(startY)–\(endY), \(yuan) · \(element))"
        case .zhHans:
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
        // Use the shared astronomical boundary, including the wrapped winter
        // solstice bucket that occurs in January before Li Chun.
        let beforeLiChun = SolarTimeCalculator.shared.isBeforeLiChun(for: date)
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
        let lang = LocalizationManager.shared.effectiveLanguage
        
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
        switch lang {
        case .en:
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
        case .zhHant:
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
        case .ja:
            if facingStarAtFacing == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "到山到向 (旺丁旺財の大吉)"
            } else if facingStarAtFacing == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "双星到向 (旺財不旺丁 · 前方に水、後方に山が吉)"
            } else if facingStarAtMount == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "双星到坐 (旺丁不旺財 · 後方に水、その奥に山が吉)"
            } else if facingStarAtMount == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "上山下水 (敗財損丁の凶局 · 顛倒勢の借用が必要)"
            } else {
                pattern = "吉凶相半の平和局"
            }
        case .ko:
            if facingStarAtFacing == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "도산도향 (왕정왕재 대길)"
            } else if facingStarAtFacing == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "쌍성도향 (재물 번창 · 앞에 물 뒤에 산이 길함)"
            } else if facingStarAtMount == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "쌍성도좌 (자손 번창 · 뒤에 물과 산이 길함)"
            } else if facingStarAtMount == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "동산하수 (손재패가 흉국 · 전도법 응용 필요)"
            } else {
                pattern = "길흉 평화국"
            }
        case .vi:
            if facingStarAtFacing == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "Đáo Sơn Đáo Hướng (Vượng đinh vượng tài đại cát)"
            } else if facingStarAtFacing == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "Song Tinh Đáo Hướng (Vượng tài · Trước có nước sau có núi)"
            } else if facingStarAtMount == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "Song Tinh Đáo Tọa (Vượng đinh · Sau có nước sau nước có núi)"
            } else if facingStarAtMount == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "Thượng Sơn Hạ Thủy (Bại tài tổn đinh hung cục · Cần phép điên đảo)"
            } else {
                pattern = "Cát hung bình hòa cục"
            }
        case .th:
            if facingStarAtFacing == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "ถึงเขาถึงทิศ (เจริญทั้งคนและทรัพย์ มงคลยิ่ง)"
            } else if facingStarAtFacing == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "สองดาวสู่ทิศหน้า (รุ่งเรืองทรัพย์สิน · หน้าควรมีน้ำหลังมีเขา)"
            } else if facingStarAtMount == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "สองดาวสู่หลังพิง (ลูกหลานรุ่งเรือง · หลังควรมีน้ำและมีเขา)"
            } else if facingStarAtMount == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "ขึ้นเขาลงน้ำ (สูญเสียทรัพย์และคน เคราะห์ร้าย · ต้องกลับทิศแก้เคล็ด)"
            } else {
                pattern = "สมดุลปานกลาง"
            }
        case .id:
            if facingStarAtFacing == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "Wang Shan Wang Xiang (Makmur Keluarga & Harta)"
            } else if facingStarAtFacing == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "Bintang Kembar di Hadap (Kaya Harta · Air di Depan, Gunung di Belakang)"
            } else if facingStarAtMount == activePeriod && mountainStarAtMount == activePeriod {
                pattern = "Bintang Kembar di Duduk (Banyak Keturunan · Air & Gunung di Belakang)"
            } else if facingStarAtMount == activePeriod && mountainStarAtFacing == activePeriod {
                pattern = "Shang Shan Xia Shui (Peta Terbalik · Rawan Kerugian Harta & Fisik)"
            } else {
                pattern = "Peta Harmonis Seimbang"
            }
        case .zhHans:
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
            
            let cell = PalaceCell(
                id: i,
                palaceName: palaceNames[i],
                trigram: palaceNames[i].prefix(1).description,
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
        
        // 6. 综合格局断语
        let summary: String
        let sittingName = sitting.localizedName
        let facingName = facing.localizedName
        switch lang {
        case .en:
            summary = "\(meta.label). Sitting \(sittingName) Facing \(facingName) presents [\(pattern)]. Cultivate auspicious Qi at the facing palace, solidify sitting mountain for harmony."
        case .zhHant:
            summary = "\(meta.isCurrent ? "當前正值" : "玄空排盤：")\(meta.yuan)\(activePeriod)運（\(meta.startYear)—\(meta.endYear)年，\(meta.starName)\(meta.element)星當令）。\(sittingName)山\(facingName)向在此元運呈現【\(pattern)】。宜重點佈局向首明堂引納\(meta.element)氣，坐後穩實以固人丁。"
        case .ja:
            summary = "\(meta.isCurrent ? "現在は" : "玄空飛星：")\(meta.yuan)\(activePeriod)運（\(meta.startYear)—\(meta.endYear)年、\(meta.starName)\(meta.element)星当令）。\(sittingName)山\(facingName)向はこの元運で【\(pattern)】となります。向首明堂に吉気を引込み、坐後を堅固にして子孫健康を守ると吉。"
        case .ko:
            summary = "\(meta.isCurrent ? "현재는 " : "현공 비성: ")\(meta.yuan) \(activePeriod)운 (\(meta.startYear)—\(meta.endYear)년, \(meta.starName) \(meta.element)성 당령). \(sittingName)산 \(facingName)향은 이 원운에서 【\(pattern)】을 이룹니다. 향수 명당에 기운을 받아들이고 좌산을 든든히 하여 인정을 보존함이 길합니다."
        case .vi:
            summary = "\(meta.isCurrent ? "Hiện tại chính là " : "Huyền Không bài bàn: ")\(meta.yuan) Vận \(activePeriod) (\(meta.startYear)—\(meta.endYear), \(meta.starName) \(meta.element) tinh đương lệnh). \(sittingName) sơn \(facingName) hướng trong nguyên vận này biểu hiện 【\(pattern)】. Nên bố trí minh đường nạp khí, tọa sơn vững chãi vượng nhân đinh."
        case .th:
            summary = "\(meta.isCurrent ? "ปัจจุบันเข้าสู่ " : "ผังเหวินคง: ")\(meta.yuan) ยุค \(activePeriod) (\(meta.startYear)—\(meta.endYear), ดาว\(meta.starName) ธาตุ\(meta.element)). \(sittingName)พิง \(facingName)หัน ในยุคนี้ปรากฏเป็น 【\(pattern)】 ควรจัดหมุนเวียนพลังงานด้านหน้า และรักษาความมั่นคงด้านหลังเพื่อเสริมสิริมงคล"
        case .id:
            summary = "\(meta.isCurrent ? "Saat ini berada pada " : "Bagan Xuan Kong: ")\(meta.yuan) Periode \(activePeriod) (\(meta.startYear)–\(meta.endYear), Bintang \(meta.starName) Unsur \(meta.element)). Posisi Duduk \(sittingName) Hadap \(facingName) membentuk [\(pattern)]. Atur tata ruang hadap untuk menyerap energi positif dan perkuat posisi duduk demi ketentraman keluarga."
        case .zhHans:
            summary = "\(meta.isCurrent ? "当前正值" : "玄空排盘：")\(meta.yuan)\(activePeriod)运（\(meta.startYear)—\(meta.endYear)年，\(meta.starName)\(meta.element)星当令）。\(sittingName)山\(facingName)向在此元运呈现【\(pattern)】。宜重点布局向首明堂引纳\(meta.element)气，坐后稳实以固人丁。"
        }
        
        return XuanKongChart(
            period: activePeriod,
            sittingMountain: sittingName,
            facingMountain: facingName,
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
