import SwiftUI
import Photos
import UIKit
import Combine

// MARK: - 福宅天机宣纸勘测长卷预览与导出视图 (TianJiShu View - PRD 第14章)

public struct TianJiShuView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var scrollImage: UIImage? = nil
    @State private var isGenerating: Bool = true
    @State private var showSavedToast: Bool = false
    @State private var saveErrorMessage: String?
    @State private var showSaveError: Bool = false
    @State private var showPhotoSettings: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var isExporting: Bool = false
    @State private var reservedTianjiCredit: String?
    @State private var shareCompletionHandled = false
    // Invalidated whenever a new render starts or the view disappears, so a
    // late background result cannot overwrite current or dismissed state.
    @State private var renderGeneration: Int = 0
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.12).ignoresSafeArea()
                
                VStack(spacing: 12) {
                    if isGenerating {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.95, green: 0.85, blue: 0.45)))
                                .scaleEffect(1.5)
                            Text(lang.t("tianji_rendering"))
                                .font(.adaptive(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    } else if let img = scrollImage {
                        // 宣纸长卷全景预览 (支持纵向长距离滚动)
                        ScrollView {
                            ZStack {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 5)
                                
                            }
                            .padding(12)
                        }
                        
                        // 底部操作栏
                        VStack(spacing: 8) {
                            if !iap.canUseTianji {
                                VIPLockCardView(
                                    title: lang.t("tianji_vip_card_title"),
                                    featureDesc: lang.t("tianji_vip_card_desc"),
                                    badge: "\(lang.t("tianji_vip_badge")) · \(iap.localizedPrice(for: .tianjiSingle))",
                                    targetProductId: .tianjiSingle,
                                    onUnlockTap: { showPaywall = true }
                                )
                            }
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    guard !isExporting else { return }
                                    if !iap.canUseTianji {
                                        showPaywall = true
                                        return
                                    }
                                    let reservation = iap.hasUnlockedVIP ? nil : iap.reserveTianjiCredit()
                                    if !iap.hasUnlockedVIP && reservation == nil {
                                        showPaywall = true
                                        return
                                    }
                                    reservedTianjiCredit = reservation
                                    isExporting = true
                                    TianJiShuEngine.shared.saveToPhotoLibrary(image: img) { success, message in
                                        DispatchQueue.main.async {
                                            isExporting = false
                                            if success {
                                                // The credit was reserved before
                                                // the asynchronous photo write.
                                                commitReservedTianjiCredit()
                                                withAnimation { showSavedToast = true }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                                    withAnimation { showSavedToast = false }
                                                }
                                            } else {
                                                releaseReservedTianjiCredit()
                                                saveErrorMessage = message ?? lang.t("save_failed")
                                                let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
                                                showPhotoSettings = status == .denied || status == .restricted
                                                showSaveError = true
                                            }
                                        }
                                    }
                                }) {
                                    HStack {
                                        if isExporting {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        } else {
                                            Image(systemName: "square.and.arrow.down.fill")
                                        }
                                        Text(isExporting ? lang.t("exporting") : lang.t("save_to_photos"))
                                    }
                                    .font(.adaptive(size: 13, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(red: 0.95, green: 0.8, blue: 0.35), Color(red: 0.75, green: 0.55, blue: 0.2)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.black)
                                    .cornerRadius(10)
                                }
                                .disabled(isExporting)
                                
                                Button(action: {
                                    guard !isExporting else { return }
                                    if !iap.canUseTianji {
                                        showPaywall = true
                                        return
                                    }
                                    let reservation = iap.hasUnlockedVIP ? nil : iap.reserveTianjiCredit()
                                    if !iap.hasUnlockedVIP && reservation == nil {
                                        showPaywall = true
                                        return
                                    }
                                    reservedTianjiCredit = reservation
                                    shareCompletionHandled = false
                                    isExporting = true
                                    showShareSheet = true
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up.fill")
                                        Text(lang.t("share_and_print"))
                                    }
                                    .font(.adaptive(size: 13, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(isExporting)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    
                    // 保存成功轻提示
                    if showSavedToast {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text(lang.t("save_success"))
                                .font(.adaptive(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationBarTitle(lang.t("tianji_scroll"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                beginRendering()
            }
            .onChange(of: lang.effectiveLanguage) { _ in
                // The report image contains localized text independently of
                // the surrounding SwiftUI labels. Re-render it after a
                // language change so the page never mixes two locales.
                beginRendering()
            }
            .onChange(of: motion.headingState.facingMountain.id) { _ in
                // A long scroll captures the measured sitting/facing
                // direction. Refresh when the device crosses a 24-mountain
                // boundary so an export cannot silently contain a previous
                // orientation while the report sheet remains open.
                guard !isExporting else { return }
                beginRendering()
            }
            .onReceive(iap.$tianjiCreditsCount.dropFirst()) { _ in
                guard !isExporting else { return }
                beginRendering()
            }
            .onReceive(iap.$isVIPUser.dropFirst()) { _ in
                guard !isExporting else { return }
                beginRendering()
            }
            .onDisappear {
                // SwiftUI may dismiss the page while the worker is still
                // rendering. Invalidate its completion. A pending credit
                // reservation remains consumed if the process is interrupted;
                // refunding it here could turn a successful background export
                // into a free export.
                renderGeneration += 1
                isExporting = false
            }
            .sheet(isPresented: $showShareSheet, onDismiss: {
                // completionWithItemsHandler is not guaranteed to run when a
                // presentation is interrupted, so always clear the gate.
                isExporting = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if !shareCompletionHandled {
                        releaseReservedTianjiCredit()
                    }
                    shareCompletionHandled = false
                }
            }) {
                if let img = scrollImage {
                    TianJiActivityViewController(activityItems: [img]) { completed in
                        DispatchQueue.main.async {
                            isExporting = false
                            shareCompletionHandled = true
                            if completed {
                                // The credit was reserved before presenting
                                // the share sheet and is already consumed.
                                commitReservedTianjiCredit()
                            } else {
                                releaseReservedTianjiCredit()
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                VIPPaywallSheet(defaultProductId: .tianjiSingle)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        // Stable overlay instead of a system alert: this page observes the
        // high-frequency compass stream, which tore down the alert.
        .overlay(
            Group {
                if showSaveError {
                    FloorplanConfirmDialog(
                        title: lang.t("save_failed"),
                        message: saveErrorMessage ?? lang.t("save_failed"),
                        confirmTitle: showPhotoSettings ? lang.t("open_system_settings") : lang.t("done"),
                        cancelTitle: showPhotoSettings ? lang.t("done") : nil,
                        confirmColor: Color(red: 0.83, green: 0.68, blue: 0.21),
                        onConfirm: {
                            showSaveError = false
                            if showPhotoSettings,
                               let url = URL(string: UIApplication.openSettingsURLString),
                               UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        },
                        onCancel: { showSaveError = false }
                    )
                }
            }
        )
    }

    private func releaseReservedTianjiCredit() {
        guard let token = reservedTianjiCredit else { return }
        reservedTianjiCredit = nil
        iap.refundTianjiCreditReservation(token)
    }

    private func commitReservedTianjiCredit() {
        guard let token = reservedTianjiCredit else { return }
        reservedTianjiCredit = nil
        iap.commitTianjiCreditReservation(token)
    }

    private func beginRendering() {
                renderGeneration += 1
                let generation = renderGeneration
                // Capture all observable sensor values on the main thread
                // before moving the expensive renderer to a worker queue.
                // Reading @Published state from the background closure could
                // otherwise mix headings, coordinates and solar time from
                // different updates.
                let heading = motion.headingState.facingAngle
                let coordsDesc = motion.coordsDesc
                let solarTimeDesc = motion.solarTimeDesc
                let language = lang.effectiveLanguage
                // Freeze the current indoor/outdoor survey archive together
                // with the compass values. The renderer runs off the main
                // queue, so reading the live store inside it could mix a new
                // record with an older heading.
                let panoramaArchive = ShaSurveyStore.shared.archive
                let floorplanReport = FloorplanAuditStore.shared.latestReport
                let reportDate = Date()
                let hasExportEntitlement = iap.canUseTianji
                isGenerating = true
                DispatchQueue.global(qos: .userInitiated).async {
                    let img = TianJiShuEngine.shared.generateScrollImage(
                        heading: heading,
                        coordsDesc: coordsDesc,
                        solarTimeDesc: solarTimeDesc,
                        language: language,
                        isPro: hasExportEntitlement,
                        floorplanReport: floorplanReport,
                        panoramaArchive: panoramaArchive,
                        reportDate: reportDate
                    )
                    DispatchQueue.main.async {
                        guard self.renderGeneration == generation else { return }
                        self.scrollImage = img
                        self.isGenerating = false
                    }
                }
    }
}

// MARK: - iOS 原生分享面板适配层
public struct TianJiActivityViewController: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil
    public var onCompletion: ((Bool) -> Void)? = nil

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        // UIActivityViewController is a popover on iPad. Supplying an anchor
        // prevents a presentation exception when the report is shared there.
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX,
                                        y: controller.view.bounds.midY,
                                        width: 1,
                                        height: 1)
            popover.permittedArrowDirections = []
        }
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onCompletion?(completed)
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
