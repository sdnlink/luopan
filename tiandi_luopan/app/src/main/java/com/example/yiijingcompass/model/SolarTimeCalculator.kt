package com.example.yiijingcompass.model

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.sin

data class SolarTimeResult(
    val standardTimeString: String,
    val trueSolarTimeString: String,
    val timeOffsetMinutes: Double,
    val equationOfTimeMinutes: Double,
    val solarTermName: String,
    val baziGanzhi: String,
    val dayPillar: String
) { val localizedDayPillar: String get() = SolarTimeCalculator.localizedDayPillar(dayPillar) }

data class SolarTermTransition(val date: Date, val name: String)

class SolarTimeCalculator private constructor() {
    companion object {
        val instance: SolarTimeCalculator by lazy { SolarTimeCalculator() }
        fun localizedDayPillar(pillar: String): String {
            val stems = "甲乙丙丁戊己庚辛壬癸"
            val branches = "子丑寅卯辰巳午未申酉戌亥"
            val language = LocalizationManager.instance.effectiveLanguage
            val values = when(language) {
                AppLanguage.EN, AppLanguage.ID -> "Jia,Yi,Bing,Ding,Wu,Ji,Geng,Xin,Ren,Gui" to "Zi,Chou,Yin,Mao,Chen,Si,Wu,Wei,Shen,You,Xu,Hai"
                AppLanguage.KO -> "갑,을,병,정,무,기,경,신,임,계" to "자,축,인,묘,진,사,오,미,신,유,술,해"
                AppLanguage.VI -> "Giáp,Ất,Bính,Đinh,Mậu,Kỷ,Canh,Tân,Nhâm,Quý" to "Tý,Sửu,Dần,Mão,Thìn,Tỵ,Ngọ,Mùi,Thân,Dậu,Tuất,Hợi"
                AppLanguage.TH -> "เจี่ย,อี้,ปิ่ง,ติง,อู่,จี่,เกิง,ซิน,เหริน,กุ่ย" to "จื่อ,โฉ่ว,หยิน,เหมา,เฉิน,ซื่อ,อู่,เว่ย,เซิน,โหย่ว,ซวี,ฮ่าย"
                else -> return pillar
            }
            val a = pillar.firstOrNull()?.let { stems.indexOf(it) } ?: -1
            val b = pillar.lastOrNull()?.let { branches.indexOf(it) } ?: -1
            return if (a >= 0 && b >= 0) values.first.split(',')[a] + values.second.split(',')[b] else pillar
        }

    }

    private val solarTerms = listOf(
        "小寒", "大寒", "立春", "雨水", "惊蛰", "春分",
        "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
        "小暑", "大暑", "立秋", "处暑", "白露", "秋分",
        "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"
    )

    private val heavenlyStems = listOf("甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸")
    private val earthlyBranches = listOf("子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥")

    fun computeNow(longitude: Double): SolarTimeResult {
        return calculate(Date(), longitude)
    }

