package com.example.yiijingcompass.model

import java.util.Calendar
import java.util.Date

/**
 * 玄空九宫飞星排盘引擎 (XuanKong Flying Stars Engine)
 * 具备三元九运、下卦/替卦、旺山旺向/上山下水/双星到向/双星到坐、父母三般卦、七星打劫与八国语言经典断语及古籍引证
 */

fun flyingStarsTraditionalSourceNote(language: AppLanguage): String {
    return when (language) {
        AppLanguage.EN ->
            "Classical sources: the Purple-White Formula says, ‘When Five Yellow overlaps, illness and calamity arrive; when Two and Five combine, illness is encountered.’ The traditional Xuan-Kong mountain/facing-star formula preserves the wording ‘Wang Shan Wang Xiang prospers people and wealth; Double Stars at Facing prospers wealth but not people; Double Stars at Sitting prospers people but not wealth; Shang Shan Xia Shui brings loss of wealth and people’ (transmitted versions differ). These wealth, people and health statements are traditional symbolic readings, not medical or financial predictions."
        AppLanguage.ZH_HANT ->
            "古籍出處：《紫白訣》云：「五黃重疊，災疾並臨；二五交加，罹疾病。」玄空山向星訣（傳本有異文）保留「到山到向，旺丁旺財；雙星到向，旺財不旺丁；雙星到坐，旺丁不旺財；上山下水，敗財損丁」等原文。上文財丁、健康語句屬傳統文化象徵解讀，不是醫療診斷或財務預測。"
        AppLanguage.JA ->
            "出典：『紫白訣』「五黄が重なれば災疾が臨み、二五が交われば病にかかる」。玄空山向星訣（伝本に異文）は「到山到向は財と人が栄え、双星到向は財、双星到坐は人、上山下水は財と人を損なう」と伝えます。財・人・健康の表現は伝統文化上の象徴であり、医学的・金融的予測ではありません。"
        AppLanguage.KO ->
            "출처: 《자백결》 ‘오황이 겹치면 재질이 임하고 이오가 교차하면 병이 따른다’. 전통 현공 산향성결은 ‘도산도향 왕정왕재, 쌍성도향 왕재불왕정, 쌍성도좌 왕정불왕재, 동산하수 손재손정’으로 전합니다(전본 이문). 재물·사람·건강 표현은 전통문화의 상징이며 의학적·재무 예측이 아닙니다."
        AppLanguage.VI ->
            "Nguồn cổ: 《Tử Bạch Quyết》 ghi ‘Ngũ Hoàng chồng lên thì tai bệnh đến; Nhị Ngũ giao nhau thì gặp bệnh’. Quyết tinh sơn hướng Huyền Không truyền câu ‘đáo sơn đáo hướng vượng đinh vượng tài; song tinh đáo hướng vượng tài bất vượng đinh; song tinh đáo tọa vượng đinh bất vượng tài; thượng sơn hạ thủy bại tài tổn đinh’ (bản truyền có dị văn). Đây là biểu tượng truyền thống, không phải dự đoán y khoa hay tài chính."
        AppLanguage.TH ->
            "ที่มาโบราณ: 《จื่อไป๋เจวี๋ย》กล่าวว่า ‘ดาวห้าเหลืองซ้อน ภัยและโรคมาเยือน; สองกับห้าประจัน พบโรคภัย’ ตำราดาวภูเขา-ทิศเสวียนคงสืบคำว่า ‘ถึงเขาถึงทิศรุ่งเรืองคนและทรัพย์; ดาวคู่สู่หน้ารุ่งเรืองทรัพย์แต่ไม่คน; ดาวคู่สู่หลังรุ่งเรืองคนแต่ไม่ทรัพย์; ขึ้นเขาลงน้ำเสียทรัพย์เสียคน’ (ตำราต่างกัน) ถ้อยคำเรื่องทรัพย์ คน และสุขภาพเป็นสัญลักษณ์ดั้งเดิม ไม่ใช่การพยากรณ์ทางการแพทย์หรือการเงิน"
        AppLanguage.ID ->
            "Sumber klasik: 《Zi Bai Jue》 menyebut, ‘Saat Lima Kuning bertumpuk, penyakit dan bencana datang; saat Dua dan Lima berpapasan, penyakit ditemui.’ Rumus bintang gunung/hadap Xuan-Kong mempertahankan ungkapan ‘makmurkan orang dan harta; bintang ganda di hadap memakmurkan harta, bintang ganda di duduk memakmurkan orang, Shang Shan Xia Shui merusak harta dan orang’ (versi tradisi berbeda). Ungkapan rezeki, keluarga, dan kesehatan adalah simbol tradisional, bukan prediksi medis atau keuangan."
        AppLanguage.ZH_HANS, AppLanguage.AUTO ->
            "古籍出处：《紫白诀》云：“五黄重叠，灾疾并临；二五交加，罹疾病。”玄空山向星诀（传本有异文）保留“到山到向，旺丁旺财；双星到向，旺财不旺丁；双星到坐，旺丁不旺财；上山下水，败财损丁”等原文。上文财丁、健康语句属于传统文化象征解读，不是医疗诊断或财务预测。"
    }
}

data class PeriodMeta(
    val period: Int,
    val yuan: String,
    val trigram: String,
    val starName: String,
    val element: String,
    val startYear: Int,
    val endYear: Int,
    val isCurrent: Boolean,
    val label: String
)

