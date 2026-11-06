import Foundation

// MARK: - 真太阳时与太阳黄经节气计算器

public typealias TrueSolarTimeEngine = SolarTimeCalculator

public struct SolarTimeResult {
    public let standardTimeString: String
    public let trueSolarTimeString: String
    public let timeOffsetMinutes: Double
    public let equationOfTimeMinutes: Double
    public let solarTermName: String
    public let baziGanzhi: String
    public let dayPillar: String

    /// Localized day pillar (e.g. 甲子 → "Jia Zi" in English, native script
    /// elsewhere). The stored `dayPillar` is always a two-character Chinese
    /// Heavenly Stem + Earthly Branch pair.
    public var localizedDayPillar: String {
        let lang = LocalizationManager.shared.effectiveLanguage
        let stem = String(dayPillar.prefix(1))
        let branch = String(dayPillar.suffix(1))
        switch lang {
        case .en, .id:
            let stems = ["甲": "Jia", "乙": "Yi", "丙": "Bing", "丁": "Ding", "戊": "Wu", "己": "Ji", "庚": "Geng", "辛": "Xin", "壬": "Ren", "癸": "Gui"]
            let branches = ["子": "Zi", "丑": "Chou", "寅": "Yin", "卯": "Mao", "辰": "Chen", "巳": "Si", "午": "Wu", "未": "Wei", "申": "Shen", "酉": "You", "戌": "Xu", "亥": "Hai"]
            return "\(stems[stem, default: stem])\(branches[branch, default: branch])"
        case .ko:
            let stems = ["甲": "갑", "乙": "을", "丙": "병", "丁": "정", "戊": "무", "己": "기", "庚": "경", "辛": "신", "壬": "임", "癸": "계"]
            let branches = ["子": "자", "丑": "축", "寅": "인", "卯": "묘", "辰": "진", "巳": "사", "午": "오", "未": "미", "申": "신", "酉": "유", "戌": "술", "亥": "해"]
            return "\(stems[stem, default: stem])\(branches[branch, default: branch])"
        case .vi:
            let stems = ["甲": "Giáp", "乙": "Ất", "丙": "Bính", "丁": "Đinh", "戊": "Mậu", "己": "Kỷ", "庚": "Canh", "辛": "Tân", "壬": "Nhâm", "癸": "Quý"]
            let branches = ["子": "Tý", "丑": "Sửu", "寅": "Dần", "卯": "Mão", "辰": "Thìn", "巳": "Tỵ", "午": "Ngọ", "未": "Mùi", "申": "Thân", "酉": "Dậu", "戌": "Tuất", "亥": "Hợi"]
            return "\(stems[stem, default: stem])\(branches[branch, default: branch])"
        case .th:
            let stems = ["甲": "เจี่ย", "乙": "อี้", "丙": "ปิ่ง", "丁": "ติง", "戊": "อู่", "己": "จี่", "庚": "เกิง", "辛": "ซิน", "壬": "เหริน", "癸": "กุ่ย"]
            let branches = ["子": "จื่อ", "丑": "โฉ่ว", "寅": "หยิน", "卯": "เหมา", "辰": "เฉิน", "巳": "ซื่อ", "午": "อู่", "未": "เว่ย", "申": "เซิน", "酉": "โหย่ว", "戌": "ซวี", "亥": "ฮ่าย"]
            return "\(stems[stem, default: stem])\(branches[branch, default: branch])"
        case .ja, .zhHant, .zhHans, .auto:
            return dayPillar
        }
    }
}

public final class SolarTimeCalculator {
    public static let shared = SolarTimeCalculator()

    // 以小寒 285°为起点，顺序为太阳视黄经每 15°对应的节气。
    private let solarTerms = [
        "小寒", "大寒", "立春", "雨水", "惊蛰", "春分",
        "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
        "小暑", "大暑", "立秋", "处暑", "白露", "秋分",
        "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"
    ]
    private let heavenlyStems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private let earthlyBranches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

    public func computeNow(longitude: Double) -> SolarTimeResult {
        return calculate(date: Date(), longitude: longitude)
    }

