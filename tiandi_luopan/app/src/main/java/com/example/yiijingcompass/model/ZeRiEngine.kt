package com.example.yiijingcompass.model

import java.util.Calendar
import java.util.Date

// MARK: - 动土择日吉凶分析引擎 (ZeRi Engine - PRD 择日分析)

data class ZeRiAnalysis(
    val fourPillarsText: String,
    val overallStatus: String,
    val isAuspicious: Boolean,
    val suiPoWarning: String?,
    val yuePoWarning: String?,
    val sanShaWarning: String?,
    val sittingClashWarning: String?,
    val detailsText: String,
    val yiActivities: List<String>,
    val jiActivities: List<String>
)

class ZeRiEngine private constructor() {
    companion object {
        val instance: ZeRiEngine by lazy { ZeRiEngine() }
    }

    private val stems = arrayOf("甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸")
    private val branches = arrayOf("子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥")

    // 地支六冲
    private val clashMap = mapOf(
        "子" to "午", "午" to "子",
        "丑" to "未", "未" to "丑",
        "寅" to "申", "申" to "寅",
        "卯" to "酉", "酉" to "卯",
        "辰" to "戌", "戌" to "辰",
        "巳" to "亥", "亥" to "巳"
    )

    fun analyze(sitting: Mountain24Item, date: Date = Date()): ZeRiAnalysis {
        return analyze(date, sitting)
    }

