#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""截图内容体检：识别白屏 / 未渲染的空白帧，避免无效截图被当成成功产物。

为什么需要：
  `xcrun simctl launch` 是异步的，返回时 App 往往还在冷启动；`simctl io screenshot`
  会老老实实把当前帧存下来 —— 此时可能是 LaunchScreen（白底）、空白 window 或
  尚未提交第一帧的纯色缓冲。旧脚本只判断命令退出码，于是白屏被计入「✓ Captured」，
  再被 convert_to_1600x1200 用左上角白色像素铺满整张 marketing 图，CI 全绿。

用法：
  python3 screenshot_guard.py FILE [FILE ...]   # 任一为白屏则退出码 1
  python3 screenshot_guard.py --dir DIR --expect N
  python3 screenshot_guard.py --print-metrics FILE

本模块同时被 capture_ipad_screenshots.py 直接 import。
"""

import argparse
import os
import sys

from PIL import Image

# 近白像素占比超过该值 → 判定为 LaunchScreen / 白屏。
WHITE_RATIO_LIMIT = 0.90
# 亮度标准差低于该值 → 画面几乎是单色（未渲染的纯黑/纯白缓冲）。
# 取 2.0 而非更大：罗盘/AR 页本身是深色主题，阈值太高会把合法暗色界面误判成白屏。
LUM_STD_LIMIT = 2.0
# 量化后的不同颜色数低于该值 → 单色缓冲。
COLOR_BUCKETS_LIMIT = 3
# 缩略图边长，降采样后再统计，避免 2048x2732 逐像素开销。
THUMB_SIDE = 96


def analyze(path):
    """返回 (is_blank: bool, metrics: dict)。"""
    with Image.open(path) as src:
        original_size = src.size
        thumb = src.convert("RGB").resize(
            (THUMB_SIDE, THUMB_SIDE), Image.Resampling.BILINEAR
        )
        pixels = list(thumb.getdata())

    count = float(len(pixels))
    near_white = sum(1 for r, g, b in pixels if r >= 245 and g >= 245 and b >= 245)
    luminances = [0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in pixels]
    mean = sum(luminances) / count
    variance = sum((v - mean) ** 2 for v in luminances) / count
    std = variance ** 0.5
    buckets = {(r // 16, g // 16, b // 16) for r, g, b in pixels}

    metrics = {
        "white_ratio": round(near_white / count, 4),
        "lum_std": round(std, 2),
        "color_buckets": len(buckets),
        "size": "%dx%d" % original_size,
    }
    blank = (
        near_white / count >= WHITE_RATIO_LIMIT
        or std < LUM_STD_LIMIT
        or len(buckets) <= COLOR_BUCKETS_LIMIT
    )
    return blank, metrics


def _format(path, blank, metrics):
    return "%s %s white=%.3f std=%.2f colors=%d %s" % (
        "BLANK" if blank else "OK   ",
        path,
        metrics["white_ratio"],
        metrics["lum_std"],
        metrics["color_buckets"],
        metrics["size"],
    )


def main():
    parser = argparse.ArgumentParser(description="Detect blank/white simulator screenshots")
    parser.add_argument("files", nargs="*", help="PNG files to inspect")
    parser.add_argument("--dir", help="Recursively inspect every *.png under this directory")
    parser.add_argument("--expect", type=int, default=0,
                        help="Require exactly N PNG files (0 = no count check)")
    parser.add_argument("--print-metrics", action="store_true",
                        help="Always print metrics; default prints only when blank")
    parser.add_argument("--quiet", action="store_true",
                        help="Do not emit ::error:: annotations (used inside retry loops, "
                             "where an intermediate blank frame is expected)")
    args = parser.parse_args()

    files = list(args.files)
    if args.dir:
        for root, _dirs, names in os.walk(args.dir):
            for name in sorted(names):
                if name.lower().endswith(".png"):
                    files.append(os.path.join(root, name))
    files = sorted(set(files))

    def annotate(text):
        if not args.quiet:
            print(text)

    if not files:
        annotate("::error::screenshot_guard: no PNG files to inspect")
        return 1
    if args.expect and len(files) != args.expect:
        annotate("::error::screenshot_guard: expected %d PNGs, found %d"
                 % (args.expect, len(files)))
        return 1

    blank_files = []
    for path in files:
        try:
            blank, metrics = analyze(path)
        except Exception as exc:  # noqa: BLE001 - one bad file must not hide the rest
            annotate("::error::screenshot_guard: cannot read %s: %s" % (path, exc))
            blank_files.append(path)
            continue
        if blank:
            blank_files.append(path)
            annotate("::error::blank screenshot: " + _format(path, blank, metrics))
            if args.quiet:
                print(_format(path, blank, metrics))
        elif args.print_metrics:
            print(_format(path, blank, metrics))

    if blank_files:
        print("screenshot_guard: %d/%d blank" % (len(blank_files), len(files)))
        return 1
    print("screenshot_guard: %d/%d screenshots contain rendered content"
          % (len(files), len(files)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
