import re

path = r"e:\code\android\tiandi_luopan\ios\TiandiLuopan\Models\LocalizationManager.swift"

new_keys_zhHans = {
    # AR 实景与形煞
    "ar_drag_hint": "拖动金黄色锁定框可模拟测煞",
    "ar_target_center": "AI 测煞靶心",
    "ar_target_bearing": "靶向方位",
    "ar_physical_facing": "物理向首",
    "ar_sha_analysis_prefix": "形煞研判",
    "ar_watermark_title": "演象时空罗盘 · AR实地勘测全案存证",
    "ar_watermark_stamp": "演象\n鉴真",
    "ar_env_features": "📐 现场环境辨识特征",
    "ar_classic_lore": "📜 经典古籍赋文",
    "ar_remedy_title": "🛡️ 开光法器与空间调理化解锦囊",
    "ar_vip_remedy_title": "杨公化煞绝学锦囊 · VIP 专享",
    "ar_vip_remedy_desc": "形峦煞气本物相克生克制化真传、开光法器安放禁忌、鲁班真尺定寸与镇煞秘方，需解锁 VIP 尊享特权。",

    # 天机宣纸长卷
    "tianji_rendering": "正统古法宣纸长卷渲染中...",
    "tianji_vip_preview_watermark": "演象·天机秘卷 VIP专享预览",
    "tianji_vip_card_title": "宣纸长卷高清导出 · VIP 专享",
    "tianji_vip_card_desc": "一键汇总实测坐向、玄空飞星、八路黄泉、时家奇门与八宅命卦，出具古典宣纸朱丝栏大师全案无水印长卷。",
    "tianji_vip_badge": "👑 VIP / 单次 ¥9.9",

    # 罗盘主屏与头部
    "mag_warning_tap": "监测到环境强磁干扰 · 点击校准",
    "header_sitting_facing": "坐向",
    "header_palace_suffix": "宫",
    "header_pitch_roll": "俯仰 / 横滚",
    "btn_palace_all": "八方全鉴",
    "btn_fenjin_detail": "分金详勘",
    "btn_calib": "校准",
    "btn_layers": "图层",

    # 玄空与理气深度分析
    "xuankong_deep_analysis": "📜 格局深研分析",
    "xuankong_wealth_advice": "• 旺财布局：向星当令之方宜开门见水，动水催财；",
    "xuankong_health_advice": "• 旺丁布局：山星当令之方宜设主卧、安床有靠；",
    "xuankong_remedy_advice": "• 二五化煞：二黑五黄交叠之宫位，悬挂六帝钱以金泄土。",
    "period_unit": "运",

    # 八宅日课与水法
    "gate_facing_prefix": "向首开门方",
    "na_qi_prefix": "纳",
    "zeri_title": "天星择日 · 动土安门日课自检",
    "current_four_pillars": "当前四柱",
    "auspicious_fit": "宜",
    "inauspicious_avoid": "忌",
    "yang_gong_water_title": "杨公形气 · 八路黄泉水法",
    "song_quote": "歌诀",
    "sitting_mountain_clash": "坐山曜煞 · 凶砂辨识与消纳",
    "clash_at": "煞在",
    "water_rule_12": "十二长生水法考量",
    "water_rule_desc": "生水旺水宜来流聚，死绝之气宜引出化煞",
    "huangquan_sha": "黄泉煞",

    # 奇门出行与吉凶
    "qimen_travel_best": "实地踏勘与出行吉方",
    "qimen_pattern_best": "玉女反闭局合德",
    "qimen_best_nav": "• 最佳动身方：大旺",
    "qimen_taboo_nav": "• 避忌凶方：逢",
    "qimen_taboo_suffix": "防阻滞惊恐，踏勘宜避开对冲。",
    "grade_auspicious": "吉",
    "grade_great_auspicious": "大吉",
    "grade_inauspicious": "凶",
    "grade_great_inauspicious": "大凶"
}

