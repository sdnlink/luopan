# -*- coding: utf-8 -*-
"""
YanXiang Compass 2.0 - Implementation of PRD Chapter 14:
'Fu Zhai Tian Ji Shu' Classical Xuan Paper Rendering & Export Engine
Generates ultra-high-resolution vermilion-columned report scrolls.
"""

import os

def update_file(file_path):
    print(f"Processing for TianJiShu: {file_path}")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. CSS for TianJiShu Modal and Buttons
    tianji_css = '''
        /* ===== PRD 第14章：“福宅天机书”宣纸风出图引擎样式 ===== */
        .tianji-banner-card {
            background: linear-gradient(135deg, #2b1f13 0%, #1c1d28 100%);
            border: 1px solid var(--gold-primary);
            border-radius: 14px;
            padding: 16px;
            margin-bottom: 14px;
            text-align: center;
            box-shadow: 0 6px 20px rgba(212, 175, 55, 0.15);
        }
        .btn-tianji-gen {
            background: linear-gradient(135deg, #d4af37 0%, #aa820a 100%);
            color: #111;
            font-size: 13px;
            font-weight: bold;
            padding: 10px 22px;
            border-radius: 25px;
            border: none;
            cursor: pointer;
            box-shadow: 0 4px 15px rgba(212, 175, 55, 0.4);
            transition: all 0.2s;
            margin-top: 8px;
        }
        .btn-tianji-gen:active {
            transform: scale(0.96);
        }

        /* 宣纸天机书全屏预览弹窗 */
        .tianji-modal-overlay {
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0, 0, 0, 0.88);
            backdrop-filter: blur(8px);
            -webkit-backdrop-filter: blur(8px);
            z-index: 3000;
            display: none;
            flex-direction: column;
            align-items: center;
            padding: 12px;
            box-sizing: border-box;
        }
        .tianji-scroll-container {
            width: 100%;
            max-width: 520px;
            flex: 1;
            overflow-y: auto;
            -webkit-overflow-scrolling: touch;
            border-radius: 10px;
            box-shadow: 0 10px 35px rgba(0,0,0,0.8);
            margin-bottom: 12px;
            background: #222;
        }
        #tianji-preview-img {
            width: 100%;
            height: auto;
            display: block;
        }
        .tianji-action-bar {
            width: 100%;
            max-width: 520px;
            display: flex;
            gap: 10px;
            justify-content: center;
            padding-bottom: env(safe-area-inset-bottom, 10px);
        }
        .tianji-btn {
            flex: 1;
            padding: 10px 0;
            border-radius: 8px;
            font-size: 13px;
            font-weight: bold;
            border: none;
            cursor: pointer;
            text-align: center;
            text-decoration: none;
        }
        .tianji-btn.save { background: var(--gold-primary); color: #111; }
        .tianji-btn.close { background: #333645; color: #ddd; }
    '''

    if ".tianji-banner-card" not in content:
        content = content.replace("</style>", f"{tianji_css}\n    </style>")

    # 2. Inject TianJiShu Modal HTML & Tab 4 Banner
    tianji_modal_html = '''
    <!-- “福宅天机书”古典宣纸风排版预览弹窗 (PRD 第14章) -->
    <div class="tianji-modal-overlay" id="tianji-modal">
        <div style="color:var(--gold-primary); font-size:16px; font-weight:bold; margin-bottom:8px; display:flex; justify-content:space-between; width:100%; max-width:520px;">
            <span>📜 福宅天机勘舆全案 · 宣纸朱丝栏长图</span>
            <span style="cursor:pointer; color:#999;" onclick="toggleTianJiModal(false)">✕</span>
        </div>
        <div class="tianji-scroll-container">
            <img id="tianji-preview-img" alt="福宅天机书渲染中..."/>
        </div>
        <div class="tianji-action-bar">
            <button class="tianji-btn save" onclick="saveTianJiShuToDevice()">💾 保存到手机相册</button>
            <button class="tianji-btn close" onclick="toggleTianJiModal(false)">关闭</button>
        </div>
    </div>
    '''

    if 'id="tianji-modal"' not in content:
        content = content.replace('</body>', f'{tianji_modal_html}\n</body>')

    # Add button to Tab 1 tab-bar
    t1_btn = '<button class="tab-btn" id="btn-tianji-top" onclick="generateTianJiShu()" style="color:#ffd166; border-color:#996515; font-weight:bold;">📜 天机书</button>'
    if 'id="btn-tianji-top"' not in content:
        content = content.replace('<button class="tab-btn" id="btn-fengshui-guide"', f'{t1_btn}\n            <button class="tab-btn" id="btn-fengshui-guide"')

    # Add banner card to Tab 4 top
    t4_banner = '''
        <!-- 演象 · 福宅天机勘舆全案生成卡 (PRD 第14章) -->
        <div class="tianji-banner-card">
            <div style="font-size:16px; font-weight:bold; color:#ffd166; margin-bottom:4px;">📜 演象 · 福宅天机堪舆全案长图</div>
            <div style="font-size:12px; color:#bbb; line-height:1.5;">一键汇总实测坐向、玄空飞星、八路黄泉、时家奇门与八宅命卦，出具古典宣纸朱丝栏勘测长卷</div>
            <button class="btn-tianji-gen" onclick="generateTianJiShu()">✨ 一键生成古典宣纸长图</button>
        </div>
'''
    if 'class="tianji-banner-card"' not in content:
        content = content.replace('<div class="app-view" id="view-fengshui">\n', f'<div class="app-view" id="view-fengshui">\n{t4_banner}')

    # 3. Inject TianJiShu Canvas Drawing Engine
    tianji_js = '''
        // ========== PRD 第14章：“福宅天机书”古典宣纸风排版出图引擎 ==========
        let lastGeneratedTianJiDataUrl = null;

        function toggleTianJiModal(show) {
            const modal = document.getElementById('tianji-modal');
            if (modal) modal.style.display = show ? 'flex' : 'none';
        }

        function saveTianJiShuToDevice() {
            if (!lastGeneratedTianJiDataUrl) return;

            // 1. 若运行在 Android 原生端，调用 Native 接口存入系统相册
            if (window.AndroidCompass && typeof window.AndroidCompass.saveImageToGallery === 'function') {
                const ok = window.AndroidCompass.saveImageToGallery(lastGeneratedTianJiDataUrl);
                if (ok) return;
            }

            // 2. 浏览器与 iOS 环境下通过 <a> 标签下载或提示长按保存
            try {
                const a = document.createElement('a');
                a.href = lastGeneratedTianJiDataUrl;
                a.download = `演象_福宅天机书_${new Date().getTime()}.jpg`;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
            } catch(e) {
                alert('长按图片即可保存至手机相册！');
            }
        }

        function drawAncientSeal(ctx, x, y, text, size, isRound) {
            ctx.save();
            ctx.strokeStyle = '#a62b2b';
            ctx.fillStyle = '#a62b2b';
            ctx.lineWidth = 3;

            if (isRound) {
                ctx.beginPath();
                ctx.arc(x, y, size / 2, 0, Math.PI * 2);
                ctx.stroke();
                ctx.font = `bold ${Math.round(size * 0.4)}px "STKaiti", "KaiTi", "SimSun", serif`;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                ctx.fillText(text, x, y);
            } else {
                ctx.strokeRect(x - size/2, y - size/2, size, size);
                ctx.font = `bold ${Math.round(size * 0.32)}px "STKaiti", "KaiTi", "SimSun", serif`;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                // 支持双字或四字折行
                if (text.length === 4) {
                    ctx.fillText(text.slice(0, 2), x, y - size * 0.18);
                    ctx.fillText(text.slice(2, 4), x, y + size * 0.22);
                } else {
                    ctx.fillText(text, x, y);
                }
            }
            ctx.restore();
        }

        function drawTianJiBanner(ctx, y, title) {
            ctx.save();
            ctx.fillStyle = '#9e2a2b';
            ctx.fillRect(45, y, 810, 38);
            ctx.fillStyle = '#faf5e8';
            ctx.font = 'bold 16px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(`【  ${title}  】`, 450, y + 20);
            ctx.restore();
        }

        function generateTianJiShu() {
            const heading = currentHeading;
            const m = getMountainFromHeading(heading);
            const sitDeg = (m.deg + 180) % 360;
            const sitM = getMountainFromHeading(sitDeg);
            const kw = diagnoseKongWang(heading);
            const fj = getFenjinAnalysis(heading);

            // 1. 创建高分辨率离屏 Canvas
            const cvs = document.createElement('canvas');
            cvs.width = 900;
            cvs.height = 2100;
            const ctx = cvs.getContext('2d');

            // 2. 宣纸底色与古典晕染
            const bgGrad = ctx.createLinearGradient(0, 0, 0, 2100);
            bgGrad.addColorStop(0, '#fcf7ec');
            bgGrad.addColorStop(0.5, '#f6efe0');
            bgGrad.addColorStop(1, '#f9f3e4');
            ctx.fillStyle = bgGrad;
            ctx.fillRect(0, 0, 900, 2100);

            // 3. 朱丝栏双层边框
            ctx.strokeStyle = '#9e2a2b';
            ctx.lineWidth = 4;
            ctx.strokeRect(30, 30, 840, 2040);
            ctx.lineWidth = 1;
            ctx.strokeRect(36, 36, 828, 2028);

            // 绘制朱丝栏淡红竖栏线
            ctx.strokeStyle = 'rgba(158, 42, 43, 0.08)';
            ctx.lineWidth = 1;
            for (let x = 60; x <= 840; x += 40) {
                ctx.beginPath();
                ctx.moveTo(x, 140);
                ctx.lineTo(x, 1960);
                ctx.stroke();
            }

            // 4. 印章
            drawAncientSeal(ctx, 100, 80, '天圆地方', 64, false);
            drawAncientSeal(ctx, 800, 80, '大吉', 54, true);

            // 5. 卷首大标题
            ctx.fillStyle = '#222';
            ctx.font = 'bold 36px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.textAlign = 'center';
            ctx.fillText('福 宅 天 机 勘 舆 书', 450, 90);

            ctx.font = '14px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.fillStyle = '#666';
            ctx.fillText('演象 · 天地全息时空罗盘 · 阳宅三元理气全案长卷', 450, 122);

            // 天时地利档案
            ctx.font = '13px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.fillStyle = '#444';
            const nowTimeStr = new Date().toLocaleString();
            const ganzhiStr = (cachedFourPillars && cachedFourPillars.fullStr) ? cachedFourPillars.fullStr : '甲辰年 季秋 丙申时';
            const solarTimeStr = (cachedTrueSolarTime && cachedTrueSolarTime.timeStr) ? cachedTrueSolarTime.timeStr : '--:--';
            ctx.fillText(`岁次四柱：${ganzhiStr} · 勘验时刻：${nowTimeStr}`, 450, 154);
            ctx.fillText(`真太阳时：${solarTimeStr} · GPS经纬度：${currentCoordsStr || '实测中'} · 地磁偏角校正：已对准真北`, 450, 178);

            // ========== 第一部：坐向立极与分金格局 ==========
            drawTianJiBanner(ctx, 210, '第一部 · 坐 向 立 极 与 分 金 格 局');
            ctx.textAlign = 'left';
            ctx.fillStyle = '#1c1c1c';
            ctx.font = '15px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.fillText(`• 正针立向：坐【${sitM.name}山】向【${m.name}山】(向首方位角 ${Math.round(heading)}°) · 下元九运当令`, 65, 275);
            ctx.fillText(`• 空亡排查：${kw.statusText} (${kw.type==='pure'?'天地纯清无驳杂':'差错交界，犯之宜谨慎'})`, 65, 305);
            ctx.fillText(`• 百分金度：${fj.displayStr} (${fj.isJewel?'丙丁庚辛珠宝吉线，主进益资财':'孤虚火坑线，急需微调避开'})`, 65, 335);

            // ========== 第二部：下元九运玄空飞星九宫方阵 ==========
            drawTianJiBanner(ctx, 370, '第二部 · 下 元 九 运 玄 空 飞 星 盘');
            
            // 绘制九宫飞星水墨方阵
            const startX = 250;
            const startY = 430;
            const cellSize = 133;
            const yunStars = flyNineStars(9, true);
            const isTiGua = (kw.type === 'jian');

            let shanBaseStar = yunStars[sitM.post === '坎' ? 1 : (sitM.post === '坤' ? 2 : (sitM.post === '震' ? 3 : (sitM.post === '巽' ? 4 : (sitM.post === '乾' ? 6 : (sitM.post === '兑' ? 7 : (sitM.post === '艮' ? 8 : 9))))))];
            let shanStar = isTiGua ? (TIGUA_MAP[sitM.name] || shanBaseStar) : shanBaseStar;
            const sitInfo = MOUNTAIN_LONG_INFO[sitM.name] || { dragon: 'tian', yy: 1 };
            let shanYY = sitInfo.yy;
            if (shanStar !== 5) {
                const targetM = PALACE_DRAGON_MOUNTAINS[shanStar] ? PALACE_DRAGON_MOUNTAINS[shanStar][sitInfo.dragon] : sitM.name;
                shanYY = MOUNTAIN_LONG_INFO[targetM] ? MOUNTAIN_LONG_INFO[targetM].yy : sitInfo.yy;
            } else { shanYY = (sitInfo.dragon === 'tian') ? -1 : 1; }
            const shanStarsMap = flyNineStars(shanStar, shanYY > 0);

            let xiangBaseStar = yunStars[m.post === '坎' ? 1 : (m.post === '坤' ? 2 : (m.post === '震' ? 3 : (m.post === '巽' ? 4 : (m.post === '乾' ? 6 : (m.post === '兑' ? 7 : (m.post === '艮' ? 8 : 9))))))];
            let xiangStar = isTiGua ? (TIGUA_MAP[m.name] || xiangBaseStar) : xiangBaseStar;
            const xiangInfo = MOUNTAIN_LONG_INFO[m.name] || { dragon: 'tian', yy: 1 };
            let xiangYY = xiangInfo.yy;
            if (xiangStar !== 5) {
                const targetM = PALACE_DRAGON_MOUNTAINS[xiangStar] ? PALACE_DRAGON_MOUNTAINS[xiangStar][xiangInfo.dragon] : m.name;
                xiangYY = MOUNTAIN_LONG_INFO[targetM] ? MOUNTAIN_LONG_INFO[targetM].yy : xiangInfo.yy;
            } else { xiangYY = (xiangInfo.dragon === 'tian') ? -1 : 1; }
            const xiangStarsMap = flyNineStars(xiangStar, xiangYY > 0);

            const curYr = new Date().getFullYear();
            const yearStarsMap = flyNineStars(getYearZiBai(curYr), true);

            const PALACES_9_LAYOUT = [
                { id: 4, name: '东南 巽', r: 0, c: 0 },
                { id: 9, name: '正南 离', r: 0, c: 1 },
                { id: 2, name: '西南 坤', r: 0, c: 2 },
                { id: 3, name: '正东 震', r: 1, c: 0 },
                { id: 5, name: '中宫 天心', r: 1, c: 1 },
                { id: 7, name: '正西 兑', r: 1, c: 2 },
                { id: 8, name: '东北 艮', r: 2, c: 0 },
                { id: 1, name: '正北 坎', r: 2, c: 1 },
                { id: 6, name: '西北 乾', r: 2, c: 2 }
            ];

            PALACES_9_LAYOUT.forEach(p => {
                const cx = startX + p.c * cellSize;
                const cy = startY + p.r * cellSize;

                ctx.strokeStyle = '#9e2a2b';
                ctx.lineWidth = 1.5;
                ctx.strokeRect(cx, cy, cellSize, cellSize);

                const s = shanStarsMap[p.id];
                const x = xiangStarsMap[p.id];
                const y = yunStars[p.id];
                const yr = yearStarsMap[p.id];

                // 坐山星 (左上青绿)
                ctx.fillStyle = '#1e7552';
                ctx.font = 'bold 20px "STKaiti", "KaiTi", serif';
                ctx.textAlign = 'left';
                ctx.fillText(`${s}`, cx + 12, cy + 30);

                // 向首星 (右上橙黄)
                ctx.fillStyle = '#b8860b';
                ctx.textAlign = 'right';
                ctx.fillText(`${x}`, cx + cellSize - 12, cy + 30);

                // 运星 (中大字朱红)
                ctx.fillStyle = '#9e2a2b';
                ctx.font = 'bold 28px "STKaiti", "KaiTi", serif';
                ctx.textAlign = 'center';
                ctx.fillText(`${y}`, cx + cellSize/2, cy + cellSize/2 + 10);

                // 宫名与流年星 (下方)
                ctx.font = '12px "STKaiti", "KaiTi", serif';
                ctx.fillStyle = '#555';
                ctx.textAlign = 'left';
                ctx.fillText(p.name, cx + 8, cy + cellSize - 10);

                ctx.fillStyle = '#c0392b';
                ctx.textAlign = 'right';
                ctx.fillText(`年${yr}`, cx + cellSize - 8, cy + cellSize - 10);
            });

            // 玄空格局断语
            const chartSummaryEl = document.getElementById('xk-chart-summary');
            const geJuText = chartSummaryEl ? chartSummaryEl.textContent : '下元九运玄空理气局 · 顺应阴阳生化';
            ctx.fillStyle = '#1c1c1c';
            ctx.font = 'bold 15px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.textAlign = 'left';
            ctx.fillText(`• ${geJuText}`, 65, 875);

            // ========== 第三部：杨公八路黄泉与坐山曜煞 ==========
            drawTianJiBanner(ctx, 915, '第三部 · 杨 公 八 路 黄 泉 与 坐 山 曜 煞');
            const hqWaterEl = document.getElementById('hq-water-desc');
            const hqBashaEl = document.getElementById('hq-basha-desc');
            const hqText1 = hqWaterEl ? hqWaterEl.innerText : '正针纯清避煞纳水';
            const hqText2 = hqBashaEl ? hqBashaEl.innerText : '排查坐山煞曜';

            ctx.font = '14px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.fillStyle = '#222';
            ctx.fillText(`• 水法宜忌：${hqText1.slice(0, 52)}`, 65, 985);
            if (hqText1.length > 52) ctx.fillText(`  ${hqText1.slice(52, 105)}`, 65, 1010);
            ctx.fillText(`• 坐山曜煞：${hqText2.slice(0, 52)}`, 65, 1045);
            if (hqText2.length > 52) ctx.fillText(`  ${hqText2.slice(52, 105)}`, 65, 1070);

            // ========== 第四部：时家奇门与八宅命卦 ==========
            drawTianJiBanner(ctx, 1110, '第四部 · 时 家 奇 门 动 身 与 八 宅 命 卦');
            const bzProfileEl = document.getElementById('bz-profile-text');
            const bzHouseEl = document.getElementById('bz-house-text');
            const qmNavEl = document.getElementById('qm-nav-desc');

            ctx.font = '14px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.fillText(`• 命卦相配：${bzProfileEl ? bzProfileEl.innerText : '福主命卦推算'}`, 65, 1180);
            ctx.fillText(`• 宅命互生：${bzHouseEl ? bzHouseEl.innerText : '东四西四宅合局'}`, 65, 1210);
            const qmText = qmNavEl ? qmNavEl.innerText : '当前出行首选西北开门大吉';
            ctx.fillText(`• 奇门动身：${qmText.slice(0, 52)}`, 65, 1240);
            if (qmText.length > 52) ctx.fillText(`  ${qmText.slice(52, 105)}`, 65, 1265);

            // ========== 第五部：全屋空间调理与化煞清单 ==========
            drawTianJiBanner(ctx, 1305, '第五部 · 全 屋 空 间 调 理 与 化 煞 秘 诀');
            ctx.font = '14px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.fillText('• 🚪 气口大门：纳气枢纽，保持明亮整洁，门坎平整，忌对角杂物堵塞；', 65, 1375);
            ctx.fillText('• 🍳 厨房灶火：严格避开西北乾宫天门重地(防火烧天门)，灶台忌与水槽水火对冲；', 65, 1405);
            ctx.fillText('• 🚽 卫浴排污：避开东北艮宫表鬼门与中心中宫天心，常开排气，置粗盐净气；', 65, 1435);
            ctx.fillText('• 💰 生旺财位：当令九紫火星与生旺向星方位，宜摆放开光阔叶绿植或聚宝盆催旺；', 65, 1465);
            ctx.fillText('• 🛡️ 煞气化泄：遇二黑五黄病符星到门到床，安放纯铜真六帝钱或开光铜葫芦泄土。', 65, 1495);

            // ========== 第六部：形峦形煞排查与天心戒言 ==========
            drawTianJiBanner(ctx, 1535, '第六部 · 形 峦 识 煞 与 天 心 戒 赋');
            ctx.font = '14px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.fillText('• 峦头识煞：窗外严防壁刀角、天斩缝、枪煞路冲与高压电塔，见煞宜安放山海镇遮挡；', 65, 1605);
            ctx.fillText('• 阴阳调和：阳气过盛则人暴躁，阴气过重则多暗疾，宜通风向阳、明堂宽阔为上；', 65, 1635);
            ctx.fillText('• 易圣古训：千尺为势，百尺为形；形吉气顺，百福骈臻。', 65, 1665);

            // 卷尾大师签章与天地赋
            ctx.textAlign = 'center';
            ctx.font = 'italic 16px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.fillStyle = '#666';
            ctx.fillText('“吉凶由人，积善之家必有余庆；理气顺天，天道酬勤。”', 450, 1770);

            // 绘制底部地师大印与防伪码
            drawAncientSeal(ctx, 750, 1870, '演象天机勘定吉局', 76, false);
            drawAncientSeal(ctx, 150, 1870, '天人合一', 58, true);

            ctx.fillStyle = '#777';
            ctx.font = '12px "STKaiti", "KaiTi", "SimSun", serif';
            ctx.textAlign = 'center';
            ctx.fillText(`演象时空罗盘 · 正统三元九运堪舆存证编号：YX-${new Date().getTime().toString().slice(-8)}`, 450, 1920);
            ctx.fillText(`本报告由演象天地罗盘算法引擎即时勘测生成 · 仅供人居环境规划与学术研讨参考`, 450, 1945);

            // 6. 导出图片并弹出预览弹窗
            try {
                const dataUrl = cvs.toDataURL('image/jpeg', 0.94);
                lastGeneratedTianJiDataUrl = dataUrl;
                const imgEl = document.getElementById('tianji-preview-img');
                if (imgEl) imgEl.src = dataUrl;
                toggleTianJiModal(true);
            } catch(e) {
                console.error('generateTianJiShu error:', e);
                alert('出图失败，请检查浏览器内存');
            }
        }
    '''

    # Place TianJi JS right before the closing </script>
    if "function generateTianJiShu" not in content:
        content = content.replace("    </script>", f"{tianji_js}\n    </script>")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Successfully injected TianJiShu engine into {file_path}, size: {len(content)} bytes")

if __name__ == "__main__":
    android_html = os.path.abspath("tiandi_luopan/app/src/main/assets/yiijing_map.html")
    ios_html = os.path.abspath("tiandi_luopan/ios/TiandiLuopan/www/index.html")
    update_file(android_html)
    update_file(ios_html)
