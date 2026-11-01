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

    // 画布默认映射：12 米开间 × 10 米进深
    private let metersW: CGFloat = 12.0
    private let metersD: CGFloat = 10.0

    private let selectableTypes: [FloorplanRoomType] = [
        .livingRoom, .masterBedroom, .secondBedroom, .study,
        .kitchen, .bathroom, .balcony, .door,
    ]

    public init() {}

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
            .onTapGesture { location in
                addRoom(at: location, in: geo.size)
            }
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
        let roomH: Float = 2.8

        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minZ = CGFloat.greatestFiniteMagnitude
        var maxZ = -CGFloat.greatestFiniteMagnitude

        var rooms3D: [SpatialRoom3D] = []
        for room in rooms {
            let x = CGFloat(room.rect.midX) * metersW
            let z = CGFloat(room.rect.midY) * metersD
            let w = max(CGFloat(0.5), CGFloat(room.rect.width) * metersW)
            let d = max(CGFloat(0.5), CGFloat(room.rect.height) * metersD)
            rooms3D.append(SpatialRoom3D(
                name: room.type.localizedName,
                type: room.type,
                center: SIMD3<Float>(Float(x), roomH * 0.5, Float(z)),
                size: SIMD3<Float>(Float(w), roomH, Float(d))
            ))
            minX = min(minX, x - w * 0.5)
            maxX = max(maxX, x + w * 0.5)
            minZ = min(minZ, z - d * 0.5)
            maxZ = max(maxZ, z + d * 0.5)
        }

        // 全屋外框墙（VR 测绘不细分房间内隔墙，隔墙由房间矩形表达）
        var walls3D: [SpatialWall3D] = []
        let fx0 = Float(minX)
        let fx1 = Float(maxX)
        let fz0 = Float(minZ)
        let fz1 = Float(maxZ)
        walls3D.append(SpatialWall3D(start: SIMD3<Float>(fx0, 0, fz0), end: SIMD3<Float>(fx1, 0, fz0), height: roomH, thickness: 0.18, isLoadBearing: false))
        walls3D.append(SpatialWall3D(start: SIMD3<Float>(fx1, 0, fz0), end: SIMD3<Float>(fx1, 0, fz1), height: roomH, thickness: 0.18, isLoadBearing: false))
        walls3D.append(SpatialWall3D(start: SIMD3<Float>(fx1, 0, fz1), end: SIMD3<Float>(fx0, 0, fz1), height: roomH, thickness: 0.18, isLoadBearing: false))
        walls3D.append(SpatialWall3D(start: SIMD3<Float>(fx0, 0, fz1), end: SIMD3<Float>(fx0, 0, fz0), height: roomH, thickness: 0.18, isLoadBearing: false))

        var openings3D: [SpatialOpening3D] = []
        for op in openings {
            let w = max(CGFloat(0.5), CGFloat(op.rect.width) * metersW)
            let h: Float = op.isDoor ? 2.1 : 1.5
            // 开口朝外（简化：法线指向画布下方 = 北）
            openings3D.append(SpatialOpening3D(
                type: op.isDoor ? .entranceDoor : .window,
                position: SIMD3<Float>(Float(op.rect.midX * metersW), h * 0.6, Float(op.rect.midY * metersD)),
                normal: SIMD3<Float>(0, 0, 1),
                width: Float(w),
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
        resultSurvey = survey
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
