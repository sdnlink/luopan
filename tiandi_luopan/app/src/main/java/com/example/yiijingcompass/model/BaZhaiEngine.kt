package com.example.yiijingcompass.model

/**
 * 八宅风水吉凶模组 (BaZhai Engine)
 */
enum class StarLuckType(val rawValue: String) {
    SHENG_QI("生气 (贪狼大吉)"),
    YAN_NIAN("延年 (武曲大吉)"),
    TIAN_YI("天医 (巨门中吉)"),
    FU_WEI("伏位 (辅弼小吉)"),
    JUE_MING("绝命 (破军大凶)"),
    WU_GUI("五鬼 (廉贞大凶)"),
    LIU_SHA("六煞 (文曲中凶)"),
    HUO_HAI("祸害 (禄存小凶)");

    val isAuspicious: Boolean
        get() = this == SHENG_QI || this == YAN_NIAN || this == TIAN_YI || this == FU_WEI

    val starName: String
        get() = when (this) {
            SHENG_QI -> "生气"
            YAN_NIAN -> "延年"
            TIAN_YI -> "天医"
            FU_WEI -> "伏位"
            JUE_MING -> "绝命"
            WU_GUI -> "五鬼"
            LIU_SHA -> "六煞"
            HUO_HAI -> "祸害"
        }

