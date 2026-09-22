import QtQuick

// Album art with graceful fallback (mirrors web Cover component).
Item {
    id: root
    property string src: ""
    property string icon: "music_note"
    property int iconSize: 16
    property real radius: 8

    Image {
        id: img
        anchors.fill: parent
        source: root.src
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: status === Image.Ready
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.surfaceHighest
        visible: !img.visible
        Text {
            anchors.centerIn: parent
            font.family: Theme.fontIcon
            font.pixelSize: root.iconSize
            color: Theme.outline
            text: root.icon
        }
    }
}
