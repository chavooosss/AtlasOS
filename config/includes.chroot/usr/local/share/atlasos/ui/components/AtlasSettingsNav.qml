import QtQuick
import "../theme"

Rectangle {
    id: navigation
    property string selected: "home"
    property bool compact: false
    signal sectionRequested(string key)
    color: theme.surfaceRaised
    border.color: theme.borderSubtle
    radius: theme.radiusLarge
    AtlasTheme { id: theme }
    readonly property var sections: [
        {key: "home", label: "Sistem", hint: "Genel ayarlar", icon: "settings"},
        {key: "display", label: "Görünüm", hint: "Ekran ve boyut", icon: "screen-draw"},
        {key: "network", label: "Ağ", hint: "Wi-Fi ve Ethernet", icon: "network"},
        {key: "sound", label: "Ses", hint: "Çıkış ve açılış", icon: "volume"},
        {key: "access", label: "Erişilebilirlik", hint: "Kalem ve dokunma", icon: "pen"},
        {key: "about", label: "Hakkında", hint: "Sistem bilgileri", icon: "help"},
        {key: "developer", label: "Geliştirici", hint: "Güvenli tanılama", icon: "settings"}
    ]
    Flickable {
        anchors.fill: parent; anchors.margins: 10
        clip: true; contentWidth: width; contentHeight: menu.implicitHeight + 8
        Column {
            id: menu; width: parent.width; spacing: 5
            Repeater { model: navigation.sections
                delegate: Rectangle {
                    required property var modelData
                    width: menu.width; height: navigation.compact ? 62 : 74; radius: theme.radiusMedium
                    color: navigation.selected === modelData.key ? theme.atlasBlueSoft : "transparent"
                    Rectangle { visible: navigation.selected === modelData.key; width: 4; height: parent.height - 14; x: 0; y: 7; radius: 2; color: theme.atlasBlue }
                    AtlasIcon { x: 15; anchors.verticalCenter: parent.verticalCenter; width: 25; height: 25; name: modelData.icon; strokeColor: navigation.selected === modelData.key ? theme.atlasBlue : theme.atlasNavy }
                    Column { x: 51; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60; spacing: 3
                        Text { width: parent.width; text: modelData.label; color: navigation.selected === modelData.key ? theme.atlasBlue : theme.ink; font.pixelSize: navigation.compact ? 15 : 16; font.bold: true; elide: Text.ElideRight }
                        Text { width: parent.width; text: modelData.hint; color: theme.muted; font.pixelSize: 12; elide: Text.ElideRight }
                    }
                    MouseArea { anchors.fill: parent; onClicked: navigation.sectionRequested(modelData.key) }
                }
            }
        }
    }
}