data class PalaceCell(
    val id: Int, // 0..8 (0:坎, 1:坤, 2:震, 3:巽, 4:中, 5:乾, 6:兑, 7:艮, 8:离)
    val palaceName: String,
    val trigram: String,
    val direction: String,
    val periodStar: Int,
    val activePeriod: Int,
    val mountainStar: Int,
    val facingStar: Int,
    val isCenter: Boolean,
    val isWangMountain: Boolean,
    val isWangFacing: Boolean,
    val isShaWuHuang: Boolean,
    val isShaErHei: Boolean
) {
    val sittingStar: Int get() = mountainStar
    val guaName: String get() = trigram
    val element: String
        get() = when (id) {
            0 -> "水"
            1, 4, 7 -> "土"
            2, 3 -> "木"
            5, 6 -> "金"
            8 -> "火"
            else -> "土"
        }

    val localizedElement: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN -> when (element) {
                "水" -> "Water"
                "木" -> "Wood"
                "火" -> "Fire"
                "土" -> "Earth"
                "金" -> "Metal"
                else -> element
            }
            AppLanguage.KO -> when (element) {
                "水" -> "수"
                "木" -> "목"
                "火" -> "화"
                "土" -> "토"
                "金" -> "금"
                else -> element
            }
            AppLanguage.VI -> when (element) {
                "水" -> "Thủy"
                "木" -> "Mộc"
                "火" -> "Hỏa"
                "土" -> "Thổ"
                "金" -> "Kim"
                else -> element
            }
            AppLanguage.TH -> when (element) {
                "水" -> "น้ำ"
                "木" -> "ไม้"
                "火" -> "ไฟ"
                "土" -> "ดิน"
                "金" -> "ทอง"
                else -> element
            }
            AppLanguage.ID -> when (element) {
                "水" -> "Air"
                "木" -> "Kayu"
                "火" -> "Api"
                "土" -> "Tanah"
                "金" -> "Logam"
                else -> element
            }
            AppLanguage.AUTO, AppLanguage.ZH_HANS, AppLanguage.ZH_HANT, AppLanguage.JA -> element
        }

    val hasEarthSha: Boolean get() = isShaWuHuang || isShaErHei

    private fun localizedEarthShaEvaluation(lang: AppLanguage): String {
        return when (lang) {
            AppLanguage.EN -> "Five Yellow/Two Black earth sha · Keep quiet and use a Metal remedy"
            AppLanguage.ZH_HANT -> "五黃／二黑土煞 · 宜靜安金屬化解"
            AppLanguage.JA -> "五黄・二黒土煞 · 静かにして金属で化解"
            AppLanguage.KO -> "오황·이흑 토살 · 조용히 하고 금속으로 화해"
            AppLanguage.VI -> "Thổ sát Ngũ Hoàng/Nhị Hắc · Giữ tĩnh và dùng kim loại hóa giải"
            AppLanguage.TH -> "เคราะห์ดินดาวห้าเหลือง/สองดำ · รักษาความสงบและใช้โลหะแก้"
            AppLanguage.ID -> "Sha tanah 5-Kuning/2-Hitam · Jaga ketenangan dan gunakan logam"
            AppLanguage.AUTO, AppLanguage.ZH_HANS -> "五黄／二黑土煞 · 宜静安金属化解"
        }
    }

    val localizedEvaluation: String
        get() = baseLocalizedEvaluation+"\n\n"+TraditionalEvidenceCatalog.text(TraditionalEvidenceCatalog.pair(mountainStar,facingStar,localizedPalaceName+" · "+LocalizationManager.instance.t("xkd_pair_natal")))

    val baseLocalizedEvaluation: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            if (hasEarthSha) return localizedEarthShaEvaluation(lang)
            if(setOf(mountainStar,facingStar)==setOf(1,6))return LocalizationManager.instance.t("ref_pair_one_six")
            return when (lang) {
                AppLanguage.EN -> {
                    if (mountainStar == activePeriod && facingStar == activePeriod) "Double Current Stars · Wealth and people prosper"
                    else if (facingStar == activePeriod) "Current Wealth Star at Facing · Open and receive qi"
                    else if (mountainStar == activePeriod) "Current Mountain Star returns · People prosper"
                    else if (isShaWuHuang || isShaErHei) "Five Yellow and Two Black clash · Calm and use Metal remedy"
                    else if ((mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1)) "One–Six harmony · Clear Water and Wood nourish Wenchang"
                    else "Mixed fortune · Balanced position"
                }
                AppLanguage.ZH_HANT -> {
                    if (mountainStar == activePeriod && facingStar == activePeriod) "當運雙星會聚 · 財丁兩旺"
                    else if (facingStar == activePeriod) "當旺財星照臨 · 宜開門納氣"
                    else if (mountainStar == activePeriod) "當運丁星歸位 · 人丁興旺"
                    else if (isShaWuHuang || isShaErHei) "五黃二黑交加 · 宜靜安銅化解"
                    else if ((mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1)) "一六共宗 · 水清木秀催文昌"
                    else "吉凶相參 · 平和之位"
                }
                AppLanguage.JA -> {
                    if (mountainStar == activePeriod && facingStar == activePeriod) "当運の双星会聚 · 財丁両旺"
                    else if (facingStar == activePeriod) "当旺の財星照臨 · 開門納気に適す"
                    else if (mountainStar == activePeriod) "当運の丁星帰位 · 子孫繁栄"
                    else if (isShaWuHuang || isShaErHei) "五黄二黒交加 · 静寂と銅器で化解"
                    else if ((mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1)) "一六共宗 · 文昌栄達を促す"
                    else "吉凶相半 · 平和の気場"
                }
                AppLanguage.KO -> {
                    if (mountainStar == activePeriod && facingStar == activePeriod) "당운 쌍성 회취 · 재물과 자손 모두 번창"
                    else if (facingStar == activePeriod) "당왕 재성 조림 · 문을 열어 기를 받음"
                    else if (mountainStar == activePeriod) "당운 정성 귀위 · 자손 번창"
                    else if (isShaWuHuang || isShaErHei) "오황 이흑 교가 · 고요히 동기로 화해"
                    else if ((mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1)) "일육공종 · 문창 학업 성취"
                    else "길흉 상참 · 평화로운 방위"
                }
                AppLanguage.VI -> {
                    if (mountainStar == activePeriod && facingStar == activePeriod) "Đương vận song tinh hội tụ · Tài đinh lưỡng vượng"
                    else if (facingStar == activePeriod) "Đương vượng tài tinh chiếu lâm · Lợi mở cửa nạp khí"
                    else if (mountainStar == activePeriod) "Đương vận đinh tinh quy vị · Nhân đinh hưng vượng"
                    else if (isShaWuHuang || isShaErHei) "Ngũ Hoàng Nhị Hắc giao gia · Nên tĩnh an đồng hóa giải"
                    else if ((mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1)) "Nhất Lục cộng tông · Văn Xương học nghiệp đại cát"
                    else "Cát hung tương tham · Vị trí bình hòa"
                }
                AppLanguage.TH -> {
                    if (mountainStar == activePeriod && facingStar == activePeriod) "สองดาวมงคลชุมนุม · ร่ำรวยและลูกหลานรุ่งเรือง"
                    else if (facingStar == activePeriod) "ดาวโชคลาภส่องสว่าง · เปิดรับพลังงานมงคล"
                    else if (mountainStar == activePeriod) "ดาวบุญบารมีคืนตำแหน่ง · ลูกหลานเจริญรุ่งเรือง"
                    else if (isShaWuHuang || isShaErHei) "ดาวห้าเหลืองปะทะดาวสองดำ · รักษาความสงบใช้โลหะแก้"
                    else if ((mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1)) "หนึ่งหกเกื้อหนุน · ส่งเสริมสติปัญญาการเรียน"
                    else "ดีร้ายปะปน · ตำแหน่งสมดุลสงบ"
                }
                AppLanguage.ID -> {
                    if (mountainStar == activePeriod && facingStar == activePeriod) "Bintang Kembar Hadir · Kekayaan & keluarga makmur"
                    else if (facingStar == activePeriod) "Bintang Rezeki Menyinari · Sambut sirkulasi energi"
                    else if (mountainStar == activePeriod) "Bintang Manusia Kembali · Keturunan berkembang pesat"
                    else if (isShaWuHuang || isShaErHei) "Benturan 5 Kuning & 2 Hitam · Tenang & gunakan obat logam"
                    else if ((mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1)) "Harmoni Satu–Enam · Mendukung prestasi akademis"
                    else "Campuran peruntungan · Posisi seimbang"
                }
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> baseEvaluation
            }
        }

    val localizedPalaceName: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> {
                    val directionMap = mapOf(
                        "正北" to "North", "西南" to "Southwest", "正东" to "East", "东南" to "Southeast",
                        "中宫" to "Center", "西北" to "Northwest", "正西" to "West", "东北" to "Northeast", "正南" to "South"
                    )
                    var result = palaceName
                    for ((source, localized) in directionMap) {
                        result = result.replace(source, localized)
                    }
                    result
                }
                AppLanguage.ZH_HANT -> {
                    palaceName
                        .replace("东", "東")
                        .replace("兑", "兌")
                        .replace("离", "離")
                        .replace("宫", "宮")
                }
                AppLanguage.JA -> {
                    palaceName
                        .replace("东南", "南東")
                        .replace("西南", "南西")
                        .replace("东北", "北東")
                        .replace("西北", "北西")
                        .replace("东", "東")
                        .replace("兑", "兌")
                        .replace("离", "離")
                        .replace("宫", "宮")
                }
                AppLanguage.KO -> {
                    val koMap = mapOf(
                        "正北" to "정북", "西南" to "남서", "正东" to "정동", "东南" to "동남",
                        "中宫" to "중궁", "西北" to "북서", "正西" to "정서", "东北" to "북동", "正南" to "정남"
                    )
                    var result = palaceName
                    for ((source, localized) in koMap) {
                        result = result.replace(source, localized)
                    }
                    result
                }
                AppLanguage.VI -> {
                    val viMap = mapOf(
                        "正北" to "Chính Bắc", "西南" to "Tây Nam", "正东" to "Chính Đông", "东南" to "Đông Nam",
                        "中宫" to "Trung Cung", "西北" to "Tây Bắc", "正西" to "Chính Tây", "东北" to "Đông Bắc", "正南" to "Chính Nam"
                    )
                    var result = palaceName
                    for ((source, localized) in viMap) {
                        result = result.replace(source, localized)
                    }
                    result
                }
                AppLanguage.TH -> {
                    val thMap = mapOf(
                        "正北" to "ทิศเหนือ", "西南" to "ทิศตะวันตกเฉียงใต้", "正东" to "ทิศตะวันออก", "东南" to "ทิศตะวันออกเฉียงใต้",
                        "中宫" to "จุดศูนย์กลาง", "西北" to "ทิศตะวันตกเฉียงเหนือ", "正西" to "ทิศตะวันตก", "东北" to "ทิศตะวันออกเฉียงเหนือ", "正南" to "ทิศใต้"
                    )
                    var result = palaceName
                    for ((source, localized) in thMap) {
                        result = result.replace(source, localized)
                    }
                    result
                }
                AppLanguage.ID -> {
                    val idMap = mapOf(
                        "正北" to "Utara", "西南" to "Barat Daya", "正东" to "Timur", "东南" to "Tenggara",
                        "中宫" to "Pusat", "西北" to "Barat Laut", "正西" to "Barat", "东北" to "Timur Laut", "正南" to "Selatan"
                    )
                    var result = palaceName
                    for ((source, localized) in idMap) {
                        result = result.replace(source, localized)
                    }
                    result
                }
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> palaceName
            }
        }

    val evaluation: String
        get() = baseEvaluation + "\n\n" + flyingStarsTraditionalSourceNote(
            LocalizationManager.shared.effectiveLanguage
        )

    val baseEvaluation: String
        get() {
            if (hasEarthSha) return "五黄／二黑土煞 · 宜静安金属化解"
            if (mountainStar == activePeriod && facingStar == activePeriod) return "当运双星会聚 · 财丁两旺"
            if (facingStar == activePeriod) return "当旺财星照临 · 宜开门纳气"
            if (mountainStar == activePeriod) return "当运丁星归位 · 人丁兴旺"
            if ((mountainStar == 1 && facingStar == 6) || (mountainStar == 6 && facingStar == 1)) return "一六共宗 · 水清木秀催文昌"
            return "吉凶相参 · 平和之位"
        }
}

