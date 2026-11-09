import QtQuick

// A plain battery: the body fills to the charge level, and a lightning bolt
// sits beside the tip while charging. Deliberately no numbers.
//
// The tip points left; the body is pinned to the right edge of this item, so
// the battery doesn't move when the bolt appears.
Item {
    id: root

    required property Theme theme
    property real u: 1
    property real level: 1          // 0..1
    property bool charging: false
    property string iconFont: "Symbols Nerd Font"

    readonly property real bodyW: 30 * u
    readonly property real bodyH: 15 * u
    // Same 1px line weight as the password field.
    readonly property real stroke: Math.max(1, Math.round(u))
    readonly property real inset: stroke + Math.max(1, 1.5 * u)  // outline + gap before the fill
    readonly property real boltGap: 5 * u

    implicitWidth: (charging ? bolt.implicitWidth + boltGap : 0) + nub.width + bodyW
    implicitHeight: bodyH

    // Same colour as the lock's clock; red only when nearly empty and not charging.
    readonly property color outline: theme.text
    readonly property color fillColor: !charging && level <= 0.15 ? theme.red : theme.text

    Rectangle {
        id: body
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: root.bodyW
        height: root.bodyH
        radius: 4 * root.u
        color: "transparent"
        border.width: root.stroke
        border.color: root.outline

        // The tip is on the left, so the fill grows from the right end
        // towards it (and drains back to the right as the charge drops).
        Rectangle {
            x: parent.width - root.inset - width
            y: root.inset
            height: parent.height - 2 * root.inset
            readonly property real maxWidth: parent.width - 2 * root.inset
            readonly property real clamped: Math.min(1, Math.max(0, root.level))
            width: clamped > 0 ? Math.max(2 * root.u, maxWidth * clamped) : 0
            radius: Math.max(1, body.radius - root.inset)
            color: root.fillColor
            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    Rectangle {
        id: nub
        anchors { right: body.left; leftMargin: 1.5 * root.u; verticalCenter: body.verticalCenter }
        width: 2.2 * root.u
        height: 6 * root.u
        radius: 1.2 * root.u
        color: root.outline
    }

    Text {
        id: bolt
        visible: root.charging
        anchors { right: nub.left; rightMargin: root.boltGap; verticalCenter: body.verticalCenter }
        text: "\u{F140B}"   // md-lightning_bolt
        color: root.theme.text
        font.family: root.iconFont
        font.pixelSize: root.bodyH * 1.15
    }
}
