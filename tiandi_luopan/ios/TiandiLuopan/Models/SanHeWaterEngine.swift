import Foundation

// MARK: - 三合风水与十二长生水法引擎 (SanHe Water Method & PRD 第13章 杨公八煞黄泉消砂)

public enum ChangShengPhase: String, CaseIterable {
    case changSheng = "长生"
    case muYu       = "沐浴"
    case guanDai    = "冠带"
    case linGuan    = "临官"
    case diWang     = "帝旺"
    case shuai      = "衰"
    case bing       = "病"
    case si         = "死"
    case mu         = "墓"
    case jue        = "绝"
    case tai        = "胎"
    case yang       = "养"
    
    public var localizedName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch self {
            case .changSheng: return "Chang Sheng (Birth)"
            case .muYu:       return "Mu Yu (Bath)"
            case .guanDai:    return "Guan Dai (Attire)"
            case .linGuan:    return "Lin Guan (Official)"
            case .diWang:     return "Di Wang (Peak Prosperity)"
            case .shuai:      return "Shuai (Decline)"
            case .bing:       return "Bing (Sickness)"
            case .si:         return "Si (Death)"
            case .mu:         return "Mu (Tomb)"
            case .jue:        return "Jue (Extinction)"
            case .tai:        return "Tai (Conception)"
            case .yang:       return "Yang (Nurture)"
            }
        case .zhHant:
            switch self {
            case .changSheng: return "長生"
            case .muYu:       return "沐浴"
            case .guanDai:    return "冠帶"
            case .linGuan:    return "臨官"
            case .diWang:     return "帝旺"
            case .shuai:      return "衰"
            case .bing:       return "病"
            case .si:         return "死"
            case .mu:         return "墓"
            case .jue:        return "絕"
            case .tai:        return "胎"
            case .yang:       return "養"
            }
        case .ja:
            switch self {
            case .changSheng: return "長生"
            case .muYu:       return "沐浴"
            case .guanDai:    return "冠帯"
            case .linGuan:    return "臨官"
            case .diWang:     return "帝旺"
            case .shuai:      return "衰"
            case .bing:       return "病"
            case .si:         return "死"
            case .mu:         return "墓"
            case .jue:        return "絶"
            case .tai:        return "胎"
            case .yang:       return "養"
            }
        case .ko:
            switch self {
            case .changSheng: return "장생"
            case .muYu:       return "목욕"
            case .guanDai:    return "관대"
            case .linGuan:    return "임관"
            case .diWang:     return "제왕"
            case .shuai:      return "쇠"
            case .bing:       return "병"
            case .si:         return "사"
            case .mu:         return "묘"
            case .jue:        return "절"
            case .tai:        return "태"
            case .yang:       return "양"
            }
        case .vi:
            switch self {
            case .changSheng: return "Trường Sinh"
            case .muYu:       return "Mộc Dục"
            case .guanDai:    return "Quan Đới"
            case .linGuan:    return "Lâm Quan"
            case .diWang:     return "Đế Vượng"
            case .shuai:      return "Suy"
            case .bing:       return "Bệnh"
            case .si:         return "Tử"
            case .mu:         return "Mộ"
            case .jue:        return "Tuyệt"
            case .tai:        return "Thai"
            case .yang:       return "Dưỡng"
            }
        case .th:
            switch self {
            case .changSheng: return "กำเนิด (ฉางเซิง)"
            case .muYu:       return "ชำระล้าง (มู่ยวี่)"
            case .guanDai:    return "สวมหมวก (กวานไต้)"
            case .linGuan:    return "ขุนนาง (หลินกวาน)"
            case .diWang:     return "รุ่งโรจน์สูงสุด (ตี้วั่ง)"
            case .shuai:      return "ถดถอย (ซวย)"
            case .bing:       return "เจ็บป่วย (ปิ้ง)"
            case .si:         return "ดับสูญ (สื่อ)"
            case .mu:         return "สุสาน (มู่)"
            case .jue:        return "สิ้นสุด (เจวี๋ย)"
            case .tai:        return "ปฏิสนธิ (ไท)"
            case .yang:       return "บำรุงเลี้ยง (หย่าง)"
            }
        case .id:
            switch self {
            case .changSheng: return "Kelahiran (Chang Sheng)"
            case .muYu:       return "Pemandian (Mu Yu)"
            case .guanDai:    return "Kedewasaan (Guan Dai)"
            case .linGuan:    return "Pejabat (Lin Guan)"
            case .diWang:     return "Puncak Kejayaan (Di Wang)"
            case .shuai:      return "Kemunduran (Shuai)"
            case .bing:       return "Penyakit (Bing)"
            case .si:         return "Kematian (Si)"
            case .mu:         return "Makam (Mu)"
            case .jue:        return "Kepunahan (Jue)"
            case .tai:        return "Janin (Tai)"
            case .yang:       return "Pengasuhan (Yang)"
            }
        case .auto, .zhHans:
            return rawValue
        }
    }
    
    public var waterRule: String {
        localizedWaterRule
    }
    
    public var localizedWaterRule: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch self {
            case .changSheng, .diWang: return "Inflow brings great wealth; outflow causes losses."
            case .linGuan, .guanDai:   return "Noble benefactor inflow; outflow is unfavorable."
            case .shuai:               return "Jumen water, flexible for inflow/outflow as storage."
            case .mu, .jue:            return "Outflow auspicious; inflow is strictly taboo."
            case .muYu:                return "Peach blossom water; both inflow/outflow cause turbulence."
            case .bing, .si, .tai, .yang: return "Neutral peaceful position; keep calm and gentle."
            }
        case .zhHant:
            switch self {
            case .changSheng, .diWang: return "來水吉，大發富貴；去水凶，損丁破財"
            case .linGuan, .guanDai:   return "貴人來水，催官發甲；出水不利"
            case .shuai:               return "巨門水，來去均宜，借庫消水"
            case .mu, .jue:            return "去水吉，化煞為權；來水大凶，黃泉破局"
            case .muYu:                return "桃花水，來去皆忌，主風流蕩產"
            case .bing, .si, .tai, .yang: return "平和之位，宜緩流靜蓄"
            }
        case .ja:
            switch self {
            case .changSheng, .diWang: return "来水は大吉で富貴を招き、去水は凶で散財損丁"
            case .linGuan, .guanDai:   return "貴人の来水で出世栄達、去水は不利"
            case .shuai:               return "巨門水、出水入水ともに可、借庫消水に適す"
            case .mu, .jue:            return "去水は吉で煞を権に変え、来水は大凶で黄泉破局"
            case .muYu:                return "桃花水、出水入水ともに凶、放蕩や破財を招く"
            case .bing, .si, .tai, .yang: return "穏やかな気位、静水緩流が吉"
            }
        case .ko:
            switch self {
            case .changSheng, .diWang: return "물이 들어오면 대길하여 부귀를 부르고, 나가면 흉하여 손실 초래"
            case .linGuan, .guanDai:   return "귀인의 수로 승진 발달, 물이 나가면 불리"
            case .shuai:               return "거문수로 들어오고 나감이 모두 무방하며 수구로 차용"
            case .mu, .jue:            return "물이 나가면 길하여 살을 권세로 화하고, 들어오면 황천 대흉"
            case .muYu:                return "도화수로 들고남이 모두 꺼려지며 주색패가"
            case .bing, .si, .tai, .yang: return "평화로운 자리로 고요하고 완만한 흐름이 적합"
            }
        case .vi:
            switch self {
            case .changSheng, .diWang: return "Nước lại cát lợi đại phát phú quý; nước đi hung tổn đinh hao tài"
            case .linGuan, .guanDai:   return "Nước quý nhân trợ quan phát đạt; nước chảy đi thì bất lợi"
            case .shuai:               return "Nước Cự Môn, đến hay đi đều được, mượn khố tiêu thủy"
            case .mu, .jue:            return "Nước đi cát, hóa sát thành quyền; nước đến đại hung phạm Hoàng Tuyền"
            case .muYu:                return "Nước Đào Hoa, đến hay đi đều kỵ, chủ phong lưu phá sản"
            case .bing, .si, .tai, .yang: return "Vị trí bình hòa, nên để dòng nước chảy chậm êm ả"
            }
        case .th:
            switch self {
            case .changSheng, .diWang: return "น้ำไหลเข้ามงคลยิ่ง ร่ำรวยมหาศาล; น้ำไหลออกอัปมงคล สูญเสียทรัพย์สิน"
            case .linGuan, .guanDai:   return "น้ำไหลเข้าส่งเสริมยศศักดิ์บารมี; น้ำไหลออกไม่เป็นผลดี"
            case .shuai:               return "น้ำจวี้เหมิน ไหลเข้าออกพอสมควร ใช้ทดน้ำระบายได้"
            case .mu, .jue:            return "น้ำไหลออกมงคล เปลี่ยนร้ายกลายเป็นดี; น้ำไหลเข้าอัปมงคลยิ่ง"
            case .muYu:                return "น้ำดอกท้อ หลีกเลี่ยงทั้งไหลเข้าและออก ระวังเรื่องชู้สาวเสียทรัพย์"
            case .bing, .si, .tai, .yang: return "ตำแหน่งสงบสมดุล ควรให้น้ำไหลเอื่อยช้าๆ"
            }
        case .id:
            switch self {
            case .changSheng, .diWang: return "Air masuk sangat baik mendatangkan rezeki; air keluar membawa kerugian"
            case .linGuan, .guanDai:   return "Air masuk membawa promosi bangsawan; air keluar tidak menguntungkan"
            case .shuai:               return "Air Jumen, baik masuk maupun keluar cukup seimbang sebagai penampung"
            case .mu, .jue:            return "Air keluar membawa berkah; air masuk sangat tabu menimbulkan petaka"
            case .muYu:                return "Air asmara/bunga persik; masuk maupun keluar harus dihindari"
            case .bing, .si, .tai, .yang: return "Posisi netral dan tenang; pertahankan aliran air yang lambat dan damai"
            }
        case .auto, .zhHans:
            switch self {
            case .changSheng, .diWang: return "来水吉，大发富贵；去水凶，损丁破财"
            case .linGuan, .guanDai:   return "贵人来水，催官发甲；出水不利"
            case .shuai:               return "巨门水，来去均宜，借库消水"
            case .mu, .jue:            return "去水吉，化煞为权；来水大凶，黄泉破局"
            case .muYu:                return "桃花水，来去皆忌，主风流荡产"
            case .bing, .si, .tai, .yang: return "平和之位，宜缓流静蓄"
            }
        }
    }
}

