import os
import json
from PIL import Image

def generate_ios_icons():
    src_path = os.path.abspath("app/src/main/res/mipmap-xxxhdpi/ic_launcher.png")
    if not os.path.exists(src_path):
        print(f"Source icon not found at {src_path}")
        return

    output_dir = os.path.abspath("ios/TiandiLuopan/Assets.xcassets/AppIcon.appiconset")
    os.makedirs(output_dir, exist_ok=True)
    pwa_dir = os.path.abspath("ios/TiandiLuopan/www")
    os.makedirs(pwa_dir, exist_ok=True)

    img = Image.open(src_path).convert("RGBA")
    print(f"Loaded source icon: {img.size}")

    # iOS icon specification
    # Each entry: (filename, size_px, idiom, size_pt, scale)
    icon_specs = [
        ("icon-20@2x.png", 40, "iphone", "20x20", "2x"),
        ("icon-20@3x.png", 60, "iphone", "20x20", "3x"),
        ("icon-29@2x.png", 58, "iphone", "29x29", "2x"),
        ("icon-29@3x.png", 87, "iphone", "29x29", "3x"),
        ("icon-40@2x.png", 80, "iphone", "40x40", "2x"),
        ("icon-40@3x.png", 120, "iphone", "40x40", "3x"),
        ("icon-60@2x.png", 120, "iphone", "60x60", "2x"),
        ("icon-60@3x.png", 180, "iphone", "60x60", "3x"),
        ("icon-20@1x-ipad.png", 20, "ipad", "20x20", "1x"),
        ("icon-20@2x-ipad.png", 40, "ipad", "20x20", "2x"),
        ("icon-29@1x-ipad.png", 29, "ipad", "29x29", "1x"),
        ("icon-29@2x-ipad.png", 58, "ipad", "29x29", "2x"),
        ("icon-40@1x-ipad.png", 40, "ipad", "40x40", "1x"),
        ("icon-40@2x-ipad.png", 80, "ipad", "40x40", "2x"),
        ("icon-76@1x-ipad.png", 76, "ipad", "76x76", "1x"),
        ("icon-76@2x-ipad.png", 152, "ipad", "76x76", "2x"),
        ("icon-83.5@2x-ipad.png", 167, "ipad", "83.5x83.5", "2x"),
        ("icon-1024.png", 1024, "ios-marketing", "1024x1024", "1x")
    ]

    contents_images = []

    for filename, px, idiom, size_pt, scale in icon_specs:
        resized = img.resize((px, px), Image.Resampling.LANCZOS)
        file_path = os.path.join(output_dir, filename)
        resized.save(file_path, "PNG")
        contents_images.append({
            "size": size_pt,
            "idiom": idiom,
            "filename": filename,
            "scale": scale
        })
        print(f"Generated {filename} ({px}x{px})")

    # Generate PWA icons
    pwa_icon_512 = img.resize((512, 512), Image.Resampling.LANCZOS)
    pwa_icon_512.save(os.path.join(pwa_dir, "icon-512.png"), "PNG")
    pwa_icon_192 = img.resize((192, 192), Image.Resampling.LANCZOS)
    pwa_icon_192.save(os.path.join(pwa_dir, "icon-192.png"), "PNG")
    pwa_icon_apple = img.resize((180, 180), Image.Resampling.LANCZOS)
    pwa_icon_apple.save(os.path.join(pwa_dir, "apple-touch-icon.png"), "PNG")

    contents_json = {
        "images": contents_images,
        "info": {
            "version": 1,
            "author": "xcode"
        }
    }

    with open(os.path.join(output_dir, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump(contents_json, f, indent=2, ensure_ascii=False)

    # Assets.xcassets Contents.json
    xcassets_dir = os.path.abspath("ios/TiandiLuopan/Assets.xcassets")
    with open(os.path.join(xcassets_dir, "Contents.json"), "w", encoding="utf-8") as f:
        json.dump({"info": {"version": 1, "author": "xcode"}}, f, indent=2)

    print("iOS AppIcon generation complete!")

if __name__ == "__main__":
    generate_ios_icons()