    fun analyze(date: Date, sitting: Mountain24Item): ZeRiAnalysis {
        val calendar = Calendar.getInstance()
        calendar.time = date
        val year = calendar.get(Calendar.YEAR)
        val month = calendar.get(Calendar.MONTH) + 1
        val day = calendar.get(Calendar.DAY_OF_MONTH)
        val hour = calendar.get(Calendar.HOUR_OF_DAY)

        // 子初 (23:00) 换日
        val dayCalendar = Calendar.getInstance()
        dayCalendar.time = date
        if (hour >= 23) {
            dayCalendar.add(Calendar.DAY_OF_MONTH, 1)
        }
        val pillarYear = dayCalendar.get(Calendar.YEAR)
        val pillarMonth = dayCalendar.get(Calendar.MONTH) + 1
        val pillarDay = dayCalendar.get(Calendar.DAY_OF_MONTH)

        val lang = LocalizationManager.shared.effectiveLanguage

        // 1. 年柱干支 (立春交岁)
        val termIndex = SolarTimeCalculator.instance.solarTermIndex(date)
        val isBeforeLiChun = SolarTimeCalculator.instance.isBeforeLiChun(date)
        val gzYear = if (isBeforeLiChun) (year - 1) else year
        val yOffset = (gzYear - 4) % 60
        val yearStem = stems[((yOffset % 10) + 10) % 10]
        val yearBranch = branches[((yOffset % 12) + 12) % 12]

        // 2. 月柱干支 (五虎遁年起月诀)
        val mBranchIdx = if (termIndex < 2) {
            1 // 小寒、大寒：丑月
        } else {
            (2 + (termIndex - 2) / 2) % 12
        }
        val mBranch = branches[mBranchIdx]
        val stemIdx = stems.indexOf(yearStem).let { if (it >= 0) it else 0 }
        val mStemStart = (stemIdx % 5) * 2 + 2
        val mStem = stems[(mStemStart + (mBranchIdx - 2 + 12) % 12) % 10]

        // 3. 日柱干支 (高精度儒略日算法)
        val a = (14 - pillarMonth) / 12
        val y = pillarYear + 4800 - a
        val m = pillarMonth + 12 * a - 3
        val jdn = pillarDay + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
        val dayGZIndex = (jdn + 49) % 60
        val dayStem = stems[((dayGZIndex % 10) + 10) % 10]
        val dayBranch = branches[((dayGZIndex % 12) + 12) % 12]

        // 4. 时柱干支 (五鼠遁日起时诀)
        val hBranchIdx = ((hour + 1) / 2) % 12
        val hBranch = branches[hBranchIdx]
        val dStemIdx = stems.indexOf(dayStem).let { if (it >= 0) it else 0 }
        val hStemStart = (dStemIdx % 5) * 2
        val hStem = stems[(hStemStart + hBranchIdx) % 10]

        val pillars = when (lang) {
            AppLanguage.EN -> {
                val pinyinStems = mapOf("甲" to "Jia", "乙" to "Yi", "丙" to "Bing", "丁" to "Ding", "戊" to "Wu", "己" to "Ji", "庚" to "Geng", "辛" to "Xin", "壬" to "Ren", "癸" to "Gui")
                val pinyinBranches = mapOf("子" to "Zi", "丑" to "Chou", "寅" to "Yin", "卯" to "Mao", "辰" to "Chen", "巳" to "Si", "午" to "Wu", "未" to "Wei", "申" to "Shen", "酉" to "You", "戌" to "Xu", "亥" to "Hai")
                val yStr = "${pinyinStems[yearStem] ?: yearStem}-${pinyinBranches[yearBranch] ?: yearBranch}"
                val mStr = "${pinyinStems[mStem] ?: mStem}-${pinyinBranches[mBranch] ?: mBranch}"
                val dStr = "${pinyinStems[dayStem] ?: dayStem}-${pinyinBranches[dayBranch] ?: dayBranch}"
                val hStr = "${pinyinStems[hStem] ?: hStem}-${pinyinBranches[hBranch] ?: hBranch}"
                "$yStr Year · $mStr Month · $dStr Day · $hStr Hour"
            }
            AppLanguage.ZH_HANT, AppLanguage.JA -> {
                "${yearStem}${yearBranch}年 ${mStem}${mBranch}月 ${dayStem}${dayBranch}日 ${hStem}${hBranch}時"
            }
            AppLanguage.KO -> {
                val koStems = mapOf("甲" to "갑", "乙" to "을", "丙" to "병", "丁" to "정", "戊" to "무", "己" to "기", "庚" to "경", "辛" to "신", "壬" to "임", "癸" to "계")
                val koBranches = mapOf("子" to "자", "丑" to "축", "寅" to "인", "卯" to "묘", "辰" to "진", "巳" to "사", "午" to "오", "未" to "미", "申" to "신", "酉" to "유", "戌" to "술", "亥" to "해")
                val yStr = "${koStems[yearStem] ?: yearStem}${koBranches[yearBranch] ?: yearBranch}년"
                val mStr = "${koStems[mStem] ?: mStem}${koBranches[mBranch] ?: mBranch}월"
                val dStr = "${koStems[dayStem] ?: dayStem}${koBranches[dayBranch] ?: dayBranch}일"
                val hStr = "${koStems[hStem] ?: hStem}${koBranches[hBranch] ?: hBranch}시"
                "$yStr $mStr $dStr $hStr"
            }
            AppLanguage.VI -> {
                val viStems = mapOf("甲" to "Giáp", "乙" to "Ất", "丙" to "Bính", "丁" to "Đinh", "戊" to "Mậu", "己" to "Kỷ", "庚" to "Canh", "辛" to "Tân", "壬" to "Nhâm", "癸" to "Quý")
                val viBranches = mapOf("子" to "Tý", "丑" to "Sửu", "寅" to "Dần", "卯" to "Mão", "辰" to "Thìn", "巳" to "Tỵ", "午" to "Ngọ", "未" to "Mùi", "申" to "Thân", "酉" to "Dậu", "戌" to "Tuất", "亥" to "Hợi")
                val yStr = "${viStems[yearStem] ?: yearStem} ${viBranches[yearBranch] ?: yearBranch} năm"
                val mStr = "${viStems[mStem] ?: mStem} ${viBranches[mBranch] ?: mBranch} tháng"
                val dStr = "${viStems[dayStem] ?: dayStem} ${viBranches[dayBranch] ?: dayBranch} ngày"
                val hStr = "${viStems[hStem] ?: hStem} ${viBranches[hBranch] ?: hBranch} giờ"
                "$yStr · $mStr · $dStr · $hStr"
            }
            AppLanguage.TH -> {
                val thStems = mapOf("甲" to "เจี่ย", "乙" to "อี้", "丙" to "ปิ่ง", "丁" to "ติง", "戊" to "อู่", "己" to "จี่", "庚" to "เกิง", "辛" to "ซิน", "壬" to "เหริน", "癸" to "กุ่ย")
                val thBranches = mapOf("子" to "จื่อ", "丑" to "โฉ่ว", "寅" to "หยิน", "卯" to "เหมา", "辰" to "เฉิน", "巳" to "ซื่อ", "午" to "อู่", "未" to "เว่ย", "申" to "เซิน", "酉" to "โหย่ว", "戌" to "ซวี", "亥" to "ฮ่าย")
                val yStr = "ปี ${thStems[yearStem] ?: yearStem}-${thBranches[yearBranch] ?: yearBranch}"
                val mStr = "เดือน ${thStems[mStem] ?: mStem}-${thBranches[mBranch] ?: mBranch}"
                val dStr = "วัน ${thStems[dayStem] ?: dayStem}-${thBranches[dayBranch] ?: dayBranch}"
                val hStr = "ยาม ${thStems[hStem] ?: hStem}-${thBranches[hBranch] ?: hBranch}"
                "$yStr · $mStr · $dStr · $hStr"
            }
            AppLanguage.ID -> {
                val pinyinStems = mapOf("甲" to "Jia", "乙" to "Yi", "丙" to "Bing", "丁" to "Ding", "戊" to "Wu", "己" to "Ji", "庚" to "Geng", "辛" to "Xin", "壬" to "Ren", "癸" to "Gui")
                val pinyinBranches = mapOf("子" to "Zi", "丑" to "Chou", "寅" to "Yin", "卯" to "Mao", "辰" to "Chen", "巳" to "Si", "午" to "Wu", "未" to "Wei", "申" to "Shen", "酉" to "You", "戌" to "Xu", "亥" to "Hai")
                val yStr = "Thn ${pinyinStems[yearStem] ?: yearStem}-${pinyinBranches[yearBranch] ?: yearBranch}"
                val mStr = "Bln ${pinyinStems[mStem] ?: mStem}-${pinyinBranches[mBranch] ?: mBranch}"
                val dStr = "Hr ${pinyinStems[dayStem] ?: dayStem}-${pinyinBranches[dayBranch] ?: dayBranch}"
                val hStr = "Jam ${pinyinStems[hStem] ?: hStem}-${pinyinBranches[hBranch] ?: hBranch}"
                "$yStr · $mStr · $dStr · $hStr"
            }
            else -> {
                "${yearStem}${yearBranch}年 ${mStem}${mBranch}月 ${dayStem}${dayBranch}日 ${hStem}${hBranch}时"
            }
        }

        // 5. 神煞冲克判定
        val warnings = mutableListOf<String>()
        var suiPo: String? = null
        var yuePo: String? = null
        var sittingClash: String? = null

        // 岁破冲煞：日支冲太岁年支
        if (clashMap[dayBranch] == yearBranch) {
            suiPo = when (lang) {
                AppLanguage.EN -> "Day branch clashes with Year Grand Duke ($yearBranch); Year Clash Taboo."
                AppLanguage.ZH_HANT -> "今日【${dayBranch}日】直衝年支太歲【${yearBranch}位】，犯【歲破大煞】，主百事不利。"
                AppLanguage.JA -> "本日【${dayBranch}日】が太歳【${yearBranch}位】と直衝し、【歳破大煞】となります。"
                AppLanguage.KO -> "오늘【${dayBranch}일】이 세차 태세【${yearBranch}위】와 직충하여 【세파대살】을 범합니다."
                AppLanguage.VI -> "Hôm nay ngày 【${dayBranch}】 trực xung Thái Tuế năm 【${yearBranch}】 phạm 【Tuế Phá Đại Sát】."
                AppLanguage.TH -> "วันนี้กิ่งดินวัน 【${dayBranch}】 ปะทะไท่ส่วยประจำปี 【${yearBranch}】 ติดขัดเคราะห์【ส่วยพั่ว】"
                AppLanguage.ID -> "Cabang hari bentrok dengan Tai Sui tahunan ($yearBranch); Tabu Benturan Tahun."
                else -> "今日【${dayBranch}日】直冲年支太岁【${yearBranch}位】，犯【岁破大煞】，主百事不利。"
            }
            warnings.add(suiPo)
        }

        // 月破冲煞：日支冲当令月支
        if (clashMap[dayBranch] == mBranch) {
            yuePo = when (lang) {
                AppLanguage.EN -> "Day branch clashes with Month Commander ($mBranch); Month Clash Taboo."
                AppLanguage.ZH_HANT -> "今日【${dayBranch}日】直衝月令月建【${mBranch}位】，犯【月破大耗】，凡事避忌。"
                AppLanguage.JA -> "本日【${dayBranch}日】が月建【${mBranch}位】と直衝し、【月破大耗】となります。"
                AppLanguage.KO -> "오늘【${dayBranch}일】이 월령 월건【${mBranch}위】과 직충하여 【월파대모】를 범합니다."
                AppLanguage.VI -> "Hôm nay ngày 【${dayBranch}】 trực xung Nguyệt Lệnh 【${mBranch}】 phạm 【Nguyệt Phá Đại Hao】."
                AppLanguage.TH -> "วันนี้กิ่งดินวัน 【${dayBranch}】 ปะทะประจำเดือน 【${mBranch}】 ติดขัดเคราะห์【เยว่พั่ว】"
                AppLanguage.ID -> "Cabang hari bentrok dengan Penguasa Bulan ($mBranch); Tabu Benturan Bulan."
                else -> "今日【${dayBranch}日】直冲月令月建【${mBranch}位】，犯【月破大耗】，凡事避忌。"
            }
            warnings.add(yuePo)
        }

        // 坐山冲犯
        val mountainBranch = mapOf(
            "壬" to "子", "子" to "子", "癸" to "子",
            "丑" to "丑", "艮" to "丑", "寅" to "寅",
            "甲" to "卯", "卯" to "卯", "乙" to "卯",
            "辰" to "辰", "巽" to "辰", "巳" to "巳",
            "丙" to "午", "午" to "午", "丁" to "午",
            "未" to "未", "坤" to "未", "申" to "申",
            "庚" to "酉", "酉" to "酉", "辛" to "酉",
            "戌" to "戌", "乾" to "戌", "亥" to "亥"
        )
        val sittingBranch = mountainBranch[sitting.name] ?: sitting.name
        val sClash = clashMap[sittingBranch]
        if (sClash == dayBranch) {
            sittingClash = when (lang) {
                AppLanguage.EN -> "Day branch clashes with House Sitting Mountain (${sitting.localizedName}); Sitting Clash Taboo."
                AppLanguage.ZH_HANT -> "今日日支【${dayBranch}】直衝本宅坐山【${sitting.localizedName}山】，犯【衝山大忌】，切勿動土安門！"
                AppLanguage.JA -> "本日の日支【${dayBranch}】が坐山【${sitting.localizedName}山】と直衝し、【衝山大忌】に該当します。"
                AppLanguage.KO -> "오늘 일진【${dayBranch}】이 좌산【${sitting.localizedName}산】과 직충하여 【충산대기】를 범하니 동토와 안문을 피하세요!"
                AppLanguage.VI -> "Hôm nay chi ngày 【${dayBranch}】 trực xung Tọa sơn 【${sitting.localizedName}】 phạm 【Xung Sơn Đại Kỵ】!"
                AppLanguage.TH -> "กิ่งดินวัน 【${dayBranch}】 ปะทะทิศพิงบ้าน 【${sitting.localizedName}】 ต้องห้ามการลงเสาเอกตั้งประตูเด็ดขาด!"
                AppLanguage.ID -> "Cabang hari bentrok dengan Gunung Sandaran (${sitting.localizedName}); Hindari renovasi dan pasang pintu!"
                else -> "今日日支【${dayBranch}】直冲本宅坐山【${sitting.name}山】，犯【冲山大忌】，切勿动土安门！"
            }
            warnings.add(sittingClash)
        }

        val isAuspicious = warnings.isEmpty()
        val status = when (lang) {
            AppLanguage.EN -> if (isAuspicious) "Auspicious Day" else "Clash Detected"
            AppLanguage.ZH_HANT -> if (isAuspicious) "今日日課吉" else "動土神煞有衝"
            AppLanguage.JA -> if (isAuspicious) "本日吉日" else "神煞の衝あり"
            AppLanguage.KO -> if (isAuspicious) "오늘의 일과 길" else "신살 충돌 감지"
            AppLanguage.VI -> if (isAuspicious) "Nhật khóa cát lợi" else "Thần sát tương xung"
            AppLanguage.TH -> if (isAuspicious) "ฤกษ์วันนี้เป็นมงคล" else "มีดาวเทพปะทะ"
            AppLanguage.ID -> if (isAuspicious) "Hari Ini Menguntungkan" else "Benturan Sha Terdeteksi"
            else -> if (isAuspicious) "今日日课吉" else "动土神煞有冲"
        }

        val details: String = if (isAuspicious) {
            when (lang) {
                AppLanguage.EN -> "Sitting Mountain Sha: Free from Year/Month clash. Harmonious Four Pillars, ideal for construction and door installation."
                AppLanguage.ZH_HANT -> "坐向神煞：無歲破、無月破、無坐向衝克。四柱比和合化，宜修造動土、安門立向。"
                AppLanguage.JA -> "坐向神煞：歳破・月破・坐向の衝克なし。四柱が調和し、改修や動土、門の設置に好適です。"
                AppLanguage.KO -> "좌향신살: 세파, 월파, 좌향 충극이 없습니다. 사주가 조화로워 동토, 안문, 수리에 이상적입니다."
                AppLanguage.VI -> "Thần sát tọa hướng: Không phạm Tuế Phá, Nguyệt Phá, Tọa Hướng tương xung. Tứ trụ hòa hợp, cát lợi cho động thổ an môn."
                AppLanguage.TH -> "เทพดาวทิศพิง: ไร้เคราะห์ส่วยพั่วและเยว่พั่ว สี่เสาประสานกลมกลืน เหมาะแก่การลงเสาเอกและตั้งประตู"
                AppLanguage.ID -> "Sha Gunung Sandaran: Bebas dari benturan tahun/bulan. Empat Pilar selaras, ideal untuk renovasi dan pasang pintu."
                else -> "坐向神煞：无岁破、无月破、无坐向冲克。四柱比和合化，宜修造动土、安门立向。"
            }
        } else {
            warnings.joinToString(" ")
        }

        val yi: List<String>
        val ji: List<String>
        when (lang) {
            AppLanguage.EN -> {
                yi = if (isAuspicious) listOf("Groundbreaking", "Door Installation", "Housewarming", "Business Opening") else listOf("Meditation", "Spiritual Cultivation")
                ji = if (isAuspicious) listOf("Excavation near graves", "Aggressive Acts") else listOf("Construction", "Door Installation", "Moving In")
            }
            AppLanguage.ZH_HANT -> {
                yi = if (isAuspicious) listOf("動土起造", "安門修方", "入宅安香", "開業祈福") else listOf("靜思祈禱", "祭祀修心")
                ji = if (isAuspicious) listOf("破土開生墳", "暴烈行事") else listOf("修造動土", "安門立向", "入宅開張")
            }
            AppLanguage.JA -> {
                yi = if (isAuspicious) listOf("地鎮祭・動土", "門の設置", "引越し入宅", "開店・祈福") else listOf("静思・瞑想", "祭祀・修養")
                ji = if (isAuspicious) listOf("墓地造成", "激しい争い") else listOf("修繕・動土", "門の設置", "入宅・開業")
            }
            AppLanguage.KO -> {
                yi = if (isAuspicious) listOf("동토 기공", "안문 수방", "입택 안향", "개업 기복") else listOf("정사 기도", "제사 수심")
                ji = if (isAuspicious) listOf("파토 생분", "과격한 행동") else listOf("수조 동토", "안문 입향", "입택 개업")
            }
            AppLanguage.VI -> {
                yi = if (isAuspicious) listOf("Động thổ khởi tạo", "An môn tu phương", "Nhập trạch an hương", "Khai trương cầu phúc") else listOf("Tĩnh tâm cầu nguyện", "Tế tự tu tâm")
                ji = if (isAuspicious) listOf("Phá thổ khai phần", "Hành sự bạo liệt") else listOf("Tu tạo động thổ", "An môn lập hướng", "Nhập trạch khai trương")
            }
            AppLanguage.TH -> {
                yi = if (isAuspicious) listOf("ลงเสาเอกก่อสร้าง", "ตั้งประตูมงคล", "ขึ้นบ้านใหม่", "เปิดกิจการ") else listOf("สงบจิตทำสมาธิ", "ไหว้พระขอพร")
                ji = if (isAuspicious) listOf("ขุดหลุมฝังศพ", "วิวาทรุนแรง") else listOf("ก่อสร้างซ่อมแซม", "ตั้งประตู", "ย้ายเข้าอยู่")
            }
            AppLanguage.ID -> {
                yi = if (isAuspicious) listOf("Peletakan Batu Pertama", "Pemasangan Pintu", "Pindah Rumah", "Pembukaan Usaha") else listOf("Meditasi Tenang", "Ibadah Doa")
                ji = if (isAuspicious) listOf("Gali Makam", "Tindakan Kasar") else listOf("Konstruksi Rumah", "Pasang Pintu", "Pindah Masuk")
            }
            else -> {
                yi = if (isAuspicious) listOf("动土起造", "安门修方", "入宅安香", "开业祈福") else listOf("静思祈祷", "祭祀修心")
                ji = if (isAuspicious) listOf("破土开生坟", "暴烈行事") else listOf("修造动土", "安门立向", "入宅开张")
            }
        }

        return ZeRiAnalysis(
            fourPillarsText = pillars,
            overallStatus = status,
            isAuspicious = isAuspicious,
            suiPoWarning = suiPo,
            yuePoWarning = yuePo,
            sanShaWarning = null,
            sittingClashWarning = sittingClash,
            detailsText = details,
            yiActivities = yi,
            jiActivities = ji
        )
    }
}
