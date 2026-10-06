import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Controls.Popup {
    id: menu
    objectName: "atlasPowerMenu"
    property string pendingAction: ""
    signal actionRequested(string action)
    modal: true; focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    padding: 24
    width: Math.min(parent.width - 48, parent.width < 1450 ? 760 : 890)
    height: parent.width < 1450 ? 382 : 428
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    onOpened: pendingAction = ""
    AtlasTheme { id: theme }
    Controls.Overlay.modal: Rectangle { color: "#07182b"; opacity: 0.66 }
    background: Rectangle {
        radius: theme.radiusPanel
        gradient: Gradient {
            GradientStop { position: 0; color: "#143d68" }
            GradientStop { position: 1; color: theme.atlasNavyDeep }
        }
        border.color: theme.shellLine
    }
    contentItem: Column {
        spacing: 20
        Row { width: parent.width; height: 70; spacing: 16
            Image { width: 62; height: 62; source: "../branding/atlas-symbol.png"; fillMode: Image.PreserveAspectFit }
            Column { width: 245; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                Text { text: "Atlas OS"; color: "white"; font.pixelSize: 26; font.bold: true }
                Text { text: menu.pendingAction ? "İşlemi onaylayın" : "Oturum ve güç seçenekleri"; color: theme.shellMutedText; font.pixelSize: 14 }
            }
            Item { width: Math.max(0, parent.width - 62 - 245 - 44 - 48); height: 1 }
            Rectangle { width: 44; height: 44; radius: 10; color: theme.shellRaised
                Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 27 }
                MouseArea { anchors.fill: parent; onClicked: menu.close() }
            }
        }
        Row {
            width: parent.width; height: menu.parent.width < 1450 ? 202 : 228; spacing: 14
            Repeater {
                model: [
                    {key: "restart", label: "Yeniden Başlat", hint: "Sistemi kapatıp tekrar açar.", icon: "refresh"},
                    {key: "shutdown", label: "Sistemi Kapat", hint: "AtlasOS'yi güvenli şekilde kapatır.", icon: "power"},
                    {key: "logout", label: "Oturumu Kapat", hint: "Bu oturumdan çıkış yapar.", icon: "arrow-right"}
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: (parent.width - 28) / 3; height: parent.height; radius: theme.radiusLarge
                    color: menu.pendingAction === modelData.key ? (modelData.key === "shutdown" ? "#a83255" : theme.atlasBlueHover) : modelData.key === "restart" ? theme.atlasBlue : modelData.key === "shutdown" ? "#6b314a" : theme.shellRaised
                    border.color: menu.pendingAction === modelData.key ? (modelData.key === "shutdown" ? theme.danger : "#68b8ff") : theme.shellLine
                    AtlasIcon { anchors.horizontalCenter: parent.horizontalCenter; y: 28; width: 44; height: 44; name: modelData.icon; strokeColor: "white" }
                    Text { x: 12; y: 91; width: parent.width - 24; horizontalAlignment: Text.AlignHCenter; text: modelData.label; color: "white"; font.pixelSize: menu.parent.width < 1450 ? 17 : 19; font.bold: true; elide: Text.ElideRight }
                    Text { x: 14; y: 130; width: parent.width - 28; horizontalAlignment: Text.AlignHCenter; text: modelData.hint; color: theme.shellMutedText; font.pixelSize: 13; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                    MouseArea { anchors.fill: parent; onClicked: menu.pendingAction = modelData.key }
                }
            }
        }
        Rectangle { width: parent.width; height: 1; color: theme.shellLine }
        Row { width: parent.width; height: 52; spacing: 14
            Text { width: parent.width - 286; anchors.verticalCenter: parent.verticalCenter; text: menu.pendingAction ? "Seçilen işlem: " + (menu.pendingAction === "restart" ? "Yeniden Başlat" : menu.pendingAction === "shutdown" ? "Sistemi Kapat" : "Oturumu Kapat") : "Bir işlem seçin."; color: theme.shellMutedText; font.pixelSize: 14; elide: Text.ElideRight }
            AtlasButton { width: 120; height: 50; text: "İptal"; variant: "darkSecondary"; onClicked: menu.close() }
            AtlasButton { width: 146; height: 50; text: "Onayla"; variant: menu.pendingAction === "shutdown" ? "danger" : "primary"; enabled: menu.pendingAction !== ""; onClicked: { menu.actionRequested(menu.pendingAction); menu.close() } }
        }
    }
}
