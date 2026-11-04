package com.example.yiijingcompass.model

/**
 * 三合风水与十二长生水法引擎 (SanHe Water Method & PRD 第13章 杨公八煞黄泉消砂)
 */
enum class ChangShengPhase(val rawValue: String) {
    CHANG_SHENG("长生"),
    MU_YU("沐浴"),
    GUAN_DAI("冠带"),
    LIN_GUAN("临官"),
    DI_WANG("帝旺"),
    SHUAI("衰"),
    BING("病"),
    SI("死"),
    MU("墓"),
    JUE("绝"),
    TAI("胎"),
    YANG("养");

    val localizedName: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> when (this) {
                    CHANG_SHENG -> "Chang Sheng (Birth)"
                    MU_YU -> "Mu Yu (Bath)"
                    GUAN_DAI -> "Guan Dai (Attire)"
                    LIN_GUAN -> "Lin Guan (Official)"
                    DI_WANG -> "Di Wang (Peak Prosperity)"
                    SHUAI -> "Shuai (Decline)"
                    BING -> "Bing (Sickness)"
                    SI -> "Si (Death)"
                    MU -> "Mu (Tomb)"
                    JUE -> "Jue (Extinction)"
                    TAI -> "Tai (Conception)"
                    YANG -> "Yang (Nurture)"
                }
                AppLanguage.ZH_HANT -> when (this) {
                    CHANG_SHENG -> "長生"
                    MU_YU -> "沐浴"
                    GUAN_DAI -> "冠帶"
                    LIN_GUAN -> "臨官"
                    DI_WANG -> "帝旺"
                    SHUAI -> "衰"
                    BING -> "病"
                    SI -> "死"
                    MU -> "墓"
                    JUE -> "絕"
                    TAI -> "胎"
                    YANG -> "養"
                }
                AppLanguage.JA -> when (this) {
                    CHANG_SHENG -> "長生"
                    MU_YU -> "沐浴"
                    GUAN_DAI -> "冠帯"
                    LIN_GUAN -> "臨官"
                    DI_WANG -> "帝旺"
                    SHUAI -> "衰"
                    BING -> "病"
                    SI -> "死"
                    MU -> "墓"
                    JUE -> "絶"
                    TAI -> "胎"
                    YANG -> "養"
                }
                AppLanguage.KO -> when (this) {
                    CHANG_SHENG -> "장생"
                    MU_YU -> "목욕"
                    GUAN_DAI -> "관대"
                    LIN_GUAN -> "임관"
                    DI_WANG -> "제왕"
                    SHUAI -> "쇠"
                    BING -> "병"
                    SI -> "사"
                    MU -> "묘"
                    JUE -> "절"
                    TAI -> "태"
                    YANG -> "양"
                }
                AppLanguage.VI -> when (this) {
                    CHANG_SHENG -> "Trường Sinh"
                    MU_YU -> "Mộc Dục"
                    GUAN_DAI -> "Quan Đới"
                    LIN_GUAN -> "Lâm Quan"
                    DI_WANG -> "Đế Vượng"
                    SHUAI -> "Suy"
                    BING -> "Bệnh"
                    SI -> "Tử"
                    MU -> "Mộ"
                    JUE -> "Tuyệt"
                    TAI -> "Thai"
                    YANG -> "Dưỡng"
                }
                AppLanguage.TH -> when (this) {
                    CHANG_SHENG -> "กำเนิด (ฉางเซิง)"
                    MU_YU -> "ชำระล้าง (มู่ยวี่)"
                    GUAN_DAI -> "สวมมงกุฎ (กวานไต้)"
                    LIN_GUAN -> "รับราชการ (หลินกวาน)"
                    DI_WANG -> "รุ่งเรืองสูงสุด (ตี้วั่ง)"
                    SHUAI -> "เริ่มเสื่อม (ซวย)"
                    BING -> "เจ็บป่วย (ปิ้ง)"
                    SI -> "ดับสูญ (สื่อ)"
                    MU -> "สุสาน (มู่)"
                    JUE -> "สิ้นสุด (เจวี๋ย)"
                    TAI -> "ก่อกำเนิด (ไท่)"
                    YANG -> "บำรุงเลี้ยง (หย่าง)"
                }
                AppLanguage.ID -> when (this) {
                    CHANG_SHENG -> "Kelahiran (Chang Sheng)"
                    MU_YU -> "Mandi (Mu Yu)"
                    GUAN_DAI -> "Mahkota (Guan Dai)"
                    LIN_GUAN -> "Pejabat (Lin Guan)"
                    DI_WANG -> "Kejayaan (Di Wang)"
                    SHUAI -> "Kemunduran (Shuai)"
                    BING -> "Penyakit (Bing)"
                    SI -> "Kematian (Si)"
                    MU -> "Makam (Mu)"
                    JUE -> "Kepunahan (Jue)"
                    TAI -> "Janin (Tai)"
                    YANG -> "Pengasuhan (Yang)"
                }
                else -> rawValue
            }
        }

    val isWaterAuspicious: Boolean
        get() = this == CHANG_SHENG || this == DI_WANG || this == LIN_GUAN || this == GUAN_DAI

    val waterRule: String
        get() = localizedWaterRule

    val localizedWaterRule: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            val core: String
            return when (lang) {
                AppLanguage.EN -> {
                    core = when (this) {
                        CHANG_SHENG, DI_WANG -> "Inflow brings great wealth; outflow causes losses."
                        LIN_GUAN, GUAN_DAI -> "Noble benefactor inflow; outflow is unfavorable."
                        SHUAI -> "Jumen water, flexible for inflow/outflow as storage."
                        MU, JUE -> "Outflow auspicious; inflow is strictly taboo."
                        MU_YU -> "Peach blossom water; both inflow/outflow cause turbulence."
                        BING, SI, TAI, YANG -> "Neutral peaceful position; keep calm and gentle."
                    }
                    core + " Source: traditional San-He twelve-phase water method. Interpretation: the wealth, people and health wording is a classical symbol, not a medical or financial prediction; inspect drainage and safety on site."
                }
                AppLanguage.ZH_HANT -> {
                    core = when (this) {
                        CHANG_SHENG, DI_WANG -> "來水吉，大發富貴；去水凶，損丁破財"
                        LIN_GUAN, GUAN_DAI -> "貴人來水，催官發甲；出水不利"
                        SHUAI -> "巨門水，來去均宜，借庫消水"
                        MU, JUE -> "去水吉，化煞為權；來水大凶，黃泉破局"
                        MU_YU -> "桃花水，來去皆忌，主風流蕩產"
                        BING, SI, TAI, YANG -> "平和之位，宜緩流靜蓄"
                    }
                    core + "。出處：傳統三合十二長生水法（傳本有異文）。解釋：其中富貴、損丁與病死等語句是古法象徵，不是醫療或財務預測；請現場檢查排水與安全。"
                }
                AppLanguage.JA -> {
                    core = when (this) {
                        CHANG_SHENG, DI_WANG -> "来水は大吉で富貴を招き、去水は凶で散財損丁"
                        LIN_GUAN, GUAN_DAI -> "貴人の来水で出世栄達、去水は不利"
                        SHUAI -> "巨門水、出水入水ともに可、借庫消水に適す"
                        MU, JUE -> "去水は吉で煞を権に変え、来水は大凶で黄泉破局"
                        MU_YU -> "桃花水、出水入水ともに凶、放蕩や破財を招く"
                        BING, SI, TAI, YANG -> "穏やかな気位、静水緩流が吉"
                    }
                    core + "。出典：伝統三合十二長生水法（伝本に異文）。健康・財産の表現は古典の象徴であり、現場の排水と安全を確認してください。"
                }
                AppLanguage.KO -> {
                    core = when (this) {
                        CHANG_SHENG, DI_WANG -> "물이 들어오면 대길하여 부귀를 부르고, 나가면 흉하여 손실 초래"
                        LIN_GUAN, GUAN_DAI -> "귀인의 수로 승진 발달, 물이 나가면 불리"
                        SHUAI -> "거문수로 들어오고 나감이 모두 무방하며 수구로 차용"
                        MU, JUE -> "물이 나가면 길하여 살을 권세로 화하고, 들어오면 황천 대흉"
                        MU_YU -> "도화수로 들고남이 모두 꺼려지며 주색패가"
                        BING, SI, TAI, YANG -> "평화로운 자리로 고요하고 완만한 흐름이 적합"
                    }
                    core + " 출처: 전통 삼합 십이장생 수법. 건강·재정 표현은 고전 상징이며 의료·재정 예측이 아닙니다."
                }
                AppLanguage.VI -> {
                    core = when (this) {
                        CHANG_SHENG, DI_WANG -> "Nước lại cát lợi đại phát phú quý; nước đi hung tổn đinh hao tài"
                        LIN_GUAN, GUAN_DAI -> "Nước quý nhân trợ quan phát đạt; nước chảy đi thì bất lợi"
                        SHUAI -> "Nước Cự Môn, đến hay đi đều được, mượn khố tiêu thủy"
                        MU, JUE -> "Nước đi cát, hóa sát thành quyền; nước đến đại hung phạm Hoàng Tuyền"
                        MU_YU -> "Nước Đào Hoa, đến hay đi đều kỵ, chủ phong lưu phá sản"
                        BING, SI, TAI, YANG -> "Vị trí bình hòa, nên để dòng nước chảy chậm êm ả"
                    }
                    core + ". Nguồn: thủy pháp Tam Hợp Thập Nhị Trường Sinh truyền thống; các câu về sức khỏe và tài lộc là biểu tượng cổ, không phải dự đoán y khoa hay tài chính."
                }
                AppLanguage.TH -> {
                    core = when (this) {
                        CHANG_SHENG, DI_WANG -> "น้ำไหลเข้ามงคลยิ่ง ร่ำรวยมหาศาล; น้ำไหลออกอัปมงคล สูญเสียทรัพย์สิน"
                        LIN_GUAN, GUAN_DAI -> "น้ำไหลเข้าส่งเสริมยศศักดิ์บารมี; น้ำไหลออกไม่เป็นผลดี"
                        SHUAI -> "น้ำจวี้เหมิน ไหลเข้าออกพอสมควร ใช้ทดน้ำระบายได้"
                        MU, JUE -> "น้ำไหลออกมงคล เปลี่ยนร้ายกลายเป็นดี; น้ำไหลเข้าอัปมงคลยิ่ง"
                        MU_YU -> "น้ำดอกท้อ หลีกเลี่ยงทั้งไหลเข้าและออก ระวังเรื่องชู้สาวเสียทรัพย์"
                        BING, SI, TAI, YANG -> "ตำแหน่งสงบสมดุล ควรให้น้ำไหลเอื่อยช้าๆ"
                    }
                    core + " แหล่งที่มา: วิธีน้ำสามประสานสิบสองระยะดั้งเดิม; ถ้อยคำเรื่องสุขภาพและทรัพย์เป็นสัญลักษณ์ ไม่ใช่การพยากรณ์ทางการแพทย์หรือการเงิน"
                }
                AppLanguage.ID -> {
                    core = when (this) {
                        CHANG_SHENG, DI_WANG -> "Air masuk sangat baik mendatangkan rezeki; air keluar membawa kerugian"
                        LIN_GUAN, GUAN_DAI -> "Air masuk membawa promosi bangsawan; air keluar tidak menguntungkan"
                        SHUAI -> "Air Jumen, baik masuk maupun keluar cukup seimbang sebagai penampung"
                        MU, JUE -> "Air keluar membawa berkah; air masuk sangat tabu menimbulkan petaka"
                        MU_YU -> "Air asmara/bunga persik; masuk maupun keluar harus dihindari"
                        BING, SI, TAI, YANG -> "Posisi netral dan tenang; pertahankan aliran air yang lambat dan damai"
                    }
                    core + ". Sumber: metode air San-He dua belas fase tradisional; ungkapan kesehatan dan rezeki bersifat simbolis, bukan prediksi medis atau keuangan."
                }
                else -> {
                    core = when (this) {
                        CHANG_SHENG, DI_WANG -> "来水吉，大发富贵；去水凶，损丁破财"
                        LIN_GUAN, GUAN_DAI -> "贵人来水，催官发甲；出水不利"
                        SHUAI -> "巨门水，来去均宜，借库消水"
                        MU, JUE -> "去水吉，化煞为权；来水大凶，黄泉破局"
                        MU_YU -> "桃花水，来去皆忌，主风流荡产"
                        BING, SI, TAI, YANG -> "平和之位，宜缓流静蓄"
                    }
                    core + "。出处：传统三合十二长生水法（传本有异文）。解释：其中富贵、损丁与病死等语句是古法象征，不是医疗或财务预测；请现场检查排水与安全。"
                }
            }
        }
}

