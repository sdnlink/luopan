import Foundation

// MARK: - 八宅风水与大游年九星吉凶模型 (BaZhai Engine)

public enum StarLuckType: String, Codable {
    case shengQi = "生气 (贪狼大吉)"
    case yanNian = "延年 (武曲大吉)"
    case tianYi  = "天医 (巨门中吉)"
    case fuWei   = "伏位 (辅弼小吉)"
    case jueMing = "绝命 (破军大凶)"
    case wuGui   = "五鬼 (廉贞大凶)"
    case liuSha  = "六煞 (文曲中凶)"
    case huoHai  = "祸害 (禄存小凶)"
    
    public var isAuspicious: Bool {
        switch self {
        case .shengQi, .yanNian, .tianYi, .fuWei: return true
        default: return false
        }
    }
    
    public var localizedName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch self {
            case .shengQi: return "Sheng Qi (Vitality - Great Luck)"
            case .yanNian: return "Yan Nian (Longevity - Great Luck)"
            case .tianYi:  return "Tian Yi (Heavenly Doctor - Medium Luck)"
            case .fuWei:   return "Fu Wei (Stability - Minor Luck)"
            case .jueMing: return "Jue Ming (Calamity - Major Taboo)"
            case .wuGui:   return "Wu Gui (Five Ghosts - Major Taboo)"
            case .liuSha:  return "Liu Sha (Six Killings - Medium Taboo)"
            case .huoHai:  return "Huo Hai (Mishap - Minor Taboo)"
            }
        case .zhHant:
            switch self {
            case .shengQi: return "生氣 (貪狼大吉)"
            case .yanNian: return "延年 (武曲大吉)"
            case .tianYi:  return "天醫 (巨門中吉)"
            case .fuWei:   return "伏位 (輔弼小吉)"
            case .jueMing: return "絕命 (破軍大凶)"
            case .wuGui:   return "五鬼 (廉貞大凶)"
            case .liuSha:  return "六煞 (文曲中凶)"
            case .huoHai:  return "禍害 (祿存小凶)"
            }
        case .ja:
            switch self {
            case .shengQi: return "生気 (貪狼大吉)"
            case .yanNian: return "延年 (武曲大吉)"
            case .tianYi:  return "天医 (巨門中吉)"
            case .fuWei:   return "伏位 (輔弼小吉)"
            case .jueMing: return "絶命 (破軍大凶)"
            case .wuGui:   return "五鬼 (廉貞大凶)"
            case .liuSha:  return "六煞 (文曲中凶)"
            case .huoHai:  return "禍害 (禄存小凶)"
            }
        case .ko:
            switch self {
            case .shengQi: return "생기 (탐랑대길)"
            case .yanNian: return "연년 (무곡대길)"
            case .tianYi:  return "천의 (거문중길)"
            case .fuWei:   return "복위 (보필소길)"
            case .jueMing: return "절명 (파군대흉)"
            case .wuGui:   return "오귀 (염정대흉)"
            case .liuSha:  return "육살 (문곡중흉)"
            case .huoHai:  return "화해 (녹존소흉)"
            }
        case .vi:
            switch self {
            case .shengQi: return "Sinh Khí (Tham Lang đại cát)"
            case .yanNian: return "Diên Niên (Vũ Khúc đại cát)"
            case .tianYi:  return "Thiên Y (Cự Môn trung cát)"
            case .fuWei:   return "Phục Vị (Phụ Bật tiểu cát)"
            case .jueMing: return "Tuyệt Mệnh (Phá Quân đại hung)"
            case .wuGui:   return "Ngũ Quỷ (Liêm Trinh đại hung)"
            case .liuSha:  return "Lục Sát (Văn Khúc trung hung)"
            case .huoHai:  return "Họa Hại (Lộc Tồn tiểu hung)"
            }
        case .th:
            switch self {
            case .shengQi: return "เซิงชี่ (พลังชีวิต มงคลยิ่ง)"
            case .yanNian: return "เหยียนเหนียน (อายุยืน มงคลยิ่ง)"
            case .tianYi:  return "เทียนอี (หมอสวรรค์ มงคลกลาง)"
            case .fuWei:   return "ฝูเว่ย (ความมั่นคง มงคลน้อย)"
            case .jueMing: return "เจวี๋ยหมิง (อันตราย อัปมงคลยิ่ง)"
            case .wuGui:   return "อู่กุ่ย (ห้าภูต อัปมงคลยิ่ง)"
            case .liuSha:  return "ลิ่วชา (หกสังหาร อัปมงคลกลาง)"
            case .huoHai:  return "ฮั่วไห่ (เภทภัย อัปมงคลน้อย)"
            }
        case .id:
            switch self {
            case .shengQi: return "Sheng Qi (Vitalitas - Sangat Baik)"
            case .yanNian: return "Yan Nian (Umur Panjang - Sangat Baik)"
            case .tianYi:  return "Tian Yi (Tabib Langit - Cukup Baik)"
            case .fuWei:   return "Fu Wei (Kestabilan - Sedikit Baik)"
            case .jueMing: return "Jue Ming (Bencana - Sangat Buruk)"
            case .wuGui:   return "Wu Gui (Lima Hantu - Sangat Buruk)"
            case .liuSha:  return "Liu Sha (Enam Petaka - Cukup Buruk)"
            case .huoHai:  return "Huo Hai (Malapetaka - Sedikit Buruk)"
            }
        case .auto, .zhHans:
            return rawValue
        }
    }
    
    public var actionSuggestion: String {
        localizedSuggestion
    }
    
    public var localizedSuggestion: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch self {
            case .shengQi: return "Ideal for wealth growth, main entrance, master bedroom, and activating vibrant energy."
            case .yanNian: return "Favors longevity, health, family harmony, and interpersonal relations; ideal for master bedroom or living room."
            case .tianYi:  return "Dispels illness and misfortune, attracts benefactors; ideal for beds and sacred altars."
            case .fuWei:   return "Stability, peace, and academic excellence; ideal for study, meditation, and children's room."
            case .jueMing: return "Indicates exhaustion and health decline; strictly avoid for bedrooms/entrance; suitable for bathroom or storage."
            case .wuGui:   return "Prone to quarrels, conflicts, and theft; counteract with heavy furnishings or peaceful water cures."
            case .liuSha:  return "Disturbed peace and emotional turbulence; suitable for storage rooms or remedies."
            case .huoHai:  return "Obstacles and petty disputes; requires stillness rather than dynamic movement."
            }
        case .zhHant:
            switch self {
            case .shengQi: return "最利求財進職、開大門、置主臥、安動氣之源"
            case .yanNian: return "利健康長壽、夫妻和睦、人際關係，宜主臥客堂"
            case .tianYi:  return "消災解厄、身體強健、得貴人相扶，利安床與神位"
            case .fuWei:   return "安穩守成、文昌得利，宜作書房、冥想及兒童房"
            case .jueMing: return "主病痛耗散，嚴禁作臥房大門，宜作衛生間或儲物室"
            case .wuGui:   return "易惹口舌是非、盜賊火災，宜壓以重物或化水局"
            case .liuSha:  return "酒色桃花、心緒不寧，宜化解或設雜物間"
            case .huoHai:  return "官非小人、財帛破耗，宜靜不宜動"
            }
        case .ja:
            switch self {
            case .shengQi: return "財運・昇進、玄関、主寝室、気を取り入れる場所に最適です"
            case .yanNian: return "健康長寿、夫婦円満、人間関係に良く、主寝室や居間に適しています"
            case .tianYi:  return "厄除け、健康増進、貴人の助けを得るのに良く、ベッドや神棚に最適です"
            case .fuWei:   return "安定安寧、学業成就、書斎、瞑想室、子供部屋に適しています"
            case .jueMing: return "病気や気力減退を招き、寝室や玄関には厳禁。浴室や倉庫に適します"
            case .wuGui:   return "口論や盗難トラブルを招きやすく、重厚な家具や水による鎮静が有効です"
            case .liuSha:  return "精神の乱れや感情トラブルを招きやすく、浄化や物置に適します"
            case .huoHai:  return "訴訟や小人の邪魔、財の散財を招くため、静寂を保つのが好ましいです"
            }
        case .ko:
            switch self {
            case .shengQi: return "재물과 승진에 가장 길하며 대문, 안방, 생기 있는 곳에 적합합니다"
            case .yanNian: return "건강 장수와 부부 화목, 대인관계에 이로우며 침실이나 거실에 좋습니다"
            case .tianYi:  return "질병 액운을 물리치고 귀인의 도움을 받으며 침대와 제단에 길합니다"
            case .fuWei:   return "안정과 수성, 학업 문창에 유익하며 서재나 명상방, 아이방에 좋습니다"
            case .jueMing: return "건강 쇠퇴와 손실을 초래하므로 안방/대문은 피하고 화장실이나 창고에 적합합니다"
            case .wuGui:   return "시비 구설과 화재 도난 위험이 있어 무거운 가구로 누르거나 물로 화해해야 합니다"
            case .liuSha:  return "정신 불안과 감정 혼란을 일으키므로 정화하거나 수납공간으로 씁니다"
            case .huoHai:  return "구설 시비와 재물 손실을 부르므로 동하기보다 정적인 상태를 유지해야 합니다"
            }
        case .vi:
            switch self {
            case .shengQi: return "Tốt nhất cho cầu tài lộc thăng tiến, mở cửa chính, phòng ngủ chính, nơi nạp khí."
            case .yanNian: return "Lợi cho sức khỏe trường thọ, gia đạo hòa thuận, quan hệ tốt đẹp, hợp phòng ngủ/khách."
            case .tianYi:  return "Tiêu trừ bệnh tật tai ương, quý nhân phù trợ, rất lợi đặt giường và bàn thờ."
            case .fuWei:   return "Bình an ổn định, vượng văn xương học vấn, hợp phòng đọc sách, thiền định, trẻ em."
            case .jueMing: return "Chủ bệnh tật hao tài, cấm kỵ làm cửa chính hay phòng ngủ, hợp làm nhà kho vệ sinh."
            case .wuGui:   return "Dễ vướng khẩu thiệt thị phi, hỏa hoạn đạo tặc, nên dùng vật nặng trấn áp hoặc thủy giải."
            case .liuSha:  return "Bất an tâm thần, đào hoa xấu phiền não, nên hóa giải hoặc bố trí nhà kho."
            case .huoHai:  return "Thị phi tiểu nhân, hao tài tốn của, nên giữ tĩnh tránh động."
            }
        case .th:
            switch self {
            case .shengQi: return "ดีที่สุดสำหรับโชคลาภการงาน ประตูใหญ่ ห้องนอนใหญ่ และจุดรับพลังงานหมุนเวียน"
            case .yanNian: return "เสริมสุขภาพ อายุยืน ครอบครัวปรองดอง เหมาะกับห้องนอนใหญ่และห้องรับแขก"
            case .tianYi:  return "ปัดเป่าโรคภัย ได้รับความช่วยเหลือจากผู้ใหญ่ เหมาะสำหรับตั้งเตียงและหิ้งบูชา"
            case .fuWei:   return "ความมั่นคงราบรื่น สติปัญญาและการเรียนรู้ เหมาะกับห้องหนังสือ ห้องสมาธิ ห้องเด็ก"
            case .jueMing: return "เหน็ดเหนื่อยเจ็บป่วย ห้ามใช้ทำประตูหรือห้องนอน เหมาะกับห้องน้ำหรือห้องเก็บของ"
            case .wuGui:   return "อาจเกิดข้อพิพาท ทะเลาะเบาะแว้ง ควรแก้ไขด้วยของหนักทับหรือใช้น้ำปรับพลัง"
            case .liuSha:  return "อารมณ์แปรปรวน ไม่สงบ ควรปรับแก้หรือใช้เป็นห้องเก็บของเบ็ดเตล็ด"
            case .huoHai:  return "อุปสรรคข้อขัดแย้ง การเงินรั่วไหล ควรปล่อยให้สงบนิ่งไม่ควรเคลื่อนไหว"
            }
        case .id:
            switch self {
            case .shengQi: return "Sangat baik untuk rezeki, karier, pintu utama, kamar utama, dan sirkulasi energi positif."
            case .yanNian: return "Mendukung kesehatan, umur panjang, keharmonisan keluarga; baik untuk kamar tidur dan ruang tamu."
            case .tianYi:  return "Menghalau penyakit, mendatangkan penolong; sangat baik untuk ranjang tidur dan altar."
            case .fuWei:   return "Kedamaian dan prestasi akademis; cocok untuk ruang kerja, meditasi, dan kamar anak."
            case .jueMing: return "Penyebab kelelahan dan penyakit; hindari untuk kamar tidur/pintu; cocok untuk toilet/gudang."
            case .wuGui:   return "Memicu perselisihan dan kerugian; netralkan dengan perabot berat atau elemen air tenang."
            case .liuSha:  return "Kekacauan emosi dan ketidakharmonisan; cocok untuk gudang atau dinetralkan."
            case .huoHai:  return "Rintangan dan pertengkaran kecil; lebih baik dijaga tetap tenang tanpa aktivitas dinamis."
            }
        case .auto, .zhHans:
            switch self {
            case .shengQi: return "最利求财进职、开大门、置主卧、安动气之源"
            case .yanNian: return "利健康长寿、夫妻和睦、人际关系，宜主卧客堂"
            case .tianYi:  return "消灾解厄、身体强健、得贵人相扶，利安床与神位"
            case .fuWei:   return "安稳守成、文昌得利，宜作书房、冥想及儿童房"
            case .jueMing: return "主病痛耗散，严禁作卧房大门，宜作卫生间或储物室"
            case .wuGui:   return "易惹口舌是非、盗贼火灾，宜压以重物或化水局"
            case .liuSha:  return "酒色桃花、心绪不宁，宜化解或设杂物间"
            case .huoHai:  return "官非小人、财帛破耗，宜静不宜动"
            }
        }
    }
}

