import QtQuick
import QtQuick.Controls

// Shared popup dialogs: add-to-playlist, settings, confirm.
Item {
    id: root
    property var playlists: []
    signal createPlaylist(string name)
    signal addToPlaylist(var playlistId, var songId)
    signal deleteSong(var songId)
    signal setEndpoint(string url)
    signal scanChannel()
    property string endpoint: ""

    // Add-to-playlist popup
    Popup {
        id: addPopup
        property var song: null
        anchors.centerIn: parent; width: 340; height: 420; padding: 0; modal: true
        background: Rectangle { radius: 16; color: Theme.surfaceHigh; border.color: Qt.rgba(1,1,1,0.1); border.width: 1 }
        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 12
            Row { width: parent.width; Text { width: parent.width - 32; font.family: Theme.fontMain; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Add to playlist"; elide: Text.ElideRight }
                Text { font.family: Theme.fontIcon; font.pixelSize: 20; color: Theme.outline; text: "close"; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addPopup.close() } }
            }
            Rectangle { width: parent.width; height: 36; radius: 10; color: Theme.surfaceContainer
                Row { anchors.fill: parent; anchors.leftMargin: 10; spacing: 6
                    Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 16; color: Theme.outline; text: "add" }
                    TextInput { id: newPlaylistInput; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24; color: Theme.onSurface; font.family: Theme.fontMain; font.pixelSize: 13; clip: true; Keys.onReturnPressed: { if (text.length > 0) { root.createPlaylist(text); text = "" } } }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.06) }
            ListView { width: parent.width; height: parent.height - 120; clip: true; model: root.playlists
                delegate: Rectangle { width: ListView.view ? ListView.view.width : (parent ? parent.width : 300); height: 40; radius: 10; color: h.hovered ? Qt.rgba(1,1,1,0.07) : "transparent"
                    HoverHandler { id: h }
                    Row { anchors.fill: parent; anchors.leftMargin: 10; spacing: 10
                        Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 16; color: Theme.onVariant; text: "queue_music" }
                        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 13; color: Theme.onSurface; text: modelData.name || "Untitled" }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (addPopup.song) { root.addToPlaylist(modelData.id, addPopup.song.id); addPopup.close() } } }
                }
            }
        }
    }

    // Settings popup
    Popup {
        id: settingsPopup
        anchors.centerIn: parent; width: 420; height: 300; padding: 0; modal: true
        background: Rectangle { radius: 16; color: Theme.surfaceHigh; border.color: Qt.rgba(1,1,1,0.1); border.width: 1 }
        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 12
            Row { width: parent.width; Text { width: parent.width - 32; font.family: Theme.fontMain; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Settings" }
                Text { font.family: Theme.fontIcon; font.pixelSize: 20; color: Theme.outline; text: "close"; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settingsPopup.close() } }
            }
            Text { font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: "Backend endpoint" }
            Rectangle { width: parent.width; height: 36; radius: 10; color: Theme.surfaceContainer
                TextInput { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: Text.AlignVCenter; color: Theme.onSurface; font.family: Theme.fontMain; font.pixelSize: 13; clip: true; text: root.endpoint; onAccepted: root.setEndpoint(text) }
            }
            Rectangle { width: parent.width; height: 36; radius: 10; color: hScan.hovered ? Qt.rgba(1,1,1,0.08) : Theme.surfaceContainer
                HoverHandler { id: hScan }
                Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Sync Telegram channel" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.scanChannel(); settingsPopup.close() } }
            }
        }
    }

    // Confirm delete popup
    Popup {
        id: confirmDelete
        property var song: null
        anchors.centerIn: parent; width: 320; height: 160; padding: 0; modal: true
        background: Rectangle { radius: 16; color: Theme.surfaceHigh; border.color: Theme.error; border.width: 1 }
        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 12
            Text { font.family: Theme.fontMain; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Delete track?" }
            Text { width: parent.width; wrapMode: Text.WordWrap; font.family: Theme.fontMain; font.pixelSize: 13; color: Theme.onVariant; text: "This will permanently remove the file from storage." }
            Row { width: parent.width; layoutDirection: Qt.RightToLeft; spacing: 10
                Rectangle { width: 72; height: 32; radius: 8; color: Theme.surfaceContainer
                    Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Cancel" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: confirmDelete.close() }
                }
                Rectangle { width: 72; height: 32; radius: 8; color: Theme.error
                    Text { anchors.centerIn: parent; font.family: Theme.fontMain; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#fff"; text: "Delete" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (confirmDelete.song) { root.deleteSong(confirmDelete.song.id); confirmDelete.close() } } }
                }
            }
        }
    }

    function openAddToPlaylist(song) { addPopup.song = song; addPopup.open() }
    function openSettings() { settingsPopup.open() }
    function openConfirmDelete(song) { confirmDelete.song = song; confirmDelete.open() }
}
