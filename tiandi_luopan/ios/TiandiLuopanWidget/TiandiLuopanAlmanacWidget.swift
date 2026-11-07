import Foundation
import WidgetKit
import SwiftUI

// MARK: - 天地罗盘小组件（单一 Widget，按尺寸分工四项内容）
//
// 设计取舍：四个模块（今日宜忌 / 节气进度 / 流年流月飞星 / 锁屏精简）
// 共用同一条 Timeline 与同一份快照，不拆成四个 Widget：
//  1. 刷新边界完全相同（00:00 换日柱、23:00 子初换日柱、节气交接、月界）；
//  2. WidgetKit 按实例计刷新预算，合并后只消耗一份；
//  3. 锁屏 accessoryInline / Circular / Rectangular 本就是同一 Widget 的尺寸变体；
//  4. 用户可多次添加同一 Widget 并选不同尺寸，无需在小组件库里放四个近似条目。

struct AlmanacEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetAlmanacSnapshot
}

struct AlmanacProvider: TimelineProvider {

    func placeholder(in context: Context) -> AlmanacEntry {
        AlmanacEntry(date: Date(), snapshot: WidgetAlmanacBuilder.make())
    }

    func getSnapshot(in context: Context, completion: @escaping (AlmanacEntry) -> Void) {
        completion(AlmanacEntry(date: Date(), snapshot: WidgetAlmanacBuilder.make()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlmanacEntry>) -> Void) {
        let now = Date()
        let dates = WidgetAlmanacBuilder.refreshDates(from: now)
        // 每个边界都用该时刻重算一次，日柱 / 宜忌 / 节气进度会随时间正确推进。
        let entries = dates.map { AlmanacEntry(date: $0, snapshot: WidgetAlmanacBuilder.make(for: $0)) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let last = entries.last?.date ?? now
        // 每日凌晨主动重取：保证系统每天唤醒一次拉最新一天的时间线，
        // 而不是等 3 天以上的长周期 Timeline 到期。
        let nextMidnight = calendar.date(byAdding: .day, value: 1,
                                         to: calendar.startOfDay(for: now)) ?? last
        // 不早于最后一个条目，避免系统提前重载造成无效刷新循环。
        let earliest = last.addingTimeInterval(60)
        let reload = max(nextMidnight, earliest)
        completion(Timeline(entries: entries, policy: .after(reload)))
    }
}

struct TiandiLuopanAlmanacWidget: Widget {
    let kind: String = "TiandiLuopanAlmanacWidget"

    var body: some WidgetConfiguration {
        let displayName: String = "天地罗盘 · \(WidgetText.dayCourse.string())"
        let summary: String = "\(WidgetText.dayCourse.string()) · \(WidgetText.term.string()) · \(WidgetText.yearStar.string())"
        return StaticConfiguration(kind: kind, provider: AlmanacProvider()) { entry in
            AlmanacWidgetRootView(entry: entry)
        }
        .configurationDisplayName(displayName)
        .description(summary)
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}

@main
struct TiandiLuopanWidgets: WidgetBundle {
    var body: some Widget {
        TiandiLuopanAlmanacWidget()
    }
}
