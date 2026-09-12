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
    <meta name="apple-mobile-web-app-title" content="演象罗盘">
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
            top: max(12px, env(safe-area-inset-top));
            left: 50%;
            transform: translateX(-50%);
            z-index: 99999;
            background: linear-gradient(135deg, #d4af37, #b8860b);
            color: #121216;
            padding: 8px 18px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: bold;
            box-shadow: 0 4px 15px rgba(0,0,0,0.5);
            cursor: pointer;
            animation: pulseBanner 1.8s infinite;
        }
        @keyframes pulseBanner {
            0% { transform: translateX(-50%) scale(1); }
            50% { transform: translateX(-50%) scale(1.05); }
            100% { transform: translateX(-50%) scale(1); }
        }
    </style>
    <div id="ios-sensor-banner" onclick="requestIOSSensorPermission()">🧭 点击激活 iPhone 罗盘与陀螺仪</div>
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
                    getCoordsDesc: function() { return window.__iosCoordsDesc || ""; }
                };
            }
        })();

        // iOS Safari / PWA 传感器授权处理
        function requestIOSSensorPermission() {
            if (typeof DeviceOrientationEvent !== 'undefined' && typeof DeviceOrientationEvent.requestPermission === 'function') {
                DeviceOrientationEvent.requestPermission()
                    .then(function(state) {
                        if (state === 'granted') {
                            const banner = document.getElementById('ios-sensor-banner');
                            if (banner) banner.style.display = 'none';
                            window.addEventListener('deviceorientation', handleOrientation);
                        } else {
                            alert('未能获得方向传感器权限，罗盘将无法随向旋转。');
                        }
                    })
                    .catch(function(err) {
                        console.error('Sensor permission error:', err);
                    });
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

        // 检测是否在 iOS Safari / PWA 中且需要用户点击授权
        window.addEventListener('DOMContentLoaded', function() {
            const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
            if (isIOS && !window.AndroidCompass && typeof DeviceOrientationEvent !== 'undefined' && typeof DeviceOrientationEvent.requestPermission === 'function') {
                const banner = document.getElementById('ios-sensor-banner');
                if (banner) banner.style.display = 'block';
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
