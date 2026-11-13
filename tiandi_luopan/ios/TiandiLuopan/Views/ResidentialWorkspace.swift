import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ARKit
import CoreSpotlight
import UserNotifications
#if canImport(RoomPlan)
import RoomPlan
#endif

enum ResidentialUpgrade {
    static func removeLegacyDiscovery() {
        let key = "residential_discovery_cleanup_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if error == nil { UserDefaults.standard.set(true, forKey: key) }
        }
    }
}

// Residential workflows deliberately use geometry only. Legacy archive keys and
// purchase identifiers remain stable so an upgrade can still read existing data.
enum ResidentialGeometry {
    static func clean(_ record: FloorplanCaseRecord) -> FloorplanCaseRecord {
        let original = record.layout
        // Rebuild the immutable layout without traditional analysis or family data.
        let layout = SavedFloorplanLayout(rooms: clean(original.rooms), centroidX: 0.5, centroidY: 0.5,
            compassRotation: original.compassRotation, isSyncWithCompass: false,
            hasFloorplanAccess: original.hasFloorplanAccess, floorplanAccessGrantID: original.floorplanAccessGrantID,
            floorplanAccessGrantSignature: original.floorplanAccessGrantSignature, aspectRatio: original.aspectRatio,
            widthMeters: original.widthMeters, depthMeters: original.depthMeters,
            surveyMapping: original.surveyMapping, familyRoomAssignments: [], estimateSettings: original.estimateSettings)
        return FloorplanCaseRecord(id: record.id, title: record.title, createdAt: record.createdAt,
            sittingSummary: "", layout: layout, imageFileName: record.imageFileName,
            spatialSurvey: record.spatialSurvey.map { ResidentialSurveyGeometry($0).restored },
            virtualSpatialSurvey: record.virtualSpatialSurvey.map { ResidentialSurveyGeometry($0).restored },
            propertyKey: record.propertyKey, backupImageData: record.backupImageData)
    }
    static func clean(_ rooms: [FloorplanRoom]) -> [FloorplanRoom] {
        rooms.filter { $0.type != .missingCorner }.map { room in
            FloorplanRoom(id: room.id, name: room.name, type: room.type,
                          rect: room.rect, polygonPoints: room.polygonPoints,
                          inspectionLevel: "")
        }
    }

    static func survey(layout: SavedFloorplanLayout) -> HouseSpatialSurvey? {
        guard let width = layout.widthMeters, let depth = layout.depthMeters,
              width.isFinite, depth.isFinite, width > 0, depth > 0 else { return nil }
        let rooms = clean(layout.rooms).filter { $0.type != .door }.map { room in
            SpatialRoom3D(id: UUID(uuidString: room.id) ?? UUID(), name: room.name, type: room.type,
                          center: SIMD3(Float(room.rect.midX) * Float(width), 1.4, Float(room.rect.midY) * Float(depth)),
                          size: SIMD3(Float(room.rect.width) * Float(width), 2.8, Float(room.rect.height) * Float(depth)))
        }
        guard !rooms.isEmpty else { return nil }
        return HouseSpatialSurveyEngine.analyzeSpatialHouse(
            scanMethod: LocalizationManager.shared.t("res_manual_source"), walls: [], openings: [],
            beams: [], rooms: rooms, objects: [], compassHeading: layout.compassRotation)
    }
}

struct ResidentialProjectsView: View {
    @Binding var selectedTab: Int
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var cases = FloorplanCaseStore.shared
    @ObservedObject private var workspace = FloorplanWorkspaceStore.shared
    @State private var projectName = ""
    @State private var message: String?
    @State private var pendingDelete: FloorplanCaseRecord?
    @State private var pendingLoad: FloorplanCaseRecord?
    @State private var importing = false
    @State private var share: ResidentialShareItem?
    @State private var planningProject: FloorplanCaseRecord?

