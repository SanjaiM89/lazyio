import QtQuick
import QtQuick.Controls
import "../js/fuzzy.js" as Fuzzy

// Left navigation rail — mirrors web Sidebar.jsx 1:1.
// fixed w-64, surface-container-low/80, logo + search + Discover/Library/Playlists + user footer.
Rectangle {
    id: root
    property string currentView: "home"
    property string searchQuery: ""
    signal navigate(string view)
    signal songRequested(string songId)
    signal albumRequested(string albumId)
    signal artistRequested(string artistName)
    signal createPlaylistRequested()
    signal settingsRequested()
    property var playlists: []

    width: Theme.sideWidth
    color: Qt.rgba(29/255, 27/255, 30/255, 0.8)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 0

        // ---- logo ----
        Item {
            width: parent.width; height: 36
            Rectangle {
                x: 4; y: 2; width: 32; height: 32; radius: 8; color: Theme.primary
                Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 20; color: Theme.onPrimary; text: "graphic_eq" }
            }
            Column {
                x: 44; anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text { font.family: Theme.fontMain; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Lazyio" }
                Text { font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.primary; text: "LOSSLESS AUDIO" }
            }
        }

        Item { width: 1; height: 16 }

        // ---- search (icon + field + placeholder, no overlaps; Enter jumps to Search) ----
        Rectangle {
            width: parent.width - 8; height: 32; x: 4; radius: 16
            color: Qt.rgba(55/255, 52/255, 55/255, 0.5)
            border.color: searchInput.activeFocus ? Qt.rgba(1, 1, 1, 0.15) : "transparent"; border.width: 1
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchInput.forceActiveFocus() }
            Text {
                x: 12; anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.outline; text: "search"
            }
            TextInput {
                id: searchInput
                x: 36; width: parent.width - 48
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.onSurface; font.family: Theme.fontMain; font.pixelSize: 12; clip: true
                onTextChanged: root.searchQuery = text
                onAccepted: { root.navigate("search"); focus = false }
                Keys.onEscapePressed: { text = ""; focus = false }
            }
            Text {
                x: 36; anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text === ""
                font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline
                text: "Search Library & Music"
            }
        }

        Item { width: 1; height: 16 }

        // ---- scrollable nav ----
        Flickable {
            width: parent.width; height: parent.height - 36 - 16 - 32 - 16 - 70
            contentHeight: navCol.height; clip: true
            Column { id: navCol; width: parent.width; spacing: 16
                Column { width: parent.width; spacing: 2
                    Text { width: parent.width; leftPadding: 8; bottomPadding: 2; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "DISCOVER" }
                    NavRow { icon: "home"; label: "Home"; active: root.currentView === "home"; onClicked: root.navigate("home") }
                    NavRow { icon: "explore"; label: "New & Explore"; active: root.currentView === "albums"; onClicked: root.navigate("albums") }
                    NavRow { icon: "radio"; label: "Music Videos"; active: root.currentView === "videos"; onClicked: root.navigate("videos") }
                    NavRow { icon: "confirmation_number"; label: "Upload"; active: root.currentView === "upload"; onClicked: root.navigate("upload") }
                }
                Column { width: parent.width; spacing: 2
                    Text { width: parent.width; leftPadding: 8; bottomPadding: 2; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "LIBRARY" }
                    NavRow { icon: "history"; label: "Recently Added"; active: root.currentView === "songs"; onClicked: root.navigate("songs") }
                    NavRow { icon: "music_note"; label: "Songs"; active: false; highlight: root.currentView === "songs"; onClicked: root.navigate("songs") }
                    NavRow { icon: "album"; label: "Albums"; active: false; highlight: root.currentView === "albums"; onClicked: root.navigate("albums") }
                    NavRow { icon: "artist"; label: "Artists"; active: root.currentView === "artists"; onClicked: root.navigate("artists") }
                    NavRow { icon: "movie"; label: "Music Videos"; active: false; highlight: root.currentView === "videos"; onClicked: root.navigate("videos") }
                }
                Column { width: parent.width; spacing: 2
                    Row { width: parent.width; height: 20
                        Text { width: parent.width - 28; leftPadding: 8; verticalAlignment: Text.AlignVCenter; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline; text: "PLAYLISTS" }
                        Rectangle { width: 20; height: 20; radius: 10; color: addHover.hovered ? Qt.rgba(1,1,1,0.1) : "transparent"
                            HoverHandler { id: addHover }
                            Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 16; color: Theme.outline; text: "add" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.createPlaylistRequested() }
                        }
                    }
                    NavRow { icon: "favorite"; label: "All Playlists"; accent: true; active: root.currentView === "playlists"; onClicked: root.navigate("playlists") }
                    Repeater {
                        model: root.playlists.slice(0, 6)
                        NavRow {
                            label: modelData.name || "Untitled"; icon: "queue_music"; active: false
                            onClicked: root.navigate("playlist:" + modelData.id)
                        }
                    }
                }
            }
        }

        // ---- user footer ----
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }
        Item { width: 1; height: 16 }
        Row {
            width: parent.width; height: 32
            spacing: 8
            Item { width: 4; height: 1 }
            Rectangle {
                width: 32; height: 32; radius: 16; color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.onPrimary; text: "person" }
            }
            Column {
                width: parent.width - 88
                anchors.verticalCenter: parent.verticalCenter
                Text { font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Listener"; elide: Text.ElideRight; width: parent.width }
                Text { font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Hi-Res Lossless"; elide: Text.ElideRight; width: parent.width }
            }
            Rectangle {
                width: 28; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                color: moreHover.hovered ? Qt.rgba(1,1,1,0.08) : "transparent"
                HoverHandler { id: moreHover }
                Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.outline; text: "more_horiz" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.settingsRequested() }
            }
        }
    }

    // ---- search dropdown (mirrors SearchBox remote+local results) ----
    Rectangle {
        id: dropdown
        width: 340
        height: Math.min(searchResultModel.count, 10) * 44 + 52
        x: 8; y: 116; radius: 16
        color: Theme.surfaceHigh
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: 1
        visible: searchInput.text.length >= 2 && searchInput.activeFocus
        z: 100

        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 2
            Rectangle {
                width: parent.width; height: 34; radius: 8; color: seeHover.hovered ? Qt.rgba(1,1,1,0.06) : "transparent"
                HoverHandler { id: seeHover }
                Row { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                    Text { width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.primary; text: "See all results for \u201c" + searchInput.text + "\u201d" }
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 16; color: Theme.primary; text: "arrow_forward" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.navigate("search"); searchInput.focus = false } }
            }
            ListView {
                width: parent.width; height: Math.max(0, dropdown.height - 52)
                model: ListModel { id: searchResultModel }
                clip: true
                delegate: Item {
                    height: (model && model.kind === "header") ? 24 : 44
                    width: ListView.view ? ListView.view.width : (parent ? parent.width : 340)
                    Rectangle { anchors.fill: parent; radius: 8; color: dHover.hovered && model && model.kind !== "header" ? Qt.rgba(1,1,1,0.06) : "transparent" }
                    HoverHandler { id: dHover }
                    Text {
                        visible: model && model.kind === "header"
                        anchors.verticalCenter: parent.verticalCenter; leftPadding: 12
                        font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.outline
                        text: (model && model.title) || ""
                    }
                    Row {
                        visible: model && model.kind !== "header"
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 10
                        Rectangle {
                            width: 36; height: 36; radius: (model && model.round) ? 18 : 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.surfaceHighest; clip: true
                            Image { anchors.fill: parent; source: (model && model.cover) || ""; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
                            Text { anchors.centerIn: parent; visible: !(model && model.cover); font.family: Theme.fontIcon; font.pixelSize: 16; color: Theme.outline; text: (model && model.kind === "artist") ? "artist" : ((model && model.kind === "album") ? "album" : "music_note") }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; width: parent.width - 52
                            Text { elide: Text.ElideRight; width: parent.width; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: (model && model.title) || "" }
                            Text { elide: Text.ElideRight; width: parent.width; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: (model && model.artist) || "" }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        enabled: model && model.kind !== "header"
                        onClicked: {
                            if (model && model.kind === "song") root.songRequested(model.id);
                            else if (model && model.kind === "album") root.albumRequested(model.id);
                            else if (model && model.kind === "artist") root.artistRequested(model.title);
                            searchInput.text = "";
                            searchInput.focus = false;
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root
        function onSearchQueryChanged() { searchTimer.restart() }
    }

    property var songCache: []
    property double songCacheAt: 0

    Timer {
        id: searchTimer; interval: 180; repeat: false
        onTriggered: {
            if (root.searchQuery.length < 2) { searchResultModel.clear(); return; }
            var q = root.searchQuery;
            var now = Date.now();
            if (now - root.songCacheAt < 30000 && root.songCache.length > 0) {
                fillResults(root.songCache, null, null, q);
            } else {
                Api.get("/songs/paginated", { page: 1, limit: 200 }, function (res) {
                    if (!res || !res.ok) return;
                    var songs = (res.data && res.data.songs) ? res.data.songs.slice(0, 200) : [];
                    root.songCache = songs;
                    root.songCacheAt = Date.now();
                    if (q === root.searchQuery) fillResults(songs, remoteArtists, remoteAlbums, q);
                });
            }
            // remote artist/album suggestions (mirrors web SearchBox)
            Api.get("/search/suggest", { q: q, limit: 5 }, function (res) {
                remoteArtists = (res && res.ok && res.data && res.data.artists) || [];
                remoteAlbums = (res && res.ok && res.data && res.data.albums) || [];
                var songs = root.songCache;
                if (songs.length > 0 && q === root.searchQuery) fillResults(songs, remoteArtists, remoteAlbums, q);
            });
        }
    }

    property var remoteArtists: []
    property var remoteAlbums: []

    // combined model: artists + albums + songs sections (mirrors web dropdown)
    function fillResults(songs, artists, albums, q) {
        searchResultModel.clear();
        (artists || []).slice(0, 3).forEach(function (a, i) {
            if (i === 0) searchResultModel.append({ kind: "header", title: "ARTISTS" });
            searchResultModel.append({ kind: "artist", id: a.key || a.name, title: a.name || "",
                artist: (a.song_count || 0) + " songs", cover: a.cover_art || "", round: true });
        });
        (albums || []).slice(0, 3).forEach(function (a, i) {
            if (i === 0) searchResultModel.append({ kind: "header", title: "ALBUMS" });
            searchResultModel.append({ kind: "album", id: a.id, title: a.name || "",
                artist: (a.song_count || 0) + " songs", cover: a.cover_art || "", round: false });
        });
        var hits = Fuzzy.fuzzySongs(songs, q, 5);
        hits.forEach(function (s, i) {
            if (i === 0) searchResultModel.append({ kind: "header", title: "SONGS" });
            searchResultModel.append({ kind: "song", id: s.id, title: s.title,
                artist: s.artist || "", cover: s.coverArt || "", round: false });
        });
    }

    component NavRow: Rectangle {
        property string icon: ""
        property string label: ""
        property bool active: false
        property bool highlight: false
        property bool accent: false
        signal clicked()
        width: root.width - 32; height: 32; radius: 8
        color: active ? Theme.primaryContainer : (hover.hovered || highlight ? Theme.surfaceHigh : "transparent")
        HoverHandler { id: hover }
        Row {
            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 18; color: active ? Theme.onPrimaryContainer : (accent ? Theme.tertiary : Theme.onVariant); text: icon }
            Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 30; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: active ? Font.DemiBold : Font.Medium; color: active ? Theme.onPrimaryContainer : Theme.onSurface; text: label }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
}
