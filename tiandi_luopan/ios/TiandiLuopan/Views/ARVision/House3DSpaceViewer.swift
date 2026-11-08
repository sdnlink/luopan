import SwiftUI
import SceneKit
import simd
import UIKit

// MARK: - 全屋 3D 空间测绘立体布局与形煞全息查看器

public struct House3DSpaceViewer: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @State public var survey: HouseSpatialSurvey
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var viewMode: ViewAngleMode = .perspective
    @State private var palaceGridMode: PalaceGridMode = .baZhai
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @State private var showPaywall: Bool = false
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

        public var localizedTitle: String {
            let lang = LocalizationManager.shared
            switch self {
            case .perspective: return lang.t("3d_view_perspective")
            case .topDown: return lang.t("3d_view_topdown")
            case .frontEntrance: return lang.t("3d_view_entrance")
            }
        }
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
                            .adaptiveFont(size: 12, weight: .bold)
                            .foregroundColor(.orange)
                        Text(lang.t("3d_centroid_warning"))
                            .adaptiveFont(size: 10, weight: .semibold)
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
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
        .onAppear {
            refreshSurveyForActiveLanguage()
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            refreshSurveyForActiveLanguage()
        }
    }

    private func refreshSurveyForActiveLanguage() {
        let localizedRooms = survey.rooms.map { r in
            SpatialRoom3D(
                id: r.id,
                name: r.type.localizedName,
                type: r.type,
                center: r.center,
                size: r.size,
                areaSqMeters: r.areaSqMeters,
                rotationY: r.rotationY
            )
        }
        let rebuilt = HouseSpatialSurveyEngine.analyzeSpatialHouse(
            scanMethod: survey.scanMethod,
            walls: survey.walls,
            openings: survey.openings,
            beams: survey.beams,
            rooms: localizedRooms,
            objects: survey.objects,
            compassHeading: survey.compassHeading,
            centroidOverride: survey.centroidWasExplicit == true ? survey.centroid : nil,
            houseFacingDegrees: survey.houseFacingDegrees,
            analysisDate: survey.timestamp
        )
        survey = rebuilt
        selectedShaItem = nil
        inspectedElementDesc = nil
    }

    // MARK: - 顶部测绘总览看板
    private var topMetricsHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "cube.transparent")
                        .adaptiveFont(size: 15, weight: .bold)
                        .foregroundColor(.yanGold)
                    Text(lang.t("ar_3d_model_title"))
                        .adaptiveFont(size: 15, weight: .bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: horizontalSizeClass == .regular ? 260 : 160, alignment: .leading)
                .layoutPriority(1)

                // 徽章 + CAD + 房间 + 分享在中文标题下需求约 280pt，加上标题会超出 iPhone 375pt，
                // 操作区放进横向滚动兜底；关闭键留在外面常驻可点。
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 传统文化参考评分徽章
                        HStack(spacing: 4) {
                            Text(lang.t("3d_score_label"))
                                .adaptiveFont(size: 11, weight: .medium)
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(survey.fengshuiScore)")
                                .adaptiveFont(size: 14, weight: .bold, design: .monospaced)
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
                                    .adaptiveFont(size: 11, weight: .bold)
                                Text("CAD")
                                    .adaptiveFont(size: 10, weight: .bold, design: .monospaced)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(Color.yanCyan)
                            .cornerRadius(12)
                        }
                        .accessibilityLabel("CAD")

                        // 毛坯房房间类型设定（一键切换类型即时刷新形煞报告）
                        Button(action: { showRoomTypePanel.toggle() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "door.sliding.left.hand.closed")
                                    .adaptiveFont(size: 11, weight: .bold)
                                Text(lang.t("3d_btn_rooms"))
                                    .adaptiveFont(size: 10, weight: .bold)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(showRoomTypePanel ? Color.orange : Color.white.opacity(0.85))
                            .cornerRadius(12)
                        }
                        .accessibilityLabel(lang.t("3d_room_type_panel_title"))

                        // 导出与分享长图存证
                        Button(action: exportAndShareReport) {
                            Image(systemName: "square.and.arrow.up")
                                .adaptiveFont(size: 12, weight: .bold)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.blue.opacity(0.75))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(lang.t("ar_roomplan_share"))
                    }
                    .padding(.vertical, 2)
                }

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }

            // 测绘核心参数横幅
            HStack(spacing: 12) {
                metricCell(
                    title: lang.t("3d_metric_depth_width"),
                    value: String(format: "%.2f × %.2f m", survey.dimensions.totalDepth, survey.dimensions.totalWidth)
                )
                Divider().frame(height: 18).background(Color.white.opacity(0.2))
                metricCell(
                    title: lang.t("3d_metric_ceiling"),
                    value: String(format: "%.2f m", survey.dimensions.ceilingHeight)
                )
                Divider().frame(height: 18).background(Color.white.opacity(0.2))
                metricCell(
                    title: lang.t("3d_metric_area"),
                    value: String(format: "%.1f m²", survey.dimensions.usableFloorArea)
                )
                Divider().frame(height: 18).background(Color.white.opacity(0.2))
                metricCell(
                    title: lang.t("3d_metric_openings"),
                    value: "\(survey.openings.count)"
                )
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.black.opacity(0.55))
            .cornerRadius(8)

            HStack(spacing: 5) {
                Image(systemName: survey.scanMethod.contains("VR") ? "wand.and.stars" : "location.magnifyingglass")
                Text("\(lang.t("3d_data_source_prefix"))\(survey.scanMethod)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .adaptiveFont(size: 9, weight: .semibold)
            .foregroundColor(survey.scanMethod.contains("VR") ? .orange : .yanCyan)
            .padding(.horizontal, 10)
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
                .adaptiveFont(size: 13, weight: .bold)
                .foregroundColor(.yanGold)
            Text(desc)
                .adaptiveFont(size: 11, weight: .medium)
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
            Button(action: {
                withAnimation { self.inspectedElementDesc = nil }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .adaptiveFont(size: 13)
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
                .adaptiveFont(size: 9, weight: .medium)
                .foregroundColor(.white.opacity(0.65))
            Text(value)
                .adaptiveFont(size: 11, weight: .bold, design: .monospaced)
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
                Text(lang.t("3d_room_type_panel_title"))
                    .adaptiveFont(size: 12, weight: .bold)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showRoomTypePanel = false }) {
                    Text(lang.t("done"))
                        .adaptiveFont(size: 11, weight: .bold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.yanGold)
                        .cornerRadius(10)
                }
            }
            if survey.rooms.isEmpty {
                Text(lang.t("3d_room_type_empty"))
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 5) {
                        ForEach(survey.rooms) { room in
                            HStack {
                                Text(room.localizedName)
                                    .adaptiveFont(size: 11, weight: .medium)
                                    .foregroundColor(.white)
                                    .frame(minWidth: 66 * AdaptiveFontMetrics.dynamicTypeScale(for: dynamicTypeSize),
                                           alignment: .leading)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .layoutPriority(1)
                                Text(String(format: "%.1f㎡", room.areaSqMeters))
                                    .adaptiveFont(size: 10, design: .monospaced)
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(minWidth: 52 * AdaptiveFontMetrics.dynamicTypeScale(for: dynamicTypeSize),
                                           alignment: .trailing)
                                    .fixedSize(horizontal: true, vertical: false)
                                Picker(room.localizedName, selection: roomTypeBinding(room)) {
                                    ForEach(FloorplanRoomType.allCases) { t in
                                        Text(t.localizedName).tag(t)
                                    }
                                }
                                .pickerStyle(.menu)
                                .adaptiveFont(size: 11)
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
            Text(lang.t("3d_room_type_hint"))
                .adaptiveFont(size: 9)
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
                areaSqMeters: room.areaSqMeters,
                rotationY: room.rotationY
            )
        }
        let rebuilt = HouseSpatialSurveyEngine.analyzeSpatialHouse(
            scanMethod: survey.scanMethod,
            walls: survey.walls,
            openings: survey.openings,
            beams: survey.beams,
            rooms: updatedRooms,
            objects: survey.objects,
            compassHeading: survey.compassHeading,
            centroidOverride: survey.centroidWasExplicit == true ? survey.centroid : nil,
            houseFacingDegrees: survey.houseFacingDegrees,
            analysisDate: survey.timestamp
        )
        survey = rebuilt
        // Keep corrections made in the viewer when the source is an actual
        // AR/RoomPlan/VR survey. A hand-built 户型立极 projection has no
        // measured archive authority and must remain session-local.
        let archiveKey: String?
        if survey.scanMethod.localizedCaseInsensitiveContains("VR") || survey.scanMethod.contains("仿真") {
            archiveKey = SpatialSurveyArchiveKeys.virtual
        } else if survey.scanMethod.contains("RoomPlan") || survey.scanMethod.contains("AR") {
            archiveKey = SpatialSurveyArchiveKeys.measured
        } else {
            archiveKey = nil
        }
        if let archiveKey, let data = try? JSONEncoder().encode(survey) {
            UserDefaults.standard.set(data, forKey: archiveKey)
            let notification: Notification.Name = archiveKey == SpatialSurveyArchiveKeys.virtual
                ? .didUpdateHouseSpatialSurvey
                : .didUpdateMeasuredSpatialSurvey
            NotificationCenter.default.post(name: notification, object: nil)
        }
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
                                        .adaptiveFont(size: 11, weight: .bold)
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
                                .adaptiveFont(size: 12, weight: .bold)
                                .foregroundColor(severityColor(item.severity))
                            Text(item.locationName)
                                .adaptiveFont(size: 10, weight: .medium)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text(item.severity.localizedTitle)
                                .adaptiveFont(size: 9, weight: .bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(severityColor(item.severity).opacity(0.25))
                                .cornerRadius(4)
                                .foregroundColor(severityColor(item.severity))
                        }
                        Text(item.detail)
                            .adaptiveFont(size: 10, weight: .regular)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                        Text("\(lang.t("floorplan_solution_prefix")) \(item.solution)")
                            .adaptiveFont(size: 10, weight: .medium)
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
                            Text(mode.localizedTitle)
                                .adaptiveFont(size: 10, weight: .medium)
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
                        Text(palaceGridMode == .baZhai ? lang.t("3d_grid_bazhai") : (palaceGridMode == .xuanKong ? lang.t("3d_grid_xuankong") : lang.t("3d_grid_off")))
                    }
                    .adaptiveFont(size: 10, weight: .bold)
                    .foregroundColor(palaceGridMode != .off ? .yanGold : .white.opacity(0.6))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(8)
                }
                .accessibilityLabel(lang.t("3d_grid_bazhai"))

                // 尺寸标注开关
                Button(action: { showDimensions.toggle() }) {
                    Image(systemName: showDimensions ? "ruler.fill" : "ruler")
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(showDimensions ? .yanCyan : .white.opacity(0.6))
                        .padding(7)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel(lang.t("3d_metric_depth_width"))

                // 形煞警示标注开关
                Button(action: { showShaAlerts.toggle() }) {
                    Image(systemName: showShaAlerts ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(showShaAlerts ? .orange : .white.opacity(0.6))
                        .padding(7)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel(lang.t("ar_sha_analysis_prefix"))

                // 重置视角
                Button(action: {
                    sceneCoordinator?.resetCamera(mode: viewMode)
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel(lang.t("3d_reset_camera"))
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
        if !iap.hasUnlockedVIP {
            showPaywall = true
            return
        }
        guard let coord = sceneCoordinator, let snapshot = coord.captureSnapshot() else { return }
        let reportImage = SurveyReportRenderer.renderReportImage(survey: survey, snapshot: snapshot)
        self.shareSheetItem = SurveyShareReportItem(activityItems: [reportImage])
    }

    private func exportAndShareDXF() {
        if !iap.hasUnlockedVIP {
            showPaywall = true
            return
        }
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
        shaAlertsNode.childNodes.forEach { $0.removeFromParentNode() }

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

        // 金色贯通天地的立极中宫光柱
        let pillarGeo = SCNCylinder(radius: 0.18, height: CGFloat(survey.dimensions.ceilingHeight * 1.5))
        let pillarMat = SCNMaterial()
        pillarMat.diffuse.contents = UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 0.75)
        pillarMat.emission.contents = UIColor(red: 0.90, green: 0.70, blue: 0.20, alpha: 0.5)
        pillarGeo.materials = [pillarMat]
        let lang = LocalizationManager.shared.effectiveLanguage
        let pillarNode = SCNNode(geometry: pillarGeo)
        pillarNode.position = SCNVector3(survey.centroidX, survey.dimensions.ceilingHeight * 0.75, survey.centroidZ)
        let coordStr = String(format: "%.1f, %.1f", survey.centroidX, survey.centroidZ)
        switch lang {
        case .zhHans, .auto: pillarNode.name = "【全屋太极立极中心】三维坐标 (\(coordStr))"
        case .zhHant: pillarNode.name = "【全屋太極立極中心】三維座標 (\(coordStr))"
        case .en:     pillarNode.name = "[Taiji Center] 3D Coords (\(coordStr))"
        case .ja:     pillarNode.name = "【全屋太極中心】3D座標 (\(coordStr))"
        case .ko:     pillarNode.name = "【전체 태극 중심】 3D 좌표 (\(coordStr))"
        case .vi:     pillarNode.name = "[Tâm Thái Cực] Tọa độ 3D (\(coordStr))"
        case .th:     pillarNode.name = "[จุดศูนย์กลางไท่จี๋] พิกัด 3D (\(coordStr))"
        case .id:     pillarNode.name = "[Pusat Taiji] Koordinat 3D (\(coordStr))"
        }
        rootHouseNode.addChildNode(pillarNode)

        let centerRingGeo = SCNTorus(ringRadius: 0.6, pipeRadius: 0.04)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 0.9)
        centerRingGeo.materials = [ringMat]
        let ringNode = SCNNode(geometry: centerRingGeo)
        ringNode.position = SCNVector3(survey.centroidX, 0.02, survey.centroidZ)
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
            let segName = LubanRulerEvaluation.evaluate(meters: op.width).localizedYangSegmentName
            let opName = op.type.localizedName
            switch lang {
            case .zhHans, .auto: opNode.name = "\(opName)：宽 \(wStr)m × 高 \(hStr)m · 鲁班尺【\(segName)】字门"
            case .zhHant: opNode.name = "\(opName)：寬 \(wStr)m × 高 \(hStr)m · 魯班尺【\(segName)】字門"
            case .en:     opNode.name = "\(opName): W \(wStr)m × H \(hStr)m · Lu Ban [\(segName)]"
            case .ja:     opNode.name = "\(opName)：幅 \(wStr)m × 高 \(hStr)m・魯班尺【\(segName)】門"
            case .ko:     opNode.name = "\(opName): 폭 \(wStr)m × 높이 \(hStr)m · 노반척【\(segName)】"
            case .vi:     opNode.name = "\(opName): Rộng \(wStr)m × Cao \(hStr)m · Lỗ Ban [\(segName)]"
            case .th:     opNode.name = "\(opName): กว้าง \(wStr)m × สูง \(hStr)m · หลู่ปาน [\(segName)]"
            case .id:     opNode.name = "\(opName): L \(wStr)m × T \(hStr)m · Lu Ban [\(segName)]"
            }
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
            case .zhHans, .auto: rNode.name = "\(rName)：实测面积 \(areaStr)㎡ · 面宽 \(wStr)m × 进深 \(dStr)m"
            case .zhHant: rNode.name = "\(rName)：實測面積 \(areaStr)㎡ · 面寬 \(wStr)m × 進深 \(dStr)m"
            case .en:     rNode.name = "\(rName): Area \(areaStr)㎡ · W \(wStr)m × D \(dStr)m"
            case .ja:     rNode.name = "\(rName)：実測面積 \(areaStr)㎡・間口 \(wStr)m × 奥行 \(dStr)m"
            case .ko:     rNode.name = "\(rName): 실측면적 \(areaStr)㎡ · 폭 \(wStr)m × 깊이 \(dStr)m"
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

        buildShaAlertVisuals(survey: survey)
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
    private func buildPalaceGridOverlay(survey: HouseSpatialSurvey, mode: House3DSpaceViewer.PalaceGridMode) {
        baguaGridNode.childNodes.forEach { $0.removeFromParentNode() }
        guard mode != .off else { return }
        let lang = LocalizationManager.shared.effectiveLanguage

        let cx = survey.centroidX
        let cz = survey.centroidZ
        let w = survey.dimensions.totalWidth
        let d = survey.dimensions.totalDepth
        let cellW = CGFloat(w / 3.0)
        let cellD = CGFloat(d / 3.0)
        // HouseSpatialSurveyEngine uses the longest wall as the OBB axis for
        // its nine-palace analysis. Rotate this visual overlay by the same
        // axis; otherwise a diagonal RoomPlan house receives a world-aligned
        // grid that disagrees with the actual walls and centroid calculation.
        let axisAngle = primaryAxisAngle(survey: survey)
        let cosAxis = cos(axisAngle)
        let sinAxis = sin(axisAngle)

        guard let houseFacing = survey.resolvedHouseFacing else { return }
        let facingGua = HouseSpatialSurveyEngine.guaForAngle(houseFacing)
        let sittingAngle = (houseFacing + 180.0).truncatingRemainder(dividingBy: 360.0)
        let sittingGua = HouseSpatialSurveyEngine.guaForAngle(sittingAngle)

        let bazhai = BaZhaiEngine.shared.analyze(sittingPalace: sittingGua, facingPalace: facingGua)
        let facingM = Mountain24Data.shared.mountain(for: houseFacing)
        let sittingM = Mountain24Data.shared.mountain(for: sittingAngle)
        let xkChart = FlyingStarsEngine.shared.calculateChart(
            period: FlyingStarsEngine.shared.currentPeriod(for: survey.timestamp),
            sitting: sittingM, facing: facingM,
            useTiGua: Mountain24Data.shared.resolveHeadingState(heading: houseFacing).isJianXiang,
            date: survey.timestamp
        )

        for row in -1...1 {
            for col in -1...1 {
                let localX = Float(col) * Float(cellW)
                let localZ = Float(row) * Float(cellD)
                let cellX = cx + localX * cosAxis - localZ * sinAxis
                let cellZ = cz + localX * sinAxis + localZ * cosAxis

                let plane = SCNPlane(width: cellW * 0.95, height: cellD * 0.95)
                let mat = SCNMaterial()

                let nodeName: String
                if row == 0 && col == 0 {
                    mat.diffuse.contents = UIColor(red: 0.95, green: 0.85, blue: 0.35, alpha: 0.20)
                    switch lang {
                    case .zhHans, .auto: nodeName = "【中宫太极】九运天心：运星 \(xkChart.period)"
                    case .zhHant: nodeName = "【中宮太極】九運天心：運星 \(xkChart.period)"
                    case .en:     nodeName = "[Center Palace] Period Star \(xkChart.period)"
                    case .ja:     nodeName = "【中宮太極】天心：運星 \(xkChart.period)"
                    case .ko:     nodeName = "【중궁 태극】 천심: 운성 \(xkChart.period)"
                    case .vi:     nodeName = "[Trung Cung Thái Cực] Vận tinh \(xkChart.period)"
                    case .th:     nodeName = "[เรือนกลางไท่จี๋] ดาวยุค \(xkChart.period)"
                    case .id:     nodeName = "[Sektor Tengah Taiji] Bintang Periode \(xkChart.period)"
                    }
                } else {
                    let angleRad = atan2(Double(localX * cosAxis - localZ * sinAxis),
                                         Double(-(localX * sinAxis + localZ * cosAxis)))
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
                            let gName = item.localizedGuaName
                            let dName = item.localizedDirection
                            let sName = item.star.localizedName
                            switch lang {
                            case .zhHans, .auto: nodeName = "【八宅·\(gName)宫】\(dName)：【\(sName)】(\(item.star.isAuspicious ? "吉" : "凶"))"
                            case .zhHant: nodeName = "【八宅·\(gName)宮】\(dName)：【\(sName)】(\(item.star.isAuspicious ? "吉" : "凶"))"
                            case .en:     nodeName = "[Ba Zhai · \(gName)] \(dName): [\(sName)] (\(item.star.isAuspicious ? "Auspicious" : "Caution"))"
                            case .ja:     nodeName = "【八宅・\(gName)宮】\(dName)：【\(sName)】(\(item.star.isAuspicious ? "吉" : "凶"))"
                            case .ko:     nodeName = "【팔택·\(gName)궁】 \(dName): 【\(sName)】(\(item.star.isAuspicious ? "길" : "흉"))"
                            case .vi:     nodeName = "[Bát Trạch · \(gName)] \(dName): [\(sName)] (\(item.star.isAuspicious ? "Cát" : "Hung"))"
                            case .th:     nodeName = "[ปาไจ๋ · \(gName)] \(dName): [\(sName)] (\(item.star.isAuspicious ? "มงคล" : "ควรระวัง"))"
                            case .id:     nodeName = "[Ba Zhai · \(gName)] \(dName): [\(sName)] (\(item.star.isAuspicious ? "Baik" : "Waspada"))"
                            }
                        } else {
                            mat.diffuse.contents = UIColor(white: 1.0, alpha: 0.08)
                            nodeName = "[\(cellGua)]"
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
                            let pName = palace.localizedPalaceName
                            switch lang {
                            case .zhHans, .auto: nodeName = "【玄空九运·\(pName)宫】山星 \(palace.mountainStar) · 向星 \(palace.facingStar) · 运星 \(palace.periodStar)"
                            case .zhHant: nodeName = "【玄空九運·\(pName)宮】山星 \(palace.mountainStar) · 向星 \(palace.facingStar) · 運星 \(palace.periodStar)"
                            case .en:     nodeName = "[Xuan Kong · \(pName)] Mountain \(palace.mountainStar) · Facing \(palace.facingStar) · Base \(palace.periodStar)"
                            case .ja:     nodeName = "【玄空・\(pName)宮】山星 \(palace.mountainStar)・向星 \(palace.facingStar)・運星 \(palace.periodStar)"
                            case .ko:     nodeName = "【현공·\(pName)궁】 산성 \(palace.mountainStar) · 향성 \(palace.facingStar) · 운성 \(palace.periodStar)"
                            case .vi:     nodeName = "[Huyền Không · \(pName)] Sơn \(palace.mountainStar) · Hướng \(palace.facingStar) · Vận \(palace.periodStar)"
                            case .th:     nodeName = "[เสวียนคง · \(pName)] ภูเขา \(palace.mountainStar) · หัน \(palace.facingStar) · ยุค \(palace.periodStar)"
                            case .id:     nodeName = "[Xuan Kong · \(pName)] Gunung \(palace.mountainStar) · Hadap \(palace.facingStar) · Dasar \(palace.periodStar)"
                            }
                        } else {
                            mat.diffuse.contents = UIColor(white: 1.0, alpha: 0.08)
                            nodeName = "[\(cellGua)]"
                        }
                    }
                }

                plane.materials = [mat]
                let node = SCNNode(geometry: plane)
                node.eulerAngles.x = -Float.pi / 2
                node.eulerAngles.y = -axisAngle
                node.position = SCNVector3(cellX, 0.012, cellZ)
                node.name = nodeName
                baguaGridNode.addChildNode(node)
            }
        }
    }

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

    private func buildShaAlertVisuals(survey: HouseSpatialSurvey) {
        let lang = LocalizationManager.shared.effectiveLanguage
        for sha in survey.shaItems {
            guard let pos = sha.coordinate else { continue }

            let sphereGeo = SCNSphere(radius: 0.22)
            let sphereMat = SCNMaterial()
            let alertColor = sha.severity == .critical ? UIColor.systemRed : (sha.severity == .warning ? UIColor.systemOrange : UIColor.systemGreen)
            sphereMat.diffuse.contents = alertColor
            sphereMat.emission.contents = alertColor.withAlphaComponent(0.6)
            sphereGeo.materials = [sphereMat]
            let sNode = SCNNode(geometry: sphereGeo)
            // Keep the measured vertical coordinate. Clamping every alert to
            // 0.5 m made floor-level, ceiling-level and wall-level findings
            // appear at the same height in the 3D scene.
            sNode.position = SCNVector3(pos.x, pos.y, pos.z)
            sNode.name = "[\(sha.title)] \(sha.locationName): \(sha.detail)"
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
                    beamNode.position = SCNVector3(mid.x, mid.y, mid.z)

                    let dir = simd_normalize(targetPos - pos)
                    let pitch = asin(-dir.y)
                    let yaw = atan2(dir.x, dir.z)
                    beamNode.eulerAngles = SCNVector3(pitch + Float.pi / 2, yaw, Float(0))
                    switch lang {
                    case .zhHans, .auto: beamNode.name = "冲煞对流轨迹：\(sha.title)"
                    case .zhHant: beamNode.name = "衝煞對流軌跡：\(sha.title)"
                    case .en:     beamNode.name = "Airflow / Sha Vector: \(sha.title)"
                    case .ja:     beamNode.name = "気流・殺気ライン：\(sha.title)"
                    case .ko:     beamNode.name = "기류·충살 궤적: \(sha.title)"
                    case .vi:     beamNode.name = "Tuyến xung khí: \(sha.title)"
                    case .th:     beamNode.name = "แนวกระแสปะทะ: \(sha.title)"
                    case .id:     beamNode.name = "Jalur Aliran / Sha: \(sha.title)"
                    }
                    shaAlertsNode.addChildNode(beamNode)
                }
            }
        }
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
        // Keep every detected finding and its remedy in the exported image.
        // The previous fixed canvas silently dropped entries after the fourth
        // item when the report was shared.
        let extraShaHeight = CGFloat(max(0, survey.shaItems.count - 4)) * 110.0
        let size = CGSize(width: 1080, height: 1920 + extraShaHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0).setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            let lang = LocalizationManager.shared.effectiveLanguage
            let reportTitle: String
            let subtitle: String
            let dimsHeader: String
            let dimsText: String
            let shaHeader: String
            let remedyPrefix: String
            let footerText: String
            let dateStr = DateFormatter.localizedString(from: survey.timestamp, dateStyle: .medium, timeStyle: .short)
            switch lang {
            case .zhHans, .auto:
                reportTitle = "天机演象 · 全屋 3D 空间测绘与形煞全息存证"
                subtitle = String(format: "测绘基准朝向: %.1f° · 空间得分: %d分 · 测绘时间: %@", survey.compassHeading, survey.fengshuiScore, dateStr)
                dimsHeader = "【房屋全维物理测绘参数】"
                dimsText = String(
                    format: "• 开间面宽: %.2f m     • 进深长度: %.2f m\n• 室内净层高: %.2f m    • 进深面宽比: %.2f\n• 套内净面积: %.1f ㎡   • 建筑估算面积: %.1f ㎡\n• 墙体总段数: %d 段     • 门窗开孔总数: %d 处",
                    survey.dimensions.totalWidth, survey.dimensions.totalDepth, survey.dimensions.ceilingHeight, survey.dimensions.aspectRatio,
                    survey.dimensions.usableFloorArea, survey.dimensions.grossFloorArea, survey.walls.count, survey.openings.count
                )
                shaHeader = "【全屋形煞引擎体检结论与化解】"
                remedyPrefix = "化解方案："
                footerText = "天机演象 · AR/LiDAR 空间测绘参考（需现场复核）"
            case .zhHant:
                reportTitle = "天機演象 · 全屋 3D 空間測繪與形煞全息存證"
                subtitle = String(format: "測繪基準朝向: %.1f° · 空間得分: %d分 · 測繪時間: %@", survey.compassHeading, survey.fengshuiScore, dateStr)
                dimsHeader = "【房屋全維物理測繪參數】"
                dimsText = String(
                    format: "• 開間面寬: %.2f m     • 進深長度: %.2f m\n• 室內淨層高: %.2f m    • 進深面寬比: %.2f\n• 套內淨面積: %.1f ㎡   • 建築估算面積: %.1f ㎡\n• 牆體總段數: %d 段     • 門窗開孔總數: %d 處",
                    survey.dimensions.totalWidth, survey.dimensions.totalDepth, survey.dimensions.ceilingHeight, survey.dimensions.aspectRatio,
                    survey.dimensions.usableFloorArea, survey.dimensions.grossFloorArea, survey.walls.count, survey.openings.count
                )
                shaHeader = "【全屋形煞引擎體檢結論與化解】"
                remedyPrefix = "化解方案："
                footerText = "天機演象 · AR/LiDAR 空間測繪參考（需現場複核）"
            case .en:
                reportTitle = "TianJi · 3D Spatial Survey & Feng Shui Audit"
                subtitle = String(format: "Heading: %.1f° · Score: %d · Date: %@", survey.compassHeading, survey.fengshuiScore, dateStr)
                dimsHeader = "[Physical Spatial Measurements]"
                dimsText = String(
                    format: "• Total Width: %.2f m    • Total Depth: %.2f m\n• Ceiling Height: %.2f m • Depth/Width Ratio: %.2f\n• Net Area: %.1f ㎡      • Est. Gross Area: %.1f ㎡\n• Wall Segments: %d      • Doors & Windows: %d",
                    survey.dimensions.totalWidth, survey.dimensions.totalDepth, survey.dimensions.ceilingHeight, survey.dimensions.aspectRatio,
                    survey.dimensions.usableFloorArea, survey.dimensions.grossFloorArea, survey.walls.count, survey.openings.count
                )
                shaHeader = "[Spatial Audit Findings & Remedies]"
                remedyPrefix = "Remedy: "
                footerText = "TianJi · AR/LiDAR Spatial Survey Reference (Verify on site)"
            case .ja:
                reportTitle = "天機演象・全屋3D空間測距＆風水診断レポート"
                subtitle = String(format: "基準方位: %.1f° ・ スコア: %d点 ・ 計測日時: %@", survey.compassHeading, survey.fengshuiScore, dateStr)
                dimsHeader = "【住戸3D物理計測パラメータ】"
                dimsText = String(
                    format: "• 間口幅: %.2f m        • 奥行長: %.2f m\n• 有効天井高: %.2f m    • 奥行間口比: %.2f\n• 専有内法面積: %.1f ㎡ • 推定延床面積: %.1f ㎡\n• 壁セグメント: %d 箇所 • 開口部総数: %d 箇所",
                    survey.dimensions.totalWidth, survey.dimensions.totalDepth, survey.dimensions.ceilingHeight, survey.dimensions.aspectRatio,
                    survey.dimensions.usableFloorArea, survey.dimensions.grossFloorArea, survey.walls.count, survey.openings.count
                )
                shaHeader = "【空間風水診断結果と化殺対策】"
                remedyPrefix = "対策："
                footerText = "天機演象・AR/LiDAR空間計測リファレンス（要現地確認）"
            case .ko:
                reportTitle = "천기연상 · 전실 3D 공간 측량 및 풍수 진단 보고서"
                subtitle = String(format: "기준 향: %.1f° · 공간 점수: %d점 · 측량 일시: %@", survey.compassHeading, survey.fengshuiScore, dateStr)
                dimsHeader = "【주택 물리 측량 파라미터】"
                dimsText = String(
                    format: "• 전면 폭: %.2f m       • 깊이 길이: %.2f m\n• 실내 층고: %.2f m     • 깊이/폭 비율: %.2f\n• 전용 면적: %.1f ㎡    • 추정 연면적: %.1f ㎡\n• 벽체 구간: %d개       • 문·창문 개구부: %d곳",
                    survey.dimensions.totalWidth, survey.dimensions.totalDepth, survey.dimensions.ceilingHeight, survey.dimensions.aspectRatio,
                    survey.dimensions.usableFloorArea, survey.dimensions.grossFloorArea, survey.walls.count, survey.openings.count
                )
                shaHeader = "【전실 형살 진단 결과 및 비보책】"
                remedyPrefix = "해결 방안: "
                footerText = "천기연상 · AR/LiDAR 공간 측량 참고 (현장 확인 권장)"
            case .vi:
                reportTitle = "Thiên Cơ · Báo Cáo Đo Đạc 3D & Thẩm Định Phong Thủy"
                subtitle = String(format: "Hướng chuẩn: %.1f° · Điểm: %d · Thời gian: %@", survey.compassHeading, survey.fengshuiScore, dateStr)
                dimsHeader = "[Thông Số Đo Đạc Không Gian]"
                dimsText = String(
                    format: "• Chiều rộng: %.2f m     • Chiều sâu: %.2f m\n• Trần thông thủy: %.2f m • Tỷ lệ sâu/rộng: %.2f\n• Diện tích thông thủy: %.1f ㎡ • Diện tích sàn ước tính: %.1f ㎡\n• Số đoạn tường: %d      • Tổng cửa & cửa sổ: %d",
                    survey.dimensions.totalWidth, survey.dimensions.totalDepth, survey.dimensions.ceilingHeight, survey.dimensions.aspectRatio,
                    survey.dimensions.usableFloorArea, survey.dimensions.grossFloorArea, survey.walls.count, survey.openings.count
                )
                shaHeader = "[Kết Luận Thẩm Định & Phương Án Hóa Giải]"
                remedyPrefix = "Hóa giải: "
                footerText = "Thiên Cơ · Tham khảo đo đạc AR/LiDAR (Cần kiểm tra thực tế)"
            case .th:
                reportTitle = "เทียนจี · รายงานสำรวจมิติ 3D และวิเคราะห์ฮวงจุ้ย"
                subtitle = String(format: "ทิศอ้างอิง: %.1f° · คะแนน: %d · เวลา: %@", survey.compassHeading, survey.fengshuiScore, dateStr)
                dimsHeader = "[พารามิเตอร์การวัดพื้นที่จริง]"
                dimsText = String(
                    format: "• ความกว้างรวม: %.2f ม.   • ความลึกรวม: %.2f ม.\n• ความสูงเพดาน: %.2f ม.  • อัตราส่วนลึก/กว้าง: %.2f\n• พื้นที่ใช้สอยสุทธิ: %.1f ตร.ม. • พื้นที่รวมประมาณ: %.1f ตร.ม.\n• จำนวนผนัง: %d ช่วง      • ประตูและหน้าต่าง: %d จุด",
                    survey.dimensions.totalWidth, survey.dimensions.totalDepth, survey.dimensions.ceilingHeight, survey.dimensions.aspectRatio,
                    survey.dimensions.usableFloorArea, survey.dimensions.grossFloorArea, survey.walls.count, survey.openings.count
                )
                shaHeader = "[ผลการตรวจสอบฮวงจุ้ยและวิธีแก้ไข]"
                remedyPrefix = "วิธีแก้ไข: "
                footerText = "เทียนจี · ข้อมูลอ้างอิงการสำรวจ AR/LiDAR (ควรตรวจสอบหน้างาน)"
            case .id:
                reportTitle = "TianJi · Laporan Survei Ruang 3D & Audit Feng Shui"
                subtitle = String(format: "Arah Acuan: %.1f° · Skor: %d · Waktu: %@", survey.compassHeading, survey.fengshuiScore, dateStr)
                dimsHeader = "[Parameter Pengukuran Fisik Bangunan]"
                dimsText = String(
                    format: "• Lebar Total: %.2f m    • Kedalaman Total: %.2f m\n• Tinggi Plafon: %.2f m  • Rasio Dalam/Lebar: %.2f\n• Luas Bersih: %.1f ㎡   • Est. Luas Kotor: %.1f ㎡\n• Segmen Dinding: %d     • Total Pintu & Jendela: %d",
                    survey.dimensions.totalWidth, survey.dimensions.totalDepth, survey.dimensions.ceilingHeight, survey.dimensions.aspectRatio,
                    survey.dimensions.usableFloorArea, survey.dimensions.grossFloorArea, survey.walls.count, survey.openings.count
                )
                shaHeader = "[Temuan Audit Ruang & Solusi Penyeimbang]"
                remedyPrefix = "Solusi: "
                footerText = "TianJi · Referensi Survei Ruang AR/LiDAR (Verifikasi di lokasi)"
            }

            // 1. 顶部标题与金线
            reportTitle.draw(
                at: CGPoint(x: 50, y: 60),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 34),
                    .foregroundColor: UIColor(red: 0.96, green: 0.85, blue: 0.40, alpha: 1.0)
                ]
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

            dimsHeader.draw(
                at: CGPoint(x: 75, y: 1070),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 24),
                    .foregroundColor: UIColor(red: 0.0, green: 0.85, blue: 0.95, alpha: 1.0)
                ]
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
            shaHeader.draw(
                at: CGPoint(x: 50, y: shaHeaderY),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 26),
                    .foregroundColor: UIColor(red: 0.96, green: 0.85, blue: 0.40, alpha: 1.0)
                ]
            )

            var curY = shaHeaderY + 45
            for sha in survey.shaItems {
                let badge = "[\(sha.severity.localizedTitle)]"
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

                let desc = "\(sha.detail)\n\(remedyPrefix)\(sha.solution)"
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
            footerText.draw(
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
