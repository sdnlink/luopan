package com.example.yiijingcompass.model

import java.util.Locale

/**
 * 一百二十分金数据结构与吉凶断语
 * 罗盘核心层次：每山 15° 细分为 5 位分金，每位 3°，共 120 分金。
 */
data class Fenjin120Item(
    val mountainName: String,    // 所属二十四山 (如 "子")
    val index: Int,              // 1..5
    val jiaziName: String,       // 甲子名称 (如 "甲子", "丙子", "戊子", "庚子", "壬子")
    val startAngle: Double,      // 起始角度 (0 ~ 360°)
    val endAngle: Double,        // 终止角度 (0 ~ 360°)
    val centerAngle: Double,     // 中心角度 (0 ~ 360°)
    val grade: String,           // "旺相大吉", "孤虚差错", "龟甲空亡", "差错退财", "差错退气", "平稳"
    val isAuspicious: Boolean,   // 是否为可用吉度 (丙子、庚子等珠宝线)
    val lore: String             // 秘诀断语
) {
    val id: String get() = "$mountainName-$index"

    val localizedMountainName: String
        get() {
            val m = Mountain24Data.mountains.firstOrNull { it.name == mountainName }
            return m?.localizedName ?: "${mountainName}山"
        }

    val localizedJiaziName: String
        get() {
            if (jiaziName.length < 2) return jiaziName
            val stemChar = jiaziName.substring(0, 1)
            val branchChar = jiaziName.substring(1, 2)
            val lang = LocalizationManager.shared.effectiveLanguage

            if (lang == AppLanguage.AUTO || lang == AppLanguage.ZH_HANS || lang == AppLanguage.ZH_HANT) {
                return jiaziName
            }

            val stemMap = mapOf(
                "甲" to mapOf(AppLanguage.EN to "Jia", AppLanguage.JA to "甲", AppLanguage.KO to "갑", AppLanguage.VI to "Giáp", AppLanguage.TH to "เจี่ย", AppLanguage.ID to "Jia"),
                "乙" to mapOf(AppLanguage.EN to "Yi", AppLanguage.JA to "乙", AppLanguage.KO to "을", AppLanguage.VI to "Ất", AppLanguage.TH to "อี่", AppLanguage.ID to "Yi"),
                "丙" to mapOf(AppLanguage.EN to "Bing", AppLanguage.JA to "丙", AppLanguage.KO to "병", AppLanguage.VI to "Bính", AppLanguage.TH to "ปิ่ง", AppLanguage.ID to "Bing"),
                "丁" to mapOf(AppLanguage.EN to "Ding", AppLanguage.JA to "丁", AppLanguage.KO to "정", AppLanguage.VI to "Đinh", AppLanguage.TH to "ติง", AppLanguage.ID to "Ding"),
                "戊" to mapOf(AppLanguage.EN to "Wu", AppLanguage.JA to "戊", AppLanguage.KO to "무", AppLanguage.VI to "Mậu", AppLanguage.TH to "อู้", AppLanguage.ID to "Wu"),
                "己" to mapOf(AppLanguage.EN to "Ji", AppLanguage.JA to "己", AppLanguage.KO to "기", AppLanguage.VI to "Kỷ", AppLanguage.TH to "จี่", AppLanguage.ID to "Ji"),
                "庚" to mapOf(AppLanguage.EN to "Geng", AppLanguage.JA to "庚", AppLanguage.KO to "경", AppLanguage.VI to "Canh", AppLanguage.TH to "เกิง", AppLanguage.ID to "Geng"),
                "辛" to mapOf(AppLanguage.EN to "Xin", AppLanguage.JA to "辛", AppLanguage.KO to "신", AppLanguage.VI to "Tân", AppLanguage.TH to "ซิน", AppLanguage.ID to "Xin"),
                "壬" to mapOf(AppLanguage.EN to "Ren", AppLanguage.JA to "壬", AppLanguage.KO to "임", AppLanguage.VI to "Nhâm", AppLanguage.TH to "เหริน", AppLanguage.ID to "Ren"),
                "癸" to mapOf(AppLanguage.EN to "Gui", AppLanguage.JA to "癸", AppLanguage.KO to "계", AppLanguage.VI to "Quý", AppLanguage.TH to "กุ่ย", AppLanguage.ID to "Gui")
            )
            val branchMap = mapOf(
                "子" to mapOf(AppLanguage.EN to "Zi", AppLanguage.JA to "子", AppLanguage.KO to "자", AppLanguage.VI to "Tý", AppLanguage.TH to "จื่อ", AppLanguage.ID to "Zi"),
                "丑" to mapOf(AppLanguage.EN to "Chou", AppLanguage.JA to "丑", AppLanguage.KO to "축", AppLanguage.VI to "Sửu", AppLanguage.TH to "โฉ่ว", AppLanguage.ID to "Chou"),
                "寅" to mapOf(AppLanguage.EN to "Yin", AppLanguage.JA to "寅", AppLanguage.KO to "인", AppLanguage.VI to "Dần", AppLanguage.TH to "อิ๋น", AppLanguage.ID to "Yin"),
                "卯" to mapOf(AppLanguage.EN to "Mao", AppLanguage.JA to "卯", AppLanguage.KO to "묘", AppLanguage.VI to "Mão", AppLanguage.TH to "เหมา", AppLanguage.ID to "Mao"),
                "辰" to mapOf(AppLanguage.EN to "Chen", AppLanguage.JA to "辰", AppLanguage.KO to "진", AppLanguage.VI to "Thìn", AppLanguage.TH to "เฉิน", AppLanguage.ID to "Chen"),
                "巳" to mapOf(AppLanguage.EN to "Si", AppLanguage.JA to "巳", AppLanguage.KO to "사", AppLanguage.VI to "Tỵ", AppLanguage.TH to "ซื่อ", AppLanguage.ID to "Si"),
                "午" to mapOf(AppLanguage.EN to "Wu", AppLanguage.JA to "午", AppLanguage.KO to "오", AppLanguage.VI to "Ngọ", AppLanguage.TH to "อู่", AppLanguage.ID to "Wu"),
                "未" to mapOf(AppLanguage.EN to "Wei", AppLanguage.JA to "未", AppLanguage.KO to "미", AppLanguage.VI to "Mùi", AppLanguage.TH to "เว่ย", AppLanguage.ID to "Wei"),
                "申" to mapOf(AppLanguage.EN to "Shen", AppLanguage.JA to "申", AppLanguage.KO to "신", AppLanguage.VI to "Thân", AppLanguage.TH to "เซิน", AppLanguage.ID to "Shen"),
                "酉" to mapOf(AppLanguage.EN to "You", AppLanguage.JA to "酉", AppLanguage.KO to "유", AppLanguage.VI to "Dậu", AppLanguage.TH to "โหย่ว", AppLanguage.ID to "You"),
                "戌" to mapOf(AppLanguage.EN to "Xu", AppLanguage.JA to "戌", AppLanguage.KO to "술", AppLanguage.VI to "Tuất", AppLanguage.TH to "ซีว์", AppLanguage.ID to "Xu"),
                "亥" to mapOf(AppLanguage.EN to "Hai", AppLanguage.JA to "亥", AppLanguage.KO to "해", AppLanguage.VI to "Hợi", AppLanguage.TH to "ไฮ่", AppLanguage.ID to "Hai")
            )

            val s = stemMap[stemChar]?.get(lang) ?: stemChar
            val b = branchMap[branchChar]?.get(lang) ?: branchChar
            return when (lang) {
                AppLanguage.EN, AppLanguage.ID -> "$s-$b"
                AppLanguage.VI -> "$s $b"
                AppLanguage.KO -> "$s$b ($jiaziName)"
                AppLanguage.JA -> "$jiaziName ($s$b)"
                AppLanguage.TH -> "$s-$b"
                else -> jiaziName
            }
        }

    val localizedGrade: String
        get() = when (LocalizationManager.instance.effectiveLanguage) {
            AppLanguage.ZH_HANT -> grade.replace("孤虚", "孤虛")
                .replace("差错", "差錯")
                .replace("退财", "退財")
                .replace("龟", "龜")
                .replace("平稳", "平穩")
            AppLanguage.EN -> when (grade) {
                "旺相大吉" -> "Auspicious Prosperity"
                "孤虚差错" -> "Lone Void Error"
                "差错退财" -> "Error · Wealth Drain"
                "龟甲空亡" -> "Turtle-Shell Void"
                "差错退气" -> "Error · Retreating Qi"
                else -> "Balanced & Neutral"
            }
            AppLanguage.JA -> when (grade) {
                "旺相大吉" -> "旺相大吉"
                "孤虚差错" -> "孤虚差錯"
                "差错退财" -> "差錯退財"
                "龟甲空亡" -> "亀甲空亡"
                "差错退气" -> "差錯退気"
                else -> "平穏"
            }
            AppLanguage.KO -> when (grade) {
                "旺相大吉" -> "왕상대길 (旺相大吉)"
                "孤虚差错" -> "고허착오 (孤虛差錯)"
                "差错退财" -> "착오퇴재 (差錯退財)"
                "龟甲空亡" -> "귀갑공망 (龜甲空亡)"
                "差错退气" -> "착오퇴기 (差錯退氣)"
                else -> "평온 (平穩)"
            }
            AppLanguage.VI -> when (grade) {
                "旺相大吉" -> "Vượng Tướng Đại Cát"
                "孤虚差错" -> "Cô Hư Sai Thất"
                "差错退财" -> "Sai Thất Thoái Tài"
                "龟甲空亡" -> "Quy Giáp Không Vong"
                "差错退气" -> "Sai Thất Thoái Khí"
                else -> "Bình Ổn"
            }
            AppLanguage.TH -> when (grade) {
                "旺相大吉" -> "มหามงคลรุ่งเรืองยิ่ง"
                "孤虚差错" -> "พลังโดดเดี่ยวว่างเปล่าผิดพลาด"
                "差错退财" -> "ผิดพลาดทรัพย์รั่วไหล"
                "龟甲空亡" -> "ช่องว่างกระดองเต่าอวมงคล"
                "差错退气" -> "ผิดพลาดพลังถดถอย"
                else -> "ราบเรียบสมดุล"
            }
            AppLanguage.ID -> when (grade) {
                "旺相大吉" -> "Sangat Menguntungkan & Makmur"
                "孤虚差错" -> "Kekosongan Terasing & Kekeliruan"
                "差错退财" -> "Kekeliruan Menguras Rezeki"
                "龟甲空亡" -> "Kekosongan Cangkang Kura-kura"
                "差错退气" -> "Kekeliruan Energi Melemah"
                else -> "Stabil & Seimbang"
            }
            else -> grade
        }

    val localizedLore: String
        get() {
            val lang = LocalizationManager.instance.effectiveLanguage
            val firstStem = if (jiaziName.isNotEmpty()) jiaziName.substring(0, 1) else ""
            val baseLore = when (lang) {
                AppLanguage.ZH_HANT -> lore.replace("差错", "差錯")
                    .replace("退财", "退財")
                    .replace("旺相", "旺相")
                    .replace("气", "氣")
                    .replace("煞气", "煞氣")
                    .replace("龟", "龜")
                AppLanguage.EN -> when (firstStem) {
                    "甲" -> "Lone-void sha qi; indicates financial decline and weakened vitality. Avoid using this facing."
                    "乙" -> "Excess yin qi; causes covert wealth drainage and makes qi gathering difficult."
                    "丙" -> "True needle yang fire in prosperity; brings wealth and enduring fortune, highly auspicious."
                    "丁" -> "Yin fire well-positioned; flourishing prosperity and honor, highly auspicious."
                    "戊" -> "Yellow 5 turtle-shell void; brings misfortune and prolonged illness, strictly avoid!"
                    "己" -> "Yin earth void; leads to loss and decline, geomancers should never select this line."
                    "庚" -> "Yang metal in prosperity; martial nobility and broad authority, highly auspicious."
                    "辛" -> "Pure yin metal; refined culture and great abundance, highly auspicious."
                    "壬" -> "Floating water lone-void sha; loss of both family vitality and wealth, do not violate."
                    "癸" -> "Degree of retreating qi; difficult to prosper or maintain responsibility."
                    else -> "Neutral balanced qi; use standard judgment."
                }
                AppLanguage.JA -> when (firstStem) {
                    "甲" -> "孤虚の煞気、冷退破財を招き人丁凋零す。立向に適さず。"
                    "乙" -> "陰気過重、密かな損財を招き集気困難なり。"
                    "丙" -> "正針陽火旺相、招財進宝にして富貴久遠、大吉として活用可。"
                    "丁" -> "陰火得位、人財両旺、科甲連登にして大吉活用可。"
                    "戊" -> "五黄土煞亀甲大空亡、横禍官非・病気衰弱を招く。厳禁すべし！"
                    "己" -> "陰土空亡衰絶、後継衰退を主る。地師慎んで用いるべからず！"
                    "庚" -> "陽金生旺、武貴栄達にして威勢四方に轟く、大吉活用可。"
                    "辛" -> "陰金純正、文雅富厚にして金玉満堂、大吉活用可。"
                    "壬" -> "水泛木浮の孤虚煞、人財倶に空亡す。慎みて犯すなかれ。"
                    "癸" -> "退気の度、発展困難にして大任に耐え難し。"
                    else -> "気場平穏にして常規の判定に従う。"
                }
                AppLanguage.KO -> when (firstStem) {
                    "甲" -> "고허살기(孤虛煞氣), 냉퇴파재와 인구 조령을 주관하므로 입향에 불가함."
                    "乙" -> "음기가 지나쳐 암암리에 재물을 소모하고 기를 모으기 어려움."
                    "丙" -> "정침 양화가 왕상하여 재물을 부르고 부귀가 영원하여 대길함."
                    "丁" -> "음화가 득위하여 인재와 재물이 모두 번창하고 과거급제하여 대길함."
                    "戊" -> "오황토살 귀갑대공망으로 재화와 관재, 오랜 병환을 부르니 엄히 피할 것!"
                    "己" -> "음토 공망패절로 후손 단절과 쇠락을 부르니 지사는 결코 놓지 말 것!"
                    "庚" -> "양금이 생왕하여 무귀로 현달하고 사방에 위세를 떨치니 대길함."
                    "辛" -> "음금이 순정하여 문아부후하고 금옥이 만당하니 대길함."
                    "壬" -> "수범목부 고허살로 인재와 재물이 모두 비니 범하지 말 것."
                    "癸" -> "퇴기의 도수로 발전하기 어렵고 큰 책임을 감당하기 어려움."
                    else -> "기운이 평온하여 일반적인 판단을 따름."
                }
                AppLanguage.VI -> when (firstStem) {
                    "甲" -> "Sát khí cô hư, chủ thoái tài tổn đinh, suy bại không nên lập hướng."
                    "乙" -> "Âm khí quá nặng, chủ hao tán tài lộc, khó tụ khí lành."
                    "丙" -> "Chính châm dương hỏa vượng tướng, chiêu tài tiến bảo, phú quý trường cửu, đại cát khả dụng."
                    "丁" -> "Âm hỏa đắc vị, đinh tài lưỡng vượng, khoa giáp liên đăng, đại cát khả dụng."
                    "戊" -> "Ngũ hoàng thổ sát quy giáp đại không vong, chủ hoạn nạn quan phi, bệnh tật triền miên, tối kỵ!"
                    "己" -> "Âm thổ không vong bại tuyệt, chủ tuyệt tự suy bại, thầy phong thủy chớ khinh suất!"
                    "庚" -> "Dương kim sinh vượng, võ quý hiển đạt, uy chấn bốn phương, đại cát khả dụng."
                    "辛" -> "Âm kim thuần chính, văn nhã phú hậu, kim ngọc mãn đường, đại cát khả dụng."
                    "壬" -> "Thủy phiếm mộc phù cô hư sát, đinh tài lưỡng không, cẩn thận chớ phạm."
                    "癸" -> "Độ số thoái khí, khó nỗi phát vinh, khó đảm đương việc lớn."
                    else -> "Khí trường bình ổn, vận dụng bình thường."
                }
                AppLanguage.TH -> when (firstStem) {
                    "甲" -> "ไอพลังโดดเดี่ยวว่างเปล่า นำพาความเสื่อมถอยและสูญเสียทรัพย์ ไม่ควรตั้งทิศ"
                    "乙" -> "พลังหยินหนักเกินไป ทำให้ทรัพย์สินรั่วไหลอย่างเงียบๆ กักเก็บพลังยาก"
                    "丙" -> "ธาตุไฟหยางเข็มตรงรุ่งเรือง เรียกทรัพย์สินเงินทอง ร่ำรวยยั่งยืน มหามงคลใช้ได้"
                    "丁" -> "ธาตุไฟหยินได้ตำแหน่ง ทรัพย์และครอบครัวเจริญรุ่งเรือง มหามงคลใช้ได้"
                    "戊" -> "ดาวเบญจดินกระดองเต่าอวมงคล เกิดคดีความและเจ็บป่วยเรื้อรัง ต้องหลีกเลี่ยงเด็ดขาด!"
                    "己" -> "ธาตุดินหยินสูญสิ้น ดับสูญและเสื่อมถอย ซินแสพึงระวังอย่าใช้!"
                    "庚" -> "ธาตุทองหยางรุ่งเรือง เจริญในยศศักดิ์และอำนาจ มหามงคลใช้ได้"
                    "辛" -> "ธาตุทองหยินบริสุทธิ์ สง่างามร่ำรวย เงินทองเต็มเรือน มหามงคลใช้ได้"
                    "壬" -> "น้ำพัดไม้ลอยพลังโดดเดี่ยว ทั้งคนและทรัพย์สูญเปล่า ระวังอย่าละเมิด"
                    "癸" -> "องศาพลังถดถอย เติบโตยาก ไม่อาจแบกรับภาระใหญ่หลวงได้"
                    else -> "พลังงานสมดุล ใช้การประเมินทิศตามปกติ"
                }
                AppLanguage.ID -> when (firstStem) {
                    "甲" -> "Energi sha kesepian kosong; menandakan kemunduran rezeki dan kelemahan keluarga. Hindari arah ini."
                    "乙" -> "Energi yin berlebihan; menyebabkan kebocoran rezeki tersembunyi dan sulit mengumpulkan qi."
                    "丙" -> "Jarum sejati api yang makmur; menarik kemakmuran dan kekayaan abadi, sangat menguntungkan."
                    "丁" -> "Api yin pada posisi tepat; keluarga dan rezeki makmur, sangat menguntungkan."
                    "戊" -> "Bintang 5 tanah kekosongan kura-kura; membawa musibah dan penyakit berkepanjangan, hindari keras!"
                    "己" -> "Tanah yin kehancuran; membawa kepunahan dan kemunduran, geomancer jangan gunakan!"
                    "庚" -> "Logam yang makmur; kemuliaan keberanian dan kewibawaan besar, sangat menguntungkan."
                    "辛" -> "Logam yin murni; elegan, makmur, dan berlimpah emas permata, sangat menguntungkan."
                    "壬" -> "Air banjir sha terasing; kehilangan keluarga dan rezeki, berhati-hatilah."
                    "癸" -> "Derajat energi mundur; sulit berkembang dan menanggung tanggung jawab besar."
                    else -> "Energi seimbang; gunakan penilaian biasa."
                }
                else -> lore
            }
            return "$baseLore\n\n(出处：传统罗盘一百二十分金口诀)"
        }
}

