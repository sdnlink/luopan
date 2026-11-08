import Foundation
import SwiftUI
import UIKit
import StoreKit
import UserNotifications
import Photos
import CoreSpotlight

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
    
    public var name: String {
        switch self {
        case .shengQi: return "生气"
        case .yanNian: return "延年"
        case .tianYi:  return "天医"
        case .fuWei:   return "伏位"
        case .jueMing: return "绝命"
        case .wuGui:   return "五鬼"
        case .liuSha:  return "六煞"
        case .huoHai:  return "祸害"
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
    
    /// Traditional wording is kept verbatim in `baseLocalizedSuggestion`.
    /// The source note below makes the health/wealth symbolism explicit without
    /// presenting it as a clinical or financial conclusion.
    public var localizedSuggestion: String {
        baseLocalizedSuggestion + "\n\n" + classicalSourceNote
    }

    private var baseLocalizedSuggestion: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch self {
            case .shengQi: return "Ideal for wealth growth, main entrance, master bedroom, and activating vibrant energy."
            case .yanNian: return "Favors longevity, health, family harmony, and interpersonal relations; ideal for master bedroom or living room."
            case .tianYi:  return "Dispels illness and misfortune, attracts benefactors; ideal for beds and sacred altars."
            case .fuWei:   return "Stability, peace, and academic excellence; ideal for study, meditation, and children's room."
            case .jueMing: return "Indicates health decline and financial drain. What to do: Use this direction for a bathroom or storage, keep it rarely occupied; never use it as the main bedroom, entrance or study. → Effect: Mainly health drain and money loss for the frail and elders of the family; covers this direction."
            case .wuGui:   return "Prone to quarrels, official disputes and theft. What to do: Counteract with a heavy object or still water (dark container); avoid red and drilling here. → Effect: Mainly disputes, official trouble and theft concerns for family members (most tied to the breadwinner's career); covers this direction."
            case .liuSha:  return "Emotional turbulence and romance trouble. What to do: Place storage cabinets/shelves here, keep it tidy and rarely occupied; avoid using it as the main bedroom or study. → Effect: Mainly disputes, gossip and relationship trouble for family members (most felt by the women, younger members and the couple), plus unwanted romance attention; covers this direction."
            case .huoHai:  return "Obstacles, petty disputes and money drain. What to do: Keep this direction still; place a ceramic/earth-toned item to stabilize, avoid heavy renovation. → Effect: Mainly official trouble, money loss and stomach discomfort (felt most by the decision-maker and the frail); covers this direction."
            }
        case .zhHant:
            switch self {
            case .shengQi: return "最利求財進職、開大門、置主臥、安動氣之源"
            case .yanNian: return "利健康長壽、夫妻和睦、人際關係，宜主臥客堂"
            case .tianYi:  return "消災解厄、身體強健、得貴人相扶，利安床與神位"
            case .fuWei:   return "安穩守成、文昌得利，宜作書房、冥想及兒童房"
            case .jueMing: return "主病痛耗散、破財風險。做法：宜作衛生間或儲物間，少坐人；嚴禁作主臥、大門或書房。→ 影響：主家中體弱者與長輩健康損耗、破財風險，覆蓋該方位。"
            case .wuGui:   return "易惹口舌是非、盜賊火災。做法：放重物壓鎮或設靜水（黑色容器）化氣；忌紅色與動工。→ 影響：主家中成員是非官非、防盜（男主人事業與官非更相關），覆蓋該方位。"
            case .liuSha:  return "酒色桃花、心緒不寧。做法：此方位設雜物櫃/儲物架，保持整潔少坐人；不宜作主臥或書房。→ 影響：主家中成員是非口舌與感情糾紛（女眷、年輕成員及夫妻關係感受最明顯），桃花困擾；覆蓋該方位。"
            case .huoHai:  return "官非小人、財帛破耗。做法：宜靜不宜動，放陶瓷/土性擺件穩定氣場，忌開鑿大動。→ 影響：主家中成員官非小人、破財與脾胃不適（主事者與體弱者更明顯），覆蓋該方位。"
            }
        case .ja:
            switch self {
            case .shengQi: return "財運・昇進、玄関、主寝室、気を取り入れる場所に最適です"
            case .yanNian: return "健康長寿、夫婦円満、人間関係に良く、主寝室や居間に適しています"
            case .tianYi:  return "厄除け、健康増進、貴人の助けを得るのに良く、ベッドや神棚に最適です"
            case .fuWei:   return "安定安寧、学業成就、書斎、瞑想室、子供部屋に適しています"
            case .jueMing: return "病気や気力減退、出費を招きます。やり方：浴室や倉庫として使い、人が長く居ないようにします。主寝室・玄関・書斎には使わない。→ 効果：体の弱い人や年配者の健康消耗と出費に作用。この方位に効果。"
            case .wuGui:   return "口論や役所トラブル、盗難を招きやすい方位。やり方：重い物で押さえるか静水（黒い容器）で化気します。赤と工事は避ける。→ 効果：家族の言い争い・官非・防犯に作用（働き手の仕事と最も関係）。この方位に効果。"
            case .liuSha:  return "感情トラブルや精神の乱れを招きやすい方位です。やり方：収納棚や物置を置き、整理整頓し人があまり居ない場所にします。主寝室や書斎にはしない。→ 効果：家族の言い争いや感情のもつれ（女性、若い世代、夫婦に最も現れやすい）、恋愛問題に作用します。この方位に効果。"
            case .huoHai:  return "訴訟や小人の邪魔、散財を招きます。やり方：この方位は静かに保ち、陶器や土色の置物で安定させ、大がかりな工事は避ける。→ 効果：家族の官非・散財・胃腸の不調に作用（主導者と体の弱い人に現れやすい）。この方位に効果。"
            }
        case .ko:
            switch self {
            case .shengQi: return "재물과 승진에 가장 길하며 대문, 안방, 생기 있는 곳에 적합합니다"
            case .yanNian: return "건강 장수와 부부 화목, 대인관계에 이로우며 침실이나 거실에 좋습니다"
            case .tianYi:  return "질병 액운을 물리치고 귀인의 도움을 받으며 침대와 제단에 길합니다"
            case .fuWei:   return "안정과 수성, 학업 문창에 유익하며 서재나 명상방, 아이방에 좋습니다"
            case .jueMing: return "건강 쇠퇴와 재물 손실을 부릅니다. 방법: 화장실이나 창고로 쓰고 사람이 오래 머물지 않게 합니다. 안방·대문·서재로는 쓰지 마세요. → 효과: 집안의 병약한 사람과 어르신의 건강 소모 및 파재에 작용. 이 방위에 효과."
            case .wuGui:   return "구설 관재와 도난 위험이 있는 방위입니다. 방법: 무거운 물건으로 누르거나 정수(검은 용기)로 화기시킵니다. 빨간색과 공사를 피하세요. → 효과: 가족의 구설·관재·방범에 작용(생계를 책임지는 사람의 일과 가장 관련). 이 방위에 효과."
            case .liuSha:  return "감정 혼란과 이성 문제를 부르는 방위입니다. 방법: 수납장이나 창고로 쓰고 정리 정돈하며 사람이 오래 머물지 않게 합니다. 안방이나 서재로는 쓰지 마세요. → 효과: 가족의 구설과 감정 다툼(여성, 젊은 세대, 부부에게 가장 잘 나타남) 및 이성 문제에 작용합니다. 이 방위에 효과."
            case .huoHai:  return "구설 시비와 재물 손실을 부릅니다. 방법: 이 방위는 조용히 두고 도자기나 흙색 장식품으로 안정시키며 큰 공사를 피합니다. → 효과: 가족의 관재·파재·위장 불편에 작용(주도하는 사람과 병약한 사람에게 잘 나타남). 이 방위에 효과."
            }
        case .vi:
            switch self {
            case .shengQi: return "Tốt nhất cho cầu tài lộc thăng tiến, mở cửa chính, phòng ngủ chính, nơi nạp khí."
            case .yanNian: return "Lợi cho sức khỏe trường thọ, gia đạo hòa thuận, quan hệ tốt đẹp, hợp phòng ngủ/khách."
            case .tianYi:  return "Tiêu trừ bệnh tật tai ương, quý nhân phù trợ, rất lợi đặt giường và bàn thờ."
            case .fuWei:   return "Bình an ổn định, vượng văn xương học vấn, hợp phòng đọc sách, thiền định, trẻ em."
            case .jueMing: return "Chủ bệnh tật hao tài. Cách làm: Dùng làm nhà vệ sinh hoặc kho, ít người lui tới; không làm cửa chính, phòng ngủ hay phòng sách. → Ảnh hưởng: Sức khỏe người yếu và người lớn tuổi bị hao tổn cùng rủi ro hao tài; phủ hướng này."
            case .wuGui:   return "Dễ vướng khẩu thiệt, thị phi quan phi, hỏa hoạn đạo tặc. Cách làm: Đặt vật nặng trấn áp hoặc nước tĩnh (bình sẫm màu) hóa giải; tránh màu đỏ và động thổ. → Ảnh hưởng: Thị phi, quan phi và phòng trộm của người nhà (liên quan nhất công danh người trụ cột); phủ hướng này."
            case .liuSha:  return "Đào hoa xấu, tâm thần bất an. Cách làm: Dùng nơi này làm tủ chứa đồ/kho, giữ gọn gàng, ít người lui tới; không làm phòng ngủ chính hay phòng sách. → Ảnh hưởng: Thị phi, cãi vã và rắc rối tình cảm của người nhà (phụ nữ, người trẻ và vợ chồng cảm nhận rõ nhất) cùng vận đào hoa; phủ hướng này."
            case .huoHai:  return "Thị phi tiểu nhân, hao tài tốn của. Cách làm: Giữ tĩnh tránh động, đặt đồ gốm/màu đất ổn định khí trường, tránh động thổ lớn. → Ảnh hưởng: Quan phi, hao tài và khó chịu dạ dày của người nhà (người quyết định và người yếu rõ hơn); phủ hướng này."
            }
        case .th:
            switch self {
            case .shengQi: return "ดีที่สุดสำหรับโชคลาภการงาน ประตูใหญ่ ห้องนอนใหญ่ และจุดรับพลังงานหมุนเวียน"
            case .yanNian: return "เสริมสุขภาพ อายุยืน ครอบครัวปรองดอง เหมาะกับห้องนอนใหญ่และห้องรับแขก"
            case .tianYi:  return "ปัดเป่าโรคภัย ได้รับความช่วยเหลือจากผู้ใหญ่ เหมาะสำหรับตั้งเตียงและหิ้งบูชา"
            case .fuWei:   return "ความมั่นคงราบรื่น สติปัญญาและการเรียนรู้ เหมาะกับห้องหนังสือ ห้องสมาธิ ห้องเด็ก"
            case .jueMing: return "เหน็ดเหนื่อยเจ็บป่วยและเสียเงิน วิธีทำ: ใช้เป็นห้องน้ำหรือห้องเก็บของ ปล่อยให้มีคนอยู่ไม่นาน ห้ามทำประตู ห้องนอน หรือห้องหนังสือ → ผล: สุขภาพคนอ่อนแอและผู้ใหญ่ทรุดโทรม เสี่ยงเสียทรัพย์ ครอบคลุมทิศนี้"
            case .wuGui:   return "เสี่ยงปากเสียง เรื่องหน่วยงานและขโมย วิธีทำ: ใช้ของหนักทับหรือน้ำนิ่ง (ภาชนะสีเข้ม) ปรับพลัง ห้ามสีแดงและห้ามขุดเจาะ → ผล: ปากเสียง เรื่องหน่วยงานและป้องกันขโมยของคนในบ้าน (สัมพันธ์กับงานของผู้หาเลี้ยงมากที่สุด) ครอบคลุมทิศนี้"
            case .liuSha:  return "อารมณ์แปรปรวน เรื่องชายหญิงไม่สงบ วิธีทำ: ใช้เป็นตู้เก็บของ/ห้องเก็บของ เก็บให้เป็นระเบียบ ไม่ควรใช้เป็นห้องนอนใหญ่หรือห้องหนังสือ → ผล: ลดปากเสียง ทะเลาะและเรื่องความรักของคนในบ้าน (ผู้หญิง คนหนุ่มสาว และคู่สามีภรรยาเห็นชัดที่สุด) รวมถึงเรื่องชู้สาว ครอบคลุมทิศนี้"
            case .huoHai:  return "อุปสรรคข้อขัดแย้ง การเงินรั่วไหล วิธีทำ: ปล่อยให้สงบนิ่ง วางของเซรามิก/สีดินเพื่อทรงพลัง หลีกเลี่ยงการรื้อปรับใหญ่ → ผล: เรื่องหน่วยงาน เสียเงินและกระเพาะไม่สบายของคนในบ้าน (ผู้ตัดสินใจและคนอ่อนแอเห็นชัดกว่า) ครอบคลุมทิศนี้"
            }
        case .id:
            switch self {
            case .shengQi: return "Sangat baik untuk rezeki, karier, pintu utama, kamar utama, dan sirkulasi energi positif."
            case .yanNian: return "Mendukung kesehatan, umur panjang, keharmonisan keluarga; baik untuk kamar tidur dan ruang tamu."
            case .tianYi:  return "Menghalau penyakit, mendatangkan penolong; sangat baik untuk ranjang tidur dan altar."
            case .fuWei:   return "Kedamaian dan prestasi akademis; cocok untuk ruang kerja, meditasi, dan kamar anak."
            case .jueMing: return "Penyebab kelelahan, penyakit dan kehilangan uang. Cara: Gunakan sebagai toilet/gudang, jarang dihuni; jangan jadikan kamar tidur utama, pintu atau ruang kerja. → Efek: Kesehatan anggota yang lemah dan orang tua terkuras serta risiko kehilangan uang; mencakup arah ini."
            case .wuGui:   return "Memicu perselisihan, masalah hukum dan pencurian. Cara: Netralkan dengan benda berat atau air tenang (wadah gelap); hindari merah dan penggalian. → Efek: Perselisihan, masalah hukum dan keamanan anggota keluarga (paling terkait karier pencari nafkah); mencakup arah ini."
            case .liuSha:  return "Kekacauan emosi dan masalah percintaan. Cara: Gunakan area ini untuk lemari penyimpanan/gudang, jaga rapi dan jarang dihuni; jangan jadikan kamar tidur utama atau ruang kerja. → Efek: Mengurangi pertikaian, gosip dan masalah hubungan anggota keluarga (paling terasa pada wanita, anggota muda dan pasangan) serta perhatian asmara tak diinginkan; mencakup arah ini."
            case .huoHai:  return "Rintangan, pertengkaran dan kehilangan uang. Cara: Jaga tetap tenang, taruh keramik/item warna tanah untuk stabil; hindari renovasi besar. → Efek: Masalah hukum, kehilangan uang dan ketidaknyamanan lambung (lebih terasa pada pengambil keputusan dan yang lemah); mencakup arah ini."
            }
        case .auto, .zhHans:
            switch self {
            case .shengQi: return "最利求财进职、开大门、置主卧、安动气之源"
            case .yanNian: return "利健康长寿、夫妻和睦、人际关系，宜主卧客堂"
            case .tianYi:  return "消灾解厄、身体强健、得贵人相扶，利安床与神位"
            case .fuWei:   return "安稳守成、文昌得利，宜作书房、冥想及儿童房"
            case .jueMing: return "主病痛耗散、破财风险。做法：宜作卫生间或储物间，少坐人；严禁作主卧、大门或书房。→ 影响：主家中体弱者与长辈健康损耗、破财风险，覆盖该方位。"
            case .wuGui:   return "易惹口舌是非、盗贼火灾。做法：放重物压镇或设静水（黑色容器）化气；忌红色与动工。→ 影响：主家中成员是非官非、防盗（男主人事业与官非更相关），覆盖该方位。"
            case .liuSha:  return "酒色桃花、心绪不宁。做法：此方位设杂物柜/储物架，保持整洁少坐人；不宜作主卧或书房。→ 影响：主家中成员是非口舌与感情纠纷（女眷、年轻成员及夫妻关系感受最明显），桃花困扰；覆盖该方位。"
            case .huoHai:  return "官非小人、财帛破耗。做法：宜静不宜动，放陶瓷/土性摆件稳定气场，忌开凿大动。→ 影响：主家中成员官非小人、破财与脾胃不适（主事者与体弱者更明显），覆盖该方位。"
            }
        }
    }

    private var classicalSourceNote: String {
        let source = "《八宅明镜》八宅九星诀：“生气贪狼木，延年武曲金，天医巨门土，伏位辅弼木；绝命破军金，五鬼廉贞火，六煞文曲水，祸害禄存土。”"
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return "Classical source: Eight-House Nine-Star formula in Ba Zhai Ming Jing: ‘Sheng Qi is Tan Lang Wood; Yan Nian is Wu Qu Metal; Tian Yi is Ju Men Earth; Fu Wei is Fu Bi Wood; Jue Ming is Po Jun Metal; Wu Gui is Lian Zhen Fire; Liu Sha is Wen Qu Water; Huo Hai is Lu Cun Earth.’ Interpretation: the health, vitality and wealth language above is a symbolic traditional-culture reading of these star names, not a medical diagnosis, treatment, financial advice or guaranteed outcome."
        case .zhHant:
            return "古籍出处： 《八宅明鏡》八宅九星訣：「生氣貪狼木，延年武曲金，天醫巨門土，伏位輔弼木；絕命破軍金，五鬼廉貞火，六煞文曲水，禍害祿存土。」解釋：上文涉及健康、元氣與財帛的語句，屬九星名義的傳統文化象徵解讀，不是醫療診斷、治療或財務建議，也不保證實際結果。"
        case .ja:
            return "出典：『八宅明鏡』八宅九星訣「生気は貪狼木、延年は武曲金、天医は巨門土、伏位は輔弼木、絶命は破軍金、五鬼は廉貞火、六殺は文曲水、禍害は禄存土」。解釈：健康・活力・財に関する表現は星名に基づく伝統文化上の象徴的な読みであり、医学的診断・治療・金融助言や結果の保証ではありません。"
        case .ko:
            return "출처: 《팔택명경》 팔택구성결 ‘생기는 탐랑목, 연년은 무곡금, 천의는 거문토, 복위는 보필목, 절명은 파군금, 오귀는 염정화, 육살은 문곡수, 화해는 녹존토’입니다. 해석: 위 건강·활력·재물 표현은 전통문화의 상징적 해석이며 의학적 진단·치료·재무 조언이나 결과 보장이 아닙니다."
        case .vi:
            return "Nguồn cổ: Quyết Cửu Tinh Bát Trạch trong Bát Trạch Minh Kính: ‘Sinh Khí thuộc Tham Lang Mộc; Diên Niên thuộc Vũ Khúc Kim; Thiên Y thuộc Cự Môn Thổ; Phục Vị thuộc Phụ Bật Mộc; Tuyệt Mệnh thuộc Phá Quân Kim; Ngũ Quỷ thuộc Liêm Trinh Hỏa; Lục Sát thuộc Văn Khúc Thủy; Họa Hại thuộc Lộc Tồn Thổ.’ Giải thích: các câu về sức khỏe, sinh lực và tài lộc là biểu tượng văn hóa truyền thống, không phải chẩn đoán y khoa, điều trị, tư vấn tài chính hay bảo đảm kết quả."
        case .th:
            return "ที่มาโบราณ: สูตรดาวเก้าดวงแปดบ้านในคัมภีร์ปาจ้ายหมิงจิ่งกล่าวว่า ‘เซิงชี่ดาวทานหลางธาตุไม้ เหยียนเหนียนดาวอู่ชวีธาตุทอง เทียนอีดาวจวี้เหมินธาตุดิน ฝูเว่ยดาวฝู่ปี้ธาตุไม้ เจวี๋ยหมิงดาวผัวจวินธาตุทอง อู่กุ่ยดาวเหลียนเจินธาตุไฟ ลิ่วซาดาวเหวินชวีธาตุน้ำ ฮั่วไห่ดาวลู่ชุนธาตุดิน’ คำอธิบาย: ถ้อยคำด้านสุขภาพ พลังชีวิต และทรัพย์สินเป็นสัญลักษณ์ทางวัฒนธรรมดั้งเดิม ไม่ใช่การวินิจฉัยหรือรักษาโรค คำแนะนำทางการเงิน หรือการรับประกันผลลัพธ์"
        case .id:
            return "Sumber klasik: Rumus Sembilan Bintang Ba Zhai dalam Ba Zhai Ming Jing: ‘Sheng Qi Tan Lang Kayu; Yan Nian Wu Qu Logam; Tian Yi Ju Men Tanah; Fu Wei Fu Bi Kayu; Jue Ming Po Jun Logam; Wu Gui Lian Zhen Api; Liu Sha Wen Qu Air; Huo Hai Lu Cun Tanah.’ Penjelasan: ungkapan tentang kesehatan, vitalitas, dan rezeki di atas adalah tafsir simbolik budaya tradisional, bukan diagnosis medis, pengobatan, nasihat keuangan, atau jaminan hasil."
        case .auto, .zhHans:
            return "古籍出处：\(source)解释：上文涉及健康、元气与财帛的语句，属于九星名义的传统文化象征解读，不是医疗诊断、治疗或财务建议，也不保证实际结果。"
        }
    }
}

