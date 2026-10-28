import SwiftUI
import UIKit
import Vision
import ImageIO

// MARK: - 户型空间立极与全屋风水体检视图 (Floorplan View - PRD 5.3)

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
    @State private var isEditingRooms: Bool = false
    @State private var activeRoomDragID: String? = nil
    @State private var activeRoomStartRect: CGRect? = nil
    @State private var roomWasDragged = false
    @State private var centroidDragStart: CGPoint? = nil
    @State private var didConsumeFloorplanCredit: Bool = false
    @State private var auditedRooms: [FloorplanRoom] = []
    @State private var auditReport: [FloorplanAuditItem] = []
    @State private var isDetectingRooms: Bool = false
    @State private var roomDetectionMessage: String?
    @State private var roomsBeforeDetection: [FloorplanRoom]?
    @State private var centroidBeforeDetection: CGPoint?
    @State private var showNewRoomTypePicker = false
    @State private var floorplanImageBeforePicker: UIImage?
    
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
    
    public var body: some View {
        // CompassMotionManager publishes tilt and magnetic-field samples more
        // often than the floorplan audit inputs change. Reuse the last audit
        // result so those unrelated samples only redraw the visible overlay.
        let auditResult: (auditedRooms: [FloorplanRoom], report: [FloorplanAuditItem]) = isActive
            ? (auditedRooms, auditReport)
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
        .sheet(isPresented: $showImagePicker) {
            FloorplanImagePicker(selectedImage: $userFloorplanImage) {
                roomsBeforeDetection = nil
                centroidBeforeDetection = nil
                roomDetectionMessage = nil
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
                floorplanImageBeforePicker = nil
            }
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .floorplanSingle)
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
            refreshAudit()
        }
        .onAppear {
            refreshAudit()
        }
        .onChange(of: isActive) { active in
            if active {
                refreshAudit()
            }
        }
        .onChange(of: effectiveHeading) { _ in
            refreshAudit()
        }
        .onChange(of: centroid) { _ in
            refreshAudit()
        }
    }

    /// Keep an already-presented room sheet aligned with the same audit input
    /// used by the canvas and report list. Without this, rotating the compass
    /// or dragging the Tai Ji point updated the page behind the sheet while
    /// the detail card continued to show stale palace/severity text.
    private func refreshAudit() {
        guard isActive else { return }
        let result = FloorplanEngine.shared.auditFloorplan(
            rooms: rooms,
            centroid: centroid,
            heading: effectiveHeading
        )
        auditedRooms = result.auditedRooms
        auditReport = result.report
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
        return true
    }
    
    // MARK: - 顶栏控制
    private func topControlBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("floorplan_title"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text("\(lang.t("floorplan_current_facing"))\(String(format: "%.1f", effectiveHeading))° (\(motion.headingState.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(motion.headingState.facingMountain.localizedName)\(lang.t("facing_suffix")))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
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
                userFloorplanImage = nil
                // Reset both the imported background and any custom room edits
                // so a demo layout can always be restored, even when the user
                // started from the built-in sample without importing an image.
                rooms = FloorplanEngine.shared.generateSampleRooms()
                centroid = CGPoint(x: 0.5, y: 0.5)
                roomsBeforeDetection = nil
                centroidBeforeDetection = nil
                roomDetectionMessage = nil
                didConsumeFloorplanCredit = false
                isEditingRooms = false
                activeRoomDragID = nil
                activeRoomStartRect = nil
                roomWasDragged = false
                refreshAudit()
            }) {
                Text(lang.t("reset_sample"))
                    .font(.system(size: 10))
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
                roomWasDragged = false
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

    @ViewBuilder
    private func headingQualityNotice() -> some View {
        let referenceText = activeNorthReference == .trueNorth
            ? lang.t("heading_reference_true")
            : lang.t("heading_reference_magnetic")
        VStack(alignment: .leading, spacing: 3) {
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
                Button(action: {
                    compassRotation = motion.headingState.facingAngle
                    refreshAudit()
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
        guard let image = userFloorplanImage,
              let cgImage = image.cgImage,
              !isDetectingRooms else { return }

        isDetectingRooms = true
        roomDetectionMessage = lang.t("floorplan_detecting")
        let orientation = Self.cgOrientation(for: image.imageOrientation)
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
                    isDetectingRooms = false
                    guard !candidates.isEmpty else {
                        roomDetectionMessage = lang.t("floorplan_detect_failed")
                        return
                    }
                    applyRoomCandidates(candidates)
                }
            } catch {
                DispatchQueue.main.async { [self] in
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
        let orderedRoomIndices = rooms.indices.sorted {
            rooms[$0].rect.width * rooms[$0].rect.height > rooms[$1].rect.width * rooms[$1].rect.height
        }
        let orderedCandidates = candidates.prefix(rooms.count)
        var updatedRooms = rooms
        for (offset, candidate) in orderedCandidates.enumerated() {
            updatedRooms[orderedRoomIndices[offset]].rect = candidate
        }
        rooms = updatedRooms
        isEditingRooms = true

        let union = orderedCandidates.dropFirst().reduce(orderedCandidates.first ?? .zero) { $0.union($1) }
        if !union.isNull {
            centroid = CGPoint(x: union.midX, y: union.midY)
        }
        roomDetectionMessage = "\(lang.t("floorplan_detected")) \(orderedCandidates.count)"
        refreshAudit()
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
        refreshAudit()
    }

    private func updateRoomType(roomID: String, type: FloorplanRoomType) {
        guard let index = rooms.firstIndex(where: { $0.id == roomID }) else { return }
        rooms[index].type = type
        rooms[index].name = type.localizedName
        roomsBeforeDetection = nil
        centroidBeforeDetection = nil
        refreshAudit()
        selectedRoom = nil
    }

    private func addRoom(type: FloorplanRoomType) {
        let roomWidth: CGFloat = 0.23
        let roomHeight: CGFloat = 0.18
        let column = rooms.count % 3
        let row = (rooms.count / 3) % 4
        let origin = CGPoint(
            x: min(1.0 - roomWidth, 0.05 + CGFloat(column) * 0.25),
            y: min(1.0 - roomHeight, 0.06 + CGFloat(row) * 0.21)
        )
        rooms.append(FloorplanRoom(
            name: type.localizedName,
            type: type,
            rect: CGRect(x: origin.x, y: origin.y, width: roomWidth, height: roomHeight)
        ))
        roomsBeforeDetection = nil
        centroidBeforeDetection = nil
        isEditingRooms = true
        refreshAudit()
    }

    private func deleteRoom(roomID: String) {
        guard rooms.count > 1 else { return }
        rooms.removeAll { $0.id == roomID }
        roomsBeforeDetection = nil
        centroidBeforeDetection = nil
        refreshAudit()
        selectedRoom = nil
    }

    private func adjustManualHeading(by delta: Double) {
        compassRotation = (compassRotation + delta).truncatingRemainder(dividingBy: 360)
        if compassRotation < 0 { compassRotation += 360 }
        refreshAudit()
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
            let w = geo.size.width
            let h = geo.size.height
            let centerPt = CGPoint(x: centroid.x * w, y: centroid.y * h)
            
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
                        .opacity(0.85)
                }
                
                // 户型外墙与房间隔断
                ForEach(auditedRooms) { room in
                    roomBlockView(room: room, w: w, h: h)
                }
                
                // 随动半透明罗盘八宫扇区与十字天心
                compassOverlayLayer(centerPt: centerPt, size: min(w, h))
                
                // 可拖拽的中宫立极点 (Centroid Handle)
                centroidHandle(centerPt: centerPt, w: w, h: h)
            }
            .clipped()
            .cornerRadius(12)
        }
    }
    
    private func roomBlockView(room: FloorplanRoom, w: CGFloat, h: CGFloat) -> some View {
        let rx = room.rect.origin.x * w
        let ry = room.rect.origin.y * h
        let rw = room.rect.size.width * w
        let rh = room.rect.size.height * h
        
        let isBad = room.isBad
        let isGood = room.isGood
        let strokeColor = isBad ? Color.red : (isGood ? Color.green : Color.white.opacity(0.25))
        let bgColor = isBad ? Color.red.opacity(0.15) : (isGood ? Color.green.opacity(0.12) : Color.white.opacity(0.05))
        
        return Button(action: {
            // Tapping always opens the diagnostic sheet. Room placement still
            // uses the drag gesture while editing, and type changes are
            // available from a dedicated action inside the diagnostic sheet.
            if roomWasDragged {
                roomWasDragged = false
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
                            .stroke(strokeColor, lineWidth: isBad ? 1.5 : 1)
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
        .position(x: rx + rw / 2, y: ry + rh / 2)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    guard isEditingRooms else { return }

                    if abs(value.translation.width) > 3 || abs(value.translation.height) > 3 {
                        roomWasDragged = true
                    }

                    if activeRoomDragID != room.id {
                        activeRoomDragID = room.id
                        activeRoomStartRect = room.rect
                    }
                    guard let startRect = activeRoomStartRect,
                          let index = rooms.firstIndex(where: { $0.id == room.id }) else { return }

                    let dx = value.translation.width / max(w, 1)
                    let dy = value.translation.height / max(h, 1)
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
                    refreshAudit()
                }
        )
    }
    
    private func compassOverlayLayer(centerPt: CGPoint, size: CGFloat) -> some View {
        let r = size * 0.44
        
        return ZStack {
            // 八宫辐射线
            ForEach(0..<8) { i in
                let angle = Double(i) * 45.0 - effectiveHeading
                Path { p in
                    p.move(to: centerPt)
                    let rad = angle * .pi / 180.0
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
        }
        .allowsHitTesting(false)
    }
    
    private func centroidHandle(centerPt: CGPoint, w: CGFloat, h: CGFloat) -> some View {
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
                    let newX = max(0.1, min(0.9, start.x + val.translation.width / max(w, 1)))
                    let newY = max(0.1, min(0.9, start.y + val.translation.height / max(h, 1)))
                    centroid = CGPoint(x: newX, y: newY)
                }
                .onEnded { _ in
                    centroidDragStart = nil
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
}

private struct FloorplanRoomTypeEditor: View {
    let titleKey: String
    let room: FloorplanRoom?
    let onSelect: (FloorplanRoomType) -> Void
    @Environment(\.presentationMode) private var presentationMode

    init(titleKey: String = "floorplan_room_type", room: FloorplanRoom?, onSelect: @escaping (FloorplanRoomType) -> Void) {
        self.titleKey = titleKey
        self.room = room
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
