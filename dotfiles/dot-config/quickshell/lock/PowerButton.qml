import QtQuick
import Quickshell

// Bare icon button for the lockscreen's power row: no box at rest, a faint
// wash of the text colour on hover, the label underneath. Destructive actions
// arm on the first click (the button widens to a red "Reboot?") and run on the
// second; they disarm by themselves after a few seconds.
Item {
    id: root

    required property Theme theme
    required property string glyph
    required property string label
    required property var command
    property bool needsConfirm: true
    property real u: 1
    property string iconFont: "Symbols Nerd Font"
    property string textFont: "Adwaita Sans"

    property bool armed: false

    function tint(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    implicitHeight: 44 * u
    implicitWidth: armed ? content.implicitWidth + 32 * u : implicitHeight
    width: implicitWidth
    height: implicitHeight
    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(height / 2, root.theme.radiusLarge * root.u)
        color: root.armed ? root.theme.red
             : mouse.pressed ? root.tint(root.theme.text, 0.22)
             : mouse.containsMouse ? root.tint(root.theme.text, 0.12)
             : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8 * root.u

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: root.armed ? root.theme.crust : root.theme.text
            font.family: root.iconFont
            font.pixelSize: 21 * root.u
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.armed
            text: root.label + "?"
            color: root.theme.crust
            font.family: root.textFont
            font.weight: Font.DemiBold
            font.pixelSize: 15 * root.u
        }
    }

    // Name under the button on hover.
    Text {
        anchors { top: parent.bottom; topMargin: 4 * root.u; horizontalCenter: parent.horizontalCenter }
        text: root.label
        opacity: mouse.containsMouse && !root.armed ? 1 : 0
        color: root.theme.text
        font.family: root.textFont
        font.pixelSize: 12 * root.u
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.needsConfirm && !root.armed) {
                root.armed = true;
                disarm.restart();
                return;
            }
            root.armed = false;
            disarm.stop();
            Quickshell.execDetached(root.command);
        }
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: root.armed = false
    }
}
