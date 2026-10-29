import SwiftUI
import UIKit
import simd

#if canImport(RoomPlan)
import RoomPlan
#endif

#if canImport(RoomPlan)

@available(iOS 16.0, *)
private func stopRoomCaptureSession(_ session: RoomCaptureSession) {
    if #available(iOS 17.0, *) {
        session.stop(pauseARSession: true)
    } else {
        session.stop()
    }
}

@available(iOS 16.0, *)
public final class ARRoomPlanModel: NSObject, ObservableObject, RoomCaptureSessionDelegate {
    @Published public private(set) var wallCount = 0
    @Published public private(set) var doorCount = 0
    @Published public private(set) var windowCount = 0
    @Published public private(set) var openingCount = 0
    @Published public private(set) var objectCount = 0
    @Published public private(set) var estimatedWidthMeters: Float = 0
    @Published public private(set) var estimatedDepthMeters: Float = 0
    @Published public private(set) var estimatedAreaSqMeters: Float = 0
    @Published public private(set) var isCapturing = false
    @Published public private(set) var didFinish = false
    @Published public private(set) var errorMessage: String?

    private weak var captureView: RoomCaptureView?
    private var latestRoom: CapturedRoom?
    private let roomBuilder = RoomBuilder(options: [.beautifyObjects])

