"""Split any wallpaper for a triple-monitor setup (or produce a single center image).

Triple-monitor layout:
  DP-2 (left)   1920x1080 @ -1920,250
  DP-1 (center) 2560x1440 @ 0,0
  DP-3 (right)  2560x1440 @ 2560,0

In triple mode the image is scaled to cover the full virtual desktop (7040x1440)
and each monitor's region is cropped with correct y-offsets.

In --center-only mode a single center.png is produced, scaled-to-cover 2560x1440.

Usage:
  python split_wallpaper.py <image_path> [output_dir]                # triple split
  python split_wallpaper.py <image_path> [output_dir] --center-only  # center only
"""

import os
import sys
from PIL import Image

MONITORS = {
    "left":   {"x": 0,    "y": 250, "w": 1920, "h": 1080},
    "center": {"x": 1920, "y": 0,   "w": 2560, "h": 1440},
    "right":  {"x": 4480, "y": 0,   "w": 2560, "h": 1440},
}

CANVAS_W = 7040
CANVAS_H = 1440

CENTER_W = 2560
CENTER_H = 1440


def _cover_resize(img, target_w, target_h):
    src_w, src_h = img.size
    scale = max(target_w / src_w, target_h / src_h)
    new_w = round(src_w * scale)
    new_h = round(src_h * scale)
    if new_w != src_w or new_h != src_h:
        img = img.resize((new_w, new_h), Image.LANCZOS)
    return img, new_w, new_h


def split_wallpaper(image_path, output_dir="."):
    with Image.open(image_path) as img:
        img, new_w, new_h = _cover_resize(img, CANVAS_W, CANVAS_H)
        off_x = (new_w - CANVAS_W) // 2
        off_y = (new_h - CANVAS_H) // 2

        for name, mon in MONITORS.items():
            x1 = off_x + mon["x"]
            y1 = off_y + mon["y"]
            x2 = x1 + mon["w"]
            y2 = y1 + mon["h"]

            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(new_w, x2), min(new_h, y2)

            cropped = img.crop((x1, y1, x2, y2))

            if cropped.size != (mon["w"], mon["h"]):
                canvas = Image.new("RGB", (mon["w"], mon["h"]), (0, 0, 0))
                canvas.paste(cropped, (0, 0))
                cropped = canvas

            out_path = os.path.join(output_dir, f"{name}.png")
            cropped.save(out_path)
            print(f"Saved {out_path} ({mon['w']}x{mon['h']})")


def center_only(image_path, output_dir="."):
    with Image.open(image_path) as img:
        if img.mode != "RGB":
            img = img.convert("RGB")
        img, new_w, new_h = _cover_resize(img, CENTER_W, CENTER_H)
        off_x = (new_w - CENTER_W) // 2
        off_y = (new_h - CENTER_H) // 2
        cropped = img.crop((off_x, off_y, off_x + CENTER_W, off_y + CENTER_H))
        out_path = os.path.join(output_dir, "center.png")
        cropped.save(out_path)
        print(f"Saved {out_path} ({CENTER_W}x{CENTER_H})")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}

    if not args:
        print("Usage: python split_wallpaper.py <image_path> [output_dir] [--center-only]")
        sys.exit(1)

    image_path = args[0]
    output_dir = args[1] if len(args) > 1 else "."
    os.makedirs(output_dir, exist_ok=True)

    if "--center-only" in flags:
        center_only(image_path, output_dir)
    else:
        split_wallpaper(image_path, output_dir)
