import SwiftUI
import SceneKit
import simd
import UIKit

// MARK: - 全屋 3D 空间测绘立体布局与形煞全息查看器

public struct House3DSpaceViewer: View {
    @State public var survey: HouseSpatialSurvey
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var mode: ViewAngleMode = .perspective
    @State private var dimensions = true
    @State private var coordinator: HouseSceneCoordinator?
    @State private var detail: String?
    @State private var share: ResidentialShareItem?
    @State private var paywall = false
    @State private var error: String?
    private let propertyID: UUID
    public enum ViewAngleMode: String, CaseIterable {
        case perspective, topDown, frontEntrance
        var title: String {
            LocalizationManager.shared.t(self == .perspective ? "3d_view_perspective" : self == .topDown ? "3d_view_topdown" : "3d_view_entrance")
        }
    }
    public init(survey: HouseSpatialSurvey, propertyID: UUID = ShaSurveyStore.shared.propertyID) {
        _survey = State(initialValue: survey)
        self.propertyID = propertyID
    }
    public var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Text(survey.scanMethod).font(.caption).foregroundColor(.secondary)
                Text(String(format: "%.2f m × %.2f m", survey.dimensions.totalWidth, survey.dimensions.totalDepth))
                    .font(.headline).monospacedDigit()
                House3DSceneRepresentable(survey: survey, viewMode: mode, showDimensions: dimensions,
                    onElementTapped: { detail = $0 }, coordinatorRef: { coordinator = $0 })
                    .frame(minHeight: 240)
                if let detail { Text(detail).font(.caption).padding(.horizontal) }
                Picker(lang.t("res_model"), selection: $mode) {
                    ForEach(ViewAngleMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal)
                Toggle(lang.t("res_show_dimensions"), isOn: $dimensions).padding(.horizontal)
                Menu(lang.t("res_export")) {
                    Button("DXF") { exportDXF() }
                    Button("JSON") { exportJSON() }
                    Button(lang.t("res_image_report")) {
                        if let image = coordinator?.captureSnapshot() {
                            share = ResidentialShareItem(items: [SurveyReportRenderer.renderReportImage(survey: survey, snapshot: image)])
                        }
                    }
                }.padding(.bottom)
            }
            .navigationTitle(lang.t("res_model"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(lang.t("done")) { dismiss() } } }
            .onChange(of: mode) { coordinator?.resetCamera(mode: $0) }
            .onReceive(ShaSurveyStore.shared.$propertyID) { if $0 != propertyID { dismiss() } }
            .sheet(item: $share) { ResidentialShareSheet(items: $0.items) }
            .sheet(isPresented: $paywall) { VIPPaywallSheet(defaultProductId: .vipYearly) }
            .alert(lang.t("res_export"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button(lang.t("done"), role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }.navigationViewStyle(.stack)
    }
    private func exportDXF() {
        guard iap.hasUnlockedVIP else { paywall = true; return }
        guard let url = survey.exportDXFFileURL() else { error = lang.t("res_export_failed"); return }
        share = ResidentialShareItem(items: [url])
    }
    private func exportJSON() {
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("survey-\(UUID().uuidString).json")
            // Rebuild from geometry so old saved luck scores/remedies cannot be shared.
            let clean = HouseSpatialSurveyEngine.analyzeSpatialHouse(scanMethod: survey.scanMethod,
                walls: survey.walls, openings: survey.openings, beams: survey.beams, rooms: survey.rooms,
                objects: survey.objects, compassHeading: survey.compassHeading, analysisDate: survey.timestamp)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(ResidentialSurveyGeometry(clean)).write(to: url, options: .atomic)
            share = ResidentialShareItem(items: [url])
        } catch { self.error = error.localizedDescription }
    }
}

// MARK: - SceneKit 3D 场景封装与渲染器

public struct House3DSceneRepresentable: UIViewRepresentable {
    public let survey: HouseSpatialSurvey
    public let viewMode: House3DSpaceViewer.ViewAngleMode
    public let showDimensions: Bool
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
            showDimensions: showDimensions
        )

        coordinatorRef(context.coordinator)
        return scnView
    }

    public func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.update(
            survey: survey,
            viewMode: viewMode,
            showDimensions: showDimensions
        )
    }
}

// MARK: - Scene Coordinator 构建 3D 模型

