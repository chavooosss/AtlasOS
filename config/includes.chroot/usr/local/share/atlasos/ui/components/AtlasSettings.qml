import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Window
import "../theme"

Rectangle {
    id: panel
    objectName: "atlasSettings"
    property string networkState: "Bilinmiyor"
    property string audioState: "Bilinmiyor"
    property var audioController: null
    property string penState: "Algılanmadı"
    property string errorText: ""
    property bool startupSoundEnabled: true
    property bool startupSoundAvailable: false
    property string displayMode: "auto"
    property bool touchscreenDetected: false
    property bool boardMode: false
    property real density: 1.0
    property string selectedSection: atlasValidateSettingsSection || "home"
    signal networkRequested()
    signal appRequested(string key)
    signal startupSoundChanged(bool enabled)
    signal displayModeRequested(string mode)
    color: theme.canvas
    AtlasTheme { id: theme }
    onSelectedSectionChanged: {
        if (selectedSection === "sound" && audioController) audioController.refreshOutputs()
    }

    function sectionTitle() {
        return selectedSection === "display" ? "Görünüm" : selectedSection === "sound" ? "Ses" :
               selectedSection === "access" ? "Erişilebilirlik" : selectedSection === "about" ? "Hakkında" :
               selectedSection === "developer" ? "Geliştirici Merkezi" : "Sistem"
    }

    Column {
        id: settingsLayout
        anchors.fill: parent
        anchors.margins: (panel.width < 1450 ? 16 : 24) * panel.density
        spacing: 16 * panel.density
        Row {
            id: settingsHeader
            width: parent.width; height: 86 * panel.density; spacing: 18 * panel.density
            AtlasIcon { anchors.verticalCenter: parent.verticalCenter; width: 44 * panel.density; height: width; name: "settings"; strokeColor: theme.atlasNavy }
            Column { anchors.verticalCenter: parent.verticalCenter; spacing: 4 * panel.density
                Text { text: "Ayarlar"; color: theme.ink; font.pixelSize: 31 * panel.density; font.bold: true }
                Text { text: "Sistem ayarlarınızı sınıf kullanımına göre yönetin."; color: theme.muted; font.pixelSize: 15 * panel.density }
            }
        }
        Row {
            width: parent.width; height: Math.max(0, settingsLayout.height - settingsHeader.height - settingsLayout.spacing); spacing: 20 * panel.density
            AtlasSettingsNav {
                boardMode: panel.boardMode
                density: panel.density
                id: settingsNav
                width: Math.min(parent.width * 0.30, (panel.width < 1450 ? 224 : 274) * panel.density); height: parent.height
                compact: panel.width < 1450; selected: panel.selectedSection
                onSectionRequested: function(key) {
                    if (key === "network") panel.networkRequested()
                    else panel.selectedSection = key
                }
            }
            Flickable {
                id: detailsScroll
                width: Math.max(0, parent.width - settingsNav.width - parent.spacing); height: parent.height
                clip: true; contentWidth: width; contentHeight: details.implicitHeight + 26
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: details; width: detailsScroll.width; spacing: 18 * panel.density
                    Rectangle {
                        width: parent.width; height: 86 * panel.density; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                        Column { x: 24 * panel.density; width: parent.width - 48 * panel.density; anchors.verticalCenter: parent.verticalCenter; spacing: 4 * panel.density
                            Text { text: panel.sectionTitle(); color: theme.ink; font.pixelSize: 26 * panel.density; font.bold: true }
                            Text { width: parent.width; text: panel.selectedSection === "developer" ? "Güvenli tanılama ve sistem kayıtları" : panel.selectedSection === "home" ? "Cihaz ve Atlas tercihleri" : "Bu cihazda kullanılabilen seçenekler"; color: theme.muted; font.pixelSize: 14 * panel.density; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                        }
                    }
                    Text { visible: panel.errorText.length > 0; width: parent.width; text: panel.errorText; color: theme.danger; font.pixelSize: 15 * panel.density; wrapMode: Text.WordWrap }

                    Column {
                        visible: panel.selectedSection === "home"; width: parent.width; spacing: 16
                        Text { text: "Cihaz durumu"; color: theme.ink; font.pixelSize: 21 * panel.density; font.bold: true }
                        Grid {
                            width: parent.width; columns: width >= 750 ? 2 : 1; spacing: 14
                            Repeater { model: [
                                {title: "Ağ", icon: "network", value: panel.networkState, key: "network"},
                                {title: "Görünüm", icon: "display", value: (panel.Window.window ? panel.Window.window.width : Screen.width) + " × " + (panel.Window.window ? panel.Window.window.height : Screen.height) + " mantıksal piksel", key: "display"},
                                {title: "Ses", icon: "volume", value: panel.audioState, key: "sound"},
                                {title: "Kalem ve dokunma", icon: "pen", value: panel.penState, key: "access"}
                            ]; delegate: Rectangle { required property var modelData
                                width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                                height: (panel.width < 1450 ? 130 : 150) * panel.density; radius: theme.radiusLarge
                                color: theme.surface; border.color: theme.borderSubtle
                                Rectangle { x: 18 * panel.density; y: 20 * panel.density; width: 46 * panel.density; height: 46 * panel.density; radius: 12 * panel.density; color: theme.atlasBlueSoft
                                    AtlasIcon { anchors.centerIn: parent; width: 25 * panel.density; height: 25 * panel.density; name: modelData.icon; strokeColor: theme.atlasBlue } }
                                Text { x: 76 * panel.density; y: 23 * panel.density; width: parent.width - 92 * panel.density; text: modelData.title; color: theme.ink; font.pixelSize: 18 * panel.density; font.bold: true; elide: Text.ElideRight }
                                Text { x: 76 * panel.density; y: 55 * panel.density; width: parent.width - 92 * panel.density; text: modelData.value; color: theme.muted; font.pixelSize: 14 * panel.density; elide: Text.ElideRight }
                                Text { x: 76 * panel.density; y: parent.height - 34 * panel.density; text: "Ayrıntıları aç  →"; color: theme.atlasBlue; font.pixelSize: 13 * panel.density }
                                MouseArea { anchors.fill: parent; onClicked: modelData.key === "network" ? panel.networkRequested() : panel.selectedSection = modelData.key }
                            } }
                        }
                        Rectangle { width: parent.width; height: 90 * panel.density; radius: theme.radiusLarge; color: theme.atlasBlueSoft
                            AtlasIcon { x: 21 * panel.density; anchors.verticalCenter: parent.verticalCenter; width: 34 * panel.density; height: 34 * panel.density; name: "settings"; strokeColor: theme.atlasBlue }
                            Column { x: 72 * panel.density; anchors.verticalCenter: parent.verticalCenter; spacing: 5 * panel.density
                                Text { text: "Sistem kaynakları"; color: theme.ink; font.pixelSize: 17 * panel.density; font.bold: true }
                                Text { text: "Gerçek zamanlı işlemci ve bellek durumu"; color: theme.muted; font.pixelSize: 14 * panel.density }
                            }
                            MouseArea { anchors.fill: parent; onClicked: panel.appRequested("resources") }
                        }
                    }

                    Column { visible: panel.selectedSection === "display"; width: parent.width; spacing: 14
                        Text { text: "Ekran ve ölçek"; color: theme.ink; font.pixelSize: 21 * panel.density; font.bold: true }
                        Rectangle { width: parent.width; height: 104 * panel.density; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Column { x: 24 * panel.density; width: parent.width - 48 * panel.density; anchors.verticalCenter: parent.verticalCenter; spacing: 7 * panel.density
                                Text { text: "Görüntü bilgisi"; color: theme.ink; font.pixelSize: 18 * panel.density; font.bold: true }
                                Text { text: (panel.Window.window ? panel.Window.window.width : Screen.width) + " × " + (panel.Window.window ? panel.Window.window.height : Screen.height) + " mantıksal piksel"; color: theme.muted; font.pixelSize: 15 * panel.density }
                            }
                        }
                        Rectangle { width: parent.width; height: 148 * panel.density; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Column { x: 24 * panel.density; width: Math.max(0, parent.width - modeSelector.width - 70 * panel.density); anchors.verticalCenter: parent.verticalCenter; spacing: 6 * panel.density
                                Text { text: "Görünüm boyutu"; color: theme.ink; font.pixelSize: 18 * panel.density; font.bold: true }
                                Text { width: parent.width; text: panel.displayMode === "auto" ? (panel.touchscreenDetected ? "Dokunmatik algılandı · Tahta görünümü" : "Dokunmatik algılanmadı · Laptop görünümü") : panel.displayMode === "board" ? "Tahta görünümü seçili" : "Laptop görünümü seçili"; color: theme.muted; font.pixelSize: 14 * panel.density; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                                Text { width: parent.width; text: "Ölçek değişince Chrome pencerelerini kapatıp yeniden açın."; color: theme.muted; font.pixelSize: 12 * panel.density; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                            }
                            AtlasComboBox { id: modeSelector; anchors.right: parent.right; anchors.rightMargin: 23 * panel.density; anchors.verticalCenter: parent.verticalCenter; width: 205 * panel.density; height: 56 * panel.density; model: ["Otomatik", "Laptop", "Tahta"]; currentIndex: panel.displayMode === "board" ? 2 : panel.displayMode === "laptop" ? 1 : 0; onActivated: panel.displayModeRequested(index === 2 ? "board" : index === 1 ? "laptop" : "auto") }
                        }
                        Rectangle { width: parent.width; height: 104 * panel.density; radius: theme.radiusLarge; color: theme.disabledSurface; border.color: theme.borderSubtle
                            Column { x: 24 * panel.density; width: parent.width - 48 * panel.density; anchors.verticalCenter: parent.verticalCenter; spacing: 6 * panel.density
                                Text { text: "Ekran parlaklığı"; color: theme.disabledInk; font.pixelSize: 18 * panel.density; font.bold: true }
                                Text { text: "Atlas üzerinden donanım parlaklığı bu cihazda kullanılamıyor."; color: theme.disabledInk; font.pixelSize: 14 * panel.density }
                            }
                        }
                    }
                    Column { visible: panel.selectedSection === "sound"; width: parent.width; spacing: 14
                        Text { text: "Ses tercihleri"; color: theme.ink; font.pixelSize: 21 * panel.density; font.bold: true }
                        Rectangle { width: parent.width; height: audioOutputs.implicitHeight + 36 * panel.density; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Column { id: audioOutputs; x: 24 * panel.density; y: 18 * panel.density; width: parent.width - 48 * panel.density; spacing: 10 * panel.density
                                Text { text: "Ses çıkışı"; color: theme.ink; font.pixelSize: 18 * panel.density; font.bold: true }
                                Text { width: parent.width; text: panel.audioController ? panel.audioController.outputStatus : panel.audioState; color: theme.muted; font.pixelSize: 14 * panel.density; wrapMode: Text.WordWrap }
                                Repeater { model: panel.audioController ? panel.audioController.outputs : []
                                    delegate: AtlasButton { required property var modelData
                                        width: audioOutputs.width; height: 52 * panel.density
                                        text: modelData.name + (modelData.selected ? " · Seçili" : "")
                                        variant: modelData.selected ? "primary" : "secondary"
                                        controlScale: panel.density
                                        enabled: !modelData.virtual
                                        onClicked: panel.audioController.selectOutput(modelData.id)
                                    }
                                }
                                Text { visible: panel.audioController && panel.audioController.profiles.length > 0
                                    text: "Ses kartı çıkış profili (yalnızca seçtiğinizde değişir)"
                                    color: theme.ink; font.pixelSize: 16 * panel.density; font.bold: true }
                                Repeater { model: panel.audioController ? panel.audioController.profiles : []
                                    delegate: AtlasButton { required property var modelData
                                        width: audioOutputs.width; height: 48 * panel.density
                                        text: modelData.label + (modelData.selected ? " · Etkin" : "")
                                        variant: modelData.selected ? "primary" : "secondary"
                                        controlScale: panel.density
                                        onClicked: panel.audioController.selectCardProfile(modelData.cardId, modelData.profile)
                                    }
                                }
                                Text { visible: panel.audioController && panel.audioController.ports.length > 0
                                    text: "Ses bağlantı noktası (yalnızca seçtiğinizde değişir)"
                                    color: theme.ink; font.pixelSize: 16 * panel.density; font.bold: true }
                                Repeater { model: panel.audioController ? panel.audioController.ports : []
                                    delegate: AtlasButton { required property var modelData
                                        width: audioOutputs.width; height: 48 * panel.density
                                        text: modelData.sinkDescription + " · " + modelData.label + (modelData.selected ? " · Etkin" : "")
                                        variant: modelData.selected ? "primary" : "secondary"
                                        controlScale: panel.density
                                        onClicked: panel.audioController.selectOutputPort(modelData.sink, modelData.port)
                                    }
                                }
                                AtlasButton {
                                    width: audioOutputs.width
                                    height: 48 * panel.density
                                    text: "Kısa test sesi çal"
                                    variant: "secondary"
                                    controlScale: panel.density
                                    enabled: panel.audioController && panel.audioController.available
                                    onClicked: panel.audioController.testOutput()
                                }
                            }
                        }
                        Rectangle { width: parent.width; height: 112 * panel.density; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Column { x: 24 * panel.density; width: parent.width - 110 * panel.density; anchors.verticalCenter: parent.verticalCenter; spacing: 6 * panel.density
                                Text { text: "Atlas açılış sesi"; color: theme.ink; font.pixelSize: 18 * panel.density; font.bold: true }
                                Text { text: panel.startupSoundAvailable ? "Oturum açıldığında kısa bir ses çalar." : "Ses dosyası bu yapıda bulunmuyor."; color: theme.muted; font.pixelSize: 14 * panel.density }
                            }
                            AtlasSwitch { anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter; visible: panel.startupSoundAvailable; checked: panel.startupSoundEnabled; onToggled: panel.startupSoundChanged(checked) }
                        }
                    }
                    Column { visible: panel.selectedSection === "access"; width: parent.width; spacing: 14
                        Text { text: "Kalem ve dokunma"; color: theme.ink; font.pixelSize: 21 * panel.density; font.bold: true }
                        Rectangle { width: parent.width; height: 132 * panel.density; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Column { anchors.fill: parent; anchors.margins: 24 * panel.density; spacing: 8 * panel.density
                                Text { text: "Giriş aygıtı durumu"; color: theme.ink; font.pixelSize: 18 * panel.density; font.bold: true }
                                Text { text: panel.penState; color: theme.atlasBlue; font.pixelSize: 16 * panel.density }
                                Text { text: "Kalem hassasiyeti ve dokunmatik davranış gerçek tahtada doğrulanmalıdır."; color: theme.muted; font.pixelSize: 14 * panel.density }
                            }
                        }
                    }
                    Column { visible: panel.selectedSection === "about"; width: parent.width; spacing: 14
                        Rectangle { width: parent.width; height: 180 * panel.density; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Image { x: 28 * panel.density; anchors.verticalCenter: parent.verticalCenter; width: 105 * panel.density; height: 105 * panel.density; source: "../branding/atlas-symbol.png"; fillMode: Image.PreserveAspectFit }
                            Column { x: 152 * panel.density; anchors.verticalCenter: parent.verticalCenter; spacing: 8 * panel.density
                                Text { text: "AtlasOS"; color: theme.ink; font.pixelSize: 29 * panel.density; font.bold: true }
                                Text { text: "0.6.4 · Live geliştirme önizlemesi"; color: theme.atlasBlue; font.pixelSize: 15 * panel.density }
                                Text { text: "Geliştirici: Veli Ercan"; color: theme.muted; font.pixelSize: 14 * panel.density }
                            }
                        }
                    }
                    Loader {
                        id: developerLoader
                        active: panel.selectedSection === "developer"
                        visible: active; width: parent.width
                        height: item ? item.implicitHeight : 0
                        source: "AtlasDeveloper.qml"
                        onLoaded: { item.width = width; item.boardMode = panel.boardMode; item.density = panel.density }
                        onWidthChanged: if (item) item.width = width
                        Connections {
                            target: panel
                            function onDensityChanged() { if (developerLoader.item) developerLoader.item.density = panel.density }
                        }
                    }
                }
            }
        }
    }
}
