import SwiftUI
import simd

// MARK: - VR 仿真测绘（无 LiDAR 设备的虚拟测绘路径）
// 测绘优先级：硬件 LiDAR（RoomPlan/场景重建）→ AR 平面测绘 → VR 仿真测绘。
// 本视图在归一化俯视画布上摆放房间、大门与窗，生成 HouseSpatialSurvey，
// 复用统一分析引擎（15 类形煞检测）与 3D 查看器。

/// Coordinate parameters captured when entering the virtual editor.
struct VRSurveyReference {
    let coordinateHeading: Double
    let houseFacingDegrees: Double?
    let normalizedCentroid: CGPoint?
    let yaw: Float

    func worldPoint(x: Float, z: Float, width: Float, depth: Float) -> SIMD3<Float> {
        let angle = yaw.isFinite ? yaw : 0
        let dx = x - width * 0.5
        let dz = z - depth * 0.5
        return SIMD3<Float>(width * 0.5 + dx * cos(angle) - dz * sin(angle), 0,
                            depth * 0.5 + dx * sin(angle) + dz * cos(angle))
    }

    func centroid(width: Float, depth: Float) -> SIMD3<Float>? {
        normalizedCentroid.map {
            worldPoint(x: Float($0.x) * width, z: Float($0.y) * depth, width: width, depth: depth)
        }
    }
}

