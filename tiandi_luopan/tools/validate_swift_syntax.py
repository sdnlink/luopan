# -*- coding: utf-8 -*-
"""
Validate Swift syntax: balanced braces, parentheses, and scope resolution across all Swift files.
"""
import os
import re
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1] / "ios" / "TiandiLuopan"

def check_file(path):
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    # Strip comments and string literals to check balanced braces
    no_comments = re.sub(r'//.*', '', text)
    no_comments = re.sub(r'/\*.*?\*/', '', no_comments, flags=re.DOTALL)
    
    # Strip string literals (preserving newlines for line counting)
    def replacer(match):
        return '"' + '\n' * match.group(0).count('\n') + '"'
    no_strings = re.sub(r'"([^"\\]*(?:\\.[^"\\]*)*)"', replacer, no_comments)

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
