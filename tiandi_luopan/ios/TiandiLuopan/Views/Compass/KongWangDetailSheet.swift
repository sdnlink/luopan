import SwiftUI

// MARK: - 空亡与兼向全景诊断弹窗 (KongWang Detail Sheet - PRD 6.1)

public struct KongWangDetailSheet: View {
    public let heading: Double
    @ObservedObject private var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        // The heading passed by CompassMainView is the opening snapshot. Read
        // the live manager here so an open diagnosis follows subsequent
        // compass movement instead of showing stale void-boundary data.
        let currentHeading = motion.headingState.facingAngle
        let m = Mountain24Data.shared.mountain(for: currentHeading)
        let rawDelta = abs(currentHeading - m.centerAngle)
        let delta = min(rawDelta, 360.0 - rawDelta)
        let kwLevel = motion.headingState.kongWangLevel
        let kwStatusText: String
        let kwGradeText: String
        let kwColor: Color
        let kwDesc: String
        let kwRemedyText: String
        
        switch kwLevel {
        case .largeVoid:
            kwStatusText = lang.t("kw_large_title")
            kwGradeText = lang.t("kw_large_grade")
            kwColor = .red
            kwDesc = lang.t("kw_large_desc")
            kwRemedyText = lang.t("kw_large_remedy")
        case .smallVoid:
            kwStatusText = lang.t("kw_small_title")
            kwGradeText = lang.t("kw_small_grade")
            kwColor = .orange
            kwDesc = lang.t("kw_small_desc")
            kwRemedyText = lang.t("kw_small_remedy")
        case .jianXiang:
            kwStatusText = lang.t("kw_sub_title")
            kwGradeText = lang.t("kw_sub_grade")
            kwColor = .yellow
            kwDesc = lang.t("kw_sub_desc")
            kwRemedyText = lang.t("kw_sub_remedy")
        case .pure:
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
                            Text("\(lang.t("kw_heading_prefix")): \(String(format: "%.1f", currentHeading))° · \(m.localizedName) (\(lang.t("kw_center_prefix")) \(String(format: "%.1f", m.centerAngle))° \(lang.t("kw_deviation_prefix")) \(String(format: "%.1f", delta))°)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
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
