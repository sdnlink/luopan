import SwiftUI
import UIKit
import Vision
import ImageIO

// MARK: - 户型空间立极与全屋风水体检视图 (Floorplan View - PRD 5.3)

extension Notification.Name {
    public static let didImportRoomPlanFloorplan = Notification.Name("com.yanxiang.compass.didImportRoomPlanFloorplan")
}

private struct SavedFloorplanLayout: Codable {
    let rooms: [FloorplanRoom]
    let centroidX: Double
    let centroidY: Double
    let compassRotation: Double
    let isSyncWithCompass: Bool
    let hasFloorplanAccess: Bool
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
    @State private var auditedRooms: [FloorplanRoom] = []
    @State private var auditReport: [FloorplanAuditItem] = []
    @State private var isDetectingRooms: Bool = false
    @State private var roomDetectionGeneration: Int = 0
    @State private var roomDetectionMessage: String?
    @State private var roomsBeforeDetection: [FloorplanRoom]?
    @State private var centroidBeforeDetection: CGPoint?
    @State private var showNewRoomTypePicker = false
    @State private var roomForTypeEditing: FloorplanRoom?
    @State private var floorplanImageBeforePicker: UIImage?
    @State private var lastAuditedHeading: Double?
    @State private var lastAuditedCentroid: CGPoint?
    @State private var didRestorePersistedLayout = false
    @State private var showARSpatialSurvey: Bool = false
    @State private var exportedReportImage: UIImage? = nil
    @State private var showReportShareSheet: Bool = false
    // Room/center edits call persistLayout frequently. Keep the image
    // identity so a large JPEG is encoded only when the imported image
    // itself changes, rather than after every drag gesture.
    @State private var persistedImageObjectID: ObjectIdentifier?

    private static let savedLayoutKey = "tiandi_floorplan_saved_layout_v1"
    private static let savedImageFileName = "floorplan-background.jpg"
    
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

