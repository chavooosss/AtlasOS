import QtQuick
import "../theme"

Item {
    id: dashboard
    property string page: "home"
    property real scaleFactor: 1.0
    property bool boardMode: false
    property bool compactLayout: dashboard.height < 740
    signal openRequested(string target)
    signal allResourcesRequested()

    AtlasTheme { id: theme }

    Image {
        visible: !dashboard.compactLayout && dashboard.width >= 780 * dashboard.scaleFactor
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.bottom: parent.bottom
        height: width * 126 / 1052
        source: "../branding/atlas-dashboard-footer.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: 0.96
        z: 0
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.leftMargin: dashboard.scaleFactor * (dashboard.width < 760 ? 18 : 28)
        anchors.rightMargin: dashboard.scaleFactor * (dashboard.width < 760 ? 18 : 26)
        anchors.topMargin: (dashboard.compactLayout ? 12 : 20) * dashboard.scaleFactor
        anchors.bottomMargin: (dashboard.compactLayout ? 6 : 12) * dashboard.scaleFactor
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        z: 1

        Column {
            id: contentColumn
            width: scroll.width
            spacing: (dashboard.compactLayout ? 12 : 21) * dashboard.scaleFactor

            Column {
                width: parent.width
                spacing: 3 * dashboard.scaleFactor
                Text {
                    width: parent.width
                    text: dashboard.page === "home" ? "Günaydın, Öğretmenim" : dashboard.page === "books" ? "Ders Kitapları" : dashboard.page === "about" ? "AtlasOS Hakkında" : "Ders Araçları"
                    color: theme.ink
                    font.family: theme.fontFamily
                    font.pixelSize: theme.typeDisplay * dashboard.scaleFactor
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: dashboard.page === "home" ? "Bugünün dersini birlikte daha verimli hale getirelim." : dashboard.page === "about" ? "Öğretmenler ve öğrenciler için geliştirilen öğrenme alanı." :
                          dashboard.page === "books" ? "Ders kaynaklarını ve bu cihazdaki materyalleri açın." :
                          "Ders sırasında ihtiyaç duyduğunuz araçlara hızlıca ulaşın."
                    color: theme.muted
                    font.family: theme.fontFamily
                    font.pixelSize: theme.typeBody * dashboard.scaleFactor
                    elide: Text.ElideRight
                }
            }

            Item {
                id: resourcesArea
                width: parent.width
                property bool wide: width >= 850 * dashboard.scaleFactor
                property real groupGap: 20 * dashboard.scaleFactor
                property real booksWidth: wide ? (width - groupGap) * 0.40 : width
                property real mebWidth: wide ? (width - groupGap) * 0.60 : width
                height: wide ? Math.max(booksGroup.implicitHeight, mebGroup.implicitHeight) : booksGroup.implicitHeight + groupGap + mebGroup.implicitHeight
                visible: dashboard.page === "home" || dashboard.page === "books"

                Column {
                    id: booksGroup
                    x: 0
                    y: 0
                    width: resourcesArea.booksWidth
                    spacing: (dashboard.compactLayout ? 6 : 10) * dashboard.scaleFactor
                    Text { text: "Ders Kitapları"; color: theme.ink; font.pixelSize: 22 * dashboard.scaleFactor; font.bold: true }
                    Row {
                        width: parent.width
                        spacing: 10 * dashboard.scaleFactor
                        AtlasCard {
                            width: dashboard.page === "books" ? (parent.width - parent.spacing) / 2 : parent.width
                            cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor
                            iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                            title: "EBA"
                            detail: "Dijital ders kitapları ve içerikler"
                            iconName: "eba"
                            accent: theme.red
                            target: "eba"
                            onActivated: dashboard.openRequested(target)
                        }
                        AtlasCard {
                            visible: dashboard.page === "books"
                            width: visible ? (parent.width - parent.spacing) / 2 : 0
                            cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor
                            iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                            title: "Bu Cihaz"
                            detail: "Ders klasörleri ve dosyalar"
                            iconName: "folder"
                            accent: theme.blue
                            target: "files"
                            onActivated: dashboard.openRequested(target)
                        }
                    }
                }

                Column {
                    id: mebGroup
                    x: resourcesArea.wide ? resourcesArea.booksWidth + resourcesArea.groupGap : 0
                    y: resourcesArea.wide ? 0 : booksGroup.implicitHeight + resourcesArea.groupGap
                    width: resourcesArea.mebWidth
                    spacing: (dashboard.compactLayout ? 6 : 10) * dashboard.scaleFactor
                    Item {
                        width: parent.width
                        height: Math.max(28 * dashboard.scaleFactor, title.implicitHeight)
                        Text {
                            id: title
                            text: "MEB Kaynakları"
                            color: theme.ink
                            font.pixelSize: 22 * dashboard.scaleFactor
                            font.bold: true
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (allResources.visible ? allResources.implicitWidth + 8 * dashboard.scaleFactor : 0)
                            elide: Text.ElideRight
                        }
                        Text {
                            id: allResources
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Tüm Kaynaklar  →"
                            color: theme.blue
                            font.pixelSize: 14 * dashboard.scaleFactor
                            visible: resourcesArea.wide
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: dashboard.allResourcesRequested()
                        }
                    }
                    Grid {
                        width: parent.width
                        columns: resourcesArea.wide ? 2 : (width < 610 * dashboard.scaleFactor ? 1 : 2)
                        spacing: 10 * dashboard.scaleFactor
                        AtlasCard {
                            width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                            cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor
                            iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                            title: "OGM Materyal"
                            detail: "Zengin eğitim materyalleri"
                            iconName: "ogm"
                            accent: "#25a982"
                            target: "ogm"
                            onActivated: dashboard.openRequested(target)
                        }
                        AtlasCard {
                            width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                            cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor
                            iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                            title: "MEBİ"
                            detail: "Konu anlatımları ve etkinlikler"
                            iconName: "mebi"
                            accent: "#496df0"
                            target: "mebi"
                            onActivated: dashboard.openRequested(target)
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: (dashboard.compactLayout ? 6 : 10) * dashboard.scaleFactor
                visible: dashboard.page === "home" || dashboard.page === "tools"
                Text { text: "Ders Araçları"; color: theme.ink; font.pixelSize: 22 * dashboard.scaleFactor; font.bold: true }
                Grid {
                    id: toolsGrid
                    width: parent.width
                    columns: width < 720 * dashboard.scaleFactor ? 2 : 3
                    spacing: (dashboard.compactLayout ? 8 : 12) * dashboard.scaleFactor
                    AtlasCard {
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor; iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                        title: "PDF Aç"; detail: "PDF aç ve görüntüle"; iconName: "pdf"; accent: theme.red; target: "pdf"
                        onActivated: dashboard.openRequested(target)
                    }
                    AtlasCard {
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor; iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                        title: "Sunum Aç"; detail: "Sunum dosyalarını göster"; iconName: "presentation"; accent: theme.amber; target: "presentation"
                        onActivated: dashboard.openRequested(target)
                    }
                    AtlasCard {
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor; iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                        title: "Video Aç"; detail: "Video aç ve oynat"; iconName: "video"; accent: "#5268e8"; target: "video"
                        onActivated: dashboard.openRequested(target)
                    }
                    AtlasCard {
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor; iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                        title: "Beyaz Tahta"; detail: "Serbestçe yaz, çiz, oluştur"; iconName: "whiteboard"; accent: theme.green; target: "whiteboard"
                        onActivated: dashboard.openRequested(target)
                    }
                    AtlasCard {
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor; iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                        title: "Ekrana Çiz"; detail: "Tahta üzerinde not al"; iconName: "whiteboard"; accent: theme.blue; target: "whiteboard"
                        onActivated: dashboard.openRequested(target)
                    }
                    AtlasCard {
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor; iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                        title: "Dosyalar"; detail: "Ders materyallerine göz at"; iconName: "folder"; accent: "#45a8e8"; target: "files"
                        onActivated: dashboard.openRequested(target)
                    }
                    AtlasCard {
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        cardHeight: (dashboard.compactLayout ? 92 : 112) * dashboard.scaleFactor; iconSize: (dashboard.compactLayout ? 58 : 72) * dashboard.scaleFactor
                        title: "Web Tarayıcısı"; detail: "Web sayfalarını aç"; iconName: "applications"; accent: theme.blue; target: "browser"
                        onActivated: dashboard.openRequested(target)
                    }
                }
            }

            Rectangle {
                visible: dashboard.page === "about"
                width: Math.min(parent.width, 900 * dashboard.scaleFactor)
                height: 286 * dashboard.scaleFactor
                radius: 16 * dashboard.scaleFactor
                color: "white"
                border.color: theme.line
                Row {
                    anchors.fill: parent
                    anchors.margins: 26 * dashboard.scaleFactor
                    spacing: Math.min(24 * dashboard.scaleFactor, parent.width * 0.035)
                    Image {
                        id: aboutLogo
                        width: Math.min(132 * dashboard.scaleFactor, parent.width * 0.23)
                        height: width
                        anchors.verticalCenter: parent.verticalCenter
                        source: "../branding/atlas-symbol.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                    Column {
                        width: Math.max(0, parent.width - aboutLogo.width - parent.spacing)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9 * dashboard.scaleFactor
                        Text { text: "AtlasOS"; color: theme.ink; font.pixelSize: 28 * dashboard.scaleFactor; font.bold: true }
                        Text { text: "Öğrenme Alanı"; color: theme.blue; font.pixelSize: 15 * dashboard.scaleFactor; font.letterSpacing: 2 }
                        Text { width: parent.width; text: "Öğretmenler ve öğrenciler için tasarlanan AtlasOS Live test ortamı."; color: theme.muted; font.pixelSize: 14 * dashboard.scaleFactor; wrapMode: Text.WordWrap }
                        Rectangle {
                            width: parent.width; height: 68 * dashboard.scaleFactor; radius: 12 * dashboard.scaleFactor; color: "#edf5fc"
                            Row {
                                anchors.fill: parent; anchors.margins: 10 * dashboard.scaleFactor; spacing: 12 * dashboard.scaleFactor
                                Rectangle { width: 44 * dashboard.scaleFactor; height: 44 * dashboard.scaleFactor; radius: width / 2; color: theme.navy; anchors.verticalCenter: parent.verticalCenter; Text { anchors.centerIn: parent; text: "VE"; color: "white"; font.pixelSize: 14 * dashboard.scaleFactor; font.bold: true } }
                                Column { anchors.verticalCenter: parent.verticalCenter; spacing: 3; Text { text: "Geliştirici"; color: theme.muted; font.pixelSize: 12 * dashboard.scaleFactor } Text { text: "Veli Ercan"; color: theme.ink; font.pixelSize: 17 * dashboard.scaleFactor; font.bold: true } }
                            }
                        }
                    }
                }
            }
        }
    }
}