typealias XuanKongPalace = PalaceCell

data class XuanKongChart(
    val period: Int,
    val sittingMountain: String,
    val facingMountain: String,
    val patternType: String,
    val isSanBanGua: Boolean,
    val isQiXingDaJie: Boolean,
    val isTiGua: Boolean,
    val chartModeTitle: String,
    val palaces: List<PalaceCell>,
    val summaryAnalysis: String,
    val periodMeta: PeriodMeta,
    val patternKind:Int?=null
) {
    val patternDesc: String get() = summaryAnalysis

    val wealthAdvice: String
        get() = baseWealthAdvice + "\n\n" + wealthSourceNote

    val baseWealthAdvice: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            val wangPalace = palaces.firstOrNull { it.facingStar == period && !it.hasEarthSha }
            val nextStar = (period % 9) + 1
            val shengQiPalace = palaces.firstOrNull { !it.isCenter && it.facingStar == nextStar && !it.hasEarthSha }
                ?: palaces.firstOrNull { it.facingStar == nextStar && !it.hasEarthSha }
            val wenchangPalace = palaces.firstOrNull { !it.isCenter && ((it.mountainStar == 1 && it.facingStar == 4) || (it.mountainStar == 4 && it.facingStar == 1) || (it.mountainStar == 1 && it.facingStar == 6) || (it.mountainStar == 6 && it.facingStar == 1)) }

            val wangName = wangPalace?.localizedPalaceName ?: ""
            val wangCombo = wangPalace?.let { "${it.mountainStar}-${it.facingStar}" } ?: "$period"
            val sqName = shengQiPalace?.localizedPalaceName ?: ""
            val sqCombo = shengQiPalace?.let { "${it.mountainStar}-${it.facingStar}" } ?: "$nextStar"
            val wcName = wenchangPalace?.localizedPalaceName

            return when (lang) {
                AppLanguage.EN -> {
                    val wcNote = if (wcName != null) " Wenchang/Harmony star gathers at [$wcName]." else ""
                    "• Wealth & Prosperity: Current Period-$period facing star lands at [$wangName] (Star $wangCombo), and future Sheng-Qi Star $nextStar reaches [$sqName] (Star $sqCombo). Keep these sectors bright, open, or place moving water to activate wealth.$wcNote"
                }
                AppLanguage.ZH_HANT -> {
                    val wcNote = if (wcName != null) "另【$wcName】逢文昌吉星會聚，利書房策劃。" else ""
                    "• 催財旺位：當令${period}運向星飛臨【$wangName】（山向$wangCombo），生氣${nextStar}星到【$sqName】（山向$sqCombo），宜在此保持明堂開闊、安設動水或長明燈催旺財源。$wcNote"
                }
                AppLanguage.JA -> {
                    val wcNote = if (wcName != null) "また【$wcName】は文昌吉星が会聚し書斎に吉。" else ""
                    "• 催財旺位：当令${period}運の向星が【$wangName】（山向$wangCombo）に飛臨し、生気${nextStar}星が【$sqName】（山向$sqCombo）に到ります。採光や動水を設けて財気を催旺してください。$wcNote"
                }
                AppLanguage.KO ->
                    "• 재물 발복 방위: 당령 ${period}운 향성이 【$wangName】(산향 $wangCombo)에 비림하고 생기 ${nextStar}성이 【$sqName】(산향 $sqCombo)에 이르니, 채광을 밝히고 동수(물)를 배치하여 재원을 활성화하십시오."
                AppLanguage.VI ->
                    "• Cung kích tài: Hướng tinh đương vận $period bay tới 【$wangName】 (Sơn Hướng $wangCombo), sinh khí tinh $nextStar đáo 【$sqName】 (Sơn Hướng $sqCombo), nên mở thoáng, tăng ánh sáng hoặc đặt thủy động kích hoạt tài lộc."
                AppLanguage.TH ->
                    "• ตำแหน่งเรียกทรัพย์: ดาวหันประจำยุค $period สถิตที่ 【$wangName】 (ดาว $wangCombo) และดาวพลัง生气 $nextStar อยู่ที่ 【$sqName】 (ดาว $sqCombo) ควรเปิดโล่งรับแสงหรือตั้งน้ำพุกระตุ้นโชคลาภ"
                AppLanguage.ID ->
                    "• Sektor Rezeki: Bintang hadap periode $period berada di [$wangName] (Bintang $wangCombo) & bintang Sheng-Qi $nextStar di [$sqName] (Bintang $sqCombo); buka sirkulasi cahaya atau letakkan air mengalir untuk mengaktifkan rezeki."
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> {
                    val wcNote = if (wcName != null) "另【$wcName】逢文昌吉星会聚，利书房策划。" else ""
                    "• 催财旺位：当令${period}运向星飞临【$wangName】（山向$wangCombo），生气${nextStar}星到【$sqName】（山向$sqCombo），宜在此保持明堂开阔、安设动水或长明灯催旺财源。$wcNote"
                }
            }
        }

    val healthAdvice: String
        get() = baseHealthAdvice + "\n\n" + healthSourceNote

    val baseHealthAdvice: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            val clash25Palace = palaces.firstOrNull { (it.mountainStar == 2 && it.facingStar == 5) || (it.mountainStar == 5 && it.facingStar == 2) || (it.mountainStar == 5 && it.facingStar == 5) }
            val wuHuangPalace = palaces.firstOrNull { it.facingStar == 5 } ?: palaces.firstOrNull { it.mountainStar == 5 }
            val erHeiPalace = palaces.firstOrNull { it.facingStar == 2 } ?: palaces.firstOrNull { it.mountainStar == 2 }

            val wuName = wuHuangPalace?.localizedPalaceName ?: ""
            val wuCombo = wuHuangPalace?.let { "${it.mountainStar}-${it.facingStar}" } ?: "5"
            val erName = erHeiPalace?.localizedPalaceName ?: ""
            val erCombo = erHeiPalace?.let { "${it.mountainStar}-${it.facingStar}" } ?: "2"

            return when (lang) {
                AppLanguage.EN -> {
                    if (clash25Palace != null) {
                        "• Health & Sha Caution: Critical 2–5 / Double-5 Earth Sha converges at [${clash25Palace.localizedPalaceName}] (Star ${clash25Palace.mountainStar}-${clash25Palace.facingStar}), with 5-Yellow at [$wuName] and 2-Black at [$erName]. Keep quiet, avoid renovation or red items, and place a copper gourd or 6-coin Metal cure."
                    } else {
                        "• Health & Sha Caution: 5-Yellow Sha lands at [$wuName] (Star $wuCombo) and 2-Black Sickness Star at [$erName] (Star $erCombo). Avoid loud noise, drilling, or fire elements here; use copper/Metal ornaments to drain Earth Sha."
                    }
                }
                AppLanguage.ZH_HANT -> {
                    if (clash25Palace != null) {
                        "• 病符防煞：【${clash25Palace.localizedPalaceName}】逢山向${clash25Palace.mountainStar}-${clash25Palace.facingStar}二五交加/五黃疊臨重煞（五黃位【$wuName】、二黑位【$erName】），切忌動土裝修與紅紫火物，務必安放銅葫蘆或六帝錢洩土化煞。"
                    } else {
                        "• 病符防煞：五黃廉貞煞飛臨【$wuName】（山向$wuCombo），二黑病符星到【$erName】（山向$erCombo），此二宮宜靜不宜動，忌見紅火動土，宜掛銅葫蘆或六帝銅錢化洩凶性。"
                    }
                }
                AppLanguage.JA -> {
                    if (clash25Palace != null) {
                        "• 病符防煞：【${clash25Palace.localizedPalaceName}】に山向${clash25Palace.mountainStar}-${clash25Palace.facingStar}の二五交加・五黄重煞が集結（五黄【$wuName】・二黒【$erName】）。改修や赤色物を避け、銅瓢箪や六帝銭で土煞を泄化してください。"
                    } else {
                        "• 病符防煞：五黄廉貞煞が【$wuName】（山向$wuCombo）、二黒病符星が【$erName】（山向$erCombo）に飛臨。静寂を保ち、銅瓢箪や金属置物で凶気を化泄すると吉。"
                    }
                }
                AppLanguage.KO ->
                    "• 병부 방살: 오황살이 【$wuName】(산향 $wuCombo)에, 이흑 병부성이 【$erName】(산향 $erCombo)에 위치합니다. 공사와 붉은색 배치를 피하고 동호리병이나 육제전(금속)으로 토살을 설기하십시오."
                AppLanguage.VI ->
                    "• Phòng bệnh hóa sát: Ngũ Hoàng sát临 【$wuName】 (Sơn Hướng $wuCombo), Nhị Hắc bệnh phù đáo 【$erName】 (Sơn Hướng $erCombo). Kỵ động thổ và vật màu đỏ, nên treo hồ lô đồng hoặc lục đế tiền để tiết thổ hóa sát."
                AppLanguage.TH ->
                    "• ป้องกันโรคและเคราะห์: ดาวห้าเหลืองอยู่ที่ 【$wuName】 (ดาว $wuCombo) และดาวสองดำโรคภัยอยู่ที่ 【$erName】 (ดาว $erCombo) หลีกเลี่ยงการต่อเติมและสีแดง แนะนำแขวนน้ำเต้าทองเหลืองหรือเหรียญจีน 6 เหรียญแก้เคล็ด"
                AppLanguage.ID ->
                    "• Kesehatan & Penangkal Sha: Bintang 5-Kuning berada di [$wuName] (Bintang $wuCombo) & 2-Hitam di [$erName] (Bintang $erCombo); hindari renovasi atau warna merah menyala, gunakan labu tembaga/logam untuk menetralkan."
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> {
                    if (clash25Palace != null) {
                        "• 病符防煞：【${clash25Palace.localizedPalaceName}】逢山向${clash25Palace.mountainStar}-${clash25Palace.facingStar}二五交加/五黄叠临重煞（五黄位【$wuName】、二黑位【$erName】），切忌动土装修与红紫火物，务必安放铜葫芦或六帝钱泄土化煞。"
                    } else {
                        "• 病符防煞：五黄廉贞煞飞临【$wuName】（山向$wuCombo），二黑病符星到【$erName】（山向$erCombo），此二宫宜静不宜动，忌见红火动土，宜挂铜葫芦或六帝铜钱化泄凶性。"
                    }
                }
            }
        }

    val remedyAdvice: String
        get() = baseRemedyAdvice + "\n\n" + healthSourceNote

    val baseRemedyAdvice: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            val dingPalace = palaces.firstOrNull { it.mountainStar == period }
            val caiPalace = palaces.firstOrNull { it.facingStar == period }
            val clash37Palace = palaces.firstOrNull { !it.isCenter && ((it.mountainStar == 3 && it.facingStar == 7) || (it.mountainStar == 7 && it.facingStar == 3)) }
            val clash79Palace = palaces.firstOrNull { !it.isCenter && ((it.mountainStar == 7 && it.facingStar == 9) || (it.mountainStar == 9 && it.facingStar == 7)) }

            val dingName = dingPalace?.localizedPalaceName ?: ""
            val caiName = caiPalace?.localizedPalaceName ?: ""
            val samePalace = (dingPalace != null && dingPalace.id == caiPalace?.id)

            return when (lang) {
                AppLanguage.EN -> {
                    val extra = if (clash37Palace != null) " At [${clash37Palace.localizedPalaceName}] (3–7 Metal-Wood clash), place still water to harmonize."
                    else if (clash79Palace != null) " At [${clash79Palace.localizedPalaceName}] (7–9 Fire-Metal clash), place ceramic/earth decor to balance."
                    else ""
                    if (samePalace) {
                        "Plain: The Period-$period wealth & health stars both land at [$caiName]. What to do: Keep water (aquarium/water feature) in front to gather wealth, and a solid cabinet or stone behind to steady health. → Effect: Manages the family's steady income & career (breadwinner & business members) plus everyone's health and the children's constitution, both at [$caiName].$extra"
                    } else {
                        "Plain: The Period-$period wealth star sits at [$caiName]. What to do: Keep this sector open, bright and water-visible (aquarium, mirror, water feature) to gather wealth; the health star at [$dingName] benefits from a tall cabinet or stone ornament. → Effect: The wealth sector manages the family's income & career (breadwinner), the health sector manages family health and the children's constitution; covers [$caiName] and [$dingName].$extra"
                    }
                }
                AppLanguage.ZH_HANT -> {
                    val extra = if (clash37Palace != null) "【${clash37Palace.localizedPalaceName}】見三七交劍煞，宜設靜水通關金木。"
                    else if (clash79Palace != null) "【${clash79Palace.localizedPalaceName}】見七九火金相戰，宜置黃玉陶瓷洩火生金。"
                    else ""
                    if (samePalace) {
                        "白話：當運山向雙${period}星同聚【$caiName】，此方位前宜見水（魚缸/水景）納財、後宜立高櫃或山石固丁。→ 影響：財丁同管——財管男主人及經營家人的正財事業、丁管全家健康與小孩體質，覆蓋【$caiName】區域。$extra"
                    } else {
                        "白話：當運財星在【$caiName】，此方位宜敞亮見水（魚缸、水景或鏡面）聚財；當運丁星在【$dingName】，宜放高櫃或山石穩住健康人丁。→ 影響：財位管家中的正財與事業進帳（男主人與經營家人）、丁位管家人健康與人丁（小孩體質、長輩康健），分別覆蓋【$caiName】【$dingName】區域。$extra"
                    }
                }
                AppLanguage.JA -> {
                    val extra = if (clash37Palace != null) "【${clash37Palace.localizedPalaceName}】の三七交剣煞には静水で金木を通関。"
                    else if (clash79Palace != null) "【${clash79Palace.localizedPalaceName}】の七九火金相克には陶器・土器で調和。"
                    else ""
                    if (samePalace) {
                        "わかりやすく：当運の山向双${period}星が【$caiName】に同聚。前方に水（水槽・水景）を置いて財を集め、後方に高家具か山石で家族を固めます。→ 効果：一家の収入と働き手の仕事、全員の健康と子供の体質に作用。【$caiName】の領域に効果。$extra"
                    } else {
                        "わかりやすく：当運の財星は【$caiName】にあります。この方位は明るく開け、水（水槽・水景・鏡）を置くと財を集めます。当運の丁星【$dingName】は背の高い家具や山石で健康・人丁を固めます。→ 効果：財位は一家の収入・仕事（働き手）、丁位は家族の健康と子供の体質に作用し、【$caiName】【$dingName】の領域に効果。$extra"
                    }
                }
                AppLanguage.KO -> {
                    if (samePalace) {
                        "쉽게: 당운 산향 쌍${period}성이 【$caiName】에 모입니다. 앞에 물(어항·수경)을 두어 재물을 모으고, 뒤에 높은 가구나 산석으로 가족을 굳힙니다. → 효과: 한 집안의 수입·일(생계를 책임지는 사람)과 온 가족의 건강·아이 체질에 작용, 【$caiName】 영역."
                    } else {
                        "쉽게: 당운 재성이 【$caiName】에 있습니다. 이 방위는 밝고 트이게 두고 물(어항·수경·거울)을 두어 재물을 모읍니다. 당운 정성 【$dingName】은 높은 가구나 산석으로 건강과 가족을 굳힙니다. → 효과: 재위는 집안의 수입·일(가장), 정위는 가족 건강과 아이 체질에 작용하며 【$caiName】【$dingName】 영역에 효과."
                    }
                }
                AppLanguage.VI -> {
                    if (samePalace) {
                        "Giải thích đơn giản: Song tinh $period tụ tại 【$caiName】. Trước đặt nước (bể cá, thủy cảnh) tụ tài, sau đặt tủ cao hoặc đá vững nhân khẩu. → Ảnh hưởng: Quản thu nhập, công việc của trụ cột gia đình và sức khỏe mọi người, thể chất trẻ em; phủ 【$caiName】."
                    } else {
                        "Giải thích đơn giản: Sao tài vận $period đáo 【$caiName】. Nơi này nên thoáng sáng và thấy nước (bể cá, thủy cảnh, gương) để tụ tài; sao đinh 【$dingName】 nên đặt tủ cao hoặc đá để vững sức khỏe và nhân khẩu. → Ảnh hưởng: Vị trí tài quản thu nhập và công danh của gia đình (trụ cột), vị trí đinh quản sức khỏe gia đình và thể chất trẻ; phủ 【$caiName】【$dingName】."
                    }
                }
                AppLanguage.TH -> {
                    if (samePalace) {
                        "อธิบายง่ายๆ: ดาวคู่ยุค $period รวมที่【$caiName】 วางน้ำด้านหน้าทรัพย์ ตั้งตู้สูงหรือหินด้านหลังเสริมคน → ผล: ดูแลรายได้และงานของผู้หาเลี้ยงครอบครัว และสุขภาพทุกคน กับร่างกายของเด็ก ครอบคลุม【$caiName】"
                    } else {
                        "อธิบายง่ายๆ: ดาวทรัพย์ยุค $period อยู่ที่【$caiName】 ควรเปิดโล่งสว่างและเห็นน้ำ (ตู้ปลา น้ำตกจำลอง กระจก) เพื่อเรียกทรัพย์ ดาวคน【$dingName】 ตั้งตู้สูงหรือหินเสริมสุขภาพและคนในบ้าน → ผล: ตำแหน่งทรัพย์ดูแลรายได้และงานของผู้หาเลี้ยง ตำแหน่งคนดูแลสุขภาพครอบครัวและร่างกายเด็ก ครอบคลุม【$caiName】【$dingName】"
                    }
                }
                AppLanguage.ID -> {
                    if (samePalace) {
                        "Ringkas: Bintang kembar periode $period berkumpul di [$caiName]. Letakkan air di depan (akuarium/fitur air) untuk rezeki dan kabinet kokoh/batu di belakang untuk kesehatan. → Efek: Mengelola pendapatan & karier pencari nafkah serta kesehatan semua dan tubuh anak; mencakup [$caiName]."
                    } else {
                        "Ringkas: Bintang rezeki periode $period berada di [$caiName]. Biarkan sektor ini terang, terbuka dan terlihat air (akuarium, fitur air, cermin) untuk mengumpulkan rezeki; bintang kesehatan [$dingName] diperkuat dengan lemari tinggi atau batu. → Efek: Sektor rezeki mengelola pendapatan & karier keluarga (pencari nafkah), sektor kesehatan mengelola kesehatan keluarga dan tubuh anak; mencakup [$caiName] & [$dingName]."
                    }
                }
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> {
                    val extra = if (clash37Palace != null) "【${clash37Palace.localizedPalaceName}】见三七交剑煞，宜设静水通关金木。"
                    else if (clash79Palace != null) "【${clash79Palace.localizedPalaceName}】见七九火金相战，宜置黄玉陶瓷泄火生金。"
                    else ""
                    if (samePalace) {
                        "白话：当运山向双${period}星同聚【$caiName】，此方位前宜见水（鱼缸/水景）纳财、后宜立高柜或山石固丁。→ 影响：财丁同管——财管男主人及经营家人的正财事业、丁管全家健康与小孩体质，覆盖【$caiName】区域。$extra"
                    } else {
                        "白话：当运财星在【$caiName】，此方位宜敞亮见水（鱼缸、水景或镜面）聚财；当运丁星在【$dingName】，宜放高柜或山石稳住健康人丁。→ 影响：财位管家中正财与事业进账（男主人与经营家人）、丁位管家人健康与人丁（小孩体质、长辈康健），分别覆盖【$caiName】【$dingName】区域。$extra"
                    }
                }
            }
        }

    val traditionalSourceNote: String
        get() = flyingStarsTraditionalSourceNote(LocalizationManager.shared.effectiveLanguage)

    val wealthSourceNote: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN ->
                "Classical source: the transmitted Xuan-Kong mountain/facing-star formula (wording varies by edition) uses ‘Wang Shan Wang Xiang prospers people and wealth’, ‘Double Stars at Facing prospers wealth’, and ‘Shang Shan Xia Shui loses wealth and people’. Explanation: wealth, income and prosperity are traditional metaphysical symbols; verify real budgets and decisions independently."
            AppLanguage.ZH_HANT ->
                "古籍出處：玄空山向星訣（傳本有異文）有「到山到向，旺丁旺財；雙星到向，旺財不旺丁；上山下水，敗財損丁」等原文。解釋：財源、收入與旺財是傳統術數象徵，實際預算及決策請獨立核對。"
            AppLanguage.JA ->
                "出典：玄空山向星訣（伝本に異文）には「到山到向は財と人が栄え、双星到向は財、上山下水は財と人を損なう」とあります。解釈：財・収入・繁栄は伝統術数の象徴であり、実際の予算と判断は独立に確認してください。"
            AppLanguage.KO ->
                "출처: 전통 현공 산향성결(전본 이문)은 ‘도산도향 왕정왕재, 쌍성도향 왕재, 동산하수 손재손정’이라 전합니다. 설명: 재물·수입·번영은 전통 술수의 상징이며 실제 예산과 결정은 별도로 확인하세요."
            AppLanguage.VI ->
                "Nguồn: Quyết tinh sơn hướng Huyền Không truyền câu ‘đáo sơn đáo hướng vượng đinh vượng tài; song tinh đáo hướng vượng tài; thượng sơn hạ thủy bại tài tổn đinh’ (bản truyền có dị văn). Giải thích: tài lộc, thu nhập và thịnh vượng là biểu tượng thuật số; hãy tự kiểm tra ngân sách và quyết định thực tế."
            AppLanguage.TH ->
                "แหล่งที่มา: ตำราดาวภูเขา-ทิศเสวียนคงสืบคำว่า ‘ถึงเขาถึงทิศรุ่งเรืองคนและทรัพย์; ดาวคู่สู่หน้ารุ่งเรืองทรัพย์; ขึ้นเขาลงน้ำเสียทรัพย์เสียคน’ (ตำราต่างกัน) คำอธิบาย: ทรัพย์ รายได้ และความรุ่งเรืองเป็นสัญลักษณ์ทางโหราศาสตร์ ควรตรวจสอบงบประมาณและการตัดสินใจจริงแยกต่างหาก"
            AppLanguage.ID ->
                "Sumber: rumus bintang gunung/hadap Xuan-Kong (versi tradisi berbeda) memuat ‘makmurkan orang dan harta; bintang ganda di hadap memakmurkan harta; Shang Shan Xia Shui merusak harta dan orang’. Penjelasan: rezeki, pendapatan, dan kemakmuran adalah simbol metafisika tradisional; periksa anggaran dan keputusan nyata secara mandiri."
            AppLanguage.AUTO, AppLanguage.ZH_HANS ->
                "古籍出处：玄空山向星诀（传本有异文）有“到山到向，旺丁旺财；双星到向，旺财不旺丁；上山下水，败财损丁”等原文。解释：财源、收入与旺财是传统术数象征，实际预算及决策请独立核对。"
        }

    val healthSourceNote: String
        get() = traditionalSourceNote + "\n解释：请结合通风、采光、噪音、排水和结构安全现场复核；涉及健康或财务事项应咨询相应专业人士。"
}

