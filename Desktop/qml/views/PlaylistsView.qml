import QtQuick
import "../components"

// PlaylistsView — mirrors web PlaylistsView: h1 + create row + cards + empty state.
Rectangle {
    id: root
    property var playlists: []
    property bool loading: true
    property int page: 1
    signal playlistRequested(string playlistId)
    signal createRequested(string name)

    color: "transparent"; clip: true

    function load(reset) {
        if (reset) { root.playlists = []; root.page = 1; root.loading = true }
        Api.get("/playlists", { page: root.page, limit: 50 }, function (res) {
            root.loading = false
            if (!res || !res.ok) return
            var list = res.data.playlists || (Array.isArray(res.data) ? res.data : [])
            root.playlists = reset ? list : root.playlists.concat(list)
        })
    }
    Component.onCompleted: load(true)

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 28; anchors.rightMargin: 28
        contentHeight: col.height + 48; clip: true
        Column { id: col; width: parent.width; spacing: 16; topPadding: 24
            Text { font.family: Theme.fontMain; font.pixelSize: 32; font.weight: Font.Bold; color: Theme.onSurface; text: "Playlists" }
            Row { width: Math.min(parent.width, 480); spacing: 8
                Rectangle { width: parent.width - 118; height: 40; radius: 20; color: Theme.surfaceContainer
                    TextInput {
                        id: newInput
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.onSurface; font.family: Theme.fontMain; font.pixelSize: 13; clip: true
                        Keys.onReturnPressed: { if (text.length > 0) { root.createRequested(text); text = "" } }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 16; visible: newInput.text === ""; font.family: Theme.fontMain; font.pixelSize: 13; color: Theme.outline; text: "New playlist name…" }
                }
                Rectangle {
                    width: 110; height: 40; radius: 20; color: Theme.primaryContainer
                    Row { anchors.centerIn: parent; spacing: 4
                        Text { font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.onPrimaryContainer; text: "add" }
                        Text { font.family: Theme.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.onPrimaryContainer; text: "Create" }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (newInput.text.length > 0) { root.createRequested(newInput.text); newInput.text = "" } } }
                }
            }
            Grid { id: grid; width: parent.width; columns: Math.max(1, Math.floor(width / 320)); spacing: 12
                Repeater { model: root.playlists
                    Rectangle {
                        width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
                        height: 80; radius: 16
                        color: plHover.hovered ? Theme.surfaceHigh : Theme.surfaceLow
                        HoverHandler { id: plHover }
                        Row { anchors.fill: parent; anchors.margins: 16; spacing: 12
                            Rectangle { width: 48; height: 48; radius: 12; anchors.verticalCenter: parent.verticalCenter; color: Theme.surfaceHighest
                                Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 22; color: Theme.primary; text: "queue_music" }
                            }
                            Column { width: parent.width - 48 - 12; anchors.verticalCenter: parent.verticalCenter
                                Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.name || "Untitled" }
                                Text { width: parent.width; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: (modelData.song_count != null ? modelData.song_count : (modelData.songs ? modelData.songs.length : 0)) + " tracks" }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.playlistRequested(modelData.id) }
                    }
                }
            }
            Column {
                width: parent.width; topPadding: 32; spacing: 8
                visible: !root.loading && root.playlists.length === 0
                height: visible ? implicitHeight : 0
                Rectangle { width: 64; height: 64; radius: 16; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceContainer
                    Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 28; color: Theme.outline; text: "queue_music" }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.onSurface; text: "No playlists yet" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Create one above, or add songs via the ••• menu." }
            }
        }
    }
}
