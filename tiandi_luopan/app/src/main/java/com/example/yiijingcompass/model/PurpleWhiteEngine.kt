package com.example.yiijingcompass.model

import java.util.Calendar
import java.util.Date

// MARK: - 紫白九星流年流月客星动态气运与太岁三煞引擎 (PRD 第12章)

data class PurpleWhitePalaceItem(
    val palaceId: Int,        // 洛书宫位 1..9
    val palaceName: String,    // "正北 坎宫"
    val direction: String,     // "正北"
    val originalStar: Int,     // 原始洛书本宫星
    val yearGuestStar: Int,    // 流年客星 (1..9)
    val monthGuestStar: Int,   // 当月流月客星 (1..9)
    val starName: String,      // 简写 "一白"
    val isDanger25: Boolean,   // 是否犯二五交加 / 逢二黑五黄大煞
    val isTaiSui: Boolean,     // 是否为太岁方位
    val isSuiPo: Boolean,      // 是否为岁破方
    val isSanSha: Boolean,     // 是否为三煞方
    val advice: String         // 调理建议
)

data class PurpleWhiteChart(
    val year: Int,
    val month: Int,
    val yearCentralStar: Int,
    val monthCentralStar: Int,
    val currentFacingPalace: Int, // 当前罗盘朝向对应的洛书宫位
    val taiSuiDescription: String,
    val suiPoDescription: String,
    val sanShaDescription: String,
    val palaceItems: List<PurpleWhitePalaceItem>
)

class PurpleWhiteEngine private constructor() {
    companion object {
        val instance: PurpleWhiteEngine by lazy { PurpleWhiteEngine() }
    }

    // 洛书飞星轨迹: [中5, 乾6, 兑7, 艮8, 离9, 坎1, 坤2, 震3, 巽4]
    private val luoshuOrder = intArrayOf(5, 6, 7, 8, 9, 1, 2, 3, 4)

    // 九宫展示顺序 (巽4, 离9, 坤2; 震3, 中宫5, 兑7; 艮8, 坎1, 乾6)
    val displayPalaceOrder = listOf(4, 9, 2, 3, 5, 7, 8, 1, 6)

    fun starName(star: Int): String {
        if (star !in 1..9) return ""
        val lang = LocalizationManager.shared.effectiveLanguage
        return when (lang) {
            AppLanguage.EN -> {
                val names = arrayOf(
                    "", "1-White Greedy Wolf", "2-Black Illness Star", "3-Jade Storage Wood", "4-Green Wenqu Wood",
                    "5-Yellow Lianzhen Sha", "6-White Martial Metal", "7-Red Army Metal", "8-White Wealth Earth", "9-Purple Vital Fire"
                )
                names[star]
            }
            AppLanguage.ZH_HANT -> {
                val names = arrayOf(
                    "", "一白貪狼水星", "二黑巨門土星(病符)", "三碧祿存木星", "四綠文曲木星",
                    "五黃廉貞土星(煞曜)", "六白武曲金星", "七赤破軍金星", "八白左輔土星", "九紫右弼火星"
                )
                names[star]
            }
            AppLanguage.JA -> {
                val names = arrayOf(
                    "", "一白貪狼水星", "二黒巨門土星(病符)", "三碧禄存木星", "四緑文曲木星",
                    "五黄廉貞土星(煞曜)", "六白武曲金星", "七赤破軍金星", "八白左輔土星", "九紫右弼火星"
                )
                names[star]
            }
            AppLanguage.KO -> {
                val names = arrayOf(
                    "", "일백 탐랑 수성", "이흑 거문 토성(병부)", "삼벽 녹존 목성", "사록 문곡 목성",
                    "오황 염정 토성(살요)", "육백 무곡 금성", "칠적 파군 금성", "팔백 좌보 토성", "구자 우필 화성"
                )
                names[star]
            }
            AppLanguage.VI -> {
                val names = arrayOf(
                    "", "Nhất Bạch Tham Lang Thủy", "Nhị Hắc Cự Môn Thổ (Bệnh Phù)", "Tam Bích Lộc Tồn Mộc", "Tứ Lục Văn Khúc Mộc",
                    "Ngũ Hoàng Liêm Trinh Thổ (Sát)", "Lục Bạch Vũ Khúc Kim", "Thất Xích Phá Quân Kim", "Bát Bạch Tả Phù Thổ", "Cửu Tử Hữu Bật Hỏa"
                )
                names[star]
            }
            AppLanguage.TH -> {
                val names = arrayOf(
                    "", "ดาวหนึ่งขาวทานหลางน้ำ", "ดาวสองดำจวี้เหมินดิน (พยาธิ)", "ดาวสามหยกเขียวลู่ชุนไม้", "ดาวสี่เขียวเหวินชวีไม้",
                    "ดาวห้าเหลืองเหลียนเจินดิน (พิฆาต)", "ดาวหกขาวอู่ชวีทอง", "ดาวเจ็ดแดงผัวจวินทอง", "ดาวแปดขาวจั่วฝู่ดิน", "ดาวเก้าม่วงโย่วปี้ไฟ"
                )
                names[star]
            }
            AppLanguage.ID -> {
                val names = arrayOf(
                    "", "1-Putih Serigala Tamak", "2-Hitam Bintang Penyakit", "3-Giok Bintang Penyimpanan", "4-Hijau Bintang Akademik",
                    "5-Kuning Bintang Sha", "6-Putih Bintang Militer", "7-Merah Bintang Tentara", "8-Putih Bintang Rezeki", "9-Ungu Bintang Vitalitas"
                )
                names[star]
            }
            else -> {
                val names = arrayOf(
                    "", "一白贪狼水星", "二黑巨门土星(病符)", "三碧禄存木星", "四绿文曲木星",
                    "五黄廉贞土星(煞曜)", "六白武曲金星", "七赤破军金星", "八白左辅土星", "九紫右弼火星"
                )
                names[star]
            }
        }
    }

