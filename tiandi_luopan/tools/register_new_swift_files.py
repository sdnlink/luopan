import os
import re

def update_pbxproj():
    pbx_path = os.path.abspath("tiandi_luopan/ios/TiandiLuopan.xcodeproj/project.pbxproj")
    if not os.path.exists(pbx_path):
        pbx_path = os.path.abspath("ios/TiandiLuopan.xcodeproj/project.pbxproj")
    
    with open(pbx_path, "r", encoding="utf-8") as f:
        content = f.read()

    swift_dir = os.path.abspath("tiandi_luopan/ios/TiandiLuopan")
    if not os.path.exists(swift_dir):
        swift_dir = os.path.abspath("ios/TiandiLuopan")

    all_swifts = []
    for root, dirs, files in os.walk(swift_dir):
        for f in files:
            if f.endswith('.swift'):
                rel = os.path.relpath(os.path.join(root, f), swift_dir).replace('\\', '/')
                all_swifts.append((f, rel))

    missing = [s for s in all_swifts if s[0] not in content]
    if not missing:
        print("All Swift files are already registered in project.pbxproj!")
        return

    print(f"Registering {len(missing)} missing files to project.pbxproj:")
    for f, rel in missing:
        print(f"  + {f} ({rel})")

    # Find highest existing IDs in 10xx and 20xx ranges
    b_ids = [int(m) for m in re.findall(r'\b(1\d{3})\b /\* .* in Sources \*/', content)]
    f_ids = [int(m) for m in re.findall(r'\b(2\d{3})\b /\* .*\.swift \*/', content)]

    next_b_id = max(b_ids) + 1 if b_ids else 1070
    next_f_id = max(f_ids) + 1 if f_ids else 2070

    build_entries = ""
    file_entries = ""
    group_entries = ""
    sources_entries = ""

    last_f_id = str(max(f_ids))
    last_b_id = str(max(b_ids))

    for name, rel_path in missing:
        b_id_str = str(next_b_id)
        f_id_str = str(next_f_id)
        next_b_id += 1
        next_f_id += 1

        build_entries += f"\t\t{b_id_str} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {f_id_str} /* {name} */; }};\n"
        file_entries += f'\t\t{f_id_str} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{rel_path}"; sourceTree = "<group>"; }};\n'
        group_entries += f"\t\t\t\t{f_id_str} /* {name} */,\n"
        sources_entries += f"\t\t\t\t{b_id_str} /* {name} in Sources */,\n"

    content = content.replace("/* End PBXBuildFile section */", build_entries + "/* End PBXBuildFile section */")
    content = content.replace("/* End PBXFileReference section */", file_entries + "/* End PBXFileReference section */")

    # Add to main group and sources build phase
    # Find an anchor in group
    anchor_file_pattern = rf'({last_f_id} /\* .*? \*/,)'
    match_group = re.search(anchor_file_pattern, content)
    if match_group:
        content = content.replace(match_group.group(1), match_group.group(1) + "\n" + group_entries.rstrip("\n"))
    else:
        # Fallback to FengshuiPalaceDetailSheet
        content = content.replace("2061 /* FengshuiPalaceDetailSheet.swift */,", "2061 /* FengshuiPalaceDetailSheet.swift */,\n" + group_entries.rstrip("\n"))

    anchor_sources_pattern = rf'({last_b_id} /\* .*? in Sources \*/,)'
    match_sources = re.search(anchor_sources_pattern, content)
    if match_sources:
        content = content.replace(match_sources.group(1), match_sources.group(1) + "\n" + sources_entries.rstrip("\n"))
    else:
        content = content.replace("1061 /* FengshuiPalaceDetailSheet.swift in Sources */,", "1061 /* FengshuiPalaceDetailSheet.swift in Sources */,\n" + sources_entries.rstrip("\n"))

    with open(pbx_path, "w", encoding="utf-8") as f:
        f.write(content)

    print("Successfully registered all missing Swift files to project.pbxproj!")

if __name__ == "__main__":
    update_pbxproj()
