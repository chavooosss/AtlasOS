import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Item {
    id: quick
    objectName: "atlasQuickSettings"
    property var audioController: null
    property var networkController: null
    property string networkState: "Bilinmiyor"
    property bool compact: false
    signal networkRequested()
    signal settingsRequested()
    signal powerRequested()
    implicitHeight: compact ? 520 : 600
    AtlasTheme { id: theme }

    readonly property string activeWifi: {
        if (!networkController) return ""
        for (var i = 0; i < networkController.networks.length; i++)
            if (networkController.networks[i].active) return networkController.networks[i].ssid
        return ""
    }

    Column {
        anchors.fill: parent
        spacing: quick.compact ? 12 : 16
        Row {
            width: parent.width; height: 56; spacing: 10
            Text { width: parent.width - 122; anchors.verticalCenter: parent.verticalCenter; text: "Hızlı Ayarlar"; color: theme.ink; font.family: theme.fontFamily; font.pixelSize: quick.compact ? 23 : 27; font.bold: true }
            Rectangle {
                width: 52; height: 52; radius: 12; color: theme.surfaceMuted; border.color: theme.borderSubtle
                AtlasIcon { anchors.centerIn: parent; name: "settings"; width: 27; height: 27; strokeColor: theme.atlasNavy }
                MouseArea { anchors.fill: parent; onClicked: quick.settingsRequested() }
            }
            Rectangle {
                width: 52; height: 52; radius: 12; color: theme.surfaceMuted; border.color: theme.borderSubtle
                AtlasIcon { anchors.centerIn: parent; name: "power"; width: 27; height: 27; strokeColor: theme.atlasNavy }
                MouseArea { anchors.fill: parent; onClicked: quick.powerRequested() }
            }
        }

        Row {
            width: parent.width; height: quick.compact ? 136 : 158; spacing: 12
            Rectangle {
                width: (parent.width - 24) / 3; height: parent.height; radius: theme.radiusLarge
                color: quick.networkController && quick.networkController.wifiEnabled ? theme.atlasBlue : theme.surfaceMuted
                border.color: quick.networkController && quick.networkController.wifiEnabled ? theme.atlasBlueHover : theme.borderSubtle
                AtlasIcon { x: 18; y: 19; width: 35; height: 35; name: "network"; strokeColor: parent.color === theme.atlasBlue ? "white" : theme.atlasNavy }
                Text { x: 18; y: parent.height - 74; text: "Wi-Fi"; color: parent.color === theme.atlasBlue ? "white" : theme.ink; font.pixelSize: 19; font.bold: true }
                Text { x: 18; y: parent.height - 46; width: parent.width - 36; text: quick.activeWifi ? quick.activeWifi + " · Bağlı" : quick.networkController && quick.networkController.wifiEnabled ? "Açık" : "Kapalı"; color: parent.color === theme.atlasBlue ? "#e3f1ff" : theme.muted; font.pixelSize: 14; elide: Text.ElideRight }
                MouseArea { anchors.fill: parent; onClicked: quick.networkRequested() }
            }
            Rectangle {
                width: (parent.width - 24) / 3; height: parent.height; radius: theme.radiusLarge; color: theme.surfaceMuted; border.color: theme.borderSubtle
                AtlasIcon { x: 18; y: 19; width: 35; height: 35; name: "network"; strokeColor: theme.atlasNavy }
                Text { x: 18; y: parent.height - 74; text: "Ethernet"; color: theme.ink; font.pixelSize: 19; font.bold: true }
                Text { x: 18; y: parent.height - 46; width: parent.width - 36; text: quick.networkController && quick.networkController.wired.carrier === "on" ? "Kablo bağlı" : "Bağlı değil"; color: theme.muted; font.pixelSize: 14; elide: Text.ElideRight }
                MouseArea { anchors.fill: parent; onClicked: quick.networkRequested() }
            }
            Rectangle {
                width: (parent.width - 24) / 3; height: parent.height; radius: theme.radiusLarge; color: theme.disabledSurface; border.color: theme.borderSubtle
                AtlasIcon { x: 18; y: 19; width: 35; height: 35; name: "bell"; strokeColor: theme.disabledInk }
                Text { x: 18; y: parent.height - 78; width: parent.width - 36; height: 38; text: "Rahatsız Etme"; color: theme.disabledInk; font.pixelSize: quick.compact ? 15 : 17; font.bold: true; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                Text { x: 18; y: parent.height - 40; width: parent.width - 36; text: "Kullanılamıyor"; color: theme.disabledInk; font.pixelSize: 13 }
            }
        }

        Row {
            width: parent.width; height: quick.compact ? 112 : 124; spacing: 12
            Rectangle {
                width: (parent.width - 12) / 2; height: parent.height; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                Column { anchors.fill: parent; anchors.margins: 17; spacing: 8
                    Row { spacing: 10; AtlasIcon { name: "bulb"; width: 25; height: 25; strokeColor: theme.disabledInk } Text { text: "Ekran Parlaklığı"; color: theme.ink; font.pixelSize: 17; font.bold: true } }
                    Text { text: "Bu cihazda kullanılamıyor"; color: theme.disabledInk; font.pixelSize: 13 }
                    Rectangle { width: parent.width - 4; height: 8; radius: 4; color: theme.disabledSurface }
                }
            }
            Rectangle {
                width: (parent.width - 12) / 2; height: parent.height; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                Column { anchors.fill: parent; anchors.margins: 17; spacing: 8
                    Row { spacing: 10; AtlasIcon { name: quick.audioController && quick.audioController.muted ? "volume-muted" : "volume"; width: 25; height: 25; strokeColor: theme.atlasNavy } Text { text: "Ses"; color: theme.ink; font.pixelSize: 17; font.bold: true } }
                    Row { width: parent.width; spacing: 8
                        AtlasSlider { id: volumeSlider; width: parent.width - 46; from: 0; to: 100; stepSize: 1; enabled: quick.audioController && quick.audioController.available; value: enabled ? quick.audioController.volume : 0; onMoved: quick.audioController.setVolume(Math.round(value)) }
                        Text { width: 38; text: Math.round(volumeSlider.value) + "%"; color: theme.muted; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: quick.audioController && quick.audioController.available ? (quick.audioController.muted ? "Sessiz · Açmak için dokunun" : "Sessize almak için dokunun") : "Ses aygıtı kullanılamıyor"; color: theme.muted; font.pixelSize: 12 }
                }
                MouseArea { x: 0; y: 0; width: parent.width; height: 51; enabled: quick.audioController && quick.audioController.available; onClicked: quick.audioController.toggleMute() }
            }
        }

        Row { width: parent.width; height: quick.compact ? 108 : 130; spacing: 12
            Repeater { model: [
                {label: "Bluetooth", icon: "network"},
                {label: "Uçak Modu", icon: "network"},
                {label: "Gece Işığı", icon: "bulb"},
                {label: "Ekran Yansıtma", icon: "screen-draw"}
            ]; delegate: Rectangle { required property var modelData; width: (parent.width - 36) / 4; height: parent.height; radius: theme.radiusLarge; color: theme.disabledSurface; border.color: theme.borderSubtle
                AtlasIcon { x: 15; y: 16; width: 29; height: 29; name: modelData.icon; strokeColor: theme.disabledInk }
                Text { x: 15; y: parent.height - 60; width: parent.width - 30; height: 34; text: modelData.label; color: theme.disabledInk; font.pixelSize: quick.compact ? 12 : 14; font.bold: true; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                Text { x: 15; y: parent.height - 25; text: "Kullanılamıyor"; color: theme.disabledInk; font.pixelSize: 11 }
            } }
        }
        Row { width: parent.width; height: quick.compact ? 54 : 60; spacing: 12
            AtlasButton { width: (parent.width - 12) / 2; height: parent.height; text: "Ağ Ayarları"; iconName: "network"; variant: "secondary"; onClicked: quick.networkRequested() }
            AtlasButton { width: (parent.width - 12) / 2; height: parent.height; text: "Sistem Ayarları"; iconName: "settings"; variant: "secondary"; onClicked: quick.settingsRequested() }
        }
    }
    Connections { target: quick.audioController; function onChanged() { if (quick.audioController && !volumeSlider.pressed) volumeSlider.value = quick.audioController.volume } }
}
