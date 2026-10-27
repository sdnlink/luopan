import os
import re

def prepare_ios_web():
    src_file = os.path.abspath("app/src/main/assets/yiijing_map.html")
    dest_file = os.path.abspath("ios/TiandiLuopan/www/index.html")
    os.makedirs(os.path.dirname(dest_file), exist_ok=True)

    with open(src_file, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Update viewport and add iOS / PWA meta tags
    old_viewport = '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
    new_viewport = '''<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
    <meta name="apple-mobile-web-app-title" content="天机演象">
    <meta name="format-detection" content="telephone=no">
    <link rel="apple-touch-icon" href="apple-touch-icon.png">
    <link rel="manifest" href="manifest.json">'''
    content = content.replace(old_viewport, new_viewport)

    # 2. Update safe-area-inset padding for notch / dynamic island
    old_padding = 'padding: 8px 8px 24px 8px;'
    new_padding = 'padding: max(8px, env(safe-area-inset-top)) max(8px, env(safe-area-inset-right)) max(24px, env(safe-area-inset-bottom)) max(8px, env(safe-area-inset-left));'
    content = content.replace(old_padding, new_padding)

    # 3. Add iOS bridge shim and sensor permission banner
    ios_shim_code = '''
    <!-- iOS 原生桥接通道与 Safari 传感器权限组件 -->
    <style>
        #ios-sensor-banner {
            display: none;
            position: fixed;
            top: max(10px, env(safe-area-inset-top));
            left: 50%;
            transform: translateX(-50%);
            z-index: 99999;
            background: linear-gradient(135deg, #d4af37, #b8860b);
            color: #121216;
            padding: 7px 16px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: bold;
            box-shadow: 0 4px 15px rgba(0,0,0,0.6);
            cursor: pointer;
            animation: pulseBanner 2s infinite;
            white-space: nowrap;
            max-width: 90vw;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        @keyframes pulseBanner {
            0% { transform: translateX(-50%) scale(1); }
            50% { transform: translateX(-50%) scale(1.03); }
            100% { transform: translateX(-50%) scale(1); }
        }
    </style>
    <div id="ios-sensor-banner" onclick="handleIOSSensorBannerClick()">🧭 点击激活 iPhone 硬件罗盘与陀螺仪</div>
    <script>
        // iOS 原生 WebKit 消息通道映射至标准 AndroidCompass 接口
        (function initIOSNativeBridge() {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.iOSCompass) {
                const handler = window.webkit.messageHandlers.iOSCompass;
                window.AndroidCompass = {
                    isCompassAvailable: function() { return true; },
                    startCompass: function() { handler.postMessage({action: "startCompass"}); },
                    stopCompass: function() { handler.postMessage({action: "stopCompass"}); },
                    resetCalibration: function() { handler.postMessage({action: "resetCalibration"}); },
                    refreshLocation: function() { handler.postMessage({action: "refreshLocation"}); },
                    requestLocationPermission: function() { handler.postMessage({action: "requestLocationPermission"}); },
                    getPitch: function() { return window.__iosPitch || 0; },
                    getRoll: function() { return window.__iosRoll || 0; },
                    getSpeed: function() { return window.__iosSpeed || 0; },
                    getLatitude: function() { return window.__iosLat || 0; },
                    getLongitude: function() { return window.__iosLon || 0; },
                    getDeclination: function() { return window.__iosDeclination || 0; },
                    hasDeclination: function() { return !!window.__iosHasDeclination; },
                    getCoordsDesc: function() { return window.__iosCoordsDesc || ""; },
                    purchaseProduct: function(pid) { handler.postMessage({action: "iap_purchase", productId: pid}); },
                    restorePurchases: function() { handler.postMessage({action: "iap_restore"}); },
                    getIAPStatus: function() { handler.postMessage({action: "iap_getStatus"}); }
                };
            }
        })();

        function handleIOSSensorBannerClick() {
            const isSecure = window.isSecureContext || window.location.protocol === 'https:' || window.location.hostname === 'localhost';
            if (!isSecure && window.location.hostname !== 'localhost') {
                const targetHttps = 'https://' + window.location.hostname + ':8443' + window.location.pathname;
                if (confirm('iOS Safari 苹果安全规范：\n硬件陀螺仪随向旋转与真实相机必须在 HTTPS 环境下运行。\\n\\n已为你启动了 HTTPS 安全模式，是否立即切换？\\n\\n（提示：切换后若提示证书未受信任，点击【显示详细信息】->【访问此网站】即可解锁真机硬件罗盘）')) {
                    window.location.href = targetHttps;
                    return;
                }
            }
            requestIOSSensorPermission();
        }

        // iOS Safari / PWA 传感器授权处理
        function requestIOSSensorPermission() {
            if (typeof DeviceOrientationEvent !== 'undefined' && typeof DeviceOrientationEvent.requestPermission === 'function') {
                DeviceOrientationEvent.requestPermission()
                    .then(function(state) {
                        if (state === 'granted') {
                            const banner = document.getElementById('ios-sensor-banner');
                            if (banner) banner.style.display = 'none';
                            window.addEventListener('deviceorientation', handleOrientation);
                            window.addEventListener('deviceorientationabsolute', handleOrientation);
                            if (typeof showGoldToast === 'function') {
                                showGoldToast('🧭 iPhone 硬件罗盘传感器已成功激活！');
                            }
                        } else {
                            alert('未能获得方向传感器权限。您可直接在屏幕上单指触控划动盘面立向！');
                        }
                    })
                    .catch(function(err) {
                        console.error('Sensor permission error:', err);
                    });
            } else {
                // 如果没有 requestPermission API (如旧版 iOS 或已默认授权)
                window.addEventListener('deviceorientation', handleOrientation);
                window.addEventListener('deviceorientationabsolute', handleOrientation);
            }

            // 同时请求地理定位
            if (navigator.geolocation && !window.AndroidCompass) {
                navigator.geolocation.getCurrentPosition(function(pos) {
                    if (window.onNativeLocationUpdate) {
                        const c = pos.coords;
                        const latStr = Math.abs(c.latitude).toFixed(5) + '°' + (c.latitude >= 0 ? 'N' : 'S');
                        const lonStr = Math.abs(c.longitude).toFixed(5) + '°' + (c.longitude >= 0 ? 'E' : 'W');
                        const altStr = c.altitude !== null ? ' · 海拔 ' + Math.round(c.altitude) + 'm' : '';
                        const coordsStr = latStr + ', ' + lonStr + altStr;
                        window.onNativeLocationUpdate(c.latitude, c.longitude, c.altitude || 0, c.altitude !== null, coordsStr);
                    }
                }, function(err) {
                    console.warn('Geolocation warning:', err);
                }, { enableHighAccuracy: true });
            }
        }

        // 检测是否在 iOS Safari / PWA 中
        window.addEventListener('DOMContentLoaded', function() {
            const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
            if (isIOS && !window.AndroidCompass) {
                const banner = document.getElementById('ios-sensor-banner');
                const isSecure = window.isSecureContext || window.location.protocol === 'https:' || window.location.hostname === 'localhost';
                if (banner) {
                    if (!isSecure && window.location.hostname !== 'localhost') {
                        banner.innerHTML = '🧭 iOS已开启【手势触控旋转】· 点此切换 HTTPS 激活硬件陀螺仪';
                        banner.style.display = 'block';
                    } else if (typeof DeviceOrientationEvent !== 'undefined' && typeof DeviceOrientationEvent.requestPermission === 'function') {
                        banner.innerHTML = '🧭 点击激活 iPhone 硬件罗盘与陀螺仪 (60FPS随向转)';
                        banner.style.display = 'block';
                    }
                }
            }

            // 非原生环境下的 Web 定位连续监听
            if (!window.AndroidCompass && navigator.geolocation) {
                navigator.geolocation.watchPosition(function(pos) {
                    const c = pos.coords;
                    const latStr = Math.abs(c.latitude).toFixed(5) + '°' + (c.latitude >= 0 ? 'N' : 'S');
                    const lonStr = Math.abs(c.longitude).toFixed(5) + '°' + (c.longitude >= 0 ? 'E' : 'W');
                    const altStr = c.altitude !== null ? ' · 海拔 ' + Math.round(c.altitude) + 'm' : '';
                    const coordsStr = latStr + ', ' + lonStr + altStr;
                    if (window.onNativeLocationUpdate) {
                        window.onNativeLocationUpdate(c.latitude, c.longitude, c.altitude || 0, c.altitude !== null, coordsStr);
                    }
                    if (c.speed !== null && !isNaN(c.speed) && window.onNativeSpeedUpdate) {
                        const speedKmH = (c.speed * 3.6).toFixed(1);
                        window.onNativeSpeedUpdate(speedKmH);
                    }
                }, function(err) {
                    console.log('GPS watchPosition info:', err);
                }, { enableHighAccuracy: true, maximumAge: 1000 });
            }

            // GPS 超时兜底：若 3 秒内未获得地理位置，提供合理默认定位 (北京)，避免真太阳时与坐标为空
            setTimeout(function() {
                if (typeof currentLongitude !== 'undefined' && currentLongitude === 0 && window.onNativeLocationUpdate) {
                    window.onNativeLocationUpdate(39.9042, 116.4074, 45, true, '39.90420°N, 116.40740°E · 海拔 45m');
                }
            }, 3000);
        });
    </script>
'''

    # Insert right after <body>
    content = content.replace("<body>", "<body>\n" + ios_shim_code)

    with open(dest_file, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Successfully generated iOS web core: {dest_file} ({len(content)} bytes)")

if __name__ == "__main__":
    prepare_ios_web()
