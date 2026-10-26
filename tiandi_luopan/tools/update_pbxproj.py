import os

def update_project():
    pbx_path = os.path.abspath("ios/TiandiLuopan.xcodeproj/project.pbxproj")
    with open(pbx_path, "r", encoding="utf-8") as f:
        content = f.read()

    new_sources = [
        ("1020", "2020", "Mountain24.swift", "Models/Mountain24.swift"),
        ("1021", "2021", "Hexagram64.swift", "Models/Hexagram64.swift"),
        ("1022", "2022", "FlyingStarsEngine.swift", "Models/FlyingStarsEngine.swift"),
        ("1023", "2023", "BaZhaiEngine.swift", "Models/BaZhaiEngine.swift"),
        ("1024", "2024", "SanHeWaterEngine.swift", "Models/SanHeWaterEngine.swift"),
        ("1025", "2025", "SolarTimeCalculator.swift", "Models/SolarTimeCalculator.swift"),
        ("1026", "2026", "ExteriorShaEngine.swift", "Models/ExteriorShaEngine.swift"),
        ("1030", "2030", "CompassDialView.swift", "Views/Compass/CompassDialView.swift"),
        ("1031", "2031", "CompassHeaderView.swift", "Views/Compass/CompassHeaderView.swift"),
        ("1032", "2032", "CompassMainView.swift", "Views/Compass/CompassMainView.swift"),
        ("1033", "2033", "ARVisionView.swift", "Views/ARVision/ARVisionView.swift"),
        ("1034", "2034", "XuanKongGridView.swift", "Views/Analysis/XuanKongGridView.swift"),
        ("1035", "2035", "BaZhaiView.swift", "Views/Analysis/BaZhaiView.swift"),
        ("1036", "2036", "SettingsView.swift", "Views/Settings/SettingsView.swift"),
        ("1037", "2037", "RootContentView.swift", "Views/RootContentView.swift"),
    ]

    # Check if already added
    if "Mountain24.swift" in content:
        print("Project pbxproj already contains Mountain24.swift")
        return

    # 1. PBXBuildFile section
    build_entries = ""
    for b_id, f_id, name, path in new_sources:
        build_entries += f"\t\t{b_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id} /* {name} */; }};\n"
    build_entries += "\t\t1040 /* AVFoundation.framework in Frameworks */ = {isa = PBXBuildFile; fileRef = 2040 /* AVFoundation.framework */; };\n"

    content = content.replace("/* End PBXBuildFile section */", build_entries + "/* End PBXBuildFile section */")

    # 2. PBXFileReference section
    file_entries = ""
    for b_id, f_id, name, path in new_sources:
        file_entries += f'\t\t{f_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = "<group>"; }};\n'
    file_entries += '\t\t2040 /* AVFoundation.framework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = AVFoundation.framework; path = System/Library/Frameworks/AVFoundation.framework; sourceTree = SDKROOT; };\n'

    content = content.replace("/* End PBXFileReference section */", file_entries + "/* End PBXFileReference section */")

    # 3. PBXFrameworksBuildPhase
    content = content.replace("1011 /* StoreKit.framework in Frameworks */,", "1011 /* StoreKit.framework in Frameworks */,\n\t\t\t\t1040 /* AVFoundation.framework in Frameworks */,")

    # 4. PBXGroup Main TiandiLuopan
    group_entries = ""
    for b_id, f_id, name, path in new_sources:
        group_entries += f"\t\t\t\t{f_id} /* {name} */,\n"
    content = content.replace("2010 /* Info.plist */,", "2010 /* Info.plist */,\n" + group_entries)

    # Frameworks group
    content = content.replace("2012 /* StoreKit.framework */,", "2012 /* StoreKit.framework */,\n\t\t\t\t2040 /* AVFoundation.framework */,")

    # 5. PBXSourcesBuildPhase
    sources_entries = ""
    for b_id, f_id, name, path in new_sources:
        sources_entries += f"\t\t\t\t{b_id} /* {name} in Sources */,\n"
    content = content.replace("1010 /* StoreKitIAPManager.swift in Sources */,", "1010 /* StoreKitIAPManager.swift in Sources */,\n" + sources_entries)

    with open(pbx_path, "w", encoding="utf-8") as f:
        f.write(content)

    print("Updated project.pbxproj successfully!")

if __name__ == "__main__":
    update_project()
