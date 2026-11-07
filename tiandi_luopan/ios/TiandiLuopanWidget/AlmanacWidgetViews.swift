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
        // accessoryInline 只接受单行文字，直接给最短可用文案，避免被系统截断。
        Text("\(s.termName) · \(s.localizedDayPillar) · \(WidgetText.dayOfficerName(at: s.dayOfficerIndex))")
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

// MARK: - 锁屏：矩形（日柱 + 宜忌 + 通用日课标记）

private struct RectangularView: View {
    let s: WidgetAlmanacSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(s.localizedDayPillar)
                    .font(.system(size: 13, weight: .bold))
                Text(s.termName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(WidgetText.dayOfficerName(at: s.dayOfficerIndex))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                if s.isGeneralDay {
                    Text(WidgetText.generalShort.string())
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text("\(WidgetText.yi.string()) \(joined(s.yiActivities))")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(WidgetText.ji.string()) \(joined(s.jiActivities))")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 小尺寸：今日日课（宜/忌 + 节气进度环）
// 组件对外名称是「今日日课」，最常用的 Small 必须能看到宜忌，
// 否则用户冲着日课添加却只看到节气环。

private struct SmallView: View {
    let s: WidgetAlmanacSnapshot
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(WidgetText.dayCourse.string())
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Palette.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text(s.localizedDayPillar)
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(Palette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            ZStack {
                Circle().stroke(Palette.gold.opacity(0.18), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: max(0.02, min(1.0, s.termProgress)))
                    .stroke(Palette.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(s.termShortName)
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundColor(Palette.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(Int(s.termProgress * 100))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Palette.dim)
                }
            }
            .frame(maxHeight: .infinity)

            // 核心宜 / 忌各取首项，两列并排，契合「今日日课」的命名预期。
            HStack(spacing: 4) {
                Text("\(WidgetText.yi.string()) \(s.yiActivities.first ?? "-")")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Palette.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(WidgetText.ji.string()) \(s.jiActivities.first ?? "-")")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Palette.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 通用日课标注：小尺寸含宜忌，必须一并说明「未含坐山冲克」。
            HStack(spacing: 3) {
                if s.isGeneralDay {
                    Text(WidgetText.generalShort.string())
                        .font(.system(size: 8))
                        .foregroundColor(Palette.dim)
                }
                Spacer(minLength: 0)
                Text("\(WidgetText.dayOfficer.string()) \(WidgetText.dayOfficerName(at: s.dayOfficerIndex))")
                    .font(.system(size: 8))
                    .foregroundColor(Palette.cyan)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }
}

// MARK: - 中尺寸：今日宜忌 + 节气环 + 流年流月

private struct MediumView: View {
    let s: WidgetAlmanacSnapshot
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(WidgetText.dayCourse.string())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Palette.dim)
                    if s.isGeneralDay {
                        Text("· \(WidgetText.generalShort.string())")
                            .font(.system(size: 9))
                            .foregroundColor(Palette.dim)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Text(s.localizedDayPillar)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundColor(Palette.gold)
                Text("\(WidgetText.dayOfficer.string()) \(WidgetText.dayOfficerName(at: s.dayOfficerIndex))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Palette.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 3) {
                    LabelLine(title: WidgetText.yi.string(), value: joined(s.yiActivities), color: Palette.yellow)
                    LabelLine(title: WidgetText.ji.string(), value: joined(s.jiActivities), color: Palette.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(Palette.gold.opacity(0.25))

            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(Palette.gold.opacity(0.18), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: max(0.02, min(1.0, s.termProgress)))
                        .stroke(Palette.gold, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(s.termName)
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundColor(Palette.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(width: 66, height: 66)

                StarRow(title: WidgetText.yearStar.string(), star: s.yearCentralStar, name: s.yearStarName)
                StarRow(title: WidgetText.monthStar.string(), star: s.monthCentralStar, name: s.monthStarName)
            }
            .frame(width: 100)
        }
    }
}

// MARK: - 大尺寸：四项全展示

private struct LargeView: View {
    let s: WidgetAlmanacSnapshot
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(WidgetText.dayCourse.string())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Palette.dim)
                    Text(s.localizedDayPillar)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(Palette.gold)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(WidgetText.dayOfficer.string())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Palette.dim)
                    Text(WidgetText.dayOfficerName(at: s.dayOfficerIndex))
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(Palette.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.leading, 10)
                Spacer()
                Text(s.fourPillarsText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Palette.dim)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    LabelLine(title: WidgetText.yi.string(), value: joined(s.yiActivities, limit: 4), color: Palette.yellow)
                    LabelLine(title: WidgetText.ji.string(), value: joined(s.jiActivities, limit: 4), color: Palette.red)
                    if s.isGeneralDay {
                        Text(WidgetText.generalShort.string())
                            .font(.system(size: 9))
                            .foregroundColor(Palette.dim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Palette.card)
                .cornerRadius(8)

                VStack(spacing: 4) {
                    ZStack {
                        Circle().stroke(Palette.gold.opacity(0.18), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: max(0.02, min(1.0, s.termProgress)))
                            .stroke(Palette.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text(s.termName)
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .foregroundColor(Palette.yellow)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text("\(Int(s.termProgress * 100))%")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Palette.dim)
                        }
                    }
                    .frame(width: 76, height: 76)
                    Text(String(format: WidgetText.daysToNext.string(), s.daysToNextTerm))
                        .font(.system(size: 9))
                        .foregroundColor(Palette.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 110)
            }

            HStack(spacing: 10) {
                StarCard(title: WidgetText.yearStar.string(), star: s.yearCentralStar, name: s.yearStarName)
                StarCard(title: WidgetText.monthStar.string(), star: s.monthCentralStar, name: s.monthStarName)
            }

            if s.isGeneralDay {
                Text(WidgetText.generalNote.string())
                    .font(.system(size: 9))
                    .foregroundColor(Palette.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - 复用小组件

private struct LabelLine: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .fixedSize(horizontal: true, vertical: false)
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(Palette.dim)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct StarRow: View {
    let title: String
    let star: Int
    let name: String
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(Palette.dim)
            Spacer(minLength: 0)
            Text("\(star)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Palette.cyan)
        }
        .lineLimit(1)
        .accessibilityLabel("\(title) \(star) \(name)")
    }
}

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