new_keys_zhHant = {
    # AR 实景与形煞
    "ar_drag_hint": "拖動金黃色鎖定框可模擬測煞",
    "ar_target_center": "AI 測煞靶心",
    "ar_target_bearing": "靶向方位",
    "ar_physical_facing": "物理向首",
    "ar_sha_analysis_prefix": "形煞研判",
    "ar_watermark_title": "演象時空羅盤 · AR實地勘測全案存證",
    "ar_watermark_stamp": "演象\n鑑真",
    "ar_env_features": "📐 現場環境辨識特徵",
    "ar_classic_lore": "📜 經典古籍賦文",
    "ar_remedy_title": "🛡️ 開光法器與空間調理化解錦囊",
    "ar_vip_remedy_title": "楊公化煞絕學錦囊 · VIP 專享",
    "ar_vip_remedy_desc": "形巒煞氣本物相剋生剋制化真傳、開光法器安放禁忌、魯班真尺定寸與鎮煞秘方，需解鎖 VIP 尊享特權。",

    # 天机宣纸长卷
    "tianji_rendering": "正統古法宣紙長卷渲染中...",
    "tianji_vip_preview_watermark": "演象·天機秘卷 VIP專享預覽",
    "tianji_vip_card_title": "宣紙長卷高清導出 · VIP 專享",
    "tianji_vip_card_desc": "一鍵匯總實測坐向、玄空飛星、八路黃泉、時家奇門與八宅命卦，出具古典宣紙朱絲欄大師全案無水印長卷。",
    "tianji_vip_badge": "👑 VIP / 單次 ¥9.9",

    # 罗盘主屏与头部
    "mag_warning_tap": "監測到環境強磁干擾 · 點擊校準",
    "header_sitting_facing": "坐向",
    "header_palace_suffix": "宮",
    "header_pitch_roll": "俯仰 / 橫滾",
    "btn_palace_all": "八方全鑑",
    "btn_fenjin_detail": "分金詳勘",
    "btn_calib": "校準",
    "btn_layers": "圖層",

    # 玄空与理气深度分析
    "xuankong_deep_analysis": "📜 格局深研分析",
    "xuankong_wealth_advice": "• 旺財布局：向星當令之方宜開門見水，動水催財；",
    "xuankong_health_advice": "• 旺丁布局：山星當令之方宜設主臥、安床有靠；",
    "xuankong_remedy_advice": "• 二五化煞：二黑五黃交疊之宮位，懸掛六帝錢以金洩土。",
    "period_unit": "運",

    # 八宅日课与水法
    "gate_facing_prefix": "向首開門方",
    "na_qi_prefix": "納",
    "zeri_title": "天星擇日 · 動土安門日課自檢",
    "current_four_pillars": "當前四柱",
    "auspicious_fit": "宜",
    "inauspicious_avoid": "忌",
    "yang_gong_water_title": "楊公形氣 · 八路黃泉水法",
    "song_quote": "歌訣",
    "sitting_mountain_clash": "坐山曜煞 · 凶砂辨識與消納",
    "clash_at": "煞在",
    "water_rule_12": "十二長生水法考量",
    "water_rule_desc": "生水旺水宜來流聚，死絕之氣宜引出化煞",
    "huangquan_sha": "黃泉煞",

    # 奇门出行与吉凶
    "qimen_travel_best": "實地踏勘與出行吉方",
    "qimen_pattern_best": "玉女反閉局合德",
    "qimen_best_nav": "• 最佳動身方：大旺",
    "qimen_taboo_nav": "• 避忌凶方：逢",
    "qimen_taboo_suffix": "防阻滯驚恐，踏勘宜避開對衝。",
    "grade_auspicious": "吉",
    "grade_great_auspicious": "大吉",
    "grade_inauspicious": "凶",
    "grade_great_inauspicious": "大凶"
}