class FlyingStarsEngine private constructor() {
    companion object {
        val instance: FlyingStarsEngine by lazy { FlyingStarsEngine() }
        val shared: FlyingStarsEngine get() = instance

        private val tiGuaStarMap: Map<String, Int> = mapOf(
            "子" to 1, "癸" to 1, "甲" to 1, "申" to 1,
            "壬" to 2, "卯" to 2, "乙" to 2, "未" to 2, "坤" to 2,
            "乾" to 6, "戌" to 6, "辰" to 6, "巽" to 6, "巳" to 6, "亥" to 6,
            "艮" to 7, "丙" to 7, "酉" to 7, "辛" to 7, "丑" to 7,
            "寅" to 9, "午" to 9, "庚" to 9, "丁" to 9
        )

        fun checkSanBanGua(cells: List<PalaceCell>): Boolean {
            val fumuSets = listOf(setOf(1, 4, 7), setOf(2, 5, 8), setOf(3, 6, 9))
            val lianzhuSets = listOf(
                setOf(1, 2, 3), setOf(2, 3, 4), setOf(3, 4, 5),
                setOf(4, 5, 6), setOf(5, 6, 7), setOf(6, 7, 8),
                setOf(7, 8, 9), setOf(8, 9, 1), setOf(9, 1, 2)
            )
            val allFumu = cells.all { c ->
                val s = setOf(c.periodStar, c.mountainStar, c.facingStar)
                fumuSets.contains(s)
            }
            if (allFumu) return true
            return cells.all { c ->
                val s = setOf(c.periodStar, c.mountainStar, c.facingStar)
                lianzhuSets.contains(s)
            }
        }

        fun checkQiXingDaJie(cells: List<PalaceCell>, activePeriod: Int, facingPalaceIdx: Int): Boolean {
            if (cells.size != 9 || cells[facingPalaceIdx].facingStar != activePeriod) return false
            val fumuSets = listOf(setOf(1, 4, 7), setOf(2, 5, 8), setOf(3, 6, 9))
            val zhenQiSet = setOf(cells[8].facingStar, cells[2].facingStar, cells[5].facingStar) // 离9、震3、乾6
            val jiaQiSet = setOf(cells[0].facingStar, cells[6].facingStar, cells[3].facingStar)  // 坎1、兑7、巽4
            return fumuSets.contains(zhenQiSet) || fumuSets.contains(jiaQiSet)
        }
    }

