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
    
    @Published public var showDegreeTicks: Bool = true
    @Published public var showSolarTerms: Bool = true
    @Published public var showHexagrams64: Bool = true
    @Published public var showFenjin120: Bool = true
    @Published public var showMountain24: Bool = true
    @Published public var showEightGua: Bool = true
    @Published public var showTrueNorthNeedle: Bool = true
    @Published public var showLevelBubble: Bool = true
    @Published public var currentPreset: CompassPreset = .comprehensive
    
    private init() {}
    
    public func applyPreset(_ preset: CompassPreset) {
        currentPreset = preset
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
