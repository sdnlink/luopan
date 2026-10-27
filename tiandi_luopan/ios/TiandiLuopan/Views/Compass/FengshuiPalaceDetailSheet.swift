import SwiftUI

// MARK: - 居家风水八方详勘与空间布局全鉴弹窗 (Fengshui Palace Detail Sheet)

public struct FengshuiPalaceDetailSheet: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    private let palaces: [(gua: String, dir: String, elem: String, member: String, body: String, bestRoom: String, taboo: String, desc: String)] = [
        ("乾", "西北方", "金", "父亲/男主人", "头部、脑血管、骨骼", "尊贵主卧、总裁书房、高大纳气方", "忌做厨房(火烧天门)、忌污秽厕所", "乾为天，刚健笃实。家宅西北方为全屋统领之尊位，关系全家事业成就与顶梁柱健康。宜开阔厚重，忌低洼破损。"),
        ("坎", "正北方", "水", "中男/次子", "肾脏、泌尿、耳部血液", "文昌书房、静心茶室、卧室", "忌堆积杂物阴暗潮湿、忌缺角", "坎为水，深邃内敛。正北水旺利财源与智慧发皇，书房安于此方文思泉涌，科甲显名。"),
        ("艮", "东北方", "土", "少男/幼子", "脾胃、背脊、手足关节", "书房、次卧、神位安奉", "忌大面积卫浴、忌开大门直冲", "艮为山，止息安固。东北方为表鬼门，关系子孙运道与田宅家底，宜实墙厚重有靠。"),
        ("震", "正东方", "木", "长男/长子", "肝胆、神经系统、足部", "客厅、运动空间、大门纳气", "忌金属重物过多压制、忌缺角", "震为雷，生发勃达。正东方为紫气东来朝气生旺之所，晨光初照，大旺长子立志与事业开拓。"),
        ("巽", "东南方", "木", "长女/文昌位", "神经、呼吸系统、股部", "文昌书房、女孩闺房、阳台", "忌设垃圾桶、忌闭塞无窗", "巽为风，柔顺通达。东南方为四绿文曲秀木之地，大旺考试读书、贵人指引与清雅声誉。"),
        ("离", "正南方", "火", "中女/次女", "眼睛、心脏、血液循环", "客厅明堂、落地窗采光阳台", "忌厕所见水克火、忌过分阴暗", "离为火，光明附丽。正南方为朱雀明堂纳阳之尊位，阳光普照，大旺声誉名望、喜庆婚嫁与商业名气。"),
        ("坤", "西南方", "土", "母亲/女主人", "脾胃、腹部、妇科健康", "主卧、衣帽间、储蓄库房", "忌设污秽卫浴(里鬼门)、忌杂乱", "坤为地，厚德载物。西南方为坤母至尊之地，承载一家包容与家庭和睦，宜整洁平整温润。"),
        ("兑", "正西方", "金", "少女/幼女", "口齿、咽喉、肺部呼吸", "餐厅、影音娱乐室、客卧", "忌炉灶烈火克金、忌尖角冲射", "兑为泽，喜悦言谈。正西方主饮食喜庆与口才技艺，宜雅致温馨，忌见凶煞尖角。")
    ]
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<palaces.count, id: \.self) { idx in
                        let p = palaces[idx]
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("【\(p.gua)卦 · \(p.dir)】")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                                    Text(p.elem)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(0.12))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                Spacer()
                                Text("对应人丁：\(p.member)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Text(p.desc)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(3)
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("✅ 宜设空间:")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.green)
                                    Text(p.bestRoom)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("❌ 严忌布局:")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.red)
                                    Text(p.taboo)
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(6)
                        }
                        .padding(12)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
            .navigationBarTitle("居家风水八方布局全鉴", displayMode: .inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
