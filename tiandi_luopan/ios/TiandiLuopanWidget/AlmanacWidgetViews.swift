import Foundation
import SwiftUI
import WidgetKit

// MARK: - 小组件配色（与 App 罗盘黑底金字保持一致）

private enum Palette {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.10)
    static let card = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let gold = Color(red: 0.95, green: 0.82, blue: 0.40)
    static let yellow = Color(red: 0.96, green: 0.85, blue: 0.45)
    static let red = Color(red: 0.96, green: 0.35, blue: 0.30)
    static let cyan = Color(red: 0.31, green: 0.82, blue: 0.77)
    static let dim = Color.white.opacity(0.68)
}

// MARK: - 轻量文案（仅小组件用到的短词，不引入主 App 的全量字典）
// 语言与各引擎共用 LocalizationManager.effectiveLanguage，避免混语与地区映射差异。

enum WidgetText {
    case yi, ji, term, yearStar, monthStar, daysToNext, generalNote, generalShort, dayCourse, dayOfficer

    /// 建除十二神值日名称（传统历法标注，非吉凶判断）。
    /// 汉字文化圈沿用原字，其它语种给出对应通行译名。
    static func dayOfficerName(at index: Int) -> String {
        let clamped = min(11, max(0, index))
        switch lang {
        case .zhHans, .zhHant, .ja:
            return ["建", "除", "满", "平", "定", "执", "破", "危", "成", "收", "开", "闭"][clamped]
        case .ko:
            return ["건", "제", "만", "평", "정", "집", "파", "위", "성", "수", "개", "폐"][clamped]
        case .vi:
            return ["Kiến", "Trừ", "Mãn", "Bình", "Định", "Chấp", "Phá", "Nguy", "Thành", "Thu", "Khai", "Bế"][clamped]
        case .th:
            return ["สร้าง", "ขจัด", "เต็ม", "ราบ", "ตั้ง", "ถือ", "ทำลาย", "อันตราย", "สำเร็จ", "เก็บ", "เปิด", "ปิด"][clamped]
        case .id:
            return ["Bangun", "Hapus", "Penuh", "Rata", "Tetap", "Pegang", "Rusak", "Bahaya", "Jadi", "Kumpul", "Buka", "Tutup"][clamped]
        case .en:
            return ["Establish", "Remove", "Full", "Level", "Settle", "Hold", "Break", "Risk", "Complete", "Gather", "Open", "Close"][clamped]
        }
    }

    private enum Lang: String {
        case zhHans, zhHant, en, th, vi, id, ja, ko
    }

    private static var lang: Lang {
        switch LocalizationManager.shared.effectiveLanguage {
        case .zhHans: return .zhHans
        case .zhHant: return .zhHant
        case .en: return .en
        case .th: return .th
        case .vi: return .vi
        case .id: return .id
        case .ja: return .ja
        case .ko: return .ko
        case .auto: return .zhHans
        }
    }

