import QtQuick
import QtQuick.Controls
import "../theme"

Rectangle {
    id: header
    objectName: "atlasHeader"
    property string networkState: "Bilinmiyor"
    property string audioState: "Bilinmiyor"
    property string penState: "Algılanmadı"
    property var audioController: null
    property var networkController: null
    property bool boardMode: false
    property int notificationCount: 0
    property date currentTime: new Date()
    property bool compact: width < 1180
    Component.onCompleted: if (atlasValidateAudioPopup) audioPopup.open()
    signal networkRequested()
    signal notificationsRequested()
    signal settingsRequested()
    signal powerRequested()

    height: width < 1080 ? 66 : 74
    color: "#f7faff"
    AtlasTheme { id: theme }
    Timer { interval: 15000; running: true; repeat: true; onTriggered: header.currentTime = new Date() }

    Image {
        id: logo
        x: header.compact ? 16 : 24
        anchors.verticalCenter: parent.verticalCenter
        width: header.compact ? 168 : header.width >= 1550 ? 220 : 204
        height: header.compact ? 48 : 66
        source: "../branding/atlas-primary.png"
        sourceSize.width: 780
        sourceSize.height: 290
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Text {
        id: tagline
        anchors.left: logo.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(120, statusRow.x - x - 20)
        visible: header.width >= 1420
        text: "Daha iyi bir yarın için, bugünün sınıfında"
        color: theme.muted
        font.pixelSize: 14
        elide: Text.ElideRight
    }

    Row {
        id: statusRow
        anchors.right: clock.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: header.compact ? 8 : 16

        Item {
            id: networkItem
            width: header.compact ? 82 : 126
            height: header.height - 6
            property bool connected: /bağlı/i.test(header.networkState) || header.networkState === "Bağlı"
            property bool internetProblem: /internet yok|internet kısıtlı|ağ girişi gerekli/i.test(header.networkState)
            property string typeLabel: header.networkState.indexOf("Ethernet") >= 0 ? "Ethernet" : header.networkState.indexOf("Wi-Fi") >= 0 ? "Wi-Fi" : "Ağ"
            AtlasIcon {
                id: networkIcon
                x: 2
                anchors.verticalCenter: parent.verticalCenter
                width: header.compact ? 22 : 26
                height: header.compact ? 22 : 26
                name: "network"
                strokeColor: networkItem.internetProblem ? theme.red : networkItem.connected ? theme.green : theme.muted
            }
            Column {
                anchors.left: networkIcon.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text { text: networkItem.typeLabel; color: theme.ink; font.pixelSize: header.compact ? 12 : 13; font.bold: true }
                Text { text: networkItem.internetProblem ? (header.networkState.indexOf("ağ girişi") >= 0 ? "Ağ girişi gerekli" : header.networkState.indexOf("kısıtlı") >= 0 ? "İnternet kısıtlı" : "İnternet yok") : networkItem.connected ? "Bağlı" : header.networkState; color: networkItem.internetProblem ? theme.red : networkItem.connected ? theme.green : theme.muted; font.pixelSize: header.compact ? 11 : 12; elide: Text.ElideRight; width: networkItem.width - networkIcon.width - 10 }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (header.networkController) header.networkController.refresh()
                    if (header.audioController) header.audioController.refresh()
                    audioPopup.open()
                }
                ToolTip.visible: containsMouse
                ToolTip.text: "Ağ tanılama ve bağlantıları aç"
            }
        }

        Rectangle { width: 1; height: 36; color: theme.line; anchors.verticalCenter: parent.verticalCenter }

        Item {
            id: audioStatus
            objectName: "atlasAudioStatus"
            width: header.compact ? 78 : 90
            height: header.height - 6
            Row {
                anchors.centerIn: parent
                spacing: 7
                AtlasIcon {
                    width: 24; height: 24
                    name: !header.audioController || !header.audioController.available ? "volume-muted" : header.audioController.muted ? "volume-muted" : header.audioController.volume < 35 ? "volume-low" : "volume"
                    strokeColor: header.audioState === "Sessiz" || (header.audioController && header.audioController.muted) ? theme.red : theme.ink
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text { text: "Ses"; color: theme.ink; font.pixelSize: 13; font.bold: true }
                    Text { text: header.audioController && header.audioController.available ? (header.audioController.muted ? "Sessiz" : header.audioController.volume + "%") : header.audioState; color: header.audioController && header.audioController.available && !header.audioController.muted ? theme.green : theme.muted; font.pixelSize: 12 }
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (header.networkController) header.networkController.refresh()
                    if (header.audioController) header.audioController.refresh()
                    audioPopup.open()
                }
                ToolTip.visible: containsMouse
                ToolTip.text: "Ses düzeyini ayarla"
            }
        }

        Rectangle { width: 1; height: 36; color: theme.line; anchors.verticalCenter: parent.verticalCenter }

        Row {
            id: penStatus
            spacing: 7
            anchors.verticalCenter: parent.verticalCenter
            AtlasIcon { width: 24; height: 24; name: "pen"; strokeColor: header.penState === "Hazır" || header.penState === "Dokunmatik" ? theme.green : theme.ink }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text { text: "Kalem"; color: theme.ink; font.pixelSize: 13; font.bold: true }
                Text { text: header.penState === "Algılanmadı" ? "Hazır değil" : header.penState; color: header.penState === "Hazır" || header.penState === "Dokunmatik" ? theme.green : theme.muted; font.pixelSize: 12 }
            }
        }

        Rectangle { width: 1; height: 36; color: theme.line; anchors.verticalCenter: parent.verticalCenter }

        Item {
            width: 48; height: 58
            AtlasIcon { anchors.centerIn: parent; name: "bell"; strokeColor: theme.ink; width: 25; height: 25 }
            Rectangle {
                visible: header.notificationCount > 0
                anchors.right: parent.right; anchors.top: parent.top
                width: 19; height: 19; radius: 10; color: theme.red
                Text { anchors.centerIn: parent; text: header.notificationCount > 9 ? "9+" : header.notificationCount; color: "white"; font.pixelSize: 10; font.bold: true }
            }
            MouseArea { anchors.fill: parent; onClicked: header.notificationsRequested() }
        }
    }

    Column {
        id: clock
        anchors.right: parent.right
        anchors.rightMargin: header.compact ? 14 : 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            text: Qt.formatTime(header.currentTime, "HH:mm")
            color: theme.ink
            font.pixelSize: header.compact ? 21 : 27
            font.bold: true
            anchors.right: parent.right
        }
        Text {
            text: Qt.locale("tr_TR").toString(header.currentTime, "dd MMMM yyyy")
            color: theme.muted
            font.pixelSize: header.compact ? 10 : 12
            anchors.right: parent.right
        }
    }

    Popup {
        id: audioPopup
        objectName: "atlasAudioPopup"
        x: Math.max(12, header.width - width - 22)
        y: header.height + 8
        width: Math.min(header.width - 24, header.width < 1450 ? 506 : 594)
        padding: header.width < 1450 ? 20 : 24
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: theme.surface
            radius: theme.radiusPanel
            border.color: theme.borderSubtle
            border.width: 1
        }
        contentItem: AtlasQuickSettings {
            width: audioPopup.width - audioPopup.leftPadding - audioPopup.rightPadding
            compact: header.width < 1450
            audioController: header.audioController
            networkController: header.networkController
            networkState: header.networkState
            onNetworkRequested: { audioPopup.close(); header.networkRequested() }
            onSettingsRequested: { audioPopup.close(); header.settingsRequested() }
            onPowerRequested: { audioPopup.close(); header.powerRequested() }
        }
    }
}
