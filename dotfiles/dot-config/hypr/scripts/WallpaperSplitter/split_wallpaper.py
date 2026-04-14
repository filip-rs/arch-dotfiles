"""Split any wallpaper for a triple-monitor setup.

Monitor layout:
  DP-2 (left)   1920x1080 @ -1920,250
  DP-1 (center) 2560x1440 @ 0,0
  DP-3 (right)  2560x1440 @ 2560,0

The image is scaled to cover the full virtual desktop (7040x1440),
then each monitor's region is cropped with correct y-offsets.

Usage: python split_wallpaper.py <image_path> [output_dir]
"""

import os
import sys
from PIL import Image

# Virtual desktop: monitors laid out left-to-right, origin at top-left of canvas
MONITORS = {
    "left":   {"x": 0,    "y": 250, "w": 1920, "h": 1080},  # DP-2 (lower)
    "center": {"x": 1920, "y": 0,   "w": 2560, "h": 1440},  # DP-1
    "right":  {"x": 4480, "y": 0,   "w": 2560, "h": 1440},  # DP-3
}

CANVAS_W = 7040  # 1920 + 2560 + 2560
CANVAS_H = 1440  # tallest monitor


def split_wallpaper(image_path, output_dir="."):
    with Image.open(image_path) as img:
        src_w, src_h = img.size

        # Scale to cover the canvas (like CSS background-size: cover)
        scale = max(CANVAS_W / src_w, CANVAS_H / src_h)
        new_w = round(src_w * scale)
        new_h = round(src_h * scale)

        if new_w != src_w or new_h != src_h:
            img = img.resize((new_w, new_h), Image.LANCZOS)

        # Center-crop to canvas
        off_x = (new_w - CANVAS_W) // 2
        off_y = (new_h - CANVAS_H) // 2

        for name, mon in MONITORS.items():
            x1 = off_x + mon["x"]
            y1 = off_y + mon["y"]
            x2 = x1 + mon["w"]
            y2 = y1 + mon["h"]

            # Clamp to image bounds
            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(new_w, x2), min(new_h, y2)

            cropped = img.crop((x1, y1, x2, y2))

            # Ensure exact output size (pad if clamping reduced it)
            if cropped.size != (mon["w"], mon["h"]):
                canvas = Image.new("RGB", (mon["w"], mon["h"]), (0, 0, 0))
                canvas.paste(cropped, (0, 0))
                cropped = canvas

            out_path = os.path.join(output_dir, f"{name}.png")
            cropped.save(out_path)
            print(f"Saved {out_path} ({mon['w']}x{mon['h']})")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python split_wallpaper.py <image_path> [output_dir]")
        sys.exit(1)

    image_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "."
    os.makedirs(output_dir, exist_ok=True)
    split_wallpaper(image_path, output_dir)
