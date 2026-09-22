import QtQuick
import QtQuick.Dialogs
import "../components"

// UploadView — mirrors web UploadView: h1 + dashed dropzone + progress.
Rectangle {
    id: root
    property bool uploading: false
    property int progress: 0
    property string status: ""
    property var uploaded: []
    signal done()

    color: "transparent"; clip: true

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: 28; anchors.rightMargin: 28
        contentHeight: col.height + 48; clip: true
        Column { id: col; width: Math.min(parent.width, 860); spacing: 16; topPadding: 24
            Text { font.family: Theme.fontMain; font.pixelSize: 32; font.weight: Font.Bold; color: Theme.onSurface; text: "Upload" }
            Rectangle {
                width: parent.width; height: 300; radius: 24
                color: drop.containsDrag ? Qt.rgba(224/255, 131/255, 110/255, 0.1) : Theme.surfaceLow
                border.color: drop.containsDrag ? Theme.primary : Qt.rgba(1,1,1,0.1); border.width: 2
                Column { anchors.centerIn: parent; spacing: 8
                    Rectangle { width: 56; height: 56; radius: 16; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceHigh
                        Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 26; color: Theme.primary; text: "upload" }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.onSurface; text: "Drop audio files here" }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.outline; text: "MP3, FLAC, M4A, WAV, OGG — lossless preserved" }
                    Rectangle {
                        width: 160; height: 40; radius: 20; anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.primaryContainer
                        Row { anchors.centerIn: parent; spacing: 6
                            Text { font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.onPrimaryContainer; text: "add" }
                            Text { font.family: Theme.fontMain; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.onPrimaryContainer; text: "Choose files" }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fileDialog.open() }
                    }
                    Rectangle { width: 280; height: 6; radius: 3; anchors.horizontalCenter: parent.horizontalCenter; color: Theme.surfaceHighest; visible: root.uploading
                        Rectangle { width: root.progress * parent.width / 100; height: parent.height; radius: 3; color: Theme.primary }
                    }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; visible: root.status !== ""; font.family: Theme.fontMain; font.pixelSize: 12; color: Theme.onVariant; text: root.status }
                }
                DropArea {
                    id: drop; anchors.fill: parent
                    onDropped: function (drop) { if (drop.hasUrls) root.doUpload(drop.urls) }
                }
            }
            Column {
                visible: root.uploaded.length > 0 && !root.uploading; spacing: 6; width: parent.width
                height: visible ? implicitHeight : 0
                Text { font.family: Theme.fontMain; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.onVariant; text: "Recently uploaded" }
                Repeater { model: root.uploaded
                    Rectangle { width: parent.width; height: 36; radius: 8; color: Theme.surfaceContainer
                        Row { anchors.fill: parent; anchors.leftMargin: 10; spacing: 8
                            Text { anchors.verticalCenter: parent.verticalCenter; font.family: Theme.fontIcon; font.pixelSize: 14; color: Theme.primary; text: "check_circle" }
                            Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 22; elide: Text.ElideRight; font.family: Theme.fontMain; font.pixelSize: 13; color: Theme.onSurface; text: modelData }
                        }
                    }
                }
            }
        }
    }

    FileDialog { id: fileDialog; title: "Select audio files"
        nameFilters: ["Audio files (*.wav *.flac *.aac *.mp3 *.ogg *.opus *.alac *.m4a)"]
        onAccepted: root.doUpload(selectedFiles)
    }

    function doUpload(files) {
        if (!files || files.length === 0) return;
        root.uploading = true; root.progress = 0; root.status = "Uploading " + files.length + " file(s)…";
        Api.upload("/upload", files, function (res) {
            root.uploading = false; root.progress = 100; root.status = "Done"
            var ok = res && res.ok
            var uploaded = []
            if (ok && res.data && res.data.uploaded) {
                uploaded = res.data.uploaded.map(function (u) { return u.title || u.filename || "uploaded" })
            } else {
                uploaded = files.map(function (f) { return ("" + f).split("/").pop() })
            }
            root.uploaded = uploaded.concat(root.uploaded).slice(0, 10)
            root.done()
        }, function (p) { root.progress = p })
    }
}
