import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Rectangle {
    id: panel
    color: theme.canvas
    property bool boardMode: false
    property string selectedSsid: ""
    AtlasTheme { id: theme }

    function connectivityLabel(value) {
        if (value === "full") return "İnternet erişimi kullanılabilir"
        if (value === "limited") return "İnternet erişimi sınırlı"
        if (value === "portal") return "Ağ giriş sayfası gerekli"
        if (value === "none") return "İnternet erişimi yok"
        return "İnternet durumu henüz doğrulanmadı"
    }
    function requestPassword(ssid) {
        selectedSsid = ssid
        wifiPassword.text = ""
        wifiDialog.open()
    }

    Controls.Dialog {
        id: wifiDialog
        title: "Wi-Fi parolası"
        modal: true
        anchors.centerIn: parent
        standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel
        width: Math.min(500, panel.width - 48)
        padding: 24
        background: Rectangle { color: theme.surface; radius: theme.radiusPanel; border.color: theme.line }
        Column {
            width: parent.width
            spacing: 14
            Controls.Label { text: "“" + panel.selectedSsid + "” ağına bağlan"; width: parent.width; wrapMode: Text.WordWrap; font.pixelSize: 18; color: theme.ink }
            Controls.TextField { id: wifiPassword; width: parent.width; height: 68; font.pixelSize: 20; echoMode: TextInput.Password; placeholderText: "Parola"; onAccepted: wifiDialog.accept() }
        }
        onAccepted: { atlasNetwork.connectSecure(panel.selectedSsid, wifiPassword.text); wifiPassword.text = "" }
        onRejected: wifiPassword.text = ""
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: panel.boardMode ? 30 : 24
        contentWidth: width
        contentHeight: content.implicitHeight + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width
            spacing: panel.boardMode ? 20 : 16

            Column {
                width: parent.width
                spacing: 6
                Text { text: "Ağ ve internet"; color: theme.ink; font.family: theme.fontFamily; font.pixelSize: panel.boardMode ? 34 : 30; font.bold: true }
                Text {
                    width: parent.width
                    text: "Ethernet ve Wi-Fi durumunu tek yerde görün, bağlantıyı yenileyin. İnternet denetimi tüm sistem bağlantısını ölçer; Ethernet'e özel değildir."
                    color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 15; wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                width: parent.width; height: panel.boardMode ? 104 : 92
                radius: theme.radiusPanel; color: theme.navy
                Row {
                    anchors.fill: parent; anchors.margins: 18; spacing: 18
                    Column {
                        width: (parent.width - 36) / 3; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                        Text { text: "ETKİN ARAYÜZ"; color: theme.shellMutedText; font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.5 }
                        Text { width: parent.width; text: atlasNetwork.active.device ? (atlasNetwork.active.type === "wifi" ? "Wi-Fi · " : "Ethernet · ") + atlasNetwork.active.device : atlasNetwork.active.state; color: theme.shellText; font.pixelSize: 16; font.bold: true; elide: Text.ElideRight }
                    }
                    Column {
                        width: (parent.width - 36) / 3; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                        Text { text: "ETKİN IP ADRESİ"; color: theme.shellMutedText; font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.5 }
                        Text { width: parent.width; text: atlasNetwork.active.address || "Henüz alınmadı"; color: theme.shellText; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
                    }
                    Column {
                        width: (parent.width - 36) / 3; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                        Text { text: "IP YAPILANDIRMASI"; color: theme.shellMutedText; font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.5 }
                        Text { width: parent.width; text: atlasNetwork.active.dhcp || "Bilinmiyor"; color: theme.shellText; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 14
                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: ethernetInfo.implicitHeight + 36
                    radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                    Column {
                        id: ethernetInfo
                        x: 18; y: 18; width: parent.width - 36; spacing: 9
                        Row {
                            width: parent.width; spacing: 10
                            AtlasIcon { width: 26; height: 26; name: "network"; strokeColor: theme.blue }
                            Text { width: parent.width - 36; text: "Ethernet"; color: theme.ink; font.pixelSize: 20; font.bold: true; verticalAlignment: Text.AlignVCenter }
                        }
                        Text { text: atlasNetwork.wired.state || "Durum bilinmiyor"; color: /connected|bağlı/i.test(atlasNetwork.wired.state) ? theme.green : theme.muted; font.pixelSize: 16; font.bold: true }
                        Text { width: parent.width; text: "Aygıt: " + (atlasNetwork.wired.device || "Algılanmadı") + "   ·   Kablo: " + (atlasNetwork.wired.carrier === "on" ? "Bağlı" : atlasNetwork.wired.carrier === "off" ? "Bağlı değil" : "Bilinmiyor"); color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
                        Rectangle { width: parent.width; height: 1; color: theme.line }
                        Row { width: parent.width; spacing: 8; Text { text: "IP adresi"; color: theme.muted; font.pixelSize: 14 } Text { text: atlasNetwork.wired.address || "Henüz alınmadı"; color: theme.ink; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; width: parent.width - 112 } }
                        Row { width: parent.width; spacing: 8; Text { text: "IP ayarı"; color: theme.muted; font.pixelSize: 14 } Text { text: atlasNetwork.wired.dhcp || "Bilinmiyor"; color: theme.ink; font.pixelSize: 14; font.bold: true } }
                        Text { visible: atlasNetwork.wired.gateway.length > 0; width: parent.width; text: "Ağ geçidi: " + atlasNetwork.wired.gateway; color: theme.muted; font.pixelSize: 13; elide: Text.ElideRight }
                        Text { visible: atlasNetwork.wired.state === "connected" && atlasNetwork.wired.connectivity !== "full"; width: parent.width; text: panel.connectivityLabel(atlasNetwork.wired.connectivity); color: theme.amber; font.pixelSize: 14; wrapMode: Text.WordWrap }
                        AtlasButton { width: parent.width; text: atlasNetwork.busy ? "Bağlantı denetleniyor…" : "Ethernet bağlantısını yeniden dene"; iconName: "refresh"; controlScale: panel.boardMode ? 1.08 : 1; enabled: !atlasNetwork.busy && atlasNetwork.wired.device.length > 0; onClicked: atlasNetwork.reconnectWired() }
                    }
                }

                Rectangle {
                    width: (parent.width - parent.spacing) / 2
                    height: wifiInfo.implicitHeight + 36
                    radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                    Column {
                        id: wifiInfo
                        x: 18; y: 18; width: parent.width - 36; spacing: 10
                        Row {
                            width: parent.width; spacing: 10
                            AtlasIcon { width: 26; height: 26; name: "network"; strokeColor: theme.blue }
                            Text { width: parent.width - wifiToggle.width - 46; text: "Wi-Fi"; color: theme.ink; font.pixelSize: 20; font.bold: true; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                            AtlasButton { id: wifiToggle; width: panel.boardMode ? 164 : 146; text: atlasNetwork.wifiRadioAvailable ? (atlasNetwork.wifiEnabled ? "Wi-Fi'yi kapat" : "Wi-Fi'yi aç") : "Kullanılamıyor"; controlScale: 1; enabled: atlasNetwork.wifiRadioAvailable && !atlasNetwork.busy; onClicked: atlasNetwork.toggleWifi() }
                        }
                        Text {
                            width: parent.width
                            text: !atlasNetwork.wifiRadioAvailable ? "Wi-Fi denetleyicisi bulunamadı veya durumu okunamadı." : !atlasNetwork.wifiEnabled ? "Kablosuz ağ araması kapalı." : activeWifi.length > 0 ? "Bağlı ağ: " + activeWifi : "Bağlı Wi-Fi ağı yok"
                            color: activeWifi.length > 0 ? theme.green : theme.muted; font.pixelSize: 15; font.bold: activeWifi.length > 0; wrapMode: Text.WordWrap
                            property string activeWifi: {
                                for (var i = 0; i < atlasNetwork.networks.length; i++)
                                    if (atlasNetwork.networks[i].active) return atlasNetwork.networks[i].ssid
                                return ""
                            }
                        }
                        Text { width: parent.width; text: atlasNetwork.busy ? "Ağlar taranıyor…" : atlasNetwork.networks.length + " kullanılabilir ağ"; color: theme.muted; font.pixelSize: 14 }
                        AtlasButton { width: parent.width; text: atlasNetwork.busy ? "Taranıyor…" : "Ağları tara"; iconName: "refresh"; variant: "secondary"; controlScale: panel.boardMode ? 1.08 : 1; enabled: !atlasNetwork.busy; onClicked: atlasNetwork.refresh() }
                    }
                }
            }

            Row {
                width: parent.width; spacing: 10
                Text { text: "Yakındaki ağlar"; color: theme.ink; font.pixelSize: 21; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                Item { width: Math.max(0, parent.width - 190); height: 1 }
                AtlasButton { width: 168; text: atlasNetwork.internetProbeBusy ? "Sınanıyor…" : "İnterneti sına"; variant: "quiet"; onClicked: atlasNetwork.testInternet() }
            }

            Rectangle {
                visible: atlasNetwork.internetProbeResult !== "Henüz sınanmadı"
                width: parent.width; height: Math.max(64, probeText.implicitHeight + 28); radius: theme.radiusCard; color: theme.paleBlue
                Text { id: probeText; anchors.fill: parent; anchors.margins: 16; verticalAlignment: Text.AlignVCenter; text: atlasNetwork.internetProbeResult; color: theme.ink; font.pixelSize: 15; wrapMode: Text.WordWrap }
            }

            Text { id: networkMessage; visible: atlasNetwork.message.length > 0; width: parent.width; text: atlasNetwork.message; color: networkMessage.messageError ? theme.red : theme.blue; font.pixelSize: 14; wrapMode: Text.WordWrap; property bool messageError: /yetki|başlatılamadı|tamamlanamadı|bulunamadı/i.test(atlasNetwork.message) }

            Column {
                width: parent.width; spacing: 9
                Repeater {
                    model: atlasNetwork.networks
                    delegate: Rectangle {
                        required property var modelData
                        width: content.width; height: panel.boardMode ? 82 : 74
                        radius: theme.radiusCard; color: theme.surface; border.color: modelData.active ? theme.blue : theme.line
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 14; spacing: 12
                            AtlasIcon { anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; name: "network"; strokeColor: modelData.active ? theme.green : theme.blue }
                            Column {
                                width: parent.width - joinButton.width - 60; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                Text { width: parent.width; text: modelData.ssid || "Gizli ağ"; color: theme.ink; font.pixelSize: 16; font.bold: true; elide: Text.ElideRight }
                                Text { text: modelData.active ? "Bağlı" : modelData.signal + "% sinyal · " + (modelData.security === "--" ? "Açık ağ" : "Parolalı ağ"); color: modelData.active ? theme.green : theme.muted; font.pixelSize: 13 }
                            }
                            AtlasButton {
                                id: joinButton; width: 128; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.active ? "Bağlı" : "Bağlan"; variant: modelData.active ? "quiet" : "secondary"; controlScale: panel.boardMode ? 1.05 : 1
                                enabled: !modelData.active && !atlasNetwork.busy && atlasNetwork.wifiEnabled
                                onClicked: modelData.security === "--" ? atlasNetwork.connectTo(modelData.ssid) : panel.requestPassword(modelData.ssid)
                            }
                        }
                    }
                }
                Text { visible: atlasNetwork.networks.length === 0 && !atlasNetwork.busy; width: parent.width; text: "Tarama tamamlandığında yakındaki Wi-Fi ağları burada görünür."; color: theme.muted; font.pixelSize: 15; wrapMode: Text.WordWrap }
            }
        }
    }
}
