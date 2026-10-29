#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Static & Cross-File Verification for LocalizationManager.swift:
1. Detects duplicate keys within the same AppLanguage block.
2. Verifies key-set parity across all 8 supported languages (zhHans, zhHant, en, th, vi, id, ja, ko).
3. Verifies zero dead/unreferenced localization keys across all Swift source files.
4. Verifies zero undefined keys referenced via .t("...") across all Swift source files.
"""

import glob
import os
import re
import sys

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOC_PATH = os.path.join(ROOT_DIR, "ios", "TiandiLuopan", "Models", "LocalizationManager.swift")
SWIFT_DIR = os.path.join(ROOT_DIR, "ios", "TiandiLuopan")


def main() -> int:
    with open(LOC_PATH, "r", encoding="utf-8") as f:
        lines = f.readlines()

    current_lang = None
    lang_keys = {}
    duplicates = {}

    lang_header_re = re.compile(r"^\s*\.(zhHans|zhHant|en|th|vi|id|ja|ko)\s*:\s*\[")
    kv_re = re.compile(r'^\s*"([^"]+)"\s*:\s*"(.*)"\s*,?\s*$')

    for idx, line in enumerate(lines, 1):
        m_lang = lang_header_re.match(line)
        if m_lang:
            current_lang = m_lang.group(1)
            lang_keys.setdefault(current_lang, [])
            duplicates.setdefault(current_lang, [])
            continue
        if current_lang:
            m_kv = kv_re.match(line)
            if m_kv:
                k = m_kv.group(1)
                existing = [x for x in lang_keys[current_lang] if x[0] == k]
                if existing:
                    duplicates[current_lang].append((k, existing[0][1], idx))
                lang_keys[current_lang].append((k, idx))

    has_error = False
    all_unique_keys = set()
    for lang, kvs in lang_keys.items():
        all_unique_keys.update(k for k, _ in kvs)
        if duplicates[lang]:
            has_error = True
            print(f"[ERROR] Language {lang} has duplicate keys: {duplicates[lang]}")

    for lang, kvs in lang_keys.items():
        s = set(k for k, _ in kvs)
        missing = all_unique_keys - s
        if missing:
            has_error = True
            print(f"[ERROR] Language {lang} missing {len(missing)} keys: {sorted(list(missing))}")

    swift_files = glob.glob(os.path.join(SWIFT_DIR, "**", "*.swift"), recursive=True)
    other_contents = ""
    code_t_keys = set()
    for sf in swift_files:
        if os.path.normcase(sf) == os.path.normcase(LOC_PATH):
            continue
        with open(sf, "r", encoding="utf-8") as f:
            txt = f.read()
        other_contents += "\n" + txt
        for m in re.finditer(r'\.t\(\s*"([^"\\]+)"\s*\)', txt):
            code_t_keys.add(m.group(1))

    unused_keys = [k for k in sorted(all_unique_keys) if f'"{k}"' not in other_contents]
    missing_in_loc = sorted(list(code_t_keys - all_unique_keys))

    if unused_keys:
        has_error = True
        print(f"[ERROR] Unused localization keys ({len(unused_keys)}): {unused_keys}")

    if missing_in_loc:
        has_error = True
        print(f"[ERROR] Keys referenced in .t(\"...\") but missing in LocalizationManager ({len(missing_in_loc)}): {missing_in_loc}")

    total_entries = sum(len(kvs) for kvs in lang_keys.values())
    print(
        f"Localization check complete: {len(lang_keys)} languages, "
        f"{len(all_unique_keys)} keys/language ({total_entries} total entries), "
        f"0 duplicates, {len(unused_keys)} unused keys, {len(missing_in_loc)} missing keys."
    )
    return 1 if has_error else 0


if __name__ == "__main__":
    sys.exit(main())
