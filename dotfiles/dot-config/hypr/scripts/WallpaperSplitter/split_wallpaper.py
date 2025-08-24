import sys

from PIL import Image


def split_wallpaper(image_path):
    with Image.open(image_path) as img:
        width, height = img.size
        if width != 7680 or height < 1440:
            raise ValueError(f"Expected at least 7680x1440 image, got {img.size}")

        # Define offsets from center monitor baseline (y=0)
        # Positive means monitor is physically LOWER, so crop shifts UP
        y_offsets = {
            "left": -134,
            "center": 0,
            "right": -40,
        }

        regions = {
            "left": (0, 0, 2560, 1440),
            "center": (2560, 0, 5120, 1440),
            "right": (5120, 0, 7680, 1440),
        }

        for name, (x1, _, x2, _) in regions.items():
            y_shift = y_offsets[name]
            top = (height - 1440) // 2 - y_shift
            bottom = top + 1440

            # Clamp to image bounds just in case
            top = max(0, top)
            bottom = min(height, bottom)

            cropped = img.crop((x1, top, x2, bottom))
            cropped.save(f"{name}.png")
            print(f"Saved {name}.png with vertical offset {y_shift}px")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python split_wallpaper.py <image_path>")
        sys.exit(1)

    image_path = sys.argv[1]
    split_wallpaper(image_path)
