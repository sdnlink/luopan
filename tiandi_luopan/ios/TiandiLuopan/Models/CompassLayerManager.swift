import Foundation
import Combine

// MARK: - 罗盘图层管理与流派预设管理器 (Compass Layer Manager - PRD 7.1)

public enum CompassPreset: String, CaseIterable, Identifiable {
    case comprehensive = "综合全息盘"
    case sanYuan = "三元玄空盘"
    case sanHe = "三合水法盘"
    case minimalist = "极简勘测盘"
    
    public var id: String { self.rawValue }
    
    public var localizedTitle: String {
        switch self {
        case .comprehensive: return LocalizationManager.shared.t("preset_comprehensive")
        case .sanYuan: return LocalizationManager.shared.t("preset_sanyuan")
        case .sanHe: return LocalizationManager.shared.t("preset_sanhe")
        case .minimalist: return LocalizationManager.shared.t("preset_minimalist")
        }
    }
}

public class CompassLayerManager: ObservableObject {
    public static let shared = CompassLayerManager()

    private static let defaults = UserDefaults.standard
    private static func storedBool(_ key: String, default value: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? value
    }

    @Published public var showDegreeTicks: Bool = CompassLayerManager.storedBool("compass_layer_degree_ticks", default: true) {
        didSet { Self.defaults.set(showDegreeTicks, forKey: "compass_layer_degree_ticks") }
    }
    @Published public var showSolarTerms: Bool = CompassLayerManager.storedBool("compass_layer_solar_terms", default: true) {
        didSet { Self.defaults.set(showSolarTerms, forKey: "compass_layer_solar_terms") }
    }
    @Published public var showHexagrams64: Bool = CompassLayerManager.storedBool("compass_layer_hexagrams64", default: true) {
        didSet { Self.defaults.set(showHexagrams64, forKey: "compass_layer_hexagrams64") }
    }
    @Published public var showFenjin120: Bool = CompassLayerManager.storedBool("compass_layer_fenjin120", default: true) {
        didSet { Self.defaults.set(showFenjin120, forKey: "compass_layer_fenjin120") }
    }
    @Published public var showMountain24: Bool = CompassLayerManager.storedBool("compass_layer_mountain24", default: true) {
        didSet { Self.defaults.set(showMountain24, forKey: "compass_layer_mountain24") }
    }
    @Published public var showEightGua: Bool = CompassLayerManager.storedBool("compass_layer_eight_gua", default: true) {
        didSet { Self.defaults.set(showEightGua, forKey: "compass_layer_eight_gua") }
    }
    @Published public var showTrueNorthNeedle: Bool = CompassLayerManager.storedBool("compass_layer_true_north", default: true) {
        didSet { Self.defaults.set(showTrueNorthNeedle, forKey: "compass_layer_true_north") }
    }
    @Published public var showLevelBubble: Bool = CompassLayerManager.storedBool("compass_layer_level_bubble", default: true) {
        didSet { Self.defaults.set(showLevelBubble, forKey: "compass_layer_level_bubble") }
    }
    @Published public var currentPreset: CompassPreset = {
        guard let raw = CompassLayerManager.defaults.string(forKey: "compass_layer_preset"),
              let preset = CompassPreset(rawValue: raw) else { return .comprehensive }
        return preset
    }()

    /// Manual switches can make the saved preset name stale. Resolve the
    /// visible selection from the actual flags so the sheet never claims a
    /// preset is active after the user customized one or more layers.
    public var activePreset: CompassPreset? {
        CompassPreset.allCases.first { preset in
            switch preset {
            case .comprehensive:
                return showDegreeTicks && showSolarTerms && showHexagrams64 && showFenjin120 && showMountain24 && showEightGua && showTrueNorthNeedle && showLevelBubble
            case .sanYuan:
                return showDegreeTicks && !showSolarTerms && showHexagrams64 && showFenjin120 && showMountain24 && showEightGua && showTrueNorthNeedle && showLevelBubble
            case .sanHe:
                return showDegreeTicks && showSolarTerms && !showHexagrams64 && showFenjin120 && showMountain24 && showEightGua && showTrueNorthNeedle && showLevelBubble
            case .minimalist:
                return showDegreeTicks && !showSolarTerms && !showHexagrams64 && !showFenjin120 && showMountain24 && showEightGua && showTrueNorthNeedle && showLevelBubble
            }
        }
    }
    
    private init() {}
    
    public func applyPreset(_ preset: CompassPreset) {
        currentPreset = preset
        Self.defaults.set(preset.rawValue, forKey: "compass_layer_preset")
        switch preset {
        case .comprehensive:
            showDegreeTicks = true
            showSolarTerms = true
            showHexagrams64 = true
            showFenjin120 = true
            showMountain24 = true
            showEightGua = true
            showTrueNorthNeedle = true
            showLevelBubble = true
        case .sanYuan:
            showDegreeTicks = true
            showSolarTerms = false
            showHexagrams64 = true
            showFenjin120 = true
            showMountain24 = true
            showEightGua = true
            showTrueNorthNeedle = true
            showLevelBubble = true
        case .sanHe:
            showDegreeTicks = true
            showSolarTerms = true
            showHexagrams64 = false
            showFenjin120 = true
            showMountain24 = true
            showEightGua = true
            showTrueNorthNeedle = true
            showLevelBubble = true
        case .minimalist:
            showDegreeTicks = true
            showSolarTerms = false
            showHexagrams64 = false
            showFenjin120 = false
            showMountain24 = true
            showEightGua = true
            showTrueNorthNeedle = true
            showLevelBubble = true
        }
    }
}
