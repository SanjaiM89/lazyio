import QtQuick

// Right panel — mirrors web QueueSidebar.jsx 1:1.
// w-80 surface-container-low/80, tabs Playing Next/Lyrics/Related + Now Playing + Next + Suggestions.
Rectangle {
    id: root
    property var queue: []
    property int currentIndex: -1
    property var currentSong: null
    property var suggestions: []
    property bool playing: false
    property real progress: 0
    property var lyrics: null
    property bool lyricsLoading: false
    property int currentTab: 0 // 0 queue, 1 lyrics, 2 related
    signal playRequested(int index)
    signal songRequested(string songId)
    signal seekRequested(real seconds)
    signal closeRequested()

    function showTab(i) { root.currentTab = i }

    width: Theme.queueWidth
    color: Qt.rgba(29/255, 27/255, 30/255, 0.8)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: 16
        anchors.bottomMargin: 112
        spacing: 0

        // ---- tabs + clear ----
        Item {
            width: parent.width; height: 36
            Row {
                id: tabsRow
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater { model: ["Playing Next", "Lyrics", "Related"]
                    Rectangle {
                        property bool active: index === root.currentTab
                        width: tabText.implicitWidth + 20; height: 28; radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: active ? Theme.surfaceHigh : (tabHover.hovered ? Qt.rgba(1,1,1,0.06) : "transparent")
                        HoverHandler { id: tabHover }
                        Text { id: tabText; anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: parent.active ? Theme.onSurface : Theme.outline; text: modelData.toUpperCase() }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = index }
                    }
                }
            }
            Rectangle {
                width: 28; height: 28; radius: 14
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                color: clearHover.hovered ? Qt.rgba(1,1,1,0.08) : "transparent"
                HoverHandler { id: clearHover }
                Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.outline; text: "clear_all" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closeRequested() }
            }
        }

        Item { width: 1; height: 12 }

        Flickable {
            id: outerFlick
            width: parent.width; height: parent.height - 48
            contentHeight: contentCol.height; clip: true
            Column { id: contentCol; width: parent.width; spacing: 16

                // ---- queue tab ----
                Column {
                    width: parent.width; spacing: 16
                    visible: root.currentTab === 0
                    height: visible ? implicitHeight : 0
                    Column { width: parent.width; spacing: 4
                        Text { font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "NOW PLAYING" }
                        Rectangle {
                            width: parent.width
                            height: visible ? 64 : 0
                            radius: 12; color: Theme.surfaceContainer
                            visible: root.currentSong !== null
                            Row { anchors.fill: parent; anchors.margins: 8; spacing: 8
                                CoverImage { width: 48; height: 48; radius: 8; anchors.verticalCenter: parent.verticalCenter; src: root.currentSong ? (root.currentSong.coverArt || root.currentSong.cover_art || "") : ""; icon: "album" }
                                Column { width: parent.width - 48 - 8 - 30; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Row { width: parent.width; spacing: 6
                                        Text { width: Math.min(implicitWidth, parent.width - 52); elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.primary; text: root.currentSong ? (root.currentSong.title || "Unknown") : "" }
                                        Rectangle { width: 44; height: 16; radius: 4; color: Theme.surfaceHighest
                                            Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 10; color: Theme.outline; text: "Hi-Res" }
                                        }
                                    }
                                    Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: root.currentSong ? (root.currentSong.artist || "Unknown Artist") : "" }
                                }
                                Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.primary; text: "equalizer" }
                            }
                        }
                        Text { font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Nothing playing yet."; visible: root.currentSong === null; leftPadding: 4; height: visible ? implicitHeight : 0 }
                    }

                    Column { width: parent.width; spacing: 4
                        Row { width: parent.width
                            Text { width: parent.width - 80; verticalAlignment: Text.AlignVCenter; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "NEXT IN QUEUE" }
                            Text { width: 80; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter; font.family: Theme.fontMain; font.pixelSize: 10; color: Theme.primary; text: "Shuffle All" }
                        }
                        Text { font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Queue is empty."; visible: root.queue.length === 0; leftPadding: 4; height: visible ? implicitHeight : 0 }
                        Repeater { model: root.queue.slice(0, 8)
                            Rectangle {
                                width: parent.width; height: 48; radius: 8
                                color: rowHover.hovered ? Theme.surfaceHigh : "transparent"
                                HoverHandler { id: rowHover }
                                Row { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                    Text {
                                        width: 16; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter
                                        font.family: rowHover.hovered ? Theme.fontIcon : Theme.fontMain
                                        font.pixelSize: rowHover.hovered ? 16 : 10
                                        color: rowHover.hovered ? Theme.onSurface : Theme.outline
                                        text: rowHover.hovered ? "play_arrow" : (index + 1)
                                    }
                                    CoverImage { width: 36; height: 36; radius: 6; anchors.verticalCenter: parent.verticalCenter; src: modelData.coverArt || modelData.cover_art || "" }
                                    Column { width: parent.width - 16 - 36 - 44 - 32; anchors.verticalCenter: parent.verticalCenter
                                        Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.title || "" }
                                        Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: modelData.artist || "" }
                                    }
                                    Text { width: 44; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; font.family: "monospace"; font.pixelSize: 11; color: Theme.outline; text: Theme.fmtTime(modelData.duration) }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.playRequested(index) }
                            }
                        }
                    }

                    Column {
                        width: parent.width; spacing: 4
                        visible: root.suggestions.length > 0
                        height: visible ? implicitHeight : 0
                        Row { width: parent.width
                            Text { width: parent.width - 24; verticalAlignment: Text.AlignVCenter; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "AUTOPLAY SUGGESTIONS" }
                            Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 16; color: Theme.outline; text: "all_inclusive" }
                        }
                        Repeater { model: root.suggestions.slice(0, 3)
                            Rectangle {
                                width: parent.width; height: 48; radius: 8
                                color: Qt.rgba(55/255, 52/255, 55/255, 0.2)
                                Row { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                    CoverImage { width: 36; height: 36; radius: 6; anchors.verticalCenter: parent.verticalCenter; src: modelData.cover_art || modelData.coverArt || ""; icon: "smart_toy" }
                                    Column { width: parent.width - 36 - 28 - 24; anchors.verticalCenter: parent.verticalCenter
                                        Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.title || "" }
                                        Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: modelData.artist || "" }
                                    }
                                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.outline; text: "add"
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.songRequested(modelData.id) }
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.songRequested(modelData.id) }
                            }
                        }
                    }
                }

                // ---- lyrics tab (fills the viewport so the whole panel is usable) ----
                LyricsPane {
                    width: parent.width
                    height: root.currentTab === 1 ? outerFlick.height : 0
                    visible: root.currentTab === 1
                    lyrics: root.lyrics; loading: root.lyricsLoading; playbackSeconds: root.progress
                    onSeekTo: function (t) { root.seekRequested(t) }
                }

                // ---- related tab ----
                Column {
                    width: parent.width; spacing: 4
                    visible: root.currentTab === 2
                    height: visible ? implicitHeight : 0
                    Text { font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "RELATED" }
                    Text { font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Play something to get recommendations."; visible: root.suggestions.length === 0 }
                    Repeater { model: root.suggestions
                        Rectangle {
                            width: parent.width; height: 48; radius: 8
                            color: relHover.hovered ? Theme.surfaceHigh : "transparent"
                            HoverHandler { id: relHover }
                            Row { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                CoverImage { width: 36; height: 36; radius: 6; anchors.verticalCenter: parent.verticalCenter; src: modelData.cover_art || modelData.coverArt || "" }
                                Column { width: parent.width - 52; anchors.verticalCenter: parent.verticalCenter
                                    Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.title || "" }
                                    Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: modelData.artist || "" }
                                }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.songRequested(modelData.id) }
                        }
                    }
                }
            }
        }
    }
}