public final class HouseSceneCoordinator: NSObject {
    private weak var scene: SCNScene?
    private weak var scnView: SCNView?
    private var cameraNode = SCNNode()
    private var rootHouseNode = SCNNode()
    private var dimensionsNode = SCNNode()
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
        showDimensions: Bool
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
        scene.rootNode.addChildNode(dimensionsNode)

        buildHouseGeometry(survey: survey)
        buildDimensionsLines(survey: survey)
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
        showDimensions: Bool
    ) {
        // Room type edits and fresh RoomPlan/AR scans replace the immutable
        // survey value. Rebuild the geometry when that snapshot changes;
        // previously only overlays were refreshed, leaving a stale 3D model
        // on screen after the underlying floorplan changed.
        if currentSurvey?.id != survey.id {
            currentSurvey = survey
            buildHouseGeometry(survey: survey)
            buildDimensionsLines(survey: survey)
            resetCamera(mode: viewMode)
        }
        dimensionsNode.isHidden = !showDimensions



    }

    public func resetCamera(mode: House3DSpaceViewer.ViewAngleMode) {
        guard let survey = currentSurvey else { return }
        // Keep the shell/floor centered on the measured envelope. The Tai Ji
        // point may intentionally be moved to a main room, so using
        // survey.centroid for the floor would shift the walls away from their
        // measured coordinates.
        let axisAngle = primaryAxisAngle(survey: survey)
        let footprintCenter = measuredFootprintCenter(survey: survey, axisAngle: axisAngle)
        let cx = footprintCenter.x
        let cz = footprintCenter.y
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

        let w = survey.dimensions.totalWidth
        let d = survey.dimensions.totalDepth
        // Keep auxiliary geometry in the same local OBB frame as the measured
        // walls.  Without this, a diagonal house got a world-aligned floor and
        // reference grid even though its wall nodes followed their measured
        // heading.
        let axisAngle = primaryAxisAngle(survey: survey)
        let footprintCenter = measuredFootprintCenter(survey: survey, axisAngle: axisAngle)

        let floorGeo = SCNPlane(width: CGFloat(w * 1.35), height: CGFloat(d * 1.35))
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 0.95)
        floorGeo.materials = [floorMat]
        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.eulerAngles.x = -Float.pi / 2
        floorNode.eulerAngles.y = -axisAngle
        floorNode.position = SCNVector3(footprintCenter.x, 0, footprintCenter.y)
        rootHouseNode.addChildNode(floorNode)

        addGridLines(centerX: footprintCenter.x, centerZ: footprintCenter.y, width: w * 1.3, depth: d * 1.3, axisAngle: axisAngle)

        let lang = LocalizationManager.shared.effectiveLanguage

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
            let lenStr = String(format: "%.2f", len)
            let hStr = String(format: "%.2f", wall.height)
            switch lang {
            case .zhHans, .auto: wallNode.name = "墙段 #\(idx + 1)：长 \(lenStr)m · 高 \(hStr)m"
            case .zhHant: wallNode.name = "牆段 #\(idx + 1)：長 \(lenStr)m · 高 \(hStr)m"
            case .en:     wallNode.name = "Wall #\(idx + 1): L \(lenStr)m · H \(hStr)m"
            case .ja:     wallNode.name = "壁 #\(idx + 1)：長さ \(lenStr)m・高さ \(hStr)m"
            case .ko:     wallNode.name = "벽체 #\(idx + 1): 길이 \(lenStr)m · 높이 \(hStr)m"
            case .vi:     wallNode.name = "Tường #\(idx + 1): Dài \(lenStr)m · Cao \(hStr)m"
            case .th:     wallNode.name = "ผนัง #\(idx + 1): ยาว \(lenStr)m · สูง \(hStr)m"
            case .id:     wallNode.name = "Dinding #\(idx + 1): P \(lenStr)m · T \(hStr)m"
            }
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
            // RoomPlan stores the opening transform at its measured centre;
            // retaining posY keeps windows and doors at their real sill/centre
            // height instead of forcing every opening to start at half-height.
            opNode.position = SCNVector3(op.posX, op.posY, op.posZ)
            let normAngle = atan2(op.normalZ, op.normalX)
            opNode.eulerAngles.y = -normAngle + Float.pi / 2
            let wStr = String(format: "%.2f", op.width)
            let hStr = String(format: "%.2f", op.height)
            opNode.name = "\(op.type.localizedName): \(wStr) m × \(hStr) m"
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
            let clrStr = String(format: "%.2f", beam.clearanceHeight)
            let lenStr = String(format: "%.2f", len)
            switch lang {
            case .zhHans, .auto: bNode.name = "结构横梁 #\(idx + 1)：净高 \(clrStr)m · 跨度 \(lenStr)m"
            case .zhHant: bNode.name = "結構橫梁 #\(idx + 1)：淨高 \(clrStr)m · 跨度 \(lenStr)m"
            case .en:     bNode.name = "Beam #\(idx + 1): Clearance \(clrStr)m · Span \(lenStr)m"
            case .ja:     bNode.name = "構造梁 #\(idx + 1)：有効高 \(clrStr)m・スパン \(lenStr)m"
            case .ko:     bNode.name = "구조 보 #\(idx + 1): 유효높이 \(clrStr)m · 경간 \(lenStr)m"
            case .vi:     bNode.name = "Xà ngang #\(idx + 1): Cao thông thủy \(clrStr)m · Nhịp \(lenStr)m"
            case .th:     bNode.name = "คานโครงสร้าง #\(idx + 1): สูงสุทธิ \(clrStr)m · ช่วงยาว \(lenStr)m"
            case .id:     bNode.name = "Balok #\(idx + 1): Tinggi bersih \(clrStr)m · Bentang \(lenStr)m"
            }
            rootHouseNode.addChildNode(bNode)
        }

        // 房间地坪高亮
        for room in survey.rooms {
            // SpatialRoom3D dimensions are measured extents in metres. Keep
            // them exact; shrinking every room to 90% made the rendered plan
            // visibly disagree with the scanned walls and area readouts.
            let rW = CGFloat(max(0.05, room.sizeX))
            let rD = CGFloat(max(0.05, room.sizeZ))
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
            // Room rectangles may carry their own measured yaw. Older
            // surveys omit it and retain the historical whole-house axis.
            rNode.eulerAngles.y = -(room.rotationY ?? axisAngle)
            rNode.position = SCNVector3(room.centerX, 0.01, room.centerZ)
            let rName = room.localizedName
            let areaStr = String(format: "%.1f", room.areaSqMeters)
            let wStr = String(format: "%.2f", room.sizeX)
            let dStr = String(format: "%.2f", room.sizeZ)
            switch lang {
            case .zhHans, .auto: rNode.name = "\(rName)：面积估算 \(areaStr)㎡ · 面宽 \(wStr)m × 进深 \(dStr)m"
            case .zhHant: rNode.name = "\(rName)：面積估算 \(areaStr)㎡ · 面寬 \(wStr)m × 進深 \(dStr)m"
            case .en:     rNode.name = "\(rName): Area \(areaStr)㎡ · W \(wStr)m × D \(dStr)m"
            case .ja:     rNode.name = "\(rName)：推定面積 \(areaStr)㎡・間口 \(wStr)m × 奥行 \(dStr)m"
            case .ko:     rNode.name = "\(rName): 추정 면적 \(areaStr)㎡ · 폭 \(wStr)m × 깊이 \(dStr)m"
            case .vi:     rNode.name = "\(rName): Diện tích \(areaStr)㎡ · Rộng \(wStr)m × Sâu \(dStr)m"
            case .th:     rNode.name = "\(rName): พื้นที่ \(areaStr) ตร.ม. · กว้าง \(wStr)m × ลึก \(dStr)m"
            case .id:     rNode.name = "\(rName): Luas \(areaStr)㎡ · L \(wStr)m × P \(dStr)m"
            }
            rootHouseNode.addChildNode(rNode)
        }

        // RoomPlan furniture/appliance objects are part of the measured
        // survey. Render their real extents and captured yaw so the viewer
        // reflects the observed interior instead of showing an empty shell.
        for (idx, object) in survey.objects.enumerated() {
            let width = CGFloat(max(0.05, object.sizeX))
            let height = CGFloat(max(0.05, object.sizeY))
            let depth = CGFloat(max(0.05, object.sizeZ))
            let objectGeo = SCNBox(width: width, height: height, length: depth, chamferRadius: 0.02)
            let objectMat = SCNMaterial()
            objectMat.diffuse.contents = objectMaterialColor(for: object.category)
            // Keep furniture readable in the measured scene. Walls and room
            // overlays remain translucent, while an 82%-transparent furniture
            // box looked like a missing object in the 3D result.
            objectMat.transparency = 0.18
            objectGeo.materials = [objectMat]

            let objectNode = SCNNode(geometry: objectGeo)
            // RoomPlan object transforms use the object centre as translation.
            objectNode.position = SCNVector3(object.posX, object.posY, object.posZ)
            if let yaw = object.rotationY, yaw.isFinite {
                objectNode.eulerAngles.y = -yaw
            }
            let dimStr = "\(String(format: "%.2f", object.sizeX))m × \(String(format: "%.2f", object.sizeY))m × \(String(format: "%.2f", object.sizeZ))m"
            let catName = object.localizedCategoryName
            switch lang {
            case .zhHans, .auto: objectNode.name = "物件 #\(idx + 1)【\(catName)】：\(dimStr)"
            case .zhHant: objectNode.name = "物件 #\(idx + 1)【\(catName)】：\(dimStr)"
            case .en:     objectNode.name = "Object #\(idx + 1) [\(catName)]: \(dimStr)"
            case .ja:     objectNode.name = "家具・設備 #\(idx + 1)【\(catName)】：\(dimStr)"
            case .ko:     objectNode.name = "가구·설비 #\(idx + 1) [\(catName)]: \(dimStr)"
            case .vi:     objectNode.name = "Vật dụng #\(idx + 1) [\(catName)]: \(dimStr)"
            case .th:     objectNode.name = "วัตถุ #\(idx + 1) [\(catName)]: \(dimStr)"
            case .id:     objectNode.name = "Objek #\(idx + 1) [\(catName)]: \(dimStr)"
            }
            rootHouseNode.addChildNode(objectNode)
        }

    }

    private func objectMaterialColor(for category: String) -> UIColor {
        let value = category.lowercased()
        if value.contains("bed") || value.contains("床") {
            return UIColor(red: 0.45, green: 0.65, blue: 0.95, alpha: 1)
        }
        if value.contains("sofa") || value.contains("chair") || value.contains("沙发") || value.contains("椅") {
            return UIColor(red: 0.95, green: 0.65, blue: 0.35, alpha: 1)
        }
        if value.contains("table") || value.contains("desk") || value.contains("桌") {
            return UIColor(red: 0.75, green: 0.48, blue: 0.25, alpha: 1)
        }
        if value.contains("toilet") || value.contains("bathtub") || value.contains("马桶") || value.contains("浴") {
            return UIColor(red: 0.30, green: 0.85, blue: 0.85, alpha: 1)
        }
        if value.contains("stove") || value.contains("oven") || value.contains("冰箱") || value.contains("炉") {
            return UIColor(red: 0.90, green: 0.35, blue: 0.25, alpha: 1)
        }
        return UIColor(red: 0.65, green: 0.70, blue: 0.78, alpha: 1)
    }

    // MARK: - 3D 尺寸标尺立体线条
    private func buildDimensionsLines(survey: HouseSpatialSurvey) {
        dimensionsNode.childNodes.forEach { $0.removeFromParentNode() }
        let w = survey.dimensions.totalWidth
        let d = survey.dimensions.totalDepth
        let h = survey.dimensions.ceilingHeight
        let axisAngle = primaryAxisAngle(survey: survey)
        let footprintCenter = measuredFootprintCenter(survey: survey, axisAngle: axisAngle)
        let cosAxis = cos(axisAngle)
        let sinAxis = sin(axisAngle)

        func worldPoint(localX: Float, localZ: Float, y: Float) -> SCNVector3 {
            SCNVector3(
                footprintCenter.x + localX * cosAxis - localZ * sinAxis,
                y,
                footprintCenter.y + localX * sinAxis + localZ * cosAxis
            )
        }

        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 0.85)

        let lang = LocalizationManager.shared.effectiveLanguage
        let wStr = String(format: "%.2f", w)
        let dStr = String(format: "%.2f", d)
        let hStr = String(format: "%.2f", h)
        let widthLineGeo = SCNBox(width: CGFloat(w), height: 0.015, length: 0.015, chamferRadius: 0)
        widthLineGeo.materials = [lineMat]
        let widthLineNode = SCNNode(geometry: widthLineGeo)
        widthLineNode.eulerAngles.y = -axisAngle
        widthLineNode.position = worldPoint(localX: 0, localZ: d * 0.5 + 0.45, y: 0.05)
        switch lang {
        case .zhHans, .auto: widthLineNode.name = "面宽开间尺寸：\(wStr) 米"
        case .zhHant: widthLineNode.name = "面寬開間尺寸：\(wStr) 米"
        case .en:     widthLineNode.name = "Total Width: \(wStr) m"
        case .ja:     widthLineNode.name = "間口幅寸法：\(wStr) m"
        case .ko:     widthLineNode.name = "전면 폭 치수: \(wStr) m"
        case .vi:     widthLineNode.name = "Chiều rộng: \(wStr) m"
        case .th:     widthLineNode.name = "ความกว้างรวม: \(wStr) ม."
        case .id:     widthLineNode.name = "Lebar Total: \(wStr) m"
        }
        dimensionsNode.addChildNode(widthLineNode)

        let depthLineGeo = SCNBox(width: 0.015, height: 0.015, length: CGFloat(d), chamferRadius: 0)
        depthLineGeo.materials = [lineMat]
        let depthLineNode = SCNNode(geometry: depthLineGeo)
        depthLineNode.eulerAngles.y = -axisAngle
        depthLineNode.position = worldPoint(localX: w * 0.5 + 0.45, localZ: 0, y: 0.05)
        switch lang {
        case .zhHans, .auto: depthLineNode.name = "进深长度尺寸：\(dStr) 米"
        case .zhHant: depthLineNode.name = "進深長度尺寸：\(dStr) 米"
        case .en:     depthLineNode.name = "Total Depth: \(dStr) m"
        case .ja:     depthLineNode.name = "奥行寸法：\(dStr) m"
        case .ko:     depthLineNode.name = "깊이 치수: \(dStr) m"
        case .vi:     depthLineNode.name = "Chiều sâu: \(dStr) m"
        case .th:     depthLineNode.name = "ความลึกรวม: \(dStr) ม."
        case .id:     depthLineNode.name = "Kedalaman Total: \(dStr) m"
        }
        dimensionsNode.addChildNode(depthLineNode)

        let heightLineGeo = SCNBox(width: 0.015, height: CGFloat(h), length: 0.015, chamferRadius: 0)
        heightLineGeo.materials = [lineMat]
        let heightLineNode = SCNNode(geometry: heightLineGeo)
        heightLineNode.position = worldPoint(localX: -w * 0.5 - 0.45, localZ: -d * 0.5 - 0.45, y: h * 0.5)
        switch lang {
        case .zhHans, .auto: heightLineNode.name = "室内净层高尺寸：\(hStr) 米"
        case .zhHant: heightLineNode.name = "室內淨層高尺寸：\(hStr) 米"
        case .en:     heightLineNode.name = "Clear Ceiling Height: \(hStr) m"
        case .ja:     heightLineNode.name = "室内有効天井高：\(hStr) m"
        case .ko:     heightLineNode.name = "실내 유효 층고: \(hStr) m"
        case .vi:     heightLineNode.name = "Chiều cao trần: \(hStr) m"
        case .th:     heightLineNode.name = "ความสูงเพดานสุทธิ: \(hStr) ม."
        case .id:     heightLineNode.name = "Tinggi Plafon Bersih: \(hStr) m"
        }
        dimensionsNode.addChildNode(heightLineNode)
    }

    // MARK: - 八宅大游年 / 玄空飞星 理气贴地投影


    private func primaryAxisAngle(survey: HouseSpatialSurvey) -> Float {
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

    /// Returns the measured footprint centre used by the floor, grid and
    /// dimension annotations. A survey centroid can intentionally be moved to
    /// a main room when a concave plan leaves the geometric centre outside the
    /// usable area, so those reference aids must stay anchored to the wall
    /// envelope while the Tai Ji pillar remains at `survey.centroid`.
    private func measuredFootprintCenter(survey: HouseSpatialSurvey, axisAngle: Float) -> SIMD2<Float> {
        let cosAxis = cos(axisAngle)
        let sinAxis = sin(axisAngle)
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude

        for wall in survey.walls {
            for point in [SIMD2<Float>(wall.startX, wall.startZ), SIMD2<Float>(wall.endX, wall.endZ)] {
                let localX = point.x * cosAxis + point.y * sinAxis
                let localZ = -point.x * sinAxis + point.y * cosAxis
                minX = min(minX, localX)
                maxX = max(maxX, localX)
                minZ = min(minZ, localZ)
                maxZ = max(maxZ, localZ)
            }
        }
        if !(minX < maxX && minZ < maxZ) {
            // Basic AR scans can contain horizontal planes without vertical
            // wall anchors. Their room boxes still give us a useful footprint
            // centre for the floor and dimension guides.
            for room in survey.rooms {
                let halfX = room.sizeX * 0.5
                let halfZ = room.sizeZ * 0.5
                for point in [
                    SIMD2<Float>(room.centerX - halfX, room.centerZ - halfZ),
                    SIMD2<Float>(room.centerX + halfX, room.centerZ - halfZ),
                    SIMD2<Float>(room.centerX + halfX, room.centerZ + halfZ),
                    SIMD2<Float>(room.centerX - halfX, room.centerZ + halfZ)
                ] {
                    let localX = point.x * cosAxis + point.y * sinAxis
                    let localZ = -point.x * sinAxis + point.y * cosAxis
                    minX = min(minX, localX)
                    maxX = max(maxX, localX)
                    minZ = min(minZ, localZ)
                    maxZ = max(maxZ, localZ)
                }
            }
        }
        guard minX < maxX && minZ < maxZ else {
            return SIMD2<Float>(survey.centroidX, survey.centroidZ)
        }
        let localCenterX = (minX + maxX) * 0.5
        let localCenterZ = (minZ + maxZ) * 0.5
        return SIMD2<Float>(
            localCenterX * cosAxis - localCenterZ * sinAxis,
            localCenterX * sinAxis + localCenterZ * cosAxis
        )
    }



    private func addGridLines(centerX: Float, centerZ: Float, width: Float, depth: Float, axisAngle: Float = 0) {
        let step: Float = 1.0
        let halfW = width * 0.5
        let halfD = depth * 0.5

        let gridNode = SCNNode()
        // Child line positions are local to the measured OBB center, then the
        // parent rotates the complete reference grid to the wall heading.
        gridNode.position = SCNVector3(centerX, 0, centerZ)
        gridNode.eulerAngles.y = -axisAngle
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = UIColor(white: 0.35, alpha: 0.3)

        var z = -halfD
        while z <= halfD {
            let line = SCNBox(width: CGFloat(width), height: 0.005, length: 0.02, chamferRadius: 0)
            line.materials = [lineMat]
            let node = SCNNode(geometry: line)
            node.position = SCNVector3(0, 0.005, z)
            gridNode.addChildNode(node)
            z += step
        }

        var x = -halfW
        while x <= halfW {
            let line = SCNBox(width: 0.02, height: 0.005, length: CGFloat(depth), chamferRadius: 0)
            line.materials = [lineMat]
            let node = SCNNode(geometry: line)
            node.position = SCNVector3(x, 0.005, 0)
            gridNode.addChildNode(node)
            x += step
        }

        rootHouseNode.addChildNode(gridNode)
    }
}