public struct BaZhaiPalaceItem: Identifiable {
    public let id: Int
    public let direction: String
    public let guaName: String
    public let star: StarLuckType
    
    public var localizedDirection: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        let enDirs = ["North (Kan)", "Southwest (Kun)", "East (Zhen)", "Southeast (Xun)", "Northwest (Qian)", "West (Dui)", "Northeast (Gen)", "South (Li)"]
        let hantDirs = ["正北 (坎)", "西南 (坤)", "正東 (震)", "東南 (巽)", "西北 (乾)", "正西 (兌)", "東北 (艮)", "正南 (離)"]
        let jaDirs = ["正北 (坎)", "南西 (坤)", "正東 (震)", "南東 (巽)", "北西 (乾)", "正西 (兌)", "北東 (艮)", "正南 (離)"]
        let koDirs = ["정북 (감)", "남서 (곤)", "정동 (진)", "동남 (손)", "북서 (건)", "정서 (태)", "북동 (간)", "정남 (이)"]
        let viDirs = ["Chính Bắc (Khảm)", "Tây Nam (Khôn)", "Chính Đông (Chấn)", "Đông Nam (Tốn)", "Tây Bắc (Càn)", "Chính Tây (Đoài)", "Đông Bắc (Cấn)", "Chính Nam (Ly)"]
        let thDirs = ["ทิศเหนือ (ข่าน)", "ทิศตะวันตกเฉียงใต้ (คุน)", "ทิศตะวันออก (เจิ้น)", "ทิศตะวันออกเฉียงใต้ (ซวิ่น)", "ทิศตะวันตกเฉียงเหนือ (เฉียน)", "ทิศตะวันตก (ตุ้ย)", "ทิศตะวันออกเฉียงเหนือ (เกิ้น)", "ทิศใต้ (หลี)"]
        let idDirs = ["Utara (Kan)", "Barat Daya (Kun)", "Timur (Zhen)", "Tenggara (Xun)", "Barat Laut (Qian)", "Barat (Dui)", "Timur Laut (Gen)", "Selatan (Li)"]

