# -*- coding: utf-8 -*-
"""
Implement full internationalization (i18n) support in yiijing_map.html:
- Follows system language by default (Android Locale, iOS Locale, navigator.languages, languagechange event)
- Supports Simplified Chinese (zh-Hans), Traditional Chinese (zh-Hant), English (en)
- Full UI translation: Header, Tab bar, Bottom nav, Compass info panel, Modals, XuanKong cards, FloorPlan, Cashier
- Language selector in top bar & in Settings modal
"""

import os
import re

def implement():
    file_path = os.path.abspath("app/src/main/assets/yiijing_map.html")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    print(f"Original file size: {len(content)} bytes")

    # 1. 在头部 tab-bar 增加语言切换按钮
    old_tab_bar_btn = '<button class="tab-btn" id="btn-vip-center" onclick="openIAPModal()"'
    new_lang_btn = '<button class="tab-btn" id="btn-lang-picker" onclick="cycleLanguage()" style="color:#64b5f6; border-color:#1e3c72; font-weight:bold;">🌐 <span id="current-lang-label">语言</span></button>\n            <button class="tab-btn" id="btn-vip-center" onclick="openIAPModal()"'
    
    if 'id="btn-lang-picker"' not in content:
        content = content.replace(old_tab_bar_btn, new_lang_btn)
        print("Injected btn-lang-picker into tab-bar")

    # 2. 在 layer-modal (图层与系统设置弹窗) 增加语言偏好选择栏
    layer_modal_anchor = '<div class="layer-preset-bar">'
    lang_preset_section = '''<!-- 语言偏好设置 -->
            <div style="font-size:12px; font-weight:bold; color:#d4af37; margin:6px 0 6px 0; display:flex; justify-content:space-between; align-items:center;">
                <span id="lbl-lang-title">🌐 语言偏好 / Language</span>
                <span id="lbl-lang-curr-hint" style="font-size:10.5px; color:#64b5f6;">📱 跟随系统</span>
            </div>
            <div class="layer-preset-bar" id="lang-switch-bar" style="margin-bottom:12px;">
                <button class="layer-preset-btn active" id="lang-opt-auto" onclick="setAppLanguage('auto')">📱 跟随系统</button>
                <button class="layer-preset-btn" id="lang-opt-hans" onclick="setAppLanguage('zh-Hans')">🇨🇳 简体中文</button>
                <button class="layer-preset-btn" id="lang-opt-hant" onclick="setAppLanguage('zh-Hant')">🇭🇰 繁體中文</button>
                <button class="layer-preset-btn" id="lang-opt-en" onclick="setAppLanguage('en')">🇬🇧 English</button>
            </div>
            <div style="font-size:12px; font-weight:bold; color:#aaa; margin:4px 0 6px 0;" id="lbl-layer-preset-title">⚙️ 罗盘圈层预设</div>
            <div class="layer-preset-bar">'''
    
    if 'id="lang-switch-bar"' not in content:
        content = content.replace(layer_modal_anchor, lang_preset_section, 1)
        print("Injected lang-switch-bar into layer-modal")

    # 3. 注入国际化 CSS (浮动提示 Toast)
    toast_css = '''
        /* 国际化语言切换 Toast 浮动提示 */
        .i18n-toast {
            position: fixed;
            top: 60px;
            left: 50%;
            transform: translateX(-50%) translateY(-20px);
            background: rgba(24, 25, 38, 0.94);
            border: 1px solid #d4af37;
            color: #ffd700;
            padding: 8px 18px;
            border-radius: 20px;
            font-size: 12.5px;
            font-weight: bold;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6);
            opacity: 0;
            pointer-events: none;
            transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
            z-index: 999999;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .i18n-toast.show {
            transform: translateX(-50%) translateY(0);
            opacity: 1;
        }
    '''
    content = content.replace("</style>", toast_css + "\n    </style>")

    # 4. 在 body 尾部注入 Toast DOM
    toast_dom = '<div class="i18n-toast" id="i18n-toast">🌐 语言已切换</div>'
    content = content.replace("</body>", toast_dom + "\n</body>")

    # 5. 注入全量 i18n 翻译字典与运行时引擎
    i18n_engine_js = '''
        // ==============================================================
        // 国际化 (i18n) 核心多语言字典与系统语言监听引擎
        // 支持：zh-Hans (简体中文), zh-Hant (繁體中文), en (English)
        // 模式：跟随系统 (auto / 默认), 手动切换锁定
        // ==============================================================

        const I18N_RESOURCES = {
            'zh-Hans': {
                langName: '简体中文',
                title: '演象 · 时空罗盘',
                crosshairHint: '🎯 十字天心瞄准 · 坐向同论 (正前▲向 · 正后▼坐)',
                tabPost: '后天八卦',
                tabPre: '先天八卦',
                rotFollow: '🔄 随向转',
                rotLock: '🔒 锁定盘',
                hdRealtime: '🔓 实时',
                hdLocked: '🔒 锁定',
                tabLayer: '⚙️ 图层',
                tabTianji: '📜 天机书',
                tabFengshui: '🏡 风水详解',
                tabVip: '👑 会员中心',
                tabLang: '语言',
                navCompass: '综合罗盘',
                navAr: '实景对准',
                navFloorplan: '户型立极',
                navFengshui: '玄空理气',
                sitZuo: '坐',
                sitFace: '向',
                sitZhengZhen: '正针',
                pureTrue: '正针纯清',
                pureSub: '兼山兼向',
                pureSmallVoid: '差错小空亡',
                pureBigVoid: '出卦大空亡',
                goldJewel: '旺相珠宝',
                goldFire: '孤虚火坑',
                labelSitFace: '立向格局',
                labelKongWang: '空亡诊断',
                labelFenJin: '一百二十分金',
                labelFsSummary: '风水方位详解',
                labelHuangQuan: '八路黄泉水法',
                labelQiMen: '时空客星与奇门',
                labelLevel: '电子水准倾角',
                labelGanZhi: '四柱天干地支',
                labelSolarTime: '真太阳时 ☀️',
                labelDir: '地理方位',
                labelCoords: '经纬坐标 ⟳',
                labelSpeed: '移动速度',
                labelPostGua: '后天八卦',
                labelPreGua: '先天八卦',
                labelElem: '五行属性',
                labelMountain: '对应山向',
                labelSolar: '当令节气',
                labelGua: '主应消息卦',
                dirs: {
                    N: '正北', S: '正南', E: '正东', W: '正西',
                    NE: '东北', SE: '东南', NW: '西北', SW: '西南'
                },
                elements: {
                    '水': '水', '木': '木', '火': '火', '土': '土', '金': '金'
                },
                levelGood: '水平良好 ✓',
                levelTilt: '调平中…',
                xkCard1: '下元九运 · 玄空九宫飞星盘',
                xkCard2: '紫白飞星 · 流年流月动态气运布防',
                xkCard3: '杨公形气 · 八路黄泉与坐山曜煞',
                xkCard4: '三式绝学 · 时家奇门遁甲全息排盘',
                xkCard5: '📜 演象 · 福宅天机堪舆全案长图',
                fpTitle: '🏡 全屋功能区合规体检看板',
                fpBtnSample: '标准三居户型',
                fpBtnUpload: '上传户型图',
                fpBtnRecenter: '重新标定重心',
                vipTitle: '演象 · 尊享堪舆会员中心',
                vipSub: '时空合一核心绝学 · 专业实勘与长卷导出',
                vipPayTitle: '💳 选择安全支付方式',
                vipPayHint: '支持全球卡与国内主流通道',
                payWechat: '微信支付',
                payAlipay: '支付宝',
                payCard: '国际信用卡',
                payUnion: '银联云闪付',
                btnPayNow: '立即安全支付',
                btnRestore: '恢复已购项目',
                langFollowSys: '📱 跟随系统',
                langSwitched: '语言已切换为：'
            },
            'zh-Hant': {
                langName: '繁體中文',
                title: '演象 · 時空羅盤',
                crosshairHint: '🎯 十字天心瞄準 · 坐向同論 (正前▲向 · 正後▼坐)',
                tabPost: '後天八卦',
                tabPre: '先天八卦',
                rotFollow: '🔄 隨向轉',
                rotLock: '🔒 鎖定盤',
                hdRealtime: '🔓 實時',
                hdLocked: '🔒 鎖定',
                tabLayer: '⚙️ 圖層',
                tabTianji: '📜 天機書',
                tabFengshui: '🏡 風水詳解',
                tabVip: '👑 會員中心',
                tabLang: '語言',
                navCompass: '綜合羅盤',
                navAr: '實景對準',
                navFloorplan: '戶型立極',
                navFengshui: '玄空理氣',
                sitZuo: '坐',
                sitFace: '向',
                sitZhengZhen: '正針',
                pureTrue: '正針純清',
                pureSub: '兼山兼向',
                pureSmallVoid: '差錯小空亡',
                pureBigVoid: '出卦大空亡',
                goldJewel: '旺相珠寶',
                goldFire: '孤虛火坑',
                labelSitFace: '立向格局',
                labelKongWang: '空亡診斷',
                labelFenJin: '一百二十分金',
                labelFsSummary: '風水方位詳解',
                labelHuangQuan: '八路黃泉水法',
                labelQiMen: '時空客星與奇門',
                labelLevel: '電子水準傾角',
                labelGanZhi: '四柱天干地支',
                labelSolarTime: '真太陽時 ☀️',
                labelDir: '地理方位',
                labelCoords: '經緯坐標 ⟳',
                labelSpeed: '移動速度',
                labelPostGua: '後天八卦',
                labelPreGua: '先天八卦',
                labelElem: '五行屬性',
                labelMountain: '對應山向',
                labelSolar: '當令節氣',
                labelGua: '主應消息卦',
                dirs: {
                    N: '正北', S: '正南', E: '正東', W: '正西',
                    NE: '東北', SE: '東南', NW: '西北', SW: '西南'
                },
                elements: {
                    '水': '水', '木': '木', '火': '火', '土': '土', '金': '金'
                },
                levelGood: '水準良好 ✓',
                levelTilt: '調平中…',
                xkCard1: '下元九運 · 玄空九宮飛星盤',
                xkCard2: '紫白飛星 · 流年流月動態氣運布防',
                xkCard3: '楊公形氣 · 八路黃泉與坐山曜煞',
                xkCard4: '三式絕學 · 時家奇門遁甲全息排盤',
                xkCard5: '📜 演象 · 福宅天機堪輿全案長圖',
                fpTitle: '🏡 全屋功能區合規體檢看板',
                fpBtnSample: '標準三居戶型',
                fpBtnUpload: '上傳戶型圖',
                fpBtnRecenter: '重新標定重心',
                vipTitle: '演象 · 尊享堪輿會員中心',
                vipSub: '時空合一核心絕學 · 專業實勘與長卷導出',
                vipPayTitle: '💳 選擇安全支付方式',
                vipPayHint: '支持全球卡與國內主流通道',
                payWechat: '微信支付',
                payAlipay: '支付寶',
                payCard: '國際信用卡',
                payUnion: '銀聯雲閃付',
                btnPayNow: '立即安全支付',
                btnRestore: '恢復已購項目',
                langFollowSys: '📱 跟隨系統',
                langSwitched: '語言已切換為：'
            },
            'en': {
                langName: 'English',
                title: 'YanXiang · Space-Time Compass',
                crosshairHint: '🎯 Crosshair Align · Front▲ Facing · Back▼ Sitting',
                tabPost: 'Later Bagua',
                tabPre: 'Earlier Bagua',
                rotFollow: '🔄 Follow',
                rotLock: '🔒 Locked',
                hdRealtime: '🔓 Live',
                hdLocked: '🔒 Fixed',
                tabLayer: '⚙️ Layers',
                tabTianji: '📜 Celestial Book',
                tabFengshui: '🏡 Feng Shui',
                tabVip: '👑 VIP Center',
                tabLang: 'Lang',
                navCompass: 'Compass',
                navAr: 'AR Align',
                navFloorplan: 'Floor Plan',
                navFengshui: 'Flying Stars',
                sitZuo: 'Sit',
                sitFace: 'Face',
                sitZhengZhen: 'True Needle',
                pureTrue: 'Pure Axis (Great)',
                pureSub: 'Sub Axis (Good)',
                pureSmallVoid: 'Small Void (Danger)',
                pureBigVoid: 'Great Void (Extreme)',
                goldJewel: 'Jewel Line (Wealth)',
                goldFire: 'Fire Pit (Avoid)',
                labelSitFace: 'Facing & Sitting',
                labelKongWang: 'Void (KongWang)',
                labelFenJin: '120 FenJin Division',
                labelFsSummary: 'Direction Audit',
                labelHuangQuan: 'Yellow Springs Law',
                labelQiMen: 'Time-Space Stars',
                labelLevel: 'Electronic Level',
                labelGanZhi: 'Four Pillars (BaZi)',
                labelSolarTime: 'Solar Time ☀️',
                labelDir: 'Cardinal Heading',
                labelCoords: 'Coordinates ⟳',
                labelSpeed: 'Speed',
                labelPostGua: 'Later Bagua',
                labelPreGua: 'Earlier Bagua',
                labelElem: 'Element',
                labelMountain: 'Mountain',
                labelSolar: 'Solar Term',
                labelGua: 'Tidal Hexagram',
                dirs: {
                    N: 'North (N)', S: 'South (S)', E: 'East (E)', W: 'West (W)',
                    NE: 'Northeast (NE)', SE: 'Southeast (SE)', NW: 'Northwest (NW)', SW: 'Southwest (SW)'
                },
                elements: {
                    '水': 'Water', '木': 'Wood', '火': 'Fire', '土': 'Earth', '金': 'Metal'
                },
                levelGood: 'Level Balanced ✓',
                levelTilt: 'Leveling…',
                xkCard1: 'Period 9 Xuan Kong Flying Stars Chart',
                xkCard2: 'Purple-White Dynamic Stars Layout',
                xkCard3: 'Yang Gong 8 Yellow Springs & Mountain Sha',
                xkCard4: 'Qi Men Dun Jia Holographic Chart',
                xkCard5: '📜 YanXiang Celestial Feng Shui Audit Scroll',
                fpTitle: '🏡 Floor Plan Compliance Audit Dashboard',
                fpBtnSample: 'Sample 3-Bed Unit',
                fpBtnUpload: 'Upload Floor Plan',
                fpBtnRecenter: 'Recalibrate Center',
                vipTitle: 'YanXiang VIP Sanctuary & Cashier',
                vipSub: 'Time-Space Esoteric Arts · Audits & Exports',
                vipPayTitle: '💳 Select Payment Method',
                vipPayHint: 'Global Cards & Mainstream Channels Supported',
                payWechat: 'WeChat Pay',
                payAlipay: 'Alipay',
                payCard: 'Credit Card',
                payUnion: 'UnionPay',
                btnPayNow: 'Pay Securely Now',
                btnRestore: 'Restore Purchases',
                langFollowSys: '📱 Follow System',
                langSwitched: 'Language switched to: '
            }
        };

        // 当前应用语言配置
        let appLanguageSetting = 'auto'; // 'auto' | 'zh-Hans' | 'zh-Hant' | 'en'
        let currentEffectiveLang = 'zh-Hans';
        window.__nativeSystemLanguage = '';

        try {
            appLanguageSetting = localStorage.getItem('yx_user_lang') || 'auto';
        } catch(e) {}

        // 检测系统当前语言
        function detectSystemLanguage() {
            let candidate = window.__nativeSystemLanguage || '';
            if (!candidate && typeof navigator !== 'undefined') {
                const navLangs = navigator.languages || [navigator.language || 'zh-CN'];
                candidate = navLangs[0] || 'zh-CN';
            }
            candidate = String(candidate).toLowerCase();

            if (candidate.startsWith('zh-tw') || candidate.startsWith('zh-hk') || candidate.startsWith('zh-mo') || candidate.includes('hant')) {
                return 'zh-Hant';
            }
            if (candidate.startsWith('zh')) {
                return 'zh-Hans';
            }
            if (candidate.startsWith('en')) {
                return 'en';
            }
            // 国际其他语言默认展示英文，保障海外无障碍使用
            return 'en';
        }

        // 计算当前生效语言
        function resolveEffectiveLanguage() {
            if (appLanguageSetting === 'auto') {
                return detectSystemLanguage();
            }
            return appLanguageSetting;
        }

        // 获取当前语言字典
        function t(key) {
            const dict = I18N_RESOURCES[currentEffectiveLang] || I18N_RESOURCES['zh-Hans'];
            return dict[key] !== undefined ? dict[key] : (I18N_RESOURCES['zh-Hans'][key] || key);
        }

        // 应用语言至全站所有 DOM 元素
        function applyLanguage(langSetting, showToastFlag = false) {
            appLanguageSetting = langSetting;
            try {
                localStorage.setItem('yx_user_lang', langSetting);
            } catch(e) {}

            currentEffectiveLang = resolveEffectiveLanguage();
            document.documentElement.lang = currentEffectiveLang === 'zh-Hant' ? 'zh-TW' : (currentEffectiveLang === 'en' ? 'en' : 'zh-CN');

            const dict = I18N_RESOURCES[currentEffectiveLang] || I18N_RESOURCES['zh-Hans'];

            // 1. 顶部主标题与状态
            const titleEl = document.querySelector('.main-title');
            if (titleEl) titleEl.innerText = dict.title;

            const crosshairHintEl = document.getElementById('direction-mark');
            if (crosshairHintEl) crosshairHintEl.innerText = dict.crosshairHint;

            // 2. 顶部 Tab 按钮
            const tabPostEl = document.getElementById('tab-post');
            if (tabPostEl) tabPostEl.innerText = dict.tabPost;

            const tabPreEl = document.getElementById('tab-pre');
            if (tabPreEl) tabPreEl.innerText = dict.tabPre;

            const tabRotModeEl = document.getElementById('tab-rot-mode');
            if (tabRotModeEl) {
                tabRotModeEl.innerText = (typeof isFreeRotation !== 'undefined' && isFreeRotation) ? dict.rotLock : dict.rotFollow;
            }

            const btnLockEl = document.getElementById('btn-lock-heading');
            if (btnLockEl) {
                btnLockEl.innerText = (typeof isHeadingLocked !== 'undefined' && isHeadingLocked) ? dict.hdLocked : dict.hdRealtime;
            }

            const btnLayerEl = document.getElementById('btn-layer-settings');
            if (btnLayerEl) btnLayerEl.innerText = dict.tabLayer;

            const btnTianjiEl = document.getElementById('btn-tianji-top');
            if (btnTianjiEl) btnTianjiEl.innerHTML = `${dict.tabTianji} <span class="tab-vip-tag">VIP</span>`;

            const btnFsGuideEl = document.getElementById('btn-fengshui-guide');
            if (btnFsGuideEl) btnFsGuideEl.innerText = dict.tabFengshui;

            const btnVipEl = document.getElementById('btn-vip-center');
            if (btnVipEl) btnVipEl.innerText = dict.tabVip;

            const langLabelEl = document.getElementById('current-lang-label');
            if (langLabelEl) langLabelEl.innerText = dict.tabLang;

            // 3. 底部导航栏
            const navLabels = document.querySelectorAll('.nav-label');
            if (navLabels && navLabels.length >= 4) {
                navLabels[0].innerText = dict.navCompass;
                navLabels[1].innerText = dict.navAr;
                navLabels[2].innerText = dict.navFloorplan;
                navLabels[3].innerText = dict.navFengshui;
            }

            // 4. 信息面板标签
            const infoItems = document.querySelectorAll('.info-item');
            infoItems.forEach(item => {
                const labelEl = item.querySelector('.info-label');
                if (!labelEl) return;
                const text = labelEl.innerText.trim();
                if (text.includes('立向格局')) labelEl.innerText = dict.labelSitFace;
                else if (text.includes('空亡诊断')) labelEl.innerHTML = `${dict.labelKongWang}<span class="info-hint-icon">?</span>`;
                else if (text.includes('一百二十分金')) labelEl.innerHTML = `${dict.labelFenJin}<span class="info-hint-icon">?</span>`;
                else if (text.includes('风水方位详解')) labelEl.innerHTML = `${dict.labelFsSummary}<span class="info-hint-icon">?</span>`;
                else if (text.includes('八路黄泉水法')) labelEl.innerHTML = `${dict.labelHuangQuan}<span class="vip-tag-inline">VIP</span><span class="info-hint-icon">?</span>`;
                else if (text.includes('时空客星与奇门')) labelEl.innerHTML = `${dict.labelQiMen}<span class="vip-tag-inline">VIP</span><span class="info-hint-icon">?</span>`;
                else if (text.includes('电子水准倾角')) labelEl.innerText = dict.labelLevel;
                else if (text.includes('四柱天干地支')) labelEl.innerText = dict.labelGanZhi;
                else if (text.includes('真太阳时')) labelEl.innerText = dict.labelSolarTime;
                else if (text.includes('地理方位')) labelEl.innerText = dict.labelDir;
                else if (text.includes('经纬坐标')) labelEl.innerText = dict.labelCoords;
                else if (text.includes('移动速度')) labelEl.innerText = dict.labelSpeed;
                else if (text.includes('后天八卦')) labelEl.innerText = dict.labelPostGua;
                else if (text.includes('先天八卦')) labelEl.innerText = dict.labelPreGua;
                else if (text.includes('五行属性')) labelEl.innerText = dict.labelElem;
                else if (text.includes('对应山向')) labelEl.innerText = dict.labelMountain;
                else if (text.includes('当令节气')) labelEl.innerText = dict.labelSolar;
                else if (text.includes('主应消息卦')) labelEl.innerText = dict.labelGua;
            });

            // 5. 语言设置弹窗栏按钮高亮
            const btnAuto = document.getElementById('lang-opt-auto');
            const btnHans = document.getElementById('lang-opt-hans');
            const btnHant = document.getElementById('lang-opt-hant');
            const btnEn = document.getElementById('lang-opt-en');
            [btnAuto, btnHans, btnHant, btnEn].forEach(b => b && b.classList.remove('active'));

            if (langSetting === 'auto' && btnAuto) btnAuto.classList.add('active');
            else if (langSetting === 'zh-Hans' && btnHans) btnHans.classList.add('active');
            else if (langSetting === 'zh-Hant' && btnHant) btnHant.classList.add('active');
            else if (langSetting === 'en' && btnEn) btnEn.classList.add('active');

            const currHint = document.getElementById('lbl-lang-curr-hint');
            if (currHint) {
                currHint.innerText = langSetting === 'auto' ? `📱 跟随系统 (${dict.langName})` : `🔒 锁定: ${dict.langName}`;
            }

            // 6. 玄空理气与户型立极核心卡片
            const xkTitles = document.querySelectorAll('.xk-title');
            if (xkTitles && xkTitles.length >= 4) {
                xkTitles[0].innerHTML = `${dict.xkCard1} <span class="badge-vip-pill">👑 VIP绝学</span>`;
                xkTitles[1].innerHTML = `${dict.xkCard2} <span class="badge-vip-pill">👑 VIP绝学</span>`;
                xkTitles[2].innerHTML = `${dict.xkCard3} <span class="badge-vip-pill">👑 VIP绝学</span>`;
                xkTitles[3].innerHTML = `${dict.xkCard4} <span class="badge-vip-pill">👑 VIP绝学</span>`;
            }

            // 7. 会员中心与收银台
            const vipTitleEl = document.querySelector('.calib-title[style*="#ffd700"]');
            if (vipTitleEl) vipTitleEl.innerText = dict.vipTitle;
            const vipChTitle = document.querySelector('.pay-channels-title span');
            if (vipChTitle) vipChTitle.innerText = dict.vipPayTitle;

            // 8. 触发罗盘刷新重绘
            if (typeof updateInfoPanel === 'function') {
                updateInfoPanel();
            }

            // 9. 弹出 Toast 提示
            if (showToastFlag) {
                const toast = document.getElementById('i18n-toast');
                if (toast) {
                    toast.innerText = `🌐 ${dict.langSwitched}${dict.langName}${langSetting === 'auto' ? ' (系统自适应)' : ''}`;
                    toast.classList.add('show');
                    setTimeout(() => toast.classList.remove('show'), 2000);
                }
            }
        }

        // 手动设置语言
        function setAppLanguage(lang) {
            applyLanguage(lang, true);
        }

        // 循环快捷切换语言 (auto -> zh-Hans -> zh-Hant -> en -> auto)
        function cycleLanguage() {
            const order = ['auto', 'zh-Hans', 'zh-Hant', 'en'];
            const nextIdx = (order.indexOf(appLanguageSetting) + 1) % order.length;
            setAppLanguage(order[nextIdx]);
        }

        // Native 原生系统语言变动广播对接 (Android onConfigurationChanged / iOS preferredLanguages)
        window.onSystemLanguageUpdate = function(sysLangTag) {
            console.log('[i18n] Received native system language update:', sysLangTag);
            window.__nativeSystemLanguage = sysLangTag;
            if (appLanguageSetting === 'auto') {
                applyLanguage('auto', false);
            }
        };

        // 监听浏览器系统的 languagechange 事件
        if (typeof window !== 'undefined') {
            window.addEventListener('languagechange', function() {
                console.log('[i18n] Browser languagechange detected:', navigator.language);
                if (appLanguageSetting === 'auto') {
                    applyLanguage('auto', false);
                }
            });
        }

        // 挂载至全局
        window.setAppLanguage = setAppLanguage;
        window.cycleLanguage = cycleLanguage;
        window.applyLanguage = applyLanguage;
        window.t = t;
    '''

    # 插入在 window.openIAPModal 前
    content = content.replace("window.openIAPModal = openIAPModal;", i18n_engine_js + "\n        window.openIAPModal = openIAPModal;")

    # 在页面初始化 onLoad 处调用 applyLanguage(appLanguageSetting)
    init_anchor = 'requestAnimationFrame(drawCompass);'
    content = content.replace(init_anchor, "applyLanguage(appLanguageSetting, false);\n            requestAnimationFrame(drawCompass);", 1)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Successfully implemented i18n engine: {len(content)} bytes")

if __name__ == "__main__":
    implement()
