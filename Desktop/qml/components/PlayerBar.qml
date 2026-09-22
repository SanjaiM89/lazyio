import QtQuick

// Bottom floating player — mirrors web PlayerBar.jsx 1:1.
// h-20 rounded-2xl surface-container-high/90, cover+LOSSLESS / transport+progress / extras+volume.
Rectangle {
    id: root
    property var currentSong: null
    property bool playing: false
    property real progress: 0
    property real duration: 0
    property real volume: 0.8
    property bool muted: false
    property bool showQueue: true
    property bool shuffle: false
    property string repeatMode: "none"
    property bool hasSong: root.currentSong !== null
    property bool loved: false
    signal playPause()
    signal next()
    signal prev()
    signal seek(real seconds)
    signal volumeSet(real value)
    signal toggleQueue()
    signal toggleLyrics()
    signal toggleShuffle()
    signal cycleRepeat()
    signal openFullPlayer()

    height: 80; radius: 16
    color: Qt.rgba(44/255, 41/255, 44/255, 0.9)
    border.color: Qt.rgba(1, 1, 1, 0.08)
    border.width: 1

    Row {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 16
        spacing: 16

        // ---- left: cover + info + favorite ----
        Row {
            width: Math.max(200, parent.width * 0.25) - 8
            height: parent.height
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
            CoverImage {
                width: 48; height: 48; radius: 12
                anchors.verticalCenter: parent.verticalCenter
                src: hasSong ? (root.currentSong.coverArt || root.currentSong.cover_art || "") : ""
                icon: "album"
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openFullPlayer() }
            }
            Column {
                width: parent.width - 48 - 8 - 28
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Row {
                    width: parent.width; spacing: 6
                    Text {
                        width: Math.min(implicitWidth, parent.width - (hasSong ? 66 : 0))
                        elide: Text.ElideRight
                        font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold
                        color: Theme.onSurface
                        text: hasSong ? (root.currentSong.title || "Unknown") : "Nothing playing"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openFullPlayer() }
                    }
                    Rectangle {
                        visible: hasSong
                        width: visible ? 58 : 0; height: 18; radius: 4
                        color: Theme.surfaceContainer
                        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                        Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.primary; text: "LOSSLESS" }
                    }
                }
                Text {
                    elide: Text.ElideRight; width: parent.width
                    font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant
                    text: hasSong ? (root.currentSong.artist || "Unknown Artist") : "Pick a track"
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontIcon; font.pixelSize: 20
                color: root.loved ? Theme.tertiary : Theme.outline
                text: "favorite"
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loved = !root.loved }
            }
        }

        // ---- center: transport + progress ----
        Column {
            width: parent.width - 2 * Math.max(200, parent.width * 0.25) - 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                TransportBtn { icon: "shuffle"; active: root.shuffle; size: 18; onClicked: root.toggleShuffle() }
                TransportBtn { icon: "skip_previous"; size: 22; filled: true; onClicked: root.prev() }
                Rectangle {
                    width: 36; height: 36; radius: 18; color: playHover.hovered ? Theme.primaryContainer : Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                    HoverHandler { id: playHover }
                    Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 22; color: Theme.onPrimary; text: root.playing ? "pause" : "play_arrow" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.playPause() }
                }
                TransportBtn { icon: "skip_next"; size: 22; filled: true; onClicked: root.next() }
                TransportBtn { icon: "repeat"; active: root.repeatMode !== "none"; size: 18; onClicked: root.cycleRepeat() }
            }
            Row {
                width: parent.width; spacing: 8
                Text {
                    width: 32; horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.fontMain; font.pixelSize: 10; color: Theme.outline
                    text: Theme.fmtTime(root.progress)
                }
                Item {
                    width: parent.width - 32 - 32 - 16; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.surfaceHighest }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.duration > 0 ? (root.progress / root.duration) * parent.width : 0
                        height: 4; radius: 2; color: barHover.hovered ? Theme.primaryContainer : Theme.primary
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: (root.duration > 0 ? (root.progress / root.duration) * parent.width : 0) - 5
                        width: 10; height: 10; radius: 5
                        color: Theme.onPrimary; border.color: Theme.primary; border.width: 2
                        visible: barHover.hovered
                    }
                    HoverHandler { id: barHover }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: function (mouse) { if (root.duration > 0) root.seek((mouse.x / width) * root.duration) }
                        onPositionChanged: function (mouse) { if (pressed && root.duration > 0) root.seek((mouse.x / width) * root.duration) }
                    }
                }
                Text {
                    width: 32
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.fontMain; font.pixelSize: 10; color: Theme.outline
                    text: Theme.fmtTime(root.duration)
                }
            }
        }

        // ---- right: extras + volume + queue ----
        Row {
            width: Math.max(200, parent.width * 0.25) - 8
            height: parent.height
            spacing: 12
            layoutDirection: Qt.RightToLeft
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontIcon; font.pixelSize: 20
                color: root.showQueue ? Theme.primary : Theme.outline
                text: "queue_music"
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleQueue() }
            }
            Item {
                width: 112; height: parent.height
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.outline
                        text: root.muted || root.volume === 0 ? "volume_off" : "volume_up"
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volumeSet(root.muted || root.volume > 0 ? 0 : 0.8) }
                    }
                    Item {
                        width: 80; height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.surfaceHighest }
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: (root.muted ? 0 : root.volume) * parent.width; height: 4; radius: 2; color: Theme.onVariant }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) { root.volumeSet(Math.max(0, Math.min(1, mouse.x / width))) }
                            onPositionChanged: function (mouse) { if (pressed) root.volumeSet(Math.max(0, Math.min(1, mouse.x / width))) }
                        }
                    }
                }
            }
            TransportBtn { icon: "picture_in_picture_alt"; size: 18; onClicked: root.openFullPlayer() }
            TransportBtn { icon: "lyrics"; size: 18; onClicked: root.toggleLyrics() }
        }
    }

    component TransportBtn: Text {
        property string icon: ""
        property bool active: false
        property bool filled: false
        property int size: 18
        signal clicked()
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.fontIcon; font.pixelSize: size
        color: active ? Theme.primary : (th.hovered ? Theme.onSurface : Theme.outline)
        text: icon
        HoverHandler { id: th }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: parent.clicked() }
    }
}
