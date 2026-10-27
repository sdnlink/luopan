import os
import re
from pathlib import Path

root_dir = Path(__file__).resolve().parents[1] / "ios" / "TiandiLuopan"

# Singletons to check
singletons = [
    ("Mountain24Data", "Mountain24.swift"),
    ("Hexagram64Data", "Hexagram64.swift"),
    ("FlyingStarsEngine", "FlyingStarsEngine.swift"),
    ("BaZhaiEngine", "BaZhaiEngine.swift"),
    ("SanHeWaterEngine", "SanHeWaterEngine.swift"),
    ("SolarTimeCalculator", "SolarTimeCalculator.swift"),
    ("ExteriorShaEngine", "ExteriorShaEngine.swift"),
    ("QimenEngine", "QimenEngine.swift"),
    ("PurpleWhiteEngine", "PurpleWhiteEngine.swift"),
    ("FloorplanEngine", "FloorplanEngine.swift"),
    ("Fenjin120Data", "Fenjin120Data.swift"),
    ("TianJiShuEngine", "TianJiShuEngine.swift"),
    ("CompassLayerManager", "CompassLayerManager.swift"),
    ("StoreKitIAPManager", "StoreKitIAPManager.swift")
]

# Collect all members of each singleton
model_members = {}
for class_name, filename in singletons:
    file_path = os.path.join(root_dir, "Models", filename)
    if not os.path.exists(file_path):
        file_path = os.path.join(root_dir, filename)
    with open(file_path, "r", encoding="utf-8") as f:
        code = f.read()
    
    props = set(re.findall(r'(?:public\s+let|public\s+var|@Published\s+public\s+var)\s+([a-zA-Z0-9_]+)', code))
    methods = set(re.findall(r'public\s+func\s+([a-zA-Z0-9_]+)', code))
    model_members[class_name] = props.union(methods)

print("Loaded singletons definitions:", len(model_members))

# Scan all swift files for <Singleton>.shared.<call>
errors = []
for root, dirs, files in os.walk(root_dir):
    for file in files:
        if file.endswith('.swift'):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            
            for class_name, _ in singletons:
                pattern = rf'{class_name}\.shared\.([a-zA-Z0-9_]+)'
                calls = re.findall(pattern, content)
                for call in set(calls):
                    if call not in model_members[class_name]:
                        errors.append(f"In {file}: {class_name}.shared.{call} not found in {class_name}!")

if not errors:
    print("ALL singleton method and property invocations verified successfully! 100% matched.")
else:
    for e in errors:
        print("ERROR:", e)