    func string() -> String {
        switch (self, Self.lang) {
        case (.yi, .zhHans): return "宜"
        case (.yi, .zhHant): return "宜"
        case (.yi, .en): return "Good"
        case (.yi, .ja): return "吉"
        case (.yi, .ko): return "길"
        case (.yi, .vi): return "Nên"
        case (.yi, .th): return "ควร"
        case (.yi, .id): return "Baik"

        case (.ji, .zhHans): return "忌"
        case (.ji, .zhHant): return "忌"
        case (.ji, .en): return "Avoid"
        case (.ji, .ja): return "忌"
        case (.ji, .ko): return "흉"
        case (.ji, .vi): return "Kỵ"
        case (.ji, .th): return "ควรหลีก"
        case (.ji, .id): return "Hindari"

        case (.term, .zhHans): return "节气"
        case (.term, .zhHant): return "節氣"
        case (.term, .en): return "Solar Term"
        case (.term, .ja): return "節気"
        case (.term, .ko): return "절기"
        case (.term, .vi): return "Tiết khí"
        case (.term, .th): return "ฤดูกาล"
        case (.term, .id): return "Musim"

        case (.yearStar, .zhHans): return "流年"
        case (.yearStar, .zhHant): return "流年"
        case (.yearStar, .en): return "Year"
        case (.yearStar, .ja): return "流年"
        case (.yearStar, .ko): return "유년"
        case (.yearStar, .vi): return "Lưu niên"
        case (.yearStar, .th): return "ปี"
        case (.yearStar, .id): return "Tahun"

        case (.monthStar, .zhHans): return "流月"
        case (.monthStar, .zhHant): return "流月"
        case (.monthStar, .en): return "Month"
        case (.monthStar, .ja): return "流月"
        case (.monthStar, .ko): return "유월"
        case (.monthStar, .vi): return "Lưu nguyệt"
        case (.monthStar, .th): return "เดือน"
        case (.monthStar, .id): return "Bulan"

        case (.daysToNext, .zhHans): return "距下一节气 %ld 天"
        case (.daysToNext, .zhHant): return "距下一節氣 %ld 天"
        case (.daysToNext, .en): return "%ld days to next term"
        case (.daysToNext, .ja): return "次の節気まで %ld 日"
        case (.daysToNext, .ko): return "다음 절기까지 %ld일"
        case (.daysToNext, .vi): return "Còn %ld ngày đến tiết sau"
        case (.daysToNext, .th): return "อีก %ld วันถึงฤดูกาลถัดไป"
        case (.daysToNext, .id): return "%ld hari ke musim berikut"

        case (.generalNote, .zhHans): return "通用日课 · 未含坐山冲克"
        case (.generalNote, .zhHant): return "通用日課 · 未含坐山沖剋"
        case (.generalNote, .en): return "General reading · no sitting-mountain check"
        case (.generalNote, .ja): return "通用日課 · 坐山の衝は未判定"
        case (.generalNote, .ko): return "일반 일과 · 좌산 충 미적용"
        case (.generalNote, .vi): return "Nhật khóa chung · chưa xét xung tọa sơn"
        case (.generalNote, .th): return "ฤกษ์ทั่วไป · ไม่ได้ตรวจทิศพิง"
        case (.generalNote, .id): return "Hari umum · tanpa cek gunung sandaran"

        case (.generalShort, .zhHans): return "通用日课"
        case (.generalShort, .zhHant): return "通用日課"
        case (.generalShort, .en): return "General"
        case (.generalShort, .ja): return "汎用"
        case (.generalShort, .ko): return "일반"
        case (.generalShort, .vi): return "Chung"
        case (.generalShort, .th): return "ทั่วไป"
        case (.generalShort, .id): return "Umum"

        case (.dayCourse, .zhHans): return "今日日课"
        case (.dayCourse, .zhHant): return "今日日課"
        case (.dayCourse, .en): return "Today's Almanac"
        case (.dayCourse, .ja): return "本日の日課"
        case (.dayCourse, .ko): return "오늘 일과"
        case (.dayCourse, .vi): return "Nhật khóa hôm nay"
        case (.dayCourse, .th): return "ฤกษ์วันนี้"
        case (.dayCourse, .id): return "Almanak Hari Ini"

        case (.dayOfficer, .zhHans): return "值日"
        case (.dayOfficer, .zhHant): return "值日"
        case (.dayOfficer, .en): return "Day Officer"
        case (.dayOfficer, .ja): return "十二直"
        case (.dayOfficer, .ko): return "십이직"
        case (.dayOfficer, .vi): return "Trực ngày"
        case (.dayOfficer, .th): return "ประจำวัน"
        case (.dayOfficer, .id): return "Harian"
        }
    }
}

// MARK: - 背景与边距：iOS 17 引入系统 widgetContentMargins（约 16pt），
// 若视图内部再叠加 .padding(12)，小尺寸可用区会被压到约 100pt。
// 这里按系统版本收敛内边距，避免在 WidgetConfiguration 上调用
// iOS 17 才有的 .contentMarginsDisabled()（部署目标 16.0，opaque 返回类型受限）。

private struct WidgetBackground: ViewModifier {
    let isAccessory: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isAccessory {
            // accessoryInline / Circular / Rectangular 由系统提供单色与 vibrancy，
            // 自定义深色底和金/红/青会破坏锁屏可读性。
            content
        } else if #available(iOS 17.0, *) {
            content.containerBackground(for: .widget) { Palette.background }
        } else {
            content.background(Palette.background)
        }
    }
}

/// 主屏尺寸的内容留白：iOS 17 起系统已提供 contentMargins，内部只留极小间距。
/// 锁屏 accessory 由系统控制排版，绝不能叠加内边距（圆形直径仅 40~48pt）。
private struct ContentInset: ViewModifier {
    let isAccessory: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isAccessory {
            content
        } else if #available(iOS 17.0, *) {
            content.padding(2)
        } else {
            content.padding(12)
        }
    }
}

// MARK: - 根视图：按尺寸分工

struct AlmanacWidgetRootView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AlmanacEntry

    private var isAccessory: Bool {
        switch family {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular: return true
        default: return false
        }
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                InlineView(s: entry.snapshot)
            case .accessoryCircular:
                CircularView(s: entry.snapshot)
            case .accessoryRectangular:
                RectangularView(s: entry.snapshot)
            case .systemSmall:
                SmallView(s: entry.snapshot)
            case .systemMedium:
                MediumView(s: entry.snapshot)
            case .systemLarge:
                LargeView(s: entry.snapshot)
            default:
                SmallView(s: entry.snapshot)
            }
        }
        .modifier(ContentInset(isAccessory: isAccessory))
        .modifier(WidgetBackground(isAccessory: isAccessory))
        .widgetURL(URL(string: "tiandiluopan://almanac"))
    }
}

