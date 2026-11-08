import SwiftUI
import UIKit
import Vision
import ImageIO

// MARK: - 户型空间立极与全屋风水体检视图 (Floorplan View - PRD 5.3)

extension Notification.Name {
    public static let didImportRoomPlanFloorplan = Notification.Name("com.yanxiang.compass.didImportRoomPlanFloorplan")
}

struct SavedFloorplanLayout: Codable {
    let rooms: [FloorplanRoom]
    let centroidX: Double
    let centroidY: Double
    let compassRotation: Double
    let isSyncWithCompass: Bool
    let hasFloorplanAccess: Bool
    /// A paid case grant is scoped to this saved layout. Older records may
    /// contain only the pre-signature ID; those records are re-sealed once on
    /// restore before they can continue to unlock the layout.
    let floorplanAccessGrantID: String?
    let floorplanAccessGrantSignature: String?
    var aspectRatio: Double? = nil
    var widthMeters: Double? = nil
    var depthMeters: Double? = nil
    var houseFacingDegrees: Double? = nil
}

/// P1.2 多套户型宅谱档案记录（支持保存多套房源/客户户型、关联 3D 空间测绘模型及各自的已购解锁凭证）
struct FloorplanCaseRecord: Codable, Identifiable {
    var id: String
    var title: String
    let createdAt: Date
    let sittingSummary: String
    let layout: SavedFloorplanLayout
    var imageFileName: String?
    var spatialSurvey: HouseSpatialSurvey? = nil
    var virtualSpatialSurvey: HouseSpatialSurvey? = nil
    var exteriorRecords: [ExteriorShaRecord]? = nil
    // Included only in portable JSON backups, never in the defaults archive.
    var backupImageData: Data? = nil
}

