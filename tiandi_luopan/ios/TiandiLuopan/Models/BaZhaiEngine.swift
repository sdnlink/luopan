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
