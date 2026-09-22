import QtQuick
import "../components"

// Fullscreen Now Playing — mirrors web NocturnePlayer.jsx 1:1.
// Ambient backdrop + top bar + vinyl stage with transport deck + Up Next drawer.
Rectangle {
    id: root
    property var song: null
    property bool playing: false
    property real progress: 0
    property real duration: 0
    property real volume: 0.8
    property var queue: []
    property int queueIndex: -1
    property var suggestions: []
    property bool shuffle: false
    property string repeatMode: "none" // none | all | one
    property bool autoplay: true
    property var lyrics: null
    property bool lyricsLoading: false
    property int drawerTab: 0 // 0 playing next, 1 lyrics, 2 related
    property bool loved: false
    signal closeRequested()
    signal playPause()
    signal next()
    signal prev()
    signal seek(real seconds)
    signal volumeSet(real value)
    signal toggleShuffle()
    signal cycleRepeat()
    signal toggleAutoplay()
    signal playFromIndex(int index)
    signal songRequested(string songId)
    signal addRequested(var song)
    property real _rotation: 0

    color: Theme.background
    z: 1000
    opacity: visible ? 1 : 0
    enabled: visible
    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

    property string cover: song ? (song.cover_art || song.coverArt || song.thumbnail || "") : ""
    property var upcoming: (queueIndex >= 0 && queue.length > 0) ? queue.slice(queueIndex + 1) : queue
    property int totalSec: { var t = 0; for (var i = 0; i < queue.length; i++) t += (queue[i].duration || 0); return t; }
    property real pct: duration > 0 ? progress / duration : 0

    Timer {
        id: discTimer; interval: 33; repeat: true; running: root.playing && root.visible
        onTriggered: root._rotation = (root._rotation + 0.45) % 360
    }

    // ---- ambient backdrop ----
    Rectangle { width: 750; height: 480; radius: 240; x: parent.width * 0.25 - 375; y: -160; color: Theme.secondaryContainer; opacity: 0.25 }
    Rectangle { width: 420; height: 360; radius: 180; x: parent.width - 460; y: parent.height * 0.33; color: Theme.primaryContainer; opacity: 0.12 }
    Rectangle { width: 700; height: 420; radius: 210; x: parent.width * 0.25 - 350; y: parent.height - 260; color: Theme.secondaryContainer; opacity: 0.18 }

    // ---- top bar ----
    Rectangle {
        id: topbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 64; color: Qt.rgba(21/255, 19/255, 22/255, 0.8)
        border.color: Qt.rgba(1,1,1,0.06); border.width: 0
        Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: Qt.rgba(1,1,1,0.06) }

        Row {
            anchors.fill: parent; anchors.leftMargin: 28; anchors.rightMargin: 28
            // left: minimize + hires badge
            Row {
                width: parent.width * 0.32; height: parent.height; spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    height: 32; width: minPillText.implicitWidth + 44; radius: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: minHover.hovered ? Theme.surfaceHigh : Theme.surfaceContainer
                    HoverHandler { id: minHover }
                    Row { anchors.centerIn: parent; spacing: 6
                        Text { font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.onVariant; text: "expand_more" }
                        Text { id: minPillText; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onVariant; text: "Now Playing" }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closeRequested() }
                }
                Rectangle {
                    height: 28; width: hiresText.implicitWidth + 30; radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(134/255, 32/255, 37/255, 0.3)
                    border.color: Qt.rgba(1,1,1,0.06); border.width: 1
                    Row { anchors.centerIn: parent; spacing: 6
                        Rectangle { width: 6; height: 6; radius: 3; color: Theme.secondary
                            SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { from: 1; to: 0.3; duration: 900 } NumberAnimation { from: 0.3; to: 1; duration: 900 } }
                        }
                        Text { id: hiresText; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.secondary; text: "Hi-Res Lossless" }
                    }
                }
            }
            // center: hifi pill
            Item {
                width: parent.width * 0.36; height: parent.height
                visible: parent.width > 700
                Row {
                    anchors.centerIn: parent; spacing: 6
                    leftPadding: 16; rightPadding: 16
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 14; color: Theme.primary; text: "graphic_eq" }
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.onVariant; text: "Lazyio Hi-Fi" }
                    Rectangle { width: 4; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Theme.outline }
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.primary; text: "Bit-Perfect" }
                }
            }
            // right: lossless + lyrics + exit
            Row {
                width: parent.width * 0.32; height: parent.height; spacing: 8
                layoutDirection: Qt.RightToLeft
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: 34; height: 34; radius: 17; anchors.verticalCenter: parent.verticalCenter
                    color: exitHover.hovered ? Theme.surfaceHigh : "transparent"
                    HoverHandler { id: exitHover }
                    Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.outline; text: "fullscreen_exit" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closeRequested() }
                }
                Rectangle {
                    width: 34; height: 34; radius: 17; anchors.verticalCenter: parent.verticalCenter
                    color: root.drawerTab === 1 ? Theme.surfaceContainer : (lyrHover.hovered ? Theme.surfaceHigh : "transparent")
                    HoverHandler { id: lyrHover }
                    Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 18; color: root.drawerTab === 1 ? Theme.primary : Theme.outline; text: "lyrics" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.drawerTab = 1 }
                }
                Rectangle {
                    width: 76; height: 22; radius: 4; anchors.verticalCenter: parent.verticalCenter
                    color: Theme.surfaceHighest
                    Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.primary; text: "LOSSLESS" }
                }
            }
        }
    }

    // ---- main stage ----
    Item {
        id: stage
        anchors.top: topbar.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 16

        // left: vinyl + info + transport
        Flickable {
            id: leftFlick
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            width: parent.width - drawerCard.width - 16
            contentHeight: leftCol.height; clip: true
            Column { id: leftCol; width: parent.width; spacing: 0
                // vinyl
                Item {
                    width: parent.width; height: discSize + 40
                    property real discSize: Math.min(380, Math.max(220, leftFlick.height - 380))
                    Item {
                        width: parent.discSize; height: parent.discSize
                        anchors.centerIn: parent
                        // glow
                        Rectangle { anchors.centerIn: parent; width: parent.width + 80; height: parent.height + 80; radius: (parent.width + 80) / 2; color: Theme.secondaryContainer; opacity: 0.3 }
                        // disc
                        Rectangle {
                            id: vinyl
                            anchors.fill: parent; radius: width / 2; color: "#0a0a0c"
                            border.color: Qt.rgba(1,1,1,0.07); border.width: 1
                            rotation: root._rotation
                            Repeater { model: 8
                                Rectangle {
                                    width: vinyl.width - 30 - index * 14; height: width
                                    anchors.centerIn: parent
                                    radius: width / 2; color: "transparent"
                                    border { width: 1; color: Qt.rgba(1, 1, 1, 0.04 + index * 0.008) }
                                }
                            }
                            // sheen
                            Rectangle {
                                anchors.fill: parent; radius: width / 2; color: "transparent"; rotation: -rotation
                                Rectangle { width: parent.width * 0.5; height: parent.height; x: parent.width * 0.25; color: "transparent" }
                            }
                            // center label with cover + texts
                            Rectangle {
                                width: parent.width * 0.42; height: width
                                anchors.centerIn: parent; radius: width / 2
                                color: Theme.primaryContainer
                                clip: true
                                Image {
                                    anchors.fill: parent; source: root.cover
                                    fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready
                                }
                                Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(0,0,0,0.45); visible: root.cover !== "" }
                                Column {
                                    anchors.centerIn: parent; width: parent.width - 16; spacing: 1
                                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 9; font.weight: Font.Bold; color: Theme.primary; text: (root.song && root.song.album ? root.song.album : "LAZYIO").toUpperCase() }
                                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 11; font.weight: Font.DemiBold; color: "white"; text: root.song ? (root.song.title || "") : "" }
                                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 9; color: "#e7e1e5"; text: root.song ? (root.song.artist || "") : "" }
                                }
                                // spindle
                                Rectangle {
                                    width: 20; height: 20; radius: 10
                                    anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                                    color: "#0f0d10"; border.color: Theme.surfaceHighest; border.width: 2
                                    Rectangle { width: 6; height: 6; radius: 3; anchors.centerIn: parent; color: "black" }
                                }
                                Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border { width: 2; color: Qt.rgba(224/255, 131/255, 110/255, 0.6) } }
                            }
                        }
                        // playing badge
                        Rectangle {
                            anchors.top: parent.top; anchors.right: parent.right
                            width: badgeText.implicitWidth + 28; height: 28; radius: 14
                            color: Qt.rgba(29/255, 27/255, 30/255, 0.8)
                            border.color: Qt.rgba(1,1,1,0.08); border.width: 1
                            Row { anchors.centerIn: parent; spacing: 6
                                Rectangle { width: 8; height: 8; radius: 4; color: root.playing ? Theme.primary : Theme.outline
                                    SequentialAnimation on opacity { running: root.playing; loops: Animation.Infinite; NumberAnimation { from: 1; to: 0.3; duration: 800 } NumberAnimation { from: 0.3; to: 1; duration: 800 } }
                                }
                                Text { id: badgeText; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: root.playing ? "Playing" : "Paused" }
                            }
                        }
                    }
                }

                // title block
                Column {
                    width: Math.min(parent.width, 640); spacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 12
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 32; font.weight: Font.Bold; color: Theme.onSurface; text: root.song ? (root.song.title || "Unknown Title") : "" }
                    Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 6
                        Text { font.family: Theme.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.onVariant; text: root.song ? (root.song.artist || "Unknown Artist") : "" }
                        Text { font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.primary; text: "check_circle" }
                    }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline
                        text: (root.song && root.song.album ? root.song.album : "Single") + "  •  " + (root.song && root.song.year ? root.song.year + "  •  " : "") + "Lossless" }
                    // actions
                    Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 12; topPadding: 8
                        Rectangle {
                            width: 40; height: 40; radius: 20
                            color: root.loved ? Theme.primaryContainer : (loveHover.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.08))
                            HoverHandler { id: loveHover }
                            Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 18; color: root.loved ? Theme.onPrimaryContainer : Theme.tertiary; text: "favorite" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.loved = !root.loved }
                        }
                        Rectangle {
                            width: 96; height: 40; radius: 20
                            color: addHover.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.08)
                            HoverHandler { id: addHover }
                            Row { anchors.centerIn: parent; spacing: 4
                                Text { font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.onSurface; text: "add" }
                                Text { font.family: Theme.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Add" }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.song) root.addRequested(root.song) }
                        }
                        Rectangle {
                            width: 40; height: 40; radius: 20
                            color: moreHover.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.08)
                            HoverHandler { id: moreHover }
                            Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 20; color: Theme.onSurface; text: "more_horiz" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.song) root.addRequested(root.song) }
                        }
                    }
                }

                // transport deck (pinned at bottom of left column)
                Column {
                    width: Math.min(parent.width, 720); spacing: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 16; bottomPadding: 8
                    // seek row
                    Row {
                        width: parent.width; spacing: 8
                        Text { width: 40; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; font.family: "monospace"; font.pixelSize: 12; color: Theme.outline; text: Theme.fmtTime(root.progress) }
                        Item {
                            width: parent.width - 40 - 48 - 16; height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Theme.surfaceHighest }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: root.pct * parent.width; height: 6; radius: 3; color: Theme.primary }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.pct * parent.width - 7
                                width: 14; height: 14; radius: 7
                                color: Theme.primary; border.color: Theme.background; border.width: 2
                                visible: seekHover.hovered; HoverHandler { id: seekHover }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                onClicked: function (mouse) { if (root.duration > 0) root.seek((mouse.x / width) * root.duration) }
                                onPositionChanged: function (mouse) { if (pressed && root.duration > 0) root.seek((mouse.x / width) * root.duration) }
                            }
                        }
                        Text { width: 48; anchors.verticalCenter: parent.verticalCenter; font.family: "monospace"; font.pixelSize: 12; color: Theme.outline; text: "-" + Theme.fmtTime(Math.max(0, root.duration - root.progress)) }
                    }
                    // buttons row
                    Item {
                        width: parent.width; height: 56
                        // left: shuffle + EQ
                        Row {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            FBtn { icon: "shuffle"; active: root.shuffle; onClicked: root.toggleShuffle() }
                            Row { spacing: 4; anchors.verticalCenter: parent.verticalCenter; visible: root.width > 1100
                                Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 16; color: Theme.primary; text: "equalizer" }
                                Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: "Lossless EQ" }
                            }
                        }
                        // center: transport
                        Row {
                            anchors.centerIn: parent
                            spacing: 20
                            FBtn { icon: "skip_previous"; size: 28; solid: true; onClicked: root.prev() }
                            Rectangle {
                                width: 56; height: 56; radius: 28; anchors.verticalCenter: parent.verticalCenter
                                color: playHover.hovered ? Theme.primaryContainer : Theme.primary
                                HoverHandler { id: playHover }
                                Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 30; color: Theme.onPrimary; text: root.playing ? "pause" : "play_arrow" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.playPause() }
                            }
                            FBtn { icon: "skip_next"; size: 28; solid: true; onClicked: root.next() }
                        }
                        // right: repeat + volume
                        Row {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            layoutDirection: Qt.RightToLeft
                            FBtn { icon: root.repeatMode === "one" ? "repeat_one" : "repeat"; active: root.repeatMode !== "none"; onClicked: root.cycleRepeat() }
                            Item {
                                width: 112; height: 24; anchors.verticalCenter: parent.verticalCenter
                                visible: root.width > 1150
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.outline
                                        text: root.volume <= 0 ? "volume_off" : "volume_up"
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.volumeSet(root.volume > 0 ? 0 : 0.8) }
                                    }
                                    Item {
                                        width: 80; height: 16; anchors.verticalCenter: parent.verticalCenter
                                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Theme.surfaceHighest }
                                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: root.volume * parent.width; height: 4; radius: 2; color: Theme.onVariant }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: function (mouse) { root.volumeSet(Math.max(0, Math.min(1, mouse.x / width))) }
                                            onPositionChanged: function (mouse) { if (pressed) root.volumeSet(Math.max(0, Math.min(1, mouse.x / width))) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // right: Up Next drawer
        Rectangle {
            id: drawerCard
            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            width: Math.min(400, parent.width * 0.33)
            radius: 16
            color: Qt.rgba(29/255, 27/255, 30/255, 0.8)
            border.color: Qt.rgba(1,1,1,0.06); border.width: 1

            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 8
                // tabs + counts
                Item {
                    width: parent.width; height: 32
                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Repeater { model: ["Playing Next", "Lyrics", "Related"]
                            Rectangle {
                                property bool active: index === root.drawerTab
                                width: dtabText.implicitWidth + 20; height: 28; radius: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: active ? Theme.surfaceContainer : (dtabHover.hovered ? Qt.rgba(1,1,1,0.06) : "transparent")
                                HoverHandler { id: dtabHover }
                                Text { id: dtabText; anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: parent.active ? Theme.onSurface : Theme.outline; text: modelData.toUpperCase() }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.drawerTab = index }
                            }
                        }
                    }
                    Rectangle {
                        id: countBox
                        width: countText.implicitWidth + 20; height: 26; radius: 6
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        color: Theme.surfaceContainer
                        Text { id: countText; anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: root.queue.length + " tracks • " + Math.floor(root.totalSec / 60) + "m" }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }
                // content
                Flickable {
                    id: drawerFlick
                    width: parent.width; height: parent.height - 32 - 1 - 8 - 64 - 16
                    contentHeight: drawerCol.height; clip: true
                    Column { id: drawerCol; width: parent.width; spacing: 4
                        // queue
                        Column {
                            width: parent.width; spacing: 4
                            visible: root.drawerTab === 0
                            height: visible ? implicitHeight : 0
                            Text { font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Queue is empty."; visible: root.upcoming.length === 0; leftPadding: 4; height: visible ? implicitHeight : 0 }
                            Repeater { model: root.upcoming
                                Rectangle {
                                    width: parent.width; height: 56; radius: 8
                                    color: (index === 0) ? Theme.surfaceContainer : (qHover.hovered ? Theme.surfaceHigh : "transparent")
                                    border.color: index === 0 ? Qt.rgba(224/255, 131/255, 110/255, 0.3) : "transparent"; border.width: 1
                                    HoverHandler { id: qHover }
                                    Row { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                        CoverImage { width: 44; height: 44; radius: 8; anchors.verticalCenter: parent.verticalCenter; src: modelData.cover_art || modelData.coverArt || "" }
                                        Column { width: parent.width - 44 - 8 - 60 - 8; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                            Row { width: parent.width; spacing: 6
                                                Text { width: Math.min(implicitWidth, parent.width - (index === 0 ? 44 : 0)); elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: (root.song && modelData.id === root.song.id) ? Theme.primary : Theme.onSurface; text: modelData.title || "" }
                                                Rectangle { visible: index === 0; width: 36; height: 16; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(224/255, 131/255, 110/255, 0.2)
                                                    Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.primary; text: "NEXT" }
                                                }
                                            }
                                            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: modelData.artist || "" }
                                        }
                                        Text { width: 52; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; font.family: "monospace"; font.pixelSize: 11; color: Theme.outline; text: Theme.fmtTime(modelData.duration) }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.playFromIndex(root.queueIndex + 1 + index) }
                                }
                            }
                        }
                        // lyrics
                        LyricsPane {
                            width: parent.width
                            height: root.drawerTab === 1 ? drawerFlick.height : 0
                            visible: root.drawerTab === 1
                            lyrics: root.lyrics; loading: root.lyricsLoading; playbackSeconds: root.progress
                            onSeekTo: function (t) { root.seek(t) }
                        }
                        // related
                        Column {
                            width: parent.width; spacing: 4
                            visible: root.drawerTab === 2
                            height: visible ? implicitHeight : 0
                            Text { font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Play more to get recommendations."; visible: root.suggestions.length === 0; leftPadding: 4; height: visible ? implicitHeight : 0 }
                            Repeater { model: root.suggestions
                                Rectangle {
                                    width: parent.width; height: 56; radius: 8
                                    color: rHover.hovered ? Theme.surfaceHigh : "transparent"
                                    HoverHandler { id: rHover }
                                    Row { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                        CoverImage { width: 44; height: 44; radius: 8; anchors.verticalCenter: parent.verticalCenter; src: modelData.cover_art || modelData.coverArt || "" }
                                        Column { width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter
                                            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: modelData.title || "" }
                                            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: modelData.artist || "" }
                                        }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.songRequested(modelData.id) }
                                }
                            }
                        }
                    }
                }
                // autoplay footer
                Rectangle {
                    width: parent.width; height: 64; radius: 12
                    color: Theme.surfaceLow
                    border.color: Qt.rgba(1,1,1,0.06); border.width: 1
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                        Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.primary; text: "all_inclusive" }
                        Column {
                            width: parent.width - 30 - 44
                            anchors.verticalCenter: parent.verticalCenter
                            Text { font.family: Theme.fontMain; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Infinite Autoplay" }
                            Text { font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "Similar songs will follow" }
                        }
                        Rectangle {
                            width: 36; height: 20; radius: 10; anchors.verticalCenter: parent.verticalCenter
                            color: root.autoplay ? Theme.primaryContainer : Theme.surfaceHighest
                            Rectangle {
                                width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter
                                x: root.autoplay ? parent.width - 18 : 2
                                color: "white"
                                Behavior on x { NumberAnimation { duration: 150 } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleAutoplay() }
                        }
                    }
                }
            }
        }
    }

    component FBtn: Text {
        property string icon: ""
        property bool active: false
        property bool solid: false
        property int size: 18
        signal clicked()
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.fontIcon; font.pixelSize: size
        color: active ? Theme.primary : (fbHover.hovered ? Theme.primary : (solid ? Theme.onSurface : Theme.outline))
        text: icon
        HoverHandler { id: fbHover }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: parent.clicked() }
    }
}