new_keys_en = {
    # AR 实景与形煞
    "ar_drag_hint": "Drag yellow box to simulate Sha analysis",
    "ar_target_center": "AI Sha Target",
    "ar_target_bearing": "Target Bearing",
    "ar_physical_facing": "Physical Facing",
    "ar_sha_analysis_prefix": "Sha Analysis",
    "ar_watermark_title": "YanXiang Compass · AR On-Site Audit Proof",
    "ar_watermark_stamp": "YanXiang\nVerified",
    "ar_env_features": "📐 On-Site Environment Features",
    "ar_classic_lore": "📜 Classical Treatise Lore",
    "ar_remedy_title": "🛡️ Consecrated Talismans & Harmonization Guide",
    "ar_vip_remedy_title": "Yang Gong Harmonization Secrets · VIP",
    "ar_vip_remedy_desc": "Master formulas for neutralizing negative environmental energy, talisman placement, and Lu Ban sacred measurements.",

    # 天机宣纸长卷
    "tianji_rendering": "Rendering Classical Xuan Paper Scroll...",
    "tianji_vip_preview_watermark": "YanXiang Celestial Scroll VIP Preview",
    "tianji_vip_card_title": "Classical Xuan Paper Scroll Export · VIP",
    "tianji_vip_card_desc": "Comprehensive compilation of facing, Flying Stars, HuangQuan water, QiMen and 8 Mansions into an exquisite watermark-free scroll.",
    "tianji_vip_badge": "👑 VIP / Single ¥9.9",

    # 罗盘主屏与头部
    "mag_warning_tap": "Magnetic Interference Detected · Tap to Calibrate",
    "header_sitting_facing": "Sitting/Facing",
    "header_palace_suffix": "Palace",
    "header_pitch_roll": "Pitch / Roll",
    "btn_palace_all": "8 Directions",
    "btn_fenjin_detail": "Fenjin",
    "btn_calib": "Calibrate",
    "btn_layers": "Layers",

    # 玄空与理气深度分析
    "xuankong_deep_analysis": "📜 Flying Stars In-Depth Analysis",
    "xuankong_wealth_advice": "• Wealth Qi: Water at facing star palace brings financial abundance;",
    "xuankong_health_advice": "• Health & Family: Mountain star palace suitable for master bedroom & bed placement;",
    "xuankong_remedy_advice": "• 2-5 Neutralization: Hang Six Emperor coins at 2-Black/5-Yellow clash palace to disperse earth qi with metal.",
    "period_unit": "Period",

    # 八宅日课与水法
    "gate_facing_prefix": "Main Door Direction",
    "na_qi_prefix": "Qi",
    "zeri_title": "Celestial Date Selection · Date Quality Check",
    "current_four_pillars": "Current Four Pillars",
    "auspicious_fit": "Favorable",
    "inauspicious_avoid": "Avoid",
    "yang_gong_water_title": "Yang Gong Metaphysics · 8 HuangQuan Water",
    "song_quote": "Formula",
    "sitting_mountain_clash": "Sitting Mountain Clash & Harmonization",
    "clash_at": "Sha At",
    "water_rule_12": "12 ChangSheng Water Considerations",
    "water_rule_desc": "Prosperous water should flow inward; decaying water should be directed away.",
    "huangquan_sha": "HuangQuan Sha",

    # 奇门出行与吉凶
    "qimen_travel_best": "On-Site Survey & Auspicious Travel",
    "qimen_pattern_best": "Auspicious Jade Maiden Configuration",
    "qimen_best_nav": "• Best Travel Direction: Highly Favorable ",
    "qimen_taboo_nav": "• Directions to Avoid: Facing ",
    "qimen_taboo_suffix": " to prevent obstacles and conflict.",
    "grade_auspicious": "Auspicious",
    "grade_great_auspicious": "Great Auspicious",
    "grade_inauspicious": "Inauspicious",
    "grade_great_inauspicious": "Great Inauspicious"
}

with open(path, "r", encoding="utf-8") as f:
    text = f.read()

def format_dict_entries(entries):
    lines = []
    for k, v in entries.items():
        v_escaped = v.replace('"', '\\"').replace('\n', '\\n')
        lines.append(f'            "{k}": "{v_escaped}",')
    return "\n".join(lines)

text = text.replace(
    '"family_member_corresp": "对应人丁：",',
    '"family_member_corresp": "对应人丁：",\n' + format_dict_entries(new_keys_zhHans)
)

text = text.replace(
    '"family_member_corresp": "對應人丁：",',
    '"family_member_corresp": "對應人丁：",\n' + format_dict_entries(new_keys_zhHant)
)

text = text.replace(
    '"family_member_corresp": "Family Member: ",',
    '"family_member_corresp": "Family Member: ",\n' + format_dict_entries(new_keys_en)
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("Batch 2 localization keys successfully appended!")