enum FloorplanCaseAssets {
    static func imageURL(fileName: String, directory: URL) throws -> URL {
        guard !fileName.isEmpty, fileName != ".", fileName != "..",
              URL(fileURLWithPath: fileName).lastPathComponent == fileName else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    static func backup(_ record: FloorplanCaseRecord, directory: URL) throws -> Data {
        var portable = record
        if let name = record.imageFileName {
            portable.backupImageData = try Data(contentsOf: imageURL(fileName: name, directory: directory))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(portable)
    }

    static func importBackup(_ data: Data, existingIDs: Set<String>, directory: URL) throws -> FloorplanCaseRecord {
        var record = try JSONDecoder().decode(FloorplanCaseRecord.self, from: data)
        if record.id.isEmpty || existingIDs.contains(record.id) { record.id = UUID().uuidString }
        let imageData: Data?
        if let embedded = record.backupImageData {
            imageData = embedded
        } else if let name = record.imageFileName {
            // Legacy backups can still be imported on the original device.
            imageData = try Data(contentsOf: imageURL(fileName: name, directory: directory))
        } else {
            imageData = nil
        }
        record.imageFileName = nil
        if let imageData {
            let name = "floorplan-case-\(UUID().uuidString).jpg"
            try imageData.write(to: imageURL(fileName: name, directory: directory), options: .atomic)
            record.imageFileName = name
        }
        record.backupImageData = nil
        return record
    }

    static func deleteImage(_ record: FloorplanCaseRecord, remainingCases: [FloorplanCaseRecord], directory: URL) throws {
        guard let name = record.imageFileName,
              !remainingCases.contains(where: { $0.imageFileName == name }) else { return }
        let url = try imageURL(fileName: name, directory: directory)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

/// One process-wide archive: windows mutate records by ID, never write a stale list.
final class FloorplanCaseStore: ObservableObject {
    static let shared = FloorplanCaseStore()
    static let storageKey = "tiandi_floorplan_cases_archive_v1"
    @Published private(set) var records: [FloorplanCaseRecord]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        records = defaults.data(forKey: Self.storageKey).flatMap {
            try? JSONDecoder().decode([FloorplanCaseRecord].self, from: $0)
        } ?? []
    }

    func insert(_ record: FloorplanCaseRecord) throws {
        var record = record
        if record.id.isEmpty || records.contains(where: { $0.id == record.id }) {
            record.id = UUID().uuidString
        }
        var updated = records
        updated.insert(record, at: 0)
        try persist(updated)
    }

    func remove(id: String, imageDirectory: URL) throws {
        guard let record = records.first(where: { $0.id == id }) else { return }
        let updated = records.filter { $0.id != id }
        let data = try JSONEncoder().encode(updated)
        try FloorplanCaseAssets.deleteImage(record, remainingCases: updated, directory: imageDirectory)
        defaults.set(data, forKey: Self.storageKey)
        records = updated
    }

    private func persist(_ updated: [FloorplanCaseRecord]) throws {
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: Self.storageKey)
        records = updated
    }
}

struct FloorplanWorkspaceSnapshot {
    let revision: UInt64
    let writerID: UUID?
    let layout: SavedFloorplanLayout?
    let image: UIImage?
}

/// Shares the active plan and its image as one revision across all scenes.
/// Revision checks also reject delayed background/gesture writes from old views.
final class FloorplanWorkspaceStore: ObservableObject {
    static let shared = FloorplanWorkspaceStore()
    static let layoutKey = "tiandi_floorplan_saved_layout_v1"
    @Published private(set) var snapshot: FloorplanWorkspaceSnapshot
    let imageURL: URL?
    private let defaults: UserDefaults
    private var encodedLayout: Data?

    init(defaults: UserDefaults = .standard, directory: URL? = nil) {
        self.defaults = defaults
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let resolvedImageURL: URL?
        if let folder, (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil {
            resolvedImageURL = folder.appendingPathComponent("floorplan-background.jpg")
        } else { resolvedImageURL = nil }
        self.imageURL = resolvedImageURL
        let layout = defaults.data(forKey: Self.layoutKey).flatMap {
            try? JSONDecoder().decode(SavedFloorplanLayout.self, from: $0)
        }
        encodedLayout = layout.flatMap { try? Self.encode($0) }
        snapshot = FloorplanWorkspaceSnapshot(revision: 0, writerID: nil, layout: layout,
                                              image: resolvedImageURL.flatMap { UIImage(contentsOfFile: $0.path) })
    }

    @discardableResult
    func save(layout: SavedFloorplanLayout, image: UIImage?, writerID: UUID,
              expectedRevision: UInt64? = nil) throws -> Bool {
        if let expectedRevision, expectedRevision != snapshot.revision { return false }
        let data = try Self.encode(layout)
        let sameImage = image === snapshot.image
        guard data != encodedLayout || !sameImage else { return true }
        if !sameImage {
            guard let imageURL else { throw CocoaError(.fileWriteNoPermission) }
            if let image {
                guard let bytes = image.jpegData(compressionQuality: 0.85) ?? image.pngData() else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try bytes.write(to: imageURL, options: .atomic)
            } else if FileManager.default.fileExists(atPath: imageURL.path) {
                try FileManager.default.removeItem(at: imageURL)
            }
        }
        defaults.set(data, forKey: Self.layoutKey)
        encodedLayout = data
        snapshot = FloorplanWorkspaceSnapshot(revision: snapshot.revision &+ 1, writerID: writerID,
                                              layout: layout, image: image)
        return true
    }

    private static func encode(_ layout: SavedFloorplanLayout) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(layout)
    }
}

/// Complete geometry and audit values captured together on the UI thread.
struct FloorplanReportSnapshot {
    let rooms: [FloorplanRoom]
    let report: [FloorplanAuditItem]
    let centroid: CGPoint
    let heading: Double
    let aspectRatio: CGFloat
    let image: UIImage?
    let date: Date

    init(rooms: [FloorplanRoom], centroid: CGPoint, heading: Double, aspectRatio: CGFloat,
         image: UIImage? = nil, date: Date = Date()) {
        self.centroid = centroid
        self.heading = heading
        self.aspectRatio = aspectRatio
        self.image = image
        self.date = date
        let result = FloorplanEngine.shared.auditFloorplan(rooms: rooms, centroid: centroid, heading: heading,
                                                          aspectRatio: aspectRatio, date: date)
        self.rooms = result.auditedRooms
        self.report = result.report
    }
}

/// 识别候选：矩形框 + 可选的真实轮廓多边形（相对坐标 0..1）
private struct RoomCandidate: Equatable {
    var rect: CGRect
    var polygonPoints: [CGPoint]?
}

public struct FloorplanView: View {
    public var isActive: Bool = true
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    
    @State private var rooms: [FloorplanRoom] = FloorplanEngine.shared.generateSampleRooms()
    @State private var centroid: CGPoint = CGPoint(x: 0.5, y: 0.5) // 归一化重心
    @State private var compassRotation: Double = 0.0
    @State private var isSyncWithCompass: Bool = true
    @State private var selectedRoom: FloorplanRoom? = nil
    @State private var userFloorplanImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var showPaywall: Bool = false
    @State private var paywallDefaultProduct: IAPProductID = .floorplanSingle
    @State private var showResetConfirmation: Bool = false
    @State private var isEditingRooms: Bool = false
    @State private var activeRoomDragID: String? = nil
    @State private var activeRoomStartRect: CGRect? = nil
    @State private var activeRoomScaleID: String? = nil
    @State private var activeRoomScaleStartRect: CGRect? = nil
    @State private var roomWasDragged = false
    @State private var selectedEditingRoomID: String?
    @State private var showEditingRoomDeleteConfirmation = false
    @State private var centroidDragStart: CGPoint? = nil
    @State private var didConsumeFloorplanCredit: Bool = false
    @State private var floorplanAccessGrantID: String?
    @State private var floorplanAccessGrantSignature: String?
    @State private var auditedRooms: [FloorplanRoom] = []
    @State private var auditReport: [FloorplanAuditItem] = []
    @State private var isDetectingRooms: Bool = false
    @State private var roomDetectionGeneration: Int = 0
    @State private var roomDetectionMessage: String?
    @State private var calibratedWidthText: String = ""
    @State private var calibratedDepthText: String = ""
    @State private var restoredAspectRatio: CGFloat = 1
    @FocusState private var isCalibrationFieldFocused: Bool
    @State private var roomsBeforeDetection: [FloorplanRoom]?
    @State private var centroidBeforeDetection: CGPoint?
    @State private var showNewRoomTypePicker = false
    @State private var roomForTypeEditing: FloorplanRoom?
    @State private var floorplanImageBeforePicker: UIImage?
    @State private var lastAuditedHeading: Double?
    @State private var lastAuditedCentroid: CGPoint?
    @State private var lastAuditTimeKey: FloorplanAuditTimeKey?
    @State private var didRestorePersistedLayout = false
    @State private var persistedSpatialSurvey: HouseSpatialSurvey? = nil
    @State private var persistedVirtualSpatialSurvey: HouseSpatialSurvey? = nil
    @State private var show3DSpaceViewer: Bool = false
    @State private var showVirtualSpaceViewer: Bool = false
    @State private var currentFloorplanSurvey: HouseSpatialSurvey? = nil
    @State private var showCurrentFloorplan3D: Bool = false
    @State private var showARSpatialSurvey: Bool = false
    @State private var showVRSpatialSurvey: Bool = false
    @State private var exportedReportImage: UIImage? = nil
    @State private var showReportShareSheet: Bool = false
    @State private var reportExportGeneration: Int = 0
    // Shared stores own writes across scenes and encode images only on replacement.
    @ObservedObject private var caseStore = FloorplanCaseStore.shared
    @ObservedObject private var workspaceStore = FloorplanWorkspaceStore.shared
    @State private var workspaceWriterID = UUID()
    @State private var workspaceRevision: UInt64 = 0
    @State private var houseFacingOffset: Double?
    private var savedCases: [FloorplanCaseRecord] { caseStore.records }
    @State private var showCaseArchiveSheet: Bool = false
    @State private var newCaseTitleInput: String = ""
    @State private var caseBackupToastMessage: String? = nil

    private static let savedLayoutKey = FloorplanWorkspaceStore.layoutKey
    
    private static let auditClock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    public init(isActive: Bool = true) {
        self.isActive = isActive
    }
    
    private var effectiveHeading: Double {
        if !isSyncWithCompass {
            return compassRotation
        }
        // 直接使用统一的实时磁航向；航向管理器已经负责环形滤波，
        // 这里再按 0.5° 四舍五入会让户型方位和罗盘读数不同步。
        return motion.headingState.facingAngle
    }

    /// Optional explicit facing is stored relative to the blueprint axes so
    /// a later north calibration rotates both bearings by the same amount.
    private var houseFacingDegrees: Double? {
        houseFacingOffset.map { Self.normalizedHeading(effectiveHeading + $0) }
    }

    private var floorplanAspectRatio: CGFloat {
        if let width = calibratedWidthMeters, let depth = calibratedDepthMeters { return width / depth }
        if let image = userFloorplanImage, image.size.width > 0, image.size.height > 0 {
            return image.size.width / image.size.height
        }
        return restoredAspectRatio
    }

    private var projectionDimensions: CGSize {
        let width = calibratedWidthMeters ?? calibratedDepthMeters.map { $0 * floorplanAspectRatio } ?? 12
        return CGSize(width: width, height: calibratedDepthMeters ?? width / floorplanAspectRatio)
    }

    private var floorplanHeadingState: CompassHeadingState {
        if let houseFacingDegrees {
            return Mountain24Data.shared.resolveHeadingState(heading: houseFacingDegrees, pitch: motion.pitch, roll: motion.roll)
        }
        if isSyncWithCompass {
            return motion.headingState
        }
        return Mountain24Data.shared.resolveHeadingState(
            heading: compassRotation,
            pitch: motion.pitch,
            roll: motion.roll
        )
    }

    // 两套口径严格区分（见 AdaptiveLayout）：
    //   isSplitLayout：iPhone Duo 展开内屏 / iPad 界面横屏 —— 左右双栏（画布在左栏，
    //                  按左栏宽度反算尺寸，绝不越出左栏）
    //   isLargeLayout：宽屏（iPad 全形态 + Duo 内屏）—— 决定画布/内容宽度上限与控件档位；
    //                  iPad 竖屏仍是上下单列，只有界面横屏才分栏。
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 布局环境值：iPad 横屏与 Duo 内屏一样分栏，竖屏回单列。
    @Environment(\.adaptiveLayoutForm) private var layoutForm
    private var isSplitLayout: Bool {
        AdaptiveLayout.isTwoPane(horizontal: horizontalSizeClass,
                                      vertical: verticalSizeClass, form: layoutForm)
    }
    private var isLargeLayout: Bool {
        AdaptiveLayout.isWide(sizeClass: horizontalSizeClass)
    }

    private var canvasHeight: CGFloat {
        isLargeLayout ? 560 : 340
    }
    
    public var body: some View {
        // CompassMotionManager publishes tilt and magnetic-field samples more
        // often than the floorplan audit inputs change. Reuse the last audit
        // result so those unrelated samples only redraw the visible overlay.
        // Render the editable source rooms until the first audit finishes so
        // the canvas never flashes empty during the initial appearance.
        let roomsForCanvas = auditedRooms.isEmpty ? rooms : auditedRooms
        let auditResult: (auditedRooms: [FloorplanRoom], report: [FloorplanAuditItem]) = isActive
            ? (roomsForCanvas, auditReport)
            : (rooms, [])
        
        return ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()
            
            if isActive {
                GeometryReader { geo in
                    let screenW: CGFloat = geo.size.width
                    let screenH: CGFloat = geo.size.height
                    // 展开态双栏：左栏宽度由 AdaptiveLayout 按当前有效宽度统一计算，
                    // 与 FoldableTwoPane / ProportionalTwoPaneLayout 用的是同一个函数，
                    // 因此画布能按左栏真实占比自适应并铺满，不会越出左栏。
                    let paneWidth = AdaptiveLayout.mainPaneWidth(totalWidth: screenW)
                    // 分栏态不设 900 之类的固定上限：工具条与画板一起铺满左栏。
                    // 合上外屏 / 普通 iPhone 走 .infinity，与手机口径完全一致。
                    let contentMax: CGFloat = isSplitLayout
                        ? .infinity
                        : (isLargeLayout ? min(screenW - 32, 900) : .infinity)
                    // 画布边长 = 左栏可用宽与可用高中较小者；只扣必要的交互边距，
                    // 不再用 screenH*0.55/0.62 这类固定系数把画板压小留白。
                    let canvasSide: CGFloat = isSplitLayout
                        ? min(paneWidth - 16, max(240, screenH - 160))
                        : isLargeLayout
                            ? min(screenW - 64, screenH * 0.62)
                            : min(screenW - 32, screenH < 700 ? 250.0 : (screenH > 900 ? 380.0 : min(340.0, screenH * 0.40)))

                    // 左栏内容（画布 + 全部操作工具）：展开态与折叠态共用同一份定义
                    let mainColumn = VStack(spacing: 8) {
                                topControlBar()
                                    .frame(maxWidth: contentMax)

                                headingQualityNotice()
                                    .frame(maxWidth: contentMax)

                                if userFloorplanImage != nil {
                                    roomDetectionBar()
                                        .frame(maxWidth: contentMax)
                                    roomCalibrationBar()
                                        .frame(maxWidth: contentMax)
                                }

                                if isEditingRooms {
                                    roomLayoutTools()
                                        .frame(maxWidth: contentMax)
                                    if let editingRoom = editingRoom {
                                        roomResizeTools(room: editingRoom)
                                            .frame(maxWidth: contentMax)
                                    }
                                }
                                
                                floorplanCanvasView(auditedRooms: auditResult.auditedRooms)
                                    .frame(width: isLargeLayout ? canvasSide : nil, height: canvasSide)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, isLargeLayout ? 0 : 16)

                                if !isSyncWithCompass {
                                    manualHeadingControl()
                                        .frame(maxWidth: contentMax)
                                        .padding(.horizontal, 16)
                                }
                    }
                    .padding(.bottom, 16)

                    // 右栏 / 页尾内容：体检报告与房间列表
                    let auditColumn = VStack(spacing: 8) {
                        auditListSection(report: auditResult.report)
                            .frame(maxWidth: contentMax)
                    }
                    .frame(maxWidth: .infinity)
                    // 内块 auditListSection 已自带 .padding(.horizontal, 16)，
                    // 外层不再加横向 padding，避免 iPad 右栏双层 16pt 把卡片内容压窄。
                    .padding(.bottom, 16)

                    if isSplitLayout {
                        // 双栏（Duo 内屏 / iPad 横屏）：两栏各自独立滚动 —— 工具全开不溢出、报告再长也可读
                        FoldableTwoPane(compactSpacing: 8) {
                            ScrollView { mainColumn }
                        } analysis: {
                            ScrollView { auditColumn }
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    } else {
                        // 折叠态：整页单一 ScrollView 驱动（画布 + 工具 + 体检报告连续下划），
                        // 消除小屏底部体检清单被挤出屏幕且无法下滑的问题
                        ScrollView {
                            VStack(spacing: 8) {
                                mainColumn
                                auditColumn
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        // The page re-renders at sensor rate. System alerts attached to inner
        // controls were repeatedly torn down (buttons unresponsive), so the
        // confirmations are rendered as a stable root-level overlay instead.
        .overlay(floorplanConfirmationOverlay)
        .sheet(item: $selectedRoom) { room in
            RoomAuditDetailSheet(
                room: room,
                onEditType: isEditingRooms ? { type in
                    updateRoomType(roomID: room.id, type: type)
                } : nil,
                onDelete: isEditingRooms ? {
                    deleteRoom(roomID: room.id)
                } : nil
            )
        }
        .sheet(item: $roomForTypeEditing) { room in
            FloorplanRoomTypeEditor(
                room: room,
                onDelete: {
                    deleteRoom(roomID: room.id)
                    roomForTypeEditing = nil
                }
            ) { type in
                updateRoomType(roomID: room.id, type: type)
                roomForTypeEditing = nil
            }
        }
        .sheet(isPresented: $showImagePicker) {
            FloorplanImagePicker(selectedImage: $userFloorplanImage) {
                workspaceRevision = workspaceStore.snapshot.revision
                let replacingExistingPlan = floorplanImageBeforePicker != nil
                roomsBeforeDetection = nil
                centroidBeforeDetection = nil
                roomDetectionMessage = nil
                roomDetectionGeneration &+= 1
                isDetectingRooms = false
                // A paid case grant follows the active layout. Replacing the
                // image therefore starts a new editable case without charging
                // a second credit for the same active one-shot entitlement.
                if !iap.hasUnlockedVIP && !didConsumeFloorplanCredit {
                    guard iap.consumeFloorplanCredit() else {
                        // UIImagePickerController updates the binding before
                        // this callback. Restore the previous plan when the
                        // user tries to switch without another entitlement.
                        userFloorplanImage = floorplanImageBeforePicker
                        showPaywall = true
                        return
                    }
                    didConsumeFloorplanCredit = true
                    let grant = iap.issueFloorplanAccessGrant()
                    floorplanAccessGrantID = grant.id
                    floorplanAccessGrantSignature = grant.signature
                }
                if replacingExistingPlan {
                    // A new plan has a different coordinate system. Do not
                    // silently carry the previous plan's room geometry into
                    // it; start from editable sample frames instead.
                    rooms = FloorplanEngine.shared.generateSampleRooms()
                    centroid = CGPoint(x: 0.5, y: 0.5)
                    isEditingRooms = true
                    selectedRoom = nil
                    selectedEditingRoomID = nil
                    roomForTypeEditing = nil
                }
                calibratedWidthText = ""
                calibratedDepthText = ""
                houseFacingOffset = nil
                restoredAspectRatio = 1
                replaceSpatialArchives(measured: nil, virtual: nil, exterior: [])
                floorplanImageBeforePicker = nil
                persistLayout()
                refreshAudit(force: true)
            }
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: paywallDefaultProduct)
        }
        .sheet(isPresented: $showARSpatialSurvey) {
            // 相机闸门：另一个窗口正在用相机时不构造采集会话，改为提示卡。
            CameraExclusiveGate {
                ARSpatialSurveyView()
            }
        }
        .fullScreenCover(isPresented: $showVRSpatialSurvey) {
            // Start the simulation from the same room rectangles currently
            // visible in 户型立极.  Previously the VR editor always opened an
            // empty canvas, so its report could not represent the floorplan
            // the user had just edited.
            VRSpatialSurveyView(
                initialFloorplanRooms: auditedRooms.isEmpty ? rooms : auditedRooms,
                initialWidthMeters: projectionDimensions.width,
                initialDepthMeters: projectionDimensions.height,
                initialCoordinateHeading: effectiveHeading,
                initialHouseFacingDegrees: houseFacingDegrees,
                initialCentroid: centroid
            )
        }
        .sheet(isPresented: $showReportShareSheet) {
            if let reportImage = exportedReportImage {
                FloorplanReportShareSheet(items: [reportImage])
            }
        }
        .sheet(isPresented: $show3DSpaceViewer) {
            if let s = persistedSpatialSurvey {
                House3DSpaceViewer(survey: s)
            }
        }
        .sheet(isPresented: $showVirtualSpaceViewer) {
            if let s = persistedVirtualSpatialSurvey {
                House3DSpaceViewer(survey: s)
            }
        }
        .sheet(isPresented: $showCurrentFloorplan3D) {
            if let s = currentFloorplanSurvey {
                House3DSpaceViewer(survey: s)
            }
        }
        .sheet(isPresented: $showCaseArchiveSheet) {
            caseArchiveSheetView()
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            // Keep the user's room geometry while refreshing language-dependent
            // sample labels and diagnostics.
            let previousRooms = rooms
            // Preserve every custom room, including rooms added by the user.
            // Rebuilding from the eight-room demo layout here used to delete
            // custom rooms whenever the app language changed.
            rooms = previousRooms.map { previousRoom in
                var updated = previousRoom
                updated.name = previousRoom.type.localizedName
                return updated
            }
            if let selectedID = selectedRoom?.id,
               let refreshedRoom = rooms.first(where: { $0.id == selectedID }) {
                selectedRoom = refreshedRoom
            }
            refreshAudit(force: true)
        }
        .onAppear {
            restorePersistedLayoutIfNeeded()
            refreshAudit(force: true)
        }
        .onDisappear {
            reportExportGeneration &+= 1
            // Vision callbacks may finish after the page is dismissed. The
            // generation guard below prevents a late result from mutating a
            // layout that is no longer on screen.
            roomDetectionGeneration &+= 1
            isDetectingRooms = false
        }
        .onChange(of: isActive) { active in
            if active {
                refreshAudit(force: true)
            } else {
                reportExportGeneration &+= 1
                roomDetectionGeneration &+= 1
                isDetectingRooms = false
            }
        }
        .onReceive(Self.auditClock) { date in
            refreshAudit(date: date)
        }
        .onChange(of: motion.currentSolarTermName) { _ in refreshAudit() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshAudit(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshAudit(force: true)
        }
        .onReceive(UserKuaProfileManager.shared.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            refreshAudit(force: true)
        }
        .onChange(of: effectiveHeading) { _ in
            refreshAudit()
        }
        .onChange(of: centroid) { _ in
            refreshAudit()
        }
        .onChange(of: calibratedWidthText) { _ in
            persistLayout()
            refreshAudit(force: true)
        }
        .onChange(of: calibratedDepthText) { _ in
            persistLayout()
            refreshAudit(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            persistLayout()
        }
        .onReceive(workspaceStore.$snapshot.receive(on: DispatchQueue.main)) { snapshot in
            guard snapshot.revision > workspaceRevision,
                  snapshot.revision == workspaceStore.snapshot.revision else { return }
            guard snapshot.writerID != workspaceWriterID else {
                workspaceRevision = snapshot.revision
                return
            }
            guard didRestorePersistedLayout else { return }
            applyWorkspaceSnapshot(snapshot)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateHouseSpatialSurvey)) { _ in
            // A VR correction updates the 3D archive but has no authority to
            // replace the editable floorplan layout. Keep the current rooms
            // and only refresh the “最近实测/VR 3D” snapshot button.
            reloadSpatialSurveyArchives()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateMeasuredSpatialSurvey)) { _ in
            reloadSpatialSurveyArchives()
        }
    }

    @discardableResult
    public static func persistRoomPlanImport(
        rooms: [FloorplanRoom],
        centroid: CGPoint,
        blueprintImage: UIImage?,
        compassHeading: Double? = nil,
        spatialSurvey: HouseSpatialSurvey? = nil
    ) -> Bool {
        let sanitizedRooms = rooms.map { sanitizedRoom($0) }
        let resolvedHeading = compassHeading.map { normalizedHeading($0) } ?? CompassMotionManager.shared.headingState.facingAngle
        let previousGrant: (Bool, String?, String?) = {
            guard let data = UserDefaults.standard.data(forKey: savedLayoutKey),
                  let previous = try? JSONDecoder().decode(SavedFloorplanLayout.self, from: data),
                  previous.hasFloorplanAccess,
                  let grantID = previous.floorplanAccessGrantID,
                  !grantID.isEmpty else {
                return (false, nil, nil)
            }
            if let grantSignature = previous.floorplanAccessGrantSignature {
                let grant = FloorplanAccessGrant(id: grantID, signature: grantSignature)
                guard StoreKitIAPManager.shared.validateFloorplanAccessGrant(grant) else {
                    return (false, nil, nil)
                }
                return (true, grantID, grantSignature)
            }
            // One-time migration for layouts written before grants were
            // signed. The old grant was already created only after a local
            // credit debit; re-seal it immediately for subsequent writes.
            let migrated = StoreKitIAPManager.shared.issueFloorplanAccessGrant()
            return (true, migrated.id, migrated.signature)
        }()
        let saved = SavedFloorplanLayout(
            rooms: sanitizedRooms,
            centroidX: Double(clampedUnit(Double(centroid.x), fallback: 0.5)),
            centroidY: Double(clampedUnit(Double(centroid.y), fallback: 0.5)),
            compassRotation: resolvedHeading,
            isSyncWithCompass: compassHeading == nil,
            // RoomPlan/AR spatial capture is free measurement. If the user
            // already paid for the active case, carry that one-case grant to
            // the newly imported geometry instead of charging twice. A fresh
            // install with no grant remains locked until acquireFloorplanAccess.
            hasFloorplanAccess: previousGrant.0,
            floorplanAccessGrantID: previousGrant.1,
            floorplanAccessGrantSignature: previousGrant.2,
            aspectRatio: blueprintImage.map { Double($0.size.width / max(1, $0.size.height)) },
            houseFacingDegrees: spatialSurvey?.resolvedHouseFacing
        )
        do {
            try FloorplanWorkspaceStore.shared.save(layout: saved, image: blueprintImage, writerID: UUID())
            ShaSurveyStore.shared.replaceProperty(measured: spatialSurvey, virtual: nil,
                                                  exterior: ShaSurveyStore.shared.records)
            NotificationCenter.default.post(name: .didUpdateMeasuredSpatialSurvey, object: nil)
            return true
        } catch {
            print("Unable to import floorplan: \(error.localizedDescription)")
            return false
        }
    }

    /// Restore the last editable plan once per view lifetime. Room geometry is
    /// normalized on load so a corrupted or stale local record cannot place a
    /// room outside the canvas or produce invalid SwiftUI frames.
    private func restorePersistedLayoutIfNeeded() {
        guard !didRestorePersistedLayout else { return }
        didRestorePersistedLayout = true
        applyWorkspaceSnapshot(workspaceStore.snapshot)
    }

    private func applyWorkspaceSnapshot(_ snapshot: FloorplanWorkspaceSnapshot) {
        workspaceRevision = snapshot.revision
        roomDetectionGeneration &+= 1
        reportExportGeneration &+= 1
        isDetectingRooms = false
        roomsBeforeDetection = nil
        centroidBeforeDetection = nil
        selectedRoom = nil
        selectedEditingRoomID = nil
        roomForTypeEditing = nil
        currentFloorplanSurvey = nil
        exportedReportImage = nil
        reloadSpatialSurveyArchives()
        guard let saved = snapshot.layout else { return }
        var restoredIDs = Set<String>()
        let restoredRooms = saved.rooms.map { room -> FloorplanRoom in
            var restored = Self.sanitizedRoom(room)
            // UserDefaults can contain records written by older builds or
            // imported data with an empty/duplicated identifier. SwiftUI's
            // ForEach and the edit/delete actions both rely on these IDs, so
            // repair them before the layout enters live state.
            var roomID = restored.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if roomID.isEmpty || restoredIDs.contains(roomID) {
                repeat { roomID = UUID().uuidString } while restoredIDs.contains(roomID)
            }
            restored.id = roomID
            restoredIDs.insert(roomID)
            // Room labels are generated from the selected type, so restore
            // them in the current app language instead of showing text from
            // the language used when the layout was saved.
            restored.name = restored.type.localizedName
            return restored
        }
        rooms = restoredRooms
        centroid = CGPoint(
            x: Self.clampedUnit(saved.centroidX, fallback: 0.5),
            y: Self.clampedUnit(saved.centroidY, fallback: 0.5)
        )
        compassRotation = Self.normalizedHeading(saved.compassRotation)
        isSyncWithCompass = saved.isSyncWithCompass
        let savedFacing = saved.houseFacingDegrees ?? persistedSpatialSurvey?.resolvedHouseFacing ?? persistedVirtualSpatialSurvey?.resolvedHouseFacing
        houseFacingOffset = FloorplanOrientation(coordinateHeading: saved.compassRotation,
                                                houseFacingDegrees: savedFacing).relativeFacing
        restoreDimensions(saved)
        if saved.hasFloorplanAccess, let grantID = saved.floorplanAccessGrantID {
            if let grantSignature = saved.floorplanAccessGrantSignature,
               iap.validateFloorplanAccessGrant(FloorplanAccessGrant(id: grantID, signature: grantSignature)) {
                floorplanAccessGrantID = grantID
                floorplanAccessGrantSignature = grantSignature
                didConsumeFloorplanCredit = true
            } else if saved.floorplanAccessGrantSignature == nil {
                // Migrate one legacy unsigned grant and persist the signed
                // replacement below. Invalid signed data remains locked.
                let migrated = iap.issueFloorplanAccessGrant()
                floorplanAccessGrantID = migrated.id
                floorplanAccessGrantSignature = migrated.signature
                didConsumeFloorplanCredit = true
            } else {
                floorplanAccessGrantID = nil
                floorplanAccessGrantSignature = nil
                didConsumeFloorplanCredit = false
            }
        } else {
            floorplanAccessGrantID = nil
            floorplanAccessGrantSignature = nil
            didConsumeFloorplanCredit = false
        }

        userFloorplanImage = snapshot.image
        // Only migrations write back. Replaying a shared snapshot must not
        // autosave a newer live heading and start a cross-window feedback loop.
        if (saved.hasFloorplanAccess && saved.floorplanAccessGrantSignature == nil)
            || (saved.houseFacingDegrees == nil && savedFacing != nil) {
            persistLayout()
        }
        refreshAudit(force: true)
    }

    /// Reads both archive slots and migrates the pre-split format where a VR
    /// report could have been written into the measured key. Keeping one
    /// canonical entry prevents duplicate 3D buttons after an app upgrade.
    private func reloadSpatialSurveyArchives() {
        persistedSpatialSurvey = nil
        persistedVirtualSpatialSurvey = nil
        if let sData = UserDefaults.standard.data(forKey: SpatialSurveyArchiveKeys.measured),
           let s = try? JSONDecoder().decode(HouseSpatialSurvey.self, from: sData) {
            let isVirtual = s.scanMethod.localizedCaseInsensitiveContains("VR") || s.scanMethod.contains("仿真")
            if isVirtual {
                if UserDefaults.standard.data(forKey: SpatialSurveyArchiveKeys.virtual) == nil,
                   let data = try? JSONEncoder().encode(s) {
                    UserDefaults.standard.set(data, forKey: SpatialSurveyArchiveKeys.virtual)
                }
                UserDefaults.standard.removeObject(forKey: SpatialSurveyArchiveKeys.measured)
                persistedVirtualSpatialSurvey = s
            } else {
                persistedSpatialSurvey = s
            }
        }
        if let sData = UserDefaults.standard.data(forKey: SpatialSurveyArchiveKeys.virtual),
           let s = try? JSONDecoder().decode(HouseSpatialSurvey.self, from: sData) {
            persistedVirtualSpatialSurvey = s
        }
    }

    private func replaceSpatialArchives(measured: HouseSpatialSurvey?, virtual: HouseSpatialSurvey?, exterior: [ExteriorShaRecord]) {
        reportExportGeneration &+= 1
        ShaSurveyStore.shared.replaceProperty(measured: measured, virtual: virtual, exterior: exterior)
        persistedSpatialSurvey = measured
        persistedVirtualSpatialSurvey = virtual
        currentFloorplanSurvey = nil
        exportedReportImage = nil
        FloorplanAuditStore.shared.clear()
        NotificationCenter.default.post(name: .didUpdateMeasuredSpatialSurvey, object: nil)
    }

    private func restoreDimensions(_ layout: SavedFloorplanLayout) {
        restoredAspectRatio = layout.aspectRatio.flatMap { $0.isFinite && $0 > 0 ? CGFloat($0) : nil } ?? 1
        calibratedWidthText = layout.widthMeters.flatMap { $0.isFinite && $0 > 0 ? String($0) : nil } ?? ""
        calibratedDepthText = layout.depthMeters.flatMap { $0.isFinite && $0 > 0 ? String($0) : nil } ?? ""
    }

    /// Keep the image outside UserDefaults and store only the small editable
    /// layout model there. This avoids a large synchronous defaults write when
    /// a user imports a camera photo or a high-resolution floor plan.
    private func persistLayout() {
        let saved = SavedFloorplanLayout(
            rooms: rooms,
            centroidX: Double(centroid.x),
            centroidY: Double(centroid.y),
            compassRotation: Self.normalizedHeading(effectiveHeading),
            isSyncWithCompass: isSyncWithCompass,
            hasFloorplanAccess: didConsumeFloorplanCredit
                && floorplanAccessGrantID != nil
                && floorplanAccessGrantSignature != nil,
            floorplanAccessGrantID: floorplanAccessGrantID,
            floorplanAccessGrantSignature: floorplanAccessGrantSignature,
            aspectRatio: Double(floorplanAspectRatio),
            widthMeters: calibratedWidthMeters.map { Double($0) },
            depthMeters: calibratedDepthMeters.map { Double($0) },
            houseFacingDegrees: houseFacingDegrees
        )
        guard didRestorePersistedLayout else { return }
        do {
            let accepted = try workspaceStore.save(layout: saved, image: userFloorplanImage,
                                                    writerID: workspaceWriterID, expectedRevision: workspaceRevision)
            if accepted { workspaceRevision = workspaceStore.snapshot.revision }
            else { applyWorkspaceSnapshot(workspaceStore.snapshot) }
        } catch {
            caseBackupToastMessage = lang.t("save_failed")
        }
    }

    private static func savedImageURL() -> URL? { FloorplanWorkspaceStore.shared.imageURL }

    private static func caseImageURL(fileName: String) -> URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try? FloorplanCaseAssets.imageURL(fileName: fileName, directory: directory)
    }

    private var archiveButtonTitle: String {
        let base: String
        switch lang.effectiveLanguage {
        case .en: base = "Cases"
        case .zhHant: base = "宅譜庫"
        case .ja: base = "宅譜庫"
        case .ko: base = "택보함"
        case .vi: base = "Hồ Sơ"
        case .th: base = "คลังผัง"
        case .id: base = "Arsip"
        case .auto, .zhHans: base = "宅谱库"
        }
        return savedCases.isEmpty ? base : "\(base)(\(savedCases.count))"
    }

    private func saveCurrentCaseToArchive(customTitle: String) {
        let caseID = UUID().uuidString
        let trimmed = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let sittingText = "\(floorplanHeadingState.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(floorplanHeadingState.facingMountain.localizedName)\(lang.t("facing_suffix")) (\(String(format: "%.1f°", floorplanHeadingState.facingAngle)))"
        let df = DateFormatter()
        df.dateFormat = "MM-dd HH:mm"
        let resolvedTitle = trimmed.isEmpty ? "\(sittingText) · \(df.string(from: Date()))" : trimmed

        var imgFileName: String? = nil
        if let image = userFloorplanImage,
           let data = image.jpegData(compressionQuality: 0.82) ?? image.pngData() {
            let fname = "floorplan-case-\(caseID).jpg"
            guard let url = Self.caseImageURL(fileName: fname) else {
                caseBackupToastMessage = lang.t("save_failed")
                return
            }
            do {
                try data.write(to: url, options: .atomic)
                imgFileName = fname
            } catch {
                caseBackupToastMessage = lang.t("save_failed")
                return
            }
        }

        let currentLayout = SavedFloorplanLayout(
            rooms: rooms,
            centroidX: Double(centroid.x),
            centroidY: Double(centroid.y),
            compassRotation: Self.normalizedHeading(effectiveHeading),
            isSyncWithCompass: false,
            hasFloorplanAccess: didConsumeFloorplanCredit
                && floorplanAccessGrantID != nil
                && floorplanAccessGrantSignature != nil,
            floorplanAccessGrantID: floorplanAccessGrantID,
            floorplanAccessGrantSignature: floorplanAccessGrantSignature,
            aspectRatio: Double(floorplanAspectRatio),
            widthMeters: calibratedWidthMeters.map { Double($0) },
            depthMeters: calibratedDepthMeters.map { Double($0) },
            houseFacingDegrees: houseFacingDegrees
        )

        let record = FloorplanCaseRecord(
            id: caseID,
            title: resolvedTitle,
            createdAt: Date(),
            sittingSummary: sittingText,
            layout: currentLayout,
            imageFileName: imgFileName,
            spatialSurvey: persistedSpatialSurvey,
            virtualSpatialSurvey: persistedVirtualSpatialSurvey,
            exteriorRecords: ShaSurveyStore.shared.records
        )
        do { try caseStore.insert(record) }
        catch { caseBackupToastMessage = lang.t("save_failed"); return }
        RetentionServiceManager.shared.recordMilestone(reason: "save_floorplan_case")
    }

    private func loadCaseFromArchive(_ record: FloorplanCaseRecord) {
        workspaceRevision = workspaceStore.snapshot.revision
        roomDetectionGeneration &+= 1
        isDetectingRooms = false
        roomsBeforeDetection = nil
        centroidBeforeDetection = nil
        selectedRoom = nil
        selectedEditingRoomID = nil
        roomForTypeEditing = nil
        let saved = record.layout
        rooms = saved.rooms.map { r in
            var copy = Self.sanitizedRoom(r)
            copy.name = copy.type.localizedName
            return copy
        }
        centroid = CGPoint(
            x: Self.clampedUnit(saved.centroidX, fallback: 0.5),
            y: Self.clampedUnit(saved.centroidY, fallback: 0.5)
        )
        compassRotation = Self.normalizedHeading(saved.compassRotation)
        isSyncWithCompass = saved.isSyncWithCompass
        let savedFacing = saved.houseFacingDegrees ?? record.spatialSurvey?.resolvedHouseFacing ?? record.virtualSpatialSurvey?.resolvedHouseFacing
        houseFacingOffset = FloorplanOrientation(coordinateHeading: saved.compassRotation,
                                                houseFacingDegrees: savedFacing).relativeFacing
        restoreDimensions(saved)
        if saved.hasFloorplanAccess,
           let gID = saved.floorplanAccessGrantID,
           let gSig = saved.floorplanAccessGrantSignature,
           iap.validateFloorplanAccessGrant(FloorplanAccessGrant(id: gID, signature: gSig)) {
            floorplanAccessGrantID = gID
            floorplanAccessGrantSignature = gSig
            didConsumeFloorplanCredit = true
        } else {
            floorplanAccessGrantID = nil
            floorplanAccessGrantSignature = nil
            didConsumeFloorplanCredit = false
        }

        if let fname = record.imageFileName,
           let url = Self.caseImageURL(fileName: fname),
           let img = UIImage(contentsOfFile: url.path) {
            userFloorplanImage = img
        } else {
            userFloorplanImage = nil
        }

        // Older records stored a VR model in the only available survey field.
        let legacyIsVirtual = record.spatialSurvey.map {
            $0.scanMethod.localizedCaseInsensitiveContains("VR") || $0.scanMethod.contains("仿真")
        } ?? false
        replaceSpatialArchives(
            measured: legacyIsVirtual ? nil : record.spatialSurvey,
            virtual: record.virtualSpatialSurvey ?? (legacyIsVirtual ? record.spatialSurvey : nil),
            exterior: record.exteriorRecords ?? []
        )

        persistLayout()
        refreshAudit(force: true)
    }

    private func exportCaseJSONToClipboard(_ record: FloorplanCaseRecord) {
        guard let directory = Self.savedImageURL()?.deletingLastPathComponent(),
              let data = try? FloorplanCaseAssets.backup(record, directory: directory),
              let jsonStr = String(data: data, encoding: .utf8) else {
            caseBackupToastMessage = lang.t("save_failed")
            return
        }
        UIPasteboard.general.string = jsonStr
        switch lang.effectiveLanguage {
        case .en: caseBackupToastMessage = "Copied case JSON backup to clipboard"
        case .zhHant: caseBackupToastMessage = "已複製該宅譜 JSON 備份至剪貼簿"
        case .ja: caseBackupToastMessage = "宅譜 JSON バックアップをコピーしました"
        case .ko: caseBackupToastMessage = "택보 JSON 백업을 클립보드에 복사했습니다"
        case .vi: caseBackupToastMessage = "Đã sao chép JSON hồ sơ vào bộ nhớ tạm"
        case .th: caseBackupToastMessage = "คัดลอกข้อมูลสำรอง JSON ไปยังคลิปบอร์ดแล้ว"
        case .id: caseBackupToastMessage = "JSON cadangan arsip disalin ke papan klip"
        case .auto, .zhHans: caseBackupToastMessage = "已复制该宅谱 JSON 备份至剪贴板"
        }
    }

    private func importCaseJSONFromClipboard() {
        guard let raw = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              let data = raw.data(using: .utf8),
              let directory = Self.savedImageURL()?.deletingLastPathComponent(),
              let decoded = try? FloorplanCaseAssets.importBackup(data, existingIDs: Set(savedCases.map { $0.id }), directory: directory) else {
            switch lang.effectiveLanguage {
            case .en: caseBackupToastMessage = "Clipboard does not contain valid Case JSON"
            case .zhHant: caseBackupToastMessage = "剪貼簿中未檢測到有效的宅譜 JSON 數據"
            case .ja: caseBackupToastMessage = "クリップボードに有効な宅譜 JSON がありません"
            case .ko: caseBackupToastMessage = "클립보드에 유효한 택보 JSON이 없습니다"
            case .vi: caseBackupToastMessage = "Bộ nhớ tạm không có dữ liệu JSON hồ sơ hợp lệ"
            case .th: caseBackupToastMessage = "ไม่พบข้อมูล JSON ผังบ้านที่ถูกต้องในคลิปบอร์ด"
            case .id: caseBackupToastMessage = "Papan klip tidak berisi JSON arsip yang valid"
            case .auto, .zhHans: caseBackupToastMessage = "剪贴板中未检测到有效的宅谱 JSON 数据"
            }
            return
        }
        do { try caseStore.insert(decoded) }
        catch { caseBackupToastMessage = lang.t("save_failed"); return }
        switch lang.effectiveLanguage {
        case .en: caseBackupToastMessage = "Imported case: \(decoded.title)"
        case .zhHant: caseBackupToastMessage = "已成功導入宅譜：\(decoded.title)"
        case .ja: caseBackupToastMessage = "宅譜をインポートしました：\(decoded.title)"
        case .ko: caseBackupToastMessage = "택보 가져오기 완료: \(decoded.title)"
        case .vi: caseBackupToastMessage = "Đã nhập hồ sơ: \(decoded.title)"
        case .th: caseBackupToastMessage = "นำเข้าแฟ้มสำเร็จ: \(decoded.title)"
        case .id: caseBackupToastMessage = "Arsip berhasil diimpor: \(decoded.title)"
        case .auto, .zhHans: caseBackupToastMessage = "已成功导入宅谱：\(decoded.title)"
        }
    }

    private func deleteCaseFromArchive(_ record: FloorplanCaseRecord) {
        guard let directory = Self.savedImageURL()?.deletingLastPathComponent() else { return }
        do { try caseStore.remove(id: record.id, imageDirectory: directory) }
        catch { caseBackupToastMessage = lang.t("save_failed") }
    }

    private func caseArchiveSheetView() -> some View {
        let sheetTitle: String
        let placeholder: String
        let saveBtnTitle: String
        let importBtnTitle: String
        let emptyTip: String
        let loadBtn: String
        switch lang.effectiveLanguage {
        case .en:
            sheetTitle = "Property & Floorplan Cases"
            placeholder = "Case Name (e.g. Home 120㎡)"
            saveBtnTitle = "Save Current Plan to Archive"
            importBtnTitle = "Import Case JSON from Clipboard"
            emptyTip = "No saved property cases yet. Save your current floorplan above so you can compare multiple properties without losing your paid unlock."
            loadBtn = "Load"
        case .zhHant:
            sheetTitle = "多套戶型宅譜檔案庫"
            placeholder = "輸入檔案名（如：萬科翡翠 120㎡）"
            saveBtnTitle = "保存當前戶型至宅譜庫"
            importBtnTitle = "從剪貼簿導入宅譜 JSON 備份"
            emptyTip = "暫無已存宅譜。點擊上方按鈕即可將當前戶型、房間布局、3D模型、立極坐向及單次解鎖憑證完整歸檔，方便多房源隨時切換對比。"
            loadBtn = "載入"
        case .ja:
            sheetTitle = "複数物件の間取り宅譜アーカイブ"
            placeholder = "物件名を入力（例：自宅 120㎡）"
            saveBtnTitle = "現在の間取りを宅譜庫に保存"
            importBtnTitle = "クリップボードから宅譜 JSON を読込"
            emptyTip = "保存された宅譜はありません。上のボタンから現在の間取り・部屋配置・3Dモデル・坐向・単回アンロック権限を保存し、複数物件を比較できます。"
            loadBtn = "読込"
        case .ko:
            sheetTitle = "다주택 평면도 택보 보관함"
            placeholder = "보관함 이름 입력 (예: 자택 120㎡)"
            saveBtnTitle = "현재 평면도를 택보함에 저장"
            importBtnTitle = "클립보드에서 택보 JSON 가져오기"
            emptyTip = "저장된 택보가 없습니다. 상단 버튼을 눌러 현재 평면도, 방 배치, 3D 모델, 좌향 및 단건 잠금해제 권한을 보관하고 여러 매물을 비교해 보세요."
            loadBtn = "불러오기"
        case .vi:
            sheetTitle = "Kho Hồ Sơ Mặt Bằng Nhiều Căn Hộ"
            placeholder = "Nhập tên hồ sơ (VD: Căn hộ 120㎡)"
            saveBtnTitle = "Lưu Mặt Bằng Hiện Tại Vào Kho"
            importBtnTitle = "Nhập Hồ Sơ JSON Từ Bộ Nhớ Tạm"
            emptyTip = "Chưa có hồ sơ nào. Nhấn nút phía trên để lưu mặt bằng, bố cục phòng, 3D, tọa hướng và quyền mở khóa để dễ dàng so sánh nhiều căn hộ."
            loadBtn = "Tải"
        case .th:
            sheetTitle = "คลังแฟ้มผังบ้านหลายหลัง"
            placeholder = "ตั้งชื่อแฟ้ม (เช่น บ้าน 120 ตร.ม.)"
            saveBtnTitle = "บันทึกผังปัจจุบันลงในคลัง"
            importBtnTitle = "นำเข้า JSON ผังบ้านจากคลิปบอร์ด"
            emptyTip = "ยังไม่มีแฟ้มที่บันทึกไว้ กดปุ่มด้านบนเพื่อบันทึกผังห้อง 3D ทิศทาง และสิทธิ์ปลดล็อก เพื่อสลับเปรียบเทียบหลายบ้านได้ทันที"
            loadBtn = "โหลด"
        case .id:
            sheetTitle = "Arsip Denah Multi-Properti"
            placeholder = "Nama Arsip (mis. Rumah 120㎡)"
            saveBtnTitle = "Simpan Denah Saat Ini ke Arsip"
            importBtnTitle = "Impor JSON Arsip dari Papan Klip"
            emptyTip = "Belum ada arsip tersimpan. Simpan denah, tata ruang, model 3D, arah, dan akses buka kunci Anda di atas untuk membandingkan beberapa properti."
            loadBtn = "Muat"
        case .auto, .zhHans:
            sheetTitle = "多套户型宅谱档案库"
            placeholder = "输入档案名（如：万科翡翠 120㎡）"
            saveBtnTitle = "保存当前户型至宅谱库"
            importBtnTitle = "从剪贴板导入宅谱 JSON 备份"
            emptyTip = "暂无已存宅谱。点击上方按钮即可将当前户型、房间布局、3D模型、立极坐向及单次解锁凭证完整归档，方便多房源随时切换对比。"
            loadBtn = "载入"
        }

        return NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.11).ignoresSafeArea()

                VStack(spacing: 14) {
                    VStack(spacing: 10) {
                        TextField(placeholder, text: $newCaseTitleInput)
                            .adaptiveFont(size: 13)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(8)

                        Button(action: {
                            saveCurrentCaseToArchive(customTitle: newCaseTitleInput)
                            newCaseTitleInput = ""
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "tray.and.arrow.down.fill")
                                Text(saveBtnTitle)
                            }
                            .adaptiveFont(size: 13, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color(red: 0.83, green: 0.68, blue: 0.21))
                            .foregroundColor(.black)
                            .cornerRadius(8)
                        }

                        Button(action: {
                            importCaseJSONFromClipboard()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.on.clipboard")
                                Text(importBtnTitle)
                            }
                            .adaptiveFont(size: 11, weight: .semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(Color.yanCyan)
                            .cornerRadius(8)
                        }

                        if let toast = caseBackupToastMessage {
                            Text(toast)
                                .adaptiveFont(size: 11, weight: .semibold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(14)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    if savedCases.isEmpty {
                        Spacer()
                        Text(emptyTip)
                            .adaptiveFont(size: 13)
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                // P3.4 多套房源 PK 横向对比矩阵（选房/租房比对神器）
                                propertyComparisonPKCard()

                                ForEach(savedCases) { item in
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(item.title)
                                                    .adaptiveFont(size: 14, weight: .bold)
                                                    .foregroundColor(.white)
                                                if item.spatialSurvey != nil || item.virtualSpatialSurvey != nil {
                                                    Text("3D")
                                                        .adaptiveFont(size: 9, weight: .bold)
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 1.5)
                                                        .background(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.22))
                                                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                                        .cornerRadius(4)
                                                }
                                            }
                                            Text("\(item.sittingSummary) · \(item.layout.rooms.count) Rooms")
                                                .adaptiveFont(size: 11)
                                                .foregroundColor(Color.yanCyan)
                                        }
                                        Spacer()
                                        Button(action: {
                                            loadCaseFromArchive(item)
                                            showCaseArchiveSheet = false
                                        }) {
                                            Text(loadBtn)
                                                .adaptiveFont(size: 12, weight: .bold)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.yanCyan.opacity(0.2))
                                                .foregroundColor(Color.yanCyan)
                                                .cornerRadius(6)
                                        }
                                        Button(action: {
                                            exportCaseJSONToClipboard(item)
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 13))
                                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                                .padding(6)
                                        }
                                        Button(action: {
                                            deleteCaseFromArchive(item)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 13))
                                                .foregroundColor(.red.opacity(0.85))
                                                .padding(6)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                                    .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(sheetTitle)
                        .adaptiveFont(size: 15, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(lang.t("done")) {
                        showCaseArchiveSheet = false
                    }
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - P3.4 多套房源 PK 横向对比矩阵（选房/租房比对神器）
    private struct PropertyPKMetric: Identifiable {
        let id: String
        let title: String
        let sittingText: String
        let score: Int
        let isKuaMatch: Bool
        let kuaBadge: String
        let auspiciousCount: Int
        let shaCount: Int
        let isCurrent: Bool
    }

    private func evaluatePKMetric(id: String, title: String, rooms: [FloorplanRoom], centroid: CGPoint, heading: Double, aspectRatio: CGFloat, isCurrent: Bool) -> PropertyPKMetric {
        let audit = FloorplanEngine.shared.auditFloorplan(rooms: rooms, centroid: centroid, heading: heading, aspectRatio: aspectRatio)
        let sitAngle = (heading + 180.0).truncatingRemainder(dividingBy: 360.0)
        let sitMtn = Mountain24Data.shared.mountain(for: sitAngle < 0 ? sitAngle + 360.0 : sitAngle)
        let faceMtn = Mountain24Data.shared.mountain(for: Self.normalizedHeading(heading))
        let compat = UserKuaProfileManager.shared.evaluateCompatibility(sittingPalace: sitMtn.palace)
        let ausp = audit.report.filter { $0.isGood }.count
        let warn = audit.report.filter { $0.isWarning }.count
        let sev  = audit.report.filter { $0.isSevere }.count
        let rawScore = 82 + ausp * 4 - warn * 5 - sev * 11 + (compat.isMatchedWithHouse ? 8 : -4)
        let clampedScore = max(38, min(99, rawScore))
        let sitLabel = "\(sitMtn.localizedName)\(lang.t("mountain_suffix"))\(faceMtn.localizedName)\(lang.t("facing_suffix"))"
        return PropertyPKMetric(
            id: id,
            title: title,
            sittingText: sitLabel,
            score: clampedScore,
            isKuaMatch: compat.isMatchedWithHouse,
            kuaBadge: compat.matchBadgeTitle,
            auspiciousCount: ausp,
            shaCount: warn + sev,
            isCurrent: isCurrent
        )
    }

    private func propertyComparisonPKCard() -> some View {
        let currentTitle: String = {
            switch lang.effectiveLanguage {
            case .en: return "Current Plan"
            case .zhHant: return "當前正在勘測戶型"
            case .ja: return "現在の間取り"
            case .ko: return "현재 평면도"
            case .vi: return "Mặt bằng hiện tại"
            case .th: return "ผังปัจจุบัน"
            case .id: return "Denah Saat Ini"
            case .auto, .zhHans: return "当前正在勘测户型"
            }
        }()
        let pkHeaderTitle: String = {
            switch lang.effectiveLanguage {
            case .en: return "Multi-Property Feng Shui PK Matrix"
            case .zhHant: return "多套房源堪輿 PK 橫向比對榜"
            case .ja: return "複数物件・風水 PK 比較マトリクス"
            case .ko: return "다주택 풍수 PK 비교 매트릭스"
            case .vi: return "Bảng So Sánh PK Phong Thủy Nhiều Căn Hộ"
            case .th: return "ตารางเปรียบเทียบฮวงจุ้ยหลายบ้าน (PK)"
            case .id: return "Matriks Perbandingan PK Multi-Properti"
            case .auto, .zhHans: return "多套房源堪舆 PK 横向比对榜"
            }
        }()
        let bestTag: String = {
            switch lang.effectiveLanguage {
            case .en: return "TOP PICK"
            case .zhHant: return "首選推薦"
            case .ja: return "最優秀物件"
            case .ko: return "최우선 추천"
            case .vi: return "ƯU TIÊN SỐ 1"
            case .th: return "แนะนำอันดับ 1"
            case .id: return "PILIHAN UTAMA"
            case .auto, .zhHans: return "首选吉宅"
            }
        }()

        let currentMetric = evaluatePKMetric(
            id: "current_live",
            title: currentTitle,
            rooms: rooms,
            centroid: centroid,
            heading: effectiveHeading,
            aspectRatio: floorplanAspectRatio,
            isCurrent: true
        )
        let archivedMetrics = savedCases.prefix(5).map { rec in
            evaluatePKMetric(
                id: rec.id,
                title: rec.title,
                rooms: rec.layout.rooms,
                centroid: CGPoint(x: rec.layout.centroidX, y: rec.layout.centroidY),
                heading: rec.layout.compassRotation,
                aspectRatio: Self.aspectRatio(for: rec),
                isCurrent: false
            )
        }
        let allMetrics = ([currentMetric] + archivedMetrics).sorted { $0.score > $1.score }
        let topId = allMetrics.first?.id

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(pkHeaderTitle)
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
            }

            ForEach(allMetrics) { m in
                let isTop = m.id == topId
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(m.title)
                                .adaptiveFont(size: 12, weight: .bold)
                                .foregroundColor(m.isCurrent ? Color.yanCyan : .white)
                                .lineLimit(1)
                            if isTop {
                                Text(bestTag)
                                    .adaptiveFont(size: 8, weight: .bold)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.green.opacity(0.25))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                        HStack(spacing: 6) {
                            Text(m.sittingText)
                                .adaptiveFont(size: 10)
                                .foregroundColor(.white.opacity(0.7))
                            Text(m.kuaBadge)
                                .adaptiveFont(size: 9, weight: .semibold)
                                .foregroundColor(m.isKuaMatch ? .green : .orange)
                            Text(pkCountSummaryText(auspicious: m.auspiciousCount, sha: m.shaCount))
                                .adaptiveFont(size: 9, design: .monospaced)
                                .foregroundColor(.white.opacity(0.65))
                        }
                    }
                    Spacer()
                    Text("\(m.score)")
                        .adaptiveFont(size: 18, weight: .bold, design: .monospaced)
                        .foregroundColor(isTop ? .green : Color(red: 0.95, green: 0.85, blue: 0.45))
                }
                .padding(8)
                .background(isTop ? Color.green.opacity(0.08) : Color.white.opacity(0.04))
                .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color(red: 0.11, green: 0.12, blue: 0.17))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.3), lineWidth: 1)
        )
    }