public struct SanHeWaterItem: Identifiable {
    public let id: Int
    public let mountainName: String
    public let phase: ChangShengPhase
    public let isHuangQuanSha: Bool
    
    public var palace: String { localizedMountainName }
    public var stage: String { phase.localizedName }
    public var lore: String { phase.localizedWaterRule }
    public var isAuspicious: Bool {
        phase == .changSheng || phase == .diWang || phase == .linGuan || phase == .guanDai
    }
    
    public var localizedMountainName: String {
        let mData = Mountain24Data.shared.mountains
        if id >= 0 && id < mData.count {
            return mData[id].localizedName
        }
        return mountainName
    }
}

// MARK: - 八路黄泉水法判定模型
public struct HuangQuanWaterResult {
    public let facingMountain: String
    public let waterDesc: String
    public let isJiuPin: Bool
    public let isDanger: Bool
    public let badgeText: String
    public let quote: String = "庚丁坤上是黄泉，乙丙须防巽水先。甲癸向中休见艮，辛壬水路怕当乾。"

    public var localizedQuote: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en: return "Geng and Ding fear Huangquan in Kun; Yi and Bing guard against Xun water. Jia and Gui avoid Gen; Xin and Ren fear Qian water."
        case .zhHant, .ja: return "庚丁坤上是黃泉，乙丙須防巽水先。甲癸向中休見艮，辛壬水路怕當乾。"
        case .ko: return "경정곤상은 황천이요, 을병은 먼저 손수를 방비하라. 갑계향 중에는 간을 보지 말고, 신임 수로는 건을 두려워한다."
        case .vi: return "Canh Đinh Khôn thượng thị Hoàng Tuyền, Ất Bính tu phòng Tốn thủy tiên. Giáp Quý hướng trung hưu kiến Cấn, Tân Nhâm thủy lộ phạ đương Càn."
        case .th: return "เกิ้งติงทิศคุนคือหวงเฉวียน อี้ปิ่งระวังน้ำทิศซวิ่น เจี่ยกุ่ยอย่าพบทิศเกิ้น ซินเหรินระวังน้ำทิศเฉียน"
        case .id: return "Geng dan Ding hindari Huangquan di Kun; Yi dan Bing waspadai air Xun. Jia dan Gui hindari Gen; Xin dan Ren waspadai jalan air Qian."
        case .auto, .zhHans: return quote
        }
    }
}

