import QtQuick
import "../components"

// VideosView — mirrors web VideosView: h1 + tiles with play overlay + duration.
Rectangle {
    id: root
    property var songs: []
    property bool loading: true
    property int page: 1
    signal videoRequested(string songId)

    color: "transparent"; clip: true

    function load(reset) {
        if (reset) { root.songs = []; root.page = 1; root.loading = true }
        Api.get("/songs/paginated", { page: root.page, limit: 100 }, function (res) {
            root.loading = false
            if (!res || !res.ok) return
            var all = (res.data.songs || []).filter(function (s) { return s.is_video || s.has_video || s.hasVideo })
            root.songs = reset ? all : root.songs.concat(all)
        })
    }
    Component.onCompleted: load(true)

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 28; anchors.rightMargin: 28
        contentHeight: col.height + 48; clip: true
        Column { id: col; width: parent.width; spacing: 16; topPadding: 24
            Text { font.family: Theme.fontMain; font.pixelSize: 32; font.weight: Font.Bold; color: Theme.onSurface; text: "Music Videos" }
            Column {
                width: parent.width; topPadding: 48; spacing: 8
                visible: !root.loading && root.songs.length === 0
                height: visible ? implicitHeight : 0
                Rectangle { width: 64; height: 64; radius: 16; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceContainer
                    Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 28; color: Theme.outline; text: "movie" }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.onSurface; text: "No videos in queue" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Videos appear here once your library includes tracks with video." }
            }
            Grid { id: grid; width: parent.width; columns: Math.max(1, Math.floor(width / 300)); spacing: 16
                Repeater { model: root.songs
                    Rectangle {
                        width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
                        height: width * 9 / 16 + 62
                        radius: 16; color: vHover.hovered ? Theme.surfaceHigh : Theme.surfaceLow
                        HoverHandler { id: vHover }
                        Column { anchors.fill: parent; spacing: 0
                            Rectangle {
                                width: parent.width; height: parent.height - 62
                                radius: 16; color: Theme.surfaceHighest; clip: true
                                Image { anchors.fill: parent; source: modelData.cover_art || modelData.coverArt || ""; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
                                Text { anchors.centerIn: parent; visible: !(modelData.cover_art || modelData.coverArt); font.family: Theme.fontIcon; font.pixelSize: 36; color: Theme.outline; text: "movie" }
                                Rectangle { width: 48; height: 48; radius: 24; anchors.centerIn: parent; color: Qt.rgba(0,0,0,0.6)
                                    Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 24; color: "white"; text: "play_arrow" }
                                }
                                Rectangle {
                                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                                    width: durText.implicitWidth + 12; height: 20; radius: 4; color: Qt.rgba(0,0,0,0.7)
                                    visible: modelData.duration > 0
                                    Text { id: durText; anchors.centerIn: parent; font.family: "monospace"; font.pixelSize: 11; color: "white"; text: Theme.fmtTime(modelData.duration) }
                                }
                            }
                            Column { anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 12; spacing: 1
                                Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.title || "" }
                                Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: modelData.artist || "" }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.videoRequested(modelData.id) }
                    }
                }
            }
        }
    }
}