public struct BaZhaiPalaceItem: Identifiable {
    public let id: Int
    public let direction: String
    public let guaName: String
    public let star: StarLuckType
    
    public var localizedSuggestion: String {
        star.localizedSuggestion
    }

    public var localizedGuaName: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en, .id:
            return ["坎": "Kan", "坤": "Kun", "震": "Zhen", "巽": "Xun", "乾": "Qian", "兑": "Dui", "艮": "Gen", "离": "Li"][guaName] ?? guaName
        case .ja, .zhHant:
            return ["坎": "坎", "坤": "坤", "震": "震", "巽": "巽", "乾": "乾", "兑": "兌", "艮": "艮", "离": "離"][guaName] ?? guaName
        case .ko:
            return ["坎": "감", "坤": "곤", "震": "진", "巽": "손", "乾": "건", "兑": "태", "艮": "간", "离": "이"][guaName] ?? guaName
        case .vi:
            return ["坎": "Khảm", "坤": "Khôn", "震": "Chấn", "巽": "Tốn", "乾": "Càn", "兑": "Đoài", "艮": "Cấn", "离": "Ly"][guaName] ?? guaName
        case .th:
            return ["坎": "ข่าน", "坤": "คุน", "震": "เจิ้น", "巽": "ซวิ่น", "乾": "เฉียน", "兑": "ตุ้ย", "艮": "เกิ้น", "离": "หลี"][guaName] ?? guaName
        case .zhHans, .auto:
            return guaName
        }
    }

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

extension StarLuckType {
    /// 顶置白话吉凶速断（面向大众用户的一句话通俗宜忌）
    public var plainLanguageSummary: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            switch self {
            case .shengQi: return "✅ Top Wealth & Vitality Spot: Best for main door, master bedroom, or work desk."
            case .yanNian: return "✅ Harmony & Relationship Spot: Ideal for master bedroom and family living room."
            case .tianYi:  return "✅ Health & Benefactor Spot: Great for beds, elders' room, and clean kitchen."
            case .fuWei:   return "✅ Study & Calm Spot: Best for study desk, reading corner, or children's room."
            case .jueMing: return "⚠️ Major Taboo Spot: Avoid sleeping or working here long-term; use as bathroom/storage."
            case .wuGui:   return "⚠️ Dispute & Fire Taboo: Keep calm and tidy; avoid red decor or drilling here."
            case .liuSha:  return "⚠️ Restless Energy Spot: Better for storage cabinets; avoid master bed or study."
            case .huoHai:  return "⚠️ Minor Drain Spot: Keep quiet with earth/ceramic decor; avoid heavy renovation."
            }
        case .zhHant:
            switch self {
            case .shengQi: return "✅ 【白話速斷 · 第一大吉位】最旺財運與事業晉升，首選設為大門、主臥或辦公桌。"
            case .yanNian: return "✅ 【白話速斷 · 感情貴人位】最利夫妻和睦與人際長壽，極宜設為主臥或客廳沙發。"
            case .tianYi:  return "✅ 【白話速斷 · 健康祛病位】利睡眠養生與貴人扶持，宜安床、長輩房或整潔廚房。"
            case .fuWei:   return "✅ 【白話速斷 · 文昌安穩位】氣場平和利讀書思考，宜設書房、書桌或兒童房。"
            case .jueMing: return "⚠️ 【白話速斷 · 凶位避忌】不宜久睡久坐，建議作衛生間或儲物間以「凶位壓凶」。"
            case .wuGui:   return "⚠️ 【白話速斷 · 防是非火險】忌大紅大紫與動土鑽牆，宜保持整潔或放黑曜石/靜水化氣。"
            case .liuSha:  return "⚠️ 【白話速斷 · 防爛桃花口舌】不宜作主臥或書房，建議設儲物櫃並保持乾爽。"
            case .huoHai:  return "⚠️ 【白話速斷 · 防小人破耗】宜靜不宜動，可擺陶瓷器物穩固氣場。"
            }
        case .ja:
            switch self {
            case .shengQi: return "✅ 【要点】財運・昇進の第一吉方位。玄関・主寝室・デスクに最適。"
            case .yanNian: return "✅ 【要点】夫婦円満・対人運の吉方位。主寝室やリビングに好適。"
            case .tianYi:  return "✅ 【要点】健康・厄除けの吉方位。ベッド配置や年長者の部屋に吉。"
            case .fuWei:   return "✅ 【要点】学業・安定の吉方位。書斎・学習机・子供部屋に好適。"
            case .jueMing: return "⚠️ 【注意】長時間過ごす寝室や書斎は避け、浴室や収納に充てると吉。"
            case .wuGui:   return "⚠️ 【注意】口論・火気に注意。赤色や工事を避け、静かに保つこと。"
            case .liuSha:  return "⚠️ 【注意】感情の乱れに注意。収納棚として使い、寝室は避ける。"
            case .huoHai:  return "⚠️ 【注意】出費・小人に注意。陶器の置物で気を安定させると良い。"
            }
        case .ko:
            switch self {
            case .shengQi: return "✅ [핵심 요약] 재물·승진 최고 길방. 대문·안방·책상 배치에 최적."
            case .yanNian: return "✅ [핵심 요약] 부부 화목·인간관계 길방. 안방이나 거실 소파에 적합."
            case .tianYi:  return "✅ [핵심 요약] 건강·귀인 길방. 침대 배치나 어르신 방에 길함."
            case .fuWei:   return "✅ [핵심 요약] 학업·안정 길방. 서재·공부방·아이방으로 적합."
            case .jueMing: return "⚠️ [주의] 침실·서재는 피하고 화장실이나 창고로 눌러주면 무난합니다."
            case .wuGui:   return "⚠️ [주의] 구설·화기 주의. 붉은색과 공사를 피하고 정갈히 유지하세요."
            case .liuSha:  return "⚠️ [주의] 감정 소모 주의. 수납장으로 활용하고 안방 배치는 피하세요."
            case .huoHai:  return "⚠️ [주의] 금전 손실 주의. 도자기 소품으로 기운을 안정시키세요."
            }
        case .vi:
            switch self {
            case .shengQi: return "✅ [Tóm tắt] Cung Đại Cát vượng tài lộc: Rất hợp đặt cửa chính, phòng ngủ chính, bàn làm việc."
            case .yanNian: return "✅ [Tóm tắt] Cung Hòa Hợp & Quý Nhân: Tốt cho phòng ngủ vợ chồng và phòng khách."
            case .tianYi:  return "✅ [Tóm tắt] Cung Sức Khỏe: Hợp kê giường ngủ, phòng người lớn tuổi."
            case .fuWei:   return "✅ [Tóm tắt] Cung Văn Xương: Hợp làm phòng đọc sách, bàn học."
            case .jueMing: return "⚠️ [Lưu ý] Tránh đặt giường ngủ/bàn làm việc; nên dùng làm phòng tắm hoặc kho."
            case .wuGui:   return "⚠️ [Lưu ý] Phòng thị phi; tránh màu đỏ rực và khoan đục tại đây."
            case .liuSha:  return "⚠️ [Lưu ý] Nên đặt tủ chứa đồ gọn gàng, tránh làm phòng ngủ chính."
            case .huoHai:  return "⚠️ [Lưu ý] Nên giữ tĩnh, đặt đồ gốm sứ để ổn định khí trường."
            }
        case .th:
            switch self {
            case .shengQi: return "✅ [สรุปเข้าใจง่าย] ทิศมงคลสูงสุดด้านโชคลาภ: เหมาะตั้งประตูหลัก ห้องนอนใหญ่ หรือโต๊ะทำงาน"
            case .yanNian: return "✅ [สรุปเข้าใจง่าย] ทิศความรักและครอบครัว: เหมาะกับห้องนอนใหญ่และห้องนั่งเล่น"
            case .tianYi:  return "✅ [สรุปเข้าใจง่าย] ทิศสุขภาพและผู้อุปถัมภ์: เหมาะตั้งเตียงนอนและห้องผู้สูงอายุ"
            case .fuWei:   return "✅ [สรุปเข้าใจง่าย] ทิศการเรียนและสมาธิ: เหมาะตั้งโต๊ะหนังสือและห้องเด็ก"
            case .jueMing: return "⚠️ [ข้อควรระวัง] ไม่ควรใช้เป็นห้องนอนหรือโต๊ะทำงาน แนะนำใช้เป็นห้องน้ำหรือห้องเก็บของ"
            case .wuGui:   return "⚠️ [ข้อควรระวัง] ระวังปากเสียง เลี่ยงสีแดงจัดและการเจาะทุบในทิศนี้"
            case .liuSha:  return "⚠️ [ข้อควรระวัง] แนะนำวางตู้เก็บของให้เป็นระเบียบ เลี่ยงการตั้งเตียงนอน"
            case .huoHai:  return "⚠️ [ข้อควรระวัง] ควรปล่อยให้นิ่ง วางเครื่องปั้นดินเผาเพื่อเสริมความมั่นคง"
            }
        case .id:
            switch self {
            case .shengQi: return "✅ [Ringkasan] Titik Rezeki Utama: Terbaik untuk pintu utama, kamar utama, atau meja kerja."
            case .yanNian: return "✅ [Ringkasan] Titik Harmoni Keluarga: Cocok untuk kamar tidur utama & ruang keluarga."
            case .tianYi:  return "✅ [Ringkasan] Titik Kesehatan: Baik untuk posisi ranjang & kamar lansia."
            case .fuWei:   return "✅ [Ringkasan] Titik Studi & Fokus: Cocok untuk ruang belajar & kamar anak."
            case .jueMing: return "⚠️ [Perhatian] Hindari tidur/kerja lama di sini; gunakan sebagai kamar mandi/gudang."
            case .wuGui:   return "⚠️ [Perhatian] Jaga tetap tenang & rapi; hindari warna merah menyala atau renovasi."
            case .liuSha:  return "⚠️ [Perhatian] Lebih baik untuk lemari penyimpanan; hindari kamar utama."
            case .huoHai:  return "⚠️ [Perhatian] Jaga tetap tenang dengan dekorasi keramik/tanah."
            }
        case .auto, .zhHans:
            switch self {
            case .shengQi: return "✅ 【白话速断 · 第一大吉位】最旺财运与事业晋升，首选设为大门、主卧或办公桌。"
            case .yanNian: return "✅ 【白话速断 · 感情贵人位】最利夫妻和睦与人际长寿，极宜设为主卧或客厅沙发。"
            case .tianYi:  return "✅ 【白话速断 · 健康祛病位】利睡眠养生与贵人扶持，宜安床、长辈房或整洁厨房。"
            case .fuWei:   return "✅ 【白话速断 · 文昌安稳位】气场平和利读书思考，宜设书房、书桌或儿童房。"
            case .jueMing: return "⚠️ 【白话速断 · 凶位避忌】不宜久睡久坐，建议作卫生间或储物间以“凶位压凶”。"
            case .wuGui:   return "⚠️ 【白话速断 · 防是非火险】忌大红大紫与动土钻墙，宜保持整洁或放黑曜石/静水化气。"
            case .liuSha:  return "⚠️ 【白话速断 · 防烂桃花口舌】不宜作主卧或书房，建议设储物柜并保持干爽。"
            case .huoHai:  return "⚠️ 【白话速断 · 防小人破耗】宜静不宜动，可摆陶瓷器物稳固气场。"
            }
        }
    }
}

