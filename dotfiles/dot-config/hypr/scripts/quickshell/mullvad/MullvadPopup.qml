import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../"

// Mullvad control panel.
//
// Replaces the Electron tray app (~1GB across seven processes) for the two
// things it was actually used for: toggling the tunnel and switching relay.
// `mullvad-daemon` does all the work, so nothing here needs the GUI running --
// this drives the `mullvad` CLI and reads `mullvad status -j`.
//
// The settings surface is deliberately absent: for account, DNS, split
// tunnelling and the like, `mullvad <subcommand>` is right there.
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

    // Tab jumps focus into the filter box -- the common path is "open panel,
    // type three letters of a city, hit enter".
    Shortcut {
        sequence: "Tab"
        onActivated: searchInput.forceActiveFocus()
    }

    function playSfx(filename) {
        try {
            // Reuses the network panel's sound set; these are the same
            // connect/disconnect gestures, so they should sound identical.
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

    // -------------------------------------------------------------------------
    // STATE
    // -------------------------------------------------------------------------
    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/quickshell/mullvad"

    // "connected" | "connecting" | "disconnected" | "disconnecting" | "error"
    property string tunnelState: "disconnected"
    property string relayHostname: ""
    property string exitCountry: ""
    property string exitCity: ""
    property string exitIpv4: ""
    property var features: []

    // Relay constraint currently pinned in the daemon, independent of whether
    // the tunnel is up -- this is what gets a checkmark in the list.
    property string selCountry: ""
    property string selCity: ""

    property var countries: []
    property string search: ""
    property string expanded: ""

    // Set while a CLI action is in flight so the button shows progress instead
    // of flapping on the next poll.
    property bool busy: false

    readonly property bool isUp: tunnelState === "connected"
    readonly property bool isTransitioning: tunnelState === "connecting" || tunnelState === "disconnecting" || busy

    readonly property color stateColor: {
        if (window.isTransitioning) return window.yellow;
        if (window.isUp) return window.green;
        if (window.tunnelState === "error") return window.red;
        return window.overlay1;
    }

    readonly property string stateLabel: {
        if (window.busy && window.tunnelState === "disconnected") return "Connecting";
        if (window.tunnelState === "connected") return "Connected";
        if (window.tunnelState === "connecting") return "Connecting";
        if (window.tunnelState === "disconnecting") return "Disconnecting";
        if (window.tunnelState === "error") return "Blocked";
        return "Disconnected";
    }

    // Plain files rather than QtCore.Settings: QSettings needs
    // organizationName/organizationDomain, which quickshell never sets, so it
    // fails to initialize and silently discards everything written to it.
    // (NetworkPopup.qml:40 has the same latent bug -- its cache never persists.)
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/qs_mullvad"
    readonly property string recentsPath: cacheDir + "/recents.json"
    readonly property string relaysPath: cacheDir + "/relays.json"

    // Last few "cc/city" picks, most recent first, so the usual two or three
    // relays stay one click away.
    property var recents: []

    function writeCache(path, contents) {
        // base64 via stdin: relay names and JSON quoting do not survive being
        // pasted into a shell command line.
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p '" + window.cacheDir + "' && printf %s '" +
            Qt.btoa(contents) + "' | base64 -d > '" + path + "'"]);
    }

    function pushRecent(cc, city) {
        let key = cc + "/" + (city || "");
        let out = [key];
        for (let i = 0; i < window.recents.length; i++) {
            if (window.recents[i] !== key) out.push(window.recents[i]);
        }
        window.recents = out.slice(0, 5);
        writeCache(window.recentsPath, JSON.stringify(window.recents));
    }

    Process {
        id: recentsLoader
        command: ["bash", "-c", "cat '" + window.recentsPath + "' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                try { window.recents = JSON.parse(txt); } catch(e) {}
            }
        }
    }

    // The relay tree changes rarely; painting the cached copy immediately
    // avoids an empty list for the ~200ms `mullvad relay list` takes.
    Process {
        id: relaysLoader
        command: ["bash", "-c", "cat '" + window.relaysPath + "' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "" || window.countries.length > 0) return;
                try { window.countries = JSON.parse(txt); } catch(e) {}
            }
        }
    }

    function countryName(cc) {
        for (let i = 0; i < window.countries.length; i++) {
            if (window.countries[i].code === cc) return window.countries[i].name;
        }
        return cc.toUpperCase();
    }

    function cityName(cc, code) {
        for (let i = 0; i < window.countries.length; i++) {
            if (window.countries[i].code !== cc) continue;
            let cs = window.countries[i].cities;
            for (let j = 0; j < cs.length; j++) {
                if (cs[j].code === code) return cs[j].name;
            }
        }
        return code.toUpperCase();
    }

    // -------------------------------------------------------------------------
    // CLI PLUMBING
    // -------------------------------------------------------------------------
    Process {
        id: statusPoll
        command: ["mullvad", "status", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                try {
                    let j = JSON.parse(txt);
                    window.tunnelState = j.state || "disconnected";
                    let loc = (j.details && j.details.location) ? j.details.location : null;
                    window.relayHostname = loc && loc.hostname ? loc.hostname : "";
                    window.exitCountry = loc && loc.country ? loc.country : "";
                    window.exitCity = loc && loc.city ? loc.city : "";
                    window.exitIpv4 = loc && loc.ipv4 ? loc.ipv4 : "";
                    window.features = (j.details && j.details.feature_indicators) ? j.details.feature_indicators : [];
                    // A settled state means whatever we kicked off has landed.
                    if (window.tunnelState === "connected" || window.tunnelState === "disconnected") {
                        window.busy = false;
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: constraintPoll
        // "Location:  country mx" or "Location:  city mx qro". Anything else
        // (custom lists, "any") leaves the selection unmarked, which is fine.
        command: ["bash", "-c", "mullvad relay get 2>/dev/null | sed -n 's/^[[:space:]]*Location:[[:space:]]*//p' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split(/\s+/);
                if (parts[0] === "country" && parts.length >= 2) {
                    window.selCountry = parts[1]; window.selCity = "";
                } else if (parts[0] === "city" && parts.length >= 3) {
                    window.selCountry = parts[1]; window.selCity = parts[2];
                } else {
                    window.selCountry = ""; window.selCity = "";
                }
            }
        }
    }

    Process {
        id: relayFetch
        command: [window.scriptsDir + "/relays.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                try {
                    let parsed = JSON.parse(txt);
                    if (parsed.length > 0) {
                        window.countries = parsed;
                        window.writeCache(window.relaysPath, txt);
                    }
                } catch(e) {}
            }
        }
    }

    Process { id: actionRunner }

    function runAction(args, sfx) {
        window.busy = true;
        if (sfx) window.playSfx(sfx);
        actionRunner.command = args;
        actionRunner.running = true;
        busyTimeout.restart();
        settleTimer.restart();
    }

    // The daemon needs a moment before `status` reflects the new state; poke it
    // shortly after the action rather than waiting for the 2s cadence.
    Timer { id: settleTimer; interval: 400; onTriggered: window.refresh() }
    // Never leave the button stuck spinning if the CLI wedges.
    Timer { id: busyTimeout; interval: 12000; onTriggered: window.busy = false }

    function refresh() {
        if (!statusPoll.running) statusPoll.running = true;
        if (!constraintPoll.running) constraintPoll.running = true;
    }

    Timer {
        interval: window.isTransitioning ? 600 : 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: window.refresh()
    }

    function toggleTunnel() {
        if (window.isUp) runAction(["mullvad", "disconnect"], "disconnect.wav");
        else runAction(["mullvad", "connect"], "connect.wav");
    }

    // Setting a location while connected needs an explicit reconnect; while
    // disconnected we connect straight into the new relay, which is what
    // clicking a city is asking for either way.
    function selectLocation(cc, city) {
        let loc = ["mullvad", "relay", "set", "location", cc];
        if (city) loc.push(city);
        window.selCountry = cc;
        window.selCity = city || "";
        pushRecent(cc, city);
        let follow = window.isUp ? "mullvad reconnect" : "mullvad connect";
        runAction(["bash", "-c", loc.join(" ") + " >/dev/null 2>&1 && " + follow + " >/dev/null 2>&1"], "connect.wav");
    }

    Component.onCompleted: {
        recentsLoader.running = true;
        relaysLoader.running = true;
        relayFetch.running = true;
        refresh();
        // Land in the filter box: the panel exists to be opened, typed at and
        // dismissed. Escape inside it clears, then hands focus back.
        searchInput.forceActiveFocus();
    }

    // -------------------------------------------------------------------------
    // FILTERING
    // -------------------------------------------------------------------------
    // A country matches on its own name/code, or if any of its cities match --
    // in which case it auto-expands so the matching city is visible.
    readonly property var filtered: {
        let q = window.search.trim().toLowerCase();
        if (q === "") return window.countries;
        let out = [];
        for (let i = 0; i < window.countries.length; i++) {
            let c = window.countries[i];
            let hit = c.name.toLowerCase().indexOf(q) !== -1 || c.code.indexOf(q) === 0;
            let cities = [];
            for (let j = 0; j < c.cities.length; j++) {
                let ct = c.cities[j];
                if (hit || ct.name.toLowerCase().indexOf(q) !== -1 || ct.code.indexOf(q) === 0) cities.push(ct);
            }
            if (hit || cities.length > 0) {
                out.push({ name: c.name, code: c.code, servers: c.servers, cities: cities });
            }
        }
        return out;
    }

    readonly property bool searching: window.search.trim() !== ""

    // -------------------------------------------------------------------------
    // UI
    // -------------------------------------------------------------------------
    // Same slow counter-rotating pair the network panel uses for its backdrop,
    // on the same 200s period so the two panels drift in step.
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

        // Backdrop blobs. They tint with the tunnel state, so the panel reads
        // green while protected and goes near-flat grey when it is not.
        Rectangle {
            width: parent.width * 0.8; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(150)
            y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(100)
            opacity: window.isUp ? 0.08 : 0.02
            color: window.isUp ? window.stateColor : window.surface2
            Behavior on color { ColorAnimation { duration: 1000 } }
            Behavior on opacity { NumberAnimation { duration: 1000 } }
            visible: opacity > 0.01
        }

        Rectangle {
            width: parent.width * 0.9; height: width; radius: width / 2
            x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-150)
            y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(-100)
            opacity: window.isUp ? 0.06 : 0.01
            color: window.isUp ? window.teal : window.surface1
            Behavior on color { ColorAnimation { duration: 1000 } }
            Behavior on opacity { NumberAnimation { duration: 1000 } }
            visible: opacity > 0.01
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: window.s(24)
            spacing: window.s(20)

            // ── LEFT: status + toggle + recents ──
            // Width is pinned on all three constraints: the hero's Text items
            // report their unelided width as an implicit minimum, which
            // otherwise widens this column until it shoves the browser off the
            // right edge of the panel.
            ColumnLayout {
                Layout.preferredWidth: window.s(300)
                Layout.minimumWidth: window.s(300)
                Layout.maximumWidth: window.s(300)
                Layout.fillHeight: true
                spacing: window.s(16)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(190)
                    radius: window.s(18)
                    color: window.mantle

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: window.s(18)
                        spacing: window.s(6)

                        RowLayout {
                            spacing: window.s(10)

                            Rectangle {
                                width: window.s(12); height: window.s(12)
                                radius: width / 2
                                color: window.stateColor

                                SequentialAnimation on opacity {
                                    running: window.isTransitioning
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                                }
                                onVisibleChanged: if (!window.isTransitioning) opacity = 1.0
                            }

                            Text {
                                text: window.stateLabel
                                color: window.stateColor
                                font.pixelSize: window.s(22)
                                font.family: "JetBrainsMono NF"
                                font.bold: true
                            }
                        }

                        Item { Layout.preferredHeight: window.s(4) }

                        Text {
                            Layout.fillWidth: true
                            text: window.isUp
                                  ? (window.exitCity !== "" ? window.exitCity + ", " + window.exitCountry : window.exitCountry)
                                  : "No tunnel"
                            color: window.text
                            font.pixelSize: window.s(17)
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.isUp ? window.relayHostname : "Traffic is not protected"
                            color: window.subtext0
                            font.pixelSize: window.s(13)
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: window.isUp && window.exitIpv4 !== ""
                            text: window.exitIpv4
                            color: window.overlay1
                            font.pixelSize: window.s(12)
                            font.family: "JetBrainsMono NF"
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillHeight: true }

                        Flow {
                            Layout.fillWidth: true
                            spacing: window.s(6)
                            visible: window.isUp && window.features.length > 0

                            Repeater {
                                model: window.features
                                Rectangle {
                                    // "QuantumResistance" -> "Quantum Resistance"
                                    readonly property string pretty: String(modelData).replace(/([a-z])([A-Z])/g, "$1 $2")
                                    width: featLabel.width + window.s(14)
                                    height: window.s(20)
                                    radius: height / 2
                                    color: window.surface0
                                    Text {
                                        id: featLabel
                                        anchors.centerIn: parent
                                        text: parent.pretty
                                        color: window.teal
                                        font.pixelSize: window.s(10)
                                        font.family: "JetBrainsMono NF"
                                    }
                                }
                            }
                        }
                    }
                }

                // Primary toggle.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(56)
                    radius: window.s(16)
                    color: toggleArea.containsMouse
                           ? Qt.lighter(window.isUp ? window.red : window.green, 1.12)
                           : (window.isUp ? window.red : window.green)
                    opacity: window.isTransitioning ? 0.55 : 1.0

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    Text {
                        anchors.centerIn: parent
                        text: window.isTransitioning ? "…" : (window.isUp ? "Disconnect" : "Connect")
                        color: window.crust
                        font.pixelSize: window.s(17)
                        font.family: "JetBrainsMono NF"
                        font.bold: true
                    }

                    MouseArea {
                        id: toggleArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.toggleTunnel()
                    }
                }

                Text {
                    text: "RECENT"
                    color: window.overlay0
                    font.pixelSize: window.s(11)
                    font.family: "JetBrainsMono NF"
                    font.bold: true
                    visible: window.recents.length > 0
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: window.s(6)

                    Repeater {
                        model: window.recents

                        Rectangle {
                            readonly property var parts: String(modelData).split("/")
                            readonly property string cc: parts[0]
                            readonly property string city: parts.length > 1 ? parts[1] : ""
                            readonly property bool active: window.selCountry === cc && window.selCity === city

                            Layout.fillWidth: true
                            Layout.preferredHeight: window.s(38)
                            radius: window.s(12)
                            color: recentArea.containsMouse ? window.surface1 : window.mantle
                            border.width: active ? window.s(2) : 0
                            border.color: window.stateColor

                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: window.s(14)
                                anchors.right: parent.right
                                anchors.rightMargin: window.s(14)
                                text: parent.city !== ""
                                      ? window.cityName(parent.cc, parent.city) + ", " + parent.cc.toUpperCase()
                                      : window.countryName(parent.cc)
                                color: window.text
                                font.pixelSize: window.s(13)
                                font.family: "JetBrainsMono NF"
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: recentArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.selectLocation(parent.cc, parent.city)
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ── RIGHT: location browser ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: window.s(12)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(42)
                    radius: window.s(12)
                    color: window.mantle
                    border.width: searchInput.activeFocus ? window.s(2) : 0
                    border.color: window.blue

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: window.s(14)
                        anchors.rightMargin: window.s(14)
                        spacing: window.s(10)

                        Text {
                            text: "󰍉"
                            color: window.overlay1
                            font.pixelSize: window.s(15)
                            font.family: "JetBrainsMono NF"
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: window.text
                            font.pixelSize: window.s(14)
                            font.family: "JetBrainsMono NF"
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            onTextChanged: window.search = text

                            Keys.onEscapePressed: {
                                if (text !== "") { text = ""; }
                                else window.focus = true;
                            }

                            // Enter takes the first city of the first match --
                            // "type ber, hit enter" lands in Berlin.
                            Keys.onReturnPressed: {
                                let f = window.filtered;
                                if (f.length === 0) return;
                                let c = f[0];
                                if (c.cities.length > 0) window.selectLocation(c.code, c.cities[0].code);
                                else window.selectLocation(c.code, "");
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: searchInput.text === ""
                                text: "Filter countries and cities…"
                                color: window.overlay0
                                font: searchInput.font
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: window.s(16)
                    color: window.mantle
                    clip: true

                    ListView {
                        id: countryList
                        anchors.fill: parent
                        anchors.margins: window.s(8)
                        clip: true
                        spacing: window.s(3)
                        model: window.filtered
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: window.s(5)
                        }

                        delegate: Column {
                            id: countryRow
                            required property var modelData

                            width: countryList.width
                            spacing: window.s(3)

                            // A filter hit expands everything, so the matching
                            // city is visible without a second click.
                            readonly property bool isOpen: window.expanded === countryRow.modelData.code || window.searching
                            readonly property bool countrySelected: window.selCountry === countryRow.modelData.code && window.selCity === ""

                            // Country row: click expands; the pin on the right
                            // selects the country as a whole (any city in it).
                            Rectangle {
                                width: parent.width
                                height: window.s(40)
                                radius: window.s(11)
                                color: countryArea.containsMouse ? window.surface1 : "transparent"

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: window.s(12)
                                    anchors.rightMargin: window.s(10)
                                    spacing: window.s(10)

                                    Text {
                                        text: countryRow.isOpen ? "󰅀" : "󰅂"
                                        color: window.overlay0
                                        font.pixelSize: window.s(12)
                                        font.family: "JetBrainsMono NF"
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: countryRow.modelData.name
                                        color: window.text
                                        font.pixelSize: window.s(14)
                                        font.family: "JetBrainsMono NF"
                                        font.bold: countryRow.countrySelected
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: countryRow.modelData.servers
                                        color: window.overlay0
                                        font.pixelSize: window.s(11)
                                        font.family: "JetBrainsMono NF"
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: window.s(26)
                                        Layout.preferredHeight: window.s(26)
                                        radius: window.s(9)
                                        color: pinArea.containsMouse ? window.surface2 : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: countryRow.countrySelected ? "󰸞" : "󰐕"
                                            color: countryRow.countrySelected ? window.stateColor : window.overlay0
                                            font.pixelSize: window.s(12)
                                            font.family: "JetBrainsMono NF"
                                        }

                                        MouseArea {
                                            id: pinArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: window.selectLocation(countryRow.modelData.code, "")
                                        }
                                    }
                                }

                                MouseArea {
                                    id: countryArea
                                    anchors.fill: parent
                                    anchors.rightMargin: window.s(40)
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.playSfx("switch.wav");
                                        window.expanded = (window.expanded === countryRow.modelData.code) ? "" : countryRow.modelData.code;
                                    }
                                }
                            }

                            Repeater {
                                model: countryRow.isOpen ? countryRow.modelData.cities : []

                                Rectangle {
                                    id: cityRow
                                    required property var modelData

                                    readonly property bool citySelected: window.selCountry === cityRow.modelData.countryCode
                                                                         && window.selCity === cityRow.modelData.code

                                    width: countryList.width
                                    height: window.s(34)
                                    radius: window.s(10)
                                    color: cityArea.containsMouse ? window.surface1 : "transparent"

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: window.s(38)
                                        anchors.rightMargin: window.s(16)
                                        spacing: window.s(8)

                                        Text {
                                            text: cityRow.citySelected ? "󰸞" : "󰆤"
                                            color: cityRow.citySelected ? window.stateColor : window.overlay0
                                            font.pixelSize: window.s(11)
                                            font.family: "JetBrainsMono NF"
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: cityRow.modelData.name
                                            color: cityRow.citySelected ? window.text : window.subtext1
                                            font.pixelSize: window.s(13)
                                            font.family: "JetBrainsMono NF"
                                            font.bold: cityRow.citySelected
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: cityRow.modelData.servers
                                            color: window.overlay0
                                            font.pixelSize: window.s(11)
                                            font.family: "JetBrainsMono NF"
                                        }
                                    }

                                    MouseArea {
                                        id: cityArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: window.selectLocation(cityRow.modelData.countryCode, cityRow.modelData.code)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