    private val luoShuOrder = intArrayOf(4, 5, 6, 7, 8, 0, 1, 2, 3)
    private val palaceNames = arrayOf("坎一宫 (正北)", "坤二宫 (西南)", "震三宫 (正东)", "巽四宫 (东南)", "天心五 (中宫)", "乾六宫 (西北)", "兑七宫 (正西)", "艮八宫 (东北)", "离九宫 (正南)")
    private val palaceTrigrams = arrayOf("坎", "坤", "震", "巽", "中", "乾", "兑", "艮", "离")
    private val palaceDirections = arrayOf("正北", "西南", "正东", "东南", "中宫", "西北", "正西", "东北", "正南")

    fun currentPeriod(date: Date = Date()): Int {
        val offset = effectiveSolarYear(date) - 1864
        val cycleYear = (offset % 180 + 180) % 180
        return (cycleYear / 20) + 1
    }

    fun periodMeta(period: Int, date: Date = Date()): PeriodMeta {
        val year = effectiveSolarYear(date)
        val curPeriod = currentPeriod(date)
        val p = period.coerceIn(1, 9)
        val offset = year - 1864
        val cycleIndex = Math.floorDiv(offset, 180)
        val cycleStart = 1864 + cycleIndex * 180
        val pStart = cycleStart + (p - 1) * 20
        val pEnd = pStart + 19

        val yuan = when (p) {
            in 1..3 -> "上元"
            in 4..6 -> "中元"
            else -> "下元"
        }
        val trigram = when (p) {
            1 -> "坎"
            2 -> "坤"
            3 -> "震"
            4 -> "巽"
            5 -> "中"
            6 -> "乾"
            7 -> "兑"
            8 -> "艮"
            9 -> "离"
            else -> "中"
        }
        val starName = when (p) {
            1 -> "一白贪狼"
            2 -> "二黑巨门"
            3 -> "三碧禄存"
            4 -> "四绿文曲"
            5 -> "五黄廉贞"
            6 -> "六白武曲"
            7 -> "七赤破军"
            8 -> "八白左辅"
            9 -> "九紫右弼"
            else -> ""
        }
        val element = when (p) {
            1 -> "水"
            2, 5, 8 -> "土"
            3, 4 -> "木"
            6, 7 -> "金"
            9 -> "火"
            else -> "土"
        }
        val label = "${yuan}${p}运 · ${trigram}宫 · ${starName} (${pStart}-${pEnd})"
        return PeriodMeta(p, yuan, trigram, starName, element, pStart, pEnd, p == curPeriod, label)
    }

