import QtQuick

// Sidebar/album/playlist card with cover + two-line caption.
Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    property string art: ""
    property string icon: "album"
    property bool wide: false // true = list row, false = grid tile
    signal clicked()

    radius: 14
    color: Theme.surfaceLow
    border.color: Qt.rgba(1, 1, 1, 0.04)
    border.width: 1

    HoverHandler { id: hover }
    property bool isHovered: hover.hovered

    states: State {
        name: "hover"; when: root.isHovered
        PropertyChanges { target: root; color: Theme.surfaceHigh }
    }
    transitions: Transition { ColorAnimation { duration: 150 } }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        CoverImage {
            width: root.wide ? 48 : parent.width
            height: root.wide ? 48 : parent.width
            src: root.art
            icon: root.icon
            radius: 10
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            font.family: Theme.fontMain
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.onSurface
            text: root.title
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            font.family: Theme.fontMain
            font.pixelSize: 12
            color: Theme.onVariant
            text: root.subtitle
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
