package com.example.yiijingcompass.model

/**
 * 二十四节气与十二消息卦数据模型
 */
data class SolarTermItem(
    val name: String,              // 如 "立春", "雨水"
    val angleCenter: Double,       // 罗盘对应角度中心
    val season: String,            // "春", "夏", "秋", "冬"
    val hexagramName: String?,     // 十二消息卦/辟卦 (如 "地天泰")
    val isMajorTerm: Boolean       // 是否为分至点 (春分、秋分、夏至、冬至)
) {
    val id: String get() = name

    val localizedName: String
        get() {
            val language = LocalizationManager.instance.effectiveLanguage
            return when (language) {
                AppLanguage.EN -> mapOf(
                    "冬至" to "Winter Solstice", "小寒" to "Minor Cold", "大寒" to "Major Cold",
                    "立春" to "Start of Spring", "雨水" to "Rain Water", "惊蛰" to "Awakening of Insects",
                    "春分" to "Spring Equinox", "清明" to "Clear and Bright", "谷雨" to "Grain Rain",
                    "立夏" to "Start of Summer", "小满" to "Grain Buds", "芒种" to "Grain in Ear",
                    "夏至" to "Summer Solstice", "小暑" to "Minor Heat", "大暑" to "Major Heat",
                    "立秋" to "Start of Autumn", "处暑" to "End of Heat", "白露" to "White Dew",
                    "秋分" to "Autumn Equinox", "寒露" to "Cold Dew", "霜降" to "Frost Descent",
                    "立冬" to "Start of Winter", "小雪" to "Minor Snow", "大雪" to "Major Snow"
                )[name] ?: name

                AppLanguage.ID -> mapOf(
                    "冬至" to "Solstis Dingin", "小寒" to "Dingin Kecil", "大寒" to "Dingin Hebat",
                    "立春" to "Awal Semi", "雨水" to "Air Hujan", "惊蛰" to "Serangga Bangkit",
                    "春分" to "Ekuinoks Semi", "清明" to "Cerah Terang", "谷雨" to "Hujan Gandum",
                    "立夏" to "Awal Panas", "小满" to "Tunas Gandum", "芒种" to "Gandum Bertunas",
                    "夏至" to "Solstis Panas", "小暑" to "Panas Kecil", "大暑" to "Panas Hebat",
                    "立秋" to "Awal Gugur", "处暑" to "Akhir Panas", "白露" to "Embun Putih",
                    "秋分" to "Ekuinoks Gugur", "寒露" to "Embun Dingin", "霜降" to "Turun Embun Beku",
                    "立冬" to "Awal Dingin", "小雪" to "Salju Kecil", "大雪" to "Salju Lebat"
                )[name] ?: name

                AppLanguage.JA -> mapOf(
                    "冬至" to "冬至", "小寒" to "小寒", "大寒" to "大寒",
                    "立春" to "立春", "雨水" to "雨水", "惊蛰" to "啓蟄",
                    "春分" to "春分", "清明" to "清明", "谷雨" to "穀雨",
                    "立夏" to "立夏", "小满" to "小満", "芒种" to "芒種",
                    "夏至" to "夏至", "小暑" to "小暑", "大暑" to "大暑",
                    "立秋" to "立秋", "处暑" to "処暑", "白露" to "白露",
                    "秋分" to "秋分", "寒露" to "寒露", "霜降" to "霜降",
                    "立冬" to "立冬", "小雪" to "小雪", "大雪" to "大雪"
                )[name] ?: name

                AppLanguage.KO -> mapOf(
                    "冬至" to "동지", "小寒" to "소한", "大寒" to "대한",
                    "立春" to "입춘", "雨水" to "우수", "惊蛰" to "경칩",
                    "春分" to "춘분", "清明" to "청명", "谷雨" to "곡우",
                    "立夏" to "입하", "小满" to "소만", "芒种" to "망종",
                    "夏至" to "하지", "小暑" to "소서", "大暑" to "대서",
                    "立秋" to "입추", "处暑" to "처서", "白露" to "백로",
                    "秋分" to "추분", "寒露" to "한로", "霜降" to "상강",
                    "立冬" to "입동", "小雪" to "소설", "大雪" to "대설"
                )[name] ?: name

                AppLanguage.VI -> mapOf(
                    "冬至" to "Đông chí", "小寒" to "Tiểu hàn", "大寒" to "Đại hàn",
                    "立春" to "Lập xuân", "雨水" to "Vũ thủy", "惊蛰" to "Kinh trập",
                    "春分" to "Xuân phân", "清明" to "Thanh minh", "谷雨" to "Cốc vũ",
                    "立夏" to "Lập hạ", "小满" to "Tiểu mãn", "芒种" to "Mang chủng",
                    "夏至" to "Hạ chí", "小暑" to "Tiểu thử", "大暑" to "Đại thử",
                    "立秋" to "Lập thu", "处暑" to "Xử thử", "白露" to "Bạch lộ",
                    "秋分" to "Thu phân", "寒露" to "Hàn lộ", "霜降" to "Sương giáng",
                    "立冬" to "Lập đông", "小雪" to "Tiểu tuyết", "大雪" to "Đại tuyết"
                )[name] ?: name

                AppLanguage.TH -> mapOf(
                    "冬至" to "เหมายัน", "小寒" to "เสี่ยวหาน", "大寒" to "ต้าหาน",
                    "立春" to "ลี่ชุน", "雨水" to "อวี่สุ่ย", "惊蛰" to "จิงเจ๋อ",
                    "春分" to "ชุนเฟิน", "清明" to "ชิงหมิง", "谷雨" to "กู่ยวี่",
                    "立夏" to "ลี่เซี่ย", "小满" to "เสี่ยวหม่าน", "芒种" to "หมางจ้ง",
                    "夏至" to "ครีษมายัน", "小暑" to "เสี่ยวสู่", "大暑" to "ต้าสู่",
                    "立秋" to "ลี่ชิว", "处暑" to "ชู่สู่", "白露" to "ไป๋ลู่",
                    "秋分" to "ศารทวิษุวัต", "寒露" to "หานลู่", "霜降" to "ซวงเจี้ยง",
                    "立冬" to "ลี่ตง", "小雪" to "เสี่ยวเสวี่ย", "大雪" to "ต้าเสวี่ย"
                )[name] ?: name

                AppLanguage.ZH_HANT -> mapOf(
                    "惊蛰" to "驚蟄", "小满" to "小滿", "芒种" to "芒種", "处暑" to "處暑"
                )[name] ?: name

                AppLanguage.AUTO, AppLanguage.ZH_HANS -> name
            }
        }
}

