import SwiftUI
import UIKit

struct ResidentialPlanningView: View {
    let layout: SavedFloorplanLayout
    let title: String
    private let metrics: ResidentialPlanMetrics
    private let onSave: ((ResidentialEstimateSettings, ResidentialEstimateSettings?) throws -> Bool)?
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var settings: ResidentialEstimateSettings
    @State private var baseline: ResidentialEstimateSettings
    @State private var persistedSettings: ResidentialEstimateSettings?
    @State private var confirmClose = false
    @State private var saved = false
    @State private var share: ResidentialShareItem?
    @State private var error: String?

    init(layout: SavedFloorplanLayout, title: String,
         onSave: ((ResidentialEstimateSettings, ResidentialEstimateSettings?) throws -> Bool)? = nil) {
        self.layout = layout; self.title = title
        self.onSave = onSave
        let metrics = ResidentialPlanMetrics(layout: layout)
        self.metrics = metrics
        let settings = layout.estimateSettings ?? ResidentialEstimateSettings(selectedRoomIDs: metrics.rooms.map(\.id).sorted())
        _settings = State(initialValue: settings)
        _baseline = State(initialValue: settings)
        _persistedSettings = State(initialValue: layout.estimateSettings)
    }
    private var hasUnsavedChanges: Bool { settings != baseline }
    private var selected: Set<String> { Set(settings.selectedRoomIDs) }
    private var estimate: ResidentialMaterialEstimate? { settings.estimate(metrics: metrics) }
    var body: some View {
        NavigationView {
            Form {
                Section(lang.t("plan_summary")) {
                    Text(title).font(.headline)
                    metric("plan_area", value: metrics.totalArea, unit: "m²")
                    metric("plan_perimeter", value: metrics.totalPerimeter, unit: "m")
                    Text(lang.t("plan_area_note")).font(.footnote).foregroundColor(.secondary)
                    if !metrics.canEstimate { Text(lang.t("plan_fix_geometry")).foregroundColor(.orange) }
                }
                Section(lang.t("plan_rooms")) {
                    if metrics.rooms.isEmpty { Text(lang.t("plan_no_rooms")) }
                    ForEach(metrics.rooms) { room in
                        Toggle(isOn: Binding(get: { selected.contains(room.id) }, set: { enabled in
                            var ids = selected
                            if enabled { ids.insert(room.id) } else { ids.remove(room.id) }
                            settings.selectedRoomIDs = ids.sorted()
                        })) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(room.name)
                                Text(String(format: "%.2f m² · %.2f m", room.area, room.perimeter)).font(.caption).foregroundColor(.secondary)
                                if metrics.overlappingRoomIDs.contains(room.id) {
                                    Text(lang.t("plan_overlap")).font(.caption).foregroundColor(.orange)
                                }
                            }
                        }
                    }
                    if metrics.invalidRoomCount > 0 {
                        Text(String(format: lang.t("plan_invalid_count"), metrics.invalidRoomCount)).foregroundColor(.orange)
                    }
                    if metrics.outsideRoomCount > 0 {
                        Text(String(format: lang.t("plan_outside_count"), metrics.outsideRoomCount)).foregroundColor(.orange)
                    }
                }
                Section(lang.t("plan_materials")) {
                    numericField("plan_wall_height", value: $settings.wallHeight, unit: "m")
                    numericField("plan_openings", value: $settings.openingArea, unit: "m²")
                    numericField("plan_pack_coverage", value: $settings.packCoverage, unit: "m²")
                    numericField("plan_paint_coverage", value: $settings.paintCoverage, unit: "m²/L")
                    Stepper(String(format: lang.t("plan_coats"), settings.coats), value: $settings.coats, in: 1...5)
                    Text(lang.t("plan_waste") + String(format: " %.0f%%", settings.waste))
                    Slider(value: $settings.waste, in: 0...50, step: 1)
                    Text(lang.t("plan_material_note")).font(.footnote).foregroundColor(.secondary)
                    if let estimate {
                        metric("plan_floor_order", value: estimate.flooringArea, unit: "m²")
                        HStack { Text(lang.t("plan_packs")); Spacer(); Text("\(estimate.flooringPacks)").monospacedDigit() }
                        metric("plan_paint_area", value: estimate.paintArea, unit: "m²")
                        metric("plan_paint_litres", value: estimate.paintLitres, unit: "L")
                    } else {
                        Text(lang.t("plan_estimate_unavailable")).font(.footnote).foregroundColor(.orange)
                    }
                }
                Section {
                    if onSave != nil {
                        Button(lang.t("plan_save_settings")) { _ = saveSettings() }
                            .disabled(!settings.isValid || (!hasUnsavedChanges && persistedSettings != nil))
                        if saved && !hasUnsavedChanges { Text(lang.t("res_saved")).foregroundColor(.secondary) }
                    }
                    Button { exportPDF() } label: { Label(lang.t("plan_pdf"), systemImage: "doc.richtext") }
                        .disabled(metrics.rooms.isEmpty)
                    Button { exportCSV() } label: { Label(lang.t("plan_csv"), systemImage: "tablecells") }
                        .disabled(metrics.rooms.isEmpty)
                    Text(lang.t("plan_csv_note")).font(.footnote).foregroundColor(.secondary)
                    Text(lang.t("plan_pdf_note")).font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle(lang.t("plan_tools"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button(lang.t("done")) {
                    if onSave != nil && hasUnsavedChanges { confirmClose = true } else { dismiss() }
                }
            } }
            .interactiveDismissDisabled(onSave != nil && hasUnsavedChanges)
            .confirmationDialog(lang.t("plan_unsaved_settings"), isPresented: $confirmClose, titleVisibility: .visible) {
                Button(lang.t("plan_save_close")) { if saveSettings() { dismiss() } }
                    .disabled(!settings.isValid)
                Button(lang.t("plan_discard_settings"), role: .destructive) { dismiss() }
            }
            .sheet(item: $share) { ResidentialShareSheet(items: $0.items) }
            .alert(lang.t("res_export"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button(lang.t("done"), role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }.navigationViewStyle(.stack)
    }
    private func metric(_ key: String, value: Double, unit: String) -> some View {
        HStack { Text(lang.t(key)); Spacer(); Text(String(format: "%.2f %@", value, unit)).monospacedDigit() }
    }
    private func saveSettings() -> Bool {
        guard settings.isValid, let onSave else { return false }
        do {
            guard try onSave(settings, persistedSettings) else { error = lang.t("res_conflict"); return false }
            persistedSettings = settings; baseline = settings; saved = true
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    private func numericField(_ key: String, value: Binding<String>, unit: String) -> some View {
        HStack {
            Text(lang.t(key))
            Spacer()
            TextField(lang.t(key), text: value)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
            Text(unit).foregroundColor(.secondary)
        }
    }
    private var parameters: [String] {
        [lang.t("plan_wall_height") + ": " + settings.wallHeight + " m",
         lang.t("plan_openings") + ": " + settings.openingArea + " m²",
         lang.t("plan_pack_coverage") + ": " + settings.packCoverage + " m²",
         lang.t("plan_paint_coverage") + ": " + settings.paintCoverage + " m²/L",
         String(format: lang.t("plan_coats"), settings.coats), lang.t("plan_waste") + String(format: ": %.0f%%", settings.waste)]
    }
    private func exportCSV() {
        do {
            let url = try ResidentialCSVReport.write(title: title, metrics: metrics, settings: settings, parameters: parameters)
            share = ResidentialShareItem(items: [url])
        } catch { self.error = error.localizedDescription }
    }
    private func exportPDF() {
        do {
            let url = try ResidentialPDFReport.write(layout: layout, title: title, metrics: metrics,
                selectedIDs: selected, estimate: estimate, parameters: parameters)
            share = ResidentialShareItem(items: [url])
        } catch { self.error = error.localizedDescription }
    }
}

enum ResidentialCSVReport {
    enum Cell {
        case text(String)
        case number(Double)
        var content: String {
            switch self {
            case .text(let value):
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                // A user-entered room title must remain text in spreadsheet apps.
                if let first = trimmed.first, "=+-@".contains(first) { return "'" + value }
                return value
            case .number(let value):
                return value.isFinite ? String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), value) : ""
            }
        }
    }
    static func encode(_ rows: [[Cell]]) -> Data {
        let text = rows.map { row in
            row.map { "\"" + $0.content.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",")
        }.joined(separator: "\r\n")
        return Data(("\u{FEFF}" + text + "\r\n").utf8)
    }
    static func write(title: String, metrics: ResidentialPlanMetrics,
                      settings: ResidentialEstimateSettings, parameters: [String]) throws -> URL {
        let lang = LocalizationManager.shared
        let selected = Set(settings.selectedRoomIDs)
        var rows: [[Cell]] = [[.text(lang.t("plan_report_title")), .text(title)],
            [.text(lang.t("res_measurement_note"))], [.text(lang.t("plan_area_note"))], [],
            [.text(lang.t("res_room_name")), .text(lang.t("res_room_type")), .text(lang.t("plan_area") + " (m²)"),
             .text(lang.t("plan_perimeter") + " (m)"), .text(lang.t("plan_csv_selected"))]]
        for room in metrics.rooms {
            rows.append([.text(room.name), .text(room.type.localizedName), .number(room.area), .number(room.perimeter),
                         .number(selected.contains(room.id) ? 1 : 0)])
        }
        rows.append([])
        rows.append([.text(lang.t("plan_area")), .number(metrics.totalArea), .text("m²")])
        rows.append([.text(lang.t("plan_perimeter")), .number(metrics.totalPerimeter), .text("m")])
        if !metrics.canEstimate { rows.append([.text(lang.t("plan_fix_geometry"))]) }
        if let estimate = settings.estimate(metrics: metrics) {
            rows.append([]); rows.append([.text(lang.t("plan_materials"))])
            for parameter in parameters { rows.append([.text(parameter)]) }
            rows.append([.text(lang.t("plan_floor_order")), .number(estimate.flooringArea), .text("m²")])
            rows.append([.text(lang.t("plan_packs")), .number(Double(estimate.flooringPacks))])
            rows.append([.text(lang.t("plan_paint_area")), .number(estimate.paintArea), .text("m²")])
            rows.append([.text(lang.t("plan_paint_litres")), .number(estimate.paintLitres), .text("L")])
            rows.append([.text(lang.t("plan_material_note"))])
        } else { rows.append([.text(lang.t("plan_estimate_unavailable"))]) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("space-materials-\(UUID().uuidString).csv")
        try encode(rows).write(to: url, options: .atomic)
        return url
    }
}

struct ResidentialComparisonView: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var cases = FloorplanCaseStore.shared
    @State private var firstID: String
    @State private var secondID: String

    init(records: [FloorplanCaseRecord]) {
        _firstID = State(initialValue: records.first?.id ?? "")
        _secondID = State(initialValue: records.dropFirst().first?.id ?? "")
    }
    private var first: FloorplanCaseRecord? { cases.records.first { $0.id == firstID } }
    private var second: FloorplanCaseRecord? { cases.records.first { $0.id == secondID } }
    var body: some View {
        Form {
            Section {
                Picker(lang.t("plan_option_a"), selection: $firstID) {
                    ForEach(cases.records) { Text($0.title).tag($0.id) }
                }
                Picker(lang.t("plan_option_b"), selection: $secondID) {
                    ForEach(cases.records) { Text($0.title).tag($0.id) }
                }
            }
            if let first, let second, firstID != secondID {
                let a = ResidentialPlanMetrics(layout: first.layout), b = ResidentialPlanMetrics(layout: second.layout)
                if a.canEstimate && b.canEstimate {
                    Section(lang.t("plan_compare")) {
                        comparisonRow("plan_area", a: a.totalArea, b: b.totalArea, unit: "m²")
                        comparisonRow("plan_perimeter", a: a.totalPerimeter, b: b.totalPerimeter, unit: "m")
                        comparisonRow("plan_room_count", a: Double(a.rooms.count), b: Double(b.rooms.count), unit: "")
                        comparisonRow("plan_bedrooms", a: Double(bedrooms(a)), b: Double(bedrooms(b)), unit: "")
                        comparisonRow("plan_wet_area", a: wetArea(a), b: wetArea(b), unit: "m²")
                        Text(lang.t("plan_difference_note")).font(.footnote).foregroundColor(.secondary)
                    }
                } else { Section { Text(lang.t("plan_fix_geometry")).foregroundColor(.orange) } }
                Section { Text(lang.t("plan_area_note")).font(.footnote).foregroundColor(.secondary) }
            } else { Section { Text(lang.t("plan_choose_two")) } }
        }
        .navigationTitle(lang.t("plan_compare"))
    }
    private func bedrooms(_ metrics: ResidentialPlanMetrics) -> Int {
        metrics.rooms.filter { $0.type == .masterBedroom || $0.type == .secondBedroom }.count
    }
    private func wetArea(_ metrics: ResidentialPlanMetrics) -> Double {
        metrics.rooms.filter { $0.type == .kitchen || $0.type == .bathroom }.reduce(0) { $0 + $1.area }
    }
    private func comparisonRow(_ key: String, a: Double, b: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t(key)).font(.headline)
            HStack {
                Text(String(format: "A  %.2f %@", a, unit))
                Spacer()
                Text(String(format: "B  %.2f %@", b, unit))
            }.font(.subheadline).monospacedDigit()
            Text(lang.t("plan_difference") + String(format: " %+.2f %@", b - a, unit))
                .font(.caption).foregroundColor(.secondary)
        }.padding(.vertical, 4)
    }
}

/// Offline, paginated A4 report. Drawing uses one scale for both axes.
enum ResidentialPDFReport {
    static func write(layout: SavedFloorplanLayout, title: String, metrics: ResidentialPlanMetrics,
                      selectedIDs: Set<String>, estimate: ResidentialMaterialEstimate?, parameters: [String]) throws -> URL {
        let lang = LocalizationManager.shared
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("space-report-\(UUID().uuidString).pdf")
        try renderer.writePDF(to: url) { context in
            var y: CGFloat = 40
            var pageNumber = 0
            func beginPage() {
                context.beginPage(); pageNumber += 1; y = 40
                ("\(pageNumber)" as NSString).draw(at: CGPoint(x: 545, y: 808),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray])
            }
            func line(_ text: String, size: CGFloat = 12) {
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: size), .foregroundColor: UIColor.black]
                let height = (text as NSString).boundingRect(with: CGSize(width: 515, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil).height + 10
                if y + height > 785 { beginPage() }
                (text as NSString).draw(in: CGRect(x: 40, y: y, width: 515, height: height), withAttributes: attributes)
                y += height
            }
            beginPage()
            line(lang.t("plan_report_title"), size: 22)
            line(title, size: 17)
            line(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))
            line(lang.t("plan_manual_geometry"))
            line(lang.t("res_measurement_note"))
            if let width = layout.widthMeters, let depth = layout.depthMeters, width > 0, depth > 0 {
                let available = CGRect(x: 60, y: y + 10, width: 475, height: 300)
                let scale = min(available.width / CGFloat(width), available.height / CGFloat(depth))
                let origin = CGPoint(x: available.midX - CGFloat(width) * scale / 2, y: available.midY - CGFloat(depth) * scale / 2)
                context.cgContext.saveGState()
                context.cgContext.clip(to: available)
                for (index, room) in metrics.rooms.enumerated() {
                    let path = UIBezierPath()
                    for (i, point) in room.points.enumerated() {
                        let p = CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
                        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    path.close(); UIColor.systemTeal.withAlphaComponent(0.12).setFill(); path.fill()
                    UIColor.darkGray.setStroke(); path.lineWidth = 1; path.stroke()
                    let point = room.triangles[0].reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x / 3, y: $0.y + $1.y / 3) }
                    ("\(index + 1)" as NSString).draw(at: CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale),
                        withAttributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black])
                }
                context.cgContext.restoreGState()
                y += 330
                line(String(format: "%.2f m × %.2f m", width, depth))
            }
            line(lang.t("plan_area") + String(format: ": %.2f m²", metrics.totalArea), size: 15)
            line(lang.t("plan_perimeter") + String(format: ": %.2f m", metrics.totalPerimeter))
            line(lang.t("plan_area_note"))
            if !metrics.canEstimate { line(lang.t("plan_fix_geometry")) }
            for (index, room) in metrics.rooms.enumerated() {
                line("\(index + 1). \(room.name) · " + String(format: "%.2f m² · %.2f m", room.area, room.perimeter))
            }
            if let estimate {
                beginPage()
                line(lang.t("plan_materials"), size: 20)
                line(lang.t("plan_selected_rooms") + ": " + metrics.rooms.filter { selectedIDs.contains($0.id) }.map(\.name).joined(separator: ", "))
                for parameter in parameters { line(parameter) }
                line(lang.t("plan_floor_order") + String(format: ": %.2f m²", estimate.flooringArea))
                line(lang.t("plan_packs") + ": \(estimate.flooringPacks)")
                line(lang.t("plan_paint_area") + String(format: ": %.2f m²", estimate.paintArea))
                line(lang.t("plan_paint_litres") + String(format: ": %.2f L", estimate.paintLitres))
                line(lang.t("plan_material_note"))
            }
        }
        return url
    }
}