    val localizedName: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> when (this) {
                    SHENG_QI -> "Sheng Qi (Vitality - Great Luck)"
                    YAN_NIAN -> "Yan Nian (Longevity - Great Luck)"
                    TIAN_YI -> "Tian Yi (Heavenly Doctor - Medium Luck)"
                    FU_WEI -> "Fu Wei (Stability - Minor Luck)"
                    JUE_MING -> "Jue Ming (Calamity - Major Taboo)"
                    WU_GUI -> "Wu Gui (Five Ghosts - Major Taboo)"
                    LIU_SHA -> "Liu Sha (Six Killings - Medium Taboo)"
                    HUO_HAI -> "Huo Hai (Mishap - Minor Taboo)"
                }
                AppLanguage.ZH_HANT -> when (this) {
                    SHENG_QI -> "生氣 (貪狼大吉)"
                    YAN_NIAN -> "延年 (武曲大吉)"
                    TIAN_YI -> "天醫 (巨門中吉)"
                    FU_WEI -> "伏位 (輔弼小吉)"
                    JUE_MING -> "絕命 (破軍大凶)"
                    WU_GUI -> "五鬼 (廉貞大凶)"
                    LIU_SHA -> "六煞 (文曲中凶)"
                    HUO_HAI -> "禍害 (祿存小凶)"
                }
                AppLanguage.JA -> when (this) {
                    SHENG_QI -> "生気 (貪狼大吉)"
                    YAN_NIAN -> "延年 (武曲大吉)"
                    TIAN_YI -> "天医 (巨門中吉)"
                    FU_WEI -> "伏位 (輔弼小吉)"
                    JUE_MING -> "絶命 (破軍大凶)"
                    WU_GUI -> "五鬼 (廉貞大凶)"
                    LIU_SHA -> "六殺 (文曲中凶)"
                    HUO_HAI -> "禍害 (禄存小凶)"
                }
                AppLanguage.KO -> when (this) {
                    SHENG_QI -> "생기 (탐랑대길)"
                    YAN_NIAN -> "연년 (무곡대길)"
                    TIAN_YI -> "천의 (거문중길)"
                    FU_WEI -> "복위 (보필소길)"
                    JUE_MING -> "절명 (파군대흉)"
                    WU_GUI -> "오귀 (염정대흉)"
                    LIU_SHA -> "육살 (문곡중흉)"
                    HUO_HAI -> "화해 (녹존소흉)"
                }
                AppLanguage.VI -> when (this) {
                    SHENG_QI -> "Sinh Khí (Tham Lang Đại Cát)"
                    YAN_NIAN -> "Diên Niên (Vũ Khúc Đại Cát)"
                    TIAN_YI -> "Thiên Y (Cự Môn Trung Cát)"
                    FU_WEI -> "Phục Vị (Phụ Bật Tiểu Cát)"
                    JUE_MING -> "Tuyệt Mệnh (Phá Quân Đại Hung)"
                    WU_GUI -> "Ngũ Quỷ (Liêm Trinh Đại Hung)"
                    LIU_SHA -> "Lục Sát (Văn Khúc Trung Hung)"
                    HUO_HAI -> "Họa Hại (Lộc Tồn Tiểu Hung)"
                }
                AppLanguage.TH -> when (this) {
                    SHENG_QI -> "เซิงชี่ (มหาลาภมหาโชค)"
                    YAN_NIAN -> "เหยียนเหนียน (อายุยืนสุขสมบูรณ์)"
                    TIAN_YI -> "เทียนอี (หมอสวรรค์ปัดเป่าโรค)"
                    FU_WEI -> "ฝูเว่ย (มั่นคงสงบร่มเย็น)"
                    JUE_MING -> "เจวี๋ยหมิง (อันตรายดับสูญ)"
                    WU_GUI -> "อู่กุ่ย (ห้าผีวิบัติภัย)"
                    LIU_SHA -> "ลิ่วชา (หกสังหาร อัปมงคลกลาง)"
                    HUO_HAI -> "ฮั่วไห่ (เภทภัย อัปมงคลน้อย)"
                }
                AppLanguage.ID -> when (this) {
                    SHENG_QI -> "Sheng Qi (Vitalitas - Sangat Baik)"
                    YAN_NIAN -> "Yan Nian (Umur Panjang - Sangat Baik)"
                    TIAN_YI -> "Tian Yi (Tabib Langit - Cukup Baik)"
                    FU_WEI -> "Fu Wei (Kestabilan - Sedikit Baik)"
                    JUE_MING -> "Jue Ming (Bencana - Sangat Buruk)"
                    WU_GUI -> "Wu Gui (Lima Hantu - Sangat Buruk)"
                    LIU_SHA -> "Liu Sha (Enam Petaka - Cukup Buruk)"
                    HUO_HAI -> "Huo Hai (Malapetaka - Sedikit Buruk)"
                }
                else -> rawValue
            }
        }

    val actionSuggestion: String
        get() = localizedSuggestion

    val localizedSuggestion: String
        get() = baseLocalizedSuggestion + "\n\n" + classicalSourceNote

    private val baseLocalizedSuggestion: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> when (this) {
                    SHENG_QI -> "Ideal for wealth growth, main entrance, master bedroom, and activating vibrant energy."
                    YAN_NIAN -> "Favors longevity, health, family harmony, and interpersonal relations; ideal for master bedroom or living room."
                    TIAN_YI -> "Dispels illness and misfortune, attracts benefactors; ideal for beds and sacred altars."
                    FU_WEI -> "Stability, peace, and academic excellence; ideal for study, meditation, and children's room."
                    JUE_MING -> "Indicates health decline and financial drain. What to do: Use this direction for a bathroom or storage, keep it rarely occupied; never use it as the main bedroom, entrance or study. → Effect: Mainly health drain and money loss for the frail and elders of the family; covers this direction."
                    WU_GUI -> "Prone to quarrels, official disputes and theft. What to do: Counteract with a heavy object or still water (dark container); avoid red and drilling here. → Effect: Mainly disputes, official trouble and theft concerns for family members (most tied to the breadwinner's career); covers this direction."
                    LIU_SHA -> "Emotional turbulence and romance trouble. What to do: Place storage cabinets/shelves here, keep it tidy and rarely occupied; avoid using it as the main bedroom or study. → Effect: Mainly disputes, gossip and relationship trouble for family members (most felt by the women, younger members and the couple), plus unwanted romance attention; covers this direction."
                    HUO_HAI -> "Obstacles, petty disputes and money drain. What to do: Keep this direction still; place a ceramic/earth-toned item to stabilize, avoid heavy renovation. → Effect: Mainly official trouble, money loss and stomach discomfort (felt most by the decision-maker and the frail); covers this direction."
                }
                AppLanguage.ZH_HANT -> when (this) {
                    SHENG_QI -> "最利求財進職、開大門、置主臥、安動氣之源"
                    YAN_NIAN -> "利健康長壽、夫妻和睦、人際關係，宜主臥客堂"
                    TIAN_YI -> "消災解厄、身體強健、得貴人相扶，利安床與神位"
                    FU_WEI -> "安穩守成、文昌得利，宜作書房、冥想及兒童房"
                    JUE_MING -> "主病痛耗散、破財風險。做法：宜作衛生間或儲物間，少坐人；嚴禁作主臥、大門或書房。→ 影響：主家中體弱者與長輩健康損耗、破財風險，覆蓋該方位。"
                    WU_GUI -> "易生口舌官非、盜賊火光。做法：此方宜放重物或靜水（黑容器）化解，忌見大紅、忌動土。→ 影響：主家人易犯口舌是非、官非竊盜（多與主事者事業相關），覆蓋該方位。"
                    LIU_SHA -> "主情緒不穩、爛桃花。做法：此處適合作收納雜物櫃，常保整潔少走動；忌作主臥、書房。→ 影響：主家人感情波折、口角是非、人際不睦（以女性、年輕成員與夫妻最顯），外帶爛桃花干擾，覆蓋該方位。"
                    HUO_HAI -> "主阻滯、小人、破財。做法：此方宜靜不宜動，放陶磁土類飾品鎮之，忌大幅改動。→ 影響：主家人常遇官非、破耗、脾胃不適（以當家主事者與體弱者為主），覆蓋該方位。"
                }
                AppLanguage.JA -> when (this) {
                    SHENG_QI -> "金運・昇進・玄関・主寝室に最適で、活気をもたらす。"
                    YAN_NIAN -> "健康長寿・夫婦和合・対人関係に良く、寝室や居間に適す。"
                    TIAN_YI -> "厄除け・健康・貴人の助けを得る。ベッドや神棚に好適。"
                    FU_WEI -> "安泰・学業成就に良く、書斎や瞑想、子供部屋に適す。"
                    JUE_MING -> "病気や出費の恐れ。やり方：浴室や収納にし、人の出入りを減らす。主寝室・玄関・書斎は厳禁。→ 効果：主に家族の高齢者や病弱な人の健康低下、散財に作用。この方位に影響。"
                    WU_GUI -> "口論や盗難の恐れ。やり方：重い物や静水を置き、赤色や工事を避ける。→ 効果：家族の口論・トラブル・盗難（世帯主の仕事と関連）。この方位に影響。"
                    LIU_SHA -> "情緒不安定や人間関係の乱れ。やり方：収納棚を置き清潔にし、出入りを減らす。主寝室や書斎は避ける。→ 効果：家族の感情の波立ち、口論、人間関係の不調。この方位に影響。"
                    HUO_HAI -> "障害・散財の恐れ。やり方：静かに保ち、陶器を置いて安定させる。大掛かりな改装は避ける。→ 効果：家族のトラブル、出費、胃腸の不調に作用。この方位に影響。"
                }
                AppLanguage.KO -> when (this) {
                    SHENG_QI -> "재물·승진·대문·안방에 최적이며 활력을 불러일으킵니다."
                    YAN_NIAN -> "건강 장수·부부 화목·대인 관계에 길하며 안방이나 거실에 적합합니다."
                    TIAN_YI -> "액운을 없애고 건강하며 귀인의 도움을 얻습니다. 침대·제단에 좋습니다."
                    FU_WEI -> "안정과 학업 성취에 좋으며 서재, 명상 공간, 자녀 방에 적합합니다."
                    JUE_MING -> "병고와 재정 손실 위험. 방법: 화장실이나 창고로 쓰고 사람이 오래 머물지 않게 합니다. 안방·대문·서재는 엄금. → 영향: 집안 어르신과 약한 사람의 건강 손실, 파재 위험에 작용."
                    WU_GUI -> "구설수와 도난 위험. 방법: 무거운 물건이나 정지된 물을 두고 빨간색과 토목 공사를 피합니다. → 영향: 가족의 구설·관재·도난(가장의 사업과 관련)."
                    LIU_SHA -> "정서 불안과 인간관계 꼬임. 방법: 수납장 등을 두고 정돈하며 자주 드나들지 않습니다. 안방·서재 피함. → 영향: 가족의 감정 기복, 말다툼, 대인 관계 불화."
                    HUO_HAI -> "장애와 재물 손실. 방법: 조용히 유지하고 도자기류를 두어 안정시킵니다. 큰 개조는 피합니다. → 영향: 가족의 분쟁, 지출 증가, 위장 불편에 작용."
                }
                AppLanguage.VI -> when (this) {
                    SHENG_QI -> "Tốt nhất cho cầu tài thăng tiến, mở cửa chính, đặt phòng ngủ chính."
                    YAN_NIAN -> "Tốt cho sức khỏe trường thọ, vợ chồng hòa thuận, nhân duyên tốt đẹp."
                    TIAN_YI -> "Tiêu tai giải ách, thân thể tráng kiện, được quý nhân phù trợ."
                    FU_WEI -> "Bình an ổn định, văn xương đắc lợi, thích hợp làm phòng đọc sách."
                    JUE_MING -> "Chủ bệnh tật hao tài. Cách làm: Nên làm phòng vệ sinh hoặc kho chứa, ít người ngồi; cấm kỵ làm phòng ngủ chính, cửa lớn hay phòng đọc. → Ảnh hưởng: Sức khỏe người lớn tuổi, đau ốm và rủi ro hao tài."
                    WU_GUI -> "Dễ sinh thị phi kiện tụng, trộm cắp hỏa hoạn. Cách làm: Đặt vật nặng hoặc nước tĩnh để hóa giải; tránh màu đỏ và động thổ. → Ảnh hưởng: Dễ vướng khẩu thiệt thị phi, trắc trở công việc."
                    LIU_SHA -> "Tâm trạng bất ổn, đào hoa xấu. Cách làm: Đặt tủ đồ gọn gàng, ít qua lại; tránh làm phòng ngủ hay phòng đọc. → Ảnh hưởng: Tình cảm trắc trở, cãi vã, quan hệ bất hòa."
                    HUO_HAI -> "Trắc trở, tiểu nhân, hao tài. Cách làm: Nên để tĩnh không nên động, đặt đồ gốm sứ trấn giữ, tránh cải tạo lớn. → Ảnh hưởng: Dễ gặp phiền phức, hao tán, tỳ vị bất hòa."
                }
                AppLanguage.TH -> when (this) {
                    SHENG_QI -> "ดีที่สุดสำหรับการแสวงหาทรัพย์ เลื่อนตำแหน่ง ประตูใหญ่ และห้องนอนใหญ่"
                    YAN_NIAN -> "เสริมสุขภาพอายุยืน ครอบครัวอบอุ่นปรองดอง เหมาะสำหรับห้องนอนใหญ่"
                    TIAN_YI -> "ปัดเป่าเคราะห์ภัย ร่างกายแข็งแรง มีผู้อุปถัมภ์ เหมาะสำหรับเตียงนอน"
                    FU_WEI -> "มั่นคงสงบสุข เสริมปัญญาการเรียน เหมาะสำหรับห้องหนังสือและห้องพระ"
                    JUE_MING -> "ระวังการเจ็บป่วยและสูญเสียทรัพย์ วิธีแก้: ทำเป็นห้องน้ำหรือห้องเก็บของ ไม่ควรนั่งนาน ห้ามใช้เป็นห้องนอนใหญ่ ประตู หรือห้องหนังสือเด็ดขาด → ผลกระทบ: สุขภาพผู้สูงอายุและคนอ่อนแอในบ้านทรุดโทรมและเสียทรัพย์"
                    WU_GUI -> "เสี่ยงคดีความและโจรกรรม วิธีแก้: วางของหนักหรือน้ำนิ่งไว้สลาย ห้ามใช้สีแดงและห้ามทุบเจาะ → ผลกระทบ: ปากเสียง คดีความ และของหาย (สัมพันธ์กับหน้าที่การงานของหัวหน้าครอบครัว)"
                    LIU_SHA -> "อารมณ์แปรปรวน รักซ้อน วิธีแก้: ทำเป็นตู้เก็บของ รักษาความสะอาด ไม่ควรใช้เป็นห้องนอนหรือห้องหนังสือ → ผลกระทบ: ความขัดแย้งด้านอารมณ์ ปากเสียง มนุษยสัมพันธ์ไม่ดี"
                    HUO_HAI -> "อุปสรรค คนพาล เสียทรัพย์ วิธีแก้: รักษาความสงบนิ่ง วางเครื่องปั้นดินเผาปรับสมดุล หลีกเลี่ยงการต่อเติมใหญ่ → ผลกระทบ: คดีความ เสียเงินกะทันหัน ปัญหาระบบย่อยอาหาร"
                }
                AppLanguage.ID -> when (this) {
                    SHENG_QI -> "Paling ideal untuk rezeki, kenaikan jabatan, pintu utama, dan kamar tidur utama."
                    YAN_NIAN -> "Baik untuk kesehatan, umur panjang, keharmonisan keluarga, dan hubungan sosial."
                    TIAN_YI -> "Menghilangkan musibah, badan bugar, mendapat pertolongan orang berkuasa."
                    FU_WEI -> "Tenang stabil, prestasi akademik baik; cocok untuk ruang belajar dan meditasi."
                    JUE_MING -> "Rentan penyakit dan pengeluaran boros. Cara mengatasi: Jadikan kamar mandi atau gudang, hindari duduk lama; dilarang keras untuk kamar tidur utama, pintu gerbang, atau ruang belajar. → Pengaruh: Penurunan kesehatan orang tua dan orang rentan di rumah, serta risiko kerugian finansial."
                    WU_GUI -> "Rentan perselisihan hukum dan pencurian. Cara mengatasi: Letakkan benda berat atau air tenang untuk menetralisir; hindari warna merah dan pembongkaran. → Pengaruh: Anggota keluarga rentan berselisih paham, masalah hukum, dan kekhawatiran pencurian."
                    LIU_SHA -> "Emosi tidak stabil dan masalah asmara tak diinginkan. Cara mengatasi: Letakkan lemari penyimpanan, jaga kebersihan, kurangi aktivitas; hindari untuk kamar tidur utama atau ruang belajar. → Pengaruh: Gejolak emosi keluarga, pertengkaran, dan hubungan yang memburuk."
                    HUO_HAI -> "Hambatan, gangguan orang jahat, dan boros. Cara mengatasi: Jaga ketenangan, letakkan hiasan keramik untuk menstabilkan, hindari renovasi besar. → Pengaruh: Masalah hukum keluarga, pengeluaran tak terduga, dan gangguan pencernaan."
                }
                else -> when (this) {
                    SHENG_QI -> "最利求财进职、开大门、置主卧、安动气之源"
                    YAN_NIAN -> "利健康长寿、夫妻和睦、人际关系，宜主卧客堂"
                    TIAN_YI -> "消灾解厄、身体强健、得贵人相扶，利安床与神位"
                    FU_WEI -> "安稳守成、文昌得利，宜作书房、冥想及儿童房"
                    JUE_MING -> "主病痛耗散、破财风险。做法：宜作卫生间或储物间，少坐人；严禁作主卧、大门或书房。→ 影响：主家中体弱者与长辈健康损耗、破财风险，覆盖该方位。"
                    WU_GUI -> "易生口舌官非、盗贼火光。做法：此方宜放重物或静水（黑容器）化解，忌见大红、忌动土。→ 影响：主家人易犯口舌是非、官非窃盗（多与主事者事业相关），覆盖该方位。"
                    LIU_SHA -> "主情绪不稳、烂桃花。做法：此处适合作收纳杂物柜，常保整洁少走动；忌作主卧、书房。→ 影响：主家人感情波折、口角是非、人际不睦（以女性、年轻成员与夫妻最显），外带烂桃花干扰，覆盖该方位。"
                    HUO_HAI -> "主阻滞、小人、破财。做法：此方宜静不宜动，放陶瓷土类饰品镇之，忌大幅改动。→ 影响：主家人常遇官非、破耗、脾胃不适（以当家主事者与体弱者为主），覆盖该方位。"
                }
            }
        }

    private val classicalSourceNote: String
        get() {
            val source = "《八宅明镜》八宅九星诀：“生气贪狼木，延年武曲金，天医巨门土，伏位辅弼木；绝命破军金，五鬼廉贞火，六煞文曲水，祸害禄存土。”"
            return when (LocalizationManager.shared.effectiveLanguage) {
                AppLanguage.EN -> "Classical source: Eight-House Nine-Star formula in Ba Zhai Ming Jing: ‘Sheng Qi is Tan Lang Wood; Yan Nian is Wu Qu Metal; Tian Yi is Ju Men Earth; Fu Wei is Fu Bi Wood; Jue Ming is Po Jun Metal; Wu Gui is Lian Zhen Fire; Liu Sha is Wen Qu Water; Huo Hai is Lu Cun Earth.’ Interpretation: the health, vitality and wealth language above is a symbolic traditional-culture reading of these star names, not a medical diagnosis, treatment, financial advice or guaranteed outcome."
                AppLanguage.ZH_HANT -> "古籍出處： 《八宅明鏡》八宅九星訣：「生氣貪狼木，延年武曲金，天醫巨門土，伏位輔弼木；絕命破軍金，五鬼廉貞火，六煞文曲水，禍害祿存土。」解釋：上文涉及健康、元氣與財帛的語句，屬九星名義的傳統文化象徵解讀，不是醫療診斷、治療或財務建議，也不保證實際結果。"
                AppLanguage.JA -> "出典：『八宅明鏡』八宅九星訣「生気は貪狼木、延年は武曲金、天医は巨門土、伏位は輔弼木、絶命は破軍金、五鬼は廉貞火、六殺は文曲水、禍害は禄存土」。解釈：健康・活力・財に関する表現は星名に基づく伝統文化上の象徴的な読みであり、医学的診断・治療・金融助言や結果の保証ではありません。"
                AppLanguage.KO -> "출처: 《팔택명경》 팔택구성결 ‘생기는 탐랑목, 연년은 무곡금, 천의는 거문토, 복위는 보필목, 절명은 파군금, 오귀는 염정화, 육살은 문곡수, 화해는 녹존토’입니다. 해석: 위 건강·활력·재물 표현은 전통문화의 상징적 해석이며 의학적 진단·치료·재무 조언이나 결과 보장이 아닙니다."
                AppLanguage.VI -> "Nguồn cổ: Quyết Cửu Tinh Bát Trạch trong Bát Trạch Minh Kính: ‘Sinh Khí thuộc Tham Lang Mộc; Diên Niên thuộc Vũ Khúc Kim; Thiên Y thuộc Cự Môn Thổ; Phục Vị thuộc Phụ Bật Mộc; Tuyệt Mệnh thuộc Phá Quân Kim; Ngũ Quỷ thuộc Liêm Trinh Hỏa; Lục Sát thuộc Văn Khúc Thủy; Họa Hại thuộc Lộc Tồn Thổ.’ Giải thích: các câu về sức khỏe, sinh lực và tài lộc là biểu tượng văn hóa truyền thống, không phải chẩn đoán y khoa, điều trị, tư vấn tài chính hay bảo đảm kết quả."
                AppLanguage.TH -> "ที่มาโบราณ: สูตรดาวเก้าดวงแปดบ้านในคัมภีร์ปาจ้ายหมิงจิ่งกล่าวว่า ‘เซิงชี่ดาวทานหลางธาตุไม้ เหยียนเหนียนดาวอู่ชวีธาตุทอง เทียนอีดาวจวี้เหมินธาตุดิน ฝูเว่ยดาวฝู่ปี้ธาตุไม้ เจวี๋ยหมิงดาวผัวจวินธาตุทอง อู่กุ่ยดาวเหลียนเจินธาตุไฟ ลิ่วซาดาวเหวินชวีธาตุน้ำ ฮั่วไห่ดาวลู่ชุนธาตุดิน’ คำอธิบาย: ถ้อยคำด้านสุขภาพ พลังชีวิต และทรัพย์สินเป็นสัญลักษณ์ทางวัฒนธรรมดั้งเดิม ไม่ใช่การวินิจฉัยหรือรักษาโรค คำแนะนำทางการเงิน หรือการรับประกันผลลัพธ์"
                AppLanguage.ID -> "Sumber klasik: Rumus Sembilan Bintang Ba Zhai dalam Ba Zhai Ming Jing: ‘Sheng Qi Tan Lang Kayu; Yan Nian Wu Qu Logam; Tian Yi Ju Men Tanah; Fu Wei Fu Bi Kayu; Jue Ming Po Jun Logam; Wu Gui Lian Zhen Api; Liu Sha Wen Qu Air; Huo Hai Lu Cun Tanah.’ Penjelasan: ungkapan tentang kesehatan, vitalitas, dan rezeki di atas adalah tafsir simbolik budaya tradisional, bukan diagnosis medis, pengobatan, nasihat keuangan, atau jaminan hasil."
                else -> "古籍出处：$source\n解释：上文涉及健康、元气与财帛的语句，属于九星名义的传统文化象征解读，不是医疗诊断、治疗或财务建议，也不保证实际结果。"
            }
        }
}

