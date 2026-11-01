import SwiftUI
import SceneKit
import simd
import UIKit

// MARK: - 全屋 3D 空间测绘立体布局与形煞全息查看器

public struct House3DSpaceViewer: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @State public var survey: HouseSpatialSurvey
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var viewMode: ViewAngleMode = .perspective
    @State private var palaceGridMode: PalaceGridMode = .baZhai
    @State private var showDimensions: Bool = true
    @State private var showShaAlerts: Bool = true
    @State private var selectedShaItem: HouseSpatialShaItem? = nil
    @State private var inspectedElementDesc: String? = nil
    @State private var sceneCoordinator: HouseSceneCoordinator? = nil
    @State private var shareSheetItem: SurveyShareReportItem? = nil
    @State private var showRoomTypePanel: Bool = false
    @State private var editRoomTypeMap: [UUID: FloorplanRoomType] = [:]

    public enum ViewAngleMode: String, CaseIterable {
        case perspective = "3D透视"
        case topDown = "正顶俯视"
        case frontEntrance = "大门内视"
    }

    public enum PalaceGridMode: String, CaseIterable {
        case baZhai = "八宅大游年"
        case xuanKong = "玄空九运盘"
        case off = "隐藏理气"
    }

    public init(survey: HouseSpatialSurvey) {
        self._survey = State(initialValue: survey)
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 3D SceneKit View
            House3DSceneRepresentable(
                survey: survey,
                viewMode: viewMode,
                showDimensions: showDimensions,
                showShaAlerts: showShaAlerts,
                palaceGridMode: palaceGridMode,
                selectedShaItem: selectedShaItem,
                onElementTapped: { desc in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.inspectedElementDesc = desc
                    }
                },
                coordinatorRef: { coord in
                    self.sceneCoordinator = coord
                }
            )
            .ignoresSafeArea()

            // 顶部测绘指标看板与构件探查气泡
            VStack(spacing: 8) {
                topMetricsHeader

                // 立极点落空警示（严重凹凸缺角户型中宫回退主功能区）
                if survey.centroidIndirect {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.adaptive(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        Text("立极点落空警示：户型凹凸缺角严重（面积比 < 75%），立极中宫已回退至主功能区重心，请以主厅立极为准")
                            .font(.adaptive(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(10)
                    .transition(.opacity)
                }

                if let desc = inspectedElementDesc {
                    inspectedElementBanner(desc: desc)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if showRoomTypePanel {
                    roomTypePanel
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Spacer()
                // 底部形煞卡片与视角控制条
                bottomControlPanel
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .sheet(item: $shareSheetItem) { report in
            SurveyShareActivityView(activityItems: report.activityItems)
        }
    }

    // MARK: - 顶部测绘总览看板
    private var topMetricsHeader: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cube.transparent")
                        .font(.adaptive(size: 15, weight: .bold))
                        .foregroundColor(.yanGold)
                    Text("全屋 3D 空间测绘模型")
                        .font(.adaptive(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                // 形煞风水评分徽章
                HStack(spacing: 4) {
                    Text("风水体检")
                        .font(.adaptive(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(survey.fengshuiScore)分")
                        .font(.adaptive(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(scoreColor(survey.fengshuiScore))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .cornerRadius(12)

                // 导出 CAD DXF 矢量图
                Button(action: exportAndShareDXF) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.adaptive(size: 11, weight: .bold))
                        Text("CAD")
                            .font(.adaptive(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(Color.yanCyan)
                    .cornerRadius(12)
                }
                .accessibilityLabel("导出工业级 AutoCAD DXF 矢量测绘图")

                // 毛坯房房间类型设定（一键切换类型即时刷新形煞报告）
                Button(action: { showRoomTypePanel.toggle() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "door.sliding.left.hand.closed")
                            .font(.adaptive(size: 11, weight: .bold))
                        Text("房间")
                            .font(.adaptive(size: 10, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(showRoomTypePanel ? Color.orange : Color.white.opacity(0.85))
                    .cornerRadius(12)
                }
                .accessibilityLabel("毛坯房房间类型设定")

                // 导出与分享长图存证
                Button(action: exportAndShareReport) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.adaptive(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.blue.opacity(0.75))
                        .clipShape(Circle())
                }
                .accessibilityLabel("导出全屋测绘与形煞报告")

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.adaptive(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }

            // 测绘核心参数横幅
            HStack(spacing: 12) {
                metricCell(
                    title: "进深 × 开间",
                    value: String(format: "%.2f × %.2f m", survey.dimensions.totalDepth, survey.dimensions.totalWidth)
                )
                Divider().frame(height: 18).background(Color.white.opacity(0.2))
                metricCell(
                    title: "室内净高",
                    value: String(format: "%.2f m", survey.dimensions.ceilingHeight)
                )
                Divider().frame(height: 18).background(Color.white.opacity(0.2))
                metricCell(
                    title: "套内实测",
                    value: String(format: "%.1f m²", survey.dimensions.usableFloorArea)
                )
                Divider().frame(height: 18).background(Color.white.opacity(0.2))
                metricCell(
                    title: "结构开孔",
                    value: "\(survey.openings.count) 处"
                )
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.black.opacity(0.55))
            .cornerRadius(8)
        }
        .padding(12)
        .background(Color.black.opacity(0.85))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.yanGold.opacity(0.3), lineWidth: 1)
        )
    }

    private func inspectedElementBanner(desc: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.adaptive(size: 13, weight: .bold))
                .foregroundColor(.yanGold)
            Text(desc)
                .font(.adaptive(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
            Button(action: {
                withAnimation { self.inspectedElementDesc = nil }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.adaptive(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.12, green: 0.14, blue: 0.20).opacity(0.95))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.yanCyan.opacity(0.6), lineWidth: 1)
        )
    }

    private func metricCell(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.adaptive(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.65))
            Text(value)
                .font(.adaptive(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.yanGold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 70 { return .orange }
        return .red
    }

    // MARK: - 毛坯房房间类型设定面板（冷启动交互修正）
    private var roomTypePanel: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("房间类型设定（毛坯房/空置房）")
                    .font(.adaptive(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showRoomTypePanel = false }) {
                    Text("完成")
                        .font(.adaptive(size: 11, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.yanGold)
                        .cornerRadius(10)
                }
            }
            if survey.rooms.isEmpty {
                Text("暂无可设定房间，请先完成测绘")
                    .font(.adaptive(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(survey.rooms) { room in
                            HStack {
                                Text(room.name)
                                    .font(.adaptive(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 66, alignment: .leading)
                                    .lineLimit(1)
                                Text(String(format: "%.1f㎡", room.areaSqMeters))
                                    .font(.adaptive(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 52, alignment: .trailing)
                                Picker(room.name, selection: roomTypeBinding(room)) {
                                    ForEach(FloorplanRoomType.allCases) { t in
                                        Text(t.localizedName).tag(t)
                                    }
                                }
                                .pickerStyle(.menu)
                                .font(.adaptive(size: 11))
                                .tint(.yanCyan)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(9)
                        }
                    }
                }
                .frame(maxHeight: 190)
            }
            Text("切换类型后形煞报告即时重算（毛坯房默认按面积启发式预判）")
                .font(.adaptive(size: 9))
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(12)
        .background(Color.black.opacity(0.82))
        .cornerRadius(14)
    }

    private func roomTypeBinding(_ room: SpatialRoom3D) -> Binding<FloorplanRoomType> {
        Binding(
            get: { editRoomTypeMap[room.id] ?? room.type },
            set: { newType in
                editRoomTypeMap[room.id] = newType
                applyRoomType(newType, for: room)
            }
        )
    }

    /// 将房间改为指定类型并即时重跑全屋形煞分析，刷新 3D 模型与报告
    private func applyRoomType(_ type: FloorplanRoomType, for room: SpatialRoom3D) {
        var updatedRooms = survey.rooms
        if let idx = updatedRooms.firstIndex(where: { $0.id == room.id }) {
            updatedRooms[idx] = SpatialRoom3D(
                id: room.id,
                name: type.localizedName,
                type: type,
                center: room.center,
                size: room.size,
                areaSqMeters: room.areaSqMeters
            )
        }
        let rebuilt = HouseSpatialSurveyEngine.analyzeSpatialHouse(
            scanMethod: survey.scanMethod,
            walls: survey.walls,
            openings: survey.openings,
            beams: survey.beams,
            rooms: updatedRooms,
            objects: survey.objects,
            compassHeading: survey.compassHeading
        )
        survey = rebuilt
    }

    // MARK: - 底部控制条与形煞诊断浮层
    private var bottomControlPanel: some View {
        VStack(spacing: 10) {
            if !survey.shaItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(survey.shaItems) { item in
                            Button(action: {
                                if selectedShaItem?.id == item.id {
                                    selectedShaItem = nil
                                } else {
                                    selectedShaItem = item
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(severityColor(item.severity))
                                        .frame(width: 7, height: 7)
                                    Text(item.title)
                                        .font(.adaptive(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedShaItem?.id == item.id ? Color.yanGold.opacity(0.25) : Color.white.opacity(0.10))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedShaItem?.id == item.id ? Color.yanGold : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                }

                if let item = selectedShaItem ?? survey.shaItems.first {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("【\(item.title)】")
                                .font(.adaptive(size: 12, weight: .bold))
                                .foregroundColor(severityColor(item.severity))
                            Text(item.locationName)
                                .font(.adaptive(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(item.severity.rawValue)
                                .font(.adaptive(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(severityColor(item.severity).opacity(0.25))
                                .cornerRadius(4)
                                .foregroundColor(severityColor(item.severity))
                        }
                        Text(item.detail)
                            .font(.adaptive(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                        Text("💡 化解方案：\(item.solution)")
                            .font(.adaptive(size: 10, weight: .medium))
                            .foregroundColor(.yanGold)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(severityColor(item.severity).opacity(0.4), lineWidth: 1)
                    )
                }
            }

            // 视角与显示开关控制行
            HStack(spacing: 8) {
                // 视角切换 Picker
                HStack(spacing: 4) {
                    ForEach(ViewAngleMode.allCases, id: \.self) { mode in
                        Button(action: { viewMode = mode }) {
                            Text(mode.rawValue)
                                .font(.adaptive(size: 10, weight: .medium))
                                .foregroundColor(viewMode == mode ? .black : .white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(viewMode == mode ? Color.yanGold : Color.white.opacity(0.12))
                                .cornerRadius(8)
                        }
                    }
                }

                Spacer()

                // 理气盘模式切换 (八宅 / 玄空 / 关)
                Button(action: {
                    switch palaceGridMode {
                    case .baZhai: palaceGridMode = .xuanKong
                    case .xuanKong: palaceGridMode = .off
                    case .off: palaceGridMode = .baZhai
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "square.grid.3x3.fill")
                        Text(palaceGridMode == .baZhai ? "八宅" : (palaceGridMode == .xuanKong ? "玄空" : "理气关"))
                    }
                    .font(.adaptive(size: 10, weight: .bold))
                    .foregroundColor(palaceGridMode != .off ? .yanGold : .white.opacity(0.6))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(8)
                }
                .accessibilityLabel("切换八宅或玄空理气投影")

                // 尺寸标注开关
                Button(action: { showDimensions.toggle() }) {
                    Image(systemName: showDimensions ? "ruler.fill" : "ruler")
                        .font(.adaptive(size: 12, weight: .bold))
                        .foregroundColor(showDimensions ? .yanCyan : .white.opacity(0.6))
                        .padding(7)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel("切换尺寸标尺")

                // 形煞警示标注开关
                Button(action: { showShaAlerts.toggle() }) {
                    Image(systemName: showShaAlerts ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                        .font(.adaptive(size: 12, weight: .bold))
                        .foregroundColor(showShaAlerts ? .orange : .white.opacity(0.6))
                        .padding(7)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel("切换形煞警示")

                // 重置视角
                Button(action: {
                    sceneCoordinator?.resetCamera(mode: viewMode)
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.adaptive(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel("重置视角")
            }
            .padding(8)
            .background(Color.black.opacity(0.85))
            .cornerRadius(12)
        }
    }

    private func severityColor(_ severity: SpatialShaSeverity) -> Color {
        switch severity {
        case .auspicious: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func exportAndShareReport() {
        guard let coord = sceneCoordinator, let snapshot = coord.captureSnapshot() else { return }
        let reportImage = SurveyReportRenderer.renderReportImage(survey: survey, snapshot: snapshot)
        self.shareSheetItem = SurveyShareReportItem(activityItems: [reportImage])
    }

    private func exportAndShareDXF() {
        if let dxfURL = survey.exportDXFFileURL() {
            self.shareSheetItem = SurveyShareReportItem(activityItems: [dxfURL])
        }
    }
}

// MARK: - SceneKit 3D 场景封装与渲染器

public struct House3DSceneRepresentable: UIViewRepresentable {
    public let survey: HouseSpatialSurvey
    public let viewMode: House3DSpaceViewer.ViewAngleMode
    public let showDimensions: Bool
    public let showShaAlerts: Bool
    public let palaceGridMode: House3DSpaceViewer.PalaceGridMode
    public let selectedShaItem: HouseSpatialShaItem?
    public let onElementTapped: (String) -> Void
    public let coordinatorRef: (HouseSceneCoordinator) -> Void

    public func makeCoordinator() -> HouseSceneCoordinator {
        HouseSceneCoordinator(onElementTapped: onElementTapped)
    }

    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = true

        let scene = SCNScene()
        scnView.scene = scene

        context.coordinator.setupScene(
            scene: scene,
            view: scnView,
            survey: survey,
            viewMode: viewMode,
            showDimensions: showDimensions,
            showShaAlerts: showShaAlerts,
            palaceGridMode: palaceGridMode
        )

        coordinatorRef(context.coordinator)
        return scnView
    }

    public func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.update(
            survey: survey,
            viewMode: viewMode,
            showDimensions: showDimensions,
            showShaAlerts: showShaAlerts,
            palaceGridMode: palaceGridMode,
            selectedShaItem: selectedShaItem
        )
    }
}

// MARK: - Scene Coordinator 构建 3D 模型

public final class HouseSceneCoordinator: NSObject {
    private weak var scene: SCNScene?
    private weak var scnView: SCNView?
    private var cameraNode = SCNNode()
    private var rootHouseNode = SCNNode()
    private var shaAlertsNode = SCNNode()
    private var dimensionsNode = SCNNode()
    private var baguaGridNode = SCNNode()
    private var currentSurvey: HouseSpatialSurvey?
    private let onElementTapped: (String) -> Void

    public init(onElementTapped: @escaping (String) -> Void) {
        self.onElementTapped = onElementTapped
        super.init()
    }

    public func captureSnapshot() -> UIImage? {
        return scnView?.snapshot()
    }

    public func setupScene(
        scene: SCNScene,
        view: SCNView,
        survey: HouseSpatialSurvey,
        viewMode: House3DSpaceViewer.ViewAngleMode,
        showDimensions: Bool,
        showShaAlerts: Bool,
        palaceGridMode: House3DSpaceViewer.PalaceGridMode
    ) {
        self.scene = scene
        self.scnView = view
        self.currentSurvey = survey

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.45, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.color = UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1.0)
        directionalLight.castsShadow = true
        let lightNode = SCNNode()
        lightNode.light = directionalLight
        lightNode.position = SCNVector3(10, 18, 12)
        lightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(lightNode)

        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 150.0
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        scene.rootNode.addChildNode(rootHouseNode)
        scene.rootNode.addChildNode(baguaGridNode)
        scene.rootNode.addChildNode(shaAlertsNode)
        scene.rootNode.addChildNode(dimensionsNode)

        buildHouseGeometry(survey: survey)
        buildDimensionsLines(survey: survey)
        buildPalaceGridOverlay(survey: survey, mode: palaceGridMode)
        resetCamera(mode: viewMode)

        // 添加轻触手势探查构件
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSceneTap(_:)))
        view.addGestureRecognizer(tap)
    }

    @objc private func handleSceneTap(_ gesture: UITapGestureRecognizer) {
        guard let view = scnView else { return }
        let point = gesture.location(in: view)
        let hits = view.hitTest(point, options: [:])
        guard let firstHit = hits.first else { return }

        if let nodeName = firstHit.node.name, !nodeName.isEmpty {
            onElementTapped(nodeName)
        }
    }

    public func update(
        survey: HouseSpatialSurvey,
        viewMode: House3DSpaceViewer.ViewAngleMode,
        showDimensions: Bool,
        showShaAlerts: Bool,
        palaceGridMode: House3DSpaceViewer.PalaceGridMode,
        selectedShaItem: HouseSpatialShaItem?
    ) {
        dimensionsNode.isHidden = !showDimensions
        shaAlertsNode.isHidden = !showShaAlerts
        baguaGridNode.isHidden = (palaceGridMode == .off)

        buildPalaceGridOverlay(survey: survey, mode: palaceGridMode)

        if let item = selectedShaItem, let coord = item.coordinate {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.6
            cameraNode.look(at: SCNVector3(coord.x, coord.y + 0.5, coord.z))
            SCNTransaction.commit()
        }
    }

    public func resetCamera(mode: House3DSpaceViewer.ViewAngleMode) {
        guard let survey = currentSurvey else { return }
        let cx = survey.centroidX
        let cz = survey.centroidZ
        let maxSpan = max(survey.dimensions.totalWidth, survey.dimensions.totalDepth)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5

        switch mode {
        case .perspective:
            cameraNode.position = SCNVector3(cx + maxSpan * 0.9, maxSpan * 1.1, cz + maxSpan * 1.1)
            cameraNode.look(at: SCNVector3(cx, 0, cz))
        case .topDown:
            cameraNode.position = SCNVector3(cx, maxSpan * 1.7, cz + 0.01)
            cameraNode.look(at: SCNVector3(cx, 0, cz))
        case .frontEntrance:
            if let door = survey.openings.first(where: { $0.type == .entranceDoor }) {
                cameraNode.position = SCNVector3(door.posX - door.normalX * 2.5, 1.6, door.posZ - door.normalZ * 2.5)
                cameraNode.look(at: SCNVector3(cx, 1.2, cz))
            } else {
                cameraNode.position = SCNVector3(cx, 1.6, cz + maxSpan * 0.8)
                cameraNode.look(at: SCNVector3(cx, 1.2, cz))
            }
        }

        SCNTransaction.commit()
    }

    private func buildHouseGeometry(survey: HouseSpatialSurvey) {
        rootHouseNode.childNodes.forEach { $0.removeFromParentNode() }
        shaAlertsNode.childNodes.forEach { $0.removeFromParentNode() }

        let cx = survey.centroidX
        let cz = survey.centroidZ
        let w = survey.dimensions.totalWidth
        let d = survey.dimensions.totalDepth

        let floorGeo = SCNPlane(width: CGFloat(w * 1.35), height: CGFloat(d * 1.35))
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 0.95)
        floorGeo.materials = [floorMat]
        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.eulerAngles.x = -Float.pi / 2
        floorNode.position = SCNVector3(cx, 0, cz)
        rootHouseNode.addChildNode(floorNode)

        addGridLines(centerX: cx, centerZ: cz, width: w * 1.3, depth: d * 1.3)

        // 金色贯通天地的立极中宫光柱
        let pillarGeo = SCNCylinder(radius: 0.18, height: CGFloat(survey.dimensions.ceilingHeight * 1.5))
        let pillarMat = SCNMaterial()
        pillarMat.diffuse.contents = UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 0.75)
        pillarMat.emission.contents = UIColor(red: 0.90, green: 0.70, blue: 0.20, alpha: 0.5)
        pillarGeo.materials = [pillarMat]
        let pillarNode = SCNNode(geometry: pillarGeo)
        pillarNode.position = SCNVector3(cx, survey.dimensions.ceilingHeight * 0.75, cz)
        pillarNode.name = "【全屋太极立极中心】三维坐标 (\(String(format: "%.1f, %.1f", cx, cz)))"
        rootHouseNode.addChildNode(pillarNode)

        let centerRingGeo = SCNTorus(ringRadius: 0.6, pipeRadius: 0.04)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 0.9)
        centerRingGeo.materials = [ringMat]
        let ringNode = SCNNode(geometry: centerRingGeo)
        ringNode.position = SCNVector3(cx, 0.02, cz)
        rootHouseNode.addChildNode(ringNode)

        // 墙体
        for (idx, wall) in survey.walls.enumerated() {
            let start = wall.start
            let end = wall.end
            let len = wall.length
            guard len > 0.1 else { continue }

            let wallHeight = CGFloat(wall.height)
            let wallBox = SCNBox(width: CGFloat(len), height: wallHeight, length: CGFloat(wall.thickness), chamferRadius: 0.02)
            let wallMat = SCNMaterial()
            if wall.isLoadBearing {
                wallMat.diffuse.contents = UIColor(red: 0.40, green: 0.55, blue: 0.75, alpha: 0.70)
            } else {
                wallMat.diffuse.contents = UIColor(red: 0.65, green: 0.75, blue: 0.88, alpha: 0.45)
            }
            wallBox.materials = [wallMat]

            let wallNode = SCNNode(geometry: wallBox)
            let midX = (start.x + end.x) * 0.5
            let midZ = (start.z + end.z) * 0.5
            wallNode.position = SCNVector3(midX, Float(wallHeight) * 0.5, midZ)

            let angle = atan2(end.z - start.z, end.x - start.x)
            wallNode.eulerAngles.y = -angle
            wallNode.name = "墙段 #\(idx + 1)：长 \(String(format: "%.2f", len))m · 高 \(String(format: "%.2f", wall.height))m"
            rootHouseNode.addChildNode(wallNode)
        }

        // 门窗
        for op in survey.openings {
            let opH = CGFloat(op.height)
            let opW = CGFloat(op.width)
            let box = SCNBox(width: opW, height: opH, length: 0.08, chamferRadius: 0.01)
            let mat = SCNMaterial()
            switch op.type {
            case .entranceDoor:
                mat.diffuse.contents = UIColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 0.90)
                mat.emission.contents = UIColor(red: 0.5, green: 0.4, blue: 0.1, alpha: 0.4)
            case .interiorDoor:
                mat.diffuse.contents = UIColor(red: 0.85, green: 0.65, blue: 0.45, alpha: 0.80)
            case .window, .balconyDoor:
                mat.diffuse.contents = UIColor(red: 0.10, green: 0.85, blue: 0.95, alpha: 0.60)
            case .opening:
                mat.diffuse.contents = UIColor(red: 0.30, green: 0.90, blue: 0.50, alpha: 0.50)
            }
            box.materials = [mat]

            let opNode = SCNNode(geometry: box)
            opNode.position = SCNVector3(op.posX, Float(opH) * 0.5, op.posZ)
            let normAngle = atan2(op.normalZ, op.normalX)
            opNode.eulerAngles.y = -normAngle + Float.pi / 2
            opNode.name = "\(op.type.rawValue)：宽 \(String(format: "%.2f", op.width))m × 高 \(String(format: "%.2f", op.height))m · 鲁班尺【\(op.yangGateName)】字门"
            rootHouseNode.addChildNode(opNode)
        }

        // 横梁
        for (idx, beam) in survey.beams.enumerated() {
            let len = simd_distance(SIMD2<Float>(beam.startX, beam.startZ), SIMD2<Float>(beam.endX, beam.endZ))
            guard len > 0.1 else { continue }
            let bGeo = SCNBox(width: CGFloat(len), height: CGFloat(beam.beamDepth), length: CGFloat(beam.beamWidth), chamferRadius: 0.01)
            let bMat = SCNMaterial()
            bMat.diffuse.contents = UIColor(red: 0.80, green: 0.35, blue: 0.25, alpha: 0.85)
            bGeo.materials = [bMat]

            let bNode = SCNNode(geometry: bGeo)
            let midX = (beam.startX + beam.endX) * 0.5
            let midZ = (beam.startZ + beam.endZ) * 0.5
            let y = beam.clearanceHeight + beam.beamDepth * 0.5
            bNode.position = SCNVector3(midX, y, midZ)
            let bAngle = atan2(beam.endZ - beam.startZ, beam.endX - beam.startX)
            bNode.eulerAngles.y = -bAngle
            bNode.name = "结构横梁 #\(idx + 1)：净高 \(String(format: "%.2f", beam.clearanceHeight))m · 跨度 \(String(format: "%.2f", len))m"
            rootHouseNode.addChildNode(bNode)
        }

        // 房间地坪高亮
        for room in survey.rooms {
            let rW = CGFloat(room.sizeX * 0.90)
            let rD = CGFloat(room.sizeZ * 0.90)
            let rGeo = SCNPlane(width: rW, height: rD)
            let rMat = SCNMaterial()
            switch room.type {
            case .livingRoom:
                rMat.diffuse.contents = UIColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 0.15)
            case .masterBedroom, .secondBedroom:
                rMat.diffuse.contents = UIColor(red: 0.25, green: 0.65, blue: 0.95, alpha: 0.15)
            case .kitchen:
                rMat.diffuse.contents = UIColor(red: 0.95, green: 0.40, blue: 0.25, alpha: 0.15)
            case .bathroom:
                rMat.diffuse.contents = UIColor(red: 0.20, green: 0.85, blue: 0.75, alpha: 0.18)
            default:
                rMat.diffuse.contents = UIColor(white: 1.0, alpha: 0.10)
            }
            rGeo.materials = [rMat]
            let rNode = SCNNode(geometry: rGeo)
            rNode.eulerAngles.x = -Float.pi / 2
            rNode.position = SCNVector3(room.centerX, 0.01, room.centerZ)
            rNode.name = "\(room.name)：实测面积 \(String(format: "%.1f", room.areaSqMeters))㎡ · 面宽 \(String(format: "%.2f", room.sizeX))m × 进深 \(String(format: "%.2f", room.sizeZ))m"
            rootHouseNode.addChildNode(rNode)
        }

        buildShaAlertVisuals(survey: survey)
    }

    // MARK: - 3D 尺寸标尺立体线条
    private func buildDimensionsLines(survey: HouseSpatialSurvey) {
        dimensionsNode.childNodes.forEach { $0.removeFromParentNode() }
        let cx = survey.centroidX
        let cz = survey.centroidZ
        let w = survey.dimensions.totalWidth
        let d = survey.dimensions.totalDepth
        let h = survey.dimensions.ceilingHeight

        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 0.85)

        let widthLineGeo = SCNBox(width: CGFloat(w), height: 0.015, length: 0.015, chamferRadius: 0)
        widthLineGeo.materials = [lineMat]
        let widthLineNode = SCNNode(geometry: widthLineGeo)
        widthLineNode.position = SCNVector3(cx, 0.05, cz + d * 0.5 + 0.45)
        widthLineNode.name = "面宽开间尺寸：\(String(format: "%.2f", w)) 米"
        dimensionsNode.addChildNode(widthLineNode)

        let depthLineGeo = SCNBox(width: 0.015, height: 0.015, length: CGFloat(d), chamferRadius: 0)
        depthLineGeo.materials = [lineMat]
        let depthLineNode = SCNNode(geometry: depthLineGeo)
        depthLineNode.position = SCNVector3(cx + w * 0.5 + 0.45, 0.05, cz)
        depthLineNode.name = "进深长度尺寸：\(String(format: "%.2f", d)) 米"
        dimensionsNode.addChildNode(depthLineNode)

        let heightLineGeo = SCNBox(width: 0.015, height: CGFloat(h), length: 0.015, chamferRadius: 0)
        heightLineGeo.materials = [lineMat]
        let heightLineNode = SCNNode(geometry: heightLineGeo)
        heightLineNode.position = SCNVector3(cx - w * 0.5 - 0.45, h * 0.5, cz - d * 0.5 - 0.45)
        heightLineNode.name = "室内净层高尺寸：\(String(format: "%.2f", h)) 米"
        dimensionsNode.addChildNode(heightLineNode)
    }

    // MARK: - 八宅大游年 / 玄空飞星 理气贴地投影
    private func buildPalaceGridOverlay(survey: HouseSpatialSurvey, mode: House3DSpaceViewer.PalaceGridMode) {
        baguaGridNode.childNodes.forEach { $0.removeFromParentNode() }
        guard mode != .off else { return }

        let cx = survey.centroidX
        let cz = survey.centroidZ
        let w = survey.dimensions.totalWidth
        let d = survey.dimensions.totalDepth
        let cellW = CGFloat(w / 3.0)
        let cellD = CGFloat(d / 3.0)

        let facingGua = HouseSpatialSurveyEngine.guaForAngle(survey.compassHeading)
        let sittingAngle = (survey.compassHeading + 180.0).truncatingRemainder(dividingBy: 360.0)
        let sittingGua = HouseSpatialSurveyEngine.guaForAngle(sittingAngle)

        let bazhai = BaZhaiEngine.shared.analyze(sittingPalace: sittingGua, facingPalace: facingGua)
        let facingM = Mountain24Data.shared.mountain(for: survey.compassHeading)
        let sittingM = Mountain24Data.shared.mountain(for: sittingAngle)
        let xkChart = FlyingStarsEngine.shared.calculateChart(sitting: sittingM, facing: facingM)

        for row in -1...1 {
            for col in -1...1 {
                let cellX = cx + Float(col) * Float(cellW)
                let cellZ = cz + Float(row) * Float(cellD)

                let plane = SCNPlane(width: cellW * 0.95, height: cellD * 0.95)
                let mat = SCNMaterial()

                let nodeName: String
                if row == 0 && col == 0 {
                    mat.diffuse.contents = UIColor(red: 0.95, green: 0.85, blue: 0.35, alpha: 0.20)
                    nodeName = "【中宫太极】九运天心：运星 \(xkChart.period)"
                } else {
                    let relX = Double(col)
                    let relZ = Double(row)
                    let angleRad = atan2(relX, -relZ)
                    let angleDeg = (angleRad * 180.0 / Double.pi + 360.0).truncatingRemainder(dividingBy: 360.0)
                    let geoAngle = (angleDeg + survey.compassHeading).truncatingRemainder(dividingBy: 360.0)
                    let cellGua = HouseSpatialSurveyEngine.guaForAngle(geoAngle)

                    if mode == .baZhai {
                        if let item = bazhai.items.first(where: { $0.guaName == cellGua }) {
                            if item.star.isAuspicious {
                                mat.diffuse.contents = UIColor(red: 0.20, green: 0.85, blue: 0.45, alpha: 0.16)
                            } else {
                                mat.diffuse.contents = UIColor(red: 0.85, green: 0.30, blue: 0.25, alpha: 0.15)
                            }
                            nodeName = "【八宅·\(cellGua)宫】\(item.direction)：【\(item.star.name)】(\(item.star.luckLevel.title))"
                        } else {
                            mat.diffuse.contents = UIColor(white: 1.0, alpha: 0.08)
                            nodeName = "【\(cellGua)宫】"
                        }
                    } else {
                        // 玄空飞星模式
                        if let palace = xkChart.palaces.first(where: { $0.guaName == cellGua }) {
                            if palace.facingStar == xkChart.period || palace.mountainStar == xkChart.period {
                                mat.diffuse.contents = UIColor(red: 0.95, green: 0.80, blue: 0.25, alpha: 0.22) // 当旺向星/山星金色发光
                            } else if palace.facingStar == 5 || palace.mountainStar == 5 {
                                mat.diffuse.contents = UIColor(red: 0.88, green: 0.25, blue: 0.20, alpha: 0.20) // 五黄煞显红
                            } else {
                                mat.diffuse.contents = UIColor(red: 0.20, green: 0.65, blue: 0.90, alpha: 0.12)
                            }
                            nodeName = "【玄空九运·\(cellGua)宫】山星 \(palace.mountainStar) · 向星 \(palace.facingStar) · 运星 \(palace.periodStar)"
                        } else {
                            mat.diffuse.contents = UIColor(white: 1.0, alpha: 0.08)
                            nodeName = "【玄空 \(cellGua)宫】"
                        }
                    }
                }

                plane.materials = [mat]
                let node = SCNNode(geometry: plane)
                node.eulerAngles.x = -Float.pi / 2
                node.position = SCNVector3(cellX, 0.012, cellZ)
                node.name = nodeName
                baguaGridNode.addChildNode(node)
            }
        }
    }

    private func buildShaAlertVisuals(survey: HouseSpatialSurvey) {
        for sha in survey.shaItems {
            guard let pos = sha.coordinate else { continue }

            let sphereGeo = SCNSphere(radius: 0.22)
            let sphereMat = SCNMaterial()
            let alertColor = sha.severity == .critical ? UIColor.systemRed : (sha.severity == .warning ? UIColor.systemOrange : UIColor.systemGreen)
            sphereMat.diffuse.contents = alertColor
            sphereMat.emission.contents = alertColor.withAlphaComponent(0.6)
            sphereGeo.materials = [sphereMat]
            let sNode = SCNNode(geometry: sphereGeo)
            sNode.position = SCNVector3(pos.x, max(0.5, pos.y), pos.z)
            sNode.name = "形煞【\(sha.title)】\(sha.locationName)：\(sha.detail)"
            shaAlertsNode.addChildNode(sNode)

            if let targetPos = sha.vectorEnd {
                let dist = simd_distance(pos, targetPos)
                if dist > 0.5 {
                    let beamGeo = SCNCylinder(radius: 0.06, height: CGFloat(dist))
                    let beamMat = SCNMaterial()
                    beamMat.diffuse.contents = alertColor.withAlphaComponent(0.85)
                    beamMat.emission.contents = alertColor.withAlphaComponent(0.8)
                    beamGeo.materials = [beamMat]

                    let beamNode = SCNNode(geometry: beamGeo)
                    let mid = (pos + targetPos) * 0.5
                    beamNode.position = SCNVector3(mid.x, 1.2, mid.z)

                    let dir = simd_normalize(targetPos - pos)
                    let pitch = asin(-dir.y)
                    let yaw = atan2(dir.x, dir.z)
                    beamNode.eulerAngles = SCNVector3(pitch + Float.pi / 2, yaw, Float(0))
                    beamNode.name = "冲煞对流轨迹：\(sha.title)"
                    shaAlertsNode.addChildNode(beamNode)
                }
            }
        }
    }

    private func addGridLines(centerX: Float, centerZ: Float, width: Float, depth: Float) {
        let step: Float = 1.0
        let halfW = width * 0.5
        let halfD = depth * 0.5

        let gridNode = SCNNode()
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = UIColor(white: 0.35, alpha: 0.3)

        var z = -halfD
        while z <= halfD {
            let line = SCNBox(width: CGFloat(width), height: 0.005, length: 0.02, chamferRadius: 0)
            line.materials = [lineMat]
            let node = SCNNode(geometry: line)
            node.position = SCNVector3(centerX, 0.005, centerZ + z)
            gridNode.addChildNode(node)
            z += step
        }

        var x = -halfW
        while x <= halfW {
            let line = SCNBox(width: 0.02, height: 0.005, length: CGFloat(depth), chamferRadius: 0)
            line.materials = [lineMat]
            let node = SCNNode(geometry: line)
            node.position = SCNVector3(centerX + x, 0.005, centerZ)
            gridNode.addChildNode(node)
            x += step
        }

        rootHouseNode.addChildNode(gridNode)
    }
}

// MARK: - 全息长图测绘报告渲染器

public enum SurveyReportRenderer {
    public static func renderReportImage(survey: HouseSpatialSurvey, snapshot: UIImage) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0).setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            // 1. 顶部标题与金线
            "天机演象 · 全屋 3D 空间测绘与形煞全息存证".draw(
                at: CGPoint(x: 50, y: 60),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 34),
                    .foregroundColor: UIColor(red: 0.96, green: 0.85, blue: 0.40, alpha: 1.0)
                ]
            )

            let subtitle = String(
                format: "测绘基准朝向: %.1f° · 空间得分: %d分 · 测绘时间: %@",
                survey.compassHeading,
                survey.fengshuiScore,
                DateFormatter.localizedString(from: survey.timestamp, dateStyle: .medium, timeStyle: .short)
            )
            subtitle.draw(
                at: CGPoint(x: 50, y: 110),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.7)
                ]
            )

            // 2. 绘制 3D 模型透视渲染图
            let snapRect = CGRect(x: 50, y: 160, width: size.width - 100, height: 860)
            snapshot.draw(in: snapRect)
            let borderPath = UIBezierPath(roundedRect: snapRect, cornerRadius: 16)
            UIColor(red: 0.96, green: 0.85, blue: 0.40, alpha: 0.6).setStroke()
            borderPath.lineWidth = 2
            borderPath.stroke()

            // 3. 物理测绘核心数据面板
            let panelRect = CGRect(x: 50, y: 1050, width: size.width - 100, height: 260)
            UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 0.90).setFill()
            UIBezierPath(roundedRect: panelRect, cornerRadius: 14).fill()

            "【房屋全维物理测绘参数】".draw(
                at: CGPoint(x: 75, y: 1070),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 24),
                    .foregroundColor: UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 1.0)
                ]
            )

            let dimsText = String(
                format: "• 开间面宽: %.2f m     • 进深长度: %.2f m\n• 室内净层高: %.2f m    • 进深面宽比: %.2f\n• 套内净面积: %.1f ㎡   • 建筑估算面积: %.1f ㎡\n• 墙体总段数: %d 段     • 门窗开孔总数: %d 处",
                survey.dimensions.totalWidth,
                survey.dimensions.totalDepth,
                survey.dimensions.ceilingHeight,
                survey.dimensions.aspectRatio,
                survey.dimensions.usableFloorArea,
                survey.dimensions.grossFloorArea,
                survey.walls.count,
                survey.openings.count
            )
            let pStyle = NSMutableParagraphStyle()
            pStyle.lineSpacing = 8
            dimsText.draw(
                in: CGRect(x: 75, y: 1115, width: panelRect.width - 50, height: 180),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .regular),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                    .paragraphStyle: pStyle
                ]
            )

            // 4. 全屋形煞体检清单
            let shaHeaderY: CGFloat = 1340
            "【全屋形煞引擎体检结论与化解】".draw(
                at: CGPoint(x: 50, y: shaHeaderY),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 26),
                    .foregroundColor: UIColor(red: 0.96, green: 0.85, blue: 0.40, alpha: 1.0)
                ]
            )

            var curY = shaHeaderY + 45
            for sha in survey.shaItems.prefix(4) {
                let badge = sha.severity == .critical ? "【严重】" : (sha.severity == .warning ? "【警示】" : "【纳吉】")
                let lineTitle = "\(badge) \(sha.title) · \(sha.locationName)"
                let titleColor = sha.severity == .critical ? UIColor.systemRed : (sha.severity == .warning ? UIColor.systemOrange : UIColor.systemGreen)

                lineTitle.draw(
                    at: CGPoint(x: 50, y: curY),
                    withAttributes: [
                        .font: UIFont.boldSystemFont(ofSize: 20),
                        .foregroundColor: titleColor
                    ]
                )
                curY += 28

                let desc = "\(sha.detail)\n化解方案：\(sha.solution)"
                let dStyle = NSMutableParagraphStyle()
                dStyle.lineSpacing = 4
                desc.draw(
                    in: CGRect(x: 50, y: curY, width: size.width - 100, height: 75),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 17),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                        .paragraphStyle: dStyle
                    ]
                )
                curY += 80
            }

            // 5. 底部版权与防伪印记
            "天机演象 AI 空间测绘引擎 · LiDAR 毫米级全息数字化建档".draw(
                at: CGPoint(x: 50, y: size.height - 50),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.4)
                ]
            )
        }
    }
}

public struct SurveyShareReportItem: Identifiable {
    public let id = UUID()
    public let activityItems: [Any]
}

public struct SurveyShareActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
