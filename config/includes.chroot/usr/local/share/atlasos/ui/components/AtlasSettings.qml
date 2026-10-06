import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Window
import "../theme"

Rectangle {
    id: panel
    objectName: "atlasSettings"
    property string networkState: "Bilinmiyor"
    property string audioState: "Bilinmiyor"
    property string penState: "Algılanmadı"
    property string errorText: ""
    property bool startupSoundEnabled: true
    property bool startupSoundAvailable: false
    property string displayMode: "auto"
    property bool touchscreenDetected: false
    property bool boardMode: false
    signal networkRequested()
    signal appRequested(string key)
    signal startupSoundChanged(bool enabled)
    signal displayModeRequested(string mode)
    color: theme.canvas
    AtlasTheme { id: theme }

    readonly property var sections: [
        { key: "home", label: "Genel" },
        { key: "network", label: "Ağ ve internet" },
        { key: "display", label: "Ekran" },
        { key: "sound", label: "Ses" },
        { key: "access", label: "Erişilebilirlik" },
        { key: "about", label: "Hakkında" },
        { key: "developer", label: "Geliştirici" }
    ]
    property string selectedSection: atlasValidateSettingsSection || "home"

    Row {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: navigation
            width: panel.boardMode ? Math.max(240, Math.min(300, panel.width * 0.24)) : Math.max(218, Math.min(270, panel.width * 0.22))
            height: parent.height
            color: theme.surfaceRaised
            Column {
                anchors.fill: parent
                anchors.margins: panel.boardMode ? 22 : 18
                spacing: 10
                Text { text: "SİSTEM"; color: theme.muted; font.pixelSize: 12; font.bold: true }
                Repeater {
                    model: panel.sections
                    delegate: Controls.Button {
                        required property var modelData
                        width: parent.width
                        height: panel.boardMode ? theme.touchBoard : theme.touch
                        text: modelData.label
                        font.family: theme.fontFamily
                        font.pixelSize: panel.boardMode ? 17 : 15
                        font.weight: panel.selectedSection === modelData.key ? Font.DemiBold : Font.Normal
                        onClicked: panel.selectedSection = modelData.key
                        background: Rectangle {
                            radius: theme.radiusCard
                            color: panel.selectedSection === modelData.key ? theme.softBlue : parent.hovered ? theme.surfaceRaised : "transparent"
                            Rectangle { visible: panel.selectedSection === modelData.key; width: 3; radius: 2; color: theme.blue; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom }
                        }
                        contentItem: Text { text: parent.text; color: theme.ink; font: parent.font; verticalAlignment: Text.AlignVCenter; leftPadding: 14; elide: Text.ElideRight }
                    }
                }
                Item { width: 1; height: Math.max(8, navigation.height - 520) }
                Text { width: parent.width; text: "AtlasOS 0.6.3 · Live"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 12 }
            }
        }

        Rectangle { width: 1; height: parent.height; color: theme.line }

        Flickable {
            id: detailsScroll
            width: parent.width - navigation.width - 1
            height: parent.height
            contentWidth: width
            contentHeight: details.implicitHeight + 52
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: details
                x: panel.boardMode ? 34 : 30; y: panel.boardMode ? 28 : 24
                width: detailsScroll.width - 60
                spacing: panel.boardMode ? 22 : 18

                Column {
                    width: parent.width
                    spacing: 5
                    Text {
                        text: panel.selectedSection === "network" ? "Ağ ve internet" : panel.selectedSection === "display" ? "Ekran" : panel.selectedSection === "sound" ? "Ses" : panel.selectedSection === "access" ? "Erişilebilirlik" : panel.selectedSection === "about" ? "AtlasOS hakkında" : panel.selectedSection === "developer" ? "Geliştirici" : "Atlas ayarları"
                        color: theme.ink; font.family: theme.fontFamily; font.pixelSize: theme.typeDisplay; font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: panel.selectedSection === "about" ? "AtlasOS Live test ortamı ve sürüm bilgileri." : panel.selectedSection === "developer" ? "Tanılama ve performans bilgileri · dahili depolama korumalıdır." : "Sınıf kullanımına göre cihaz durumunu ve Atlas tercihlerini yönetin."
                        color: theme.muted; font.family: theme.fontFamily; font.pixelSize: theme.typeSecondary; wrapMode: Text.WordWrap
                    }
                }

                Text { visible: panel.errorText.length > 0; width: parent.width; text: panel.errorText; color: theme.red; font.pixelSize: 15; wrapMode: Text.WordWrap }

                Column {
                    visible: panel.selectedSection === "home"
                    width: parent.width; spacing: 12
                    Text { text: "Hızlı durum"; color: theme.ink; font.pixelSize: 20; font.bold: true }
                    Grid {
                        width: parent.width
                        columns: width >= 700 ? 2 : 1
                        spacing: 12
                        Rectangle {
                            width: (parent.width - parent.spacing) / parent.columns; height: panel.boardMode ? 132 : 116; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                            Column { anchors.fill: parent; anchors.margins: 18; spacing: 8; Text { text: "Ağ"; color: theme.muted; font.pixelSize: 14 } Text { text: panel.networkState; color: theme.ink; font.pixelSize: 18; font.bold: true } }
                            MouseArea { anchors.fill: parent; onClicked: panel.networkRequested() }
                        }
                        Rectangle {
                            width: (parent.width - parent.spacing) / parent.columns; height: panel.boardMode ? 132 : 116; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                            Column { anchors.fill: parent; anchors.margins: 18; spacing: 8; Text { text: "Ses çıkışı"; color: theme.muted; font.pixelSize: 14 } Text { text: panel.audioState; color: theme.ink; font.pixelSize: 18; font.bold: true } }
                            MouseArea { anchors.fill: parent; onClicked: panel.selectedSection = "sound" }
                        }
                        Rectangle {
                            width: (parent.width - parent.spacing) / parent.columns; height: panel.boardMode ? 132 : 116; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                            Column { anchors.fill: parent; anchors.margins: 18; spacing: 8; Text { text: "Ekran"; color: theme.muted; font.pixelSize: 14 } Text { text: Screen.width + " × " + Screen.height; color: theme.ink; font.pixelSize: 18; font.bold: true } }
                            MouseArea { anchors.fill: parent; onClicked: panel.selectedSection = "display" }
                        }
                        Rectangle {
                            width: (parent.width - parent.spacing) / parent.columns; height: panel.boardMode ? 132 : 116; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                            Column { anchors.fill: parent; anchors.margins: 18; spacing: 8; Text { text: "Kalem ve dokunma"; color: theme.muted; font.pixelSize: 14 } Text { text: panel.penState; color: theme.ink; font.pixelSize: 18; font.bold: true } }
                            MouseArea { anchors.fill: parent; onClicked: panel.selectedSection = "access" }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 84; radius: theme.radiusCard; color: theme.paleBlue
                        Row { anchors.fill: parent; anchors.margins: 18; spacing: 14; Text { text: "⚙"; color: theme.blue; font.pixelSize: 26; anchors.verticalCenter: parent.verticalCenter } Column { anchors.verticalCenter: parent.verticalCenter; spacing: 4; Text { text: "Atlas sistem araçları"; color: theme.ink; font.pixelSize: 16; font.bold: true } Text { text: "CPU ve bellek kullanımını görüntüle"; color: theme.muted; font.pixelSize: 14 } } }
                        MouseArea { anchors.fill: parent; onClicked: panel.appRequested("resources") }
                    }
                }

                Column {
                    visible: panel.selectedSection === "network"
                    width: parent.width; spacing: 12
                    Rectangle {
                        width: parent.width; height: 138; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                        Column { anchors.fill: parent; anchors.margins: 20; spacing: 8; Text { text: "Bağlantı durumu"; color: theme.ink; font.pixelSize: 18; font.bold: true } Text { width: parent.width; text: panel.networkState; color: theme.muted; font.pixelSize: 15; wrapMode: Text.WordWrap } Text { text: "Kablolu ağ ve Wi‑Fi tanılamasını aç"; color: theme.blue; font.pixelSize: 14 } }
                        MouseArea { anchors.fill: parent; onClicked: panel.networkRequested() }
                    }
                    Text { width: parent.width; text: "İnternet durumu ağ bağlantısından ayrı değerlendirilir. Ethernet kablosunun takılı olması internete erişildiğini tek başına göstermez."; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
                }

                Column {
                    visible: panel.selectedSection === "display"
                    width: parent.width; spacing: 12
                    Rectangle {
                        width: parent.width; height: 140; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                        Column { anchors.fill: parent; anchors.margins: 20; spacing: 8; Text { text: "Görüntü bilgisi"; color: theme.ink; font.pixelSize: 18; font.bold: true } Text { text: Screen.width + " × " + Screen.height + " mantıksal piksel"; color: theme.ink; font.pixelSize: 16 } Text { text: "Atlas arayüzü bağlı ekran boyutuna uyum sağlar. Ekran çözünürlüğü cihazın görüntü aygıtı tarafından belirlenir."; width: parent.width; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap } }
                    }
                    Rectangle {
                        width: parent.width; height: 126; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                        Row {
                            anchors.fill: parent; anchors.margins: 18; spacing: 16
                            Column {
                                width: parent.width - modeSelector.width - parent.spacing
                                anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                Text { text: "Görünüm boyutu"; color: theme.ink; font.pixelSize: 17; font.bold: true }
                                Text { width: parent.width; text: panel.displayMode === "auto" ? (panel.touchscreenDetected ? "Dokunmatik ekran algılandı · Tahta görünümü" : "Dokunmatik ekran algılanmadı · Laptop görünümü") : panel.displayMode === "board" ? "Tahta görünümü elle seçildi" : "Laptop görünümü elle seçildi"; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
                            }
                            Controls.ComboBox {
                                id: modeSelector
                                width: panel.boardMode ? 220 : 190; height: panel.boardMode ? 76 : 64; anchors.verticalCenter: parent.verticalCenter
                                model: ["Otomatik", "Laptop", "Tahta"]
                                currentIndex: panel.displayMode === "board" ? 2 : panel.displayMode === "laptop" ? 1 : 0
                                onActivated: panel.displayModeRequested(index === 2 ? "board" : index === 1 ? "laptop" : "auto")
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: panel.boardMode ? 108 : 92; radius: theme.radiusCard; color: theme.paleBlue
                        Column { anchors.fill: parent; anchors.margins: 18; spacing: 5; Text { text: "Dokunma hedefleri"; color: theme.ink; font.pixelSize: 16; font.bold: true } Text { text: "Ana etkileşim alanları en az 64 mantıksal piksel hedeflenerek hazırlanır."; width: parent.width; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap } }
                    }
                    Rectangle {
                        width: parent.width; height: 92; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                        Row {
                            anchors.fill: parent; anchors.margins: 18; spacing: 14
                            AtlasIcon { width: 26; height: 26; name: "bulb"; strokeColor: theme.muted; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                width: parent.width - 40
                                anchors.verticalCenter: parent.verticalCenter; spacing: 5
                                Text { text: "Parlaklık denetimi"; color: theme.ink; font.pixelSize: 16; font.bold: true }
                                Text { width: parent.width; text: "Bu ekranda Atlas üzerinden donanım parlaklığı ayarlanamıyor."; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
                            }
                        }
                    }
                }

                Column {
                    visible: panel.selectedSection === "sound"
                    width: parent.width; spacing: 12
                    Rectangle {
                        width: parent.width; height: 116; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                        Row {
                            anchors.fill: parent; anchors.margins: 20; spacing: 16
                            Column {
                                width: parent.width - (panel.startupSoundAvailable ? startupSwitch.width + 16 : 0)
                                anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                Text { text: "Atlas açılış sesi"; color: theme.ink; font.pixelSize: 17; font.bold: true }
                                Text { width: parent.width; text: panel.startupSoundAvailable ? "Oturum açıldıktan sonra kısa bir kez çalar." : "ElevenLabs ses dosyası bu sürüme eklendiğinde çalar."; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
                            }
                            Controls.Switch { id: startupSwitch; visible: panel.startupSoundAvailable; anchors.verticalCenter: parent.verticalCenter; checked: panel.startupSoundEnabled; onToggled: panel.startupSoundChanged(checked) }
                        }
                    }
                    Rectangle {
                        width: parent.width; height: 96; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                        Column { anchors.fill: parent; anchors.margins: 20; spacing: 6; Text { text: "Ses aygıtı"; color: theme.ink; font.pixelSize: 17; font.bold: true } Text { text: panel.audioState; color: theme.muted; font.pixelSize: 14 } }
                    }
                }

                Column {
                    visible: panel.selectedSection === "access"
                    width: parent.width; spacing: 12
                    Rectangle {
                        width: parent.width; height: 124; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                        Column { anchors.fill: parent; anchors.margins: 20; spacing: 7; Text { text: "Kalem ve dokunmatik ekran"; color: theme.ink; font.pixelSize: 18; font.bold: true } Text { width: parent.width; text: panel.penState; color: theme.blue; font.pixelSize: 15 } Text { width: parent.width; text: "Durum algılanan giriş aygıtlarından okunur. Fiziksel kalem hassasiyeti gerçek tahtada ayrıca sınanmalıdır."; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap } }
                    }
                }

                Column {
                    visible: panel.selectedSection === "about"
                    width: parent.width; spacing: 12
                    Rectangle {
                        width: parent.width; height: 260; radius: theme.radiusPanel; color: theme.surface; border.color: theme.line
                        Row {
                            anchors.fill: parent; anchors.margins: 28; spacing: 24
                            Image { width: 140; height: 140; anchors.verticalCenter: parent.verticalCenter; source: "../branding/atlas-symbol.png"; fillMode: Image.PreserveAspectFit; smooth: true }
                            Column {
                                width: parent.width - 164; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                                Text { text: "AtlasOS"; color: theme.ink; font.pixelSize: 28; font.bold: true }
                                Text { text: "Öğrenme Alanı · Live test sürümü"; color: theme.blue; font.pixelSize: 15 }
                                Rectangle { width: parent.width; height: 1; color: theme.line }
                                Text { text: "Geliştirici"; color: theme.muted; font.pixelSize: 14 }
                                Text { text: "Veli Ercan"; color: theme.ink; font.pixelSize: 22; font.bold: true }
                            }
                        }
                    }
                    Text { width: parent.width; text: "AtlasOS Live ortamı USB üzerinden çalışan test sürümüdür."; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
                }

                Loader {
                    id: developerLoader
                    active: panel.selectedSection === "developer"
                    visible: active
                    width: parent.width
                    height: item ? item.implicitHeight : 0
                    source: "AtlasDeveloper.qml"
                    onLoaded: {
                        item.width = width
                        item.boardMode = panel.boardMode
                    }
                    onWidthChanged: if (item) item.width = width
                    Connections {
                        target: panel
                        function onBoardModeChanged() { if (developerLoader.item) developerLoader.item.boardMode = panel.boardMode }
                    }
                }
            }
        }
    }
}