data class SanHeWaterItem(
    val id: Int,
    val mountainName: String,
    val phase: ChangShengPhase,
    val isHuangQuanSha: Boolean
) {
    val palace: String get() = localizedMountainName
    val stage: String get() = phase.localizedName
    val lore: String get() = phase.localizedWaterRule
    val isAuspicious: Boolean get() = phase.isWaterAuspicious

    val localizedMountainName: String
        get() {
            val mData = Mountain24Data.mountains
            if (id in mData.indices) {
                return mData[id].localizedName
            }
            return mountainName
        }
}

// MARK: - 八路黄泉水法判定模型
data class HuangQuanWaterResult(
    val facingMountain: String,
    val waterDesc: String,
    val isJiuPin: Boolean,
    val isDanger: Boolean,
    val badgeText: String,
    val quote: String = "庚丁坤上是黄泉，乙丙须防巽水先。甲癸向中休见艮，辛壬水路怕当乾。"
) {
    val localizedQuote: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN -> "Geng and Ding fear Huangquan in Kun; Yi and Bing guard against Xun water. Jia and Gui avoid Gen; Xin and Ren fear Qian water."
            AppLanguage.ZH_HANT, AppLanguage.JA -> "庚丁坤上是黃泉，乙丙須防巽水先。甲癸向中休見艮，辛壬水路怕當乾。"
            AppLanguage.KO -> "경정곤상은 황천이요, 을병은 먼저 손수를 방비하라. 갑계향 중에는 간을 보지 말고, 신임 수로는 건을 두려워한다."
            AppLanguage.VI -> "Canh Đinh Khôn thượng thị Hoàng Tuyền, Ất Bính tu phòng Tốn thủy tiên. Giáp Quý hướng trung hưu kiến Cấn, Tân Nhâm thủy lộ phạ đương Càn."
            AppLanguage.TH -> "เกิ้งติงทิศคุนคือหวงเฉวียน อี้ปิ่งระวังน้ำทิศซวิ่น เจี่ยกุ่ยอย่าพบทิศเกิ้น ซินเหรินระวังน้ำทิศเฉียน"
            AppLanguage.ID -> "Geng dan Ding hindari Huangquan di Kun; Yi dan Bing waspadai air Xun. Jia dan Gui hindari Gen; Xin dan Ren waspadai jalan air Qian."
            else -> quote
        }
}