    /// Reports are user-created exports. Keep them in the app's support
    /// directory instead of `temporaryDirectory`, which iOS may purge while
    /// the share sheet is still open or as soon as the app is suspended.
    private static func reportDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ARRoomPlanExportError.storageUnavailable
        }
        let directory = applicationSupport
            .appendingPathComponent("TianJiYanXiang", isDirectory: true)
            .appendingPathComponent("ARExports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory
    }

    /// Room reports are exported for sharing and can be generated repeatedly
    /// during a survey. Retain a small rolling history so abandoned exports
    /// cannot grow the app's support directory forever.
    private static func pruneReports(in directory: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        var reports = files.filter {
            ($0.pathExtension == "json" || $0.pathExtension == "usdz") &&
            $0.lastPathComponent.hasPrefix("TianJiYanXiang-RoomPlan-")
        }
        .compactMap { url -> (url: URL, date: Date, size: Int)? in
            guard let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                  let date = values.creationDate,
                  let size = values.fileSize else { return nil }
            return (url, date, size)
        }
        .sorted { $0.date < $1.date }
        let maxFiles = 24
        let maxBytes = 40 * 1024 * 1024
        var totalBytes = reports.reduce(0) { $0 + $1.size }
        while reports.count > maxFiles || totalBytes > maxBytes {
            guard let oldest = reports.first else { break }
            try? FileManager.default.removeItem(at: oldest.url)
            totalBytes -= oldest.size
            reports.removeFirst()
        }
    }

    public func attach(to view: RoomCaptureView) {
        captureView = view
        view.captureSession.delegate = self
        latestRoom = nil
        estimatedWidthMeters = 0
        estimatedDepthMeters = 0
        estimatedAreaSqMeters = 0
        isCapturing = true
        didFinish = false
        errorMessage = nil
        view.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    public func stop() {
        if let session = captureView?.captureSession {
            stopRoomCaptureSession(session)
        }
        captureView = nil
        isCapturing = false
    }

    public func saveSemanticReport() -> Result<[URL], Error> {
        guard didFinish else {
            return .failure(ARRoomPlanExportError.captureNotFinished)
        }
        do {
            let directory = try Self.reportDirectory()
            let exportID = UUID().uuidString
            var exportedURLs: [URL] = []

            let surfaceToDict: (CapturedRoom.Surface) -> [String: Any] = { surface in
                let pos = surface.transform.columns.3
                return [
                    "id": surface.identifier.uuidString,
                    "width": Double(surface.dimensions.x),
                    "height": Double(surface.dimensions.y),
                    "depth": Double(surface.dimensions.z),
                    "position": [Double(pos.x), Double(pos.y), Double(pos.z)]
                ]
            }
            let objectToDict: (CapturedRoom.Object) -> [String: Any] = { object in
                let pos = object.transform.columns.3
                return [
                    "id": object.identifier.uuidString,
                    "category": String(describing: object.category),
                    "width": Double(object.dimensions.x),
                    "height": Double(object.dimensions.y),
                    "depth": Double(object.dimensions.z),
                    "position": [Double(pos.x), Double(pos.y), Double(pos.z)]
                ]
            }

            let payload: [String: Any] = [
                "source": "RoomPlan",
                "createdAt": ISO8601DateFormatter().string(from: Date()),
                "walls": wallCount,
                "doors": doorCount,
                "windows": windowCount,
                "openings": openingCount,
                "objects": objectCount,
                "dimensionsMeters": [
                    "width": Double(estimatedWidthMeters),
                    "depth": Double(estimatedDepthMeters),
                    "areaSqMeters": Double(estimatedAreaSqMeters)
                ],
                "wallSurfaces": latestRoom?.walls.map(surfaceToDict) ?? [],
                "doorSurfaces": latestRoom?.doors.map(surfaceToDict) ?? [],
                "windowSurfaces": latestRoom?.windows.map(surfaceToDict) ?? [],
                "openingSurfaces": latestRoom?.openings.map(surfaceToDict) ?? [],
                "detectedObjects": latestRoom?.objects.map(objectToDict) ?? []
            ]

            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            let jsonURL = directory.appendingPathComponent("TianJiYanXiang-RoomPlan-\(exportID).json")
            try data.write(to: jsonURL, options: .atomic)
            exportedURLs.append(jsonURL)

            if let room = latestRoom {
                let usdzURL = directory.appendingPathComponent("TianJiYanXiang-RoomPlan-\(exportID).usdz")
                if (try? room.export(to: usdzURL)) != nil {
                    exportedURLs.append(usdzURL)
                }
            }

            Self.pruneReports(in: directory)
            return .success(exportedURLs)
        } catch {
            return .failure(error)
        }
    }

    /// Converts the 3D CapturedRoom geometry into a 2D top-down architectural
    /// blueprint image and normalized `[FloorplanRoom]` blocks, then syncs them
    /// directly to Tab 3 (`FloorplanView`) for Nine-Palace / Eight-Mansions audit.
    public func syncToFloorplan() -> Bool {
        guard let room = latestRoom,
              let envelope = Self.compute2DEnvelope(for: room) else {
            return false
        }
        let spanX = max(0.5, envelope.maxX - envelope.minX)
        let spanZ = max(0.5, envelope.maxZ - envelope.minZ)
        let padding: Float = 0.10

        func normalizeRect(centerX: Float, centerZ: Float, width: Float, depth: Float) -> CGRect {
            let nx = CGFloat((centerX - envelope.minX) / spanX) * CGFloat(1.0 - 2 * padding) + CGFloat(padding)
            let ny = CGFloat((centerZ - envelope.minZ) / spanZ) * CGFloat(1.0 - 2 * padding) + CGFloat(padding)
            let nw = max(0.12, min(0.82, CGFloat(width / spanX) * CGFloat(1.0 - 2 * padding)))
            let nh = max(0.10, min(0.82, CGFloat(depth / spanZ) * CGFloat(1.0 - 2 * padding)))
            return CGRect(
                x: max(0.02, min(0.98 - nw, nx - nw / 2)),
                y: max(0.02, min(0.98 - nh, ny - nh / 2)),
                width: nw,
                height: nh
            )
        }

        var generatedRooms: [FloorplanRoom] = []

        // 1. Map doors (or openings if no doors) to `.door` blocks
        let doorSurfaces = !room.doors.isEmpty ? room.doors : Array(room.openings.prefix(1))
        for door in doorSurfaces.prefix(2) {
            let pos = door.transform.columns.3
            let rect = normalizeRect(
                centerX: pos.x,
                centerZ: pos.z,
                width: max(0.9, door.dimensions.x),
                depth: max(0.7, door.dimensions.z)
            )
            generatedRooms.append(FloorplanRoom(
                name: FloorplanRoomType.door.localizedName,
                type: .door,
                rect: rect
            ))
        }

        // 2. Map furniture objects into functional room zones
        var assignedTypes = Set<FloorplanRoomType>()
        for object in room.objects {
            let roomType: FloorplanRoomType?
            switch object.category {
            case .toilet, .bathtub:
                roomType = .bathroom
            case .stove, .refrigerator, .oven, .dishwasher:
                roomType = .kitchen
            case .bed:
                roomType = assignedTypes.contains(.masterBedroom) ? .secondBedroom : .masterBedroom
            case .sofa, .television, .fireplace:
                roomType = .livingRoom
            case .table, .storage:
                roomType = assignedTypes.contains(.livingRoom) ? .study : nil
            default:
                roomType = nil
            }
            guard let resolvedType = roomType, !assignedTypes.contains(resolvedType) else { continue }
            assignedTypes.insert(resolvedType)
            let pos = object.transform.columns.3
            let zoneW = max(1.8, object.dimensions.x * 1.8)
            let zoneD = max(1.8, object.dimensions.z * 1.8)
            let rect = normalizeRect(centerX: pos.x, centerZ: pos.z, width: zoneW, depth: zoneD)
            generatedRooms.append(FloorplanRoom(
                name: resolvedType.localizedName,
                type: resolvedType,
                rect: rect
            ))
        }

        // 3. Ensure at least a main living space is present if no furniture objects were classified
        if !assignedTypes.contains(.livingRoom) {
            let centerX = (envelope.minX + envelope.maxX) * 0.5
            let centerZ = (envelope.minZ + envelope.maxZ) * 0.5
            let mainRect = normalizeRect(
                centerX: centerX,
                centerZ: centerZ,
                width: spanX * 0.55,
                depth: spanZ * 0.55
            )
            generatedRooms.append(FloorplanRoom(
                name: FloorplanRoomType.livingRoom.localizedName,
                type: .livingRoom,
                rect: mainRect
            ))
        }

        // 4. Compute area-weighted geometric centroid
        let validRooms = generatedRooms.filter { $0.rect.width > 0 && $0.rect.height > 0 }
        let totalArea = validRooms.reduce(CGFloat(0)) { $0 + $1.rect.width * $1.rect.height }
        let centroid: CGPoint
        if totalArea > 0 {
            let cx = validRooms.reduce(CGFloat(0)) { $0 + $1.rect.midX * ($1.rect.width * $1.rect.height) } / totalArea
            let cy = validRooms.reduce(CGFloat(0)) { $0 + $1.rect.midY * ($1.rect.width * $1.rect.height) } / totalArea
            centroid = CGPoint(x: max(0.15, min(0.85, cx)), y: max(0.15, min(0.85, cy)))
        } else {
            centroid = CGPoint(x: 0.5, y: 0.5)
        }

        let blueprint = Self.render2DBlueprintImage(room: room, envelope: envelope)
        FloorplanView.persistRoomPlanImport(
            rooms: generatedRooms,
            centroid: centroid,
            blueprintImage: blueprint
        )
        return true
    }

    private static func compute2DEnvelope(
        for room: CapturedRoom
    ) -> (minX: Float, maxX: Float, minZ: Float, maxZ: Float)? {
        var minX = Float.greatestFiniteMagnitude
        var maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude
        var maxZ = -Float.greatestFiniteMagnitude
        var hasPoint = false

        let includeSurface: (CapturedRoom.Surface) -> Void = { surface in
            let center = surface.transform.columns.3
            let axisX = surface.transform.columns.0
            let halfW = surface.dimensions.x * 0.5
            let dx = abs(axisX.x) * halfW + 0.08
            let dz = abs(axisX.z) * halfW + 0.08
            minX = min(minX, center.x - dx)
            maxX = max(maxX, center.x + dx)
            minZ = min(minZ, center.z - dz)
            maxZ = max(maxZ, center.z + dz)
            hasPoint = true
        }
        room.walls.forEach(includeSurface)
        room.doors.forEach(includeSurface)
        room.windows.forEach(includeSurface)
        room.openings.forEach(includeSurface)
        for object in room.objects {
            let center = object.transform.columns.3
            let halfW = object.dimensions.x * 0.5
            let halfD = object.dimensions.z * 0.5
            minX = min(minX, center.x - halfW)
            maxX = max(maxX, center.x + halfW)
            minZ = min(minZ, center.z - halfD)
            maxZ = max(maxZ, center.z + halfD)
            hasPoint = true
        }
        guard hasPoint, maxX > minX, maxZ > minZ else { return nil }
        return (minX, maxX, minZ, maxZ)
    }

    private static func render2DBlueprintImage(
        room: CapturedRoom,
        envelope: (minX: Float, maxX: Float, minZ: Float, maxZ: Float)
    ) -> UIImage {
        let size = CGSize(width: 960, height: 960)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let spanX = max(0.5, envelope.maxX - envelope.minX)
        let spanZ = max(0.5, envelope.maxZ - envelope.minZ)
        let pad: CGFloat = 96.0
        let drawW = size.width - pad * 2
        let drawH = size.height - pad * 2

        let mapPoint: (Float, Float) -> CGPoint = { x, z in
            let nx = CGFloat((x - envelope.minX) / spanX)
            let nz = CGFloat((z - envelope.minZ) / spanZ)
            return CGPoint(x: pad + nx * drawW, y: pad + nz * drawH)
        }

        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1.0).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            // Draw subtle metric grid
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.06).cgColor)
            cg.setLineWidth(1)
            for idx in 0...8 {
                let offset = pad + CGFloat(idx) * (drawW / 8.0)
                cg.move(to: CGPoint(x: offset, y: pad))
                cg.addLine(to: CGPoint(x: offset, y: size.height - pad))
                cg.move(to: CGPoint(x: pad, y: offset))
                cg.addLine(to: CGPoint(x: size.width - pad, y: offset))
            }
            cg.strokePath()

            let drawSurfaceSegment: (CapturedRoom.Surface, UIColor, CGFloat) -> Void = { surface, color, lineWidth in
                let center = surface.transform.columns.3
                let axisX = surface.transform.columns.0
                let halfLen = surface.dimensions.x * 0.5
                let p1 = mapPoint(center.x - axisX.x * halfLen, center.z - axisX.z * halfLen)
                let p2 = mapPoint(center.x + axisX.x * halfLen, center.z + axisX.z * halfLen)
                cg.setStrokeColor(color.cgColor)
                cg.setLineWidth(lineWidth)
                cg.setLineCap(.round)
                cg.move(to: p1)
                cg.addLine(to: p2)
                cg.strokePath()
            }

            // Walls, windows, doors
            for wall in room.walls {
                drawSurfaceSegment(wall, UIColor(red: 0.85, green: 0.90, blue: 0.96, alpha: 0.95), 8.0)
            }
            for window in room.windows {
                drawSurfaceSegment(window, UIColor(red: 0.0, green: 0.82, blue: 0.95, alpha: 0.95), 6.0)
            }
            for door in room.doors {
                drawSurfaceSegment(door, UIColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 0.98), 7.0)
            }
            for opening in room.openings {
                drawSurfaceSegment(opening, UIColor.systemGreen.withAlphaComponent(0.85), 5.0)
            }

            // Dimension caption
            let dimText = String(format: "LiDAR RoomPlan · %.2f m × %.2f m (%.1f m²)", spanX, spanZ, spanX * spanZ)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor(red: 0.95, green: 0.85, blue: 0.45, alpha: 0.9)
            ]
            dimText.draw(at: CGPoint(x: pad, y: 34), withAttributes: attrs)
        }
    }

    private func updateMetrics(from room: CapturedRoom) {
        let wallCount = room.walls.count
        let doorCount = room.doors.count
        let windowCount = room.windows.count
        let openingCount = room.openings.count
        let objectCount = room.objects.count
        let envelope = Self.compute2DEnvelope(for: room)
        let width = envelope.map { max(0, $0.maxX - $0.minX) } ?? 0
        let depth = envelope.map { max(0, $0.maxZ - $0.minZ) } ?? 0
        let area = width * depth
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.latestRoom = room
            self.wallCount = wallCount
            self.doorCount = doorCount
            self.windowCount = windowCount
            self.openingCount = openingCount
            self.objectCount = objectCount
            self.estimatedWidthMeters = width
            self.estimatedDepthMeters = depth
            self.estimatedAreaSqMeters = area
        }
    }

    public func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        updateMetrics(from: room)
    }

    public func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isCapturing = false
                self.didFinish = false
                self.errorMessage = error.localizedDescription
            }
            return
        }
        Task { [weak self] in
            guard let self = self else { return }
            if let finalRoom = try? await self.roomBuilder.capturedRoom(from: data) {
                self.updateMetrics(from: finalRoom)
            }
            await MainActor.run {
                self.isCapturing = false
                self.didFinish = true
                self.errorMessage = nil
            }
        }
    }
}