    private var directory: URL { workspace.imageURL?.deletingLastPathComponent() ?? FileManager.default.temporaryDirectory }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text(lang.t("res_intro"))
                    Button { selectedTab = 1 } label: { Label(lang.t("res_measure"), systemImage: "viewfinder") }
                    Button { selectedTab = 2 } label: { Label(lang.t("res_edit"), systemImage: "square.and.pencil") }
                }
                Section(lang.t("res_save_project")) {
                    TextField(lang.t("res_project_name"), text: $projectName)
                    Button(lang.t("res_save_project"), action: saveProject)
                        .disabled(workspace.snapshot.layout == nil)
                    Button { importing = true } label: { Label(lang.t("res_import_backup"), systemImage: "square.and.arrow.down") }
                    if cases.records.count >= 2 {
                        NavigationLink { ResidentialComparisonView(records: cases.records) } label: {
                            Label(lang.t("plan_compare"), systemImage: "square.split.2x1")
                        }
                    }
                }
                Section(lang.t("res_projects")) {
                    if cases.records.isEmpty { Text(lang.t("res_empty" )).foregroundColor(.secondary) }
                    ForEach(cases.records) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(record.title).font(.headline)
                            Text(record.createdAt, style: .date).font(.caption).foregroundColor(.secondary)
                            Button { planningProject = record } label: { Label(lang.t("plan_tools"), systemImage: "ruler") }
                                .buttonStyle(.borderless)
                            HStack {
                                Button(lang.t("res_open")) { pendingLoad = record }
                                Spacer()
                                Button { export(record) } label: { Image(systemName: "square.and.arrow.up") }
                                    .accessibilityLabel(lang.t("res_export_backup"))
                                Button(role: .destructive) { pendingDelete = record } label: { Image(systemName: "trash") }
                                    .accessibilityLabel(lang.t("delete"))
                            }.buttonStyle(.borderless)
                        }.padding(.vertical, 6)
                    }
                }
                Section { Text(lang.t("res_measurement_note")).font(.footnote).foregroundColor(.secondary) }
            }
            .navigationTitle(lang.t("res_projects"))
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let record = try FloorplanCaseAssets.importBackup(Data(contentsOf: url),
                        existingIDs: Set(cases.records.map(\.id)), directory: directory)
                    try cases.insert(record)
                } catch { message = error.localizedDescription }
            }
            .sheet(item: $share) { ResidentialShareSheet(items: $0.items) }
            .sheet(item: $planningProject) { record in
                ResidentialPlanningView(layout: record.layout, title: record.title) { settings, previous in
                    try cases.saveEstimateSettings(id: record.id, settings: settings,
                        expectedLayout: record.layout, expectedSettings: previous)
                }
            }
            .confirmationDialog(lang.t("res_replace_workspace"), isPresented: Binding(
                get: { pendingLoad != nil }, set: { if !$0 { pendingLoad = nil } })) {
                if let record = pendingLoad {
                    Button(lang.t("res_open")) { load(record); pendingLoad = nil }
                }
            } message: { Text(lang.t("res_save_first")) }
            .confirmationDialog(lang.t("delete"), isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                if let record = pendingDelete {
                    Button(lang.t("delete"), role: .destructive) {
                        do { try cases.remove(id: record.id, imageDirectory: directory) }
                        catch { message = error.localizedDescription }
                        pendingDelete = nil
                    }
                }
            }
            .alert(lang.t("res_projects"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(lang.t("done"), role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }.navigationViewStyle(.stack)
    }

    private func saveProject() {
        guard let layout = workspace.snapshot.layout else { return }
        var createdImageURL: URL?
        do {
            let id = UUID().uuidString
            var imageName: String?
            if let image = workspace.snapshot.image {
                guard let data = image.jpegData(compressionQuality: 0.85) else { throw CocoaError(.fileWriteUnknown) }
                let name = "res-project-\(id).jpg"
                let url = directory.appendingPathComponent(name)
                createdImageURL = url
                try data.write(to: url, options: .atomic)
                imageName = name
            }
            let title = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
            let models = ShaSurveyStore.shared.projectModels()
            let record = FloorplanCaseRecord(id: id, title: title.isEmpty ? lang.t("res_untitled") : title,
                createdAt: Date(), sittingSummary: "", layout: layout, imageFileName: imageName,
                spatialSurvey: models.measured,
                virtualSpatialSurvey: models.manual,
                propertyKey: ShaSurveyStore.shared.propertyKey)
            try cases.insert(ResidentialGeometry.clean(record))
            projectName = ""
            message = lang.t("res_saved")
        } catch {
            if let createdImageURL { try? FileManager.default.removeItem(at: createdImageURL) }
            message = error.localizedDescription
        }
    }

    private func load(_ record: FloorplanCaseRecord) {
        do {
            let record = ResidentialGeometry.clean(record)
            let image = try record.imageFileName.map { try Data(contentsOf: FloorplanCaseAssets.imageURL(fileName: $0, directory: directory)) }
                .flatMap { UIImage(data: $0) }
            // Persist the workspace first. A failed image write must not switch
            // the active property and leave the old layout attached to it.
            guard try workspace.save(layout: record.layout, image: image, writerID: UUID()) else { return }
            _ = ShaSurveyStore.shared.replaceProperty(measured: record.spatialSurvey, virtual: record.virtualSpatialSurvey,
                exterior: [], propertyKey: record.propertyKey)
            _ = try workspace.save(layout: record.layout, image: image, writerID: UUID())
            selectedTab = 2
        } catch { message = error.localizedDescription }
    }

    private func export(_ record: FloorplanCaseRecord) {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("res-project-\(UUID().uuidString).json")
            try FloorplanCaseAssets.backup(record, directory: directory).write(to: url, options: .atomic)
            share = ResidentialShareItem(items: [url])
        } catch { message = error.localizedDescription }
    }
}