    fun palaceDirection(palaceId: Int): String {
        val lang = LocalizationManager.shared.effectiveLanguage
        return when (lang) {
            AppLanguage.EN -> {
                val dirs = mapOf(1 to "North", 2 to "Southwest", 3 to "East", 4 to "Southeast", 5 to "Center", 6 to "Northwest", 7 to "West", 8 to "Northeast", 9 to "South")
                dirs[palaceId] ?: "Center"
            }
            AppLanguage.ZH_HANT -> {
                val dirs = mapOf(1 to "正北", 2 to "西南", 3 to "正東", 4 to "東南", 5 to "中央", 6 to "西北", 7 to "正西", 8 to "東北", 9 to "正南")
                dirs[palaceId] ?: "中央"
            }
            AppLanguage.JA -> {
                val dirs = mapOf(1 to "正北", 2 to "南西", 3 to "正東", 4 to "南東", 5 to "中央", 6 to "北西", 7 to "正西", 8 to "北東", 9 to "正南")
                dirs[palaceId] ?: "中央"
            }
            AppLanguage.KO -> {
                val dirs = mapOf(1 to "정북", 2 to "남서", 3 to "정동", 4 to "동남", 5 to "중앙", 6 to "북서", 7 to "정서", 8 to "북동", 9 to "정남")
                dirs[palaceId] ?: "중앙"
            }
            AppLanguage.VI -> {
                val dirs = mapOf(1 to "Chính Bắc", 2 to "Tây Nam", 3 to "Chính Đông", 4 to "Đông Nam", 5 to "Trung Cung", 6 to "Tây Bắc", 7 to "Chính Tây", 8 to "Đông Bắc", 9 to "Chính Nam")
                dirs[palaceId] ?: "Trung Cung"
            }
            AppLanguage.TH -> {
                val dirs = mapOf(1 to "ทิศเหนือ", 2 to "ทิศตะวันตกเฉียงใต้", 3 to "ทิศตะวันออก", 4 to "ทิศตะวันออกเฉียงใต้", 5 to "ตรงกลาง", 6 to "ทิศตะวันตกเฉียงเหนือ", 7 to "ทิศตะวันตก", 8 to "ทิศตะวันออกเฉียงเหนือ", 9 to "ทิศใต้")
                dirs[palaceId] ?: "ตรงกลาง"
            }
            AppLanguage.ID -> {
                val dirs = mapOf(1 to "Utara", 2 to "Barat Daya", 3 to "Timur", 4 to "Tenggara", 5 to "Pusat", 6 to "Barat Laut", 7 to "Barat", 8 to "Timur Laut", 9 to "Selatan")
                dirs[palaceId] ?: "Pusat"
            }
            else -> {
                val dirs = mapOf(1 to "正北", 2 to "西南", 3 to "正东", 4 to "东南", 5 to "中央", 6 to "西北", 7 to "正西", 8 to "东北", 9 to "正南")
                dirs[palaceId] ?: "中央"
            }
        }
    }

    fun palaceFullName(palaceId: Int): String {
        val lang = LocalizationManager.shared.effectiveLanguage
        return when (lang) {
            AppLanguage.EN -> {
                val full = mapOf(1 to "North (Kan)", 2 to "Southwest (Kun)", 3 to "East (Zhen)", 4 to "Southeast (Xun)", 5 to "Center (Taiji)", 6 to "Northwest (Qian)", 7 to "West (Dui)", 8 to "Northeast (Gen)", 9 to "South (Li)")
                full[palaceId] ?: "Center (Taiji)"
            }
            AppLanguage.ZH_HANT -> {
                val full = mapOf(1 to "正北 坎宮", 2 to "西南 坤宮", 3 to "正東 震宮", 4 to "東南 巽宮", 5 to "中央 太極", 6 to "西北 乾宮", 7 to "正西 兌宮", 8 to "東北 艮宮", 9 to "正南 離宮")
                full[palaceId] ?: "中央 太極"
            }
            AppLanguage.JA -> {
                val full = mapOf(1 to "正北 坎宮", 2 to "南西 坤宮", 3 to "正東 震宮", 4 to "南東 巽宮", 5 to "中央 太極", 6 to "北西 乾宮", 7 to "正西 兌宮", 8 to "北東 艮宮", 9 to "正南 離宮")
                full[palaceId] ?: "中央 太極"
            }
            AppLanguage.KO -> {
                val full = mapOf(1 to "정북 감궁", 2 to "남서 곤궁", 3 to "정동 진궁", 4 to "동남 손궁", 5 to "중앙 태극", 6 to "북서 건궁", 7 to "정서 태궁", 8 to "북동 간궁", 9 to "정남 이궁")
                full[palaceId] ?: "중앙 태극"
            }
            AppLanguage.VI -> {
                val full = mapOf(1 to "Chính Bắc Khảm Cung", 2 to "Tây Nam Khôn Cung", 3 to "Chính Đông Chấn Cung", 4 to "Đông Nam Tốn Cung", 5 to "Trung Cung Thái Cực", 6 to "Tây Bắc Càn Cung", 7 to "Chính Tây Đoài Cung", 8 to "Đông Bắc Cấn Cung", 9 to "Chính Nam Ly Cung")
                full[palaceId] ?: "Trung Cung Thái Cực"
            }
            AppLanguage.TH -> {
                val full = mapOf(1 to "ทิศเหนือ วังข่าน", 2 to "ทิศตะวันตกเฉียงใต้ วังคุน", 3 to "ทิศตะวันออก วังเจิ้น", 4 to "ทิศตะวันออกเฉียงใต้ วังซวิ่น", 5 to "ตรงกลาง ไท่จี๋", 6 to "ทิศตะวันตกเฉียงเหนือ วังเฉียน", 7 to "ทิศตะวันตก วังตุ้ย", 8 to "ทิศตะวันออกเฉียงเหนือ วังเกิ้น", 9 to "ทิศใต้ วังหลี")
                full[palaceId] ?: "ตรงกลาง ไท่จี๋"
            }
            AppLanguage.ID -> {
                val full = mapOf(1 to "Utara (Kan)", 2 to "Barat Daya (Kun)", 3 to "Timur (Zhen)", 4 to "Tenggara (Xun)", 5 to "Pusat (Taiji)", 6 to "Barat Laut (Qian)", 7 to "Barat (Dui)", 8 to "Timur Laut (Gen)", 9 to "Selatan (Li)")
                full[palaceId] ?: "Pusat (Taiji)"
            }
            else -> {
                val full = mapOf(1 to "正北 坎宫", 2 to "西南 坤宫", 3 to "正东 震宫", 4 to "东南 巽宫", 5 to "中央 太极", 6 to "西北 乾宫", 7 to "正西 兑宫", 8 to "东北 艮宫", 9 to "正南 离宫")
                full[palaceId] ?: "中央 太极"
            }
        }
    }

    fun calcYearStar(year: Int): Int {
        var num = (11 - (year % 9)) % 9
        if (num <= 0) num += 9
        return num
    }

    fun calcMonthStar(year: Int, month: Int): Int {
        val branchIndex = ((year - 4) % 12 + 12) % 12
        val baseStar = when (branchIndex) {
            0, 3, 6, 9 -> 8 // 子午卯酉年
            1, 4, 7, 10 -> 5 // 辰戌丑未年
            else -> 2 // 寅申巳亥年
        }
        var mStar = (baseStar - (month - 1)) % 9
        if (mStar <= 0) mStar += 9
        return mStar
    }

