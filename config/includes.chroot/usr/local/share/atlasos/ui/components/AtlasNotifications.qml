import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Rectangle {
    id: panel
    objectName: "atlasNotificationsPanel"
    property bool boardMode: false
    signal closeRequested()
    color: theme.surfaceRaised
    radius: theme.radiusPanel
    border.color: theme.borderSubtle
    AtlasTheme { id: theme }

    Column {
        anchors.fill: parent; anchors.margins: 18; spacing: 14
        Row {
            width: parent.width; height: 52; spacing: 8
            Text { width: parent.width - 56; anchors.verticalCenter: parent.verticalCenter; text: "Bildirimler"; color: theme.ink; font.pixelSize: 24; font.bold: true }
            Rectangle { width: 48; height: 48; radius: 11; color: theme.surface
                Text { anchors.centerIn: parent; text: "×"; color: theme.atlasNavy; font.pixelSize: 29 }
                MouseArea { anchors.fill: parent; onClicked: panel.closeRequested() }
            }
        }
        Rectangle { width: parent.width; height: 2; color: theme.atlasBlue }
        Rectangle {
            visible: atlasAlerts.items.length === 0
            width: parent.width; height: 178; radius: theme.radiusLarge
            color: theme.surface; border.color: theme.borderSubtle
            Column { anchors.centerIn: parent; spacing: 12
                AtlasIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "bell"; width: 36; height: 36; strokeColor: theme.atlasBlue }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Yeni bildirim yok"; color: theme.ink; font.pixelSize: 19; font.bold: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sistem bildirimleri burada görünür."; color: theme.muted; font.pixelSize: 14 }
            }
        }
        ListView {
            visible: atlasAlerts.items.length > 0
            width: parent.width; height: parent.height - 149
            model: atlasAlerts.items; spacing: 10; clip: true
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width - 9; height: 92; radius: theme.radiusMedium
                color: theme.surface; border.color: theme.borderSubtle
                Rectangle { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 46; height: 46; radius: 12; color: theme.atlasBlueSoft
                    AtlasIcon { anchors.centerIn: parent; name: "bell"; width: 24; height: 24; strokeColor: theme.atlasBlue }
                }
                Column { x: 73; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 150; spacing: 5
                    Text { width: parent.width; text: modelData.title; color: theme.ink; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
                    Text { width: parent.width; text: modelData.message; color: theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                }
                Text { anchors.right: parent.right; anchors.rightMargin: 13; anchors.top: parent.top; anchors.topMargin: 15; text: modelData.time; color: theme.muted; font.pixelSize: 12 }
            }
        }
        AtlasButton {
            width: parent.width; height: 54
            text: "Tüm Bildirimleri Temizle"; iconName: "refresh"; variant: "secondary"
            enabled: atlasAlerts.items.length > 0
            onClicked: atlasAlerts.clear()
        }
    }
}
