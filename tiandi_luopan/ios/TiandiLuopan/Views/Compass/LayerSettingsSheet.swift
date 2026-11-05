import SwiftUI

// MARK: - 罗盘圈层图层配置与预设选择弹窗 (Layer Settings Sheet)

public struct LayerSettingsSheet: View {
    @ObservedObject var layers = CompassLayerManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        return NavigationView {
            List {
                // 流派预设一键切换
                Section(header: Text(lang.t("preset_section_title"))) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CompassPreset.allCases) { preset in
                                Button(action: {
                                    layers.applyPreset(preset)
                                }) {
                                    Text(preset.localizedTitle)
                                        .adaptiveFont(size: 13, weight: layers.activePreset == preset ? .bold : .medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(layers.activePreset == preset ? Color(red: 0.83, green: 0.68, blue: 0.21) : Color.white.opacity(0.08))
                                        .foregroundColor(layers.activePreset == preset ? .black : .white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 圈层开关自定义
                Section(header: Text(lang.t("layers_custom_section"))) {
                    Toggle(lang.t("layer_degree_ticks"), isOn: $layers.showDegreeTicks)
                    Toggle(lang.t("layer_solar_terms"), isOn: $layers.showSolarTerms)
                    Toggle(lang.t("layer_hexagrams64"), isOn: $layers.showHexagrams64)
                    Toggle(lang.t("layer_fenjin120"), isOn: $layers.showFenjin120)
                    Toggle(lang.t("layer_mountain24"), isOn: $layers.showMountain24)
                    Toggle(lang.t("layer_eight_gua"), isOn: $layers.showEightGua)
                }
                
                // 天池仪器与指针
                Section(header: Text(lang.t("tianchi_section"))) {
                    Toggle(lang.t("layer_true_north"), isOn: $layers.showTrueNorthNeedle)
                    Toggle(lang.t("layer_level_bubble"), isOn: $layers.showLevelBubble)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle(lang.t("layers_settings"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
