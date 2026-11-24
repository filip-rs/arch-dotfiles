import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../WindowRegistry.js" as LayoutMath
import "search.js" as Search

// App launcher. Super + Space presses the quickshell:launcher global shortcut
// (hypr/lua/binds.lua), which goes straight to this running shell. Nothing is
// spawned on the keypress.
//
// It runs inside Main.qml's process, so opening it only maps a window that
// already exists, with the app list already indexed.
//
// Typing filters apps by name. The moment exactly one app is left it launches
// without waiting for Enter (search.js explains why that can't pick the wrong
// app). Keys typed after that are swallowed until you pause, so the rest of
// the word doesn't land in the window underneath.
//
//   Enter                 launch the selected app
//   Up/Down, Tab/S-Tab,
//   Ctrl+J/K, Ctrl+N/P    move the selection
//   Ctrl+U                clear the search
//   Esc, click outside    close
//
// Also reachable over IPC:
//   qs -p ~/.config/quickshell/Main.qml ipc call launcher toggle
PanelWindow {
    id: launcher

    // ---- settings -------------------------------------------------------
    property bool autoLaunch: true
    // Never listed. Steam registers its runtimes and Proton builds as apps.
    property var hiddenNames: [/^Steam Linux Runtime/, /^Proton (Experimental|Hotfix|[0-9])/]
    property int visibleRows: 8
    // wofi's font: GTK's default (Cantarell, which isn't installed, so
    // fontconfig gives Adwaita Sans).
    property string fontFamily: "Adwaita Sans"
    // Only for the search glyph. Adwaita Sans has its own private-use
    // glyphs, so icons must name a Nerd Font explicitly.
    property string iconFont: "Symbols Nerd Font"
    // Colour of the typed letters inside app names (they are also bold).
    property color matchColor: "#ffffff"
    property string colorsPath: Quickshell.env("HOME") + "/.config/quickshell/qs_colors.json"
    property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell"
    readonly property string usagePath: stateDir + "/launcher-usage.json"
    // How long a pause in typing ends the swallow period after an auto-launch.
    property int swallowMs: 250

    // Emitted on open, so Main.qml can close whatever panel it has up.
    signal opened()

    // ---- window ---------------------------------------------------------
    visible: false
    color: "transparent"
    screen: targetScreen
    property var targetScreen: null

    WlrLayershell.namespace: "qs-launcher" // hypr/lua/rules.lua turns Hyprland's layer animation off for it
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    // Full screen, so a click anywhere outside the card closes it.
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property real sc: LayoutMath.getScale(screen ? screen.width : 1920)
    function s(v) { return Math.round(v * sc); }
    readonly property int rowH: s(46)

    // ---- theme (qs_colors.json, written by matugen) ---------------------
    property color cBase: "#010d1a"
    property color cSurface: "#091e2e"
    property color cBorder: "#1a3a5c"
    property color cText: "#CBE0F0"
    property color cMuted: "#7d99ab"
    property color cAccent: "#65b2ff"
    property color cSelection: "#0f3f63"

    FileView {
        path: launcher.colorsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: launcher.applyColors(text())
    }

    function applyColors(txt) {
        let c;
        try { c = JSON.parse(txt); } catch (e) { console.warn("Launcher: bad qs_colors.json:", e); return; }
        if (c.base) cBase = c.base;
        if (c.surface0) cSurface = c.surface0;
        if (c.border || c.surface1) cBorder = c.border || c.surface1;
        if (c.text) cText = c.text;
        if (c.subtext1) cMuted = c.subtext1;
        if (c.accent || c.blue) cAccent = c.accent || c.blue;
        if (c.selection || c.surface1) cSelection = c.selection || c.surface1;
    }

    // ---- launch counts, for ranking -------------------------------------
    property var usage: ({})

    FileView {
        id: usageFile
        path: launcher.usagePath
        printErrors: false // missing until the first launch
        onLoaded: {
            try { launcher.usage = JSON.parse(text()) || {}; } catch (e) { launcher.usage = {}; }
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", launcher.stateDir])

    function recordLaunch(rec) {
        let u = launcher.usage || {};
        const old = u[rec.id] || { n: 0, t: 0 };
        u[rec.id] = { n: old.n + 1, t: Date.now() };
        launcher.usage = u;
        usageFile.setText(JSON.stringify(u));
    }

    // ---- app index ------------------------------------------------------
    property var index: []
    property bool indexDirty: true

    // Entries arrive one at a time at startup and again whenever a .desktop
    // file changes, so only mark the index stale and rebuild it when needed.
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            launcher.indexDirty = true;
            if (launcher.visible && !launcher.launching) reindexTimer.restart();
        }
    }
    Timer { id: reindexTimer; interval: 100; onTriggered: launcher.refilter() }
    // Build it once at startup, so the first Super + Space has nothing to do.
    Timer { interval: 3000; running: true; onTriggered: launcher.ensureIndex() }

    function ensureIndex() {
        if (!indexDirty) return;
        index = Search.buildIndex(DesktopEntries.applications.values, hiddenNames);
        indexDirty = false;
    }

    // ---- state ----------------------------------------------------------
    property string query: ""
    property var results: []
    property bool fallbackMode: false
    property int selected: 0
    // True between an auto-launch and the window closing: keys are swallowed.
    property bool launching: false

    function refilter() {
        ensureIndex();
        const r = Search.search(index, query, usage, Date.now());
        results = r.results;
        fallbackMode = r.fallback;
        selected = 0;
        list.positionViewAtBeginning();
    }

    function queryEdited(text) {
        const grew = text.length > query.length;
        query = text;
        refilter();
        // Only on typing forward: a deletion or a mid-word edit that happens
        // to leave one app shouldn't fire it.
        if (grew && autoLaunch && !fallbackMode && results.length === 1 && query.trim() !== "")
            launch(results[0], true);
    }

    function focusedScreen() {
        const mon = Hyprland.focusedMonitor;
        const screens = Quickshell.screens;
        if (mon) {
            for (let i = 0; i < screens.length; i++)
                if (screens[i].name === mon.name) return screens[i];
        }
        return screens.length > 0 ? screens[0] : null;
    }

    function open() {
        if (visible) return;
        targetScreen = focusedScreen();
        launching = false;
        query = "";
        input.text = "";
        refilter();
        hover.lastX = NaN;
        hover.lastY = NaN;
        visible = true;
        input.forceActiveFocus();
        openAnim.restart();
        opened();
    }

    function close() {
        swallowTimer.stop();
        swallowCap.stop();
        launchFade.stop();
        visible = false;
        launching = false;
        query = "";
        input.text = "";
    }

    function toggle() {
        if (visible) close(); else open();
    }

    function launch(rec, auto) {
        if (!rec || launching) return;
        const entry = rec.entry;
        const cmd = Search.shellCommand(entry);
        if (cmd !== "" && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) {
            // Through Hyprland rather than DesktopEntry.execute(): apps get
            // Hyprland's environment (this shell runs without
            // QT_QPA_PLATFORMTHEME, so Qt apps would lose qt6ct) and open on
            // the workspace they were launched from. The dispatch argument is
            // Lua because the Hyprland config is Lua.
            Hyprland.dispatch("hl.dsp.exec_cmd(" + Search.luaString(cmd) + ")");
        } else {
            entry.execute();
        }
        recordLaunch(rec);

        if (auto) {
            launching = true;
            selected = results.indexOf(rec);
            launchFade.restart();
            swallowTimer.restart();
            swallowCap.restart();
        } else {
            close();
        }
    }

    // Closes once typing pauses after an auto-launch, with a hard cap in case
    // a key is held down.
    Timer { id: swallowTimer; interval: launcher.swallowMs; onTriggered: launcher.close() }
    Timer { id: swallowCap; interval: 1500; onTriggered: launcher.close() }

    function move(d) {
        if (results.length === 0) return;
        selected = Math.max(0, Math.min(results.length - 1, selected + d));
        list.positionViewAtIndex(selected, ListView.Contain);
    }

    function handleKey(event) {
        if (launching) {
            if (event.key === Qt.Key_Escape) close();
            else swallowTimer.restart();
            event.accepted = true;
            return;
        }

        const k = event.key;
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (k === Qt.Key_Escape) {
            close();
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (results.length > 0) launch(results[selected], false);
        } else if (k === Qt.Key_Down || k === Qt.Key_Tab || (ctrl && (k === Qt.Key_J || k === Qt.Key_N))) {
            move(1);
        } else if (k === Qt.Key_Up || k === Qt.Key_Backtab || (ctrl && (k === Qt.Key_K || k === Qt.Key_P))) {
            move(-1);
        } else if (k === Qt.Key_PageDown) {
            move(visibleRows);
        } else if (k === Qt.Key_PageUp) {
            move(-visibleRows);
        } else if (ctrl && k === Qt.Key_U) {
            input.text = "";
        } else {
            return;
        }
        event.accepted = true;
    }

    // ---- UI -------------------------------------------------------------
    MouseArea {
        anchors.fill: parent
        onClicked: launcher.close()
    }

    Rectangle {
        id: card
        width: launcher.s(640)
        height: searchRow.height + 1 + listBox.height + launcher.s(16)
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) * 0.38)
        radius: launcher.s(18)
        color: launcher.cBase
        border.color: launcher.cBorder
        border.width: 1

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 110; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; from: 0.97; to: 1; duration: 140; easing.type: Easing.OutCubic }
        }
        NumberAnimation { id: launchFade; target: card; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InCubic }

        // Keep clicks on the card from reaching the close-on-click area.
        MouseArea { anchors.fill: parent }

        Item {
            id: searchRow
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: launcher.s(58)

            Text {
                id: glyph
                anchors { left: parent.left; leftMargin: launcher.s(22); verticalCenter: parent.verticalCenter }
                text: "\u{F0349}" // nf-md-magnify
                font.family: launcher.iconFont
                font.pixelSize: launcher.s(20)
                color: launcher.cAccent
            }

            TextInput {
                id: input
                anchors {
                    left: glyph.right; leftMargin: launcher.s(14)
                    right: countLabel.left; rightMargin: launcher.s(12)
                    verticalCenter: parent.verticalCenter
                }
                focus: true
                clip: true
                readOnly: launcher.launching
                selectByMouse: true
                font.family: launcher.fontFamily
                font.pixelSize: launcher.s(18)
                color: launcher.cText
                selectionColor: launcher.cSelection
                selectedTextColor: launcher.cText
                cursorDelegate: Rectangle {
                    width: launcher.s(2)
                    color: launcher.cAccent
                    visible: input.cursorVisible && !launcher.launching
                }
                onTextChanged: {
                    if (!launcher.launching && text !== launcher.query) launcher.queryEdited(text);
                }
                Keys.onPressed: (event) => launcher.handleKey(event)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Launch…"
                    font: input.font
                    color: launcher.cMuted
                }
            }

            Text {
                id: countLabel
                anchors { right: parent.right; rightMargin: launcher.s(22); verticalCenter: parent.verticalCenter }
                text: launcher.query.trim() === "" || launcher.results.length === 0 ? ""
                    : launcher.fallbackMode ? "by keyword" : String(launcher.results.length)
                font.family: launcher.fontFamily
                font.pixelSize: launcher.s(13)
                color: launcher.cMuted
            }
        }

        Rectangle {
            id: divider
            anchors { top: searchRow.bottom; left: parent.left; right: parent.right; leftMargin: launcher.s(14); rightMargin: launcher.s(14) }
            height: 1
            color: launcher.cBorder
        }

        Item {
            id: listBox
            anchors { top: divider.bottom; topMargin: launcher.s(8); left: parent.left; right: parent.right; leftMargin: launcher.s(8); rightMargin: launcher.s(8) }
            height: launcher.visibleRows * launcher.rowH

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                model: launcher.results
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: index === launcher.selected
                    width: list.width
                    height: launcher.rowH

                    Rectangle {
                        anchors.fill: parent
                        radius: launcher.s(10)
                        color: row.current ? launcher.cSelection : "transparent"
                    }

                    Item {
                        id: iconBox
                        anchors { left: parent.left; leftMargin: launcher.s(12); verticalCenter: parent.verticalCenter }
                        width: launcher.s(30)
                        height: width
                        readonly property string icon: row.modelData.icon

                        Image {
                            id: img
                            anchors.fill: parent
                            source: iconBox.icon === "" ? ""
                                  : iconBox.icon.startsWith("/") ? "file://" + iconBox.icon
                                  : Quickshell.iconPath(iconBox.icon, true)
                            sourceSize: Qt.size(launcher.s(60), launcher.s(60))
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            visible: status === Image.Ready
                        }

                        // No icon: first letter on a tile.
                        Rectangle {
                            anchors.fill: parent
                            visible: img.status !== Image.Ready
                            radius: launcher.s(8)
                            color: launcher.cSurface
                            Text {
                                anchors.centerIn: parent
                                text: row.modelData.name.charAt(0).toUpperCase()
                                font.family: launcher.fontFamily
                                font.pixelSize: launcher.s(16)
                                font.bold: true
                                color: launcher.cAccent
                            }
                        }
                    }

                    Text {
                        id: nameText
                        anchors { left: iconBox.right; leftMargin: launcher.s(14); verticalCenter: parent.verticalCenter }
                        width: Math.min(implicitWidth, row.width - x - launcher.s(16))
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        text: Search.highlight(row.modelData, launcher.query, String(launcher.matchColor))
                        font.family: launcher.fontFamily
                        font.pixelSize: launcher.s(16)
                        color: launcher.cText
                    }


                    MouseArea {
                        anchors.fill: parent
                        onClicked: launcher.launch(row.modelData, false)
                    }
                }
            }

            // Mouse selection follows real pointer movement only. When the list
            // changes under a pointer that's sitting still, Qt sends hover
            // events at the same spot, and those mustn't steal the selection
            // from the keyboard (Enter would launch the wrong app).
            HoverHandler {
                id: hover
                property real lastX: NaN
                property real lastY: NaN
                onPointChanged: {
                    // Window coordinates: item-local ones drift while the card
                    // scales in, which would look like movement.
                    const g = point.scenePosition;
                    if (Math.abs(g.x - lastX) < 1 && Math.abs(g.y - lastY) < 1) return;
                    const first = isNaN(lastX);
                    lastX = g.x;
                    lastY = g.y;
                    if (first || launcher.launching) return; // where the pointer already was on open
                    const p = point.position;
                    const i = list.indexAt(p.x + list.contentX, p.y + list.contentY);
                    if (i >= 0) launcher.selected = i;
                }
            }

            Text {
                anchors.centerIn: parent
                visible: launcher.results.length === 0
                text: "No matches"
                font.family: launcher.fontFamily
                font.pixelSize: launcher.s(15)
                color: launcher.cMuted
            }
        }
    }

    // ---- entry points ---------------------------------------------------
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Open the app launcher"
        onPressed: launcher.toggle()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle(); }
        function open(): void { launcher.open(); }
        function close(): void { launcher.close(); }
    }
}
