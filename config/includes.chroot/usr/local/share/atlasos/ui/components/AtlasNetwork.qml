import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Rectangle {
    id: panel
    objectName: "atlasNetworkPage"
    property bool boardMode: false
    property real density: 1.0
    property string selectedSsid: ""
    signal settingsSectionRequested(string key)
    color: theme.canvas
    AtlasTheme { id: theme }

    readonly property bool connected: atlasNetwork.active.device && atlasNetwork.active.address
    readonly property string connectionType: atlasNetwork.active.type === "wifi" ? "Wi-Fi" : atlasNetwork.active.type === "ethernet" ? "Ethernet" : "—"
    readonly property string activeWifi: {
        for (var i = 0; i < atlasNetwork.networks.length; i++)
            if (atlasNetwork.networks[i].active) return atlasNetwork.networks[i].ssid
        return ""
    }
    function requestPassword(ssid) { selectedSsid = ssid; wifiPassword.text = ""; wifiDialog.open() }

    Controls.Dialog {
        id: wifiDialog; title: "Wi-Fi ağına bağlan"; modal: true; anchors.centerIn: parent
        standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel
        width: Math.min(520 * panel.density, panel.width - 48 * panel.density); padding: 24 * panel.density
        background: Rectangle { color: theme.surface; radius: theme.radiusPanel; border.color: theme.borderSubtle }
        Column { width: parent.width; spacing: 16 * panel.density
            Text { text: "“" + panel.selectedSsid + "” için parola"; color: theme.ink; font.pixelSize: 18 * panel.density }
            Controls.TextField { id: wifiPassword; width: parent.width; height: 60 * panel.density; echoMode: TextInput.Password; placeholderText: "Parola"; onAccepted: wifiDialog.accept() }
        }
        onAccepted: { atlasNetwork.connectSecure(panel.selectedSsid, wifiPassword.text); wifiPassword.text = "" }
        onRejected: wifiPassword.text = ""
    }

    Row {
        anchors.fill: parent; anchors.margins: panel.width < 1450 ? 16 : 24; spacing: 20
        AtlasSettingsNav {
                boardMode: panel.boardMode
                density: panel.density
            id: settingsNav; width: Math.min(parent.width * 0.30, (panel.width < 1450 ? 224 : 274) * panel.density); height: parent.height
            compact: panel.width < 1450; selected: "network"
            onSectionRequested: function(key) { panel.settingsSectionRequested(key) }
        }
        Flickable {
            id: scroll; width: parent.width - settingsNav.width - parent.spacing; height: parent.height
            clip: true; contentWidth: width; contentHeight: content.implicitHeight + 24
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: content; width: scroll.width; spacing: 16 * panel.density
                Row { width: parent.width; height: 76 * panel.density; spacing: 15 * panel.density
                    AtlasIcon { anchors.verticalCenter: parent.verticalCenter; width: 43 * panel.density; height: 43 * panel.density; name: "network"; strokeColor: theme.atlasNavy }
                    Column { anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: "Ağ"; color: theme.ink; font.pixelSize: 30 * panel.density; font.bold: true }
                        Text { text: "İnternet bağlantınızı yönetin ve ağ ayarlarınızı düzenleyin."; color: theme.muted; font.pixelSize: 15 * panel.density }
                    }
                }
                Rectangle {
                    width: parent.width; height: (panel.width < 1450 ? 160 : 190) * panel.density
                    radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                    Row { x: 22 * panel.density; y: 19 * panel.density; spacing: 16 * panel.density
                        Rectangle { width: 55 * panel.density; height: width; radius: 14; color: theme.atlasBlueSoft
                            AtlasIcon { anchors.centerIn: parent; name: "network"; width: 30 * panel.density; height: 30 * panel.density; strokeColor: theme.atlasBlue }
                        }
                        Column { anchors.verticalCenter: parent.verticalCenter; spacing: 4
                            Text { text: panel.connected ? "Bağlantı etkin" : "Bağlantı yok"; color: panel.connected ? theme.success : theme.ink; font.pixelSize: 21 * panel.density; font.bold: true }
                            Text { text: panel.connected ? (atlasNetwork.active.connection || panel.connectionType) + " üzerinden bağlı" : (atlasNetwork.active.state || "Etkin bağlantı bulunamadı"); color: theme.muted; font.pixelSize: 14 * panel.density }
                        }
                    }
                    Rectangle { x: 22 * panel.density; y: parent.height - 75 * panel.density; width: parent.width - 44 * panel.density; height: 1; color: theme.borderSubtle }
                    Row { x: 22 * panel.density; y: parent.height - 62 * panel.density; width: parent.width - 44 * panel.density; height: 50 * panel.density; spacing: 0
                        Repeater { model: [
                            {label: "Bağlantı", value: panel.connectionType},
                            {label: "IP adresi", value: atlasNetwork.active.address || "Alınmadı"},
                            {label: "Ağ geçidi", value: atlasNetwork.active.gateway || "—"},
                            {label: "DNS", value: atlasNetwork.active.dns || "—"},
                            {label: "Arayüz", value: atlasNetwork.active.device || "—"}
                        ]; delegate: Column { required property var modelData; width: parent.width / 5; spacing: 5
                            Text { width: parent.width - 8; text: modelData.label; color: theme.muted; font.pixelSize: 12 * panel.density; elide: Text.ElideRight }
                            Text { width: parent.width - 8; text: modelData.value; color: theme.ink; font.pixelSize: 14 * panel.density; font.bold: true; elide: Text.ElideRight }
                        } }
                    }
                }
                Row {
                    width: parent.width; spacing: 16
                    Rectangle {
                        width: (parent.width - 16 * panel.density) / 2; height: (panel.width < 1450 ? 350 : 410) * panel.density
                        radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                        Column { anchors.fill: parent; anchors.margins: 20 * panel.density; spacing: 10 * panel.density
                            Row { width: parent.width; height: 58 * panel.density; spacing: 12 * panel.density
                                Rectangle { width: 45 * panel.density; height: 45 * panel.density; radius: 12 * panel.density; color: theme.atlasBlue
                                    AtlasIcon { anchors.centerIn: parent; name: "wifi"; width: 27 * panel.density; height: 27 * panel.density; strokeColor: "white" } }
                                Column { width: parent.width - wifiSwitch.width - 65 * panel.density; anchors.verticalCenter: parent.verticalCenter; spacing: 3 * panel.density
                                    Text { text: "Wi-Fi"; color: theme.ink; font.pixelSize: 21 * panel.density; font.bold: true }
                                    Text { width: parent.width; text: atlasNetwork.wifiRadioAvailable ? (atlasNetwork.wifiEnabled ? "Kablosuz ağ açık" : "Kablosuz ağ kapalı") : "Denetleyici bulunamadı"; color: theme.muted; font.pixelSize: 13 * panel.density; elide: Text.ElideRight }
                                }
                                AtlasSwitch { id: wifiSwitch; anchors.verticalCenter: parent.verticalCenter; checked: atlasNetwork.wifiEnabled; enabled: atlasNetwork.wifiRadioAvailable && !atlasNetwork.busy; onToggled: atlasNetwork.toggleWifi() }
                            }
                            Rectangle { width: parent.width; height: 55 * panel.density; radius: 10 * panel.density; color: theme.surfaceMuted
                                Text { anchors.fill: parent; anchors.margins: 13 * panel.density; verticalAlignment: Text.AlignVCenter; text: panel.activeWifi ? panel.activeWifi + " · Bağlı" : "Bağlı Wi-Fi ağı yok"; color: panel.activeWifi ? theme.success : theme.muted; font.pixelSize: 15 * panel.density; font.bold: panel.activeWifi.length > 0; elide: Text.ElideRight }
                            }
                            Row { width: parent.width; height: 39 * panel.density
                                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - scanButton.width; text: "Kullanılabilir ağlar"; color: theme.ink; font.pixelSize: 16 * panel.density; font.bold: true }
                                AtlasButton { id: scanButton; width: 176 * panel.density; height: 39 * panel.density; controlScale: panel.density; text: atlasNetwork.busy ? "Taranıyor" : "Yeniden Tara"; iconName: "refresh"; variant: "quiet"; enabled: !atlasNetwork.busy; onClicked: atlasNetwork.refresh() }
                            }
                            ListView { width: parent.width; height: parent.height - 194 * panel.density; clip: true; model: atlasNetwork.networks; spacing: 4 * panel.density
                                delegate: Rectangle { required property var modelData; width: ListView.view.width; height: 47 * panel.density; radius: 9 * panel.density; color: modelData.active ? theme.atlasBlueSoft : theme.surfaceRaised
                                    Row { anchors.fill: parent; anchors.margins: 9 * panel.density; spacing: 9 * panel.density
                                        AtlasIcon { anchors.verticalCenter: parent.verticalCenter; name: "wifi"; width: 23 * panel.density; height: 23 * panel.density; strokeColor: modelData.active ? theme.atlasBlue : theme.atlasNavy }
                                        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - join.width - 45; text: modelData.ssid || "Gizli ağ"; color: theme.ink; font.pixelSize: 14 * panel.density; font.bold: modelData.active; elide: Text.ElideRight }
                                        AtlasButton { id: join; anchors.verticalCenter: parent.verticalCenter; width: 108 * panel.density; height: 38 * panel.density; controlScale: panel.density; text: modelData.active ? "Bağlı" : "Bağlan"; variant: modelData.active ? "quiet" : "secondary"; enabled: !modelData.active && !atlasNetwork.busy && atlasNetwork.wifiEnabled; onClicked: modelData.security === "--" ? atlasNetwork.connectTo(modelData.ssid) : panel.requestPassword(modelData.ssid) }
                                    }
                                }
                                Text { anchors.centerIn: parent; visible: atlasNetwork.networks.length === 0; text: atlasNetwork.busy ? "Ağlar taranıyor…" : "Yakında ağ bulunamadı"; color: theme.muted; font.pixelSize: 14 * panel.density }
                            }
                        }
                    }
                    Rectangle {
                        width: (parent.width - 16 * panel.density) / 2; height: (panel.width < 1450 ? 350 : 410) * panel.density
                        radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                        Column { anchors.fill: parent; anchors.margins: 20 * panel.density; spacing: 12 * panel.density
                            Row { width: parent.width; height: 58 * panel.density; spacing: 12 * panel.density
                                Rectangle { width: 45 * panel.density; height: 45 * panel.density; radius: 12 * panel.density; color: theme.atlasBlueSoft
                                    AtlasIcon { anchors.centerIn: parent; name: "ethernet"; width: 27 * panel.density; height: 27 * panel.density; strokeColor: theme.atlasNavy } }
                                Column { anchors.verticalCenter: parent.verticalCenter; spacing: 3
                                    Text { text: "Ethernet"; color: theme.ink; font.pixelSize: 21 * panel.density; font.bold: true }
                                    Text { text: "Kablolu ağ bağlantısı"; color: theme.muted; font.pixelSize: 13 * panel.density }
                                }
                            }
                            Rectangle { width: parent.width; height: 60 * panel.density; radius: 10 * panel.density; color: theme.surfaceMuted
                                Column { x: 14 * panel.density; width: parent.width - 28 * panel.density; anchors.verticalCenter: parent.verticalCenter; spacing: 3 * panel.density
                                    Text { text: atlasNetwork.wired.carrier === "on" ? "Kablo bağlı" : "Kablo bağlı değil"; color: atlasNetwork.wired.carrier === "on" ? theme.success : theme.ink; font.pixelSize: 16 * panel.density; font.bold: true }
                                    Text { text: atlasNetwork.wired.state === "unmanaged" ? "Aygıt ağ yöneticisi tarafından yönetilmiyor" : (atlasNetwork.wired.state || "Durum bilinmiyor"); color: theme.muted; font.pixelSize: 13 * panel.density }
                                }
                            }
                            Repeater { model: [
                                {label: "Arayüz", value: atlasNetwork.wired.device || "Algılanmadı"},
                                {label: "IP adresi", value: atlasNetwork.wired.address || "Alınmadı"},
                                {label: "Ağ geçidi", value: atlasNetwork.wired.gateway || "—"},
                                {label: "DNS", value: atlasNetwork.wired.dns || "—"},
                                {label: "IP ayarı", value: atlasNetwork.wired.dhcp || "Bilinmiyor"}
                            ]; delegate: Row { required property var modelData; width: parent.width; height: 24 * panel.density
                                Text { width: parent.width * 0.37; text: modelData.label; color: theme.muted; font.pixelSize: 13 * panel.density }
                                Text { width: parent.width * 0.63; text: modelData.value; color: theme.ink; font.pixelSize: 13 * panel.density; font.bold: true; elide: Text.ElideRight }
                            } }
                            AtlasButton { width: parent.width; height: 48 * panel.density; text: "Yeniden Dene"; iconName: "refresh"; variant: "secondary"; controlScale: panel.density; enabled: !atlasNetwork.busy && atlasNetwork.wired.device.length > 0 && atlasNetwork.wired.state !== "unmanaged"; onClicked: atlasNetwork.reconnectWired() }
                        }
                    }
                }
                Text { visible: atlasNetwork.message.length > 0; width: parent.width; text: atlasNetwork.message; color: theme.atlasBlue; font.pixelSize: 14 * panel.density; wrapMode: Text.WordWrap }
                Row { width: parent.width; height: 64; spacing: 16
                    Rectangle { width: (parent.width - 16) / 2; height: parent.height; radius: theme.radiusMedium; color: theme.disabledSurface; border.color: theme.borderSubtle
                        Text { anchors.centerIn: parent; text: "Proxy ayarları · Bu sürümde kullanılamıyor"; color: theme.disabledInk; font.pixelSize: 14 * panel.density } }
                    Rectangle { width: (parent.width - 16) / 2; height: parent.height; radius: theme.radiusMedium; color: theme.disabledSurface; border.color: theme.borderSubtle
                        Text { anchors.centerIn: parent; text: "VPN · Bu sürümde kullanılamıyor"; color: theme.disabledInk; font.pixelSize: 14 * panel.density } }
                }
            }
        }
    }
}