// MARK: - 坐山八煞曜位模型
public struct BaShaResult {
    public let sittingMountain: String
    public let sittingPalace: String
    public let shaZhi: String
    public let shaDir: String
    public let lore: String
    public let remedy: String
    public let song: String = "坎龙坤兔震山猴，巽鸡乾马兑蛇头，艮虎离猪为煞曜。"
    public let xiaoShaRule: String = "生我为生砂（催贵），同我为旺砂（旺丁财），克我为煞砂（大凶血光），我克为奴砂（得财帛），我生为泄砂（虚耗脱白）。"

    public var localizedSong: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en: return "Kan Dragon, Kun Rabbit, Zhen Monkey; Xun Rooster, Qian Horse, Dui Snake; Gen Tiger and Li Pig mark the Sha stars."
        case .zhHant, .ja: return "坎龍坤兔震山猴，巽雞乾馬兌蛇頭，艮虎離豬為煞曜。"
        case .ko: return "감룡 곤토 진산후, 손계 건마 태사두, 간호 이저는 살요가 된다."
        case .vi: return "Khảm Long Khôn Thố Chấn sơn hầu, Tốn Kê Càn Mã Đoài xà đầu, Cấn Hổ Ly Trư vi sát diệu."
        case .th: return "ข่านมังกร คุนกระต่าย เจิ้นลิง ซวิ่นไก่ เฉียนม้า ตุ้ยงู เกิ้นเสือ หลีหมู เป็นดาวพิฆาต"
        case .id: return "Naga Kan, Kelinci Kun, Monyet Zhen; Ayam Xun, Kuda Qian, Ular Dui; Harimau Gen dan Babi Li adalah Bintang Sha."
        case .auto, .zhHans: return song
        }
    }

    public var localizedXiaoShaRule: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en: return "Generating me is Sheng Sha (noble aid); same as me is Wang Sha (people and wealth); overcoming me is Sha (major harm); I overcome is Slave Sha (wealth); I generate is Draining Sha (waste)."
        case .zhHant: return "生我為生砂（催貴），同我為旺砂（旺丁財），克我為煞砂（大凶血光），我克為奴砂（得財帛），我生為洩砂（虛耗脫白）。"
        case .ja: return "生我は生砂（貴人を促す）、同我は旺砂（人財を盛んにす）、克我は煞砂（大凶血光）、我克は奴砂（財帛を得る）、我生は洩砂（散財衰耗）。"
        case .ko: return "생하는 것은 생사(귀인 조력), 같은 것은 왕사(인재 재물 번창), 극하는 것은 살사(대흉 혈광), 내가 극하는 것은 노사(재물 획득), 내가 생하는 것은 설사(소모 쇠퇴)."
        case .vi: return "Sinh ngã vi Sinh Sa (trợ quý), đồng ngã vi Vượng Sa (vượng nhân đinh tài lộc), khắc ngã vi Sát Sa (đại hung huyết quang), ngã khắc vi Nô Sa (đắc tài bạch), ngã sinh vi Tiết Sa (tiêu hao hư thoát)."
        case .th: return "ธาตุเกื้อหนุนคือเซิงซา (เสริมบารมี); ธาตุเดียวกันคือวั่งซา (บริบูรณ์ทรัพย์และคน); ธาตุข่มคือชาซา (เคราะห์ใหญ่เลือดตก); เราข่มคือหนูซา (ได้ลาภทรัพย์); เราก่อกำเนิดคือเซี่ยซา (รั่วไหลสูญเปล่า)"
        case .id: return "Menghidupkan adalah Sheng Sha (penolong bangsawan); seunsur adalah Wang Sha (keluarga & kekayaan); menaklukkan saya adalah Sifat Sha (bahaya besar); saya taklukkan adalah Budak Sha (kekayaan); saya hidupkan adalah Boros Sha (pemborosan)."
        case .auto, .zhHans: return xiaoShaRule
        }
    }
    
    public var localizedShaDir: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            let zhiEn = ["辰": "Chen", "卯": "Mao", "申": "Shen", "酉": "You", "午": "Wu", "巳": "Si", "寅": "Yin", "亥": "Hai"]
            let dirEn = ["东南": "Southeast", "正东": "East", "西南": "Southwest", "正西": "West", "正南": "South", "东北": "Northeast", "西北": "Northwest"]
            let z = zhiEn[shaZhi] ?? shaZhi
            let d = dirEn[shaDir] ?? shaDir
            return "\(d) (\(z))"
        case .zhHant:
            let dirHant = ["东南": "東南", "正东": "正東", "西南": "西南", "正西": "正西", "正南": "正南", "东北": "東北", "西北": "西北"]
            let d = dirHant[shaDir] ?? shaDir
            return "\(d)\(shaZhi)"
        case .ja:
            let dirJa = ["东南": "南東", "正东": "正東", "西南": "南西", "正西": "正西", "正南": "正南", "东北": "北東", "西北": "北西"]
            let d = dirJa[shaDir] ?? shaDir
            return "\(d) (\(shaZhi)方)"
        case .ko:
            let dirKo = ["东南": "동남", "正东": "정동", "西南": "남서", "正西": "정서", "正南": "정남", "东北": "북동", "西北": "북서"]
            let zhiKo = ["辰": "진", "卯": "묘", "申": "신", "酉": "유", "午": "오", "巳": "사", "寅": "인", "亥": "해"]
            let d = dirKo[shaDir] ?? shaDir
            let z = zhiKo[shaZhi] ?? shaZhi
            return "\(d) (\(z)방)"
        case .vi:
            let dirVi = ["东南": "Đông Nam", "正东": "Chính Đông", "西南": "Tây Nam", "正西": "Chính Tây", "正南": "Chính Nam", "东北": "Đông Bắc", "西北": "Tây Bắc"]
            let zhiVi = ["辰": "Thìn", "卯": "Mão", "申": "Thân", "酉": "Dậu", "午": "Ngọ", "巳": "Tị", "寅": "Dần", "亥": "Hợi"]
            let d = dirVi[shaDir] ?? shaDir
            let z = zhiVi[shaZhi] ?? shaZhi
            return "\(d) (phương \(z))"
        case .th:
            let dirTh = ["东南": "ทิศตะวันออกเฉียงใต้", "正东": "ทิศตะวันออก", "西南": "ทิศตะวันตกเฉียงใต้", "正西": "ทิศตะวันตก", "正南": "ทิศใต้", "东北": "ทิศตะวันออกเฉียงเหนือ", "西北": "ทิศตะวันตกเฉียงเหนือ"]
            let zhiTh = ["辰": "เฉิน", "卯": "เหม่า", "申": "เซิน", "酉": "โหย่ว", "午": "อู่", "巳": "ซื่อ", "寅": "อิ๋น", "亥": "ไฮ่"]
            let d = dirTh[shaDir] ?? shaDir
            let z = zhiTh[shaZhi] ?? shaZhi
            return "\(d) (ทิศ\(z))"
        case .id:
            let dirId = ["东南": "Tenggara", "正东": "Timur", "西南": "Barat Daya", "正西": "Barat", "正南": "Selatan", "东北": "Timur Laut", "西北": "Barat Laut"]
            let d = dirId[shaDir] ?? shaDir
            return "\(d) (\(shaZhi))"
        case .auto, .zhHans:
            return "\(shaDir)\(shaZhi)"
        }
    }
}

