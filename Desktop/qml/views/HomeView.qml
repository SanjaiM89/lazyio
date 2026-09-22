import QtQuick
import "../components"

// HomeView — mirrors web HomeView (Views.jsx): hero gradient + Recently Played + AI playlist.
Rectangle {
    id: root
    property var homeData: null
    property bool loading: true
    property string currentSongId: ""
    property string filter: ""
    signal songRequested(string songId)
    signal playRequested(var song, var queue, int index)
    signal albumRequested(string albumId)
    signal refreshRequested()

    color: "transparent"
    clip: true

    property var recent: homeData ? (homeData.recently_played || homeData.recent || []) : []
    property var aiSongs: homeData ? ((homeData.ai_playlist && homeData.ai_playlist.songs) || homeData.ai_songs || []) : []
    property string aiName: (homeData && homeData.ai_playlist && homeData.ai_playlist.name) || "For You"
    property var filteredAi: {
        if (filter === "") return aiSongs;
        var q = filter.toLowerCase();
        return aiSongs.filter(function (s) {
            return (s.title || "").toLowerCase().indexOf(q) >= 0 || (s.artist || "").toLowerCase().indexOf(q) >= 0;
        });
    }

    // loading spinner (mirrors web border-spin)
    Rectangle {
        anchors.fill: parent; color: "transparent"
        visible: root.loading || !root.homeData
        Rectangle {
            width: 48; height: 48; radius: 24
            anchors.centerIn: parent
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 4
            Rectangle {
                width: 48; height: 12; color: "transparent"
                Rectangle { width: 12; height: 12; radius: 6; color: Theme.primary; anchors.horizontalCenter: parent.horizontalCenter }
            }
            RotationAnimation on rotation { loops: Animation.Infinite; duration: 900; from: 0; to: 360 }
        }
    }

    Flickable {
        anchors.fill: parent; contentHeight: col.height; clip: true
        visible: !root.loading && root.homeData
        Column { id: col; width: parent.width; spacing: 0
            // ---- hero ----
            Rectangle {
                width: parent.width; height: 190
                color: "#200b0e"
                Rectangle { anchors.fill: parent; color: "#3a0d12"; opacity: 0.55 }
                Rectangle {
                    width: 500; height: 220; radius: 110
                    x: parent.width * 0.25 - 250; y: -110
                    color: Theme.secondaryContainer; opacity: 0.4
                }
                Column {
                    anchors.fill: parent; anchors.leftMargin: 28; anchors.rightMargin: 28; anchors.topMargin: 24
                    spacing: 2
                    Row {
                        spacing: 6
                        Rectangle { width: 6; height: 6; radius: 3; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { from: 1; to: 0.3; duration: 800 } NumberAnimation { from: 0.3; to: 1; duration: 800 } }
                        }
                        Text { font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.primary; text: "LISTEN NOW"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        width: parent.width
                        Column {
                            width: parent.width - 140
                            Text { font.family: Theme.fontMain; font.pixelSize: 44; font.weight: Font.Bold; color: Theme.onSurface; text: "Welcome Back" }
                            Text { font.family: Theme.fontMain; font.pixelSize: 15; color: Theme.onVariant; text: "Your lossless library, freshly synced." }
                        }
                        Rectangle {
                            width: 120; height: 40; radius: 20
                            anchors.verticalCenter: parent.verticalCenter
                            color: refreshHover.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.08)
                            HoverHandler { id: refreshHover }
                            Row { anchors.centerIn: parent; spacing: 6
                                Text { font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.onSurface; text: "refresh" }
                                Text { font.family: Theme.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Refresh" }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.refreshRequested() }
                        }
                    }
                }
            }

            Column {
                width: parent.width - 56; x: 28
                spacing: 24
                topPadding: 16; bottomPadding: 24

                // ---- recently played ----
                Column {
                    width: parent.width; spacing: 8
                    visible: root.recent.length > 0
                    height: visible ? implicitHeight : 0
                    Text { font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "RECENTLY PLAYED"; leftPadding: 4 }
                    Grid {
                        width: parent.width; columns: 5; spacing: 12
                        Repeater { model: root.recent.slice(0, 5)
                            Rectangle {
                                width: (parent.width - 48) / 5; height: width + 52
                                radius: 12; color: cardHover.hovered ? Theme.surfaceHigh : Theme.surfaceContainer
                                HoverHandler { id: cardHover }
                                Column { anchors.fill: parent; anchors.margins: 12; spacing: 6
                                    CoverImage { width: parent.width; height: parent.width; radius: 8; src: modelData.cover_art || modelData.coverArt || ""; icon: "music_note" }
                                    Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.title || "" }
                                    Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: modelData.artist || "" }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.songRequested(modelData.id) }
                            }
                        }
                    }
                }

                // ---- AI playlist ----
                Column {
                    width: parent.width; spacing: 8
                    visible: root.aiSongs.length > 0
                    height: visible ? implicitHeight : 0
                    Row { width: parent.width
                        Text { width: parent.width - 110; leftPadding: 4; verticalAlignment: Text.AlignVCenter; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: root.aiName.toUpperCase() }
                        Rectangle { width: 102; height: 20; radius: 4; color: Theme.surfaceHighest
                            Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.primary; text: "AI GENERATED" }
                        }
                    }
                    Rectangle {
                        width: parent.width; radius: 16; color: Theme.surfaceLow
                        height: filterBox.height + aiList.height + 24
                        Column { anchors.fill: parent; anchors.margins: 8; spacing: 4
                            Rectangle { id: filterBox; width: parent.width; height: 36; radius: 10; color: Theme.surfaceContainer
                                Row { anchors.fill: parent; anchors.leftMargin: 12; spacing: 8
                                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 16; color: Theme.outline; text: "search" }
                                    TextInput {
                                        anchors.verticalCenter: parent.verticalCenter; width: parent.width - 32
                                        color: Theme.onSurface; font.family: Theme.fontMain; font.pixelSize: 13; clip: true
                                        onTextChanged: root.filter = text
                                    }
                                }
                            }
                            Column { id: aiList; width: parent.width; spacing: 0
                                Repeater { model: root.filteredAi
                                    TrackRow { width: parent.width; song: modelData; number: index; active: modelData.id === root.currentSongId
                                        onPlayRequested: function (s) { root.playRequested(s, root.filteredAi, index) }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- empty state ----
                Column {
                    width: parent.width; spacing: 8; topPadding: 48
                    visible: root.recent.length === 0 && root.aiSongs.length === 0
                    height: visible ? implicitHeight : 0
                    Rectangle { width: 64; height: 64; radius: 16; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceContainer
                        Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 28; color: Theme.outline; text: "graphic_eq" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Library is quiet" }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Upload music or scan your Telegram channel to get started." }
                }
            }
        }
    }
}