    private fun effectiveSolarYear(date: Date): Int {
        val cal = java.util.GregorianCalendar()
        cal.time = date
        val year = cal.get(Calendar.YEAR)
        val month = cal.get(Calendar.MONTH) + 1
        val day = cal.get(Calendar.DAY_OF_MONTH)
        return if (month < 2 || (month == 2 && day < 4)) year - 1 else year
    }

    private fun resolveStarAndPolarity(
        originalStar: Int,
        mountainOrder: Int,
        isParentFive: Boolean,
        parentSittingGua: String
    ): Pair<Int, Boolean> {
        var baseStar = originalStar
        if (baseStar == 5) {
            baseStar = if (isParentFive) {
                when (parentSittingGua) {
                    "坎" -> 1; "坤" -> 2; "震" -> 3; "巽" -> 4; "乾" -> 6; "兑" -> 7; "艮" -> 8; "离" -> 9; else -> 2
                }
            } else {
                when (mountainOrder) {
                    1 -> 2; 2 -> 2; 3 -> 8; else -> 2
                }
            }
        }

        val yangMountainsOdd = setOf(1, 2)
        val yangMountainsEven = setOf(3)
        val isOddStar = (baseStar % 2 != 0)
        val isYang = if (isOddStar) {
            yangMountainsOdd.contains(mountainOrder)
        } else {
            yangMountainsEven.contains(mountainOrder)
        }
        return Pair(baseStar, isYang)
    }