    private func pkCountSummaryText(auspicious: Int, sha: Int) -> String {
        switch lang.effectiveLanguage {
        case .en: return "Good \(auspicious) / Sha \(sha)"
        case .zhHant, .ja: return "吉\(auspicious) / 煞\(sha)"
        case .ko: return "길\(auspicious) / 살\(sha)"
        case .vi: return "Cát \(auspicious) / Sát \(sha)"
        case .th: return "มงคล \(auspicious) / พิฆาต \(sha)"
        case .id: return "Baik \(auspicious) / Sha \(sha)"
        case .auto, .zhHans: return "吉\(auspicious) / 煞\(sha)"
        }
    }

    private static func clampedUnit(_ value: Double, fallback: Double) -> CGFloat {
        guard value.isFinite else { return CGFloat(fallback) }
        return CGFloat(max(0.0, min(1.0, value)))
    }

    private static func normalizedHeading(_ value: Double) -> Double {
        guard value.isFinite else { return 0.0 }
        let normalized = value.truncatingRemainder(dividingBy: 360.0)
        return normalized >= 0 ? normalized : normalized + 360.0
    }

    private static func sanitizedRoom(_ room: FloorplanRoom) -> FloorplanRoom {
        var result = room
        let width = room.rect.width.isFinite ? max(0.04, min(1.0, room.rect.width)) : 0.2
        let height = room.rect.height.isFinite ? max(0.04, min(1.0, room.rect.height)) : 0.2
        let x = room.rect.origin.x.isFinite ? room.rect.origin.x : 0.0
        let y = room.rect.origin.y.isFinite ? room.rect.origin.y : 0.0
        result.rect = CGRect(
            x: max(0.0, min(1.0 - width, x)),
            y: max(0.0, min(1.0 - height, y)),
            width: width,
            height: height
        )
        return result
    }

