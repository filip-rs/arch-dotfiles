import QtQuick
import Quickshell
import Quickshell.Io

// Lockscreen palette, read once from qs_colors.json (written by
// theme_apply.sh). The defaults are the Gruvbox values from that file, so a
// missing or broken theme file still gives a readable lock.
Scope {
    id: root

    property color crust: "#161616"
    property color mantle: "#1d2021"
    property color base: "#282828"
    property color surface0: "#3c3836"
    property color surface1: "#504945"
    property color surface2: "#665c54"
    property color overlay0: "#7c6f64"
    property color overlay1: "#928374"
    property color overlay2: "#a89984"
    property color subtext0: "#d5c4a1"
    property color subtext1: "#bdae93"
    property color text: "#ebdbb2"
    property color accent: "#fabd2f"
    property color red: "#fb4934"
    property color peach: "#fe8019"
    property color yellow: "#fabd2f"
    property color green: "#b8bb26"

    // Same corner radius as windows (hypr decoration.rounding = radius_large).
    property real radiusLarge: 16

    readonly property var keys: [
        "crust", "mantle", "base", "surface0", "surface1", "surface2",
        "overlay0", "overlay1", "overlay2", "subtext0", "subtext1", "text",
        "accent", "red", "peach", "yellow", "green"
    ]

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/qs_colors.json"
        blockLoading: true
        printErrors: false

        onLoaded: {
            try {
                const c = JSON.parse(colorsFile.text());
                for (const k of root.keys)
                    if (typeof c[k] === "string")
                        root[k] = c[k];
                if (typeof c.radius_large === "number")
                    root.radiusLarge = c.radius_large;
            } catch (e) {
                console.warn("lock: ignoring unreadable qs_colors.json:", e);
            }
        }
    }
}
