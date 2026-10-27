import SwiftUI

// MARK: - 罗盘圈层图层配置与预设选择弹窗 (Layer Settings Sheet)

public struct LayerSettingsSheet: View {
    @ObservedObject var layers = CompassLayerManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            List {
                // 流派预设一键切换
                Section(header: Text("易学流派盘面预设")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CompassPreset.allCases) { preset in
                                Button(action: {
                                    layers.applyPreset(preset)
                                }) {
                                    Text(preset.rawValue)
                                        .font(.system(size: 13, weight: layers.currentPreset == preset ? .bold : .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(layers.currentPreset == preset ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.white.opacity(0.08))
                                        .foregroundColor(layers.currentPreset == preset ? .black : .white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 圈层开关自定义
                Section(header: Text("罗盘同心圈层自定义显示")) {
                    Toggle("360° 外圈主刻度环", isOn: $layers.showDegreeTicks)
                    Toggle("二十四节气与十二消息卦环", isOn: $layers.showSolarTerms)
                    Toggle("先天六十四卦分金环", isOn: $layers.showHexagrams64)
                    Toggle("一百二十分金精细刻度环", isOn: $layers.showFenjin120)
                    Toggle("二十四山正针天盘环", isOn: $layers.showMountain24)
                    Toggle("先天八卦八宫内环", isOn: $layers.showEightGua)
                }
                
                // 天池仪器与指针
                Section(header: Text("天池双针与水准仪")) {
                    Toggle("地理真北金针 (根据磁偏角偏转)", isOn: $layers.showTrueNorthNeedle)
                    Toggle("天池中央电子双轴水准仪", isOn: $layers.showLevelBubble)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle(LocalizationManager.shared.t("layers_settings"), displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