public struct FloorplanView: View {
    public var isActive = true
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var workspace = FloorplanWorkspaceStore.shared
    @State private var rooms: [FloorplanRoom] = []
    @State private var image: UIImage?
    @State private var width = 10.0
    @State private var depth = 10.0
    @State private var selectedID: String?
    @State private var showImage = false
    @State private var showModel = false
    @State private var message: String?
    @State private var dragStart: CGRect?
    @State private var revision: UInt64 = 0
    @State private var writerID = UUID()
    @State private var showReset = false
    @State private var share: ResidentialShareItem?
    @State private var model: HouseSpatialSurvey?
    @State private var planningSession: ResidentialPlanningSession?

    public init(isActive: Bool = true) { self.isActive = isActive }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(lang.t("res_manual_note")).font(.footnote).foregroundColor(.secondary)
                    HStack {
                        Button { showImage = true } label: { Label(lang.t("res_import_image"), systemImage: "photo") }
                        Spacer()
                        Button { showReset = true } label: { Label(lang.t("res_new"), systemImage: "plus") }
                    }
                    HStack {
                        dimensionField(lang.t("res_width"), value: $width)
                        dimensionField(lang.t("res_depth"), value: $depth)
                    }
                    GeometryReader { geo in
                        let ratio = width.isFinite && depth.isFinite && width > 0 && depth > 0 ? width / depth : 1
                        let canvas = GeometryUtils.aspectFitRect(aspectRatio: CGFloat(ratio), in: CGRect(origin: .zero, size: geo.size))
                        ZStack(alignment: .topLeading) {
                            Color.gray.opacity(0.15)
                            if let image { Image(uiImage: image).resizable().scaledToFill().frame(width: canvas.width, height: canvas.height).clipped().opacity(0.55) }
                            ForEach(rooms) { room in roomBlock(room, size: canvas.size) }
                        }.clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(width: canvas.width, height: canvas.height)
                            .position(x: canvas.midX, y: canvas.midY)
                    }.frame(height: 340)
                    Menu {
                        ForEach(FloorplanRoomType.allCases.filter { $0 != .missingCorner }) { type in
                            Button(type.localizedName) { addRoom(type) }
                        }
                    } label: { Label(lang.t("res_add_room"), systemImage: "plus.rectangle") }
                    if let index = rooms.firstIndex(where: { $0.id == selectedID }) {
                        roomEditor(index)
                    }
                    HStack {
                        Button(lang.t("res_save")) { persist() }
                        Spacer()
                        Button(lang.t("res_model")) {
                            guard persist() else { return }
                            model = ResidentialGeometry.survey(layout: currentLayout)
                            showModel = model != nil
                        }.disabled(rooms.isEmpty)
                        Button { exportPlan() } label: { Image(systemName: "square.and.arrow.up") }
                            .accessibilityLabel(lang.t("res_export"))
                    }
                    ForEach(rooms.filter { $0.type != .door }) { room in
                        HStack {
                            Label(room.name, systemImage: room.type.iconName)
                            Spacer()
                            Text(String(format: "%.2f m²", Double(FloorplanEngine.roomArea(room)) * width * depth))
                                .monospacedDigit()
                        }.font(.subheadline)
                    }
                    Button {
                        guard persist() else { return }
                        planningSession = ResidentialPlanningSession(layout: currentLayout, propertyID: workspace.snapshot.propertyID)
                    } label: { Label(lang.t("plan_tools"), systemImage: "ruler") }
                        .disabled(rooms.isEmpty)
                }.padding()
            }
            .navigationTitle(lang.t("res_edit"))
            .onAppear { reload() }
            .onReceive(workspace.$snapshot) { snapshot in
                if snapshot.writerID != writerID { reload(snapshot) }
                revision = snapshot.revision
            }
            .onChange(of: isActive) { if !$0 { persist() } }
            .sheet(isPresented: $showImage) {
                FloorplanImagePicker(selectedImage: $image, onImagePicked: { persist() })
            }
            .sheet(isPresented: $showModel) { if let model { House3DSpaceViewer(survey: model) } }
            .sheet(item: $planningSession) { session in
                ResidentialPlanningView(layout: session.layout, title: lang.t("res_untitled")) { settings, previous in
                    try workspace.saveEstimateSettings(settings, expectedLayout: session.layout,
                        expectedSettings: previous, propertyID: session.propertyID)
                }
            }
            .sheet(item: $share) { ResidentialShareSheet(items: $0.items) }
            .confirmationDialog(lang.t("res_new"), isPresented: $showReset) {
                Button(lang.t("res_new"), role: .destructive) {
                    rooms = []; image = nil; selectedID = nil; width = 10; depth = 10
                    guard persist() else { reload(); return }
                    _ = ShaSurveyStore.shared.replaceProperty(measured: nil, virtual: nil, exterior: [])
                    // A new property must not inherit material deductions or selections.
                    var layout = currentLayout; layout.estimateSettings = nil
                    do { _ = try workspace.save(layout: layout, image: image, writerID: writerID) }
                    catch { message = error.localizedDescription }
                    persist()
                }
            } message: { Text(lang.t("res_save_first")) }
            .alert(lang.t("res_edit"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button(lang.t("done"), role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }.navigationViewStyle(.stack)
    }

    private var currentLayout: SavedFloorplanLayout {
        let old = workspace.snapshot.layout
        return SavedFloorplanLayout(rooms: ResidentialGeometry.clean(rooms), centroidX: 0.5, centroidY: 0.5,
            compassRotation: old?.compassRotation ?? 0, isSyncWithCompass: false,
            hasFloorplanAccess: old?.hasFloorplanAccess ?? false,
            floorplanAccessGrantID: old?.floorplanAccessGrantID, floorplanAccessGrantSignature: old?.floorplanAccessGrantSignature,
            aspectRatio: width / depth, widthMeters: width, depthMeters: depth,
            houseFacingDegrees: old?.houseFacingDegrees, houseFacingWasExplicit: old?.houseFacingWasExplicit,
            surveyMapping: old?.surveyMapping, familyRoomAssignments: [], estimateSettings: old?.estimateSettings)
    }

    private func dimensionField(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption)
            TextField(title, value: value, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                .onSubmit { persist() }
        }
    }

    private func roomBlock(_ room: FloorplanRoom, size: CGSize) -> some View {
        let rect = CGRect(x: room.rect.minX * size.width, y: room.rect.minY * size.height,
                          width: room.rect.width * size.width, height: room.rect.height * size.height)
        let outline = Path { path in
            if let points = room.polygonPoints, points.count >= 3 {
                path.addLines(points.map { CGPoint(x: ($0.x - room.rect.minX) * size.width, y: ($0.y - room.rect.minY) * size.height) })
                path.closeSubpath()
            } else { path.addRect(CGRect(origin: .zero, size: rect.size)) }
        }
        return ZStack {
            outline.fill(selectedID == room.id ? Color.blue.opacity(0.65) : Color.teal.opacity(0.45))
            outline.stroke(selectedID == room.id ? Color.white : Color.teal, lineWidth: 2)
            Text(room.name).font(.caption).minimumScaleFactor(0.7)
        }
            .frame(width: rect.width, height: rect.height)
            .contentShape(outline)
            .position(x: rect.midX, y: rect.midY)
            .onTapGesture { selectedID = room.id }
            .gesture(DragGesture().onChanged { value in
                if dragStart == nil { dragStart = room.rect; selectedID = room.id }
                guard let start = dragStart, let index = rooms.firstIndex(where: { $0.id == room.id }) else { return }
                let next = CGRect(x: min(1 - start.width, max(0, start.minX + value.translation.width / size.width)),
                                  y: min(1 - start.height, max(0, start.minY + value.translation.height / size.height)),
                                  width: start.width, height: start.height)
                rooms[index] = rooms[index].transformed(to: next)
            }.onEnded { _ in dragStart = nil; persist() })
    }

    private func roomEditor(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(lang.t("res_room_name"), text: $rooms[index].name).textFieldStyle(.roundedBorder)
                .onSubmit { persist() }
            Picker(lang.t("res_room_type"), selection: $rooms[index].type) {
                ForEach(FloorplanRoomType.allCases.filter { $0 != .missingCorner }) { Text($0.localizedName).tag($0) }
            }.onChange(of: rooms[index].type) { _ in persist() }
            Text(lang.t("res_room_width"))
            Slider(value: roomSize(index, horizontal: true), in: 0.04...max(0.04, 1 - rooms[index].rect.minX), onEditingChanged: { if !$0 { persist() } })
            Text(lang.t("res_room_depth"))
            Slider(value: roomSize(index, horizontal: false), in: 0.04...max(0.04, 1 - rooms[index].rect.minY), onEditingChanged: { if !$0 { persist() } })
            Button(lang.t("delete"), role: .destructive) { rooms.remove(at: index); selectedID = nil; persist() }
        }
    }

    private func roomSize(_ index: Int, horizontal: Bool) -> Binding<Double> {
        Binding(get: { Double(horizontal ? rooms[index].rect.width : rooms[index].rect.height) }, set: { value in
            var rect = rooms[index].rect
            if horizontal { rect.size.width = CGFloat(value) } else { rect.size.height = CGFloat(value) }
            rooms[index] = rooms[index].transformed(to: rect)
        })
    }

    private func addRoom(_ type: FloorplanRoomType) {
        let room = FloorplanRoom(name: type.localizedName, type: type, rect: CGRect(x: 0.1, y: 0.1, width: 0.25, height: 0.25), inspectionLevel: "")
        rooms.append(room); selectedID = room.id; persist()
    }

    private func reload(_ incoming: FloorplanWorkspaceSnapshot? = nil) {
        let snapshot = incoming ?? workspace.snapshot
        revision = snapshot.revision
        rooms = ResidentialGeometry.clean(snapshot.layout?.rooms ?? [])
        image = snapshot.image
        width = snapshot.layout?.widthMeters ?? 10
        depth = snapshot.layout?.depthMeters ?? 10
        selectedID = nil
    }

    @discardableResult private func persist() -> Bool {
        guard width.isFinite, depth.isFinite, (0.5...200).contains(width), (0.5...200).contains(depth) else {
            message = lang.t("res_invalid_dimensions"); return false
        }
        do {
            guard try workspace.save(layout: currentLayout, image: image, writerID: writerID,
                expectedRevision: revision, expectedPropertyID: workspace.snapshot.propertyID) else {
                reload(); message = lang.t("res_conflict"); return false
            }
            revision = workspace.snapshot.revision
            return true
        } catch { message = error.localizedDescription; return false }
    }

    private func exportPlan() {
        guard persist() else { return }
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("floorplan-\(UUID().uuidString).json")
            // Use the same geometry schema as backups, including nonrectangular outlines.
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(ResidentialProjectBackup.Plan(currentLayout)).write(to: url, options: .atomic)
            share = ResidentialShareItem(items: [url])
        } catch { message = error.localizedDescription }
    }

    @discardableResult static func persistRoomPlanImport(rooms: [FloorplanRoom], centroid: CGPoint,
        blueprintImage: UIImage?, propertyID: UUID, compassHeading: Double,
        spatialSurvey: HouseSpatialSurvey?, surveyMapping: FloorplanSurveyMapping?) -> Bool {
        guard ShaSurveyStore.shared.isCurrentProperty(propertyID) else { return false }
        let workspace = FloorplanWorkspaceStore.shared
        let old = workspace.snapshot.layout
        let mapping = surveyMapping
        let layout = SavedFloorplanLayout(rooms: ResidentialGeometry.clean(rooms), centroidX: Double(centroid.x), centroidY: Double(centroid.y),
            compassRotation: compassHeading, isSyncWithCompass: false, hasFloorplanAccess: old?.hasFloorplanAccess ?? false,
            floorplanAccessGrantID: old?.floorplanAccessGrantID, floorplanAccessGrantSignature: old?.floorplanAccessGrantSignature,
            aspectRatio: mapping.map { $0.spanX / $0.spanZ },
            widthMeters: mapping.map { $0.spanX / (1 - 2 * $0.padding) },
            depthMeters: mapping.map { $0.spanZ / (1 - 2 * $0.padding) },
            houseFacingDegrees: spatialSurvey?.houseFacingDegrees, surveyMapping: surveyMapping, familyRoomAssignments: [])
        do {
            let saved = try workspace.save(layout: layout, image: blueprintImage, writerID: UUID(),
                expectedRevision: workspace.snapshot.revision, expectedPropertyID: propertyID)
            if saved { NotificationCenter.default.post(name: .didImportRoomPlanFloorplan, object: nil) }
            return saved
        } catch { return false }
    }
}

