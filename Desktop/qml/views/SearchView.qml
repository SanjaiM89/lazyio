import QtQuick
import "../components"
import "../js/fuzzy.js" as Fuzzy

// SearchView — mirrors web SearchView: Results h1 + counts + Artists/Albums/Songs sections.
Rectangle {
    id: root
    property string query: ""
    property var songs: []
    property var albums: []
    property var artists: []
    property bool loading: false
    property string currentSongId: ""
    signal playRequested(var song, var queue, int index)
    signal albumRequested(string albumId)
    signal artistRequested(string name)
    signal songMenuRequested(var song)

    color: "transparent"; clip: true

    Connections { target: root; function onQueryChanged() { searchTimer.restart() } }

    Timer { id: searchTimer; interval: 300; repeat: false; onTriggered: {
        if (root.query.length < 1) { root.songs = []; root.albums = []; root.artists = []; return }
        root.loading = true
        Api.get("/search", { q: root.query, song_limit: 30, album_limit: 8, artist_limit: 8 }, function (res) {
            root.loading = false
            if (!res || !res.ok) return
            root.songs = res.data.songs || []
            root.albums = res.data.albums || []
            root.artists = res.data.artists || []
        })
    }}

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 28; anchors.rightMargin: 28
        contentHeight: col.height + 48; clip: true
        Column { id: col; width: parent.width; spacing: 16; topPadding: 24
            Column { width: parent.width; spacing: 2
                Text { width: parent.width; wrapMode: Text.WordWrap; font.family: Theme.fontMain; font.pixelSize: 32; font.weight: Font.Bold; color: Theme.onSurface; text: "Results for \u201c" + root.query + "\u201d" }
                Text { visible: !root.loading && root.query !== ""; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline
                    text: "Found " + root.songs.length + " songs, " + root.albums.length + " albums, " + root.artists.length + " artists" }
            }
            Rectangle {
                width: visible ? 40 : 0; height: visible ? 40 : 0; radius: 20
                anchors.horizontalCenter: parent.horizontalCenter; color: "transparent"; visible: root.loading
                border.color: Qt.rgba(1,1,1,0.15); border.width: 4
                Rectangle { width: 12; height: 12; radius: 6; color: Theme.primary; anchors.horizontalCenter: parent.horizontalCenter; y: -6 }
                RotationAnimation on rotation { loops: Animation.Infinite; duration: 900; from: 0; to: 360 }
            }
            // artists
            Column {
                width: parent.width; spacing: 8
                visible: root.artists.length > 0
                height: visible ? implicitHeight : 0
                Text { font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "ARTISTS"; leftPadding: 4 }
                Grid { width: parent.width; columns: 4; spacing: 12
                    Repeater { model: root.artists.slice(0, 4)
                        Rectangle {
                            width: (parent.width - 36) / 4; height: width + 52
                            radius: 12; color: aHover.hovered ? Theme.surfaceHigh : Theme.surfaceLow
                            HoverHandler { id: aHover }
                            Column { anchors.fill: parent; anchors.margins: 12; spacing: 6
                                Rectangle { width: parent.width; height: parent.width; radius: parent.width / 2; color: Theme.surfaceHighest; clip: true
                                    Image { anchors.fill: parent; source: modelData.cover_art || ""; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
                                    Text { anchors.centerIn: parent; visible: !modelData.cover_art; font.family: Theme.fontIcon; font.pixelSize: 24; color: Theme.outline; text: "artist" }
            // idle hint
            Column {
                width: parent.width; topPadding: 32; spacing: 8
                visible: !root.loading && root.query === ""
                height: visible ? implicitHeight : 0
                Rectangle { width: 64; height: 64; radius: 16; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceContainer
                    Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 28; color: Theme.outline; text: "search" }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Search your library" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Type in the sidebar box above and press Enter." }
            }
        }
                                Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.name || "" }
                                Text { width: parent.width; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: (modelData.song_count || 0) + " songs" }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.artistRequested(modelData.name || modelData.key) }
                        }
                    }
                }
            }
            // albums
            Column {
                width: parent.width; spacing: 8
                visible: root.albums.length > 0
                height: visible ? implicitHeight : 0
                Text { font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "ALBUMS"; leftPadding: 4 }
                Grid { width: parent.width; columns: 4; spacing: 12
                    Repeater { model: root.albums.slice(0, 4)
                        Rectangle {
                            width: (parent.width - 36) / 4; height: width + 52
                            radius: 12; color: alHover.hovered ? Theme.surfaceHigh : Theme.surfaceLow
                            HoverHandler { id: alHover }
                            Column { anchors.fill: parent; anchors.margins: 12; spacing: 6
                                CoverImage { width: parent.width; height: parent.width; radius: 8; src: modelData.cover_art || modelData.coverArt || ""; icon: "album" }
                                Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.name || "" }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.albumRequested(modelData.id) }
                        }
                    }
                }
            }
            // songs
            Column {
                width: parent.width; spacing: 8
                visible: !root.loading && root.query !== ""
                height: visible ? implicitHeight : 0
                Text { font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "SONGS"; leftPadding: 4 }
                Rectangle {
                    width: parent.width; radius: 16; color: Theme.surfaceLow
                    height: songCol.height + 16
                    visible: root.songs.length > 0
                    Column { id: songCol; width: parent.width - 16; x: 8; y: 8; spacing: 0
                        Repeater { model: root.songs
                            TrackRow { width: parent.width; song: modelData; number: index; active: modelData.id === root.currentSongId
                                onPlayRequested: function (s) { root.playRequested(s, root.songs, index) }
                                onMenuRequested: function (s) { root.songMenuRequested(s) }
                            }
                        }
                    }
                }
                Column {
                    width: parent.width; topPadding: 32; spacing: 8
                    visible: root.songs.length === 0
                    height: visible ? implicitHeight : 0
                    Rectangle { width: 64; height: 64; radius: 16; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceContainer
                        Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 28; color: Theme.outline; text: "search" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.onSurface; text: "No results found" }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Nothing matched \"" + root.query + "\". Check spelling or try an artist name." }
                }
            }
        }
    }
}
