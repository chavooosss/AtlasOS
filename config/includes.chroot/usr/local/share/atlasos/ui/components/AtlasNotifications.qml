import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Rectangle {
    id: panel
    property bool boardMode: false
    color: theme.canvas
    AtlasTheme { id: theme }

    Column {
        anchors.fill: parent
        anchors.margins: panel.boardMode ? 30 : 24
        spacing: panel.boardMode ? 18 : 14
        Row {
            width: parent.width
            height: panel.boardMode ? 76 : 68
            Text {
                text: "Atlas Bildirimleri"
                color: theme.ink; font.family: theme.fontFamily; font.pixelSize: panel.boardMode ? 34 : 30; font.bold: true
                width: parent.width - clearButton.width - 12
                anchors.verticalCenter: parent.verticalCenter
            }
            AtlasButton {
                id: clearButton
                width: 160; height: panel.boardMode ? theme.touchBoard : theme.touch
                text: "Temizle"; iconName: "refresh"; variant: "secondary"
                enabled: atlasAlerts.items.length > 0
                onClicked: atlasAlerts.clear()
            }
        }
        Rectangle {
            visible: atlasAlerts.items.length === 0
            width: parent.width; height: 164
            radius: theme.radiusPanel; color: theme.surfaceRaised
            Column {
                anchors.centerIn: parent; spacing: 10
                AtlasIcon { anchors.horizontalCenter: parent.horizontalCenter; width: 34; height: 34; name: "bell"; strokeColor: theme.blue }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Şimdilik her şey sakin"; color: theme.ink; font.pixelSize: 19; font.bold: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Yeni sistem bildirimleri burada görünecek."; color: theme.muted; font.pixelSize: 14 }
            }
        }
        ListView {
            visible: atlasAlerts.items.length > 0
            width: parent.width
            height: parent.height - 82
            model: atlasAlerts.items
            spacing: 10
            clip: true
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            delegate: Rectangle {
                width: ListView.view.width - 12
                height: panel.boardMode ? 104 : 92
                radius: theme.radiusCard; color: index % 2 === 0 ? theme.surface : theme.surfaceRaised; border.color: theme.line
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 20
                    anchors.right: timeText.left; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Text { width: parent.width; text: modelData.title; color: theme.ink; font.pixelSize: 18; font.bold: true; elide: Text.ElideRight }
                    Text { width: parent.width; text: modelData.message; color: theme.muted; font.pixelSize: 15; maximumLineCount: 2; wrapMode: Text.WordWrap; elide: Text.ElideRight }
                }
                Text {
                    id: timeText
                    anchors.right: parent.right; anchors.rightMargin: 18
                    anchors.top: parent.top; anchors.topMargin: 18
                    text: modelData.time; color: theme.muted; font.pixelSize: 13
                }
            }
        }
    }
}