@available(iOS 16.0, *)
private enum ARRoomPlanExportError: Error {
    case captureNotFinished
    case storageUnavailable
}

@available(iOS 16.0, *)
public struct ARRoomPlanPreviewView: UIViewRepresentable {
    @ObservedObject private var model: ARRoomPlanModel

    public init(model: ARRoomPlanModel) {
        self.model = model
    }

    public func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        model.attach(to: view)
        return view
    }

    public func updateUIView(_ uiView: RoomCaptureView, context: Context) {}

    public static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: ()) {
        stopRoomCaptureSession(uiView.captureSession)
    }
}

@available(iOS 16.0, *)
public struct ARRoomPlanSurveyView: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @StateObject private var model = ARRoomPlanModel()
    @Environment(\.presentationMode) private var presentationMode
    @State private var shareItem: ARRoomPlanShareItem?
    @State private var reportMessage: String?

    public init() {}

    public var body: some View {
        ZStack {
            ARRoomPlanPreviewView(model: model)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.t("ar_roomplan_title"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text(model.isCapturing ? lang.t("ar_roomplan_scanning") : lang.t("ar_roomplan_finished"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(model.isCapturing ? .green : .orange)
                    }
                    Spacer()
                    if model.isCapturing {
                        Button(action: { model.stop() }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .padding(9)
                                .background(Color.green)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(lang.t("ar_roomplan_finish"))
                    } else if model.didFinish {
                        Button(action: syncToFloorplan) {
                            Image(systemName: "scope")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                                .padding(9)
                                .background(Color.yanCyan)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(lang.t("tab_floorplan"))
                        Button(action: shareReport) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(9)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(lang.t("ar_roomplan_share"))
                    }
                    Button(action: {
                        model.stop()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(9)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(lang.t("ar_spatial_close"))
                }
                .padding(10)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding(.horizontal, 14)
                .padding(.top, 10)

                Spacer()

                VStack(alignment: .leading, spacing: 7) {
                    Text(lang.t("ar_roomplan_semantic_note"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                    if model.estimatedAreaSqMeters > 0 {
                        Text(String(
                            format: "%.2f × %.2f m (%.1f m²)",
                            model.estimatedWidthMeters,
                            model.estimatedDepthMeters,
                            model.estimatedAreaSqMeters
                        ))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.yanCyan)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        semanticCount("ar_spatial_wall", value: model.wallCount, icon: "rectangle.portrait")
                        semanticCount("ar_spatial_door", value: model.doorCount, icon: "door.left.hand.open")
                        semanticCount("ar_spatial_window", value: model.windowCount, icon: "window.vertical.open")
                        semanticCount("ar_roomplan_opening", value: model.openingCount, icon: "rectangle.dashed")
                        semanticCount("ar_roomplan_object", value: model.objectCount, icon: "cube")
                    }
                    if let error = model.errorMessage {
                        Text("\(lang.t("ar_roomplan_failed")): \(error)")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    if let reportMessage = reportMessage {
                        Text(reportMessage)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.yanCyan)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onDisappear { model.stop() }
        .sheet(item: $shareItem) { item in
            ARRoomPlanShareSheet(items: item.urls)
        }
    }

    private func syncToFloorplan() {
        if model.syncToFloorplan() {
            reportMessage = "\(lang.t("tab_floorplan")) · \(lang.t("save_success"))"
        } else {
            reportMessage = lang.t("ar_roomplan_report_unavailable")
        }
    }

    private func shareReport() {
        switch model.saveSemanticReport() {
        case .success(let urls):
            reportMessage = lang.t("ar_roomplan_report_ready")
            shareItem = ARRoomPlanShareItem(urls: urls)
        case .failure:
            reportMessage = lang.t("ar_roomplan_report_unavailable")
        }
    }

    private func semanticCount(_ key: String, value: Int, icon: String) -> some View {
        Label("\(lang.t(key)): \(value)", systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 16.0, *)
private struct ARRoomPlanShareItem: Identifiable {
    let id = UUID()
    let urls: [URL]
}

@available(iOS 16.0, *)
private struct ARRoomPlanShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(
                x: controller.view.bounds.midX,
                y: controller.view.bounds.midY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#endif
