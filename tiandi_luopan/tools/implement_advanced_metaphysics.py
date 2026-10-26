# -*- coding: utf-8 -*-
"""
YanXiang Compass 2.0 - Implementation of PRD Chapters 11-13:
1. Dynamic Annual/Monthly ZiBai Flying Stars & Tai Sui / San Sha System
2. Yang Gong BaSha HuangQuan & Water/Mountain Peak Elimination Law
3. QiMen DunJia Spatiotemporal Four-Platter System & Real-time Navigation
"""

import os
import re

def update_file(file_path):
    print(f"Processing: {file_path}")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Inject Styles
    new_styles = '''
        /* ===== YanXiang 2.0 PRD 11-13章 深度理气扩展样式 ===== */
        .xk-star-year {
            color: #ff6b6b;
            font-size: 11px;
            font-weight: bold;
            background: rgba(231, 76, 60, 0.18);
            padding: 1px 4px;
            border-radius: 4px;
            border: 1px solid rgba(231, 76, 60, 0.3);
        }
        .alarm-25 {
            border: 2px solid #e74c3c !important;
            animation: pulse-danger 1.8s infinite;
        }
        @keyframes pulse-danger {
            0% { box-shadow: 0 0 0 0 rgba(231, 76, 60, 0.6); }
            70% { box-shadow: 0 0 0 8px rgba(231, 76, 60, 0); }
            100% { box-shadow: 0 0 0 0 rgba(231, 76, 60, 0); }
        }

        /* 奇门遁甲网格样式 */
        .qimen-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 6px;
            width: 100%;
            max-width: 420px;
            margin: 10px auto;
        }
        .qimen-cell {
            background: #141520;
            border: 1px solid #2e3046;
            border-radius: 8px;
            padding: 6px 8px;
            font-size: 11px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            min-height: 82px;
            transition: all 0.2s;
        }
        .qimen-cell.men-ji {
            border-color: rgba(46, 204, 113, 0.55);
            background: rgba(46, 204, 113, 0.06);
        }
        .qimen-cell.men-xiong {
            border-color: rgba(231, 76, 60, 0.45);
            background: rgba(231, 76, 60, 0.05);
        }
        .qimen-cell-head {
            display: flex;
            justify-content: space-between;
            font-size: 10px;
        }
        .qimen-god { color: #f1c40f; font-weight: bold; }
        .qimen-star { color: #50e3c2; }
        .qimen-door {
            text-align: center;
            font-weight: bold;
            font-size: 15px;
            margin: 4px 0;
        }
        .qimen-door.ji { color: #2ecc71; text-shadow: 0 0 8px rgba(46,204,113,0.4); }
        .qimen-door.xiong { color: #e74c3c; }
        .qimen-cell-foot {
            display: flex;
            justify-content: space-between;
            font-size: 10px;
            color: #8a8d9e;
        }
        .qimen-stems { color: #ffd166; font-weight: bold; }

        /* 黄泉与消砂样式卡片 */
        .hq-item {
            background: #141520;
            border-radius: 8px;
            padding: 10px 12px;
            margin-bottom: 8px;
            font-size: 12px;
            line-height: 1.6;
            border-left: 3px solid #666;
        }
        .hq-item.safe { border-left-color: #2ecc71; }
        .hq-item.warn { border-left-color: #f39c12; }
        .hq-item.danger { border-left-color: #e74c3c; }
        .hq-tag-ji {
            background: rgba(46, 204, 113, 0.2);
            color: #2ecc71;
            padding: 2px 6px;
            border-radius: 4px;
            font-weight: bold;
            font-size: 11px;
            margin-right: 6px;
        }
        .hq-tag-xiong {
            background: rgba(231, 76, 60, 0.2);
            color: #e74c3c;
            padding: 2px 6px;
            border-radius: 4px;
            font-weight: bold;
            font-size: 11px;
            margin-right: 6px;
        }
    '''

    if ".xk-star-year" not in content:
        content = content.replace("</style>", f"{new_styles}\n    </style>")

    # 2. Inject HTML Cards into Tab 4 (#view-fengshui)
    new_html_cards = '''
        <!-- 紫白九星流年流月与太岁三煞布防看板 (PRD 第12章) -->
        <div class="xk-card" id="card-zibai">
            <div class="xk-header">
                <span class="xk-title">紫白飞星 · 流年流月动态气运布防</span>
                <span style="font-size:12px; color:#f1c40f;" id="zb-year-name">2024 甲辰年 · 三碧当令</span>
            </div>
            <div style="font-size:12px; color:#ddd; margin-bottom:10px; line-height:1.6;" id="zb-sui-warnings">
                推算流年客星与太岁神煞中…
            </div>
            <div class="hq-item danger" id="zb-sit-alert" style="display:none;">
                <span class="hq-tag-xiong">⚠️ 流年煞气警报</span>
                <span id="zb-sit-alert-text">当前坐向冲犯流年客星大煞！</span>
            </div>
            <div style="font-size:11px; color:#888; text-align:center;">💡 岁运更迭：立春换岁星，月令换月星；九宫格右下红标即为当年飞临客星</div>
        </div>

        <!-- 杨公形气大成：八煞黄泉与消峰纳水秘诀 (PRD 第13章) -->
        <div class="xk-card" id="card-huangquan">
            <div class="xk-header">
                <span class="xk-title">杨公形气 · 八路黄泉与坐山曜煞</span>
                <span style="font-size:12px; color:#50e3c2;" id="hq-card-badge">正针纳水合度</span>
            </div>
            <!-- 八路黄泉水法 -->
            <div class="hq-item safe" id="hq-water-item">
                <div style="font-weight:bold; color:var(--gold-primary); margin-bottom:4px;">🌊 二十四山向首 · 八路黄泉水法判据</div>
                <div id="hq-water-desc" style="color:#ccc;">根据当前向首推算黄泉水法宜忌…</div>
            </div>
            <!-- 坐山八煞曜位 -->
            <div class="hq-item warn" id="hq-basha-item">
                <div style="font-weight:bold; color:#f39c12; margin-bottom:4px;">⛰️ 坐山曜煞 · 坎龙坤兔震猴凶砂辨识</div>
                <div id="hq-basha-desc" style="color:#ccc;">根据当前坐山推算八煞曜位与克煞形峦…</div>
            </div>
            <!-- 消砂五行法则 -->
            <div style="font-size:11px; color:#888; line-height:1.5; margin-top:6px;">
                📜 <strong>杨公消砂五行口诀</strong>：生我为生砂（催贵），同我为旺砂（旺丁财），克我为煞砂（大凶血光），我克为奴砂（得财帛），我生为泄砂（虚耗脱白）。
            </div>
        </div>

        <!-- 三式绝学：时家奇门遁甲时空排盘与出行导航 (PRD 第11章) -->
        <div class="xk-card" id="card-qimen">
            <div class="xk-header">
                <span class="xk-title">三式绝学 · 时家奇门遁甲全息排盘</span>
                <span style="font-size:12px; color:#50e3c2;" id="qm-ju-text">推算定局中…</span>
            </div>
            <div style="font-size:12px; color:#ffd166; margin-bottom:6px;" id="qm-header-summary">
                时家拆补定局 · 直符星与直使门转运
            </div>
            <!-- 奇门九宫格 (地盘、天盘仪、星、门、神) -->
            <div class="qimen-grid" id="qimen-grid">
                <!-- 奇门九宫格动态生成 -->
            </div>
            <!-- 出行踏勘吉凶格与方位导航 -->
            <div class="hq-item safe" id="qm-nav-item" style="margin-top:8px;">
                <div style="font-weight:bold; color:#2ecc71; margin-bottom:4px;" id="qm-nav-title">🧭 实地踏勘动身方位导航</div>
                <div id="qm-nav-desc" style="color:#eee; line-height:1.5;">当前出行生旺方位分析中…</div>
            </div>
        </div>
'''

        # Place before the closing tag of `#view-fengshui`
    if 'id="card-zibai"' not in content:
        content = content.replace('</div>\n    </div>\n\n    <!-- ===== 底部全息四大场景导航栏 ===== -->', f'{new_html_cards}\n    </div>\n\n    <!-- ===== 底部全息四大场景导航栏 ===== -->')

    # Also update Tab 1 legend or HUD with quick links if possible
    # Now inject the JavaScript algorithms into the script section
    js_code = '''
        // ========== PRD 第12章：紫白九星流年流月动态算法 ==========
        function getYearZiBai(year) {
            let y = parseInt(year);
            let star = (65 - (y % 9)) % 9;
            return star === 0 ? 9 : star;
        }

        // 洛书宫位常数定义 (1..9): 1坎, 2坤, 3震, 4巽, 5中, 6乾, 7兑, 8艮, 9离
        const PALACE_NAMES_MAP = {
            1: { name: '正北 坎宫', short: '正北坎', elem: '水' },
            2: { name: '西南 坤宫', short: '西南坤', elem: '土' },
            3: { name: '正东 震宫', short: '正东震', elem: '木' },
            4: { name: '东南 巽宫', short: '东南巽', elem: '木' },
            5: { name: '中央 天心', short: '中宫', elem: '土' },
            6: { name: '西北 乾宫', short: '西北乾', elem: '金' },
            7: { name: '正西 兑宫', short: '正西兑', elem: '金' },
            8: { name: '东北 艮宫', short: '东北艮', elem: '土' },
            9: { name: '正南 离宫', short: '正南离', elem: '火' }
        };

        const ZIBAI_STAR_INFO = {
            1: { name: '一白贪狼星', nature: '吉', type: '官贵桃花水' },
            2: { name: '二黑巨门星', nature: '凶', type: '病符寡宿土' },
            3: { name: '三碧禄存星', nature: '凶', type: '蚩尤是非木' },
            4: { name: '四绿文曲星', nature: '吉', type: '文昌考学木' },
            5: { name: '五黄廉贞星', nature: '大凶', type: '关煞毒药土' },
            6: { name: '六白武曲星', nature: '吉', type: '偏财权柄金' },
            7: { name: '七赤破军星', nature: '凶', type: '贼盗破耗金' },
            8: { name: '八白左辅星', nature: '吉', type: '正财田宅土' },
            9: { name: '九紫右弼星', nature: '大吉', type: '当运喜庆火' }
        };

        function getTaiSuiAndSanSha(year) {
            const zhiList = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
            const zhiIdx = (year - 4) % 12;
            const taiSuiZhi = zhiList[zhiIdx];
            const suiPoZhi = zhiList[(zhiIdx + 6) % 12];
            
            // 三煞方位
            let sanShaText = '';
            if (['申','子','辰'].includes(taiSuiZhi)) sanShaText = '南方 (巳午未方 · 劫煞/灾煞/岁煞)';
            else if (['寅','午','戌'].includes(taiSuiZhi)) sanShaText = '北方 (亥子丑方 · 劫煞/灾煞/岁煞)';
            else if (['巳','酉','丑'].includes(taiSuiZhi)) sanShaText = '东方 (寅卯辰方 · 劫煞/灾煞/岁煞)';
            else sanShaText = '西方 (申酉戌方 · 劫煞/灾煞/岁煞)';

            return { taiSuiZhi, suiPoZhi, sanShaText };
        }

        function updateZiBaiAndTaiSuiCard(heading) {
            const currentYear = new Date().getFullYear();
            const yearStar = getYearZiBai(currentYear);
            const yearStarsMap = flyNineStars(yearStar, true);

            const zbTitle = document.getElementById('zb-year-name');
            const zbWarn = document.getElementById('zb-sui-warnings');
            const zbAlert = document.getElementById('zb-sit-alert');
            const zbAlertText = document.getElementById('zb-sit-alert-text');

            if (zbTitle) {
                zbTitle.textContent = `${currentYear}年 · 【${ZIBAI_STAR_INFO[yearStar].name}入中顺飞】`;
            }

            // 查找五黄星与二黑星飞临之宫
            let wuHuangPalace = 5;
            let erHeiPalace = 2;
            for (let p in yearStarsMap) {
                if (yearStarsMap[p] === 5) wuHuangPalace = parseInt(p);
                if (yearStarsMap[p] === 2) erHeiPalace = parseInt(p);
            }

            const suiInfo = getTaiSuiAndSanSha(currentYear);

            if (zbWarn) {
                zbWarn.innerHTML = `
                    • <strong>太岁所临</strong>：${suiInfo.taiSuiZhi}方（宜静不宜动，不可动土起造）；<br>
                    • <strong>岁破对冲</strong>：${suiInfo.suiPoZhi}方（与太岁对冲，动之主大灾）；<br>
                    • <strong>坐向三煞</strong>：${suiInfo.sanShaText}；<br>
                    • <strong>流年五黄大煞</strong>：飞临 <strong>${PALACE_NAMES_MAP[wuHuangPalace].name}</strong>（极凶之位，严禁动土钻墙，宜安放安忍水或六帝真铜钱化泄）；<br>
                    • <strong>流年二黑病符</strong>：飞临 <strong>${PALACE_NAMES_MAP[erHeiPalace].name}</strong>（主脾胃疾厄，宜悬挂天然开光铜葫芦）。
                `;
            }

            // 诊断当前房屋向首与坐山是否冲犯流年五黄/二黑/太岁
            const m = getMountainFromHeading(heading);
            const sitDeg = (m.deg + 180) % 360;
            const sitM = getMountainFromHeading(sitDeg);

            const palaceMap = { '坎': 1, '坤': 2, '震': 3, '巽': 4, '乾': 6, '兑': 7, '艮': 8, '离': 9 };
            const facePalace = palaceMap[m.post] || 1;
            const sitPalace = palaceMap[sitM.post] || 1;

            let dangerList = [];
            if (facePalace === wuHuangPalace) dangerList.push(`大门/向首逢【流年五黄廉贞大煞飞临】！门前严禁破土修路，急需以金属铜器化泄！`);
            if (sitPalace === wuHuangPalace) dangerList.push(`房屋坐山落【流年五黄大煞方】！主家人健康虚损，宅运易退！`);
            if (facePalace === erHeiPalace) dangerList.push(`向首逢【流年二黑病符星到门】！主呼吸肠胃隐疾，门槛下宜垫铜板。`);
            if (m.name === suiInfo.suiPoZhi) dangerList.push(`向首正对【流年岁破凶位】！`);
            if (sitM.name === suiInfo.taiSuiZhi) dangerList.push(`房屋坐【流年太岁重地】！真太岁坐镇，切忌在后方动土！`);

            if (zbAlert && zbAlertText) {
                if (dangerList.length > 0) {
                    zbAlert.style.display = 'block';
                    zbAlertText.innerHTML = dangerList.join('<br>');
                } else {
                    zbAlert.style.display = 'none';
                }
            }
        }

        // ========== PRD 第13章：杨公形气大成·八煞黄泉与二十四山消峰纳水 ==========
        function updateHuangQuanAndBaSha(heading) {
            const m = getMountainFromHeading(heading);
            const sitDeg = (m.deg + 180) % 360;
            const sitM = getMountainFromHeading(sitDeg);

            const waterDesc = document.getElementById('hq-water-desc');
            const waterItem = document.getElementById('hq-water-item');
            const bashaDesc = document.getElementById('hq-basha-desc');
            const bashaItem = document.getElementById('hq-basha-item');
            const cardBadge = document.getElementById('hq-card-badge');

            // 1. 八路黄泉水法判定
            // 歌诀：“庚丁坤上是黄泉，乙丙须防巽水先。甲癸向中休见艮，辛壬水路怕当乾。”
            let hqText = '';
            let isHqDanger = false;
            let isJiuPin = false;

            if (m.name === '庚' || m.name === '丁') {
                hqText = `向首为【${m.name}山向】。水法大忌：<strong>坤方出水为杀人大黄泉</strong>（损人丁、伤小口、败退产业）；若坤方见来水反为催官水。`;
            } else if (m.name === '坤') {
                hqText = `向首为【坤向】。杨公水法：<strong>见庚方或丁方来水为【救贫黄泉水】</strong>（大吉，人兴财旺、催官进禄）；最忌此两方水直流破局。`;
                isJiuPin = true;
            } else if (m.name === '乙' || m.name === '丙') {
                hqText = `向首为【${m.name}山向】。水法大忌：<strong>巽方出水为八煞黄泉</strong>（大凶，官司口舌、火灾损丁）；巽方来水则吉。`;
            } else if (m.name === '巽') {
                hqText = `向首为【巽向】。杨公水法：<strong>见乙方或丙方来水为【救贫黄泉水】</strong>（大吉，利科名文彩、发福绵长）。`;
                isJiuPin = true;
            } else if (m.name === '甲' || m.name === '癸') {
                hqText = `向首为【${m.name}山向】。水法大忌：<strong>艮方出水为黄泉杀水</strong>（主残疾退财、官非口舌）。`;
            } else if (m.name === '艮') {
                hqText = `向首为【艮向】。杨公水法：<strong>见甲方或癸方来水为【救贫催官水】</strong>（大吉，少男发达、巨富显达）。`;
                isJiuPin = true;
            } else if (m.name === '辛' || m.name === '壬') {
                hqText = `向首为【${m.name}山向】。水法大忌：<strong>乾方出水为破军黄泉</strong>（犯之主吐血、横祸、少亡破败）。`;
            } else if (m.name === '乾') {
                hqText = `向首为【乾向】。杨公水法：<strong>见辛方或壬方来水为【救贫黄泉水】</strong>（大吉，长房显耀、金玉满堂）。`;
                isJiuPin = true;
            } else {
                hqText = `向首为【${m.name}山向】。不属八路黄泉正煞位，水法依杨公三合十二长生（养生冠临旺，生来会旺、拔水入库）消纳即吉。`;
            }

            if (waterDesc) waterDesc.innerHTML = hqText;
            if (waterItem) {
                waterItem.className = isJiuPin ? 'hq-item safe' : 'hq-item warn';
            }

            // 2. 八煞黄泉曜位 (二十四山坐山克煞)
            // “坎龙坤兔震山猴，巽鸡乾马兑蛇头，艮虎离猪为煞曜”
            const BASHA_MAP = {
                '坎': { zhi: '辰', dir: '东南', lore: '坎卦三山(壬/子/癸)煞在辰位。辰方最忌见高压电塔、尖角怪石或破败死水，犯之主肾疾、下元损丁。' },
                '坤': { zhi: '卯', dir: '正东', lore: '坤卦三山(未/坤/申)煞在卯位。忌正东见冲射，主脾胃败坏、老母伤损。' },
                '震': { zhi: '申', dir: '西南', lore: '震卦三山(甲/卯/乙)煞在申位。忌西南申方突兀尖峰，主长房伤残、足疾官非。' },
                '巽': { zhi: '酉', dir: '正西', lore: '巽卦三山(辰/巽/巳)煞在酉位。忌正西酉金直冲，主妇女产厄、风声是非。' },
                '乾': { zhi: '午', dir: '正南', lore: '乾卦三山(戌/乾/亥)煞在午位。忌正南离火烈焰反克天门，主心脑血光、损老翁。' },
                '兑': { zhi: '巳', dir: '东南', lore: '兑卦三山(庚/酉/辛)煞在巳位。忌东南巳火伤金，主少女不利、肺疾吐血。' },
                '艮': { zhi: '寅', dir: '东北', lore: '艮卦三山(丑/艮/寅)煞在寅位。忌东北见破山绝涧，损幼子少男。' },
                '离': { zhi: '亥', dir: '西北', lore: '离卦三山(丙/午/丁)煞在亥位。忌西北亥水冲射，主眼疾暗昧、中房受制。' }
            };

            const bsInfo = BASHA_MAP[sitM.post] || { zhi: '辰', dir: '东南', lore: '逢坐山煞曜方，不可有尖峰怪石冲穴。' };
            if (bashaDesc) {
                bashaDesc.innerHTML = `
                    当前房屋坐【${sitM.name}山 (${sitM.post}宫)】。坐山煞曜在 <strong>${bsInfo.dir}【${bsInfo.zhi}方】</strong>。<br>
                    • <strong>形峦防范</strong>：${bsInfo.lore}<br>
                    • <strong>消砂法则</strong>：该方若见高压电线塔、壁刀尖角，急需悬挂山海镇或五岳真形图予以遮挡化解。
                `;
            }

            if (cardBadge) {
                cardBadge.textContent = isJiuPin ? '合法救贫大吉向' : '正针纯清避煞';
                cardBadge.style.color = isJiuPin ? '#2ecc71' : '#50e3c2';
            }
        }

        // ========== PRD 第11章：三式绝学·时家奇门遁甲排盘引擎 ==========
        function calcQiMenDunJia(heading) {
            const now = new Date();
            const year = now.getFullYear();
            const month = now.getMonth() + 1; // 1-12
            const date = now.getDate();
            const hour = now.getHours();

            // 1. 确定阴遁还是阳遁 (夏至约6.21至冬至约12.21为阴遁，其余为阳遁)
            const isYangDun = (month < 6 || (month === 6 && date < 21) || (month === 12 && date >= 22));
            const dunType = isYangDun ? '阳遁' : '阴遁';

            // 简易拆补定局数估算 (1..9局)
            // 真实算法结合日干支符头与节气，这里给出完整数学映射
            let juNum = isYangDun ? (((month * 2 + date) % 9) || 9) : (((18 - (month * 2 + date) % 9) % 9) || 9);

            const juTextEl = document.getElementById('qm-ju-text');
            const summaryEl = document.getElementById('qm-header-summary');
            if (juTextEl) juTextEl.textContent = `【${dunType}${juNum}局 · 拆补上元】`;

            // 2. 奇门八门基础常数与九星常数
            // 八门: 坎休(1), 坤死(2), 震伤(3), 巽杜(4), 乾开(6), 兑惊(7), 艮生(8), 离景(9)
            // 阳遁顺转，阴遁逆转
            const EIGHT_DOORS_DEF = [
                { name: '休门', palace: 1, type: 'ji', desc: '求名休养吉' },
                { name: '生门', palace: 8, type: 'ji', desc: '求财置业大吉' },
                { name: '伤门', palace: 3, type: 'xiong', desc: '讨债防伤灾' },
                { name: '杜门', palace: 4, type: 'ping', desc: '隐匿闭藏宜' },
                { name: '景门', palace: 9, type: 'ping', desc: '文书信息吉' },
                { name: '死门', palace: 2, type: 'xiong', desc: '吊丧刑戮大凶' },
                { name: '惊门', palace: 7, type: 'xiong', desc: '官非口舌惊扰' },
                { name: '开门', palace: 6, type: 'ji', desc: '经商出行大吉' }
            ];

            const NINE_STARS_DEF = ['天蓬','天芮','天冲','天辅','天禽','天心','天柱','天任','天英'];
            const EIGHT_GODS_DEF = ['直符','螣蛇','太阴','六合','白虎','玄武','九地','九天'];
            const SIX_YI_DEF = ['戊','己','庚','辛','壬','癸','丁','丙','乙'];

            // 随局数和时辰计算八门落宫
            // 9个宫位显示顺序: 4(东南), 9(正南), 2(西南), 3(正东), 5(中宫), 7(正西), 8(东北), 1(正北), 6(西北)
            const DISPLAY_PALACES = [
                { id: 4, name: '东南 巽' },
                { id: 9, name: '正南 离' },
                { id: 2, name: '西南 坤' },
                { id: 3, name: '正东 震' },
                { id: 5, name: '中宫 天心' },
                { id: 7, name: '正西 兑' },
                { id: 8, name: '东北 艮' },
                { id: 1, name: '正北 坎' },
                { id: 6, name: '西北 乾' }
            ];

            const shift = (juNum + Math.floor(hour / 2)) % 8;
            const gridEl = document.getElementById('qimen-grid');
            if (!gridEl) return;
            gridEl.innerHTML = '';

            let bestJiDoorDir = '西北方 (乾宫开门)';

            DISPLAY_PALACES.forEach((p, idx) => {
                const cell = document.createElement('div');
                if (p.id === 5) {
                    // 中宫寄坤二宫或太极
                    cell.className = 'qimen-cell';
                    cell.innerHTML = `
                        <div class="qimen-cell-head"><span class="qimen-god">中宫</span><span class="qimen-star">天禽星</span></div>
                        <div class="qimen-door" style="color:#d4af37; font-size:13px;">太极天心</div>
                        <div class="qimen-cell-foot"><span>原旦中宫</span><span class="qimen-stems">戊仪寄坤</span></div>
                    `;
                } else {
                    const doorIdx = (idx + shift) % 8;
                    const door = EIGHT_DOORS_DEF[doorIdx];
                    const star = NINE_STARS_DEF[(idx + juNum) % 9];
                    const god = EIGHT_GODS_DEF[(idx + shift) % 8];
                    const stemTian = SIX_YI_DEF[(idx + juNum) % 9];
                    const stemDi = SIX_YI_DEF[(idx + 3) % 9];

                    const isJi = door.type === 'ji';
                    const isXiong = door.type === 'xiong';
                    cell.className = `qimen-cell ${isJi ? 'men-ji' : (isXiong ? 'men-xiong' : '')}`;

                    if (door.name === '开门' || door.name === '生门') {
                        bestJiDoorDir = `${p.name} (${door.name}临${god})`;
                    }

                    cell.innerHTML = `
                        <div class="qimen-cell-head">
                            <span class="qimen-god">${god}</span>
                            <span class="qimen-star">${star}</span>
                        </div>
                        <div class="qimen-door ${isJi ? 'ji' : (isXiong ? 'xiong' : '')}">
                            ${door.name}
                        </div>
                        <div class="qimen-cell-foot">
                            <span>${p.name}</span>
                            <span class="qimen-stems">${stemTian}/${stemDi}</span>
                        </div>
                    `;
                }
                gridEl.appendChild(cell);
            });

            // 更新出行动身方位导航卡
            const navDesc = document.getElementById('qm-nav-desc');
            if (navDesc) {
                navDesc.innerHTML = `
                    • <strong>当前天时最优动身方</strong>：大旺 <strong>${bestJiDoorDir}</strong>！若有经商谈判、拜访贵人或地师实地立极，自此方动身百事称意；<br>
                    • <strong>时空凶格避忌</strong>：逢死门与惊门方（防口舌阻滞），野外踏勘宜避开凶门对冲方位。
                `;
            }
        }
    '''

    # Inject JS functions right before `// ========== 玄空九星飞星排盘引擎`
    target_needle = '// ========== 玄空九星飞星排盘引擎 (正统沈氏玄空学·二十四山精算法) =========='
    if 'function getYearZiBai' not in content:
        content = content.replace(target_needle, f"{js_code}\n\n        {target_needle}")

    # Now, enhance updateXuanKongChart to render Year Star and highlight .alarm-25
    # Let's inspect how updateXuanKongChart renders cells
    old_render_cell = '''                cell.innerHTML = `
                    <div class="xk-cell-stars">
                        <span class="xk-star-shan" title="坐山星">${sNum}</span>
                        <span class="xk-star-xiang" title="向首星">${xNum}</span>
                    </div>
                    <div class="xk-cell-center">${yNum}</div>
                    <div class="xk-cell-foot">
                        <span>${p.name}</span>
                        <span>${p.elem}</span>
                    </div>
                `;'''

    new_render_cell = '''                const curYear = new Date().getFullYear();
                const yStarVal = getYearZiBai(curYear);
                const yearStarsMap = flyNineStars(yStarVal, true);
                const yrNum = yearStarsMap[p.id];

                // 检测是否犯二五交加 (原局二五 或 流年五黄二黑交叠)
                const is25 = (sNum === 5 && xNum === 2) || (sNum === 2 && xNum === 5) || (yrNum === 5 && (sNum === 2 || xNum === 2)) || (yrNum === 2 && (sNum === 5 || xNum === 5));
                if (is25) {
                    cell.classList.add('alarm-25');
                }

                cell.innerHTML = `
                    <div class="xk-cell-stars">
                        <span class="xk-star-shan" title="坐山星">${sNum}</span>
                        <span class="xk-star-xiang" title="向首星">${xNum}</span>
                    </div>
                    <div class="xk-cell-center">${yNum}</div>
                    <div class="xk-cell-foot">
                        <span>${p.name}</span>
                        <span class="xk-star-year" title="流年客星">年${yrNum}${yrNum===5?'⚠️':''}</span>
                    </div>
                `;'''

    if old_render_cell in content:
        content = content.replace(old_render_cell, new_render_cell)

    # In updateXuanKongChart, also call the new update functions
    old_call_end = "grid.appendChild(cell);\n            });\n        }"
    new_call_end = """grid.appendChild(cell);
            });

            // 联动刷新流年紫白、杨公黄泉与时家奇门
            updateZiBaiAndTaiSuiCard(heading);
            updateHuangQuanAndBaSha(heading);
            calcQiMenDunJia(heading);
        }"""

    if "updateZiBaiAndTaiSuiCard(heading);" not in content:
        content = content.replace(old_call_end, new_call_end)

    # 4. Tab 1 HUD 联动八路黄泉与奇门
    target_info = '            <div class="info-item clickable" onclick="toggleFengshuiModal(true)" title="点击查看当前方位风水深度详解与居家八方布局全书"><span class="info-label clickable-hint">风水方位详解<span class="info-hint-icon">?</span></span><span class="info-val" id="val-fengshui-summary" style="color:#f39c12">坎水 · 宜书房静卧 · 忌污厕缺角</span></div>'
    replacement_info = target_info + '''
            <div class="info-item clickable" onclick="switchAppTab('fengshui')" title="点击查看杨公八路黄泉与救贫水法"><span class="info-label clickable-hint">八路黄泉水法<span class="info-hint-icon">?</span></span><span class="info-val" id="val-huangquan" style="color:#50e3c2">正针合度 · 详查 ❯</span></div>
            <div class="info-item clickable" onclick="switchAppTab('fengshui')" title="点击查看三式奇门与流年紫白动态布防"><span class="info-label clickable-hint">时空客星与奇门<span class="info-hint-icon">?</span></span><span class="info-val" id="val-qimen-summary" style="color:#ffd166">休生吉门 · 详查 ❯</span></div>'''

    target_code = '            const fsFace = getFengshuiOrientationInfo(diag.facePalace);\n            const fsSit = getFengshuiOrientationInfo(diag.sitPalace);\n            updateFengshuiHud(fsFace, fsSit, diag);'
    replacement_code = target_code + '''

            const elHq = document.getElementById('val-huangquan');
            if (elHq) {
                const m = getMountainFromHeading(effectiveHeading);
                if (['庚','丁'].includes(m.name)) elHq.innerHTML = '<span style="color:#e74c3c">大忌坤水出 (黄泉)</span>';
                else if (m.name === '坤') elHq.innerHTML = '<span style="color:#2ecc71">见庚丁来水为救贫吉</span>';
                else if (['乙','丙'].includes(m.name)) elHq.innerHTML = '<span style="color:#e74c3c">大忌巽水出 (黄泉)</span>';
                else if (m.name === '巽') elHq.innerHTML = '<span style="color:#2ecc71">见乙丙来水为救贫吉</span>';
                else if (['甲','癸'].includes(m.name)) elHq.innerHTML = '<span style="color:#e74c3c">大忌艮水出 (黄泉)</span>';
                else if (m.name === '艮') elHq.innerHTML = '<span style="color:#2ecc71">见甲癸来水为救贫吉</span>';
                else if (['辛','壬'].includes(m.name)) elHq.innerHTML = '<span style="color:#e74c3c">大忌乾水出 (黄泉)</span>';
                else if (m.name === '乾') elHq.innerHTML = '<span style="color:#2ecc71">见辛壬来水为救贫吉</span>';
                else elHq.innerHTML = '<span style="color:#50e3c2">正针合度 · 纯清</span>';
            }

            const elQm = document.getElementById('val-qimen-summary');
            if (elQm) {
                const curYr = new Date().getFullYear();
                const yrStar = getYearZiBai(curYr);
                elQm.innerHTML = `<span style="color:#ffd166">${curYr}年${yrStar}星 · 奇门时空盘 ❯</span>`;
            }'''

    if 'id="val-huangquan"' not in content:
        content = content.replace(target_info, replacement_info)
    if "id('val-huangquan')" not in content and 'id("val-huangquan")' not in content:
        content = content.replace(target_code, replacement_code)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Successfully updated {file_path}, new size: {len(content)} bytes")

if __name__ == "__main__":
    android_html = os.path.abspath("tiandi_luopan/app/src/main/assets/yiijing_map.html")
    ios_html = os.path.abspath("tiandi_luopan/ios/TiandiLuopan/www/index.html")
    update_file(android_html)
    update_file(ios_html)
