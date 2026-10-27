import os
import re

manager_path = "tiandi_luopan/ios/TiandiLuopan/CompassMotionManager.swift"
with open(manager_path, "r", encoding="utf-8") as f:
    manager_code = f.read()

# Collect all published properties and methods in CompassMotionManager
manager_props = set(re.findall(r'@Published\s+public\s+var\s+([a-zA-Z0-9_]+)', manager_code))
manager_methods = set(re.findall(r'public\s+func\s+([a-zA-Z0-9_]+)', manager_code))
all_manager_members = manager_props.union(manager_methods)

print("CompassMotionManager members count:", len(all_manager_members))

# Scan all other swift files
root_dir = "tiandi_luopan/ios/TiandiLuopan"
missing_members = {}

for root, dirs, files in os.walk(root_dir):
    for file in files:
        if file.endswith('.swift') and file != 'CompassMotionManager.swift':
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            
            # Find usages of motion.<name>
            matches = re.findall(r'\bmotion\.([a-zA-Z0-9_]+)', content)
            for m in set(matches):
                if m not in all_manager_members:
                    if m not in missing_members:
                        missing_members[m] = []
                    missing_members[m].append(file)

print("\nMissing members in CompassMotionManager used by other files:")
for m, files in missing_members.items():
    print(f"  - '{m}' used in: {files}")
