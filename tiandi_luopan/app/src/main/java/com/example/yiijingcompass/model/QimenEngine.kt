package com.example.yiijingcompass.model

import java.util.Calendar
import java.util.Date

data class QimenDoor(
    val name: String,
    val palace: Int,
    val isAuspicious: Boolean,
    val luckType: String, // "吉", "大吉", "平", "凶", "大凶"
    val lore: String
) {
    val localizedName: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> mapOf("休门" to "Rest Gate", "生门" to "Life Gate", "伤门" to "Harm Gate", "杜门" to "Block Gate", "景门" to "View Gate", "死门" to "Death Gate", "惊门" to "Shock Gate", "开门" to "Open Gate")[name] ?: name
                AppLanguage.ZH_HANT, AppLanguage.JA -> mapOf("休门" to "休門", "生门" to "生門", "伤门" to "傷門", "杜门" to "杜門", "景门" to "景門", "死门" to "死門", "惊门" to "驚門", "开门" to "開門")[name] ?: name
                AppLanguage.KO -> mapOf("休门" to "휴문", "生门" to "생문", "伤门" to "상문", "杜门" to "두문", "景门" to "경문", "死门" to "사문", "惊门" to "경문(驚)", "开门" to "개문")[name] ?: name
                AppLanguage.VI -> mapOf("休门" to "Hưu Môn", "生门" to "Sinh Môn", "伤门" to "Thương Môn", "杜门" to "Đỗ Môn", "景门" to "Cảnh Môn", "死门" to "Tử Môn", "惊门" to "Kinh Môn", "开门" to "Khai Môn")[name] ?: name
                AppLanguage.TH -> mapOf("休门" to "ประตูพัก", "生门" to "ประตูเกิด", "伤门" to "ประตูเจ็บ", "杜门" to "ประตูซ่อน", "景门" to "ประตูวิว", "死门" to "ประตูตาย", "惊门" to "ประตูตกใจ", "开门" to "ประตูเปิด")[name] ?: name
                AppLanguage.ID -> mapOf("休门" to "Gerbang Istirahat", "生门" to "Gerbang Kehidupan", "伤门" to "Gerbang Luka", "杜门" to "Gerbang Rintangan", "景门" to "Gerbang Pemandangan", "死门" to "Gerbang Kematian", "惊门" to "Gerbang Terkejut", "开门" to "Gerbang Pembuka")[name] ?: name
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> name
            }
        }

    val localizedLuckType: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN -> mapOf("大吉" to "Great Luck", "吉" to "Auspicious", "凶" to "Inauspicious", "大凶" to "Major Taboo", "平" to "Neutral")[luckType] ?: luckType
            AppLanguage.ZH_HANT, AppLanguage.JA -> luckType
            AppLanguage.KO -> mapOf("大吉" to "대길", "吉" to "길", "凶" to "흉", "大凶" to "대흉", "平" to "평")[luckType] ?: luckType
            AppLanguage.VI -> mapOf("大吉" to "Đại Cát", "吉" to "Cát", "凶" to "Hung", "大凶" to "Đại Hung", "平" to "Bình")[luckType] ?: luckType
            AppLanguage.TH -> mapOf("大吉" to "มงคลยิ่ง", "吉" to "มงคล", "凶" to "อัปมงคล", "大凶" to "อัปมงคลยิ่ง", "平" to "ปานกลาง")[luckType] ?: luckType
            AppLanguage.ID -> mapOf("大吉" to "Sangat Baik", "吉" to "Baik", "凶" to "Buruk", "大凶" to "Sangat Buruk", "平" to "Netral")[luckType] ?: luckType
            AppLanguage.AUTO, AppLanguage.ZH_HANS -> luckType
        }

    val localizedLore: String
        get() = baseLocalizedLore + "\n\n" + classicalSourceNote

    private val baseLocalizedLore: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN -> mapOf(
                "休门" to "Favorable for rest, study and quiet pursuits.",
                "生门" to "Excellent for wealth, property and growth.",
                "伤门" to "Useful for pursuit, but guard against travel injuries.",
                "杜门" to "Hide and consolidate; keep doors closed.",
                "景门" to "Good for documents and examinations; avoid haste.",
                "死门" to "Suitable for mourning rites; avoid travel and construction.",
                "惊门" to "Disputes and alarm are possible; useful for catching thieves.",
                "开门" to "Excellent for business, opening and movement."
            )[name] ?: lore
            AppLanguage.ZH_HANT -> mapOf(
                "休门" to "求名休閒大吉，水清木秀", "生门" to "求財置業大吉，土旺金生",
                "伤门" to "討債索敵宜，出行防傷災", "杜门" to "潛伏隱匿避災，閉藏門戶",
                "景门" to "文書考試宴請吉，火炎防急", "死门" to "吊喪刑戮宜，出行造葬大凶",
                "惊门" to "官非驚恐口舌，捕盜宜", "开门" to "經商開業動身，百事通亨"
            )[name] ?: lore
            AppLanguage.JA -> mapOf(
                "休门" to "休息や学問、名声の獲得に大吉", "生门" to "求財や不動産取得に大吉、発展を促す",
                "伤门" to "債権回収や討伐に適するが怪我に注意", "杜门" to "隠匿や難逃れに適し、戸を閉ざす",
                "景门" to "文書作成や試験に吉、焦りは禁物", "死门" to "葬儀弔問にのみ適し、出行動土は大凶",
                "惊门" to "口論や驚愕を招きやすく盗賊捕縛に吉", "开门" to "開業や出発商談に万事通亨の大吉"
            )[name] ?: lore
            AppLanguage.KO -> mapOf(
                "休门" to "휴식과 명예, 학문에 대길합니다", "生门" to "재물 축적과 부동산에 대길합니다",
                "伤门" to "추적과 채권 회수에는 좋으나 부상에 주의", "杜门" to "은닉과 액막이에 적합하며 문을 닫음",
                "景门" to "문서와 시험에 길하며 성급함을 피함", "死门" to "조문과 형벌에만 적합, 여행과 토목은 대흉",
                "惊门" to "구설수와 놀람을 주의, 도적 체포에 길함", "开门" to "개업과 출발, 사업 등 모든 일에 통달대길"
            )[name] ?: lore
            AppLanguage.VI -> mapOf(
                "休门" to "Cầu danh nghỉ ngơi đại cát, thủy thanh mộc tú", "生门" to "Cầu tài mua nhà đất đại cát, sinh sôi phát triển",
                "伤门" to "Đòi nợ truy bắt hợp, xuất hành phòng tổn thương", "杜门" to "Ẩn nấp lánh nạn, đóng chặt cửa nẻo",
                "景门" to "Văn thư thi cử tiệc tùng cát, tránh nóng vội", "死门" to "Hợp tang lễ, xuất hành an táng đại hung",
                "惊门" to "Dễ gặp thị phi kinh hãi, hợp truy bắt đạo tặc", "开门" to "Kinh doanh khai trương xuất hành, trăm sự hanh thông"
            )[name] ?: lore
            AppLanguage.TH -> mapOf(
                "休门" to "เหมาะแก่การพักผ่อน ศึกษาหาความรู้ มงคลยิ่ง", "生门" to "ดีที่สุดสำหรับการค้า ซื้ออสังหาฯ และสร้างความมั่งคั่ง",
                "伤门" to "เหมาะแก่การทวงหนี้ ติดตาม แต่ระวังบาดเจ็บ", "杜门" to "เก็บตัว ซ่อนเร้น หลบภัย ปิดประตูมิดชิด",
                "景门" to "ดีต่อการสอบ เอกสารสัญญา หลีกเลี่ยงความใจร้อน", "死门" to "เหมาะเฉพาะพิธีศพ ห้ามเดินทางและก่อสร้าง อัปมงคลยิ่ง",
                "惊门" to "ระวังข้อพิพาทตกใจ เหมาะแก่การจับขโมย", "开门" to "เปิดกิจการ ค้าขาย ออกเดินทาง ราบรื่นทุกประการ"
            )[name] ?: lore
            AppLanguage.ID -> mapOf(
                "休门" to "Sangat baik untuk istirahat, studi, dan ketenangan", "生门" to "Sangat baik untuk rezeki, properti, dan pertumbuhan usaha",
                "伤门" to "Cocok menagih hak, namun waspadai cedera perjalanan", "杜门" to "Menyembunyikan diri dan konsolidasi; tutup pintu rapat",
                "景门" to "Baik untuk urusan dokumen & ujian; hindari tergesa-gesa", "死门" to "Hanya cocok upacara duka; hindari bepergian/konstruksi",
                "惊门" to "Waspadai perselisihan; cocok untuk menangkap pencuri", "开门" to "Sangat baik untuk pembukaan bisnis, relokasi & sukses lancar"
            )[name] ?: lore
            AppLanguage.AUTO, AppLanguage.ZH_HANS -> mapOf(
                "休门" to "求名休闲大吉，水清木秀", "生门" to "求财置业大吉，土旺金生",
                "伤门" to "讨债索敌宜，出行防伤灾", "杜门" to "潜伏隐匿避灾，闭藏门户",
                "景门" to "文书考试宴请吉，火炎防急", "死门" to "吊丧刑戮宜，出行造葬大凶",
                "惊门" to "官非惊恐口舌，捕盗宜", "开门" to "经商开业动身，百事通亨"
            )[name] ?: lore
        }

    val classicalSourceNote: String
        get() = when (LocalizationManager.shared.effectiveLanguage) {
            AppLanguage.EN -> "Classical source: the traditional Eight-Gates mnemonic in Qimen Dunjia texts, ‘Rest, Life and Open are the three auspicious gates; Death, Shock and Harm are the three inauspicious gates; Block and View are intermediate.’ Interpretation: the gate language above is a historical symbolic reading. It does not determine travel safety, health, construction, legal or financial outcomes; verify real-world conditions and consult qualified professionals."
            AppLanguage.ZH_HANT -> "古籍出處：奇門遁甲八門傳統訣：「休、生、開三吉；死、驚、傷三凶；杜、景二門中。」解釋：上文門象為古籍術數的象徵解讀，不決定出行安全、健康、施工、法律或財務結果；請以現場條件及專業意見為準。"
            AppLanguage.JA -> "出典：奇門遁甲の八門訣「休・生・開は三吉、死・驚・傷は三凶、杜・景は中門」。解釈：門の吉凶は古典術数の象徴的な読みであり、旅行の安全、健康、工事、法律・金融の結果を決めるものではありません。"
            AppLanguage.KO -> "출처: 기문둔갑 팔문 전통결 ‘휴·생·개는 삼길, 사·경·상은 삼흉, 두·경은 중문’. 해석: 위 문상은 고전 술수의 상징적 해석이며 여행 안전·건강·공사·법률·재무 결과를 결정하지 않습니다."
            AppLanguage.VI -> "Nguồn cổ: khẩu quyết Bát Môn trong Kỳ Môn Độn Giáp: ‘Hưu, Sinh, Khai là ba cửa cát; Tử, Kinh, Thương là ba cửa hung; Đỗ, Cảnh là cửa trung.’ Giải thích: ngôn ngữ cửa là biểu tượng thuật số cổ, không quyết định an toàn đi lại, sức khỏe, xây dựng, pháp lý hay tài chính."
            AppLanguage.TH -> "ที่มาโบราณ: สูตรแปดประตูในฉีเหมินตุ้นเจี่ย ‘ประตูพัก เกิด เปิด เป็นสามประตูมงคล; ตาย ตกใจ บาดเจ็บ เป็นสามประตูอัปมงคล; ซ่อนและทัศน์เป็นประตูกลาง’ คำอธิบาย: ถ้อยคำเรื่องประตูเป็นสัญลักษณ์ของศาสตร์โบราณ ไม่ได้กำหนดความปลอดภัย สุขภาพ งานก่อสร้าง กฎหมาย หรือการเงิน"
            AppLanguage.ID -> "Sumber klasik: mnemonik Delapan Gerbang Qimen Dunjia, ‘Istirahat, Kehidupan, dan Pembuka adalah tiga gerbang baik; Kematian, Kejutan, dan Luka adalah tiga gerbang buruk; Blokir dan Pandang adalah gerbang menengah.’ Penjelasan: simbol gerbang ini adalah tafsir sejarah, bukan penentu keselamatan perjalanan, kesehatan, konstruksi, hukum, atau keuangan."
            AppLanguage.AUTO, AppLanguage.ZH_HANS -> "古籍出处：奇门遁甲八门传统诀：“休、生、开三吉；死、惊、伤三凶；杜、景二门中。”解释：上文门象为古籍术数的象征解读，不决定出行安全、健康、施工、法律或财务结果；请以现场条件及专业意见为准。"
        }
}

