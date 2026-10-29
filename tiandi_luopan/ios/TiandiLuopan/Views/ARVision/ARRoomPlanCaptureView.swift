import SwiftUI
import UIKit

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
    @Published public private(set) var isCapturing = false
    @Published public private(set) var didFinish = false
    @Published public private(set) var errorMessage: String?

    private weak var captureView: RoomCaptureView?

    public func attach(to view: RoomCaptureView) {
        captureView = view
        view.captureSession.delegate = self
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

    public func saveSemanticReport() -> Result<URL, Error> {
        guard didFinish else {
            return .failure(ARRoomPlanExportError.captureNotFinished)
        }
        let payload: [String: Any] = [
            "source": "RoomPlan",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "walls": wallCount,
            "doors": doorCount,
            "windows": windowCount,
            "openings": openingCount,
            "objects": objectCount
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("TianJiYanXiang-RoomPlan-\(Int(Date().timeIntervalSince1970)).json")
            try data.write(to: url, options: .atomic)
            return .success(url)
        } catch {
            return .failure(error)
        }
    }

    public func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        let wallCount = room.walls.count
        let doorCount = room.doors.count
        let windowCount = room.windows.count
        let openingCount = room.openings.count
        let objectCount = room.objects.count
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.wallCount = wallCount
            self.doorCount = doorCount
            self.windowCount = windowCount
            self.openingCount = openingCount
            self.objectCount = objectCount
        }
    }

    public func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isCapturing = false
            self.didFinish = error == nil
            self.errorMessage = error?.localizedDescription
        }
    }
}

@available(iOS 16.0, *)
private enum ARRoomPlanExportError: Error {
    case captureNotFinished
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
            ARRoomPlanShareSheet(items: [item.url])
        }
    }

    private func shareReport() {
        switch model.saveSemanticReport() {
        case .success(let url):
            reportMessage = lang.t("ar_roomplan_report_ready")
            shareItem = ARRoomPlanShareItem(url: url)
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
    let url: URL
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
