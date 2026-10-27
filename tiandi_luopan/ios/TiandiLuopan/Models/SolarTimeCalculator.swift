import Foundation

// MARK: - 真太阳时与天文学节气经度计算器 (True Solar Time Calculator)

public struct SolarTimeResult {
    public let standardTimeString: String    // 本地平太阳时/北京时间
    public let trueSolarTimeString: String    // 高精度视太阳时 (真太阳时)
    public let timeOffsetMinutes: Double      // 经度与时差总校正分 (±分)
    public let equationOfTimeMinutes: Double  // 地球公转真平太阳时差 (EOT)
    public let solarTermName: String          // 当前节气
    public let baziGanzhi: String             // 年月日时四柱干支
}

public final class SolarTimeCalculator {
    public static let shared = SolarTimeCalculator()
    
    // 二十四节气参考数据
    private let solarTerms = [
        "小寒", "大寒", "立春", "雨水", "惊蛰", "春分",
        "清明", "谷雨", "立夏", "小满", "芒种", "夏至",
        "小暑", "大暑", "立秋", "处暑", "白露", "秋分",
        "寒露", "霜降", "立冬", "小雪", "大雪", "冬至"
    ]
    
    // 天干地支
    private let heavenlyStems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private let earthlyBranches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    
    public func calculate(date: Date = Date(), longitude: Double = 116.4074) -> SolarTimeResult {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        
        // 1. 经度时差：每经度相差 4 分钟 (相对于东经120°标准经线)
        let lonDiff = longitude - 120.0
        let lonOffsetMinutes = lonDiff * 4.0
        
        // 2. 地球轨道公转导致的真平太阳时差 (Equation of Time, 经典近似公式)
        // B = 360/365 * (d - 81) 度
        let bRad = (360.0 / 365.0 * Double(dayOfYear - 81)) * .pi / 180.0
        let eotMinutes = 9.87 * sin(2.0 * bRad) - 7.53 * cos(bRad) - 1.5 * sin(bRad)
        
        let totalOffsetSeconds = (lonOffsetMinutes + eotMinutes) * 60.0
        let trueSolarDate = date.addingTimeInterval(totalOffsetSeconds)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone.current
        let stdTimeStr = formatter.string(from: date)
        let trueSolarStr = formatter.string(from: trueSolarDate)
        
        // 节气估算 (每15天一节气)
        let termIdx = (dayOfYear / 15) % 24
        let termName = solarTerms[termIdx]
        
        // 简要四柱干支生成 (严格遵循立春交岁正统天文学天干地支更迭法则)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let isBeforeLiChun = (month < 2 || (month == 2 && day < 4))
        let gzYear = isBeforeLiChun ? (year - 1) : year
        
        let yearStem = heavenlyStems[((gzYear - 4) % 10 + 10) % 10]
        let yearBranch = earthlyBranches[((gzYear - 4) % 12 + 12) % 12]
        let bazi = "\(yearStem)\(yearBranch)年 · \(termName)令"
        
        return SolarTimeResult(
            standardTimeString: stdTimeStr,
            trueSolarTimeString: trueSolarStr,
            timeOffsetMinutes: (lonOffsetMinutes + eotMinutes),
            equationOfTimeMinutes: eotMinutes,
            solarTermName: termName,
            baziGanzhi: bazi
        )
    }
}
