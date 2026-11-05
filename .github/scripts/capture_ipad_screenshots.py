#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Automated iPad 12.9" Screenshot Capture Script for GitHub Actions
Captures all tabs across all 8 supported languages on an iPad Pro 12.9"/13" simulator,
saving both native resolution (2048x2732 for 12.9", 2064x2752 for 13") and marketing
format (1600x1200).
"""

import argparse
import atexit
import json
import os
import subprocess
import sys
import re
import time
from PIL import Image

# 脚本与 screenshot_guard.py 同目录；CI 从仓库根调用，显式加入以免 import 失败。
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import screenshot_guard  # noqa: E402

LANGUAGES = [
    {"code": "zh-Hans", "name": "简体中文", "locale": "zh_CN"},
    {"code": "zh-Hant", "name": "繁體中文", "locale": "zh_TW"},
    {"code": "en",      "name": "English",  "locale": "en_US"},
    {"code": "ja",      "name": "日本語",    "locale": "ja_JP"},
    {"code": "ko",      "name": "한국어",    "locale": "ko_KR"},
    {"code": "th",      "name": "ภาษาไทย",  "locale": "th_TH"},
    {"code": "vi",      "name": "Tiếng Việt", "locale": "vi_VN"},
    {"code": "id",      "name": "Bahasa Indonesia", "locale": "id_ID"}
]

SCREENS = [
    {"tab": 0, "id": "01_compass",   "title": "主罗盘与天心十道"},
    {"tab": 1, "id": "02_ar_vision", "title": "AR实景天心透视"},
    {"tab": 2, "id": "03_floorplan", "title": "户型空间立极"},
    {"tab": 3, "id": "04_analysis",  "title": "玄空理气与三式绝学"},
    {"tab": 4, "id": "05_settings",  "title": "系统设置与会员中心"}
]

BUNDLE_ID = "com.yanxiang.compass"


def run_cmd(cmd, check=True, capture=True):
    """Execute command and return stdout string. On failure, show captured output first."""
    if isinstance(cmd, list):
        print(f"Running: {' '.join(cmd)}")
    else:
        print(f"Running: {cmd}")
    try:
        res = subprocess.run(cmd, check=check, capture_output=capture, text=True, shell=isinstance(cmd, str))
    except subprocess.CalledProcessError as e:
        # capture_output=True 会吞掉 stderr，不打印的话 CI 日志里只剩一个没有信息的 traceback
        print(f"!! Command failed (exit {e.returncode})")
        if e.stdout:
            print(f"   stdout: {e.stdout.strip()}")
        if e.stderr:
            print(f"   stderr: {e.stderr.strip()}")
        raise
    return res.stdout.strip() if capture else ""


def _version_key(version):
    return tuple(int(x) for x in re.findall(r"\d+", version))


def _is_big_ipad_pro(name):
    return "iPad Pro" in name and ("12.9" in name or "13" in name)


def find_or_create_ipad_simulator():
    """
    Locate (or create) an iPad Pro 12.9"/13" simulator.

    The runtime is chosen explicitly: the newest available iOS runtime that actually
    supports such a device type. This matters on the Xcode 27 runner image, where the
    iOS 27.1 runtime only contains iPhone Duo and iPad devices live in the 27.0 runtime;
    `simctl create` without a runtime, or picking the first iPad found in dict order,
    can land on the wrong one.
    """
    print("=== Scanning iPad Pro 12.9\"/13\" simulators ===")
    runtimes = json.loads(run_cmd(["xcrun", "simctl", "list", "-j", "runtimes"])).get("runtimes", [])
    types = json.loads(run_cmd(["xcrun", "simctl", "list", "-j", "devicetypes"])).get("devicetypes", [])
    devices_by_runtime = json.loads(run_cmd(["xcrun", "simctl", "list", "-j", "devices"])).get("devices", {})

    ipad_types = [t for t in types if _is_big_ipad_pro(t.get("name", ""))]
    ios_runtimes = [r for r in runtimes
                    if ".iOS-" in r.get("identifier", "") and r.get("isAvailable", True)]

    for rt in sorted(ios_runtimes, key=lambda r: _version_key(r.get("version", "0")), reverse=True):
        supported = {d.get("identifier") for d in rt.get("supportedDeviceTypes", [])}
        cands = [t for t in ipad_types if t["identifier"] in supported]
        if not cands:
            continue
        cand_ids = {t["identifier"] for t in cands}

        # Reuse an existing available device of such a type on this runtime
        for dev in devices_by_runtime.get(rt["identifier"], []):
            if dev.get("isAvailable", True) and dev.get("deviceTypeIdentifier") in cand_ids:
                print(f"Found iPad simulator: {dev['name']} ({dev['udid']}) [{rt['identifier']}]")
                return dev["udid"], dev["name"]

        # Otherwise create one (list order is chronological -> last = newest model)
        t = cands[-1]
        print(f"Creating {t['name']} on {rt['identifier']}")
        udid = run_cmd(["xcrun", "simctl", "create", t["name"], t["identifier"], rt["identifier"]])
        return udid, t["name"]

    print("ERROR: no available iOS runtime supports an iPad Pro 12.9\"/13\" device type.")
    print("iOS runtimes seen: " + (", ".join(f"{r.get('identifier')} ({r.get('version')})" for r in ios_runtimes) or "none"))
    print("iPad Pro device types seen: " + (", ".join(t["name"] for t in ipad_types) or "none"))
    sys.exit(2)


def convert_to_1600x1200(src_path, dst_path):
    """
    Fit image into 1600x1200 canvas while preserving aspect ratio and
    seamlessly extending background color.
    """
    with Image.open(src_path) as img:
        w, h = img.size
        target_w, target_h = (1600, 1200)

        # 四角众数：白屏/启动屏时左上角常是纯白，单点采样会把整张 marketing 图染白
        bg_pixel = sample_background_color(img)

        # Scale proportionally to fit target height (1200)
        scale = target_h / h
        new_w = int(w * scale)
        new_h = target_h

        img_scaled = img.convert("RGBA").resize((new_w, new_h), Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", (target_w, target_h), bg_pixel)
        x_offset = (target_w - new_w) // 2
        y_offset = (target_h - new_h) // 2

        mask = img_scaled.split()[3] if "A" in img_scaled.mode else None
        canvas.paste(img_scaled, (x_offset, y_offset), mask=mask)

        os.makedirs(os.path.dirname(dst_path), exist_ok=True)
        canvas.save(dst_path, "PNG")


def sample_background_color(img):
    """取四角像素的众数做背景色，避免左上角恰是状态栏白字时把整张画布染白。"""
    w, h = img.size
    rgb = img.convert("RGB")
    probes = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    counts = {}
    for point in probes:
        color = rgb.getpixel(point)
        counts[color] = counts.get(color, 0) + 1
    return max(counts, key=counts.get)


def terminate_app(udid):
    run_cmd(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)


def launch_app(udid, launch_args):
    """terminate 与 launch 之间必须留出进程真正退出的时间。

    `simctl terminate` 是异步的；紧接着 launch 时旧进程可能尚未退出，simctl 会附着到
    旧进程并把本次的 -selectedTab / 语言参数全部忽略 —— 表现为截图停在上一页、
    启动屏或空白 window。启动成功时 simctl 会打印 `<bundle>: <pid>`，据此确认。
    """
    terminate_app(udid)
    out = ""
    for attempt in range(1, 4):
        time.sleep(0.8 if attempt == 1 else 0.5)
        try:
            out = run_cmd(launch_args)
        except subprocess.CalledProcessError:
            if attempt == 3:
                raise
            print("    ... launch 第 %d 次失败，重试" % attempt)
            continue
        if re.search(r"\b\d{3,}\b", out or ""):
            return out
        print("    ... launch 未返回 PID（可能附着到旧进程），重试")
    return out


def capture_rendered_frame(udid, dest, launch_args, settle, ready_timeout, poll_interval):
    """轮询截图直到画面真的渲染出来；持续白屏则重新拉起 App 再给一轮机会。

    返回 (metrics, attempts, blank)。blank=True 表示最终仍是白屏，调用方必须记为失败，
    绝不能把白屏当成「✓ Captured」上传并让 CI 变绿。
    """
    last_metrics = {}
    total_attempts = 0
    for round_no in (1, 2):
        if round_no == 2:
            print("    ... 持续白屏，重新拉起 App 后再给一轮机会")
            launch_app(udid, launch_args)
            time.sleep(settle)
        deadline = time.time() + ready_timeout
        while True:
            total_attempts += 1
            run_cmd(["xcrun", "simctl", "io", udid, "screenshot", dest])
            blank, metrics = screenshot_guard.analyze(dest)
            last_metrics = metrics
            if not blank:
                return metrics, total_attempts, False
            print("    ... 第 %d 次截图仍是白屏 %s，继续等渲染" % (total_attempts, metrics))
            if time.time() >= deadline:
                break
            time.sleep(poll_interval)
    return last_metrics, total_attempts, True


def simulator_is_landscape(udid):
    """Probe the device's real orientation via a throwaway screenshot."""
    probe = os.path.join(os.environ.get("RUNNER_TEMP", "/tmp"),
                         "orientation_probe_%s.png" % udid)
    try:
        run_cmd(["xcrun", "simctl", "io", udid, "screenshot", probe])
        with Image.open(probe) as im:
            width, height = im.size
        print("Orientation probe: %dx%d" % (width, height))
        return width > height
    except Exception as exc:  # noqa: BLE001 - probe must never abort the capture
        print("WARNING: orientation probe failed: %s" % exc)
        return False
    finally:
        try:
            os.remove(probe)
        except OSError:
            pass