    /// Keep an already-presented room sheet aligned with the same audit input
    /// used by the canvas and report list. Without this, rotating the compass
    /// or dragging the Tai Ji point updated the page behind the sheet while
    /// the detail card continued to show stale palace/severity text.
    private func refreshAudit(force: Bool = false, date: Date = Date()) {
        guard isActive else { return }
        let timeKey = FloorplanAuditTimeKey(date: date)
        if !force, lastAuditTimeKey == timeKey,
           let previousHeading = lastAuditedHeading,
           let previousCentroid = lastAuditedCentroid {
            let rawHeadingDelta = abs(effectiveHeading - previousHeading)
            let headingDelta = min(rawHeadingDelta, 360.0 - rawHeadingDelta)
            let centroidDX = Double(centroid.x - previousCentroid.x)
            let centroidDY = Double(centroid.y - previousCentroid.y)
            let centroidDelta = sqrt(centroidDX * centroidDX + centroidDY * centroidDY)
            // Room palace assignments only change at 45° boundaries. A
            // sub-degree gate keeps sensor noise and tiny Tai Ji drags from
            // rebuilding every report row while the live overlay remains
            // responsive.
            if headingDelta < 0.5 && centroidDelta < 0.005 {
                return
            }
        }
        let result = FloorplanEngine.shared.auditFloorplan(
            rooms: rooms,
            centroid: centroid,
            heading: effectiveHeading,
            aspectRatio: floorplanAspectRatio,
            date: date
        )
        auditedRooms = result.auditedRooms
        auditReport = result.report
        FloorplanAuditStore.shared.update(result.report)
        lastAuditTimeKey = timeKey
        lastAuditedHeading = effectiveHeading
        lastAuditedCentroid = centroid
        if let selectedID = selectedRoom?.id {
            selectedRoom = result.auditedRooms.first(where: { $0.id == selectedID })
        }
    }

    private var hasFloorplanAccess: Bool {
        iap.hasUnlockedVIP || didConsumeFloorplanCredit
    }

    private static func aspectRatio(for record: FloorplanCaseRecord) -> CGFloat {
        if let ratio = record.layout.aspectRatio, ratio.isFinite, ratio > 0 { return CGFloat(ratio) }
        if let name = record.imageFileName, let url = caseImageURL(fileName: name),
           let image = UIImage(contentsOfFile: url.path), image.size.height > 0 {
            return image.size.width / image.size.height
        }
        return 1
    }

    private func acquireFloorplanAccess() -> Bool {
        if iap.hasUnlockedVIP || didConsumeFloorplanCredit { return true }
        guard iap.consumeFloorplanCredit() else {
            paywallDefaultProduct = .floorplanSingle
            showPaywall = true
            return false
        }
        didConsumeFloorplanCredit = true
        let grant = iap.issueFloorplanAccessGrant()
        floorplanAccessGrantID = grant.id
        floorplanAccessGrantSignature = grant.signature
        persistLayout()
        return true
    }
    
    // MARK: - 顶栏控制
    private func topControlBar() -> some View {
        // 横向按钮组理想宽度很大，与标题同层 HStack 时会把标题压成竖排单字。
        // 改为纵向：标题 / 副标题 / 按钮组各占整行，按钮组仍可横向滚动。
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("floorplan_title"))
                    .adaptiveFont(size: 15, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(lang.t("floorplan_current_facing"))\(String(format: "%.1f", floorplanHeadingState.facingAngle))° (\(floorplanHeadingState.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(floorplanHeadingState.facingMountain.localizedName)\(lang.t("facing_suffix")))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
            // AR 空间测绘 / RoomPlan 扫描快速入口 (全景形煞AR实测免费开放)
            Button(action: {
                showARSpatialSurvey = true
            }) {
                Image(systemName: "viewfinder")
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(6)
                    .background(Color(red: 0.95, green: 0.80, blue: 0.25).opacity(0.22))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .cornerRadius(6)
            }
            .accessibilityLabel(lang.t("ar_spatial_survey"))
            
            // 导入真实户型图纸
            Button(action: {
                // An already purchased case remains editable until the user
                // starts a different case. Keep the picker available even
                // after its single credit has been consumed so replacing the
                // background does not incorrectly send the user back to the
                // paywall.
                if hasFloorplanAccess || iap.floorplanCreditsCount > 0 {
                    floorplanImageBeforePicker = userFloorplanImage
                    showImagePicker = true
                } else {
                    paywallDefaultProduct = .floorplanSingle
                    showPaywall = true
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "photo.badge.plus")
                    Text(userFloorplanImage == nil ? lang.t("import_plan") : lang.t("change_plan"))
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color.yanCyan.opacity(0.2))
                .foregroundColor(Color.yanCyan)
                .cornerRadius(6)
            }
            
            // P1.2 多套户型宅谱档案库按钮
            Button(action: {
                showCaseArchiveSheet = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "folder.fill.badge.plus")
                    Text(archiveButtonTitle)
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.22))
                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                .cornerRadius(6)
            }

