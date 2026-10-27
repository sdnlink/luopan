# -*- coding: utf-8 -*-
"""
Localize all remaining strings across iOS SwiftUI views and update LocalizationManager.
"""
import os
import re

BASE_DIR = r"e:\code\android\tiandi_luopan\ios\TiandiLuopan"
LOC_MGR_PATH = os.path.join(BASE_DIR, "Models", "LocalizationManager.swift")

# 1. Update LocalizationManager.swift with extra translation keys
def update_loc_manager():
    with open(LOC_MGR_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    hans_extra = """            "mag_warning_tap": "监测到环境强磁干扰",
            "tap_to_calib": "点击校准",
            "btn_calib": "校准",
            "btn_layers": "图层",
            "btn_palace_all": "八方全鉴",
            "btn_fenjin_detail": "分金详勘",
            "mountain_suffix": "山",
            "facing_suffix": "向",
            "palace_suffix": "宫",
            "true_solar_time_prefix": "真太阳时",
            "pitch_label": "俯仰",
            "roll_label": "横滚",
            "tianji_rendering": "正统古法宣纸长卷渲染中...",
            "tianji_vip_preview_watermark": "演象·天机秘卷 VIP专享预览",
            "tianji_vip_card_title": "宣纸长卷高清导出 · VIP 专享",
            "tianji_vip_card_desc": "一键汇总实测坐向、玄空飞星、八路黄泉、时家奇门与八宅命卦，出具古典宣纸朱丝栏大师全案无水印长卷。",
            "tianji_vip_badge": "👑 VIP / 单次 ¥9.9",
            "xuankong_period_unit": "运",
            "xuankong_integrated_title": "集成坐向立极、玄空九星、八路黄泉与奇门命卦",
            "xuankong_deep_analysis": "📜 格局深研分析",
            "xuankong_wealth_advice": "• 旺财布局：向星当令之方宜开门见水，动水催财；",
            "xuankong_health_advice": "• 旺丁布局：山星当令之方宜设主卧、安床有靠；",
            "xuankong_remedy_advice": "• 二五化煞：二黑五黄交叠之宫位，悬挂六帝钱以金泄土。",
            "tag_month_prefix": "月",
            "true_north_short": "真",
            "floorplan_current_facing": "当前立向: ",
            "floorplan_severe_sha": "严重煞气",
            "floorplan_warn_sha": "预警",
"""

    hant_extra = """            "mag_warning_tap": "監測到環境強磁干擾",
            "tap_to_calib": "點擊校準",
            "btn_calib": "校準",
            "btn_layers": "圖層",
            "btn_palace_all": "八方全鑑",
            "btn_fenjin_detail": "分金詳勘",
            "mountain_suffix": "山",
            "facing_suffix": "向",
            "palace_suffix": "宮",
            "true_solar_time_prefix": "真太陽時",
            "pitch_label": "俯仰",
            "roll_label": "橫滾",
            "tianji_rendering": "正統古法宣紙長卷渲染中...",
            "tianji_vip_preview_watermark": "演象·天機秘卷 VIP專享預覽",
            "tianji_vip_card_title": "宣紙長卷高清導出 · VIP 專享",
            "tianji_vip_card_desc": "一鍵匯總實測坐向、玄空飛星、八路黃泉、時家奇門與八宅命卦，出具古典宣紙朱絲欄大師全案無水印長卷。",
            "tianji_vip_badge": "👑 VIP / 單次 ¥9.9",
            "xuankong_period_unit": "運",
            "xuankong_integrated_title": "集成坐向立極、玄空九星、八路黃泉與奇門命卦",
            "xuankong_deep_analysis": "📜 格局深研分析",
            "xuankong_wealth_advice": "• 旺財布局：向星當令之方宜開門見水，動水催財；",
            "xuankong_health_advice": "• 旺丁布局：山星當令之方宜設主臥、安床有靠；",
            "xuankong_remedy_advice": "• 二五化煞：二黑五黃交疊之宮位，懸掛六帝錢以金洩土。",
            "tag_month_prefix": "月",
            "true_north_short": "真",
            "floorplan_current_facing": "當前立向: ",
            "floorplan_severe_sha": "嚴重煞氣",
            "floorplan_warn_sha": "預警",
"""

    en_extra = """            "mag_warning_tap": "Strong magnetic interference detected",
            "tap_to_calib": "Tap to calibrate",
            "btn_calib": "Calibrate",
            "btn_layers": "Layers",
            "btn_palace_all": "8 Palaces",
            "btn_fenjin_detail": "Fenjin",
            "mountain_suffix": " Mtn",
            "facing_suffix": " Facing",
            "palace_suffix": " Palace",
            "true_solar_time_prefix": "True Solar Time",
            "pitch_label": "Pitch",
            "roll_label": "Roll",
            "tianji_rendering": "Rendering Classical Rice Paper Scroll...",
            "tianji_vip_preview_watermark": "YanXiang TianJi Secret VIP Preview",
            "tianji_vip_card_title": "Classical Scroll HD Export · VIP Exclusive",
            "tianji_vip_card_desc": "Export a comprehensive unwatermarked classical scroll detailing sitting/facing, 9 Flying Stars, HuangQuan Water, QiMen, and 8 Mansions.",
            "tianji_vip_badge": "👑 VIP / $1.99 Once",
            "xuankong_period_unit": " Period",
            "xuankong_integrated_title": "Integrated Orientation, Flying Stars, HuangQuan & QiMen",
            "xuankong_deep_analysis": "📜 Deep Analysis of Configuration",
            "xuankong_wealth_advice": "• Wealth Layout: Facing star in power favors door or dynamic water;",
            "xuankong_health_advice": "• Health Layout: Sitting star in power favors master bedroom and backed bed;",
            "xuankong_remedy_advice": "• Remedy 2-5: Palace with 2-Black/5-Yellow requires metal coins to dissipate earth sha.",
            "tag_month_prefix": "M",
            "true_north_short": "T",
            "floorplan_current_facing": "Current Orientation: ",
            "floorplan_severe_sha": "Severe Sha",
            "floorplan_warn_sha": "Warning",
"""

    if '"mag_warning_tap"' not in content:
        content = content.replace('"grade_great_inauspicious": "大凶",\n        ],', '"grade_great_inauspicious": "大凶",\n' + hans_extra + '        ],', 1)
        content = content.replace('"grade_great_inauspicious": "大凶",\n        ],', '"grade_great_inauspicious": "大凶",\n' + hant_extra + '        ],', 1)
        content = content.replace('"grade_great_inauspicious": "Great Inauspicious",\n        ]', '"grade_great_inauspicious": "Great Inauspicious",\n' + en_extra + '        ]', 1)
        with open(LOC_MGR_PATH, "w", encoding="utf-8") as f:
            f.write(content)
        print("Updated LocalizationManager.swift with extra keys.")
    else:
        print("LocalizationManager.swift already has extra keys.")

if __name__ == "__main__":
    update_loc_manager()
