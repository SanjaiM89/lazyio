import QtQuick
import "../components"

// ArtistsView — mirrors web ArtistsView: h1 + filter + avatar grid.
Rectangle {
    id: root
    property var artists: []
    property bool loading: true
    property string filter: ""
    signal artistRequested(string name)

    color: "transparent"; clip: true

    property var visibleArtists: {
        if (filter === "") return artists;
        var q = filter.toLowerCase();
        return artists.filter(function (a) { return (a.name || "").toLowerCase().indexOf(q) >= 0; });
    }

    function load() {
        root.loading = true
        Api.get("/artists", { page: 1, limit: 100 }, function (res) {
            root.loading = false
            if (!res || !res.ok) return
            root.artists = res.data.artists || (Array.isArray(res.data) ? res.data : [])
        })
    }
    Component.onCompleted: load()

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 28; anchors.rightMargin: 28
        contentHeight: col.height + 48; clip: true
        Column { id: col; width: parent.width; spacing: 16; topPadding: 24
            Text { font.family: Theme.fontMain; font.pixelSize: 32; font.weight: Font.Bold; color: Theme.onSurface; text: "Artists" }
            Rectangle {
                width: 280; height: 36; radius: 18; color: Theme.surfaceContainer
                Row { anchors.fill: parent; anchors.leftMargin: 12; spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.outline; text: "search" }
                    TextInput {
                        id: filterBoxInput
                        anchors.verticalCenter: parent.verticalCenter; width: parent.width - 32
                        color: Theme.onSurface; font.family: Theme.fontMain; font.pixelSize: 12; clip: true
                        onTextChanged: root.filter = text
                    }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 38; visible: filterBoxInput.text === ""; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Filter artists…" }
            }
            Grid { id: grid; width: parent.width; columns: Math.max(2, Math.floor(width / 200)); spacing: 16
                Repeater { model: root.visibleArtists
                    Rectangle {
                        width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
                        height: 170
                        radius: 16; color: artHover.hovered ? Theme.surfaceHigh : Theme.surfaceLow
                        HoverHandler { id: artHover }
                        Column { anchors.fill: parent; anchors.margins: 16; spacing: 6
                            Rectangle {
                                width: 80; height: 80; radius: 40
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Theme.surfaceHighest
                                clip: true
                                Image {
                                    anchors.fill: parent; source: modelData.cover_art || modelData.coverArt || ""
                                    fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready
                                }
                                Text { anchors.centerIn: parent; visible: !(modelData.cover_art || modelData.coverArt); font.family: Theme.fontIcon; font.pixelSize: 28; color: Theme.outline; text: "artist" }
                            }
                            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.name || "" }
                            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: (modelData.song_count || modelData.songCount || 0) + " songs" }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.artistRequested(modelData.name) }
                    }
                }
            }
            Column {
                width: parent.width; topPadding: 48; spacing: 8
                visible: !root.loading && root.visibleArtists.length === 0
                height: visible ? implicitHeight : 0
                Rectangle { width: 64; height: 64; radius: 16; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceContainer
                    Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 28; color: Theme.outline; text: "artist" }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.onSurface; text: "No artists found" }
            }
        }
    }
}
