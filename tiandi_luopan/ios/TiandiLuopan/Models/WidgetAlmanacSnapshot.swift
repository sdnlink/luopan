import Foundation

// MARK: - 小组件共享数据层
// 本文件同时加入主 App 与 Widget Extension 的 Target Membership。
// 只依赖 Foundation，不引用 UIKit / UIApplication，可在扩展进程中安全运行。
// 数据来源全部是「给一个 Date 就能算」的纯函数引擎，不读取实时传感器或单例状态。

public struct WidgetAlmanacSnapshot {
    /// 该条目对应的时刻（用于 Timeline 推进，不是生成时间）
    public let date: Date
    /// 本地化后的日柱，如 "甲子" / "Jia Zi"。
    /// 与 fourPillarsText 同源于 ZeRiEngine 的本地日历口径，绝不使用真太阳时校正后的日期，
    /// 避免同一屏出现两个互相矛盾的日柱。
    public let localizedDayPillar: String
    /// 四柱干支文本（与上者同源）
    public let fourPillarsText: String
    public let yiActivities: [String]
    public let jiActivities: [String]

    /// 当前节气名（已本地化）
    public let termName: String
    /// 当前节气已走过的比例 0...1
    public let termProgress: Double
    /// 距下一节气的整天数
    public let daysToNextTerm: Int

    /// 流年 / 流月中宫星
    public let yearCentralStar: Int
    public let monthCentralStar: Int
    public let yearStarName: String
    public let monthStarName: String

    /// 建除十二神值日索引 0...11（建除满平定执破危成收开闭）。
    /// 纯历法标注，按「月建地支 + 日支相对位置」推算，每日变化，
    /// 不附加任何吉凶判断，也不改动主 App 的择日结论。
    public let dayOfficerIndex: Int

    /// 小组件使用「通用日课」：不含坐山冲克判定。
    /// 所有展示宜忌的尺寸都必须显示此说明，避免把结果误读为某一宅的坐向结论。
    public let isGeneralDay: Bool
}

public enum WidgetAlmanacBuilder {

    /// 一个节气桶为太阳视黄经 15°，按引擎采用的平均视运动 0.98564736°/天换算。
    /// 与 SolarTimeCalculator.solarTermProgress(for:) 的分母保持一致。
    private static let termLengthDays: Double = 15.0 / 0.98564736

    private static let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

    /// 建除十二神值日（传统历法标注，非吉凶判断）。
    /// 规则：以节气月建地支为「建」起点，日支依次顺行
    /// 建→除→满→平→定→执→破→危→成→收→开→闭，12 日一循环。
    /// 月建口径与 ZeRiEngine 一致（小寒大寒仍属丑月，立春起寅月）。
    /// 简化：传统通书在节气交接当日会「重复」前一日值神，此处按自然日顺行，
    /// 因此仅作历法参考标注，不用于任何择日或吉凶判断。
    private static func resolveDayOfficerIndex(for date: Date, dayPillar: String) -> Int {
        let termIndex = SolarTimeCalculator.shared.solarTermIndex(for: date)
        let monthBranchIdx = termIndex < 2 ? 1 : (2 + (termIndex - 2) / 2) % 12
        let dayBranch = String(dayPillar.suffix(1))
        guard let dayBranchIdx = branches.firstIndex(of: dayBranch) else { return 0 }
        return (dayBranchIdx - monthBranchIdx + 12) % 12
    }

    /// 为指定时刻生成快照。所有输入都来自 Date，不依赖主 App 运行状态。
    public static func make(for date: Date = Date()) -> WidgetAlmanacSnapshot {
        let solar = SolarTimeCalculator.shared

        // 通用日课：不传坐山，跳过坐山冲克，只按四柱 / 岁破 / 月破判读。
        // 日柱与四柱均由这里统一提供，口径一致。
        let dayCourse = ZeRiEngine.shared.analyzeGeneralDay(date: date)

        let purple = PurpleWhiteEngine.shared.calculateChart(date: date)
        let starEngine = PurpleWhiteEngine.shared

        let rawTermName = solar.solarTermName(for: date)
        let termName = SolarTermsData.shared.terms
            .first { $0.name == rawTermName }?.localizedName ?? rawTermName

        let elapsedDays = solar.solarTermProgress(for: date)
        let progress = min(1.0, max(0.0, elapsedDays / termLengthDays))
        let daysLeft = max(0, Int(ceil(termLengthDays - elapsedDays)))

        return WidgetAlmanacSnapshot(
            date: date,
            localizedDayPillar: dayCourse.localizedDayPillar,
            fourPillarsText: dayCourse.fourPillarsText,
            yiActivities: dayCourse.yiActivities,
            jiActivities: dayCourse.jiActivities,
            termName: termName,
            termProgress: progress,
            daysToNextTerm: daysLeft,
            yearCentralStar: purple.yearCentralStar,
            monthCentralStar: purple.monthCentralStar,
            yearStarName: starEngine.starName(for: purple.yearCentralStar),
            monthStarName: starEngine.starName(for: purple.monthCentralStar),
            dayOfficerIndex: resolveDayOfficerIndex(for: date, dayPillar: dayCourse.dayPillar),
            isGeneralDay: true
        )
    }

    /// Timeline 刷新边界：
    /// - 每日 00:00（换日柱）与 23:00（子初换日柱）；
    /// - 每 3 小时一个采样点，让节气进度环连续推进而不是一天只跳两次；
    /// - 节气交接时刻（termIndex 变化点），保证节气名、流月飞星及时切换。
    /// 返回从 now 起、按时间排序且去重的时刻。
    public static func refreshDates(from now: Date, days: Int = 3) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let startOfToday = calendar.startOfDay(for: now)

        var dates: [Date] = [now]
        guard days > 0 else { return Array(Set(dates)).sorted() }

        for hourOffset in stride(from: 0, through: days * 24, by: 3) {
            guard let point = calendar.date(byAdding: .hour, value: hourOffset, to: startOfToday),
                  point > now else { continue }
            dates.append(point)
        }
        // 23:00 子初换日柱不属于 3 小时网格，显式补齐。
        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
                  let point = calendar.date(byAdding: .hour, value: 23, to: day),
                  point > now else { continue }
            dates.append(point)
        }
        // 节气交接与流月月界都落在 termIndex 变化点，用逐小时扫描定位。
        let horizon = Date(timeInterval: TimeInterval(days * 24 + 1) * 3600, since: now)
        if let boundary = nextTermBoundary(after: now, before: horizon) {
            dates.append(boundary)
        }
        return Array(Set(dates)).sorted()
    }

    /// 用二分查找定位 [after, before] 内第一个节气桶变化的时刻（精度约 1 分钟）。
    private static func nextTermBoundary(after: Date, before: Date) -> Date? {
        let solar = SolarTimeCalculator.shared
        guard before > after else { return nil }
        let startIndex = solar.solarTermIndex(for: after)
        guard solar.solarTermIndex(for: before) != startIndex else { return nil }
        var low = after
        var high = before
        while high.timeIntervalSince(low) > 60 {
            let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if solar.solarTermIndex(for: mid) == startIndex {
                low = mid
            } else {
                high = mid
            }
        }
        return high
    }
}
