import QtQuick
import QtQuick.Shapes

// A hand-drawn battery: the body fills to the charge level and a bolt appears
// while charging. Deliberately no numbers.
Item {
    id: root

    required property Theme theme
    property real u: 1
    property real level: 1          // 0..1
    property bool charging: false

    readonly property real bodyW: 36 * u
    readonly property real bodyH: 18 * u
    // The bolt path is drawn in a 10x14 box, scaled to stay inside the outline.
    readonly property real boltScale: bodyH * 0.68 / 14
    readonly property real stroke: Math.max(1, 1.6 * u)
    readonly property real inset: stroke + Math.max(1, 1.6 * u)  // outline + gap before the fill

    implicitWidth: bodyW + 1.5 * u + nub.width
    implicitHeight: bodyH

    // Same colour as the lock's clock; red only when nearly empty and not
    // charging. The bolt is what shows charging.
    readonly property color outline: theme.text
    readonly property color fillColor: !charging && level <= 0.15 ? theme.red : theme.text

    Rectangle {
        id: body
        width: root.bodyW
        height: root.bodyH
        radius: 5 * root.u
        color: "transparent"
        border.width: root.stroke
        border.color: root.outline

        Rectangle {
            x: root.inset
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
        width: 2.8 * root.u
        height: 7 * root.u
        radius: 1.2 * root.u
        color: root.outline
    }

    // The bolt gets a dark outline so it reads over both the fill and the
    // empty part of the body.
    Shape {
        visible: root.charging
        anchors.centerIn: body
        width: 10 * root.boltScale
        height: 14 * root.boltScale
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.theme.text
            strokeColor: root.theme.crust
            strokeWidth: 1.4 * root.u
            joinStyle: ShapePath.RoundJoin

            startX: 6 * root.boltScale; startY: 0
            PathLine { x: 0.5 * root.boltScale; y: 8 * root.boltScale }
            PathLine { x: 4.5 * root.boltScale; y: 8 * root.boltScale }
            PathLine { x: 3.5 * root.boltScale; y: 14 * root.boltScale }
            PathLine { x: 9.5 * root.boltScale; y: 5.5 * root.boltScale }
            PathLine { x: 5.5 * root.boltScale; y: 5.5 * root.boltScale }
            PathLine { x: 6 * root.boltScale; y: 0 }
        }
    }
}