        if id >= 0 && id < 8 {
            switch lang {
            case .en: return enDirs[id]
            case .zhHant: return hantDirs[id]
            case .ja: return jaDirs[id]
            case .ko: return koDirs[id]
            case .vi: return viDirs[id]
            case .th: return thDirs[id]
            case .id: return idDirs[id]
            case .auto, .zhHans: return direction
            }
        }
        return direction
    }
}

public struct BaZhaiAnalysis {
    public let houseGua: String       // 宅卦 (如: 坎宅、乾宅)
    public let houseType: String      // 东四宅 / 西四宅
    public let gateDirection: String  // 大门开向
    public let gateStar: StarLuckType // 大门纳气吉凶
    public let items: [BaZhaiPalaceItem]
    
    public var localizedHouseGua: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            let map = ["坎宅": "Kan House", "坤宅": "Kun House", "震宅": "Zhen House", "巽宅": "Xun House", "乾宅": "Qian House", "兑宅": "Dui House", "艮宅": "Gen House", "离宅": "Li House"]
            return map[houseGua] ?? houseGua
        case .zhHant:
            let map = ["坎宅": "坎宅", "坤宅": "坤宅", "震宅": "震宅", "巽宅": "巽宅", "乾宅": "乾宅", "兑宅": "兌宅", "艮宅": "艮宅", "离宅": "離宅"]
            return map[houseGua] ?? houseGua
        case .ja:
            let map = ["坎宅": "坎宅", "坤宅": "坤宅", "震宅": "震宅", "巽宅": "巽宅", "乾宅": "乾宅", "兑宅": "兌宅", "艮宅": "艮宅", "离宅": "離宅"]
            return map[houseGua] ?? houseGua
        case .ko:
            let map = ["坎宅": "감택", "坤宅": "곤택", "震宅": "진택", "巽宅": "손택", "乾宅": "건택", "兑宅": "태택", "艮宅": "간택", "离宅": "이택"]
            return map[houseGua] ?? houseGua
        case .vi:
            let map = ["坎宅": "Khảm Trạch", "坤宅": "Khôn Trạch", "震宅": "Chấn Trạch", "巽宅": "Tốn Trạch", "乾宅": "Càn Trạch", "兑宅": "Đoài Trạch", "艮宅": "Cấn Trạch", "离宅": "Ly Trạch"]
            return map[houseGua] ?? houseGua
        case .th:
            let map = ["坎宅": "บ้านข่าน", "坤宅": "บ้านคุน", "震宅": "บ้านเจิ้น", "巽宅": "บ้านซวิ่น", "乾宅": "บ้านเฉียน", "兑宅": "บ้านตุ้ย", "艮宅": "บ้านเกิ้น", "离宅": "บ้านหลี"]
            return map[houseGua] ?? houseGua
        case .id:
            let map = ["坎宅": "Rumah Kan", "坤宅": "Rumah Kun", "震宅": "Rumah Zhen", "巽宅": "Rumah Xun", "乾宅": "Rumah Qian", "兑宅": "Rumah Dui", "艮宅": "Rumah Gen", "离宅": "Rumah Li"]
            return map[houseGua] ?? houseGua
        case .auto, .zhHans:
            return houseGua
        }
    }
    
    public var localizedHouseType: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            return houseType == "东四宅" ? "East House" : "West House"
        case .zhHant:
            return houseType == "东四宅" ? "東四宅" : "西四宅"
        case .ja:
            return houseType == "东四宅" ? "東四宅" : "西四宅"
        case .ko:
            return houseType == "东四宅" ? "동사택" : "서사택"
        case .vi:
            return houseType == "东四宅" ? "Đông Tứ Trạch" : "Tây Tứ Trạch"
        case .th:
            return houseType == "东四宅" ? "บ้านทิศตะวันออก" : "บ้านทิศตะวันตก"
        case .id:
            return houseType == "东四宅" ? "Rumah Empat Timur" : "Rumah Empat Barat"
        case .auto, .zhHans:
            return houseType
        }
    }
    
    public var localizedGateDirection: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            let map = ["坎": "North (Kan)", "坤": "Southwest (Kun)", "震": "East (Zhen)", "巽": "Southeast (Xun)", "乾": "Northwest (Qian)", "兑": "West (Dui)", "艮": "Northeast (Gen)", "离": "South (Li)"]
            return map[gateDirection] ?? gateDirection
        case .zhHant:
            let map = ["坎": "正北 (坎)", "坤": "西南 (坤)", "震": "正東 (震)", "巽": "東南 (巽)", "乾": "西北 (乾)", "兑": "正西 (兌)", "艮": "東北 (艮)", "离": "正南 (離)"]
            return map[gateDirection] ?? gateDirection
        case .ja:
            let map = ["坎": "正北 (坎)", "坤": "南西 (坤)", "震": "正東 (震)", "巽": "南東 (巽)", "乾": "北西 (乾)", "兑": "正西 (兌)", "艮": "北東 (艮)", "离": "正南 (離)"]
            return map[gateDirection] ?? gateDirection
        case .ko:
            let map = ["坎": "정북 (감)", "坤": "남서 (곤)", "震": "정동 (진)", "巽": "동남 (손)", "乾": "북서 (건)", "兑": "정서 (태)", "艮": "북동 (간)", "离": "정남 (이)"]
            return map[gateDirection] ?? gateDirection
        case .vi:
            let map = ["坎": "Chính Bắc (Khảm)", "坤": "Tây Nam (Khôn)", "震": "Chính Đông (Chấn)", "巽": "Đông Nam (Tốn)", "乾": "Tây Bắc (Càn)", "兑": "Chính Tây (Đoài)", "艮": "Đông Bắc (Cấn)", "离": "Chính Nam (Ly)"]
            return map[gateDirection] ?? gateDirection
        case .th:
            let map = ["坎": "ทิศเหนือ (ข่าน)", "坤": "ทิศตะวันตกเฉียงใต้ (คุน)", "震": "ทิศตะวันออก (เจิ้น)", "巽": "ทิศตะวันออกเฉียงใต้ (ซวิ่น)", "乾": "ทิศตะวันตกเฉียงเหนือ (เฉียน)", "兑": "ทิศตะวันตก (ตุ้ย)", "艮": "ทิศตะวันออกเฉียงเหนือ (เกิ้น)", "离": "ทิศใต้ (หลี)"]
            return map[gateDirection] ?? gateDirection
        case .id:
            let map = ["坎": "Utara (Kan)", "坤": "Barat Daya (Kun)", "震": "Timur (Zhen)", "巽": "Tenggara (Xun)", "乾": "Barat Laut (Qian)", "兑": "Barat (Dui)", "艮": "Timur Laut (Gen)", "离": "Selatan (Li)"]
            return map[gateDirection] ?? gateDirection
        case .auto, .zhHans:
            return gateDirection
        }
    }
}