def ensure_portrait(udid):
    """竖屏调用前把设备方向复位。

    模拟器复用同一个 UDID，shutdown 未必清除方向偏好；若上一次横屏真旋转残留，
    本次「竖屏 8 语言」会全程产出横屏像素。先探测，横屏则尝试 Cmd+Down 旋回。
    """
    if not simulator_is_landscape(udid):
        return
    print("WARNING: device still landscape at start of a portrait run; rotating back.")
    try:
        subprocess.run(
            ["osascript",
             "-e", 'tell application "Simulator" to activate',
             "-e", "delay 0.5",
             "-e", 'tell application "System Events" to key code 125 using {command down}'],
            check=False, capture_output=True, text=True, timeout=30)
        time.sleep(2.5)
    except Exception as exc:  # noqa: BLE001 - best effort only
        print("WARNING: AppleScript portrait rotation unavailable: %s" % exc)
    if simulator_is_landscape(udid):
        print("::error::设备方向残留横屏且无法复位；竖屏截图不可信，终止本次采集。"
              "请在 runner 上重置该模拟器方向或删除后重建。")
        sys.exit(2)


def restore_portrait(udid):
    """横屏采集结束后 best-effort 旋回竖屏，避免方向偏好污染下一次竖屏运行。

    与 ensure_portrait 不同：这里失败只告警，绝不让已经成功采集的截图流程变红。
    """
    if not simulator_is_landscape(udid):
        return
    try:
        subprocess.run(
            ["osascript",
             "-e", 'tell application "Simulator" to activate',
             "-e", "delay 0.5",
             "-e", 'tell application "System Events" to key code 125 using {command down}'],
            check=False, capture_output=True, text=True, timeout=30)
        time.sleep(2.0)
    except Exception as exc:  # noqa: BLE001 - best effort only
        print("WARNING: portrait restoration unavailable: %s" % exc)
    if simulator_is_landscape(udid):
        print("::warning::模拟器方向未能复位为竖屏；下次竖屏采集会由 ensure_portrait 再尝试。"
              "若持续失败，请在 runner 上重置该模拟器方向或删除后重建。")
    else:
        print("Orientation restored to portrait.")


