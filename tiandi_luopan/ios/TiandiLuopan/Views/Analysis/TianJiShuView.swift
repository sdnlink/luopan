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
    @State private var exportImage: UIImage?
    // Invalidated whenever a new render starts or the view disappears, so a
    // late background result cannot overwrite current or dismissed state.
    @State private var renderGeneration: Int = 0
    @State private var showCustomSignEditor: Bool = false
    @State private var customClientName: String = UserDefaults.standard.string(forKey: "tianjishu_custom_client") ?? ""
    @State private var customMasterName: String = UserDefaults.standard.string(forKey: "tianjishu_custom_master") ?? ""
    @State private var customSealText: String = UserDefaults.standard.string(forKey: "tianjishu_custom_seal") ?? ""
    
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
                                .adaptiveFont(size: 14)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    } else if let img = scrollImage {
                        // P3.8 自定义师门落款、堂号印章与福主署名栏
                        customSignatureBar()
                            .padding(.horizontal, 16)

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
                                    prepareExportImage { exportImage in
                                        guard let exportImage = exportImage else {
                                            isExporting = false
                                            releaseReservedTianjiCredit()
                                            saveErrorMessage = lang.t("save_failed")
                                            showSaveError = true
                                            return
                                        }
                                        TianJiShuEngine.shared.saveToPhotoLibrary(image: exportImage) { success, message in
                                            DispatchQueue.main.async {
                                                isExporting = false
                                                if success {
                                                    // The credit is committed only
                                                    // after the photo write succeeds.
                                                    commitReservedTianjiCredit()
                                                    RetentionServiceManager.shared.recordMilestone(reason: "save_tianjishu")
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
                                    .adaptiveFont(size: 13, weight: .bold)
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
                                    isExporting = true
                                    prepareExportImage { exportImage in
                                        guard let exportImage = exportImage else {
                                            isExporting = false
                                            releaseReservedTianjiCredit()
                                            saveErrorMessage = lang.t("save_failed")
                                            showSaveError = true
                                            return
                                        }
                                        self.exportImage = exportImage
                                        // Keep only one long image in memory while
                                        // the share controller is presented.
                                        self.scrollImage = nil
                                        showShareSheet = true
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up.fill")
                                        Text(lang.t("share_and_print"))
                                    }
                                    .adaptiveFont(size: 13, weight: .bold)
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
                                .adaptiveFont(size: 12, weight: .bold)
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
                // rendering. The manager keeps the in-flight slot bounded and
                // the durable credit is only committed after success, so a
                // terminated process cannot permanently lose the credit.
                renderGeneration += 1
                isExporting = false
            }
            .sheet(isPresented: $showShareSheet, onDismiss: {
                // The activity controller completion callback is the source of
                // truth for commit/refund. If iOS interrupts the sheet before
                // invoking it, the manager's reservation timeout releases the
                // in-flight slot without debiting the credit.
                isExporting = false
                exportImage = nil
                if scrollImage == nil {
                    beginRendering()
                }
            }) {
                if let exportImage {
                    TianJiActivityViewController(activityItems: [exportImage]) { completed in
                        DispatchQueue.main.async {
                            isExporting = false
                            if completed {
                                // Commit exactly once after the share operation
                                // reports success. The manager makes repeated
                                // callbacks harmless.
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

    private func customSignatureBar() -> some View {
        let barTitle: String
        let clientPh: String
        let masterPh: String
        let sealPh: String
        let applyTitle: String
        switch lang.effectiveLanguage {
        case .en:
            barTitle = "Custom Seal, Studio & Client Signature"
            clientPh = "Client Name (e.g. Mr. Chen)"
            masterPh = "Master / Studio Name"
            sealPh = "Seal Text (e.g. XUAN KONG SEAL)"
            applyTitle = "Apply & Re-render Scroll"
        case .zhHant:
            barTitle = "定制師門落款 · 堂號朱印 · 福主署名"
            clientPh = "委託福主尊稱（如：陳公諱明 雅鑒）"
            masterPh = "堪輿師/堂號落款（如：玄空堂 李師傅）"
            sealPh = "朱砂印文（空格換行，如：玄空堂 欽定印）"
            applyTitle = "鈐印並重新生成長卷"
        case .ja:
            barTitle = "鑑定師落款・屋号朱印・施主名のカスタマイズ"
            clientPh = "施主様のお名前"
            masterPh = "鑑定師・屋号"
            sealPh = "朱印テキスト（空白で改行）"
            applyTitle = "落款を反映して再生成"
        case .ko:
            barTitle = "감여사 낙관 · 당호 인장 · 복주 서명 맞춤 설정"
            clientPh = "의뢰 복주 성함"
            masterPh = "감여사 / 당호 낙관"
            sealPh = "인장 문구 (공백으로 줄바꿈)"
            applyTitle = "낙관 적용 및 장권 재생성"
        case .vi:
            barTitle = "Tùy Chỉnh Lạc Khoản · Ấn Chương · Tên Thân Chủ"
            clientPh = "Tên Thân Chủ"
            masterPh = "Tên Đại Sư / Đường Hiệu"
            sealPh = "Chữ Ấn Chương"
            applyTitle = "Áp Dụng & Tạo Lại Trường Quyển"
        case .th:
            barTitle = "ปรับแต่งชื่อซินแส · ตราประทับ · ชื่อเจ้าของบ้าน"
            clientPh = "ชื่อเจ้าของบ้าน"
            masterPh = "ชื่อซินแส / สำนัก"
            sealPh = "ข้อความในตราประทับ"
            applyTitle = "ประทับตราและสร้างม้วนคัมภีร์ใหม่"
        case .id:
            barTitle = "Kustomisasi Nama Klien, Master & Stempel"
            clientPh = "Nama Klien"
            masterPh = "Nama Master / Studio"
            sealPh = "Teks Stempel Merah"
            applyTitle = "Terapkan & Buat Ulang"
        case .auto, .zhHans:
            barTitle = "定制师门落款 · 堂号朱印 · 福主署名"
            clientPh = "委托福主尊称（如：陈先生 雅鉴）"
            masterPh = "堪舆师/堂号落款（如：玄空堂 李师傅）"
            sealPh = "朱砂印文（空格换行，如：玄空堂 钦定印）"
            applyTitle = "钤印并重新生成长卷"
        }

        return VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCustomSignEditor.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "seal.fill")
                        .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.32))
                    Text(barTitle)
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Spacer()
                    Image(systemName: showCustomSignEditor ? "chevron.up" : "chevron.down")
                        .adaptiveFont(size: 10, weight: .bold)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            if showCustomSignEditor {
                VStack(spacing: 6) {
                    TextField(clientPh, text: $customClientName)
                        .adaptiveFont(size: 11)
                        .padding(7)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    HStack(spacing: 6) {
                        TextField(masterPh, text: $customMasterName)
                            .adaptiveFont(size: 11)
                            .padding(7)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        TextField(sealPh, text: $customSealText)
                            .adaptiveFont(size: 11)
                            .padding(7)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    Button(action: {
                        UserDefaults.standard.set(customClientName, forKey: "tianjishu_custom_client")
                        UserDefaults.standard.set(customMasterName, forKey: "tianjishu_custom_master")
                        UserDefaults.standard.set(customSealText, forKey: "tianjishu_custom_seal")
                        showCustomSignEditor = false
                        beginRendering()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                            Text(applyTitle)
                        }
                        .adaptiveFont(size: 11, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(red: 0.83, green: 0.68, blue: 0.21))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
    }

    /// Render a clean export image only after the user starts a real save/share
    /// operation. The on-screen preview remains watermarked for single-credit
    /// users, preventing screenshots from bypassing the one-export rule.
    private func prepareExportImage(completion: @escaping (UIImage?) -> Void) {
        let heading = motion.headingState.facingAngle
        let coordsDesc = motion.coordsDesc
        let solarTimeDesc = motion.solarTimeDesc
        let language = lang.effectiveLanguage
        let panoramaArchive = ShaSurveyStore.shared.archive
        let floorplanReport = FloorplanAuditStore.shared.latestReport
        let reportDate = Date()
        DispatchQueue.global(qos: .userInitiated).async {
            let image = TianJiShuEngine.shared.generateScrollImage(
                heading: heading,
                coordsDesc: coordsDesc,
                solarTimeDesc: solarTimeDesc,
                language: language,
                isPro: true,
                floorplanReport: floorplanReport,
                panoramaArchive: panoramaArchive,
                reportDate: reportDate
            )
            DispatchQueue.main.async {
                completion(image)
            }
        }
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
                // A single credit authorizes one actual export. Keep the
                // preview watermarked until that export is committed; VIP and
                // lifetime users receive the clean preview immediately.
                let hasExportEntitlement = iap.hasUnlockedVIP
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