public final class BaZhaiEngine {
    public static let shared = BaZhaiEngine()
    
    // 八宅大游年口诀对照表
    // 乾六、坎一、艮八、震三、巽四、离九、坤二、兑七
    private let guaFamilies: [String: String] = [
        "坎": "东四宅", "震": "东四宅", "巽": "东四宅", "离": "东四宅",
        "乾": "西四宅", "坤": "西四宅", "艮": "西四宅", "兑": "西四宅"
    ]
    
    public func analyze(sittingPalace: String, facingPalace: String) -> BaZhaiAnalysis {
        let hType = guaFamilies[sittingPalace] ?? "东四宅"
        let houseName = "\(sittingPalace)宅"
        
        let directions = ["正北 (坎)", "西南 (坤)", "正东 (震)", "东南 (巽)", "西北 (乾)", "正西 (兑)", "东北 (艮)", "正南 (离)"]
        let guas = ["坎", "坤", "震", "巽", "乾", "兑", "艮", "离"]
        
        var list: [BaZhaiPalaceItem] = []
        for i in 0..<8 {
            let targetGua = guas[i]
            let star = calculateStar(from: sittingPalace, to: targetGua)
            list.append(BaZhaiPalaceItem(id: i, direction: directions[i], guaName: targetGua, star: star))
        }
        
        let gateStar = calculateStar(from: sittingPalace, to: facingPalace)
        
        return BaZhaiAnalysis(
            houseGua: houseName,
            houseType: hType,
            gateDirection: facingPalace,
            gateStar: gateStar,
            items: list
        )
    }
    
