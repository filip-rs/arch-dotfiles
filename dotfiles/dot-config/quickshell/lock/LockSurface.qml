import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.UPower

// What one output shows while locked. Every output gets the full UI; the
// password text lives in the shared LockContext, so typing works on any screen.
Item {
    id: root

    required property LockContext context
    required property Theme theme

    // Layout unit: 1.0 at 1080 logical px tall.
    readonly property real u: Math.max(0.75, Math.min(height / 1080, 2.0))
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property string textFont: "Noto Sans"

    // Background look, tuned against a real hyprlock render of the same
    // wallpaper (blur_size 4, blur_passes 3 + its default brightness/vibrancy).
    // Without these, a plain blur comes out hazier and greyer than hyprlock.
    readonly property real bgDarken: 0.10      // 0 = full brightness, 0.1 = 10% darker
    readonly property real bgSaturation: 0.15  // MultiEffect saturation, -1..1

    function tint(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // ---- background ------------------------------------------------------

    Image {
        id: wallpaper
        anchors.fill: parent
        // Kept current by scripts/desktop/wallpaper_split.sh (hyprlock used it too).
        source: "file://" + Quickshell.env("HOME") + "/.config/scripts/desktop/WallpaperSplitter/center.png"
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Math.ceil(root.width / 2)  // blurred anyway; half-res loads faster
        asynchronous: true
        cache: false
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 48
        blur: 1.0
        saturation: root.bgSaturation
    }

    // Plain multiply-style darkening (black at bgDarken opacity), not a gradient.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.bgDarken
    }

    // Clicking anywhere puts the cursor back in the password field.
    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    // Everything above the background fades in instead of popping.
    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // ---- clock, field, status (centre) ---------------------------------

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -parent.height * 0.05

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.theme.text
                font.family: root.textFont
                font.weight: Font.Bold
                font.pixelSize: 128 * root.u
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                color: root.theme.text
                font.family: root.textFont
                font.pixelSize: 22 * root.u
            }

            Item { width: 1; height: 28 * root.u }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Welcome back, " + root.userName
                color: root.theme.text
                font.family: root.textFont
                font.pixelSize: 28 * root.u
            }

            Item { width: 1; height: 16 * root.u }

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 380 * root.u
                height: 56 * root.u
                radius: root.theme.radiusLarge * root.u
                color: "transparent"
                border.width: Math.max(1, 1.5 * root.u)
                // Everything on the lock uses the clock's colour; red only for a
                // failed attempt.
                border.color: root.context.passwordError !== "" ? root.theme.red : root.theme.text
                Behavior on border.color { ColorAnimation { duration: 150 } }

                transform: Translate { id: shakeShift }

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: shakeShift; property: "x"; to: -14 * root.u; duration: 45 }
                    NumberAnimation { target: shakeShift; property: "x"; to: 12 * root.u; duration: 70 }
                    NumberAnimation { target: shakeShift; property: "x"; to: -8 * root.u; duration: 60 }
                    NumberAnimation { target: shakeShift; property: "x"; to: 4 * root.u; duration: 50 }
                    NumberAnimation { target: shakeShift; property: "x"; to: 0; duration: 40 }
                }

                Connections {
                    target: root.context
                    function onFailSerialChanged() { shake.restart(); }
                }

                TextInput {
                    id: input
                    anchors {
                        left: parent.left
                        right: fpIcon.left
                        leftMargin: 26 * root.u
                        rightMargin: 12 * root.u
                        verticalCenter: parent.verticalCenter
                    }
                    focus: true
                    clip: true
                    echoMode: TextInput.Password
                    readOnly: root.context.checking || root.context.unlocking
                    // The text itself is invisible; the row of dots below draws it.
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    cursorDelegate: Item {}
                    font.pixelSize: 22 * root.u

                    onTextChanged: root.context.currentText = text
                    onAccepted: root.context.tryPassword()
                    Keys.onEscapePressed: root.context.currentText = ""

                    Connections {
                        target: root.context
                        function onCurrentTextChanged() {
                            if (input.text !== root.context.currentText)
                                input.text = root.context.currentText;
                        }
                    }

                    Component.onCompleted: forceActiveFocus()
                }

                // One dot per character, centred in the field. Each dot sits in a
                // slot whose width animates open, so the row grows outwards from
                // the middle as you type (and collapses back into it when cleared).
                Row {
                    id: dots
                    anchors.centerIn: parent

                    Repeater {
                        model: root.maxDots

                        Item {
                            id: slot
                            required property int index
                            readonly property bool shown: index < input.length
                            width: shown ? root.dotSize + root.dotGap : 0
                            height: root.dotSize
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.centerIn: parent
                                width: root.dotSize
                                height: width
                                radius: width / 2
                                color: root.theme.text
                                scale: slot.shown ? 1 : 0
                                opacity: slot.shown ? 1 : 0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: input.text === ""
                    text: root.context.checking ? "Checking…" : "Enter greatness..."
                    color: root.theme.text
                    font.family: root.textFont
                    font.italic: !root.context.checking
                    font.pixelSize: 18 * root.u
                }

                Text {
                    id: fpIcon
                    anchors { right: parent.right; rightMargin: 18 * root.u; verticalCenter: parent.verticalCenter }
                    text: root.context.fpState === "disabled" || root.context.fpState === "unavailable"
                          ? "\u{F0EB1}"   // md-fingerprint_off
                          : "\u{F0237}"   // md-fingerprint
                    color: root.fpColor
                    font.family: root.iconFont
                    font.pixelSize: 26 * root.u
                    Behavior on color { ColorAnimation { duration: 180 } }

                    // Breathe while the reader is still coming up.
                    SequentialAnimation on opacity {
                        running: root.context.fpState === "starting" || root.context.fpState === "waking"
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
            }

            Item { width: 1; height: 16 * root.u }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: field.width * 1.5
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.status.text
                color: root.status.color
                font.family: root.textFont
                font.pixelSize: 15 * root.u
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // ---- power (bottom centre) -------------------------------------------

        Row {
            id: powerRow
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 54 * root.u }
            spacing: 16 * root.u

            PowerButton {
                theme: root.theme; u: root.u; iconFont: root.iconFont; textFont: root.textFont
                glyph: "\u{F0904}"   // md-power_sleep
                label: "Suspend"
                command: ["systemctl", "suspend"]
                needsConfirm: false
            }
            PowerButton {
                theme: root.theme; u: root.u; iconFont: root.iconFont; textFont: root.textFont
                glyph: "\u{F0709}"   // md-restart
                label: "Reboot"
                command: ["systemctl", "reboot"]
            }
            PowerButton {
                theme: root.theme; u: root.u; iconFont: root.iconFont; textFont: root.textFont
                glyph: "\u{F0425}"   // md-power
                label: "Shut down"
                command: ["systemctl", "poweroff"]
            }
        }

        // ---- battery (bottom right, level on the same line as the power row) --

        BatteryIcon {
            visible: root.hasBattery
            anchors { right: parent.right; rightMargin: 44 * root.u; verticalCenter: powerRow.verticalCenter }
            theme: root.theme
            u: root.u
            level: root.batteryLevel
            charging: root.hasBattery && root.battery.state === UPowerDeviceState.Charging
        }
    }

    // ---- state -------------------------------------------------------------

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property string userName: {
        const name = Quickshell.env("USER") ?? "";
        return name.length > 0 ? name.charAt(0).toUpperCase() + name.slice(1) : "friend";
    }

    // The icon itself shows the state (crossed out when off, breathing while
    // the reader wakes); colour only flags a mismatch.
    readonly property color fpColor: root.context.fpState === "nomatch" ? root.theme.red : root.theme.text

    readonly property var status: {
        const c = root.context;
        const t = root.theme;
        // Same colour as the clock; red only for an actual failed attempt.
        if (c.checking)
            return { text: "Checking…", color: t.text };
        if (c.passwordError !== "")
            return { text: c.passwordError, color: t.red };
        switch (c.fpState) {
        case "nomatch":
            return { text: "Fingerprint not recognised · " + c.fpAttemptsLeft
                           + (c.fpAttemptsLeft === 1 ? " try left" : " tries left"), color: t.red };
        case "disabled":
            return { text: "Too many fingerprint attempts, use your password", color: t.text };
        case "unavailable":
            return { text: "Fingerprint unavailable, type your password", color: t.text };
        case "ready":
            return { text: c.fpHint, color: t.text };
        default:
            return { text: "Waking the fingerprint reader…", color: t.text };
        }
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.ready && battery.isLaptopBattery
    readonly property real batteryLevel: hasBattery ? battery.percentage : 0  // UPower gives 0..1

    // Password dots: one per character, as many as fit between the fingerprint
    // icon and the same margin mirrored on the left (the row is centred).
    readonly property real dotSize: 11 * u
    readonly property real dotGap: 8 * u
    readonly property real dotReserve: field.width - fpIcon.x + 6 * u
    readonly property int maxDots: Math.max(1, Math.floor((field.width - 2 * dotReserve) / (dotSize + dotGap)))
}
