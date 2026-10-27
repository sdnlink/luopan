import SwiftUI

// MARK: - 福宅天机宣纸勘测长卷预览与导出视图 (TianJiShu View - PRD 第14章)

public struct TianJiShuView: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var scrollImage: UIImage? = nil
    @State private var isGenerating: Bool = true
    @State private var showSavedToast: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showPaywall: Bool = false
    
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
                            Text("正统古法宣纸长卷渲染中...")
                                .font(.system(size: 14))
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
                                
                                if !iap.canUseTianji {
                                    VStack(spacing: 60) {
                                        ForEach(0..<8, id: \.self) { _ in
                                            Text("演象·天机秘卷 VIP专享预览")
                                                .font(.system(size: 22, weight: .bold, design: .serif))
                                                .foregroundColor(Color.red.opacity(0.2))
                                                .rotationEffect(.degrees(-25))
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .allowsHitTesting(false)
                                }
                            }
                            .padding(12)
                        }
                        
                        // 底部操作栏
                        VStack(spacing: 8) {
                            if !iap.canUseTianji {
                                VIPLockCardView(
                                    title: "宣纸长卷高清导出 · VIP 专享",
                                    featureDesc: "一键汇总实测坐向、玄空飞星、八路黄泉、时家奇门与八宅命卦，出具古典宣纸朱丝栏大师全案无水印长卷。",
                                    badge: "👑 VIP / 单次 ¥9.9",
                                    targetProductId: .tianjiSingle,
                                    onUnlockTap: { showPaywall = true }
                                )
                            }
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    if !iap.canUseTianji {
                                        showPaywall = true
                                        return
                                    }
                                    _ = iap.consumeTianjiCredit()
                                    TianJiShuEngine.shared.saveToPhotoLibrary(image: img) { success, _ in
                                        if success {
                                            withAnimation { showSavedToast = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                                withAnimation { showSavedToast = false }
                                            }
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down.fill")
                                        Text(lang.t("save_to_photos"))
                                    }
                                    .font(.system(size: 13, weight: .bold))
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
                                
                                Button(action: {
                                    if !iap.canUseTianji {
                                        showPaywall = true
                                        return
                                    }
                                    _ = iap.consumeTianjiCredit()
                                    showShareSheet = true
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up.fill")
                                        Text(lang.t("share_and_print"))
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
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
                                .font(.system(size: 12, weight: .bold))
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
                DispatchQueue.global(qos: .userInitiated).async {
                    let img = TianJiShuEngine.shared.generateScrollImage(
                        heading: motion.headingState.facingAngle,
                        coordsDesc: motion.coordsDesc,
                        solarTimeDesc: motion.solarTimeDesc
                    )
                    DispatchQueue.main.async {
                        self.scrollImage = img
                        self.isGenerating = false
                    }
                }
            .sheet(isPresented: $showShareSheet) {
                if let img = scrollImage {
                    TianJiActivityViewController(activityItems: [img])
                }
            }
            .sheet(isPresented: $showPaywall) {
                VIPPaywallSheet(defaultProductId: .tianjiSingle)
            }
        }
    }
}

// MARK: - iOS 原生分享面板适配层
public struct TianJiActivityViewController: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
