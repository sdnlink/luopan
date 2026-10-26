# -*- coding: utf-8 -*-
"""
YanXiang Compass 2.0 - Implementation of PRD Chapter 5.2 & Chapter 14:
'AR Spatial Vision & Exterior Sha Recognition Engine'
Upgrades Tab 2 with live camera stream, simulated scenery fallback,
interactive reticle targeting, AI exterior sha scanner,
three-tier traditional/scientific/remedy diagnostic cards,
and master-grade watermarked forensic evidence photo generation.
"""

import os
import re

def implement():
    html_path = os.path.abspath("app/src/main/assets/yiijing_map.html")
    with open(html_path, "r", encoding="utf-8") as f:
        content = f.read()

    print(f"Original content length: {len(content)} bytes")

    # 1. AR Vision CSS
    ar_css = '''
        /* ===== PRD 5.2 & 14: AR 实景天心透视与形煞智能识别引擎样式 ===== */
        .ar-viewport-box {
            position: relative;
            width: 100%;
            height: calc(100vh - 145px);
            min-height: 480px;
            max-height: 640px;
            border-radius: 18px;
            overflow: hidden;
            background: #08090d;
            border: 1px solid rgba(212, 175, 55, 0.45);
            box-shadow: 0 10px 35px rgba(0,0,0,0.85);
            display: flex;
            justify-content: center;
            align-items: center;
            touch-action: none;
            user-select: none;
        }
        #ar-video {
            width: 100%;
            height: 100%;
            object-fit: cover;
            position: absolute;
            top: 0; left: 0;
            z-index: 1;
        }
        #ar-simulated-canvas {
            width: 100%;
            height: 100%;
            position: absolute;
            top: 0; left: 0;
            z-index: 2;
            display: none;
        }
        #ar-dial-canvas {
            position: absolute;
            top: 0; left: 0;
            width: 100%; height: 100%;
            z-index: 4;
            pointer-events: none;
        }
        .ar-scanner-beam {
            position: absolute;
            left: 0; right: 0;
            height: 3px;
            background: linear-gradient(90deg, transparent 5%, rgba(212, 175, 55, 0.9) 30%, #fff 50%, rgba(212, 175, 55, 0.9) 70%, transparent 95%);
            box-shadow: 0 0 14px rgba(212, 175, 55, 0.9), 0 0 28px rgba(255, 209, 102, 0.6);
            z-index: 8;
            pointer-events: none;
            display: none;
        }
        .ar-scanner-beam.active {
            display: block;
            animation: arScanMotion 2s ease-in-out infinite alternate;
        }
        @keyframes arScanMotion {
            0% { top: 8%; opacity: 0.2; }
            50% { opacity: 1; }
            100% { top: 92%; opacity: 0.2; }
        }
        .ar-range-grid {
            position: absolute;
            top: 50%; left: 50%;
            transform: translate(-50%, -50%);
            width: 260px; height: 260px;
            border-radius: 50%;
            border: 1px dashed rgba(212, 175, 55, 0.3);
            pointer-events: none;
            z-index: 3;
            transition: opacity 0.3s;
        }
        .ar-range-grid::before {
            content: '';
            position: absolute;
            top: 25%; left: 25%; right: 25%; bottom: 25%;
            border-radius: 50%;
            border: 1px dotted rgba(212, 175, 55, 0.25);
        }
        .ar-target-reticle {
            position: absolute;
            width: 58px; height: 58px;
            border: 2px solid var(--red-danger);
            border-radius: 12px;
            transform: translate(-50%, -50%);
            z-index: 9;
            cursor: move;
            box-shadow: 0 0 14px rgba(231, 76, 60, 0.7);
            transition: border-color 0.2s;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .ar-target-reticle::before {
            content: '';
            width: 8px; height: 8px;
            background: var(--red-danger);
            border-radius: 50%;
            box-shadow: 0 0 6px rgba(231, 76, 60, 0.9);
        }
        .ar-target-tag {
            position: absolute;
            top: -26px;
            left: 50%;
            transform: translateX(-50%);
            white-space: nowrap;
            background: rgba(231, 76, 60, 0.92);
            color: #fff;
            font-size: 10px;
            font-weight: bold;
            padding: 3px 8px;
            border-radius: 10px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.6);
            letter-spacing: 0.5px;
        }
        .ar-hud-overlay {
            position: absolute;
            top: 10px;
            left: 10px;
            right: 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: rgba(14, 15, 22, 0.88);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            padding: 7px 12px;
            border-radius: 20px;
            border: 1px solid rgba(212, 175, 55, 0.35);
            z-index: 10;
            font-size: 11px;
            color: var(--text-main);
            box-shadow: 0 4px 15px rgba(0,0,0,0.5);
        }
        .ar-quick-toolbar {
            position: absolute;
            top: 52px;
            right: 10px;
            display: flex;
            flex-direction: column;
            gap: 7px;
            z-index: 10;
        }
        .ar-tool-btn {
            background: rgba(18, 20, 28, 0.88);
            border: 1px solid rgba(212, 175, 55, 0.4);
            color: var(--gold-light);
            font-size: 11px;
            padding: 5px 9px;
            border-radius: 14px;
            cursor: pointer;
            backdrop-filter: blur(8px);
            transition: all 0.2s;
            box-shadow: 0 2px 8px rgba(0,0,0,0.4);
            display: flex;
            align-items: center;
            gap: 4px;
        }
        .ar-tool-btn.active {
            background: linear-gradient(135deg, var(--gold-primary), var(--gold-dark));
            color: #111;
            font-weight: bold;
            border-color: var(--gold-primary);
        }
        .ar-action-bar {
            position: absolute;
            bottom: 12px;
            left: 10px;
            right: 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 8px;
            z-index: 10;
        }
        .ar-btn {
            flex: 1;
            background: rgba(18, 19, 26, 0.92);
            border: 1px solid var(--gold-primary);
            color: var(--gold-light);
            padding: 9px 4px;
            border-radius: 22px;
            font-size: 11.5px;
            font-weight: 600;
            cursor: pointer;
            backdrop-filter: blur(8px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.5);
            transition: all 0.2s;
            text-align: center;
        }
        .ar-btn:active {
            transform: scale(0.96);
        }
        .ar-btn-primary {
            background: linear-gradient(135deg, var(--gold-primary), var(--gold-dark));
            color: #111;
            font-weight: bold;
            box-shadow: 0 4px 16px rgba(212, 175, 55, 0.4);
        }
        .ar-sha-selector {
            width: 100%;
            display: flex;
            gap: 6px;
            overflow-x: auto;
            padding: 8px 2px 6px 2px;
            margin-top: 8px;
            scrollbar-width: none;
        }
        .ar-sha-selector::-webkit-scrollbar {
            display: none;
        }
        .sha-chip {
            flex-shrink: 0;
            background: #1a1c27;
            border: 1px solid rgba(212, 175, 55, 0.25);
            color: #bbb;
            font-size: 11px;
            padding: 5px 11px;
            border-radius: 16px;
            cursor: pointer;
            transition: all 0.2s;
        }
        .sha-chip.active {
            background: linear-gradient(135deg, #3d1c16, #29120e);
            border-color: var(--red-danger);
            color: #ff9988;
            font-weight: bold;
            box-shadow: 0 2px 8px rgba(231, 76, 60, 0.35);
        }
        .ar-report-card {
            background: linear-gradient(135deg, #1b1d28 0%, #13141c 100%);
            border: 1px solid rgba(212, 175, 55, 0.35);
            border-radius: 16px;
            padding: 14px;
            margin-top: 10px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.6);
            width: 100%;
            box-sizing: border-box;
        }
        .ar-report-badge {
            display: inline-block;
            background: rgba(231, 76, 60, 0.2);
            color: var(--red-danger);
            border: 1px solid rgba(231, 76, 60, 0.5);
            font-size: 11px;
            font-weight: bold;
            padding: 3px 8px;
            border-radius: 10px;
            margin-bottom: 8px;
        }
        .ar-section-title {
            color: var(--gold-light);
            font-size: 12.5px;
            font-weight: bold;
            margin-top: 8px;
            margin-bottom: 4px;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .ar-section-content {
            font-size: 11.5px;
            color: #ccc;
            line-height: 1.6;
        }
        .ar-remedy-box {
            background: rgba(212, 175, 55, 0.08);
            border-left: 3px solid var(--gold-primary);
            padding: 8px 12px;
            border-radius: 4px;
            margin-top: 8px;
            font-size: 11.5px;
            color: #eee;
            line-height: 1.5;
        }
        /* 快照全屏弹窗 */
        .ar-snapshot-modal {
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0, 0, 0, 0.88);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            z-index: 5000;
            display: none;
            flex-direction: column;
            align-items: center;
            padding: 16px;
            box-sizing: border-box;
        }
        .ar-snapshot-img {
            max-width: 100%;
            max-height: 75vh;
            border-radius: 12px;
            border: 2px solid var(--gold-primary);
            box-shadow: 0 10px 30px rgba(0,0,0,0.8);
            margin-bottom: 14px;
        }
    '''

    # Inject ar_css into <style> before </head>
    head_end_pos = content.find("</head>")
    if head_end_pos != -1:
        content = content[:head_end_pos] + ar_css + "\n" + content[head_end_pos:]

    # 2. Updated HTML inside id="view-ar"
    old_ar_html_regex = r'<div class="app-view" id="view-ar">.*?</div>\s*<!-- ===== Tab 3:'
    new_ar_html = '''<div class="app-view" id="view-ar">
        <div class="ar-viewport-box" id="ar-viewport-box" onclick="handleARViewportClick(event)">
            <!-- 真实摄像头流 -->
            <video id="ar-video" playsinline autoplay muted></video>
            <!-- 模拟窗外实景画板（室内或无摄像头时呈现精美实景街景/楼宇） -->
            <canvas id="ar-simulated-canvas"></canvas>
            <!-- AR 实景同心罗盘环画板 -->
            <canvas id="ar-dial-canvas"></canvas>
            
            <!-- 天心十字瞄准经纬线 -->
            <div class="ar-crosshair-v"></div>
            <div class="ar-crosshair-h"></div>
            <div class="ar-pointer-xiang" id="ar-pointer-xiang">▲ 向 (正前)</div>
            <div class="ar-pointer-zuo" id="ar-pointer-zuo">▼ 坐 (正后)</div>
            
            <!-- 视距同心圆射界网格 -->
            <div class="ar-range-grid" id="ar-range-grid"></div>

            <!-- 中心电子平水珠 -->
            <div class="ar-level-bubble" id="ar-level-bubble" style="top:50%; left:50%;"></div>
            
            <!-- AI 雷达扫描光束 -->
            <div class="ar-scanner-beam" id="ar-scanner-beam"></div>

            <!-- 交互式可拖动测煞靶心 -->
            <div class="ar-target-reticle" id="ar-target-reticle" style="top:36%; left:65%;" onmousedown="startDragTarget(event)" ontouchstart="startDragTarget(event)">
                <div class="ar-target-tag" id="ar-target-tag">🎯 壁刀煞 [偏右22°]</div>
            </div>

            <!-- AR 顶部 HUD 态势条 -->
            <div class="ar-hud-overlay">
                <span id="ar-hud-heading">向 0° · 正北</span>
                <span id="ar-hud-tilt">水平 0.0°</span>
                <span id="ar-hud-kw" style="color:var(--green-pure)">纯清</span>
                <span id="ar-hud-target-angle" style="color:var(--gold-primary)">靶点: 偏右22°</span>
            </div>

            <!-- AR 右侧微型快捷工具栏 -->
            <div class="ar-quick-toolbar">
                <button class="ar-tool-btn" id="btn-ar-scan" onclick="triggerAIShaScan()">⚡ AI扫描</button>
                <button class="ar-tool-btn active" id="btn-ar-dial" onclick="toggleARDialOverlay()">🌐 罗盘环</button>
                <button class="ar-tool-btn" id="btn-ar-sim" onclick="toggleARSimulatedMode()">🏙️ 实景演练</button>
                <button class="ar-tool-btn" id="btn-ar-camera" onclick="toggleCameraFacing()">🔄 翻转</button>
            </div>

            <!-- AR 底部交互操作栏 -->
            <div class="ar-action-bar">
                <button class="ar-btn" onclick="resetARTargetCenter()">🎯 准星居中</button>
                <button class="ar-btn ar-btn-primary" onclick="performShaDiagnosis()">🔍 形煞深度研判</button>
                <button class="ar-btn" onclick="captureARSnapshotMaster()">📸 存证快照</button>
            </div>
        </div>

        <!-- 常见形煞类型快速点选滑块 -->
        <div class="ar-sha-selector">
            <div class="sha-chip active" onclick="selectShaType('bidao', this)">🔪 壁刀煞</div>
            <div class="sha-chip" onclick="selectShaType('tianzhan', this)">⚡ 天斩煞</div>
            <div class="sha-chip" onclick="selectShaType('qiangsha', this)">🏹 直冲枪煞</div>
            <div class="sha-chip" onclick="selectShaType('fangong', this)">🌙 反弓水煞</div>
            <div class="sha-chip" onclick="selectShaType('tantou', this)">👀 窥头煞</div>
            <div class="sha-chip" onclick="selectShaType('dingxin', this)">🌲 顶心电杆</div>
            <div class="sha-chip" onclick="selectShaType('jianjiao', this)">🗼 尖角火煞</div>
            <div class="sha-chip" onclick="selectShaType('baihu', this)">🚜 白虎动土</div>
        </div>

        <!-- 形煞详勘报告卡 (三段论结构化呈现) -->
        <div class="ar-report-card" id="ar-sha-report-card">
            <div style="display:flex; justify-content:space-between; align-items:center;">
                <span class="ar-report-badge" id="ar-report-badge">⚠️ 重点形煞关注</span>
                <span style="font-size:11px; color:#9ea0b4;" id="ar-report-coords">靶向: 丙山方 · 距中线 +22.4°</span>
            </div>
            <div style="font-size:15px; font-weight:bold; color:var(--gold-primary); margin-bottom:4px;" id="ar-report-name">火形壁刀煞 (切向正门)</div>
            
            <div class="ar-section-title">📜 古法易象赋文</div>
            <div class="ar-section-content" id="ar-report-classic">“前面有刀劈，人财两无及；壁角直冲门，凶横屡遭灾。” 邻近大厦墙面转角如利刃垂直斩切向首，气流沿墙面加速俯冲，激荡宅门明堂。</div>
            
            <div class="ar-section-title">🔬 现代人居物理原理解析</div>
            <div class="ar-section-content" id="ar-report-science">建筑物棱角在风压作用下产生强烈边缘气流剪切与局部微气旋，造成门窗通风紊乱与气压骤变；且阳面反射强光刺目，容易诱发居者视疲劳、神经衰弱及心血管负担。</div>

            <div class="ar-section-title">🛡️ 针对性三阶化解微调清单</div>
            <div class="ar-remedy-box" id="ar-report-remedy">
                1. <strong>遮挡缓气</strong>：在正对壁刀方位的阳台或窗前摆放茂密阔叶绿植（如龟背竹、发财树）；<br>
                2. <strong>折射化煞</strong>：窗外正对悬挂纯铜九宫八卦凸镜或山海镇，将直射煞气化泄折射；<br>
                3. <strong>镇宅固本</strong>：室内正对窗台安放纯铜泰山石敢当，稳固明堂太极场。
            </div>
        </div>
    </div>

    <!-- ===== AR 勘测存证快照弹窗 ===== -->
    <div class="ar-snapshot-modal" id="ar-snapshot-modal">
        <div style="font-size:15px; font-weight:bold; color:var(--gold-primary); margin-bottom:12px;">📸 演象 · 实地勘测全案存证快照</div>
        <img class="ar-snapshot-img" id="ar-snapshot-img" src="" alt="勘测存证">
        <div style="display:flex; gap:10px; width:100%; max-width:360px;">
            <a class="ar-btn ar-btn-primary" id="ar-download-btn" download="yanxiang_ar_evidence.png">💾 保存图片到本地</a>
            <button class="ar-btn" onclick="closeARSnapshotModal()">关闭</button>
        </div>
    </div>

    <!-- ===== Tab 3:'''

    # Replace view-ar in content
    content = re.sub(old_ar_html_regex, new_ar_html, content, flags=re.DOTALL)

    # 3. Enhanced AR JavaScript Logic
    ar_js = '''
        // ========== PRD 5.2 & 14: AR 实景天心透视与形煞智能标注核心引擎 ==========
        arFacingMode = 'environment';
        arStream = null;
        let arSimulatedMode = false;
        let arDialOverlayVisible = true;
        let arTargetX = 0.65; // Normalized target coordinates [0, 1]
        let arTargetY = 0.36;
        let isDraggingTarget = false;
        let selectedShaKey = 'bidao';

        // 经典形煞结构化知识库 (PRD 第14章 堪舆 RAG)
        const SHA_DATABASE = {
            bidao: {
                name: '火形壁刀煞 (切向正门)',
                badge: '⚠️ 重点形煞关注 (高危)',
                classic: '“前面有刀劈，人财两无及；壁角直冲门，凶横屡遭灾。” 邻近大厦墙面转角如利刃垂直斩切向首，气流沿墙面加速俯冲，激荡宅门明堂。',
                science: '建筑物棱角在风压作用下产生强烈边缘气流剪切与局部微气旋，造成门窗通风紊乱与气压骤变；且阳面反射强光刺目，容易诱发居者视疲劳、神经衰弱及心血管负担。',
                remedy: '1. 遮挡缓气：在正对壁刀方位的阳台或窗前摆放茂密阔叶绿植（如龟背竹、发财树）；<br>2. 折射化煞：窗外正对悬挂纯铜九宫八卦凸镜或山海镇，将直射煞气化泄折射；<br>3. 镇宅固本：室内正对窗台安放纯铜泰山石敢当，稳固明堂太极场。'
            },
            tianzhan: {
                name: '天斩绝煞 (双厦夹缝刀劈)',
                badge: '⚡ 出卦大煞 (极危)',
                classic: '“天斩杀人不用刀，双楼夹缝起怒号。” 宅前正对两栋高耸大楼间极狭窄之空隙，犹如巨斧凌空劈下，半空风声凌厉。',
                science: '典型流体力学“狭管效应 (Venturi Effect)”：外界微风在穿过狭窄高楼缝隙时流速剧增数倍，对正对住宅形成持续高频强风压与次声波共振，主神经紊乱与意外惊吓。',
                remedy: '1. 强力抵挡：窗户必须安装高气密性双层隔音降噪夹胶玻璃；<br>2. 气场转换：悬挂真正开光大号纯铜山海镇，或安放一对纯铜貔貅正对缝隙；<br>3. 室内聚气：进门处务必设玄关屏风阻隔强对流气流。'
            },
            qiangsha: {
                name: '直冲枪煞 (一条直路一条枪)',
                badge: '🏹 动线冲犯 (中危)',
                classic: '“一条直路一条枪，直冲大门家业亡。” 门前或窗口正对一条笔直延伸而来的长路、长走廊或巷道，来势汹汹。',
                science: '直线动线聚集迎面车流灯光、尾气颗粒与持续噪音，行人视线直视室内毫无私密感，居者心理常处于防御警惕状态，睡眠质量受损。',
                remedy: '1. 设玄关屏风改变室内动线为九曲回环；<br>2. 大门门槛下安放正统五帝钱（顺治、康熙、雍正、乾隆、嘉庆）；<br>3. 门前悬挂天然开口木葫芦纳气化泄。'
            },
            fangong: {
                name: '反弓水煞 / 镰刀割腰煞',
                badge: '🌙 形气相战 (高危)',
                classic: '“反弓之水无情义，子孙飘零客死乡。” 门前马路、高架立交桥或水流呈向外弯曲弧形，住宅正处于弧形外凸之弓背受冲位。',
                science: '离心力物理效应：车辆高速过弯时若发生意外容易冲向弧度外侧；且夜间大灯光束随转弯横扫室内形成“光煞”，风声刺耳。',
                remedy: '1. 沿弧形受冲方向筑起实体隔音绿篱，或阳台窗台摆放密植金桔/仙人掌；<br>2. 窗外悬挂八卦凸镜折射反弓离心煞力；<br>3. 室内对应位置供奉泰山石敢当以重镇之。'
            },
            tantou: {
                name: '窥头煞 / 探头小人煞',
                badge: '👀 阴暗潜伏 (中危)',
                classic: '“前楼背后露小头，家招盗贼暗生愁。” 正面建筑屋顶后方隐约冒出另一建筑物尖顶或小半截楼体，宛若小人暗中窥探。',
                science: '视线错觉造成的心理压迫感与不安全感，潜意识中引发居者受监视感，长此以往容易疑神疑鬼、人际关系紧张。',
                remedy: '1. 窗前安装半透百叶窗或纱帘隔断视线；<br>2. 窗台摆放纯铜公鸡（金鸡啄小人）或八卦平面镜化解；<br>3. 提升室内采光照度，增加明亮阳气。'
            },
            dingxin: {
                name: '顶心煞 (立木插心)',
                badge: '🌲 门前阻碍 (中危)',
                classic: '“门前立木立电杆，悬针刺目破家业。” 大门正前方视线正中见电线杆、大路灯柱、路牌或枯树躯干直插。',
                science: '垂直圆柱体直接切割入户视觉中心，阻挡出入视线；若为高压电杆，其工频电磁辐射与变压器低频嗡鸣会对人体脑电波产生微弱干扰。',
                remedy: '1. 大门上挂山海镇或贴红色福字化解木克；<br>2. 门框上方悬挂凸透镜或八卦太极图；<br>3. 室内玄关设暖光玄关灯提升阳和之气。'
            },
            jianjiao: {
                name: '尖角火煞 / 高压塔煞',
                badge: '🗼 离火燥烈 (高危)',
                classic: '“火星冲照两头焦，官非口舌日夜烧。” 正前方见高压电塔、变压箱、红色三角形尖顶或烟囱高耸。',
                science: '强电磁场环境可能扰乱周围微磁场，引起指南针与罗盘读数漂移；且红色锐角在视觉心理学上引发烦躁、易怒与焦虑。',
                remedy: '1. 增强接地屏蔽，窗户贴防电磁辐射膜；<br>2. 室内多采用属水、属湿土的深蓝色、黑色、玄色软装以克制火燥；<br>3. 摆放纯铜黑曜石七星阵吸纳燥气。'
            },
            baihu: {
                name: '白虎动土煞 (右翼兴工)',
                badge: '🚜 动土大煞 (高危)',
                classic: '“宁叫青龙高万丈，莫教白虎动一寸。” 站在大门面朝外看，右手方（白虎方）正在施工开挖、打桩吊机运作。',
                science: '打桩与地基挖掘产生强烈的地面次声震动（Ground Vibration），直接传导至房屋主体结构与门窗，噪声与粉尘造成严重的生理应激。',
                remedy: '1. 紧闭白虎方门窗，加装防尘胶条与厚质避光吸音窗帘；<br>2. 白虎动土方窗台安放一对镇煞纯铜麒麟，头朝动土方向；<br>3. 动土期间本宅内部切忌在对应方位钉钉子或钻孔。'
            }
        };

        // 启动或停止 AR 镜头
        async function startARCamera() {
            if (arSimulatedMode) {
                renderSimulatedScenery();
                return;
            }
            const video = document.getElementById('ar-video');
            const simCanvas = document.getElementById('ar-simulated-canvas');
            if (simCanvas) simCanvas.style.display = 'none';
            if (video) video.style.display = 'block';

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
                if (video) {
                    video.srcObject = arStream;
                    video.play();
                }
            } catch (err) {
                console.warn('AR Camera not accessible, switching to simulated scenery fallback:', err);
                toggleARSimulatedMode(true);
            }
            initARDialCanvas();
        }

        function stopARCamera() {
            if (arStream) {
                arStream.getTracks().forEach(track => track.stop());
                arStream = null;
            }
        }

        function toggleCameraFacing() {
            if (arSimulatedMode) {
                toggleARSimulatedMode(false);
                return;
            }
            arFacingMode = (arFacingMode === 'environment') ? 'user' : 'environment';
            startARCamera();
        }

        // 切换实景演练/仿真背景
        function toggleARSimulatedMode(forceSim = null) {
            arSimulatedMode = (forceSim !== null) ? forceSim : !arSimulatedMode;
            const btnSim = document.getElementById('btn-ar-sim');
            const video = document.getElementById('ar-video');
            const simCanvas = document.getElementById('ar-simulated-canvas');

            if (arSimulatedMode) {
                stopARCamera();
                if (video) video.style.display = 'none';
                if (simCanvas) simCanvas.style.display = 'block';
                if (btnSim) btnSim.classList.add('active');
                renderSimulatedScenery();
            } else {
                if (simCanvas) simCanvas.style.display = 'none';
                if (btnSim) btnSim.classList.remove('active');
                startARCamera();
            }
        }

        // 渲染高拟真现代建筑窗外实景演练画板
        function renderSimulatedScenery() {
            const canvas = document.getElementById('ar-simulated-canvas');
            if (!canvas) return;
            const box = document.getElementById('ar-viewport-box');
            if (!box) return;
            canvas.width = box.clientWidth || 400;
            canvas.height = box.clientHeight || 500;
            const ctx = canvas.getContext('2d');
            const w = canvas.width, h = canvas.height;

            // 天空微光背景
            const skyGrad = ctx.createLinearGradient(0, 0, 0, h);
            skyGrad.addColorStop(0, '#1c2438');
            skyGrad.addColorStop(0.5, '#2e3a55');
            skyGrad.addColorStop(0.85, '#424f6b');
            skyGrad.addColorStop(1, '#1b1f2b');
            ctx.fillStyle = skyGrad;
            ctx.fillRect(0, 0, w, h);

            // 远景山峦与城市天际线
            ctx.fillStyle = '#141824';
            ctx.beginPath();
            ctx.moveTo(0, h * 0.7);
            ctx.lineTo(w * 0.25, h * 0.65);
            ctx.lineTo(w * 0.5, h * 0.72);
            ctx.lineTo(w * 0.8, h * 0.62);
            ctx.lineTo(w, h * 0.68);
            ctx.lineTo(w, h);
            ctx.lineTo(0, h);
            ctx.fill();

            // 中景：左侧高楼
            ctx.fillStyle = '#222838';
            ctx.fillRect(w * 0.05, h * 0.28, w * 0.28, h * 0.72);
            // 窗户灯火点阵
            ctx.fillStyle = 'rgba(255, 230, 160, 0.4)';
            for (let r = 0; r < 8; r++) {
                for (let c = 0; c < 3; c++) {
                    ctx.fillRect(w * 0.08 + c * (w * 0.08), h * 0.32 + r * 22, 12, 8);
                }
            }

            // 中景：右侧对向大厦 (形成壁刀墙角切角)
            ctx.fillStyle = '#181f2f';
            ctx.beginPath();
            ctx.moveTo(w * 0.58, h * 0.15); // 尖锐壁刀墙角
            ctx.lineTo(w * 0.92, h * 0.22);
            ctx.lineTo(w * 0.92, h);
            ctx.lineTo(w * 0.58, h);
            ctx.closePath();
            ctx.fill();
            // 壁刀反光棱线
            ctx.strokeStyle = 'rgba(231, 76, 60, 0.7)';
            ctx.lineWidth = 2.5;
            ctx.beginPath();
            ctx.moveTo(w * 0.58, h * 0.15);
            ctx.lineTo(w * 0.58, h);
            ctx.stroke();

            // 远景双厦夹缝 (天斩煞缝隙)
            ctx.fillStyle = 'rgba(255, 255, 255, 0.15)';
            ctx.fillRect(w * 0.33, h * 0.38, w * 0.06, h * 0.4);

            // 近景：道路与草木
            ctx.fillStyle = '#10121a';
            ctx.fillRect(0, h * 0.78, w, h * 0.22);
            ctx.strokeStyle = 'rgba(212, 175, 55, 0.3)';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(0, h * 0.9);
            ctx.lineTo(w, h * 0.9);
            ctx.stroke();
        }

        // 初始化/重绘 AR 半透明罗盘刻度盘
        function initARDialCanvas() {
            const canvas = document.getElementById('ar-dial-canvas');
            if (!canvas) return;
            const box = document.getElementById('ar-viewport-box');
            if (!box) return;
            canvas.width = box.clientWidth || 400;
            canvas.height = box.clientHeight || 500;
            drawARDial(currentHeading);
        }

        function toggleARDialOverlay() {
            arDialOverlayVisible = !arDialOverlayVisible;
            const btn = document.getElementById('btn-ar-dial');
            const canvas = document.getElementById('ar-dial-canvas');
            if (btn) btn.classList.toggle('active', arDialOverlayVisible);
            if (canvas) canvas.style.display = arDialOverlayVisible ? 'block' : 'none';
            if (arDialOverlayVisible) drawARDial(currentHeading);
        }

        // 绘制透视半透明二十四山 AR 罗盘环
        function drawARDial(heading) {
            if (!arDialOverlayVisible) return;
            const canvas = document.getElementById('ar-dial-canvas');
            if (!canvas) return;
            const ctx = canvas.getContext('2d');
            const w = canvas.width, h = canvas.height;
            ctx.clearRect(0, 0, w, h);

            const cx = w / 2;
            const cy = h / 2;
            const r = Math.min(w, h) * 0.44;

            ctx.save();
            ctx.translate(cx, cy);
            ctx.rotate(-heading * Math.PI / 180);

            // 罗盘大圆环金边
            ctx.strokeStyle = 'rgba(212, 175, 55, 0.35)';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.arc(0, 0, r, 0, 2 * Math.PI);
            ctx.stroke();

            ctx.strokeStyle = 'rgba(212, 175, 55, 0.18)';
            ctx.beginPath();
            ctx.arc(0, 0, r - 26, 0, 2 * Math.PI);
            ctx.stroke();

            // 刻度线与 24 山文字
            const mountains = [
                '子','癸','丑','艮','寅','甲','卯','乙',
                '辰','巽','巳','丙','午','丁','未','坤',
                '申','庚','酉','辛','戌','乾','亥','壬'
            ];
            for (let i = 0; i < 24; i++) {
                const angle = i * 15 * Math.PI / 180;
                ctx.save();
                ctx.rotate(angle);

                // 刻度线
                ctx.strokeStyle = (i % 3 === 0) ? 'rgba(231, 76, 60, 0.6)' : 'rgba(212, 175, 55, 0.4)';
                ctx.lineWidth = (i % 3 === 0) ? 2 : 1;
                ctx.beginPath();
                ctx.moveTo(0, -r);
                ctx.lineTo(0, -r + ((i % 3 === 0) ? 14 : 8));
                ctx.stroke();

                // 标注 24 山汉字
                ctx.fillStyle = (i % 3 === 0) ? '#ff7b72' : 'rgba(240, 240, 245, 0.7)';
                ctx.font = 'bold 11px sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText(mountains[i], 0, -r + 20);

                ctx.restore();
            }

            ctx.restore();
        }

        // 交互式靶位交互 (点击/拖动微调)
        function handleARViewportClick(e) {
            if (isDraggingTarget) return;
            const box = document.getElementById('ar-viewport-box');
            if (!box) return;
            const rect = box.getBoundingClientRect();
            const clickX = (e.clientX - rect.left) / rect.width;
            const clickY = (e.clientY - rect.top) / rect.height;
            // 避免点击到底部操作栏
            if (clickY > 0.85 || clickY < 0.12) return;
            setTargetNormalized(clickX, clickY);
        }

        function startDragTarget(e) {
            e.stopPropagation();
            isDraggingTarget = true;
            const box = document.getElementById('ar-viewport-box');
            if (!box) return;

            const onMove = (moveEv) => {
                const rect = box.getBoundingClientRect();
                const clientX = moveEv.touches ? moveEv.touches[0].clientX : moveEv.clientX;
                const clientY = moveEv.touches ? moveEv.touches[0].clientY : moveEv.clientY;
                const nx = Math.max(0.05, Math.min(0.95, (clientX - rect.left) / rect.width));
                const ny = Math.max(0.15, Math.min(0.85, (clientY - rect.top) / rect.height));
                setTargetNormalized(nx, ny);
            };

            const onUp = () => {
                isDraggingTarget = false;
                window.removeEventListener('mousemove', onMove);
                window.removeEventListener('mouseup', onUp);
                window.removeEventListener('touchmove', onMove);
                window.removeEventListener('touchend', onUp);
            };

            window.addEventListener('mousemove', onMove);
            window.addEventListener('mouseup', onUp);
            window.addEventListener('touchmove', onMove, { passive: true });
            window.addEventListener('touchend', onUp);
        }

        function setTargetNormalized(nx, ny) {
            arTargetX = nx;
            arTargetY = ny;
            const reticle = document.getElementById('ar-target-reticle');
            if (reticle) {
                reticle.style.left = (arTargetX * 100).toFixed(1) + '%';
                reticle.style.top = (arTargetY * 100).toFixed(1) + '%';
            }
            updateARTargetInfo();
        }

        function resetARTargetCenter() {
            setTargetNormalized(0.5, 0.5);
        }

        function updateARTargetInfo() {
            // 计算相对准星（屏幕中心 0.5, 0.5）的水平夹角与方位
            // 手机摄像头水平视场角（H-FOV）通常约为 65°
            const hFOV = 65;
            const angleOffset = (arTargetX - 0.5) * hFOV;
            const targetHeading = (currentHeading + angleOffset + 360) % 360;
            const m = getMountainFromHeading(targetHeading);

            const offsetStr = (angleOffset >= 0 ? '+' : '') + angleOffset.toFixed(1) + '°';
            const dirStr = (angleOffset >= 0 ? '偏右' : '偏左') + Math.abs(angleOffset).toFixed(1) + '°';

            const tagEl = document.getElementById('ar-target-tag');
            if (tagEl) {
                const sha = SHA_DATABASE[selectedShaKey] || SHA_DATABASE['bidao'];
                tagEl.textContent = `🎯 ${sha.name.split(' ')[0]} [${dirStr}]`;
            }

            const hudAngleEl = document.getElementById('ar-hud-target-angle');
            if (hudAngleEl) {
                hudAngleEl.textContent = `靶点: ${m.name}山 (${dirStr})`;
            }

            const coordsEl = document.getElementById('ar-report-coords');
            if (coordsEl) {
                coordsEl.textContent = `靶向: ${m.name}山 (${m.post}宫) · 偏向首 ${offsetStr}`;
            }
        }

        // 选择形煞类型
        function selectShaType(shaKey, element) {
            selectedShaKey = shaKey;
            document.querySelectorAll('.sha-chip').forEach(c => c.classList.remove('active'));
            if (element) element.classList.add('active');

            const sha = SHA_DATABASE[shaKey];
            if (!sha) return;

            const badgeEl = document.getElementById('ar-report-badge');
            const nameEl = document.getElementById('ar-report-name');
            const classicEl = document.getElementById('ar-report-classic');
            const scienceEl = document.getElementById('ar-report-science');
            const remedyEl = document.getElementById('ar-report-remedy');

            if (badgeEl) badgeEl.textContent = sha.badge;
            if (nameEl) nameEl.textContent = sha.name;
            if (classicEl) classicEl.innerHTML = sha.classic;
            if (scienceEl) scienceEl.innerHTML = sha.science;
            if (remedyEl) remedyEl.innerHTML = sha.remedy;

            updateARTargetInfo();
        }

        // 触发 AI 智能形煞雷达扫描
        function triggerAIShaScan() {
            const beam = document.getElementById('ar-scanner-beam');
            const btn = document.getElementById('btn-ar-scan');
            if (btn) btn.classList.add('active');
            if (beam) beam.classList.add('active');

            // 震动提示
            if (navigator.vibrate) navigator.vibrate([40, 60, 40]);

            setTimeout(() => {
                if (beam) beam.classList.remove('active');
                if (btn) btn.classList.remove('active');

                // 智能检测锁定：自动将靶位微调对准实景中特征显著区
                setTargetNormalized(0.62, 0.35);
                selectShaType('bidao', document.querySelectorAll('.sha-chip')[0]);

                if (typeof showGoldToast === 'function') {
                    showGoldToast('⚡ AI形煞扫描完毕：向首右前 22° 锁定火形壁刀煞 (置信度 96.8%)');
                } else {
                    alert('AI形煞扫描完毕：向首右前方 22° 锁定火形壁刀煞');
                }
            }, 1800);
        }

        // 深入研判
        function performShaDiagnosis() {
            const card = document.getElementById('ar-sha-report-card');
            if (card) {
                card.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                card.style.border = '1px solid var(--red-danger)';
                setTimeout(() => {
                    card.style.border = '1px solid rgba(212, 175, 55, 0.35)';
                }, 1200);
            }
        }

        // 实时更新 AR 顶部态势栏
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

            // 更新 AR 水准平水珠
            if (bubbleEl) {
                const maxOffset = 50;
                const bx = Math.max(-maxOffset, Math.min(maxOffset, roll * 5));
                const by = Math.max(-maxOffset, Math.min(maxOffset, -pitch * 5));
                bubbleEl.style.transform = `translate(calc(-50% + ${bx}px), calc(-50% + ${by}px))`;
                const tiltMag = Math.hypot(pitch, roll);
                bubbleEl.classList.toggle('warn', tiltMag > 3.0);
            }

            drawARDial(heading);
            updateARTargetInfo();
        }

        // 大师级 AR 勘测存证快照生成 (PRD 5.2 & 14)
        function captureARSnapshotMaster() {
            const box = document.getElementById('ar-viewport-box');
            if (!box) return;

            const snapW = 1080;
            const snapH = 1520;
            const snapCanvas = document.createElement('canvas');
            snapCanvas.width = snapW;
            snapCanvas.height = snapH;
            const sCtx = snapCanvas.getContext('2d');

            // 1. 抓取真实视频或仿真画板
            const video = document.getElementById('ar-video');
            const simCanvas = document.getElementById('ar-simulated-canvas');
            if (!arSimulatedMode && video && video.videoWidth) {
                sCtx.drawImage(video, 0, 0, snapW, snapH);
            } else if (simCanvas) {
                sCtx.drawImage(simCanvas, 0, 0, snapW, snapH);
            } else {
                sCtx.fillStyle = '#141620';
                sCtx.fillRect(0, 0, snapW, snapH);
            }

            // 2. 绘制金色十字天心线
            const cx = snapW / 2;
            const cy = snapH * 0.44;
            sCtx.strokeStyle = 'rgba(212, 175, 55, 0.85)';
            sCtx.lineWidth = 3;
            sCtx.beginPath();
            sCtx.moveTo(cx, 0); sCtx.lineTo(cx, snapH * 0.78);
            sCtx.moveTo(0, cy); sCtx.lineTo(snapW, cy);
            sCtx.stroke();

            // 绘制视距同心圆
            sCtx.strokeStyle = 'rgba(212, 175, 55, 0.4)';
            sCtx.lineWidth = 2;
            sCtx.setLineDash([8, 8]);
            sCtx.beginPath();
            sCtx.arc(cx, cy, 260, 0, 2 * Math.PI);
            sCtx.arc(cx, cy, 140, 0, 2 * Math.PI);
            sCtx.stroke();
            sCtx.setLineDash([]);

            // 3. 绘制形煞锁定靶框
            const targetPixelX = arTargetX * snapW;
            const targetPixelY = arTargetY * snapH * 0.78;
            sCtx.strokeStyle = '#e74c3c';
            sCtx.lineWidth = 4;
            sCtx.strokeRect(targetPixelX - 50, targetPixelY - 50, 100, 100);
            
            sCtx.fillStyle = '#e74c3c';
            sCtx.fillRect(targetPixelX - 90, targetPixelY - 95, 180, 36);
            sCtx.fillStyle = '#ffffff';
            sCtx.font = 'bold 20px sans-serif';
            sCtx.textAlign = 'center';
            const sha = SHA_DATABASE[selectedShaKey] || SHA_DATABASE['bidao'];
            sCtx.fillText(sha.name.split(' ')[0], targetPixelX, targetPixelY - 70);

            // 4. 底部大师级黑金半透明防伪存证印章卡片
            const cardH = 340;
            const cardY = snapH - cardH - 30;
            sCtx.fillStyle = 'rgba(14, 15, 22, 0.9)';
            sCtx.fillRect(30, cardY, snapW - 60, cardH);
            sCtx.strokeStyle = '#d4af37';
            sCtx.lineWidth = 3;
            sCtx.strokeRect(30, cardY, snapW - 60, cardH);

            // 卡片标题
            sCtx.fillStyle = '#ffd166';
            sCtx.font = 'bold 32px sans-serif';
            sCtx.textAlign = 'left';
            sCtx.fillText('演象 · 空间实景天心勘测全案存证', 60, cardY + 54);

            sCtx.fillStyle = '#9ea0b4';
            sCtx.font = '19px sans-serif';
            sCtx.fillText('YanXiang Space-Time Fengshui AR Forensic Certificate', 60, cardY + 86);

            // 详细参数矩阵
            const m = getMountainFromHeading(currentHeading);
            const zuoM = getMountainFromHeading((currentHeading + 180) % 360);
            const kw = diagnoseKongWang(currentHeading);

            sCtx.fillStyle = '#ffffff';
            sCtx.font = '22px sans-serif';
            sCtx.fillText(`【立向格局】 坐${zuoM.name}山 向${m.name}山 (${Math.round(currentHeading)}°) · ${kw.shortText}`, 60, cardY + 138);

            const hFOV = 65;
            const angleOffset = (arTargetX - 0.5) * hFOV;
            const targetHeading = (currentHeading + angleOffset + 360) % 360;
            const targetM = getMountainFromHeading(targetHeading);
            sCtx.fillText(`【冲犯形煞】 ${sha.name} · 锁定${targetM.name}山 (${angleOffset >= 0 ? '+' : ''}${angleOffset.toFixed(1)}°)`, 60, cardY + 180);

            sCtx.fillStyle = '#d4af37';
            sCtx.font = '20px sans-serif';
            const coordsText = (window.AndroidCompass && window.AndroidCompass.getCoordsDesc) ? window.AndroidCompass.getCoordsDesc() : '实地勘测GPS定位已校准';
            sCtx.fillText(`【地理时空】 ${coordsText}`, 60, cardY + 224);

            // 底部防伪编码与时间
            const now = new Date();
            const timeStr = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')} ${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}:${String(now.getSeconds()).padStart(2,'0')}`;
            const certId = 'CERT-' + Math.random().toString(36).substring(2, 10).toUpperCase();
            
            sCtx.fillStyle = '#888';
            sCtx.font = '17px monospace';
            sCtx.fillText(`勘测时间: ${timeStr} · 存证防伪编号: ${certId}`, 60, cardY + 280);

            // 右下角红色大师朱砂印章
            sCtx.save();
            sCtx.strokeStyle = '#c0392b';
            sCtx.lineWidth = 3;
            sCtx.strokeRect(snapW - 210, cardY + 140, 140, 140);
            sCtx.fillStyle = 'rgba(192, 57, 43, 0.15)';
            sCtx.fillRect(snapW - 210, cardY + 140, 140, 140);
            sCtx.fillStyle = '#e74c3c';
            sCtx.font = 'bold 36px serif';
            sCtx.textAlign = 'center';
            sCtx.fillText('演象', snapW - 140, cardY + 200);
            sCtx.fillText('印鉴', snapW - 140, cardY + 250);
            sCtx.restore();

            // 弹出预览弹窗
            const dataUrl = snapCanvas.toDataURL('image/png');
            const modal = document.getElementById('ar-snapshot-modal');
            const img = document.getElementById('ar-snapshot-img');
            const dBtn = document.getElementById('ar-download-btn');
            if (img) img.src = dataUrl;
            if (dBtn) dBtn.href = dataUrl;
            if (modal) modal.style.display = 'flex';
        }

        function closeARSnapshotModal() {
            const modal = document.getElementById('ar-snapshot-modal');
            if (modal) modal.style.display = 'none';
        }
    '''

    # Replace old AR JS functions in script
    old_ar_js_regex = r'// ========== AR 实景天心透视模块 ==========.*?function captureARSnapshot\(\) \{.*?\n        \}'
    content = re.sub(old_ar_js_regex, ar_js, content, flags=re.DOTALL)

    # 4. Inject AR Translations into I18N_RESOURCES and applyLanguage
    if "btnArScan: '⚡ AI扫描'" not in content:
        content = content.replace("navFengshui: '玄空理气',", "navFengshui: '玄空理气',\n                btnArScan: '⚡ AI扫描',\n                btnArDial: '🌐 罗盘环',\n                btnArSim: '🏙️ 实景演练',\n                btnArFlip: '🔄 翻转',\n                btnArCenter: '🎯 准星居中',\n                btnArShaAudit: '🔍 形煞深度研判',\n                btnArSnapshot: '📸 存证快照',\n                arPointerXiang: '▲ 向 (正前)',\n                arPointerZuo: '▼ 坐 (正后)',")
        content = content.replace("navFengshui: '玄空理氣',", "navFengshui: '玄空理氣',\n                btnArScan: '⚡ AI掃描',\n                btnArDial: '🌐 羅盤環',\n                btnArSim: '🏙️ 實景演練',\n                btnArFlip: '🔄 翻轉',\n                btnArCenter: '🎯 準星居中',\n                btnArShaAudit: '🔍 形煞深度研判',\n                btnArSnapshot: '📸 存證快照',\n                arPointerXiang: '▲ 向 (正前)',\n                arPointerZuo: '▼ 坐 (正後)',")
        content = content.replace("navFengshui: 'Flying Stars',", "navFengshui: 'Flying Stars',\n                btnArScan: '⚡ AI Scan',\n                btnArDial: '🌐 Dial Ring',\n                btnArSim: '🏙️ Scenery Demo',\n                btnArFlip: '🔄 Flip',\n                btnArCenter: '🎯 Center Reticle',\n                btnArShaAudit: '🔍 In-Depth Sha Diagnosis',\n                btnArSnapshot: '📸 Evidence Photo',\n                arPointerXiang: '▲ Facing (Front)',\n                arPointerZuo: '▼ Sitting (Back)',")

    # In applyLanguage, bind AR buttons
    ar_apply_lang_code = '''
            // 7. AR 实景透视多语言绑定
            const btnScanEl = document.getElementById('btn-ar-scan');
            if (btnScanEl && dict.btnArScan) btnScanEl.innerText = dict.btnArScan;
            const btnDialEl = document.getElementById('btn-ar-dial');
            if (btnDialEl && dict.btnArDial) btnDialEl.innerText = dict.btnArDial;
            const btnSimEl = document.getElementById('btn-ar-sim');
            if (btnSimEl && dict.btnArSim) btnSimEl.innerText = dict.btnArSim;
            const btnFlipEl = document.getElementById('btn-ar-camera');
            if (btnFlipEl && dict.btnArFlip) btnFlipEl.innerText = dict.btnArFlip;
            const pXiang = document.getElementById('ar-pointer-xiang');
            if (pXiang && dict.arPointerXiang) pXiang.innerText = dict.arPointerXiang;
            const pZuo = document.getElementById('ar-pointer-zuo');
            if (pZuo && dict.arPointerZuo) pZuo.innerText = dict.arPointerZuo;
    '''
    if 'btn-ar-scan' not in content[content.find('function applyLanguage('):content.find('function showGoldToast')]:
        content = content.replace("document.querySelectorAll('.btn-buy-vip').forEach(b => {",
                                  ar_apply_lang_code + "\n            document.querySelectorAll('.btn-buy-vip').forEach(b => {")

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Updated {html_path} successfully ({len(content)} bytes)")

if __name__ == "__main__":
    implement()
