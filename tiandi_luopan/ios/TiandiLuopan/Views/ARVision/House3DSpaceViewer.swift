import SwiftUI
import SceneKit
import simd

// MARK: - 全屋 3D 空间测绘立体布局与形煞全息查看器

public struct House3DSpaceViewer: View {
    @ObservedObject private var lang = LocalizationManager.shared
    public let survey: HouseSpatialSurvey
    @Environment(\.presentationMode) private var presentationMode
    
    @State private var viewMode: ViewAngleMode = .perspective
    @State private var showDimensions: Bool = true
    @State private var showShaAlerts: Bool = true
    @State private var selectedShaItem: HouseSpatialShaItem? = nil
    @State private var sceneCoordinator: HouseSceneCoordinator? = nil

    public enum ViewAngleMode: String, CaseIterable {
        case perspective = "3D透视"
        case topDown = "正顶俯视"
        case frontEntrance = "大门内视"
    }

    public init(survey: HouseSpatialSurvey) {
        self.survey = survey
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
                selectedShaItem: selectedShaItem,
                coordinatorRef: { coord in
                    self.sceneCoordinator = coord
                }
            )
            .ignoresSafeArea()

            // 顶部测绘指标看板
            VStack(spacing: 8) {
                topMetricsHeader
                Spacer()
                // 底部形煞卡片与视角控制条
                bottomControlPanel
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
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
                    title: "房间数",
                    value: "\(max(1, survey.rooms.count)) 室"
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

    // MARK: - 底部控制条与形煞诊断浮层
    private var bottomControlPanel: some View {
        VStack(spacing: 10) {
            // 形煞诊断卡片 (当有形煞项或用户选中项)
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

                // 选中形煞的详细解析与化解方案
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

                // 尺寸标注开关
                Button(action: { showDimensions.toggle() }) {
                    Image(systemName: showDimensions ? "ruler.fill" : "ruler")
                        .font(.adaptive(size: 12, weight: .bold))
                        .foregroundColor(showDimensions ? .yanGold : .white.opacity(0.6))
                        .padding(7)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }

                // 形煞警示标注开关
                Button(action: { showShaAlerts.toggle() }) {
                    Image(systemName: showShaAlerts ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                        .font(.adaptive(size: 12, weight: .bold))
                        .foregroundColor(showShaAlerts ? .orange : .white.opacity(0.6))
                        .padding(7)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }

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
            }
            .padding(8)
            .background(Color.black.opacity(0.85))
            .cornerRadius(12)
        }
    }

    private func severityColor(_ severity: ShaSeverity) -> Color {
        switch severity {
        case .auspicious: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - SceneKit 3D 场景封装与渲染器

public struct House3DSceneRepresentable: UIViewRepresentable {
    public let survey: HouseSpatialSurvey
    public let viewMode: House3DSpaceViewer.ViewAngleMode
    public let showDimensions: Bool
    public let showShaAlerts: Bool
    public let selectedShaItem: HouseSpatialShaItem?
    public let coordinatorRef: (HouseSceneCoordinator) -> Void

    public func makeCoordinator() -> HouseSceneCoordinator {
        HouseSceneCoordinator()
    }

    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = true // 支持单指旋转、双指缩放

        let scene = SCNScene()
        scnView.scene = scene

        context.coordinator.setupScene(
            scene: scene,
            view: scnView,
            survey: survey,
            viewMode: viewMode,
            showDimensions: showDimensions,
            showShaAlerts: showShaAlerts
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
    private var currentSurvey: HouseSpatialSurvey?

    public func setupScene(
        scene: SCNScene,
        view: SCNView,
        survey: HouseSpatialSurvey,
        viewMode: House3DSpaceViewer.ViewAngleMode,
        showDimensions: Bool,
        showShaAlerts: Bool
    ) {
        self.scene = scene
        self.scnView = view
        self.currentSurvey = survey

        // 1. 设置光照系统 (环境光 + 主金色辅光 + 侧顶光)
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

        // 2. 摄像机设置
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 150.0
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        // 3. 构建全屋模型节点
        scene.rootNode.addChildNode(rootHouseNode)
        scene.rootNode.addChildNode(shaAlertsNode)
        scene.rootNode.addChildNode(dimensionsNode)

        buildHouseGeometry(survey: survey)
        resetCamera(mode: viewMode)
    }

    public func update(
        survey: HouseSpatialSurvey,
        viewMode: House3DSpaceViewer.ViewAngleMode,
        showDimensions: Bool,
        showShaAlerts: Bool,
        selectedShaItem: HouseSpatialShaItem?
    ) {
        dimensionsNode.isHidden = !showDimensions
        shaAlertsNode.isHidden = !showShaAlerts

        if let item = selectedShaItem, let coord = item.coordinate {
            // 摄像机微移平滑聚焦在形煞位置
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
        dimensionsNode.childNodes.forEach { $0.removeFromParentNode() }

        let cx = survey.centroidX
        let cz = survey.centroidZ
        let w = survey.dimensions.totalWidth
        let d = survey.dimensions.totalDepth

        // 1. 地面基盘与八卦罗盘网格
        let floorGeo = SCNPlane(width: CGFloat(w * 1.35), height: CGFloat(d * 1.35))
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 0.95)
        floorGeo.materials = [floorMat]
        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.eulerAngles.x = -Float.pi / 2
        floorNode.position = SCNVector3(cx, 0, cz)
        rootHouseNode.addChildNode(floorNode)

        // 地面网格线
        addGridLines(centerX: cx, centerZ: cz, width: w * 1.3, depth: d * 1.3)

        // 2. 3D 立极中宫点 (金色贯通天地的太极光柱)
        let pillarGeo = SCNCylinder(radius: 0.18, height: CGFloat(survey.dimensions.ceilingHeight * 1.5))
        let pillarMat = SCNMaterial()
        pillarMat.diffuse.contents = UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 0.75)
        pillarMat.emission.contents = UIColor(red: 0.90, green: 0.70, blue: 0.20, alpha: 0.5)
        pillarGeo.materials = [pillarMat]
        let pillarNode = SCNNode(geometry: pillarGeo)
        pillarNode.position = SCNVector3(cx, survey.dimensions.ceilingHeight * 0.75, cz)
        rootHouseNode.addChildNode(pillarNode)

        // 立极中宫地面太极圆盘
        let centerRingGeo = SCNTorus(ringRadius: 0.6, pipeRadius: 0.04)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 0.9)
        centerRingGeo.materials = [ringMat]
        let ringNode = SCNNode(geometry: centerRingGeo)
        ringNode.position = SCNVector3(cx, 0.02, cz)
        rootHouseNode.addChildNode(ringNode)

        // 3. 墙体几何生成 (半透明建筑玻璃体科技质感)
        for wall in survey.walls {
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
            rootHouseNode.addChildNode(wallNode)
        }

        // 4. 门窗开孔三维立体显影
        for op in survey.openings {
            let opH = CGFloat(op.height)
            let opW = CGFloat(op.width)
            let box = SCNBox(width: opW, height: opH, length: 0.08, chamferRadius: 0.01)
            let mat = SCNMaterial()
            switch op.type {
            case .entranceDoor:
                mat.diffuse.contents = UIColor(red: 0.95, green: 0.80, blue: 0.20, alpha: 0.90) // 金黄大门
                mat.emission.contents = UIColor(red: 0.5, green: 0.4, blue: 0.1, alpha: 0.4)
            case .interiorDoor:
                mat.diffuse.contents = UIColor(red: 0.85, green: 0.65, blue: 0.45, alpha: 0.80) // 木色房门
            case .window, .balconyDoor:
                mat.diffuse.contents = UIColor(red: 0.10, green: 0.85, blue: 0.95, alpha: 0.60) // 亮青色玻璃窗
            case .opening:
                mat.diffuse.contents = UIColor(red: 0.30, green: 0.90, blue: 0.50, alpha: 0.50) // 绿色通透开口
            }
            box.materials = [mat]

            let opNode = SCNNode(geometry: box)
            opNode.position = SCNVector3(op.posX, Float(opH) * 0.5, op.posZ)
            let normAngle = atan2(op.normalZ, op.normalX)
            opNode.eulerAngles.y = -normAngle + Float.pi / 2
            rootHouseNode.addChildNode(opNode)
        }

        // 5. 结构横梁展示 (悬空红棕色/沉降压顶)
        for beam in survey.beams {
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
            rootHouseNode.addChildNode(bNode)
        }

        // 6. 房间功能分区地坪高亮与标签
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
            rootHouseNode.addChildNode(rNode)
        }

        // 7. 形煞警示标注与流线
        buildShaAlertVisuals(survey: survey)
    }

    private func buildShaAlertVisuals(survey: HouseSpatialSurvey) {
        for sha in survey.shaItems {
            guard let pos = sha.coordinate else { continue }

            // 警示浮球
            let sphereGeo = SCNSphere(radius: 0.22)
            let sphereMat = SCNMaterial()
            let alertColor = sha.severity == .critical ? UIColor.systemRed : (sha.severity == .warning ? UIColor.systemOrange : UIColor.systemGreen)
            sphereMat.diffuse.contents = alertColor
            sphereMat.emission.contents = alertColor.withAlphaComponent(0.6)
            sphereGeo.materials = [sphereMat]
            let sNode = SCNNode(geometry: sphereGeo)
            sNode.position = SCNVector3(pos.x, max(0.5, pos.y), pos.z)
            shaAlertsNode.addChildNode(sNode)

            // 穿堂煞对冲光线 (从大门直通主窗/阳台)
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
                    beamNode.eulerAngles = SCNVector3(pitch + Float.pi / 2, yaw, 0)
                    shaAlertsNode.addChildNode(beamNode)
                }
            }
        }
    }

    private func addGridLines(centerX: Float, centerZ: Float, width: Float, depth: Float) {
        let step: Float = 1.0 // 1米格网
        let halfW = width * 0.5
        let halfD = depth * 0.5

        let gridNode = SCNNode()
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = UIColor(white: 0.35, alpha: 0.3)

        // X 方向网格线
        var z = -halfD
        while z <= halfD {
            let line = SCNBox(width: CGFloat(width), height: 0.005, length: 0.02, chamferRadius: 0)
            line.materials = [lineMat]
            let node = SCNNode(geometry: line)
            node.position = SCNVector3(centerX, 0.005, centerZ + z)
            gridNode.addChildNode(node)
            z += step
        }

        // Z 方向网格线
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
