import QtQuick
import "../theme"

Rectangle {
    id: navigation
    property string selected: "home"
    property bool compact: false
    property bool boardMode: false
    property real density: 1.0
    signal sectionRequested(string key)
    color: theme.surfaceRaised
    border.color: theme.borderSubtle
    radius: theme.radiusLarge
    AtlasTheme { id: theme }
    readonly property var sections: [
        {key: "home", label: "Sistem", hint: "Genel ayarlar", icon: "settings"},
        {key: "display", label: "Görünüm", hint: "Ekran ve boyut", icon: "display"},
        {key: "network", label: "Ağ", hint: "Wi-Fi ve Ethernet", icon: "network"},
        {key: "sound", label: "Ses", hint: "Çıkış ve açılış", icon: "volume"},
        {key: "access", label: "Erişilebilirlik", hint: "Kalem ve dokunma", icon: "pen"},
        {key: "about", label: "Hakkında", hint: "Sistem bilgileri", icon: "help"},
        {key: "developer", label: "Geliştirici", hint: "Güvenli tanılama", icon: "developer"}
    ]
    Flickable {
        anchors.fill: parent; anchors.margins: 10 * navigation.density
        clip: true; contentWidth: width; contentHeight: menu.implicitHeight + 8 * navigation.density
        Column {
            id: menu; width: parent.width; spacing: 5 * navigation.density
            Repeater { model: navigation.sections
                delegate: Rectangle {
                    required property var modelData
                    width: menu.width; height: (navigation.compact ? 62 : 74) * navigation.density; radius: theme.radiusMedium
                    color: navigation.selected === modelData.key ? theme.atlasBlueSoft : "transparent"
                    Rectangle { visible: navigation.selected === modelData.key; width: 4 * navigation.density; height: parent.height - 14 * navigation.density; x: 0; y: 7 * navigation.density; radius: 2 * navigation.density; color: theme.atlasBlue }
                    AtlasIcon { x: 15 * navigation.density; anchors.verticalCenter: parent.verticalCenter; width: 25 * navigation.density; height: width; name: modelData.icon; strokeColor: navigation.selected === modelData.key ? theme.atlasBlue : theme.atlasNavy }
                    Column { x: 15 * navigation.density + 36 * navigation.density; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - 9 * navigation.density; spacing: 3 * navigation.density
                        Text { width: parent.width; text: modelData.label; color: navigation.selected === modelData.key ? theme.atlasBlue : theme.ink; font.pixelSize: (navigation.compact ? 15 : 16) * navigation.density; font.bold: true; elide: Text.ElideRight }
                        Text { width: parent.width; text: modelData.hint; color: theme.muted; font.pixelSize: 12 * navigation.density; elide: Text.ElideRight }
                    }
                    MouseArea { anchors.fill: parent; onClicked: navigation.sectionRequested(modelData.key) }
                }
            }
        }
    }
}
