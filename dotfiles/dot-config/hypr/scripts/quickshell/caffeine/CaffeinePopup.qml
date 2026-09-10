import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../"

// Idle-inhibition control panel, driving the `hyprcaffeine` CLI.
//
// Replaces the menu `hyprcaffeine menu` opens. That one launches a *second*
// quickshell process against /usr/share/hyprcaffeine/ui/shell.qml, whose
// palette is hardcoded and whose theme file is an Omarchy path that does not
// exist on this system -- so it lands off-theme no matter what theme_apply.sh
// is set to. This reads the same state and shells out to the same CLI, but
// through the panel machinery every other bar icon already uses.
//
// Three independent inhibitors, which is the thing the panel exists to make
// legible -- the CLI's own summary line does not:
//
//   Timer / Infinite   blocks suspend only; dim, DPMS and lock still happen
//   Keep Display On    blocks dim + DPMS + lock; survives a reboot
//   Block Lid          blocks lid-close suspend; survives a reboot
Item {
    id: window

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    function s(val) {
        return scaler.s(val);
    }

    focus: true

    function playSfx(filename) {
        try {
            // Same sound set the network and mullvad panels use, so a toggle
            // here sounds like a toggle there.
            let rawUrl = Qt.resolvedUrl("../network/sounds/" + filename).toString();
            let cleanPath = rawUrl;
            if (cleanPath.indexOf("file://") === 0) cleanPath = cleanPath.substring(7);
            let cmd = "pw-play '" + cleanPath + "' 2>/dev/null || paplay '" + cleanPath + "' 2>/dev/null";
            Quickshell.execDetached(["sh", "-c", cmd]);
        } catch(e) {}
    }

    // -------------------------------------------------------------------------
    // COLORS (Dynamic Matugen Palette)
    // -------------------------------------------------------------------------
    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color subtext1: _theme.subtext1
    readonly property color overlay0: _theme.overlay0
    readonly property color overlay1: _theme.overlay1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2

    readonly property color green: _theme.green
    readonly property color red: _theme.red
    readonly property color yellow: _theme.yellow
    readonly property color peach: _theme.peach
    readonly property color blue: _theme.blue
    readonly property color mauve: _theme.mauve
    readonly property color teal: _theme.teal
    readonly property color sapphire: _theme.sapphire

    // -------------------------------------------------------------------------
    // STATE
    // -------------------------------------------------------------------------
    // hyprcaffeine owns this file; it is the same one the waybar module reads
    // (see waybar/scripts/hyprcaffeine-status.sh). Reading it directly rather
    // than parsing `hyprcaffeine status` keeps the countdown local, so the
    // panel ticks once a second without spawning anything.
    readonly property string stateFile: Quickshell.env("HOME") + "/.cache/hyprcaffeine/state.json"

    property string status: "inactive"
    property int duration: 0        // seconds; 0 means infinite
    property int activatedAt: 0     // epoch seconds
    property bool monitorOn: false
    property bool lidOn: false

    // Wall clock, refreshed on the same 1s tick that drives the countdown.
    property int nowSec: Math.floor(Date.now() / 1000)

    // Set while a CLI call is in flight, so a button shows progress instead of
    // flapping back on the next poll.
    property bool busy: false

    property bool customOpen: false

    readonly property bool isActive: window.status === "active"
    readonly property bool isInfinite: window.isActive && window.duration === 0
    readonly property bool isTimer: window.isActive && window.duration !== 0

    // Anything at all holding the machine awake.
    readonly property bool anyHold: window.isActive || window.monitorOn || window.lidOn

    readonly property int remaining: {
        if (!window.isTimer || window.activatedAt === 0) return 0;
        let r = window.duration - (window.nowSec - window.activatedAt);
        return r > 0 ? r : 0;
    }

    readonly property color stateColor: {
        if (window.isInfinite && window.monitorOn && window.lidOn) return window.red;
        if (window.isInfinite) return window.peach;
        if (window.isTimer) return window.yellow;
        if (window.monitorOn && window.lidOn) return window.blue;
        if (window.monitorOn) return window.sapphire;
        if (window.lidOn) return window.mauve;
        return window.overlay1;
    }

    readonly property string stateLabel: {
        if (window.isInfinite) return "Awake";
        if (window.isTimer) return window.fmtClock(window.remaining);
        if (window.monitorOn || window.lidOn) return "Partly held";
        return "Idle";
    }

    // The detail line under the hero label: what is actually being blocked,
    // rather than a restatement of the label.
    readonly property string stateDetail: {
        if (window.isInfinite) return "Suspend blocked, no time limit";
        if (window.isTimer) return "Suspend blocked until the timer runs out";
        if (window.monitorOn || window.lidOn) return "Suspend is not blocked";
        return "Nothing is being held awake";
    }

    // "1h 05m" / "24m 09s" / "42s" -- seconds only once they are the headline,
    // so the big number does not churn through six digits for an hour.
    function fmtClock(sec) {
        if (sec <= 0) return "0s";
        let h = Math.floor(sec / 3600);
        let m = Math.floor((sec % 3600) / 60);
        let x = sec % 60;
        function pad(n) { return n < 10 ? "0" + n : "" + n; }
        if (h > 0) return h + "h " + pad(m) + "m";
        if (m > 0) return m + "m " + pad(x) + "s";
        return x + "s";
    }

    // -------------------------------------------------------------------------
    // CLI PLUMBING
    // -------------------------------------------------------------------------
    Process {
        id: statePoll
        command: ["cat", window.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                try {
                    let j = JSON.parse(txt);
                    window.status = j.status || "inactive";
                    window.duration = parseInt(j.duration) || 0;
                    // Written as a *string* of epoch seconds, and empty while
                    // inactive -- parseInt("") is NaN, hence the || 0.
                    window.activatedAt = parseInt(j.activated_at) || 0;
                    window.monitorOn = j.monitor === true;
                    window.lidOn = j.lid === true;
                    window.busy = false;
                } catch(e) {}
            }
        }
    }

    Process { id: actionRunner }

    function run(args, sfx) {
        window.busy = true;
        if (sfx) window.playSfx(sfx);
        actionRunner.command = args;
        actionRunner.running = true;
        settleTimer.restart();
        busyTimeout.restart();
    }

    // `hyprcaffeine on` writes state after it has taken the inhibitor, so give
    // it a beat before re-reading rather than waiting out the 1s cadence.
    Timer { id: settleTimer; interval: 350; onTriggered: window.refresh() }
    // Never leave a button stuck spinning if the CLI wedges.
    Timer { id: busyTimeout; interval: 8000; onTriggered: window.busy = false }

    function refresh() {
        if (!statePoll.running) statePoll.running = true;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            window.nowSec = Math.floor(Date.now() / 1000);
            window.refresh();
        }
    }

    // `on` replaces whatever suspend-blocker is already running, so these need
    // no "turn the old one off first" step.
    function startFor(arg) { window.run(["hyprcaffeine", "on", arg], "power_on.wav"); }

    // Plain `off` stops the suspend blocker and deliberately leaves display and
    // lid alone -- they are independent, and persist across reboots. Clearing
    // all three at once is what the Release everything row is for.
    function stopIdle()   { window.run(["hyprcaffeine", "off"], "power_off.wav"); }
    function releaseAll() { window.run(["hyprcaffeine", "off", "--all"], "power_off.wav"); }

    function toggleMonitor() { window.run(["hyprcaffeine", "monitor", "toggle"], "switch.wav"); }
    function toggleLid()     { window.run(["hyprcaffeine", "lid", "toggle"], "switch.wav"); }

    function submitCustom() {
        let v = customInput.text.trim();
        if (v === "") return;
        window.startFor(v);
        customInput.text = "";
        window.customOpen = false;
    }

    // Two rows here are conditional -- the custom-duration field, and the
    // release row that only exists while something is held -- and a bar-docked
    // panel keeps its top edge wherever the layout leaves it. Without this the
    // idle panel (the common case) opens with a dead strip along the bottom.
    //
    // Driven off the layout's own implicit height rather than a table of
    // constants, so adding a row later does not silently reintroduce the gap.
    // `h` in WindowRegistry.js (660) is this panel at its tallest: every hold
    // active with the custom field open, measured at 658. The guard is what
    // lets the panel load outside Main.qml too.
    readonly property int naturalHeight: content.implicitHeight + 2 * window.s(24)

    function syncHeight() {
        if (typeof masterWindow === "undefined") return;
        masterWindow.setContentHeight(window.naturalHeight);
    }

    onNaturalHeightChanged: window.syncHeight()

    Component.onCompleted: {
        refresh();
        syncHeight();
    }

    readonly property var presets: [
        { label: "15 min",  arg: "15m" },
        { label: "30 min",  arg: "30m" },
        { label: "1 hour",  arg: "1h"  },
        { label: "2 hours", arg: "2h"  }
    ]

    // -------------------------------------------------------------------------
    // UI
    // -------------------------------------------------------------------------
    // Same counter-rotating backdrop pair as the network and mullvad panels, on
    // the same 200s period so all three drift in step.
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 200000; loops: Animation.Infinite; running: true
    }

    Rectangle {
        anchors.fill: parent
        radius: window.s(20)
        color: window.base
        border.color: window.surface0
        border.width: 1
        clip: true

        // Tinted by the state colour, so the panel warms up as holds
        // accumulate and goes near-flat grey when nothing is held.
        Rectangle {
            width: parent.width * 0.8; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(150)
            y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(100)
            opacity: window.anyHold ? 0.08 : 0.02
            color: window.anyHold ? window.stateColor : window.surface2
            Behavior on color { ColorAnimation { duration: 1000 } }
            Behavior on opacity { NumberAnimation { duration: 1000 } }
            visible: opacity > 0.01
        }

        Rectangle {
            width: parent.width * 0.9; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-150)
            y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(-100)
            opacity: window.anyHold ? 0.06 : 0.01
            color: window.anyHold ? window.peach : window.surface1
            Behavior on color { ColorAnimation { duration: 1000 } }
            Behavior on opacity { NumberAnimation { duration: 1000 } }
            visible: opacity > 0.01
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: window.s(24)
            spacing: window.s(16)

            // ── HERO: what is held right now ──
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(140)
                radius: window.s(18)
                color: window.mantle

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(18)
                    spacing: window.s(4)

                    RowLayout {
                        spacing: window.s(12)

                        Text {
                            id: cupGlyph
                            text: window.isActive ? "󰅶" : "󰛊"
                            color: window.stateColor
                            font.pixelSize: window.s(26)
                            font.family: "JetBrainsMono NF"

                            // Breathes only while a timer is counting: an
                            // infinite hold has nothing to count toward.
                            SequentialAnimation on opacity {
                                running: window.isTimer
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.45; duration: 1400; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
                            }

                            // The animation stops wherever it happened to be,
                            // so the glyph has to be put back to full opacity
                            // explicitly when the timer ends.
                            Connections {
                                target: window
                                function onIsTimerChanged() {
                                    if (!window.isTimer) cupGlyph.opacity = 1.0;
                                }
                            }
                        }

                        Text {
                            text: window.stateLabel
                            color: window.stateColor
                            font.pixelSize: window.s(28)
                            font.family: "JetBrainsMono NF"
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            visible: window.isInfinite
                            text: "󰛤"
                            color: window.stateColor
                            font.pixelSize: window.s(22)
                            font.family: "JetBrainsMono NF"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: window.stateDetail
                        color: window.subtext0
                        font.pixelSize: window.s(13)
                        font.family: "JetBrainsMono NF"
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }

                    // One chip per active inhibitor. Absent rather than greyed
                    // out: the toggles below already say what is available.
                    Flow {
                        Layout.fillWidth: true
                        spacing: window.s(6)

                        Repeater {
                            model: {
                                let out = [];
                                if (window.isInfinite) out.push({ icon: "󰛤", label: "Infinite", c: window.peach });
                                if (window.isTimer) out.push({ icon: "󰔛", label: "Timer", c: window.yellow });
                                if (window.monitorOn) out.push({ icon: "󰍹", label: "Display", c: window.sapphire });
                                if (window.lidOn) out.push({ icon: "󰌢", label: "Lid", c: window.mauve });
                                return out;
                            }

                            Rectangle {
                                id: holdChip
                                required property var modelData

                                width: chipRow.width + window.s(16)
                                height: window.s(22)
                                radius: height / 2
                                color: window.surface0

                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: window.s(5)

                                    Text {
                                        text: holdChip.modelData.icon
                                        color: holdChip.modelData.c
                                        font.pixelSize: window.s(11)
                                        font.family: "JetBrainsMono NF"
                                    }

                                    Text {
                                        text: holdChip.modelData.label
                                        color: holdChip.modelData.c
                                        font.pixelSize: window.s(10)
                                        font.family: "JetBrainsMono NF"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── BLOCK SUSPEND ──
            Text {
                text: "BLOCK SUSPEND"
                color: window.overlay0
                font.pixelSize: window.s(11)
                font.family: "JetBrainsMono NF"
                font.bold: true
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: window.s(10)
                rowSpacing: window.s(10)

                Repeater {
                    model: window.presets

                    Rectangle {
                        id: presetBtn
                        required property var modelData

                        // A timer for exactly this preset is the running one.
                        readonly property bool current: window.isTimer
                                                        && window.duration === window.argSeconds(presetBtn.modelData.arg)

                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(48)
                        radius: window.s(14)
                        color: presetArea.containsMouse ? window.surface1 : window.mantle
                        border.width: presetBtn.current ? window.s(2) : 0
                        border.color: window.stateColor

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: presetBtn.modelData.label
                            color: presetBtn.current ? window.stateColor : window.text
                            font.pixelSize: window.s(14)
                            font.family: "JetBrainsMono NF"
                            font.bold: presetBtn.current
                        }

                        MouseArea {
                            id: presetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.startFor(presetBtn.modelData.arg)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(48)
                    radius: window.s(14)
                    color: infArea.containsMouse ? window.surface1 : window.mantle
                    border.width: window.isInfinite ? window.s(2) : 0
                    border.color: window.peach

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: window.s(7)

                        Text {
                            text: "󰛤"
                            color: window.isInfinite ? window.peach : window.text
                            font.pixelSize: window.s(15)
                            font.family: "JetBrainsMono NF"
                        }

                        Text {
                            text: "Infinite"
                            color: window.isInfinite ? window.peach : window.text
                            font.pixelSize: window.s(14)
                            font.family: "JetBrainsMono NF"
                            font.bold: window.isInfinite
                        }
                    }

                    MouseArea {
                        id: infArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.startFor("infinite")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(48)
                    radius: window.s(14)
                    color: customArea.containsMouse ? window.surface1 : window.mantle
                    border.width: window.customOpen ? window.s(2) : 0
                    border.color: window.blue

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Custom…"
                        color: window.customOpen ? window.blue : window.text
                        font.pixelSize: window.s(14)
                        font.family: "JetBrainsMono NF"
                    }

                    MouseArea {
                        id: customArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            window.customOpen = !window.customOpen;
                            if (window.customOpen) customInput.forceActiveFocus();
                        }
                    }
                }
            }

            // Revealed by Custom…, so the panel does not carry a text field it
            // almost never needs. Duration syntax is hyprcaffeine's own.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: window.s(44)
                visible: window.customOpen
                radius: window.s(12)
                color: window.mantle
                border.width: customInput.activeFocus ? window.s(2) : 0
                border.color: window.blue

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: window.s(14)
                    anchors.rightMargin: window.s(14)
                    spacing: window.s(10)

                    Text {
                        text: "󰔛"
                        color: window.overlay1
                        font.pixelSize: window.s(15)
                        font.family: "JetBrainsMono NF"
                    }

                    TextInput {
                        id: customInput
                        Layout.fillWidth: true
                        color: window.text
                        font.pixelSize: window.s(14)
                        font.family: "JetBrainsMono NF"
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        Keys.onReturnPressed: window.submitCustom()
                        Keys.onEnterPressed: window.submitCustom()

                        Keys.onEscapePressed: {
                            if (text !== "") text = "";
                            else { window.customOpen = false; window.focus = true; }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: customInput.text === ""
                            text: "45m, 2h, 1:30…"
                            color: window.overlay0
                            font: customInput.font
                        }
                    }
                }
            }

            // ── INDEPENDENT TOGGLES ──
            Text {
                text: "ALSO BLOCK"
                color: window.overlay0
                font.pixelSize: window.s(11)
                font.family: "JetBrainsMono NF"
                font.bold: true
            }

            // Deliberately separate from the presets above: these two are not
            // suspend blockers and are not cleared when a timer expires. They
            // also persist across reboots, which is worth stating on screen --
            // it is the surprising part of hyprcaffeine's model.
            Repeater {
                model: [
                    {
                        icon: "󰍹",
                        title: "Keep Display On",
                        sub: "Blocks dim, DPMS and lock",
                        key: "monitor"
                    },
                    {
                        icon: "󰌢",
                        title: "Block Lid",
                        sub: "Closing the lid will not suspend",
                        key: "lid"
                    }
                ]

                Rectangle {
                    id: toggleRow
                    required property var modelData

                    readonly property bool on: toggleRow.modelData.key === "monitor" ? window.monitorOn : window.lidOn
                    readonly property color tint: toggleRow.modelData.key === "monitor" ? window.sapphire : window.mauve

                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(56)
                    radius: window.s(14)
                    color: toggleArea.containsMouse ? window.surface1 : window.mantle

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: window.s(16)
                        anchors.rightMargin: window.s(16)
                        spacing: window.s(12)

                        Text {
                            text: toggleRow.modelData.icon
                            color: toggleRow.on ? toggleRow.tint : window.overlay1
                            font.pixelSize: window.s(18)
                            font.family: "JetBrainsMono NF"

                            Behavior on color { ColorAnimation { duration: 160 } }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: toggleRow.modelData.title
                                color: window.text
                                font.pixelSize: window.s(14)
                                font.family: "JetBrainsMono NF"
                                font.bold: toggleRow.on
                            }

                            Text {
                                Layout.fillWidth: true
                                text: toggleRow.modelData.sub
                                color: window.overlay1
                                font.pixelSize: window.s(11)
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: window.s(46)
                            Layout.preferredHeight: window.s(24)
                            radius: height / 2
                            color: toggleRow.on ? toggleRow.tint : window.surface2

                            Behavior on color { ColorAnimation { duration: 160 } }

                            Rectangle {
                                width: window.s(18)
                                height: window.s(18)
                                radius: width / 2
                                color: window.crust
                                anchors.verticalCenter: parent.verticalCenter
                                x: toggleRow.on ? parent.width - width - window.s(3) : window.s(3)

                                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    MouseArea {
                        id: toggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (toggleRow.modelData.key === "monitor") window.toggleMonitor();
                            else window.toggleLid();
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // ── RELEASE ──
            // Two separate exits, because `off` and `off --all` are genuinely
            // different: stopping a timer leaves display and lid held, and
            // those two survive a reboot. Collapsing them into one button is
            // how you end up with a laptop that quietly never sleeps again.
            RowLayout {
                Layout.fillWidth: true
                spacing: window.s(10)
                visible: window.anyHold

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(50)
                    visible: window.isActive
                    radius: window.s(14)
                    color: stopArea.containsMouse ? Qt.lighter(window.surface1, 1.15) : window.surface0
                    opacity: window.busy ? 0.55 : 1.0

                    Behavior on color { ColorAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Stop timer"
                        color: window.text
                        font.pixelSize: window.s(14)
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                    }

                    MouseArea {
                        id: stopArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.stopIdle()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(50)
                    radius: window.s(14)
                    color: allArea.containsMouse ? Qt.lighter(window.red, 1.12) : window.red
                    opacity: window.busy ? 0.55 : 1.0

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: window.s(8)

                        Text {
                            text: "󰤆"
                            color: window.crust
                            font.pixelSize: window.s(15)
                            font.family: "JetBrainsMono NF"
                        }

                        Text {
                            text: "Release everything"
                            color: window.crust
                            font.pixelSize: window.s(14)
                            font.family: "JetBrainsMono NF"
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: allArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.releaseAll()
                    }
                }
            }
        }
    }

    // hyprcaffeine's duration tokens, in seconds, so a preset button can tell
    // whether the running timer is its own. Mirrors preset_arg() in
    // /usr/share/hyprcaffeine/scripts/config.sh -- single unit, never a bare
    // number, which that CLI reads as minutes.
    function argSeconds(arg) {
        let m = /^([0-9]+)([hms])$/.exec(arg);
        if (!m) return -1;
        let n = parseInt(m[1]);
        if (m[2] === "h") return n * 3600;
        if (m[2] === "m") return n * 60;
        return n;
    }
}
