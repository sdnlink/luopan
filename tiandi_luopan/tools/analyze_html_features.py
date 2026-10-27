import re
import os

with open('tiandi_luopan/app/src/main/assets/yiijing_map.html', 'r', encoding='utf-8', errors='ignore') as f:
    text = f.read()

# Find all HTML elements with id
ids = re.findall(r'id=["\']([^"\']+)["\']', text)
print(f"Total IDs: {len(ids)}")

# Find all modal or sheet or overlay divs
modals = [i for i in ids if any(k in i.lower() for k in ['modal', 'sheet', 'overlay', 'dialog', 'popup', 'card', 'view', 'panel'])]
print("Modals/Panels:", modals)

# Find major JavaScript function definitions
js_funcs = re.findall(r'function\s+([a-zA-Z0-9_$]+)\s*\(', text)
print(f"Total JS functions: {len(js_funcs)}")

# Write summary to a text file for complete inspection
with open('tiandi_luopan/tools/html_features_summary.txt', 'w', encoding='utf-8') as out:
    out.write("=== HTML IDS ===\n")
    for i in ids:
        out.write(f"- {i}\n")
    out.write("\n=== JS FUNCTIONS ===\n")
    for fn in js_funcs:
        out.write(f"- {fn}\n")
print("Saved summary to tiandi_luopan/tools/html_features_summary.txt")
