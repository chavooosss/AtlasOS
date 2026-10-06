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
        x: Math.max(8, Math.min(header.width - width - 12, audioStatus.mapToItem(header, 0, 0).x + audioStatus.width / 2 - width / 2))
        y: header.height + 8
        width: Math.min(header.boardMode ? 440 : 400, header.width - 24)
        padding: header.boardMode ? 22 : 20
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: theme.shell; radius: theme.radiusPanel; border.color: theme.shellLine; border.width: 1 }
        contentItem: Column {
            spacing: 15
            Text { text: "Hızlı Ayarlar"; color: theme.shellText; font.family: theme.fontFamily; font.pixelSize: 22; font.bold: true }
            Text { text: "Sınıf araçları ve sistem durumu"; color: theme.shellMutedText; font.family: theme.fontFamily; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Row {
                width: parent.width
                spacing: 12
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        required property int index
                        width: (parent.width - parent.spacing) / 2
                        height: header.boardMode ? 98 : 86
                        radius: theme.radiusCard
                        color: index === 0 && header.networkController && header.networkController.wifiRadioAvailable && header.networkController.wifiEnabled ? theme.blue : theme.shellRaised
                        border.color: theme.shellLine
                        AtlasIcon { x: 14; y: 14; width: 24; height: 24; name: index === 0 ? "network" : "network"; strokeColor: theme.shellText }
                        Text {
                            x: 14; y: 42; width: parent.width - 28
                            text: index === 0 ? "Wi-Fi" : "Ethernet"
                            color: theme.shellText
                            font.family: theme.fontFamily; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight
                        }
                        Text {
                            x: 14; y: 63; width: parent.width - 28
                            text: index === 0 ? (!header.networkController || !header.networkController.wifiRadioAvailable ? "Denetleyici bulunamadı" : header.networkController.wifiEnabled ? "Açık" : "Kapalı") : (header.networkState || "Durum bilinmiyor")
                            color: theme.shellMutedText
                            font.family: theme.fontFamily; font.pixelSize: 12; elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: index === 0 ? (header.networkController && header.networkController.wifiRadioAvailable) : true
                            onClicked: index === 0 ? header.networkController.toggleWifi() : header.networkRequested()
                        }
                    }
                }
            }
            AtlasButton { objectName: "atlasQuickNetworkButton"; width: parent.width; text: "Ağları ve bağlantı ayrıntılarını yönet"; iconName: "network"; variant: "darkSecondary"; controlScale: header.boardMode ? 1.1 : 1.0; onClicked: { audioPopup.close(); header.networkRequested() } }
            Rectangle { width: parent.width; height: 1; color: theme.shellLine }
            Text { text: "Ses"; color: theme.shellText; font.family: theme.fontFamily; font.pixelSize: 18; font.bold: true }
            Row {
                width: parent.width
                spacing: 12
                AtlasIcon { anchors.verticalCenter: parent.verticalCenter; width: 23; height: 23; name: !header.audioController || header.audioController.muted ? "volume-muted" : header.audioController.volume < 35 ? "volume-low" : "volume"; strokeColor: theme.shellText }
                AtlasSlider {
                    id: volumeSlider
                    darkMode: true
                    width: parent.width - 72
                    from: 0; to: 100; stepSize: 1
                    value: header.audioController && header.audioController.available ? header.audioController.volume : 0
                    enabled: header.audioController && header.audioController.available
                    onMoved: if (header.audioController) header.audioController.setVolume(Math.round(value))
                }
                Text { width: 36; anchors.verticalCenter: parent.verticalCenter; text: Math.round(volumeSlider.value) + "%"; color: theme.shellText; font.pixelSize: 14; horizontalAlignment: Text.AlignRight }
            }
            AtlasButton {
                width: parent.width
                controlScale: header.boardMode ? 1.1 : 1
                text: header.audioController && header.audioController.muted ? "Sesi Aç" : "Sessize Al"
                iconName: header.audioController && header.audioController.muted ? "volume" : "volume-muted"
                enabled: header.audioController && header.audioController.available
                variant: "darkSecondary"
                onClicked: header.audioController.toggleMute()
            }
            Rectangle { width: parent.width; height: 1; color: theme.shellLine }
            Row {
                width: parent.width; spacing: 12
                AtlasIcon { anchors.verticalCenter: parent.verticalCenter; width: 23; height: 23; name: "bulb"; strokeColor: theme.shellMutedText }
                Column {
                    width: parent.width - 42; spacing: 4
                    Text { text: "Ekran parlaklığı"; color: theme.shellText; font.family: theme.fontFamily; font.pixelSize: 16; font.bold: true }
                    Text { width: parent.width; text: "Bu ekran için Atlas üzerinden parlaklık denetimi kullanılamıyor."; color: theme.shellMutedText; font.family: theme.fontFamily; font.pixelSize: 13; wrapMode: Text.WordWrap }
                }
            }
            Text {
                visible: !header.audioController || !header.audioController.available
                width: parent.width
                text: "Ses aygıtı şu anda kullanılamıyor."
                color: theme.shellMutedText
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            Row {
                width: parent.width; spacing: 10
                AtlasButton { width: (parent.width - parent.spacing) / 2; text: "Ayarlar"; iconName: "settings"; variant: "darkSecondary"; controlScale: header.boardMode ? 1.08 : 1; onClicked: { audioPopup.close(); header.settingsRequested() } }
                AtlasButton { width: (parent.width - parent.spacing) / 2; text: "Güç"; iconName: "power"; variant: "darkSecondary"; controlScale: header.boardMode ? 1.08 : 1; onClicked: { audioPopup.close(); header.powerRequested() } }
            }
        }
        Connections {
            target: header.audioController
            function onChanged() { if (!volumeSlider.pressed && header.audioController.available) volumeSlider.value = header.audioController.volume }
        }
    }
}
