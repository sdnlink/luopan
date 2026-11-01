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
        case .auto, .zhHans, .zhHant, .ja:
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
        case .auto, .zhHans:
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
        case .auto, .zhHans:
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
    public let isTiGua: Bool             // 是否为兼向替卦排盘
    public let chartModeTitle: String    // 排盘模式 (下卦 / 替卦)
    public let palaces: [PalaceCell]     // 九宫格数据
    public let summaryAnalysis: String   // 综合格局断语
    public var patternDesc: String { summaryAnalysis }
    public let periodMeta: PeriodMeta    // 动态历法元信息
    
    /// 基于九宫飞星排盘动态推导的【催财旺气建议】
    public var wealthAdvice: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        let wangPalace = palaces.first(where: { $0.facingStar == period })
        let nextStar = (period % 9) + 1
        let shengQiPalace = palaces.first(where: { !$0.isCenter && $0.facingStar == nextStar }) ?? palaces.first(where: { $0.facingStar == nextStar })
        let wenchangPalace = palaces.first(where: { !$0.isCenter && (($0.mountainStar == 1 && $0.facingStar == 4) || ($0.mountainStar == 4 && $0.facingStar == 1) || ($0.mountainStar == 1 && $0.facingStar == 6) || ($0.mountainStar == 6 && $0.facingStar == 1)) })
        
        let wangName = wangPalace?.localizedPalaceName ?? ""
        let wangCombo = wangPalace.map { "\($0.mountainStar)-\($0.facingStar)" } ?? "\(period)"
        let sqName = shengQiPalace?.localizedPalaceName ?? ""
        let sqCombo = shengQiPalace.map { "\($0.mountainStar)-\($0.facingStar)" } ?? "\(nextStar)"
        let wcName = wenchangPalace?.localizedPalaceName
        
        switch lang {
        case .en:
            let wcNote = wcName.map { " Wenchang/Harmony star gathers at [\($0)]." } ?? ""
            return "• Wealth & Prosperity: Current Period-\(period) facing star lands at [\(wangName)] (Star \(wangCombo)), and future Sheng-Qi Star \(nextStar) reaches [\(sqName)] (Star \(sqCombo)). Keep these sectors bright, open, or place moving water to activate wealth.\(wcNote)"
        case .zhHant:
            let wcNote = wcName.map { "另【\($0)】逢文昌吉星會聚，利書房策劃。" } ?? ""
            return "• 催財旺位：當令\(period)運向星飛臨【\(wangName)】（山向\(wangCombo)），生氣\(nextStar)星到【\(sqName)】（山向\(sqCombo)），宜在此保持明堂開闊、安設動水或長明燈催旺財源。\(wcNote)"
        case .ja:
            let wcNote = wcName.map { "また【\($0)】は文昌吉星が会聚し書斎に吉。" } ?? ""
            return "• 催財旺位：当令\(period)運の向星が【\(wangName)】（山向\(wangCombo)）に飛臨し、生気\(nextStar)星が【\(sqName)】（山向\(sqCombo)）に到ります。採光や動水を設けて財気を催旺してください。\(wcNote)"
        case .ko:
            return "• 재물 발복 방위: 당령 \(period)운 향성이 【\(wangName)】(산향 \(wangCombo))에 비림하고 생기 \(nextStar)성이 【\(sqName)】(산향 \(sqCombo))에 이르니, 채광을 밝히고 동수(물)를 배치하여 재원을 활성화하십시오."
        case .vi:
            return "• Cung kích tài: Hướng tinh đương vận \(period) bay tới 【\(wangName)】 (Sơn Hướng \(wangCombo)), sinh khí tinh \(nextStar) đáo 【\(sqName)】 (Sơn Hướng \(sqCombo)), nên mở thoáng, tăng ánh sáng hoặc đặt thủy động kích hoạt tài lộc."
        case .th:
            return "• ตำแหน่งเรียกทรัพย์: ดาวหันประจำยุค \(period) สถิตที่ 【\(wangName)】 (ดาว \(wangCombo)) และดาวพลัง生气 \(nextStar) อยู่ที่ 【\(sqName)】 (ดาว \(sqCombo)) ควรเปิดโล่งรับแสงหรือตั้งน้ำพุกระตุ้นโชคลาภ"
        case .id:
            return "• Sektor Rezeki: Bintang hadap periode \(period) berada di [\(wangName)] (Bintang \(wangCombo)) & bintang Sheng-Qi \(nextStar) di [\(sqName)] (Bintang \(sqCombo)); buka sirkulasi cahaya atau letakkan air mengalir untuk mengaktifkan rezeki."
        case .auto, .zhHans:
            let wcNote = wcName.map { "另【\($0)】逢文昌吉星会聚，利书房策划。" } ?? ""
            return "• 催财旺位：当令\(period)运向星飞临【\(wangName)】（山向\(wangCombo)），生气\(nextStar)星到【\(sqName)】（山向\(sqCombo)），宜在此保持明堂开阔、安设动水或长明灯催旺财源。\(wcNote)"
        }
    }
    
    /// 基于九宫飞星排盘动态推导的【五黄二黑病符防煞建议】
    public var healthAdvice: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        let clash25Palace = palaces.first(where: { ($0.mountainStar == 2 && $0.facingStar == 5) || ($0.mountainStar == 5 && $0.facingStar == 2) || ($0.mountainStar == 5 && $0.facingStar == 5) })
        let wuHuangPalace = palaces.first(where: { $0.facingStar == 5 }) ?? palaces.first(where: { $0.mountainStar == 5 })
        let erHeiPalace = palaces.first(where: { $0.facingStar == 2 }) ?? palaces.first(where: { $0.mountainStar == 2 })
        
        let wuName = wuHuangPalace?.localizedPalaceName ?? ""
        let wuCombo = wuHuangPalace.map { "\($0.mountainStar)-\($0.facingStar)" } ?? "5"
        let erName = erHeiPalace?.localizedPalaceName ?? ""
        let erCombo = erHeiPalace.map { "\($0.mountainStar)-\($0.facingStar)" } ?? "2"
        
        switch lang {
        case .en:
            if let clash = clash25Palace {
                return "• Health & Sha Caution: Critical 2–5 / Double-5 Earth Sha converges at [\(clash.localizedPalaceName)] (Star \(clash.mountainStar)-\(clash.facingStar)), with 5-Yellow at [\(wuName)] and 2-Black at [\(erName)]. Keep quiet, avoid renovation or red items, and place a copper gourd or 6-coin Metal cure."
            }
            return "• Health & Sha Caution: 5-Yellow Sha lands at [\(wuName)] (Star \(wuCombo)) and 2-Black Sickness Star at [\(erName)] (Star \(erCombo)). Avoid loud noise, drilling, or fire elements here; use copper/Metal ornaments to drain Earth Sha."
        case .zhHant:
            if let clash = clash25Palace {
                return "• 病符防煞：【\(clash.localizedPalaceName)】逢山向\(clash.mountainStar)-\(clash.facingStar)二五交加/五黃疊臨重煞（五黃位【\(wuName)】、二黑位【\(erName)】），切忌動土裝修與紅紫火物，務必安放銅葫蘆或六帝錢洩土化煞。"
            }
            return "• 病符防煞：五黃廉貞煞飛臨【\(wuName)】（山向\(wuCombo)），二黑病符星到【\(erName)】（山向\(erCombo)），此二宮宜靜不宜動，忌見紅火動土，宜掛銅葫蘆或六帝銅錢化洩凶性。"
        case .ja:
            if let clash = clash25Palace {
                return "• 病符防煞：【\(clash.localizedPalaceName)】に山向\(clash.mountainStar)-\(clash.facingStar)の二五交加・五黄重煞が集結（五黄【\(wuName)】・二黒【\(erName)】）。改修や赤色物を避け、銅瓢箪や六帝銭で土煞を泄化してください。"
            }
            return "• 病符防煞：五黄廉貞煞が【\(wuName)】（山向\(wuCombo)）、二黒病符星が【\(erName)】（山向\(erCombo)）に飛臨。静寂を保ち、銅瓢箪や金属置物で凶気を化泄すると吉。"
        case .ko:
            return "• 병부 방살: 오황살이 【\(wuName)】(산향 \(wuCombo))에, 이흑 병부성이 【\(erName)】(산향 \(erCombo))에 위치합니다. 공사와 붉은색 배치를 피하고 동호리병이나 육제전(금속)으로 토살을 설기하십시오."
        case .vi:
            return "• Phòng bệnh hóa sát: Ngũ Hoàng sát临 【\(wuName)】 (Sơn Hướng \(wuCombo)), Nhị Hắc bệnh phù đáo 【\(erName)】 (Sơn Hướng \(erCombo)). Kỵ động thổ và vật màu đỏ, nên treo hồ lô đồng hoặc lục đế tiền để tiết thổ hóa sát."
        case .th:
            return "• ป้องกันโรคและเคราะห์: ดาวห้าเหลืองอยู่ที่ 【\(wuName)】 (ดาว \(wuCombo)) และดาวสองดำโรคภัยอยู่ที่ 【\(erName)】 (ดาว \(erCombo)) หลีกเลี่ยงการต่อเติมและสีแดง แนะนำแขวนน้ำเต้าทองเหลืองหรือเหรียญจีน 6 เหรียญแก้เคล็ด"
        case .id:
            return "• Kesehatan & Penangkal Sha: Bintang 5-Kuning berada di [\(wuName)] (Bintang \(wuCombo)) & 2-Hitam di [\(erName)] (Bintang \(erCombo)); hindari renovasi atau warna merah menyala, gunakan labu tembaga/logam untuk menetralkan."
        case .auto, .zhHans:
            if let clash = clash25Palace {
                return "• 病符防煞：【\(clash.localizedPalaceName)】逢山向\(clash.mountainStar)-\(clash.facingStar)二五交加/五黄叠临重煞（五黄位【\(wuName)】、二黑位【\(erName)】），切忌动土装修与红紫火物，务必安放铜葫芦或六帝钱泄土化煞。"
            }
            return "• 病符防煞：五黄廉贞煞飞临【\(wuName)】（山向\(wuCombo)），二黑病符星到【\(erName)】（山向\(erCombo)），此二宫宜静不宜动，忌见红火动土，宜挂铜葫芦或六帝铜钱化泄凶性。"
        }
    }
    
    /// 基于九宫飞星排盘动态推导的【山向调候与五行通关建议】
    public var remedyAdvice: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        let dingPalace = palaces.first(where: { $0.mountainStar == period })
        let caiPalace = palaces.first(where: { $0.facingStar == period })
        let clash37Palace = palaces.first(where: { !$0.isCenter && (($0.mountainStar == 3 && $0.facingStar == 7) || ($0.mountainStar == 7 && $0.facingStar == 3)) })
        let clash79Palace = palaces.first(where: { !$0.isCenter && (($0.mountainStar == 7 && $0.facingStar == 9) || ($0.mountainStar == 9 && $0.facingStar == 7)) })
        
        let dingName = dingPalace?.localizedPalaceName ?? ""
        let caiName = caiPalace?.localizedPalaceName ?? ""
        let samePalace = (dingPalace?.id != nil && dingPalace?.id == caiPalace?.id)
        
        switch lang {
        case .en:
            var extra = ""
            if let c37 = clash37Palace {
                extra = " At [\(c37.localizedPalaceName)] (3–7 Metal-Wood clash), place still water to harmonize."
            } else if let c79 = clash79Palace {
                extra = " At [\(c79.localizedPalaceName)] (7–9 Fire-Metal clash), place ceramic/earth decor to balance."
            }
            if samePalace {
                return "Plain: The Period-\(period) wealth & health stars both land at [\(caiName)]. What to do: Keep water (aquarium/water feature) in front to gather wealth, and a solid cabinet or stone behind to steady health. → Effect: Manages the family's steady income & career (breadwinner & business members) plus everyone's health and the children's constitution, both at [\(caiName)].\(extra)"
            }
            return "Plain: The Period-\(period) wealth star sits at [\(caiName)]. What to do: Keep this sector open, bright and water-visible (aquarium, mirror, water feature) to gather wealth; the health star at [\(dingName)] benefits from a tall cabinet or stone ornament. → Effect: The wealth sector manages the family's income & career (breadwinner), the health sector manages family health and the children's constitution; covers [\(caiName)] and [\(dingName)].\(extra)"
        case .zhHant:
            var extra = ""
            if let c37 = clash37Palace {
                extra = "【\(c37.localizedPalaceName)】見三七交劍煞，宜設靜水通關金木。"
            } else if let c79 = clash79Palace {
                extra = "【\(c79.localizedPalaceName)】見七九火金相戰，宜置黃玉陶瓷洩火生金。"
            }
            if samePalace {
                return "白話：當運山向雙\(period)星同聚【\(caiName)】，此方位前宜見水（魚缸/水景）納財、後宜立高櫃或山石固丁。→ 影響：財丁同管——財管男主人及經營家人的正財事業、丁管全家健康與小孩體質，覆蓋【\(caiName)】區域。\(extra)"
            }
            return "白話：當運財星在【\(caiName)】，此方位宜敞亮見水（魚缸、水景或鏡面）聚財；當運丁星在【\(dingName)】，宜放高櫃或山石穩住健康人丁。→ 影響：財位管家中的正財與事業進帳（男主人與經營家人）、丁位管家人健康與人丁（小孩體質、長輩康健），分別覆蓋【\(caiName)】【\(dingName)】區域。\(extra)"
        case .ja:
            var extra = ""
            if let c37 = clash37Palace {
                extra = "【\(c37.localizedPalaceName)】の三七交剣煞には静水で金木を通関。"
            } else if let c79 = clash79Palace {
                extra = "【\(c79.localizedPalaceName)】の七九火金相克には陶器・土器で調和。"
            }
            if samePalace {
                return "わかりやすく：当運の山向双\(period)星が【\(caiName)】に同聚。前方に水（水槽・水景）を置いて財を集め、後方に高家具か山石で家族を固めます。→ 効果：一家の収入と働き手の仕事、全員の健康と子供の体質に作用。【\(caiName)】の領域に効果。\(extra)"
            }
            return "わかりやすく：当運の財星は【\(caiName)】にあります。この方位は明るく開け、水（水槽・水景・鏡）を置くと財を集めます。当運の丁星【\(dingName)】は背の高い家具や山石で健康・人丁を固めます。→ 効果：財位は一家の収入・仕事（働き手）、丁位は家族の健康と子供の体質に作用し、【\(caiName)】【\(dingName)】の領域に効果。\(extra)"
        case .ko:
            if samePalace {
                return "쉽게: 당운 산향 쌍\(period)성이 【\(caiName)】에 모입니다. 앞에 물(어항·수경)을 두어 재물을 모으고, 뒤에 높은 가구나 산석으로 가족을 굳힙니다. → 효과: 한 집안의 수입·일(생계를 책임지는 사람)과 온 가족의 건강·아이 체질에 작용, 【\(caiName)】 영역."
            }
            return "쉽게: 당운 재성이 【\(caiName)】에 있습니다. 이 방위는 밝고 트이게 두고 물(어항·수경·거울)을 두어 재물을 모읍니다. 당운 정성 【\(dingName)】은 높은 가구나 산석으로 건강과 가족을 굳힙니다. → 효과: 재위는 집안의 수입·일(가장), 정위는 가족 건강과 아이 체질에 작용하며 【\(caiName)】【\(dingName)】 영역에 효과."
        case .vi:
            if samePalace {
                return "Giải thích đơn giản: Song tinh \(period) tụ tại 【\(caiName)】. Trước đặt nước (bể cá, thủy cảnh) tụ tài, sau đặt tủ cao hoặc đá vững nhân khẩu. → Ảnh hưởng: Quản thu nhập, công việc của trụ cột gia đình và sức khỏe mọi người, thể chất trẻ em; phủ 【\(caiName)】."
            }
            return "Giải thích đơn giản: Sao tài vận \(period) đáo 【\(caiName)】. Nơi này nên thoáng sáng và thấy nước (bể cá, thủy cảnh, gương) để tụ tài; sao đinh 【\(dingName)】 nên đặt tủ cao hoặc đá để vững sức khỏe và nhân khẩu. → Ảnh hưởng: Vị trí tài quản thu nhập và công danh của gia đình (trụ cột), vị trí đinh quản sức khỏe gia đình và thể chất trẻ; phủ 【\(caiName)】【\(dingName)】."
        case .th:
            if samePalace {
                return "อธิบายง่ายๆ: ดาวคู่ยุค \(period) รวมที่【\(caiName)】 วางน้ำด้านหน้าทรัพย์ ตั้งตู้สูงหรือหินด้านหลังเสริมคน → ผล: ดูแลรายได้และงานของผู้หาเลี้ยงครอบครัว และสุขภาพทุกคน กับร่างกายของเด็ก ครอบคลุม【\(caiName)】"
            }
            return "อธิบายง่ายๆ: ดาวทรัพย์ยุค \(period) อยู่ที่【\(caiName)】 ควรเปิดโล่งสว่างและเห็นน้ำ (ตู้ปลา น้ำตกจำลอง กระจก) เพื่อเรียกทรัพย์ ดาวคน【\(dingName)】 ตั้งตู้สูงหรือหินเสริมสุขภาพและคนในบ้าน → ผล: ตำแหน่งทรัพย์ดูแลรายได้และงานของผู้หาเลี้ยง ตำแหน่งคนดูแลสุขภาพครอบครัวและร่างกายเด็ก ครอบคลุม【\(caiName)】【\(dingName)】"
        case .id:
            if samePalace {
                return "Ringkas: Bintang kembar periode \(period) berkumpul di [\(caiName)]. Letakkan air di depan (akuarium/fitur air) untuk rezeki dan kabinet kokoh/batu di belakang untuk kesehatan. → Efek: Mengelola pendapatan & karier pencari nafkah serta kesehatan semua dan tubuh anak; mencakup [\(caiName)]."
            }
            return "Ringkas: Bintang rezeki periode \(period) berada di [\(caiName)]. Biarkan sektor ini terang, terbuka dan terlihat air (akuarium, fitur air, cermin) untuk mengumpulkan rezeki; bintang kesehatan [\(dingName)] diperkuat dengan lemari tinggi atau batu. → Efek: Sektor rezeki mengelola pendapatan & karier keluarga (pencari nafkah), sektor kesehatan mengelola kesehatan keluarga dan tubuh anak; mencakup [\(caiName)] & [\(dingName)]."
        case .auto, .zhHans:
            var extra = ""
            if let c37 = clash37Palace {
                extra = "【\(c37.localizedPalaceName)】见三七交剑煞，宜设静水通关金木。"
            } else if let c79 = clash79Palace {
                extra = "【\(c79.localizedPalaceName)】见七九火金相战，宜置黄玉陶瓷泄火生金。"
            }
            if samePalace {
                return "白话：当运山向双\(period)星同聚【\(caiName)】，此方位前宜见水（鱼缸/水景）纳财、后宜立高柜或山石固丁。→ 影响：财丁同管——财管男主人及经营家人的正财事业、丁管全家健康与小孩体质，覆盖【\(caiName)】区域。\(extra)"
            }
            return "白话：当运财星在【\(caiName)】，此方位宜敞亮见水（鱼缸、水景或镜面）聚财；当运丁星在【\(dingName)】，宜放高柜或山石稳住健康人丁。→ 影响：财位管家中正财与事业进账（男主人与经营家人）、丁位管家人健康与人丁（小孩体质、长辈康健），分别覆盖【\(caiName)】【\(dingName)】区域。\(extra)"
        }
    }
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
        case .auto, .zhHans:
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
        case .auto, .zhHans:
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
    
    /// 24山正统替卦口诀映射表 (沈氏玄空替卦诀)：
    /// 子癸并甲申，贪狼一路行 (1)；壬卯乙未坤，五位为巨门 (2)；
    /// 乾戌辰巽巳亥，尽是武曲位 (6)；艮丙酉辛丑，全归破军位 (7)；
    /// 寅午庚丁上，右弼九星迎 (9)。
    private static let tiGuaStarMap: [String: Int] = [
        "子": 1, "癸": 1, "甲": 1, "申": 1,
        "壬": 2, "卯": 2, "乙": 2, "未": 2, "坤": 2,
        "乾": 6, "戌": 6, "辰": 6, "巽": 6, "巳": 6, "亥": 6,
        "艮": 7, "丙": 7, "酉": 7, "辛": 7, "丑": 7,
        "寅": 9, "午": 9, "庚": 9, "丁": 9
    ]

    /// 计算入中之星与顺逆飞性（支持正向下卦与兼向替卦）：
    /// - 下卦：运星直接入中，依坐向山元龙查运星本宫同元龙之山阴阳定顺逆。
    /// - 替卦：查运星本宫同元龙之山，依替卦口诀取替星入中；顺逆仍以原所对应之山阴阳判定。
    private func resolveStarAndPolarity(
        periodStarInPalace: Int,
        baseMountain: Mountain24Item,
        useTiGua: Bool
    ) -> (starInCentral: Int, isForward: Bool) {
        if periodStarInPalace == 5 {
            // 五黄到宫：无替，随坐向本山之元龙阴阳顺逆
            let subStar = useTiGua ? (Self.tiGuaStarMap[baseMountain.name] ?? 5) : 5
            return (subStar, baseMountain.polarity > 0)
        }
        
        let palaceNameByStar: [Int: String] = [
            1: "坎", 2: "坤", 3: "震", 4: "巽",
            6: "乾", 7: "兑", 8: "艮", 9: "离"
        ]
        guard let homePalace = palaceNameByStar[periodStarInPalace] else {
            return (periodStarInPalace, baseMountain.polarity > 0)
        }
        let homeMountains = Mountain24Data.shared.mountains.filter { $0.palace == homePalace }
        guard let matched = homeMountains.first(where: { $0.yuan == baseMountain.yuan }) else {
            return (periodStarInPalace, baseMountain.polarity > 0)
        }
        
        let star = useTiGua ? (Self.tiGuaStarMap[matched.name] ?? periodStarInPalace) : periodStarInPalace
        let isForward = matched.polarity > 0
        return (star, isForward)
    }

    public func calculateChart(
        period: Int? = nil,
        sitting: Mountain24Item,
        facing: Mountain24Item,
        useTiGua: Bool = false,
        date: Date = Date()
    ) -> XuanKongChart {
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
        
        // 2. 查坐山与向山所在宫位的运盘星，定山星与向星入中 (支持正向下卦与兼向替卦)
        let sittingPalaceIdx = palaceIndex(for: sitting.palace)
        let facingPalaceIdx = palaceIndex(for: facing.palace)
        
        let sittingPeriodStar = basePeriod[sittingPalaceIdx]
        let facingPeriodStar = basePeriod[facingPalaceIdx]
        
        // 3. 计算山向星入中数字与顺逆飞性 (下卦正针 vs 兼向替卦)
        let sittingResult = resolveStarAndPolarity(periodStarInPalace: sittingPeriodStar, baseMountain: sitting, useTiGua: useTiGua)
        let facingResult = resolveStarAndPolarity(periodStarInPalace: facingPeriodStar, baseMountain: facing, useTiGua: useTiGua)
        let sittingInCentral = sittingResult.starInCentral
        let sittingIsForward = sittingResult.isForward
        let facingInCentral = facingResult.starInCentral
        let facingIsForward = facingResult.isForward
        
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
        case .auto, .zhHans:
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
        case .auto, .zhHans:
            summary = "\(meta.isCurrent ? "当前正值" : "玄空排盘：")\(meta.yuan)\(activePeriod)运（\(meta.startYear)—\(meta.endYear)年，\(meta.starName)\(meta.element)星当令）。\(sittingName)山\(facingName)向在此元运呈现【\(pattern)】。宜重点布局向首明堂引纳\(meta.element)气，坐后稳实以固人丁。"
        }
        
        let modeTitle = useTiGua
            ? LocalizationManager.shared.t("chart_mode_tigua")
            : LocalizationManager.shared.t("chart_mode_xiagua")

        return XuanKongChart(
            period: activePeriod,
            sittingMountain: sittingName,
            facingMountain: facingName,
            patternType: pattern,
            isSanBanGua: Self.checkSanBanGua(cells: cells),
            isQiXingDaJie: Self.checkQiXingDaJie(cells: cells, activePeriod: activePeriod, facingPalaceIdx: sittingFacingIdx),
            isTiGua: useTiGua,
            chartModeTitle: modeTitle,
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
    
    /// 判定是否为父母三般卦（各宫运、山、向星均属 147 / 258 / 369）或连珠三般卦
    private static func checkSanBanGua(cells: [PalaceCell]) -> Bool {
        let fumuSets: [Set<Int>] = [Set([1, 4, 7]), Set([2, 5, 8]), Set([3, 6, 9])]
        let lianzhuSets: [Set<Int>] = [
            Set([1, 2, 3]), Set([2, 3, 4]), Set([3, 4, 5]),
            Set([4, 5, 6]), Set([5, 6, 7]), Set([6, 7, 8]),
            Set([7, 8, 9]), Set([8, 9, 1]), Set([9, 1, 2])
        ]
        let allFumu = cells.allSatisfy { c in
            let s = Set([c.periodStar, c.mountainStar, c.facingStar])
            return fumuSets.contains(s)
        }
        if allFumu { return true }
        return cells.allSatisfy { c in
            let s = Set([c.periodStar, c.mountainStar, c.facingStar])
            return lianzhuSets.contains(s)
        }
    }
    
    /// 判定是否构成七星打劫局（离震乾或坎兑巽三宫向星合成 147 / 258 / 369 且当旺向星到向）
    private static func checkQiXingDaJie(cells: [PalaceCell], activePeriod: Int, facingPalaceIdx: Int) -> Bool {
        guard cells.count == 9, cells[facingPalaceIdx].facingStar == activePeriod else { return false }
        let fumuSets: [Set<Int>] = [Set([1, 4, 7]), Set([2, 5, 8]), Set([3, 6, 9])]
        let zhenQiSet = Set([cells[8].facingStar, cells[2].facingStar, cells[5].facingStar]) // 离9、震3、乾6
        let jiaQiSet = Set([cells[0].facingStar, cells[6].facingStar, cells[3].facingStar])  // 坎1、兑7、巽4
        return fumuSets.contains(zhenQiSet) || fumuSets.contains(jiaQiSet)
    }
}