    fun calculate(date: Date = Date(), longitude: Double = 0.0, timeZone: TimeZone = TimeZone.getDefault()): SolarTimeResult {
        val civilCalendar = java.util.GregorianCalendar(timeZone).apply { time = date }
        val calendar = java.util.GregorianCalendar(TimeZone.getTimeZone("UTC"))
        calendar.time = date

        val hour = calendar.get(Calendar.HOUR_OF_DAY)
        val minute = calendar.get(Calendar.MINUTE)
        val second = calendar.get(Calendar.SECOND)
        val dayOfYear = calendar.get(Calendar.DAY_OF_YEAR)

        val daysInYear = calendar.getActualMaximum(Calendar.DAY_OF_YEAR).toDouble()
        val fractionalDay = (dayOfYear - 1).toDouble() +
                (hour - 12).toDouble() / 24.0 +
                minute.toDouble() / 1440.0 +
                second.toDouble() / 86400.0
        val gamma = 2.0 * Math.PI / daysInYear * fractionalDay
        val equationOfTime = 229.18 * (
                0.000075 +
                0.001868 * cos(gamma) -
                0.032077 * sin(gamma) -
                0.014615 * cos(2.0 * gamma) -
                0.040849 * sin(2.0 * gamma)
        )
        val solarOffsetMinutes = longitude * 4.0 + equationOfTime
        val totalOffsetMinutes = solarOffsetMinutes - timeZone.getOffset(date.time) / 60000.0
        val trueSolarDate = Date(date.time + (solarOffsetMinutes * 60000.0).toLong())
        val formatter = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).apply { this.timeZone = timeZone }
        val solarFormatter = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).apply { this.timeZone = TimeZone.getTimeZone("UTC") }
        val termIndex = solarTermIndex(date)
        val bazi = calculateBazi(trueSolarDate, termIndex, calendar, civilCalendar.get(Calendar.YEAR), isBeforeLiChun(date, timeZone))

        return SolarTimeResult(
            standardTimeString = formatter.format(date),
            trueSolarTimeString = solarFormatter.format(trueSolarDate),
            timeOffsetMinutes = totalOffsetMinutes,
            equationOfTimeMinutes = equationOfTime,
            solarTermName = solarTerms[termIndex],
            baziGanzhi = bazi.first,
            dayPillar = bazi.second
        )
    }

    fun upcomingSolarTerms(after: Date, count: Int = 24): List<SolarTermTransition> {
        var cursor = after.time
        return (0 until count.coerceIn(0, 48)).map {
            val index = solarTermIndex(Date(cursor))
            var low = cursor; var high = cursor + 20 * 86400000L
            while (high - low > 100) {
                val middle = low + (high - low) / 2
                if (solarTermIndex(Date(middle)) == index) low = middle else high = middle
            }
            cursor = high + 1000
            SolarTermTransition(Date(high), solarTermName(Date(high)))
        }
    }

    private fun normalizedDegrees(value: Double): Double {
        val result = value % 360.0
        return if (result >= 0) result else result + 360.0
    }

    fun solarTermIndex(date: Date): Int {
        return solarTermIndexForLongitude(solarApparentLongitude(date))
    }

    fun solarTermName(date: Date = Date()): String {
        return solarTerms[solarTermIndex(date)]
    }

    fun isBeforeLiChun(date: Date, timeZone: TimeZone = TimeZone.getDefault()): Boolean {
        val cal = java.util.GregorianCalendar(timeZone)
        cal.time = date
        val month = cal.get(Calendar.MONTH) + 1 // 1-based
        val termIndex = solarTermIndex(date)
        return month < 2 || (month == 2 && termIndex < 2)
    }

    fun solarTermProgress(date: Date): Double {
        val lon = solarApparentLongitude(date)
        val shifted = normalizedDegrees(lon - 285.0)
        val degreesIntoTerm = shifted % 15.0
        return degreesIntoTerm / 0.98564736
    }

    private fun solarTermIndexForLongitude(longitude: Double): Int {
        val shifted = normalizedDegrees(longitude - 285.0)
        return floor(shifted / 15.0).toInt().coerceIn(0, 23)
    }

    private fun solarApparentLongitude(date: Date): Double {
        val julianDate = date.time.toDouble() / 86400000.0 + 2440587.5
        val centuries = (julianDate - 2451545.0) / 36525.0
        val meanLongitude = normalizedDegrees(280.46646 + 36000.76983 * centuries + 0.0003032 * centuries * centuries)
        val meanAnomaly = Math.toRadians(normalizedDegrees(357.52911 + 35999.05029 * centuries - 0.0001537 * centuries * centuries))
        val equationOfCenter = (1.914602 - 0.004817 * centuries - 0.000014 * centuries * centuries) * sin(meanAnomaly) +
                (0.019993 - 0.000101 * centuries) * sin(2.0 * meanAnomaly) +
                0.000289 * sin(3.0 * meanAnomaly)
        return normalizedDegrees(meanLongitude + equationOfCenter)
    }

    private fun positiveModulo(value: Int, modulus: Int): Int {
        val result = value % modulus
        return if (result >= 0) result else result + modulus
    }

    private fun calculateBazi(
        date: Date,
        termIndex: Int,
        calendar: Calendar,
        civilYear: Int,
        beforeLiChun: Boolean
    ): Pair<String, String> {
        calendar.time = date
        val hour = calendar.get(Calendar.HOUR_OF_DAY)

        val dayPillarDate = if (hour >= 23) {
            Date(date.time + 86400000L)
        } else {
            date
        }
        val dayCal = java.util.GregorianCalendar(calendar.timeZone).apply { time = dayPillarDate }
        val dayYear = dayCal.get(Calendar.YEAR)
        val dayMonth = dayCal.get(Calendar.MONTH) + 1
        val dayDay = dayCal.get(Calendar.DAY_OF_MONTH)

        val ganzhiYear = if (beforeLiChun) civilYear - 1 else civilYear
        val yearCycle = positiveModulo(ganzhiYear - 4, 60)
        val yearStem = yearCycle % 10
        val yearBranch = yearCycle % 12

        val monthBranch = if (termIndex < 2) 1 else positiveModulo(2 + (termIndex - 2) / 2, 12)
        val monthStemStart = positiveModulo((yearStem % 5) * 2 + 2, 10)
        val monthStem = positiveModulo(monthStemStart + positiveModulo(monthBranch - 2, 12), 10)

        val a = (14 - dayMonth) / 12
        val y = dayYear + 4800 - a
        val m = dayMonth + 12 * a - 3
        val julianDay = dayDay + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
        val dayCycle = positiveModulo(julianDay + 49, 60)
        val dayStem = dayCycle % 10
        val dayBranch = dayCycle % 12

        val hourBranch = ((hour + 1) / 2) % 12
        val hourStem = positiveModulo((dayStem % 5) * 2 + hourBranch, 10)

        val dayPillar = "${heavenlyStems[dayStem]}${earthlyBranches[dayBranch]}"

        val lang = LocalizationManager.instance.effectiveLanguage
        val fullText = when (lang) {
            AppLanguage.EN -> {
                val stemPinyin = listOf("Jia", "Yi", "Bing", "Ding", "Wu", "Ji", "Geng", "Xin", "Ren", "Gui")
                val branchPinyin = listOf("Zi", "Chou", "Yin", "Mao", "Chen", "Si", "Wu", "Wei", "Shen", "You", "Xu", "Hai")
                "${stemPinyin[yearStem]}-${branchPinyin[yearBranch]} Year · " +
                "${stemPinyin[monthStem]}-${branchPinyin[monthBranch]} Month · " +
                "${stemPinyin[dayStem]}-${branchPinyin[dayBranch]} Day · " +
                "${stemPinyin[hourStem]}-${branchPinyin[hourBranch]} Hour"
            }
            AppLanguage.ID -> {
                val stemPinyin = listOf("Jia", "Yi", "Bing", "Ding", "Wu", "Ji", "Geng", "Xin", "Ren", "Gui")
                val branchPinyin = listOf("Zi", "Chou", "Yin", "Mao", "Chen", "Si", "Wu", "Wei", "Shen", "You", "Xu", "Hai")
                "Thn ${stemPinyin[yearStem]}-${branchPinyin[yearBranch]} · " +
                "Bln ${stemPinyin[monthStem]}-${branchPinyin[monthBranch]} · " +
                "Hr ${stemPinyin[dayStem]}-${branchPinyin[dayBranch]} · " +
                "Jam ${stemPinyin[hourStem]}-${branchPinyin[hourBranch]}"
            }
            AppLanguage.JA -> {
                "${heavenlyStems[yearStem]}${earthlyBranches[yearBranch]}年 " +
                "${heavenlyStems[monthStem]}${earthlyBranches[monthBranch]}月 " +
                "${heavenlyStems[dayStem]}${earthlyBranches[dayBranch]}日 " +
                "${heavenlyStems[hourStem]}${earthlyBranches[hourBranch]}時"
            }
            AppLanguage.KO -> {
                val koStems = listOf("갑", "을", "병", "정", "무", "기", "경", "신", "임", "계")
                val koBranches = listOf("자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해")
                "${koStems[yearStem]}${koBranches[yearBranch]}년 " +
                "${koStems[monthStem]}${koBranches[monthBranch]}월 " +
                "${koStems[dayStem]}${koBranches[dayBranch]}일 " +
                "${koStems[hourStem]}${koBranches[hourBranch]}시"
            }
            AppLanguage.VI -> {
                val viStems = listOf("Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý")
                val viBranches = listOf("Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi")
                "${viStems[yearStem]} ${viBranches[yearBranch]} năm · " +
                "${viStems[monthStem]} ${viBranches[monthBranch]} tháng · " +
                "${viStems[dayStem]} ${viBranches[dayBranch]} ngày · " +
                "${viStems[hourStem]} ${viBranches[hourBranch]} giờ"
            }
            AppLanguage.TH -> {
                val thStems = listOf("เจี่ย", "อี้", "ปิ่ง", "ติง", "อู่", "จี่", "เกิง", "ซิน", "เหริน", "กุ่ย")
                val thBranches = listOf("จื่อ", "โฉ่ว", "หยิน", "เหมา", "เฉิน", "ซื่อ", "อู่", "เว่ย", "เซิน", "โหย่ว", "ซวี", "ฮ่าย")
                "ปี ${thStems[yearStem]}-${thBranches[yearBranch]} · " +
                "เดือน ${thStems[monthStem]}-${thBranches[monthBranch]} · " +
                "วัน ${thStems[dayStem]}-${thBranches[dayBranch]} · " +
                "ยาม ${thStems[hourStem]}-${thBranches[hourBranch]}"
            }
            AppLanguage.ZH_HANT -> {
                "${heavenlyStems[yearStem]}${earthlyBranches[yearBranch]}年 " +
                "${heavenlyStems[monthStem]}${earthlyBranches[monthBranch]}月 " +
                "${heavenlyStems[dayStem]}${earthlyBranches[dayBranch]}日 " +
                "${heavenlyStems[hourStem]}${earthlyBranches[hourBranch]}時"
            }
            AppLanguage.AUTO, AppLanguage.ZH_HANS -> {
                "${heavenlyStems[yearStem]}${earthlyBranches[yearBranch]}年 " +
                "${heavenlyStems[monthStem]}${earthlyBranches[monthBranch]}月 " +
                "${heavenlyStems[dayStem]}${earthlyBranches[dayBranch]}日 " +
                "${heavenlyStems[hourStem]}${earthlyBranches[hourBranch]}时"
            }
        }
        return Pair(fullText, dayPillar)
    }
}