// MARK: - 坐山八煞曜位模型
data class BaShaResult(
    val sittingMountain: String,
    val sittingPalace: String,
    val shaZhi: String,
    val shaDir: String,
    val lore: String,
    val remedy: String,
    val song: String = "坎龙坤兔震山猴，巽鸡乾马兑蛇头，艮虎离猪为煞曜。",
    val xiaoShaRule: String = "生我为生砂（催贵），同我为旺砂（旺丁财），克我为煞砂（大凶血光），我克为奴砂（得财帛），我生为泄砂（虚耗脱白）。"
) {
    val localizedSong: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN -> "Kan Dragon, Kun Rabbit, Zhen Monkey; Xun Rooster, Qian Horse, Dui Snake; Gen Tiger and Li Pig mark the Sha stars."
            AppLanguage.ZH_HANT, AppLanguage.JA -> "坎龍坤兔震山猴，巽雞乾馬兌蛇頭，艮虎離豬為煞曜。"
            AppLanguage.KO -> "감룡 곤토 진산후, 손계 건마 태사두, 간호 이저는 살요가 된다."
            AppLanguage.VI -> "Khảm Long Khôn Thố Chấn sơn hầu, Tốn Kê Càn Mã Đoài xà đầu, Cấn Hổ Ly Trư vi sát diệu."
            AppLanguage.TH -> "ข่านมังกร คุนกระต่าย เจิ้นลิง ซวิ่นไก่ เฉียนม้า ตุ้ยงู เกิ้นเสือ หลีหมู เป็นดาวพิฆาต"
            AppLanguage.ID -> "Naga Kan, Kelinci Kun, Monyet Zhen; Ayam Xun, Kuda Qian, Ular Dui; Harimau Gen dan Babi Li adalah Bintang Sha."
            else -> song
        }

    val localizedXiaoShaRule: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN -> "Generating me is Sheng Sha (noble aid); same as me is Wang Sha (people and wealth); overcoming me is Sha (major harm); I overcome is Slave Sha (wealth); I generate is Draining Sha (waste). Source: traditional Xiao-Sha five-element rule; health, blood-harm and wealth wording is symbolic, not a diagnosis or prediction."
            AppLanguage.ZH_HANT -> "生我為生砂（催貴），同我為旺砂（旺丁財），克我為煞砂（大凶血光），我克為奴砂（得財帛），我生為洩砂（虛耗脫白）。出處：傳統消砂五行口訣。解釋：旺丁、血光與財帛語句是古法象徵，請現場核對安全，不是醫療或財務預測。"
            AppLanguage.JA -> "生我は生砂（貴人を促す）、同我は旺砂（人財を盛んにす）、克我は煞砂（大凶血光）、我克は奴砂（財帛を得る）、我生は洩砂（散財衰耗）。出典：伝統消砂五行訣。健康・事故・財産の表現は象徴であり、診断や予測ではありません。"
            AppLanguage.KO -> "생하는 것은 생사(귀인 조력), 같은 것은 왕사(인재 재물 번창), 극하는 것은 살사(대흉 혈광), 내가 극하는 것은 노사(재물 획득), 내가 생하는 것은 설사(소모 쇠퇴). 출처: 전통 소사 오행결. 건강·사고·재정 표현은 상징이며 진단이나 예측이 아닙니다."
            AppLanguage.VI -> "Sinh ngã vi Sinh Sa (trợ quý), đồng ngã vi Vượng Sa (vượng nhân đinh tài lộc), khắc ngã vi Sát Sa (đại hung huyết quang), ngã khắc vi Nô Sa (đắc tài bạch), ngã sinh vi Tiết Sa (tiêu hao hư thoát). Nguồn: khẩu quyết Ngũ hành Tiêu Sa truyền thống; các câu về sức khỏe và tài lộc là biểu tượng, không phải chẩn đoán hay dự đoán."
            AppLanguage.TH -> "ธาตุเกื้อหนุนคือเซิงซา (เสริมบารมี); ธาตุเดียวกันคือวั่งซา (บริบูรณ์ทรัพย์และคน); ธาตุข่มคือชาซา (เคราะห์ใหญ่เลือดตก); เราข่มคือหนูซา (ได้ลาภทรัพย์); เราก่อกำเนิดคือเซี่ยซา (รั่วไหลสูญเปล่า) แหล่งที่มา: กฎห้าธาตุเซียวซาแบบดั้งเดิม ถ้อยคำเรื่องสุขภาพและทรัพย์เป็นสัญลักษณ์ ไม่ใช่การวินิจฉัยหรือพยากรณ์"
            AppLanguage.ID -> "Menghidupkan adalah Sheng Sha (penolong bangsawan); seunsur adalah Wang Sha (keluarga & kekayaan); menaklukkan saya adalah Sifat Sha (bahaya besar); saya taklukkan adalah Budak Sha (kekayaan); saya hidupkan adalah Boros Sha (pemborosan). Sumber: aturan lima elemen Xiao-Sha tradisional; ungkapan kesehatan dan rezeki bersifat simbolis."
            else -> "生我为生砂（催贵），同我为旺砂（旺丁财），克我为煞砂（大凶血光），我克为奴砂（得财帛），我生为泄砂（虚耗脱白）。出处：传统消砂五行口诀。解释：旺丁、血光与财帛语句是古法象征，请现场核对安全，不是医疗或财务预测。"
        }

    val localizedShaDir: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> {
                    val zhiEn = mapOf("辰" to "Chen", "卯" to "Mao", "申" to "Shen", "酉" to "You", "午" to "Wu", "巳" to "Si", "寅" to "Yin", "亥" to "Hai")
                    val dirEn = mapOf("东南" to "Southeast", "正东" to "East", "西南" to "Southwest", "正西" to "West", "正南" to "South", "东北" to "Northeast", "西北" to "Northwest")
                    val z = zhiEn[shaZhi] ?: shaZhi
                    val d = dirEn[shaDir] ?: shaDir
                    "$d ($z)"
                }
                AppLanguage.ZH_HANT -> {
                    val dirHant = mapOf("东南" to "東南", "正东" to "正東", "西南" to "西南", "正西" to "正西", "正南" to "正南", "东北" to "東北", "西北" to "西北")
                    val d = dirHant[shaDir] ?: shaDir
                    "$d$shaZhi"
                }
                AppLanguage.JA -> {
                    val dirJa = mapOf("东南" to "南東", "正东" to "正東", "西南" to "南西", "正西" to "正西", "正南" to "正南", "东北" to "北東", "西北" to "北西")
                    val d = dirJa[shaDir] ?: shaDir
                    "$d (${shaZhi}方)"
                }
                AppLanguage.KO -> {
                    val dirKo = mapOf("东南" to "동남", "正东" to "정동", "西南" to "남서", "正西" to "정서", "正南" to "정남", "东北" to "북동", "西北" to "북서")
                    val zhiKo = mapOf("辰" to "진", "卯" to "묘", "申" to "신", "酉" to "유", "午" to "오", "巳" to "사", "寅" to "인", "亥" to "해")
                    val d = dirKo[shaDir] ?: shaDir
                    val z = zhiKo[shaZhi] ?: shaZhi
                    "$d (${z}방)"
                }
                AppLanguage.VI -> {
                    val dirVi = mapOf("东南" to "Đông Nam", "正东" to "Chính Đông", "西南" to "Tây Nam", "正西" to "Chính Tây", "正南" to "Chính Nam", "东北" to "Đông Bắc", "西北" to "Tây Bắc")
                    val zhiVi = mapOf("辰" to "Thìn", "卯" to "Mão", "申" to "Thân", "酉" to "Dậu", "午" to "Ngọ", "巳" to "Tị", "寅" to "Dần", "亥" to "Hợi")
                    val d = dirVi[shaDir] ?: shaDir
                    val z = zhiVi[shaZhi] ?: shaZhi
                    "$d (phương $z)"
                }
                AppLanguage.TH -> {
                    val dirTh = mapOf("东南" to "ทิศตะวันออกเฉียงใต้", "正东" to "ทิศตะวันออก", "西南" to "ทิศตะวันตกเฉียงใต้", "正西" to "ทิศตะวันตก", "正南" to "ทิศใต้", "东北" to "ทิศตะวันออกเฉียงเหนือ", "西北" to "ทิศตะวันตกเฉียงเหนือ")
                    val zhiTh = mapOf("辰" to "เฉิน", "卯" to "เหม่า", "申" to "เซิน", "酉" to "โหย่ว", "午" to "อู่", "巳" to "ซื่อ", "寅" to "อิ๋น", "亥" to "ไฮ่")
                    val d = dirTh[shaDir] ?: shaDir
                    val z = zhiTh[shaZhi] ?: shaZhi
                    "$d (ทิศ$z)"
                }
                AppLanguage.ID -> {
                    val dirId = mapOf("东南" to "Tenggara", "正东" to "Timur", "西南" to "Barat Daya", "正西" to "Barat", "正南" to "Selatan", "东北" to "Timur Laut", "西北" to "Barat Laut")
                    val d = dirId[shaDir] ?: shaDir
                    "$d ($shaZhi)"
                }
                else -> "$shaDir$shaZhi"
            }
        }
}