data class BaZhaiPalaceItem(
    val id: Int,
    val direction: String,
    val guaName: String,
    val star: StarLuckType
) {
    val localizedSuggestion: String
        get() = star.localizedSuggestion

    val localizedDirection: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            val enDirs = listOf("North (Kan)", "Southwest (Kun)", "East (Zhen)", "Southeast (Xun)", "Northwest (Qian)", "West (Dui)", "Northeast (Gen)", "South (Li)")
            val hantDirs = listOf("正北 (坎)", "西南 (坤)", "正東 (震)", "東南 (巽)", "西北 (乾)", "正西 (兌)", "東北 (艮)", "正南 (離)")
            val jaDirs = listOf("正北 (坎)", "南西 (坤)", "正東 (震)", "南東 (巽)", "北西 (乾)", "正西 (兌)", "北東 (艮)", "正南 (離)")
            val koDirs = listOf("정북 (감)", "남서 (곤)", "정동 (진)", "동남 (손)", "북서 (건)", "정서 (태)", "북동 (간)", "정남 (이)")
            val viDirs = listOf("Chính Bắc (Khảm)", "Tây Nam (Khôn)", "Chính Đông (Chấn)", "Đông Nam (Tốn)", "Tây Bắc (Càn)", "Chính Tây (Đoài)", "Đông Bắc (Cấn)", "Chính Nam (Ly)")
            val thDirs = listOf("ทิศเหนือ (ข่าน)", "ทิศตะวันตกเฉียงใต้ (คุน)", "ทิศตะวันออก (เจิ้น)", "ทิศตะวันออกเฉียงใต้ (ซวิ่น)", "ทิศตะวันตกเฉียงเหนือ (เฉียน)", "ทิศตะวันตก (ตุ้ย)", "ทิศตะวันออกเฉียงเหนือ (เกิ้น)", "ทิศใต้ (หลี)")
            val idDirs = listOf("Utara (Kan)", "Barat Daya (Kun)", "Timur (Zhen)", "Tenggara (Xun)", "Barat Laut (Qian)", "Barat (Dui)", "Timur Laut (Gen)", "Selatan (Li)")

            if (id in 0..7) {
                return when (lang) {
                    AppLanguage.EN -> enDirs[id]
                    AppLanguage.ZH_HANT -> hantDirs[id]
                    AppLanguage.JA -> jaDirs[id]
                    AppLanguage.KO -> koDirs[id]
                    AppLanguage.VI -> viDirs[id]
                    AppLanguage.TH -> thDirs[id]
                    AppLanguage.ID -> idDirs[id]
                    else -> direction
                }
            }
            return direction
        }
}