/**
 * 一百二十分金权威数据库与检索器
 */
class Fenjin120Data private constructor() {
    companion object {
        val instance: Fenjin120Data by lazy { Fenjin120Data() }
        val shared: Fenjin120Data get() = instance
    }

    val allFenjin: List<Fenjin120Item>

    private val stemTypes = mapOf(
        "甲" to Triple("孤虚差错", false, "孤虚煞气，主冷退破财，丁口凋零，不宜立向。"),
        "乙" to Triple("差错退财", false, "阴气过重，主暗耗损财，难以聚气。"),
        "丙" to Triple("旺相大吉", true, "正针阳火旺相，招财进宝，富贵绵远，大吉可用。"),
        "丁" to Triple("旺相大吉", true, "阴火得位，丁财两旺，科甲联登，大吉可用。"),
        "戊" to Triple("龟甲空亡", false, "五黄土煞龟甲大空亡，主横祸官非、病榻缠绵，切忌犯之！"),
        "己" to Triple("龟甲空亡", false, "阴土空亡败绝，主绝嗣衰败，地师慎勿轻下！"),
        "庚" to Triple("旺相大吉", true, "阳金生旺，武贵显达，威震四方，大吉可用。"),
        "辛" to Triple("旺相大吉", true, "阴金纯正，文雅富厚，金玉满堂，大吉可用。"),
        "壬" to Triple("孤虚差错", false, "水泛木浮孤虚煞，丁财两空，慎莫相犯。"),
        "癸" to Triple("差错退气", false, "退气之度，难以发皇，难当大任。")
    )

