import QtQuick
import QtQuick.Controls
import "../theme"

Rectangle {
    id: panel
    color: theme.canvas
    AtlasTheme { id: theme }

    Column {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 14
        Row {
            width: parent.width; height: 64
            Text {
                text: "Atlas Bildirimleri"
                color: theme.ink; font.pixelSize: 28; font.bold: true
                width: parent.width - clearButton.width
            }
            Button {
                id: clearButton
                width: 150; height: 64
                text: "Temizle"
                font.pixelSize: 17
                enabled: atlasAlerts.items.length > 0
                onClicked: atlasAlerts.clear()
            }
        }
        Text {
            visible: atlasAlerts.items.length === 0
            text: "Bu oturumda Atlas bildirimi yok."
            color: theme.muted; font.pixelSize: 17
        }
        ListView {
            width: parent.width
            height: parent.height - 78
            model: atlasAlerts.items
            spacing: 9
            clip: true
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                width: ListView.view.width - 12; height: 86
                radius: 6; color: "white"; border.color: theme.line
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 18
                    anchors.right: timeText.left; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 5
                    Text { text: modelData.title; color: theme.ink; font.pixelSize: 18; font.bold: true }
                    Text { width: parent.width; text: modelData.message; color: theme.muted; font.pixelSize: 15; elide: Text.ElideRight }
                }
                Text {
                    id: timeText
                    anchors.right: parent.right; anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.time; color: theme.muted; font.pixelSize: 14
                }
            }
        }
    }
}