public final class SanHeWaterEngine {
    public static let shared = SanHeWaterEngine()
    
    // 八煞克煞曜位映射表：“坎龙坤兔震山猴，巽鸡乾马兑蛇头，艮虎离猪为煞曜”
    private let baShaMap: [String: (zhi: String, dir: String, lore: String)] = [
        "坎": ("辰", "东南", "坎卦三山(壬/子/癸)煞在辰位。辰方最忌见高压电塔、尖角怪石或破败死水，犯之主肾疾、下元损丁。"),
        "坤": ("卯", "正东", "坤卦三山(未/坤/申)煞在卯位。忌正东见冲射，主脾胃败坏、老母伤损。"),
        "震": ("申", "西南", "震卦三山(甲/卯/乙)煞在申位。忌西南申方突兀尖峰，主长房伤残、足疾官非。"),
        "巽": ("酉", "正西", "巽卦三山(辰/巽/巳)煞在酉位。忌正西酉金直冲，主妇女产厄、风声是非。"),
        "乾": ("午", "正南", "乾卦三山(戌/乾/亥)煞在午位。忌正南离火烈焰反克天门，主心脑血光、损老翁。"),
        "兑": ("巳", "东南", "兑卦三山(庚/酉/辛)煞在巳位。忌东南巳火伤金，主少女不利、肺疾吐血。"),
        "艮": ("寅", "东北", "艮卦三山(丑/艮/寅)煞在寅位。忌东北见破山绝涧，损幼子少男。"),
        "离": ("亥", "西北", "离卦三山(丙/午/丁)煞在亥位。忌西北亥水冲射，主眼疾暗昧、中房受制。")
    ]
    