// MARK: - P1.1 宅主个人命卦画像与「人宅合一」配对引擎 (UserKuaProfileManager)

public struct HouseKuaCompatibility {
    public let ownerGua: String             // 如 "离"
    public let localizedOwnerGuaName: String// 如 "离命 (九紫火)"
    public let isEastLife: Bool             // true = 东四命, false = 西四命
    public let localizedLifeGroup: String   // "东四命" / "西四命"
    public let zodiacBranch: String         // 生肖地支，如 "午"
    public let localizedZodiacName: String  // 如 "午马"
    public let isMatchedWithHouse: Bool     // 命宅是否同属东四/西四
    public let matchBadgeTitle: String      // "命宅相配 · 大吉" / "命宅相违 · 需调和"
    public let matchAdvice: String          // 定制化安床/书桌/催吉指引
    public let wealthDirection: String      // 本命生气财位
    public let healthDirection: String      // 本命天医健康位
    public let harmonyDirection: String     // 本命延年感情位
    public let studyDirection: String       // 本命伏位文昌位
}

public enum FamilyRole: String, Codable, CaseIterable, Identifiable {
    case spouse   = "spouse"   // 配偶/伴侣
    case father   = "father"   // 父亲
    case mother   = "mother"   // 母亲
    case elder    = "elder"    // 父母/长辈
    case son      = "son"      // 儿子
    case daughter = "daughter" // 女儿
    case child1   = "child1"   // 长子/长女
    case child2   = "child2"   // 次子/次女
    case other    = "other"    // 其他家人

    public var id: String { rawValue }

    public var defaultIsMale: Bool {
        switch self {
        case .spouse:   return !UserKuaProfileManager.shared.isMale
        case .father:   return true
        case .mother:   return false
        case .elder:    return true
        case .son:      return true
        case .daughter: return false
        case .child1:   return true
        case .child2:   return false
        case .other:    return true
        }
    }

    public var localizedTitle: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch self {
            case .spouse:   return "Spouse"
            case .father:   return "Father"
            case .mother:   return "Mother"
            case .elder:    return "Parent/Elder"
            case .son:      return "Son"
            case .daughter: return "Daughter"
            case .child1:   return "Child 1"
            case .child2:   return "Child 2"
            case .other:    return "Other Family"
            }
        case .zhHant:
            switch self {
            case .spouse:   return "配偶/伴侶"
            case .father:   return "父親"
            case .mother:   return "母親"
            case .elder:    return "父母/長輩"
            case .son:      return "兒子"
            case .daughter: return "女兒"
            case .child1:   return "長子/長女"
            case .child2:   return "次子/次女"
            case .other:    return "其他家人"
            }
        case .ja:
            switch self {
            case .spouse:   return "配偶者"
            case .father:   return "父親"
            case .mother:   return "母親"
            case .elder:    return "両親・年長者"
            case .son:      return "息子"
            case .daughter: return "娘"
            case .child1:   return "第一子"
            case .child2:   return "第二子"
            case .other:    return "その他家族"
            }
        case .ko:
            switch self {
            case .spouse:   return "배우자"
            case .father:   return "아버지"
            case .mother:   return "어머니"
            case .elder:    return "부모/어르신"
            case .son:      return "아들"
            case .daughter: return "딸"
            case .child1:   return "자녀 1"
            case .child2:   return "자녀 2"
            case .other:    return "기타 가족"
            }
        case .vi:
            switch self {
            case .spouse:   return "Vợ/Chồng"
            case .father:   return "Cha"
            case .mother:   return "Mẹ"
            case .elder:    return "Ông Bà/Cha Mẹ"
            case .son:      return "Con trai"
            case .daughter: return "Con gái"
            case .child1:   return "Con thứ 1"
            case .child2:   return "Con thứ 2"
            case .other:    return "Người thân khác"
            }
        case .th:
            switch self {
            case .spouse:   return "คู่สมรส"
            case .father:   return "บิดา/พ่อ"
            case .mother:   return "มารดา/แม่"
            case .elder:    return "ผู้สูงอายุ"
            case .son:      return "บุตรชาย"
            case .daughter: return "บุตรสาว"
            case .child1:   return "บุตรคนที่ 1"
            case .child2:   return "บุตรคนที่ 2"
            case .other:    return "สมาชิกอื่นๆ"
            }
        case .id:
            switch self {
            case .spouse:   return "Pasangan"
            case .father:   return "Ayah"
            case .mother:   return "Ibu"
            case .elder:    return "Orang Tua"
            case .son:      return "Anak Laki-laki"
            case .daughter: return "Anak Perempuan"
            case .child1:   return "Anak 1"
            case .child2:   return "Anak 2"
            case .other:    return "Keluarga Lain"
            }
        case .auto, .zhHans:
            switch self {
            case .spouse:   return "配偶/伴侣"
            case .father:   return "父亲"
            case .mother:   return "母亲"
            case .elder:    return "父母/长辈"
            case .son:      return "儿子"
            case .daughter: return "女儿"
            case .child1:   return "长子/长女"
            case .child2:   return "次子/次女"
            case .other:    return "其他家人"
            }
        }
    }
}

public struct FamilyMemberProfile: Codable, Identifiable, Equatable {
    public var id: String
    public var role: FamilyRole
    public var customName: String?
    public var birthYear: Int
    public var isMale: Bool

    public init(id: String = UUID().uuidString, role: FamilyRole, customName: String? = nil, birthYear: Int, isMale: Bool) {
        self.id = id
        self.role = role
        self.customName = customName
        self.birthYear = max(1920, min(2035, birthYear))
        self.isMale = isMale
    }

    enum CodingKeys: String, CodingKey {
        case id, role, customName, birthYear, isMale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role = try container.decode(FamilyRole.self, forKey: .role)
        self.customName = try container.decodeIfPresent(String.self, forKey: .customName)
        self.birthYear = try container.decode(Int.self, forKey: .birthYear)
        self.isMale = try container.decode(Bool.self, forKey: .isMale)
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encodeIfPresent(customName, forKey: .customName)
        try container.encode(birthYear, forKey: .birthYear)
        try container.encode(isMale, forKey: .isMale)
    }

    public var displayName: String {
        if let name = customName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return role.localizedTitle
    }

    public var lifeGuaNumber: Int {
        UserKuaProfileManager.calcGuaNumber(birthYear: birthYear, isMale: isMale)
    }

    public var guaKey: String {
        UserKuaProfileManager.guaKey(for: lifeGuaNumber)
    }

    public var isEastLife: Bool {
        [1, 3, 4, 9].contains(lifeGuaNumber)
    }

    public var localizedGuaBadge: String {
        let guaItem = BaZhaiPalaceItem(id: 0, direction: "", guaName: guaKey, star: .fuWei)
        let lang = LocalizationManager.shared.effectiveLanguage
        switch lang {
        case .en:
            return "\(guaItem.localizedGuaName) · \(isEastLife ? "East 4" : "West 4")"
        case .zhHant, .ja:
            return "\(guaItem.localizedGuaName)命·\(isEastLife ? "東四命" : "西四命")"
        case .ko:
            return "\(guaItem.localizedGuaName)명·\(isEastLife ? "동사명" : "서사명")"
        case .vi:
            return "Mệnh \(guaItem.localizedGuaName)·\(isEastLife ? "Đông Tứ" : "Tây Tứ")"
        case .th:
            return "ดวง\(guaItem.localizedGuaName)·\(isEastLife ? "ตะวันออก" : "ตะวันตก")"
        case .id:
            return "Gua \(guaItem.localizedGuaName)·\(isEastLife ? "Timur" : "Barat")"
        case .auto, .zhHans:
            return "\(guaItem.localizedGuaName)命·\(isEastLife ? "东四命" : "西四命")"
        }
    }

    public var personalWealthAndStudySummary: String {
        let chart = BaZhaiEngine.shared.analyze(sittingPalace: guaKey, facingPalace: "离")
        let wDir = chart.items.first(where: { $0.star == .shengQi })?.localizedDirection ?? "-"
        let sDir = chart.items.first(where: { $0.star == .fuWei })?.localizedDirection ?? "-"
        let hDir = chart.items.first(where: { $0.star == .tianYi })?.localizedDirection ?? "-"
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            return "Wealth: \(wDir) · Health: \(hDir) · Study: \(sDir)"
        case .zhHant, .ja:
            return "生氣財位:\(wDir) · 天醫康健:\(hDir) · 文昌伏位:\(sDir)"
        case .ko:
            return "생기:\(wDir) · 천의:\(hDir) · 문창:\(sDir)"
        case .vi:
            return "Sinh Khí:\(wDir) · Thiên Y:\(hDir) · Văn Xương:\(sDir)"
        case .th:
            return "โชคลาภ:\(wDir) · สุขภาพ:\(hDir) · การเรียน:\(sDir)"
        case .id:
            return "Rezeki:\(wDir) · Sehat:\(hDir) · Studi:\(sDir)"
        case .auto, .zhHans:
            return "生气财位:\(wDir) · 天医康健:\(hDir) · 文昌伏位:\(sDir)"
        }
    }
}

public final class UserKuaProfileManager: ObservableObject {
    public static let shared = UserKuaProfileManager()

    private let kBirthYearKey = "tiandi_owner_birth_year"
    private let kBirthDateKey = "tiandi_owner_birth_date"
    private let kIsMaleKey = "tiandi_owner_is_male"
    private let kEnabledKey = "tiandi_owner_profile_enabled"
    private let kFamilyMembersKey = "tiandi_family_members_v1"

    @Published public var birthYear: Int {
        didSet {
            let clamped = max(1920, min(2035, birthYear))
            if birthYear != clamped {
                birthYear = clamped
                return
            }
            UserDefaults.standard.set(birthYear, forKey: kBirthYearKey)
            LocalizationManager.sharedDefaults?.set(birthYear, forKey: kBirthYearKey)
            NSUbiquitousKeyValueStore.default.set(Int64(birthYear), forKey: kBirthYearKey)
        }
    }

    @Published public var birthDate: Date {
        didSet {
            UserDefaults.standard.set(birthDate.timeIntervalSince1970, forKey: kBirthDateKey)
            LocalizationManager.sharedDefaults?.set(birthDate.timeIntervalSince1970, forKey: kBirthDateKey)
            NSUbiquitousKeyValueStore.default.set(birthDate.timeIntervalSince1970, forKey: kBirthDateKey)
        }
    }

    @Published public var isMale: Bool {
        didSet {
            UserDefaults.standard.set(isMale, forKey: kIsMaleKey)
            LocalizationManager.sharedDefaults?.set(isMale, forKey: kIsMaleKey)
            NSUbiquitousKeyValueStore.default.set(isMale, forKey: kIsMaleKey)
        }
    }

