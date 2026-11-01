import SwiftUI
import simd

// MARK: - VR 仿真测绘（无 LiDAR 设备的虚拟测绘路径）
// 测绘优先级：硬件 LiDAR（RoomPlan/场景重建）→ AR 平面测绘 → VR 仿真测绘。
// 本视图在归一化俯视画布上摆放房间、大门与窗，生成 HouseSpatialSurvey，
// 复用统一分析引擎（15 类形煞检测）与 3D 查看器。

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

    private var metersW: CGFloat { boundedMeters(widthMetersText, fallback: 12.0) }
    private var metersD: CGFloat { boundedMeters(depthMetersText, fallback: 10.0) }
    private var ceilingHeight: Float { Float(boundedMeters(ceilingMetersText, fallback: 2.8)) }

    private let selectableTypes: [FloorplanRoomType] = [
        .livingRoom, .masterBedroom, .secondBedroom, .study,
        .kitchen, .bathroom, .balcony, .door,
    ]

    public init(
        initialFloorplanRooms: [FloorplanRoom] = [],
        initialSurvey: HouseSpatialSurvey? = nil,
        initialWidthMeters: CGFloat? = nil,
        initialDepthMeters: CGFloat? = nil,
        initialCeilingMeters: CGFloat? = nil
    ) {
        if let initialSurvey {
            let seeded = Self.seededItems(from: initialSurvey)
            self._rooms = State(initialValue: seeded.rooms)
            self._openings = State(initialValue: seeded.openings)
            self._widthMetersText = State(initialValue: String(format: "%.2f", initialSurvey.dimensions.totalWidth))
            self._depthMetersText = State(initialValue: String(format: "%.2f", initialSurvey.dimensions.totalDepth))
            self._ceilingMetersText = State(initialValue: String(format: "%.2f", initialSurvey.dimensions.ceilingHeight))
        } else {
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
                .font(.adaptive(size: 14, weight: .bold))
                .foregroundColor(.yanCyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("vr_survey_title"))
                    .font(.adaptive(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(lang.t("vr_survey_hint"))
                    .font(.adaptive(size: 10, weight: .medium))
                    .foregroundColor(.orange)
                Text("仿真模型：请先填写实测开间、进深和层高；画布仅用于按比例重建")
                    .font(.adaptive(size: 9))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .font(.adaptive(size: 13, weight: .bold))
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
        .aspectRatio(6.0 / 5.0, contentMode: .fit)
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
                .font(.adaptive(size: 9, weight: .semibold))
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
                .font(.adaptive(size: 8, weight: .semibold))
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
                Text("实测尺寸(m)")
                    .font(.adaptive(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                dimensionField(title: "开间", text: $widthMetersText)
                dimensionField(title: "进深", text: $depthMetersText)
                dimensionField(title: "层高", text: $ceilingMetersText)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(selectableTypes, id: \.self) { type in
                        Button(action: { selectedType = type }) {
                            Text(type.localizedName)
                                .font(.adaptive(size: 11, weight: .semibold))
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
                        .font(.adaptive(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.blue.opacity(0.75))
                        .cornerRadius(12)
                }
                Button(action: { addOpening(isDoor: true) }) {
                    Label(lang.t("vr_survey_add_door"), systemImage: "door.left.hand.open")
                        .font(.adaptive(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.yellow.opacity(0.9))
                        .cornerRadius(12)
                }
                Button(action: { addOpening(isDoor: false) }) {
                    Label(lang.t("vr_survey_add_window"), systemImage: "rectangle.split.3x1")
                        .font(.adaptive(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.cyan.opacity(0.9))
                        .cornerRadius(12)
                }
                Button(action: clearAll) {
                    Label(lang.t("vr_survey_clear"), systemImage: "trash")
                        .font(.adaptive(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(12)
                }
                Button(action: generateReport) {
                    Label(lang.t("vr_survey_generate"), systemImage: "wand.and.stars")
                        .font(.adaptive(size: 11, weight: .bold))
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
                .font(.adaptive(size: 9))
                .foregroundColor(.white.opacity(0.65))
            TextField("", text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
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
    }

    // MARK: - 生成测绘报告

    private func generateReport() {
        guard !rooms.isEmpty else { return }
        let width = metersW
        let depth = metersD
        let roomH = ceilingHeight

        var rooms3D: [SpatialRoom3D] = []
        for room in rooms where room.type != .door {
            let x = CGFloat(room.rect.midX) * width
            let z = CGFloat(room.rect.midY) * depth
            let w = max(CGFloat(0.5), CGFloat(room.rect.width) * width)
            let d = max(CGFloat(0.5), CGFloat(room.rect.height) * depth)
            rooms3D.append(SpatialRoom3D(
                name: room.type.localizedName,
                type: room.type,
                center: SIMD3<Float>(Float(x), roomH * 0.5, Float(z)),
                size: SIMD3<Float>(Float(w), roomH, Float(d))
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
        walls3D.append(SpatialWall3D(start: SIMD3<Float>(fx0, 0, fz0), end: SIMD3<Float>(fx1, 0, fz0), height: roomH, thickness: 0.18, isLoadBearing: false))
        walls3D.append(SpatialWall3D(start: SIMD3<Float>(fx1, 0, fz0), end: SIMD3<Float>(fx1, 0, fz1), height: roomH, thickness: 0.18, isLoadBearing: false))
        walls3D.append(SpatialWall3D(start: SIMD3<Float>(fx1, 0, fz1), end: SIMD3<Float>(fx0, 0, fz1), height: roomH, thickness: 0.18, isLoadBearing: false))
        walls3D.append(SpatialWall3D(start: SIMD3<Float>(fx0, 0, fz1), end: SIMD3<Float>(fx0, 0, fz0), height: roomH, thickness: 0.18, isLoadBearing: false))

        // Rooms are drawn as floor regions in the viewer. Add their perimeter
        // as light partition walls so the 3D result communicates the actual
        // hand-drawn room separation instead of showing floating floor tiles.
        for room in rooms where room.type != .door {
            let x0 = Float(room.rect.minX * width)
            let x1 = Float(room.rect.maxX * width)
            let z0 = Float(room.rect.minY * depth)
            let z1 = Float(room.rect.maxY * depth)
            let corners = [
                SIMD3<Float>(x0, 0, z0), SIMD3<Float>(x1, 0, z0),
                SIMD3<Float>(x1, 0, z1), SIMD3<Float>(x0, 0, z1)
            ]
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
            openings3D.append(SpatialOpening3D(
                type: op.isDoor ? .entranceDoor : .window,
                position: SIMD3<Float>(placement.x, h * 0.5, placement.z),
                normal: placement.normal,
                width: Float(placement.span),
                height: h
            ))
        }

        let heading = CompassMotionManager.shared.headingState.facingAngle
        let survey = HouseSpatialSurveyEngine.analyzeSpatialHouse(
            scanMethod: "VR 仿真测绘",
            walls: walls3D,
            openings: openings3D,
            beams: [],
            rooms: rooms3D,
            objects: [],
            compassHeading: heading
        )
        ShaSurveyStore.shared.updateInterior(survey)
        // Keep the generated snapshot in the same local archive consumed by
        // 户型立极 and the report exporter.  Without this write, leaving the
        // VR sheet discarded the model and the floorplan's 3D button kept
        // showing an older RoomPlan result (or no result at all).
        if let data = try? JSONEncoder().encode(survey) {
            UserDefaults.standard.set(data, forKey: "latest_house_spatial_survey")
            NotificationCenter.default.post(name: .didUpdateHouseSpatialSurvey, object: nil)
        }
        resultSurvey = survey
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
    private static func seededItems(from survey: HouseSpatialSurvey) -> (rooms: [VRRoomItem], openings: [VROpeningItem]) {
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        for wall in survey.walls {
            minX = min(minX, min(wall.startX, wall.endX))
            maxX = max(maxX, max(wall.startX, wall.endX))
            minZ = min(minZ, min(wall.startZ, wall.endZ))
            maxZ = max(maxZ, max(wall.startZ, wall.endZ))
        }
        if !(minX < maxX && minZ < maxZ) {
            minX = survey.centroidX - survey.dimensions.totalWidth * 0.5
            maxX = survey.centroidX + survey.dimensions.totalWidth * 0.5
            minZ = survey.centroidZ - survey.dimensions.totalDepth * 0.5
            maxZ = survey.centroidZ + survey.dimensions.totalDepth * 0.5
        }
        let spanX = max(1.0, maxX - minX)
        let spanZ = max(1.0, maxZ - minZ)
        let roomItems = survey.rooms.map { room in
            let rect = CGRect(
                x: CGFloat((room.centerX - room.sizeX * 0.5 - minX) / spanX),
                y: CGFloat((room.centerZ - room.sizeZ * 0.5 - minZ) / spanZ),
                width: CGFloat(room.sizeX / spanX),
                height: CGFloat(room.sizeZ / spanZ)
            )
            return VRRoomItem(type: room.type, rect: Self.clampedRect(rect))
        }
        // The VR editor has one explicit entrance type and one window type;
        // interior doors are already represented by room partition walls and
        // must not be reclassified as additional entrances.
        let openingItems = survey.openings.compactMap { opening -> VROpeningItem? in
            guard opening.type != .interiorDoor else { return nil }
            let normal = SIMD2<Float>(opening.normalX, opening.normalZ)
            let verticalEdge = abs(normal.x) > abs(normal.y)
            let rect: CGRect
            if verticalEdge {
                rect = CGRect(
                    x: CGFloat((opening.posX - minX) / spanX - 0.025),
                    y: CGFloat((opening.posZ - opening.width * 0.5 - minZ) / spanZ),
                    width: 0.05,
                    height: CGFloat(opening.width / spanZ)
                )
            } else {
                rect = CGRect(
                    x: CGFloat((opening.posX - opening.width * 0.5 - minX) / spanX),
                    y: CGFloat((opening.posZ - minZ) / spanZ - 0.025),
                    width: CGFloat(opening.width / spanX),
                    height: 0.05
                )
            }
            return VROpeningItem(isDoor: opening.type == .entranceDoor || opening.type == .interiorDoor, rect: Self.clampedRect(rect))
        }
        return (roomItems, openingItems)
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
