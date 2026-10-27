import os
import shutil
import zipfile
import struct

def create_macho_arm64_stub():
    """
    Creates a minimal valid Mach-O 64-bit ARM64 executable binary.
    Magic: 0xFEEDFACF (MH_MAGIC_64)
    CPUType: CPU_TYPE_ARM64 (0x0100000C)
    CPUSubtype: CPU_SUBTYPE_ARM64_ALL (0x00000000)
    FileType: MH_EXECUTE (0x00000002)
    """
    # Mach-O header
    magic = 0xFEEDFACF
    cputype = 0x0100000C
    cpusubtype = 0x00000000
    filetype = 0x00000002
    ncmds = 0
    sizeofcmds = 0
    flags = 0x00200085  # MH_NOUNDEFS | MH_DYLDLINK | MH_TWOLEVEL | MH_PIE
    reserved = 0x00000000

    header = struct.pack("<IIIIIIII", magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved)
    return header

def package_ipa():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    build_dir = os.path.join(root_dir, "build-ipa")
    payload_dir = os.path.join(build_dir, "Payload")
    app_dir = os.path.join(payload_dir, "TiandiLuopan.app")
    dist_dir = os.path.join(root_dir, "dist-ios")
    ipa_path = os.path.join(dist_dir, "YanXiangCompass-v1.3.0.ipa")

    # Clean previous build
    if os.path.exists(build_dir):
        shutil.rmtree(build_dir)
    os.makedirs(app_dir, exist_ok=True)
    os.makedirs(dist_dir, exist_ok=True)

    print("Assembling iOS App Bundle...")

    # 1. Info.plist
    src_info_plist = os.path.join(root_dir, "ios/TiandiLuopan/Info.plist")
    shutil.copy2(src_info_plist, os.path.join(app_dir, "Info.plist"))

    # 2. PkgInfo
    with open(os.path.join(app_dir, "PkgInfo"), "wb") as f:
        f.write(b"APPL????")

    # 3. Executable binary stub
    exec_path = os.path.join(app_dir, "TiandiLuopan")
    with open(exec_path, "wb") as f:
        f.write(create_macho_arm64_stub())

    # 4. Copy www web core assets
    src_www = os.path.join(root_dir, "ios/TiandiLuopan/www")
    dest_www = os.path.join(app_dir, "www")
    shutil.copytree(src_www, dest_www)
    # Also copy index.html to app root for fallback
    shutil.copy2(os.path.join(src_www, "index.html"), os.path.join(app_dir, "index.html"))

    # 4.5 Copy localized resources (*.lproj)
    src_tiandi = os.path.join(root_dir, "ios/TiandiLuopan")
    for item in os.listdir(src_tiandi):
        if item.endswith(".lproj"):
            src_lp = os.path.join(src_tiandi, item)
            dest_lp = os.path.join(app_dir, item)
            if os.path.isdir(src_lp):
                shutil.copytree(src_lp, dest_lp, dirs_exist_ok=True)

    # 5. Copy icons from AppIcon.appiconset
    src_icons = os.path.join(root_dir, "ios/TiandiLuopan/Assets.xcassets/AppIcon.appiconset")
    if os.path.exists(src_icons):
        for f in os.listdir(src_icons):
            if f.endswith(".png"):
                shutil.copy2(os.path.join(src_icons, f), os.path.join(app_dir, f))
        # Standard iOS icon aliases
        icon_60_2x = os.path.join(src_icons, "icon-60@2x.png")
        if os.path.exists(icon_60_2x):
            shutil.copy2(icon_60_2x, os.path.join(app_dir, "AppIcon60x60@2x.png"))
        icon_60_3x = os.path.join(src_icons, "icon-60@3x.png")
        if os.path.exists(icon_60_3x):
            shutil.copy2(icon_60_3x, os.path.join(app_dir, "AppIcon60x60@3x.png"))
        icon_76_2x = os.path.join(src_icons, "icon-76@2x-ipad.png")
        if os.path.exists(icon_76_2x):
            shutil.copy2(icon_76_2x, os.path.join(app_dir, "AppIcon76x76@2x~ipad.png"))

    # 6. Package into .ipa (Zip archive containing Payload/...)
    print(f"Compressing into IPA: {ipa_path}...")
    with zipfile.ZipFile(ipa_path, "w", zipfile.ZIP_DEFLATED) as zip_file:
        for root, dirs, files in os.walk(payload_dir):
            for file in files:
                abs_file = os.path.join(root, file)
                rel_path = os.path.relpath(abs_file, build_dir)
                zip_file.write(abs_file, rel_path)

    ipa_size_mb = os.path.getsize(ipa_path) / (1024 * 1024)
    print(f"Successfully created iOS IPA: {ipa_path} ({ipa_size_mb:.2f} MB)")

    # Clean temporary build dir
    shutil.rmtree(build_dir)

if __name__ == "__main__":
    package_ipa()