    @Published public var isProfileEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isProfileEnabled, forKey: kEnabledKey)
            LocalizationManager.sharedDefaults?.set(isProfileEnabled, forKey: kEnabledKey)
            NSUbiquitousKeyValueStore.default.set(isProfileEnabled, forKey: kEnabledKey)
        }
    }

    @Published public var familyMembers: [FamilyMemberProfile] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(familyMembers) {
                UserDefaults.standard.set(data, forKey: kFamilyMembersKey)
                LocalizationManager.sharedDefaults?.set(data, forKey: kFamilyMembersKey)
                NSUbiquitousKeyValueStore.default.set(data, forKey: kFamilyMembersKey)
            }
        }
    }

    private init() {
        let shared = LocalizationManager.sharedDefaults
        let cloud = NSUbiquitousKeyValueStore.default
        let cloudYear = cloud.longLong(forKey: kBirthYearKey)
        let savedYear = (shared?.object(forKey: kBirthYearKey) as? Int)
            ?? (UserDefaults.standard.object(forKey: kBirthYearKey) as? Int)
            ?? (cloudYear > 0 ? Int(cloudYear) : nil)
            ?? 1990
        let clampedYear = max(1920, min(2035, savedYear))
        let savedTimestamp = (shared?.object(forKey: kBirthDateKey) as? Double)
            ?? (UserDefaults.standard.object(forKey: kBirthDateKey) as? Double)
            ?? {
                var comp = DateComponents()
                comp.year = clampedYear
                comp.month = 6
                comp.day = 15
                return Calendar.current.date(from: comp)?.timeIntervalSince1970
            }()
            ?? Date().timeIntervalSince1970
        let savedMale = (shared?.object(forKey: kIsMaleKey) as? Bool)
            ?? (UserDefaults.standard.object(forKey: kIsMaleKey) as? Bool)
            ?? true
        let savedEnabled = (shared?.object(forKey: kEnabledKey) as? Bool)
            ?? (UserDefaults.standard.object(forKey: kEnabledKey) as? Bool)
            ?? true
        self.birthYear = clampedYear
        self.birthDate = Date(timeIntervalSince1970: savedTimestamp)
        self.isMale = savedMale
        self.isProfileEnabled = savedEnabled
        if let fData = (shared?.data(forKey: kFamilyMembersKey))
            ?? UserDefaults.standard.data(forKey: kFamilyMembersKey)
            ?? cloud.data(forKey: kFamilyMembersKey),
           let decoded = try? JSONDecoder().decode([FamilyMemberProfile].self, from: fData) {
            self.familyMembers = decoded
        }
    }

    /// 根据公历日期精确推算所属风水流年（以每年公历约2月4日立春交节为界）
    public static func fengShuiYear(for date: Date) -> Int {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        // 立春公历约在 2 月 4 日（偶为 2 月 3 或 5 日），立春前按上一干支岁次核算
        if month < 2 || (month == 2 && day < 4) {
            return max(1920, min(2035, year - 1))
        }
        return max(1920, min(2035, year))
    }

    /// 统一更新宅主生辰日期（支持年月日公历日期）与性别
    public func updateOwnerBirth(date: Date, isMale: Bool) {
        self.birthDate = date
        self.birthYear = Self.fengShuiYear(for: date)
        self.isMale = isMale
    }

    /// 统一更新宅主出生年份与性别
    public func updateOwnerBirthYear(_ year: Int, isMale: Bool) {
        let clamped = max(1920, min(2035, year))
        self.birthYear = clamped
        self.isMale = isMale
        var comp = Calendar.current.dateComponents([.year, .month, .day], from: self.birthDate)
        comp.year = clamped
        if let newDate = Calendar.current.date(from: comp) {
            self.birthDate = newDate
        }
    }

    public static func calcGuaNumber(birthYear: Int, isMale: Bool) -> Int {
        var sum = birthYear
        while sum >= 10 {
            var next = 0
            var temp = sum
            while temp > 0 {
                next += temp % 10
                temp /= 10
            }
            sum = next
        }
        let raw: Int
        if isMale {
            var v = (11 - sum) % 9
            if v <= 0 { v += 9 }
            raw = (v == 5) ? 2 : v
        } else {
            var v = (sum + 4) % 9
            if v <= 0 { v += 9 }
            raw = (v == 5) ? 8 : v
        }
        return raw
    }

    public static func guaKey(for guaNumber: Int) -> String {
        switch guaNumber {
        case 1: return "坎"
        case 2: return "坤"
        case 3: return "震"
        case 4: return "巽"
        case 6: return "乾"
        case 7: return "兑"
        case 8: return "艮"
        case 9: return "离"
        default: return "坎"
        }
    }

    public func addFamilyMember(role: FamilyRole, customName: String? = nil, birthYear: Int, isMale: Bool) {
        let profile = FamilyMemberProfile(role: role, customName: customName, birthYear: birthYear, isMale: isMale)
        familyMembers.append(profile)
    }

    public func updateFamilyMember(id: String, role: FamilyRole? = nil, customName: String? = nil, birthYear: Int? = nil, isMale: Bool? = nil) {
        guard let idx = familyMembers.firstIndex(where: { $0.id == id }) else { return }
        var m = familyMembers[idx]
        if let role = role { m.role = role }
        if let customName = customName { m.customName = customName }
        if let birthYear = birthYear { m.birthYear = max(1920, min(2035, birthYear)) }
        if let isMale = isMale { m.isMale = isMale }
        familyMembers[idx] = m
    }

    public func removeFamilyMember(id: String) {
        familyMembers.removeAll { $0.id == id }
    }

    public func addOrUpdateFamilyMember(role: FamilyRole, birthYear: Int, isMale: Bool) {
        if let idx = familyMembers.firstIndex(where: { $0.role == role }) {
            familyMembers[idx].birthYear = birthYear
            familyMembers[idx].isMale = isMale
        } else {
            addFamilyMember(role: role, birthYear: birthYear, isMale: isMale)
        }
    }

    public func removeFamilyMember(role: FamilyRole) {
        familyMembers.removeAll { $0.role == role }
    }

    /// 智能分房推荐：根据房间落宫八卦，自动匹配最适合居住/使用该房间的家庭成员（如子女文昌伏位、长辈天医位、夫妻延年/生气位）
    public func recommendFamilyMemberForPalace(canonGua: String) -> String? {
        guard isProfileEnabled, canonGua != "中", !familyMembers.isEmpty else { return nil }
        for member in familyMembers {
            let chart = BaZhaiEngine.shared.analyze(sittingPalace: member.guaKey, facingPalace: "离")
            if let item = chart.items.first(where: { $0.guaName == canonGua }), item.star.isAuspicious {
                let sName = item.star.localizedName
                switch LocalizationManager.shared.effectiveLanguage {
                case .en:
                    return "[Smart Room Fit] Best for \(member.displayName) (\(member.birthYear), \(sName))"
                case .zhHant:
                    return "【智能分房推薦】極利「\(member.displayName)（\(member.birthYear)年）」居住或學習（落其本命\(sName)）"
                case .ja:
                    return "【部屋割推奨】「\(member.displayName)（\(member.birthYear)年）」に最適（本命\(sName)）"
                case .ko:
                    return "[맞춤 방 추천] '\(member.displayName)(\(member.birthYear)년)'에게 최적 (본명 \(sName))"
                case .vi:
                    return "[Gợi Ý Phân Phòng] Rất hợp cho \(member.displayName) (\(member.birthYear), \(sName))"
                case .th:
                    return "[แนะนำจัดห้อง] เหมาะกับ\(member.displayName) (\(member.birthYear), \(sName))"
                case .id:
                    return "[Rekomendasi Kamar] Cocok untuk \(member.displayName) (\(member.birthYear), \(sName))"
                case .auto, .zhHans:
                    return "【智能分房推荐】极利「\(member.displayName)（\(member.birthYear)年）」居住或学习（落其本命\(sName)）"
                }
            }
        }
        return nil
    }

    /// 根据后天洛书命卦公式计算本命卦洛书数 (1..9，5男寄坤2、女寄艮8)
    public var lifeGuaNumber: Int {
        Self.calcGuaNumber(birthYear: birthYear, isMale: isMale)
    }

    public var ownerGuaKey: String {
        Self.guaKey(for: lifeGuaNumber)
    }

    public var isEastLife: Bool {
        return [1, 3, 4, 9].contains(lifeGuaNumber)
    }

    public func localizedZodiac(language: AppLanguage = LocalizationManager.shared.effectiveLanguage) -> String {
        return evaluateCompatibility(sittingPalace: "坎").localizedZodiacName
    }

    public func localizedLifeKuaName(language: AppLanguage = LocalizationManager.shared.effectiveLanguage) -> String {
        let compat = evaluateCompatibility(sittingPalace: "坎")
        return "\(compat.localizedOwnerGuaName) (\(compat.localizedLifeGroup))"
    }

    public func evaluateCompatibility(sittingPalace: String) -> HouseKuaCompatibility {
        let houseIsEast = ["坎", "震", "巽", "离"].contains(sittingPalace)
        let isMatched = (isEastLife == houseIsEast)
        let personalChart = BaZhaiEngine.shared.analyze(sittingPalace: ownerGuaKey, facingPalace: sittingPalace)

        let dirForStar: (StarLuckType) -> String = { target in
            personalChart.items.first(where: { $0.star == target })?.localizedDirection ?? "-"
        }
        let wealthDir = dirForStar(.shengQi)
        let healthDir = dirForStar(.tianYi)
        let harmonyDir = dirForStar(.yanNian)
        let studyDir = dirForStar(.fuWei)

        let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
        let bIdx = ((birthYear - 4) % 12 + 12) % 12
        let branch = branches[bIdx]

        let lang = LocalizationManager.shared.effectiveLanguage
        let zodiacNames: [String]
        switch lang {
        case .en, .id:
            zodiacNames = ["Rat", "Ox", "Tiger", "Rabbit", "Dragon", "Snake", "Horse", "Goat", "Monkey", "Rooster", "Dog", "Pig"]
        case .zhHant, .ja:
            zodiacNames = ["子鼠", "丑牛", "寅虎", "卯兔", "辰龍", "巳蛇", "午馬", "未羊", "申猴", "酉雞", "戌狗", "亥豬"]
        case .ko:
            zodiacNames = ["자쥐", "축소", "인호랑이", "묘토끼", "진용", "사뱀", "오말", "미양", "신원숭이", "유닭", "술개", "해돼지"]
        case .vi:
            zodiacNames = ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"]
        case .th:
            zodiacNames = ["ชวด", "ฉลู", "ขาล", "เถาะ", "มะโรง", "มะเส็ง", "มะเมีย", "มะแม", "วอก", "ระกา", "จอ", "กุน"]
        case .auto, .zhHans:
            zodiacNames = ["子鼠", "丑牛", "寅虎", "卯兔", "辰龙", "巳蛇", "午马", "未羊", "申猴", "酉鸡", "戌狗", "亥猪"]
        }

        let guaItem = BaZhaiPalaceItem(id: 0, direction: "", guaName: ownerGuaKey, star: .fuWei)
        let localizedGua: String
        let lifeGroup: String
        let badge: String
        let advice: String

        switch lang {
        case .en:
            localizedGua = "\(guaItem.localizedGuaName) Gua (#\(lifeGuaNumber))"
            lifeGroup = isEastLife ? "East 4 Life" : "West 4 Life"
            badge = isMatched ? "Life & House Matched · Auspicious" : "Life & House Mismatch · Adjust Bed/Desk"
            advice = isMatched
                ? "Your \(lifeGroup) matches this house. Place your master bed or work desk facing your personal Wealth (\(wealthDir)) or Health (\(healthDir)) sector."
                : "Your \(lifeGroup) differs from this house's group. Mitigate by placing your bedhead or desk toward your personal Tian Yi (\(healthDir)) or Sheng Qi (\(wealthDir)) direction."
        case .zhHant:
            localizedGua = "\(guaItem.localizedGuaName)命"
            lifeGroup = isEastLife ? "東四命" : "西四命"
            badge = isMatched ? "宅命相配 · 人宅合一" : "宅命不同組 · 宜用本命吉方調候"
            advice = isMatched
                ? "宅主屬【\(lifeGroup)】，與本宅坐向同氣相求！主臥安床與辦公桌首選朝向本命生氣財位【\(wealthDir)】或天醫位【\(healthDir)】。"
                : "宅主屬【\(lifeGroup)】，與本宅不同四宅。化解之法：將床頭、書桌或常坐沙發朝向宅主本命天醫位【\(healthDir)】或生氣位【\(wealthDir)】，即可納吉氣。"
        case .ja:
            localizedGua = "\(guaItem.localizedGuaName)命"
            lifeGroup = isEastLife ? "東四命" : "西四命"
            badge = isMatched ? "宅命一致 · 大吉" : "宅命不一致 · 吉方位で調整"
            advice = isMatched
                ? "施主は【\(lifeGroup)】で家相と調和しています。ベッドや机は本命の生気財位【\(wealthDir)】または天医位【\(healthDir)】に向けると吉。"
                : "施主は【\(lifeGroup)】です。ベッドの頭や机を本命の天医位【\(healthDir)】または生気位【\(wealthDir)】に向けて調和させてください。"
        case .ko:
            localizedGua = "\(guaItem.localizedGuaName)명"
            lifeGroup = isEastLife ? "동사명" : "서사명"
            badge = isMatched ? "택명상배 · 대길" : "택명불일치 · 본명 길방 활용"
            advice = isMatched
                ? "택주는 【\(lifeGroup)】으로 본 주택과 조화롭습니다. 침대와 책상은 본명 생기 재물방【\(wealthDir)】이나 천의방【\(healthDir)】으로 배치하세요."
                : "택주는 【\(lifeGroup)】입니다. 침대 머리나 책상을 본명 천의방【\(healthDir)】 또는 생기방【\(wealthDir)】으로 두어 조화시키세요."
        case .vi:
            localizedGua = "Mệnh \(guaItem.localizedGuaName)"
            lifeGroup = isEastLife ? "Đông Tứ Mệnh" : "Tây Tứ Mệnh"
            badge = isMatched ? "Mệnh Trạch Tương Hợp · Đại Cát" : "Mệnh Trạch Khác Nhóm · Hóa Giải"
            advice = isMatched
                ? "Gia chủ thuộc 【\(lifeGroup)】, hợp với hướng nhà. Nên đặt giường hoặc bàn làm việc hướng về Sinh Khí 【\(wealthDir)】 hoặc Thiên Y 【\(healthDir)】."
                : "Gia chủ thuộc 【\(lifeGroup)】. Hóa giải bằng cách xoay đầu giường hoặc bàn làm việc về hướng Thiên Y 【\(healthDir)】 hoặc Sinh Khí 【\(wealthDir)】."
        case .th:
            localizedGua = "ดวง\(guaItem.localizedGuaName)"
            lifeGroup = isEastLife ? "ดวงทิศตะวันออก" : "ดวงทิศตะวันตก"
            badge = isMatched ? "ดวงเจ้าของบ้านสมพงศ์กับบ้าน" : "ดวงต่างกลุ่ม · ปรับด้วยทิศมงคลเฉพาะตัว"
            advice = isMatched
                ? "เจ้าของบ้านอยู่กลุ่ม【\(lifeGroup)】สมพงศ์กับบ้าน แนะนำหันหัวเตียงหรือโต๊ะทำงานไปทางทิศโชคลาภ【\(wealthDir)】หรือทิศสุขภาพ【\(healthDir)】"
                : "แนะนำปรับแก้โดยหันหัวเตียงหรือโต๊ะทำงานไปทางทิศหมอสวรรค์【\(healthDir)】หรือทิศโชคลาภ【\(wealthDir)】ของเจ้าของบ้าน"
        case .id:
            localizedGua = "Gua \(guaItem.localizedGuaName)"
            lifeGroup = isEastLife ? "Empat Timur" : "Empat Barat"
            badge = isMatched ? "Gua Pemilik & Rumah Selaras" : "Beda Kelompok · Sesuaikan Arah Ranjang"
            advice = isMatched
                ? "Gua Anda (\(lifeGroup)) selaras dengan rumah ini. Arahkan ranjang atau meja kerja ke arah Rezeki (\(wealthDir)) atau Kesehatan (\(healthDir))."
                : "Sesuaikan dengan mengarahkan kepala ranjang atau meja kerja ke arah Tian Yi (\(healthDir)) atau Sheng Qi (\(wealthDir)) pribadi Anda."
        case .auto, .zhHans:
            localizedGua = "\(guaItem.localizedGuaName)命"
            lifeGroup = isEastLife ? "东四命" : "西四命"
            badge = isMatched ? "宅命相配 · 人宅合一" : "宅命不同组 · 宜用本命吉方调候"
            advice = isMatched
                ? "宅主属【\(lifeGroup)】，与本宅坐向同气相求！主卧安床与办公桌首选朝向本命生气财位【\(wealthDir)】或天医位【\(healthDir)】。"
                : "宅主属【\(lifeGroup)】，与本宅不同四宅。化解之法：将床头、书桌或常坐沙发朝向宅主本命天医位【\(healthDir)】或生气位【\(wealthDir)】，即可纳吉气。"
        }

        return HouseKuaCompatibility(
            ownerGua: ownerGuaKey,
            localizedOwnerGuaName: localizedGua,
            isEastLife: isEastLife,
            localizedLifeGroup: lifeGroup,
            zodiacBranch: branch,
            localizedZodiacName: zodiacNames[bIdx],
            isMatchedWithHouse: isMatched,
            matchBadgeTitle: badge,
            matchAdvice: advice,
            wealthDirection: wealthDir,
            healthDirection: healthDir,
            harmonyDirection: harmonyDir,
            studyDirection: studyDir
        )
    }
}

