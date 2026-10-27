import Foundation
import Combine

// MARK: - 演象·时空罗盘 原生国际化多语言管理器 (LocalizationManager)
// 支持：zh-Hans (简体中文), zh-Hant (繁體中文), en (English), auto (跟随系统)

public enum AppLanguage: String, CaseIterable, Identifiable {
    case auto = "auto"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en = "en"
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .auto: return "跟随系统 (Auto)"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        }
    }
}

public class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    @Published public var currentSetting: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentSetting.rawValue, forKey: "app_language")
            updateEffectiveLanguage()
        }
    }
    
    @Published public var effectiveLanguage: AppLanguage = .zhHans
    
    private let kAppLanguageKey = "app_language"
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: kAppLanguageKey) ?? "auto"
        let setting = AppLanguage(rawValue: saved) ?? .auto
        self.currentSetting = setting
        self.effectiveLanguage = LocalizationManager.resolveLanguage(for: setting)
    }
    
    public func setLanguage(_ lang: AppLanguage) {
        currentSetting = lang
    }
    
    private static func resolveLanguage(for setting: AppLanguage) -> AppLanguage {
        if setting == .auto {
            let pref = Locale.preferredLanguages.first ?? "zh-Hans"
            let lower = pref.lowercased()
            if lower.contains("hant") || lower.contains("tw") || lower.contains("hk") || lower.contains("mo") {
                return .zhHant
            } else if lower.starts(with: "zh") {
                return .zhHans
            } else {
                return .en
            }
        }
        return setting
    }
    
    private func updateEffectiveLanguage() {
        let resolved = LocalizationManager.resolveLanguage(for: currentSetting)
        if effectiveLanguage != resolved {
            effectiveLanguage = resolved
        }
    }
    
    // MARK: - 字符串本地化快速查询
    public func t(_ key: String) -> String {
        return localizedStrings[effectiveLanguage]?[key] ?? localizedStrings[.zhHans]?[key] ?? key
    }
    
    private let localizedStrings: [AppLanguage: [String: String]] = [
        .zhHans: [
            // Tab 栏
            "tab_compass": "时空罗盘",
            "tab_ar": "全景形煞",
            "tab_floorplan": "户型立极",
            "tab_analysis": "玄空理气",
            "tab_settings": "大师会员",
            
            // 罗盘与工具
            "compass_title": "演象 · 时空罗盘",
            "lock_heading": "锁定朝向",
            "locked_heading": "已锁定朝向",
            "layers_settings": "图层管理",
            "compass_calib": "罗盘双针校准",
            "pure_alignment": "正针纯清",
            "sub_mountain": "兼针替卦",
            "small_void": "差错小空亡",
            "big_void": "出卦大空亡",
            "jewel_line": "旺相珠宝",
            "fire_pit": "孤虚火坑",
            "fenjin_120": "一百二十分金",
            "true_solar_time": "真太阳时",
            "gps_coords": "GPS 实时经纬坐标",
            "calib_accuracy": "地磁精度与校准",
            "mag_distortion": "磁场干扰状态",
            "haptic_feedback": "二十四山过界微触觉震感",
            
            // 理气分析
            "xuankong_stars": "玄空九星",
            "bazhai_sanhe": "八宅三合",
            "purple_white": "紫白客星",
            "qimen_dunjia": "时家奇门",
            "tianji_scroll": "福宅天机长卷",
            "period_selection": "元运选择",
            "current_period_9": "当前下元九运 (2024-2043)",
            "sitting_facing": "坐向分析",
            
            // 户型空间
            "floorplan_title": "户型空间立极 · 全屋体检",
            "import_plan": "导入图纸",
            "change_plan": "更换图纸",
            "reset_sample": "重置示例",
            "audit_checklist": "全屋风水格局体检清单",
            "room_details": "功能区诊断报告",
            
            // AR 实景
            "ar_title": "AR 实景天心透视与形煞智能研判",
            "capture_proof": "存证快照",
            "remedy_guide": "化解锦囊",
            "simulation_mode": "室内 / 模拟实景演练模式",
            "sha_report": "形煞诊断报告",
            
            // 会员与设置
            "vip_member_center": "演象·时空罗盘 会员中心",
            "vip_user": "VIP 尊享用户",
            "standard_user": "标准用户",
            "restore_purchases": "恢复已有购买 (Restore Purchases)",
            "app_language": "界面语言 (Language)",
            "done": "完成",
            "close": "关闭",
            "pay_securely": "Apple Pay 一键开通所选服务"
        ],
        .zhHant: [
            // Tab 欄
            "tab_compass": "時空羅盤",
            "tab_ar": "全景形煞",
            "tab_floorplan": "戶型立極",
            "tab_analysis": "玄空理氣",
            "tab_settings": "大師會員",
            
            // 羅盤與工具
            "compass_title": "演象 · 時空羅盤",
            "lock_heading": "鎖定朝向",
            "locked_heading": "已鎖定朝向",
            "layers_settings": "圖層管理",
            "compass_calib": "羅盤雙針校準",
            "pure_alignment": "正針純清",
            "sub_mountain": "兼針替卦",
            "small_void": "差錯小空亡",
            "big_void": "出卦大空亡",
            "jewel_line": "旺相珠寶",
            "fire_pit": "孤虛火坑",
            "fenjin_120": "一百二十分金",
            "true_solar_time": "真太陽時",
            "gps_coords": "GPS 實時經緯坐標",
            "calib_accuracy": "地磁精度與校準",
            "mag_distortion": "磁場干擾狀態",
            "haptic_feedback": "二十四山過界微觸覺震感",
            
            // 理氣分析
            "xuankong_stars": "玄空九星",
            "bazhai_sanhe": "八宅三合",
            "purple_white": "紫白客星",
            "qimen_dunjia": "時家奇門",
            "tianji_scroll": "福宅天機長卷",
            "period_selection": "元運選擇",
            "current_period_9": "當前下元九運 (2024-2043)",
            "sitting_facing": "坐向分析",
            
            // 戶型空間
            "floorplan_title": "戶型空間立極 · 全屋體檢",
            "import_plan": "導入圖紙",
            "change_plan": "更換圖紙",
            "reset_sample": "重置示例",
            "audit_checklist": "全屋風水格局體檢清單",
            "room_details": "功能區診斷報告",
            
            // AR 實景
            "ar_title": "AR 實景天心透視與形煞智能研判",
            "capture_proof": "存證快照",
            "remedy_guide": "化解錦囊",
            "simulation_mode": "室內 / 模擬實景演練模式",
            "sha_report": "形煞診斷報告",
            
            // 會員與設置
            "vip_member_center": "演象·時空羅盤 會員中心",
            "vip_user": "VIP 尊享用戶",
            "standard_user": "標準用戶",
            "restore_purchases": "恢復已有購買 (Restore Purchases)",
            "app_language": "界面語言 (Language)",
            "done": "完成",
            "close": "關閉",
            "pay_securely": "Apple Pay 一鍵開通所選服務"
        ],
        .en: [
            // Tab Bar
            "tab_compass": "Compass",
            "tab_ar": "AR Vision",
            "tab_floorplan": "Floor Plan",
            "tab_analysis": "Feng Shui",
            "tab_settings": "Settings",
            
            // Compass & Tools
            "compass_title": "YanXiang Compass",
            "lock_heading": "Lock Heading",
            "locked_heading": "Heading Locked",
            "layers_settings": "Layers",
            "compass_calib": "Calibration",
            "pure_alignment": "Pure Line",
            "sub_mountain": "Sub-Mountain",
            "small_void": "Small Void Line",
            "big_void": "Great Void Line",
            "jewel_line": "Jewel Line (Auspicious)",
            "fire_pit": "Fire Pit (Inauspicious)",
            "fenjin_120": "120 Fenjin",
            "true_solar_time": "True Solar Time",
            "gps_coords": "GPS Coordinates",
            "calib_accuracy": "Sensor Accuracy",
            "mag_distortion": "Magnetic Interference",
            "haptic_feedback": "Boundary Haptic Feedback",
            
            // Feng Shui Analysis
            "xuankong_stars": "Flying Stars",
            "bazhai_sanhe": "8 Mansions & Water",
            "purple_white": "Purple-White Stars",
            "qimen_dunjia": "QiMen DunJia",
            "tianji_scroll": "Celestial Scroll",
            "period_selection": "Period Selection",
            "current_period_9": "Current Period 9 (2024-2043)",
            "sitting_facing": "Sitting & Facing",
            
            // Floor Plan
            "floorplan_title": "Floor Plan Spatial Audit",
            "import_plan": "Import Plan",
            "change_plan": "Change Plan",
            "reset_sample": "Reset Sample",
            "audit_checklist": "Comprehensive Audit Checklist",
            "room_details": "Room Diagnostic Report",
            
            // AR Vision
            "ar_title": "AR Spatial & Exterior Sha Analysis",
            "capture_proof": "Capture Proof",
            "remedy_guide": "Remedy Guide",
            "simulation_mode": "Indoor Simulation Mode",
            "sha_report": "Sha Diagnostic Report",
            
            // Membership & Settings
            "vip_member_center": "YanXiang VIP Sanctuary",
            "vip_user": "VIP Member",
            "standard_user": "Standard User",
            "restore_purchases": "Restore Purchases",
            "app_language": "App Language",
            "done": "Done",
            "close": "Close",
            "pay_securely": "Pay with Apple Pay"
        ]
    ]
}
