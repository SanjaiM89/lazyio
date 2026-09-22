import QtQuick

// One tracklist row: index -> hover play, title, artist chip, time, menu.
Rectangle {
    id: root
    property var song: ({})
    property int number: 0
    property bool active: false
    signal playRequested(var song)
    signal menuRequested(var song)

    height: 46
    radius: 8
    color: active ? Qt.rgba(1, 1, 1, 0.07) : (root.isHovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

    property bool isHovered: hover.hovered
    HoverHandler { id: hover }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 8

        // # / play / equalizer
        Item {
            width: 28; height: parent.height
            Text {
                anchors.centerIn: parent
                visible: !root.active && !root.isHovered
                font.family: Theme.fontMain
                font.pixelSize: 12
                color: Theme.outline
                text: root.number + 1
            }
            Text {
                anchors.centerIn: parent
                visible: !root.active && root.isHovered
                font.family: Theme.fontIcon
                font.pixelSize: 18
                color: Theme.onSurface
                text: "play_arrow"
            }
            // animated equalizer for the playing row
            Row {
                anchors.centerIn: parent
                spacing: 2
                visible: root.active
                Repeater {
                    model: 3
                    Rectangle {
                        width: 3
                        color: Theme.primary
                        radius: 1
                        SequentialAnimation on height {
                            loops: Animation.Infinite
                            NumberAnimation { from: 4; to: 14; duration: 380 + index * 130 }
                            NumberAnimation { from: 14; to: 4; duration: 380 + index * 130 }
                        }
                    }
                }
            }
        }

        // title
        Text {
            width: parent.width - 28 - 130 - 70 - 40 - 32
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.family: Theme.fontMain
            font.pixelSize: 14
            font.weight: root.active ? Font.DemiBold : Font.Medium
            color: root.active ? Theme.primary : Theme.onSurface
            text: song.title || "Unknown"
        }
        // artist chip
        Rectangle {
            width: 130; height: 22
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: Theme.surfaceContainer
            Text {
                anchors.centerIn: parent
                width: parent.width - 12
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.family: "monospace"
                font.pixelSize: 11
                color: root.active ? Theme.primary : Theme.onVariant
                text: (song.artist || "—").slice(0, 16)
            }
        }
        // time
        Text {
            width: 70
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            font.family: "monospace"
            font.pixelSize: 12
            color: root.active ? Theme.primary : Theme.outline
            text: Theme.fmtTime(song.duration)
        }
        // menu
        Text {
            width: 40; height: parent.height
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            visible: root.active || root.isHovered
            font.family: Theme.fontIcon
            font.pixelSize: 18
            color: root.active ? Theme.primary : Theme.outline
            text: "more_horiz"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: function (e) { root.menuRequested(root.song); e.accepted = true; }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.playRequested(root.song)
    }
}
