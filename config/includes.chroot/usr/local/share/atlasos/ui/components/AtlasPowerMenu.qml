import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Controls.Popup {
    id: menu
    objectName: "atlasPowerMenu"
    property string pendingAction: ""
    property bool boardMode: false
    property real density: 1.0
    signal actionRequested(string action)
    modal: true; focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    padding: 24 * density
    width: Math.min(parent.width - 48, (parent.width < 1450 ? 760 : 890) * density)
    height: Math.min(parent.height - 40, (boardMode ? (parent.width < 1450 ? 450 : 480) : (parent.width < 1450 ? 382 : 428)) * density)
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
        spacing: 20 * menu.density
        Row { width: parent.width; height: 70 * menu.density; spacing: 16 * menu.density
            Image { width: 62 * menu.density; height: width; source: "../branding/atlas-symbol.png"; fillMode: Image.PreserveAspectFit }
            Column { width: 245 * menu.density; anchors.verticalCenter: parent.verticalCenter; spacing: 5 * menu.density
                Text { text: "Atlas OS"; color: "white"; font.pixelSize: 26 * menu.density; font.bold: true }
                Text { text: menu.pendingAction ? "İşlemi onaylayın" : "Oturum ve güç seçenekleri"; color: theme.shellMutedText; font.pixelSize: 14 * menu.density }
            }
            Item { width: Math.max(0, parent.width - (62 + 245 + 44 + 48) * menu.density); height: 1 }
            Rectangle { width: 44 * menu.density; height: width; radius: 10; color: theme.shellRaised
                AtlasIcon { anchors.centerIn: parent; name: "close"; width: 22; height: 22; strokeColor: "white" }
                MouseArea { anchors.fill: parent; onClicked: menu.close() }
            }
        }
        Row {
            width: parent.width; height: (menu.parent.width < 1450 ? 202 : 228) * menu.density; spacing: 14 * menu.density
            Repeater {
                model: [
                    {key: "restart", label: "Yeniden Başlat", hint: "Sistemi kapatıp tekrar açar.", icon: "refresh"},
                    {key: "shutdown", label: "Sistemi Kapat", hint: "AtlasOS'yi güvenli şekilde kapatır.", icon: "power"},
                    {key: "logout", label: "Oturumu Kapat", hint: "Bu oturumdan çıkış yapar.", icon: "logout"}
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: (parent.width - 2 * parent.spacing) / 3; height: parent.height; radius: theme.radiusLarge
                    color: menu.pendingAction === modelData.key ? (modelData.key === "shutdown" ? "#a83255" : theme.atlasBlueHover) : modelData.key === "restart" ? theme.atlasBlue : modelData.key === "shutdown" ? "#6b314a" : theme.shellRaised
                    border.color: menu.pendingAction === modelData.key ? (modelData.key === "shutdown" ? theme.danger : "#68b8ff") : theme.shellLine
                    AtlasIcon { anchors.horizontalCenter: parent.horizontalCenter; y: 28 * menu.density; width: 44 * menu.density; height: width; name: modelData.icon; strokeColor: "white" }
                    Text { x: 12; y: 91 * menu.density; width: parent.width - 24; horizontalAlignment: Text.AlignHCenter; text: modelData.label; color: "white"; font.pixelSize: (menu.parent.width < 1450 ? 17 : 19) * menu.density; font.bold: true; elide: Text.ElideRight }
                    Text { x: 14; y: 130 * menu.density; width: parent.width - 28; horizontalAlignment: Text.AlignHCenter; text: modelData.hint; color: theme.shellMutedText; font.pixelSize: 13 * menu.density; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                    MouseArea { anchors.fill: parent; onClicked: menu.pendingAction = modelData.key }
                }
            }
        }
        Rectangle { width: parent.width; height: 1; color: theme.shellLine }
        Row { width: parent.width; height: 52 * menu.density; spacing: 14 * menu.density
            Text { width: Math.max(0, parent.width - (120 + 146 + 2 * 14) * menu.density); anchors.verticalCenter: parent.verticalCenter; text: menu.pendingAction ? "Seçilen işlem: " + (menu.pendingAction === "restart" ? "Yeniden Başlat" : menu.pendingAction === "shutdown" ? "Sistemi Kapat" : "Oturumu Kapat") : "Bir işlem seçin."; color: theme.shellMutedText; font.pixelSize: 14 * menu.density; elide: Text.ElideRight }
            AtlasButton { width: 120 * menu.density; height: 50 * menu.density; text: "İptal"; variant: "darkSecondary"; controlScale: menu.density; onClicked: menu.close() }
            AtlasButton { width: 146 * menu.density; height: 50 * menu.density; text: "Onayla"; variant: menu.pendingAction === "shutdown" ? "danger" : "primary"; controlScale: menu.density; enabled: menu.pendingAction !== ""; onClicked: { menu.actionRequested(menu.pendingAction); menu.close() } }
        }
    }
}