data class QimenPalaceCell(
    val id: Int,
    val palaceName: String,
    val direction: String,
    val angleCenter: Double,
    val doorName: String,
    val starName: String,
    val godName: String,
    val tianPanGan: String,
    val diPanGan: String,
    val isAuspicious: Boolean,
    val luckType: String,
    val isCenter: Boolean,
    val isFacingDirection: Boolean
) {
    val tianStem: String get() = tianPanGan
    val diStem: String get() = diPanGan
    val doorLuck: String get() = luckType
    val localizedDoorName: String
        get() {
            val d = QimenEngine.instance.resolveDoor(doorName)
            return d?.localizedName ?: doorName
        }

    val localizedStarName: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> mapOf("天蓬" to "Peng Star", "天芮" to "Rui Star", "天冲" to "Chong Star", "天辅" to "Fu Star", "天禽" to "Qin Star", "天心" to "Xin Star", "天柱" to "Zhu Star", "天任" to "Ren Star", "天英" to "Ying Star")[starName] ?: starName
                AppLanguage.ZH_HANT -> starName.replace("冲", "沖").replace("辅", "輔")
                AppLanguage.JA -> mapOf("天蓬" to "天蓬", "天芮" to "天芮", "天冲" to "天衝", "天辅" to "天輔", "天禽" to "天禽", "天心" to "天心", "天柱" to "天柱", "天任" to "天任", "天英" to "天英")[starName] ?: starName
                AppLanguage.KO -> mapOf("天蓬" to "천봉", "天芮" to "천예", "天冲" to "천충", "天辅" to "천보", "天禽" to "천금", "天心" to "천심", "天柱" to "천주", "天任" to "천임", "天英" to "천영")[starName] ?: starName
                AppLanguage.VI -> mapOf("天蓬" to "Thiên Bồng", "天芮" to "Thiên Nhuế", "天冲" to "Thiên Xung", "天辅" to "Thiên Phụ", "天禽" to "Thiên Cầm", "天心" to "Thiên Tâm", "天柱" to "Thiên Trụ", "天任" to "Thiên Nhậm", "天英" to "Thiên Anh")[starName] ?: starName
                AppLanguage.TH -> mapOf("天蓬" to "เทียนเผิง", "天芮" to "เทียนรุ่ย", "天冲" to "เทียนชง", "天辅" to "เทียนฝู่", "天禽" to "เทียนฉิน", "天心" to "เทียนซิน", "天柱" to "เทียนจู้", "天任" to "เทียนเหริน", "天英" to "เทียนอิง")[starName] ?: starName
                AppLanguage.ID -> mapOf("天蓬" to "Bintang Peng", "天芮" to "Bintang Rui", "天冲" to "Bintang Chong", "天辅" to "Bintang Fu", "天禽" to "Bintang Qin", "天心" to "Bintang Xin", "天柱" to "Bintang Zhu", "天任" to "Bintang Ren", "天英" to "Bintang Ying")[starName] ?: starName
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> starName
            }
        }

    val localizedGodName: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            return when (lang) {
                AppLanguage.EN -> mapOf("值符" to "Chief Deity", "螣蛇" to "Snake", "太阴" to "Great Yin", "六合" to "Six Harmony", "白虎" to "White Tiger", "玄武" to "Black Tortoise", "九地" to "Nine Earth", "九天" to "Nine Heaven", "元极" to "Center Pole")[godName] ?: godName
                AppLanguage.ZH_HANT -> godName.replace("阴", "陰").replace("极", "極")
                AppLanguage.JA -> mapOf("值符" to "直符", "螣蛇" to "騰蛇", "太阴" to "太陰", "六合" to "六合", "白虎" to "白虎", "玄武" to "玄武", "九地" to "九地", "九天" to "九天", "元极" to "太極")[godName] ?: godName
                AppLanguage.KO -> mapOf("值符" to "직부", "螣蛇" to "등사", "太阴" to "태음", "六合" to "육합", "白虎" to "백호", "玄武" to "현무", "九地" to "구지", "九天" to "구천", "元极" to "원극")[godName] ?: godName
                AppLanguage.VI -> mapOf("值符" to "Trực Phù", "螣蛇" to "Đằng Xà", "太阴" to "Thái Âm", "六合" to "Lục Hợp", "白虎" to "Bạch Hổ", "玄武" to "Huyền Vũ", "九地" to "Cửu Địa", "九天" to "Cửu Thiên", "元极" to "Nguyên Cực")[godName] ?: godName
                AppLanguage.TH -> mapOf("值符" to "จื่อฝู", "螣蛇" to "เถิงเสือ", "太阴" to "ไท่อิน", "六合" to "ลิ่วเหอ", "白虎" to "ไป๋หู่", "玄武" to "เสวียนอู่", "九地" to "จิ่วตี้", "九天" to "จิ่วเทียน", "元极" to "ไท่จี๋")[godName] ?: godName
                AppLanguage.ID -> mapOf("值符" to "Panglima", "螣蛇" to "Ular Api", "太阴" to "Yin Sejati", "六合" to "Enam Harmoni", "白虎" to "Harimau Putih", "玄武" to "Kura-kura Hitam", "九地" to "Sembilan Bumi", "九天" to "Sembilan Langit", "元极" to "Titik Pusat")[godName] ?: godName
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> godName
            }
        }

    val localizedPalaceName: String
        get() {
            val lang = LocalizationManager.shared.effectiveLanguage
            val hantMap = mapOf("东南" to "東南", "正南" to "正南", "西南" to "西南", "正东" to "正東", "中宫" to "中宮", "正西" to "正西", "东北" to "東北", "正北" to "正北", "西北" to "西北")
            val trigramHantMap = mapOf("巽" to "巽", "离" to "離", "坤" to "坤", "震" to "震", "兑" to "兌", "艮" to "艮", "坎" to "坎", "乾" to "乾", "太极" to "太極")

            return when (lang) {
                AppLanguage.ZH_HANT -> {
                    val parts = palaceName.split(" ", limit = 2)
                    if (parts.size == 2) {
                        val trigram = trigramHantMap[parts[1]] ?: parts[1].replace("宫", "宮")
                        "${hantMap[parts[0]] ?: parts[0]} $trigram"
                    } else {
                        hantMap[palaceName] ?: palaceName.replace("宫", "宮")
                    }
                }
                AppLanguage.JA -> {
                    val jaMap = mapOf("东南" to "南東", "正南" to "正南", "西南" to "南西", "正东" to "正東", "中宫" to "中宮", "正西" to "正西", "东北" to "北東", "正北" to "正北", "西北" to "北西")
                    val parts = palaceName.split(" ", limit = 2)
                    if (parts.size == 2) {
                        val trigram = trigramHantMap[parts[1]] ?: parts[1]
                        "${jaMap[parts[0]] ?: parts[0]} ($trigram)"
                    } else {
                        jaMap[palaceName] ?: palaceName
                    }
                }
                AppLanguage.KO -> {
                    val koMap = mapOf("东南" to "동남", "正南" to "정남", "西南" to "남서", "正东" to "정동", "中宫" to "중궁", "正西" to "정서", "东北" to "북동", "正北" to "정북", "西北" to "북서")
                    val trigramKoMap = mapOf("巽" to "손", "离" to "이", "坤" to "곤", "震" to "진", "兑" to "태", "艮" to "간", "坎" to "감", "乾" to "건", "太极" to "태극")
                    val parts = palaceName.split(" ", limit = 2)
                    if (parts.size == 2) {
                        "${koMap[parts[0]] ?: parts[0]} (${trigramKoMap[parts[1]] ?: parts[1]})"
                    } else {
                        koMap[palaceName] ?: palaceName
                    }
                }
                AppLanguage.VI -> {
                    val viMap = mapOf("东南" to "Đông Nam", "正南" to "Chính Nam", "西南" to "Tây Nam", "正东" to "Chính Đông", "中宫" to "Trung Cung", "正西" to "Chính Tây", "东北" to "Đông Bắc", "正北" to "Chính Bắc", "西北" to "Tây Bắc")
                    val trigramViMap = mapOf("巽" to "Tốn", "离" to "Ly", "坤" to "Khôn", "震" to "Chấn", "兑" to "Đoài", "艮" to "Cấn", "坎" to "Khảm", "乾" to "Càn", "太极" to "Thái Cực")
                    val parts = palaceName.split(" ", limit = 2)
                    if (parts.size == 2) {
                        "${viMap[parts[0]] ?: parts[0]} (${trigramViMap[parts[1]] ?: parts[1]})"
                    } else {
                        viMap[palaceName] ?: palaceName
                    }
                }
                AppLanguage.TH -> {
                    val thMap = mapOf("东南" to "ทิศตะวันออกเฉียงใต้", "正南" to "ทิศใต้", "西南" to "ทิศตะวันตกเฉียงใต้", "正东" to "ทิศตะวันออก", "中宫" to "จุดศูนย์กลาง", "正西" to "ทิศตะวันตก", "东北" to "ทิศตะวันออกเฉียงเหนือ", "正北" to "ทิศเหนือ", "西北" to "ทิศตะวันตกเฉียงเหนือ")
                    val trigramThMap = mapOf("巽" to "ซวิ่น", "离" to "หลี", "坤" to "คุน", "震" to "เจิ้น", "兑" to "ตุ้ย", "艮" to "เกิ้น", "坎" to "ขั่น", "乾" to "เฉียน", "太极" to "ไท่จี๋")
                    val parts = palaceName.split(" ", limit = 2)
                    if (parts.size == 2) {
                        "${thMap[parts[0]] ?: parts[0]} (${trigramThMap[parts[1]] ?: parts[1]})"
                    } else {
                        thMap[palaceName] ?: palaceName
                    }
                }
                AppLanguage.ID -> {
                    val idMap = mapOf("东南" to "Tenggara", "正南" to "Selatan", "西南" to "Barat Daya", "正东" to "Timur", "中宫" to "Pusat", "正西" to "Barat", "东北" to "Timur Laut", "正北" to "Utara", "西北" to "Barat Laut")
                    val trigramEnMap = mapOf("巽" to "Xun", "离" to "Li", "坤" to "Kun", "震" to "Zhen", "兑" to "Dui", "艮" to "Gen", "坎" to "Kan", "乾" to "Qian", "太极" to "Taiji")
                    val parts = palaceName.split(" ", limit = 2)
                    if (parts.size == 2) {
                        "${idMap[parts[0]] ?: parts[0]} (${trigramEnMap[parts[1]] ?: parts[1]})"
                    } else {
                        idMap[palaceName] ?: palaceName
                    }
                }
                AppLanguage.EN -> {
                    val enMap = mapOf("东南" to "Southeast", "正南" to "South", "西南" to "Southwest", "正东" to "East", "中宫" to "Center", "正西" to "West", "东北" to "Northeast", "正北" to "North", "西北" to "Northwest")
                    val trigramEnMap = mapOf("巽" to "Xun", "离" to "Li", "坤" to "Kun", "震" to "Zhen", "兑" to "Dui", "艮" to "Gen", "坎" to "Kan", "乾" to "Qian", "太极" to "Taiji")
                    val parts = palaceName.split(" ", limit = 2)
                    if (parts.size == 2) {
                        "${enMap[parts[0]] ?: parts[0]} (${trigramEnMap[parts[1]] ?: parts[1]})"
                    } else {
                        enMap[palaceName] ?: palaceName
                    }
                }
                AppLanguage.AUTO, AppLanguage.ZH_HANS -> palaceName
            }
        }
}

