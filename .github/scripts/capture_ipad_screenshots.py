#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Automated iPad 12.9" Screenshot Capture Script for GitHub Actions
Captures all tabs across all 8 supported languages on iPad Pro 12.9" simulator,
saving both native resolution (2048x2732) and marketing format (1600x1200).
"""

import argparse
import json
import os
import subprocess
import sys
import time
from PIL import Image

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
    """Execute command and return stdout string."""
    if isinstance(cmd, list):
        print(f"Running: {' '.join(cmd)}")
    else:
        print(f"Running: {cmd}")
    res = subprocess.run(cmd, check=check, capture_output=capture, text=True, shell=isinstance(cmd, str))
    return res.stdout.strip() if capture else ""


def find_or_create_ipad_simulator():
    """Locate an available iPad Pro 12.9" simulator or create one."""
    print("=== Scanning available iPad Pro 12.9\" simulators ===")
    out = run_cmd(["xcrun", "simctl", "list", "-j", "devices"])
    data = json.loads(out)
    devices_by_runtime = data.get("devices", {})

    target_udid = None
    target_name = None

    # Scan for existing iPad Pro 12.9" or 13" devices
    for runtime, devices in devices_by_runtime.items():
        if "iOS" not in runtime:
            continue
        for dev in devices:
            if not dev.get("isAvailable", True):
                continue
            name = dev.get("name", "")
            # Match 12.9-inch or 13-inch iPad Pro
            if ("iPad Pro" in name and ("12.9" in name or "13" in name)) or ("iPad" in name and "12.9" in name):
                target_udid = dev.get("udid")
                target_name = name
                print(f"Found iPad simulator: {target_name} ({target_udid}) [{runtime}]")
                break
        if target_udid:
            break

    # If no 12.9" iPad found, look for device types to create one
    if not target_udid:
        print("No existing iPad 12.9\" found. Searching devicetypes...")
        types_out = run_cmd(["xcrun", "simctl", "list", "-j", "devicetypes"])
        types_data = json.loads(types_out)
        type_id = None
        for t in types_data.get("devicetypes", []):
            t_name = t.get("name", "")
            if "iPad Pro" in t_name and ("12.9" in t_name or "13" in t_name):
                type_id = t.get("identifier")
                break

        if not type_id:
            type_id = "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-12-9-inch-6th-generation"

        print(f"Creating new iPad 12.9\" simulator with type: {type_id}")
        target_udid = run_cmd(["xcrun", "simctl", "create", "iPad Pro (12.9-inch)", type_id])
        target_name = "iPad Pro (12.9-inch)"

    return target_udid, target_name


def convert_to_1600x1200(src_path, dst_path):
    """
    Fit image into 1600x1200 canvas while preserving aspect ratio and
    seamlessly extending background color.
    """
    with Image.open(src_path) as img:
        w, h = img.size
        target_w, target_h = (1600, 1200)

        # Sample background color from top-left corner
        bg_pixel = img.convert("RGB").getpixel((0, 0))

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


def main():
    parser = argparse.ArgumentParser(description="Capture iPad 12.9\" screenshots")
    parser.add_argument("--app-path", required=True, help="Path to built TiandiLuopan.app")
    parser.add_argument("--lang", default="all", help="Target language code or 'all'")
    parser.add_argument("--output-dir", default="dist-screenshots", help="Output directory")
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

    # Filter target languages
    if args.lang.strip().lower() in ["all", ""]:
        selected_langs = LANGUAGES
    else:
        req_codes = [c.strip() for c in args.lang.split(",")]
        selected_langs = [l for l in LANGUAGES if l["code"] in req_codes or any(c.lower() in l["code"].lower() for c in req_codes)]
        if not selected_langs:
            print(f"Warning: No matching languages for '{args.lang}', defaulting to all.")
            selected_langs = LANGUAGES

    print(f"Selected languages ({len(selected_langs)}): {[l['name'] for l in selected_langs]}")

    # 1. Locate / Boot Simulator
    udid, sim_name = find_or_create_ipad_simulator()
    print(f"Booting simulator: {sim_name} ({udid})...")
    subprocess.run(["xcrun", "simctl", "boot", udid], check=False)
    run_cmd(["xcrun", "simctl", "bootstatus", udid, "-b"])

    # Disable hardware keyboard for clean full-screen rendering
    run_cmd(["defaults", "write", "com.apple.iphonesimulator", "ConnectHardwareKeyboard", "0"], check=False)

    # 2. Install App
    print(f"Installing {app_path} onto simulator...")
    run_cmd(["xcrun", "simctl", "install", udid, app_path])

    captured_records = []

    # 3. Iterate Languages & Screens
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

                # Launch app with command line arguments
                launch_args = [
                    "xcrun", "simctl", "launch", udid, BUNDLE_ID,
                    "-AppleLanguages", f"({code})",
                    "-AppleLocale", locale,
                    "-appLanguage", code,
                    "-selectedTab", str(tab)
                ]
                run_cmd(launch_args)

                # Wait for view transition and canvas rendering to stabilize
                time.sleep(2.5)

                # Save native screenshot
                native_file = os.path.join(dir_native, code, f"{s_id}.png")
                os.makedirs(os.path.dirname(native_file), exist_ok=True)
                run_cmd(["xcrun", "simctl", "io", udid, "screenshot", native_file])

                # Convert to 1600x1200 format
                scaled_file = os.path.join(dir_1600, code, f"{s_id}_1600x1200.png")
                convert_to_1600x1200(native_file, scaled_file)

                # Terminate app for next clean start
                run_cmd(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)

                captured_records.append({
                    "lang_code": code,
                    "lang_name": name,
                    "tab": tab,
                    "title": title,
                    "native_path": native_file,
                    "scaled_path": scaled_file
                })

                print(f"    ✓ Captured: {os.path.basename(native_file)} & {os.path.basename(scaled_file)}")

    finally:
        print("\nShutting down simulator...")
        subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False)

    # 4. Generate GitHub Actions Step Summary
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a", encoding="utf-8") as f:
            f.write("## 📸 iPad 12.9-inch 自动截屏生成报告\n\n")
            f.write(f"- **目标模拟器**：`{sim_name}` (`{udid}`)\n")
            f.write(f"- **截屏语言总数**：{len(selected_langs)} 种语言\n")
            f.write(f"- **总截屏张数**：{len(captured_records)} 张（原图原生分辨率） + {len(captured_records)} 张（1600×1200 格式）\n")
            f.write("- **截图下载方式**：请前往当前 Actions 运行页面的 **Artifacts** 区域下载 `iPad-12.9-Screenshots` 压缩包。\n\n")
            f.write("### 截图详细清单\n\n")
            f.write("| 语言 | 界面编号与标题 | 原生高分辨率截图 | 1600×1200 标准格式 |\n")
            f.write("| :--- | :--- | :--- | :--- |\n")
            for r in captured_records:
                f.write(f"| {r['lang_name']} (`{r['lang_code']}`) | Tab {r['tab']}: {r['title']} | `{os.path.basename(r['native_path'])}` | `{os.path.basename(r['scaled_path'])}` |\n")
            f.write("\n")

    print(f"\n🎉 Successfully captured {len(captured_records)} screenshots across {len(selected_langs)} languages!")
    print(f"Artifacts output directory: {out_base}")


if __name__ == "__main__":
    main()

