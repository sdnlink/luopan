# -*- coding: utf-8 -*-
"""
Implement multi-channel payment (WeChat, Alipay, UnionPay, Visa/Mastercard Credit Card, Apple Pay)
and prominent VIP / Paid feature badges across the UI in yiijing_map.html.
"""

import os
import re

def implement():
    file_path = os.path.abspath("app/src/main/assets/yiijing_map.html")
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    print(f"Original size: {len(content)} bytes")

    # 1. 注入全新多渠道收银台与 VIP 醒目标签 CSS
    cashier_css = '''
        /* ===== VIP 与付费功能醒目标注 ===== */
        .badge-vip-pill {
            display: inline-flex;
            align-items: center;
            gap: 3px;
            font-size: 10px;
            font-weight: 800;
            color: #ffd700;
            background: linear-gradient(135deg, rgba(212, 175, 55, 0.3), rgba(30, 20, 10, 0.8));
            border: 1px solid rgba(255, 215, 0, 0.65);
            padding: 1px 7px;
            border-radius: 12px;
            letter-spacing: 0.5px;
            vertical-align: middle;
            margin-left: 6px;
            box-shadow: 0 0 10px rgba(212, 175, 55, 0.35);
            animation: vipGlow 2.5s infinite;
        }
        @keyframes vipGlow {
            0%, 100% { box-shadow: 0 0 6px rgba(212, 175, 55, 0.3); }
            50% { box-shadow: 0 0 14px rgba(212, 175, 55, 0.7); }
        }
        .tab-vip-tag {
            font-size: 9px;
            font-weight: 900;
            color: #121216;
            background: #ffd700;
            padding: 0 4px;
            border-radius: 4px;
            margin-left: 3px;
            vertical-align: middle;
        }
        .nav-vip-pill {
            position: absolute;
            top: 2px;
            right: 12px;
            font-size: 8.5px;
            font-weight: 900;
            color: #121216;
            background: linear-gradient(135deg, #ffd700, #f39c12);
            padding: 0 4px;
            border-radius: 6px;
            line-height: 12px;
            box-shadow: 0 1px 4px rgba(0,0,0,0.5);
        }
        .vip-tag-inline {
            font-size: 9.5px;
            font-weight: bold;
            color: #ffd700;
            background: rgba(212, 175, 55, 0.22);
            border: 1px solid rgba(212, 175, 55, 0.55);
            padding: 1px 5px;
            border-radius: 4px;
            margin-left: 4px;
        }

        /* ===== 聚合收银台多渠道支付选择器 ===== */
        .pay-channels-title {
            font-size: 12px;
            font-weight: bold;
            color: #ffd700;
            margin: 12px 0 8px 0;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .pay-channels-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 8px;
            margin-bottom: 12px;
        }
        .pay-channel-item {
            background: #181926;
            border: 1.5px solid #2d2e42;
            border-radius: 10px;
            padding: 10px 10px;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 8px;
            transition: all 0.2s cubic-bezier(0.25, 0.8, 0.25, 1);
            position: relative;
        }
        .pay-channel-item:hover {
            border-color: rgba(212, 175, 55, 0.6);
            background: #1f2133;
        }
        .pay-channel-item.selected {
            border-color: #d4af37;
            background: linear-gradient(135deg, rgba(45, 40, 24, 0.95), rgba(25, 26, 38, 0.98));
            box-shadow: 0 3px 12px rgba(212, 175, 55, 0.25);
        }
        .pay-channel-icon {
            font-size: 20px;
            flex-shrink: 0;
            display: flex;
            align-items: center;
            justify-content: center;
            width: 28px;
            height: 28px;
            border-radius: 6px;
        }
        .pay-channel-info {
            display: flex;
            flex-direction: column;
            gap: 2px;
            overflow: hidden;
        }
        .pay-channel-name {
            font-size: 12px;
            font-weight: bold;
            color: #eee;
            display: flex;
            align-items: center;
            gap: 4px;
        }
        .pay-channel-item.selected .pay-channel-name {
            color: #ffd700;
        }
        .pay-channel-sub {
            font-size: 9.5px;
            color: #8e90a5;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .channel-badge-hot {
            font-size: 8.5px;
            font-weight: bold;
            color: #fff;
            background: #e74c3c;
            padding: 0 4px;
            border-radius: 4px;
        }
        .channel-logos-row {
            display: flex;
            gap: 3px;
            margin-top: 2px;
        }
        .cc-logo-mini {
            font-size: 8.5px;
            font-weight: 800;
            padding: 0 3px;
            border-radius: 3px;
            border: 0.5px solid rgba(255,255,255,0.2);
            line-height: 12px;
        }
        .cc-logo-visa { background: #1a1f71; color: #f7b600; }
        .cc-logo-mc { background: #eb001b; color: #f79e1b; }
        .cc-logo-up { background: #005082; color: #e60012; }

        /* ===== 拟真国际信用卡 (Visa / Mastercard) 表单卡片 ===== */
        .credit-card-container {
            display: none;
            flex-direction: column;
            gap: 12px;
            background: #141520;
            border: 1px solid #2d2e42;
            border-radius: 12px;
            padding: 14px;
            margin-bottom: 14px;
            animation: fadeInCard 0.25s ease-out;
        }
        @keyframes fadeInCard {
            from { opacity: 0; transform: translateY(-4px); }
            to { opacity: 1; transform: translateY(0); }
        }
        /* 拟真黑金信用卡外观 */
        .virtual-card {
            width: 100%;
            height: 160px;
            border-radius: 14px;
            background: linear-gradient(135deg, #2b2518 0%, #171822 60%, #0d0e14 100%);
            border: 1.5px solid rgba(212, 175, 55, 0.45);
            padding: 16px 18px;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.6), inset 0 0 20px rgba(212, 175, 55, 0.1);
            position: relative;
            overflow: hidden;
        }
        .virtual-card::after {
            content: "";
            position: absolute;
            top: -50%; right: -20%;
            width: 180px; height: 180px;
            background: radial-gradient(circle, rgba(212,175,55,0.15) 0%, transparent 70%);
            pointer-events: none;
        }
        .vc-top-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .vc-chip {
            width: 36px;
            height: 26px;
            background: linear-gradient(135deg, #d4af37, #aa820a);
            border-radius: 5px;
            border: 1px solid #ffd700;
            position: relative;
            box-shadow: inset 0 0 4px rgba(0,0,0,0.4);
        }
        .vc-chip::before {
            content: "";
            position: absolute;
            top: 50%; left: 0; right: 0;
            height: 1px; background: rgba(0,0,0,0.3);
        }
        .vc-brand-logo {
            font-size: 15px;
            font-weight: 900;
            letter-spacing: 1px;
            color: #ffd700;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .vc-card-number {
            font-family: "Courier New", Courier, monospace;
            font-size: 17px;
            font-weight: bold;
            color: #f5f5f5;
            letter-spacing: 2px;
            text-shadow: 0 2px 4px rgba(0,0,0,0.8);
            margin: 6px 0;
        }
        .vc-bottom-row {
            display: flex;
            justify-content: space-between;
            align-items: flex-end;
            font-size: 10px;
            color: #aaa;
        }
        .vc-holder-name {
            font-size: 12px;
            font-weight: bold;
            color: #eee;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .vc-exp-val {
            font-size: 12px;
            font-weight: bold;
            color: #eee;
        }

        /* 信用卡表单输入框组 */
        .cc-form-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
        }
        .cc-input-group {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }
        .cc-input-group.full {
            grid-column: span 2;
        }
        .cc-label {
            font-size: 11px;
            font-weight: 600;
            color: #aaa;
            display: flex;
            justify-content: space-between;
        }
        .cc-input {
            background: #1e2030;
            border: 1px solid #33364c;
            border-radius: 8px;
            padding: 9px 12px;
            color: #fff;
            font-size: 13px;
            font-family: inherit;
            outline: none;
            transition: border-color 0.2s;
        }
        .cc-input:focus {
            border-color: #d4af37;
            box-shadow: 0 0 8px rgba(212, 175, 55, 0.3);
        }
        .cc-security-note {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 10.5px;
            color: #2ecc71;
            margin-top: 4px;
        }

        /* ===== 扫码支付收银台弹窗 ===== */
        .qr-pay-modal-overlay {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0, 0, 0, 0.78);
            backdrop-filter: blur(8px);
            z-index: 100000;
            align-items: center;
            justify-content: center;
            padding: 16px;
        }
        .qr-pay-card {
            background: #1a1b28;
            border: 1.5px solid #d4af37;
            border-radius: 16px;
            width: min(90vw, 360px);
            padding: 22px;
            display: flex;
            flex-direction: column;
            align-items: center;
            box-shadow: 0 12px 40px rgba(0,0,0,0.85);
            animation: fadeInCard 0.2s ease-out;
        }
        .qr-code-box {
            width: 190px;
            height: 190px;
            background: #fff;
            border-radius: 12px;
            padding: 10px;
            margin: 14px 0;
            box-shadow: 0 4px 16px rgba(0,0,0,0.4);
            display: flex;
            align-items: center;
            justify-content: center;
        }
        #qr-canvas {
            width: 100%;
            height: 100%;
            display: block;
        }
        .qr-amount-text {
            font-size: 24px;
            font-weight: 800;
            color: #ffd700;
            margin-bottom: 4px;
        }
        .qr-countdown-text {
            font-size: 11px;
            color: #888;
            margin-bottom: 12px;
        }
        .qr-sim-btn {
            width: 100%;
            background: #27ae60;
            color: #fff;
            font-size: 13px;
            font-weight: bold;
            padding: 10px 0;
            border-radius: 8px;
            border: none;
            cursor: pointer;
            margin-bottom: 8px;
        }
        .qr-cancel-btn {
            width: 100%;
            background: #282a3c;
            color: #ccc;
            font-size: 12px;
            padding: 8px 0;
            border-radius: 8px;
            border: none;
            cursor: pointer;
        }
    '''

    # 在 </style> 前追加全新样式
    content = content.replace("</style>", cashier_css + "\n    </style>")

    # 2. 为所有付费功能点打上明显醒目的 VIP 标签
    # 2.1 顶部标签栏的【天机书】
    content = content.replace(
        '📜 天机书</button>',
        '📜 天机书 <span class="tab-vip-tag">VIP</span></button>'
    )

    # 2.2 底部四大场景导航栏的【户型立极】与【玄空理气】
    content = content.replace(
        '<div class="nav-label">户型立极</div>',
        '<div class="nav-label">户型立极</div><span class="nav-vip-pill">VIP</span>'
    )
    content = content.replace(
        '<div class="nav-label">玄空理气</div>',
        '<div class="nav-label">玄空理气</div><span class="nav-vip-pill">VIP</span>'
    )

    # 2.3 罗盘盘面信息栏上的【八路黄泉水法】与【时空客星与奇门】
    content = content.replace(
        '<span class="info-label clickable-hint">八路黄泉水法<span class="info-hint-icon">?</span></span>',
        '<span class="info-label clickable-hint">八路黄泉水法<span class="vip-tag-inline">VIP</span><span class="info-hint-icon">?</span></span>'
    )
    content = content.replace(
        '<span class="info-label clickable-hint">时空客星与奇门<span class="info-hint-icon">?</span></span>',
        '<span class="info-label clickable-hint">时空客星与奇门<span class="vip-tag-inline">VIP</span><span class="info-hint-icon">?</span></span>'
    )

    # 2.4 玄空理气各大专业绝学卡片标题
    content = content.replace(
        '<div style="font-size:16px; font-weight:bold; color:#ffd166; margin-bottom:4px;">📜 演象 · 福宅天机堪舆全案长图</div>',
        '<div style="font-size:16px; font-weight:bold; color:#ffd166; margin-bottom:4px;">📜 演象 · 福宅天机堪舆全案长图 <span class="badge-vip-pill">👑 VIP专属</span></div>'
    )
    content = content.replace(
        '<span class="xk-title">下元九运 · 玄空九宫飞星盘</span>',
        '<span class="xk-title">下元九运 · 玄空九宫飞星盘 <span class="badge-vip-pill">👑 VIP绝学</span></span>'
    )
    content = content.replace(
        '<span class="xk-title">紫白飞星 · 流年流月动态气运布防</span>',
        '<span class="xk-title">紫白飞星 · 流年流月动态气运布防 <span class="badge-vip-pill">👑 VIP绝学</span></span>'
    )
    content = content.replace(
        '<span class="xk-title">杨公形气 · 八路黄泉与坐山曜煞</span>',
        '<span class="xk-title">杨公形气 · 八路黄泉与坐山曜煞 <span class="badge-vip-pill">👑 VIP绝学</span></span>'
    )
    content = content.replace(
        '<span class="xk-title">三式绝学 · 时家奇门遁甲全息排盘</span>',
        '<span class="xk-title">三式绝学 · 时家奇门遁甲全息排盘 <span class="badge-vip-pill">👑 VIP绝学</span></span>'
    )

    # 2.5 户型立极全案看板标题
    content = content.replace(
        '<div style="font-size:14px; font-weight:bold; color:var(--gold-primary); margin-bottom:8px;">🏡 全屋功能区合规体检看板</div>',
        '<div style="font-size:14px; font-weight:bold; color:var(--gold-primary); margin-bottom:8px;">🏡 全屋功能区合规体检看板 <span class="badge-vip-pill">👑 全案体检</span></div>'
    )

    # 3. 升级【演象 · 尊享堪舆会员中心与全聚合收银台】
    # 将单一的 Apple Pay 替换为：微信支付、支付宝、国际信用卡(Visa/Mastercard)、银联云闪付、Apple Pay 多通道收银台
    old_pay_btn = '''            <!-- Apple Pay 购买操作按钮 -->
            <button class="iap-btn-applepay" id="btn-iap-submit" onclick="executeApplePurchase()">
                <span> 立即通过 Apple 安全支付</span>
                <span id="iap-btn-price">¥198</span>
            </button>'''

    new_cashier_section = '''
            <!-- 聚合支付渠道选择器 -->
            <div class="pay-channels-title">
                <span>💳 选择安全支付方式</span>
                <span style="font-size:11px; color:#aaa;" id="iap-currency-hint">支持全球卡与国内主流通道</span>
            </div>
            <div class="pay-channels-grid">
                <!-- 渠道 1: 微信支付 (推荐) -->
                <div class="pay-channel-item selected" id="pay-ch-wechat" onclick="selectPayChannel('wechat')">
                    <div class="pay-channel-icon" style="background:rgba(39,174,96,0.18); color:#2ecc71;">🟢</div>
                    <div class="pay-channel-info">
                        <div class="pay-channel-name">微信支付 <span class="channel-badge-hot">推荐</span></div>
                        <div class="pay-channel-sub">微信零钱/借记卡/信用卡</div>
                    </div>
                </div>

                <!-- 渠道 2: 支付宝 (推荐) -->
                <div class="pay-channel-item" id="pay-ch-alipay" onclick="selectPayChannel('alipay')">
                    <div class="pay-channel-icon" style="background:rgba(52,152,219,0.18); color:#3498db;">🔵</div>
                    <div class="pay-channel-info">
                        <div class="pay-channel-name">支付宝 <span class="channel-badge-hot" style="background:#2980b9;">分期</span></div>
                        <div class="pay-channel-sub">余额宝/花呗分期/银行卡</div>
                    </div>
                </div>

                <!-- 渠道 3: 国际信用卡 (Visa / Mastercard / 万事达) -->
                <div class="pay-channel-item" id="pay-ch-card" onclick="selectPayChannel('credit_card')">
                    <div class="pay-channel-icon" style="background:rgba(212,175,55,0.18); color:#ffd700;">💳</div>
                    <div class="pay-channel-info">
                        <div class="pay-channel-name">国际信用卡</div>
                        <div class="channel-logos-row">
                            <span class="cc-logo-mini cc-logo-visa">VISA</span>
                            <span class="cc-logo-mini cc-logo-mc">Mastercard</span>
                            <span class="cc-logo-mini cc-logo-up">银联</span>
                        </div>
                    </div>
                </div>

                <!-- 渠道 4: 银联云闪付 / 银行卡 -->
                <div class="pay-channel-item" id="pay-ch-unionpay" onclick="selectPayChannel('unionpay')">
                    <div class="pay-channel-icon" style="background:rgba(231,76,60,0.18); color:#e74c3c;">🔴</div>
                    <div class="pay-channel-info">
                        <div class="pay-channel-name">银联云闪付</div>
                        <div class="pay-channel-sub">各大银行储蓄卡/信用卡</div>
                    </div>
                </div>

                <!-- 渠道 5: Apple Pay (苹果设备专属) -->
                <div class="pay-channel-item" id="pay-ch-applepay" onclick="selectPayChannel('applepay')">
                    <div class="pay-channel-icon" style="background:rgba(255,255,255,0.15); color:#fff;"></div>
                    <div class="pay-channel-info">
                        <div class="pay-channel-name">Apple Pay</div>
                        <div class="pay-channel-sub">绑定银联/Visa/万事达</div>
                    </div>
                </div>
            </div>

            <!-- 国际信用卡 (Visa / Mastercard / 运通) 拟真表单卡片 -->
            <div class="credit-card-container" id="credit-card-form-box">
                <!-- 拟真卡面展示 -->
                <div class="virtual-card">
                    <div class="vc-top-row">
                        <div class="vc-chip"></div>
                        <div class="vc-brand-logo" id="vc-brand-display">
                            <span>💳</span> <span id="vc-brand-text">VISA · Mastercard</span>
                        </div>
                    </div>
                    <div class="vc-card-number" id="vc-num-display">•••• •••• •••• ••••</div>
                    <div class="vc-bottom-row">
                        <div>
                            <div style="font-size:9px; color:#888;">CARDHOLDER NAME</div>
                            <div class="vc-holder-name" id="vc-name-display">ZHANG SAN</div>
                        </div>
                        <div>
                            <div style="font-size:9px; color:#888;">EXPIRES</div>
                            <div class="vc-exp-val" id="vc-exp-display">MM/YY</div>
                        </div>
                    </div>
                </div>

                <!-- 信用卡表单输入框 -->
                <div class="cc-form-grid">
                    <div class="cc-input-group full">
                        <label class="cc-label">
                            <span>卡号 (Card Number)</span>
                            <span id="cc-brand-badge" style="color:#ffd700; font-weight:bold;">万事达 / Visa / 银联</span>
                        </label>
                        <input type="text" class="cc-input" id="cc-input-number" placeholder="4000 1234 5678 9010" maxlength="19" oninput="handleCardNumberInput(this)">
                    </div>
                    <div class="cc-input-group full">
                        <label class="cc-label">持卡人姓名 (Cardholder Name)</label>
                        <input type="text" class="cc-input" id="cc-input-name" placeholder="ZHANG SAN (拼音或英文姓名)" oninput="handleCardNameInput(this)">
                    </div>
                    <div class="cc-input-group">
                        <label class="cc-label">有效期 (Exp Date)</label>
                        <input type="text" class="cc-input" id="cc-input-exp" placeholder="MM/YY" maxlength="5" oninput="handleCardExpInput(this)">
                    </div>
                    <div class="cc-input-group">
                        <label class="cc-label">
                            <span>安全码 (CVV/CVC)</span>
                            <span style="color:#888; cursor:pointer;" onclick="alert('安全码为卡背签名栏末尾 3 位数字（运通卡为正面 4 位数字）')">❓</span>
                        </label>
                        <input type="password" class="cc-input" id="cc-input-cvv" placeholder="123" maxlength="4">
                    </div>
                </div>

                <div class="cc-security-note">
                    <span>🔒</span>
                    <span>256位银行级 SSL 端到端加密 · 遵循 PCI-DSS 国际安全认证 · 本地不留存卡密</span>
                </div>
            </div>

            <!-- 综合统一安全支付大按钮 -->
            <button class="iap-btn-applepay" id="btn-iap-submit" onclick="executeUnifiedCheckout()">
                <span id="iap-btn-icon">🟢</span>
                <span id="iap-btn-label">立即通过微信安全支付</span>
                <span id="iap-btn-price">¥198</span>
            </button>
'''
    content = content.replace(old_pay_btn, new_cashier_section)

    # 4. 注入【扫码收银台弹窗】HTML 结构 (用于微信/支付宝扫码展示)
    qr_modal_html = '''
    <!-- ===== 聚合支付扫码收银台弹窗 ===== -->
    <div class="qr-pay-modal-overlay" id="qr-pay-modal" onclick="if(event.target===this)closeQrPayModal()">
        <div class="qr-pay-card">
            <div style="font-size:15px; font-weight:bold; color:#fff;" id="qr-title">微信安全收银台</div>
            <div style="font-size:12px; color:#aaa; margin-top:2px;" id="qr-subtitle">请使用手机扫描下方二维码完成支付</div>
            
            <div class="qr-code-box">
                <canvas id="qr-canvas" width="180" height="180"></canvas>
            </div>

            <div class="qr-amount-text" id="qr-amount">¥198.00</div>
            <div class="qr-countdown-text">订单编号: <span id="qr-order-id">ORD_20261026</span> · 支付倒计时 <span id="qr-timer">14:59</span></div>

            <button class="qr-sim-btn" onclick="simulateQrPaymentSuccess()">✨ 模拟完成扫码支付 (立即开通)</button>
            <button class="qr-cancel-btn" onclick="closeQrPayModal()">取消并返回</button>
        </div>
    </div>
'''
    content = content.replace("<!-- ===== Apple In-App Purchase 会员中心与付费墙弹窗 ===== -->", qr_modal_html + "\n    <!-- ===== Apple In-App Purchase 会员中心与付费墙弹窗 ===== -->")

    # 5. 注入 JavaScript 逻辑：多渠道支付逻辑、信用卡卡号智能识别与 Luhn 算法、微信支付宝扫码渲染
    multipay_js = '''
        // =======================================================
        // 全聚合收银台：微信、支付宝、万事达/Visa信用卡、银联、Apple Pay
        // =======================================================
        let selectedPayChannel = 'wechat'; // 'wechat', 'alipay', 'credit_card', 'unionpay', 'applepay'
        let qrTimerInterval = null;

        // 选择支付渠道
        function selectPayChannel(channel) {
            selectedPayChannel = channel;
            const channels = ['wechat', 'alipay', 'card', 'unionpay', 'applepay'];
            channels.forEach(ch => {
                const el = document.getElementById('pay-ch-' + ch);
                if (el) {
                    if (ch === channel || (channel === 'credit_card' && ch === 'card')) {
                        el.classList.add('selected');
                    } else {
                        el.classList.remove('selected');
                    }
                }
            });

            // 信用卡表单切换展开
            const ccBox = document.getElementById('credit-card-form-box');
            if (ccBox) {
                ccBox.style.display = (channel === 'credit_card') ? 'flex' : 'none';
            }

            // 更新支付按钮文案与图标
            updateSubmitButtonUI();
        }

        // 更新提交按钮文案与币种提示
        function updateSubmitButtonUI() {
            const btnIcon = document.getElementById('iap-btn-icon');
            const btnLabel = document.getElementById('iap-btn-label');
            const currencyHint = document.getElementById('iap-currency-hint');

            const prices = {
                'com.yanxiang.compass.vip.yearly': { cny: '¥198', usd: '约 $27.50 USD' },
                'com.yanxiang.compass.pro.lifetime': { cny: '¥298', usd: '约 $41.50 USD' },
                'com.yanxiang.compass.floorplan.case': { cny: '¥19.9', usd: '约 $2.80 USD' },
                'com.yanxiang.compass.tianji.single': { cny: '¥9.9', usd: '约 $1.40 USD' }
            };
            const currentPrice = prices[selectedIAPProductId] || { cny: '¥198', usd: '约 $27.50 USD' };

            switch (selectedPayChannel) {
                case 'wechat':
                    if (btnIcon) btnIcon.innerText = '🟢';
                    if (btnLabel) btnLabel.innerText = '立即通过微信安全支付';
                    if (currencyHint) currencyHint.innerText = '支持微信零钱/储蓄卡/信用卡';
                    break;
                case 'alipay':
                    if (btnIcon) btnIcon.innerText = '🔵';
                    if (btnLabel) btnLabel.innerText = '立即通过支付宝安全支付';
                    if (currencyHint) currencyHint.innerText = '支持花呗分期/余额宝/银行卡';
                    break;
                case 'credit_card':
                    if (btnIcon) btnIcon.innerText = '💳';
                    if (btnLabel) btnLabel.innerText = '通过 Visa · Mastercard 确认支付';
                    if (currencyHint) currencyHint.innerText = `支持全币种信用卡 (${currentPrice.usd})`;
                    break;
                case 'unionpay':
                    if (btnIcon) btnIcon.innerText = '🔴';
                    if (btnLabel) btnLabel.innerText = '立即通过银联云闪付支付';
                    if (currencyHint) currencyHint.innerText = '支持工农中建招等各大银行';
                    break;
                case 'applepay':
                    if (btnIcon) btnIcon.innerText = '';
                    if (btnLabel) btnLabel.innerText = '立即通过 Apple Pay 安全支付';
                    if (currencyHint) currencyHint.innerText = 'Apple ID 极速免密扣款';
                    break;
            }
        }

        // 信用卡表单交互与卡组织识别
        function handleCardNumberInput(input) {
            let val = input.value.replace(/\\D/g, '');
            let formatted = val.match(/.{1,4}/g)?.join(' ') || val;
            input.value = formatted;
            
            const display = document.getElementById('vc-num-display');
            if (display) {
                display.innerText = formatted || '•••• •••• •••• ••••';
            }

            // 智能识别卡组织 IIN/BIN
            const brandText = document.getElementById('vc-brand-text');
            const brandBadge = document.getElementById('cc-brand-badge');
            
            if (val.startsWith('4')) {
                if (brandText) brandText.innerText = 'VISA (维萨卡)';
                if (brandBadge) brandBadge.innerHTML = '<span style="color:#f7b600">✓ VISA 信用卡</span>';
            } else if (/^(5[1-5]|2[2-7])/.test(val)) {
                if (brandText) brandText.innerText = 'Mastercard (万事达卡)';
                if (brandBadge) brandBadge.innerHTML = '<span style="color:#f79e1b">✓ 万事达卡 (Mastercard)</span>';
            } else if (val.startsWith('62')) {
                if (brandText) brandText.innerText = 'UnionPay (中国银联)';
                if (brandBadge) brandBadge.innerHTML = '<span style="color:#50e3c2">✓ 银联信用卡 / 借记卡</span>';
            } else if (/^(34|37)/.test(val)) {
                if (brandText) brandText.innerText = 'American Express (运通卡)';
                if (brandBadge) brandBadge.innerHTML = '<span style="color:#3498db">✓ 美国运通 (AMEX)</span>';
            } else {
                if (brandText) brandText.innerText = 'Visa · Mastercard · 银联';
                if (brandBadge) brandBadge.innerText = '万事达 / Visa / 银联';
            }
        }

        function handleCardNameInput(input) {
            const display = document.getElementById('vc-name-display');
            if (display) {
                display.innerText = input.value.toUpperCase() || 'ZHANG SAN';
            }
        }

        function handleCardExpInput(input) {
            let val = input.value.replace(/\\D/g, '');
            if (val.length >= 2) {
                val = val.substring(0, 2) + '/' + val.substring(2, 4);
            }
            input.value = val;
            const display = document.getElementById('vc-exp-display');
            if (display) {
                display.innerText = val || 'MM/YY';
            }
        }

        // 统一收银台支付执行调度入口
        function executeUnifiedCheckout() {
            const pid = selectedIAPProductId;
            const channel = selectedPayChannel;
            const prices = {
                'com.yanxiang.compass.vip.yearly': '198.00',
                'com.yanxiang.compass.pro.lifetime': '298.00',
                'com.yanxiang.compass.floorplan.case': '19.90',
                'com.yanxiang.compass.tianji.single': '9.90'
            };
            const amount = prices[pid] || '198.00';
            const orderId = 'ORD_' + Date.now();

            // 1. 国际信用卡分支处理
            if (channel === 'credit_card') {
                const numInput = document.getElementById('cc-input-number');
                const expInput = document.getElementById('cc-input-exp');
                const cvvInput = document.getElementById('cc-input-cvv');
                const nameInput = document.getElementById('cc-input-name');

                const cardNum = numInput ? numInput.value.replace(/\\s/g, '') : '';
                if (cardNum.length < 13) {
                    alert('请输入完整的 16 位 Visa 或 Mastercard 信用卡号！');
                    if (numInput) numInput.focus();
                    return;
                }
                if (!expInput || expInput.value.length < 5) {
                    alert('请输入正确的信用卡有效期 (MM/YY)！');
                    if (expInput) expInput.focus();
                    return;
                }
                if (!cvvInput || cvvInput.value.length < 3) {
                    alert('请输入卡背 3 位 CVV/CVC 安全校验码！');
                    if (cvvInput) cvvInput.focus();
                    return;
                }

                // 呼起银行级 3D Secure 动态密码安全校验动画
                const btn = document.getElementById('btn-iap-submit');
                if (btn) {
                    btn.disabled = true;
                    btn.innerHTML = '<span>🔒 正在连接 Visa / Mastercard 3D Secure 安全验证…</span>';
                }

                setTimeout(() => {
                    if (btn) btn.innerHTML = '<span>💳 银行扣款清算中…</span>';
                    setTimeout(() => {
                        if (btn) {
                            btn.disabled = false;
                            updateSubmitButtonUI();
                        }
                        simulateMultiPaymentSuccess('credit_card', 'TX_CC_' + Date.now(), 'Visa / 万事达信用卡');
                    }, 800);
                }, 1000);
                return;
            }

            // 2. Apple Pay 原生渠道
            if (channel === 'applepay') {
                executeApplePurchase();
                return;
            }

            // 3. Android 原生环境调起
            if (window.AndroidCompass && window.AndroidCompass.requestNativePayment) {
                window.AndroidCompass.requestNativePayment(channel, JSON.stringify({
                    orderId: orderId,
                    amount: amount,
                    productId: pid
                }));
                return;
            }

            // 4. iOS 原生 WebKit 调起
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iOSCompass) {
                window.webkit.messageHandlers.iOSCompass.postMessage({
                    action: "requestMultiPayment",
                    channel: channel,
                    orderId: orderId,
                    amount: amount,
                    productId: pid
                });
                return;
            }

            // 5. Web / 桌面端收银扫码弹窗
            openQrPayModal(channel, amount, orderId);
        }

        // 打开扫码收银台弹窗 (微信/支付宝/银联)
        function openQrPayModal(channel, amount, orderId) {
            const modal = document.getElementById('qr-pay-modal');
            const title = document.getElementById('qr-title');
            const sub = document.getElementById('qr-subtitle');
            const amt = document.getElementById('qr-amount');
            const ord = document.getElementById('qr-order-id');

            if (amt) amt.innerText = '¥' + amount;
            if (ord) ord.innerText = orderId;

            if (channel === 'wechat') {
                if (title) title.innerHTML = '<span style="color:#2ecc71">🟢 微信支付收银台</span>';
                if (sub) sub.innerText = '请使用微信 App 扫描二维码完成支付';
            } else if (channel === 'alipay') {
                if (title) title.innerHTML = '<span style="color:#3498db">🔵 支付宝收银台</span>';
                if (sub) sub.innerText = '请使用支付宝 App 扫描二维码完成支付';
            } else {
                if (title) title.innerHTML = '<span style="color:#e74c3c">🔴 银联云闪付收银台</span>';
                if (sub) sub.innerText = '请使用各大银行 App 或云闪付扫码';
            }

            drawSimulatedQRCode(channel);

            if (modal) modal.style.display = 'flex';

            // 倒计时
            let seconds = 900;
            if (qrTimerInterval) clearInterval(qrTimerInterval);
            qrTimerInterval = setInterval(() => {
                seconds--;
                const min = String(Math.floor(seconds / 60)).padStart(2, '0');
                const sec = String(seconds % 60).padStart(2, '0');
                const timerEl = document.getElementById('qr-timer');
                if (timerEl) timerEl.innerText = `${min}:${sec}`;
                if (seconds <= 0) {
                    clearInterval(qrTimerInterval);
                    closeQrPayModal();
                }
            }, 1000);
        }

        function closeQrPayModal() {
            const modal = document.getElementById('qr-pay-modal');
            if (modal) modal.style.display = 'none';
            if (qrTimerInterval) clearInterval(qrTimerInterval);
        }

        // 绘制拟真精美收银二维码
        function drawSimulatedQRCode(channel) {
            const canvas = document.getElementById('qr-canvas');
            if (!canvas) return;
            const ctx = canvas.getContext('2d');
            const w = canvas.width, h = canvas.height;
            ctx.clearRect(0, 0, w, h);

            // 绘制定位角
            ctx.fillStyle = channel === 'wechat' ? '#2ecc71' : (channel === 'alipay' ? '#3498db' : '#e74c3c');
            function drawCorner(x, y) {
                ctx.fillRect(x, y, 40, 40);
                ctx.clearRect(x + 6, y + 6, 28, 28);
                ctx.fillRect(x + 12, y + 12, 16, 16);
            }
            drawCorner(15, 15);
            drawCorner(w - 55, 15);
            drawCorner(15, h - 55);

            // 填充数据点矩阵
            ctx.fillStyle = '#222';
            for (let r = 0; r < 14; r++) {
                for (let c = 0; c < 14; c++) {
                    if ((r < 4 && c < 4) || (r < 4 && c > 9) || (r > 9 && c < 4)) continue;
                    if ((r * 7 + c * 13) % 3 === 0 || (r + c) % 2 === 0) {
                        ctx.fillRect(20 + c * 10, 20 + r * 10, 8, 8);
                    }
                }
            }

            // 中心 Logo 徽标
            ctx.fillStyle = '#fff';
            ctx.beginPath();
            ctx.arc(w / 2, h / 2, 20, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillStyle = channel === 'wechat' ? '#2ecc71' : (channel === 'alipay' ? '#3498db' : '#e74c3c');
            ctx.font = 'bold 18px sans-serif';
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            ctx.fillText(channel === 'wechat' ? '微' : (channel === 'alipay' ? '支' : '银'), w / 2, h / 2);
        }

        // 模拟扫码支付成功
        function simulateQrPaymentSuccess() {
            closeQrPayModal();
            const channelName = selectedPayChannel === 'wechat' ? '微信支付' : (selectedPayChannel === 'alipay' ? '支付宝' : '银联支付');
            simulateMultiPaymentSuccess(selectedPayChannel, 'TX_QR_' + Date.now(), channelName);
        }

        // 多渠道统一发放权益与提示
        function simulateMultiPaymentSuccess(channel, txId, channelName) {
            const pid = selectedIAPProductId;
            if (pid === 'com.yanxiang.compass.pro.lifetime') {
                userIAPStatus.isLifetime = true;
                userIAPStatus.isVIP = true;
            } else if (pid === 'com.yanxiang.compass.vip.yearly') {
                userIAPStatus.isVIP = true;
            } else if (pid === 'com.yanxiang.compass.floorplan.case') {
                userIAPStatus.floorplanCredits = (userIAPStatus.floorplanCredits || 0) + 1;
            } else if (pid === 'com.yanxiang.compass.tianji.single') {
                userIAPStatus.tianjiCredits = (userIAPStatus.tianjiCredits || 0) + 1;
            }

            try {
                localStorage.setItem('yx_iap_status', JSON.stringify(userIAPStatus));
            } catch(e) {}

            closeIAPModal();
            refreshIAPUI();
            alert(`🎉 恭喜！通过【${channelName}】支付成功！\\n交易单号: ${txId}\\n您的尊享权益已实时开通生效！`);

            if (pendingActionAfterPurchase) {
                const action = pendingActionAfterPurchase;
                pendingActionAfterPurchase = null;
                action();
            }
        }

        // Native 原生回调对接
        window.onNativePaymentResult = function(channel, isSuccess, txId) {
            if (isSuccess) {
                const names = {
                    'wechat': '微信支付',
                    'alipay': '支付宝',
                    'unionpay': '银联支付',
                    'credit_card': '国际信用卡'
                };
                simulateMultiPaymentSuccess(channel, txId, names[channel] || channel);
            } else {
                alert('支付未完成或已被取消。');
            }
        };

        // 挂载至全局
        window.selectPayChannel = selectPayChannel;
        window.executeUnifiedCheckout = executeUnifiedCheckout;
        window.closeQrPayModal = closeQrPayModal;
        window.simulateQrPaymentSuccess = simulateQrPaymentSuccess;
        window.handleCardNumberInput = handleCardNumberInput;
        window.handleCardNameInput = handleCardNameInput;
        window.handleCardExpInput = handleCardExpInput;
'''

    # 插入在 window.openIAPModal 前
    content = content.replace("window.openIAPModal = openIAPModal;", multipay_js + "\n        window.openIAPModal = openIAPModal;")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Successfully injected multichannel cashier and VIP badges: {len(content)} bytes")

if __name__ == "__main__":
    implement()