class SanHeWaterEngine private constructor() {
    companion object {
        val instance: SanHeWaterEngine by lazy { SanHeWaterEngine() }
    }

    private fun localizedHuangQuanSourceNote(lang: AppLanguage): String = when (lang) {
        AppLanguage.ZH_HANT -> "出處：楊公八路黃泉水法口訣。解釋：上述疾厄、損丁與財運語句為古法象徵，不是醫療或財務預測；請現場核對排水與安全。"
        AppLanguage.JA -> "出典：楊公八路黄泉水法の口訣。健康・家族・財産の表現は古法の象徴であり、医療・金融の予測ではありません。排水と安全を現地で確認してください。"
        AppLanguage.KO -> "출처: 양공 팔로황천 수법 구결. 건강·가족·재정 표현은 고법의 상징이며 의료·재정 예측이 아닙니다. 배수와 안전을 현장에서 확인하세요."
        AppLanguage.VI -> "Nguồn: khẩu quyết Bát Lộ Hoàng Tuyền thủy pháp của Dương Công. Các câu về tai ách, tổn đinh và tài vận là biểu tượng cổ, không phải dự đoán y khoa hay tài chính."
        AppLanguage.TH -> "แหล่งที่มา: คำทำนายหวงเฉวียนแปดทิศของท่านหยางกง ถ้อยคำเรื่องเคราะห์ภัยและทรัพย์สินเป็นสัญลักษณ์โบราณ ไม่ใช่การวินิจฉัยทางการแพทย์ โปรดตรวจการระบายน้ำและความปลอดภัย"
        AppLanguage.ID -> "Sumber: rumus Delapan Jalan Air Huangquan Yang Gong. Ungkapan penyakit, keluarga dan rezeki adalah simbol klasik, bukan ramalan medis atau finansial."
        AppLanguage.EN -> "Source: Master Yang's Eight-Path Huangquan water formula. Illness, misfortune and wealth phrases are classical symbolism, not a medical or financial prediction; inspect drainage and safety on site."
        else -> "出处：杨公八路黄泉水法口诀。解释：上述疾厄、损丁与财运语句为古法象征，不是医疗或财务预测；请现场核对排水与安全。"
    }

    private fun localizedBaShaSourceNote(lang: AppLanguage): String = when (lang) {
        AppLanguage.ZH_HANT -> "出處：傳統八煞曜位歌訣「坎龍坤兔震山猴，巽雞乾馬兌蛇頭，艮虎離豬為煞曜」。解釋：腎疾、脾胃、眼疾、傷損等語句是古籍象徵，不是醫療診斷；請先處理現場結構、噪音、排水和通行安全。"
        AppLanguage.JA -> "出典：伝統八煞曜位の歌訣。腎臓・胃腸・眼・けがの表現は古典の象徴で、医学的診断ではありません。構造、騒音、排水、安全を現地で確認してください。"
        AppLanguage.KO -> "출처: 전통 팔살요위 구결. 신장·소화·눈·부상 표현은 고전 상징이며 의료 진단이 아닙니다. 구조·소음·배수·통행 안전을 현장에서 확인하세요."
        AppLanguage.VI -> "Nguồn: khẩu quyết Bát Sát Diệu vị truyền thống. Các câu về thận, tỳ vị, mắt và thương tổn là biểu tượng cổ, không phải chẩn đoán y khoa; hãy kiểm tra cấu trúc, tiếng ồn, thoát nước và an toàn."
        AppLanguage.TH -> "แหล่งที่มา: คาถาดาวพิฆาตแปดทิศดั้งเดิม ถ้อยคำเรื่องไต ระบบย่อยอาหาร ดวงตา และการบาดเจ็บเป็นสัญลักษณ์โบราณ ไม่ใช่การวินิจฉัยทางการแพทย์ โปรดตรวจโครงสร้าง เสียง การระบายน้ำ และความปลอดภัย"
        AppLanguage.ID -> "Sumber: mantra delapan bintang Sha tradisional. Ungkapan ginjal, pencernaan, mata, dan cedera bersifat simbolis, bukan diagnosis medis; periksa struktur, kebisingan, drainase, dan keselamatan."
        AppLanguage.EN -> "Source: traditional Eight-Sha star formula. Kidney, digestion, eye and injury wording is classical symbolism, not a medical diagnosis; inspect structure, noise, drainage and access safety on site."
        else -> "出处：传统八煞曜位歌诀“坎龙坤兔震山猴，巽鸡乾马兑蛇头，艮虎离猪为煞曜”。解释：肾疾、脾胃、眼疾、伤损等语句是古籍象征，不是医疗诊断；请先处理现场结构、噪音、排水和通行安全。"
    }

    private data class Quad(val zhi: String, val dir: String, val lore: String)
    private val baShaMap = mapOf(
        "坎" to Quad("辰", "东南", "坎卦三山（壬／子／癸）煞在辰位。辰方最忌见高压电塔、尖角怪石或破败死水，犯之主肾疾、下元损丁。"),
        "坤" to Quad("卯", "正东", "坤卦三山（未／坤／申）煞在卯位。忌正东见冲射，主脾胃败坏、老母伤损。"),
        "震" to Quad("申", "西南", "震卦三山（甲／卯／乙）煞在申位。忌西南申方突兀尖峰，主长房伤残、足疾官非。"),
        "巽" to Quad("酉", "正西", "巽卦三山（辰／巽／巳）煞在酉位。忌正西酉金直冲，主妇女产厄、风声是非。"),
        "乾" to Quad("午", "正南", "乾卦三山（戌／乾／亥）煞在午位。忌正南离火烈焰反克天门，主心脑血光、损老翁。"),
        "兑" to Quad("巳", "东南", "兑卦三山（庚／酉／辛）煞在巳位。忌东南巳火伤金，主少女不利、肺疾吐血。"),
        "艮" to Quad("寅", "东北", "艮卦三山（丑／艮／寅）煞在寅位。忌东北见破山绝涧，损幼子少男。"),
        "离" to Quad("亥", "西北", "离卦三山（丙／午／丁）煞在亥位。忌西北亥水冲射，主眼疾暗昧、中房受制。")
    )