// MARK: - 锁屏：一行文字（缩短以适配单行，附通用日课标记）

private struct InlineView: View {
    let s: WidgetAlmanacSnapshot
    var body: some View {
        // accessoryInline 只接受单行文字，优先采用 termShortName 避免英文长节气名在锁屏单行截断。
        Text("\(s.termShortName) · \(s.localizedDayPillar) · \(WidgetText.dayOfficerName(at: s.dayOfficerIndex))")
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - 锁屏：节气进度环

private struct CircularView: View {
    let s: WidgetAlmanacSnapshot
    var body: some View {
        // 系统 Gauge 会按锁屏 vibrancy 与可用直径自动排布，
        // 避免自绘圆环内塞两行长文本（英文节气名可达 20 字符）被强截。
        Gauge(value: min(1.0, max(0.0, s.termProgress)), in: 0...1) {
            Text(s.termShortName)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        } currentValueLabel: {
            Text("\(Int(s.termProgress * 100))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
        .accessibilityLabel("\(s.termName) \(Int(s.termProgress * 100))%")
    }
}

// MARK: - 锁屏：矩形（日柱 + 节气 + 值神，核心宜忌）

private struct RectangularView: View {
    let s: WidgetAlmanacSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(s.localizedDayPillar)
                    .font(.system(size: 13, weight: .bold))
                Text("·")
                    .foregroundStyle(.secondary)
                Text(s.termShortName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(WidgetText.dayOfficerName(at: s.dayOfficerIndex))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text("\(WidgetText.yi.string()) \(joined(s.yiActivities, limit: 2))")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(WidgetText.ji.string()) \(joined(s.jiActivities, limit: 2))")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 小尺寸：极简日课（日柱大字 + 值神胶囊 + 节气环 + 核心宜忌）

private struct SmallView: View {
    let s: WidgetAlmanacSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 顶栏：日柱大字 + 值神高亮胶囊 + 节气短名
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(s.localizedDayPillar)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(Palette.gold)

                Text(WidgetText.dayOfficerName(at: s.dayOfficerIndex))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Palette.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Palette.cyan.opacity(0.16))
                    .cornerRadius(4)

                Spacer(minLength: 0)

                Text(s.termShortName)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundColor(Palette.yellow)
                    .lineLimit(1)
            }

            // 中间：节气进度环（舒展大方，数字清晰）
            ZStack {
                Circle()
                    .stroke(Palette.gold.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: max(0.02, min(1.0, s.termProgress)))
                    .stroke(Palette.gold, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(s.termProgress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.gold.opacity(0.9))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 底栏：精炼宜忌（鲜明标识，去除冗长堆叠文字）
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(WidgetText.yi.string())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Palette.yellow)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Palette.yellow.opacity(0.18))
                        .cornerRadius(3)
                    Text(s.yiActivities.first ?? "-")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Palette.yellow)
                        .lineLimit(1)
                }

                HStack(spacing: 5) {
                    Text(WidgetText.ji.string())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Palette.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Palette.red.opacity(0.18))
                        .cornerRadius(3)
                    Text(s.jiActivities.first ?? "-")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Palette.dim)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - 中尺寸：核心日课宜忌 + 节气环 + 飞星胶囊

private struct MediumView: View {
    let s: WidgetAlmanacSnapshot

    var body: some View {
        HStack(spacing: 12) {
            // 左半区：日柱大字与双列精炼宜忌
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(s.localizedDayPillar)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(Palette.gold)

                    Text(WidgetText.dayOfficerName(at: s.dayOfficerIndex))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Palette.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Palette.cyan.opacity(0.16))
                        .cornerRadius(4)

                    if let badge = s.sittingMountainBadge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(s.hasSittingClash ? Palette.red : Palette.gold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background((s.hasSittingClash ? Palette.red : Palette.gold).opacity(0.16))
                            .cornerRadius(4)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(WidgetText.yi.string())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Palette.yellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Palette.yellow.opacity(0.18))
                            .cornerRadius(3)
                        Text(joined(s.yiActivities, limit: 2))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Palette.yellow)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        Text(WidgetText.ji.string())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Palette.red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Palette.red.opacity(0.18))
                            .cornerRadius(3)
                        Text(joined(s.jiActivities, limit: 2))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Palette.dim)
                            .lineLimit(1)
                    }

                    Link(destination: URL(string: "tiandiluopan://compass?guide=dailyGods")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.north.circle.fill")
                                .font(.system(size: 9))
                            Text(s.wealthJoyBadge)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundColor(Palette.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Palette.cyan.opacity(0.14))
                        .cornerRadius(4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(Palette.gold.opacity(0.2))

            // 右半区：节气进度环与流年月星胶囊
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Palette.gold.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: max(0.02, min(1.0, s.termProgress)))
                        .stroke(Palette.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text(s.termShortName)
                            .font(.system(size: 12, weight: .bold, design: .serif))
                            .foregroundColor(Palette.yellow)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text("\(Int(s.termProgress * 100))%")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Palette.dim)
                    }
                }
                .frame(width: 58, height: 58)

                HStack(spacing: 5) {
                    HStack(spacing: 2) {
                        Text(WidgetText.yearStar.string())
                            .font(.system(size: 9))
                            .foregroundColor(Palette.dim)
                        Text("\(s.yearCentralStar)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.cyan)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Palette.card)
                    .cornerRadius(4)

                    HStack(spacing: 2) {
                        Text(WidgetText.monthStar.string())
                            .font(.system(size: 9))
                            .foregroundColor(Palette.dim)
                        Text("\(s.monthCentralStar)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Palette.cyan)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Palette.card)
                    .cornerRadius(4)
                }
            }
            .frame(width: 105)
        }
    }
}

