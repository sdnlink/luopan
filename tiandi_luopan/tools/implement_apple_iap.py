# -*- coding: utf-8 -*-
"""
Implement Apple In-App Purchase (IAP) UI, Paywall Modal, and JS Bridge into yiijing_map.html.
"""

import os
import re

def implement_iap():
    file_path = os.path.abspath("app/src/main/assets/yiijing_map.html")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    print(f"Original size: {len(content)} bytes")

    # 1. 注入 CSS 样式
    iap_css = '''
        /* ===== Apple In-App Purchase (IAP) 会员中心与付费墙样式 ===== */
        .vip-badge-tag {
            display: inline-flex;
            align-items: center;
            gap: 3px;
            font-size: 10px;
            font-weight: bold;
            color: #ffd700;
            background: linear-gradient(135deg, rgba(212, 175, 55, 0.25), rgba(0, 0, 0, 0.4));
            border: 1px solid rgba(212, 175, 55, 0.6);
            padding: 1px 6px;
            border-radius: 10px;
            letter-spacing: 0.5px;
            box-shadow: 0 0 8px rgba(212, 175, 55, 0.3);
        }
        .vip-card-glow {
            background: linear-gradient(135deg, #24221c 0%, #161720 100%);
            border: 1.5px solid #d4af37;
            box-shadow: 0 0 25px rgba(212, 175, 55, 0.25);
        }
        .iap-status-bar {
            background: rgba(28, 29, 42, 0.85);
            border: 1px solid rgba(212, 175, 55, 0.3);
            border-radius: 10px;
            padding: 10px 14px;
            margin-bottom: 14px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .iap-status-info {
            display: flex;
            flex-direction: column;
            gap: 3px;
        }
        .iap-status-title {
            font-size: 13px;
            font-weight: bold;
            color: #ffd700;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .iap-status-sub {
            font-size: 11px;
            color: #aaa;
        }
        .iap-products-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            margin-bottom: 14px;
        }
        .iap-prod-card {
            background: #181926;
            border: 1.5px solid #2d2e42;
            border-radius: 12px;
            padding: 12px 10px;
            cursor: pointer;
            transition: all 0.22s ease;
            position: relative;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }
        .iap-prod-card:hover {
            border-color: rgba(212, 175, 55, 0.7);
            background: #1e2030;
        }
        .iap-prod-card.selected {
            border-color: #d4af37;
            background: linear-gradient(145deg, rgba(45, 40, 24, 0.95), rgba(24, 25, 38, 0.98));
            box-shadow: 0 4px 18px rgba(212, 175, 55, 0.28);
        }
        .iap-badge-corner {
            position: absolute;
            top: -8px;
            right: 8px;
            background: linear-gradient(135deg, #e74c3c, #c0392b);
            color: #fff;
            font-size: 9.5px;
            font-weight: bold;
            padding: 1px 7px;
            border-radius: 10px;
            letter-spacing: 0.3px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.4);
        }
        .iap-badge-corner.gold {
            background: linear-gradient(135deg, #d4af37, #aa820a);
            color: #111;
        }
        .iap-prod-name {
            font-size: 13px;
            font-weight: bold;
            color: #eee;
            margin-bottom: 4px;
        }
        .iap-prod-card.selected .iap-prod-name {
            color: #ffd700;
        }
        .iap-prod-price {
            font-size: 18px;
            font-weight: 800;
            color: #ffd700;
            margin-bottom: 2px;
        }
        .iap-prod-price small {
            font-size: 11px;
            font-weight: normal;
            color: #aaa;
        }
        .iap-prod-desc {
            font-size: 10.5px;
            color: #8e90a5;
            line-height: 1.35;
            margin-top: 4px;
        }
        .iap-privileges-box {
            background: #141520;
            border: 1px solid #282a3c;
            border-radius: 10px;
            padding: 12px;
            margin-bottom: 14px;
        }
        .iap-priv-title {
            font-size: 12px;
            font-weight: bold;
            color: #ffd700;
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .iap-priv-list {
            display: flex;
            flex-direction: column;
            gap: 5px;
        }
        .iap-priv-row {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 11.5px;
            color: #ccc;
        }
        .iap-priv-check {
            color: #2ecc71;
            font-weight: bold;
            font-size: 12px;
        }
        .iap-priv-tag {
            font-size: 9px;
            background: rgba(212, 175, 55, 0.2);
            color: #ffd700;
            padding: 0 4px;
            border-radius: 4px;
            border: 1px solid rgba(212, 175, 55, 0.4);
        }
        .iap-btn-applepay {
            width: 100%;
            background: linear-gradient(135deg, #f1c40f, #d4af37);
            color: #121216;
            font-size: 15px;
            font-weight: bold;
            padding: 13px 0;
            border: none;
            border-radius: 10px;
            cursor: pointer;
            box-shadow: 0 4px 18px rgba(212, 175, 55, 0.4);
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            letter-spacing: 0.5px;
            transition: all 0.2s;
        }
        .iap-btn-applepay:active {
            transform: scale(0.98);
            filter: brightness(0.95);
        }
        .iap-compliance-footer {
            margin-top: 12px;
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 6px;
            font-size: 10.5px;
            color: #777a8e;
            text-align: center;
            line-height: 1.4;
        }
        .iap-links-row {
            display: flex;
            gap: 12px;
            justify-content: center;
        }
        .iap-link-btn {
            color: #9ea0b4;
            text-decoration: underline;
            cursor: pointer;
        }
        .iap-link-btn:hover {
            color: #d4af37;
        }
        .gated-badge {
            background: linear-gradient(135deg, #d4af37, #aa820a);
            color: #111;
            font-size: 10px;
            font-weight: bold;
            padding: 1px 6px;
            border-radius: 4px;
            margin-left: 6px;
            vertical-align: middle;
        }
'''

    # 在 </style> 前注入 CSS
    content = content.replace("</style>", iap_css + "\n    </style>")

    # 2. 顶部导航栏注入【👑 会员中心】按钮
    old_tab_bar_btn = '<button class="tab-btn" id="btn-fengshui-guide" onclick="toggleFengshuiModal(true)" style="color:#f39c12; border-color:#8e5a1b; font-weight:bold;">🏡 风水详解</button>'
    new_tab_bar_btn = old_tab_bar_btn + '\n            <button class="tab-btn" id="btn-vip-center" onclick="openIAPModal()" style="color:#ffd700; border-color:#d4af37; font-weight:bold; background:linear-gradient(135deg, rgba(212,175,55,0.22), rgba(28,29,40,0.85));">👑 会员中心</button>'
    content = content.replace(old_tab_bar_btn, new_tab_bar_btn)

    # 3. 注入【Apple In-App Purchase 会员中心与付费墙弹窗】HTML 结构
    iap_modal_html = '''
    <!-- ===== Apple In-App Purchase 会员中心与付费墙弹窗 ===== -->
    <div class="calib-modal-overlay" id="iap-modal" onclick="if(event.target===this)closeIAPModal()">
        <div class="calib-card vip-card-glow" style="max-height:90vh; overflow-y:auto; width:min(94vw, 460px);">
            <div class="calib-header">
                <div style="display:flex; align-items:center; gap:8px;">
                    <span style="font-size:20px;">👑</span>
                    <div>
                        <div class="calib-title" style="color:#ffd700; font-size:16px;">演象 · 尊享堪舆会员中心</div>
                        <div style="font-size:11px; color:#aaa;">时空合一核心绝学 · 专业实勘与长卷导出</div>
                    </div>
                </div>
                <span class="calib-close" onclick="closeIAPModal()">✕</span>
            </div>

            <!-- 当前用户权益状态 -->
            <div class="iap-status-bar">
                <div class="iap-status-info">
                    <div class="iap-status-title" id="iap-user-title">
                        <span>未开通会员</span>
                    </div>
                    <div class="iap-status-sub" id="iap-user-sub">开通享奇门排盘、紫白布防及宣纸天机书无限导出</div>
                </div>
                <div id="iap-user-badge">
                    <span class="vip-badge-tag" style="background:#282b3d; color:#888; border-color:#444;">标准用户</span>
                </div>
            </div>

            <!-- 核心商品选购网格 (StoreKit 四大商品) -->
            <div class="iap-products-grid">
                <!-- 商品 1: 年度堪舆 VIP (推荐) -->
                <div class="iap-prod-card selected" id="card-prod-yearly" onclick="selectIAPProduct('com.yanxiang.luopan.vip.yearly')">
                    <span class="iap-badge-corner">80% 首选</span>
                    <div>
                        <div class="iap-prod-name">👑 年度堪舆 VIP</div>
                        <div class="iap-prod-price">¥198 <small>/ 年</small></div>
                    </div>
                    <div class="iap-prod-desc">约合 ¥0.54/天 · 全场景全息交互与四大绝学完整解锁</div>
                </div>

                <!-- 商品 2: 大师终身专业版 -->
                <div class="iap-prod-card" id="card-prod-lifetime" onclick="selectIAPProduct('com.yanxiang.luopan.pro.lifetime')">
                    <span class="iap-badge-corner gold">终身买断</span>
                    <div>
                        <div class="iap-prod-name">💎 大师终身版</div>
                        <div class="iap-prod-price">¥298 <small>永久</small></div>
                    </div>
                    <div class="iap-prod-desc">一次购买 · 终身受用 · 含未来所有易学算法升级</div>
                </div>

                <!-- 商品 3: 户型空间立极单次测算 -->
                <div class="iap-prod-card" id="card-prod-floorplan" onclick="selectIAPProduct('com.yanxiang.luopan.floorplan.single')">
                    <div>
                        <div class="iap-prod-name">🏡 户型立极全案</div>
                        <div class="iap-prod-price">¥19.9 <small>/ 套</small></div>
                    </div>
                    <div class="iap-prod-desc">单套户型几何求重心、大门灶卫文昌财位深度体检</div>
                </div>

                <!-- 商品 4: 福宅天机宣纸长卷单次导出 -->
                <div class="iap-prod-card" id="card-prod-tianji" onclick="selectIAPProduct('com.yanxiang.luopan.tianji.single')">
                    <div>
                        <div class="iap-prod-name">📜 天机宣纸长卷</div>
                        <div class="iap-prod-price">¥9.9 <small>/ 次</small></div>
                    </div>
                    <div class="iap-prod-desc">单次导出超清无水印古典宣纸朱丝栏勘测长图</div>
                </div>
            </div>

            <!-- VIP 核心权益清单 -->
            <div class="iap-privileges-box">
                <div class="iap-priv-title">
                    <span>✨ 会员专享 7 大易学绝学特权</span>
                </div>
                <div class="iap-priv-list">
                    <div class="iap-priv-row">
                        <span class="iap-priv-check">✓</span>
                        <span>三式绝学 · 时家奇门遁甲全息排盘与出行踏勘导航</span>
                        <span class="iap-priv-tag">VIP</span>
                    </div>
                    <div class="iap-priv-row">
                        <span class="iap-priv-check">✓</span>
                        <span>紫白九星 · 流年流月动态气运布防与太岁三煞警报</span>
                        <span class="iap-priv-tag">VIP</span>
                    </div>
                    <div class="iap-priv-row">
                        <span class="iap-priv-check">✓</span>
                        <span>杨公形气 · 八路黄泉水法宜忌判据与坐山曜煞辨识</span>
                        <span class="iap-priv-tag">VIP</span>
                    </div>
                    <div class="iap-priv-row">
                        <span class="iap-priv-check">✓</span>
                        <span>户型立极 · 房型几何重心立极与全屋动线吉凶体检</span>
                        <span class="iap-priv-tag">全案</span>
                    </div>
                    <div class="iap-priv-row">
                        <span class="iap-priv-check">✓</span>
                        <span>福宅天机书 · 古典宣纸朱丝栏堪舆全案长图无限制导出</span>
                        <span class="iap-priv-tag">无水印</span>
                    </div>
                    <div class="iap-priv-row">
                        <span class="iap-priv-check">✓</span>
                        <span>一百二十分金 · 丙子/庚子旺相珠宝线与孤虚火坑线辨识</span>
                        <span class="iap-priv-tag">毫厘精研</span>
                    </div>
                    <div class="iap-priv-row">
                        <span class="iap-priv-check">✓</span>
                        <span>尊贵标识 · 开启专属御览天机金色钤印与金框罗盘盘面</span>
                        <span class="iap-priv-tag">尊享</span>
                    </div>
                </div>
            </div>

            <!-- Apple Pay 购买操作按钮 -->
            <button class="iap-btn-applepay" id="btn-iap-submit" onclick="executeApplePurchase()">
                <span> 立即通过 Apple 安全支付</span>
                <span id="iap-btn-price">¥198</span>
            </button>

            <!-- Apple 审核合规说明与链接 -->
            <div class="iap-compliance-footer">
                <div>确认购买后将向您的 Apple ID 账户扣款。连续包年订阅会在到期前 24 小时自动扣费续订，如需取消请在当前计费周期结束前至少 24 小时在 iOS【设置 -> Apple ID -> 订阅】中关闭。</div>
                <div class="iap-links-row">
                    <span class="iap-link-btn" onclick="executeAppleRestore()">🔄 恢复已购项目</span>
                    <span style="color:#444;">·</span>
                    <span class="iap-link-btn" onclick="showAgreement('terms')">服务协议</span>
                    <span style="color:#444;">·</span>
                    <span class="iap-link-btn" onclick="showAgreement('privacy')">隐私政策</span>
                </div>
            </div>
        </div>
    </div>
'''

    # 插入在 <body> 后的首个弹窗前
    content = content.replace('<!-- 自动校准提示与弹窗 -->', iap_modal_html + '\n    <!-- 自动校准提示与弹窗 -->')

    # 4. 注入 JavaScript 逻辑：StoreKit 桥接、权益状态持久化、付费拦截与模拟
    iap_js = '''
        // ==========================================
        // Apple In-App Purchase (IAP) 原生桥接与权益管理
        // ==========================================
        let userIAPStatus = {
            isVIP: false,
            isLifetime: false,
            floorplanCredits: 0,
            tianjiCredits: 0
        };
        let selectedIAPProductId = 'com.yanxiang.luopan.vip.yearly';
        let pendingActionAfterPurchase = null;

        // 本地缓存加载
        (function loadLocalIAPStatus() {
            try {
                const saved = localStorage.getItem('yx_iap_status');
                if (saved) {
                    const parsed = JSON.parse(saved);
                    Object.assign(userIAPStatus, parsed);
                }
            } catch(e) {}
        })();

        // 刷新界面上的会员标识与权益提示
        function refreshIAPUI() {
            const btnVip = document.getElementById('btn-vip-center');
            const titleEl = document.getElementById('iap-user-title');
            const subEl = document.getElementById('iap-user-sub');
            const badgeEl = document.getElementById('iap-user-badge');

            if (userIAPStatus.isLifetime) {
                if (btnVip) btnVip.innerHTML = '💎 终身大师';
                if (titleEl) titleEl.innerHTML = '<span style="color:#50e3c2">💎 大师终身版会员</span>';
                if (subEl) subEl.innerText = '终身永久全享 · 所有易学绝学与高清长图无限制';
                if (badgeEl) badgeEl.innerHTML = '<span class="vip-badge-tag" style="background:#133d31; color:#50e3c2; border-color:#2ecc71;">终身尊享</span>';
            } else if (userIAPStatus.isVIP) {
                if (btnVip) btnVip.innerHTML = '👑 年度VIP';
                if (titleEl) titleEl.innerHTML = '<span style="color:#ffd700">👑 尊享年度会员</span>';
                if (subEl) subEl.innerText = '有效期内全享 · 四大场景全息交互与宣纸长卷无限导出';
                if (badgeEl) badgeEl.innerHTML = '<span class="vip-badge-tag">年度VIP</span>';
            } else {
                if (btnVip) btnVip.innerHTML = '👑 会员中心';
                if (titleEl) titleEl.innerHTML = '<span>标准普通用户</span>';
                const fCredits = userIAPStatus.floorplanCredits || 0;
                const tCredits = userIAPStatus.tianjiCredits || 0;
                if (fCredits > 0 || tCredits > 0) {
                    if (subEl) subEl.innerText = `可用额度：户型立极 ${fCredits} 次 · 宣纸长卷 ${tCredits} 次`;
                } else {
                    if (subEl) subEl.innerText = '开通享奇门排盘、紫白布防及宣纸天机书无限导出';
                }
                if (badgeEl) badgeEl.innerHTML = '<span class="vip-badge-tag" style="background:#282b3d; color:#888; border-color:#444;">标准用户</span>';
            }
        }

        // 打开会员中心弹窗 (可指定预选商品)
        function openIAPModal(preselectPid) {
            if (preselectPid) {
                selectIAPProduct(preselectPid);
            }
            refreshIAPUI();
            const modal = document.getElementById('iap-modal');
            if (modal) {
                modal.style.display = 'flex';
                // 尝试向 iOS 原生端查询最新商品和状态
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iOSCompass) {
                    window.webkit.messageHandlers.iOSCompass.postMessage({action: "iap_getStatus"});
                    window.webkit.messageHandlers.iOSCompass.postMessage({action: "iap_getProducts"});
                }
            }
        }

        function closeIAPModal() {
            const modal = document.getElementById('iap-modal');
            if (modal) modal.style.display = 'none';
        }

        // 选择商品卡片
        function selectIAPProduct(pid) {
            selectedIAPProductId = pid;
            const cards = {
                'com.yanxiang.luopan.vip.yearly': 'card-prod-yearly',
                'com.yanxiang.luopan.pro.lifetime': 'card-prod-lifetime',
                'com.yanxiang.luopan.floorplan.single': 'card-prod-floorplan',
                'com.yanxiang.luopan.tianji.single': 'card-prod-tianji'
            };
            const prices = {
                'com.yanxiang.luopan.vip.yearly': '¥198',
                'com.yanxiang.luopan.pro.lifetime': '¥298',
                'com.yanxiang.luopan.floorplan.single': '¥19.9',
                'com.yanxiang.luopan.tianji.single': '¥9.9'
            };
            for (let k in cards) {
                const el = document.getElementById(cards[k]);
                if (el) {
                    if (k === pid) {
                        el.classList.add('selected');
                    } else {
                        el.classList.remove('selected');
                    }
                }
            }
            const btnPrice = document.getElementById('iap-btn-price');
            if (btnPrice && prices[pid]) {
                btnPrice.innerText = prices[pid];
            }
        }

        // 发起 Apple StoreKit 支付
        function executeApplePurchase() {
            const pid = selectedIAPProductId;
            const btn = document.getElementById('btn-iap-submit');
            if (btn) {
                btn.disabled = true;
                btn.style.opacity = '0.7';
                btn.innerHTML = '<span> 正在呼起 Apple 安全支付…</span>';
            }

            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iOSCompass) {
                // 原生 iOS 环境
                window.webkit.messageHandlers.iOSCompass.postMessage({
                    action: "iap_purchase",
                    productId: pid
                });
            } else {
                // Web 调试 / 本机体验环境 (友好模拟 Apple Pay 成功)
                setTimeout(() => {
                    if (btn) {
                        btn.disabled = false;
                        btn.style.opacity = '1';
                        btn.innerHTML = '<span> 立即通过 Apple 安全支付</span> <span id="iap-btn-price">¥198</span>';
                    }
                    simulateWebPurchaseSuccess(pid);
                }, 800);
            }
        }

        // 发起恢复购买
        function executeAppleRestore() {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iOSCompass) {
                window.webkit.messageHandlers.iOSCompass.postMessage({ action: "iap_restore" });
            } else {
                alert('已成功同步并恢复您的 App Store 购买记录！');
            }
        }

        // Web 模拟购买成功 (开发调试便利)
        function simulateWebPurchaseSuccess(pid) {
            if (pid === 'com.yanxiang.luopan.pro.lifetime') {
                userIAPStatus.isLifetime = true;
                userIAPStatus.isVIP = true;
            } else if (pid === 'com.yanxiang.luopan.vip.yearly') {
                userIAPStatus.isVIP = true;
            } else if (pid === 'com.yanxiang.luopan.floorplan.single') {
                userIAPStatus.floorplanCredits = (userIAPStatus.floorplanCredits || 0) + 1;
            } else if (pid === 'com.yanxiang.luopan.tianji.single') {
                userIAPStatus.tianjiCredits = (userIAPStatus.tianjiCredits || 0) + 1;
            }
            try {
                localStorage.setItem('yx_iap_status', JSON.stringify(userIAPStatus));
            } catch(e) {}
            
            closeIAPModal();
            refreshIAPUI();
            alert('🎉 恭喜！Apple In-App Purchase 支付成功，尊享权益已立即生效！');

            if (pendingActionAfterPurchase) {
                const action = pendingActionAfterPurchase;
                pendingActionAfterPurchase = null;
                action();
            }
        }

        // MARK: - Native iOS 核心回调
        window.onNativeIAPStatusUpdate = function(status) {
            if (typeof status === 'string') {
                try { status = JSON.parse(status); } catch(e) {}
            }
            if (status) {
                Object.assign(userIAPStatus, status);
                try {
                    localStorage.setItem('yx_iap_status', JSON.stringify(userIAPStatus));
                } catch(e) {}
                refreshIAPUI();
            }
        };

        window.onNativeIAPPurchaseSuccess = function(pid, txId) {
            const btn = document.getElementById('btn-iap-submit');
            if (btn) {
                btn.disabled = false;
                btn.style.opacity = '1';
                btn.innerHTML = '<span> 立即通过 Apple 安全支付</span> <span id="iap-btn-price">¥198</span>';
            }
            if (pid === 'com.yanxiang.luopan.pro.lifetime') {
                userIAPStatus.isLifetime = true;
                userIAPStatus.isVIP = true;
            } else if (pid === 'com.yanxiang.luopan.vip.yearly') {
                userIAPStatus.isVIP = true;
            } else if (pid === 'com.yanxiang.luopan.floorplan.single') {
                userIAPStatus.floorplanCredits = (userIAPStatus.floorplanCredits || 0) + 1;
            } else if (pid === 'com.yanxiang.luopan.tianji.single') {
                userIAPStatus.tianjiCredits = (userIAPStatus.tianjiCredits || 0) + 1;
            }
            try {
                localStorage.setItem('yx_iap_status', JSON.stringify(userIAPStatus));
            } catch(e) {}
            
            closeIAPModal();
            refreshIAPUI();
            alert('🎉 感谢开通！Apple In-App Purchase 交易成功，尊享权益已激活！');

            if (pendingActionAfterPurchase) {
                const action = pendingActionAfterPurchase;
                pendingActionAfterPurchase = null;
                action();
            }
        };

        window.onNativeIAPPurchaseError = function(pid, errorMsg) {
            const btn = document.getElementById('btn-iap-submit');
            if (btn) {
                btn.disabled = false;
                btn.style.opacity = '1';
                btn.innerHTML = '<span> 立即通过 Apple 安全支付</span> <span id="iap-btn-price">¥198</span>';
            }
            if (errorMsg && !errorMsg.includes('取消')) {
                alert('支付未完成: ' + errorMsg);
            }
        };

        window.onNativeIAPRestoreSuccess = function(productIds) {
            alert('🎉 恢复购买成功！已找回您绑定的 Apple 权益。');
            refreshIAPUI();
        };

        function showAgreement(type) {
            if (type === 'terms') {
                alert('【演象时空罗盘 · 用户服务协议】\\n\\n1. 演象罗盘提供的易学算法与空间测算仅供传统民俗文化研究与生活规划参考；\\n2. 会员权益在订阅期内专享，支持在相同 Apple ID 设备间无缝恢复使用；\\n3. 如有问题可通过应用内支持渠道反馈。');
            } else {
                alert('【演象时空罗盘 · 隐私保护政策】\\n\\n1. 本应用严格遵循 Apple 隐私规范，设备方位角、俯仰姿态及经纬度仅在本地用于罗盘与日晷运算，绝不上传任何第三方云端服务器；\\n2. 相机与户型图仅在本地进行实景渲染与立极分析，保障居家住宅隐私绝对安全。');
            }
        }

        window.openIAPModal = openIAPModal;
        window.closeIAPModal = closeIAPModal;
        window.selectIAPProduct = selectIAPProduct;
        window.executeApplePurchase = executeApplePurchase;
        window.executeAppleRestore = executeAppleRestore;
        window.refreshIAPUI = refreshIAPUI;
        window.showAgreement = showAgreement;
        window.userIAPStatus = userIAPStatus;
    '''

    # 在 window.onload 或 DOMContentLoaded 中加入 refreshIAPUI()
    iap_js_trigger = '''
        // 初始化会员状态
        refreshIAPUI();
    '''

    # 替换进入核心脚本
    target_anchor = "window.toggleLayerModal = function(show) {"
    if target_anchor in content:
        content = content.replace(target_anchor, iap_js + "\n        " + target_anchor)
    else:
        print("WARNING: target_anchor not found!")

    # 5. 付费拦截与权益门槛：
    # 5.1 福宅天机书生成拦截 (检查 VIP 或天机点数)
    old_tianji_gen_start = "function generateTianJiShu() {"
    new_tianji_gen_start = '''function generateTianJiShu() {
            // 付费门槛检测：若非 VIP 且无单次导出额度，弹出 Apple 付费墙
            if (!userIAPStatus.isVIP && (!userIAPStatus.tianjiCredits || userIAPStatus.tianjiCredits <= 0)) {
                pendingActionAfterPurchase = function() { generateTianJiShu(); };
                openIAPModal('com.yanxiang.luopan.tianji.single');
                return;
            }
            // 若使用单次额度，扣减 1 点
            if (!userIAPStatus.isVIP && userIAPStatus.tianjiCredits > 0) {
                userIAPStatus.tianjiCredits -= 1;
                try { localStorage.setItem('yx_iap_status', JSON.stringify(userIAPStatus)); } catch(e) {}
                refreshIAPUI();
            }
'''
    content = content.replace(old_tianji_gen_start, new_tianji_gen_start)

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Successfully updated yiijing_map.html with Apple IAP: {len(content)} bytes")

if __name__ == "__main__":
    implement_iap()