    fun resolveHuangQuanWater(facing: Mountain24Item): HuangQuanWaterResult {
        val name = facing.name
        val pName = facing.localizedName
        val lang = LocalizationManager.shared.effectiveLanguage

        var desc: String
        var isJiuPin = false
        var isDanger = false
        var badge: String

        when (lang) {
            AppLanguage.EN -> {
                badge = "Pure Needle Auspicious"
                when (name) {
                    "庚", "丁" -> {
                        desc = "Facing Mountain: [$pName]. Major Taboo: Water outlet towards Kun is lethal Huangquan sha (harms descendants and fortune). Inflow from Kun brings noble blessings."
                        isDanger = true
                        badge = "Avoid Kun Water Outlet"
                    }
                    "坤" -> {
                        desc = "Facing Mountain: [$pName]. Yang Gong Rule: Inflow from Geng or Ding is Wealth-Rescue Water (Auspicious, promotes prosperity and noble honors). Direct drainage here is taboo."
                        isJiuPin = true
                        badge = "Wealth Rescue Facing"
                    }
                    "乙", "丙" -> {
                        desc = "Facing Mountain: [$pName]. Major Taboo: Water outlet towards Xun is Eight-Sha Huangquan (misfortunes, disputes, fire hazard). Inflow from Xun is favorable."
                        isDanger = true
                        badge = "Avoid Xun Water Outlet"
                    }
                    "巽" -> {
                        desc = "Facing Mountain: [$pName]. Yang Gong Rule: Inflow from Yi or Bing is Wealth-Rescue Water (Auspicious, boosts academic recognition and lasting prosperity)."
                        isJiuPin = true
                        badge = "Wealth Rescue Facing"
                    }
                    "甲", "癸" -> {
                        desc = "Facing Mountain: [$pName]. Major Taboo: Water outlet towards Gen is Huangquan Killing Water (causes financial setbacks and legal troubles)."
                        isDanger = true
                        badge = "Avoid Gen Water Outlet"
                    }
                    "艮" -> {
                        desc = "Facing Mountain: [$pName]. Yang Gong Rule: Inflow from Jia or Gui is Promotion Water (Auspicious, boosts vitality and eminent accomplishments)."
                        isJiuPin = true
                        badge = "Wealth Rescue Facing"
                    }
                    "辛", "壬" -> {
                        desc = "Facing Mountain: [$pName]. Major Taboo: Water outlet towards Qian is Po Jun Huangquan (causes unexpected losses and blood accidents)."
                        isDanger = true
                        badge = "Avoid Qian Water Outlet"
                    }
                    "乾" -> {
                        desc = "Facing Mountain: [$pName]. Yang Gong Rule: Inflow from Xin or Ren is Wealth-Rescue Water (Auspicious, brings abundance and honor to elders)."
                        isJiuPin = true
                        badge = "Wealth Rescue Facing"
                    }
                    else -> {
                        desc = "Facing Mountain: [$pName]. Not in the Eight-Road Huangquan taboo; align with Twelve Changsheng water method for optimal fortune."
                        badge = "Pure Auspicious Water"
                    }
                }
            }
            AppLanguage.ZH_HANT -> {
                badge = "正針合度純清"
                when (name) {
                    "庚", "丁" -> {
                        desc = "向首為【$pName】。水法大忌：坤方出水為殺人大黃泉（損人丁、傷小口、敗退產業）；若坤方見來水反為催官水。"
                        isDanger = true
                        badge = "大忌坤水破局"
                    }
                    "坤" -> {
                        desc = "向首為【$pName】。楊公水法：見庚方或丁方來水為【救貧黃泉水】（大吉，人興財旺、催官進祿）；最忌此兩方水直流破局。"
                        isJiuPin = true
                        badge = "救貧大吉向首"
                    }
                    "乙", "丙" -> {
                        desc = "向首為【$pName】。水法大忌：巽方出水為八煞黃泉（大凶，官司口舌、火災損丁）；巽方來水則吉。"
                        isDanger = true
                        badge = "大忌巽方破局"
                    }
                    "巽" -> {
                        desc = "向首為【$pName】。楊公水法：見乙方或丙方來水為【救貧黃泉水】（大吉，利科名文彩、發福綿長）。"
                        isJiuPin = true
                        badge = "救貧大吉向首"
                    }
                    "甲", "癸" -> {
                        desc = "向首為【$pName】。水法大忌：艮方出水為黃泉殺水（主殘疾退財、官非口舌）。"
                        isDanger = true
                        badge = "大忌艮水出煞"
                    }
                    "艮" -> {
                        desc = "向首為【$pName】。楊公水法：見甲方或癸方來水為【救貧催官水】（大吉，少男發達、巨富顯達）。"
                        isJiuPin = true
                        badge = "救貧大吉向首"
                    }
                    "辛", "壬" -> {
                        desc = "向首為【$pName】。水法大忌：乾方出水為破軍黃泉（犯之主吐血、橫禍、少亡破敗）。"
                        isDanger = true
                        badge = "大忌乾方破局"
                    }
                    "乾" -> {
                        desc = "向首為【$pName】。楊公水法：見辛方或壬方來水為【救貧黃泉水】（大吉，長房顯耀、金玉滿堂）。"
                        isJiuPin = true
                        badge = "救貧大吉向首"
                    }
                    else -> {
                        desc = "向首為【$pName】。不屬八路黃泉正煞位，水法依楊公三合十二長生（養生冠臨旺，生來會旺、拔水入庫）消納即吉。"
                        badge = "正針純清納水"
                    }
                }
            }
            AppLanguage.JA -> {
                badge = "正針合度純清"
                when (name) {
                    "庚", "丁" -> {
                        desc = "向首：【$pName】。水法禁忌：坤方の出水は殺人黄泉の大煞（人命損失・破産）。坤方からの来水は逆に催官の吉水。"
                        isDanger = true
                        badge = "坤方出水は厳禁"
                    }
                    "坤" -> {
                        desc = "向首：【$pName】。楊公水法：庚方または丁方の来水は【救貧黄泉水】（大吉、家運隆盛・昇進栄達）。"
                        isJiuPin = true
                        badge = "救貧大吉の向首"
                    }
                    "乙", "丙" -> {
                        desc = "向首：【$pName】。水法禁忌：巽方の出水は八煞黄泉（大凶、訴訟争議・火災散財）。巽方からの来水は吉。"
                        isDanger = true
                        badge = "巽方出水は厳禁"
                    }
                    "巽" -> {
                        desc = "向首：【$pName】。楊公水法：乙方または丙方の来水は【救貧黄泉水】（大吉、学問文彩・繁栄長久）。"
                        isJiuPin = true
                        badge = "救貧大吉の向首"
                    }
                    "甲", "癸" -> {
                        desc = "向首：【$pName】。水法禁忌：艮方の出水は黄泉殺水（障がいや財産損失・訴訟口舌）。"
                        isDanger = true
                        badge = "艮方出水は厳禁"
                    }
                    "艮" -> {
                        desc = "向首：【$pName】。楊公水法：甲方または癸方の来水は【救貧催官水】（大吉、子孫発展・巨富顕達）。"
                        isJiuPin = true
                        badge = "救貧大吉の向首"
                    }
                    "辛", "壬" -> {
                        desc = "向首：【$pName】。水法禁忌：乾方の出水は破軍黄泉（吐血・不慮の事故・衰退）。"
                        isDanger = true
                        badge = "乾方出水は厳禁"
                    }
                    "乾" -> {
                        desc = "向首：【$pName】。楊公水法：辛方または壬方の来水は【救貧黄泉水】（大吉、長男隆盛・財産豊か）。"
                        isJiuPin = true
                        badge = "救貧大吉の向首"
                    }
                    else -> {
                        desc = "向首：【$pName】。八路黄泉の煞位に非ず、三合十二長生水法に従えば吉。"
                        badge = "正針純清納水"
                    }
                }
            }
            AppLanguage.KO -> {
                badge = "정침합도순청"
                when (name) {
                    "庚", "丁" -> {
                        desc = "향두: 【$pName】. 수법 대기: 곤방 출수는 살인황천대살(인명 손실, 재산 파탄). 곤방 내수는 최관수."
                        isDanger = true
                        badge = "곤방 출수 엄금"
                    }
                    "坤" -> {
                        desc = "향두: 【$pName】. 양공수법: 경방이나 정방의 내수는 【구빈황천수】(대길, 가운 융성, 관직 상승)."
                        isJiuPin = true
                        badge = "구빈대길 향두"
                    }
                    "乙", "丙" -> {
                        desc = "향두: 【$pName】. 수법 대기: 손방 출수는 팔살황천(대흉, 관재구설, 화재 손실)."
                        isDanger = true
                        badge = "손방 출수 엄금"
                    }
                    "巽" -> {
                        desc = "향두: 【$pName】. 양공수법: 을방이나 병방의 내수는 【구빈황천수】(대길, 학문 발전, 번영 지속)."
                        isJiuPin = true
                        badge = "구빈대길 향두"
                    }
                    "甲", "癸" -> {
                        desc = "향두: 【$pName】. 수법 대기: 간방 출수는 황천살수(신체 손상, 재산 감소)."
                        isDanger = true
                        badge = "간방 출수 엄금"
                    }
                    "艮" -> {
                        desc = "향두: 【$pName】. 양공수법: 갑방이나 계방의 내수는 【구빈최관수】(대길, 자손 번창, 거부 현달)."
                        isJiuPin = true
                        badge = "구빈대길 향두"
                    }
                    "辛", "壬" -> {
                        desc = "향두: 【$pName】. 수법 대기: 건방 출수는 파군황천(불의의 사고, 가운 쇠퇴)."
                        isDanger = true
                        badge = "건방 출수 엄금"
                    }
                    "乾" -> {
                        desc = "향두: 【$pName】. 양공수법: 신방이나 임방의 내수는 【구빈황천수】(대길, 장남 출세, 재물 풍족)."
                        isJiuPin = true
                        badge = "구빈대길 향두"
                    }
                    else -> {
                        desc = "향두: 【$pName】. 팔로황천 살위에 속하지 않으며, 십이장생 수법에 따르면 길함."
                        badge = "정침순청납수"
                    }
                }
            }
            AppLanguage.VI -> {
                badge = "Chính Châm Hợp Độ"
                when (name) {
                    "庚", "丁" -> {
                        desc = "Hướng thủ: 【$pName】. Đại kỵ thủy pháp: Khôn phương xuất thủy phạm Sát Nhân Hoàng Tuyền (tổn thất nhân đinh, hao tán điền sản); nếu có nước Khôn phương chảy đến lại là Thôi Quan Thủy."
                        isDanger = true
                        badge = "Kỵ Khôn Thủy Thoát"
                    }
                    "坤" -> {
                        desc = "Hướng thủ: 【$pName】. Dương Công thủy pháp: Nước phương Canh hoặc Đinh lại là 【Cứu Bần Hoàng Tuyền Thủy】 (Đại cát, nhân hưng tài vượng)."
                        isJiuPin = true
                        badge = "Cứu Bần Đại Cát Hướng"
                    }
                    "乙", "丙" -> {
                        desc = "Hướng thủ: 【$pName】. Đại kỵ thủy pháp: Tốn phương xuất thủy là Bát Sát Hoàng Tuyền (đại hung, kiện tụng thị phi, hỏa tai)."
                        isDanger = true
                        badge = "Kỵ Tốn Phương Thoát"
                    }
                    "巽" -> {
                        desc = "Hướng thủ: 【$pName】. Dương Công thủy pháp: Nước Ất hoặc Bính lại là 【Cứu Bần Hoàng Tuyền Thủy】 (Đại cát, văn chương khoa cử)."
                        isJiuPin = true
                        badge = "Cứu Bần Đại Cát Hướng"
                    }
                    "甲", "癸" -> {
                        desc = "Hướng thủ: 【$pName】. Đại kỵ thủy pháp: Cấn phương xuất thủy là Hoàng Tuyền Sát Thủy (tật bệnh hao tài)."
                        isDanger = true
                        badge = "Kỵ Cấn Thủy Thoát"
                    }
                    "艮" -> {
                        desc = "Hướng thủ: 【$pName】. Dương Công thủy pháp: Nước Giáp hoặc Quý lại là 【Cứu Bần Thôi Quan Thủy】 (Đại cát, phú quý vinh hoa)."
                        isJiuPin = true
                        badge = "Cứu Bần Đại Cát Hướng"
                    }
                    "辛", "壬" -> {
                        desc = "Hướng thủ: 【$pName】. Đại kỵ thủy pháp: Càn phương xuất thủy là Phá Quân Hoàng Tuyền (tai họa bất ngờ, suy bại)."
                        isDanger = true
                        badge = "Kỵ Càn Phương Thoát"
                    }
                    "乾" -> {
                        desc = "Hướng thủ: 【$pName】. Dương Công thủy pháp: Nước Tân hoặc Nhâm lại là 【Cứu Bần Hoàng Tuyền Thủy】 (Đại cát, kim ngọc mãn đường)."
                        isJiuPin = true
                        badge = "Cứu Bần Đại Cát Hướng"
                    }
                    else -> {
                        desc = "Hướng thủ: 【$pName】. Không thuộc Bát Lộ Hoàng Tuyền sát vị, nạp thủy theo Thập Nhị Trường Sinh ắt cát."
                        badge = "Chính Châm Thuần Thanh"
                    }
                }
            }
            AppLanguage.TH -> {
                badge = "ทิศตรงระเบียบมงคล"
                when (name) {
                    "庚", "丁" -> {
                        desc = "ทิศหันหน้า: 【$pName】 ข้อห้ามใหญ่: น้ำไหลออกทิศคุนคือมหาเคราะห์หวงเฉวียนทำลายวงศ์ตระกูล แต่น้ำไหลเข้ากลับส่งเสริมบารมี"
                        isDanger = true
                        badge = "ห้ามน้ำออกทิศคุน"
                    }
                    "坤" -> {
                        desc = "ทิศหันหน้า: 【$pName】 น้ำไหลเข้าทิศเกิ้งหรือติงคือน้ำมงคลปลดหนี้หยางกง นำความมั่งคั่งลาภยศ"
                        isJiuPin = true
                        badge = "ทิศมงคลปลดหนี้"
                    }
                    "乙", "丙" -> {
                        desc = "ทิศหันหน้า: 【$pName】 ข้อห้ามใหญ่: น้ำไหลออกทิศซวิ่นคือเคราะห์หวงเฉวียนแปดพิฆาต ระวังคดีความและอัคคีภัย"
                        isDanger = true
                        badge = "ห้ามน้ำออกทิศซวิ่น"
                    }
                    "巽" -> {
                        desc = "ทิศหันหน้า: 【$pName】 น้ำไหลเข้าทิศอี้หรือปิ่งคือน้ำมงคลปลดหนี้หยางกง เสริมการศึกษาและรุ่งเรืองยาวนาน"
                        isJiuPin = true
                        badge = "ทิศมงคลปลดหนี้"
                    }
                    "甲", "癸" -> {
                        desc = "ทิศหันหน้า: 【$pName】 ข้อห้ามใหญ่: น้ำไหลออกทิศเกิ้นคือน้ำพิฆาตหวงเฉวียน เสียทรัพย์สินและเกิดคดีความ"
                        isDanger = true
                        badge = "ห้ามน้ำออกทิศเกิ้น"
                    }
                    "艮" -> {
                        desc = "ทิศหันหน้า: 【$pName】 น้ำไหลเข้าทิศเจี่ยหรือกุ่ยคือน้ำมงคลหยางกง เสริมลูกหลานเจริญก้าวหน้า"
                        isJiuPin = true
                        badge = "ทิศมงคลปลดหนี้"
                    }
                    "辛", "壬" -> {
                        desc = "ทิศหันหน้า: 【$pName】 ข้อห้ามใหญ่: น้ำไหลออกทิศเฉียนคือน้ำผัวจวินหวงเฉวียน เกิดอุบัติเหตุไม่คาดฝัน"
                        isDanger = true
                        badge = "ห้ามน้ำออกทิศเฉียน"
                    }
                    "乾" -> {
                        desc = "ทิศหันหน้า: 【$pName】 น้ำไหลเข้าทิศซินหรือเหรินคือน้ำมงคลปลดหนี้ นำพาความมั่งคั่งสมบูรณ์"
                        isJiuPin = true
                        badge = "ทิศมงคลปลดหนี้"
                    }
                    else -> {
                        desc = "ทิศหันหน้า: 【$pName】 ไม่ติดเคราะห์แปดหวงเฉวียน จัดน้ำตามวิธีสิบสองระยะเพื่อความมงคล"
                        badge = "น้ำบริสุทธิ์มงคล"
                    }
                }
            }
            AppLanguage.ID -> {
                badge = "Jarum Lurus Murni"
                when (name) {
                    "庚", "丁" -> {
                        desc = "Menghadap: [$pName]. Tabu Besar: Air keluar ke arah Kun adalah petaka Huangquan yang fatal. Aliran masuk dari Kun membawa berkah."
                        isDanger = true
                        badge = "Hindari Air Keluar Kun"
                    }
                    "坤" -> {
                        desc = "Menghadap: [$pName]. Aturan Yang Gong: Aliran masuk dari Geng atau Ding adalah Air Penyelamat Kemiskinan (Sangat Baik, makmur dan sukses)."
                        isJiuPin = true
                        badge = "Hadap Selamatkan Kemiskinan"
                    }
                    "乙", "丙" -> {
                        desc = "Menghadap: [$pName]. Tabu Besar: Air keluar ke arah Xun adalah Huangquan Delapan Sha (pertikaian, kebakaran)."
                        isDanger = true
                        badge = "Hindari Air Keluar Xun"
                    }
                    "巽" -> {
                        desc = "Menghadap: [$pName]. Aturan Yang Gong: Aliran masuk dari Yi atau Bing adalah Air Penyelamat Kemiskinan (Sangat Baik, sukses akademis)."
                        isJiuPin = true
                        badge = "Hadap Selamatkan Kemiskinan"
                    }
                    "甲", "癸" -> {
                        desc = "Menghadap: [$pName]. Tabu Besar: Air keluar ke arah Gen adalah Air Pembunuh Huangquan (kerugian finansial)."
                        isDanger = true
                        badge = "Hindari Air Keluar Gen"
                    }
                    "艮" -> {
                        desc = "Menghadap: [$pName]. Aturan Yang Gong: Aliran masuk dari Jia atau Gui adalah Air Promosi (Sangat Baik, anak cucu makmur)."
                        isJiuPin = true
                        badge = "Hadap Selamatkan Kemiskinan"
                    }
                    "辛", "壬" -> {
                        desc = "Menghadap: [$pName]. Tabu Besar: Air keluar ke arah Qian adalah Po Jun Huangquan (kerugian mendadak)."
                        isDanger = true
                        badge = "Hindari Air Keluar Qian"
                    }
                    "乾" -> {
                        desc = "Menghadap: [$pName]. Aturan Yang Gong: Aliran masuk dari Xin atau Ren adalah Air Penyelamat Kemiskinan (Sangat Baik, rezeki berlimpah)."
                        isJiuPin = true
                        badge = "Hadap Selamatkan Kemiskinan"
                    }
                    else -> {
                        desc = "Menghadap: [$pName]. Tidak berada di zona tabu Delapan Jalan Huangquan; ikuti metode dua belas fase air untuk kebaikan."
                        badge = "Air Murni Menguntungkan"
                    }
                }
            }
            else -> {
                badge = "正针合度纯清"
                when (name) {
                    "庚", "丁" -> {
                        desc = "向首为【${name}山向】。水法大忌：坤方出水为杀人大黄泉（损人丁、伤小口、败退产业）；若坤方见来水反为催官水。"
                        isDanger = true
                        badge = "大忌坤水破局"
                    }
                    "坤" -> {
                        desc = "向首为【坤向】。杨公水法：见庚方或丁方来水为【救贫黄泉水】（大吉，人兴财旺、催官进禄）；最忌此两方水直流破局。"
                        isJiuPin = true
                        badge = "救贫大吉向首"
                    }
                    "乙", "丙" -> {
                        desc = "向首为【${name}山向】。水法大忌：巽方出水为八煞黄泉（大凶，官司口舌、火灾损丁）；巽方来水则吉。"
                        isDanger = true
                        badge = "大忌巽方破局"
                    }
                    "巽" -> {
                        desc = "向首为【巽向】。杨公水法：见乙方或丙方来水为【救贫黄泉水】（大吉，利科名文彩、发福绵长）。"
                        isJiuPin = true
                        badge = "救贫大吉向首"
                    }
                    "甲", "癸" -> {
                        desc = "向首为【${name}山向】。水法大忌：艮方出水为黄泉杀水（主残疾退财、官非口舌）。"
                        isDanger = true
                        badge = "大忌艮水出煞"
                    }
                    "艮" -> {
                        desc = "向首为【艮向】。杨公水法：见甲方或癸方来水为【救贫催官水】（大吉，少男发达、巨富显达）。"
                        isJiuPin = true
                        badge = "救贫大吉向首"
                    }
                    "辛", "壬" -> {
                        desc = "向首为【${name}山向】。水法大忌：乾方出水为破军黄泉（犯之主吐血、横祸、少亡破败）。"
                        isDanger = true
                        badge = "大忌乾方破局"
                    }
                    "乾" -> {
                        desc = "向首为【乾向】。杨公水法：见辛方或壬方来水为【救贫黄泉水】（大吉，长房显耀、金玉满堂）。"
                        isJiuPin = true
                        badge = "救贫大吉向首"
                    }
                    else -> {
                        desc = "向首为【${name}山向】。不属八路黄泉正煞位，水法依杨公三合十二长生（养生冠临旺，生来会旺、拔水入库）消纳即吉。"
                        badge = "正针纯清纳水"
                    }
                }
            }
        }

        desc += "\n\n" + localizedHuangQuanSourceNote(lang)

        return HuangQuanWaterResult(
            facingMountain = name,
            waterDesc = desc,
            isJiuPin = isJiuPin,
            isDanger = isDanger,
            badgeText = badge
        )
    }

