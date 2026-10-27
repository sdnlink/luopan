import SwiftUI

// MARK: - 一百二十分金定位与吉凶详解弹窗 (Fenjin Detail Sheet)

public struct FenjinDetailSheet: View {
    public let fenjin: FenjinItem
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        let lang = LocalizationManager.shared
        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 分金标题与吉凶徽章
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("【\(fenjin.jiaziName)】\(lang.t("fenjin_title_suffix"))")
                                .font(.system(size: 26, weight: .bold, design: .serif))
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Text("\(lang.t("fenjin_mountain_belong"))：\(fenjin.localizedMountainName) · \(lang.t("fenjin_index_prefix"))\(fenjin.index)\(lang.t("fenjin_title_suffix")) (\(lang.t("fenjin_center_deg")) \(String(format: "%.1f", fenjin.centerAngle))°)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(fenjin.localizedGrade)
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(fenjin.isAuspicious ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                            .foregroundColor(fenjin.isAuspicious ? .green : .red)
                            .cornerRadius(6)
                    }
                    
                    Divider()
                    
                    // 度数跨度
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.t("fenjin_range_section"))
                            .font(.system(size: 15, weight: .bold))
                        Text("\(String(format: "%.1f", fenjin.startAngle))° \(lang.t("fenjin_to")) \(String(format: "%.1f", fenjin.endAngle))° (\(lang.t("fenjin_span")) 3.0°)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    // 孤虚旺相秘传断语
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.t("fenjin_lore_section"))
                            .font(.system(size: 15, weight: .bold))
                        Text(fenjin.localizedLore)
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .padding(12)
                            .background(Color.yellow.opacity(0.08))
                            .cornerRadius(8)
                    }
                    
                    // 立向指引
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.t("fenjin_guidance_section"))
                            .font(.system(size: 15, weight: .bold))
                        Text(fenjin.isAuspicious ?
                             lang.t("fenjin_auspicious_advice") :
                             lang.t("fenjin_inauspicious_advice"))
                            .font(.system(size: 13))
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
    }
}