public struct VRSpatialSurveyView: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) private var presentationMode

    private struct VRRoomItem: Identifiable {
        let id = UUID()
        var type: FloorplanRoomType
        var rect: CGRect // 归一化 0..1，X=开间、Y=进深
    }

    private struct VROpeningItem: Identifiable {
        let id = UUID()
        var isDoor: Bool
        var rect: CGRect
    }

    @ObservedObject private var iap = StoreKitIAPManager.shared
    @State private var showPaywall = false
    @State private var rooms: [VRRoomItem] = []
    @State private var openings: [VROpeningItem] = []
    @State private var selectedType: FloorplanRoomType = .livingRoom
    @State private var selectedID: UUID?
    @State private var lastDrag: [UUID: CGSize] = [:]
    @State private var resultSurvey: HouseSpatialSurvey?
    // VR is a scaled reconstruction path. Keep the scale explicit so a user
    // can enter the measured envelope instead of treating the canvas as a
    // physically accurate 12 × 10 metre scan.
    @State private var widthMetersText: String = "12.0"
    @State private var depthMetersText: String = "10.0"
    @State private var ceilingMetersText: String = "2.8"
    @State private var validationMessage: String?
    /// 尺寸输入框是否处于编辑态：数字键盘没有回车键，聚焦时在尺寸行内显示唯一的「完成」按钮。
    /// （不用 ToolbarItem(.keyboard)：它要求处于 NavigationView 内，且每个输入框各挂一个会重复显示。）
    @FocusState private var isDimensionFieldFocused: Bool
    /// Preserve the measured survey heading when the editor is opened from a
    /// RoomPlan/AR result. A VR correction should not silently switch to the
    /// phone's current facing direction after the user turns around.
    @State private var surveyReference: VRSurveyReference

    private var metersW: CGFloat { boundedMeters(widthMetersText, fallback: 12.0) }
    private var metersD: CGFloat { boundedMeters(depthMetersText, fallback: 10.0) }
    private var ceilingHeight: Float { Float(boundedMeters(ceilingMetersText, fallback: 2.8)) }

    private var enteredDimensionsValid: Bool {
        [widthMetersText, depthMetersText, ceilingMetersText].allSatisfy { text in
            guard let value = Double(text), value.isFinite else { return false }
            return value >= 2.0 && value <= 50.0
        }
    }

    private let selectableTypes: [FloorplanRoomType] = [
        .livingRoom, .masterBedroom, .secondBedroom, .study,
        .kitchen, .bathroom, .balcony, .door,
    ]

    public init(
        initialFloorplanRooms: [FloorplanRoom] = [],
        initialSurvey: HouseSpatialSurvey? = nil,
        initialWidthMeters: CGFloat? = nil,
        initialDepthMeters: CGFloat? = nil,
        initialCeilingMeters: CGFloat? = nil,
        initialCoordinateHeading: Double? = nil,
        initialHouseFacingDegrees: Double? = nil,
        initialCentroid: CGPoint? = nil
    ) {
        if let initialSurvey {
            let seeded = Self.seededItems(from: initialSurvey)
            self._surveyReference = State(initialValue: VRSurveyReference(
                coordinateHeading: initialSurvey.compassHeading,
                houseFacingDegrees: initialSurvey.resolvedHouseFacing,
                normalizedCentroid: seeded.centroid,
                yaw: Self.primaryAxisAngle(from: initialSurvey)
            ))
            self._rooms = State(initialValue: seeded.rooms)
            self._openings = State(initialValue: seeded.openings)
            self._widthMetersText = State(initialValue: String(format: "%.2f", initialSurvey.dimensions.totalWidth))
            self._depthMetersText = State(initialValue: String(format: "%.2f", initialSurvey.dimensions.totalDepth))
            self._ceilingMetersText = State(initialValue: String(format: "%.2f", initialSurvey.dimensions.ceilingHeight))
        } else {
            self._surveyReference = State(initialValue: VRSurveyReference(
                coordinateHeading: initialCoordinateHeading ?? CompassMotionManager.shared.headingState.facingAngle,
                houseFacingDegrees: initialHouseFacingDegrees,
                normalizedCentroid: initialCentroid,
                yaw: 0
            ))
            let seededRooms = initialFloorplanRooms
                .filter { $0.type != .missingCorner }
                .map { VRRoomItem(type: $0.type, rect: Self.clampedRect($0.rect)) }
            self._rooms = State(initialValue: seededRooms)
            if let initialWidthMeters, initialWidthMeters.isFinite, initialWidthMeters > 0 {
                self._widthMetersText = State(initialValue: String(format: "%.2f", initialWidthMeters))
            }
            if let initialDepthMeters, initialDepthMeters.isFinite, initialDepthMeters > 0 {
                self._depthMetersText = State(initialValue: String(format: "%.2f", initialDepthMeters))
            }
            if let initialCeilingMeters, initialCeilingMeters.isFinite, initialCeilingMeters > 0 {
                self._ceilingMetersText = State(initialValue: String(format: "%.2f", initialCeilingMeters))
            }
        }
    }

    public var body: some View {
        VStack(spacing: 8) {
            header
            canvas
            toolbar
        }
        .padding(10)
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: resultPresented) {
            if let survey = resultSurvey {
                House3DSpaceViewer(survey: survey)
            }
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
    }

    private var resultPresented: Binding<Bool> {
        Binding(
            get: { resultSurvey != nil },
            set: { if !$0 { resultSurvey = nil } }
        )
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "view.3d")
                .adaptiveFont(size: 14, weight: .bold)
                .foregroundColor(.yanCyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("vr_survey_title"))
                    .adaptiveFont(size: 15, weight: .bold)
                    .foregroundColor(.white)
                Text(lang.t("vr_survey_hint"))
                    .adaptiveFont(size: 10, weight: .medium)
                    .foregroundColor(.orange)
                Text(lang.t("vr_survey_model_note"))
                    .adaptiveFont(size: 9)
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(.white)
                    .padding(9)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .accessibilityLabel(lang.t("ar_spatial_close"))
        }
    }

    // MARK: - 画布

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                gridBackground(size: geo.size)
                ForEach(rooms) { room in
                    roomView(room, size: geo.size)
                }
                ForEach(openings) { op in
                    openingView(op, size: geo.size)
                }
            }
            .contentShape(Rectangle())
            // `onTapGesture` with a CGPoint callback is an iOS 17 API, while
            // this target still supports iOS 16. A zero-distance drag gives
            // us the local tap location on every supported OS. The occupied
            // check prevents a tap on an existing room/opening from creating
            // a second room behind the selected item.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onEnded { value in
                        // A parent simultaneous drag also receives room move
                        // and resize gestures. Only a near-zero translation
                        // is a canvas tap; otherwise a room drag could add a
                        // duplicate room when its final point leaves the old
                        // rectangle before the child state update lands.
                        guard abs(value.translation.width) < 5,
                              abs(value.translation.height) < 5 else { return }
                        guard !isCanvasPointOccupied(value.location, in: geo.size) else { return }
                        addRoom(at: value.location, in: geo.size)
                    }
            )
        }
        .aspectRatio(metersW / metersD, contentMode: .fit)
        .background(Color(red: 0.05, green: 0.07, blue: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func gridBackground(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            var path = Path()
            let cols = 10
            let rows = 10
            for i in 0...cols {
                let x = CGFloat(i) / CGFloat(cols) * canvasSize.width
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
            }
            for j in 0...rows {
                let y = CGFloat(j) / CGFloat(rows) * canvasSize.height
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
            }
            ctx.stroke(path, with: .color(.white.opacity(0.08)), lineWidth: 1)
        }
    }

    private func roomView(_ room: VRRoomItem, size: CGSize) -> some View {
        let selected = room.id == selectedID
        let tint = tint(for: room.type)
        return ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(tint.opacity(0.32))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tint, lineWidth: selected ? 2.5 : 1.5)
                )
            Text(room.type.localizedName)
                .adaptiveFont(size: 9, weight: .semibold)
                .foregroundColor(.white)
                .padding(3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if selected {
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1))
                    .padding(4)
                    .gesture(resizeGesture(id: room.id, size: size))
            }
        }
        .frame(width: room.rect.width * size.width, height: room.rect.height * size.height)
        .position(x: room.rect.midX * size.width, y: room.rect.midY * size.height)
        .onTapGesture { selectedID = room.id }
        .gesture(moveGesture(id: room.id, size: size))
    }

    private func openingView(_ op: VROpeningItem, size: CGSize) -> some View {
        let selected = op.id == selectedID
        let color: Color = op.isDoor ? .yellow : .cyan
        return ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: selected ? 2 : 1.2))
            Text(op.isDoor ? lang.t("vr_survey_door") : lang.t("vr_survey_window"))
                .adaptiveFont(size: 8, weight: .semibold)
                .foregroundColor(.black.opacity(0.85))
                .padding(1)
            if selected {
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1))
                    .padding(2)
                    .gesture(resizeGesture(id: op.id, size: size))
            }
        }
        .frame(width: op.rect.width * size.width, height: op.rect.height * size.height)
        .position(x: op.rect.midX * size.width, y: op.rect.midY * size.height)
        .onTapGesture { selectedID = op.id }
        .gesture(moveGesture(id: op.id, size: size))
    }

    // MARK: - 手势

    private func moveGesture(id: UUID, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let prev = lastDrag[id] ?? .zero
                let dx = (value.translation.width - prev.width) / size.width
                let dy = (value.translation.height - prev.height) / size.height
                lastDrag[id] = value.translation
                if let ri = rooms.firstIndex(where: { $0.id == id }) {
                    let r = rooms[ri].rect
                    rooms[ri].rect = CGRect(
                        x: min(max(r.minX + dx, 0.02), 0.98 - r.width),
                        y: min(max(r.minY + dy, 0.02), 0.98 - r.height),
                        width: r.width, height: r.height
                    )
                } else if let oi = openings.firstIndex(where: { $0.id == id }) {
                    let r = openings[oi].rect
                    openings[oi].rect = CGRect(
                        x: min(max(r.minX + dx, 0.02), 0.98 - r.width),
                        y: min(max(r.minY + dy, 0.02), 0.98 - r.height),
                        width: r.width, height: r.height
                    )
                }
            }
            .onEnded { _ in lastDrag[id] = nil }
    }

    private func resizeGesture(id: UUID, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let prev = lastDrag[id] ?? .zero
                let dw = (value.translation.width - prev.width) / size.width
                let dh = (value.translation.height - prev.height) / size.height
                lastDrag[id] = value.translation
                if let ri = rooms.firstIndex(where: { $0.id == id }) {
                    let r = rooms[ri].rect
                    rooms[ri].rect = CGRect(
                        x: r.minX,
                        y: r.minY,
                        width: min(max(r.width + dw, 0.06), 0.96 - r.minX),
                        height: min(max(r.height + dh, 0.05), 0.96 - r.minY)
                    )
                } else if let oi = openings.firstIndex(where: { $0.id == id }) {
                    let r = openings[oi].rect
                    openings[oi].rect = CGRect(
                        x: r.minX,
                        y: r.minY,
                        width: min(max(r.width + dw, 0.04), 0.96 - r.minX),
                        height: min(max(r.height + dh, 0.03), 0.96 - r.minY)
                    )
                }
            }
            .onEnded { _ in lastDrag[id] = nil }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(lang.t("vr_survey_dimensions_m"))
                    .adaptiveFont(size: 10, weight: .semibold)
                    .foregroundColor(.white.opacity(0.8))
                dimensionField(title: lang.t("floorplan_width_hint"), text: $widthMetersText)
                dimensionField(title: lang.t("floorplan_depth_hint"), text: $depthMetersText)
                dimensionField(title: lang.t("vr_survey_ceiling_hint"), text: $ceilingMetersText)
                if isDimensionFieldFocused {
                    Button(lang.t("done")) {
                        isDimensionFieldFocused = false
                    }
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(.yanCyan)
                }
            }
            if let validationMessage {
                Text(validationMessage)
                    .adaptiveFont(size: 10, weight: .semibold)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(selectableTypes, id: \.self) { type in
                        Button(action: { selectedType = type }) {
                            Text(type.localizedName)
                                .adaptiveFont(size: 11, weight: .semibold)
                                .foregroundColor(selectedType == type ? .black : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedType == type ? tint(for: type) : Color.white.opacity(0.12))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Button(action: { addRoom(at: nil, in: nil) }) {
                    Label(lang.t("vr_survey_add_room"), systemImage: "plus.square.on.square")
                        .adaptiveFont(size: 11, weight: .semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.blue.opacity(0.75))
                        .cornerRadius(12)
                }
                Button(action: { addOpening(isDoor: true) }) {
                    Label(lang.t("vr_survey_add_door"), systemImage: "door.left.hand.open")
                        .adaptiveFont(size: 11, weight: .semibold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.yellow.opacity(0.9))
                        .cornerRadius(12)
                }
                Button(action: { addOpening(isDoor: false) }) {
                    Label(lang.t("vr_survey_add_window"), systemImage: "rectangle.split.3x1")
                        .adaptiveFont(size: 11, weight: .semibold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.cyan.opacity(0.9))
                        .cornerRadius(12)
                }
                Button(action: clearAll) {
                    Label(lang.t("vr_survey_clear"), systemImage: "trash")
                        .adaptiveFont(size: 11, weight: .semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(12)
                }
                Button(action: generateReport) {
                    Label(lang.t("vr_survey_generate"), systemImage: "wand.and.stars")
                        .adaptiveFont(size: 11, weight: .bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.yanGold)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - 添加与清空

    private func addRoom(at location: CGPoint?, in size: CGSize?) {
        let defaultRect = CGRect(x: 0.39, y: 0.42, width: 0.22, height: 0.16)
        let rect: CGRect
        if let location = location, let size = size {
            let w = defaultRect.width
            let h = defaultRect.height
            let x = min(max(location.x / size.width - w * 0.5, 0.02), 0.98 - w)
            let y = min(max(location.y / size.height - h * 0.5, 0.02), 0.98 - h)
            rect = CGRect(x: x, y: y, width: w, height: h)
        } else {
            rect = defaultRect
        }
        let item = VRRoomItem(type: selectedType, rect: rect)
        rooms.append(item)
        selectedID = item.id
    }

    private func addOpening(isDoor: Bool) {
        let rect = CGRect(x: 0.44, y: 0.03, width: 0.12, height: 0.05)
        let item = VROpeningItem(isDoor: isDoor, rect: rect)
        openings.append(item)
        selectedID = item.id
    }

    private func isCanvasPointOccupied(_ point: CGPoint, in size: CGSize) -> Bool {
        guard size.width > 0, size.height > 0 else { return false }
        let normalized = CGPoint(x: point.x / size.width, y: point.y / size.height)
        return rooms.contains { $0.rect.contains(normalized) }
            || openings.contains { $0.rect.contains(normalized) }
    }

    private func dimensionField(title: String, text: Binding<String>) -> some View {
        HStack(spacing: 2) {
            Text(title)
                .adaptiveFont(size: 9)
                .foregroundColor(.white.opacity(0.65))
            TextField("", text: text)
                .keyboardType(.decimalPad)
                .adaptiveFont(size: 11, design: .monospaced)
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
                .focused($isDimensionFieldFocused)
                .frame(width: 42)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.10))
        .cornerRadius(5)
    }

    private func clearAll() {
        rooms.removeAll()
        openings.removeAll()
        selectedID = nil
        lastDrag.removeAll()
        resultSurvey = nil
        validationMessage = nil
    }

    // MARK: - 生成测绘报告

    private func generateReport() {
        if !iap.hasUnlockedVIP {
            showPaywall = true
            return
        }
        validationMessage = nil
        guard !rooms.isEmpty else {
            validationMessage = lang.t("vr_err_no_room")
            return
        }
        let width = metersW
        let depth = metersD
        let roomH = ceilingHeight

        // A virtual layout is still useful for planning, but invalid dimensions
        // and overlapping room rectangles produce an internally impossible
        // model. Refuse to generate a report until the user has a usable
        // envelope and room topology.
        guard enteredDimensionsValid,
              width.isFinite, depth.isFinite, roomH.isFinite,
              width >= 1.0, depth >= 1.0, roomH >= 2.0 else {
            validationMessage = lang.t("vr_err_invalid_dim")
            return
        }
        let drawableRooms = rooms.filter { $0.type != .door }
        guard !drawableRooms.isEmpty else {
            validationMessage = lang.t("vr_err_only_door")
            return
        }
        let overlapPairs = drawableRooms.indices.reduce(into: 0) { count, i in
            for j in (i + 1)..<drawableRooms.count {
                let overlap = drawableRooms[i].rect.intersection(drawableRooms[j].rect)
                if overlap.width > 0.01, overlap.height > 0.01 { count += 1 }
            }
        }
        // A small overlap can be intentional at a partition boundary. Larger
        // overlaps mean the canvas no longer describes disjoint rooms and the
        // area/九宫 calculations would double count the same floor.
        guard overlapPairs == 0 else {
            validationMessage = lang.t("vr_err_overlap")
            return
        }

        let yaw = surveyReference.yaw.isFinite ? surveyReference.yaw : 0
        let cosYaw = cos(yaw)
        let sinYaw = sin(yaw)
        func worldPoint(_ x: Float, _ z: Float) -> SIMD3<Float> {
            surveyReference.worldPoint(x: x, z: z, width: Float(width), depth: Float(depth))
        }
        func worldNormal(_ n: SIMD3<Float>) -> SIMD3<Float> {
            SIMD3<Float>(n.x * cosYaw - n.z * sinYaw, 0, n.x * sinYaw + n.z * cosYaw)
        }

        var rooms3D: [SpatialRoom3D] = []
        for room in drawableRooms {
            let x = CGFloat(room.rect.midX) * width
            let z = CGFloat(room.rect.midY) * depth
            let w = max(CGFloat(0.5), CGFloat(room.rect.width) * width)
            let d = max(CGFloat(0.5), CGFloat(room.rect.height) * depth)
            let center = worldPoint(Float(x), Float(z))
            rooms3D.append(SpatialRoom3D(
                name: room.type.localizedName,
                type: room.type,
                center: SIMD3<Float>(center.x, roomH * 0.5, center.z),
                size: SIMD3<Float>(Float(w), roomH, Float(d)),
                rotationY: yaw
            ))
        }

        // The canvas is the measured envelope. Keeping the envelope fixed at
        // the entered width/depth makes room coordinates and opening positions
        // share one coordinate system; deriving the envelope from room boxes
        // previously shifted doors and windows whenever a room was moved.
        var walls3D: [SpatialWall3D] = []
        let fx0: Float = 0
        let fx1 = Float(width)
        let fz0: Float = 0
        let fz1 = Float(depth)
        let outerCorners = [worldPoint(fx0, fz0), worldPoint(fx1, fz0), worldPoint(fx1, fz1), worldPoint(fx0, fz1)]
        for index in 0..<4 {
            walls3D.append(SpatialWall3D(start: outerCorners[index], end: outerCorners[(index + 1) % 4], height: roomH, thickness: 0.18, isLoadBearing: false))
        }

        // Rooms are drawn as floor regions in the viewer. Add their perimeter
        // as light partition walls so the 3D result communicates the actual
        // hand-drawn room separation instead of showing floating floor tiles.
        for room in drawableRooms {
            let x0 = Float(room.rect.minX * width)
            let x1 = Float(room.rect.maxX * width)
            let z0 = Float(room.rect.minY * depth)
            let z1 = Float(room.rect.maxY * depth)
            let corners = [worldPoint(x0, z0), worldPoint(x1, z0), worldPoint(x1, z1), worldPoint(x0, z1)]
            for index in 0..<4 {
                walls3D.append(SpatialWall3D(
                    start: corners[index],
                    end: corners[(index + 1) % 4],
                    height: roomH,
                    thickness: 0.10,
                    isLoadBearing: false
                ))
            }
        }

        // A door room imported from 户型立极 represents the entrance even when
        // the user has not placed a separate opening marker in this editor.
        // Seed it at the nearest outer edge so the 3D model and the floorplan
        // share the same entrance direction.
        var openingItems = openings
        if !openingItems.contains(where: { $0.isDoor }),
           let doorRoom = rooms.first(where: { $0.type == .door }) {
            openingItems.append(VROpeningItem(isDoor: true, rect: doorRoom.rect))
        }
        if !openingItems.contains(where: { !$0.isDoor }),
           let balconyRoom = rooms.first(where: { $0.type == .balcony }) {
            openingItems.append(VROpeningItem(isDoor: false, rect: balconyRoom.rect))
        }

        var openings3D: [SpatialOpening3D] = []
        for op in openingItems {
            let placement = openingPlacement(op, width: width, depth: depth)
            let h = min(max(0.6, roomH - 0.1), op.isDoor ? 2.1 : 1.5)
            let position = worldPoint(placement.x, placement.z)
            openings3D.append(SpatialOpening3D(
                type: op.isDoor ? .entranceDoor : .window,
                position: SIMD3<Float>(position.x, h * 0.5, position.z),
                normal: worldNormal(placement.normal),
                width: Float(placement.span),
                height: h
            ))
        }

        let heading = surveyReference.coordinateHeading
        let scanMethodTitle: String
        switch LocalizationManager.shared.effectiveLanguage {
        case .zhHans, .auto: scanMethodTitle = "VR 仿真测绘"
        case .zhHant: scanMethodTitle = "VR 仿真測繪"
        case .en:     scanMethodTitle = "VR Spatial Simulation"
        case .ja:     scanMethodTitle = "VR 空間シミュレーション"
        case .ko:     scanMethodTitle = "VR 공간 시뮬레이션"
        case .vi:     scanMethodTitle = "Mô phỏng không gian VR"
        case .th:     scanMethodTitle = "จำลองพื้นที่ VR"
        case .id:     scanMethodTitle = "Simulasi Ruang VR"
        }
        let survey = HouseSpatialSurveyEngine.analyzeSpatialHouse(
            scanMethod: scanMethodTitle,
            walls: walls3D,
            openings: openings3D,
            beams: [],
            rooms: rooms3D,
            objects: [],
            compassHeading: heading,
            centroidOverride: surveyReference.centroid(width: Float(width), depth: Float(depth)),
            houseFacingDegrees: surveyReference.houseFacingDegrees
        )
        // Keep virtual output separate from the measured archive. A VR edit is
        // a correction/planning result and must never replace the latest
        // LiDAR/RoomPlan survey used by the measured 3D entry and long scroll.
        if let data = try? JSONEncoder().encode(survey) {
            UserDefaults.standard.set(data, forKey: SpatialSurveyArchiveKeys.virtual)
            NotificationCenter.default.post(name: .didUpdateHouseSpatialSurvey, object: nil)
        }
        resultSurvey = survey
        validationMessage = nil
    }

    private func openingPlacement(_ opening: VROpeningItem, width: CGFloat, depth: CGFloat) -> (x: Float, z: Float, normal: SIMD3<Float>, span: CGFloat) {
        let distances: [(edge: Int, value: CGFloat)] = [
            (0, opening.rect.minY),
            (1, 1.0 - opening.rect.maxX),
            (2, 1.0 - opening.rect.maxY),
            (3, opening.rect.minX)
        ]
        let edge = distances.min(by: { $0.value < $1.value })?.edge ?? 0
        switch edge {
        case 1:
            return (Float(width), Float(opening.rect.midY * depth), SIMD3<Float>(1, 0, 0), max(0.5, opening.rect.height * depth))
        case 2:
            return (Float(opening.rect.midX * width), Float(depth), SIMD3<Float>(0, 0, 1), max(0.5, opening.rect.width * width))
        case 3:
            return (0, Float(opening.rect.midY * depth), SIMD3<Float>(-1, 0, 0), max(0.5, opening.rect.height * depth))
        default:
            return (Float(opening.rect.midX * width), 0, SIMD3<Float>(0, 0, -1), max(0.5, opening.rect.width * width))
        }
    }

    private func boundedMeters(_ text: String, fallback: CGFloat) -> CGFloat {
        guard let value = Double(text), value.isFinite else { return fallback }
        return CGFloat(max(1.0, min(100.0, value)))
    }

    private static func clampedRect(_ rect: CGRect) -> CGRect {
        let width = min(max(rect.width, 0.04), 0.96)
        let height = min(max(rect.height, 0.04), 0.96)
        let x = min(max(rect.origin.x, 0), 1 - width)
        let y = min(max(rect.origin.y, 0), 1 - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Project a completed AR/RoomPlan survey into the editor's normalized
    /// canvas. This keeps the VR path useful for correcting a scan instead of
    /// silently replacing a real scan with an empty synthetic layout.
    private static func seededItems(from survey: HouseSpatialSurvey) -> (rooms: [VRRoomItem], openings: [VROpeningItem], centroid: CGPoint) {
        let yaw = primaryAxisAngle(from: survey)
        let cosYaw = cos(yaw)
        let sinYaw = sin(yaw)
        func localPoint(_ x: Float, _ z: Float) -> SIMD2<Float> {
            SIMD2<Float>(x * cosYaw + z * sinYaw, -x * sinYaw + z * cosYaw)
        }
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        for wall in survey.walls {
            let a = localPoint(wall.startX, wall.startZ)
            let b = localPoint(wall.endX, wall.endZ)
            minX = min(minX, min(a.x, b.x))
            maxX = max(maxX, max(a.x, b.x))
            minZ = min(minZ, min(a.y, b.y))
            maxZ = max(maxZ, max(a.y, b.y))
        }
        if !(minX < maxX && minZ < maxZ) {
            let center = localPoint(survey.centroidX, survey.centroidZ)
            minX = center.x - survey.dimensions.totalWidth * 0.5
            maxX = center.x + survey.dimensions.totalWidth * 0.5
            minZ = center.y - survey.dimensions.totalDepth * 0.5
            maxZ = center.y + survey.dimensions.totalDepth * 0.5
        }
        let spanX = max(1.0, maxX - minX)
        let spanZ = max(1.0, maxZ - minZ)
        let roomItems = survey.rooms.map { room in
            // Preserve a room-specific yaw when an archive carries one. The
            // previous center-only conversion treated every rectangle as
            // axis-aligned in the whole-house frame and could rotate it twice
            // when the VR report was generated again.
            let roomYaw = room.rotationY ?? yaw
            let cosRoom = cos(roomYaw)
            let sinRoom = sin(roomYaw)
            let halfX = room.sizeX * 0.5
            let halfZ = room.sizeZ * 0.5
            let worldCorners = [
                SIMD2<Float>(-halfX, -halfZ), SIMD2<Float>(halfX, -halfZ),
                SIMD2<Float>(halfX, halfZ), SIMD2<Float>(-halfX, halfZ)
            ].map { offset in
                let worldX = room.centerX + offset.x * cosRoom - offset.y * sinRoom
                let worldZ = room.centerZ + offset.x * sinRoom + offset.y * cosRoom
                return localPoint(worldX, worldZ)
            }
            let localMinX = worldCorners.map(\.x).min() ?? localPoint(room.centerX, room.centerZ).x
            let localMaxX = worldCorners.map(\.x).max() ?? localMinX + room.sizeX
            let localMinZ = worldCorners.map(\.y).min() ?? localPoint(room.centerX, room.centerZ).y
            let localMaxZ = worldCorners.map(\.y).max() ?? localMinZ + room.sizeZ
            let rect = CGRect(
                x: CGFloat((localMinX - minX) / spanX),
                y: CGFloat((localMinZ - minZ) / spanZ),
                width: CGFloat((localMaxX - localMinX) / spanX),
                height: CGFloat((localMaxZ - localMinZ) / spanZ)
            )
            return VRRoomItem(type: room.type, rect: Self.clampedRect(rect))
        }
        // The VR editor has one explicit entrance type and one window type;
        // interior doors are already represented by room partition walls and
        // must not be reclassified as additional entrances.
        let openingItems = survey.openings.compactMap { opening -> VROpeningItem? in
            guard opening.type != .interiorDoor else { return nil }
            let normal = SIMD2<Float>(opening.normalX, opening.normalZ)
            let localPos = localPoint(opening.posX, opening.posZ)
            let localNormal = SIMD2<Float>(normal.x * cosYaw + normal.y * sinYaw,
                                           -normal.x * sinYaw + normal.y * cosYaw)
            let verticalEdge = abs(localNormal.x) > abs(localNormal.y)
            let rect: CGRect
            if verticalEdge {
                rect = CGRect(
                    x: CGFloat((localPos.x - minX) / spanX - 0.025),
                    y: CGFloat((localPos.y - opening.width * 0.5 - minZ) / spanZ),
                    width: 0.05,
                    height: CGFloat(opening.width / spanZ)
                )
            } else {
                rect = CGRect(
                    x: CGFloat((localPos.x - opening.width * 0.5 - minX) / spanX),
                    y: CGFloat((localPos.y - minZ) / spanZ - 0.025),
                    width: CGFloat(opening.width / spanX),
                    height: 0.05
                )
            }
            return VROpeningItem(isDoor: opening.type == .entranceDoor || opening.type == .interiorDoor, rect: Self.clampedRect(rect))
        }
        let localCentroid = localPoint(survey.centroidX, survey.centroidZ)
        let centroid = CGPoint(x: CGFloat((localCentroid.x - minX) / spanX),
                               y: CGFloat((localCentroid.y - minZ) / spanZ))
        return (roomItems, openingItems, centroid)
    }

    private static func primaryAxisAngle(from survey: HouseSpatialSurvey) -> Float {
        var bestLength: Float = 0
        var bestAngle: Float = 0
        for wall in survey.walls {
            let dx = wall.endX - wall.startX
            let dz = wall.endZ - wall.startZ
            let length = simd_length(SIMD2<Float>(dx, dz))
            guard length > 0.3 else { continue }
            var angle = atan2(dz, dx)
            if angle < 0 { angle += .pi }
            if angle >= .pi { angle -= .pi }
            if length > bestLength {
                bestLength = length
                bestAngle = angle
            }
        }
        return bestAngle
    }

    // MARK: - 视觉辅助

    private func tint(for type: FloorplanRoomType) -> Color {
        switch type {
        case .livingRoom: return .yanGold
        case .masterBedroom: return .pink
        case .secondBedroom: return .purple
        case .study: return .teal
        case .kitchen: return .orange
        case .bathroom: return .cyan
        case .balcony: return .green
        case .door: return .yellow
        case .missingCorner: return .red
        }
    }
}
