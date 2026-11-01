#!/usr/bin/env python3
"""Logo'dan AppIcon seti + launch görselleri üretir (Pillow).
Kullanım: python3 scripts/generate_icons.py /path/to/logo.jpg
"""
import json, os, sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "AdisyonYonetim", "Resources", "Assets.xcassets")
TEAL = (0x0F, 0x76, 0x6E)

ICONS = [  # (idiom, size pt, scale)
    ("iphone", 20, 2), ("iphone", 20, 3), ("iphone", 29, 2), ("iphone", 29, 3),
    ("iphone", 40, 2), ("iphone", 40, 3), ("iphone", 60, 2), ("iphone", 60, 3),
    ("ipad", 20, 1), ("ipad", 20, 2), ("ipad", 29, 1), ("ipad", 29, 2),
    ("ipad", 40, 1), ("ipad", 40, 2), ("ipad", 76, 1), ("ipad", 76, 2), ("ipad", 83.5, 2),
    ("ios-marketing", 1024, 1),
]

def square(img, size, bg=(255, 255, 255)):
    """Logoyu kare tuvale ortalar; şeffaflık yok (App Store gereği)."""
    w, h = img.size
    side = max(w, h)
    canvas = Image.new("RGB", (side, side), bg)
    canvas.paste(img, ((side - w) // 2, (side - h) // 2))
    return canvas.resize((size, size), Image.LANCZOS)

def write_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)

def main(src):
    logo = Image.open(src).convert("RGB")
    # kenar rengini arka plan olarak kullan
    bg = logo.getpixel((2, 2))
    os.makedirs(ROOT, exist_ok=True)
    write_json(os.path.join(ROOT, "Contents.json"), {"info": {"author": "xcode", "version": 1}})

    icon_dir = os.path.join(ROOT, "AppIcon.appiconset")
    os.makedirs(icon_dir, exist_ok=True)
    images = []
    for idiom, pt, scale in ICONS:
        px = int(round(pt * scale))
        pt_s = ("%g" % pt)
        name = f"icon-{idiom}-{pt_s}@{scale}x.png"
        square(logo, px, bg).save(os.path.join(icon_dir, name), "PNG")
        images.append({"idiom": idiom, "size": f"{pt_s}x{pt_s}", "scale": f"{scale}x", "filename": name})
    write_json(os.path.join(icon_dir, "Contents.json"), {"images": images, "info": {"author": "xcode", "version": 1}})

    launch_dir = os.path.join(ROOT, "LaunchLogo.imageset")
    os.makedirs(launch_dir, exist_ok=True)
    limgs = []
    for scale in (1, 2, 3):
        name = f"launch-logo@{scale}x.png"
        square(logo, 200 * scale, bg).save(os.path.join(launch_dir, name), "PNG")
        limgs.append({"idiom": "universal", "scale": f"{scale}x", "filename": name})
    write_json(os.path.join(launch_dir, "Contents.json"), {"images": limgs, "info": {"author": "xcode", "version": 1}})

    def color_set(name, light, dark):
        d = os.path.join(ROOT, f"{name}.colorset")
        os.makedirs(d, exist_ok=True)
        def comp(rgb):
            return {"color-space": "srgb", "components": {"red": "0x%02X" % rgb[0], "green": "0x%02X" % rgb[1], "blue": "0x%02X" % rgb[2], "alpha": "1.000"}}
        write_json(os.path.join(d, "Contents.json"), {
            "colors": [
                {"idiom": "universal", "color": comp(light)},
                {"idiom": "universal", "appearances": [{"appearance": "luminosity", "value": "dark"}], "color": comp(dark)},
            ],
            "info": {"author": "xcode", "version": 1},
        })
    color_set("LaunchBackground", (0xFF, 0xFF, 0xFF), (0xFF, 0xFF, 0xFF))  # logo zemini beyaz
    color_set("AccentColor", TEAL, (0x14, 0xB8, 0xA6))
    color_set("BrandAmber", (0xF5, 0x9E, 0x0B), (0xFB, 0xBF, 0x24))
    print("ok", len(images), "icons; bg", bg)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/workspace/adisyonyonetim_logo.jpg")