            Button(action: {
                showResetConfirmation = true
            }) {
                Text(lang.t("reset_sample"))
                    .adaptiveFont(size: 10)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            
            // 罗盘联动 / 手动微调
            Button(action: {
                // Capture the live heading before leaving sync mode so the
                // manual slider starts at the direction the user is actually
                // measuring instead of falling back to zero degrees.
                if isSyncWithCompass {
                    compassRotation = motion.headingState.facingAngle
                }
                isSyncWithCompass.toggle()
                persistLayout()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: isSyncWithCompass ? "location.fill" : "hand.draw.fill")
                    Text(isSyncWithCompass ? lang.t("floorplan_sync_compass") : lang.t("floorplan_manual_tune"))
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(isSyncWithCompass ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                .foregroundColor(isSyncWithCompass ? .green : .orange)
                .cornerRadius(6)
            }

            // 导入户型图后，可手动把示例房间框调整到真实房间位置。
            Button(action: {
                isEditingRooms.toggle()
                activeRoomDragID = nil
                activeRoomStartRect = nil
                activeRoomScaleID = nil
                activeRoomScaleStartRect = nil
                roomWasDragged = false
                if !isEditingRooms {
                    selectedEditingRoomID = nil
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: isEditingRooms ? "checkmark.circle.fill" : "rectangle.3.group")
                    Text(lang.t(isEditingRooms ? "floorplan_finish_rooms" : "floorplan_edit_rooms"))
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(isEditingRooms ? Color.green.opacity(0.25) : Color.white.opacity(0.1))
                .foregroundColor(isEditingRooms ? .green : .white)
                .cornerRadius(6)
            }
            
            // Always build this view from the rooms currently shown in 户型立极.
            // The previous button opened the last persisted AR/VR snapshot,
            // which could belong to a different floorplan.
            Button(action: {
                if !iap.hasUnlockedVIP {
                    paywallDefaultProduct = .vipYearly
                    showPaywall = true
                    return
                }
                guard let survey = buildCurrentFloorplanSurvey() else { return }
                currentFloorplanSurvey = survey
                // Make the exact snapshot shown by this button available to
                // 福宅天机长卷 and the AR archive while keeping its推演来源标记.
                ShaSurveyStore.shared.updateInterior(survey)
                showCurrentFloorplan3D = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: iap.hasUnlockedVIP ? "cube.transparent" : "lock.fill")
                    Text(lang.t("floorplan_3d_current"))
                    if !iap.hasUnlockedVIP {
                        Text(lang.t("vip_badge_title"))
                            .adaptiveFont(size: 8, weight: .bold)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.yellow.opacity(0.3))
                            .foregroundColor(.yellow)
                            .cornerRadius(3)
                    }
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color.yanGold.opacity(0.85))
                .foregroundColor(.black)
                .cornerRadius(6)
            }

            if let survey = persistedSpatialSurvey {
                let isVR = survey.scanMethod.contains("VR") || survey.scanMethod.contains("仿真")
                Button(action: {
                    if isVR && !iap.hasUnlockedVIP {
                        paywallDefaultProduct = .vipYearly
                        showPaywall = true
                        return
                    }
                    show3DSpaceViewer = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isVR && !iap.hasUnlockedVIP ? "lock.fill" : "cube.transparent")
                        Text(isVR ? lang.t("floorplan_3d_recent_vr") : lang.t("floorplan_3d_recent_actual"))
                        if isVR && !iap.hasUnlockedVIP {
                            Text(lang.t("vip_badge_title"))
                                .adaptiveFont(size: 8, weight: .bold)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.yellow.opacity(0.3))
                                .foregroundColor(.yellow)
                                .cornerRadius(3)
                        }
                    }
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(Color.yanGold.opacity(0.85))
                    .foregroundColor(.black)
                    .cornerRadius(6)
                }
            }

            if persistedVirtualSpatialSurvey != nil {
                Button(action: {
                    if !iap.hasUnlockedVIP {
                        paywallDefaultProduct = .vipYearly
                        showPaywall = true
                        return
                    }
                    showVirtualSpaceViewer = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: iap.hasUnlockedVIP ? "view.3d" : "lock.fill")
                        Text(lang.t("floorplan_3d_recent_vr"))
                        if !iap.hasUnlockedVIP {
                            Text(lang.t("vip_badge_title"))
                                .adaptiveFont(size: 8, weight: .bold)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(3)
                        }
                    }
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.78))
                    .foregroundColor(.black)
                    .cornerRadius(6)
                }
            }

            // 户型图/手工房间编辑没有 RoomPlan 档案时，也应有明确的
            // 3D 入口。该入口是“按比例仿真”，不会冒充 LiDAR 实测结果。
            Button(action: {
                if !iap.hasUnlockedVIP {
                    paywallDefaultProduct = .vipYearly
                    showPaywall = true
                    return
                }
                showVRSpatialSurvey = true
            }) {
                HStack(spacing: 3) {
                    Image(systemName: iap.hasUnlockedVIP ? "view.3d" : "lock.fill")
                    Text(lang.t("vr_survey_title"))
                    if !iap.hasUnlockedVIP {
                        Text(lang.t("vip_badge_title"))
                            .adaptiveFont(size: 8, weight: .bold)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                    }
                }
                .adaptiveFont(size: 11, weight: .bold)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.78))
                .foregroundColor(.black)
                .cornerRadius(6)
            }
            .accessibilityLabel(lang.t("vr_survey_title"))

            // 重置立极点
            Button(action: {
                centroid = CGPoint(x: 0.5, y: 0.5)
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .adaptiveFont(size: 11)
                    .padding(5)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func roomDetectionBar() -> some View {
        HStack(spacing: 8) {
            Button(action: detectRoomLayout) {
                HStack(spacing: 4) {
                    Image(systemName: isDetectingRooms ? "hourglass" : "sparkles")
                    Text(lang.t("floorplan_auto_detect"))
                }
                .adaptiveFont(size: 10, weight: .bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.yanCyan.opacity(0.18))
                .foregroundColor(Color.yanCyan)
                .cornerRadius(6)
            }
            .disabled(isDetectingRooms)

            if isDetectingRooms {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .yanCyan))
                    .scaleEffect(0.7)
            }
            if let roomDetectionMessage = roomDetectionMessage {
                Text(roomDetectionMessage)
                    .adaptiveFont(size: 9)
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
            }
            if roomsBeforeDetection != nil {
                Button(action: undoRoomDetection) {
                    Text(lang.t("floorplan_undo_detect"))
                        .adaptiveFont(size: 9, weight: .bold)
                        .foregroundColor(.orange)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    /// 实测尺寸标定：输入开间/进深（米），估算真实户型面积
    private var estimatedAreaSqm: Double? {
        let width = Double(calibratedWidthText.replacingOccurrences(of: ",", with: "."))
        let depth = Double(calibratedDepthText.replacingOccurrences(of: ",", with: "."))
        guard let width = width, let depth = depth, width > 0, depth > 0 else { return nil }
        return width * depth
    }

    private var calibratedWidthMeters: CGFloat? {
        guard let value = Double(calibratedWidthText.replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value > 0 else { return nil }
        return CGFloat(value)
    }

    private var calibratedDepthMeters: CGFloat? {
        guard let value = Double(calibratedDepthText.replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value > 0 else { return nil }
        return CGFloat(value)
    }

    private func roomCalibrationBar() -> some View {
        HStack(spacing: 6) {
            Text(lang.t("floorplan_calibrate"))
                .adaptiveFont(size: 10, weight: .bold)
                .foregroundColor(.white.opacity(0.75))
            TextField(lang.t("floorplan_width_hint"), text: $calibratedWidthText)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .adaptiveFont(size: 12)
                .focused($isCalibrationFieldFocused)
                .frame(width: 64)
            Text("×")
                .adaptiveFont(size: 10)
                .foregroundColor(.white.opacity(0.5))
            TextField(lang.t("floorplan_depth_hint"), text: $calibratedDepthText)
                .keyboardType(.decimalPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .adaptiveFont(size: 12)
                .focused($isCalibrationFieldFocused)
                .frame(width: 64)
            if isCalibrationFieldFocused {
                Button(lang.t("done")) {
                    isCalibrationFieldFocused = false
                }
                .adaptiveFont(size: 11, weight: .bold)
                .foregroundColor(.yanCyan)
            }
            if let area = estimatedAreaSqm {
                Text(String(format: "≈ %.1f ㎡", area))
                    .adaptiveFont(size: 10, weight: .bold)
                    .foregroundColor(Color.yanCyan)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private func roomLayoutTools() -> some View {
        HStack(spacing: 8) {
            Button(action: centerFromRoomLayout) {
                Label(lang.t("floorplan_auto_center"), systemImage: "scope")
                    .adaptiveFont(size: 10, weight: .bold)
                    .foregroundColor(.yanCyan)
            }
            Button(action: { showNewRoomTypePicker = true }) {
                Label(lang.t("floorplan_add_room"), systemImage: "plus.rectangle")
                    .adaptiveFont(size: 10, weight: .bold)
                    .foregroundColor(.green)
            }
            Spacer(minLength: 0)
            Text(lang.t("floorplan_editing_hint"))
                .adaptiveFont(size: 9)
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showNewRoomTypePicker) {
            FloorplanRoomTypeEditor(titleKey: "floorplan_add_room", room: nil) { type in
                addRoom(type: type)
            }
        }
    }

    private var editingRoom: FloorplanRoom? {
        guard let selectedEditingRoomID = selectedEditingRoomID else { return nil }
        return rooms.first(where: { $0.id == selectedEditingRoomID })
    }

    /// A selected-room control panel is easier to use than a tiny pinch handle
    /// on a dense floor plan. Width and height are adjusted independently in
    /// small steps, keeping the room centered and inside the canvas.
    private func roomResizeTools(room: FloorplanRoom) -> some View {
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundColor(.yanCyan)
                Text("\(lang.t("floorplan_selected_room")): \(room.type.localizedName)")
                    .adaptiveFont(size: 10, weight: .bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Button {
                    roomForTypeEditing = room
                } label: {
                    Label(lang.t("floorplan_room_type"), systemImage: "tag")
                        .adaptiveFont(size: 9, weight: .semibold)
                }
                .foregroundColor(.yanCyan)
                Button {
                    showEditingRoomDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .adaptiveFont(size: 11, weight: .semibold)
                }
                .foregroundColor(.red)
                .accessibilityLabel(lang.t("floorplan_delete_room"))
            }

            VStack(spacing: 4) {
                resizeAxisRow(
                    title: lang.t("floorplan_width"),
                    value: String(format: "%.0f%%", room.rect.width * 100),
                    decreaseLabel: lang.t("floorplan_width_shrink"),
                    increaseLabel: lang.t("floorplan_width_expand"),
                    decrease: { adjustSelectedRoomSize(widthDelta: -0.02) },
                    increase: { adjustSelectedRoomSize(widthDelta: 0.02) }
                )
                resizeAxisRow(
                    title: lang.t("floorplan_height"),
                    value: String(format: "%.0f%%", room.rect.height * 100),
                    decreaseLabel: lang.t("floorplan_height_shrink"),
                    increaseLabel: lang.t("floorplan_height_expand"),
                    decrease: { adjustSelectedRoomSize(heightDelta: -0.02) },
                    increase: { adjustSelectedRoomSize(heightDelta: 0.02) }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.35))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    private func resizeButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .adaptiveFont(size: 9, weight: .bold)
                .frame(width: 24, height: 22)
                .background(Color.white.opacity(0.12))
                .cornerRadius(5)
        }
        .foregroundColor(.yanCyan)
        .accessibilityLabel(label)
    }

    private func resizeAxisRow(
        title: String,
        value: String,
        decreaseLabel: String,
        increaseLabel: String,
        decrease: @escaping () -> Void,
        increase: @escaping () -> Void
    ) -> some View {
        return HStack(spacing: 8) {
            Text(title)
                .adaptiveFont(size: 9, weight: .semibold)
                .foregroundColor(.white.opacity(0.75))
                .frame(width: 38, alignment: .leading)
            resizeButton(symbol: "minus", label: decreaseLabel, action: decrease)
            Text(value)
                .adaptiveFont(size: 9, weight: .bold, design: .monospaced)
                .foregroundColor(.white)
                .frame(width: 42)
            resizeButton(symbol: "plus", label: increaseLabel, action: increase)
            Spacer(minLength: 0)
        }
    }

    private func adjustSelectedRoomSize(widthDelta: CGFloat = 0, heightDelta: CGFloat = 0) {
        guard let selectedEditingRoomID = selectedEditingRoomID,
              let index = rooms.firstIndex(where: { $0.id == selectedEditingRoomID }) else { return }
        let original = rooms[index].rect
        let width = max(0.08, min(0.9, original.width + widthDelta))
        let height = max(0.06, min(0.9, original.height + heightDelta))
        let centerX = original.midX
        let centerY = original.midY
        let rect = CGRect(
            x: max(0, min(1 - width, centerX - width / 2)),
            y: max(0, min(1 - height, centerY - height / 2)),
            width: width,
            height: height
        )
        rooms[index].rect = rect
        if let auditedIndex = auditedRooms.firstIndex(where: { $0.id == selectedEditingRoomID }) {
            auditedRooms[auditedIndex].rect = rect
        }
        persistLayout()
        refreshAudit(force: true)
    }

    @ViewBuilder
    private var floorplanConfirmationOverlay: some View {
        if showResetConfirmation {
            FloorplanConfirmDialog(
                title: lang.t("reset_sample"),
                message: lang.t("floorplan_reset_confirm"),
                confirmTitle: lang.t("reset_sample"),
                cancelTitle: lang.t("cancel"),
                onConfirm: {
                    showResetConfirmation = false
                    resetToSampleLayout()
                },
                onCancel: { showResetConfirmation = false }
            )
        } else if showEditingRoomDeleteConfirmation {
            FloorplanConfirmDialog(
                title: lang.t("floorplan_delete_room"),
                message: lang.t("floorplan_delete_confirm"),
                confirmTitle: lang.t("floorplan_delete_room"),
                cancelTitle: lang.t("cancel"),
                onConfirm: {
                    showEditingRoomDeleteConfirmation = false
                    deleteSelectedEditingRoom()
                },
                onCancel: { showEditingRoomDeleteConfirmation = false }
            )
        }
    }

    private func deleteSelectedEditingRoom() {
        guard let selectedEditingRoomID = selectedEditingRoomID else { return }
        deleteRoom(roomID: selectedEditingRoomID)
        self.selectedEditingRoomID = nil
    }

    private func centerFromRoomLayout() {
        // 立极中宫：按房间真实面积（多边形优先）加权质心
        centroid = FloorplanEngine.roomsCentroid(rooms)
        persistLayout()
    }

    private func resetToSampleLayout() {
        workspaceRevision = workspaceStore.snapshot.revision
        houseFacingOffset = nil
        userFloorplanImage = nil
        calibratedWidthText = ""
        calibratedDepthText = ""
        restoredAspectRatio = 1
        // Reset both the imported background and any custom room edits so a
        // demo layout can always be restored after explicit confirmation.
        rooms = FloorplanEngine.shared.generateSampleRooms()
        centroid = CGPoint(x: 0.5, y: 0.5)
        roomsBeforeDetection = nil
        centroidBeforeDetection = nil
        roomDetectionMessage = nil
        isEditingRooms = false
        activeRoomDragID = nil
        activeRoomStartRect = nil
        activeRoomScaleID = nil
        activeRoomScaleStartRect = nil
        roomWasDragged = false
        selectedRoom = nil
        selectedEditingRoomID = nil
        roomForTypeEditing = nil
        showEditingRoomDeleteConfirmation = false
        // Keep an already purchased one-case grant attached to the active
        // layout. Resetting the editor must not silently consume the user's
        // paid case; the next imported plan can reuse that active grant.
        replaceSpatialArchives(measured: nil, virtual: nil, exterior: [])
        persistLayout()
        refreshAudit(force: true)
    }

    /// Builds a 3D projection from the rooms currently edited on this page.
    /// The result is deliberately labelled as a floorplan projection because
    /// its geometry comes from normalized room frames and optional user scale
    /// calibration, not from LiDAR or RoomPlan observations.
    private func buildCurrentFloorplanSurvey() -> HouseSpatialSurvey? {
        let sourceRooms = (auditedRooms.isEmpty ? rooms : auditedRooms)
            .filter { $0.type != .missingCorner }
        guard !sourceRooms.isEmpty else { return nil }

        let width = Float(projectionDimensions.width)
        let depth = Float(projectionDimensions.height)
        let roomHeight: Float = 2.8

        let rooms3D = sourceRooms
            .filter { $0.type != .door }
            .map { room in
                SpatialRoom3D(
                    id: UUID(uuidString: room.id) ?? UUID(),
                    name: room.name,
                    type: room.type,
                    center: SIMD3<Float>(Float(room.rect.midX) * width, roomHeight * 0.5, Float(room.rect.midY) * depth),
                    size: SIMD3<Float>(max(0.5, Float(room.rect.width) * width), roomHeight, max(0.5, Float(room.rect.height) * depth))
                )
            }

        var walls: [SpatialWall3D] = []
        func addWall(_ start: SIMD3<Float>, _ end: SIMD3<Float>, thickness: Float = 0.12) {
            walls.append(SpatialWall3D(start: start, end: end, height: roomHeight, thickness: thickness))
        }
        let outer = [
            SIMD3<Float>(0, 0, 0), SIMD3<Float>(width, 0, 0),
            SIMD3<Float>(width, 0, depth), SIMD3<Float>(0, 0, depth)
        ]
        for index in 0..<4 { addWall(outer[index], outer[(index + 1) % 4], thickness: 0.18) }
        for room in sourceRooms where room.type != .door {
            let x0 = Float(room.rect.minX) * width
            let x1 = Float(room.rect.maxX) * width
            let z0 = Float(room.rect.minY) * depth
            let z1 = Float(room.rect.maxY) * depth
            let corners = [SIMD3<Float>(x0, 0, z0), SIMD3<Float>(x1, 0, z0), SIMD3<Float>(x1, 0, z1), SIMD3<Float>(x0, 0, z1)]
            for index in 0..<4 { addWall(corners[index], corners[(index + 1) % 4]) }
        }

        func makeOpening(for room: FloorplanRoom, type: SpatialOpeningType) -> SpatialOpening3D {
            let distances: [(Int, CGFloat)] = [
                (0, room.rect.minY), (1, 1 - room.rect.maxX),
                (2, 1 - room.rect.maxY), (3, room.rect.minX)
            ]
            let edge = distances.min(by: { $0.1 < $1.1 })?.0 ?? 0
            let alongDepth = edge == 1 || edge == 3
            let span = max(0.5, Float((alongDepth ? room.rect.height * CGFloat(depth) : room.rect.width * CGFloat(width))))
            let height: Float = type == .window || type == .balconyDoor ? 1.5 : 2.1
            switch edge {
            case 1:
                return SpatialOpening3D(type: type, position: SIMD3<Float>(width, roomHeight * 0.5, Float(room.rect.midY) * depth), normal: SIMD3<Float>(1, 0, 0), width: span, height: height)
            case 2:
                return SpatialOpening3D(type: type, position: SIMD3<Float>(Float(room.rect.midX) * width, roomHeight * 0.5, depth), normal: SIMD3<Float>(0, 0, 1), width: span, height: height)
            case 3:
                return SpatialOpening3D(type: type, position: SIMD3<Float>(0, roomHeight * 0.5, Float(room.rect.midY) * depth), normal: SIMD3<Float>(-1, 0, 0), width: span, height: height)
            default:
                return SpatialOpening3D(type: type, position: SIMD3<Float>(Float(room.rect.midX) * width, roomHeight * 0.5, 0), normal: SIMD3<Float>(0, 0, -1), width: span, height: height)
            }
        }

        var openings: [SpatialOpening3D] = []
        if let door = sourceRooms.first(where: { $0.type == .door }) {
            openings.append(makeOpening(for: door, type: .entranceDoor))
        }
        if let balcony = sourceRooms.first(where: { $0.type == .balcony }) {
            openings.append(makeOpening(for: balcony, type: .balconyDoor))
        }

        let scanMethodTitle: String
        switch lang.effectiveLanguage {
        case .en: scanMethodTitle = "3D Floorplan Projection (Current Plan)"
        case .zhHant: scanMethodTitle = "戶型圖 3D 推演（當前戶型）"
        case .ja: scanMethodTitle = "間取り図 3D 推演（現在の間取り）"
        case .ko: scanMethodTitle = "평면도 3D 추연 (현재 평면도)"
        case .vi: scanMethodTitle = "Mô phỏng 3D Sơ đồ (Mặt bằng hiện tại)"
        case .th: scanMethodTitle = "จำลองผังบ้าน 3D (ผังปัจจุบัน)"
        case .id: scanMethodTitle = "Proyeksi Denah 3D (Denah Saat Ini)"
        case .auto, .zhHans: scanMethodTitle = "户型图 3D 推演（当前户型）"
        }

        return HouseSpatialSurveyEngine.analyzeSpatialHouse(
            scanMethod: scanMethodTitle,
            walls: walls,
            openings: openings,
            beams: [],
            rooms: rooms3D,
            objects: [],
            compassHeading: effectiveHeading,
            centroidOverride: SIMD3<Float>(Float(centroid.x) * width, 0, Float(centroid.y) * depth),
            houseFacingDegrees: houseFacingDegrees
        )
    }

    private func headingQualityNotice() -> some View {
        let referenceText: String
        if isSyncWithCompass {
            referenceText = activeNorthReference == .trueNorth
                ? lang.t("heading_reference_true")
                : lang.t("heading_reference_magnetic")
        } else {
            referenceText = lang.t("floorplan_manual_heading")
        }
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(lang.t("floorplan_heading_reference")): \(referenceText)")
                .adaptiveFont(size: 9, weight: .medium)
                .foregroundColor(.white.opacity(0.65))
            if motion.isDistorted || motion.accuracyLevel < 2 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(motion.isDistorted
                         ? lang.t("settings_mag_field_warning")
                         : lang.t("calib_precision_need"))
                }
                .adaptiveFont(size: 9, weight: .semibold)
                .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    private func manualHeadingControl() -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(lang.t("floorplan_manual_heading"))
                    .adaptiveFont(size: 10, weight: .semibold)
                    .foregroundColor(.orange)
                Spacer()
                Text(String(format: "%.1f°", compassRotation))
                    .adaptiveFont(size: 11, weight: .bold, design: .monospaced)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
                Button(action: {
                    compassRotation = motion.headingState.facingAngle
                    persistLayout()
                    refreshAudit(force: true)
                }) {
                    Text(lang.t("floorplan_heading_use_compass"))
                        .adaptiveFont(size: 9, weight: .bold)
                        .foregroundColor(.yanCyan)
                }
            }
            HStack(spacing: 8) {
                Button(action: { adjustManualHeading(by: -1) }) {
                    Text("−1°")
                }
                Button(action: { adjustManualHeading(by: 1) }) {
                    Text("+1°")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .adaptiveFont(size: 10, weight: .bold, design: .monospaced)
            .foregroundColor(.orange)
            Slider(value: $compassRotation, in: 0...359.5, step: 0.5)
                .accentColor(.orange)
                .accessibilityValue(String(format: "%.1f°", compassRotation))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.35))
        .cornerRadius(8)
    }

    /// Runs a lightweight Vision pass over the imported plan: a rectangle
    /// channel plus a closed-contour channel. Room names are still editable
    /// by the user, but the detected polygons (not just boxes) let the layout
    /// follow the real wall lines, and extra detected regions are added as new
    /// rooms instead of being discarded.
    private func detectRoomLayout() {
        guard !rooms.isEmpty else {
            roomDetectionMessage = lang.t("floorplan_detect_failed")
            return
        }
        guard let image = userFloorplanImage,
              let cgImage = image.cgImage,
              !isDetectingRooms else { return }

        isDetectingRooms = true
        roomDetectionMessage = lang.t("floorplan_detecting")
        let orientation = Self.cgOrientation(for: image.imageOrientation)
        roomDetectionGeneration &+= 1
        let generation = roomDetectionGeneration
        let sourceImage = image
        DispatchQueue.global(qos: .userInitiated).async {
            // 通道 1：矩形检测（高置信度矩形，适合规整线稿）
            let rectCandidates = Self.detectRectCandidates(
                cgImage: cgImage,
                orientation: orientation
            )
            // 通道 2：闭合轮廓多边形（VNDetectContoursRequest 自带对比度
            // 增强与灰度化，适配照片拍摄的图纸）
            let contourCandidates = Self.detectContourCandidates(
                cgImage: cgImage,
                orientation: orientation
            )
            let merged = Self.mergeCandidates(
                rectCandidates: rectCandidates,
                contourCandidates: contourCandidates
            )
            DispatchQueue.main.async { [self] in
                guard generation == roomDetectionGeneration,
                      userFloorplanImage === sourceImage else { return }
                isDetectingRooms = false
                guard !merged.isEmpty else {
                    roomDetectionMessage = lang.t("floorplan_detect_failed")
                    return
                }
                applyRoomCandidates(merged)
            }
        }
    }

    /// 矩形通道：VNDetectRectanglesRequest + 归一化/去重
    private static func detectRectCandidates(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> [CGRect] {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.35
        request.minimumSize = 0.04
        request.minimumAspectRatio = 0.15
        request.maximumAspectRatio = 6.0
        request.maximumObservations = 32
        do {
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
                options: [:]
            )
            try handler.perform([request])
            return normalizedRoomCandidates(
                from: request.results ?? []
            )
        } catch {
            return []
        }
    }

    /// 轮廓通道：VNDetectContoursRequest → 近似闭合的顶层轮廓 → 多边形候选
    private static func detectContourCandidates(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> [(rect: CGRect, points: [CGPoint])] {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 2.0
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 640
        do {
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
                options: [:]
            )
            try handler.perform([request])
            guard let observation = request.results?.first else { return [] }
            return contourRoomCandidates(from: observation)
        } catch {
            return []
        }
    }

    /// 把顶层闭合轮廓转成房间候选（面积过滤 + 面积降序）
    private static func contourRoomCandidates(from observation: VNContoursObservation) -> [(rect: CGRect, points: [CGPoint])] {
        var result: [(rect: CGRect, points: [CGPoint])] = []
        for contour in observation.topLevelContours {
            let rawPoints = contour.normalizedPoints
            guard rawPoints.count >= 4 else { continue }
            // Vision 坐标 y 向上（左下原点）→ 翻转为 UIKit y 向下
            let flipped = rawPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat(1 - $0.y)) }
            // 轮廓首尾接近即视为闭合房间边界
            let first = flipped.first ?? .zero
            let last = flipped.last ?? .zero
            guard hypot(last.x - first.x, last.y - first.y) < 0.03 else { continue }
            guard let bounds = GeometryUtils.polygonBounds(flipped) else { continue }
            guard bounds.width >= 0.08, bounds.height >= 0.06,
                  bounds.width * bounds.height >= 0.012,
                  bounds.width * bounds.height <= 0.78 else { continue }
            result.append((bounds, flipped))
        }
        return result.sorted {
            ($0.rect.width * $0.rect.height) > ($1.rect.width * $1.rect.height)
        }
    }

    /// 双通道候选合并：矩形优先入列，轮廓补齐；IoU > 0.55 视为同区域去重
    private static func mergeCandidates(
        rectCandidates: [CGRect],
        contourCandidates: [(rect: CGRect, points: [CGPoint])]
    ) -> [RoomCandidate] {
        var merged: [RoomCandidate] = []
        for rect in rectCandidates {
            let overlaps = merged.contains { existing in
                let intersection = existing.rect.intersection(rect)
                guard !intersection.isNull else { return false }
                let unionArea = existing.rect.union(rect).width * existing.rect.union(rect).height
                return unionArea > 0 && (intersection.width * intersection.height) / unionArea > 0.55
            }
            if !overlaps { merged.append(RoomCandidate(rect: rect, polygonPoints: nil)) }
        }
        for contour in contourCandidates {
            let overlaps = merged.contains { existing in
                let intersection = existing.rect.intersection(contour.rect)
                guard !intersection.isNull else { return false }
                let unionArea = existing.rect.union(contour.rect).width * existing.rect.union(contour.rect).height
                return unionArea > 0 && (intersection.width * intersection.height) / unionArea > 0.55
            }
            if !overlaps {
                merged.append(RoomCandidate(rect: contour.rect, polygonPoints: contour.points))
            }
        }
        return merged.sorted {
            ($0.rect.width * $0.rect.height) > ($1.rect.width * $1.rect.height)
        }
    }

    private static func cgOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    private static func normalizedRoomCandidates(from observations: [VNRectangleObservation]) -> [CGRect] {
        let candidates = observations.compactMap { observation -> CGRect? in
            let box = observation.boundingBox
            let rect = CGRect(
                x: max(0, min(1, box.minX)),
                y: max(0, min(1, 1 - box.maxY)),
                width: max(0, min(1, box.width)),
                height: max(0, min(1, box.height))
            )
            guard rect.width >= 0.08, rect.height >= 0.06,
                  rect.width * rect.height >= 0.012,
                  rect.width * rect.height <= 0.78 else { return nil }
            return rect
        }
        .sorted { $0.width * $0.height > $1.width * $1.height }

        // Vision may return the same room at several nested scales. Keep the
        // first (largest) candidate and discard heavily overlapping boxes.
        return candidates.reduce(into: []) { result, candidate in
            let overlaps = result.contains { existing in
                let intersection = existing.intersection(candidate)
                guard !intersection.isNull else { return false }
                let unionArea = existing.union(candidate).width * existing.union(candidate).height
                return unionArea > 0 && (intersection.width * intersection.height) / unionArea > 0.55
            }
            if !overlaps { result.append(candidate) }
        }
    }

    private func applyRoomCandidates(_ candidates: [RoomCandidate]) {
        guard !rooms.isEmpty else { return }
        roomsBeforeDetection = rooms
        centroidBeforeDetection = centroid
        let orderedRoomIndices = rooms.indices.filter { rooms[$0].type != .missingCorner }.sorted {
            rooms[$0].rect.width * rooms[$0].rect.height > rooms[$1].rect.width * rooms[$1].rect.height
        }
        let orderedCandidates = candidates.sorted {
            ($0.rect.width * $0.rect.height) > ($1.rect.width * $1.rect.height)
        }
        var updatedRooms = rooms
        // 1) 匹配覆盖：候选按面积降序匹配现有房间（保留类型与名称，更新边界）
        let matchCount = min(orderedRoomIndices.count, orderedCandidates.count)
        for offset in 0..<matchCount {
            let candidate = orderedCandidates[offset]
            var room = updatedRooms[orderedRoomIndices[offset]]
            room.rect = candidate.rect
            room.polygonPoints = candidate.polygonPoints
            updatedRooms[orderedRoomIndices[offset]] = room
        }
        // 2) 超出房间数的候选 → 新增房间（规则推断类型，后续可逐间修改）
        let addedCount = max(0, orderedCandidates.count - orderedRoomIndices.count)
        if addedCount > 0 {
            for candidate in orderedCandidates.dropFirst(orderedRoomIndices.count) {
                let areaRatio = candidate.rect.width * candidate.rect.height
                let aspectRatio = candidate.rect.width / max(candidate.rect.height, 0.0001)
                let type = FloorplanEngine.inferRoomType(
                    areaRatio: areaRatio,
                    aspectRatio: aspectRatio,
                    existing: updatedRooms
                ) ?? .study
                updatedRooms.append(FloorplanRoom(
                    name: type.localizedName,
                    type: type,
                    rect: candidate.rect,
                    polygonPoints: candidate.polygonPoints
                ))
            }
        }
        rooms = updatedRooms
        isEditingRooms = true
        // 3) 立极中宫：按真实多边形面积加权质心
        centroid = FloorplanEngine.roomsCentroid(updatedRooms)
        persistLayout()
        if addedCount > 0 {
            roomDetectionMessage = "\(lang.t("floorplan_detected")) \(matchCount) · +\(addedCount)"
        } else {
            roomDetectionMessage = "\(lang.t("floorplan_detected")) \(matchCount)"
        }
        refreshAudit(force: true)
    }

    private func undoRoomDetection() {
        guard let roomsBeforeDetection = roomsBeforeDetection else { return }
        rooms = roomsBeforeDetection
        if let centroidBeforeDetection = centroidBeforeDetection {
            centroid = centroidBeforeDetection
        }
        self.roomsBeforeDetection = nil
        self.centroidBeforeDetection = nil
        roomDetectionMessage = nil
        persistLayout()
        refreshAudit(force: true)
    }

    private func updateRoomType(roomID: String, type: FloorplanRoomType) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].type = type
        rooms[index].name = type.localizedName
        roomsBeforeDetection = nil
        centroidBeforeDetection = nil
        persistLayout()
        refreshAudit(force: true)
        selectedRoom = nil
    }

    private func addRoom(type: FloorplanRoomType) {
        let roomWidth: CGFloat = 0.23
        let roomHeight: CGFloat = 0.18
        let origin = suggestedRoomOrigin(width: roomWidth, height: roomHeight)
        rooms.append(FloorplanRoom(
            name: type.localizedName,
            type: type,
            rect: CGRect(x: origin.x, y: origin.y, width: roomWidth, height: roomHeight)
        ))
        roomsBeforeDetection = nil
        centroidBeforeDetection = nil
        isEditingRooms = true
        persistLayout()
        refreshAudit(force: true)
    }

    /// Choose the least-overlapping slot in a bounded editing grid. The old
    /// count-based modulo placement wrapped after twelve rooms and could put
    /// a newly added room directly on top of an existing one.
    private func suggestedRoomOrigin(width: CGFloat, height: CGFloat) -> CGPoint {
        let columns = 4
        let rows = 5
        let maxX = max(0, 1.0 - width)
        let maxY = max(0, 1.0 - height)
        let xStep = columns > 1 ? maxX / CGFloat(columns - 1) : 0
        let yStep = rows > 1 ? maxY / CGFloat(rows - 1) : 0
        let candidates: [CGPoint] = (0..<rows).flatMap { row in
            (0..<columns).map { column in
                CGPoint(
                    x: min(maxX, CGFloat(column) * xStep),
                    y: min(maxY, CGFloat(row) * yStep)
                )
            }
        }
        let score: (CGPoint) -> CGFloat = { origin in
            let candidate = CGRect(origin: origin, size: CGSize(width: width, height: height))
            return self.rooms.reduce(0) { partial, room in
                let overlap = candidate.intersection(room.rect)
                guard !overlap.isNull else { return partial }
                return partial + overlap.width * overlap.height
            }
        }
        return candidates.min {
            let lhs = score($0)
            let rhs = score($1)
            if abs(lhs - rhs) > 0.0001 { return lhs < rhs }
            if abs($0.y - $1.y) > 0.0001 { return $0.y < $1.y }
            return $0.x < $1.x
        } ?? CGPoint(x: 0, y: 0)
    }

    private func deleteRoom(roomID: String) {
        rooms.removeAll { $0.id == roomID }
        roomsBeforeDetection = nil
        centroidBeforeDetection = nil
        if selectedEditingRoomID == roomID {
            selectedEditingRoomID = nil
        }
        persistLayout()
        refreshAudit(force: true)
        selectedRoom = nil
    }

    private func adjustManualHeading(by delta: Double) {
        compassRotation = (compassRotation + delta).truncatingRemainder(dividingBy: 360)
        if compassRotation < 0 { compassRotation += 360 }
        persistLayout()
        refreshAudit(force: true)
    }

    private var activeNorthReference: CompassNorthReference {
        if motion.northReference == .trueNorth && motion.hasDeclination {
            return .trueNorth
        }
        return .magneticNorth
    }
    
    // MARK: - 户型交互画布
    private func floorplanCanvasView(auditedRooms: [FloorplanRoom]) -> some View {
        GeometryReader { geo in
            let layoutRect = floorplanContentRect(in: geo.size)
            let centerPt = CGPoint(
                x: layoutRect.minX + centroid.x * layoutRect.width,
                y: layoutRect.minY + centroid.y * layoutRect.height
            )
            
            ZStack {
                // 底色
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.11, green: 0.12, blue: 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                
                // 真实导入图纸底图
                if let userImg = userFloorplanImage {
                    Image(uiImage: userImg)
                        .resizable()
                        .frame(width: layoutRect.width, height: layoutRect.height)
                        .position(x: layoutRect.midX, y: layoutRect.midY)
                        .opacity(0.85)
                }
                
                // 户型外墙与房间隔断
                ForEach(auditedRooms) { room in
                    roomBlockView(room: room, layoutRect: layoutRect)
                }
                
                // 随动半透明罗盘八宫扇区与十字天心
                compassOverlayLayer(centerPt: centerPt, size: min(layoutRect.width, layoutRect.height))
                
                // 可拖拽的中宫立极点 (Centroid Handle)
                centroidHandle(centerPt: centerPt, layoutRect: layoutRect)
            }
            .clipped()
            .cornerRadius(12)
        }
    }
    
    private func floorplanContentRect(in canvasSize: CGSize) -> CGRect {
        GeometryUtils.aspectFitRect(aspectRatio: floorplanAspectRatio,
                                    in: CGRect(origin: .zero, size: canvasSize))
    }

    private func roomBlockView(room: FloorplanRoom, layoutRect: CGRect) -> some View {
        let rx = room.rect.origin.x * layoutRect.width
        let ry = room.rect.origin.y * layoutRect.height
        let rw = room.rect.size.width * layoutRect.width
        let rh = room.rect.size.height * layoutRect.height
        
        let isBad = room.isBad
        let isGood = room.isGood
        let isMissingCorner = room.type == .missingCorner
        let isSelectedForEditing = isEditingRooms && selectedEditingRoomID == room.id
        let strokeColor = isSelectedForEditing
            ? Color.yanCyan
            : (isMissingCorner ? Color.red : (isBad ? Color.red : (isGood ? Color.green : Color.white.opacity(0.25))))
        let bgColor = isMissingCorner ? Color.red.opacity(0.12) : (isBad ? Color.red.opacity(0.15) : (isGood ? Color.green.opacity(0.12) : Color.white.opacity(0.05)))
        
        return Button(action: {
            // Tapping always opens the diagnostic sheet. Room placement still
            // uses the drag gesture while editing, and type changes are
            // available from a dedicated action inside the diagnostic sheet.
            if roomWasDragged {
                roomWasDragged = false
                return
            }
            // Room placement and type editing are local layout operations and
            // should remain available before a paid diagnostic is unlocked.
            if isEditingRooms {
                selectedEditingRoomID = room.id
                return
            }
            // Layout editing is available before purchase, but room-level
            // diagnosis remains protected by the same entitlement check as
            // the report list. Do not let edit mode bypass the paywall.
            if acquireFloorplanAccess() {
                selectedRoom = room
            }
        }) {
            ZStack {
                if let pts = room.polygonPoints, pts.count >= 3 {
                    // 识别出的真实墙线轮廓：按多边形绘制（矩形仅作兜底边界）
                    Path { path in
                        let first = pts[0]
                        path.move(to: CGPoint(
                            x: layoutRect.minX + first.x * layoutRect.width,
                            y: layoutRect.minY + first.y * layoutRect.height
                        ))
                        for p in pts.dropFirst() {
                            path.addLine(to: CGPoint(
                                x: layoutRect.minX + p.x * layoutRect.width,
                                y: layoutRect.minY + p.y * layoutRect.height
                            ))
                        }
                        path.closeSubpath()
                    }
                    .fill(bgColor)
                    .overlay(
                        Path { path in
                            let first = pts[0]
                            path.move(to: CGPoint(
                                x: layoutRect.minX + first.x * layoutRect.width,
                                y: layoutRect.minY + first.y * layoutRect.height
                            ))
                            for p in pts.dropFirst() {
                                path.addLine(to: CGPoint(
                                    x: layoutRect.minX + p.x * layoutRect.width,
                                    y: layoutRect.minY + p.y * layoutRect.height
                                ))
                            }
                            path.closeSubpath()
                        }
                        .stroke(
                            strokeColor,
                            style: StrokeStyle(
                                lineWidth: isMissingCorner || isBad ? 1.5 : 1,
                                dash: isMissingCorner ? [5, 3] : []
                            )
                        )
                    )
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(bgColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    strokeColor,
                                    style: StrokeStyle(
                                        lineWidth: isMissingCorner || isBad ? 1.5 : 1,
                                        dash: isMissingCorner ? [5, 3] : []
                                    )
                                )
                        )
                }
                
                VStack(spacing: 2) {
                    Image(systemName: room.type.iconName)
                        .adaptiveFont(size: 11)
                        .foregroundColor(strokeColor)
                    Text(room.type.localizedName)
                        .adaptiveFont(size: 10, weight: .bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(room.palaceName)
                        .adaptiveFont(size: 8)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .padding(isLargeLayout ? 4 : 2)
            }
        }
        .frame(width: rw, height: rh)
        .position(
            x: layoutRect.minX + rx + rw / 2,
            y: layoutRect.minY + ry + rh / 2
        )
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard isEditingRooms else { return }
                    selectedEditingRoomID = room.id
                    // A two-finger pinch can also emit a drag translation.
                    // Once scaling has started, keep the room anchored and
                    // let only the magnification gesture change its size.
                    guard activeRoomScaleID == nil else { return }

                    if abs(value.translation.width) > 3 || abs(value.translation.height) > 3 {
                        roomWasDragged = true
                    }

                    if activeRoomDragID != room.id {
                        activeRoomDragID = room.id
                        activeRoomStartRect = room.rect
                    }
                    guard let startRect = activeRoomStartRect,
                          let index = rooms.firstIndex(where: { $0.id == room.id }) else { return }

                    let dx = value.translation.width / max(layoutRect.width, 1)
                    let dy = value.translation.height / max(layoutRect.height, 1)
                    let maxX = max(0.0, 1.0 - startRect.width)
                    let maxY = max(0.0, 1.0 - startRect.height)
                    var updated = rooms[index]
                    updated.rect.origin.x = max(0.0, min(maxX, startRect.origin.x + dx))
                    updated.rect.origin.y = max(0.0, min(maxY, startRect.origin.y + dy))
                    rooms[index] = updated

                    // Keep the dragged rectangle responsive without rerunning
                    // palace/severity evaluation for every drag sample. The
                    // full audit is refreshed once the gesture ends.
                    if let auditedIndex = auditedRooms.firstIndex(where: { $0.id == room.id }) {
                        var audited = auditedRooms[auditedIndex]
                        audited.rect = updated.rect
                        auditedRooms[auditedIndex] = audited
                    }
                }
                .onEnded { _ in
                    activeRoomDragID = nil
                    activeRoomStartRect = nil
                    // Let a Button action from the same touch cycle observe
                    // the drag marker, then clear it for the next gesture.
                    DispatchQueue.main.async {
                        roomWasDragged = false
                    }
                    persistLayout()
                    refreshAudit(force: true)
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { scale in
                    guard isEditingRooms, scale.isFinite else { return }
                    roomWasDragged = true
                    if activeRoomScaleID != room.id {
                        activeRoomScaleID = room.id
                        activeRoomScaleStartRect = room.rect
                        activeRoomDragID = nil
                        activeRoomStartRect = nil
                    }
                    guard let startRect = activeRoomScaleStartRect,
                          let index = rooms.firstIndex(where: { $0.id == room.id }) else { return }

                    let minWidth: CGFloat = 0.08
                    let minHeight: CGFloat = 0.06
                    let newWidth = max(minWidth, min(0.9, startRect.width * scale))
                    let newHeight = max(minHeight, min(0.9, startRect.height * scale))
                    let maxX = max(0.0, 1.0 - newWidth)
                    let maxY = max(0.0, 1.0 - newHeight)
                    var updated = rooms[index]
                    updated.rect = CGRect(
                        x: min(max(0.0, startRect.origin.x), maxX),
                        y: min(max(0.0, startRect.origin.y), maxY),
                        width: newWidth,
                        height: newHeight
                    )
                    rooms[index] = updated
                    if let auditedIndex = auditedRooms.firstIndex(where: { $0.id == room.id }) {
                        var audited = auditedRooms[auditedIndex]
                        audited.rect = updated.rect
                        auditedRooms[auditedIndex] = audited
                    }
                }
                .onEnded { _ in
                    activeRoomScaleID = nil
                    activeRoomScaleStartRect = nil
                    persistLayout()
                    refreshAudit(force: true)
                }
        )
    }
    
    private func localizedOverlayPalaceBadges() -> [(geoAngle: Double, title: String, star: String, isAuspicious: Bool)] {
        switch lang.effectiveLanguage {
        case .en:
            return [
                (0.0,   "N · Kan",   "5-Yellow", false),
                (45.0,  "NE · Gen",  "3-Jade",   false),
                (90.0,  "E · Zhen",  "7-Red",    false),
                (135.0, "SE · Xun",  "8-Wealth", true),
                (180.0, "S · Li",    "4-Study",  true),
                (225.0, "SW · Kun",  "6-Noble",  true),
                (270.0, "W · Dui",   "2-Illness",false),
                (315.0, "NW · Qian", "1-Ausp.",  true)
            ]
        case .zhHant:
            return [
                (0.0,   "坎北",   "五黃煞",   false),
                (45.0,  "艮東北", "三碧",     false),
                (90.0,  "震東",   "七赤",     false),
                (135.0, "巽東南", "八白財",   true),
                (180.0, "離南",   "四綠文昌", true),
                (225.0, "坤西南", "六白官",   true),
                (270.0, "兌西",   "二黑病",   false),
                (315.0, "乾西北", "一白吉",   true)
            ]
        case .ja:
            return [
                (0.0,   "坎北",   "五黄殺",   false),
                (45.0,  "艮北東", "三碧",     false),
                (90.0,  "震東",   "七赤",     false),
                (135.0, "巽南東", "八白財",   true),
                (180.0, "離南",   "四緑文昌", true),
                (225.0, "坤南西", "六白官",   true),
                (270.0, "兌西",   "二黒病",   false),
                (315.0, "乾北西", "一白吉",   true)
            ]
        case .ko:
            return [
                (0.0,   "감북",   "오황살",   false),
                (45.0,  "간동북", "삼벽",     false),
                (90.0,  "진동",   "칠적",     false),
                (135.0, "손동남", "팔백재",   true),
                (180.0, "이남",   "사록문창", true),
                (225.0, "곤서남", "육백관",   true),
                (270.0, "태서",   "이흑병",   false),
                (315.0, "건서북", "일백길",   true)
            ]
        case .vi:
            return [
                (0.0,   "Khảm B",  "Ngũ Hoàng", false),
                (45.0,  "Cấn ĐB",  "Tam Bích",  false),
                (90.0,  "Chấn Đ",  "Thất Xích", false),
                (135.0, "Tốn ĐN",  "Bát Bạch",  true),
                (180.0, "Ly N",    "Văn Xương", true),
                (225.0, "Khôn TN", "Lục Bạch",  true),
                (270.0, "Đoài T",  "Nhị Hắc",   false),
                (315.0, "Càn TB",  "Nhất Bạch", true)
            ]
        case .th:
            return [
                (0.0,   "ข่าน N",  "5 เหลือง", false),
                (45.0,  "เกิ่น NE","3 เขียว",  false),
                (90.0,  "เจิ้น E", "7 แดง",    false),
                (135.0, "ซวิ่น SE","8 ทรัพย์", true),
                (180.0, "หลี S",   "4 บัณฑิต", true),
                (225.0, "คุน SW",  "6 ยศ",     true),
                (270.0, "ตุ้ย W",  "2 โรค",    false),
                (315.0, "เฉียน NW","1 มงคล",   true)
            ]
        case .id:
            return [
                (0.0,   "U · Kan",  "5-Kuning", false),
                (45.0,  "TL · Gen", "3-Hijau",  false),
                (90.0,  "T · Zhen", "7-Merah",  false),
                (135.0, "TG · Xun", "8-Rezeki", true),
                (180.0, "S · Li",   "4-Studi",  true),
                (225.0, "BD · Kun", "6-Karier", true),
                (270.0, "B · Dui",  "2-Sakit",  false),
                (315.0, "BL · Qian","1-Berkah", true)
            ]
        case .auto, .zhHans:
            return [
                (0.0,   "坎北",   "五黄煞",   false),
                (45.0,  "艮东北", "三碧",     false),
                (90.0,  "震东",   "七赤",     false),
                (135.0, "巽东南", "八白财",   true),
                (180.0, "离南",   "四绿文昌", true),
                (225.0, "坤西南", "六白官",   true),
                (270.0, "兑西",   "二黑病",   false),
                (315.0, "乾西北", "一白吉",   true)
            ]
        }
    }

    private func compassOverlayLayer(centerPt: CGPoint, size: CGFloat) -> some View {
        let r = size * 0.44
        // 角标原放在 0.37（金环内侧），正好落在房间卡片上，压住房间名
        //（截图里"乾西北 三碧"叠在 Gourmet Kitchen 上）。挪到金环外侧
        // 0.465：角标落在环与画布边缘之间的空环带上，不再压房间标题。
        let badgeR = size * 0.465
        let badges = localizedOverlayPalaceBadges()

        return ZStack {
            // 八宫分界辐射线 (位于每宫 ±22.5° 交界处，与 FloorplanEngine.palaceForPoint 完全对齐)
            ForEach(0..<8) { i in
                let boundaryAngle = Double(i) * 45.0 + 22.5 - effectiveHeading
                Path { p in
                    p.move(to: centerPt)
                    let rad = boundaryAngle * .pi / 180.0
                    p.addLine(to: CGPoint(x: centerPt.x + CGFloat(sin(rad)) * r, y: centerPt.y - CGFloat(cos(rad)) * r))
                }
                .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.35), lineWidth: 1)
            }

            // 十字天心红线
            Path { p in
                p.move(to: CGPoint(x: centerPt.x - r, y: centerPt.y))
                p.addLine(to: CGPoint(x: centerPt.x + r, y: centerPt.y))
                p.move(to: CGPoint(x: centerPt.x, y: centerPt.y - r))
                p.addLine(to: CGPoint(x: centerPt.x, y: centerPt.y + r))
            }
            .stroke(Color.red.opacity(0.6), lineWidth: 1.5)

            // 外圈金环
            Circle()
                .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.4), lineWidth: 1)
                .frame(width: r * 2, height: r * 2)
                .position(centerPt)

            // 八宫八卦方位与九运飞星财位/文昌位角标
            ForEach(0..<badges.count, id: \.self) { idx in
                let item = badges[idx]
                let screenAngle = item.geoAngle - effectiveHeading
                let rad = screenAngle * .pi / 180.0
                let bx = centerPt.x + CGFloat(sin(rad)) * badgeR
                let by = centerPt.y - CGFloat(cos(rad)) * badgeR
                VStack(spacing: 0) {
                    Text(item.title)
                        .adaptiveFont(size: 8, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(item.star)
                        .adaptiveFont(size: 7, weight: .semibold)
                        .foregroundColor(item.isAuspicious ? .green : .orange.opacity(0.9))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.black.opacity(0.62))
                .cornerRadius(4)
                .position(x: bx, y: by)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func centroidHandle(centerPt: CGPoint, layoutRect: CGRect) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.95, green: 0.85, blue: 0.45))
                .frame(width: 18, height: 18)
                .shadow(color: .black.opacity(0.6), radius: 3)
            Circle()
                .stroke(Color.red, lineWidth: 2)
                .frame(width: 24, height: 24)
            Text(lang.t("floorplan_center_point"))
                .adaptiveFont(size: 8, weight: .bold)
                .foregroundColor(.black)
        }
        .position(centerPt)
        .gesture(
            DragGesture()
                .onChanged { val in
                    if centroidDragStart == nil {
                        centroidDragStart = centroid
                    }
                    guard let start = centroidDragStart else { return }
                    let newX = max(0.1, min(0.9, start.x + val.translation.width / max(layoutRect.width, 1)))
                    let newY = max(0.1, min(0.9, start.y + val.translation.height / max(layoutRect.height, 1)))
                    centroid = CGPoint(x: newX, y: newY)
                }
                .onEnded { _ in
                    centroidDragStart = nil
                    persistLayout()
                    // The live drag is throttled to avoid rebuilding the
                    // report for every touch sample. Always run one final
                    // audit at the exact committed Tai Ji point so a small
                    // last movement cannot leave room recommendations stale.
                    refreshAudit(force: true)
                }
        )
    }
    
    // MARK: - 底部体检报告
    private func auditListSection(report: [FloorplanAuditItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 分栏右栏只有约 270~360pt，标题 / 提示 / 分享按钮三段横排会把
            // 越南语「Danh mục kiểm tra cực diện phong thủy toàn nhà」压成竖排单字。
            // 改为纵向堆叠：标题与提示各占整行，按钮单独一行靠前。
            VStack(alignment: .leading, spacing: 6) {
                Text("🏠 \(lang.t("audit_checklist")) (\(report.count))")
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
                Text(lang.t("drag_center_hint"))
                    .adaptiveFont(size: 10)
                    .foregroundColor(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: {
                    if acquireFloorplanAccess() {
                        exportFloorplanReport()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up")
                        Text(lang.t("ar_roomplan_share"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .adaptiveFont(size: 10, weight: .bold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.95, green: 0.80, blue: 0.25).opacity(0.22))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .cornerRadius(6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            
            VStack(spacing: 8) {
                if !hasFloorplanAccess {
                    VIPLockCardView(
                        title: lang.t("privilege_floorplan_title"),
                        featureDesc: lang.t("privilege_floorplan_desc"),
                        badge: lang.t("vip_badge_title"),
                        targetProductId: .floorplanSingle,
                        onUnlockTap: { showPaywall = true }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 免费展示首条体检概览
                    if let firstItem = report.first {
                        auditItemRow(item: firstItem)
                    }
                } else {
                    ForEach(report) { item in
                        auditItemRow(item: item)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func auditItemRow(item: FloorplanAuditItem) -> some View {
        HStack(alignment: .top, spacing: isLargeLayout ? 10 : 8) {
            Circle()
                .fill(item.isSevere ? Color.red : (item.isGood ? Color.green : Color.orange))
                .frame(width: isLargeLayout ? 10 : 8, height: isLargeLayout ? 10 : 8)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: isLargeLayout ? 4 : 3) {
                // 标题与判级徽章不再横排：窄右栏里长标题会被徽章压成竖排单字。
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.isSevere ? lang.t("floorplan_severe_sha") : (item.isGood ? lang.t("grade_auspicious") : lang.t("floorplan_warn_sha")))
                        .adaptiveFont(size: 10, weight: .bold)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(item.isSevere ? Color.red.opacity(0.2) : (item.isGood ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)))
                        .foregroundColor(item.isSevere ? .red : (item.isGood ? .green : .orange))
                        .cornerRadius(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.lore)
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(lang.t("floorplan_solution_prefix")) \(item.solution)")
                    .adaptiveFont(size: 10)
                    .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(8)
    }

    // MARK: - 一键导出全屋户型立极与堪舆全案长图 (PRD 5.3)
    private func exportFloorplanReport(report: [FloorplanAuditItem]) {
        // 主线程快照渲染所需状态，绘制移到后台队列，避免 1080×1920 全页
        // 同步渲染（含全尺寸户型图）阻塞主线程导致点击导出卡顿。
        reportExportGeneration &+= 1
        let generation = reportExportGeneration
        let snapshot = FloorplanReportSnapshot(rooms: rooms, centroid: centroid, heading: effectiveHeading,
                                               aspectRatio: floorplanAspectRatio, image: userFloorplanImage)
        let roomsToDraw = snapshot.rooms
        let report = snapshot.report
        let heading = snapshot.heading
        let state = floorplanHeadingState
        let bgImage = snapshot.image
        let planAspectRatio = snapshot.aspectRatio
        let solutionPrefix = lang.t("floorplan_solution_prefix")
        let solarCaption: String
        if motion.hasLocationFix {
            let solarInfo = SolarTimeCalculator.shared.calculate(date: snapshot.date, longitude: motion.longitude)
            solarCaption = "\(solarInfo.localizedDayPillar) \(solarInfo.trueSolarTimeString)"
        } else { solarCaption = lang.t("location_unavailable") }
        let kuaMatch = UserKuaProfileManager.shared.evaluateCompatibility(sittingPalace: state.sittingMountain.palace)
        let kuaSuffix = " · \(kuaMatch.localizedOwnerGuaName) (\(kuaMatch.matchBadgeTitle))"
        let reportMainTitle: String
        let reportSubHeadline: String
        switch lang.effectiveLanguage {
        case .en:
            reportMainTitle = "YanXiang · Whole-Home Floorplan & Feng Shui Report"
            reportSubHeadline = "Period 9 · Nine-Palace Bagua Alignment\(kuaSuffix)"
        case .zhHant:
            reportMainTitle = "演象 · 戶型空間立極與全屋堪輿全案"
            reportSubHeadline = "下元九運 · 九宮八卦立極透視\(kuaSuffix)"
        case .ja:
            reportMainTitle = "演象・間取り立極＆全室風水鑑定レポート"
            reportSubHeadline = "下元九運・九宮八卦立極透視\(kuaSuffix)"
        case .ko:
            reportMainTitle = "연상 · 평면도 입극 및 전택 풍수 감정 보고서"
            reportSubHeadline = "하원 9운 · 구궁팔괘 입극 투시\(kuaSuffix)"
        case .vi:
            reportMainTitle = "Diễn Tượng · Hồ Sơ Phong Thủy & Lập Cực Mặt Bằng"
            reportSubHeadline = "Hạ Nguyên Vận 9 · Thấu Thị Cửu Cung Bát Quái\(kuaSuffix)"
        case .th:
            reportMainTitle = "เหยียนเซี่ยง · รายงานฮวงจุ้ยและจุดศูนย์กลางผังบ้าน"
            reportSubHeadline = "ยุค 9 ล่าง · วิเคราะห์เก้าวังแปดทิศ\(kuaSuffix)"
        case .id:
            reportMainTitle = "YanXiang · Laporan Feng Shui & Titik Pusat Denah Rumah"
            reportSubHeadline = "Periode 9 · Analisis Sembilan Istana Bagua\(kuaSuffix)"
        case .auto, .zhHans:
            reportMainTitle = "演象 · 户型空间立极与全屋堪舆全案"
            reportSubHeadline = "下元九运 · 九宫八卦立极透视\(kuaSuffix)"
        }
        let subText = "\(state.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(state.facingMountain.localizedName)\(lang.t("facing_suffix")) · \(String(format: "%.1f°", state.facingAngle)) · \(state.kongWangLevel.localizedTitle) · \(solarCaption)"

        DispatchQueue.global(qos: .userInitiated).async {
            // The audit can contain more than six rooms/sector findings. Size
            // the export from the complete report so no diagnosis or remedy is
            // silently dropped when the image is generated.
            let listTop: CGFloat = 1000
            let bottomPadding: CGFloat = 48
            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let bodyFont = UIFont.systemFont(ofSize: 17)
            let solutionFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
            let bodyWidth: CGFloat = 920
            func measuredRowHeight(_ item: FloorplanAuditItem) -> CGFloat {
                let titleHeight = (item.title as NSString).boundingRect(
                    with: CGSize(width: bodyWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: titleFont],
                    context: nil
                ).height
                let loreHeight = (item.lore as NSString).boundingRect(
                    with: CGSize(width: bodyWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: bodyFont],
                    context: nil
                ).height
                let solution = "\(solutionPrefix) \(item.solution)"
                let solutionHeight = (solution as NSString).boundingRect(
                    with: CGSize(width: bodyWidth, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: solutionFont],
                    context: nil
                ).height
                // Keep the compact card for short Chinese strings, while
                // allowing localized or user-authored remedies to wrap fully.
                return max(138, ceil(16 + titleHeight + 8 + loreHeight + 8 + solutionHeight + 16))
            }
            let rowHeights = report.map(measuredRowHeight)
            let canvasHeight = max(1920, listTop + rowHeights.reduce(0, +) + bottomPadding)
            let canvasSize = CGSize(width: 1080, height: canvasHeight)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1.0).setFill()
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            // 1. 顶部金边标题卡
            let headerRect = CGRect(x: 40, y: 40, width: 1000, height: 170)
            UIColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: headerRect, cornerRadius: 18).fill()
            UIColor(red: 0.83, green: 0.68, blue: 0.21, alpha: 0.65).setStroke()
            let headerBorder = UIBezierPath(roundedRect: headerRect, cornerRadius: 18)
            headerBorder.lineWidth = 2
            headerBorder.stroke()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: UIColor(red: 0.95, green: 0.85, blue: 0.45, alpha: 1.0)
            ]
            reportMainTitle.draw(at: CGPoint(x: 70, y: 64), withAttributes: titleAttrs)


            subText.draw(at: CGPoint(x: 70, y: 116), withAttributes: [
                .font: UIFont.systemFont(ofSize: 21, weight: .semibold),
                .foregroundColor: UIColor.cyan
            ])
            reportSubHeadline.draw(at: CGPoint(x: 70, y: 154), withAttributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ])

            // 2. 户型立极画板区
            let planBox = CGRect(x: 40, y: 234, width: 1000, height: 740)
            UIColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: planBox, cornerRadius: 18).fill()

            let innerBox = GeometryUtils.aspectFitRect(aspectRatio: planAspectRatio,
                                                       in: planBox.insetBy(dx: 24, dy: 24))
            if let bgImg = bgImage {
                bgImg.draw(in: innerBox, blendMode: .normal, alpha: 0.80)
            }
            for room in roomsToDraw {
                let rx = innerBox.minX + room.rect.origin.x * innerBox.width
                let ry = innerBox.minY + room.rect.origin.y * innerBox.height
                let rw = room.rect.size.width * innerBox.width
                let rh = room.rect.size.height * innerBox.height
                let rRect = CGRect(x: rx, y: ry, width: rw, height: rh)
                let strokeCol: UIColor = (room.type == .missingCorner || room.isBad)
                    ? UIColor(red: 1.0, green: 0.32, blue: 0.32, alpha: 0.9)
                    : (room.isGood ? UIColor(red: 0.25, green: 0.90, blue: 0.55, alpha: 0.9) : UIColor.white.withAlphaComponent(0.45))
                strokeCol.withAlphaComponent(0.18).setFill()
                UIBezierPath(roundedRect: rRect, cornerRadius: 10).fill()
                strokeCol.setStroke()
                let rPath = UIBezierPath(roundedRect: rRect, cornerRadius: 10)
                rPath.lineWidth = 2.5
                rPath.stroke()

                let label = "\(room.name)\n\(room.palaceName)"
                let pStyle = NSMutableParagraphStyle()
                pStyle.alignment = .center
                label.draw(
                    in: CGRect(x: rRect.minX + 4, y: rRect.midY - 22, width: max(20, rRect.width - 8), height: 48),
                    withAttributes: [
                        .font: UIFont.boldSystemFont(ofSize: 17),
                        .foregroundColor: UIColor.white,
                        .paragraphStyle: pStyle
                    ]
                )
            }

            // 太极中宫立极点与八宫辐射线
            let cx = innerBox.minX + snapshot.centroid.x * innerBox.width
            let cy = innerBox.minY + snapshot.centroid.y * innerBox.height
            let radius = min(innerBox.width, innerBox.height) * 0.44
            cg.setStrokeColor(UIColor(red: 0.83, green: 0.68, blue: 0.21, alpha: 0.45).cgColor)
            cg.setLineWidth(2)
            cg.strokeEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
            for i in 0..<8 {
                let boundary = (Double(i) * 45.0 + 22.5 - heading) * .pi / 180.0
                cg.move(to: CGPoint(x: cx, y: cy))
                cg.addLine(to: CGPoint(x: cx + CGFloat(sin(boundary)) * radius, y: cy - CGFloat(cos(boundary)) * radius))
            }
            cg.strokePath()

            UIColor.red.setFill()
            cg.fillEllipse(in: CGRect(x: cx - 14, y: cy - 14, width: 28, height: 28))

            // 3. 底部全屋体检清单
            var cursorY: CGFloat = listTop
            for (item, rowHeight) in zip(report, rowHeights) {
                let rowRect = CGRect(x: 40, y: cursorY, width: 1000, height: rowHeight - 12)
                UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1.0).setFill()
                UIBezierPath(roundedRect: rowRect, cornerRadius: 14).fill()

                let tagColor: UIColor = item.isSevere ? .systemRed : (item.isGood ? .systemGreen : .systemOrange)
                tagColor.setFill()
                cg.fillEllipse(in: CGRect(x: 64, y: cursorY + 24, width: 14, height: 14))

                item.title.draw(in: CGRect(x: 90, y: cursorY + 16, width: 920, height: rowHeight - 16), withAttributes: [
                    .font: titleFont,
                    .foregroundColor: UIColor.white
                ])
                item.lore.draw(in: CGRect(x: 90, y: cursorY + 48, width: 920, height: rowHeight - 48), withAttributes: [
                    .font: bodyFont,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.78)
                ])
                let solution = "\(solutionPrefix) \(item.solution)"
                solution.draw(
                    in: CGRect(x: 90, y: cursorY + 84, width: 920, height: rowHeight - 84),
                    withAttributes: [
                        .font: solutionFont,
                        .foregroundColor: UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 1.0)
                    ]
                )
                cursorY += rowHeight
            }
        }

        // 回主线程更新 SwiftUI 状态并弹出分享面板
        DispatchQueue.main.async {
            guard self.isActive, self.reportExportGeneration == generation else { return }
            self.exportedReportImage = image
            self.showReportShareSheet = true
        }
        }
    }
}

private struct FloorplanReportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct FloorplanRoomTypeEditor: View {
    let titleKey: String
    let room: FloorplanRoom?
    let onDelete: (() -> Void)?
    let onSelect: (FloorplanRoomType) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var showDeleteConfirmation = false

    init(titleKey: String = "floorplan_room_type", room: FloorplanRoom?, onDelete: (() -> Void)? = nil, onSelect: @escaping (FloorplanRoomType) -> Void) {
        self.titleKey = titleKey
        self.room = room
        self.onDelete = onDelete
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(FloorplanRoomType.allCases) { type in
                        Button(action: {
                            onSelect(type)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: type.iconName)
                                    .frame(width: 24)
                                    .foregroundColor(.yanCyan)
                                Text(type.localizedName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if room?.type == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text(LocalizationManager.shared.t(titleKey))
                }
                if onDelete != nil {
                    Section {
                        Button(action: { showDeleteConfirmation = true }) {
                            Label(LocalizationManager.shared.t("floorplan_delete_room"), systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationBarTitle(LocalizationManager.shared.t(titleKey), displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay(
            Group {
                if showDeleteConfirmation, let onDelete = onDelete {
                    FloorplanConfirmDialog(
                        title: LocalizationManager.shared.t("floorplan_delete_room"),
                        message: LocalizationManager.shared.t("floorplan_delete_confirm"),
                        confirmTitle: LocalizationManager.shared.t("floorplan_delete_room"),
                        cancelTitle: LocalizationManager.shared.t("cancel"),
                        onConfirm: {
                            showDeleteConfirmation = false
                            onDelete()
                            presentationMode.wrappedValue.dismiss()
                        },
                        onCancel: { showDeleteConfirmation = false }
                    )
                }
            }
        )
    }
}

/// Self-contained confirmation dialog. It does not depend on UIKit alert
/// presentation, so it keeps working while the host view is re-rendered by
/// high-frequency sensor updates.
struct FloorplanConfirmDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String?
    var confirmColor: Color = Color.red.opacity(0.85)
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            VStack(spacing: 14) {
                Text(title)
                    .adaptiveFont(size: 16, weight: .bold)
                    .foregroundColor(.white)
                Text(message)
                    .adaptiveFont(size: 13)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    if let cancelTitle = cancelTitle {
                        Button(action: onCancel) {
                            Text(cancelTitle)
                                .adaptiveFont(size: 14, weight: .semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .adaptiveFont(size: 14, weight: .semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(confirmColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(18)
            .frame(maxWidth: 300)
            .background(Color(red: 0.14, green: 0.14, blue: 0.18))
            .cornerRadius(14)
        }
    }
}

// MARK: - 房间风水体检详勘弹窗 (Room Audit Detail Sheet)
public struct RoomAuditDetailSheet: View {
    public let room: FloorplanRoom
    private let onEditType: ((FloorplanRoomType) -> Void)?
    private let onDelete: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showTypeEditor = false
    @State private var showDeleteConfirmation = false
    
    public init(
        room: FloorplanRoom,
        onEditType: ((FloorplanRoomType) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.room = room
        self.onEditType = onEditType
        self.onDelete = onDelete
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.11).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 1. 顶部房间名与方位徽章
                        HStack(spacing: 12) {
                            Image(systemName: room.type.iconName)
                                .adaptiveFont(size: 24)
                                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(room.type.localizedName)
                                    .adaptiveFont(size: 16, weight: .bold)
                                    .foregroundColor(.white)
                                
                                Text(room.palaceName.isEmpty ? lang.t("floorplan_analyzing_center") : "\(lang.t("floorplan_palace_prefix"))\(room.palaceName)")
                                    .adaptiveFont(size: 12)
                                    .foregroundColor(Color.yanCyan)
                            }
                            
                            Spacer()
                            
                            Text(localizedLevel)
                                .adaptiveFont(size: 12, weight: .bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(badgeColor.opacity(0.2))
                                .foregroundColor(badgeColor)
                                .cornerRadius(6)
                        }
                        .padding(14)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                        .cornerRadius(12)

                        if let onEditType = onEditType {
                            Button(action: { showTypeEditor = true }) {
                                Label(lang.t("floorplan_room_type"), systemImage: "tag")
                                    .adaptiveFont(size: 12, weight: .semibold)
                                    .foregroundColor(.yanCyan)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(Color.yanCyan.opacity(0.10))
                            .cornerRadius(10)
                            .sheet(isPresented: $showTypeEditor) {
                                FloorplanRoomTypeEditor(room: room) { type in
                                    onEditType(type)
                                }
                            }
                        }

                        if onDelete != nil {
                            Button(action: { showDeleteConfirmation = true }) {
                                Label(lang.t("floorplan_delete_room"), systemImage: "trash")
                                    .adaptiveFont(size: 12, weight: .semibold)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.10))
                            .cornerRadius(10)
                        }
                        
                        // 2. 气场格局诊断
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                Text("\(lang.t("floorplan_diag_prefix"))\(room.inspectionTitle)")
                                    .adaptiveFont(size: 14, weight: .bold)
                                    .foregroundColor(.white)
                            }
                            
                            Text(room.inspectionAdvice)
                                .adaptiveFont(size: 13)
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                        .cornerRadius(12)

                        if !room.inspectionLore.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(lang.t("floorplan_impact_scope"))
                                    .adaptiveFont(size: 13, weight: .bold)
                                    .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.4))
                                Text(room.inspectionLore)
                                    .adaptiveFont(size: 12)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(3)
                            }
                            .padding(14)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                            .cornerRadius(12)
                        }
                        
                        // 3. 经典堪舆古籍与现代环境机理
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.t("floorplan_classic_origin"))
                                .adaptiveFont(size: 13, weight: .bold)
                                .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.4))
                            
                            Text(lang.t("floorplan_yangzhai_quote"))
                                .adaptiveFont(size: 12, design: .serif)
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                        .cornerRadius(12)
                        
                        // 4. 生旺化煞秘笈
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.t("floorplan_master_remedy"))
                                .adaptiveFont(size: 13, weight: .bold)
                                .foregroundColor(Color.green)
                            
                            Text(room.inspectionAdvice.isEmpty ? lang.t("floorplan_room_advice") : room.inspectionAdvice)
                                .adaptiveFont(size: 12)
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .background(Color(red: 0.11, green: 0.12, blue: 0.11))
                        .cornerRadius(12)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitle(lang.t("floorplan_detail_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay(
            Group {
                if showDeleteConfirmation, let onDelete = onDelete {
                    FloorplanConfirmDialog(
                        title: lang.t("floorplan_delete_room"),
                        message: lang.t("floorplan_delete_confirm"),
                        confirmTitle: lang.t("floorplan_delete_room"),
                        cancelTitle: lang.t("cancel"),
                        onConfirm: {
                            showDeleteConfirmation = false
                            onDelete()
                            presentationMode.wrappedValue.dismiss()
                        },
                        onCancel: { showDeleteConfirmation = false }
                    )
                }
            }
        )
    }
    
    private var badgeColor: Color {
        if room.isGood { return .green }
        if room.isSevere { return .red }
        if room.isWarning { return .orange }
        return Color.yanCyan
    }
    
    private var localizedLevel: String {
        let lang = LocalizationManager.shared
        if room.isGood { return lang.t("floorplan_level_auspicious") }
        if room.isSevere { return lang.t("floorplan_level_severe") }
        if room.isWarning { return lang.t("floorplan_level_warning") }
        return lang.t("floorplan_level_neutral")
    }
}
