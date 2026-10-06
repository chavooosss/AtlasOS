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
    property string selectedSection: atlasValidateSettingsSection || "home"
    signal networkRequested()
    signal appRequested(string key)
    signal startupSoundChanged(bool enabled)
    signal displayModeRequested(string mode)
    color: theme.canvas
    AtlasTheme { id: theme }

    function sectionTitle() {
        return selectedSection === "display" ? "Görünüm" : selectedSection === "sound" ? "Ses" :
               selectedSection === "access" ? "Erişilebilirlik" : selectedSection === "about" ? "Hakkında" :
               selectedSection === "developer" ? "Geliştirici Merkezi" : "Sistem"
    }

    Column {
        anchors.fill: parent
        anchors.margins: panel.width < 1450 ? 16 : 24
        spacing: 16
        Row {
            width: parent.width; height: panel.width < 1450 ? 74 : 86; spacing: 18
            AtlasIcon { anchors.verticalCenter: parent.verticalCenter; width: 44; height: 44; name: "settings"; strokeColor: theme.atlasNavy }
            Column { anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Text { text: "Ayarlar"; color: theme.ink; font.pixelSize: 31; font.bold: true }
                Text { text: "Sistem ayarlarınızı sınıf kullanımına göre yönetin."; color: theme.muted; font.pixelSize: 15 }
            }
        }
        Row {
            width: parent.width; height: parent.height - (panel.width < 1450 ? 90 : 102); spacing: 20
            AtlasSettingsNav {
                id: settingsNav
                width: panel.width < 1450 ? 224 : 274; height: parent.height
                compact: panel.width < 1450; selected: panel.selectedSection
                onSectionRequested: function(key) {
                    if (key === "network") panel.networkRequested()
                    else panel.selectedSection = key
                }
            }
            Flickable {
                id: detailsScroll
                width: parent.width - settingsNav.width - parent.spacing; height: parent.height
                clip: true; contentWidth: width; contentHeight: details.implicitHeight + 26
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: details; width: detailsScroll.width; spacing: 18
                    Rectangle {
                        width: parent.width; height: 86; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                        Column { x: 24; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                            Text { text: panel.sectionTitle(); color: theme.ink; font.pixelSize: 26; font.bold: true }
                            Text { text: panel.selectedSection === "developer" ? "Güvenli tanılama ve sistem kayıtları" : panel.selectedSection === "home" ? "Cihaz ve Atlas tercihleri" : "Bu cihazda kullanılabilen seçenekler"; color: theme.muted; font.pixelSize: 14 }
                        }
                    }
                    Text { visible: panel.errorText.length > 0; width: parent.width; text: panel.errorText; color: theme.danger; font.pixelSize: 15; wrapMode: Text.WordWrap }

                    Column {
                        visible: panel.selectedSection === "home"; width: parent.width; spacing: 16
                        Text { text: "Cihaz durumu"; color: theme.ink; font.pixelSize: 21; font.bold: true }
                        Grid {
                            width: parent.width; columns: width >= 750 ? 2 : 1; spacing: 14
                            Repeater { model: [
                                {title: "Ağ", icon: "network", value: panel.networkState, key: "network"},
                                {title: "Görünüm", icon: "screen-draw", value: (panel.Window.window ? panel.Window.window.width : Screen.width) + " × " + (panel.Window.window ? panel.Window.window.height : Screen.height) + " mantıksal piksel", key: "display"},
                                {title: "Ses", icon: "volume", value: panel.audioState, key: "sound"},
                                {title: "Kalem ve dokunma", icon: "pen", value: panel.penState, key: "access"}
                            ]; delegate: Rectangle { required property var modelData
                                width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                                height: panel.width < 1450 ? 130 : 150; radius: theme.radiusLarge
                                color: theme.surface; border.color: theme.borderSubtle
                                Rectangle { x: 18; y: 20; width: 46; height: 46; radius: 12; color: theme.atlasBlueSoft
                                    AtlasIcon { anchors.centerIn: parent; width: 25; height: 25; name: modelData.icon; strokeColor: theme.atlasBlue } }
                                Text { x: 76; y: 23; width: parent.width - 92; text: modelData.title; color: theme.ink; font.pixelSize: 18; font.bold: true; elide: Text.ElideRight }
                                Text { x: 76; y: 55; width: parent.width - 92; text: modelData.value; color: theme.muted; font.pixelSize: 14; elide: Text.ElideRight }
                                Text { x: 76; y: parent.height - 34; text: "Ayrıntıları aç  →"; color: theme.atlasBlue; font.pixelSize: 13 }
                                MouseArea { anchors.fill: parent; onClicked: modelData.key === "network" ? panel.networkRequested() : panel.selectedSection = modelData.key }
                            } }
                        }
                        Rectangle { width: parent.width; height: 90; radius: theme.radiusLarge; color: theme.atlasBlueSoft
                            AtlasIcon { x: 21; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; name: "settings"; strokeColor: theme.atlasBlue }
                            Column { x: 72; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                                Text { text: "Sistem kaynakları"; color: theme.ink; font.pixelSize: 17; font.bold: true }
                                Text { text: "Gerçek zamanlı işlemci ve bellek durumu"; color: theme.muted; font.pixelSize: 14 }
                            }
                            MouseArea { anchors.fill: parent; onClicked: panel.appRequested("resources") }
                        }
                    }

                    Column { visible: panel.selectedSection === "display"; width: parent.width; spacing: 14
                        Text { text: "Ekran ve ölçek"; color: theme.ink; font.pixelSize: 21; font.bold: true }
                        Rectangle { width: parent.width; height: 104; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Column { x: 24; anchors.verticalCenter: parent.verticalCenter; spacing: 7
                                Text { text: "Görüntü bilgisi"; color: theme.ink; font.pixelSize: 18; font.bold: true }
                                Text { text: (panel.Window.window ? panel.Window.window.width : Screen.width) + " × " + (panel.Window.window ? panel.Window.window.height : Screen.height) + " mantıksal piksel"; color: theme.muted; font.pixelSize: 15 }
                            }
                        }
                        Rectangle { width: parent.width; height: 112; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Column { x: 24; width: parent.width - modeSelector.width - 70; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                Text { text: "Görünüm boyutu"; color: theme.ink; font.pixelSize: 18; font.bold: true }
                                Text { width: parent.width; text: panel.displayMode === "auto" ? (panel.touchscreenDetected ? "Dokunmatik algılandı · Tahta görünümü" : "Dokunmatik algılanmadı · Laptop görünümü") : panel.displayMode === "board" ? "Tahta görünümü seçili" : "Laptop görünümü seçili"; color: theme.muted; font.pixelSize: 14; elide: Text.ElideRight }
                            }
                            Controls.ComboBox { id: modeSelector; anchors.right: parent.right; anchors.rightMargin: 23; anchors.verticalCenter: parent.verticalCenter; width: 205; height: 56; model: ["Otomatik", "Laptop", "Tahta"]; currentIndex: panel.displayMode === "board" ? 2 : panel.displayMode === "laptop" ? 1 : 0; onActivated: panel.displayModeRequested(index === 2 ? "board" : index === 1 ? "laptop" : "auto") }
                        }
                        Rectangle { width: parent.width; height: 104; radius: theme.radiusLarge; color: theme.disabledSurface; border.color: theme.borderSubtle
                            Column { x: 24; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                Text { text: "Ekran parlaklığı"; color: theme.disabledInk; font.pixelSize: 18; font.bold: true }
                                Text { text: "Atlas üzerinden donanım parlaklığı bu cihazda kullanılamıyor."; color: theme.disabledInk; font.pixelSize: 14 }
                            }
                        }
                    }
                    Column { visible: panel.selectedSection === "sound"; width: parent.width; spacing: 14
                        Text { text: "Ses tercihleri"; color: theme.ink; font.pixelSize: 21; font.bold: true }
                        Rectangle { width: parent.width; height: 112; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Column { x: 24; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                Text { text: "Ses çıkışı"; color: theme.ink; font.pixelSize: 18; font.bold: true }
                                Text { text: panel.audioState; color: theme.muted; font.pixelSize: 14 }
                            }
                        }
                        Rectangle { width: parent.width; height: 112; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Column { x: 24; width: parent.width - 110; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                Text { text: "Atlas açılış sesi"; color: theme.ink; font.pixelSize: 18; font.bold: true }
                                Text { text: panel.startupSoundAvailable ? "Oturum açıldığında kısa bir ses çalar." : "Ses dosyası bu yapıda bulunmuyor."; color: theme.muted; font.pixelSize: 14 }
                            }
                            Controls.Switch { anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter; visible: panel.startupSoundAvailable; checked: panel.startupSoundEnabled; onClicked: panel.startupSoundChanged(checked) }
                        }
                    }
                    Column { visible: panel.selectedSection === "access"; width: parent.width; spacing: 14
                        Text { text: "Kalem ve dokunma"; color: theme.ink; font.pixelSize: 21; font.bold: true }
                        Rectangle { width: parent.width; height: 132; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Column { anchors.fill: parent; anchors.margins: 24; spacing: 8
                                Text { text: "Giriş aygıtı durumu"; color: theme.ink; font.pixelSize: 18; font.bold: true }
                                Text { text: panel.penState; color: theme.atlasBlue; font.pixelSize: 16 }
                                Text { text: "Kalem hassasiyeti ve dokunmatik davranış gerçek tahtada doğrulanmalıdır."; color: theme.muted; font.pixelSize: 14 }
                            }
                        }
                    }
                    Column { visible: panel.selectedSection === "about"; width: parent.width; spacing: 14
                        Rectangle { width: parent.width; height: 180; radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                            Image { x: 28; anchors.verticalCenter: parent.verticalCenter; width: 105; height: 105; source: "../branding/atlas-symbol.png"; fillMode: Image.PreserveAspectFit }
                            Column { x: 152; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                                Text { text: "AtlasOS"; color: theme.ink; font.pixelSize: 29; font.bold: true }
                                Text { text: "0.6.3 · Live geliştirme önizlemesi"; color: theme.atlasBlue; font.pixelSize: 15 }
                                Text { text: "Geliştirici: Veli Ercan"; color: theme.muted; font.pixelSize: 14 }
                            }
                        }
                    }
                    Loader {
                        id: developerLoader
                        active: panel.selectedSection === "developer"
                        visible: active; width: parent.width
                        height: item ? item.implicitHeight : 0
                        source: "AtlasDeveloper.qml"
                        onLoaded: { item.width = width; item.boardMode = panel.boardMode }
                        onWidthChanged: if (item) item.width = width
                    }
                }
            }
        }
    }
}
