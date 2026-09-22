import QtQuick
import QtQuick.Controls

// Small context menu for a song: play next / add to playlist / delete.
Popup {
    id: root
    property var song: ({})
    signal addRequested(var song)
    signal playNextRequested(var song)
    signal deleteRequested(var song)
    property bool canDelete: false

    padding: 6
    background: Rectangle {
        radius: 12
        color: Theme.surfaceHighest
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
    }

    Column {
        spacing: 2
        MenuRow { label: "Play next"; icon: "playlist_add"; onClicked: { root.playNextRequested(root.song); root.close(); } }
        MenuRow { label: "Add to playlist"; icon: "playlist_add"; onClicked: { root.addRequested(root.song); root.close(); } }
        MenuRow { label: "Delete"; icon: "delete"; danger: true; visible: root.canDelete; onClicked: { root.deleteRequested(root.song); root.close(); } }
    }

    component MenuRow: Rectangle {
        id: row
        property string label
        property string icon
        property bool danger: false
        signal clicked()
        width: 180; height: 34
        radius: 8
        color: h.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        HoverHandler { id: h }
        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontIcon
                font.pixelSize: 16
                color: row.danger ? Theme.error : Theme.onSurface
                text: row.icon
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: row.danger ? Theme.error : Theme.onSurface
                text: row.label
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: row.clicked() }
    }
}
