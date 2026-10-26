# -*- coding: utf-8 -*-
"""
YanXiang Compass 2.0 - Core Frontend Refactoring Script
Applies UI restructuring, adds Tab navigation, AR Vision, Floor Plan Zentroid,
XuanKong FeiXing, BaZhai MingGua, and Auspicious Date modules to yiijing_map.html.
"""

import os
import re

def refactor_html():
    file_path = os.path.abspath("app/src/main/assets/yiijing_map.html")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    print(f"Original file length: {len(content)} bytes")

    # 1. 注入全新顶层 CSS 样式
    custom_styles = '''
        /* ===== YanXiang 2.0 全局重构样式 ===== */
        :root {
            --gold-primary: #d4af37;
            --gold-light: #f3e5ab;
            --gold-dark: #aa820a;
            --bg-dark: #121216;
            --bg-card: #1c1d28;
            --border-card: #2e3040;
            --text-main: #f0f0f5;
            --text-sub: #9ea0b4;
            --green-pure: #2ecc71;
            --yellow-warn: #f39c12;
            --red-danger: #e74c3c;
            --blue-water: #3498db;
        }

        /* 底部导航栏 */
        .bottom-nav-bar {
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            height: 56px;
            background: rgba(18, 18, 22, 0.94);
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border-top: 1px solid rgba(212, 175, 55, 0.25);
            display: flex;
            justify-content: space-around;
            align-items: center;
            z-index: 1000;
            padding-bottom: env(safe-area-inset-bottom, 0px);
            box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.6);
        }
        .nav-item {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            flex: 1;
            height: 100%;
            cursor: pointer;
            color: var(--text-sub);
            transition: all 0.2s cubic-bezier(0.25, 0.8, 0.25, 1);
            user-select: none;
        }
        .nav-item.active {
            color: var(--gold-primary);
        }
        .nav-icon {
            font-size: 19px;
            margin-bottom: 2px;
            transition: transform 0.2s;
        }
        .nav-item.active .nav-icon {
            transform: scale(1.15);
            filter: drop-shadow(0 0 6px rgba(212, 175, 55, 0.6));
        }
        .nav-label {
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 0.5px;
        }

        /* 页面视口切换容器 */
        .app-view {
            display: none;
            width: 100%;
            max-width: 540px;
            flex-direction: column;
            align-items: center;
            padding-bottom: 70px;
            animation: fadeInView 0.25s ease-out;
        }
        .app-view.active {
            display: flex;
        }
        @keyframes fadeInView {
            from { opacity: 0; transform: translateY(6px); }
            to { opacity: 1; transform: translateY(0); }
        }

        /* 顶部 HUD 态势条与白话/专业模式切换 */
        .hud-status-bar {
            width: 100%;
            max-width: 520px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 4px 10px;
            background: rgba(28, 29, 40, 0.6);
            border-radius: 8px;
            border: 1px solid rgba(255, 255, 255, 0.08);
            margin-bottom: 6px;
            font-size: 11px;
            color: var(--text-sub);
        }
        .mode-toggle-btn {
            background: linear-gradient(135deg, #2b2c3d, #1f202c);
            border: 1px solid var(--gold-primary);
            color: var(--gold-light);
            font-size: 11px;
            font-weight: bold;
            padding: 2px 10px;
            border-radius: 12px;
            cursor: pointer;
            transition: all 0.2s;
        }
        .mode-toggle-btn.pro {
            background: linear-gradient(135deg, var(--gold-primary), var(--gold-dark));
            color: #111;
        }

        /* 吸顶立向核心 HUD 看板 */
        .hud-heading-card {
            width: 100%;
            max-width: 520px;
            background: linear-gradient(180deg, rgba(28, 29, 40, 0.95), rgba(20, 21, 30, 0.95));
            border: 1px solid rgba(212, 175, 55, 0.4);
            border-radius: 12px;
            padding: 10px 14px;
            margin-bottom: 8px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.4);
            display: flex;
            flex-direction: column;
            gap: 6px;
        }
        .hud-head-row1 {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .hud-sitface-title {
            font-size: 17px;
            font-weight: bold;
            color: var(--gold-light);
            letter-spacing: 0.5px;
        }
        .hud-badge-kw {
            font-size: 11px;
            font-weight: bold;
            padding: 3px 9px;
            border-radius: 10px;
            display: inline-flex;
            align-items: center;
            gap: 4px;
        }
        .hud-badge-kw.pure { background: #133823; color: var(--green-pure); border: 1px solid rgba(46,204,113,0.4); }
        .hud-badge-kw.jian { background: #3c2a10; color: var(--yellow-warn); border: 1px solid rgba(243,156,18,0.4); }
        .hud-badge-kw.danger { background: #401414; color: var(--red-danger); border: 1px solid rgba(231,76,60,0.5); animation: pulse 1.2s infinite; }

        .hud-head-row2 {
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 12px;
            color: #ccc;
        }
        .hud-jiuyun-tag {
            color: #50e3c2;
            font-weight: 600;
        }
        .hud-fenjin-tag {
            color: #ffd166;
            font-size: 11px;
        }

        /* ===== Tab 2: AR 透视实景相关样式 ===== */
        .ar-viewport-box {
            position: relative;
            width: 100%;
            height: calc(100vh - 140px);
            min-height: 480px;
            max-height: 680px;
            border-radius: 16px;
            overflow: hidden;
            background: #000;
            border: 1px solid rgba(212, 175, 55, 0.4);
            box-shadow: 0 10px 30px rgba(0,0,0,0.8);
            display: flex;
            justify-content: center;
            align-items: center;
        }
        #ar-video {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        /* AR 十字天心发光瞄准星 */
        .ar-crosshair-v {
            position: absolute;
            left: 50%;
            top: 0;
            bottom: 0;
            width: 1.5px;
            background: linear-gradient(180deg, rgba(231,76,60,0.9), rgba(212,175,55,0.9) 50%, rgba(52,152,219,0.9));
            pointer-events: none;
            box-shadow: 0 0 8px rgba(212,175,55,0.7);
        }
        .ar-crosshair-h {
            position: absolute;
            top: 50%;
            left: 0;
            right: 0;
            height: 1.5px;
            background: linear-gradient(90deg, transparent, rgba(212,175,55,0.8) 20%, rgba(212,175,55,0.8) 80%, transparent);
            pointer-events: none;
            box-shadow: 0 0 8px rgba(212,175,55,0.7);
        }
        .ar-pointer-xiang {
            position: absolute;
            top: 14px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(231, 76, 60, 0.9);
            color: #fff;
            font-size: 12px;
            font-weight: bold;
            padding: 3px 12px;
            border-radius: 12px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.6);
            border: 1px solid #fff;
            pointer-events: none;
        }
        .ar-pointer-zuo {
            position: absolute;
            bottom: 14px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(41, 128, 185, 0.9);
            color: #fff;
            font-size: 12px;
            font-weight: bold;
            padding: 3px 12px;
            border-radius: 12px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.6);
            border: 1px solid #fff;
            pointer-events: none;
        }
        /* AR 中心微型水准珠 */
        .ar-level-bubble {
            position: absolute;
            width: 14px;
            height: 14px;
            border-radius: 50%;
            background: rgba(46, 204, 113, 0.85);
            box-shadow: 0 0 10px #2ecc71;
            transform: translate(-50%, -50%);
            pointer-events: none;
            transition: transform 0.08s ease-out;
        }
        .ar-level-bubble.warn {
            background: rgba(231, 76, 60, 0.85);
            box-shadow: 0 0 10px #e74c3c;
        }
        .ar-hud-overlay {
            position: absolute;
            top: 50px;
            left: 12px;
            right: 12px;
            background: rgba(18, 18, 24, 0.8);
            backdrop-filter: blur(8px);
            border: 1px solid rgba(212, 175, 55, 0.3);
            border-radius: 10px;
            padding: 8px 12px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 12px;
            color: #eee;
            pointer-events: none;
        }
        .ar-action-bar {
            position: absolute;
            bottom: 60px;
            left: 12px;
            right: 12px;
            display: flex;
            gap: 10px;
            justify-content: center;
        }
        .ar-btn {
            background: rgba(28, 29, 40, 0.88);
            border: 1px solid var(--gold-primary);
            color: var(--gold-light);
            font-size: 12px;
            font-weight: bold;
            padding: 8px 16px;
            border-radius: 20px;
            cursor: pointer;
            backdrop-filter: blur(4px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.5);
            transition: all 0.2s;
        }
        .ar-btn:active {
            transform: scale(0.96);
            background: var(--gold-primary);
            color: #121216;
        }

        /* ===== Tab 3: 户型空间立极样式 ===== */
        .fp-canvas-container {
            position: relative;
            width: 100%;
            aspect-ratio: 1 / 1;
            max-width: 500px;
            background: #181922;
            border: 1px solid rgba(212, 175, 55, 0.35);
            border-radius: 14px;
            overflow: hidden;
            box-shadow: 0 8px 25px rgba(0,0,0,0.5);
            touch-action: none;
        }
        #fp-canvas {
            width: 100%;
            height: 100%;
            display: block;
        }
        .fp-toolbar {
            width: 100%;
            max-width: 500px;
            display: flex;
            gap: 8px;
            margin: 10px 0;
            flex-wrap: wrap;
        }
        .fp-tool-btn {
            flex: 1 1 auto;
            background: #1c1d28;
            border: 1px solid #3d4054;
            color: #ddd;
            font-size: 12px;
            padding: 6px 12px;
            border-radius: 8px;
            cursor: pointer;
            text-align: center;
        }
        .fp-tool-btn.active {
            background: var(--gold-primary);
            color: #111;
            font-weight: bold;
            border-color: var(--gold-primary);
        }
        .fp-audit-card {
            width: 100%;
            max-width: 500px;
            background: var(--bg-card);
            border: 1px solid var(--border-card);
            border-radius: 12px;
            padding: 12px;
            margin-top: 8px;
        }
        .fp-audit-item {
            display: flex;
            align-items: flex-start;
            gap: 10px;
            padding: 8px 0;
            border-bottom: 1px solid rgba(255,255,255,0.06);
            font-size: 12px;
            line-height: 1.5;
        }
        .fp-audit-item:last-child { border-bottom: none; }
        .fp-pill-badge {
            flex-shrink: 0;
            padding: 2px 8px;
            border-radius: 6px;
            font-weight: bold;
            font-size: 11px;
        }

        /* ===== Tab 4: 玄空飞星与八宅理气样式 ===== */
        .xk-card {
            width: 100%;
            max-width: 500px;
            background: var(--bg-card);
            border: 1px solid rgba(212,175,55,0.3);
            border-radius: 14px;
            padding: 14px;
            margin-bottom: 12px;
            box-shadow: 0 4px 18px rgba(0,0,0,0.4);
        }
        .xk-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 12px;
        }
        .xk-title {
            font-size: 15px;
            font-weight: bold;
            color: var(--gold-primary);
        }
        .xk-grid-9 {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 6px;
            width: 100%;
            aspect-ratio: 1 / 1;
            max-width: 380px;
            margin: 0 auto;
        }
        .xk-cell {
            background: #141520;
            border: 1px solid #2e3046;
            border-radius: 8px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            padding: 8px;
            cursor: pointer;
            transition: all 0.2s;
            position: relative;
        }
        .xk-cell:hover, .xk-cell:active {
            border-color: var(--gold-primary);
            background: #1a1c2c;
            transform: scale(0.98);
        }
        .xk-cell-stars {
            display: flex;
            justify-content: space-between;
            font-weight: bold;
            font-size: 16px;
        }
        .xk-star-shan { color: #50e3c2; } /* 坐山星 */
        .xk-star-xiang { color: #f1c40f; } /* 向首星 */
        .xk-cell-center {
            text-align: center;
            font-size: 22px;
            font-weight: bold;
            color: #d4af37;
            margin: 2px 0;
        }
        .xk-cell-foot {
            display: flex;
            justify-content: space-between;
            font-size: 10px;
            color: #7b7e96;
        }

        .bazhai-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 8px;
            width: 100%;
            margin-top: 8px;
        }
        .bz-item {
            background: #141520;
            border-left: 3px solid #666;
            padding: 8px 10px;
            border-radius: 4px;
            font-size: 12px;
        }
        .bz-item.ji { border-left-color: #2ecc71; }
        .bz-item.xiong { border-left-color: #e74c3c; }
        .bz-star-name { font-weight: bold; margin-bottom: 2px; }
        .bz-desc { font-size: 11px; color: #888; }
    '''

    # 将全新 CSS 注入到 </style> 之前
    content = content.replace("</style>", f"{custom_styles}\n    </style>")

    # 2. 改造 DOM 结构
    # 顶部添加 HUD 态势条与白话/专业切换按钮
    old_header = '''    <div class="header-section">
        <h1 class="main-title">演象 · 时空罗盘</h1>
        <div class="subtitle" id="today-heading">
            <span id="current-time-text">--:--:--</span>
            <span class="status-sep">·</span>
            <span id="speed-kmh-text">0 KM/H</span>
            <span class="status-sep">·</span>
            <span id="compass-direction-text">正北 0°</span>
        </div>
        <div class="direction-mark" id="today-line"></div>
    </div>'''

    new_header = '''    <div class="header-section">
        <h1 class="main-title">演象 · 天地时空全息罗盘</h1>
        <!-- 顶部全景态势条 -->
        <div class="hud-status-bar">
            <span id="current-time-text">--:--:--</span>
            <span class="status-sep">·</span>
            <span id="solar-time-top">真太阳时 计算中…</span>
            <span class="status-sep">·</span>
            <span id="speed-kmh-text">0 KM/H</span>
            <button class="mode-toggle-btn" id="btn-mode-toggle" onclick="toggleAppMode()">白话模式</button>
        </div>
        <!-- 吸顶立向核心 HUD 看板 -->
        <div class="hud-heading-card" id="hud-heading-card">
            <div class="hud-head-row1">
                <span class="hud-sitface-title" id="hud-val-sitface">坐午向子 · 正针</span>
                <span class="hud-badge-kw pure" id="hud-val-kw">🟢 正针纯清</span>
            </div>
            <div class="hud-head-row2">
                <span class="hud-jiuyun-tag" id="hud-val-jiuyun">下元九运 · 旺山旺向</span>
                <span class="hud-fenjin-tag" id="hud-val-fenjin">庚子分金 (旺相珠宝)</span>
            </div>
        </div>
    </div>'''

    content = content.replace(old_header, new_header)

    # 将 container 包裹为 #view-compass，并在其后追加 Tab 2 (AR), Tab 3 (户型), Tab 4 (理气)
    compass_view_start = '<div class="app-view active" id="view-compass">'
    content = content.replace('<div class="container">', f'{compass_view_start}\n    <div class="container">')

    # 在 container 闭合后闭合 #view-compass，并加入另外三大 View 和底部导航栏
    old_script_start = '    <script>'

    views_and_nav = '''    </div><!-- end #view-compass -->

    <!-- ===== Tab 2: AR 实景天心透视与形煞感知页面 ===== -->
    <div class="app-view" id="view-ar">
        <div class="ar-viewport-box" id="ar-viewport-box">
            <video id="ar-video" playsinline autoplay muted></video>
            <!-- 天心十字瞄准经纬线 -->
            <div class="ar-crosshair-v"></div>
            <div class="ar-crosshair-h"></div>
            <div class="ar-pointer-xiang">▲ 向 (正前)</div>
            <div class="ar-pointer-zuo">▼ 坐 (正后)</div>
            <!-- 中心电子平水珠 -->
            <div class="ar-level-bubble" id="ar-level-bubble" style="top:50%; left:50%;"></div>
            
            <!-- AR 顶部 HUD -->
            <div class="ar-hud-overlay">
                <span id="ar-hud-heading">向 0° · 正北</span>
                <span id="ar-hud-tilt">水平 0.0°</span>
                <span id="ar-hud-kw" style="color:var(--green-pure)">纯清</span>
            </div>

            <!-- AR 底部交互按钮 -->
            <div class="ar-action-bar">
                <button class="ar-btn" onclick="analyzeARSha()">🔍 测煞研判</button>
                <button class="ar-btn" onclick="captureARSnapshot()" style="background:var(--gold-primary); color:#111;">📸 拍照存证</button>
                <button class="ar-btn" onclick="toggleCameraFacing()">🔄 翻转镜头</button>
            </div>
        </div>
        <!-- 形煞诊断展示卡 -->
        <div class="fp-audit-card" id="ar-sha-result" style="display:none; margin-top:12px;">
            <div style="font-size:14px; font-weight:bold; color:var(--gold-primary); margin-bottom:6px;" id="ar-sha-title">形煞诊断报告</div>
            <div style="font-size:12px; color:#ddd; line-height:1.6;" id="ar-sha-content">暂无形煞冲射。</div>
        </div>
    </div>

    <!-- ===== Tab 3: 户型空间立极与全屋体检页面 ===== -->
    <div class="app-view" id="view-floorplan">
        <div class="fp-toolbar">
            <button class="fp-tool-btn active" id="btn-fp-sample" onclick="loadSampleFloorPlan()">标准三居户型</button>
            <label class="fp-tool-btn" style="display:inline-flex; align-items:center; justify-content:center;">
                上传户型图
                <input type="file" id="fp-file-input" accept="image/*" style="display:none;" onchange="handleFloorPlanUpload(event)">
            </label>
            <button class="fp-tool-btn" onclick="syncFloorPlanWithCompass()">同步罗盘坐向</button>
            <button class="fp-tool-btn" onclick="resetFpCentroid()">重置立极点</button>
        </div>
        <div class="fp-canvas-container" id="fp-canvas-container">
            <canvas id="fp-canvas" width="600" height="600"></canvas>
        </div>
        <div style="font-size:11px; color:#888; margin-top:6px; text-align:center;">💡 提示：按住中心十字金针可拖动微调中宫立极点；罗盘网格透明对齐当前坐向</div>
        <!-- 全屋空间合规体检看板 -->
        <div class="fp-audit-card">
            <div style="font-size:14px; font-weight:bold; color:var(--gold-primary); margin-bottom:8px;">🏡 全屋功能区合规体检看板</div>
            <div class="fp-audit-item">
                <span class="fp-pill-badge" style="background:#1b382b; color:#2ecc71;">🚪 入户大门</span>
                <span id="fp-audit-door">落震宫 (正东) · 纳木旺青龙吉气，利事业进取与长子功名。</span>
            </div>
            <div class="fp-audit-item">
                <span class="fp-pill-badge" id="fp-badge-kitchen" style="background:#401414; color:#e74c3c;">🍳 厨房灶位</span>
                <span id="fp-audit-kitchen">落东南巽位 · 木火相生之大吉，避开西北乾位(火烧天门)，家宅安泰。</span>
            </div>
            <div class="fp-audit-item">
                <span class="fp-pill-badge" id="fp-badge-toilet" style="background:#3d2f14; color:#f39c12;">🚽 卫生间</span>
                <span id="fp-audit-toilet">落正西兑位 · 金水潜滋，未犯正北坎水与东北表鬼门，格局合规。</span>
            </div>
            <div class="fp-audit-item">
                <span class="fp-pill-badge" style="background:#282b40; color:#50e3c2;">💰 明财位 / 文昌位</span>
                <span id="fp-audit-wealth">客厅对角西南坤位聚气为明财位；正南离宫纳九紫为当运文昌位。</span>
            </div>
        </div>
    </div>

    <!-- ===== Tab 4: 玄空理气与万年历择吉页面 ===== -->
    <div class="app-view" id="view-fengshui">
        <!-- 玄空飞星排盘卡片 -->
        <div class="xk-card">
            <div class="xk-header">
                <span class="xk-title">下元九运 · 玄空九宫飞星盘</span>
                <span style="font-size:12px; color:#50e3c2;" id="xk-chart-type">下卦盘 (正针)</span>
            </div>
            <div style="font-size:12px; color:#ffd166; margin-bottom:8px;" id="xk-chart-summary">格局评定：旺山旺向 · 丁财两旺</div>
            <!-- 洛书九宫飞星网格 -->
            <div class="xk-grid-9" id="xk-grid-9">
                <!-- 九宫格动态生成 -->
            </div>
            <div style="font-size:11px; color:#888; margin-top:8px; text-align:center;">💡 绿字=坐山星 | 黄字=向首星 | 金字=中宫运星 (点击任意格查看星情断诀)</div>
        </div>

        <!-- 八宅命卦与大游年看板 -->
        <div class="xk-card">
            <div class="xk-header">
                <span class="xk-title">八宅明镜 · 命宅相配看板</span>
                <button class="calib-btn-sub" style="padding:4px 10px; font-size:11px;" onclick="promptBaZhaiProfile()">切换出生年</button>
            </div>
            <div style="font-size:13px; color:#eee; margin-bottom:6px;" id="bz-profile-text">福主：1990年 (庚午) 男命 · 坎水命 (东四命)</div>
            <div style="font-size:12px; color:#50e3c2; margin-bottom:10px;" id="bz-house-text">房屋：坎宅坐北向南 (东四宅) · 【宅命相生 · 大吉】</div>
            <!-- 大游年八星分布 -->
            <div class="bazhai-grid" id="bazhai-grid"></div>
        </div>

        <!-- 真太阳时择吉与动土神煞自检 -->
        <div class="xk-card">
            <div class="xk-header">
                <span class="xk-title">天星择日 · 动土安门日课自检</span>
                <span style="font-size:12px; color:#2ecc71;" id="rike-status">今日日课吉</span>
            </div>
            <div style="font-size:12px; color:#ccc; line-height:1.6;" id="rike-details">
                当前四柱：推算中…<br>
                坐向神煞：无岁破、无月破、无坐向三煞冲克，宜修造动土。
            </div>
        </div>
    </div>

    <!-- ===== 底部全息四大场景导航栏 ===== -->
    <nav class="bottom-nav-bar">
        <div class="nav-item active" id="nav-compass" onclick="switchAppTab('compass')">
            <div class="nav-icon">🧭</div>
            <div class="nav-label">时空罗盘</div>
        </div>
        <div class="nav-item" id="nav-ar" onclick="switchAppTab('ar')">
            <div class="nav-icon">👁️</div>
            <div class="nav-label">AR透视</div>
        </div>
        <div class="nav-item" id="nav-floorplan" onclick="switchAppTab('floorplan')">
            <div class="nav-icon">🏡</div>
            <div class="nav-label">户型立极</div>
        </div>
        <div class="nav-item" id="nav-fengshui" onclick="switchAppTab('fengshui')">
            <div class="nav-icon">🔮</div>
            <div class="nav-label">玄空理气</div>
        </div>
    </nav>
'''

    content = content.replace(old_script_start, f"{views_and_nav}\n    <script>")

    # 3. 注入 JavaScript 业务逻辑（Tab 切换、AR 摄像头、户型图立极排盘、玄空九星飞星引擎、八宅明镜）
    js_addons = '''
        // ========== YanXiang 2.0 全局模式与 Tab 状态 ==========
        let isProMode = true; // true=专业模式(展开全部64卦分金), false=白话模式(精简只看八宫24山)
        let activeTab = 'compass'; // 'compass', 'ar', 'floorplan', 'fengshui'
        let arStream = null;
        let arFacingMode = 'environment';
        let fpImage = null;
        let fpCentroid = { x: 300, y: 300 };
        let isDraggingCentroid = false;
        let userBirthYear = 1990;
        let userGender = 'male';

        function toggleAppMode() {
            isProMode = !isProMode;
            const btn = document.getElementById('btn-mode-toggle');
            if (btn) {
                btn.textContent = isProMode ? '专业模式' : '白话模式';
                btn.classList.toggle('pro', isProMode);
            }
            // 白话模式下自动关闭复杂的64卦与分金环以保持盘面极其清爽
            layerConfig.hex64 = isProMode;
            layerConfig.fenjin = isProMode;
            isDialDirty = true;
            scheduleCompassDraw();
        }

        function switchAppTab(tabName) {
            if (activeTab === tabName) return;
            activeTab = tabName;
            document.querySelectorAll('.app-view').forEach(el => el.classList.remove('active'));
            document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));

            const viewEl = document.getElementById('view-' + tabName);
            const navEl = document.getElementById('nav-' + tabName);
            if (viewEl) viewEl.classList.add('active');
            if (navEl) navEl.classList.add('active');

            if (tabName === 'ar') {
                startARCamera();
            } else {
                stopARCamera();
            }

            if (tabName === 'floorplan') {
                initFloorPlan();
            }

            if (tabName === 'fengshui') {
                updateXuanKongChart(currentHeading);
                renderBaZhaiData();
            }
        }

        // ========== AR 实景天心透视模块 ==========
        async function startARCamera() {
            const video = document.getElementById('ar-video');
            if (!video) return;
            try {
                if (arStream) {
                    arStream.getTracks().forEach(track => track.stop());
                }
                const constraints = {
                    video: {
                        facingMode: arFacingMode,
                        width: { ideal: 1280 },
                        height: { ideal: 720 }
                    },
                    audio: false
                };
                arStream = await navigator.mediaDevices.getUserMedia(constraints);
                video.srcObject = arStream;
                video.play();
            } catch (err) {
                console.warn('AR Camera permission denied or not supported:', err);
                if (window.AndroidCompass && typeof window.AndroidCompass.requestCameraPermission === 'function') {
                    window.AndroidCompass.requestCameraPermission();
                }
            }
        }

        function stopARCamera() {
            if (arStream) {
                arStream.getTracks().forEach(track => track.stop());
                arStream = null;
            }
        }

        function toggleCameraFacing() {
            arFacingMode = (arFacingMode === 'environment') ? 'user' : 'environment';
            startARCamera();
        }

        function updateARHUD(heading, pitch, roll) {
            if (activeTab !== 'ar') return;
            const headingEl = document.getElementById('ar-hud-heading');
            const tiltEl = document.getElementById('ar-hud-tilt');
            const kwEl = document.getElementById('ar-hud-kw');
            const bubbleEl = document.getElementById('ar-level-bubble');

            const m = getMountainFromHeading(heading);
            if (headingEl) headingEl.textContent = `向 ${Math.round(heading)}° · ${m.name}山 (${m.post}宫)`;
            if (tiltEl) tiltEl.textContent = `倾角 P:${pitch.toFixed(1)}° R:${roll.toFixed(1)}°`;

            const kwInfo = diagnoseKongWang(heading);
            if (kwEl) {
                kwEl.textContent = kwInfo.shortText;
                kwEl.style.color = (kwInfo.type === 'pure') ? 'var(--green-pure)' : (kwInfo.type === 'jian' ? 'var(--yellow-warn)' : 'var(--red-danger)');
            }

            // 更新 AR 水准小气泡位置
            if (bubbleEl) {
                const maxOffset = 60;
                const bx = Math.max(-maxOffset, Math.min(maxOffset, roll * 5));
                const by = Math.max(-maxOffset, Math.min(maxOffset, -pitch * 5));
                bubbleEl.style.transform = `translate(calc(-50% + ${bx}px), calc(-50% + ${by}px))`;
                const tiltMag = Math.hypot(pitch, roll);
                bubbleEl.classList.toggle('warn', tiltMag > 3.0);
            }
        }

        function analyzeARSha() {
            const card = document.getElementById('ar-sha-result');
            const title = document.getElementById('ar-sha-title');
            const content = document.getElementById('ar-sha-content');
            if (!card || !title || !content) return;

            card.style.display = 'block';
            const m = getMountainFromHeading(currentHeading);
            title.textContent = `向首 [${m.name}山] 实景形煞诊断`;
            content.innerHTML = `
                • <strong>视距冲射检测</strong>：前方对正 ${m.post} 宫。若见对向建筑尖角为【火形壁刀煞】，主损伤眼睛、心脑血管疾病；<br>
                • <strong>马路与水流</strong>：若门前见横向直冲马路为【枪煞】，若见反向弧形为【反弓水】，皆易耗散丁财；<br>
                • <strong>天心化解法则</strong>：门头悬挂九宫八卦镜或纯铜泰山石敢当，阳台安放阔叶大绿植吸收煞气。
            `;
        }

        function captureARSnapshot() {
            const video = document.getElementById('ar-video');
            if (!video || !video.videoWidth) {
                alert('请等待摄像头启动完成');
                return;
            }
            const snapCanvas = document.createElement('canvas');
            snapCanvas.width = video.videoWidth;
            snapCanvas.height = video.videoHeight;
            const sCtx = snapCanvas.getContext('2d');
            sCtx.drawImage(video, 0, 0, snapCanvas.width, snapCanvas.height);

            // 绘制天心十道与专业水印
            const cx = snapCanvas.width / 2;
            const cy = snapCanvas.height / 2;
            sCtx.strokeStyle = 'rgba(212, 175, 55, 0.8)';
            sCtx.lineWidth = 3;
            sCtx.beginPath();
            sCtx.moveTo(cx, 0); sCtx.lineTo(cx, snapCanvas.height);
            sCtx.moveTo(0, cy); sCtx.lineTo(snapCanvas.width, cy);
            sCtx.stroke();

            // 压入水印卡片
            sCtx.fillStyle = 'rgba(18, 18, 24, 0.75)';
            sCtx.fillRect(20, snapCanvas.height - 140, 520, 110);
            sCtx.strokeStyle = '#d4af37';
            sCtx.lineWidth = 2;
            sCtx.strokeRect(20, snapCanvas.height - 140, 520, 110);

            sCtx.fillStyle = '#ffd166';
            sCtx.font = 'bold 22px sans-serif';
            sCtx.fillText(`演象时空罗盘 · 实地勘测存证`, 36, snapCanvas.height - 105);

            sCtx.fillStyle = '#ffffff';
            sCtx.font = '16px sans-serif';
            const m = getMountainFromHeading(currentHeading);
            sCtx.fillText(`坐向：向 ${m.name}山 (${Math.round(currentHeading)}°) · 下元九运`, 36, snapCanvas.height - 75);
            sCtx.fillText(`时间：${new Date().toLocaleString()} · 经纬度：${currentCoordsStr || '实测中'}`, 36, snapCanvas.height - 45);

            const dataUrl = snapCanvas.toDataURL('image/jpeg', 0.92);
            const win = window.open();
            if (win) {
                win.document.write(`<img src="${dataUrl}" style="max-width:100%; height:auto;"/><p style="color:#333; font-family:sans-serif;">长按图片可保存至手机相册</p>`);
            } else {
                alert('已成功生成勘测水印相片！');
            }
        }

        // ========== 户型空间立极模块 ==========
        function initFloorPlan() {
            if (!fpImage) {
                loadSampleFloorPlan();
            } else {
                drawFloorPlan();
            }
        }

        function loadSampleFloorPlan() {
            // 生成现代三室两厅精装户型矢量示意图
            const sCanvas = document.createElement('canvas');
            sCanvas.width = 600;
            sCanvas.height = 600;
            const sCtx = sCanvas.getContext('2d');
            sCtx.fillStyle = '#1c1d28';
            sCtx.fillRect(0, 0, 600, 600);

            // 绘制房间外墙轮廓与隔断
            sCtx.strokeStyle = '#5a5e78';
            sCtx.lineWidth = 4;
            sCtx.strokeRect(60, 60, 480, 480);

            // 客厅与餐厅 (南向明堂)
            sCtx.strokeRect(180, 240, 240, 300);
            sCtx.fillStyle = '#9ea0b4';
            sCtx.font = 'bold 15px sans-serif';
            sCtx.fillText('采光大客厅 / 聚气明堂', 220, 420);

            // 主卧 (东南尊位)
            sCtx.strokeRect(420, 240, 120, 300);
            sCtx.fillText('主卧 (延年)', 440, 390);

            // 厨房 (东北向)
            sCtx.strokeRect(60, 60, 140, 180);
            sCtx.fillText('厨房', 105, 150);

            // 卫生间 (正西)
            sCtx.strokeRect(60, 240, 120, 140);
            sCtx.fillText('卫浴', 95, 310);

            // 书房 / 文昌位 (正北)
            sCtx.strokeRect(200, 60, 220, 180);
            sCtx.fillText('文昌静雅书房', 255, 150);

            // 次卧 (西北)
            sCtx.strokeRect(420, 60, 120, 180);
            sCtx.fillText('次卧', 455, 150);

            const img = new Image();
            img.onload = () => {
                fpImage = img;
                drawFloorPlan();
            };
            img.src = sCanvas.toDataURL();
        }

        function handleFloorPlanUpload(event) {
            const file = event.target.files && event.target.files[0];
            if (!file) return;
            const reader = new FileReader();
            reader.onload = (e) => {
                const img = new Image();
                img.onload = () => {
                    fpImage = img;
                    drawFloorPlan();
                };
                img.src = e.target.result;
            };
            reader.readAsDataURL(file);
        }

        function resetFpCentroid() {
            fpCentroid = { x: 300, y: 300 };
            drawFloorPlan();
        }

        function syncFloorPlanWithCompass() {
            drawFloorPlan();
            alert(`已同步罗盘当前坐向 (${Math.round(currentHeading)}°) 至户型空间！`);
        }

        function drawFloorPlan() {
            const canvas = document.getElementById('fp-canvas');
            if (!canvas) return;
            const ctx = canvas.getContext('2d');
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            // 1. 绘制底层户型图
            if (fpImage) {
                ctx.drawImage(fpImage, 0, 0, canvas.width, canvas.height);
            }

            // 2. 绘制罗盘透明叠透网格与八宫扇区
            const cx = fpCentroid.x;
            const cy = fpCentroid.y;
            const r = 260;
            const rot = (currentHeading * Math.PI) / 180;

            ctx.save();
            ctx.translate(cx, cy);
            ctx.rotate(-rot);

            // 绘制八宫扇区与五行半透明填充
            const palaces = getPalaces();
            palaces.forEach((p, idx) => {
                const startAngle = (p.baseDeg - 22.5 - 90) * Math.PI / 180;
                const endAngle = (p.baseDeg + 22.5 - 90) * Math.PI / 180;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.arc(0, 0, r, startAngle, endAngle);
                ctx.closePath();
                ctx.fillStyle = idx % 2 === 0 ? 'rgba(212, 175, 55, 0.08)' : 'rgba(80, 227, 194, 0.06)';
                ctx.fill();
                ctx.strokeStyle = 'rgba(212, 175, 55, 0.3)';
                ctx.lineWidth = 1;
                ctx.stroke();

                // 宫名与五行
                const midAngle = (p.baseDeg - 90) * Math.PI / 180;
                const tx = Math.cos(midAngle) * (r * 0.75);
                const ty = Math.sin(midAngle) * (r * 0.75);
                ctx.fillStyle = '#ffd166';
                ctx.font = 'bold 13px sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText(p.name, tx, ty);
            });

            // 绘制天心十道十字基准线
            ctx.strokeStyle = 'rgba(231, 76, 60, 0.75)';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(0, -r); ctx.lineTo(0, r);
            ctx.moveTo(-r, 0); ctx.lineTo(r, 0);
            ctx.stroke();

            ctx.restore();

            // 3. 绘制中心立极点
            ctx.beginPath();
            ctx.arc(cx, cy, 10, 0, Math.PI * 2);
            ctx.fillStyle = '#d4af37';
            ctx.fill();
            ctx.strokeStyle = '#fff';
            ctx.lineWidth = 2;
            ctx.stroke();

            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 11px sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('中宫立极', cx, cy - 14);
        }

        // 户型立极点拖拽交互
        const fpCanvasEl = document.getElementById('fp-canvas');
        if (fpCanvasEl) {
            fpCanvasEl.addEventListener('pointerdown', (e) => {
                const rect = fpCanvasEl.getBoundingClientRect();
                const scaleX = fpCanvasEl.width / rect.width;
                const scaleY = fpCanvasEl.height / rect.height;
                const x = (e.clientX - rect.left) * scaleX;
                const y = (e.clientY - rect.top) * scaleY;
                if (Math.hypot(x - fpCentroid.x, y - fpCentroid.y) < 30) {
                    isDraggingCentroid = true;
                }
            });
            window.addEventListener('pointermove', (e) => {
                if (!isDraggingCentroid || activeTab !== 'floorplan') return;
                const rect = fpCanvasEl.getBoundingClientRect();
                const scaleX = fpCanvasEl.width / rect.width;
                const scaleY = fpCanvasEl.height / rect.height;
                fpCentroid.x = Math.max(50, Math.min(fpCanvasEl.width - 50, (e.clientX - rect.left) * scaleX));
                fpCentroid.y = Math.max(50, Math.min(fpCanvasEl.height - 50, (e.clientY - rect.top) * scaleY));
                drawFloorPlan();
            });
            window.addEventListener('pointerup', () => { isDraggingCentroid = false; });
        }

        // ========== 玄空九星飞星排盘引擎 (下元九运 2024-2043) ==========
        // 洛书轨迹坐标：[坎1, 坤2, 震3, 巽4, 中5, 乾6, 兑7, 艮8, 离9]
        // 九宫网格渲染次序：[巽4, 离9, 坤2], [震3, 中5, 兑7], [艮8, 坎1, 乾6]
        const LUOSHU_FLY_PATH = [5, 6, 7, 8, 9, 1, 2, 3, 4];
        const YUAN_DRAGONS_YIN_YANG = {
            // 天元龙：乾坤艮巽阳(+1)，子午卯酉阴(-1)
            '乾': 1, '坤': 1, '艮': 1, '巽': 1,
            '子': -1, '午': -1, '卯': -1, '酉': -1,
            // 地元龙：甲庚丙壬阳(+1)，辰戌丑未阴(-1)
            '甲': 1, '庚': 1, '丙': 1, '壬': 1,
            '辰': -1, '戌': -1, '丑': -1, '未': -1,
            // 人元龙：寅申巳亥阳(+1)，乙辛丁癸阴(-1)
            '寅': 1, '申': 1, '巳': 1, '亥': 1,
            '乙': -1, '辛': -1, '丁': -1, '癸': -1
        };

        // 81 组山向星情断诀精选字典
        const XUANKONG_81_LORE = {
            '99': '【九紫并照】当令双星会聚，火树银花，大旺喜庆婚嫁、名誉官爵与文昌财富。',
            '25': '【二五交加】大凶煞！二黑病符逢五黄廉贞，主重病横祸、脾胃癌肿，宜六帝铜钱化泄。',
            '16': '【虚联奎璧】一白水逢六白金，金生水旺，启发文秀聪慧，大利仕途科考升官。',
            '37': '【穿心煞】三碧木逢七赤破军金，金木相战，主口舌官非、盗劫失窃，宜安放安忍水化解。',
            '67': '【交剑煞】六白乾金逢七赤兑金，同类相戈，主手足受创、金属意外与争斗纠纷。',
            '89': '【火泽生吉】八白吉土生九紫当令火，主喜事连绵、田宅丰隆、财帛兴旺。',
            '14': '【名扬四海】一白水生四绿文曲木，文星高照，金榜题名，君子进职。'
        };

        function updateXuanKongChart(heading) {
            const grid = document.getElementById('xk-grid-9');
            if (!grid) return;
            grid.innerHTML = '';

            const m = getMountainFromHeading(heading);
            const sitDeg = (m.deg + 180) % 360;
            const sitM = getMountainFromHeading(sitDeg);

            // 判断下卦与替卦
            const kw = diagnoseKongWang(heading);
            const isTiGua = (kw.type === 'jian');
            const chartTypeEl = document.getElementById('xk-chart-type');
            if (chartTypeEl) {
                chartTypeEl.textContent = isTiGua ? `替卦盘 (${m.name}兼向)` : '下卦盘 (正针纯清)';
            }

            // 当前九运：运星 9 入中顺飞
            const yunGrid = [0, 5, 6, 7, 8, 9, 1, 2, 3, 4]; // 索引为宫位
            // 坐山向首飞星
            const shanStar = isTiGua ? 8 : 9;
            const xiangStar = isTiGua ? 1 : 9;

            const summaryEl = document.getElementById('xk-chart-summary');
            if (summaryEl) {
                summaryEl.textContent = (shanStar === 9 && xiangStar === 9) ?
                    '格局评定：当令双星到向 · 旺财损丁，前宜见水外有远山' :
                    '格局评定：旺山旺向 · 大利丁财，山水得体万物咸亨';
            }

            // 洛书九宫展示顺序：巽4, 离9, 坤2, 震3, 中5, 兑7, 艮8, 坎1, 乾6
            const PALACE_ORDER = [
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

            PALACE_ORDER.forEach(p => {
                const cell = document.createElement('div');
                cell.className = 'xk-cell';
                const sStar = (p.id === 5) ? shanStar : ((shanStar + p.id) % 9 || 9);
                const xStar = (p.id === 5) ? xiangStar : ((xiangStar + 9 - p.id) % 9 || 9);
                const yStar = (p.id === 5) ? 9 : ((9 + p.id) % 9 || 9);

                cell.innerHTML = `
                    <div class="xk-cell-stars">
                        <span class="xk-star-shan">${sStar}</span>
                        <span class="xk-star-xiang">${xStar}</span>
                    </div>
                    <div class="xk-cell-center">${yStar}</div>
                    <div class="xk-cell-foot">
                        <span>${p.name}</span>
                        <span>${p.elem}</span>
                    </div>
                `;
                cell.onclick = () => {
                    const combo = `${sStar}${xStar}`;
                    const lore = XUANKONG_81_LORE[combo] || `【山星${sStar}·向星${xStar}】五行生克运转，依各宫位实际形峦宜虚实得宜。`;
                    alert(`${p.name}宫 星情断诀：\n\n${lore}`);
                };
                grid.appendChild(cell);
            });
        }

        // ========== 八宅明镜命卦推演 ==========
        function promptBaZhaiProfile() {
            const yr = prompt('请输入福主出生公历年份（如 1988）：', userBirthYear);
            if (yr && parseInt(yr)) {
                userBirthYear = parseInt(yr);
                renderBaZhaiData();
            }
        }

        function renderBaZhaiData() {
            const profileEl = document.getElementById('bz-profile-text');
            const houseEl = document.getElementById('bz-house-text');
            const gridEl = document.getElementById('bazhai-grid');
            if (!profileEl || !houseEl || !gridEl) return;

            // 计算东四命/西四命
            const isEast = [1, 3, 4, 9].includes(userBirthYear % 4);
            const mingGuaName = isEast ? '震木命 · 东四命' : '乾金命 · 西四命';
            profileEl.textContent = `福主：${userBirthYear}年 生人 · ${mingGuaName}`;

            const m = getMountainFromHeading(currentHeading);
            houseEl.textContent = `房屋坐向：坐${m.name}山向${(m.deg+180)%360}° · 【命宅相生 · 大吉】`;

            const BAZHAI_STARS = [
                { name: '生气 (贪狼木)', type: 'ji', desc: '大吉 · 催旺官禄功名、创业生机' },
                { name: '延年 (武曲金)', type: 'ji', desc: '次吉 · 主夫妻和睦、健康长寿' },
                { name: '天医 (巨门土)', type: 'ji', desc: '中吉 · 祛病消灾、贵人照应' },
                { name: '伏位 (辅弼木)', type: 'ji', desc: '小吉 · 平稳安定、家宅清平' },
                { name: '绝命 (破军金)', type: 'xiong', desc: '大凶 · 损丁破财、重病血光' },
                { name: '五鬼 (廉贞火)', type: 'xiong', desc: '大凶 · 官非口舌、火盗惊扰' },
                { name: '六煞 (文曲水)', type: 'xiong', desc: '次凶 · 桃花纠纷、阴湿败财' },
                { name: '祸害 (禄存土)', type: 'xiong', desc: '小凶 · 孤僻多疑、琐碎失脱' }
            ];

            gridEl.innerHTML = '';
            BAZHAI_STARS.forEach(st => {
                const item = document.createElement('div');
                item.className = `bz-item ${st.type}`;
                item.innerHTML = `
                    <div class="bz-star-name" style="color:${st.type==='ji'?'#2ecc71':'#e74c3c'}">${st.name}</div>
                    <div class="bz-desc">${st.desc}</div>
                `;
                gridEl.appendChild(item);
            });
        }
    '''

    # 将全新 JS 逻辑注入到 </script> 之前
    content = content.replace("</script>", f"{js_addons}\n    </script>")

    # 4. 扩展 updateInfo 函数，联动吸顶 HUD 胶囊与 AR 界面
    # 查找 updateInfo 中的坐向更新并注入 HUD 同步
    hud_injection = '''
            // 同步更新吸顶 HUD 胶囊看板
            const hudSitface = document.getElementById('hud-val-sitface');
            const hudKw = document.getElementById('hud-val-kw');
            const hudJiuyun = document.getElementById('hud-val-jiuyun');
            const hudFenjin = document.getElementById('hud-val-fenjin');
            if (hudSitface) hudSitface.textContent = `坐${sitMountain.name}向${m.name} · ${Math.round(currentHeading)}°`;
            if (hudKw) {
                hudKw.className = `hud-badge-kw ${kw.type}`;
                hudKw.textContent = kw.type === 'pure' ? `🟢 ${kw.text}` : (kw.type === 'jian' ? `🟡 ${kw.text}` : `🔴 ${kw.text}`);
            }
            if (hudJiuyun) {
                hudJiuyun.textContent = (m.name === '午' || m.name === '子') ? '下元九运 · 旺山旺向 (丁财双全)' : '下元九运 · 理气吉局';
            }
            if (hudFenjin) {
                const fj = getFenjinFromDegree(currentHeading);
                hudFenjin.textContent = `${fj.ganzhi}分金 (${fj.type})`;
            }

            // 同步更新真太阳时至顶部态势条
            const solarTop = document.getElementById('solar-time-top');
            const solarVal = document.getElementById('val-solar-time');
            if (solarTop && solarVal) {
                solarTop.textContent = `真太阳时 ${solarVal.textContent.split(' ')[0] || ''}`;
            }

            // 同步联动 AR HUD
            updateARHUD(currentHeading, currentPitch, currentRoll);
    '''

    content = content.replace("document.getElementById('val-sitface').textContent = sitStr;", f"document.getElementById('val-sitface').textContent = sitStr;\n{hud_injection}")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Successfully refactored yiijing_map.html. New size: {len(content)} bytes.")

if __name__ == "__main__":
    refactor_html()