data class BaZhaiAnalysis(
    val houseGua: String,       // 宅卦 (如: 坎宅、乾宅)
    val houseType: String,      // 东四宅 / 西四宅
    val gateDirection: String,  // 大门开向
    val gateStar: StarLuckType, // 大门纳气吉凶
    val items: List<BaZhaiPalaceItem>
) {
    val localizedHouseGua: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> {
                    val map = mapOf("坎宅" to "Kan House", "坤宅" to "Kun House", "震宅" to "Zhen House", "巽宅" to "Xun House", "乾宅" to "Qian House", "兑宅" to "Dui House", "艮宅" to "Gen House", "离宅" to "Li House")
                    map[houseGua] ?: houseGua
                }
                AppLanguage.ZH_HANT, AppLanguage.JA -> {
                    val map = mapOf("坎宅" to "坎宅", "坤宅" to "坤宅", "震宅" to "震宅", "巽宅" to "巽宅", "乾宅" to "乾宅", "兑宅" to "兌宅", "艮宅" to "艮宅", "离宅" to "離宅")
                    map[houseGua] ?: houseGua
                }
                AppLanguage.KO -> {
                    val map = mapOf("坎宅" to "감택", "坤宅" to "곤택", "震宅" to "진택", "巽宅" to "손택", "乾宅" to "건택", "兑宅" to "태택", "艮宅" to "간택", "离宅" to "이택")
                    map[houseGua] ?: houseGua
                }
                AppLanguage.VI -> {
                    val map = mapOf("坎宅" to "Khảm Trạch", "坤宅" to "Khôn Trạch", "震宅" to "Chấn Trạch", "巽宅" to "Tốn Trạch", "乾宅" to "Càn Trạch", "兑宅" to "Đoài Trạch", "艮宅" to "Cấn Trạch", "离宅" to "Ly Trạch")
                    map[houseGua] ?: houseGua
                }
                AppLanguage.TH -> {
                    val map = mapOf("坎宅" to "บ้านข่าน", "坤宅" to "บ้านคุน", "震宅" to "บ้านเจิ้น", "巽宅" to "บ้านซวิ่น", "乾宅" to "บ้านเฉียน", "兑宅" to "บ้านตุ้ย", "艮宅" to "บ้านเกิ้น", "离宅" to "บ้านหลี")
                    map[houseGua] ?: houseGua
                }
                AppLanguage.ID -> {
                    val map = mapOf("坎宅" to "Rumah Kan", "坤宅" to "Rumah Kun", "震宅" to "Rumah Zhen", "巽宅" to "Rumah Xun", "乾宅" to "Rumah Qian", "兑宅" to "Rumah Dui", "艮宅" to "Rumah Gen", "离宅" to "Rumah Li")
                    map[houseGua] ?: houseGua
                }
                else -> houseGua
            }
        }

    val localizedHouseType: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> if (houseType == "东四宅") "East Group House" else "West Group House"
                AppLanguage.ZH_HANT -> if (houseType == "东四宅") "東四宅" else "西四宅"
                AppLanguage.JA -> if (houseType == "东四宅") "東四宅" else "西四宅"
                AppLanguage.KO -> if (houseType == "东四宅") "동사택" else "서사택"
                AppLanguage.VI -> if (houseType == "东四宅") "Đông Tứ Trạch" else "Tây Tứ Trạch"
                AppLanguage.TH -> if (houseType == "东四宅") "บ้านกลุ่มทิศตะวันออก" else "บ้านกลุ่มทิศตะวันตก"
                AppLanguage.ID -> if (houseType == "东四宅") "Kelompok Rumah Timur" else "Kelompok Rumah Barat"
                else -> houseType
            }
        }

    val localizedGateDirection: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> {
                    val map = mapOf("坎" to "North (Kan)", "坤" to "Southwest (Kun)", "震" to "East (Zhen)", "巽" to "Southeast (Xun)", "乾" to "Northwest (Qian)", "兑" to "West (Dui)", "艮" to "Northeast (Gen)", "离" to "South (Li)")
                    map[gateDirection] ?: gateDirection
                }
                AppLanguage.ZH_HANT -> {
                    val map = mapOf("坎" to "正北 (坎)", "坤" to "西南 (坤)", "震" to "正東 (震)", "巽" to "東南 (巽)", "乾" to "西北 (乾)", "兑" to "正西 (兌)", "艮" to "東北 (艮)", "离" to "正南 (離)")
                    map[gateDirection] ?: gateDirection
                }
                AppLanguage.JA -> {
                    val map = mapOf("坎" to "正北 (坎)", "坤" to "南西 (坤)", "震" to "正東 (震)", "巽" to "南東 (巽)", "乾" to "北西 (乾)", "兑" to "正西 (兌)", "艮" to "北東 (艮)", "离" to "正南 (離)")
                    map[gateDirection] ?: gateDirection
                }
                AppLanguage.KO -> {
                    val map = mapOf("坎" to "정북 (감)", "坤" to "남서 (곤)", "震" to "정동 (진)", "巽" to "동남 (손)", "乾" to "북서 (건)", "兑" to "정서 (태)", "艮" to "북동 (간)", "离" to "정남 (이)")
                    map[gateDirection] ?: gateDirection
                }
                AppLanguage.VI -> {
                    val map = mapOf("坎" to "Chính Bắc (Khảm)", "坤" to "Tây Nam (Khôn)", "震" to "Chính Đông (Chấn)", "巽" to "Đông Nam (Tốn)", "乾" to "Tây Bắc (Càn)", "兑" to "Chính Tây (Đoài)", "艮" to "Đông Bắc (Cấn)", "离" to "Chính Nam (Ly)")
                    map[gateDirection] ?: gateDirection
                }
                AppLanguage.TH -> {
                    val map = mapOf("坎" to "ทิศเหนือ (ข่าน)", "坤" to "ทิศตะวันตกเฉียงใต้ (คุน)", "震" to "ทิศตะวันออก (เจิ้น)", "巽" to "ทิศตะวันออกเฉียงใต้ (ซวิ่น)", "乾" to "ทิศตะวันตกเฉียงเหนือ (เฉียน)", "兑" to "ทิศตะวันตก (ตุ้ย)", "艮" to "ทิศตะวันออกเฉียงเหนือ (เกิ้น)", "离" to "ทิศใต้ (หลี)")
                    map[gateDirection] ?: gateDirection
                }
                AppLanguage.ID -> {
                    val map = mapOf("坎" to "Utara (Kan)", "坤" to "Barat Daya (Kun)", "震" to "Timur (Zhen)", "巽" to "Tenggara (Xun)", "乾" to "Barat Laut (Qian)", "兑" to "Barat (Dui)", "艮" to "Timur Laut (Gen)", "离" to "Selatan (Li)")
                    map[gateDirection] ?: gateDirection
                }
                else -> gateDirection
            }
        }
}

