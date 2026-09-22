import QtQuick

// Synced lyrics pane — mirrors web LyricsPane.jsx.
// Header (source + SYNCED badge), clickable synced lines, plain/instrumental states,
// and autoscroll that only moves when the active line leaves the viewport.
Item {
    id: root
    property var lyrics: null
    property bool loading: false
    property real playbackSeconds: 0
    signal seekTo(real seconds)

    clip: true

    property var lines: lyrics ? (lyrics.lines || []) : []
    property bool synced: lines.length > 0
    property string plain: lyrics ? (lyrics.plain || "") : ""
    property bool instrumental: lyrics ? !!lyrics.instrumental : false
    property string source: lyrics ? (lyrics.source || "") : ""

    function activeIndex() {
        var ls = lines;
        var found = -1;
        for (var i = 0; i < ls.length; i++) {
            if ((ls[i].time || 0) <= root.playbackSeconds + 0.2) found = i;
            else break;
        }
        return found;
    }

    Column {
        anchors.fill: parent
        spacing: 4

        // header
        Row {
            width: parent.width; height: 28
            spacing: 6
            Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 16; color: Theme.primary; text: "lyrics" }
            Text {
                width: parent.width - 22 - (root.synced ? 70 : 0) - 12
                anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline
                text: root.source === "lrclib" ? "LYRICS · LRCLIB" : "LYRICS"
            }
            Rectangle {
                visible: root.synced
                width: 64; height: 18; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(224/255, 131/255, 110/255, 0.2)
                Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.primary; text: "SYNCED" }
            }
        }

        // loading shimmer
        Column {
            width: parent.width; spacing: 10
            visible: root.loading
            height: visible ? implicitHeight : 0
            topPadding: 8
            Repeater { model: [0.9, 0.7, 0.8, 0.55, 0.75]
                Rectangle {
                    width: parent.width * modelData; height: 12; radius: 6
                    color: Theme.surfaceHighest
                    SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { from: 0.3; to: 0.8; duration: 700 } NumberAnimation { from: 0.8; to: 0.3; duration: 700 } }
                }
            }
        }

        // body scroll
        Flickable {
            id: flick
            width: parent.width; height: Math.max(0, parent.height - 32)
            contentHeight: col.height
            visible: !root.loading
            clip: true

            Column {
                id: col; width: parent.width; spacing: 2
                topPadding: 8; bottomPadding: 120

                // no lyrics
                Column {
                    width: parent.width; spacing: 8; topPadding: 32
                    visible: !root.synced && root.plain === "" && !root.instrumental
                    height: visible ? implicitHeight : 0
                    Rectangle { width: 48; height: 48; radius: 14; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceContainer
                        Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 22; color: Theme.outline; text: "search_off" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: "No lyrics found" }
                }

                // instrumental
                Column {
                    width: parent.width; spacing: 8; topPadding: 32
                    visible: root.instrumental
                    height: visible ? implicitHeight : 0
                    Rectangle { width: 48; height: 48; radius: 14; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceContainer
                        Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 22; color: Theme.outline; text: "graphic_eq" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Instrumental track" }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "This song has no lyrics — enjoy the music." }
                }

                // synced lines (tap a line to jump to it)
                Repeater {
                    id: lrcRepeater
                    model: root.lines
                    Rectangle {
                        property real lineTime: modelData.time !== undefined ? modelData.time : 0
                        property bool isActive: index === root.activeIndex()
                        width: col.width; height: lineText.height + 12; radius: 8
                        color: isActive ? Qt.rgba(224/255, 131/255, 110/255, 0.12) : (lineHover.hovered ? Theme.surfaceHigh : "transparent")
                        HoverHandler { id: lineHover }
                        Text {
                            id: lineText
                            x: 8; y: 6; width: parent.width - 16
                            wrapMode: Text.WordWrap
                            font.family: Theme.fontMain; font.pixelSize: isActive ? 15 : 13; font.weight: isActive ? Font.DemiBold : Font.Normal
                            color: isActive ? Theme.primary : Theme.onVariant
                            text: modelData.text || ""
                            Behavior on font.pixelSize { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.seekTo(lineTime) }
                    }
                }

                // plain (unsynced) lyrics
                Text {
                    width: parent.width; leftPadding: 8; rightPadding: 8
                    wrapMode: Text.WordWrap
                    visible: !root.synced && root.plain !== ""
                    height: visible ? implicitHeight : 0
                    font.family: Theme.fontMain; font.pixelSize: 13
                    color: Theme.onVariant
                    text: root.plain
                }
            }
        }
    }

    // follow the active line only when it leaves the viewport (never fights the user)
    Connections {
        target: root
        function onPlaybackSecondsChanged() {
            var i = root.activeIndex();
            if (i < 0) return;
            var it = lrcRepeater.itemAt(i);
            if (!it) return;
            var top = it.y;
            var bottom = it.y + it.height;
            if (top < flick.contentY + 20 || bottom > flick.contentY + flick.height - 20) {
                flick.contentY = Math.max(0, top - flick.height / 2 + it.height / 2);
            }
        }
    }
}
