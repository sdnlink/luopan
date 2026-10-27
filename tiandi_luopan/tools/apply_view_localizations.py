# -*- coding: utf-8 -*-
"""
Apply full internationalization replacements across all 11 SwiftUI view files.
"""
import os
import re

VIEWS_DIR = r"e:\code\android\tiandi_luopan\ios\TiandiLuopan\Views"

def process_tianjishu():
    path = os.path.join(VIEWS_DIR, "Analysis", "TianJiShuView.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()
    
    c = c.replace('Text("正统古法宣纸长卷渲染中...")', 'Text(lang.t("tianji_rendering"))')
    c = c.replace('Text("演象·天机秘卷 VIP专享预览")', 'Text(lang.t("tianji_vip_preview_watermark"))')
    c = c.replace('title: "宣纸长卷高清导出 · VIP 专享",', 'title: lang.t("tianji_vip_card_title"),')
    c = c.replace('featureDesc: "一键汇总实测坐向、玄空飞星、八路黄泉、时家奇门与八宅命卦，出具古典宣纸朱丝栏大师全案无水印长卷。",', 'featureDesc: lang.t("tianji_vip_card_desc"),')
    c = c.replace('badge: "👑 VIP / 单次 ¥9.9",', 'badge: lang.t("tianji_vip_badge"),')
    
    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed TianJiShuView.swift")

def process_compass_main():
    path = os.path.join(VIEWS_DIR, "Compass", "CompassMainView.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    # Warning banner
    c = re.sub(
        r'Text\("监测到环境强磁干扰 \(\\" \+ String\(format: "%\.0f", motion\.magneticStrengthUT\) \+ " μT\) · 点击校准"\)',
        'Text("\(lang.t(\\"mag_warning_tap\\")) (\(String(format: \\"%.0f\\", motion.magneticStrengthUT)) μT) · \(lang.t(\\"tap_to_calib\\"))")',
        c
    )
    # Buttons
    c = c.replace('Text("校准")', 'Text(lang.t("btn_calib"))')
    c = c.replace('Text("图层")', 'Text(lang.t("btn_layers"))')
    c = c.replace('Text("八方全鉴")', 'Text(lang.t("btn_palace_all"))')
    c = c.replace('Text("分金详勘")', 'Text(lang.t("btn_fenjin_detail"))')

    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed CompassMainView.swift")

def process_compass_header():
    path = os.path.join(VIEWS_DIR, "Compass", "CompassHeaderView.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    if "@ObservedObject var lang = LocalizationManager.shared" not in c:
        c = c.replace(
            "public struct CompassHeaderView: View {\n    @ObservedObject var motion = CompassMotionManager.shared",
            "public struct CompassHeaderView: View {\n    @ObservedObject var motion = CompassMotionManager.shared\n    @ObservedObject var lang = LocalizationManager.shared"
        )
    
    c = c.replace(
        'Text("\(state.sittingMountain.name)山\(state.facingMountain.name)向")',
        'Text("\(state.sittingMountain.name)\(lang.t("mountain_suffix"))\(state.facingMountain.name)\(lang.t("facing_suffix"))")'
    )
    c = c.replace(
        'Text(state.facingMountain.palace + "宫")',
        'Text(state.facingMountain.palace + lang.t("palace_suffix"))'
    )
    c = c.replace(
        'Text("真太阳时 \(motion.trueSolarTimeStr)")',
        'Text("\(lang.t("true_solar_time_prefix")) \(motion.trueSolarTimeStr)")'
    )
    c = re.sub(
        r'Text\("俯仰 \\\(String\(format: \\"%\.1f\\", motion\.pitch\)\)° / 横滚 \\\(String\(format: \\"%\.1f\\", motion\.roll\)\)°"\)',
        'Text("\(lang.t(\\"pitch_label\\")) \(String(format: \\"%.1f\\", motion.pitch))° / \(lang.t(\\"roll_label\\")) \(String(format: \\"%.1f\\", motion.roll))°")',
        c
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed CompassHeaderView.swift")

def process_ar_vision():
    path = os.path.join(VIEWS_DIR, "ARVision", "ARVisionView.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace(
        'Text("\(lang.t("ar_target_center")) · \(m.name)山")',
        'Text("\(lang.t("ar_target_center")) · \(m.name)\(lang.t("mountain_suffix"))")'
    )
    c = c.replace(
        'Text("\(lang.t("ar_physical_facing")): \(motion.headingState.facingMountain.name)山 (\(String(format: "%.1f", motion.headingState.facingAngle))°)")',
        'Text("\(lang.t("ar_physical_facing")): \(motion.headingState.facingMountain.name)\(lang.t("mountain_suffix")) (\(String(format: "%.1f", motion.headingState.facingAngle))°)")'
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed ARVisionView.swift")

def process_xuankong():
    path = os.path.join(VIEWS_DIR, "Analysis", "XuanKongGridView.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace(
        'Text("集成坐向立极、玄空九星、八路黄泉与奇门命卦")',
        'Text(lang.t("xuankong_integrated_title"))'
    )
    c = c.replace(
        'Text("\(p)运")',
        'Text("\(p)\(lang.t("xuankong_period_unit"))")'
    )
    c = c.replace(
        'Text("\(chart.sittingMountain)山\(chart.facingMountain)向")',
        'Text("\(chart.sittingMountain)\(lang.t("mountain_suffix"))\(chart.facingMountain)\(lang.t("facing_suffix"))")'
    )
    c = c.replace(
        'Text("📜 格局深研分析")',
        'Text(lang.t("xuankong_deep_analysis"))'
    )
    c = c.replace(
        'Text("• 旺财布局：向星当令之方宜开门见水，动水催财；")',
        'Text(lang.t("xuankong_wealth_advice"))'
    )
    c = c.replace(
        'Text("• 旺丁布局：山星当令之方宜设主卧、安床有靠；")',
        'Text(lang.t("xuankong_health_advice"))'
    )
    c = c.replace(
        'Text("• 二五化煞：二黑五黄交叠之宫位，悬挂六帝钱以金泄土。")',
        'Text(lang.t("xuankong_remedy_advice"))'
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed XuanKongGridView.swift")

def process_bazhai():
    path = os.path.join(VIEWS_DIR, "Analysis", "BaZhaiView.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace(
        'Text("向首开门方：\(bz.gateDirection)方 · 纳【\(bz.gateStar.rawValue)】")',
        'Text("\(lang.t("gate_facing_prefix"))：\(bz.gateDirection) · \(lang.t("na_qi_prefix"))【\(bz.gateStar.rawValue)】")'
    )
    c = c.replace(
        'Text("天星择日 · 动土安门日课自检")',
        'Text(lang.t("zeri_title"))'
    )
    c = c.replace(
        'Text("当前四柱：\(zeri.fourPillarsText)")',
        'Text("\(lang.t("current_four_pillars"))：\(zeri.fourPillarsText)")'
    )
    c = c.replace(
        'Text("宜")',
        'Text(lang.t("auspicious_fit"))'
    )
    c = c.replace(
        'Text("忌")',
        'Text(lang.t("inauspicious_avoid"))'
    )
    c = c.replace(
        'Text("杨公形气 · 八路黄泉水法")',
        'Text(lang.t("yang_gong_water_title"))'
    )
    c = c.replace(
        'Text("歌诀：“\(hq.quote)”")',
        'Text("\(lang.t("song_quote"))：“\(hq.quote)”")'
    )
    c = c.replace(
        'Text("坐山曜煞 · 凶砂辨识与消纳")',
        'Text(lang.t("sitting_mountain_clash"))'
    )
    c = c.replace(
        'Text("煞在【\(basha.shaDir)\(basha.shaZhi)位】")',
        'Text("\(lang.t("clash_at"))【\(basha.shaDir)\(basha.shaZhi)】")'
    )
    c = c.replace(
        'Text("口诀：“\(basha.song)”\\n法则：\(basha.xiaoShaRule)")',
        'Text("\(lang.t("song_quote"))：“\(basha.song)”\\n\(basha.xiaoShaRule)")'
    )
    c = c.replace(
        'Text("以【\(state.sittingMountain.name)山】考量十二长生水法")',
        'Text("\(lang.t("water_rule_12")): \(state.sittingMountain.name)\(lang.t("mountain_suffix"))")'
    )
    c = c.replace(
        'Text("生水旺水宜来流聚，死绝之气宜引出化煞")',
        'Text(lang.t("water_rule_desc"))'
    )
    c = c.replace(
        'Text(item.mountainName + "山")',
        'Text(item.mountainName + lang.t("mountain_suffix"))'
    )
    c = c.replace(
        'Text("黄泉煞")',
        'Text(lang.t("huangquan_sha"))'
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed BaZhaiView.swift")

def process_qimen():
    path = os.path.join(VIEWS_DIR, "Analysis", "QimenDunjiaView.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace(
        'Text("实地踏勘与出行吉方")',
        'Text(lang.t("qimen_travel_best"))'
    )
    c = c.replace(
        'Text("玉女反闭局合德")',
        'Text(lang.t("qimen_pattern_best"))'
    )
    c = c.replace(
        'Text("• 最佳动身方：大旺【\(chart.bestNavDirection)】！\(chart.bestNavReason)")',
        'Text("\(lang.t("qimen_best_nav"))【\(chart.bestNavDirection)】！\(chart.bestNavReason)")'
    )
    c = c.replace(
        'Text("• 避忌凶方：逢【\(chart.tabooDirections)】防阻滞惊恐，踏勘宜避开对冲。")',
        'Text("\(lang.t("qimen_taboo_nav"))【\(chart.tabooDirections)】\(lang.t("qimen_taboo_suffix"))")'
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed QimenDunjiaView.swift")

def process_purple_white():
    path = os.path.join(VIEWS_DIR, "Analysis", "PurpleWhiteView.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace('Text("太岁")', 'Text(lang.t("tag_taisui"))')
    c = c.replace('Text("三煞")', 'Text(lang.t("tag_sansha"))')
    c = c.replace('Text("月\(item.monthGuestStar)")', 'Text("\(lang.t("tag_month_prefix"))\(item.monthGuestStar)")')

    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed PurpleWhiteView.swift")

def process_floorplan():
    path = os.path.join(VIEWS_DIR, "Floorplan", "FloorplanView.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    c = c.replace(
        'Text("当前立向: \(String(format: "%.1f", effectiveHeading))° (\(motion.headingState.sittingMountain.name)山\(motion.headingState.facingMountain.name)向)")',
        'Text("\(lang.t("floorplan_current_facing"))\(String(format: "%.1f", effectiveHeading))° (\(motion.headingState.sittingMountain.name)\(lang.t("mountain_suffix"))\(motion.headingState.facingMountain.name)\(lang.t("facing_suffix")))")'
    )
    c = c.replace(
        'Text(item.severity)',
        'Text(item.severity == "严重煞气" ? lang.t("floorplan_severe_sha") : (item.severity == "吉" ? lang.t("grade_auspicious") : lang.t("floorplan_warn_sha")))'
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed FloorplanView.swift")

def process_compass_dial():
    path = os.path.join(VIEWS_DIR, "Compass", "CompassDialView.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    # True North indicator
    c = c.replace('Text("真")', 'Text(lang.t("true_north_short"))')

    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed CompassDialView.swift")

def process_palace_sheet():
    path = os.path.join(VIEWS_DIR, "Compass", "FengshuiPalaceDetailSheet.swift")
    with open(path, "r", encoding="utf-8") as f:
        c = f.read()

    # Replace the hardcoded static palace array with dynamic localized palace array
    old_array = """    private let palaces: [(gua: String, dir: String, elem: String, member: String, body: String, bestRoom: String, taboo: String, desc: String)] = [
        ("乾", "西北方", "金", "父亲/男主人", "头部、脑血管、骨骼", "尊贵主卧、总裁书房、高大纳气方", "忌做厨房(火烧天门)、忌污秽厕所", "乾为天，刚健笃实。家宅西北方为全屋统领之尊位，关系全家事业成就与顶梁柱健康。宜开阔厚重，忌低洼破损。"),
        ("坎", "正北方", "水", "中男/次子", "肾脏、泌尿、耳部血液", "文昌书房、静心茶室、卧室", "忌堆积杂物阴暗潮湿、忌缺角", "坎为水，深邃内敛。正北水旺利财源与智慧发皇，书房安于此方文思泉涌，科甲显名。"),
        ("艮", "东北方", "土", "少男/幼子", "脾胃、背脊、手足关节", "书房、次卧、神位安奉", "忌大面积卫浴、忌开大门直冲", "艮为山，止息安固。东北方为表鬼门，关系子孙运道与田宅家底，宜实墙厚重有靠。"),
        ("震", "正东方", "木", "长男/长子", "肝胆、神经系统、足部", "客厅、运动空间、大门纳气", "忌金属重物过多压制、忌缺角", "震为雷，生发勃达。正东方为紫气东来朝气生旺之所，晨光初照，大旺长子立志与事业开拓。"),
        ("巽", "东南方", "木", "长女/文昌位", "神经、呼吸系统、股部", "文昌书房、女孩闺房、阳台", "忌设垃圾桶、忌闭塞无窗", "巽为风，柔顺通达。东南方为四绿文曲秀木之地，大旺考试读书、贵人指引与清雅声誉。"),
        ("离", "正南方", "火", "中女/次女", "眼睛、心脏、血液循环", "客厅明堂、落地窗采光阳台", "忌厕所见水克火、忌过分阴暗", "离为火，光明附丽。正南方为朱雀明堂纳阳之尊位，阳光普照，大旺声誉名望、喜庆婚嫁与商业名气。"),
        ("坤", "西南方", "土", "母亲/女主人", "脾胃、腹部、妇科健康", "主卧、衣帽间、储蓄库房", "忌设污秽卫浴(里鬼门)、忌杂乱", "坤为地，厚德载物。西南方为坤母至尊之地，承载一家包容与家庭和睦，宜整洁平整温润。"),
        ("兑", "正西方", "金", "少女/幼女", "口齿、咽喉、肺部呼吸", "餐厅、影音娱乐室、客卧", "忌炉灶烈火克金、忌尖角冲射", "兑为泽，喜悦言谈。正西方主饮食喜庆与口才技艺，宜雅致温馨，忌见凶煞尖角。")
    ]"""

    new_array = """    private var palaces: [(gua: String, dir: String, elem: String, member: String, body: String, bestRoom: String, taboo: String, desc: String)] {
        let l = LocalizationManager.shared
        return [
            (l.t("gua_qian"), l.t("dir_nw"), l.t("elem_metal"), l.t("member_father"), l.t("body_head"), l.t("best_room_qian"), l.t("taboo_qian"), l.t("desc_qian")),
            (l.t("gua_kan"), l.t("dir_n"), l.t("elem_water"), l.t("member_middle_son"), l.t("body_kidney"), l.t("best_room_kan"), l.t("taboo_kan"), l.t("desc_kan")),
            (l.t("gua_gen"), l.t("dir_ne"), l.t("elem_earth"), l.t("member_youngest_son"), l.t("body_spleen"), l.t("best_room_gen"), l.t("taboo_gen"), l.t("desc_gen")),
            (l.t("gua_zhen"), l.t("dir_e"), l.t("elem_wood"), l.t("member_eldest_son"), l.t("body_liver"), l.t("best_room_zhen"), l.t("taboo_zhen"), l.t("desc_zhen")),
            (l.t("gua_xun"), l.t("dir_se"), l.t("elem_wood"), l.t("member_eldest_daughter"), l.t("body_nerve"), l.t("best_room_xun"), l.t("taboo_xun"), l.t("desc_xun")),
            (l.t("gua_li"), l.t("dir_s"), l.t("elem_fire"), l.t("member_middle_daughter"), l.t("body_heart"), l.t("best_room_li"), l.t("taboo_li"), l.t("desc_li")),
            (l.t("gua_kun"), l.t("dir_sw"), l.t("elem_earth"), l.t("member_mother"), l.t("body_belly"), l.t("best_room_kun"), l.t("taboo_kun"), l.t("desc_kun")),
            (l.t("gua_dui"), l.t("dir_w"), l.t("elem_metal"), l.t("member_youngest_daughter"), l.t("body_mouth"), l.t("best_room_dui"), l.t("taboo_dui"), l.t("desc_dui"))
        ]
    }"""

    c = c.replace(old_array, new_array)
    c = c.replace('Text("【\(p.gua)卦 · \(p.dir)】")', 'Text("【\(p.gua)\(lang.t("gua_suffix")) · \(p.dir)】")')

    with open(path, "w", encoding="utf-8") as f:
        f.write(c)
    print("Processed FengshuiPalaceDetailSheet.swift")

if __name__ == "__main__":
    process_tianjishu()
    process_compass_main()
    process_compass_header()
    process_ar_vision()
    process_xuankong()
    process_bazhai()
    process_qimen()
    process_purple_white()
    process_floorplan()
    process_compass_dial()
    process_palace_sheet()
    print("All view localizations applied successfully.")