data class QimenChart(
    val title: String,
    val dunType: String,
    val juNumber: Int,
    val shichen: String,
    val bestDirection: String,
    val bestBearing: Double?,
    val bestReason: String,
    val worstDirection: String,
    val worstBearing: Double?,
    val worstReason: String,
    val cells: List<QimenPalaceCell>
) {
    val bestNavDirection: String get() = bestDirection
    val bestNavReason: String get() = bestReason
    val tabooDirections: String get() = worstDirection
}

class QimenEngine private constructor() {
    companion object {
        val instance: QimenEngine by lazy { QimenEngine() }
        val shared: QimenEngine get() = instance
    }

    fun resolveDoor(name: String): QimenDoor? {
        return eightDoors.firstOrNull { it.name == name }
    }

    private val nineStars = listOf("天蓬", "天芮", "天冲", "天辅", "天禽", "天心", "天柱", "天任", "天英")
    private val sixYiStems = listOf("戊", "己", "庚", "辛", "壬", "癸", "丁", "丙", "乙")
    private val luoShuFull = listOf(1, 2, 3, 4, 5, 6, 7, 8, 9)
    private val luoShuSkip = listOf(1, 8, 3, 4, 9, 2, 7, 6)

    private val eightDoors = listOf(
        QimenDoor("休门", 1, true, "大吉", "求名休闲大吉，水清木秀"),
        QimenDoor("生门", 8, true, "大吉", "求财置业大吉，土旺金生"),
        QimenDoor("伤门", 3, false, "凶", "讨债索敌宜，出行防伤灾"),
        QimenDoor("杜门", 4, false, "平", "潜伏隐匿避灾，闭藏门户"),
        QimenDoor("景门", 9, true, "吉", "文书考试宴请吉，火炎防急"),
        QimenDoor("死门", 2, false, "大凶", "吊丧刑戮宜，出行造葬大凶"),
        QimenDoor("惊门", 7, false, "凶", "捕盗争讼宜，常人动则招惊"),
        QimenDoor("开门", 6, true, "大吉", "开业远行见贵大吉，通达显赫")
    )

