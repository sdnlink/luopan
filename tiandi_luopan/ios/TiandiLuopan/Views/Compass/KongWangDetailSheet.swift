import SwiftUI

// MARK: - 空亡与兼向全景诊断弹窗 (KongWang Detail Sheet - PRD 6.1)

public struct KongWangDetailSheet: View {
    public let heading: Double
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        let m = Mountain24Data.shared.mountain(for: heading)
        let delta = abs(heading - m.centerAngle)
        let isLargeKW = delta >= 6.8 && [1, 3, 5, 7].contains(m.subIndex)
        let isSmallKW = delta >= 6.5 && !isLargeKW
        let isJianXiang = delta >= 1.5 && delta < 6.5
        let isZhengZhen = delta < 1.5
        let lang = LocalizationManager.shared
        
        let kwStatusText: String
        let kwGradeText: String
        let kwColor: Color
        let kwDesc: String
        let kwRemedyText: String
        
        if isLargeKW {
            kwStatusText = lang.t("kw_large_title")
            kwGradeText = lang.t("kw_large_grade")
            kwColor = .red
            kwDesc = lang.t("kw_large_desc")
            kwRemedyText = lang.t("kw_large_remedy")
        } else if isSmallKW {
            kwStatusText = lang.t("kw_small_title")
            kwGradeText = lang.t("kw_small_grade")
            kwColor = .orange
            kwDesc = lang.t("kw_small_desc")
            kwRemedyText = lang.t("kw_small_remedy")
        } else if isJianXiang {
            kwStatusText = lang.t("kw_sub_title")
            kwGradeText = lang.t("kw_sub_grade")
            kwColor = .yellow
            kwDesc = lang.t("kw_sub_desc")
            kwRemedyText = lang.t("kw_sub_remedy")
        } else {
            kwStatusText = lang.t("kw_pure_title")
            kwGradeText = lang.t("kw_pure_grade")
            kwColor = .green
            kwDesc = lang.t("kw_pure_desc")
            kwRemedyText = lang.t("kw_pure_remedy")
        }
        
        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 状态徽章
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kwStatusText)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(kwColor)
                            Text("\(lang.t("kw_heading_prefix")): \(String(format: "%.1f", heading))° · \(m.name) (\(lang.t("kw_center_prefix")) \(String(format: "%.1f", m.centerAngle))° \(lang.t("kw_deviation_prefix")) \(String(format: "%.1f", delta))°)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(kwGradeText)
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(kwColor.opacity(0.2))
                            .foregroundColor(kwColor)
                            .cornerRadius(6)
                    }
                    
                    Divider()
                    
                    // 诊断解析
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.t("kw_principle_section"))
                            .font(.system(size: 15, weight: .bold))
                        Text(kwDesc)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                    }
                    
                    // 地师调理
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.t("kw_master_remedy_section"))
                            .font(.system(size: 15, weight: .bold))
                        Text(kwRemedyText)
                            .font(.system(size: 13))
                            .lineSpacing(3)
                            .padding(12)
                            .background(Color.yellow.opacity(0.08))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle(lang.t("kw_sheet_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