// MARK: - 大尺寸：四柱微胶囊 + 核心宜忌 + 节气盘 + 紫白飞星

private struct LargeView: View {
    let s: WidgetAlmanacSnapshot

    private var pillarCapsules: [String] {
        let text = s.fourPillarsText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains(" · ") {
            return text.components(separatedBy: " · ")
        } else if text.contains(" ") {
            return text.components(separatedBy: " ")
        } else {
            return [text]
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // 顶栏：日柱大字 + 值神胶囊 + 四柱微胶囊排列
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(s.localizedDayPillar)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(Palette.gold)

                    Text(WidgetText.dayOfficerName(at: s.dayOfficerIndex))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Palette.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Palette.cyan.opacity(0.16))
                        .cornerRadius(4)

                    if let badge = s.sittingMountainBadge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(s.hasSittingClash ? Palette.red : Palette.gold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background((s.hasSittingClash ? Palette.red : Palette.gold).opacity(0.16))
                            .cornerRadius(4)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    ForEach(Array(pillarCapsules.enumerated()), id: \.offset) { _, pillar in
                        Text(pillar)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Palette.dim)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Palette.card)
                            .cornerRadius(4)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }

            // 中栏：左侧宜忌卡 + 右侧节气盘
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(WidgetText.yi.string())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Palette.yellow)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Palette.yellow.opacity(0.18))
                            .cornerRadius(4)
                        Text(joined(s.yiActivities, limit: 3))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Palette.yellow)
                            .lineLimit(2)
                    }

                    Divider().background(Palette.gold.opacity(0.15))

                    HStack(alignment: .top, spacing: 6) {
                        Text(WidgetText.ji.string())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Palette.red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Palette.red.opacity(0.18))
                            .cornerRadius(4)
                        Text(joined(s.jiActivities, limit: 3))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Palette.dim)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Palette.card)
                .cornerRadius(10)

                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Palette.gold.opacity(0.15), lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: max(0.02, min(1.0, s.termProgress)))
                            .stroke(Palette.gold, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 1) {
                            Text(s.termShortName)
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .foregroundColor(Palette.yellow)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                            Text("\(Int(s.termProgress * 100))%")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Palette.dim)
                        }
                    }
                    .frame(width: 70, height: 70)

                    Text(String(format: WidgetText.daysToNext.string(), s.daysToNextTerm))
                        .font(.system(size: 9))
                        .foregroundColor(Palette.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 100)
            }

            // 底栏：流年与流月中宫客星 + 今日财神喜神吉方直达胶囊
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    StarCard(title: WidgetText.yearStar.string(), star: s.yearCentralStar, name: s.yearStarName)
                    StarCard(title: WidgetText.monthStar.string(), star: s.monthCentralStar, name: s.monthStarName)
                }
                Link(destination: URL(string: "tiandiluopan://compass?guide=dailyGods")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "location.north.circle.fill")
                            .font(.system(size: 10))
                        Text(s.wealthJoyBadge)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Palette.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Palette.card)
                    .cornerRadius(6)
                }
            }
        }
    }
}

// MARK: - 复用小组件

private struct StarCard: View {
    let title: String
    let star: Int
    let name: String
    var body: some View {
        HStack(spacing: 6) {
            Text("\(star)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(Palette.cyan)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundColor(Palette.dim)
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Palette.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Palette.card)
        .cornerRadius(8)
    }
}

private func joined(_ values: [String], limit: Int = 2) -> String {
    let picked = values.prefix(limit)
    return picked.isEmpty ? "-" : picked.joined(separator: " · ")
}