    public func calculate(date: Date = Date(), longitude: Double = 0.0) -> SolarTimeResult {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        // 以当前系统时区的标准经线为基准；中国时区仍然等于东经 120°，
        // 在其他地区也不会误套北京时间。secondsFromGMT(for:) 包含夏令时，
        // 直接使用会在夏令时地区额外产生 1 小时（15°）的经度误差；
        // 真太阳时应以时区的标准偏移量作为民用钟表基准。
        let daylightSavingOffset = calendar.timeZone.daylightSavingTimeOffset(for: date)
        let standardSecondsFromGMT = calendar.timeZone.secondsFromGMT(for: date) - Int(daylightSavingOffset)
        let timezoneMeridian = Double(standardSecondsFromGMT) / 3600.0 * 15.0
        let longitudeOffset = (longitude - timezoneMeridian) * 4.0
        let daysInYear = Double(calendar.range(of: .day, in: .year, for: date)?.count ?? 365)
        let fractionalDay = Double(dayOfYear - 1)
            + Double((components.hour ?? 12) - 12) / 24.0
            + Double(components.minute ?? 0) / 1_440.0
            + Double(components.second ?? 0) / 86_400.0
        let gamma = 2.0 * .pi / daysInYear * fractionalDay
        let equationOfTime = 229.18 * (
            0.000075
            + 0.001868 * cos(gamma)
            - 0.032077 * sin(gamma)
            - 0.014615 * cos(2.0 * gamma)
            - 0.040849 * sin(2.0 * gamma)
        )
        let totalOffsetMinutes = longitudeOffset + equationOfTime
        let trueSolarDate = date.addingTimeInterval(totalOffsetMinutes * 60.0)

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = calendar.timeZone

        let termIndex = solarTermIndex(for: date)
        // Four Pillars use local apparent solar time.  A longitude correction
        // can move an instant across a solar-term boundary, so derive the
        // year/month pillar bucket from the corrected instant as well.
        let baziTermIndex = solarTermIndex(for: trueSolarDate)
        let bazi = calculateBazi(
            for: trueSolarDate,
            termIndex: baziTermIndex,
            calendar: calendar,
            beforeLiChun: isBeforeLiChun(for: trueSolarDate)
        )

        return SolarTimeResult(
            standardTimeString: formatter.string(from: date),
            trueSolarTimeString: formatter.string(from: trueSolarDate),
            timeOffsetMinutes: totalOffsetMinutes,
            equationOfTimeMinutes: equationOfTime,
            solarTermName: solarTerms[termIndex],
            baziGanzhi: bazi.fullText,
            dayPillar: bazi.dayPillar
        )
    }