    private var floorplanHeadingState: CompassHeadingState {
        if isSyncWithCompass {
            return motion.headingState
        }
        return Mountain24Data.shared.resolveHeadingState(
            heading: compassRotation,
            pitch: motion.pitch,
            roll: motion.roll
        )
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
                VStack(spacing: 8) {
                // 1. 顶部控制栏
                topControlBar()

                headingQualityNotice()

                if userFloorplanImage != nil {
                    roomDetectionBar()
                }

                if isEditingRooms {
                    roomLayoutTools()
                    if let editingRoom = editingRoom {
                        roomResizeTools(room: editingRoom)
                    }
                }
                
                // 2. 户型交互画布 (户型图 + 随动罗盘半透明扇区 + 立极中宫点)
                floorplanCanvasView(auditedRooms: auditResult.auditedRooms)
                    .frame(height: 340)
                    .padding(.horizontal, 16)

                if !isSyncWithCompass {
                    manualHeadingControl()
                        .padding(.horizontal, 16)
                }
                
                // 3. 底部体检报告与房间列表
                auditListSection(report: auditResult.report)
            }
            .padding(.top, 8)
        }
        }
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
                let replacingExistingPlan = floorplanImageBeforePicker != nil
                roomsBeforeDetection = nil
                centroidBeforeDetection = nil
                roomDetectionMessage = nil
                roomDetectionGeneration &+= 1
                isDetectingRooms = false
                if !iap.hasUnlockedVIP {
                    guard iap.consumeFloorplanCredit() else {
                        // UIImagePickerController updates the binding before
                        // this callback. Restore the previous plan when the
                        // user tries to switch without another entitlement.
                        userFloorplanImage = floorplanImageBeforePicker
                        showPaywall = true
                        return
                    }
                    didConsumeFloorplanCredit = true
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
                floorplanImageBeforePicker = nil
                persistLayout()
                refreshAudit(force: true)
            }
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .floorplanSingle)
        }
        .sheet(isPresented: $showARSpatialSurvey) {
            ARSpatialSurveyView()
        }
        .sheet(isPresented: $showReportShareSheet) {
            if let reportImage = exportedReportImage {
                FloorplanReportShareSheet(items: [reportImage])
            }
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
                roomDetectionGeneration &+= 1
                isDetectingRooms = false
            }
        }
        .onChange(of: effectiveHeading) { _ in
            refreshAudit()
        }
        .onChange(of: centroid) { _ in
            refreshAudit()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            persistLayout()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didImportRoomPlanFloorplan)) { _ in
            didRestorePersistedLayout = false
            persistedImageObjectID = nil
            restorePersistedLayoutIfNeeded()
            refreshAudit(force: true)
        }
    }

    public static func persistRoomPlanImport(
        rooms: [FloorplanRoom],
        centroid: CGPoint,
        blueprintImage: UIImage?,
        compassHeading: Double? = nil
    ) {
        let sanitizedRooms = rooms.map { sanitizedRoom($0) }
        let resolvedHeading = compassHeading.map { normalizedHeading($0) } ?? CompassMotionManager.shared.headingState.facingAngle
        let saved = SavedFloorplanLayout(
            rooms: sanitizedRooms,
            centroidX: Double(clampedUnit(Double(centroid.x), fallback: 0.5)),
            centroidY: Double(clampedUnit(Double(centroid.y), fallback: 0.5)),
            compassRotation: resolvedHeading,
            isSyncWithCompass: compassHeading == nil,
            hasFloorplanAccess: true
        )
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: savedLayoutKey)
        }
        if let imageURL = savedImageURL() {
            if let image = blueprintImage,
               let imageData = image.jpegData(compressionQuality: 0.85) ?? image.pngData() {
                try? imageData.write(to: imageURL, options: .atomic)
            }
        }
        NotificationCenter.default.post(name: .didImportRoomPlanFloorplan, object: nil)
    }

    /// Restore the last editable plan once per view lifetime. Room geometry is
    /// normalized on load so a corrupted or stale local record cannot place a
    /// room outside the canvas or produce invalid SwiftUI frames.
    private func restorePersistedLayoutIfNeeded() {
        guard !didRestorePersistedLayout else { return }
        didRestorePersistedLayout = true
        guard let data = UserDefaults.standard.data(forKey: Self.savedLayoutKey),
              let saved = try? JSONDecoder().decode(SavedFloorplanLayout.self, from: data) else { return }

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
        didConsumeFloorplanCredit = saved.hasFloorplanAccess

        if let imageURL = Self.savedImageURL(),
           let image = UIImage(contentsOfFile: imageURL.path) {
            userFloorplanImage = image
        }
    }

    /// Keep the image outside UserDefaults and store only the small editable
    /// layout model there. This avoids a large synchronous defaults write when
    /// a user imports a camera photo or a high-resolution floor plan.
    private func persistLayout() {
        let saved = SavedFloorplanLayout(
            rooms: rooms,
            centroidX: Double(centroid.x),
            centroidY: Double(centroid.y),
            compassRotation: Self.normalizedHeading(compassRotation),
            isSyncWithCompass: isSyncWithCompass,
            hasFloorplanAccess: didConsumeFloorplanCredit
        )
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.savedLayoutKey)
        }

        guard let imageURL = Self.savedImageURL() else { return }
        let imageObjectID = userFloorplanImage.map { ObjectIdentifier($0) }
        guard imageObjectID != persistedImageObjectID else { return }
        do {
            if let image = userFloorplanImage,
               let imageData = image.jpegData(compressionQuality: 0.82) ?? image.pngData() {
                try imageData.write(to: imageURL, options: .atomic)
                persistedImageObjectID = imageObjectID
            } else if FileManager.default.fileExists(atPath: imageURL.path) {
                try FileManager.default.removeItem(at: imageURL)
                persistedImageObjectID = nil
            }
        } catch {
            // A layout can still be restored without its optional background.
            // Do not interrupt editing just because the sandbox is full.
            print("Unable to persist floorplan image: \(error.localizedDescription)")
        }
    }

    private static func savedImageURL() -> URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return directory.appendingPathComponent(savedImageFileName, isDirectory: false)
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
    private func refreshAudit(force: Bool = false) {
        guard isActive else { return }
        if !force,
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
            heading: effectiveHeading
        )
        auditedRooms = result.auditedRooms
        auditReport = result.report
        lastAuditedHeading = effectiveHeading
        lastAuditedCentroid = centroid
        if let selectedID = selectedRoom?.id {
            selectedRoom = result.auditedRooms.first(where: { $0.id == selectedID })
        }
    }

    private var hasFloorplanAccess: Bool {
        iap.hasUnlockedVIP || didConsumeFloorplanCredit
    }

    private func acquireFloorplanAccess() -> Bool {
        if iap.hasUnlockedVIP || didConsumeFloorplanCredit { return true }
        guard iap.consumeFloorplanCredit() else {
            showPaywall = true
            return false
        }
        didConsumeFloorplanCredit = true
        persistLayout()
        return true
    }
    
    // MARK: - 顶栏控制
    private func topControlBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("floorplan_title"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text("\(lang.t("floorplan_current_facing"))\(String(format: "%.1f", effectiveHeading))° (\(floorplanHeadingState.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(floorplanHeadingState.facingMountain.localizedName)\(lang.t("facing_suffix")))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .layoutPriority(1)
            }
            
            Spacer()

            // AR 空间测绘 / RoomPlan 扫描快速入口
            Button(action: {
                showARSpatialSurvey = true
            }) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 11, weight: .bold))
                    .padding(6)
                    .background(Color(red: 0.95, green: 0.80, blue: 0.25).opacity(0.22))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .cornerRadius(6)
            }
            .accessibilityLabel(lang.t("ar_spatial_survey"))
            
            // 导入真实户型图纸
            Button(action: {
                if iap.hasUnlockedVIP || iap.floorplanCreditsCount > 0 {
                    floorplanImageBeforePicker = userFloorplanImage
                    showImagePicker = true
                } else {
                    showPaywall = true
                }
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "photo.badge.plus")
                    Text(userFloorplanImage == nil ? lang.t("import_plan") : lang.t("change_plan"))
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Color.yanCyan.opacity(0.2))
                .foregroundColor(Color.yanCyan)
                .cornerRadius(6)
            }
            
            Button(action: {
                showResetConfirmation = true
            }) {
                Text(lang.t("reset_sample"))
                    .font(.system(size: 10))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .alert(isPresented: $showResetConfirmation) {
                Alert(
                    title: Text(lang.t("reset_sample")),
                    message: Text(lang.t("floorplan_reset_confirm")),
                    primaryButton: .destructive(Text(lang.t("reset_sample"))) {
                        resetToSampleLayout()
                    },
                    secondaryButton: .cancel()
                )
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
                .font(.system(size: 11, weight: .bold))
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
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(isEditingRooms ? Color.green.opacity(0.25) : Color.white.opacity(0.1))
                .foregroundColor(isEditingRooms ? .green : .white)
                .cornerRadius(6)
            }
            
            // 重置立极点
            Button(action: {
                centroid = CGPoint(x: 0.5, y: 0.5)
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .padding(5)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .clipShape(Circle())
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
                .font(.system(size: 10, weight: .bold))
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
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(2)
            }
            if roomsBeforeDetection != nil {
                Button(action: undoRoomDetection) {
                    Text(lang.t("floorplan_undo_detect"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private func roomLayoutTools() -> some View {
        HStack(spacing: 8) {
            Button(action: centerFromRoomLayout) {
                Label(lang.t("floorplan_auto_center"), systemImage: "scope")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.yanCyan)
            }
            Button(action: { showNewRoomTypePicker = true }) {
                Label(lang.t("floorplan_add_room"), systemImage: "plus.rectangle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
            }
            Spacer(minLength: 0)
            Text(lang.t("floorplan_editing_hint"))
                .font(.system(size: 9))
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
                Text("\(lang.t("floorplan_selected_room")): \(room.name)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Button {
                    roomForTypeEditing = room
                } label: {
                    Label(lang.t("floorplan_room_type"), systemImage: "tag")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.yanCyan)
                Button {
                    showEditingRoomDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
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
        .alert(isPresented: $showEditingRoomDeleteConfirmation) {
            Alert(
                title: Text(lang.t("floorplan_delete_room")),
                message: Text(lang.t("floorplan_delete_confirm")),
                primaryButton: .destructive(Text(lang.t("floorplan_delete_room"))) {
                    deleteSelectedEditingRoom()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func resizeButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
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
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.75))
                .frame(width: 38, alignment: .leading)
            resizeButton(symbol: "minus", label: decreaseLabel, action: decrease)
            Text(value)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
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

    private func deleteSelectedEditingRoom() {
        guard let selectedEditingRoomID = selectedEditingRoomID else { return }
        deleteRoom(roomID: selectedEditingRoomID)
        self.selectedEditingRoomID = nil
    }

    private func centerFromRoomLayout() {
        let validRooms = rooms.filter {
            $0.type != .missingCorner && $0.rect.width > 0 && $0.rect.height > 0
        }
        let totalArea = validRooms.reduce(0.0) { partial, room in
            partial + Double(room.rect.width * room.rect.height)
        }
        guard totalArea > 0 else { return }
        let weightedX = validRooms.reduce(0.0) { partial, room in
            let area = Double(room.rect.width * room.rect.height)
            return partial + Double(room.rect.midX) * area
        }
        let weightedY = validRooms.reduce(0.0) { partial, room in
            let area = Double(room.rect.width * room.rect.height)
            return partial + Double(room.rect.midY) * area
        }
        centroid = CGPoint(
            x: max(0.05, min(0.95, weightedX / totalArea)),
            y: max(0.05, min(0.95, weightedY / totalArea))
        )
        persistLayout()
    }

    private func resetToSampleLayout() {
        userFloorplanImage = nil
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
        didConsumeFloorplanCredit = false
        persistedImageObjectID = nil
        if let imageURL = Self.savedImageURL(), FileManager.default.fileExists(atPath: imageURL.path) {
            try? FileManager.default.removeItem(at: imageURL)
        }
        UserDefaults.standard.removeObject(forKey: Self.savedLayoutKey)
        refreshAudit(force: true)
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
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
            if motion.isDistorted || motion.accuracyLevel < 2 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(motion.isDistorted
                         ? lang.t("settings_mag_field_warning")
                         : lang.t("calib_precision_need"))
                }
                .font(.system(size: 9, weight: .semibold))
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
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.orange)
                Spacer()
                Text(String(format: "%.1f°", compassRotation))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
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
                        .font(.system(size: 9, weight: .bold))
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
            .font(.system(size: 10, weight: .bold, design: .monospaced))
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

    /// Runs a lightweight Vision rectangle pass over the imported plan. Room
    /// names cannot be inferred reliably from a photograph, so the detected
    /// boxes are applied as layout suggestions to the existing room labels and
    /// remain fully editable by the user.
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
                let candidates = Self.normalizedRoomCandidates(
                    from: request.results as? [VNRectangleObservation] ?? []
                )
                DispatchQueue.main.async { [self] in
                    guard generation == roomDetectionGeneration,
                          userFloorplanImage === sourceImage else { return }
                    isDetectingRooms = false
                    guard !candidates.isEmpty else {
                        roomDetectionMessage = lang.t("floorplan_detect_failed")
                        return
                    }
                    applyRoomCandidates(candidates)
                }
            } catch {
                DispatchQueue.main.async { [self] in
                    guard generation == roomDetectionGeneration,
                          userFloorplanImage === sourceImage else { return }
                    isDetectingRooms = false
                    roomDetectionMessage = lang.t("floorplan_detect_failed")
                }
            }
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

    private func applyRoomCandidates(_ candidates: [CGRect]) {
        guard !rooms.isEmpty else { return }
        roomsBeforeDetection = rooms
        centroidBeforeDetection = centroid
        let orderedRoomIndices = rooms.indices.filter { rooms[$0].type != .missingCorner }.sorted {
            rooms[$0].rect.width * rooms[$0].rect.height > rooms[$1].rect.width * rooms[$1].rect.height
        }
        let orderedCandidates = candidates.prefix(orderedRoomIndices.count)
        var updatedRooms = rooms
        for (offset, candidate) in orderedCandidates.enumerated() {
            updatedRooms[orderedRoomIndices[offset]].rect = candidate
        }
        rooms = updatedRooms
        isEditingRooms = true

        if let firstCandidate = orderedCandidates.first {
            let union = orderedCandidates.dropFirst().reduce(firstCandidate) { $0.union($1) }
            if !union.isNull, union.width > 0, union.height > 0 {
                centroid = CGPoint(x: union.midX, y: union.midY)
            }
        }
        persistLayout()
        roomDetectionMessage = "\(lang.t("floorplan_detected")) \(orderedCandidates.count)"
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
            let layoutRect = floorplanContentRect(image: userFloorplanImage, in: geo.size)
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
                        .scaledToFit()
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
    
    private func floorplanContentRect(image: UIImage?, in canvasSize: CGSize) -> CGRect {
        guard let image = image,
              image.size.width > 0,
              image.size.height > 0,
              canvasSize.width > 0,
              canvasSize.height > 0 else {
            return CGRect(origin: .zero, size: canvasSize)
        }
        let imageAspect = image.size.width / image.size.height
        let canvasAspect = canvasSize.width / canvasSize.height
        if imageAspect > canvasAspect {
            let height = canvasSize.width / imageAspect
            return CGRect(
                x: 0,
                y: (canvasSize.height - height) / 2,
                width: canvasSize.width,
                height: height
            )
        }
        let width = canvasSize.height * imageAspect
        return CGRect(
            x: (canvasSize.width - width) / 2,
            y: 0,
            width: width,
            height: canvasSize.height
        )
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
                
                VStack(spacing: 2) {
                    Image(systemName: room.type.iconName)
                        .font(.system(size: 11))
                        .foregroundColor(strokeColor)
                    Text(room.name)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Text(room.palaceName)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(2)
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
    
    private static let overlayPalaceBadges: [(geoAngle: Double, title: String, star: String, isAuspicious: Bool)] = [
        (0.0,   "坎北", "五黄煞", false),
        (45.0,  "艮东北", "三碧", false),
        (90.0,  "震东", "七赤", false),
        (135.0, "巽东南", "八白财", true),
        (180.0, "离南", "四绿文昌", true),
        (225.0, "坤西南", "六白官", true),
        (270.0, "兑西", "二黑病", false),
        (315.0, "乾西北", "一白吉", true)
    ]

    private func compassOverlayLayer(centerPt: CGPoint, size: CGFloat) -> some View {
        let r = size * 0.44
        let badgeR = size * 0.37

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
            ForEach(0..<Self.overlayPalaceBadges.count, id: \.self) { idx in
                let item = Self.overlayPalaceBadges[idx]
                let screenAngle = item.geoAngle - effectiveHeading
                let rad = screenAngle * .pi / 180.0
                let bx = centerPt.x + CGFloat(sin(rad)) * badgeR
                let by = centerPt.y - CGFloat(cos(rad)) * badgeR
                VStack(spacing: 0) {
                    Text(item.title)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Text(item.star)
                        .font(.system(size: 7, weight: .semibold))
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
                .font(.system(size: 8, weight: .bold))
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
            HStack {
                Text("🏠 \(lang.t("audit_checklist")) (\(report.count))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
                Text(lang.t("drag_center_hint"))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                Button(action: {
                    if acquireFloorplanAccess() {
                        exportFloorplanReport(report: report)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up")
                        Text(lang.t("ar_roomplan_share"))
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.95, green: 0.80, blue: 0.25).opacity(0.22))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            
            ScrollView {
                VStack(spacing: 8) {
                    if !hasFloorplanAccess {
                        VIPLockCardView(
                            title: lang.t("privilege_floorplan_title"),
                            featureDesc: lang.t("privilege_floorplan_desc"),
                            badge: lang.t("vip_badge_title"),
                            targetProductId: .floorplanSingle,
                            onUnlockTap: { showPaywall = true }
                        )
                        
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
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    private func auditItemRow(item: FloorplanAuditItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(item.isSevere ? Color.red : (item.isGood ? Color.green : Color.orange))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(item.isSevere ? lang.t("floorplan_severe_sha") : (item.isGood ? lang.t("grade_auspicious") : lang.t("floorplan_warn_sha")))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(item.isSevere ? Color.red.opacity(0.2) : (item.isGood ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)))
                        .foregroundColor(item.isSevere ? .red : (item.isGood ? .green : .orange))
                        .cornerRadius(4)
                }
                Text(item.lore)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
                Text("\(lang.t("floorplan_solution_prefix")) \(item.solution)")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
            }
        }
        .padding(10)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(8)
    }

    // MARK: - 一键导出全屋户型立极与堪舆全案长图 (PRD 5.3)
    private func exportFloorplanReport(report: [FloorplanAuditItem]) {
        let canvasSize = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let roomsToDraw = auditedRooms.isEmpty ? rooms : auditedRooms
        let state = floorplanHeadingState
        let solarInfo = TrueSolarTimeEngine.shared.computeNow(longitude: motion.longitude)

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
            "演象 · 户型空间立极与全屋堪舆全案".draw(at: CGPoint(x: 70, y: 64), withAttributes: titleAttrs)

            let subText = "\(state.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(state.facingMountain.localizedName)\(lang.t("facing_suffix")) · \(String(format: "%.1f°", effectiveHeading)) · \(state.kongWangLevel.localizedTitle) · \(solarInfo.dayPillar)\(lang.t("day_unit")) \(solarInfo.trueSolarTimeStr)"
            subText.draw(at: CGPoint(x: 70, y: 116), withAttributes: [
                .font: UIFont.systemFont(ofSize: 21, weight: .semibold),
                .foregroundColor: UIColor.cyan
            ])
            "下元九运 · 九宫八卦立极透视与居家化解建议".draw(at: CGPoint(x: 70, y: 154), withAttributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ])

            // 2. 户型立极画板区
            let planBox = CGRect(x: 40, y: 234, width: 1000, height: 740)
            UIColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: planBox, cornerRadius: 18).fill()

            if let bgImg = userFloorplanImage {
                bgImg.draw(in: planBox.insetBy(dx: 20, dy: 20), blendMode: .normal, alpha: 0.80)
            }

            let innerBox = planBox.insetBy(dx: 24, dy: 24)
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
            let cx = innerBox.minX + centroid.x * innerBox.width
            let cy = innerBox.minY + centroid.y * innerBox.height
            let radius = min(innerBox.width, innerBox.height) * 0.44
            cg.setStrokeColor(UIColor(red: 0.83, green: 0.68, blue: 0.21, alpha: 0.45).cgColor)
            cg.setLineWidth(2)
            cg.strokeEllipse(in: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
            for i in 0..<8 {
                let boundary = (Double(i) * 45.0 + 22.5 - effectiveHeading) * .pi / 180.0
                cg.move(to: CGPoint(x: cx, y: cy))
                cg.addLine(to: CGPoint(x: cx + CGFloat(sin(boundary)) * radius, y: cy - CGFloat(cos(boundary)) * radius))
            }
            cg.strokePath()

            UIColor.red.setFill()
            cg.fillEllipse(in: CGRect(x: cx - 14, y: cy - 14, width: 28, height: 28))

            // 3. 底部全屋体检清单
            var cursorY: CGFloat = 1000
            for item in report.prefix(6) {
                guard cursorY + 138 <= 1880 else { break }
                let rowRect = CGRect(x: 40, y: cursorY, width: 1000, height: 126)
                UIColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 1.0).setFill()
                UIBezierPath(roundedRect: rowRect, cornerRadius: 14).fill()

                let tagColor: UIColor = item.isSevere ? .systemRed : (item.isGood ? .systemGreen : .systemOrange)
                tagColor.setFill()
                cg.fillEllipse(in: CGRect(x: 64, y: cursorY + 24, width: 14, height: 14))

                item.title.draw(at: CGPoint(x: 90, y: cursorY + 16), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 22),
                    .foregroundColor: UIColor.white
                ])
                item.lore.draw(in: CGRect(x: 90, y: cursorY + 48, width: 920, height: 34), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 17),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.78)
                ])
                "\(lang.t("floorplan_solution_prefix")) \(item.solution)".draw(
                    in: CGRect(x: 90, y: cursorY + 84, width: 920, height: 34),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                        .foregroundColor: UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 1.0)
                    ]
                )
                cursorY += 138
            }
        }

        exportedReportImage = image
        showReportShareSheet = true
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
                if let onDelete = onDelete {
                    Section {
                        Button(action: { showDeleteConfirmation = true }) {
                            Label(LocalizationManager.shared.t("floorplan_delete_room"), systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .alert(isPresented: $showDeleteConfirmation) {
                        Alert(
                            title: Text(LocalizationManager.shared.t("floorplan_delete_room")),
                            message: Text(LocalizationManager.shared.t("floorplan_delete_confirm")),
                            primaryButton: .destructive(Text(LocalizationManager.shared.t("floorplan_delete_room"))) {
                                onDelete()
                                presentationMode.wrappedValue.dismiss()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            .navigationBarTitle(LocalizationManager.shared.t(titleKey), displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
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
                                .font(.system(size: 24))
                                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(room.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(room.palaceName.isEmpty ? lang.t("floorplan_analyzing_center") : "\(lang.t("floorplan_palace_prefix"))\(room.palaceName)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.yanCyan)
                            }
                            
                            Spacer()
                            
                            Text(localizedLevel)
                                .font(.system(size: 12, weight: .bold))
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
                                    .font(.system(size: 12, weight: .semibold))
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

                        if let onDelete = onDelete {
                            Button(action: { showDeleteConfirmation = true }) {
                                Label(lang.t("floorplan_delete_room"), systemImage: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.10))
                            .cornerRadius(10)
                            .alert(isPresented: $showDeleteConfirmation) {
                                Alert(
                                    title: Text(lang.t("floorplan_delete_room")),
                                    message: Text(lang.t("floorplan_delete_confirm")),
                                    primaryButton: .destructive(Text(lang.t("floorplan_delete_room"))) {
                                        onDelete()
                                        presentationMode.wrappedValue.dismiss()
                                    },
                                    secondaryButton: .cancel()
                                )
                            }
                        }
                        
                        // 2. 气场格局诊断
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                Text("\(lang.t("floorplan_diag_prefix"))\(room.inspectionTitle)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(room.inspectionAdvice)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                        .cornerRadius(12)

                        if !room.inspectionLore.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(lang.t("floorplan_impact_scope"))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.4))
                                Text(room.inspectionLore)
                                    .font(.system(size: 12))
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
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.4))
                            
                            Text(lang.t("floorplan_yangzhai_quote"))
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
                        .cornerRadius(12)
                        
                        // 4. 生旺化煞秘笈
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.t("floorplan_master_remedy"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.green)
                            
                            Text(room.inspectionAdvice.isEmpty ? lang.t("floorplan_room_advice") : room.inspectionAdvice)
                                .font(.system(size: 12))
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
