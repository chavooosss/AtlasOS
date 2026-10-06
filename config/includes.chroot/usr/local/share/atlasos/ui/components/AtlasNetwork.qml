import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Rectangle {
    id: panel
    objectName: "atlasNetworkPage"
    property bool boardMode: false
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
        width: Math.min(520, panel.width - 48); padding: 24
        background: Rectangle { color: theme.surface; radius: theme.radiusPanel; border.color: theme.borderSubtle }
        Column { width: parent.width; spacing: 16
            Text { text: "“" + panel.selectedSsid + "” için parola"; color: theme.ink; font.pixelSize: 18 }
            Controls.TextField { id: wifiPassword; width: parent.width; height: 60; echoMode: TextInput.Password; placeholderText: "Parola"; onAccepted: wifiDialog.accept() }
        }
        onAccepted: { atlasNetwork.connectSecure(panel.selectedSsid, wifiPassword.text); wifiPassword.text = "" }
        onRejected: wifiPassword.text = ""
    }

    Row {
        anchors.fill: parent; anchors.margins: panel.width < 1450 ? 16 : 24; spacing: 20
        AtlasSettingsNav {
            id: settingsNav; width: panel.width < 1450 ? 224 : 274; height: parent.height
            compact: panel.width < 1450; selected: "network"
            onSectionRequested: function(key) { panel.settingsSectionRequested(key) }
        }
        Flickable {
            id: scroll; width: parent.width - settingsNav.width - parent.spacing; height: parent.height
            clip: true; contentWidth: width; contentHeight: content.implicitHeight + 24
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: content; width: scroll.width; spacing: 16
                Row { width: parent.width; height: 76; spacing: 15
                    AtlasIcon { anchors.verticalCenter: parent.verticalCenter; width: 43; height: 43; name: "network"; strokeColor: theme.atlasNavy }
                    Column { anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: "Ağ"; color: theme.ink; font.pixelSize: 30; font.bold: true }
                        Text { text: "İnternet bağlantınızı yönetin ve ağ ayarlarınızı düzenleyin."; color: theme.muted; font.pixelSize: 15 }
                    }
                }
                Rectangle {
                    width: parent.width; height: panel.width < 1450 ? 160 : 190
                    radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                    Row { x: 22; y: 19; spacing: 16
                        Rectangle { width: 55; height: 55; radius: 14; color: theme.atlasBlueSoft
                            AtlasIcon { anchors.centerIn: parent; name: "network"; width: 30; height: 30; strokeColor: theme.atlasBlue }
                        }
                        Column { anchors.verticalCenter: parent.verticalCenter; spacing: 4
                            Text { text: panel.connected ? "Bağlantı etkin" : "Bağlantı yok"; color: panel.connected ? theme.success : theme.ink; font.pixelSize: 21; font.bold: true }
                            Text { text: panel.connected ? (atlasNetwork.active.connection || panel.connectionType) + " üzerinden bağlı" : (atlasNetwork.active.state || "Etkin bağlantı bulunamadı"); color: theme.muted; font.pixelSize: 14 }
                        }
                    }
                    Rectangle { x: 22; y: parent.height - 75; width: parent.width - 44; height: 1; color: theme.borderSubtle }
                    Row { x: 22; y: parent.height - 62; width: parent.width - 44; height: 50; spacing: 0
                        Repeater { model: [
                            {label: "Bağlantı", value: panel.connectionType},
                            {label: "IP adresi", value: atlasNetwork.active.address || "Alınmadı"},
                            {label: "Ağ geçidi", value: atlasNetwork.active.gateway || "—"},
                            {label: "DNS", value: atlasNetwork.active.dns || "—"},
                            {label: "Arayüz", value: atlasNetwork.active.device || "—"}
                        ]; delegate: Column { required property var modelData; width: parent.width / 5; spacing: 5
                            Text { width: parent.width - 8; text: modelData.label; color: theme.muted; font.pixelSize: 12; elide: Text.ElideRight }
                            Text { width: parent.width - 8; text: modelData.value; color: theme.ink; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
                        } }
                    }
                }
                Row {
                    width: parent.width; spacing: 16
                    Rectangle {
                        width: (parent.width - 16) / 2; height: panel.width < 1450 ? 350 : 410
                        radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                        Column { anchors.fill: parent; anchors.margins: 20; spacing: 10
                            Row { width: parent.width; height: 50; spacing: 12
                                Rectangle { width: 45; height: 45; radius: 12; color: theme.atlasBlue
                                    AtlasIcon { anchors.centerIn: parent; name: "network"; width: 27; height: 27; strokeColor: "white" } }
                                Column { width: parent.width - wifiSwitch.width - 65; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                                    Text { text: "Wi-Fi"; color: theme.ink; font.pixelSize: 21; font.bold: true }
                                    Text { width: parent.width; text: atlasNetwork.wifiRadioAvailable ? (atlasNetwork.wifiEnabled ? "Kablosuz ağ açık" : "Kablosuz ağ kapalı") : "Denetleyici bulunamadı"; color: theme.muted; font.pixelSize: 13; elide: Text.ElideRight }
                                }
                                AtlasSwitch { id: wifiSwitch; anchors.verticalCenter: parent.verticalCenter; checked: atlasNetwork.wifiEnabled; enabled: atlasNetwork.wifiRadioAvailable && !atlasNetwork.busy; onToggled: atlasNetwork.toggleWifi() }
                            }
                            Rectangle { width: parent.width; height: 55; radius: 10; color: theme.surfaceMuted
                                Text { anchors.fill: parent; anchors.margins: 13; verticalAlignment: Text.AlignVCenter; text: panel.activeWifi ? panel.activeWifi + " · Bağlı" : "Bağlı Wi-Fi ağı yok"; color: panel.activeWifi ? theme.success : theme.muted; font.pixelSize: 15; font.bold: panel.activeWifi.length > 0; elide: Text.ElideRight }
                            }
                            Row { width: parent.width; height: 39
                                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - scanButton.width; text: "Kullanılabilir ağlar"; color: theme.ink; font.pixelSize: 16; font.bold: true }
                                AtlasButton { id: scanButton; width: 138; height: 39; text: atlasNetwork.busy ? "Taranıyor" : "Yeniden Tara"; iconName: "refresh"; variant: "quiet"; enabled: !atlasNetwork.busy; onClicked: atlasNetwork.refresh() }
                            }
                            ListView { width: parent.width; height: parent.height - 194; clip: true; model: atlasNetwork.networks; spacing: 4
                                delegate: Rectangle { required property var modelData; width: ListView.view.width; height: 47; radius: 9; color: modelData.active ? theme.atlasBlueSoft : theme.surfaceRaised
                                    Row { anchors.fill: parent; anchors.margins: 9; spacing: 9
                                        AtlasIcon { anchors.verticalCenter: parent.verticalCenter; name: "network"; width: 23; height: 23; strokeColor: modelData.active ? theme.atlasBlue : theme.atlasNavy }
                                        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - join.width - 45; text: modelData.ssid || "Gizli ağ"; color: theme.ink; font.pixelSize: 14; font.bold: modelData.active; elide: Text.ElideRight }
                                        AtlasButton { id: join; anchors.verticalCenter: parent.verticalCenter; width: 108; height: 38; text: modelData.active ? "Bağlı" : "Bağlan"; variant: modelData.active ? "quiet" : "secondary"; enabled: !modelData.active && !atlasNetwork.busy && atlasNetwork.wifiEnabled; onClicked: modelData.security === "--" ? atlasNetwork.connectTo(modelData.ssid) : panel.requestPassword(modelData.ssid) }
                                    }
                                }
                                Text { anchors.centerIn: parent; visible: atlasNetwork.networks.length === 0; text: atlasNetwork.busy ? "Ağlar taranıyor…" : "Yakında ağ bulunamadı"; color: theme.muted; font.pixelSize: 14 }
                            }
                        }
                    }
                    Rectangle {
                        width: (parent.width - 16) / 2; height: panel.width < 1450 ? 350 : 410
                        radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                        Column { anchors.fill: parent; anchors.margins: 20; spacing: 12
                            Row { width: parent.width; height: 50; spacing: 12
                                Rectangle { width: 45; height: 45; radius: 12; color: theme.atlasBlueSoft
                                    AtlasIcon { anchors.centerIn: parent; name: "network"; width: 27; height: 27; strokeColor: theme.atlasNavy } }
                                Column { anchors.verticalCenter: parent.verticalCenter; spacing: 3
                                    Text { text: "Ethernet"; color: theme.ink; font.pixelSize: 21; font.bold: true }
                                    Text { text: "Kablolu ağ bağlantısı"; color: theme.muted; font.pixelSize: 13 }
                                }
                            }
                            Rectangle { width: parent.width; height: 60; radius: 10; color: theme.surfaceMuted
                                Column { x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                                    Text { text: atlasNetwork.wired.carrier === "on" ? "Kablo bağlı" : "Kablo bağlı değil"; color: atlasNetwork.wired.carrier === "on" ? theme.success : theme.ink; font.pixelSize: 16; font.bold: true }
                                    Text { text: atlasNetwork.wired.state || "Durum bilinmiyor"; color: theme.muted; font.pixelSize: 13 }
                                }
                            }
                            Repeater { model: [
                                {label: "Arayüz", value: atlasNetwork.wired.device || "Algılanmadı"},
                                {label: "IP adresi", value: atlasNetwork.wired.address || "Alınmadı"},
                                {label: "Ağ geçidi", value: atlasNetwork.wired.gateway || "—"},
                                {label: "DNS", value: atlasNetwork.wired.dns || "—"},
                                {label: "IP ayarı", value: atlasNetwork.wired.dhcp || "Bilinmiyor"}
                            ]; delegate: Row { required property var modelData; width: parent.width; height: 24
                                Text { width: parent.width * 0.37; text: modelData.label; color: theme.muted; font.pixelSize: 13 }
                                Text { width: parent.width * 0.63; text: modelData.value; color: theme.ink; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight }
                            } }
                            AtlasButton { width: parent.width; height: 48; text: "Yeniden Dene"; iconName: "refresh"; variant: "secondary"; enabled: !atlasNetwork.busy && atlasNetwork.wired.device.length > 0; onClicked: atlasNetwork.reconnectWired() }
                        }
                    }
                }
                Text { visible: atlasNetwork.message.length > 0; width: parent.width; text: atlasNetwork.message; color: theme.atlasBlue; font.pixelSize: 14; wrapMode: Text.WordWrap }
                Row { width: parent.width; height: 64; spacing: 16
                    Rectangle { width: (parent.width - 16) / 2; height: parent.height; radius: theme.radiusMedium; color: theme.disabledSurface; border.color: theme.borderSubtle
                        Text { anchors.centerIn: parent; text: "Proxy ayarları · Bu sürümde kullanılamıyor"; color: theme.disabledInk; font.pixelSize: 14 } }
                    Rectangle { width: (parent.width - 16) / 2; height: parent.height; radius: theme.radiusMedium; color: theme.disabledSurface; border.color: theme.borderSubtle
                        Text { anchors.centerIn: parent; text: "VPN · Bu sürümde kullanılamıyor"; color: theme.disabledInk; font.pixelSize: 14 } }
                }
            }
        }
    }
}
