#!/usr/bin/env bash
# matugen_apply.sh — regenerate ~/.config/quickshell/qs_colors.json from a wallpaper.
#
# Usage: matugen_apply.sh <image> [dark|light]
#
# The single place matugen runs, so a wallpaper gives the same palette however
# it was applied (wallpaper picker, theme menu). theme_apply.sh then turns
# qs_colors.json into every app's colours.

set -uo pipefail

src="${1:-}"
mode="${2:-dark}"
[ -f "$src" ] || { echo "matugen_apply.sh: image not found: $src" >&2; exit 1; }

MATUGEN_CONFIG="$HOME/.config/matugen/config.toml"
if [ ! -f "$MATUGEN_CONFIG" ]; then
    echo "matugen_apply.sh: ~/.config/matugen/config.toml missing; stow the dotfiles first" >&2
    exit 1
fi

mode_args=(-m dark)
[ "$mode" = "light" ] && mode_args=(-m light --contrast -0.5)

# matugen 4.1 aborts the whole run if ANY template's input_path is missing,
# e.g. the Millennium Steam skin on a machine without it, and can leave
# qs_colors.json half-written. Run it on a copy of the config without those
# templates.
runtime_config=$(mktemp --suffix=.toml)
trap 'rm -f "$runtime_config"' EXIT
python3 - "$MATUGEN_CONFIG" "$runtime_config" << 'PYEOF'
import os, re, sys
src, dst = sys.argv[1], sys.argv[2]
out = []
for block in re.split(r'(?m)^(?=\[)', open(src).read()):
    if re.match(r'\[templates\.[^\]]+\]', block):
        ip = re.search(r'input_path\s*=\s*"([^"]+)"', block)
        if ip and not os.path.isfile(os.path.expanduser(ip.group(1))):
            continue
    out.append(block)
open(dst, 'w').write(''.join(out))
PYEOF

matugen -c "$runtime_config" image "$src" --type scheme-content --prefer saturation "${mode_args[@]}" >/dev/null 2>&1 || {
    echo "matugen_apply.sh: matugen failed on $src" >&2
    exit 1
}