def try_rotate_to_landscape(udid):
    """Best-effort real rotation; returns True when the device is landscape.

    `simctl` has no orientation command. On classic Xcode images Simulator.app's
    Hardware > Rotate Left (Cmd+Left) works through AppleScript. Xcode 27 replaced
    it with Device Hub, where System Events control often lacks Accessibility
    permission. In that case the caller falls back to `-forceLandscapeLayout`,
    which still exercises the real two-pane SwiftUI layout code path.
    """
    if simulator_is_landscape(udid):
        print("Simulator is already landscape.")
        return True
    try:
        subprocess.run(
            ["osascript",
             "-e", 'tell application "Simulator" to activate',
             "-e", "delay 0.5",
             "-e", 'tell application "System Events" to key code 123 using {command down}'],
            check=False, capture_output=True, text=True, timeout=30)
        time.sleep(2.5)
    except Exception as exc:  # noqa: BLE001 - best effort only
        print("WARNING: AppleScript rotation unavailable: %s" % exc)
    if simulator_is_landscape(udid):
        print("Real rotation succeeded: screenshots will be landscape pixels.")
        return True
    print("WARNING: real rotation failed -> falling back to -forceLandscapeLayout.")
    return False


def main():
    parser = argparse.ArgumentParser(description="Capture iPad 12.9\" screenshots")
    parser.add_argument("--app-path", required=True, help="Path to built TiandiLuopan.app")
    parser.add_argument("--lang", default="all", help="Target language code(s), comma separated, or 'all'")
    parser.add_argument("--output-dir", default="dist-screenshots", help="Output directory")
    parser.add_argument("--settle", type=float, default=2.5,
                        help="Seconds to wait after launch before the first frame probe (default 2.5)")
    parser.add_argument("--ready-timeout", type=float, default=18.0,
                        help="Max seconds to keep polling a blank screen per launch round (default 18)")
    parser.add_argument("--ready-interval", type=float, default=1.5,
                        help="Seconds between blank-frame probes (default 1.5)")
    parser.add_argument("--rotate-landscape", action="store_true",
                        help="Capture the iPad LANDSCAPE two-pane layout. Tries a real device "
                             "rotation first; if that is unavailable, falls back to the "
                             "-forceLandscapeLayout launch argument (landscape layout, portrait pixels).")
    args = parser.parse_args()

    app_path = os.path.abspath(args.app_path)
    if not os.path.exists(app_path):
        print(f"Error: App bundle not found at {app_path}")
        sys.exit(1)

    out_base = os.path.abspath(args.output_dir)
    dir_native = os.path.join(out_base, "native_ipad_12.9")
    dir_1600 = os.path.join(out_base, "marketing_1600x1200")

    os.makedirs(dir_native, exist_ok=True)
    os.makedirs(dir_1600, exist_ok=True)

    # Filter target languages (exact, case-insensitive match; a typo is an error, not "all")
    if args.lang.strip().lower() in ["all", ""]:
        selected_langs = LANGUAGES
    else:
        req_codes = {c.strip().lower() for c in args.lang.split(",") if c.strip()}
        selected_langs = [l for l in LANGUAGES if l["code"].lower() in req_codes]
        if not selected_langs:
            print(f"Error: no matching languages for '{args.lang}'. "
                  f"Valid codes: {', '.join(l['code'] for l in LANGUAGES)}")
            sys.exit(2)

    print(f"Selected languages ({len(selected_langs)}): {[l['name'] for l in selected_langs]}")

    # 1. Locate / Boot Simulator
    udid, sim_name = find_or_create_ipad_simulator()
    # boot / bootstatus / install / privacy 任一抛异常时也要 shutdown：
    # 原实现把这些放在 try 之外，finally 覆盖不到，设备会残留 Booted 并污染下一次运行。
    atexit.register(lambda: subprocess.run(
        ["xcrun", "simctl", "shutdown", udid], check=False))
    print(f"Booting simulator: {sim_name} ({udid})...")
    subprocess.run(["xcrun", "simctl", "boot", udid], check=False)
    run_cmd(["xcrun", "simctl", "bootstatus", udid, "-b"])

    # 方向状态：每次 boot 后都显式管理。竖屏调用必须确保设备真是竖屏，
    # 横屏调用才尝试真旋转，避免复用设备时上一次的方向污染本次全部截图。
    real_rotation = False
    if args.rotate_landscape:
        real_rotation = try_rotate_to_landscape(udid)
    else:
        ensure_portrait(udid)

    # Disable hardware keyboard for clean full-screen rendering
    # (Xcode 27's Device Hub replaced Simulator.app; if this domain no longer applies it is a harmless no-op)
    run_cmd(["defaults", "write", "com.apple.iphonesimulator", "ConnectHardwareKeyboard", "0"], check=False)

    # 2. Install App
    # Note: the app is built with the iOS 27.1 SDK but runs on whatever runtime hosts the iPad
    # (27.0 on the Xcode 27 image). Its deployment target must therefore be <= that runtime.
    print(f"Installing {app_path} onto simulator...")
    run_cmd(["xcrun", "simctl", "install", udid, app_path])

    # 3. Pre-grant all system privacy permissions (Location, Camera, Photos, Motion, etc.)
    # This prevents any permission authorization alert dialogs from appearing during capture.
    print(f"Pre-granting all privacy permissions for {BUNDLE_ID}...")
    services = [
        "all",
        "location",
        "location-always",
        "camera",
        "photos",
        "photos-add",
        "motion",
        "microphone",
        "user-tracking"
    ]
    for s in services:
        run_cmd(["xcrun", "simctl", "privacy", udid, "grant", s, BUNDLE_ID], check=False)

    # 4. Set fixed GPS coordinates (Beijing) so compass/solar terms compute immediately
    run_cmd(["xcrun", "simctl", "location", udid, "set", "39.9042,116.4074"], check=False)

    # 5. Clean status bar (9:41 AM, 100% battery, full signal) for professional App Store screenshots
    run_cmd([
        "xcrun", "simctl", "status_bar", udid, "override",
        "--time", "9:41",
        "--batteryState", "charged",
        "--batteryLevel", "100",
        "--cellularBars", "4",
        "--wifiBars", "3"
    ], check=False)

    captured_records = []
    failures = []

    # 6. Iterate Languages & Screens
    # A failure on one screenshot is recorded and the run continues, so the artifact still holds
    # everything that did succeed; the script exits non-zero at the end if anything failed.
    try:
        for lang_info in selected_langs:
            code = lang_info["code"]
            name = lang_info["name"]
            locale = lang_info["locale"]

            print(f"\n=======================================================")
            print(f"  Capturing Language: {name} ({code}) [locale: {locale}]")
            print(f"=======================================================")

            for screen in SCREENS:
                tab = screen["tab"]
                s_id = screen["id"]
                title = screen["title"]

                print(f"--> [{code}] Tab {tab}: {title} ({s_id})...")

                native_file = os.path.join(dir_native, code, f"{s_id}.png")
                scaled_file = os.path.join(dir_1600, code, f"{s_id}_1600x1200.png")
                try:
                    # 启动参数：语言、Tab、横屏兜底布局
                    launch_args = [
                        "xcrun", "simctl", "launch", udid, BUNDLE_ID,
                        "-AppleLanguages", f"({code})",
                        "-AppleLocale", locale,
                        "-appLanguage", code,
                        "-selectedTab", str(tab)
                    ]
                    if args.rotate_landscape and not real_rotation:
                        launch_args.append("-forceLandscapeLayout")
                    launch_app(udid, launch_args)

                    # 冷启动首帧之前的固定等待；之后由内容轮询接管，不再靠猜时间
                    time.sleep(args.settle)

                    os.makedirs(os.path.dirname(native_file), exist_ok=True)
                    metrics, attempts, blank = capture_rendered_frame(
                        udid, native_file, launch_args, args.settle,
                        args.ready_timeout, args.ready_interval)
                    if blank:
                        # 删掉残留的白屏文件，避免即使 CI 变红、artifact 里仍混着白图
                        try:
                            os.remove(native_file)
                        except OSError:
                            pass
                        raise RuntimeError(
                            f"白屏/未渲染帧：{attempts} 次截图后仍为空白 {metrics} "
                            f"(settle={args.settle}s, ready_timeout={args.ready_timeout}s)")

                    with Image.open(native_file) as im:
                        native_size = f"{im.size[0]}x{im.size[1]}"
                        w, h = im.size
                        # 结果级断言：真旋转必须是横屏像素；竖屏调用不能被上次横屏污染
                        if args.rotate_landscape and real_rotation and w <= h:
                            raise RuntimeError(
                                f"真旋转方向在截图中途丢失：{native_size} 不是横屏像素")
                        if not args.rotate_landscape and w > h:
                            raise RuntimeError(
                                f"竖屏调用被上次横屏状态污染：{native_size} 是横屏像素")

                    # 逐图复检：内容体检必须通过，避免把误判帧写进产物
                    blank2, _metrics2 = screenshot_guard.analyze(native_file)
                    if blank2:
                        raise RuntimeError("native 截图复检仍为白屏")

                    # Convert to 1600x1200 format
                    convert_to_1600x1200(native_file, scaled_file)
                except Exception as e:  # noqa: BLE001 - keep capturing the remaining screens
                    detail = str(e)
                    if isinstance(e, subprocess.CalledProcessError) and e.stderr and e.stderr.strip():
                        detail = f"simctl {e.cmd[2]}: {e.stderr.strip().splitlines()[-1]}"
                    print(f"    ✗ FAILED [{code}] {s_id}: {detail}")
                    failures.append({"lang_code": code, "lang_name": name, "tab": tab,
                                     "title": title, "error": detail})
                    continue
                finally:
                    # Terminate app for next clean start
                    run_cmd(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)

                captured_records.append({
                    "lang_code": code,
                    "lang_name": name,
                    "tab": tab,
                    "title": title,
                    "native_path": native_file,
                    "scaled_path": scaled_file,
                    "native_size": native_size
                })

                print(f"    ✓ Captured: {os.path.basename(native_file)} ({native_size}) & {os.path.basename(scaled_file)}")

    finally:
        # 真旋转成功的横屏调用必须在 shutdown 前把方向复位：模拟器复用同一个 UDID，
        # 方向偏好可能跨 shutdown 残留，否则下一次竖屏采集会被 ensure_portrait()
        # 判为「残留横屏」并在 AppleScript 不可用时直接终止，连竖屏 40 张都拿不到。
        if args.rotate_landscape and real_rotation:
            print("Restoring simulator orientation to portrait before shutdown...")
            restore_portrait(udid)
        print("\nShutting down simulator...")
        subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False)

    # 7. 把真实结果写进 GITHUB_OUTPUT，供 workflow 的 Summary / 上传前校验读取。
    #    不再由 workflow 用 always() 静态宣称「左右双栏 / 不假绿」。
    mode_key = ("real-rotation" if real_rotation
                else "forced-landscape" if args.rotate_landscape else "portrait")
    blank_failures = sum(1 for r in failures
                         if "白屏" in r["error"] or "blank" in r["error"])
    output_file = os.environ.get("GITHUB_OUTPUT")
    if output_file:
        with open(output_file, "a", encoding="utf-8") as f:
            f.write(f"captured={len(captured_records)}\n")
            f.write(f"failed={len(failures)}\n")
            f.write(f"blank_failed={blank_failures}\n")
            f.write(f"render_mode={mode_key}\n")
            f.write(f"expected={len(selected_langs) * len(SCREENS)}\n")

    # 8. Generate GitHub Actions Step Summary（如实报告，不静态宣称验证通过）
    expected = len(selected_langs) * len(SCREENS)
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        heading = ("iPad 横屏分栏截屏报告" if args.rotate_landscape
                   else "iPad 竖屏单列截屏报告")
        with open(summary_file, "a", encoding="utf-8") as f:
            f.write(f"## 📸 {heading}\n\n")
            f.write(f"- **目标模拟器**：`{sim_name}` (`{udid}`)\n")
            f.write(f"- **截屏语言总数**：{len(selected_langs)} 种语言\n")
            f.write(f"- **成功 / 应有**：{len(captured_records)} / {expected} 张\n")
            if args.rotate_landscape:
                mode = ("设备真实旋转（横屏像素）" if real_rotation
                        else "App 强制横屏布局（`-forceLandscapeLayout`，设备仍为竖屏像素）")
                f.write(f"- **横屏渲染模式**：{mode}\n")
                f.write("- **说明**：脚本只保证按横屏布局路径渲染，"
                        "**未做双栏特征像素校验**，是否真的左右分栏仍需人工看图确认。\n")
            f.write(f"- **白屏剔除**：{blank_failures} 张（白屏一律记为失败，不写入产物）\n")
            f.write(f"- **总产出**：{len(captured_records)} 张原生 + {len(captured_records)} 张 1600×1200\n")
            f.write("- **下载**：Actions 运行页 **Artifacts** 区域下载本次 workflow 上传的截图压缩包。\n\n")
            if failures:
                f.write("### ❌ 失败清单\n\n")
                f.write("| 语言 | 界面 | 错误 |\n| :--- | :--- | :--- |\n")
                for r in failures:
                    err = r["error"].replace("|", "\\|").replace("\n", " ")[:200]
                    f.write(f"| {r['lang_name']} (`{r['lang_code']}`) | Tab {r['tab']}: {r['title']} | {err} |\n")
                f.write("\n")
            f.write("### 截图详细清单\n\n")
            f.write("| 语言 | 界面编号与标题 | 原生高分辨率截图 | 原生尺寸 | 1600×1200 标准格式 |\n")
            f.write("| :--- | :--- | :--- | :--- | :--- |\n")
            for r in captured_records:
                f.write(f"| {r['lang_name']} (`{r['lang_code']}`) | Tab {r['tab']}: {r['title']} | `{os.path.basename(r['native_path'])}` | {r['native_size']} | `{os.path.basename(r['scaled_path'])}` |\n")
            f.write("\n")

    print(f"\n🎉 Captured {len(captured_records)} screenshots across {len(selected_langs)} languages.")
    print(f"Artifacts output directory: {out_base}")
    if failures:
        print(f"\n❌ {len(failures)} screenshot(s) failed:")
        for r in failures:
            print(f"   - [{r['lang_code']}] Tab {r['tab']} {r['title']}: {r['error'][:200]}")
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except BaseException as exc:  # boot/install/privacy 等 try 之外的异常也要留下证据
        print(f"::error::iPad screenshot setup/capture aborted: {exc}")
        summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary:
            with open(summary, "a", encoding="utf-8") as fh:
                fh.write("## ❌ iPad 截屏流程中断\n\n")
                fh.write(f"- 阶段：模拟器 boot / install / 权限预置 / 截图循环\n")
                fh.write(f"- 错误：`{str(exc).replace('|', '\\|')[:400]}`\n")
                fh.write("- 本次**没有**产出可信截图；请勿把 Artifacts 中的旧图当作本次结果。\n\n")
        sys.exit(1)
