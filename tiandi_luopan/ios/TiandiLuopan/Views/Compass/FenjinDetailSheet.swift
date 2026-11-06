import SwiftUI

// MARK: - 一百二十分金定位与吉凶详解弹窗 (Fenjin Detail Sheet)

public struct FenjinDetailSheet: View {
    public let fenjin: FenjinItem
    @ObservedObject private var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        // Keep the detail card live while the user rotates the compass. The
        // value passed when presenting the sheet is only the initial snapshot.
        let currentFenjin = Fenjin120Data.shared.resolveFenjin(for: motion.headingState.facingAngle)
        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 分金标题与吉凶徽章
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            let belongPrefix = lang.t("fenjin_mountain_belong")
                            let belongSep = (belongPrefix.hasSuffix(":") || belongPrefix.hasSuffix("：")) ? " " : "："
                            Text("【\(currentFenjin.localizedJiaziName)】\(lang.t("fenjin_title_suffix"))")
                                .adaptiveFont(size: 26, weight: .bold, design: .serif)
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                            Text("\(belongPrefix)\(belongSep)\(currentFenjin.localizedMountainName) · \(lang.t("fenjin_index_prefix"))\(currentFenjin.index)\(lang.t("fenjin_title_suffix")) (\(lang.t("fenjin_center_deg")) \(String(format: "%.1f", currentFenjin.centerAngle))°)")
                                .adaptiveFont(size: 13)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                        }
                        Spacer()
                        Text(currentFenjin.localizedGrade)
                            .adaptiveFont(size: 13, weight: .bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(currentFenjin.isAuspicious ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(currentFenjin.isAuspicious ? .green : .red)
                            .cornerRadius(6)
                    }
                    
                    Divider()
                    
                    // 度数跨度
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.t("fenjin_range_section"))
                            .adaptiveFont(size: 15, weight: .bold)
                        Text("\(String(format: "%.1f", currentFenjin.startAngle))° \(lang.t("fenjin_to")) \(String(format: "%.1f", currentFenjin.endAngle))° (\(lang.t("fenjin_span")) 3.0°)")
                            .adaptiveFont(size: 13, design: .monospaced)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    
                    // 孤虚旺相秘传断语
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.t("fenjin_lore_section"))
                            .adaptiveFont(size: 15, weight: .bold)
                        Text(currentFenjin.localizedLore)
                            .adaptiveFont(size: 14)
                            .lineSpacing(4)
                            .padding(12)
                            .background(Color.yellow.opacity(0.08))
                            .cornerRadius(8)
                    }
                    
                    // 立向指引
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.t("fenjin_guidance_section"))
                            .adaptiveFont(size: 15, weight: .bold)
                        Text(currentFenjin.isAuspicious ?
                             lang.t("fenjin_auspicious_advice") :
                             lang.t("fenjin_inauspicious_advice"))
                            .adaptiveFont(size: 13)
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle(lang.t("fenjin_detail_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
