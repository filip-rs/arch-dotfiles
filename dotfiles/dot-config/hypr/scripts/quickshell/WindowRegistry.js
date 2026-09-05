.pragma library

// Waybar sits at the BOTTOM of the screen (see waybar/config.jsonc), so panels
// that belong to a bar icon dock just above it rather than at the top, and are
// aligned horizontally with the icon that opened them.
//
// BAR_HEIGHT is waybar's layer-shell height in logical pixels; it is a fixed
// CSS size, so it is deliberately NOT run through s().
var BAR_HEIGHT = 53;
var BAR_GAP = 8;

function getScale(mw) {
    if (mw <= 0) return 1.0;
    let r = mw / 1920.0;

    if (r <= 1.0) {
        return Math.max(0.35, Math.pow(r, 0.85));
    } else {
        // SCALING UP:
        return Math.pow(r, 0.5);
    }
}

// Helper to easily round scaled values
function s(val, scale) {
    return Math.round(val * scale);
}

// Horizontal placement for bar-docked panels. `anchor` is passed in by
// qs_manager.sh: waybar icons send the side they live on, keybinds send
// "center".
function anchorX(anchor, mw, w, scale) {
    if (anchor === "left")  return s(12, scale);
    if (anchor === "right") return Math.max(s(12, scale), mw - w - s(20, scale));
    return Math.floor((mw - w) / 2);
}

function isDocked(name) {
    return !!DOCKED[name];
}

// Y coordinate that puts a panel of height `h` just above the bar. Widgets that
// resize themselves at runtime re-run this so they stay docked.
function dockedY(h, mh, scale) {
    return Math.max(s(8, scale), mh - h - BAR_HEIGHT - BAR_GAP);
}

// Panels docked to the bar. `anchor` here is the default used when the caller
// does not specify one.
var DOCKED = {
    "battery":  { w: 480,  h: 760, anchor: "right",  comp: "battery/BatteryPopup.qml" },
    "volume":   { w: 480,  h: 760, anchor: "right",  comp: "volume/VolumePopup.qml" },
    "network":  { w: 900,  h: 700, anchor: "right",  comp: "network/NetworkPopup.qml" },
    "mullvad":  { w: 860,  h: 700, anchor: "right",  comp: "mullvad/MullvadPopup.qml" },
    "calendar": { w: 1450, h: 750, anchor: "center", comp: "calendar/CalendarPopup.qml" },
    "music":    { w: 700,  h: 620, anchor: "left",   comp: "music/MusicPopup.qml" }
};

// Modal panels: centred on the screen, anchor ignored.
var CENTRED = {
    "monitors":  { w: 850,  h: 580, comp: "monitors/MonitorPopup.qml" },
    "focustime": { w: 900,  h: 720, comp: "focustime/FocusTimePopup.qml" },
    "guide":     { w: 1200, h: 750, comp: "guide/GuidePopup.qml" }
};

// Centralized registry for all widget dimensions and positional mathematics.
function getLayout(name, mx, my, mw, mh, anchor) {
    let scale = getScale(mw);
    let t = null;

    if (DOCKED[name]) {
        let d = DOCKED[name];
        let w = s(d.w, scale);
        let h = s(d.h, scale);
        // Sit above the bar; never push the top of the panel off-screen.
        let y = dockedY(h, mh, scale);
        t = {
            w: w,
            h: h,
            rx: anchorX(anchor || d.anchor, mw, w, scale),
            ry: y,
            comp: d.comp
        };
    } else if (CENTRED[name]) {
        let c = CENTRED[name];
        let w = s(c.w, scale);
        let h = s(c.h, scale);
        t = {
            w: w,
            h: h,
            rx: Math.floor((mw - w) / 2),
            ry: Math.floor((mh - h) / 2),
            comp: c.comp
        };
    } else if (name === "wallpaper") {
        // Full width, centred vertically.
        let h = s(650, scale);
        t = { w: mw, h: h, rx: 0, ry: Math.floor((mh - h) / 2), comp: "wallpaper/WallpaperPicker.qml" };
    } else if (name === "hidden") {
        t = { w: 1, h: 1, rx: -5000 - mx, ry: -5000 - my, comp: "" };
    }

    if (!t) return null;

    // Calculate final absolute coordinates based on active monitor offset
    t.x = mx + t.rx;
    t.y = my + t.ry;

    return t;
}
