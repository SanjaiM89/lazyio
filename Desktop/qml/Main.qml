import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import "components"
import "views"
import "player"

ApplicationWindow {
    id: win
    visible: true
    width: 1440; height: 900; minimumWidth: 1024; minimumHeight: 600
    title: "Lazyio — Lossless Audio Player"
    color: Theme.background
    font.family: Theme.fontMain

    // -- state (mirrors web App.jsx) --
    property string currentView: "home"
    property var navHistory: ["home"]
    property int navIndex: 0
    property string searchQuery: ""
    property var currentSong: null
    property var queue: []
    property int queueIndex: -1
    property var suggestions: []
    property real volume: 0.8
    property bool muted: false
    property bool shuffle: false
    property string repeatMode: "none"
    property bool autoplay: true
    property var playlists: []
    property bool scanning: false
    property bool showQueue: true
    property bool showFullPlayer: false
    property real playbackProgress: 0
    property real playbackDuration: 0
    property var lyrics: null
    property bool lyricsLoading: false
    property string backendUrl: "http://localhost:8000"

    property var homeData: null
    property bool homeLoading: true
    property int songsTotal: 0
    property string albumDetailId: ""
    property string artistDetailName: ""
    property string playlistDetailId: ""

    readonly property var viewMap: { "home":0, "songs":1, "library":1, "albums":2, "artists":3, "videos":4, "upload":5, "playlists":6, "search":7, "albumDetail":8, "artistDetail":9, "playlistDetail":10, "settings":11 }

    Component.onCompleted: {
        Api.baseUrl = backendUrl
        if (width < 1300) showQueue = false
        loadHome()
        keyCatcher.forceActiveFocus()
    }

    // -- audio --
    AudioOutput { id: audioOutput; volume: win.muted ? 0 : win.volume }

    MediaPlayer {
        id: player
        audioOutput: audioOutput
        onPlaybackStateChanged: win.playing = (playbackState === MediaPlayer.PlayingState)
        onDurationChanged: win.playbackDuration = duration / 1000
        onPositionChanged: win.playbackProgress = position / 1000
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                if (win.repeatMode === "one") { player.play(); return }
                win.next()
            }
        }
    }
    property bool playing: false

    // -- keyboard shortcuts (ApplicationWindow is not an Item: use a focus catcher) --
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Space && !(event.modifiers & Qt.ControlModifier)) { win.togglePlay(); event.accepted = true }
            else if (event.key === Qt.Key_Right && event.modifiers & Qt.ControlModifier) { win.next(); event.accepted = true }
            else if (event.key === Qt.Key_Left && event.modifiers & Qt.ControlModifier) { win.prev(); event.accepted = true }
            else if (event.key === Qt.Key_Escape && showFullPlayer) { showFullPlayer = false; event.accepted = true }
        }
    }

    // -- tray integration --
    Connections {
        target: Tray
        function onQuittingChanged() { if (Tray.quitting) { player.stop(); Qt.quit() } }
    }
    function trayTogglePlay() { win.togglePlay() }
    function trayNext() { win.next() }
    function trayPrev() { win.prev() }

    // -- background scan polling + library refresh --
    Timer { id: scanPollTimer; interval: 3000; repeat: true; running: win.scanning; onTriggered: pollScan() }
    Timer { id: libPollTimer; interval: 45000; repeat: true; running: true; onTriggered: pollLibrary() }

    // -- layout (mirrors web: fixed sidebar w-64, fixed queue w-80, content pl-64 pr-80) --
    SideBar {
        id: sidebar
        z: 10 // above center content so the search dropdown overlays every page uniformly
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
        currentView: win.currentView
        playlists: win.playlists
        onNavigate: function (v) { win.navigate(v) }
        onSongRequested: function (id) { playSongById(id) }
        onAlbumRequested: function (id) { albumDetailId = id; navigate("albumDetail") }
        onArtistRequested: function (n) { artistDetailName = n; navigate("artistDetail") }
        onCreatePlaylistRequested: function () { win.navigate("playlists") }
        onSettingsRequested: function () { modals.openSettings() }
        onSearchQueryChanged: win.searchQuery = sidebar.searchQuery
    }

    QueuePanel {
        id: queuepanel
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        visible: win.showQueue
        width: Theme.queueWidth
        queue: win.queue; currentIndex: win.queueIndex; currentSong: win.currentSong
        suggestions: win.suggestions
        playing: win.playing; progress: win.playbackProgress
        lyrics: win.lyrics; lyricsLoading: win.lyricsLoading
        onPlayRequested: function (i) { playFromIndex(i) }
        onSongRequested: function (id) { playSongById(id) }
        onSeekRequested: function (t) { if (t >= 0) player.position = t * 1000 }
        onCloseRequested: win.showQueue = false
    }

    // center column: header + views
    Item {
        id: centerCol
        anchors.left: sidebar.right
        anchors.right: win.showQueue ? queuepanel.left : parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.bottomMargin: 104

        HeaderBar {
            id: headerbar
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            currentView: win.currentView
            onNavigate: function (v) { win.navigate(v) }
            onBack: win.goBack()
            onForward: win.goForward()
            onSettingsRequested: modals.openSettings()
        }

        StackLayout {
            anchors.top: headerbar.bottom
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            currentIndex: viewMap[currentView] !== undefined ? viewMap[currentView] : 0

            HomeView { homeData: win.homeData; loading: win.homeLoading; currentSongId: currentSong ? currentSong.id : ""
                onSongRequested: function (id) { playSongById(id) }
                onPlayRequested: function (s, q, i) { playFromQueue(s, q, i) }
                onAlbumRequested: function (id) { albumDetailId = id; navigate("albumDetail") }
                onRefreshRequested: refreshHome()
            }
            SongsView { currentSongId: currentSong ? currentSong.id : ""
                onPlayRequested: function (s, q, i) { playFromQueue(s, q, i) }
                onSongMenuRequested: function (s) { songMenuTarget = s; songMenu.open() }
            }
            AlbumsView { onAlbumRequested: function (id) { albumDetailId = id; navigate("albumDetail") } }
            ArtistsView { onArtistRequested: function (n) { artistDetailName = n; navigate("artistDetail") } }
            VideosView { onVideoRequested: function (id) { playSongById(id) } }
            UploadView { onDone: refreshHome() }
            PlaylistsView { onPlaylistRequested: function (id) { playlistDetailId = id; navigate("playlistDetail") }; onCreateRequested: createPlaylist }
            SearchView { query: win.searchQuery; currentSongId: currentSong ? currentSong.id : ""
                onPlayRequested: function (s, q, i) { playFromQueue(s, q, i) }
                onSongMenuRequested: function (s) { songMenuTarget = s; songMenu.open() }
                onAlbumRequested: function (id) { albumDetailId = id; navigate("albumDetail") }
                onArtistRequested: function (n) { artistDetailName = n; navigate("artistDetail") }
            }
            AlbumDetail { albumId: albumDetailId; currentSongId: currentSong ? currentSong.id : ""
                onPlayRequested: function (s, q, i) { playFromQueue(s, q, i) }
                onBackRequested: goBack()
            }
            ArtistDetail { name: artistDetailName; currentSongId: currentSong ? currentSong.id : ""
                onPlayRequested: function (s, q, i) { playFromQueue(s, q, i) }
                onBackRequested: goBack()
            }
            PlaylistDetail { playlistId: playlistDetailId; currentSongId: currentSong ? currentSong.id : ""
                onPlayRequested: function (s, q, i) { playFromQueue(s, q, i) }
                onBackRequested: goBack()
            }
            Rectangle { // settings placeholder
                color: "transparent"
                Column { anchors.centerIn: parent; spacing: 12
                    Text { font.family: Theme.fontIcon; font.pixelSize: 32; color: Theme.outline; text: "settings"; anchors.horizontalCenter: parent.horizontalCenter }
                    Text { font.family: Theme.fontMain; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Settings" }
                    Text { font.family: Theme.fontMain; font.pixelSize: 13; color: Theme.outline; text: "Backend: " + win.backendUrl }
                    Row { spacing: 12; anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle { width: 140; height: 36; radius: 10; color: Theme.surfaceContainer
                            TextInput { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: Text.AlignVCenter; color: Theme.onSurface; font.family: Theme.fontMain; font.pixelSize: 13; clip: true
                                text: win.backendUrl; Keys.onReturnPressed: { win.backendUrl = text; Api.baseUrl = text } } }
                        Rectangle { width: 140; height: 36; radius: 10; color: Theme.surfaceContainer; Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Sync Telegram" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: scanTelegram() } }
                    }
                }
            }
        }
    }

    // floating player pill (mirrors web fixed bottom-3 left-64 right-80)
    PlayerBar {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        anchors.left: parent.left; anchors.leftMargin: Theme.sideWidth + 16
        anchors.right: parent.right; anchors.rightMargin: (win.showQueue ? Theme.queueWidth : 0) + 16
        currentSong: win.currentSong; playing: win.playing; progress: win.playbackProgress; duration: win.playbackDuration
        volume: win.volume; muted: win.muted; showQueue: win.showQueue; shuffle: win.shuffle; repeatMode: win.repeatMode
        onPlayPause: win.togglePlay()
        onNext: win.next()
        onPrev: win.prev()
        onSeek: function (s) { player.position = s * 1000 }
        onVolumeSet: function (v) { if (v <= 0) { win.muted = true } else { win.muted = false; win.volume = v } }
        onToggleQueue: win.showQueue = !win.showQueue
        onToggleLyrics: { win.showQueue = true; queuepanel.showTab(1) }
        onToggleShuffle: win.shuffle = !win.shuffle
        onCycleRepeat: { var modes = ["none","all","one"]; repeatMode = modes[(modes.indexOf(repeatMode) + 1) % 3] }
        onOpenFullPlayer: win.toggleFull()
    }

    // full screen player
    FullPlayer {
        anchors.fill: parent; visible: showFullPlayer
        song: win.currentSong; playing: win.playing; progress: win.playbackProgress; duration: win.playbackDuration
        volume: win.muted ? 0 : win.volume
        queue: win.queue; queueIndex: win.queueIndex; suggestions: win.suggestions
        shuffle: win.shuffle; repeatMode: win.repeatMode; autoplay: win.autoplay
        lyrics: win.lyrics; lyricsLoading: win.lyricsLoading
        onCloseRequested: win.showFullPlayer = false
        onPlayPause: win.togglePlay()
        onNext: win.next(); onPrev: win.prev()
        onSeek: function (s) { player.position = s * 1000 }
        onVolumeSet: function (v) { if (v <= 0) { win.muted = true } else { win.muted = false; win.volume = v } }
        onToggleShuffle: win.shuffle = !win.shuffle
        onCycleRepeat: { var modes = ["none","all","one"]; repeatMode = modes[(modes.indexOf(repeatMode) + 1) % 3] }
        onToggleAutoplay: win.autoplay = !win.autoplay
        onPlayFromIndex: function (i) { playFromIndex(i) }
        onSongRequested: function (id) { playSongById(id) }
        onAddRequested: function (s) { modals.openAddToPlaylist(s) }
    }

    // song context menu
    SongMenu {
        id: songMenu
        song: songMenuTarget
        canDelete: true
        onAddRequested: function (s) { modals.openAddToPlaylist(s) }
        onDeleteRequested: function (s) { modals.openConfirmDelete(s) }
    }
    property var songMenuTarget: null

    // modals
    Modals {
        id: modals; anchors.fill: parent; playlists: win.playlists; endpoint: win.backendUrl
        onCreatePlaylist: function (n) { createPlaylist(n) }
        onAddToPlaylist: function (pid, sid) { Api.post("/playlists/" + pid + "/songs", { song_id: sid }, {}, function () { loadPlaylists() }) }
        onDeleteSong: function (id) { Api.del("/songs/" + id, {}, function () { loadHome() }) }
        onSetEndpoint: function (url) { win.backendUrl = url; Api.baseUrl = url; }
        onScanChannel: scanTelegram()
    }

    // -- navigation (mirrors web history) --
    function navigate(v) {
        if (v === "settings") { modals.openSettings(); return }
        if (v && v.indexOf("playlist:") === 0) { playlistDetailId = v.slice(9); v = "playlistDetail" }
        if (v === currentView) return
        navHistory = navHistory.slice(0, navIndex + 1).concat([v])
        navIndex = navHistory.length - 1
        currentView = v
    }
    function goBack() { if (navIndex > 0) { navIndex--; currentView = navHistory[navIndex] } }
    function goForward() { if (navIndex < navHistory.length - 1) { navIndex++; currentView = navHistory[navIndex] } }

    // -- data helpers --
    function loadHome() {
        homeLoading = true
        Api.get("/home", {}, function (res) {
            homeLoading = false
            if (!res || !res.ok) return
            homeData = res.data
            songsTotal = res.data.songsTotal || (res.data.recently_played || []).length
        })
        loadPlaylists()
        Api.get("/songs/paginated", { page: 1, limit: 1 }, function (res) {
            if (res && res.ok) songsTotal = res.data.total || 0
        })
    }
    function refreshHome() { Api.post("/home/refresh", {}, {}, function () { setTimeout(loadHome, 3000) }) }
    function loadPlaylists() {
        Api.get("/playlists", { page: 1, limit: 50 }, function (res) {
            if (res && res.ok) playlists = res.data.playlists || res.data || []
        })
    }
    function createPlaylist(name) {
        Api.post("/playlists", {}, { name: name }, function () { loadPlaylists() })
    }
    function scanTelegram() {
        scanning = true
        Api.post("/telegram/scan", {}, {}, function () { scanPollTimer.start() })
    }
    function pollScan() {
        Api.get("/telegram/scan/status", {}, function (res) {
            if (!res || !res.ok) return
            if (res.data.status === "completed" || res.data.status === "idle" || res.data.status === "error") {
                scanning = false; scanPollTimer.stop(); loadHome()
            }
        })
    }
    function pollLibrary() {
        Api.get("/songs/paginated", { page: 1, limit: 1 }, function (res) {
            if (res && res.ok) songsTotal = res.data.total || 0
        })
    }
    function setTimeout(fn, ms) { var t = Qt.createQmlObject("import QtQuick; Timer { interval: " + ms + "; running: true; repeat: false }", win, "timer"); t.triggered.connect(function () { fn(); t.destroy() }) }

    function playSongById(id) {
        Api.get("/songs/paginated", { page: 1, limit: 200 }, function (res) {
            if (!res || !res.ok) return
            var songs = res.data.songs || []
            var idx = songs.findIndex(function (s) { return s.id === id })
            if (idx === -1) return
            playFromQueue(songs[idx], songs, idx)
        })
    }
    function playFromQueue(song, q, idx) {
        queue = q; queueIndex = idx; setSong(song)
    }
    function playFromIndex(i) {
        if (i >= 0 && i < queue.length) { queueIndex = i; setSong(queue[i]) }
    }
    function setSong(song) {
        currentSong = song
        player.source = Api.streamUrl(song.id)
        player.play()
        Api.post("/songs/" + song.id + "/play", {}, {}, function () {})
        loadLyrics(song.id)
        loadRelated(song.id)
        Tray.updateTrack(song.title || "Unknown", song.artist || "")
    }
    function loadLyrics(id) {
        lyricsLoading = true; lyrics = null
        Api.get("/songs/" + id + "/lyrics", {}, function (res) {
            lyricsLoading = false
            if (res && res.ok) lyrics = res.data
        })
    }
    function loadRelated(id) {
        Api.get("/recommend/similar/" + id, { limit: 6 }, function (res) {
            if (res && res.ok) suggestions = res.data.similar || res.data.songs || []
        })
    }
    function togglePlay() {
        if (!currentSong) return
        if (playing) player.pause(); else player.play()
    }
    function next() {
        var q = queue.length ? queue : []
        if (q.length === 0) return
        if (shuffle) { var r = Math.floor(Math.random() * q.length); queueIndex = r; setSong(q[r]); return }
        if (queueIndex + 1 < q.length) { queueIndex++; setSong(q[queueIndex]); return }
        if (repeatMode === "all") { queueIndex = 0; setSong(q[0]); return }
        if (autoplay && currentSong && suggestions.length > 0) {
            var known = {};
            q.forEach(function (s) { known[s.id] = true });
            var fresh = suggestions.filter(function (s) { return s && s.id && !known[s.id] });
            if (fresh.length > 0) {
                queue = q.concat(fresh);
                queueIndex = q.length;
                setSong(fresh[0]);
                return;
            }
        }
        player.pause()
    }
    function prev() {
        if (queue.length === 0) return
        var prevIdx = queueIndex - 1
        if (prevIdx < 0) prevIdx = repeatMode === "all" ? queue.length - 1 : 0
        queueIndex = prevIdx; setSong(queue[prevIdx])
    }
    function toggleFull() { showFullPlayer = !showFullPlayer }
}