// MARK: - 全息长图测绘报告渲染器

public enum SurveyReportRenderer {
    public static func renderReportImage(survey: HouseSpatialSurvey, snapshot: UIImage) -> UIImage {
        let lang = LocalizationManager.shared
        let rows = [lang.t("res_image_report"), survey.scanMethod,
            DateFormatter.localizedString(from: survey.timestamp, dateStyle: .medium, timeStyle: .short),
            String(format: "%.2f m × %.2f m", survey.dimensions.totalWidth, survey.dimensions.totalDepth)]
            + survey.rooms.map { "\($0.name): " + String(format: "%.2f m × %.2f m", $0.sizeX, $0.sizeZ) }
            + [lang.t("res_measurement_note")]
        let font = UIFont.systemFont(ofSize: 26)
        let heights = rows.map { ($0 as NSString).boundingRect(with: CGSize(width: 960, height: 10000),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height + 20 }
        let size = CGSize(width: 1080, height: 840 + heights.reduce(0, +))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill(); UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            snapshot.draw(in: CGRect(x: 60, y: 40, width: 960, height: 720))
            var y: CGFloat = 800
            for (index, row) in rows.enumerated() {
                (row as NSString).draw(in: CGRect(x: 60, y: y, width: 960, height: heights[index]),
                    withAttributes: [.font: font, .foregroundColor: UIColor.black])
                y += heights[index]
            }
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
