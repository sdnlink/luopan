import SwiftUI

// MARK: - 一百二十分金定位与吉凶详解弹窗 (Fenjin Detail Sheet)

public struct FenjinDetailSheet: View {
    public let fenjin: FenjinItem
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 分金标题与吉凶徽章
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("【\(fenjin.jiaziName)】分金")
                                .font(.system(size: 26, weight: .bold, design: .serif))
                                .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                            Text("所属山向：\(fenjin.mountainName) · 第\(fenjin.index)分金 (中心度数 \(String(format: "%.1f", fenjin.centerAngle))°)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(fenjin.grade)
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
                        Text("📐 分金精确定位度数区间")
                            .font(.system(size: 15, weight: .bold))
                        Text("\(String(format: "%.1f", fenjin.startAngle))° 至 \(String(format: "%.1f", fenjin.endAngle))° (跨度 3.0°)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    // 孤虚旺相秘传断语
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📜 杨公分金秘诀与堪舆断语")
                            .font(.system(size: 15, weight: .bold))
                        Text(fenjin.lore)
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .padding(12)
                            .background(Color.yellow.opacity(0.08))
                            .cornerRadius(8)
                    }
                    
                    // 立向指引
                    VStack(alignment: .leading, spacing: 6) {
                        Text("🧭 地师实地立极指引")
                            .font(.system(size: 15, weight: .bold))
                        Text(fenjin.isAuspicious ?
                             "此度属天干旺相之位，正气流行，利于阴阳化合，主家宅安和、子孙绵盛，可放心定向立极。" :
                             "此度属孤虚或龟甲空亡败气之位，磁场偏枯，容易引发败财与体弱，建议地师微调罗盘准星避开此3度区间，拨向相邻旺相吉度。")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle("分金度数详勘", displayMode: .inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