    // 1. 八路黄泉水法判定
    public func resolveHuangQuanWater(facing: Mountain24Item) -> HuangQuanWaterResult {
        let name = facing.name
        let pName = facing.localizedName
        let lang = LocalizationManager.shared.effectiveLanguage
        
        var desc = ""
        var isJiuPin = false
        var isDanger = false
        var badge = ""
        
        switch lang {
        case .en:
            badge = "Pure Needle Auspicious"
            if name == "庚" || name == "丁" {
                desc = "Facing Mountain: [\(pName)]. Major Taboo: Water outlet towards Kun is lethal Huangquan sha (harms descendants and fortune). Inflow from Kun brings noble blessings."
                isDanger = true
                badge = "Avoid Kun Water Outlet"
            } else if name == "坤" {
                desc = "Facing Mountain: [\(pName)]. Yang Gong Rule: Inflow from Geng or Ding is Wealth-Rescue Water (Auspicious, promotes prosperity and noble honors). Direct drainage here is taboo."
                isJiuPin = true
                badge = "Wealth Rescue Facing"
            } else if name == "乙" || name == "丙" {
                desc = "Facing Mountain: [\(pName)]. Major Taboo: Water outlet towards Xun is Eight-Sha Huangquan (misfortunes, disputes, fire hazard). Inflow from Xun is favorable."
                isDanger = true
                badge = "Avoid Xun Water Outlet"
            } else if name == "巽" {
                desc = "Facing Mountain: [\(pName)]. Yang Gong Rule: Inflow from Yi or Bing is Wealth-Rescue Water (Auspicious, boosts academic recognition and lasting prosperity)."
                isJiuPin = true
                badge = "Wealth Rescue Facing"
            } else if name == "甲" || name == "癸" {
                desc = "Facing Mountain: [\(pName)]. Major Taboo: Water outlet towards Gen is Huangquan Killing Water (causes financial setbacks and legal troubles)."
                isDanger = true
                badge = "Avoid Gen Water Outlet"
            } else if name == "艮" {
                desc = "Facing Mountain: [\(pName)]. Yang Gong Rule: Inflow from Jia or Gui is Promotion Water (Auspicious, boosts vitality and eminent accomplishments)."
                isJiuPin = true
                badge = "Wealth Rescue Facing"
            } else if name == "辛" || name == "壬" {
                desc = "Facing Mountain: [\(pName)]. Major Taboo: Water outlet towards Qian is Po Jun Huangquan (causes unexpected losses and blood accidents)."
                isDanger = true
                badge = "Avoid Qian Water Outlet"
            } else if name == "乾" {
                desc = "Facing Mountain: [\(pName)]. Yang Gong Rule: Inflow from Xin or Ren is Wealth-Rescue Water (Auspicious, brings abundance and honor to elders)."
                isJiuPin = true
                badge = "Wealth Rescue Facing"
            } else {
                desc = "Facing Mountain: [\(pName)]. Not in the Eight-Road Huangquan taboo; align with Twelve Changsheng water method for optimal fortune."
                badge = "Pure Auspicious Water"
            }
        case .zhHant:
            badge = "正針合度純清"
            if name == "庚" || name == "丁" {
                desc = "向首為【\(pName)】。水法大忌：坤方出水為殺人大黃泉（損人丁、傷小口、敗退產業）；若坤方見來水反為催官水。"
                isDanger = true
                badge = "大忌坤水破局"
            } else if name == "坤" {
                desc = "向首為【\(pName)】。楊公水法：見庚方或丁方來水為【救貧黃泉水】（大吉，人興財旺、催官進祿）；最忌此兩方水直流破局。"
                isJiuPin = true
                badge = "救貧大吉向首"
            } else if name == "乙" || name == "丙" {
                desc = "向首為【\(pName)】。水法大忌：巽方出水為八煞黃泉（大凶，官司口舌、火災損丁）；巽方來水則吉。"
                isDanger = true
                badge = "大忌巽方破局"
            } else if name == "巽" {
                desc = "向首為【\(pName)】。楊公水法：見乙方或丙方來水為【救貧黃泉水】（大吉，利科名文彩、發福綿長）。"
                isJiuPin = true
                badge = "救貧大吉向首"
            } else if name == "甲" || name == "癸" {
                desc = "向首為【\(pName)】。水法大忌：艮方出水為黃泉殺水（主殘疾退財、官非口舌）。"
                isDanger = true
                badge = "大忌艮水出煞"
            } else if name == "艮" {
                desc = "向首為【\(pName)】。楊公水法：見甲方或癸方來水為【救貧催官水】（大吉，少男發達、巨富顯達）。"
                isJiuPin = true
                badge = "救貧大吉向首"
            } else if name == "辛" || name == "壬" {
                desc = "向首為【\(pName)】。水法大忌：乾方出水為破軍黃泉（犯之主吐血、橫禍、少亡破敗）。"
                isDanger = true
                badge = "大忌乾方破局"
            } else if name == "乾" {
                desc = "向首為【\(pName)】。楊公水法：見辛方或壬方來水為【救貧黃泉水】（大吉，長房顯耀、金玉滿堂）。"
                isJiuPin = true
                badge = "救貧大吉向首"
            } else {
                desc = "向首為【\(pName)】。不屬八路黃泉正煞位，水法依楊公三合十二長生（養生冠臨旺，生來會旺、拔水入庫）消納即吉。"
                badge = "正針純清納水"
            }
        case .ja:
            badge = "正針合度純清"
            if name == "庚" || name == "丁" {
                desc = "向首：【\(pName)】。水法禁忌：坤方の出水は殺人黄泉の大煞（人命損失・破産）。坤方からの来水は逆に催官の吉水。"
                isDanger = true
                badge = "坤方出水は厳禁"
            } else if name == "坤" {
                desc = "向首：【\(pName)】。楊公水法：庚方または丁方の来水は【救貧黄泉水】（大吉、家運隆盛・昇進栄達）。"
                isJiuPin = true
                badge = "救貧大吉の向首"
            } else if name == "乙" || name == "丙" {
                desc = "向首：【\(pName)】。水法禁忌：巽方の出水は八煞黄泉（大凶、訴訟争議・火災散財）。巽方からの来水は吉。"
                isDanger = true
                badge = "巽方出水は厳禁"
            } else if name == "巽" {
                desc = "向首：【\(pName)】。楊公水法：乙方または丙方の来水は【救貧黄泉水】（大吉、学問文彩・繁栄長久）。"
                isJiuPin = true
                badge = "救貧大吉の向首"
            } else if name == "甲" || name == "癸" {
                desc = "向首：【\(pName)】。水法禁忌：艮方の出水は黄泉殺水（障がいや財産損失・訴訟口舌）。"
                isDanger = true
                badge = "艮方出水は厳禁"
            } else if name == "艮" {
                desc = "向首：【\(pName)】。楊公水法：甲方または癸方の来水は【救貧催官水】（大吉、子孫発展・巨富顕達）。"
                isJiuPin = true
                badge = "救貧大吉の向首"
            } else if name == "辛" || name == "壬" {
                desc = "向首：【\(pName)】。水法禁忌：乾方の出水は破軍黄泉（大凶、突発事故・若年損失）。"
                isDanger = true
                badge = "乾方出水は厳禁"
            } else if name == "乾" {
                desc = "向首：【\(pName)】。楊公水法：辛方または壬方の来水は【救貧黄泉水】（大吉、金玉満堂・家門繁栄）。"
                isJiuPin = true
                badge = "救貧大吉の向首"
            } else {
                desc = "向首：【\(pName)】。八路黄泉の煞位にはあたらず、十二長生水法（生来会旺・借庫消水）に従えば吉。"
                badge = "正針純清納水"
            }
        case .ko:
            badge = "정침합도순청"
            if name == "庚" || name == "丁" {
                desc = "향수: 【\(pName)】. 수법 대기: 곤방 출수는 살인 황천 대살(손재패가, 인명 손실). 곤방 내수는 관운을 촉진."
                isDanger = true
                badge = "곤방 출수 엄금"
            } else if name == "坤" {
                desc = "향수: 【\(pName)】. 양공수법: 경방이나 정방 내수는 【구빈황천수】(대길, 인흥재왕, 벼슬 승진)."
                isJiuPin = true
                badge = "구빈 대길 향수"
            } else if name == "乙" || name == "丙" {
                desc = "향수: 【\(pName)】. 수법 대기: 손방 출수는 팔살 황천(대흉, 관재 구설, 화재 질병)."
                isDanger = true
                badge = "손방 출수 엄금"
            } else if name == "巽" {
                desc = "향수: 【\(pName)】. 양공수법: 을방이나 병방 내수는 【구빈황천수】(대길, 학문 발전, 자손 번창)."
                isJiuPin = true
                badge = "구빈 대길 향수"
            } else if name == "甲" || name == "癸" {
                desc = "향수: 【\(pName)】. 수법 대기: 간방 출수는 황천 살수(재산 손실 및 질병)."
                isDanger = true
                badge = "간방 출수 엄금"
            } else if name == "艮" {
                desc = "향수: 【\(pName)】. 양공수법: 갑방이나 계방 내수는 【구빈최관수】(대길, 가문 현달, 거부 번영)."
                isJiuPin = true
                badge = "구빈 대길 향수"
            } else if name == "辛" || name == "壬" {
                desc = "향수: 【\(pName)】. 수법 대기: 건방 출수는 파군 황천(대흉, 혈광사 및 파산)."
                isDanger = true
                badge = "건방 출수 엄금"
            } else if name == "乾" {
                desc = "향수: 【\(pName)】. 양공수법: 신방이나 임방 내수는 【구빈황천수】(대길, 부귀쌍전, 자손 창성)."
                isJiuPin = true
                badge = "구빈 대길 향수"
            } else {
                desc = "향수: 【\(pName)】. 팔로 황천의 살위가 아니며 십이장생 수법으로 조화롭게 거두면 길합니다."
                badge = "정침 순청 납수"
            }
        case .vi:
            badge = "Chính Châm Hợp Độ Thuần Thanh"
            if name == "庚" || name == "丁" {
                desc = "Hướng thủ: 【\(pName)】. Đại kỵ thủy pháp: Khôn phương xuất thủy phạm Sát Nhân Hoàng Tuyền (hại người hao tài). Khôn phương lai thủy thì ngược lại là thôi quan cát thủy."
                isDanger = true
                badge = "Đại kỵ xuất thủy hướng Khôn"
            } else if name == "坤" {
                desc = "Hướng thủ: 【\(pName)】. Dương Công thủy pháp: Thấy Canh hoặc Đinh phương lai thủy là 【Cứu Bần Hoàng Tuyền Thủy】 (đại cát, nhân tài hưng vượng, thăng quan tiến lộc)."
                isJiuPin = true
                badge = "Cứu Bần Đại Cát Hướng Thủ"
            } else if name == "乙" || name == "丙" {
                desc = "Hướng thủ: 【\(pName)】. Đại kỵ thủy pháp: Tốn phương xuất thủy là Bát Sát Hoàng Tuyền (đại hung, quan tụng khẩu thiệt, tai họa hỏa hoạn)."
                isDanger = true
                badge = "Đại kỵ xuất thủy hướng Tốn"
            } else if name == "巽" {
                desc = "Hướng thủ: 【\(pName)】. Dương Công thủy pháp: Thấy Ất hoặc Bính phương lai thủy là 【Cứu Bần Hoàng Tuyền Thủy】 (đại cát, lợi khoa danh văn chương, trường thọ phát phúc)."
                isJiuPin = true
                badge = "Cứu Bần Đại Cát Hướng Thủ"
            } else if name == "甲" || name == "癸" {
                desc = "Hướng thủ: 【\(pName)】. Đại kỵ thủy pháp: Cấn phương xuất thủy phạm Hoàng Tuyền Sát Thủy (chủ bại tài tật bệnh, thị phi)."
                isDanger = true
                badge = "Đại kỵ xuất thủy hướng Cấn"
            } else if name == "艮" {
                desc = "Hướng thủ: 【\(pName)】. Dương Công thủy pháp: Thấy Giáp hoặc Quý phương lai thủy là 【Cứu Bần Thôi Quan Thủy】 (đại cát, con cháu phát đạt, cự phú hiển vinh)."
                isJiuPin = true
                badge = "Cứu Bần Đại Cát Hướng Thủ"
            } else if name == "辛" || name == "壬" {
                desc = "Hướng thủ: 【\(pName)】. Đại kỵ thủy pháp: Càn phương xuất thủy phạm Phá Quân Hoàng Tuyền (chủ huyết quang, phá sản, đoản thọ)."
                isDanger = true
                badge = "Đại kỵ xuất thủy hướng Càn"
            } else if name == "乾" {
                desc = "Hướng thủ: 【\(pName)】. Dương Công thủy pháp: Thấy Tân hoặc Nhâm phương lai thủy là 【Cứu Bần Hoàng Tuyền Thủy】 (đại cát, gia tộc vinh hiển, vàng ngọc đầy nhà)."
                isJiuPin = true
                badge = "Cứu Bần Đại Cát Hướng Thủ"
            } else {
                desc = "Hướng thủ: 【\(pName)】. Không thuộc phương sát Bát Lộ Hoàng Tuyền, tiêu nạp theo Thập Nhị Trường Sinh là đại cát."
                badge = "Chính Châm Thuần Thanh Nạp Thủy"
            }
        case .th:
            badge = "องศาบริสุทธิ์ถูกหลัก"
            if name == "庚" || name == "丁" {
                desc = "ทิศหน้า: 【\(pName)】 ข้อห้ามใหญ่: น้ำไหลออกทางทิศคุนคือหวงเฉวียนสังหาร (สูญเสียลูกหลาน ทรัพย์สินเสียหาย); หากน้ำไหลเข้าทางทิศคุนกลับเป็นมงคลเกื้อหนุน"
                isDanger = true
                badge = "ห้ามระบายน้ำออกทิศคุน"
            } else if name == "坤" {
                desc = "ทิศหน้า: 【\(pName)】 ตำราหยางกง: น้ำไหลเข้าจากทิศเกิ้งหรือติงคือ【น้ำหวงเฉวียนปลดหนี้】(มงคลยิ่ง ทรัพย์สินรุ่งเรือง เลื่อนยศตำแหน่ง)"
                isJiuPin = true
                badge = "ทิศหน้าปลดหนี้มงคลยิ่ง"
            } else if name == "乙" || name == "丙" {
                desc = "ทิศหน้า: 【\(pName)】 ข้อห้ามใหญ่: น้ำไหลออกทางทิศซวิ่นคือแปดพิฆาตหวงเฉวียน (อัปมงคลยิ่ง คดีความ ฟืนไฟ)"
                isDanger = true
                badge = "ห้ามระบายน้ำออกทิศซวิ่น"
            } else if name == "巽" {
                desc = "ทิศหน้า: 【\(pName)】 ตำราหยางกง: น้ำไหลเข้าจากทิศอี้หรือปิ่งคือ【น้ำหวงเฉวียนปลดหนี้】(มงคลยิ่ง ส่งเสริมการศึกษา ความเจริญยาวนาน)"
                isJiuPin = true
                badge = "ทิศหน้าปลดหนี้มงคลยิ่ง"
            } else if name == "甲" || name == "癸" {
                desc = "ทิศหน้า: 【\(pName)】 ข้อห้ามใหญ่: น้ำไหลออกทางทิศเกิ้นคือน้ำพิฆาตหวงเฉวียน (อุปสรรคการเงิน ข้อพิพาท)"
                isDanger = true
                badge = "ห้ามระบายน้ำออกทิศเกิ้น"
            } else if name == "艮" {
                desc = "ทิศหน้า: 【\(pName)】 ตำราหยางกง: น้ำไหลเข้าจากทิศเจี่ยหรือกุ่ยคือ【น้ำปลดหนี้หนุนยศ】(มงคลยิ่ง เจริญก้าวหน้า ร่ำรวยมหาศาล)"
                isJiuPin = true
                badge = "ทิศหน้าปลดหนี้มงคลยิ่ง"
            } else if name == "辛" || name == "壬" {
                desc = "ทิศหน้า: 【\(pName)】 ข้อห้ามใหญ่: น้ำไหลออกทางทิศเฉียนคือโพ่จวินหวงเฉวียน (เคราะห์เลือดตกยางออก สูญเสียฉับพลัน)"
                isDanger = true
                badge = "ห้ามระบายน้ำออกทิศเฉียน"
            } else if name == "乾" {
                desc = "ทิศหน้า: 【\(pName)】 ตำราหยางกง: น้ำไหลเข้าจากทิศซินหรือเหรินคือ【น้ำหวงเฉวียนปลดหนี้】(มงคลยิ่ง ทรัพย์สินเนืองนอง ครอบครัวเจริญรุ่งเรือง)"
                isJiuPin = true
                badge = "ทิศหน้าปลดหนี้มงคลยิ่ง"
            } else {
                desc = "ทิศหน้า: 【\(pName)】 ไม่ติดตำแหน่งเคราะห์แปดสายหวงเฉวียน จัดระบายน้ำตามหลักสิบสองฉางเซิงจะเกิดมงคล"
                badge = "รับน้ำบริสุทธิ์ถูกต้อง"
            }
        case .id:
            badge = "Arah Murni Membawa Berkah"
            if name == "庚" || name == "丁" {
                desc = "Arah Hadap: [\(pName)]. Larangan Utama: Saluran air keluar ke arah Kun adalah Huangquan mematikan (merugikan keturunan dan harta). Aliran air masuk dari Kun justru membawa berkah promosi."
                isDanger = true
                badge = "Hindari Saluran Keluar Kun"
            } else if name == "坤" {
                desc = "Arah Hadap: [\(pName)]. Aturan Yang Gong: Air masuk dari Geng atau Ding adalah [Air Huangquan Penolong Kemiskinan] (sangat berkah, mendatangkan kemakmuran)."
                isJiuPin = true
                badge = "Hadap Berkah Kemakmuran"
            } else if name == "乙" || name == "丙" {
                desc = "Arah Hadap: [\(pName)]. Larangan Utama: Saluran air keluar ke arah Xun adalah Delapan Sha Huangquan (musibah, perselisihan, kebakaran)."
                isDanger = true
                badge = "Hindari Saluran Keluar Xun"
            } else if name == "巽" {
                desc = "Arah Hadap: [\(pName)]. Aturan Yang Gong: Air masuk dari Yi atau Bing adalah [Air Huangquan Penolong Kemiskinan] (sangat berkah, mendukung pendidikan & kemakmuran)."
                isJiuPin = true
                badge = "Hadap Berkah Kemakmuran"
            } else if name == "甲" || name == "癸" {
                desc = "Arah Hadap: [\(pName)]. Larangan Utama: Saluran air keluar ke arah Gen adalah Air Pembunuh Huangquan (membawa kerugian finansial & masalah hukum)."
                isDanger = true
                badge = "Hindari Saluran Keluar Gen"
            } else if name == "艮" {
                desc = "Arah Hadap: [\(pName)]. Aturan Yang Gong: Air masuk dari Jia atau Gui adalah Air Promosi (sangat berkah, sukses besar dan kekayaan melimpah)."
                isJiuPin = true
                badge = "Hadap Berkah Kemakmuran"
            } else if name == "辛" || name == "壬" {
                desc = "Arah Hadap: [\(pName)]. Larangan Utama: Saluran air keluar ke arah Qian adalah Po Jun Huangquan (kerugian mendadak & bahaya fisik)."
                isDanger = true
                badge = "Hindari Saluran Keluar Qian"
            } else if name == "乾" {
                desc = "Arah Hadap: [\(pName)]. Aturan Yang Gong: Air masuk dari Xin atau Ren adalah [Air Huangquan Penolong Kemiskinan] (sangat berkah, kehormatan dan kelimpahan rezeki)."
                isJiuPin = true
                badge = "Hadap Berkah Kemakmuran"
            } else {
                desc = "Arah Hadap: [\(pName)]. Bebas dari pantangan Delapan Jalur Huangquan; sesuaikan dengan Dua Belas Siklus Changsheng untuk keberuntungan optimal."
                badge = "Aliran Air Murni Harmonis"
            }
        case .auto, .zhHans:
            badge = "正针合度纯清"
            if name == "庚" || name == "丁" {
                desc = "向首为【\(name)山向】。水法大忌：坤方出水为杀人大黄泉（损人丁、伤小口、败退产业）；若坤方见来水反为催官水。"
                isDanger = true
                badge = "大忌坤水破局"
            } else if name == "坤" {
                desc = "向首为【坤向】。杨公水法：见庚方或丁方来水为【救贫黄泉水】（大吉，人兴财旺、催官进禄）；最忌此两方水直流破局。"
                isJiuPin = true
                badge = "救贫大吉向首"
            } else if name == "乙" || name == "丙" {
                desc = "向首为【\(name)山向】。水法大忌：巽方出水为八煞黄泉（大凶，官司口舌、火灾损丁）；巽方来水则吉。"
                isDanger = true
                badge = "大忌巽方破局"
            } else if name == "巽" {
                desc = "向首为【巽向】。杨公水法：见乙方或丙方来水为【救贫黄泉水】（大吉，利科名文彩、发福绵长）。"
                isJiuPin = true
                badge = "救贫大吉向首"
            } else if name == "甲" || name == "癸" {
                desc = "向首为【\(name)山向】。水法大忌：艮方出水为黄泉杀水（主残疾退财、官非口舌）。"
                isDanger = true
                badge = "大忌艮水出煞"
            } else if name == "艮" {
                desc = "向首为【艮向】。杨公水法：见甲方或癸方来水为【救贫催官水】（大吉，少男发达、巨富显达）。"
                isJiuPin = true
                badge = "救贫大吉向首"
            } else if name == "辛" || name == "壬" {
                desc = "向首为【\(name)山向】。水法大忌：乾方出水为破军黄泉（犯之主吐血、横祸、少亡破败）。"
                isDanger = true
                badge = "大忌乾方破局"
            } else if name == "乾" {
                desc = "向首为【乾向】。杨公水法：见辛方或壬方来水为【救贫黄泉水】（大吉，长房显耀、金玉满堂）。"
                isJiuPin = true
                badge = "救贫大吉向首"
            } else {
                desc = "向首为【\(name)山向】。不属八路黄泉正煞位，水法依杨公三合十二长生（养生冠临旺，生来会旺、拔水入库）消纳即吉。"
                badge = "正针纯清纳水"
            }
        }
        
        return HuangQuanWaterResult(
            facingMountain: name,
            waterDesc: desc,
            isJiuPin: isJiuPin,
            isDanger: isDanger,
            badgeText: badge
        )
    }
    