    private val displayPalaceDefs = listOf(
        Triple(4, "东南 巽宫", 135.0),
        Triple(9, "正南 离宫", 180.0),
        Triple(2, "西南 坤宫", 225.0),
        Triple(3, "正东 震宫", 90.0),
        Triple(5, "中央 太极", 0.0),
        Triple(7, "正西 兑宫", 270.0),
        Triple(8, "东北 艮宫", 45.0),
        Triple(1, "正北 坎宫", 0.0),
        Triple(6, "西北 乾宫", 315.0)
    )

    private fun flightFull(from: Int, forward: Boolean): List<Int> {
        val startIdx = luoShuFull.indexOf(from).let { if (it >= 0) it else 0 }
        val result = mutableListOf<Int>()
        for (i in 0 until 9) {
            val idx = if (forward) (startIdx + i) % 9 else (startIdx - i + 9) % 9
            result.add(luoShuFull[idx])
        }
        return result
    }

    private fun flightSkip(from: Int, forward: Boolean): List<Int> {
        val startIdx = luoShuSkip.indexOf(from).let { if (it >= 0) it else 0 }
        val result = mutableListOf<Int>()
        for (i in 0 until 8) {
            val idx = if (forward) (startIdx + i) % 8 else (startIdx - i + 8) % 8
            result.add(luoShuSkip[idx])
        }
        return result
    }