    init {
        val items = mutableListOf<Fenjin120Item>()
        val mountains = Mountain24Data.instance.mountains

        val branchGroups = intArrayOf(0, 1, 3, 4, 6, 7, 9, 10)
        val branchNames = arrayOf("子", "丑", "卯", "辰", "午", "未", "酉", "戌")
        val stems = arrayOf("甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸")

        for (m in mountains) {
            val group = Math.min(Math.max(m.id / 3, 0), branchGroups.size - 1)
            val branchIndex = branchGroups[group]
            val branch = branchNames[group]
            val firstStemIndex = branchIndex % 2

            for (i in 0 until 5) {
                val jiazi = "${stems[firstStemIndex + i * 2]}$branch"
                val startA = (m.startAngle + i * 3.0) % 360.0
                val endA = (m.startAngle + (i + 1) * 3.0) % 360.0
                val centerA = (m.startAngle + i * 3.0 + 1.5) % 360.0

                val firstChar = if (jiazi.isNotEmpty()) jiazi.substring(0, 1) else ""
                val meta = stemTypes[firstChar] ?: Triple("平稳", false, "气场平平")

                items.add(
                    Fenjin120Item(
                        mountainName = m.name,
                        index = i + 1,
                        jiaziName = jiazi,
                        startAngle = startA,
                        endAngle = endA,
                        centerAngle = centerA,
                        grade = meta.first,
                        isAuspicious = meta.second,
                        lore = meta.third
                    )
                )
            }
        }
        allFenjin = items
    }

    fun resolveFenjin(angle: Double): Fenjin120Item {
        val norm = (angle % 360.0 + 360.0) % 360.0
        for (item in allFenjin) {
            if (item.startAngle < item.endAngle) {
                if (norm >= item.startAngle && norm < item.endAngle) {
                    return item
                }
            } else {
                // 跨越 0°/360° 正北子山分金
                if (norm >= item.startAngle || norm < item.endAngle) {
                    return item
                }
            }
        }
        return allFenjin.firstOrNull() ?: Fenjin120Item(
            mountainName = "子",
            index = 1,
            jiaziName = "甲子",
            startAngle = 0.0,
            endAngle = 3.0,
            centerAngle = 1.5,
            grade = "平稳",
            isAuspicious = false,
            lore = "气场平平"
        )
    }
}