    private func calculateStar(from base: String, to target: String) -> StarLuckType {
        if base == target { return .fuWei }
        // 简易经典大游年八宅排星算法映射
        let pairs: [String: [String: StarLuckType]] = [
            "坎": ["巽": .shengQi, "离": .yanNian, "震": .tianYi, "坤": .jueMing, "艮": .wuGui, "乾": .liuSha, "兑": .huoHai],
            "离": ["震": .shengQi, "坎": .yanNian, "巽": .tianYi, "乾": .jueMing, "兑": .wuGui, "坤": .liuSha, "艮": .huoHai],
            "震": ["离": .shengQi, "巽": .yanNian, "坎": .tianYi, "兑": .jueMing, "乾": .wuGui, "艮": .liuSha, "坤": .huoHai],
            "巽": ["坎": .shengQi, "震": .yanNian, "离": .tianYi, "艮": .jueMing, "坤": .wuGui, "兑": .liuSha, "乾": .huoHai],
            "乾": ["兑": .shengQi, "坤": .yanNian, "艮": .tianYi, "离": .jueMing, "震": .wuGui, "坎": .liuSha, "巽": .huoHai],
            "坤": ["艮": .shengQi, "乾": .yanNian, "兑": .tianYi, "坎": .jueMing, "巽": .wuGui, "离": .liuSha, "震": .huoHai],
            "艮": ["坤": .shengQi, "兑": .yanNian, "乾": .tianYi, "巽": .jueMing, "坎": .wuGui, "震": .liuSha, "离": .huoHai],
            "兑": ["乾": .shengQi, "艮": .yanNian, "坤": .tianYi, "震": .jueMing, "离": .wuGui, "巽": .liuSha, "坎": .huoHai]
        ]
        return pairs[base]?[target] ?? .fuWei
    }
}