// MARK: - P1.3 留存与召回服务：App Store 智能好评引导与节气/吉日本地通知 (RetentionServiceManager)

public struct FengshuiRemedyTask: Codable, Identifiable, Equatable {
    public let id: String
    public let palaceDirection: String
    public let title: String
    public let remedyAction: String
    public let createdAt: Date
    public var isCompleted: Bool

    public init(
        id: String,
        palaceDirection: String,
        title: String,
        remedyAction: String,
        createdAt: Date = Date(),
        isCompleted: Bool = false
    ) {
        self.id = id
        self.palaceDirection = palaceDirection
        self.title = title
        self.remedyAction = remedyAction
        self.createdAt = createdAt
        self.isCompleted = isCompleted
    }
}

public final class RetentionServiceManager: ObservableObject {
    public static let shared = RetentionServiceManager()

    private let kMilestoneCountKey = "tiandi_review_milestone_count"
    private let kLastReviewPromptTimeKey = "tiandi_last_review_prompt_ts"
    private let kSolarTermNotifyKey = "tiandi_solar_term_notify_enabled"
    private let kScheduledDaysKey = "tiandi_scheduled_auspicious_days"
    private let kRemedyTasksKey = "tiandi_remedy_tasks_v1"

    @Published public var solarTermNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(solarTermNotificationsEnabled, forKey: kSolarTermNotifyKey)
        }
    }
    @Published public var showNotificationPermissionDeniedAlert: Bool = false

    @Published public private(set) var scheduledDayIDs: Set<String> = []
    @Published public var remedyTasks: [FengshuiRemedyTask] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(remedyTasks) {
                UserDefaults.standard.set(data, forKey: kRemedyTasksKey)
                NSUbiquitousKeyValueStore.default.set(data, forKey: kRemedyTasksKey)
            }
        }
    }

    private init() {
        self.solarTermNotificationsEnabled = UserDefaults.standard.bool(forKey: kSolarTermNotifyKey)
        if let saved = UserDefaults.standard.stringArray(forKey: kScheduledDaysKey) {
            self.scheduledDayIDs = Set(saved)
        }
        if let rData = UserDefaults.standard.data(forKey: kRemedyTasksKey)
            ?? NSUbiquitousKeyValueStore.default.data(forKey: kRemedyTasksKey),
           let decoded = try? JSONDecoder().decode([FengshuiRemedyTask].self, from: rData) {
            self.remedyTasks = decoded
        }
    }

    public func toggleRemedyTask(id: String, palaceDirection: String, title: String, remedyAction: String) {
        if let idx = remedyTasks.firstIndex(where: { $0.id == id }) {
            remedyTasks.remove(at: idx)
        } else {
            let task = FengshuiRemedyTask(
                id: id,
                palaceDirection: palaceDirection,
                title: title,
                remedyAction: remedyAction
            )
            remedyTasks.insert(task, at: 0)
        }
    }

    public func toggleRemedyCompletion(id: String) {
        if let idx = remedyTasks.firstIndex(where: { $0.id == id }) {
            remedyTasks[idx].isCompleted.toggle()
        }
    }

    public func removeRemedyTask(id: String) {
        remedyTasks.removeAll { $0.id == id }
    }

    /// 注册 iOS 主屏幕长按快捷入口 (Quick Actions) 与系统 Spotlight 搜索索引 (CoreSpotlight)
    public func registerSystemShortcutsAndSpotlight() {
        let lang = LocalizationManager.shared.effectiveLanguage
        let s1Title: String; let s1Sub: String
        let s2Title: String; let s2Sub: String
        let s3Title: String; let s3Sub: String
        let s4Title: String; let s4Sub: String
        switch lang {
        case .en:
            s1Title = "Daily Wealth & Joy Compass"; s1Sub = "Locate today's auspicious directions"
            s2Title = "Daily Auspicious Sign Card"; s2Sub = "Generate & share today's fortune card"
            s3Title = "Floorplan 9-Palace Audit"; s3Sub = "Check room layout & owner Life Gua"
            s4Title = "Qi Men Decision Guide"; s4Sub = "Best hour & direction for contracts/wealth"
        case .zhHant:
            s1Title = "今日財神與吉方導引"; s1Sub = "一鍵開啟羅盤財神喜神金標"
            s2Title = "今日吉方日籤海報"; s2Sub = "生成黑金國風日課分享卡"
            s3Title = "戶型九宮立極體檢"; s3Sub = "多套宅譜對比與智能分房"
            s4Title = "奇門遁甲辦事吉方"; s4Sub = "簽約求財出行一事一斷"
        case .ja:
            s1Title = "本日の財神・吉方位ガイド"; s1Sub = "羅盤で吉方位を即座に確認"
            s2Title = "本日の吉籤カード作成"; s2Sub = "日課カードを保存・共有"
            s3Title = "間取り九宮風水診断"; s3Sub = "複数物件比較と部屋割推奨"
            s4Title = "奇門遁甲・用事別吉方"; s4Sub = "契約・金運・外出の吉方"
        case .ko:
            s1Title = "오늘의 재신·길방 가이드"; s1Sub = "나침반 길방 마커 바로 켜기"
            s2Title = "오늘의 길첨 카드"; s2Sub = "일과 길방 포스터 생성 및 공유"
            s3Title = "평면도 구궁 풍수 진단"; s3Sub = "다주택 비교 및 맞춤 방 추천"
            s4Title = "기문둔갑 용건별 길방"; s4Sub = "계약·재물·출행 길방 속람"
        case .vi:
            s1Title = "Hướng Thần Tài & Hỷ Thần"; s1Sub = "Mở nhanh kim chỉ nam cát phương"
            s2Title = "Thẻ Cát Phương Hôm Nay"; s2Sub = "Tạo & chia sẻ thẻ nhật khóa"
            s3Title = "Khám Phong Thủy Mặt Bằng"; s3Sub = "So sánh căn hộ & gợi ý phân phòng"
            s4Title = "Kỳ Môn Cát Phương Theo Việc"; s4Sub = "Ký kết, cầu tài, xuất hành"
        case .th:
            s1Title = "นำทางทิศเทพโชคลาภวันนี้"; s1Sub = "เปิดเข็มทิศชี้ทิศมงคลทันที"
            s2Title = "การ์ดมงคลประจำวัน"; s2Sub = "สร้างและแชร์การ์ดฤกษ์มงคล"
            s3Title = "ตรวจฮวงจุ้ยผังบ้าน 9 วัง"; s3Sub = "เปรียบเทียบผังบ้านและจัดห้อง"
            s4Title = "ฉีเหมินชี้ทิศตามธุระ"; s4Sub = "เซ็นสัญญา โชคลาภ เดินทาง"
        case .id:
            s1Title = "Panduan Arah Rezeki Hari Ini"; s1Sub = "Buka penunjuk arah hoki di kompas"
            s2Title = "Kartu Keberuntungan Harian"; s2Sub = "Buat & bagikan kartu harian"
            s3Title = "Audit Denah 9 Istana"; s3Sub = "Bandingkan properti & rekomendasi kamar"
            s4Title = "Panduan Qi Men Sesuai Urusan"; s4Sub = "Kontrak, rezeki, perjalanan"
        case .auto, .zhHans:
            s1Title = "今日财神与吉方导引"; s1Sub = "一键开启罗盘财神喜神金标"
            s2Title = "今日吉方日签海报"; s2Sub = "生成黑金国风日课分享卡"
            s3Title = "户型九宫立极体检"; s3Sub = "多套宅谱对比与智能分房"
            s4Title = "奇门遁甲办事吉方"; s4Sub = "签约求财出行一事一断"
        }

        DispatchQueue.main.async {
            UIApplication.shared.shortcutItems = [
                UIApplicationShortcutItem(
                    type: "com.yanxiang.compass.shortcut.dailygods",
                    localizedTitle: s1Title,
                    localizedSubtitle: s1Sub,
                    icon: UIApplicationShortcutIcon(systemImageName: "safari.fill")
                ),
                UIApplicationShortcutItem(
                    type: "com.yanxiang.compass.shortcut.dailysign",
                    localizedTitle: s2Title,
                    localizedSubtitle: s2Sub,
                    icon: UIApplicationShortcutIcon(systemImageName: "sparkles.rectangle.stack.fill")
                ),
                UIApplicationShortcutItem(
                    type: "com.yanxiang.compass.shortcut.floorplan",
                    localizedTitle: s3Title,
                    localizedSubtitle: s3Sub,
                    icon: UIApplicationShortcutIcon(systemImageName: "square.split.bottomrightquarter.fill")
                ),
                UIApplicationShortcutItem(
                    type: "com.yanxiang.compass.shortcut.qimen",
                    localizedTitle: s4Title,
                    localizedSubtitle: s4Sub,
                    icon: UIApplicationShortcutIcon(systemImageName: "timelapse")
                )
            ]
        }

        // CoreSpotlight 索引注册，支持用户在 iOS 负一屏下拉搜索“财神方位”、“黄道吉日”、“户型风水”、“奇门遁甲”直达本 App
        let entries: [(id: String, title: String, desc: String, keywords: [String])] = [
            ("tiandiluopan://compass?guide=dailyGods", s1Title, s1Sub, ["财神", "喜神", "罗盘", "吉方", "Compass", "Wealth", "Fengshui"]),
            ("tiandiluopan://compass?sheet=dailySign", s2Title, s2Sub, ["日签", "黄历", "吉日", "Almanac", "Sign"]),
            ("tiandiluopan://tab?index=3", s3Title, s3Sub, ["户型", "分房", "缺角", "八宅", "Floorplan", "Room"]),
            ("tiandiluopan://tab?index=2&sub=qimen", s4Title, s4Sub, ["奇门遁甲", "出行", "签约", "求财", "Qimen"])
        ]
        var searchableItems: [CSSearchableItem] = []
        for entry in entries {
            let attr = CSSearchableItemAttributeSet(itemContentType: "public.content")
            attr.title = entry.title
            attr.contentDescription = entry.desc
            attr.keywords = entry.keywords
            let item = CSSearchableItem(uniqueIdentifier: entry.id, domainIdentifier: "com.yanxiang.compass", attributeSet: attr)
            searchableItems.append(item)
        }
        CSSearchableIndex.default().indexSearchableItems(searchableItems, completionHandler: nil)
    }

    /// 是否正处于自动化 UI 测试或截图流水线环境（避免弹窗干扰自动化测试）
    public static var isRunningAutomatedTests: Bool {
        let args = CommandLine.arguments
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return true }
        if args.contains("-appLanguage") || args.contains("-uiTesting") { return true }
        return false
    }

    /// 当前是否运行于 TestFlight 测试分发或 Xcode 本地调试沙盒环境
    public static var isTestFlightOrDebug: Bool {
        #if DEBUG
        return true
        #else
        guard let url = Bundle.main.appStoreReceiptURL else { return false }
        return url.lastPathComponent == "sandboxReceipt"
        #endif
    }

    /// 记录用户核心正向行为（锁盘、保存户型档案、导出天机长卷等），达到阈值且距上次弹窗超过 14 天时请求系统级评分
    public func recordMilestone(reason: String) {
        guard !Self.isRunningAutomatedTests else { return }
        let count = UserDefaults.standard.integer(forKey: kMilestoneCountKey) + 1
        UserDefaults.standard.set(count, forKey: kMilestoneCountKey)
        // 在第 2 次、第 6 次、第 15 次关键操作完成时触发
        guard count == 2 || count == 6 || count % 15 == 0 else { return }
        let lastPrompt = UserDefaults.standard.double(forKey: kLastReviewPromptTimeKey)
        let now = Date().timeIntervalSince1970
        guard now - lastPrompt > 14 * 86400 else { return }
        UserDefaults.standard.set(now, forKey: kLastReviewPromptTimeKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.requestImmediateReview()
        }
    }

    public func setSolarTermNotifications(enabled: Bool) {
        if !enabled {
            self.solarTermNotificationsEnabled = false
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["tiandi_next_solar_term"])
            return
        }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            switch settings.authorizationStatus {
            case .denied:
                DispatchQueue.main.async {
                    self.solarTermNotificationsEnabled = false
                    self.showNotificationPermissionDeniedAlert = true
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    DispatchQueue.main.async {
                        if granted {
                            self.solarTermNotificationsEnabled = true
                            self.scheduleSolarTermNotificationPayload()
                        } else {
                            self.solarTermNotificationsEnabled = false
                        }
                    }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    self.solarTermNotificationsEnabled = true
                    self.scheduleSolarTermNotificationPayload()
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.solarTermNotificationsEnabled = false
                }
            }
        }
    }

    /// 跳转至 iOS 系统设置开启本 App 的通知权限
    public func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// 同步最新的系统通知授权状态（从后台回前台或从系统设置切回时调用）
    public func syncNotificationAuthorizationStatus() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied {
                    if self.solarTermNotificationsEnabled {
                        self.solarTermNotificationsEnabled = false
                        center.removePendingNotificationRequests(withIdentifiers: ["tiandi_next_solar_term"])
                    }
                } else if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                    let savedPref = UserDefaults.standard.bool(forKey: self.kSolarTermNotifyKey)
                    if savedPref && !self.solarTermNotificationsEnabled {
                        self.solarTermNotificationsEnabled = true
                        self.scheduleSolarTermNotificationPayload()
                    }
                }
            }
        }
    }

    public func requestImmediateReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        if #available(iOS 14.0, *) {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    /// 开启并排程下一节气交节与流月飞星换局提醒（兼容旧调用）
    public func requestAndScheduleSolarTermNotifications() {
        setSolarTermNotifications(enabled: true)
    }

    /// 执行下一节气提醒排程
    public func scheduleSolarTermNotificationPayload() {
        let solar = SolarTimeCalculator.shared
        let now = Date()
        let elapsed = solar.solarTermProgress(for: now)
        let termDays = 15.0 / 0.98564736
        let daysLeft = max(1, Int(ceil(termDays - elapsed)))
        var cal = Calendar.current
        cal.timeZone = .current
        guard let targetDay = cal.date(byAdding: .day, value: daysLeft, to: now),
              let fireDate = cal.date(bySettingHour: 8, minute: 30, second: 0, of: targetDay) else { return }

        let nextIndex = (solar.solarTermIndex(for: now) + 1) % 24
        let nextTermName = SolarTermsData.shared.terms[safe: nextIndex]?.localizedName ?? ""

        let content = UNMutableNotificationContent()
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            content.title = "Solar Term Transition · \(nextTermName)"
            content.body = "Monthly Flying Stars and Qi shift today. Open Tiandi Luopan to check your home's auspicious directions."
        case .zhHant:
            content.title = "節氣交節提醒 · 今日【\(nextTermName)】"
            content.body = "節氣更迭，流月紫白九星氣場今日換局，點擊查看本宅最新流月財位與吉凶宜忌。"
        case .ja:
            content.title = "節気交節リマインダー・本日【\(nextTermName)】"
            content.body = "節気が切り替わり、流月紫白九星の気場が更新されました。今月の財位と吉凶方位を確認しましょう。"
        case .ko:
            content.title = "절기 교절 알림 · 오늘 【\(nextTermName)】"
            content.body = "절기가 바뀌며 유월 자백구성 기장이 전환되었습니다. 이달의 재물방과 길흉 방위를 확인하세요."
        case .vi:
            content.title = "Nhắc Nhở Giao Tiết Khí · Hôm Nay 【\(nextTermName)】"
            content.body = "Tiết khí chuyển giao, Cửu Tinh lưu nguyệt đổi cục hôm nay. Mở ứng dụng để xem tài vị và hướng tốt."
        case .th:
            content.title = "แจ้งเตือนเปลี่ยน절기 · วันนี้ 【\(nextTermName)】"
            content.body = "เปลี่ยนสาร์ท절기 ดาวบินประจำเดือนเปลี่ยน局วันนี้ เปิดแอปเพื่อตรวจทิศโชคลาภและฤกษ์มงคล"
        case .id:
            content.title = "Pengingat Pergantian Musim · Hari Ini 【\(nextTermName)】"
            content.body = "Bintang Terbang bulanan berganti hari ini. Buka Tiandi Luopan untuk memeriksa arah keberuntungan rumah Anda."
        case .auto, .zhHans:
            content.title = "节气交节提醒 · 今日【\(nextTermName)】"
            content.body = "节气更迭，流月紫白九星气场今日换局，点击查看本宅最新流月财位与吉凶宜忌。"
        }
        content.sound = .default

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: "tiandi_next_solar_term", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    /// 为用户选定的吉日设置当天早晨 08:00 动土/入宅/出行提醒
    public func toggleAuspiciousDayReminder(day: ZeRiEngine.UpcomingAuspiciousDay, sittingName: String) {
        let reqID = "tiandi_zeri_\(day.id)"
        let center = UNUserNotificationCenter.current()
        if scheduledDayIDs.contains(day.id) {
            center.removePendingNotificationRequests(withIdentifiers: [reqID])
            scheduledDayIDs.remove(day.id)
            UserDefaults.standard.set(Array(scheduledDayIDs), forKey: kScheduledDaysKey)
            return
        }

        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            switch settings.authorizationStatus {
            case .denied:
                DispatchQueue.main.async {
                    self.showNotificationPermissionDeniedAlert = true
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        if granted {
                            self.scheduleAuspiciousDayPayload(day: day, sittingName: sittingName)
                        }
                    }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    self.scheduleAuspiciousDayPayload(day: day, sittingName: sittingName)
                }
            @unknown default:
                break
            }
        }
    }

    private func scheduleAuspiciousDayPayload(day: ZeRiEngine.UpcomingAuspiciousDay, sittingName: String) {
        let reqID = "tiandi_zeri_\(day.id)"
        var cal = Calendar.current
        cal.timeZone = .current
        let now = Date()
        var fireDate = cal.date(bySettingHour: 8, minute: 0, second: 0, of: day.date) ?? day.date
        if fireDate <= now {
            fireDate = now.addingTimeInterval(10)
        }
        let content = UNMutableNotificationContent()
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            content.title = "Auspicious Day Reminder · \(day.localizedDayPillar)"
            content.body = "\(day.dateLabel) (\(sittingName)): Good for \(day.yiSummary)."
        case .zhHant:
            content.title = "黃道吉日提醒 · \(day.dateLabel) (\(day.localizedDayPillar)日)"
            content.body = "本宅【\(sittingName)】今日無歲破月破衝山，宜：\(day.yiSummary)。"
        case .ja:
            content.title = "吉日リマインダー・\(day.dateLabel) (\(day.localizedDayPillar)日)"
            content.body = "本宅【\(sittingName)】本日は歳破・月破の沖山なし。宜：\(day.yiSummary)。"
        case .ko:
            content.title = "황도길일 알림 · \(day.dateLabel) (\(day.localizedDayPillar)일)"
            content.body = "본택【\(sittingName)】 오늘은 세파·월파 충산이 없는 길일입니다. 마땅함: \(day.yiSummary)."
        case .vi:
            content.title = "Nhắc Nhở Ngày Hoàng Đạo · \(day.dateLabel) (\(day.localizedDayPillar))"
            content.body = "Bản trạch 【\(sittingName)】 hôm nay không phạm Tuế Phá/Nguyệt Phá. Nên: \(day.yiSummary)."
        case .th:
            content.title = "แจ้งเตือนวันธงชัย · \(day.dateLabel) (\(day.localizedDayPillar))"
            content.body = "บ้าน【\(sittingName)】วันนี้ไม่ชงทิศหลังบ้าน เหมาะสำหรับ: \(day.yiSummary)"
        case .id:
            content.title = "Pengingat Hari Baik · \(day.dateLabel) (\(day.localizedDayPillar))"
            content.body = "Rumah 【\(sittingName)】 bebas bentrokan hari ini. Baik untuk: \(day.yiSummary)."
        case .auto, .zhHans:
            content.title = "黄道吉日提醒 · \(day.dateLabel) (\(day.localizedDayPillar)日)"
            content.body = "本宅【\(sittingName)】今日无岁破月破冲山，宜：\(day.yiSummary)。"
        }
        content.sound = .default
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: reqID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { [weak self] error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.scheduledDayIDs.insert(day.id)
                    UserDefaults.standard.set(Array(self?.scheduledDayIDs ?? []), forKey: self?.kScheduledDaysKey ?? "tiandi_scheduled_auspicious_days")
                }
            }
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - P2.3 「今日吉方日签」黑金国风分享卡生成与预览弹窗 (DailyAuspiciousCardSheet)