struct ResidentialMeasurementView: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var store = ShaSurveyStore.shared
    @State private var showAR = false
    @State private var showRoomPlan = false
    @State private var showManual = false
    @State private var model: HouseSpatialSurvey?
    @State private var showModel = false
    var body: some View {
        NavigationView {
            List {
                Section(lang.t("res_measure")) {
                    Button { showAR = true } label: { Label(lang.t("res_ar_measure"), systemImage: "viewfinder") }
                        .disabled(!ARWorldTrackingConfiguration.isSupported)
#if canImport(RoomPlan)
                    if RoomCaptureSession.isSupported {
                        Button { showRoomPlan = true } label: { Label(lang.t("ar_roomplan_title"), systemImage: "house") }
                    } else { Text(lang.t("res_lidar_note")).foregroundColor(.secondary) }
#endif
                    Button { showManual = true } label: { Label(lang.t("res_manual_model"), systemImage: "square.and.pencil") }
                }
                if let survey = store.latestInterior {
                    Section(lang.t("res_recent_model")) {
                        Text(survey.scanMethod)
                        Text(survey.timestamp, style: .date)
                        Button(lang.t("res_model")) { model = survey; showModel = true }
                    }
                }
                Section { Text(lang.t("res_measurement_note")).font(.footnote).foregroundColor(.secondary) }
            }.navigationTitle(lang.t("res_measure"))
            .fullScreenCover(isPresented: $showAR) { CameraExclusiveGate { ARSpatialSurveyView() } }
            .fullScreenCover(isPresented: $showRoomPlan) {
#if canImport(RoomPlan)
                CameraExclusiveGate { ARRoomPlanCaptureView() }
#endif
            }
            .sheet(isPresented: $showManual) { VRSpatialSurveyView() }
            .sheet(isPresented: $showModel) { if let model { House3DSpaceViewer(survey: model) } }
        }.navigationViewStyle(.stack)
    }
}

struct ResidentialShareItem: Identifiable { let id = UUID(); let items: [Any] }
struct ResidentialPlanningSession: Identifiable {
    let id = UUID()
    let layout: SavedFloorplanLayout
    let propertyID: UUID
}
struct ResidentialShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
