import os
import re
from pathlib import Path

root_dir = Path(__file__).resolve().parents[1] / "ios" / "TiandiLuopan"

identifiable_structs = {}
all_structs = {}

for root, dirs, files in os.walk(root_dir):
    for file in files:
        if file.endswith('.swift'):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                code = f.read()
            
            # Find all struct definitions
            matches = re.finditer(r'struct\s+([a-zA-Z0-9_]+)(?:\s*:\s*([^{]+))?\s*\{', code)
            for m in matches:
                name = m.group(1)
                protocols = m.group(2) or ""
                all_structs[name] = path
                if "Identifiable" in protocols:
                    identifiable_structs[name] = path

print(f"Total structs: {len(all_structs)}, Identifiable structs: {len(identifiable_structs)}")

# Check that every Identifiable struct has an 'id' member
id_missing = []
for struct_name, file in identifiable_structs.items():
    path = os.path.join(root_dir, file) if not os.path.exists(file) else file
    with open(path, "r", encoding="utf-8") as f:
        code = f.read()
    
    # Extract struct block
    m = re.search(rf'struct\s+{struct_name}[^{{]*\{{([\s\S]*?)\n\}}', code)
    if m:
        block = m.group(1)
        if not re.search(r'\b(?:var|let)\s+id\b', block):
            id_missing.append((struct_name, file))

if not id_missing:
    print("ALL Identifiable structs have a valid 'id' property!")
else:
    for s, f in id_missing:
        print("ERROR: Struct missing id:", s, "in", f)