    // 2. 坐山八煞曜位
    public func resolveBaSha(sitting: Mountain24Item) -> BaShaResult {
        let palace = sitting.palace
        let lang = LocalizationManager.shared.effectiveLanguage
        let info = baShaMap[palace] ?? ("辰", "东南", "逢坐山煞曜方，不可有尖峰怪石冲穴。")
        
        let remedy: String
        let lore: String
        switch lang {
        case .en:
            remedy = "Sha Neutralization: If power towers or sharp wall edges appear in this direction, hang a Mountain-Sea Mirror or Five Sacred Mountains Talisman to shield."
            lore = "Sitting Mountain Sha in \(info.dir) (\(info.zhi)). Strictly avoid high-voltage towers, sharp rocks, or stagnant water in this sector."
        case .zhHant:
            remedy = "消砂法則：該方若見高壓電線塔、壁刀尖角，急需懸掛山海鎮或五嶽真形圖予以遮擋化解。"
            let hantLore: [String: String] = [
                "坎": "坎卦三山（壬／子／癸）煞在辰位。辰方最忌見高壓電塔、尖角怪石或破敗死水，犯之主腎疾、下元損丁。",
                "坤": "坤卦三山（未／坤／申）煞在卯位。忌正東見衝射，主脾胃敗壞、老母傷損。",
                "震": "震卦三山（甲／卯／乙）煞在申位。忌西南申方突兀尖峰，主長房傷殘、足疾官非。",
                "巽": "巽卦三山（辰／巽／巳）煞在酉位。忌正西酉金直衝，主婦女產厄、風聲是非。",
                "乾": "乾卦三山（戌／乾／亥）煞在午位。忌正南離火烈焰反克天門，主心腦血光、損老翁。",
                "兑": "兌卦三山（庚／酉／辛）煞在巳位。忌東南巳火傷金，主少女不利、肺疾吐血。",
                "艮": "艮卦三山（丑／艮／寅）煞在寅位。忌東北見破山絕澗，損幼子少男。",
                "离": "離卦三山（丙／午／丁）煞在亥位。忌西北亥水衝射，主眼疾暗昧、中房受制。"
            ]
            lore = hantLore[palace] ?? info.lore
        case .ja:
            remedy = "消砂の法：該当方向に高圧電線塔や尖角がある場合、山海鎮鏡や五岳真形図を掲げて化解します。"
            lore = "\(palace)卦の坐山八煞は\(info.dir)(\(info.zhi))方位にあります。高圧電線塔や怪石、死水を厳禁とします。"
        case .ko:
            remedy = "소사 법칙: 해당 방위에 고압 전선탑이나 벽도 등의 뾰족한 모서리가 보이면 산해진이나 오악진형도로 가려 화해합니다."
            lore = "\(palace)괘 좌산의 팔살요위는 \(info.dir)(\(info.zhi))방입니다. 고압탑, 괴석, 오염된 물을 엄금합니다."
        case .vi:
            remedy = "Pháp tắc tiêu sát: Phương này nếu thấy cột điện cao thế hay góc nhọn xung xạ, cần treo Sơn Hải Trấn hoặc Ngũ Nhạc Chân Hình Đồ để hóa giải."
            lore = "Khảm quái tọa sơn Bát Sát tại phương \(info.dir) (\(info.zhi)). Kỵ thấy cột điện cao áp, đá nhọn quái dị hay nước tù đọng."
        case .th:
            remedy = "วิธีแก้เคราะห์: หากทิศดังกล่าวมีเสาไฟฟ้าแรงสูงหรือมุมแหลมพุ่งชน ควรแขวนกระจกซานไห่เจิ้นหรือยันต์ห้าขุนเขาเพื่อสะท้อนสลายพลังร้าย"
            lore = "ทิศเคราะห์แปดพิฆาตของขุนเขาหลังพิงอยู่ที่ \(info.dir) (\(info.zhi)) ระวังเสาไฟฟ้า หน้าผาหินแหลม หรือน้ำเน่าเสีย"
        case .id:
            remedy = "Netralisasi Sha: Jika terdapat tiang listrik tegangan tinggi atau sudut tajam dinding di arah ini, gantung cermin Shan Hai Zhen atau jimat pelindung."
            lore = "Sha Posisi Duduk berada di \(info.dir) (\(info.zhi)). Hindari menara listrik, batu tajam, atau genangan air kotor di sektor ini."
        case .auto, .zhHans:
            remedy = "消砂法则：该方若见高压电线塔、壁刀尖角，急需悬挂山海镇或五岳真形图予以遮挡化解。"
            lore = info.lore
        }
        
        return BaShaResult(
            sittingMountain: sitting.name,
            sittingPalace: palace,
            shaZhi: info.zhi,
            shaDir: info.dir,
            lore: lore,
            remedy: remedy
        )
    }
    