    fun flyStars(centralStar: Int): Map<Int, Int> {
        val result = mutableMapOf<Int, Int>()
        for ((step, targetPalace) in luoshuOrder.withIndex()) {
            var s = (centralStar + step) % 9
            if (s <= 0) s += 9
            result[targetPalace] = s
        }
        return result
    }

    fun calculateChart(date: Date = Date(), heading: Double = 0.0): PurpleWhiteChart {
        val calendar = Calendar.getInstance()
        calendar.time = date
        val rawYear = calendar.get(Calendar.YEAR)
        val rawMonth = calendar.get(Calendar.MONTH) + 1
        val solarTermIndex = SolarTimeCalculator.instance.solarTermIndex(date)

        val isBeforeLichun = SolarTimeCalculator.instance.isBeforeLiChun(date)
        val effectiveYear = if (isBeforeLichun) (rawYear - 1) else rawYear

        val effectiveMonth: Int = if (rawMonth == 1) {
            1
        } else if (solarTermIndex < 2) {
            maxOf(1, rawMonth - 1)
        } else {
            minOf(12, 2 + (solarTermIndex - 2) / 2)
        }
        val solarMonthForStar = if (solarTermIndex < 2) 12 else minOf(11, 1 + (solarTermIndex - 2) / 2)

        val yCenter = calcYearStar(effectiveYear)
        val mCenter = calcMonthStar(effectiveYear, solarMonthForStar)

        val yearStarsMap = flyStars(yCenter)
        val monthStarsMap = flyStars(mCenter)

        val zhiIndex = ((effectiveYear - 4) % 12 + 12) % 12
        val lang = LocalizationManager.shared.effectiveLanguage

        val baseConfigs = mapOf(
            0 to Triple(1, 9, listOf(9)), 1 to Triple(8, 2, listOf(3)), 2 to Triple(8, 2, listOf(1)), 3 to Triple(3, 7, listOf(7)),
            4 to Triple(4, 6, listOf(9)), 5 to Triple(4, 6, listOf(3)), 6 to Triple(9, 1, listOf(1)), 7 to Triple(2, 8, listOf(7)),
            8 to Triple(2, 8, listOf(9)), 9 to Triple(7, 3, listOf(3)), 10 to Triple(6, 4, listOf(1)), 11 to Triple(6, 4, listOf(7))
        )
        val baseConf = baseConfigs[zhiIndex] ?: Triple(9, 1, listOf(1))
        val taiSuiPalace = baseConf.first
        val suiPoPalace = baseConf.second
        val sanShaPalaces = baseConf.third

        val taiSuiDesc: String
        val suiPoDesc: String
        val sanShaDesc: String

        when (lang) {
            AppLanguage.EN -> {
                val enConfig = mapOf(
                    0 to Triple("North (Zi)", "South (Wu)", "South (Si-Wu-Wei)"),
                    1 to Triple("Northeast (Chou)", "Southwest (Wei)", "East (Yin-Mao-Chen)"),
                    2 to Triple("Northeast (Yin)", "Southwest (Shen)", "North (Hai-Zi-Chou)"),
                    3 to Triple("East (Mao)", "West (You)", "West (Shen-You-Xu)"),
                    4 to Triple("Southeast (Chen)", "Northwest (Xu)", "South (Si-Wu-Wei)"),
                    5 to Triple("Southeast (Si)", "Northwest (Hai)", "East (Yin-Mao-Chen)"),
                    6 to Triple("South (Wu)", "North (Zi)", "North (Hai-Zi-Chou)"),
                    7 to Triple("Southwest (Wei)", "Northeast (Chou)", "West (Shen-You-Xu)"),
                    8 to Triple("Southwest (Shen)", "Northeast (Yin)", "South (Si-Wu-Wei)"),
                    9 to Triple("West (You)", "East (Mao)", "East (Yin-Mao-Chen)"),
                    10 to Triple("Northwest (Xu)", "Southeast (Chen)", "North (Hai-Zi-Chou)"),
                    11 to Triple("Northwest (Hai)", "Southeast (Si)", "West (Shen-You-Xu)")
                )
                val c = enConfig[zhiIndex] ?: Triple("South", "North", "North")
                taiSuiDesc = c.first; suiPoDesc = c.second; sanShaDesc = c.third
            }
            AppLanguage.ZH_HANT -> {
                val hantConfig = mapOf(
                    0 to Triple("正北 (子方)", "正南 (午方)", "正南 (巳午未方)"),
                    1 to Triple("東北 (丑方)", "西南 (未方)", "正東 (寅卯辰方)"),
                    2 to Triple("東北 (寅方)", "西南 (申方)", "正北 (亥子丑方)"),
                    3 to Triple("正東 (卯方)", "正西 (酉方)", "正西 (申酉戌方)"),
                    4 to Triple("東南 (辰方)", "西北 (戌方)", "正南 (巳午未方)"),
                    5 to Triple("東南 (巳方)", "西北 (亥方)", "正東 (寅卯辰方)"),
                    6 to Triple("正南 (午方)", "正北 (子方)", "正北 (亥子丑方)"),
                    7 to Triple("西南 (未方)", "東北 (丑方)", "正西 (申酉戌方)"),
                    8 to Triple("西南 (申方)", "東北 (寅方)", "正南 (巳午未方)"),
                    9 to Triple("正西 (酉方)", "正東 (卯方)", "正東 (寅卯辰方)"),
                    10 to Triple("西北 (戌方)", "東南 (辰方)", "正北 (亥子丑方)"),
                    11 to Triple("西北 (亥方)", "東南 (巳方)", "正西 (申酉戌方)")
                )
                val c = hantConfig[zhiIndex] ?: Triple("正南方", "正北方", "正北方")
                taiSuiDesc = c.first; suiPoDesc = c.second; sanShaDesc = c.third
            }
            AppLanguage.JA -> {
                val jaConfig = mapOf(
                    0 to Triple("正北 (子方)", "正南 (午方)", "正南 (巳午未方)"),
                    1 to Triple("北東 (丑方)", "南西 (未方)", "正東 (寅卯辰方)"),
                    2 to Triple("北東 (寅方)", "南西 (申方)", "正北 (亥子丑方)"),
                    3 to Triple("正東 (卯方)", "正西 (酉方)", "正西 (申酉戌方)"),
                    4 to Triple("南東 (辰方)", "北西 (戌方)", "正南 (巳午未方)"),
                    5 to Triple("南東 (巳方)", "北西 (亥方)", "正東 (寅卯辰方)"),
                    6 to Triple("正南 (午方)", "正北 (子方)", "正北 (亥子丑方)"),
                    7 to Triple("南西 (未方)", "北東 (丑方)", "正西 (申酉戌方)"),
                    8 to Triple("南西 (申方)", "北東 (寅方)", "正南 (巳午未方)"),
                    9 to Triple("正西 (酉方)", "正東 (卯方)", "正東 (寅卯辰方)"),
                    10 to Triple("北西 (戌方)", "南東 (辰方)", "正北 (亥子丑方)"),
                    11 to Triple("北西 (亥方)", "南東 (巳方)", "正西 (申酉戌方)")
                )
                val c = jaConfig[zhiIndex] ?: Triple("正南", "正北", "正北")
                taiSuiDesc = c.first; suiPoDesc = c.second; sanShaDesc = c.third
            }
            AppLanguage.KO -> {
                val koConfig = mapOf(
                    0 to Triple("정북 (자방)", "정남 (오방)", "정남 (사오미방)"),
                    1 to Triple("북동 (축방)", "남서 (미방)", "정동 (인묘진방)"),
                    2 to Triple("북동 (인방)", "남서 (신방)", "정북 (해자축방)"),
                    3 to Triple("정동 (묘방)", "정서 (유방)", "정서 (신유술방)"),
                    4 to Triple("동남 (진방)", "북서 (술방)", "정남 (사오미방)"),
                    5 to Triple("동남 (사방)", "북서 (해방)", "정동 (인묘진방)"),
                    6 to Triple("정남 (오방)", "정북 (자방)", "정북 (해자축방)"),
                    7 to Triple("남서 (미방)", "북동 (축방)", "정서 (신유술방)"),
                    8 to Triple("남서 (신방)", "북동 (인방)", "정남 (사오미방)"),
                    9 to Triple("정서 (유방)", "정동 (묘방)", "정동 (인묘진방)"),
                    10 to Triple("북서 (술방)", "동남 (진방)", "정북 (해자축방)"),
                    11 to Triple("북서 (해방)", "동남 (사방)", "정서 (신유술방)")
                )
                val c = koConfig[zhiIndex] ?: Triple("정남", "정북", "정북")
                taiSuiDesc = c.first; suiPoDesc = c.second; sanShaDesc = c.third
            }
            AppLanguage.VI -> {
                val viConfig = mapOf(
                    0 to Triple("Chính Bắc (Tử)", "Chính Nam (Ngọ)", "Chính Nam (Tị Ngọ Mùi)"),
                    1 to Triple("Đông Bắc (Sửu)", "Tây Nam (Mùi)", "Chính Đông (Dần Mão Thìn)"),
                    2 to Triple("Đông Bắc (Dần)", "Tây Nam (Thân)", "Chính Bắc (Hợi Tý Sửu)"),
                    3 to Triple("Chính Đông (Mão)", "Chính Tây (Dậu)", "Chính Tây (Thân Dậu Tuất)"),
                    4 to Triple("Đông Nam (Thìn)", "Tây Bắc (Tuất)", "Chính Nam (Tị Ngọ Mùi)"),
                    5 to Triple("Đông Nam (Tị)", "Tây Bắc (Hợi)", "Chính Đông (Dần Mão Thìn)"),
                    6 to Triple("Chính Nam (Ngọ)", "Chính Bắc (Tử)", "Chính Bắc (Hợi Tý Sửu)"),
                    7 to Triple("Tây Nam (Mùi)", "Đông Bắc (Sửu)", "Chính Tây (Thân Dậu Tuất)"),
                    8 to Triple("Tây Nam (Thân)", "Đông Bắc (Dần)", "Chính Nam (Tị Ngọ Mùi)"),
                    9 to Triple("Chính Tây (Dậu)", "Chính Đông (Mão)", "Chính Đông (Dần Mão Thìn)"),
                    10 to Triple("Tây Bắc (Tuất)", "Đông Nam (Thìn)", "Chính Bắc (Hợi Tý Sửu)"),
                    11 to Triple("Tây Bắc (Hợi)", "Đông Nam (Tị)", "Chính Tây (Thân Dậu Tuất)")
                )
                val c = viConfig[zhiIndex] ?: Triple("Chính Nam", "Chính Bắc", "Chính Bắc")
                taiSuiDesc = c.first; suiPoDesc = c.second; sanShaDesc = c.third
            }
            AppLanguage.TH -> {
                val thConfig = mapOf(
                    0 to Triple("ทิศเหนือ (จื่อ)", "ทิศใต้ (อู่)", "ทิศใต้ (ซื่อ-อู่-เว่ย)"),
                    1 to Triple("ทิศตะวันออกเฉียงเหนือ (โฉ่ว)", "ทิศตะวันตกเฉียงใต้ (เว่ย)", "ทิศตะวันออก (หยิน-เหมา-เฉิน)"),
                    2 to Triple("ทิศตะวันออกเฉียงเหนือ (หยิน)", "ทิศตะวันตกเฉียงใต้ (เซิน)", "ทิศเหนือ (ฮ่าย-จื่อ-โฉ่ว)"),
                    3 to Triple("ทิศตะวันออก (เหมา)", "ทิศตะวันตก (โหย่ว)", "ทิศตะวันตก (เซิน-โหย่ว-ซวี)"),
                    4 to Triple("ทิศตะวันออกเฉียงใต้ (เฉิน)", "ทิศตะวันตกเฉียงเหนือ (ซวี)", "ทิศใต้ (ซื่อ-อู่-เว่ย)"),
                    5 to Triple("ทิศตะวันออกเฉียงใต้ (ซื่อ)", "ทิศตะวันตกเฉียงเหนือ (ฮ่าย)", "ทิศตะวันออก (หยิน-เหมา-เฉิน)"),
                    6 to Triple("ทิศใต้ (อู่)", "ทิศเหนือ (จื่อ)", "ทิศเหนือ (ฮ่าย-จื่อ-โฉ่ว)"),
                    7 to Triple("ทิศตะวันตกเฉียงใต้ (เว่ย)", "ทิศตะวันออกเฉียงเหนือ (โฉ่ว)", "ทิศตะวันตก (เซิน-โหย่ว-ซวี)"),
                    8 to Triple("ทิศตะวันตกเฉียงใต้ (เซิน)", "ทิศตะวันออกเฉียงเหนือ (หยิน)", "ทิศใต้ (ซื่อ-อู่-เว่ย)"),
                    9 to Triple("ทิศตะวันตก (โหย่ว)", "ทิศตะวันออก (เหมา)", "ทิศตะวันออก (หยิน-เหมา-เฉิน)"),
                    10 to Triple("ทิศตะวันตกเฉียงเหนือ (ซวี)", "ทิศตะวันออกเฉียงใต้ (เฉิน)", "ทิศเหนือ (ฮ่าย-จื่อ-โฉ่ว)"),
                    11 to Triple("ทิศตะวันตกเฉียงเหนือ (ฮ่าย)", "ทิศตะวันออกเฉียงใต้ (ซื่อ)", "ทิศตะวันตก (เซิน-โหย่ว-ซวี)")
                )
                val c = thConfig[zhiIndex] ?: Triple("ทิศใต้", "ทิศเหนือ", "ทิศเหนือ")
                taiSuiDesc = c.first; suiPoDesc = c.second; sanShaDesc = c.third
            }
            AppLanguage.ID -> {
                val idConfig = mapOf(
                    0 to Triple("Utara (Zi)", "Selatan (Wu)", "Selatan (Si-Wu-Wei)"),
                    1 to Triple("Timur Laut (Chou)", "Barat Daya (Wei)", "Timur (Yin-Mao-Chen)"),
                    2 to Triple("Timur Laut (Yin)", "Barat Daya (Shen)", "Utara (Hai-Zi-Chou)"),
                    3 to Triple("Timur (Mao)", "Barat (You)", "Barat (Shen-You-Xu)"),
                    4 to Triple("Tenggara (Chen)", "Barat Laut (Xu)", "Selatan (Si-Wu-Wei)"),
                    5 to Triple("Tenggara (Si)", "Barat Laut (Hai)", "Timur (Yin-Mao-Chen)"),
                    6 to Triple("Selatan (Wu)", "Utara (Zi)", "Utara (Hai-Zi-Chou)"),
                    7 to Triple("Barat Daya (Wei)", "Timur Laut (Chou)", "Barat (Shen-You-Xu)"),
                    8 to Triple("Barat Daya (Shen)", "Timur Laut (Yin)", "Selatan (Si-Wu-Wei)"),
                    9 to Triple("Barat (You)", "Timur (Mao)", "Timur (Yin-Mao-Chen)"),
                    10 to Triple("Barat Laut (Xu)", "Tenggara (Chen)", "Utara (Hai-Zi-Chou)"),
                    11 to Triple("Barat Laut (Hai)", "Tenggara (Si)", "Barat (Shen-You-Xu)")
                )
                val c = idConfig[zhiIndex] ?: Triple("Selatan", "Utara", "Utara")
                taiSuiDesc = c.first; suiPoDesc = c.second; sanShaDesc = c.third
            }
            else -> {
                val hansConfig = mapOf(
                    0 to Triple("正北 (子方)", "正南 (午方)", "正南 (巳午未方)"),
                    1 to Triple("东北 (丑方)", "西南 (未方)", "正东 (寅卯辰方)"),
                    2 to Triple("东北 (寅方)", "西南 (申方)", "正北 (亥子丑方)"),
                    3 to Triple("正东 (卯方)", "正西 (酉方)", "正西 (申酉戌方)"),
                    4 to Triple("东南 (辰方)", "西北 (戌方)", "正南 (巳午未方)"),
                    5 to Triple("东南 (巳方)", "西北 (亥方)", "正东 (寅卯辰方)"),
                    6 to Triple("正南 (午方)", "正北 (子方)", "正北 (亥子丑方)"),
                    7 to Triple("西南 (未方)", "东北 (丑方)", "正西 (申酉戌方)"),
                    8 to Triple("西南 (申方)", "东北 (寅方)", "正南 (巳午未方)"),
                    9 to Triple("正西 (酉方)", "正东 (卯方)", "正东 (寅卯辰方)"),
                    10 to Triple("西北 (戌方)", "东南 (辰方)", "正北 (亥子丑方)"),
                    11 to Triple("西北 (亥方)", "东南 (巳方)", "正西 (申酉戌方)")
                )
                val c = hansConfig[zhiIndex] ?: Triple("正南方", "正北方", "正北方")
                taiSuiDesc = c.first; suiPoDesc = c.second; sanShaDesc = c.third
            }
        }

        val palaceItems = mutableListOf<PurpleWhitePalaceItem>()
        for (pId in displayPalaceOrder) {
            val yStar = yearStarsMap[pId] ?: 1
            val mStar = monthStarsMap[pId] ?: 1
            val isTaiSui = (pId == taiSuiPalace)
            val isSuiPo = (pId == suiPoPalace)
            val isSanSha = sanShaPalaces.contains(pId)

            val isDanger25 = (yStar == 5 && mStar == 2) || (yStar == 2 && mStar == 5)
            val hasFiveYellow = yStar == 5 || mStar == 5
            val hasIllnessStar = yStar == 2 || mStar == 2

            var advice = when (lang) {
                AppLanguage.EN -> {
                    if (isDanger25) {
                        "[2-5 Double Taboo] Illness Star meets Five Yellow. What to do: Hang a brass gourd or 6-Emperor coins here; no drilling, no red. → Effect: Mainly elders' (esp. male) health - digestion, heart/brain - plus disputes and financial loss; covers this palace area."
                    } else if (hasFiveYellow) {
                        "[Five Yellow] Avoid drilling or hammering walls. What to do: Place a pacifying water vessel or brass item to settle Earth qi. → Effect: Family health (digestion, recurring ailments; elders and the unwell more sensitive) and financial-loss risk in this direction."
                    } else if (hasIllnessStar) {
                        "[Illness Star] What to do: Place a brass item to drain the energy; keep this area ventilated and dry. → Effect: Family health (stomach, gynecological, recurring ailments; women and the frail more affected); covers this palace."
                    } else if (yStar == 9) {
                        "[9-Purple Vitality] What to do: Place red/green plants or warm-colored decor. → Effect: Favors romance, weddings, celebrations, and new family members; covers this palace."
                    } else if (yStar == 8) {
                        "[8-White Wealth Star] What to do: Keep tidy; place an energy-gathering object or money box. → Effect: Favors family income, property, and savings (most tied to the breadwinner); covers this palace."
                    } else if (yStar == 1 || yStar == 4 || yStar == 6) {
                        "[Literary Benefactor Star] What to do: Place a study desk and lamp, Wenchang pagoda or green plant. → Effect: Favors academic growth, examinations and career rise (good for students and seekers); covers this palace."
                    } else {
                        "Balanced energy field. What to do: Keep tidy, ventilated as usual. → Effect: Family fortune is stable; no special remedy needed."
                    }
                }
                AppLanguage.ZH_HANT -> {
                    if (isDanger25) {
                        "【二五交加】病符疊五黃。做法：此方懸掛純銅葫蘆或六帝錢化解，嚴禁動土、見大紅。→ 影響：主長輩（尤以男性）脾胃、心腦血管健康損耗，兼防口舌官非與破財；覆蓋該宮位區域。"
                    } else if (hasFiveYellow) {
                        "【五黃煞】忌動土、鑽孔打釘。做法：宜安放安忍水或銅製擺件沉降土氣。→ 影響：主家人整體健康（脾胃、舊疾復發，以長輩與體弱者最顯）及該方位破耗風險。"
                    } else if (hasIllnessStar) {
                        "【病符星】做法：宜擺設銅器化泄，該處保持通風、乾燥。→ 影響：主家人健康隱患（脾胃、婦科、舊疾反覆，以女性及體弱者為主）；覆蓋該宮位。"
                    } else if (yStar == 9) {
                        "【九紫喜慶】做法：宜佈置紅綠植栽或暖色調飾物催動。→ 影響：主家中女性良緣、婚嫁、添丁、添人口與喜慶之事；覆蓋該宮位。"
                    } else if (yStar == 8) {
                        "【八白財星】做法：宜保持整潔，放聚氣擺設或存錢罐。→ 影響：主家中正財、田宅與儲蓄積累（與家庭主事者收入最相關）；覆蓋該宮位。"
                    } else if (yStar == 1 || yStar == 4 || yStar == 6) {
                        "【文昌吉星】做法：宜設書桌、檯燈，配文昌塔或綠植。→ 影響：主子女學業、考試、升遷與功名運勢（學生與進職者受惠）；覆蓋該宮位。"
                    } else {
                        "氣場平穩。做法：如常保持明亮、通風即可。→ 影響：主家人運勢平順，無須刻意化煞。"
                    }
                }
                AppLanguage.JA -> {
                    if (isDanger25) {
                        "【二五交加】病符と五黄が重なる。やり方：銅製ひょうたんか六帝銭を吊るし、土木工事や赤色を避ける。→ 効果：主に高齢者（特に男性）の健康（胃腸・循環器）と争い・散財に作用。この宮の区域に効果。"
                    } else if (hasFiveYellow) {
                        "【五黄】動土や壁の穴あけを避ける。やり方：安忍水か銅製品で土気を鎮める。→ 効果：家族の健康（胃腸、持病。年配者や病弱な人ほど敏感）と散財リスクに作用。この方位に効果。"
                    } else if (hasIllnessStar) {
                        "【病符】やり方：銅製品を置いて気を泄し、この場所は風通しよく乾燥させる。→ 効果：家族の健康（胃腸・婦人科・持病の再発。女性や体の弱い人に現れやすい）。この宮に効果。"
                    } else if (yStar == 9) {
                        "【九紫喜慶】やり方：赤や緑の植物、暖色の飾りを置く。→ 効果：家の女性の良縁・結婚、慶事と新たな家族の増加に吉。この宮に効果。"
                    } else if (yStar == 8) {
                        "【八白財星】やり方：整理整頓し、気を集める置物か財布箱を置く。→ 効果：家の正財・不動産・蓄財に有利（一家の働き手の収入と最も関係）。この宮に効果。"
                    } else if (yStar == 1 || yStar == 4 || yStar == 6) {
                        "【文昌吉星】やり方：机とスタンドライトを置き、文昌塔か観葉植物を飾る。→ 効果：子供の学業・受験・出世に有利（学生や仕事を目指す人に良い）。この宮に効果。"
                    } else {
                        "気場は穏やか。やり方：いつも通り清潔で風通しよく保つ。→ 効果：家族の運勢は安定。特別な調理は不要。"
                    }
                }
                AppLanguage.KO -> {
                    if (isDanger25) {
                        "【이오교가】병부성과 오황이 겹침. 방법: 이 방위에 구리 호리병이나 육제전을 겁니다. 토목·빨간색 금지. → 효과: 주로 집안 어르신(특히 남성) 건강(위장·심혈관)과 구설·관재·파재에 작용. 이 궁 영역에 효과."
                    } else if (hasFiveYellow) {
                        "【오황】토목 공사나 벽 뚫기를 피합니다. 방법: 안인수나 구리 제품으로 토기를 안정시킵니다. → 효과: 가족 건강(위장, 지병. 어르신과 병약한 사람이 더 민감)과 파재 위험에 작용. 이 방위에 효과."
                    } else if (hasIllnessStar) {
                        "【병부】방법: 구리 제품을 두어 기운을 빼고, 이곳은 통풍·건조하게 유지합니다. → 효과: 가족 건강(위장·부인과·지병 반복. 여성과 몸이 약한 사람에게 잘 나타남). 이 궁에 효과."
                    } else if (yStar == 9) {
                        "【구자 희경】방법: 빨강/초록 식물이나 따뜻한 색 장식을 둡니다. → 효과: 집안 여성의 인연·혼인, 경사와 새 식구 증가에 길. 이 궁에 효과."
                    } else if (yStar == 8) {
                        "【팔백 재성】방법: 정리 정돈하고 기를 모으는 장식품이나 돈통을 둡니다. → 효과: 집안의 정재·부동산·저축에 유리(생계를 책임지는 사람의 수입과 가장 관련). 이 궁에 효과."
                    } else if (yStar == 1 || yStar == 4 || yStar == 6) {
                        "【문창 길성】방법: 책상과 스탠드를 두고 문창탑이나 화분을 둡니다. → 효과: 자녀의 학업·시험운·출세에 유리(학생과 입시 준비생에게 좋음). 이 궁에 효과."
                    } else {
                        "기운이 안정됨. 방법: 평소처럼 청결하고 통풍 잘 유지. → 효과: 가족 운세 안정. 특별한 조치 불필요."
                    }
                }
                AppLanguage.VI -> {
                    if (isDanger25) {
                        "【Nhị Ngũ Giao Gia】Bệnh Phù gặp Ngũ Hoàng. Cách làm: Treo hồ lô đồng hoặc tiền lục đế ở hướng này; tránh động thổ và màu đỏ. → Ảnh hưởng: Chủ yếu sức khỏe người lớn tuổi (nhất là nam giới) - tiêu hóa, tim mạch - cùng thị phi, quan phi và hao tài; phủ khu vực cung này."
                    } else if (hasFiveYellow) {
                        "【Ngũ Hoàng】Tránh động thổ khoan tường. Cách làm: Đặt an nhẫn thủy hoặc vật bằng đồng để trấn thổ khí. → Ảnh hưởng: Sức khỏe gia đình (tiêu hóa, bệnh cũ; người lớn tuổi và người bệnh nhạy cảm hơn) và rủi ro hao tài ở hướng này."
                    } else if (hasIllnessStar) {
                        "【Bệnh Phù】Cách làm: Đặt vật bằng đồng để tiết khí; giữ nơi này thông thoáng khô ráo. → Ảnh hưởng: Sức khỏe gia đình (dạ dày, phụ khoa, bệnh cũ tái phát; phụ nữ và người yếu rõ hơn); phủ cung này."
                    } else if (yStar == 9) {
                        "【Cửu Tử Hỷ Khánh】Cách làm: Bày cây đỏ/xanh hoặc vật trang trí tông ấm. → Ảnh hưởng: Trợ duyên, hôn nhân cho nữ trong nhà, tin vui và thêm nhân khẩu; phủ cung này."
                    } else if (yStar == 8) {
                        "【Bát Bạch Tài Tinh】Cách làm: Giữ gọn gàng, đặt vật tụ khí hoặc hộp tiền. → Ảnh hưởng: Trợ chính tài, điền sản và tích lũy của gia đình (liên quan nhất đến thu nhập người trụ cột); phủ cung này."
                    } else if (yStar == 1 || yStar == 4 || yStar == 6) {
                        "【Văn Xương Cát Tinh】Cách làm: Đặt bàn học, đèn bàn, tháp Văn Xương hoặc cây xanh. → Ảnh hưởng: Trợ học hành, thi cử và công danh của con cái (học sinh và người cầu danh được lợi); phủ cung này."
                    } else {
                        "Khí trường bình hòa. Cách làm: Giữ sạch sẽ thông thoáng như thường. → Ảnh hưởng: Vận của gia đình bình ổn; không cần điều chỉnh đặc biệt."
                    }
                }
                AppLanguage.TH -> {
                    if (isDanger25) {
                        "【สองห้าประจัน】ดาวพยาธิปะทะดาวห้าเหลือง วิธีทำ: แขวนน้ำเต้าทองเหลืองหรือเหรียญหกจักรพรรดิที่ทิศนี้ ห้ามขุดเจาะและห้ามสีแดง → ผล: หลักคือสุขภาพผู้ใหญ่ในบ้าน (โดยเฉพาะชาย) กระเพาะ หัวใจและสมอง กับปากเสียง เรื่องหน่วยงานและเสียทรัพย์ ครอบคลุมพื้นที่นั้น"
                    } else if (hasFiveYellow) {
                        "【ดาวห้าเหลือง】ห้ามขุดเจาะผนัง วิธีทำ: ตั้งอ่างน้ำสงบหรือของทองเหลืองระงับพลังดิน → ผล: สุขภาพคนในบ้าน (กระเพาะ โรคประจำตัว ผู้ใหญ่และคนป่วยอ่อนไหวกว่า) และเสี่ยงเสียทรัพย์ที่ทิศนี้"
                    } else if (hasIllnessStar) {
                        "【ดาวพยาธิ】วิธีทำ: วางของทองเหลืองระบายพลัง ดูแลที่แห่งนี้โปร่งและแห้ง → ผล: สุขภาพคนในบ้าน (กระเพาะ สตรี โรคประจำตัวกำเริบ ผู้หญิงและคนอ่อนแอเห็นชัดกว่า) ครอบคลุมพื้นที่นั้น"
                    } else if (yStar == 9) {
                        "【ดาวเก้าม่วงมงคล】วิธีทำ: วางต้นไม้เขียวหรือของแต่งโทนอุ่น → ผล: เสริมความรัก การแต่งงานของหญิงในบ้าน ข่าวดีและสมาชิกใหม่ ครอบคลุมพื้นที่นั้น"
                    } else if (yStar == 8) {
                        "【ดาวแปดขาวทรัพย์】วิธีทำ: เก็บให้เป็นระเบียบ วางของรวมพลังหรือกล่องเงิน → ผล: ส่งเสริมรายได้หลัก ที่ดินและการออมของบ้าน (เกี่ยวข้องกับรายได้คนหาเงินหลักมากที่สุด) ครอบคลุมพื้นที่นั้น"
                    } else if (yStar == 1 || yStar == 4 || yStar == 6) {
                        "【ดาวเหวินชวีมงคล】วิธีทำ: ตั้งโต๊ะทำงาน โคมไฟ เจดีย์เหวินชวีหรือต้นไม้เขียว → ผล: เสริมการเรียน สอบและเลื่อนขั้นของบุตรหลาน ครอบคลุมพื้นที่นั้น"
                    } else {
                        "พลังสมดุลราบรื่น วิธีทำ: ดูแลให้สว่างและถ่ายเทตามปกติ → ผล: ดวงชะตาคนในบ้านราบรื่น ไม่ต้องแก้เคล็ดใดๆ"
                    }
                }
                AppLanguage.ID -> {
                    if (isDanger25) {
                        "[Tabu Ganda 2-5] Bintang Penyakit bertemu Lima Kuning. Cara mengatasi: Gantung labu kuningan atau 6 koin kaisar di sini; jangan mengebor dinding, hindari warna merah. → Pengaruh: Terutama kesehatan orang tua (khususnya pria) - pencernaan, jantung/otak - ditambah perselisihan dan kerugian finansial."
                    } else if (hasFiveYellow) {
                        "[Lima Kuning] Hindari mengebor atau memaku dinding. Cara mengatasi: Letakkan wadah air penenang atau benda kuningan untuk meredakan energi Tanah. → Pengaruh: Kesehatan keluarga (pencernaan, penyakit berulang) dan risiko pengeluaran tak terduga."
                    } else if (hasIllnessStar) {
                        "[Bintang Penyakit] Cara mengatasi: Letakkan benda kuningan untuk membuang energi; jaga area berventilasi dan kering. → Pengaruh: Kesehatan keluarga (perut, ginekologi, penyakit kambuhan); mencakup istana ini."
                    } else if (yStar == 9) {
                        "[Vitalitas 9-Ungu] Cara mengatasi: Letakkan tanaman merah/hijau atau dekorasi bernuansa hangat. → Pengaruh: Mendukung asmara, pernikahan, perayaan dan penambahan anggota keluarga; mencakup istana ini."
                    } else if (yStar == 8) {
                        "[Bintang Rezeki 8-Putih] Cara mengatasi: Jaga kerapian; letakkan wadah penyimpan uang. → Pengaruh: Mendukung rezeki utama keluarga, kepemilikan tanah dan tabungan; mencakup istana ini."
                    } else if (yStar == 1 || yStar == 4 || yStar == 6) {
                        "[Bintang Akademik] Cara mengatasi: Letakkan meja belajar, lampu meja atau tanaman hijau. → Pengaruh: Mendukung prestasi belajar, ujian dan kemajuan karier anak-anak; mencakup istana ini."
                    } else {
                        "Medan energi seimbang. Cara mengatasi: Jaga tetap rapi dan berventilasi seperti biasa. → Pengaruh: Keberuntungan keluarga stabil; tidak memerlukan tindakan khusus."
                    }
                }
                else -> {
                    if (isDanger25) {
                        "【二五交加】病符叠五黄。做法：此方悬挂纯铜葫芦或六帝钱化解，严禁动土、见大红。→ 影响：主长辈（尤以男性）脾胃、心脑血管健康损耗，兼防口舌官非与破财；覆盖该宫位区域。"
                    } else if (hasFiveYellow) {
                        "【五黄煞】忌动土、钻孔打钉。做法：宜安放安忍水或铜制摆件沉降土气。→ 影响：主家人整体健康（脾胃、旧疾复发，以长辈与体弱者最显）及该方位破耗风险。"
                    } else if (hasIllnessStar) {
                        "【病符星】做法：宜摆设铜器化泄，该处保持通风、干燥。→ 影响：主家人健康隐患（脾胃、妇科、旧疾反复，以女性及体弱者为主）；覆盖该宫位。"
                    } else if (yStar == 9) {
                        "【九紫喜庆】做法：宜布置红绿植栽或暖色调饰物催动。→ 影响：主家中女性良缘、婚嫁、添丁、添人口与喜庆之事；覆盖该宫位。"
                    } else if (yStar == 8) {
                        "【八白财星】做法：宜保持整洁，放聚气摆设或存钱罐。→ 影响：主家中正财、田宅与储蓄积累（与家庭主事者收入最相关）；覆盖该宫位。"
                    } else if (yStar == 1 || yStar == 4 || yStar == 6) {
                        "【文昌吉星】做法：宜设书桌、台灯，配文昌塔或绿植。→ 影响：主子女学业、考试、升迁与功名运势（学生与进职者受惠）；覆盖该宫位。"
                    } else {
                        "气场平稳。做法：如常保持明亮、通风即可。→ 影响：主家人运势平顺，无须刻意化煞。"
                    }
                }
            }

            if (isDanger25 || hasFiveYellow || hasIllnessStar || yStar == 8 || yStar == 9) {
                advice += when (lang) {
                    AppLanguage.EN -> " Source: traditional Zi-Bai Nine-Star formula describes ‘8-White as wealth star and 9-Purple as celebration’; Zi Bai Jue notes ‘when Five Yellow overlaps, calamities and illnesses visit together.’ Interpretation: the wealth, savings, loss and celebration wording is classical symbolism, not a medical or financial prediction."
                    AppLanguage.ZH_HANT -> " 出處：傳統紫白九星訣（傳本有異文）稱「八白財星、九紫喜慶」；《紫白訣》又云「五黃重疊，災疾並臨」。解釋：正財、田宅、儲蓄、破財與喜慶是古法象徵，不是醫療診斷或財務預測。"
                    AppLanguage.JA -> " 出典：伝統紫白九星訣（伝本に異文）は「八白財星・九紫喜慶」とし、『紫白訣』は「五黄重なれば災疾並び臨む」と伝えます。解釈：正財・不動産・蓄財・散財と慶事は古法の象徴であり、医学的・金融的予測ではありません。"
                    AppLanguage.KO -> " 출처: 전통 자백구성결(전본 이문)은 ‘팔백 재성·구자 희경’이라 하고 《자백결》은 ‘오황이 겹치면 재질이 임한다’고 전합니다. 설명: 정재·부동산·저축·손재와 경사는 고법의 상징이며 의학적·재무 예측이 아닙니다."
                    AppLanguage.VI -> " Nguồn: Quyết Tử Bạch truyền thống (bản truyền có dị văn) gọi đây là ‘Bát Bạch Tài Tinh, Cửu Tử Hỷ Khánh’; 《Tử Bạch Quyết》 ghi ‘Ngũ Hoàng chồng lên thì tai bệnh đến’. Giải thích: tài sản, thu nhập, hao tài và hỷ sự là biểu tượng cổ pháp, không phải dự đoán y khoa hay tài chính."
                    AppLanguage.TH -> " แหล่งที่มา: ตำราจื่อไป๋เก้าดาวแบบดั้งเดิม (ตำราต่างกัน) เรียก ‘ดาวแปดขาวทรัพย์·ดาวเก้าม่วงมงคล’; 《จื่อไป๋เจวี๋ย》กล่าวว่า ‘ดาวห้าเหลืองซ้อน ภัยและโรคมาเยือน’ คำอธิบาย: ทรัพย์ รายได้ การเสียทรัพย์ และความยินดีเป็นสัญลักษณ์โบราณ ไม่ใช่การพยากรณ์ทางการแพทย์หรือการเงิน"
                    AppLanguage.ID -> " Sumber: rumus sembilan bintang Zi Bai tradisional (versi berbeda) menyebut ‘Bintang Rezeki 8-Putih dan Keberuntungan 9-Ungu’; 《Zi Bai Jue》 menyebut ‘Saat Lima Kuning bertumpuk, penyakit dan bencana datang.’ Penjelasan: harta, pendapatan, kerugian dan sukacita adalah simbol klasik, bukan prediksi medis atau keuangan."
                    else -> " 出处：传统紫白九星诀（传本有异文）称“八白财星、九紫喜庆”；《紫白诀》又云“五黄重叠，灾疾并临”。解释：正财、田宅、储蓄、破财与喜庆是古法象征，不是医疗诊断或财务预测。"
                }
            }

            palaceItems.add(
                PurpleWhitePalaceItem(
                    palaceId = pId,
                    palaceName = palaceFullName(pId),
                    direction = palaceDirection(pId),
                    originalStar = pId,
                    yearGuestStar = yStar,
                    monthGuestStar = mStar,
                    starName = starName(yStar),
                    isDanger25 = isDanger25,
                    isTaiSui = isTaiSui,
                    isSuiPo = isSuiPo,
                    isSanSha = isSanSha,
                    advice = advice
                )
            )
        }

        return PurpleWhiteChart(
            year = effectiveYear,
            month = effectiveMonth,
            yearCentralStar = yCenter,
            monthCentralStar = mCenter,
            currentFacingPalace = palaceID(heading),
            taiSuiDescription = taiSuiDesc,
            suiPoDescription = suiPoDesc,
            sanShaDescription = sanShaDesc,
            palaceItems = palaceItems
        )
    }

    private fun palaceID(heading: Double): Int {
        val normalized = (heading % 360.0 + 360.0) % 360.0
        return when {
            normalized in 337.5..360.0 || normalized in 0.0..22.5 -> 1
            normalized in 22.5..67.5 -> 8
            normalized in 67.5..112.5 -> 3
            normalized in 112.5..157.5 -> 4
            normalized in 157.5..202.5 -> 9
            normalized in 202.5..247.5 -> 2
            normalized in 247.5..292.5 -> 7
            else -> 6
        }
    }
}
