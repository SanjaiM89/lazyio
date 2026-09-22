import QtQuick
import "../components"

// Artist detail — songs grouped by artist (mirrors web ArtistDetail).
Rectangle {
    id: root
    property string name: ""
    property var artist: null
    property var songs: []
    property bool loading: true
    property string currentSongId: ""
    signal playRequested(var song, var queue, int index)
    signal songMenuRequested(var song)
    signal backRequested()

    color: "transparent"; clip: true

    Component.onCompleted: {
        Api.get("/artists/" + encodeURIComponent(name), {}, function (res) {
            root.loading = false
            if (!res || !res.ok) return
            root.artist = res.data
            root.songs = res.data.songs || []
        })
    }

    Flickable { anchors.fill: parent; anchors.margins: 24; contentHeight: col.height; clip: true
        Column { id: col; width: parent.width; spacing: 20
            Row { spacing: 8
                Text { font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.primary; text: "arrow_back"
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.backRequested() }
                }
                Text { font.family: Theme.fontMain; font.pixelSize: 13; color: Theme.primary; text: "Artists"; anchors.verticalCenter: parent.verticalCenter }
            }
            Row { width: parent.width; spacing: 24
                CoverImage { width: 220; height: 220; src: root.artist ? (root.artist.coverArt || "") : ""; radius: 16; icon: "person" }
                Column { anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Text { font.family: Theme.fontMain; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.onVariant; text: "Artist" }
                    Text { font.family: Theme.fontMain; font.pixelSize: 28; font.weight: Font.DemiBold; color: Theme.onSurface; text: root.name }
                    Text { font.family: "monospace"; font.pixelSize: 12; color: Theme.outline; text: root.songs.length + " tracks" }
                    Rectangle { width: 40; height: 40; radius: 20; color: Theme.primary
                        Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 22; color: Theme.onPrimary; text: "play_arrow" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.songs.length > 0) root.playRequested(root.songs[0], root.songs, 0) } }
                    }
                }
            }
            Column { width: parent.width; spacing: 6
                Repeater { model: root.songs
                    TrackRow { width: parent.width; song: modelData; number: index; active: modelData.id === root.currentSongId
                        onPlayRequested: function (s) { root.playRequested(s, root.songs, index) }
                        onMenuRequested: function (s) { root.songMenuRequested(s) }
                    }
                }
            }
        }
    }
}