    fun resolveBaSha(sitting: Mountain24Item): BaShaResult {
        val palace = sitting.palace
        val lang = LocalizationManager.shared.effectiveLanguage
        val info = baShaMap[palace] ?: Quad("辰", "东南", "逢坐山煞曜方，不可有尖峰怪石冲穴。")

        val remedy: String
        val lore: String
        when (lang) {
            AppLanguage.EN -> {
                remedy = "Sha Neutralization: If power towers or sharp wall edges appear in this direction, hang a Mountain-Sea Mirror or Five Sacred Mountains Talisman to shield."
                lore = "Sitting Mountain Sha in ${info.dir} (${info.zhi}). Strictly avoid high-voltage towers, sharp rocks, or stagnant water in this sector."
            }
            AppLanguage.ZH_HANT -> {
                remedy = "消砂法則：該方若見高壓電線塔、壁刀尖角，急需懸掛山海鎮或五嶽真形圖予以遮擋化解。"
                val hantLore = mapOf(
                    "坎" to "坎卦三山（壬／子／癸）煞在辰位。辰方最忌見高壓電塔、尖角怪石或破敗死水，犯之主腎疾、下元損丁。",
                    "坤" to "坤卦三山（未／坤／申）煞在卯位。忌正東見衝射，主脾胃敗壞、老母傷損。",
                    "震" to "震卦三山（甲／卯／乙）煞在申位。忌西南申方突兀尖峰，主長房傷殘、足疾官非。",
                    "巽" to "巽卦三山（辰／巽／巳）煞在酉位。忌正西酉金直衝，主婦女產厄、風聲是非。",
                    "乾" to "乾卦三山（戌／乾／亥）煞在午位。忌正南離火烈焰反克天門，主心腦血光、損老翁。",
                    "兑" to "兌卦三山（庚／酉／辛）煞在巳位。忌東南巳火傷金，主少女不利、肺疾吐血。",
                    "艮" to "艮卦三山（丑／艮／寅）煞在寅位。忌東北見破山絕澗，損幼子少男。",
                    "离" to "離卦三山（丙／午／丁）煞在亥位。忌西北亥水衝射，主眼疾暗昧、中房受制。"
                )
                lore = hantLore[palace] ?: info.lore
            }
            AppLanguage.JA -> {
                remedy = "消砂の法：該当方向に高圧電線塔や尖角がある場合、山海鎮鏡や五岳真形図を掲げて化解します。"
                lore = "${palace}卦の坐山八煞は${info.dir}(${info.zhi})方位にあります。高圧線鉄塔や尖った岩石、淀んだ死水を厳重に避けてください。"
            }
            AppLanguage.KO -> {
                remedy = "소사 법칙: 해당 방위에 고압 전신주나 벽의 뾰족한 각이 보이면 산해진경이나 오악진형도를 걸어 차단 해소합니다."
                lore = "${palace}괘의 좌산팔살은 ${info.dir}(${info.zhi}) 방위에 해당합니다. 고압선탑이나 뾰족한 바위, 탁한 물을 엄격히 피하세요."
            }
            AppLanguage.VI -> {
                remedy = "Quy tắc Tiêu Sa: Nếu phương vị này thấy cột điện cao thế, góc nhọn tường chém, lập tức treo gương Sơn Hải Trấn để hóa giải."
                lore = "Tọa sơn Bát Sát của quẻ $palace tại ${info.dir} (${info.zhi}). Nghiêm cấm thấy cột điện cao áp, mỏm đá nhọn hay vũng nước tù đọng."
            }
            AppLanguage.TH -> {
                remedy = "วิธีแก้สลายเคราะห์: หากทิศนี้มีเสาไฟฟ้าแรงสูงหรือมุมแหลมพุ่งชน ควรแขวนกระจกซานไห่เจิ้นหรือยันต์ห้าขุนเขาเพื่อสะท้อนสลายพลังร้าย"
                lore = "ทิศเคราะห์แปดพิฆาตของขุนเขาหลังพิงอยู่ที่ ${info.dir} (${info.zhi}) ระวังเสาไฟฟ้า หน้าผาหินแหลม หรือน้ำเน่าเสีย"
            }
            AppLanguage.ID -> {
                remedy = "Netralisasi Sha: Jika terdapat tiang listrik tegangan tinggi atau sudut tajam dinding di arah ini, gantung cermin Shan Hai Zhen atau jimat pelindung."
                lore = "Sha Posisi Duduk berada di ${info.dir} (${info.zhi}). Hindari menara listrik, batu tajam, atau genangan air kotor di sektor ini."
            }
            else -> {
                remedy = "消砂法则：该方若见高压电线塔、壁刀尖角，急需悬挂山海镇或五岳真形图予以遮挡化解。"
                lore = info.lore
            }
        }

        return BaShaResult(
            sittingMountain = sitting.name,
            sittingPalace = palace,
            shaZhi = info.zhi,
            shaDir = info.dir,
            lore = lore + "\n\n" + localizedBaShaSourceNote(lang),
            remedy = remedy
        )
    }

