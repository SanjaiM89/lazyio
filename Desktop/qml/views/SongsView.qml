import QtQuick
import "../components"

// SongsView — mirrors web SongsView: LIBRARY eyebrow + Songs h1 + filter + TrackTable.
Rectangle {
    id: root
    property var songs: []
    property bool loading: true
    property int page: 1
    property int total: 0
    property string filter: ""
    property string currentSongId: ""
    signal playRequested(var song, var queue, int index)
    signal songMenuRequested(var song)

    color: "transparent"
    clip: true

    property var visibleSongs: {
        if (filter === "") return songs;
        var q = filter.toLowerCase();
        return songs.filter(function (s) {
            return (s.title || "").toLowerCase().indexOf(q) >= 0 || (s.artist || "").toLowerCase().indexOf(q) >= 0;
        });
    }

    function load(reset) {
        if (reset) { root.songs = []; root.page = 1; root.loading = true }
        Api.get("/songs/paginated", { page: root.page, limit: 50 }, function (res) {
            root.loading = false
            if (!res || !res.ok) return
            var d = res.data || {}
            var list = d.songs || []
            root.total = d.total || list.length
            root.songs = (reset ? list : root.songs.concat(list))
        })
    }

    Component.onCompleted: load(true)

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 28; anchors.rightMargin: 28
        contentHeight: col.height + 48; clip: true
        Column { id: col; width: parent.width; spacing: 16; topPadding: 24
            // hero
            Row { width: parent.width
                Column { width: parent.width - 120
                    Row { spacing: 6
                        Rectangle { width: 6; height: 6; radius: 3; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Text { font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.primary; text: "LIBRARY"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { font.family: Theme.fontMain; font.pixelSize: 32; font.weight: Font.Bold; color: Theme.onSurface; text: "Songs" }
                }
                Text { width: 120; horizontalAlignment: Text.AlignRight; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: root.songs.length + " tracks" }
            }
            // table card
            Rectangle {
                width: parent.width; radius: 16; color: Theme.surfaceLow
                height: filterBox.height + tableCol.height + 24
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
                    Column {
                        visible: root.loading; width: parent.width; spacing: 6
                        height: visible ? implicitHeight : 0
                        Repeater { model: 8
                            Rectangle { width: parent.width; height: 40; radius: 8; color: Theme.surfaceHighest
                                SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { from: 0.25; to: 0.75; duration: 650 } NumberAnimation { from: 0.75; to: 0.25; duration: 650 } }
                            }
                        }
                    }
                    Column { id: tableCol; width: parent.width; spacing: 0
                        Row { width: parent.width; height: 28; leftPadding: 12; spacing: 8
                            Text { width: 28; font.family: Theme.fontMain; font.pixelSize: 11; color: Theme.outline; text: "#" }
                            Text { width: parent.width - 28 - 130 - 70 - 40 - 32; font.family: Theme.fontMain; font.pixelSize: 11; color: Theme.outline; text: "TITLE" }
                            Text { width: 130; font.family: Theme.fontMain; font.pixelSize: 11; color: Theme.outline; text: "ARTIST" }
                            Text { width: 70; horizontalAlignment: Text.AlignRight; font.family: Theme.fontMain; font.pixelSize: 11; color: Theme.outline; text: "TIME" }
                            Text { width: 40; font.family: Theme.fontMain; font.pixelSize: 11; color: Theme.outline; text: "" }
                        }
                        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }
                        Repeater {
                            model: root.visibleSongs
                            TrackRow {
                                width: parent.width; song: modelData; number: index; active: modelData.id === root.currentSongId
                                onPlayRequested: function (s) { root.playRequested(s, root.visibleSongs, index) }
                                onMenuRequested: function (s) { root.songMenuRequested(s) }
                            }
                        }
                    }
                }
            }
            Rectangle {
                visible: root.total > root.songs.length
                width: visible ? 140 : 0; height: visible ? 36 : 0; radius: 18; anchors.horizontalCenter: parent.horizontalCenter
                color: moreHover.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.08)
                HoverHandler { id: moreHover }
                Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: root.loading ? "Loading…" : "Load more" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.page++; root.load(false) } }
            }
        }
    }
}