class BaZhaiEngine private constructor() {
    companion object {
        val instance: BaZhaiEngine by lazy { BaZhaiEngine() }
    }

    private val guaFamilies: Map<String, String> = mapOf(
        "坎" to "东四宅", "震" to "东四宅", "巽" to "东四宅", "离" to "东四宅",
        "乾" to "西四宅", "坤" to "西四宅", "艮" to "西四宅", "兑" to "西四宅"
    )

    fun analyze(sittingPalace: String, facingPalace: String): BaZhaiAnalysis {
        val hType = guaFamilies[sittingPalace] ?: "东四宅"
        val houseName = "${sittingPalace}宅"

        val directions = arrayOf("正北 (坎)", "西南 (坤)", "正东 (震)", "东南 (巽)", "西北 (乾)", "正西 (兑)", "东北 (艮)", "正南 (离)")
        val guas = arrayOf("坎", "坤", "震", "巽", "乾", "兑", "艮", "离")

        val list = mutableListOf<BaZhaiPalaceItem>()
        for (i in 0 until 8) {
            val targetGua = guas[i]
            val star = calculateStar(sittingPalace, targetGua)
            list.add(BaZhaiPalaceItem(id = i, direction = directions[i], guaName = targetGua, star = star))
        }

        val gateStar = calculateStar(sittingPalace, facingPalace)

        return BaZhaiAnalysis(
            houseGua = houseName,
            houseType = hType,
            gateDirection = facingPalace,
            gateStar = gateStar,
            items = list
        )
    }