class SolarTermsData private constructor() {
    companion object {
        val instance: SolarTermsData by lazy { SolarTermsData() }
    }

    val terms: List<SolarTermItem> = listOf(
        SolarTermItem("冬至", 0.0, "冬", "地雷复", true),
        SolarTermItem("小寒", 15.0, "冬", null, false),
        SolarTermItem("大寒", 30.0, "冬", "地泽临", false),
        SolarTermItem("立春", 45.0, "春", "地天泰", false),
        SolarTermItem("雨水", 60.0, "春", null, false),
        SolarTermItem("惊蛰", 75.0, "春", "雷天大壮", false),
        SolarTermItem("春分", 90.0, "春", null, true),
        SolarTermItem("清明", 105.0, "春", "泽天夬", false),
        SolarTermItem("谷雨", 120.0, "春", null, false),
        SolarTermItem("立夏", 135.0, "夏", "乾为天", false),
        SolarTermItem("小满", 150.0, "夏", null, false),
        SolarTermItem("芒种", 165.0, "夏", "天风姤", false),
        SolarTermItem("夏至", 180.0, "夏", null, true),
        SolarTermItem("小暑", 195.0, "夏", "天山遁", false),
        SolarTermItem("大暑", 210.0, "夏", null, false),
        SolarTermItem("立秋", 225.0, "秋", "天地否", false),
        SolarTermItem("处暑", 240.0, "秋", null, false),
        SolarTermItem("白露", 255.0, "秋", "风地观", false),
        SolarTermItem("秋分", 270.0, "秋", null, true),
        SolarTermItem("寒露", 285.0, "秋", "山地剥", false),
        SolarTermItem("霜降", 300.0, "秋", null, false),
        SolarTermItem("立冬", 315.0, "冬", "坤为地", false),
        SolarTermItem("小雪", 330.0, "冬", null, false),
        SolarTermItem("大雪", 345.0, "冬", null, false)
    )
}