public struct DailyAuspiciousCardSheet: View {
    public let targetDate: Date
    @ObservedObject private var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var renderedImage: UIImage? = nil
    @State private var showShareSheet = false
    @State private var savedToast = false

    public init(targetDate: Date = Date(), sittingMountain: Mountain24Item? = nil) {
        self.targetDate = targetDate
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

                VStack(spacing: 14) {
                    if let img = renderedImage {
                        ScrollView {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 6)
                                .padding(.horizontal, 24)
                                .padding(.top, 12)
                        }
                    } else {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.95, green: 0.85, blue: 0.45)))
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            guard let img = renderedImage else { return }
                            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                                guard status == .authorized || status == .limited else { return }
                                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                                DispatchQueue.main.async {
                                    savedToast = true
                                    RetentionServiceManager.shared.recordMilestone(reason: "save_daily_card")
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        savedToast = false
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text(lang.t("save_to_photos"))
                            }
                            .adaptiveFont(size: 13, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.83, green: 0.68, blue: 0.21))
                            .foregroundColor(.black)
                            .cornerRadius(10)
                        }

                        Button(action: {
                            guard renderedImage != nil else { return }
                            showShareSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text(lang.t("share_and_print"))
                            }
                            .adaptiveFont(size: 13, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.14))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                if savedToast {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                        Text(lang.t("save_success"))
                            .adaptiveFont(size: 12, weight: .bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(cardTitle)
                        .adaptiveFont(size: 15, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lang.t("done")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let img = renderedImage {
                    ActivityShareSheet(items: [img])
                }
            }
            .onAppear {
                renderedImage = Self.renderPoster(date: targetDate, state: motion.headingState)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var cardTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Daily Auspicious Sign Card"
        case .zhHant, .ja: return "今日吉方日籤 · 宣紙海報"
        case .ko: return "오늘의 길방 일첨 카드"
        case .vi: return "Thẻ Cát Phương Hôm Nay"
        case .th: return "การ์ดทิศมงคลประจำวัน"
        case .id: return "Kartu Arah Keberuntungan Harian"
        case .auto, .zhHans: return "今日吉方日签 · 宣纸海报"
        }
    }

    public static func renderPoster(date: Date, state: CompassHeadingState) -> UIImage {
        let size = CGSize(width: 750, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)
        let zeri = ZeRiEngine.shared.analyze(date: date, sitting: state.sittingMountain)
        let gods = ZeRiEngine.shared.dailyCompassDirections(for: date)
        let qimen = QimenEngine.shared.calculateChart(date: date, heading: state.facingAngle)
        let kuaMatch = UserKuaProfileManager.shared.evaluateCompatibility(sittingPalace: state.sittingMountain.palace)
        let termRaw = SolarTimeCalculator.shared.solarTermName(for: date)
        let termName = SolarTermsData.shared.terms.first(where: { $0.name == termRaw })?.localizedName ?? termRaw
        let df = DateFormatter()
        df.dateFormat = "yyyy · MM · dd"
        let dateStr = df.string(from: date)
        let effLang = LocalizationManager.shared.effectiveLanguage

        return renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // 1. 黑金渐变底色与外框
            UIColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 1.0).setFill()
            cg.fill(rect)

            let borderRect = rect.insetBy(dx: 28, dy: 28)
            cg.setStrokeColor(UIColor(red: 0.85, green: 0.70, blue: 0.30, alpha: 0.65).cgColor)
            cg.setLineWidth(2.5)
            cg.stroke(borderRect)

            let innerRect = rect.insetBy(dx: 38, dy: 38)
            cg.setStrokeColor(UIColor(red: 0.85, green: 0.70, blue: 0.30, alpha: 0.25).cgColor)
            cg.setLineWidth(1.0)
            cg.stroke(innerRect)

            let gold = UIColor(red: 0.95, green: 0.83, blue: 0.42, alpha: 1.0)
            let cyan = UIColor(red: 0.35, green: 0.85, blue: 0.80, alpha: 1.0)
            let white = UIColor.white
            let dim = UIColor.white.withAlphaComponent(0.72)

            let centerStyle = NSMutableParagraphStyle()
            centerStyle.alignment = .center

            // 2. 顶部纪年与节气
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
                .foregroundColor: gold,
                .paragraphStyle: centerStyle
            ]
            ("\(dateStr)  ·  \(termName)" as NSString).draw(in: CGRect(x: 60, y: 72, width: 630, height: 34), withAttributes: headerAttrs)

            // 3. 日柱大字
            let pillarAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 78),
                .foregroundColor: gold,
                .paragraphStyle: centerStyle
            ]
            (zeri.localizedDayPillar as NSString).draw(in: CGRect(x: 60, y: 125, width: 630, height: 96), withAttributes: pillarAttrs)

            let fourPillarAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .medium),
                .foregroundColor: dim,
                .paragraphStyle: centerStyle
            ]
            (zeri.fourPillarsText as NSString).draw(in: CGRect(x: 60, y: 232, width: 630, height: 32), withAttributes: fourPillarAttrs)

            // 4. 今日财神 / 喜神 / 奇门动身吉方 / 宅主本命卦卡片
            let cardRect = CGRect(x: 64, y: 288, width: 622, height: 342)
            UIColor(red: 0.13, green: 0.13, blue: 0.17, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: cardRect, cornerRadius: 16).fill()

            let leftStyle = NSMutableParagraphStyle()
            leftStyle.alignment = .left
            leftStyle.lineSpacing = 7

            let sectionTitle: String
            let wealthLine: String
            let joyLine: String
            let qimenLine: String
            let sittingLine: String
            let kuaLine: String
            let yiLabel: String
            let jiLabel: String
            let footer: String

            switch effLang {
            case .en:
                sectionTitle = "✦ TODAY'S AUSPICIOUS COMPASS GUIDE"
                wealthLine = "💰 God of Wealth: \(gods.wealthDirection) (\(Int(gods.wealthAngle))°)"
                joyLine = "🎉 God of Joy: \(gods.joyDirection) (\(Int(gods.joyAngle))°)"
                qimenLine = "🧭 Qimen Best Gate: \(qimen.bestNavDirection)"
                sittingLine = "🏠 House Sitting: \(state.sittingMountain.localizedName) → \(state.facingMountain.localizedName) (\(String(format: "%.1f°", state.facingAngle)))"
                kuaLine = "👤 Owner Gua: \(kuaMatch.localizedOwnerGuaName) · Wealth \(kuaMatch.wealthDirection)"
                yiLabel = "GOOD FOR: "
                jiLabel = "AVOID: "
                footer = "TIANDI LUOPAN · CLASSICAL FENGSHUI & COMPASS"
            case .zhHant:
                sectionTitle = "✦ 今日出行納吉方位導引"
                wealthLine = "💰 今日財神正位：【\(gods.wealthDirection)】 (羅盤 \(Int(gods.wealthAngle))°)"
                joyLine = "🎉 今日喜神吉位：【\(gods.joyDirection)】 (羅盤 \(Int(gods.joyAngle))°)"
                qimenLine = "🧭 時家奇門吉門：【\(qimen.bestNavDirection)】"
                sittingLine = "🏠 當前立極坐向：\(state.sittingMountain.localizedName)山\(state.facingMountain.localizedName)向 (\(String(format: "%.1f°", state.facingAngle)))"
                kuaLine = "👤 宅主本命配卦：\(kuaMatch.localizedOwnerGuaName)（\(kuaMatch.matchBadgeTitle)）· 生氣【\(kuaMatch.wealthDirection)】"
                yiLabel = "【今日宜】 "
                jiLabel = "【今日忌】 "
                footer = "天地羅盤 · 三元玄空與三式絕學專業堪輿羅經"
            case .ja:
                sectionTitle = "✦ 本日の出行納吉方位ガイド"
                wealthLine = "💰 本日の財神方位：【\(gods.wealthDirection)】 (羅盤 \(Int(gods.wealthAngle))°)"
                joyLine = "🎉 本日の喜神方位：【\(gods.joyDirection)】 (羅盤 \(Int(gods.joyAngle))°)"
                qimenLine = "🧭 時家奇門吉門：【\(qimen.bestNavDirection)】"
                sittingLine = "🏠 現在の立極坐向：\(state.sittingMountain.localizedName)山\(state.facingMountain.localizedName)向 (\(String(format: "%.1f°", state.facingAngle)))"
                kuaLine = "👤 家主本命卦：\(kuaMatch.localizedOwnerGuaName)（\(kuaMatch.matchBadgeTitle)）・生気【\(kuaMatch.wealthDirection)】"
                yiLabel = "【本日の宜】 "
                jiLabel = "【本日の忌】 "
                footer = "天地羅盤・三元玄空＆三式風水プロフェッショナル羅経"
            case .ko:
                sectionTitle = "✦ 오늘의 출행 납길 방위 가이드"
                wealthLine = "💰 오늘의 재신 방위: 【\(gods.wealthDirection)】 (나경 \(Int(gods.wealthAngle))°)"
                joyLine = "🎉 오늘의 희신 방위: 【\(gods.joyDirection)】 (나경 \(Int(gods.joyAngle))°)"
                qimenLine = "🧭 시가기문 길문: 【\(qimen.bestNavDirection)】"
                sittingLine = "🏠 현재 입극 좌향: \(state.sittingMountain.localizedName)산 \(state.facingMountain.localizedName)향 (\(String(format: "%.1f°", state.facingAngle)))"
                kuaLine = "👤 택주 본명괘: \(kuaMatch.localizedOwnerGuaName) (\(kuaMatch.matchBadgeTitle)) · 생기【\(kuaMatch.wealthDirection)】"
                yiLabel = "【오늘의 의(宜)】 "
                jiLabel = "【오늘의 기(忌)】 "
                footer = "천지나경 · 삼원현공 및 삼식 풍수 전문 나경"
            case .vi:
                sectionTitle = "✦ HƯỚNG DẪN PHƯƠNG VỊ ĐÓN CÁT HÔM NAY"
                wealthLine = "💰 Hướng Thần Tài: 【\(gods.wealthDirection)】 (La bàn \(Int(gods.wealthAngle))°)"
                joyLine = "🎉 Hướng Hỷ Thần: 【\(gods.joyDirection)】 (La bàn \(Int(gods.joyAngle))°)"
                qimenLine = "🧭 Cát Môn Kỳ Môn: 【\(qimen.bestNavDirection)】"
                sittingLine = "🏠 Tọa Hướng Lập Cực: Tọa \(state.sittingMountain.localizedName) Hướng \(state.facingMountain.localizedName) (\(String(format: "%.1f°", state.facingAngle)))"
                kuaLine = "👤 Bản Mệnh Gia Chủ: \(kuaMatch.localizedOwnerGuaName) · Sinh Khí 【\(kuaMatch.wealthDirection)】"
                yiLabel = "【NÊN LÀM】 "
                jiLabel = "【KIÊNG KỴ】 "
                footer = "THIÊN ĐỊA LA BÀN · LA KINH PHONG THỦY TAM NGUYÊN HUYỀN KHÔNG"
            case .th:
                sectionTitle = "✦ เข็มทิศนำทางรับโชคมงคลวันนี้"
                wealthLine = "💰 ทิศเทพเจ้าโชคลาภ: 【\(gods.wealthDirection)】 (\(Int(gods.wealthAngle))°)"
                joyLine = "🎉 ทิศเทพแห่งความยินดี: 【\(gods.joyDirection)】 (\(Int(gods.joyAngle))°)"
                qimenLine = "🧭 ประตูมงคลฉีเหมิน: 【\(qimen.bestNavDirection)】"
                sittingLine = "🏠 ทิศบ้านปัจจุบัน: หลังพิง\(state.sittingMountain.localizedName) หันหน้า\(state.facingMountain.localizedName) (\(String(format: "%.1f°", state.facingAngle)))"
                kuaLine = "👤 ดวงเจ้าของบ้าน: \(kuaMatch.localizedOwnerGuaName) · ทิศโชคลาภ【\(kuaMatch.wealthDirection)】"
                yiLabel = "【สิ่งที่ควรทำ】 "
                jiLabel = "【สิ่งที่ควรเลี่ยง】 "
                footer = "เทียนตี้หลัวผาน · เข็มทิศฮวงจุ้ยซานหยวนเสวียนคงระดับมืออาชีพ"
            case .id:
                sectionTitle = "✦ PANDUAN ARAH KEBERUNTUNGAN HARI INI"
                wealthLine = "💰 Arah Dewa Rezeki: 【\(gods.wealthDirection)】 (\(Int(gods.wealthAngle))°)"
                joyLine = "🎉 Arah Dewa Kebahagiaan: 【\(gods.joyDirection)】 (\(Int(gods.joyAngle))°)"
                qimenLine = "🧭 Gerbang Baik Qimen: 【\(qimen.bestNavDirection)】"
                sittingLine = "🏠 Arah Rumah: Duduk \(state.sittingMountain.localizedName) Hadap \(state.facingMountain.localizedName) (\(String(format: "%.1f°", state.facingAngle)))"
                kuaLine = "👤 Gua Pemilik: \(kuaMatch.localizedOwnerGuaName) · Rezeki 【\(kuaMatch.wealthDirection)】"
                yiLabel = "BAIK UNTUK: "
                jiLabel = "HINDARI: "
                footer = "TIANDI LUOPAN · KOMPAS FENG SHUI KLASIK PROFESIONAL"
            case .auto, .zhHans:
                sectionTitle = "✦ 今日出行纳吉方位导引"
                wealthLine = "💰 今日财神正位：【\(gods.wealthDirection)】 (罗盘 \(Int(gods.wealthAngle))°)"
                joyLine = "🎉 今日喜神吉位：【\(gods.joyDirection)】 (罗盘 \(Int(gods.joyAngle))°)"
                qimenLine = "🧭 时家奇门吉门：【\(qimen.bestNavDirection)】"
                sittingLine = "🏠 当前立极坐向：\(state.sittingMountain.localizedName)山\(state.facingMountain.localizedName)向 (\(String(format: "%.1f°", state.facingAngle)))"
                kuaLine = "👤 宅主本命配卦：\(kuaMatch.localizedOwnerGuaName)（\(kuaMatch.matchBadgeTitle)）· 生气【\(kuaMatch.wealthDirection)】"
                yiLabel = "【今日宜】 "
                jiLabel = "【今日忌】 "
                footer = "天地罗盘 · 三元玄空与三式绝学专业堪舆罗经"
            }

            (sectionTitle as NSString).draw(
                in: CGRect(x: 92, y: 312, width: 566, height: 32),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 22), .foregroundColor: cyan]
            )

            let bodyText = [wealthLine, joyLine, qimenLine, sittingLine, kuaLine].joined(separator: "\n")
            (bodyText as NSString).draw(
                in: CGRect(x: 92, y: 356, width: 566, height: 262),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 21, weight: .semibold),
                    .foregroundColor: white,
                    .paragraphStyle: leftStyle
                ]
            )

            // 5. 今日宜忌卡片
            let yijiRect = CGRect(x: 64, y: 650, width: 622, height: 240)
            UIColor(red: 0.13, green: 0.12, blue: 0.14, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: yijiRect, cornerRadius: 16).fill()

            let yiStr = yiLabel + zeri.yiActivities.joined(separator: " · ")
            let jiStr = jiLabel + zeri.jiActivities.joined(separator: " · ")

            (zeri.overallStatus as NSString).draw(
                in: CGRect(x: 92, y: 676, width: 566, height: 32),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 24),
                    .foregroundColor: zeri.isAuspicious ? UIColor.systemGreen : UIColor.systemOrange
                ]
            )
            (yiStr as NSString).draw(
                in: CGRect(x: 92, y: 726, width: 566, height: 64),
                withAttributes: [.font: UIFont.systemFont(ofSize: 21, weight: .medium), .foregroundColor: gold]
            )
            (jiStr as NSString).draw(
                in: CGRect(x: 92, y: 798, width: 566, height: 64),
                withAttributes: [.font: UIFont.systemFont(ofSize: 20, weight: .regular), .foregroundColor: dim]
            )

            // 6. 底部品牌落款
            (footer as NSString).draw(
                in: CGRect(x: 60, y: 955, width: 630, height: 40),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 19, weight: .bold),
                    .foregroundColor: gold.withAlphaComponent(0.85),
                    .paragraphStyle: centerStyle
                ]
            )
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - P2.3 首次启动三步新手引导 (OnboardingGuideSheet)

