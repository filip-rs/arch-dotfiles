#!/usr/bin/env python3
"""Build the icon theme "Palette": Adwaita with its folders in the accent colour.

Usage: folder_icons.py <accent #rrggbb> <output theme dir>
Called by theme_apply.sh (section 4b); every other icon is inherited from Adwaita.

Adwaita draws its folders with a few blue shades: a light front panel
(#a4caee), a darker back panel and emblem, and edge highlights. The front panel
becomes the accent; every other shade keeps its lightness and chroma offset
from the front panel in OKLCH, so the folders keep Adwaita's depth and contrast.
"""
import math
import re
import shutil
import sys
from pathlib import Path

ADWAITA = Path("/usr/share/icons/Adwaita/scalable")
ICONS = {
    "places": ["folder*.svg", "user-home.svg", "user-desktop.svg"],
    "mimetypes": ["inode-directory.svg"],
    "status": ["folder-open.svg", "folder-drag-accept.svg"],
}
CONTEXTS = {"places": "Places", "mimetypes": "MimeTypes", "status": "Status"}
FRONT = "#a4caee"  # the large visible front panel
# Front-panel lightness range that still reads as a folder: lighter washes the
# highlights out to white, darker makes the back panel and emblems muddy.
L_MIN, L_MAX = 0.66, 0.88


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def linear_to_srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def hex_to_oklch(h):
    r, g, b = (srgb_to_linear(int(h[i:i + 2], 16) / 255) for i in (1, 3, 5))
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360


def oklch_to_rgb(L, C, H):
    a, b = C * math.cos(math.radians(H)), C * math.sin(math.radians(H))
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def oklch_to_hex(L, C, H):
    L = min(max(L, 0.0), 1.0)
    while True:  # reduce chroma until the colour fits in sRGB
        rgb = oklch_to_rgb(L, C, H)
        if all(-1e-4 <= c <= 1 + 1e-4 for c in rgb) or C < 1e-3:
            break
        C *= 0.95
    return "#" + "".join(f"{round(min(max(linear_to_srgb(max(c, 0)), 0), 1) * 255):02x}" for c in rgb)


def main():
    accent, out = sys.argv[1], Path(sys.argv[2])
    fL, fC, fH = hex_to_oklch(FRONT)
    aL, aC, aH = hex_to_oklch(accent)
    aL = min(max(aL, L_MIN), L_MAX)
    grey = aC < 0.03  # monochrome palettes get neutral grey folders

    def recolour(m):
        L, C, H = hex_to_oklch(m.group(0).lower())
        if C < 0.03 or abs((H - fH + 180) % 360 - 180) > 45:
            return m.group(0)  # greys and non-blue details stay as they are
        return oklch_to_hex(aL + (L - fL), 0 if grey else max(aC + (C - fC), 0), aH)

    # Build next to the target and swap, so apps never see a half-written theme
    tmp = out.with_name(out.name + ".new")
    shutil.rmtree(tmp, ignore_errors=True)
    dirs = []
    for ctx, patterns in ICONS.items():
        (tmp / "scalable" / ctx).mkdir(parents=True)
        dirs.append(f"scalable/{ctx}")
        for pat in patterns:
            for src in sorted((ADWAITA / ctx).glob(pat)):
                svg = re.sub(r"#[0-9a-fA-F]{6}\b", recolour, src.read_text())
                (tmp / "scalable" / ctx / src.name).write_text(svg)

    sections = "".join(
        f"\n[{d}]\nContext={CONTEXTS[d.split('/')[1]]}\nSize=128\nMinSize=8\nMaxSize=512\nType=Scalable\n"
        for d in dirs)
    (tmp / "index.theme").write_text(
        "[Icon Theme]\nName=Palette\nComment=Adwaita with folders recoloured by theme_apply.sh\n"
        f"Inherits=Adwaita,hicolor\nDirectories={','.join(dirs)}\n{sections}")

    shutil.rmtree(out, ignore_errors=True)
    tmp.rename(out)


if __name__ == "__main__":
    main()