    // 3. 四大局长生对照与十二长生水法
    public func resolveWaterMethod(sitting: Mountain24Item) -> [SanHeWaterItem] {
        let phases = ChangShengPhase.allCases
        var list: [SanHeWaterItem] = []

        // The twelve phases are anchored by the four San-He bureaus rather
        // than by the array index of a mountain.  The bureau of the sitting
        // mountain follows the project's double-mountain rule:
        // 火局 = 艮丙辛, 水局 = 坤壬乙, 金局 = 巽庚癸,
        // 木局 = 乾甲丁 (with their corresponding earthly branches).
        // This is different from simply assigning every mountain to its
        // nearest earthly branch; doing that misclassifies 乙、辛、癸、丁.
        let branchByMountain: [String: Int] = [
            "壬": 0, "子": 0, "癸": 0,
            "丑": 1, "艮": 2, "寅": 2,
            "甲": 3, "卯": 3, "乙": 3,
            "辰": 4, "巽": 5, "巳": 5,
            "丙": 6, "午": 6, "丁": 6,
            "未": 7, "坤": 8, "申": 8,
            "庚": 9, "酉": 9, "辛": 9,
            "戌": 10, "乾": 11, "亥": 11
        ]
        let branchIndexForMountain: (Mountain24Item) -> Int = { mountain in
            branchByMountain[mountain.name] ?? 0
        }
        let bureauStart: Int
        switch sitting.name {
        case "申", "子", "辰", "坤", "壬", "乙":
            // 申子辰水局，长生在申
            bureauStart = 8
        case "亥", "卯", "未", "乾", "甲", "丁":
            // 亥卯未木局，长生在亥
            bureauStart = 11
        case "寅", "午", "戌", "艮", "丙", "辛":
            // 寅午戌火局，长生在寅
            bureauStart = 2
        default:
            // 巳酉丑金局，长生在巳
            bureauStart = 5
        }

        let mData = Mountain24Data.shared.mountains
        for (idx, m) in mData.enumerated() {
            let targetBranch = branchIndexForMountain(m)
            let phaseOffset = (targetBranch - bureauStart + 12) % 12
            let p = phases[phaseOffset]
            let isHQ = (sitting.name == "庚" && m.name == "坤") || (sitting.name == "丁" && m.name == "坤") ||
                       (sitting.name == "乙" && m.name == "巽") || (sitting.name == "丙" && m.name == "巽") ||
                       (sitting.name == "甲" && m.name == "艮") || (sitting.name == "癸" && m.name == "艮") ||
                       (sitting.name == "辛" && m.name == "乾") || (sitting.name == "壬" && m.name == "乾")
            list.append(SanHeWaterItem(id: idx, mountainName: m.name, phase: p, isHuangQuanSha: isHQ))
        }
        return list
    }
}