public struct OnboardingGuideSheet: View {
    private static let kCompletedKey = "tiandi_onboarding_v1_completed"
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var kua = UserKuaProfileManager.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var step: Int = 0

    public init() {}

    public static func shouldPresentOnLaunch() -> Bool {
        if RetentionServiceManager.isRunningAutomatedTests { return false }
        return !UserDefaults.standard.bool(forKey: kCompletedKey)
    }

    public static func markCompleted() {
        UserDefaults.standard.set(true, forKey: kCompletedKey)
    }

    public var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Text("✦ \(headerTitle)")
                        .adaptiveFont(size: 16, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Spacer()
                    Button(action: finish) {
                        Text(skipTitle)
                            .adaptiveFont(size: 13, weight: .medium)
                            .foregroundColor(.white.opacity(0.65))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                // 步骤指示条
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { idx in
                        Capsule()
                            .fill(idx <= step ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.15))
                            .frame(height: 5)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 8)

                if step == 0 {
                    stepView(
                        icon: "safari.fill",
                        title: step1Title,
                        subtitle: step1Desc,
                        bullets: step1Bullets
                    )
                } else if step == 1 {
                    VStack(spacing: 16) {
                        stepView(
                            icon: "person.text.rectangle.fill",
                            title: step2Title,
                            subtitle: step2Desc,
                            bullets: step2Bullets
                        )

                        // 直接在引导第 2 步完成宅主生辰录入
                        VStack(spacing: 10) {
                            HStack {
                                Text(birthYearLabel)
                                    .adaptiveFont(size: 13, weight: .semibold)
                                    .foregroundColor(.white)
                                Spacer()
                                Picker("", selection: $kua.birthYear) {
                                    ForEach(1940...2025, id: \.self) { yr in
                                        Text("\(String(yr))").tag(yr)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(Color(red: 0.95, green: 0.85, blue: 0.45))

                                Picker("", selection: $kua.isMale) {
                                    Text(maleLabel).tag(true)
                                    Text(femaleLabel).tag(false)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                            }
                            let compat = kua.evaluateCompatibility(sittingPalace: "坎")
                            HStack {
                                Text("🌟 \(compat.localizedOwnerGuaName) · \(compat.localizedLifeGroup) (\(compat.localizedZodiacName))")
                                    .adaptiveFont(size: 12, weight: .bold)
                                    .foregroundColor(Color.yanCyan)
                                Spacer()
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                    }
                } else {
                    stepView(
                        icon: "house.fill",
                        title: step3Title,
                        subtitle: step3Desc,
                        bullets: step3Bullets
                    )
                }

                Spacer(minLength: 8)

                Button(action: {
                    if step < 2 {
                        withAnimation { step += 1 }
                    } else {
                        finish()
                    }
                }) {
                    Text(step < 2 ? nextButtonTitle : startButtonTitle)
                        .adaptiveFont(size: 15, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.82, blue: 0.38), Color(red: 0.78, green: 0.58, blue: 0.20)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.black)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func finish() {
        Self.markCompleted()
        presentationMode.wrappedValue.dismiss()
    }

    private func stepView(icon: String, title: String, subtitle: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(title)
                    .adaptiveFont(size: 20, weight: .bold)
                    .foregroundColor(.white)
            }

            Text(subtitle)
                .adaptiveFont(size: 13)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(bullets, id: \.self) { b in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            .font(.system(size: 14))
                        Text(b)
                            .adaptiveFont(size: 13)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .padding(.horizontal, 24)
    }

    private var headerTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Quick Start Guide (3 Steps)"
        case .zhHant: return "三步快速上手指南"
        case .ja: return "3ステップ・クイックガイド"
        case .ko: return "3단계 빠른 시작 가이드"
        case .vi: return "Hướng Dẫn Nhanh 3 Bước"
        case .th: return "คู่มือเริ่มต้นใช้งาน 3 ขั้นตอน"
        case .id: return "Panduan Cepat 3 Langkah"
        case .auto, .zhHans: return "三步快速上手指南"
        }
    }
    private var skipTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Skip"
        case .zhHant: return "跳過"
        case .ja: return "スキップ"
        case .ko: return "건너뛰기"
        case .vi: return "Bỏ qua"
        case .th: return "ข้าม"
        case .id: return "Lewati"
        case .auto, .zhHans: return "跳过"
        }
    }
    private var step1Title: String {
        switch lang.effectiveLanguage {
        case .en: return "1. Stand at Center & Lock Heading"
        case .zhHant: return "第一步：客廳中心立極與鎖盤"
        case .ja: return "ステップ1：家の中心で立極＆方位固定"
        case .ko: return "1단계: 거실 중심 입극 및 좌향 잠금"
        case .vi: return "Bước 1: Lập Cực Tại Tâm Nhà & Khóa Hướng"
        case .th: return "ขั้นตอนที่ 1: ยืนกลางบ้านและล็อกทิศ"
        case .id: return "Langkah 1: Berdiri di Tengah & Kunci Arah"
        case .auto, .zhHans: return "第一步：客厅中心立极与锁盘"
        }
    }
    private var step1Desc: String {
        switch lang.effectiveLanguage {
        case .en: return "Hold your phone flat at the center of your living room, facing the main door or largest balcony window:"
        case .zhHant: return "站在房屋客廳中心，手持手機端平（使中央水泡居中），面朝入戶大門或主陽台採光面："
        case .ja: return "リビングの中央に立ち、スマホを水平に保ちながら玄関またはメインバルコニーに向きます："
        case .ko: return "거실 중앙에 서서 스마트폰을 수평으로 들고 현관문이나 주 발코니를 바라보세요:"
        case .vi: return "Đứng ở tâm phòng khách, giữ điện thoại phẳng (bọt nước ở giữa), hướng về cửa chính hoặc ban công lớn:"
        case .th: return "ยืนที่กึ่งกลางห้องนั่งเล่น ถือโทรศัพท์ให้ขนานกับพื้น หันหน้าไปทางประตูหลักหรือระเบียงรับแสง:"
        case .id: return "Berdiri di tengah ruang tamu, pegang ponsel rata menghadap pintu utama atau balkon utama:"
        case .auto, .zhHans: return "站在房屋客厅中心，手持手机端平（使中央水泡居中），面朝入户大门或主阳台采光面："
        }
    }
    private var step1Bullets: [String] {
        switch lang.effectiveLanguage {
        case .en:
            return [
                "Tap [Lock Heading] to freeze your house's sitting/facing direction across all tabs.",
                "Or pick any of the 24 Mountains manually on the Analysis tab without rotating your phone.",
                "Enable [God of Wealth Guide] on the compass to see today's lucky travel bearings."
            ]
        case .zhHant:
            return [
                "點擊【鎖定朝向】，坐向度數將跨頁面持久保存並同步至桌面小組件。",
                "不在現場時，可在「理氣」頁頂部直接手選【二十四山】靜態排盤。",
                "開啟羅盤【吉方導引】，一鍵標出今日財神、喜神與奇門吉門方位。"
            ]
        case .ja:
            return [
                "【方位固定】をタップすると、坐向が全タブおよびホーム画面ウィジェットに同期されます。",
                "現地にいない場合でも、「理気」タブ上部から【二十四山】を手動選択して静的排盤が可能です。",
                "羅盤の【吉方ガイド】をONにすると、本日の財神・喜神方位が盤面上に光って表示されます。"
            ]
        case .ko:
            return [
                "【방향 잠금】을 누르면 좌향 각도가 모든 탭과 홈 화면 위젯에 동기화됩니다.",
                "현장이 아닐 때는 '이기' 탭 상단에서 【24산】을 직접 선택해 정적 배반할 수 있습니다.",
                "나경의 【길방 가이드】를 켜면 오늘의 재신·희신 방위가 반면에 표시됩니다."
            ]
        case .vi:
            return [
                "Nhấn [Khóa Hướng] để lưu tọa hướng xuyên suốt các tab và đồng bộ với Widget màn hình chính.",
                "Khi không ở hiện trường, có thể chọn thủ công [24 Sơn] ngay đầu tab Lý Khí.",
                "Bật [Chỉ Dẫn Cát Phương] trên la bàn để hiển thị hướng Thần Tài và Hỷ Thần hôm nay."
            ]
        case .th:
            return [
                "แตะ [ล็อกทิศ] เพื่อบันทึกองศาหลังพิง-หันหน้าข้ามทุกแท็บและซิงค์กับวิดเจ็ตหน้าจอโฮม",
                "หากไม่อยู่หน้างาน สามารถเลือก [24 ขุนเขา] ด้วยตนเองที่ด้านบนของแท็บวิเคราะห์",
                "เปิด [นำทางทิศมงคล] บนเข็มทิศเพื่อแสดงตำแหน่งเทพโชคลาภและเทพแห่งความยินดีบนหน้าปัด"
            ]
        case .id:
            return [
                "Ketuk [Kunci Arah] untuk menyimpan arah duduk/hadap di semua tab dan menyinkronkan ke Widget.",
                "Pilih [24 Gunung] secara manual di bagian atas tab Analisis saat tidak berada di lokasi.",
                "Aktifkan [Panduan Arah Baik] di kompas untuk menampilkan penanda Dewa Rezeki & Kebahagiaan."
            ]
        case .auto, .zhHans:
            return [
                "点击【锁定朝向】，坐向度数将跨页面持久保存并同步至桌面小组件。",
                "不在现场时，可在“理气”页顶部直接手选【二十四山】静态排盘。",
                "开启罗盘【吉方导引】，一键标出今日财神、喜神与奇门吉门方位。"
            ]
        }
    }
    private var step2Title: String {
        switch lang.effectiveLanguage {
        case .en: return "2. Set Owner Birth Year (Life Gua)"
        case .zhHant: return "第二步：設定宅主生辰（人宅合一）"
        case .ja: return "ステップ2：家主の生年設定（人宅合一）"
        case .ko: return "2단계: 택주 생년 설정 (인택합일)"
        case .vi: return "Bước 2: Cài Đặt Năm Sinh Gia Chủ (Nhân Trạch Hợp Nhất)"
        case .th: return "ขั้นตอนที่ 2: ตั้งค่าปีเกิดเจ้าของบ้าน (คนสมพงศ์บ้าน)"
        case .id: return "Langkah 2: Atur Tahun Lahir Pemilik (Harmoni Gua)"
        case .auto, .zhHans: return "第二步：设定宅主生辰（人宅合一）"
        }
    }
    private var step2Desc: String {
        switch lang.effectiveLanguage {
        case .en: return "Enter the homeowner's birth year & gender to compute your Personal Life Gua, Wealth/Study spots, and Zodiac clash-free dates:"
        case .zhHant: return "八宅風水講究「宅命相配」。設定出生年份後，系統將自動推算您的本命卦、個人財位/文昌位，並在擇日時避開衝生肖之日："
        case .ja: return "八宅風水では「宅命相配」を重視します。生年を設定すると本命卦・個人の財位/文昌位を算出し、択日で干支冲を自動回避します："
        case .ko: return "팔택풍수는 '택명상배'를 중시합니다. 출생연도를 설정하면 본명괘와 개인 재물/문창방을 계산하고 택일 시 띠 충을 피합니다:"
        case .vi: return "Bát Trạch chú trọng 'Trạch Mệnh Tương Phối'. Nhập năm sinh để tính Bản Mệnh Quái, Tài vị/Văn Xương và lọc ngày không xung tuổi:"
        case .th: return "ฮวงจุ้ยแปดทิศเน้นความสมพงศ์ระหว่างคนกับบ้าน ตั้งปีเกิดเพื่อคำนวณรหัสประจำตัว ทิศโชคลาภ และคัดกรองวันมงคลไม่ชงปีเกิด:"
        case .id: return "Masukkan tahun lahir & jenis kelamin pemilik untuk menghitung Gua Pribadi, titik Rezeki/Studi, dan hari baik bebas bentrokan Shio:"
        case .auto, .zhHans: return "八宅风水讲究“宅命相配”。设定出生年份后，系统将自动推算您的本命卦、个人财位/文昌位，并在择日时避开冲生肖之日："
        }
    }
    private var step2Bullets: [String] {
        switch lang.effectiveLanguage {
        case .en:
            return [
                "Instant East/West 4 Life matching with your house's sitting palace.",
                "30-Day Auspicious Calendar for moving, renovation, and business opening."
            ]
        case .zhHant:
            return [
                "自動判定「東四命/西四命」是否與本宅坐山相配，給出安床與書桌朝向方案。",
                "支持「未來30天黃道吉日速查」與時辰穿越撥盤，可一鍵開啟早晨吉日提醒。"
            ]
        case .ja:
            return [
                "「東四命／西四命」と家屋の坐山との相性を自動判定し、ベッドや机の最適方位を提案します。",
                "「今後30日間の吉日一覧」と日時トラベル機能を備え、当日の朝リマインダーも設定可能です。"
            ]
        case .ko:
            return [
                "'동사명/서사명'과 주택 좌산의 조화를 자동 판정하여 침대 및 책상 배치 방안을 제시합니다.",
                "'향후 30일 황도길일 속람'과 시간 탐색 다이얼 및 당일 아침 알림을 지원합니다."
            ]
        case .vi:
            return [
                "Tự động đối chiếu 'Đông Tứ Mệnh / Tây Tứ Mệnh' với tọa sơn của nhà, gợi ý hướng kê giường và bàn làm việc.",
                "Hỗ trợ 'Tra cứu ngày tốt 30 ngày tới', xoay thời gian và bật nhắc nhở buổi sáng."
            ]
        case .th:
            return [
                "ตรวจสอบกลุ่มดวงตะวันออก/ตะวันตกกับทิศบ้านโดยอัตโนมัติ พร้อมแนะนำทิศหัวนอนและโต๊ะทำงาน",
                "รองรับปฏิทินฤกษ์มงคล 30 วันข้างหน้า การย้อน/ข้ามเวลา และการตั้งเตือนเช้าวันมงคล"
            ]
        case .id:
            return [
                "Pencocokan otomatis Empat Timur/Barat dengan arah duduk rumah, lengkap dengan saran arah ranjang & meja.",
                "Kalender Hari Baik 30 Hari ke depan dengan pengingat pagi otomatis."
            ]
        case .auto, .zhHans:
            return [
                "自动判定“东四命/西四命”是否与本宅坐山相配，给出安床与书桌朝向方案。",
                "支持“未来30天黄道吉日速查”与时辰穿越拨盘，可一键开启早晨吉日提醒。"
            ]
        }
    }
    private var step3Title: String {
        switch lang.effectiveLanguage {
        case .en: return "3. Multi-Case Floorplan & AR Survey"
        case .zhHant: return "第三步：多套戶型檔案與 AR 實景勘測"
        case .ja: return "ステップ3：複数物件の宅譜管理＆AR実景測量"
        case .ko: return "3단계: 다주택 평면도 보관함 및 AR 실경 측정"
        case .vi: return "Bước 3: Kho Hồ Sơ Đa Căn Hộ & Khảo Sát AR"
        case .th: return "ขั้นตอนที่ 3: คลังผังบ้านหลายหลังและสแกน AR"
        case .id: return "Langkah 3: Arsip Multi-Properti & Survei AR"
        case .auto, .zhHans: return "第三步：多套户型档案与 AR 实景勘测"
        }
    }
    private var step3Desc: String {
        switch lang.effectiveLanguage {
        case .en: return "Import floorplans or scan with 3D RoomPlan, and save multiple property cases to compare anytime:"
        case .zhHant: return "導入戶型圖或使用 RoomPlan 3D 掃描全屋，建立您的專屬「宅譜檔案夾」："
        case .ja: return "間取り図の読込やRoomPlan 3Dスキャンで、複数物件の「宅譜アーカイブ」を構築できます："
        case .ko: return "평면도를 불러오거나 RoomPlan 3D 스캔을 사용하여 나만의 '택보 보관함'을 구축하세요:"
        case .vi: return "Nhập sơ đồ mặt bằng hoặc quét 3D RoomPlan, lưu trữ nhiều hồ sơ căn hộ để so sánh bất cứ lúc nào:"
        case .th: return "นำเข้าผังบ้านหรือสแกน 3D RoomPlan พร้อมบันทึกแฟ้มบ้านหลายหลังเพื่อสลับเปรียบเทียบได้ตลอดเวลา:"
        case .id: return "Impor denah atau pindai 3D RoomPlan, dan simpan beberapa arsip properti untuk dibandingkan kapan saja:"
        case .auto, .zhHans: return "导入户型图或使用 RoomPlan 3D 扫描全屋，建立您的专属“宅谱档案夹”："
        }
    }
    private var step3Bullets: [String] {
        switch lang.effectiveLanguage {
        case .en:
            return [
                "Save & switch between multiple properties (Home, Office, Client Cases).",
                "Diagnose bathroom/kitchen placement (Fire at Heaven's Gate) in plain language."
            ]
        case .zhHant:
            return [
                "支持保存多套看房/客戶戶型檔案，隨時切換對比，單次解鎖憑證獨立隨檔案永久保留。",
                "每個宮位均提供「白話吉凶速斷」與古籍斷語雙重視角，新手老手皆宜。"
            ]
        case .ja:
            return [
                "自宅・オフィス・内見物件など複数の間取りを保存して比較でき、単回アンロック権限も各物件に永続保持されます。",
                "すべての宮位に「わかりやすい現代語解説」と「古典断語」の両方を収録しています。"
            ]
        case .ko:
            return [
                "자택, 사무실, 매물 등 여러 평면도를 저장 및 전환할 수 있으며 단건 잠금해제 권한도 영구 보존됩니다.",
                "모든 궁위에 '쉬운 현대어 해설'과 '고전 단언'을 함께 제공하여 초보자와 전문가 모두에게 적합합니다."
            ]
        case .vi:
            return [
                "Lưu và chuyển đổi giữa nhiều căn hộ (Nhà ở, Văn phòng, Khách hàng), giữ nguyên quyền mở khóa cho từng hồ sơ.",
                "Mỗi cung vị đều có cả 'Luận giải dễ hiểu' lẫn 'Đoán ngữ cổ tịch', phù hợp cho cả người mới và chuyên gia."
            ]
        case .th:
            return [
                "บันทึกและสลับดูผังบ้านหลายหลัง (บ้าน ออฟฟิศ หรือบ้านลูกค้า) โดยสิทธิ์ปลดล็อกจะถูกเก็บไว้กับแต่ละแฟ้มอย่างถาวร",
                "ทุกวังมีทั้งคำอธิบายภาษาเข้าใจง่ายและคัมภีร์โบราณ เหมาะสำหรับทั้งมือใหม่และซินแสมืออาชีพ"
            ]
        case .id:
            return [
                "Simpan & beralih antar beberapa properti (Rumah, Kantor, Klien) dengan bukti buka kunci yang tersimpan permanen.",
                "Setiap istana dilengkapi ringkasan bahasa sehari-hari yang mudah dipahami serta teks klasik."
            ]
        case .auto, .zhHans:
            return [
                "支持保存多套看房/客户户型档案，随时切换对比，单次解锁凭证独立随档案永久保留。",
                "每个宫位均提供“白话吉凶速断”与古籍断语双重视角，新手老手皆宜。"
            ]
        }
    }
    private var birthYearLabel: String {
        switch lang.effectiveLanguage {
        case .en: return "Owner Birth Year:"
        case .zhHant: return "宅主出生年份："
        case .ja: return "家主の生年："
        case .ko: return "택주 출생연도:"
        case .vi: return "Năm sinh gia chủ:"
        case .th: return "ปีเกิดเจ้าของบ้าน:"
        case .id: return "Tahun Lahir Pemilik:"
        case .auto, .zhHans: return "宅主出生年份："
        }
    }
    private var maleLabel: String {
        switch lang.effectiveLanguage {
        case .en: return "Male"
        case .ko: return "남"
        case .vi: return "Nam"
        case .th: return "ชาย"
        case .id: return "Pria"
        case .auto, .zhHans, .zhHant, .ja: return "男"
        }
    }
    private var femaleLabel: String {
        switch lang.effectiveLanguage {
        case .en: return "Female"
        case .ko: return "여"
        case .vi: return "Nữ"
        case .th: return "หญิง"
        case .id: return "Wanita"
        case .auto, .zhHans, .zhHant, .ja: return "女"
        }
    }
    private var nextButtonTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Next Step"
        case .zhHant: return "下一步"
        case .ja: return "次へ"
        case .ko: return "다음 단계"
        case .vi: return "Bước tiếp"
        case .th: return "ถัดไป"
        case .id: return "Berikutnya"
        case .auto, .zhHans: return "下一步"
        }
    }
    private var startButtonTitle: String {
        switch lang.effectiveLanguage {
        case .en: return "Start Using Tiandi Luopan"
        case .zhHant: return "立即開啟天地羅盤"
        case .ja: return "天地羅盤をはじめる"
        case .ko: return "천지나경 시작하기"
        case .vi: return "Bắt Đầu Sử Dụng Thiên Địa La Bàn"
        case .th: return "เริ่มต้นใช้งานเทียนตี้หลัวผาน"
        case .id: return "Mulai Gunakan Tiandi Luopan"
        case .auto, .zhHans: return "立即开启天地罗盘"
        }
    }
}
