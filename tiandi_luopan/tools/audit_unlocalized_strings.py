import os
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

ios_root = Path(__file__).resolve().parents[1] / "ios" / "TiandiLuopan"
chinese_re = re.compile(r"[\u4e00-\u9fff]")
string_re = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')

file_data = {}

for root, dirs, files in os.walk(str(ios_root)):
    for f in sorted(files):
        if f.endswith(".swift") and f != "LocalizationManager.swift":
            fpath = os.path.join(root, f)
            with open(fpath, "r", encoding="utf-8") as fp:
                lines = fp.readlines()
            
            unlocalized = []
            for i, line in enumerate(lines, 1):
                stripped = line.strip()
                if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
                    continue
                matches = string_re.findall(line)
                for m in matches:
                    if chinese_re.search(m):
                        if f'lang.t("{m}")' not in line:
                            unlocalized.append((i, m, stripped))
            
            rel = os.path.relpath(fpath, ios_root)
            if unlocalized:
                file_data[rel] = unlocalized

print("=== SUMMARY RANKING ===")
for k, v in sorted(file_data.items(), key=lambda x: -len(x[1])):
    print(f"{len(v):3d} strings: {k}")

print("\n=== DETAIL BY FILE ===")
for k in sorted(file_data.keys()):
    items = file_data[k]
    print(f"\n--- {k} ({len(items)}) ---")
    for lno, text, lcode in items:
        # truncate long text
        display_text = text if len(text) <= 50 else text[:47] + "..."
        print(f"  L{lno:3d}: {display_text}")