    private fun calculateStar(base: String, target: String): StarLuckType {
        if (base == target) return StarLuckType.FU_WEI
        val pairs = mapOf(
            "坎" to mapOf("巽" to StarLuckType.SHENG_QI, "离" to StarLuckType.YAN_NIAN, "震" to StarLuckType.TIAN_YI, "坤" to StarLuckType.JUE_MING, "艮" to StarLuckType.WU_GUI, "乾" to StarLuckType.LIU_SHA, "兑" to StarLuckType.HUO_HAI),
            "离" to mapOf("震" to StarLuckType.SHENG_QI, "坎" to StarLuckType.YAN_NIAN, "巽" to StarLuckType.TIAN_YI, "乾" to StarLuckType.JUE_MING, "兑" to StarLuckType.WU_GUI, "坤" to StarLuckType.LIU_SHA, "艮" to StarLuckType.HUO_HAI),
            "震" to mapOf("离" to StarLuckType.SHENG_QI, "巽" to StarLuckType.YAN_NIAN, "坎" to StarLuckType.TIAN_YI, "兑" to StarLuckType.JUE_MING, "乾" to StarLuckType.WU_GUI, "艮" to StarLuckType.LIU_SHA, "坤" to StarLuckType.HUO_HAI),
            "巽" to mapOf("坎" to StarLuckType.SHENG_QI, "震" to StarLuckType.YAN_NIAN, "离" to StarLuckType.TIAN_YI, "艮" to StarLuckType.JUE_MING, "坤" to StarLuckType.WU_GUI, "兑" to StarLuckType.LIU_SHA, "乾" to StarLuckType.HUO_HAI),
            "乾" to mapOf("兑" to StarLuckType.SHENG_QI, "坤" to StarLuckType.YAN_NIAN, "艮" to StarLuckType.TIAN_YI, "离" to StarLuckType.JUE_MING, "震" to StarLuckType.WU_GUI, "坎" to StarLuckType.LIU_SHA, "巽" to StarLuckType.HUO_HAI),
            "坤" to mapOf("艮" to StarLuckType.SHENG_QI, "乾" to StarLuckType.YAN_NIAN, "兑" to StarLuckType.TIAN_YI, "坎" to StarLuckType.JUE_MING, "巽" to StarLuckType.WU_GUI, "离" to StarLuckType.LIU_SHA, "震" to StarLuckType.HUO_HAI),
            "艮" to mapOf("坤" to StarLuckType.SHENG_QI, "兑" to StarLuckType.YAN_NIAN, "乾" to StarLuckType.TIAN_YI, "巽" to StarLuckType.JUE_MING, "坎" to StarLuckType.WU_GUI, "震" to StarLuckType.LIU_SHA, "离" to StarLuckType.HUO_HAI),
            "兑" to mapOf("乾" to StarLuckType.SHENG_QI, "艮" to StarLuckType.YAN_NIAN, "坤" to StarLuckType.TIAN_YI, "震" to StarLuckType.JUE_MING, "离" to StarLuckType.WU_GUI, "巽" to StarLuckType.LIU_SHA, "坎" to StarLuckType.HUO_HAI)
        )
        return pairs[base]?.get(target) ?: StarLuckType.FU_WEI
    }
}