    private fun flySkip(start: Int, steps: Int, forward: Boolean): Int {
        val idx = luoShuSkip.indexOf(start).let { if (it >= 0) it else 0 }
        val targetIdx = if (forward) (idx + steps) % 8 else (idx - steps % 8 + 8) % 8
        return luoShuSkip[targetIdx]
    }

    private fun dayGanZhiIndex(date: Date): Int {
        val cal = Calendar.getInstance()
        cal.time = date
        val y = cal.get(Calendar.YEAR)
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        val a = (14 - m) / 12
        val yy = y + 4800 - a
        val mm = m + 12 * a - 3
        val jdn = d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045
        return ((jdn + 49) % 60 + 60) % 60
    }

    fun calculateChart(date: Date = Date(), heading: Double = 0.0): QimenChart {
        val cal = Calendar.getInstance()
        cal.time = date
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val solarTermIndex = SolarTimeCalculator.instance.solarTermIndex(date)

        val isYangDun = solarTermIndex < 11 || solarTermIndex >= 23
        val forward = isYangDun
        val dunType = if (isYangDun) "阳遁" else "阴遁"

        val dayGz = dayGanZhiIndex(date)
        val fuHead = dayGz - (dayGz % 5)
        val yuanIndex = when (fuHead % 15) {
            0 -> 0
            5 -> 2
            10 -> 1
            else -> 0
        }

        val yangBureaus = mapOf(
            23 to listOf(1, 7, 4), 0 to listOf(2, 8, 5), 1 to listOf(3, 9, 6),
            2 to listOf(8, 5, 2), 3 to listOf(9, 6, 3), 4 to listOf(1, 7, 4),
            5 to listOf(3, 9, 6), 6 to listOf(4, 1, 7), 7 to listOf(5, 2, 8),
            8 to listOf(4, 1, 7), 9 to listOf(5, 2, 8), 10 to listOf(6, 3, 9)
        )
        val yinBureaus = mapOf(
            11 to listOf(9, 3, 6), 12 to listOf(8, 2, 5), 13 to listOf(7, 1, 4),
            14 to listOf(2, 5, 8), 15 to listOf(1, 4, 7), 16 to listOf(9, 3, 6),
            17 to listOf(7, 1, 4), 18 to listOf(6, 9, 3), 19 to listOf(5, 8, 2),
            20 to listOf(5, 8, 2), 21 to listOf(4, 7, 1), 22 to listOf(3, 6, 9)
        )
        val bureauTable = if (isYangDun) yangBureaus else yinBureaus
        val juNumber = bureauTable[solarTermIndex]?.get(yuanIndex) ?: 1
        val yuanName = listOf("上元", "中元", "下元")[yuanIndex]
        val title = "【${dunType}${juNumber}局 · 拆补${yuanName}】"

        val dayRef = Date(date.time + 3600000L)
        val effDayGz = dayGanZhiIndex(dayRef)
        val dayStem = effDayGz % 10
        val hourBranch = ((hour + 1) / 2) % 12
        val hourStem = ((dayStem % 5) * 2 + hourBranch) % 10
        val stems = listOf("甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸")
        val branches = listOf("子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥")
        val hourStemChar = stems[hourStem]
        val shichenStr = "${hourStemChar}${branches[hourBranch]}时"

        val shichenGz = ((effDayGz * 12 + hourBranch) % 60 + 60) % 60
        val xun = shichenGz / 10

        val diPanStem = mutableMapOf<Int, String>()
        val diPlacement = flightFull(juNumber, forward)
        for ((i, palace) in diPlacement.withIndex()) {
            diPanStem[palace] = sixYiStems[i]
        }
        val stemToPalace = diPanStem.entries.associate { (k, v) -> v to k }
        val xunToSixYi = listOf("戊", "己", "庚", "辛", "壬", "癸")
        val xunHeadSixYi = xunToSixYi[xun]
        val zhiFuPalace = stemToPalace[xunHeadSixYi] ?: (diPlacement.firstOrNull() ?: 1)

        val doorPalaceToName = mapOf(1 to "休门", 2 to "死门", 3 to "伤门", 4 to "杜门", 9 to "景门", 8 to "生门", 7 to "惊门", 6 to "开门")
        val doorInfo = eightDoors.associate { it.name to Pair(it.luckType, it.isAuspicious) }

        val zhiFuStarStart = if (hourStemChar == "甲") zhiFuPalace else (stemToPalace[hourStemChar] ?: zhiFuPalace)
        val stepsIntoXun = shichenGz % 10
        val zhiShiStart = flySkip(zhiFuPalace, stepsIntoXun, forward)

        val starOrigin = flightFull(zhiFuPalace, forward)
        val starDest = flightFull(zhiFuStarStart, forward)
        val tianStar = mutableMapOf<Int, String>()
        val tianStem = mutableMapOf<Int, String>()
        for (k in 0 until 9) {
            val dest = starDest[k]
            val origin = starOrigin[k]
            tianStar[dest] = nineStars[origin - 1]
            tianStem[dest] = diPanStem[origin] ?: "戊"
        }

        val doorOrigin = flightSkip(zhiFuPalace, forward)
        val doorDest = flightSkip(zhiShiStart, forward)
        val tianDoor = mutableMapOf<Int, String>()
        for (k in 0 until 8) {
            tianDoor[doorDest[k]] = doorPalaceToName[doorOrigin[k]] ?: "休门"
        }

        val godOrder = if (isYangDun)
            listOf("值符", "螣蛇", "太阴", "六合", "白虎", "玄武", "九地", "九天")
        else
            listOf("值符", "螣蛇", "太阴", "六合", "玄武", "白虎", "九地", "九天")
        val godDest = flightSkip(zhiFuStarStart, forward)
        val tianGod = mutableMapOf<Int, String>()
        for (k in 0 until 8) {
            tianGod[godDest[k]] = godOrder[k]
        }

        val normHeading = (heading % 360.0 + 360.0) % 360.0
        val currentFacingPalace = when (normHeading) {
            in 22.5..67.5 -> 8
            in 67.5..112.5 -> 3
            in 112.5..157.5 -> 4
            in 157.5..202.5 -> 9
            in 202.5..247.5 -> 2
            in 247.5..292.5 -> 7
            in 292.5..337.5 -> 6
            else -> 1
        }

        val cells = mutableListOf<QimenPalaceCell>()
        for (def in displayPalaceDefs) {
            val p = def.first
            val name = def.second
            val angle = def.third
            val isCenter = (p == 5)
            val isFacing = (p == currentFacingPalace)

            val door = if (isCenter) "中宫" else (tianDoor[p] ?: "休门")
            val star = if (isCenter) (tianStar[5] ?: "天禽") else (tianStar[p] ?: nineStars[p - 1])
            val god = if (isCenter) "元极" else (tianGod[p] ?: "元极")
            val tian = tianStem[p] ?: "戊"
            val di = diPanStem[p] ?: "戊"

            val info = doorInfo[door] ?: Pair("平", false)
            val luck = if (isCenter) "平" else info.first
            val ausp = if (isCenter) false else info.second

            cells.add(
                QimenPalaceCell(
                    id = p,
                    palaceName = name,
                    direction = name.substringBefore(" "),
                    angleCenter = angle,
                    doorName = door,
                    starName = star,
                    godName = god,
                    tianPanGan = tian,
                    diPanGan = di,
                    isAuspicious = ausp,
                    luckType = luck,
                    isCenter = isCenter,
                    isFacingDirection = isFacing
                )
            )
        }

        val bestPalace = cells.filter { !it.isCenter && it.isAuspicious }.maxByOrNull {
            if (it.luckType == "大吉") 3 else if (it.luckType == "吉") 2 else 1
        } ?: cells.first { !it.isCenter }

        val worstPalace = cells.filter { !it.isCenter && !it.isAuspicious }.minByOrNull {
            if (it.luckType == "大凶") 0 else if (it.luckType == "凶") 1 else 2
        } ?: cells.last { !it.isCenter }

        return QimenChart(
            title = title,
            dunType = dunType,
            juNumber = juNumber,
            shichen = shichenStr,
            bestDirection = "${bestPalace.direction} (${bestPalace.doorName})",
            bestBearing = bestPalace.angleCenter,
            bestReason = "三吉门生旺之方，利于开拓洽商、求财出行",
            worstDirection = "${worstPalace.direction} (${worstPalace.doorName})",
            worstBearing = worstPalace.angleCenter,
            worstReason = "落入凶门闭塞，不利远行修造，宜静守避忌",
            cells = cells
        )
    }
}

