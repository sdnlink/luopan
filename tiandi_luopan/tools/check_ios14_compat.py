import os
import re
from pathlib import Path

root_dir = Path(__file__).resolve().parents[1] / "ios" / "TiandiLuopan"

ios15_patterns = [
    (r'\bColor\.(cyan|brown|mint|teal|indigo)\b', "iOS 15+ exclusive Color"),
    (r'\.task\s*\{', "iOS 15+ .task modifier"),
    (r'\.refreshable\s*\{', "iOS 15+ .refreshable modifier"),
    (r'\.badge\s*\(', "iOS 15+ .badge modifier"),
    (r'\.onSubmit\s*\{', "iOS 15+ .onSubmit modifier"),
    (r'\bPhotosPicker\b', "iOS 16+ PhotosPicker"),
    (r'\.searchable\s*\(', "iOS 15+ .searchable modifier"),
    (r'\.material\b', "iOS 15+ Material"),
    (r'\.tint\s*\(', "iOS 15+ .tint modifier (use .accentColor on iOS 14)"),
]

findings = []

for root, dirs, files in os.walk(root_dir):
    for file in files:
        if file.endswith('.swift'):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                lines = f.readlines()
            for line_no, line in enumerate(lines, 1):
                for pattern, desc in ios15_patterns:
                    m = re.search(pattern, line)
                    if m:
                        findings.append((file, line_no, line.strip(), desc))

print(f"Total iOS 15+ compatibility findings: {len(findings)}")
for f, l, content, desc in findings:
    print(f"  [{desc}] {f}:{l} -> {content}")
