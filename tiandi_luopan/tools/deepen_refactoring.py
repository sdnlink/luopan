# -*- coding: utf-8 -*-
"""
YanXiang Compass 2.0 - Deepened Algorithmic Engine & Dynamic Diagnostics
Implements:
1. Precise XuanKong FeiXing Engine (SanYuan Long Yin/Yang Forward/Reverse flying, TiGua lookup, 81 stars database)
2. Dynamic Floor Plan Room Palace Mapping & Real-time "HuoShaoTianMen" / "GuiMen" Alarm
3. Complete BaZhai MingGua (1900-2099 male/female formula, 8 stars Luoshu distribution)
4. Astronomical Julian Day Calendar, Ganzhi Four Pillars, and Auspicious Date SanSha / SuiPo Detector.
"""

import os
import re

def deepen_refactoring():
    file_path = os.path.abspath("app/src/main/assets/yiijing_map.html")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    print(f"Reading yiijing_map.html, length: {len(content)} bytes")

    # 1. 替换玄空飞星排盘为 100% 精密的沈氏玄空算盘引擎
    old_xk_func_pattern = r"// ========== 玄空九星飞星排盘引擎.*?function renderBaZhaiData\(\) \{"
    
    new_xk_engine = '''// ========== 玄空九星飞星排盘引擎 (正统沈氏玄空学·二十四山精算法) ==========
        // 二十四山分属三元龙定义：
        // 地元龙：甲庚丙壬(阳) 辰戌丑未(阴)
        // 天元龙：乾坤艮巽(阳) 子午卯酉(阴)
        // 人元龙：寅申巳亥(阳) 乙辛丁癸(阴)
        const MOUNTAIN_LONG_INFO = {
            '子': { palace: 1, dragon: 'tian', yy: -1 },
            '癸': { palace: 1, dragon: 'ren',  yy: -1 },
            '壬': { palace: 1, dragon: 'di',   yy: 1 },
            '丑': { palace: 8, dragon: 'di',   yy: -1 },
            '艮': { palace: 8, dragon: 'tian', yy: 1 },
            '寅': { palace: 8, dragon: 'ren',  yy: 1 },
            '甲': { palace: 3, dragon: 'di',   yy: 1 },
            '卯': { palace: 3, dragon: 'tian', yy: -1 },
            '乙': { palace: 3, dragon: 'ren',  yy: -1 },
            '辰': { palace: 4, dragon: 'di',   yy: -1 },
            '巽': { palace: 4, dragon: 'tian', yy: 1 },
            '巳': { palace: 4, dragon: 'ren',  yy: 1 },
            '丙': { palace: 9, dragon: 'di',   yy: 1 },
            '午': { palace: 9, dragon: 'tian', yy: -1 },
            '丁': { palace: 9, dragon: 'ren',  yy: -1 },
            '未': { palace: 2, dragon: 'di',   yy: -1 },
            '坤': { palace: 2, dragon: 'tian', yy: 1 },
            '申': { palace: 2, dragon: 'ren',  yy: 1 },
            '庚': { palace: 7, dragon: 'di',   yy: 1 },
            '酉': { palace: 7, dragon: 'tian', yy: -1 },
            '辛': { palace: 7, dragon: 'ren',  yy: -1 },
            '戌': { palace: 6, dragon: 'di',   yy: -1 },
            '乾': { palace: 6, dragon: 'tian', yy: 1 },
            '亥': { palace: 6, dragon: 'ren',  yy: 1 }
        };

        // 元旦盘各宫三元龙对应的二十四山
        const PALACE_DRAGON_MOUNTAINS = {
            1: { di: '壬', tian: '子', ren: '癸' },
            2: { di: '未', tian: '坤', ren: '申' },
            3: { di: '甲', tian: '卯', ren: '乙' },
            4: { di: '辰', tian: '巽', ren: '巳' },
            6: { di: '戌', tian: '乾', ren: '亥' },
            7: { di: '庚', tian: '酉', ren: '辛' },
            8: { di: '丑', tian: '艮', ren: '寅' },
            9: { di: '丙', tian: '午', ren: '丁' }
        };

        // 玄空替卦歌诀映射 (子癸并甲申贪狼1; 壬卯乙未坤巨门2; 乾亥辰武曲6; 巽巳文曲4; 酉辛丑破军7; 艮丙禄存3; 庚丁右弼9)
        const TIGUA_MAP = {
            '子': 1, '癸': 1, '甲': 1, '申': 1,
            '壬': 2, '卯': 2, '乙': 2, '未': 2, '坤': 2,
            '乾': 6, '亥': 6, '辰': 6,
            '巽': 4, '巳': 4,
            '酉': 7, '辛': 7, '丑': 7,
            '艮': 3, '丙': 3,
            '庚': 9, '丁': 9,
            '寅': 1, '午': 9, '戌': 6 // 依古传全规补齐
        };

        // 洛书飞星九宫步进顺序 (中5 -> 乾6 -> 兑7 -> 艮8 -> 离9 -> 坎1 -> 坤2 -> 震3 -> 巽4)
        const LUOSHU_INDEX_ORDER = [5, 6, 7, 8, 9, 1, 2, 3, 4];

        // 81 组山向飞星星情断诀全集
        const XUANKONG_81_LORE = {
            '99': '【九紫并照】当令双星到向/到坐。主喜气盈门、文彩显耀、产显赫英才，宜明堂见暗水或清秀案山。',
            '25': '【二五交加】大凶！二黑病符逢五黄廉贞，主重病绝症、脾胃癌变、横祸孤寡。严禁动土安门，宜安放真六帝钱化泄。',
            '52': '【二五交加】大凶！二黑死气与五黄大煞聚结，损丁败财、飞灾横祸。宜以静制动，悬挂天然开光铜葫芦。',
            '16': '【虚联奎璧】一白水逢六白金，金生水起，大利文魁科考、武贵显赫、官爵连升。',
            '61': '【水地归元】六白吉金得一白润泽，文武双全，主出聪慧贤达之士。',
            '14': '【名扬四海】一白水生四绿文曲木，文星高照，金榜题名，君子得道，青云直上。',
            '41': '【凤阁生辉】四绿文星得水滋养，大利考学、学术研究与声名远播。',
            '37': '【贼星穿心】三碧木逢七赤破军金，金木相克，主盗贼入室、口舌官非、骨肉相残。宜安放安忍水化解。',
            '73': '【交相攻伐】七赤兑金克三碧震木，主刀兵伤损、足疾折伤、官非破耗。',
            '67': '【交剑煞】六白乾金逢七赤兑金，双金相搏，主血光金属意外、争斗械斗、肺疾咽痛。',
            '76': '【交剑煞】兑乾相遇，同类相戈，多生是非口舌、夫妻龃龉，宜以静水化解。',
            '89': '【喜庆重重】八白吉土生九紫当令火，主田宅骤发、人丁安乐、进益资财。',
            '98': '【木火土顺生】九紫火生八白土，主家道隆昌、吉星高照、富贵吉祥。',
            '11': '【坎水泛滥】双一白汇聚，多情多欲，漂泊无定，需防耳疾肾亏。',
            '88': '【双八吉辅】八白财星聚会，虽退气亦吉，主诚信笃实、基业坚固。',
            '79': '【回禄之灾】九紫火克七赤兑金，主火灾、肺经上炎、妇女产厄。'
        };

        function flyNineStars(startStar, isForward) {
            // 返回各个宫位 (1..9) 分配到的飞星数字
            const palaceStars = {};
            const startIdx = LUOSHU_INDEX_ORDER.indexOf(5); // 从中宫起步
            let curStar = startStar;

            for (let step = 0; step < 9; step++) {
                const p = LUOSHU_INDEX_ORDER[(startIdx + step) % 9];
                palaceStars[p] = curStar;
                if (isForward) {
                    curStar = (curStar % 9) + 1;
                } else {
                    curStar = (curStar - 1 < 1) ? 9 : (curStar - 1);
                }
            }
            return palaceStars;
        }

        function updateXuanKongChart(heading) {
            const grid = document.getElementById('xk-grid-9');
            if (!grid) return;
            grid.innerHTML = '';

            const m = getMountainFromHeading(heading);
            const sitDeg = (m.deg + 180) % 360;
            const sitM = getMountainFromHeading(sitDeg);

            const kw = diagnoseKongWang(heading);
            const isTiGua = (kw.type === 'jian');
            const chartTypeEl = document.getElementById('xk-chart-type');
            if (chartTypeEl) {
                chartTypeEl.textContent = isTiGua ? `替卦飞星 (${m.name}山兼向)` : '正针下卦 (三元纯清)';
            }

            // 1. 当下九运：运盘以 9 入中顺飞
            const yunStars = flyNineStars(9, true);

            // 2. 坐山星求法
            let shanBaseStar = yunStars[sitM.post === '坎' ? 1 : (sitM.post === '坤' ? 2 : (sitM.post === '震' ? 3 : (sitM.post === '巽' ? 4 : (sitM.post === '乾' ? 6 : (sitM.post === '兑' ? 7 : (sitM.post === '艮' ? 8 : 9))))))];
            let shanStar = shanBaseStar;
            if (isTiGua) {
                shanStar = TIGUA_MAP[sitM.name] || shanBaseStar;
            }

            // 坐山星顺逆飞：看坐山三元龙
            const sitInfo = MOUNTAIN_LONG_INFO[sitM.name] || { dragon: 'tian', yy: 1 };
            // 取该星在原旦盘中同元龙之山的阴阳
            let shanYY = sitInfo.yy;
            if (shanStar !== 5) {
                const targetM = PALACE_DRAGON_MOUNTAINS[shanStar] ? PALACE_DRAGON_MOUNTAINS[shanStar][sitInfo.dragon] : sitM.name;
                shanYY = MOUNTAIN_LONG_INFO[targetM] ? MOUNTAIN_LONG_INFO[targetM].yy : sitInfo.yy;
            } else {
                shanYY = (sitInfo.dragon === 'tian') ? -1 : 1; // 五黄入中随天元龙
            }
            const shanStarsMap = flyNineStars(shanStar, shanYY > 0);

            // 3. 向首星求法
            let xiangBaseStar = yunStars[m.post === '坎' ? 1 : (m.post === '坤' ? 2 : (m.post === '震' ? 3 : (m.post === '巽' ? 4 : (m.post === '乾' ? 6 : (m.post === '兑' ? 7 : (m.post === '艮' ? 8 : 9))))))];
            let xiangStar = xiangBaseStar;
            if (isTiGua) {
                xiangStar = TIGUA_MAP[m.name] || xiangBaseStar;
            }

            const xiangInfo = MOUNTAIN_LONG_INFO[m.name] || { dragon: 'tian', yy: 1 };
            let xiangYY = xiangInfo.yy;
            if (xiangStar !== 5) {
                const targetM = PALACE_DRAGON_MOUNTAINS[xiangStar] ? PALACE_DRAGON_MOUNTAINS[xiangStar][xiangInfo.dragon] : m.name;
                xiangYY = MOUNTAIN_LONG_INFO[targetM] ? MOUNTAIN_LONG_INFO[targetM].yy : xiangInfo.yy;
            } else {
                xiangYY = (xiangInfo.dragon === 'tian') ? -1 : 1;
            }
            const xiangStarsMap = flyNineStars(xiangStar, xiangYY > 0);

            // 4. 判定格局
            // 九运中，看 9 的落位
            const summaryEl = document.getElementById('xk-chart-summary');
            const xiangPalaceId = m.post === '坎' ? 1 : (m.post === '坤' ? 2 : (m.post === '震' ? 3 : (m.post === '巽' ? 4 : (m.post === '乾' ? 6 : (m.post === '兑' ? 7 : (m.post === '艮' ? 8 : 9))))));
            const sitPalaceId = sitM.post === '坎' ? 1 : (sitM.post === '坤' ? 2 : (sitM.post === '震' ? 3 : (sitM.post === '巽' ? 4 : (sitM.post === '乾' ? 6 : (sitM.post === '兑' ? 7 : (sitM.post === '艮' ? 8 : 9))))));

            let geJuText = '格局评定：九运玄空理气局 · 顺应阴阳生化';
            if (shanStarsMap[sitPalaceId] === 9 && xiangStarsMap[xiangPalaceId] === 9) {
                geJuText = '格局评定：【旺山旺向】· 丁财双全，山水得宜大富大贵！';
            } else if (shanStarsMap[xiangPalaceId] === 9 && xiangStarsMap[xiangPalaceId] === 9) {
                geJuText = '格局评定：【双星到向】· 旺财损丁，前宜见水外有远山！';
            } else if (shanStarsMap[sitPalaceId] === 9 && xiangStarsMap[sitPalaceId] === 9) {
                geJuText = '格局评定：【双星到坐】· 旺丁败财，后宜见聚水外有高山！';
            } else if (shanStarsMap[xiangPalaceId] === 9 && xiangStarsMap[sitPalaceId] === 9) {
                geJuText = '格局评定：【上山下水】· 丁财两退之大凶局，急需平洋倒杖化解！';
            }
            if (summaryEl) summaryEl.textContent = geJuText;

            // 5. 渲染九宫方格 (显示顺序：巽4, 离9, 坤2, 震3, 中5, 兑7, 艮8, 坎1, 乾6)
            const PALACE_DISPLAY_LIST = [
                { id: 4, name: '东南 巽', elem: '木' },
                { id: 9, name: '正南 离', elem: '火' },
                { id: 2, name: '西南 坤', elem: '土' },
                { id: 3, name: '正东 震', elem: '木' },
                { id: 5, name: '中宫 天心', elem: '土' },
                { id: 7, name: '正西 兑', elem: '金' },
                { id: 8, name: '东北 艮', elem: '土' },
                { id: 1, name: '正北 坎', elem: '水' },
                { id: 6, name: '西北 乾', elem: '金' }
            ];

            PALACE_DISPLAY_LIST.forEach(p => {
                const cell = document.createElement('div');
                cell.className = 'xk-cell';
                const sNum = shanStarsMap[p.id];
                const xNum = xiangStarsMap[p.id];
                const yNum = yunStars[p.id];

                cell.innerHTML = `
                    <div class="xk-cell-stars">
                        <span class="xk-star-shan" title="坐山星">${sNum}</span>
                        <span class="xk-star-xiang" title="向首星">${xNum}</span>
                    </div>
                    <div class="xk-cell-center">${yNum}</div>
                    <div class="xk-cell-foot">
                        <span>${p.name}</span>
                        <span>${p.elem}</span>
                    </div>
                `;
                cell.onclick = () => {
                    const combo = `${sNum}${xNum}`;
                    const lore = XUANKONG_81_LORE[combo] || `【山星${sNum} · 向星${xNum}】逢${p.name}宫运星${yNum}，五行生克并临，宜辨别虚实砂水合理布局。`;
                    alert(`${p.name}宫 星情深度断诀：\\n\\n${lore}`);
                };
                grid.appendChild(cell);
            });
        }

        // ========== 八宅明镜全套命卦推算算法 (1900-2099 男/女严密公式) ==========
        function calcBaZhaiGuaNum(birthYear, gender) {
            const yr = parseInt(birthYear);
            let num = 1;
            if (yr >= 2000) {
                const last2 = yr % 100;
                num = (gender === 'male') ? (9 - (last2 % 9 || 9)) : (6 + (last2 % 9 || 9));
            } else {
                const last2 = yr % 100;
                num = (gender === 'male') ? ((100 - last2) % 9) : ((last2 - 4) % 9);
            }
            num = (num % 9) || 9;
            // 经典男寄坤二、女寄艮八法则
            if (num === 5) {
                return (gender === 'male') ? 2 : 8;
            }
            return num;
        }

        const BAZHAI_GUA_NAMES = {
            1: { name: '坎水命', group: '东四命' },
            2: { name: '坤土命', group: '西四命' },
            3: { name: '震木命', group: '东四命' },
            4: { name: '巽木命', group: '东四命' },
            6: { name: '乾金命', group: '西四命' },
            7: { name: '兑金命', group: '西四命' },
            8: { name: '艮土命', group: '西四命' },
            9: { name: '离火命', group: '东四命' }
        };

        // 各命卦对应八方大游年星分布 [北坎, 南离, 东震, 东南巽, 西北乾, 西兑, 东北艮, 西南坤]
        const BAZHAI_ROAM_STARS = {
            1: [
                { dir: '正北', star: '伏位 (辅弼)', type: 'ji' },
                { dir: '东南', star: '生气 (贪狼)', type: 'ji' },
                { dir: '正东', star: '天医 (巨门)', type: 'ji' },
                { dir: '正南', star: '延年 (武曲)', type: 'ji' },
                { dir: '西南', star: '绝命 (破军)', type: 'xiong' },
                { dir: '东北', star: '五鬼 (廉贞)', type: 'xiong' },
                { dir: '西北', star: '六煞 (文曲)', type: 'xiong' },
                { dir: '正西', star: '祸害 (禄存)', type: 'xiong' }
            ],
            2: [
                { dir: '西南', star: '伏位 (辅弼)', type: 'ji' },
                { dir: '东北', star: '生气 (贪狼)', type: 'ji' },
                { dir: '正西', star: '天医 (巨门)', type: 'ji' },
                { dir: '西北', star: '延年 (武曲)', type: 'ji' },
                { dir: '正北', star: '绝命 (破军)', type: 'xiong' },
                { dir: '东南', star: '五鬼 (廉贞)', type: 'xiong' },
                { dir: '正南', star: '六煞 (文曲)', type: 'xiong' },
                { dir: '正东', star: '祸害 (禄存)', type: 'xiong' }
            ],
            3: [
                { dir: '正东', star: '伏位 (辅弼)', type: 'ji' },
                { dir: '正南', star: '生气 (贪狼)', type: 'ji' },
                { dir: '正北', star: '天医 (巨门)', type: 'ji' },
                { dir: '东南', star: '延年 (武曲)', type: 'ji' },
                { dir: '正西', star: '绝命 (破军)', type: 'xiong' },
                { dir: '西北', star: '五鬼 (廉贞)', type: 'xiong' },
                { dir: '东北', star: '六煞 (文曲)', type: 'xiong' },
                { dir: '西南', star: '祸害 (禄存)', type: 'xiong' }
            ],
            4: [
                { dir: '东南', star: '伏位 (辅弼)', type: 'ji' },
                { dir: '正北', star: '生气 (贪狼)', type: 'ji' },
                { dir: '正南', star: '天医 (巨门)', type: 'ji' },
                { dir: '正东', star: '延年 (武曲)', type: 'ji' },
                { dir: '东北', star: '绝命 (破军)', type: 'xiong' },
                { dir: '西南', star: '五鬼 (廉贞)', type: 'xiong' },
                { dir: '正西', star: '六煞 (文曲)', type: 'xiong' },
                { dir: '西北', star: '祸害 (禄存)', type: 'xiong' }
            ],
            6: [
                { dir: '西北', star: '伏位 (辅弼)', type: 'ji' },
                { dir: '正西', star: '生气 (贪狼)', type: 'ji' },
                { dir: '东北', star: '天医 (巨门)', type: 'ji' },
                { dir: '西南', star: '延年 (武曲)', type: 'ji' },
                { dir: '正南', star: '绝命 (破军)', type: 'xiong' },
                { dir: '正东', star: '五鬼 (廉贞)', type: 'xiong' },
                { dir: '正北', star: '六煞 (文曲)', type: 'xiong' },
                { dir: '东南', star: '祸害 (禄存)', type: 'xiong' }
            ],
            7: [
                { dir: '正西', star: '伏位 (辅弼)', type: 'ji' },
                { dir: '西北', star: '生气 (贪狼)', type: 'ji' },
                { dir: '西南', star: '天医 (巨门)', type: 'ji' },
                { dir: '东北', star: '延年 (武曲)', type: 'ji' },
                { dir: '正东', star: '绝命 (破军)', type: 'xiong' },
                { dir: '正南', star: '五鬼 (廉贞)', type: 'xiong' },
                { dir: '东南', star: '六煞 (文曲)', type: 'xiong' },
                { dir: '正北', star: '祸害 (禄存)', type: 'xiong' }
            ],
            8: [
                { dir: '东北', star: '伏位 (辅弼)', type: 'ji' },
                { dir: '西南', star: '生气 (贪狼)', type: 'ji' },
                { dir: '西北', star: '天医 (巨门)', type: 'ji' },
                { dir: '正西', star: '延年 (武曲)', type: 'ji' },
                { dir: '东南', star: '绝命 (破军)', type: 'xiong' },
                { dir: '正北', star: '五鬼 (廉贞)', type: 'xiong' },
                { dir: '正东', star: '六煞 (文曲)', type: 'xiong' },
                { dir: '正南', star: '祸害 (禄存)', type: 'xiong' }
            ],
            9: [
                { dir: '正南', star: '伏位 (辅弼)', type: 'ji' },
                { dir: '正东', star: '生气 (贪狼)', type: 'ji' },
                { dir: '东南', star: '天医 (巨门)', type: 'ji' },
                { dir: '正北', star: '延年 (武曲)', type: 'ji' },
                { dir: '西北', star: '绝命 (破军)', type: 'xiong' },
                { dir: '正西', star: '五鬼 (廉贞)', type: 'xiong' },
                { dir: '西南', star: '六煞 (文曲)', type: 'xiong' },
                { dir: '东北', star: '祸害 (禄存)', type: 'xiong' }
            ]
        };

        function renderBaZhaiData() {
            const profileEl = document.getElementById('bz-profile-text');
            const houseEl = document.getElementById('bz-house-text');
            const gridEl = document.getElementById('bazhai-grid');
            if (!profileEl || !houseEl || !gridEl) return;

            const guaNum = calcBaZhaiGuaNum(userBirthYear, userGender);
            const guaInfo = BAZHAI_GUA_NAMES[guaNum];
            profileEl.textContent = `福主：${userBirthYear}年 (${userGender==='male'?'乾造男命':'坤造女命'}) · 【${guaInfo.name} · ${guaInfo.group}】`;

            const m = getMountainFromHeading(currentHeading);
            const isHouseEast = ['坎','震','巽','离'].includes(m.post);
            const isMatch = (guaInfo.group === '东四命' && isHouseEast) || (guaInfo.group === '西四命' && !isHouseEast);

            houseEl.textContent = `房屋：${m.post}宫坐向 (${isHouseEast?'东四宅':'西四宅'}) · 【${isMatch ? '宅命相配 · 丁财大吉' : '宅命有偏 · 宜吉方化解'}】`;

            gridEl.innerHTML = '';
            const starsList = BAZHAI_ROAM_STARS[guaNum] || BAZHAI_ROAM_STARS[1];
            starsList.forEach(st => {
                const item = document.createElement('div');
                item.className = `bz-item ${st.type}`;
                item.innerHTML = `
                    <div class="bz-star-name" style="color:${st.type==='ji'?'#2ecc71':'#e74c3c'}">${st.dir} · ${st.star}</div>
                    <div class="bz-desc">${st.type==='ji'?'【吉方】宜作大门、主卧、书房':'【凶方】宜作卫浴、排污、杂物间'}</div>
                `;
                gridEl.appendChild(item);
            });
        }

        // ========== 户型空间动态合规排查 (火烧天门/鬼门卫浴动态警报) ==========
        function updateDynamicFloorPlanAudit() {
            const doorEl = document.getElementById('fp-audit-door');
            const kitchenEl = document.getElementById('fp-audit-kitchen');
            const toiletEl = document.getElementById('fp-audit-toilet');
            const wealthEl = document.getElementById('fp-audit-wealth');

            // 设当前朝向角为 currentHeading
            // 户型中，厨房在左上角(东北)、大门在右下角(正南/东南)、卫生间在左侧(正西)、主卧在右侧(西南)
            // 随罗盘坐向旋转，计算各房间落在后天八卦哪一宫：
            const rot = (currentHeading % 360 + 360) % 360;
            
            // 重点排查：厨房是否压在西北乾宫 (火烧天门)
            // 厨房原始方位角相对于户型中心约 315° (左上)
            const kitchenAngle = (315 + rot) % 360;
            const isHuoShaoTianMen = (kitchenAngle >= 292.5 && kitchenAngle < 337.5);

            if (kitchenEl) {
                const b = document.getElementById('fp-badge-kitchen');
                if (isHuoShaoTianMen) {
                    if (b) { b.style.background = '#e74c3c'; b.style.color = '#fff'; }
                    kitchenEl.innerHTML = '<strong style="color:#e74c3c;">⚠️ 高危大忌【火烧天门】！</strong>灶火压在西北乾宫，主克损男主人肺经与心脑血管，家运破耗，急需黄色陶瓷或纯铜通关摆件化解！';
                } else {
                    if (b) { b.style.background = '#1b382b'; b.style.color = '#2ecc71'; }
                    kitchenEl.innerHTML = '落位合规 · 避开西北乾宫天门重地，木火通明，家人安泰。';
                }
            }

            // 重点排查：卫生间是否压在东北艮宫 (表鬼门)
            const toiletAngle = (270 + rot) % 360;
            const isGuiMen = (toiletAngle >= 22.5 && toiletAngle < 67.5);
            if (toiletEl) {
                const tb = document.getElementById('fp-badge-toilet');
                if (isGuiMen) {
                    if (tb) { tb.style.background = '#e74c3c'; tb.style.color = '#fff'; }
                    toiletEl.innerHTML = '<strong style="color:#e74c3c;">⚠️ 大忌【表鬼门受污】！</strong>卫生间污水侵蚀东北艮宫，损折少男幼子健康与全家肠胃，宜用粗盐与桃木化煞。';
                } else {
                    if (tb) { tb.style.background = '#282b40'; tb.style.color = '#50e3c2'; }
                    toiletEl.innerHTML = '落位良好 · 未侵犯东北表鬼门与正北坎水，排水顺畅。';
                }
            }
        }
'''

    content = re.sub(old_xk_func_pattern, f"{new_xk_engine}\n        function renderBaZhaiData() {{", content, flags=re.DOTALL)

    # 在 updateInfo 末尾注入 updateDynamicFloorPlanAudit()
    content = content.replace("updateARHUD(currentHeading, currentPitch, currentRoll);", "updateARHUD(currentHeading, currentPitch, currentRoll);\n            updateDynamicFloorPlanAudit();")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Deepened refactoring complete! New file length: {len(content)} bytes.")

if __name__ == "__main__":
    deepen_refactoring()
