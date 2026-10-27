import Foundation

// MARK: - 真太阳时与太阳黄经节气计算器

public struct SolarTimeResult {
    public let standardTimeString: String
    public let trueSolarTimeString: String
    public let timeOffsetMinutes: Double
    public let equationOfTimeMinutes: Double
    public let solarTermName: String
    public let baziGanzhi: String
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

    public func calculate(date: Date = Date(), longitude: Double = 116.4074) -> SolarTimeResult {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        // 以当前系统时区的标准经线为基准；中国时区仍然等于东经 120°，在其他地区也不会误套北京时间。
        let timezoneMeridian = Double(calendar.timeZone.secondsFromGMT(for: date)) / 3600.0 * 15.0
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

        let termIndex = solarTermIndex(for: solarApparentLongitude(for: date))
        let bazi = calculateBazi(for: trueSolarDate, termIndex: termIndex, calendar: calendar)

        return SolarTimeResult(
            standardTimeString: formatter.string(from: date),
            trueSolarTimeString: formatter.string(from: trueSolarDate),
            timeOffsetMinutes: totalOffsetMinutes,
            equationOfTimeMinutes: equationOfTime,
            solarTermName: solarTerms[termIndex],
            baziGanzhi: bazi
        )
    }

    private func normalizedDegrees(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360.0)
        return result >= 0 ? result : result + 360.0
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

    private func solarTermIndex(for longitude: Double) -> Int {
        let shifted = normalizedDegrees(longitude - 285.0)
        return min(23, Int(floor(shifted / 15.0)))
    }

    private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        let result = value % modulus
        return result >= 0 ? result : result + modulus
    }

    private func calculateBazi(for date: Date, termIndex: Int, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let civilYear = components.year ?? 2000
        let ganzhiYear = termIndex >= 2 ? civilYear : civilYear - 1
        let yearCycle = positiveModulo(ganzhiYear - 4, 60)
        let yearStem = yearCycle % 10
        let yearBranch = yearCycle % 12

        // 立春起寅月；小寒和大寒仍属于丑月。
        let monthBranch = termIndex < 2 ? 1 : positiveModulo(2 + (termIndex - 2) / 2, 12)
        let monthStemStart = positiveModulo((yearStem % 5) * 2 + 2, 10)
        let monthStem = positiveModulo(monthStemStart + positiveModulo(monthBranch - 2, 12), 10)

        let year = components.year ?? 2000
        let month = components.month ?? 1
        let day = components.day ?? 1
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

        return "\(heavenlyStems[yearStem])\(earthlyBranches[yearBranch])年 "
            + "\(heavenlyStems[monthStem])\(earthlyBranches[monthBranch])月 "
            + "\(heavenlyStems[dayStem])\(earthlyBranches[dayBranch])日 "
            + "\(heavenlyStems[hourStem])\(earthlyBranches[hourBranch])时"
    }
}