    fun calculateChart(
        period: Int? = null,
        sitting: Mountain24Item,
        facing: Mountain24Item,
        useTiGua: Boolean = false,
        date: Date = Date()
    ): XuanKongChart {
        val activePeriod = period ?: currentPeriod(date)
        val meta = periodMeta(activePeriod, date)

        // 1. 运盘排布
        val basePeriod = IntArray(9)
        for (step in 0 until 9) {
            val palaceIdx = luoShuOrder[step]
            basePeriod[palaceIdx] = (activePeriod - 1 + step) % 9 + 1
        }

        // 2. 确定坐山与向山所在的宫位及地元/天元/人元属性
        val sittingIdx = palaceIndex(sitting.palace)
        val facingIdx = palaceIndex(facing.palace)
        val sittingFacingIdx = if (sittingIdx == 4) 8 else sittingIdx

        val sittingMountainStar = basePeriod[sittingFacingIdx]
        val facingMountainStar = basePeriod[palaceIndex(facing.palace)]

        val sResolved = resolveStarAndPolarity(sittingMountainStar, sitting.order, sittingIdx == 4, sitting.palace)
        val fResolved = resolveStarAndPolarity(facingMountainStar, facing.order, sittingIdx == 4, sitting.palace)

        val finalSittingStar = if (useTiGua) (tiGuaStarMap[sitting.name] ?: sResolved.first) else sResolved.first
        val finalFacingStar = if (useTiGua) (tiGuaStarMap[facing.name] ?: fResolved.first) else fResolved.first

        // 3. 飞星排布
        val mountainStars = IntArray(9)
        val facingStars = IntArray(9)

        for (step in 0 until 9) {
            val palaceIdx = luoShuOrder[step]
            mountainStars[palaceIdx] = if (sResolved.second) {
                (finalSittingStar - 1 + step) % 9 + 1
            } else {
                (finalSittingStar - 1 - step % 9 + 9) % 9 + 1
            }

            facingStars[palaceIdx] = if (fResolved.second) {
                (finalFacingStar - 1 + step) % 9 + 1
            } else {
                (finalFacingStar - 1 - step % 9 + 9) % 9 + 1
            }
        }

        // 4. 判断四大格局
        val wangShanAtSitting = mountainStars[sittingFacingIdx] == activePeriod
        val wangXiangAtFacing = facingStars[facingIdx] == activePeriod
        val wangXiangAtSitting = facingStars[sittingFacingIdx] == activePeriod
        val wangShanAtFacing = mountainStars[facingIdx] == activePeriod

        val patternKind = if (wangShanAtSitting && wangXiangAtFacing) {
            0 // 到山到向
        } else if (wangXiangAtFacing && wangShanAtFacing) {
            1 // 双星到向
        } else if (wangShanAtSitting && wangXiangAtSitting) {
            2 // 双星到坐
        } else if (wangShanAtFacing && wangXiangAtSitting) {
            3 // 上山下水
        } else {
            4 // 吉凶平和局
        }

        val lang = LocalizationManager.shared.effectiveLanguage
        val pattern = when (lang) {
            AppLanguage.EN -> listOf("Wang Shan Wang Xiang (Supreme Wealth & Health)", "Double Stars at Facing (Auspicious Wealth)", "Double Stars at Sitting (Auspicious Health)", "Shang Shan Xia Shui (Reverse Chart)", "Balanced Harmony Chart")[patternKind]
            AppLanguage.ZH_HANT -> listOf("到山到向 (旺丁旺財最吉)", "雙星到向 (旺財不旺丁 · 宜向前有水後有山)", "雙星到坐 (旺丁不旺財 · 宜向後有水水後有山)", "上山下水 (敗財損丁凶局 · 需借勢顛倒用法)", "吉凶平和局")[patternKind]
            AppLanguage.JA -> listOf("到山到向 (旺丁旺財の大吉)", "双星到向 (旺財不旺丁 · 前方に水、後方に山が吉)", "双星到坐 (旺丁不旺財 · 後方に水、その奥に山が吉)", "上山下水 (敗財損丁の凶局 · 顛倒勢の借用が必要)", "吉凶相半の平和局")[patternKind]
            AppLanguage.KO -> listOf("도산도향 (왕정왕재 대길)", "쌍성도향 (재물 번창 · 앞에 물 뒤에 산이 길함)", "쌍성도좌 (자손 번창 · 뒤에 물과 산이 길함)", "동산하수 (손재패가 흉국 · 전도법 응용 필요)", "길흉 평화국")[patternKind]
            AppLanguage.VI -> listOf("Đáo Sơn Đáo Hướng (Vượng đinh vượng tài đại cát)", "Song Tinh Đáo Hướng (Vượng tài · Trước có nước sau có núi)", "Song Tinh Đáo Tọa (Vượng đinh · Sau có nước sau nước có núi)", "Thượng Sơn Hạ Thủy (Bại tài tổn đinh hung cục · Cần phép điên đảo)", "Cát hung bình hòa cục")[patternKind]
            AppLanguage.TH -> listOf("ถึงเขาถึงทิศ (เจริญทั้งคนและทรัพย์ มงคลยิ่ง)", "สองดาวสู่ทิศหน้า (รุ่งเรืองทรัพย์สิน · หน้าควรมีน้ำหลังมีเขา)", "สองดาวสู่หลังพิง (ลูกหลานรุ่งเรือง · หลังควรมีน้ำและมีเขา)", "ขึ้นเขาลงน้ำ (สูญเสียทรัพย์และคน เคราะห์ร้าย · ต้องกลับทิศแก้เคล็ด)", "สมดุลปานกลาง")[patternKind]
            AppLanguage.ID -> listOf("Wang Shan Wang Xiang (Makmur Keluarga & Harta)", "Bintang Kembar di Hadap (Kaya Harta · Air di Depan, Gunung di Belakang)", "Bintang Kembar di Duduk (Banyak Keturunan · Air & Gunung di Belakang)", "Shang Shan Xia Shui (Peta Terbalik · Rawan Kerugian Harta & Fisik)", "Peta Harmonis Seimbang")[patternKind]
            AppLanguage.AUTO, AppLanguage.ZH_HANS -> listOf("到山到向 (旺丁旺财最吉)", "双星到向 (旺财不旺丁 · 宜向前有水后有山)", "双星到坐 (旺丁不旺财 · 宜向后有水水后有山)", "上山下水 (败财损丁凶局 · 需借势颠倒用法)", "吉凶平和局")[patternKind]
        }

        // 5. 组合九宫格模型
        val cells = ArrayList<PalaceCell>()
        for (i in 0 until 9) {
            val isWangM = mountainStars[i] == activePeriod
            val isWangF = facingStars[i] == activePeriod
            val isWuHuang = mountainStars[i] == 5 || facingStars[i] == 5
            val isErHei = mountainStars[i] == 2 || facingStars[i] == 2

            val cell = PalaceCell(
                id = i,
                palaceName = palaceNames[i],
                trigram = palaceTrigrams[i],
                direction = palaceDirections[i],
                periodStar = basePeriod[i],
                activePeriod = activePeriod,
                mountainStar = mountainStars[i],
                facingStar = facingStars[i],
                isCenter = i == 4,
                isWangMountain = isWangM,
                isWangFacing = isWangF,
                isShaWuHuang = isWuHuang,
                isShaErHei = isErHei
            )
            cells.add(cell)
        }

        // 6. 综合格局说明。仅描述计算出的盘面，不对现实结果作承诺。
        val sittingName = sitting.localizedName
        val facingName = facing.localizedName
        val sourceNote = flyingStarsTraditionalSourceNote(lang)
        val summary = when (lang) {
            AppLanguage.EN ->
                "${meta.label}. Sitting $sittingName Facing $facingName presents [$pattern]. Cultivate auspicious Qi at the facing palace, solidify sitting mountain for harmony.\n\n$sourceNote"
            AppLanguage.ZH_HANT ->
                "${if (meta.isCurrent) "當前正值" else "玄空排盤："}${meta.yuan}${activePeriod}運（${meta.startYear}—${meta.endYear}年，${meta.starName}${meta.element}星當令）。${sittingName}山${facingName}向在此元運呈現【$pattern】。宜重點佈局向首明堂引納${meta.element}氣，坐後穩實以固人丁。\n\n$sourceNote"
            AppLanguage.JA ->
                "${if (meta.isCurrent) "現在は" else "玄空飛星："}${meta.yuan}${activePeriod}運（${meta.startYear}—${meta.endYear}年、${meta.starName}${meta.element}星当令）。${sittingName}山${facingName}向はこの元運で【$pattern】となります。向首明堂に吉気を引込み、坐後を堅固にして子孫健康を守ると吉。\n\n$sourceNote"
            AppLanguage.KO ->
                "${if (meta.isCurrent) "현재는 " else "현공 비성: "}${meta.yuan} ${activePeriod}운 (${meta.startYear}—${meta.endYear}년, ${meta.starName} ${meta.element}성 당령). ${sittingName}산 ${facingName}향은 이 원운에서 【$pattern】을 이룹니다. 향수 명당에 기운을 받아들이고 좌산을 든든히 하여 인정을 보존함이 길합니다。\n\n$sourceNote"
            AppLanguage.VI ->
                "${if (meta.isCurrent) "Hiện tại chính là " else "Huyền Không bài bàn: "}${meta.yuan} Vận ${activePeriod} (${meta.startYear}—${meta.endYear}, ${meta.starName} ${meta.element} tinh đương lệnh). ${sittingName} sơn ${facingName} hướng trong nguyên vận này biểu hiện 【$pattern】. Nên bố trí minh đường nạp khí, tọa sơn vững chãi vượng nhân đinh.\n\n$sourceNote"
            AppLanguage.TH ->
                "${if (meta.isCurrent) "ปัจจุบันเข้าสู่ " else "ผังเหวินคง: "}${meta.yuan} ยุค ${activePeriod} (${meta.startYear}—${meta.endYear}, ดาว${meta.starName} ธาตุ${meta.element}). ${sittingName}พิง ${facingName}หัน ในยุคนี้ปรากฏเป็น 【$pattern】 ควรจัดหมุนเวียนพลังงานด้านหน้า และรักษาความมั่นคงด้านหลังเพื่อเสริมสิริมงคล\n\n$sourceNote"
            AppLanguage.ID ->
                "${if (meta.isCurrent) "Saat ini berada pada " else "Bagan Xuan Kong: "}${meta.yuan} Periode ${activePeriod} (${meta.startYear}—${meta.endYear}, Bintang ${meta.starName} Unsur ${meta.element}). Posisi Duduk ${sittingName} Hadap ${facingName} membentuk [$pattern]. Atur tata ruang hadap untuk menyerap energi positif dan perkuat posisi duduk demi ketentraman keluarga.\n\n$sourceNote"
            AppLanguage.AUTO, AppLanguage.ZH_HANS ->
                "${if (meta.isCurrent) "当前正值" else "玄空排盘："}${meta.yuan}${activePeriod}运（${meta.startYear}—${meta.endYear}年，${meta.starName}${meta.element}星当令）。${sittingName}山${facingName}向在此元运呈现【$pattern】。宜重点布局向首明堂引纳${meta.element}气，坐后稳实以固人丁。\n\n$sourceNote"
        }

        val modeTitle = if (useTiGua)
            LocalizationManager.shared.t("chart_mode_tigua")
        else
            LocalizationManager.shared.t("chart_mode_xiagua")

        return XuanKongChart(
            period = activePeriod,
            sittingMountain = sittingName,
            facingMountain = facingName,
            patternType = pattern,
            isSanBanGua = checkSanBanGua(cells),
            isQiXingDaJie = checkQiXingDaJie(cells, activePeriod, sittingFacingIdx),
            isTiGua = useTiGua,
            chartModeTitle = modeTitle,
            palaces = cells,
            summaryAnalysis = summary,
            periodMeta = meta,
            patternKind=patternKind
        )
    }

    private fun palaceIndex(palaceName: String): Int {
        return when (palaceName) {
            "坎" -> 0
            "坤" -> 1
            "震" -> 2
            "巽" -> 3
            "乾" -> 5
            "兑" -> 6
            "艮" -> 7
            "离" -> 8
            else -> 4
        }
    }
}
