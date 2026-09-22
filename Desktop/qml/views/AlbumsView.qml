import QtQuick
import "../components"

// AlbumsGridView — mirrors web AlbumsGridView: BROWSE eyebrow + Albums h1 + rescan + grid.
Rectangle {
    id: root
    property var albums: []
    property bool loading: true
    property int page: 1
    property int pages: 1
    property bool rescanning: false
    signal albumRequested(string albumId)

    color: "transparent"; clip: true

    function load(reset) {
        if (reset) { root.albums = []; root.page = 1; root.loading = true }
        Api.get("/albums", { page: root.page, limit: 60 }, function (res) {
            root.loading = false
            if (!res || !res.ok) return
            var d = res.data || {}
            var list = d.albums || (Array.isArray(res.data) ? res.data : [])
            root.albums = reset ? list : root.albums.concat(list)
            root.page = d.page || root.page
            root.pages = d.pages || 1
        })
    }
    Component.onCompleted: load(true)

    function rescan() {
        root.rescanning = true
        Api.post("/telegram/scan", {}, {}, function () {
            var t = Qt.createQmlObject("import QtQuick; Timer { interval: 3000; running: true; repeat: true }", root, "rescan");
            var n = 0;
            t.triggered.connect(function () {
                n++;
                Api.get("/telegram/scan/status", {}, function (res) {
                    if ((res && res.ok && !res.data.running) || n > 200) {
                        t.stop(); t.destroy(); root.rescanning = false; root.load(true);
                    }
                });
            });
        })
    }

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 28; anchors.rightMargin: 28
        contentHeight: col.height + 48; clip: true
        Column { id: col; width: parent.width; spacing: 16; topPadding: 24
            Row { width: parent.width
                Column { width: parent.width - 170
                    Row { spacing: 6
                        Rectangle { width: 6; height: 6; radius: 3; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Text { font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.primary; text: "BROWSE"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { font.family: Theme.fontMain; font.pixelSize: 32; font.weight: Font.Bold; color: Theme.onSurface; text: "Albums" }
                }
                Rectangle {
                    width: 150; height: 36; radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: rescanHover.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.08)
                    opacity: root.rescanning ? 0.5 : 1
                    HoverHandler { id: rescanHover }
                    Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: root.rescanning ? "Scanning…" : "Rescan channel" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !root.rescanning; onClicked: root.rescan() }
                }
            }
            // spinner
            Rectangle {
                width: visible ? 40 : 0; height: visible ? 40 : 0; radius: 20
                anchors.horizontalCenter: parent.horizontalCenter; color: "transparent"; visible: root.loading
                border.color: Qt.rgba(1,1,1,0.15); border.width: 4
                Rectangle { width: 12; height: 12; radius: 6; color: Theme.primary; anchors.horizontalCenter: parent.horizontalCenter; y: -6 }
                RotationAnimation on rotation { loops: Animation.Infinite; duration: 900; from: 0; to: 360 }
            }
            // empty
            Column {
                width: parent.width; topPadding: 48; spacing: 8
                visible: !root.loading && root.albums.length === 0
                height: visible ? implicitHeight : 0
                Rectangle { width: 64; height: 64; radius: 16; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceContainer
                    Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 28; color: Theme.outline; text: "album" }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.onSurface; text: "No albums yet" }
                Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Add music to the source channel, then rescan." }
            }
            Grid { id: grid; width: parent.width; columns: Math.max(2, Math.floor(width / 220)); spacing: 16
                Repeater { model: root.albums
                    Rectangle {
                        width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
                        height: width + 56
                        radius: 16; color: albumHover.hovered ? Theme.surfaceHigh : Theme.surfaceLow
                        HoverHandler { id: albumHover }
                        Column { anchors.fill: parent; anchors.margins: 12; spacing: 6
                            CoverImage { width: parent.width; height: parent.width; radius: 12; src: modelData.cover_art || modelData.coverArt || ""; icon: "album" }
                            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.name || modelData.title || "" }
                            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: (modelData.song_count || modelData.songCount || 0) + " songs" }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.albumRequested(modelData.id) }
                    }
                }
            }
            Rectangle {
                visible: root.page < root.pages
                width: visible ? 140 : 0; height: visible ? 36 : 0; radius: 18; anchors.horizontalCenter: parent.horizontalCenter
                color: moreHover.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.08)
                HoverHandler { id: moreHover }
                Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Load more" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.page++; root.load(false) } }
            }
        }
    }
}
