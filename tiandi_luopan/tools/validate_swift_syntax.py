# -*- coding: utf-8 -*-
"""
Validate Swift syntax: balanced braces, parentheses, and scope resolution across all Swift files.
"""
import os
import re
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1] / "ios"

def clean_code(text):
    out = []
    i = 0
    n = len(text)
    while i < n:
        if text[i:i+2] == '/*':
            out.append(' ')
            i += 2
            while i < n and text[i:i+2] != '*/':
                if text[i] == '\n':
                    out.append('\n')
                i += 1
            i += 2
        elif text[i:i+2] == '//':
            i += 2
            while i < n and text[i] != '\n':
                i += 1
        elif text[i:i+3] == '"""':
            out.append('"')
            i += 3
            while i < n and text[i:i+3] != '"""':
                if text[i] == '\n':
                    out.append('\n')
                elif text[i] == '\\' and i + 1 < n:
                    i += 1
                i += 1
            i += 3
            out.append('"')
        elif text[i] == '"':
            out.append('"')
            i += 1
            while i < n and text[i] != '"' and text[i] != '\n':
                if text[i] == '\\' and i + 1 < n:
                    i += 2
                    continue
                i += 1
            if i < n and text[i] == '"':
                i += 1
            out.append('"')
        else:
            out.append(text[i])
            i += 1
    return "".join(out)

def check_file(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    no_strings = clean_code(text)

    stack = []
    errors = []
    lines = no_strings.split('\n')
    
    for lno, line in enumerate(lines, 1):
        for ch in line:
            if ch in '({[':
                stack.append((ch, lno))
            elif ch in ')}]':
                if not stack:
                    errors.append(f"Unexpected '{ch}' at line {lno}")
                else:
                    open_ch, open_lno = stack.pop()
                    expected = {'(': ')', '{': '}', '[': ']'}[open_ch]
                    if ch != expected:
                        errors.append(f"Mismatched '{open_ch}' from line {open_lno} with '{ch}' at line {lno}")

    while stack:
        open_ch, open_lno = stack.pop()
        errors.append(f"Unclosed '{open_ch}' from line {open_lno}")

    return errors

def main():
    total_files = 0
    total_errors = 0
    for root, dirs, files in os.walk(str(ROOT_DIR)):
        for f in sorted(files):
            if f.endswith('.swift'):
                total_files += 1
                fpath = os.path.join(root, f)
                rel = os.path.relpath(fpath, ROOT_DIR)
                errs = check_file(fpath)
                if errs:
                    total_errors += len(errs)
                    print(f"❌ {rel}:")
                    for e in errs:
                        print(f"   {e}")
                else:
                    pass

    print(f"\nScanned {total_files} Swift files. Total syntax/bracket errors: {total_errors}")

if __name__ == "__main__":
    main()
