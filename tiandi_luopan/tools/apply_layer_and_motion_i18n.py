# -*- coding: utf-8 -*-
"""
Update LocalizationManager, CompassLayerManager, LayerSettingsSheet, CompassMotionManager, and package_ipa.
"""
import os

BASE_DIR = r"e:\code\android\tiandi_luopan\ios\TiandiLuopan"
LOC_MGR_PATH = os.path.join(BASE_DIR, "Models", "LocalizationManager.swift")
LAYER_MGR_PATH = os.path.join(BASE_DIR, "Models", "CompassLayerManager.swift")
LAYER_SHEET_PATH = os.path.join(BASE_DIR, "Views", "Compass", "LayerSettingsSheet.swift")
MOTION_MGR_PATH = os.path.join(BASE_DIR, "CompassMotionManager.swift")
PACKAGE_IPA_PATH = r"e:\code\android\tiandi_luopan\tools\package_ipa.py"

def update_localization_manager():
    with open(LOC_MGR_PATH, "r", encoding="utf-8") as f:
        c = f.read().replace("\r\n", "\n")

    if '"preset_comprehensive"' in c:
        print("LocalizationManager already has preset keys.")
        return

    hans = """            "preset_comprehensive": "综合全息盘",
            "preset_sanyuan": "三元玄空盘",
            "preset_sanhe": "三合水法盘",
            "preset_minimalist": "极简勘测盘",
            "altitude_label": "海拔",
            "solar_eq_time": "均时差",
            "minute_unit": "分",
            "solar_calib_title": "真太阳时校准",
"""

    hant = """            "preset_comprehensive": "綜合全息盤",
            "preset_sanyuan": "三元玄空盤",
            "preset_sanhe": "三合水法盤",
            "preset_minimalist": "極簡勘測盤",
            "altitude_label": "海拔",
            "solar_eq_time": "均時差",
            "minute_unit": "分",
            "solar_calib_title": "真太陽時校準",
"""

    en = """            "preset_comprehensive": "Comprehensive Holographic",
            "preset_sanyuan": "SanYuan XuanKong",
            "preset_sanhe": "SanHe Water Method",
            "preset_minimalist": "Minimalist Survey",
            "altitude_label": "Alt",
            "solar_eq_time": "Eq of Time",
            "minute_unit": "m",
            "solar_calib_title": "True Solar Time Calibrated",
"""

    pos_hant = c.find(".zhHant: [")
    if pos_hant != -1:
        close_hans = c.rfind("],", 0, pos_hant)
        if close_hans != -1:
            c = c[:close_hans] + hans + c[close_hans:]

    pos_en = c.find(".en: [")
    if pos_en != -1:
        close_hant = c.rfind("],", 0, pos_en)
        if close_hant != -1:
            c = c[:close_hant] + hant + c[close_hant:]

    close_en = c.rfind("]")
    if close_en != -1:
        close_dict = c.rfind("]", 0, close_en)
        if close_dict != -1:
            c = c[:close_dict] + en + c[close_dict:]

    with open(LOC_MGR_PATH, "w", encoding="utf-8") as f:
        f.write(c)
    print("Updated LocalizationManager with preset and motion keys.")

def update_layer_manager():
    with open(LAYER_MGR_PATH, "r", encoding="utf-8") as f:
        c = f.read()

    if "localizedTitle" in c:
        print("CompassLayerManager already has localizedTitle.")
        return

    old_enum = """public enum CompassPreset: String, CaseIterable, Identifiable {
    case comprehensive = "综合全息盘"
    case sanYuan = "三元玄空盘"
    case sanHe = "三合水法盘"
    case minimalist = "极简勘测盘"
    
    public var id: String { self.rawValue }
}"""

    new_enum = """public enum CompassPreset: String, CaseIterable, Identifiable {
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
}"""
    c = c.replace(old_enum, new_enum)
    with open(LAYER_MGR_PATH, "w", encoding="utf-8") as f:
        f.write(c)
    print("Updated CompassLayerManager.swift.")

def update_layer_sheet():
    with open(LAYER_SHEET_PATH, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace("Text(preset.rawValue)", "Text(preset.localizedTitle)")
    with open(LAYER_SHEET_PATH, "w", encoding="utf-8") as f:
        f.write(c)
    print("Updated LayerSettingsSheet.swift.")

def update_motion_manager():
    with open(MOTION_MGR_PATH, "r", encoding="utf-8") as f:
        c = f.read()

    # coordsDesc
    c = c.replace(
        '@Published public var coordsDesc: String = "39.90420°N, 116.40740°E · 海拔 45m"',
        '@Published public var coordsDesc: String = "39.90420°N, 116.40740°E · 45m"'
    )
    c = c.replace(
        'let altStr = String(format: " · 海拔 %.0fm", loc.altitude)',
        'let altStr = " · " + LocalizationManager.shared.t("altitude_label") + String(format: " %.0fm", loc.altitude)'
    )

    # solarTimeDesc
    c = c.replace(
        '@Published public var solarTimeDesc: String = "真太阳时校准 · 均时差 +0.0分"',
        '@Published public var solarTimeDesc: String = "12:00:00"'
    )
    c = c.replace(
        'self.solarTimeDesc = "\(solarResult.baziGanzhi) (均时差 \(offsetSign)\(String(format: "%.1f", solarResult.timeOffsetMinutes))分)"',
        'let eqLabel = LocalizationManager.shared.t("solar_eq_time"); let minUnit = LocalizationManager.shared.t("minute_unit"); self.solarTimeDesc = "\(solarResult.baziGanzhi) (\(eqLabel) \(offsetSign)\(String(format: "%.1f", solarResult.timeOffsetMinutes))\(minUnit))"'
    )

    with open(MOTION_MGR_PATH, "w", encoding="utf-8") as f:
        f.write(c)
    print("Updated CompassMotionManager.swift.")

def update_package_ipa():
    with open(PACKAGE_IPA_PATH, "r", encoding="utf-8") as f:
        c = f.read()

    if "lproj" in c:
        print("package_ipa already copies lproj.")
        return

    insert_point = "    # 5. Copy icons from AppIcon.appiconset"
    lproj_copy = """    # 4.5 Copy localized resources (*.lproj)
    src_tiandi = os.path.join(root_dir, "ios/TiandiLuopan")
    for item in os.listdir(src_tiandi):
        if item.endswith(".lproj"):
            src_lp = os.path.join(src_tiandi, item)
            dest_lp = os.path.join(app_dir, item)
            if os.path.isdir(src_lp):
                shutil.copytree(src_lp, dest_lp, dirs_exist_ok=True)

    # 5. Copy icons from AppIcon.appiconset"""
    c = c.replace(insert_point, lproj_copy)

    with open(PACKAGE_IPA_PATH, "w", encoding="utf-8") as f:
        f.write(c)
    print("Updated package_ipa.py.")

if __name__ == "__main__":
    update_localization_manager()
    update_layer_manager()
    update_layer_sheet()
    update_motion_manager()
    update_package_ipa()