    fun resolveWaterMethod(sitting: Mountain24Item, facing: Mountain24Item): List<SanHeWaterItem> {
        val phases = ChangShengPhase.values()
        val list = mutableListOf<SanHeWaterItem>()

        val branchByMountain = mapOf(
            "壬" to 0, "子" to 0,
            "癸" to 1, "丑" to 1,
            "艮" to 2, "寅" to 2,
            "甲" to 3, "卯" to 3,
            "乙" to 4, "辰" to 4,
            "巽" to 5, "巳" to 5,
            "丙" to 6, "午" to 6,
            "丁" to 7, "未" to 7,
            "坤" to 8, "申" to 8,
            "庚" to 9, "酉" to 9,
            "辛" to 10, "戌" to 10,
            "乾" to 11, "亥" to 11
        )
        val bureauStart = when (sitting.name) {
            "申", "子", "辰", "坤", "壬", "乙" -> 8
            "亥", "卯", "未", "乾", "甲", "丁" -> 11
            "寅", "午", "戌", "艮", "丙", "辛" -> 2
            else -> 5
        }

        val mData = Mountain24Data.mountains
        for ((idx, m) in mData.withIndex()) {
            val targetBranch = branchByMountain[m.name] ?: 0
            val phaseOffset = (targetBranch - bureauStart + 12) % 12
            val p = phases[phaseOffset]
            val isHQ = (facing.name == "庚" && m.name == "坤") || (facing.name == "丁" && m.name == "坤") ||
                       (facing.name == "乙" && m.name == "巽") || (facing.name == "丙" && m.name == "巽") ||
                       (facing.name == "甲" && m.name == "艮") || (facing.name == "癸" && m.name == "艮") ||
                       (facing.name == "辛" && m.name == "乾") || (facing.name == "壬" && m.name == "乾")
            list.add(SanHeWaterItem(id = idx, mountainName = m.name, phase = p, isHuangQuanSha = isHQ))
        }
        return list
    }
}
