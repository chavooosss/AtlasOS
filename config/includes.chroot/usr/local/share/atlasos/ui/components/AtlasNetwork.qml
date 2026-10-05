import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import "../theme"

Rectangle {
    id: panel
    color: theme.canvas
    AtlasTheme { id: theme }
    property string selectedSsid: ""
    function connectivityLabel(value) {
        if (value === "full") return "NetworkManager: İnternet denetimi başarılı"
        if (value === "limited") return "NetworkManager: İnternet erişimi sınırlı"
        if (value === "portal") return "NetworkManager: Ağ giriş sayfası gerekli"
        if (value === "none") return "NetworkManager: İnternet erişimi yok"
        return "NetworkManager: Denetim sonucu alınamadı"
    }
    function requestPassword(ssid) { selectedSsid = ssid; wifiPassword.text = ""; wifiDialog.open() }
    Controls.Dialog {
        id: wifiDialog; title: "Wi-Fi parolası"; modal: true; anchors.centerIn: parent
        standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel
        width: Math.min(440, panel.width - 40)
        Column { spacing: 12; width: parent.width
            Controls.Label { text: "“" + panel.selectedSsid + "” ağına bağlan"; width: parent.width; wrapMode: Text.WordWrap }
            Controls.TextField { id: wifiPassword; width: parent.width; height: 64; font.pixelSize: 18; echoMode: TextInput.Password; placeholderText: "Parola"; onAccepted: wifiDialog.accept() }
        }
        onAccepted: { atlasNetwork.connectSecure(panel.selectedSsid, wifiPassword.text); wifiPassword.text = "" }
        onRejected: wifiPassword.text = ""
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 24
        contentWidth: width
        contentHeight: Math.max(height, column.height)
        clip: true

        Column {
            id: column
            width: parent.width
            spacing: 14

            Text { text: "Ağ Bağlantıları"; color: theme.ink; font.pixelSize: 28; font.bold: true }
            Text {
                width: parent.width
                text: "İnternet denetimi tüm sistem bağlantısını ölçer; Ethernet'e özel değildir. Kablo, IP, ağ geçidi ve DNS bilgileriyle birlikte değerlendirin."
                color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap
            }
            Text { text: "Kablolu ağ"; color: theme.ink; font.pixelSize: 21; font.bold: true }
            Rectangle {
                width: parent.width; height: wiredDetails.height + 32; radius: 6
                color: "white"; border.color: theme.line
                Column {
                    id: wiredDetails
                    x: 16; y: 16; width: parent.width - 32; spacing: 7
                    Text { text: "Durum: " + atlasNetwork.wired.state; color: theme.ink; font.pixelSize: 18; font.bold: true }
                    Text { text: "Aygıt: " + (atlasNetwork.wired.device || "Yok") + "    Kablo: " + (atlasNetwork.wired.carrier || "Bilinmiyor"); color: theme.ink; font.pixelSize: 16 }
                    Text { text: "IP: " + (atlasNetwork.wired.address || "Alınmadı"); color: theme.ink; font.pixelSize: 16 }
                    Text { text: "Ağ geçidi: " + (atlasNetwork.wired.gateway || "Yok"); color: theme.ink; font.pixelSize: 16 }
                    Text { text: "DNS: " + (atlasNetwork.wired.dns || "Yok"); color: theme.ink; font.pixelSize: 16; width: parent.width; elide: Text.ElideRight }
                    Text {
                        text: panel.connectivityLabel(atlasNetwork.wired.connectivity)
                        color: atlasNetwork.wired.connectivity === "full" ? "#138567" : theme.red
                        font.pixelSize: 16; font.bold: true; width: parent.width; wrapMode: Text.WordWrap
                    }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; color: theme.muted; font.pixelSize: 14
                        text: !atlasNetwork.wired.device ? "Ethernet aygıtı algılanmadı." :
                              atlasNetwork.wired.carrier === "off" ? "Kablo veya port bağlantısını kontrol edin." :
                              !atlasNetwork.wired.address ? "Kablo algılandıysa DHCP yapılandırmasını kontrol edin." :
                              !atlasNetwork.wired.gateway ? "IP var; ağ geçidi verilmemiş." :
                              !atlasNetwork.wired.dns ? "IP ve geçit var; DNS verilmemiş." :
                              "Yerel ağ yapılandırması var. İnternet erişimi için ağ kısıtı veya proxy ayrıca incelenmeli."
                    }
                }
            }
            Text { text: "Kablosuz ağlar"; color: theme.ink; font.pixelSize: 21; font.bold: true }

            Row {
                spacing: 10
                Button { width: 140; height: 64; font.pixelSize: 17; text: atlasNetwork.busy ? "Taranıyor..." : "Yenile"; enabled: !atlasNetwork.busy; onClicked: atlasNetwork.refresh() }
                Button { width: 210; height: 64; font.pixelSize: 17; text: atlasNetwork.internetProbeBusy ? "Sınanıyor…" : "İnterneti Sına"; enabled: !atlasNetwork.internetProbeBusy; onClicked: atlasNetwork.testInternet() }
            }

            Rectangle {
                width: parent.width; height: 64; radius: 8; color: "#eaf2fb"
                Text { anchors.fill: parent; anchors.margins: 14; verticalAlignment: Text.AlignVCenter; text: atlasNetwork.internetProbeResult; color: theme.ink; font.pixelSize: 16; wrapMode: Text.WordWrap }
            }

            Text {
                width: parent.width
                visible: atlasNetwork.message.length > 0
                text: atlasNetwork.message
                color: theme.muted
                wrapMode: Text.WordWrap
                font.pixelSize: 14
            }

            Repeater {
                model: atlasNetwork.networks
                delegate: Rectangle {
                    width: column.width
                    height: 80
                    radius: 6
                    color: "white"
                    border.color: theme.line
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        spacing: 16
                        Text {
                            width: Math.max(120, parent.width - connectButton.width - 50)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.ssid + (modelData.active ? "  •  Bağlı" : "")
                            color: theme.ink
                            font.pixelSize: 17
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Button {
                            id: connectButton
                            width: 110
                            height: 64
                            font.pixelSize: 17
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.active ? "Bağlı" : "Bağlan"
                            enabled: !modelData.active && !atlasNetwork.busy
                            onClicked: modelData.security === "--" ? atlasNetwork.connectTo(modelData.ssid) : panel.requestPassword(modelData.ssid)
                        }
                    }
                }
            }
            Text {
                width: parent.width
                text: "Şifreli ağ parolası Atlas içinde istenir; parola komut satırı geçmişine eklenmez."
                color: theme.muted
                wrapMode: Text.WordWrap
                font.pixelSize: 13
            }
        }
    }
}
