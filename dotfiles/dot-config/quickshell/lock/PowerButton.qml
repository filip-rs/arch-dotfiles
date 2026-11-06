import QtQuick
import Quickshell

// Round icon button for the lockscreen's power row. Destructive actions arm on
// the first click (the pill widens to "Reboot?") and run on the second; they
// disarm by themselves after a few seconds.
Item {
    id: root

    required property Theme theme
    required property string glyph
    required property string label
    required property var command
    property bool needsConfirm: true
    property real u: 1
    property string iconFont: "Symbols Nerd Font"
    property string textFont: "Noto Sans"

    property bool armed: false

    function tint(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    implicitHeight: 54 * u
    implicitWidth: armed ? content.implicitWidth + 40 * u : implicitHeight
    width: implicitWidth
    height: implicitHeight
    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: root.theme.radiusLarge * root.u
        // Outline in the clock's colour like the password field; hover and
        // press only add a faint wash of the same colour. Red = armed.
        color: root.armed ? root.tint(root.theme.red, 0.9)
             : mouse.pressed ? root.tint(root.theme.text, 0.22)
             : mouse.containsMouse ? root.tint(root.theme.text, 0.12)
             : "transparent"
        border.width: Math.max(1, 1.5 * root.u)
        border.color: root.armed ? root.theme.red : root.theme.text
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
            font.pixelSize: 22 * root.u
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.armed
            text: root.label + "?"
            color: root.theme.crust
            font.family: root.textFont
            font.weight: Font.DemiBold
            font.pixelSize: 16 * root.u
        }
    }

    // Name under the button on hover.
    Text {
        anchors { top: parent.bottom; topMargin: 8 * root.u; horizontalCenter: parent.horizontalCenter }
        text: root.label
        opacity: mouse.containsMouse && !root.armed ? 1 : 0
        color: root.theme.text
        font.family: root.textFont
        font.pixelSize: 13 * root.u
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