    private func normalizedDegrees(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360.0)
        return result >= 0 ? result : result + 360.0
    }

    /// Returns the current solar-term bucket (0 = 小寒 ... 23 = 冬至).
    /// Keeping this calculation in one place prevents the date-selection
    /// engines from silently falling back to Gregorian month boundaries.
    public func solarTermIndex(for date: Date) -> Int {
        solarTermIndex(forLongitude: solarApparentLongitude(for: date))
    }

    /// Returns the localized-independent source name of the current solar-term
    /// bucket.  The compass maps this name to its own north-based ring order.
    public func solarTermName(for date: Date = Date()) -> String {
        solarTerms[solarTermIndex(for: date)]
    }

    /// Whether the instant is before the traditional Li Chun year boundary.
    ///
    /// The term index wraps at the winter solstice: index 23 covers the
    /// interval from winter solstice to Xiao Han, followed by indices 0 and 1
    /// before Li Chun (index 2).  Checking only `termIndex < 2` therefore
    /// mislabels January dates that are still in index 23 as the new Ganzhi
    /// year.
    public func isBeforeLiChun(for date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let month = calendar.component(.month, from: date)
        let termIndex = solarTermIndex(for: date)
        // Bucket 23 is handled by the January branch above; in February only
        // the two buckets immediately before Li Chun can still be active.
        return month < 2 || (month == 2 && termIndex < 2)
    }

    /// Fractional days elapsed since the start of the current 15° solar-term
    /// bucket.  This is used by the Qimen 拆补 method to split each term into
    /// upper, middle and lower five-day yuan segments.
    public func solarTermProgress(for date: Date) -> Double {
        let longitude = solarApparentLongitude(for: date)
        let shifted = normalizedDegrees(longitude - 285.0)
        let degreesIntoTerm = shifted.truncatingRemainder(dividingBy: 15.0)
        // Mean apparent solar motion; the low-order longitude model above is
        // already the limiting accuracy of this offline calculation.
        return degreesIntoTerm / 0.98564736
    }

    private func solarTermIndex(forLongitude longitude: Double) -> Int {
        let shifted = normalizedDegrees(longitude - 285.0)
        return min(23, Int(floor(shifted / 15.0)))
    }

    /// Meeus 低阶太阳位置公式。它直接按太阳视黄经确定节气，避免固定 15 天间隔造成的节气错位。
    private func solarApparentLongitude(for date: Date) -> Double {
        let julianDate = date.timeIntervalSince1970 / 86_400.0 + 2_440_587.5
        let centuries = (julianDate - 2_451_545.0) / 36_525.0
        let meanLongitude = normalizedDegrees(280.46646 + 36_000.76983 * centuries + 0.0003032 * centuries * centuries)
        let meanAnomaly = normalizedDegrees(357.52911 + 35_999.05029 * centuries - 0.0001537 * centuries * centuries) * .pi / 180.0
        let equationOfCenter =
            (1.914602 - 0.004817 * centuries - 0.000014 * centuries * centuries) * sin(meanAnomaly)
            + (0.019993 - 0.000101 * centuries) * sin(2.0 * meanAnomaly)
            + 0.000289 * sin(3.0 * meanAnomaly)
        return normalizedDegrees(meanLongitude + equationOfCenter)
    }

    private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        let result = value % modulus
        return result >= 0 ? result : result + modulus
    }

    private func calculateBazi(
        for date: Date,
        termIndex: Int,
        calendar: Calendar,
        beforeLiChun: Bool
    ) -> (fullText: String, dayPillar: String) {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        // In the traditional convention the day changes at 子初 (23:00),
        // while the year/month still follow the solar-term bucket supplied by
        // the caller. Apply the one-day rollover only to the day pillar.
        let dayPillarDate = (components.hour ?? 0) >= 23
            ? (calendar.date(byAdding: .day, value: 1, to: date) ?? date)
            : date
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: dayPillarDate)
        let civilYear = components.year ?? 2000
        // Li Chun is a civil-date boundary in addition to the solar-term
        // bucket.  In January the sun can still be in bucket 23 (冬至), which
        // is before Li Chun even though its index is greater than 2.
        // The caller evaluates Li Chun using the same corrected apparent-solar
        // instant used for the month bucket. This avoids assigning a different
        // year during the few minutes around the boundary.
        let ganzhiYear = beforeLiChun ? civilYear - 1 : civilYear
        let yearCycle = positiveModulo(ganzhiYear - 4, 60)
        let yearStem = yearCycle % 10
        let yearBranch = yearCycle % 12

        // 立春起寅月；小寒和大寒仍属于丑月。
        let monthBranch = termIndex < 2 ? 1 : positiveModulo(2 + (termIndex - 2) / 2, 12)
        let monthStemStart = positiveModulo((yearStem % 5) * 2 + 2, 10)
        let monthStem = positiveModulo(monthStemStart + positiveModulo(monthBranch - 2, 12), 10)

        let year = dayComponents.year ?? civilYear
        let month = dayComponents.month ?? (components.month ?? 1)
        let day = dayComponents.day ?? (components.day ?? 1)
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        let julianDay = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32_045
        let dayCycle = positiveModulo(julianDay + 49, 60)
        let dayStem = dayCycle % 10
        let dayBranch = dayCycle % 12

        let hour = components.hour ?? 12
        let hourBranch = ((hour + 1) / 2) % 12
        let hourStem = positiveModulo((dayStem % 5) * 2 + hourBranch, 10)

        let dayPillar = "\(heavenlyStems[dayStem])\(earthlyBranches[dayBranch])"
        let language = LocalizationManager.shared.effectiveLanguage
        switch language {
        case .en:
            let stemPinyin = ["Jia", "Yi", "Bing", "Ding", "Wu", "Ji", "Geng", "Xin", "Ren", "Gui"]
            let branchPinyin = ["Zi", "Chou", "Yin", "Mao", "Chen", "Si", "Wu", "Wei", "Shen", "You", "Xu", "Hai"]
            return (fullText: "\(stemPinyin[yearStem])-\(branchPinyin[yearBranch]) Year · "
                + "\(stemPinyin[monthStem])-\(branchPinyin[monthBranch]) Month · "
                + "\(stemPinyin[dayStem])-\(branchPinyin[dayBranch]) Day · "
                + "\(stemPinyin[hourStem])-\(branchPinyin[hourBranch]) Hour", dayPillar: dayPillar)
        case .id:
            let stemPinyin = ["Jia", "Yi", "Bing", "Ding", "Wu", "Ji", "Geng", "Xin", "Ren", "Gui"]
            let branchPinyin = ["Zi", "Chou", "Yin", "Mao", "Chen", "Si", "Wu", "Wei", "Shen", "You", "Xu", "Hai"]
            return (fullText: "Thn \(stemPinyin[yearStem])-\(branchPinyin[yearBranch]) · "
                + "Bln \(stemPinyin[monthStem])-\(branchPinyin[monthBranch]) · "
                + "Hr \(stemPinyin[dayStem])-\(branchPinyin[dayBranch]) · "
                + "Jam \(stemPinyin[hourStem])-\(branchPinyin[hourBranch])", dayPillar: dayPillar)
        case .ja:
            return (fullText: "\(heavenlyStems[yearStem])\(earthlyBranches[yearBranch])年 "
                + "\(heavenlyStems[monthStem])\(earthlyBranches[monthBranch])月 "
                + "\(heavenlyStems[dayStem])\(earthlyBranches[dayBranch])日 "
                + "\(heavenlyStems[hourStem])\(earthlyBranches[hourBranch])時", dayPillar: dayPillar)
        case .ko:
            let koStems = ["갑", "을", "병", "정", "무", "기", "경", "신", "임", "계"]
            let koBranches = ["자", "축", "인", "묘", "진", "사", "오", "미", "신", "유", "술", "해"]
            return (fullText: "\(koStems[yearStem])\(koBranches[yearBranch])년 "
                + "\(koStems[monthStem])\(koBranches[monthBranch])월 "
                + "\(koStems[dayStem])\(koBranches[dayBranch])일 "
                + "\(koStems[hourStem])\(koBranches[hourBranch])시", dayPillar: dayPillar)
        case .vi:
            let viStems = ["Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý"]
            let viBranches = ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"]
            return (fullText: "\(viStems[yearStem]) \(viBranches[yearBranch]) năm · "
                + "\(viStems[monthStem]) \(viBranches[monthBranch]) tháng · "
                + "\(viStems[dayStem]) \(viBranches[dayBranch]) ngày · "
                + "\(viStems[hourStem]) \(viBranches[hourBranch]) giờ", dayPillar: dayPillar)
        case .th:
            let thStems = ["เจี่ย", "อี้", "ปิ่ง", "ติง", "อู่", "จี่", "เกิง", "ซิน", "เหริน", "กุ่ย"]
            let thBranches = ["จื่อ", "โฉ่ว", "หยิน", "เหมา", "เฉิน", "ซื่อ", "อู่", "เว่ย", "เซิน", "โหย่ว", "ซวี", "ฮ่าย"]
            return (fullText: "ปี \(thStems[yearStem])-\(thBranches[yearBranch]) · "
                + "เดือน \(thStems[monthStem])-\(thBranches[monthBranch]) · "
                + "วัน \(thStems[dayStem])-\(thBranches[dayBranch]) · "
                + "ยาม \(thStems[hourStem])-\(thBranches[hourBranch])", dayPillar: dayPillar)
        case .zhHant:
            return (fullText: "\(heavenlyStems[yearStem])\(earthlyBranches[yearBranch])年 "
                + "\(heavenlyStems[monthStem])\(earthlyBranches[monthBranch])月 "
                + "\(heavenlyStems[dayStem])\(earthlyBranches[dayBranch])日 "
                + "\(heavenlyStems[hourStem])\(earthlyBranches[hourBranch])時", dayPillar: dayPillar)
        case .auto, .zhHans:
            return (fullText: "\(heavenlyStems[yearStem])\(earthlyBranches[yearBranch])年 "
                + "\(heavenlyStems[monthStem])\(earthlyBranches[monthBranch])月 "
                + "\(heavenlyStems[dayStem])\(earthlyBranches[dayBranch])日 "
                + "\(heavenlyStems[hourStem])\(earthlyBranches[hourBranch])时", dayPillar: dayPillar)
        }
    }
}
