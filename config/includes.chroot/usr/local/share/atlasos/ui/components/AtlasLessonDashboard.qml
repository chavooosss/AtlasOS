import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Item {
    id: page
    objectName: "atlasMaterials"
    property real scaleFactor: 1.0
    property bool boardMode: false
    property int grade: 11
    property string track: "Sayısal"
    property string subject: "Matematik"
    property string activeLessonTitle: ""
    property string activeLessonTime: ""
    property int activeLessonElapsedSeconds: 0
    property var favoriteKeys: []
    property var recentKeys: []
    property string category: ["favorites", "recent", "local", "web"].indexOf(atlasValidateMaterialFilter) >= 0 ? atlasValidateMaterialFilter : "all"
    property string query: ""
    signal toolRequested(string target)
    AtlasTheme { id: theme }

    readonly property var catalog: [
        {key:"eba", title:"EBA", subject:"Tüm dersler", detail:"MEB dijital ders kitapları ve içerikleri", icon:"eba", accent:"#f05261", kind:"Web", target:"eba", keywords:"kitap ders içeriği müfredat"},
        {key:"ogm", title:"OGM Materyal", subject:"Tüm dersler", detail:"MEB öğrenme materyalleri ve etkinlikleri", icon:"ogm", accent:"#17a982", kind:"Web", target:"ogm", keywords:"etkinlik konu anlatımı test"},
        {key:"mebi", title:"MEBİ", subject:"Tüm dersler", detail:"MEBİ konu anlatımları ve öğrenme etkinlikleri", icon:"mebi", accent:"#4e6df5", kind:"Web", target:"mebi", keywords:"konu anlatımı etkinlik"},
        {key:"geogebra", title:"GeoGebra", subject:"Matematik", detail:"Geometri ve matematik keşifleri · internet gerekir", icon:"applications", accent:"#4388e8", kind:"Web", target:"geogebra", keywords:"grafik geometri cebir"},
        {key:"kig", title:"Kig Geometri", subject:"Matematik", detail:"Bu cihazda geometrik çizimler oluştur", icon:"applications", accent:"#4388e8", kind:"Cihazda", target:"kig", keywords:"geometri çizim"},
        {key:"step", title:"Step Fizik", subject:"Fizik", detail:"Fizik düzeneklerini bu cihazda modelle", icon:"physics", accent:"#5e68dd", kind:"Cihazda", target:"step", keywords:"simülasyon hareket kuvvet"},
        {key:"kalzium", title:"Kalzium", subject:"Kimya", detail:"Periyodik tabloyu ve element bilgilerini aç", icon:"chemistry", accent:"#17a982", kind:"Cihazda", target:"kalzium", keywords:"element periyodik tablo"},
        {key:"books", title:"Ders Kitapları", subject:"Tüm dersler", detail:"Cihazdaki ders kitabı dosyalarına göz at", icon:"books", accent:"#f05261", kind:"Cihazda", target:"books", keywords:"pdf kitap yerel"},
        {key:"pdf", title:"PDF Aç", subject:"Tüm dersler", detail:"Ders PDF dosyalarını aç ve görüntüle", icon:"pdf", accent:"#f05261", kind:"Cihazda", target:"pdf", keywords:"belge pdf"},
        {key:"presentation", title:"Sunum Aç", subject:"Tüm dersler", detail:"Sunum dosyalarını sınıfta göster", icon:"presentation", accent:"#f0aa32", kind:"Cihazda", target:"presentation", keywords:"slayt libreoffice"},
        {key:"video", title:"Video Aç", subject:"Tüm dersler", detail:"Cihazdaki ders videolarını oynat", icon:"video", accent:"#5e68dd", kind:"Cihazda", target:"video", keywords:"film video"},
        {key:"whiteboard", title:"Beyaz Tahta", subject:"Tüm dersler", detail:"Tahtada çiz, yaz ve çalışmanı kaydet", icon:"whiteboard", accent:"#17a982", kind:"Cihazda", target:"whiteboard", keywords:"çizim not kalem"},
        {key:"library", title:"Kaynak Rafı", subject:"Tüm dersler", detail:"Ders kitapları, indirilenler ve USB kaynakları", icon:"folder", accent:"#48aee6", kind:"Cihazda", target:"library", keywords:"dosya usb yerel"}
    ]

    function subjects() {
        if (grade <= 10) return ["Matematik", "Türk Dili ve Edebiyatı", "Fizik", "Kimya", "Biyoloji", "Tarih", "Coğrafya", "Felsefe", "İngilizce", "Din Kültürü", "Beden Eğitimi"]
        if (track === "Eşit Ağırlık") return ["Matematik", "Türk Dili ve Edebiyatı", "Tarih", "Coğrafya", "Felsefe", "İngilizce"]
        if (track === "Sözel") return ["Türk Dili ve Edebiyatı", "Tarih", "Coğrafya", "Felsefe", "Din Kültürü", "İngilizce"]
        return ["Matematik", "Fizik", "Kimya", "Biyoloji", "Türk Dili ve Edebiyatı", "İngilizce"]
    }
    function chooseGrade(value) {
        grade = value
        if (subjects().indexOf(subject) < 0) subject = subjects()[0]
    }
    function matches(item) {
        var favorite = page.favoriteKeys.indexOf(item.key) >= 0
        if (page.category === "favorites" && !favorite) return false
        if (page.category === "recent" && page.recentKeys.indexOf(item.key) < 0) return false
        if (page.category === "local" && item.kind !== "Cihazda") return false
        if (page.category === "web" && item.kind !== "Web") return false
        if (item.subject !== "Tüm dersler" && item.subject !== page.subject) return false
        var needle = page.query.trim().toLocaleLowerCase()
        return needle === "" || (item.title + " " + item.detail + " " + item.subject + " " + item.keywords).toLocaleLowerCase().indexOf(needle) >= 0
    }
    function visibleItems() { return catalog.filter(matches) }

    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.margins: (page.boardMode ? 26 : 22) * page.scaleFactor
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

        Column {
            id: content
            width: scroll.width
            spacing: (page.boardMode ? 17 : 14) * page.scaleFactor
            Column {
                width: parent.width
                spacing: 4 * page.scaleFactor
                Text { text: "Materyal Merkezi"; color: theme.ink; font.family: theme.fontFamily; font.pixelSize: theme.typeDisplay * page.scaleFactor; font.bold: true; elide: Text.ElideRight }
                Text { width: parent.width; text: "Dersini seç; sınıfta kullanacağın kaynakları ve araçları tek yerde bul."; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: theme.typeBody * page.scaleFactor; wrapMode: Text.WordWrap }
            }
            Rectangle {
                visible: page.activeLessonTitle.length > 0
                width: parent.width
                height: visible ? 76 * page.scaleFactor : 0
                radius: theme.radiusCard * page.scaleFactor
                color: "#eaf7f4"
                border.color: theme.green
                Row {
                    anchors.fill: parent; anchors.margins: 14 * page.scaleFactor; spacing: 12 * page.scaleFactor
                    AtlasIcon { width: 26 * page.scaleFactor; height: width; anchors.verticalCenter: parent.verticalCenter; name: "calendar"; strokeColor: theme.green }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 3 * page.scaleFactor
                        Text { text: "DERS OTURUMU · " + page.activeLessonTime; color: theme.green; font.pixelSize: 12 * page.scaleFactor; font.bold: true }
                        Text { text: page.activeLessonTitle + "   ·   " + Math.floor(page.activeLessonElapsedSeconds / 60) + ":" + (page.activeLessonElapsedSeconds % 60 < 10 ? "0" : "") + (page.activeLessonElapsedSeconds % 60); color: theme.ink; font.pixelSize: 18 * page.scaleFactor; font.bold: true; elide: Text.ElideRight }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8 * page.scaleFactor
                Repeater {
                    model: [9, 10, 11, 12]
                    delegate: AtlasButton {
                        text: modelData + ". sınıf"; controlScale: page.scaleFactor
                        checkable: true; checked: page.grade === modelData
                        onClicked: page.chooseGrade(modelData)
                    }
                }
                Repeater {
                    model: ["Sayısal", "Eşit Ağırlık", "Sözel"]
                    delegate: AtlasButton {
                        visible: page.grade >= 11
                        text: modelData; controlScale: page.scaleFactor
                        checkable: true; checked: visible && page.track === modelData
                        onClicked: { page.track = modelData; if (page.subjects().indexOf(page.subject) < 0) page.subject = page.subjects()[0] }
                    }
                }
            }

            Flow {
                id: subjectFlow
                width: parent.width
                spacing: 8 * page.scaleFactor
                Repeater {
                    model: page.subjects()
                    delegate: AtlasButton {
                        text: modelData; controlScale: page.boardMode ? Math.max(page.scaleFactor, 1.06) : page.scaleFactor
                        checkable: true; checked: page.subject === modelData
                        onClicked: page.subject = modelData
                    }
                }
            }

            Row {
                width: parent.width; spacing: 12 * page.scaleFactor
                AtlasSearch {
                    id: search
                    width: parent.width - categoryRow.implicitWidth - parent.spacing
                    controlScale: page.boardMode ? 1.08 : page.scaleFactor
                    placeholderText: "Ders, konu veya araç ara"
                    text: page.query
                    onTextEdited: page.query = text
                    Keys.onEscapePressed: { text = ""; page.query = "" }
                }
                Row {
                    id: categoryRow
                    spacing: 5 * page.scaleFactor
                    Repeater {
                        model: [{key:"all",label:"Tümü"},{key:"favorites",label:"Sık"},{key:"recent",label:"Son"},{key:"local",label:"Cihaz"},{key:"web",label:"Web"}]
                        delegate: AtlasButton {
                            text: modelData.label; controlScale: page.scaleFactor * 0.92
                            checkable: true; checked: page.category === modelData.key
                            onClicked: page.category = modelData.key
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8 * page.scaleFactor
                AtlasIcon { width: 22 * page.scaleFactor; height: width; anchors.verticalCenter: parent.verticalCenter; name: "books"; strokeColor: theme.navy }
                Text { text: page.subject + " · Kaynaklar ve araçlar"; color: theme.ink; font.family: theme.fontFamily; font.pixelSize: theme.typeSection * page.scaleFactor; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }

            Flow {
                id: resourceFlow
                width: parent.width
                spacing: 12 * page.scaleFactor
                Repeater {
                    model: page.visibleItems()
                    delegate: AtlasMaterialCard {
                        width: Math.max(220 * page.scaleFactor, Math.min(330 * page.scaleFactor, (resourceFlow.width - 24 * page.scaleFactor) / 3))
                        title: modelData.title
                        detail: modelData.detail
                        iconName: modelData.icon
                        accent: modelData.accent
                        kind: modelData.kind
                        scaleFactor: page.scaleFactor
                        boardMode: page.boardMode
                        favorite: page.favoriteKeys.indexOf(modelData.key) >= 0
                        onActivated: page.toolRequested(modelData.target)
                        onFavoriteToggled: function(enabled) { atlasApps.setFavorite(modelData.key, enabled) }
                    }
                }
            }
            Rectangle {
                visible: page.visibleItems().length === 0
                width: parent.width; height: 106 * page.scaleFactor
                radius: theme.radiusCard * page.scaleFactor
                color: theme.surface; border.color: theme.line
                Column {
                    anchors.centerIn: parent; spacing: 6 * page.scaleFactor
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: page.category === "favorites" ? "Henüz sık kullanılan yok" : page.category === "recent" ? "Henüz açılan kaynak yok" : "Eşleşen kaynak bulunamadı"; color: theme.ink; font.pixelSize: 17 * page.scaleFactor; font.bold: true }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Arama sözcüğünü veya ders seçimini değiştirebilirsin."; color: theme.muted; font.pixelSize: 13 * page.scaleFactor }
                }
            }
            Text { width: parent.width; text: "Web kaynakları için internet bağlantısı gerekir. GeoGebra'nın kullanımı kendi lisans koşullarına tabidir; Atlas içeriği kopyalamaz."; color: theme.muted; font.pixelSize: 12 * page.scaleFactor; wrapMode: Text.WordWrap }
        }
    }
}
