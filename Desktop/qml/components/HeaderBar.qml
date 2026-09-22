import QtQuick

// Top header — mirrors web Header.jsx 1:1.
// fixed h-16, back/forward + Listen Now/Browse/Videos tabs + cast/notifications/avatar.
Rectangle {
    id: root
    property string currentView: "home"
    signal navigate(string view)
    signal back()
    signal forward()
    signal settingsRequested()

    height: Theme.headerH
    color: Qt.rgba(21/255, 19/255, 22/255, 0.8)

    Row {
        anchors.fill: parent
        anchors.leftMargin: 28; anchors.rightMargin: 28

        // left: nav arrows + tabs
        Row {
            width: parent.width / 2; height: parent.height
            spacing: 16
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                CircleBtn { icon: "chevron_left"; onClicked: root.back() }
                CircleBtn { icon: "chevron_right"; onClicked: root.forward() }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 24
                TabBtn { label: "Listen Now"; active: root.currentView === "home"; onClicked: root.navigate("home") }
                TabBtn { label: "Browse"; active: root.currentView === "albums"; onClicked: root.navigate("albums") }
                TabBtn { label: "Videos"; active: root.currentView === "videos"; onClicked: root.navigate("videos") }
            }
        }

        Item { width: parent.width / 2 - rightRow.width; height: 1 }

        // right: cast / notifications / avatar
        Row {
            id: rightRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            CircleBtn { icon: "cast" }
            CircleBtn { icon: "notifications" }
            Rectangle {
                width: 32; height: 32; radius: 16; color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 18; color: Theme.onPrimary; text: "person" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.settingsRequested() }
            }
        }
    }

    Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: Qt.rgba(1,1,1,0.06) }

    component CircleBtn: Rectangle {
        property string icon: ""
        signal clicked()
        width: 32; height: 32; radius: 16
        anchors.verticalCenter: parent.verticalCenter
        color: h.hovered ? Theme.surfaceHigh : "transparent"
        HoverHandler { id: h }
        Text { anchors.centerIn: parent; font.family: Theme.fontIcon; font.pixelSize: 20; color: Theme.outline; text: parent.icon }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    component TabBtn: Text {
        property string label: ""
        property bool active: false
        signal clicked()
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.fontMain
        font.pixelSize: 12
        font.weight: active ? Font.DemiBold : Font.Medium
        color: active ? Theme.onSurface : Theme.onVariant
        text: label
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: parent.clicked(); onEntered: if (!parent.active) parent.color = Theme.onSurface; onExited: if (!parent.active) parent.color = Theme.onVariant }
    }
}
