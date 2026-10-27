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
        
        let kwStatusText: String
        let kwGradeText: String
        let kwColor: Color
        let kwDesc: String
        let remedyText: String
        
        if isLargeKW {
            kwStatusText = "大空亡线煞 (两卦相交界缝)"
            kwGradeText = "极凶大忌"
            kwColor = .red
            kwDesc = "当前立向正踏在八卦大卦交界之缝隙线上（大空亡），此线五行错乱、阴阳差错无序，磁场极其紊乱。在堪舆古训中属于绝线，主家道暴落、精神恍惚、横祸离异。"
            kwRemedyText = "必须立即拨动向首或微调建筑立面朝向，避开卦界缝隙至少 2 度以上，切勿在此角度立门定向！"
        } else if isSmallKW {
            kwStatusText = "小空亡出卦煞 (同宫两山交界)"
            kwGradeText = "出卦凶煞"
            kwColor = .orange
            kwDesc = "当前朝向临近同卦内两山交接缝隙线（小空亡），气杂不纯，阴差阳错，容易引起家人情绪不睦、口舌官非及呼吸神经衰弱。"
            kwRemedyText = "地师立向宜避开两山夹缝，微调向线回归正针或合规兼向分金内。"
        } else if isJianXiang {
            kwStatusText = "兼针兼向 (偏离中线 1.5°~4.5°)"
            kwGradeText = "起替卦排盘"
            kwColor = .yellow
            kwDesc = "当前朝向兼向偏离中心线，沈氏玄空学当以【替卦诀】起排九宫飞星，不能用单纯下卦，气场虽杂但合得水法与替星亦能发秀。"
            kwRemedyText = "进入【三元九运】页面查看替卦排盘方阵，依替卦挨星法定阴阳顺逆。"
        } else {
            kwStatusText = "正针纯清 (偏离中线 < 1.5°)"
            kwGradeText = "纯清正向"
            kwColor = .green
            kwDesc = "当前朝向端正居中，正针坐向，龙气纯粹无杂，属于正统下卦纯清大吉向，气运醇厚，吉庆发皇绵长。"
            kwRemedyText = "保持当前朝向立极，依玄空正向下卦排布开门、安床与灶位即可。"
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
                            Text("向首度数: \(String(format: "%.1f", heading))° · \(m.name)山 (中心 \(String(format: "%.1f", m.centerAngle))° 偏离 \(String(format: "%.1f", delta))°)")
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
                        Text("📐 易学空亡断决原理")
                            .font(.system(size: 15, weight: .bold))
                        Text(kwDesc)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                    }
                    
                    // 地师调理
                    VStack(alignment: .leading, spacing: 6) {
                        Text("🧭 专业地师立极化解调理指引")
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
            .navigationBarTitle("空亡全景诊断", displayMode: .inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
