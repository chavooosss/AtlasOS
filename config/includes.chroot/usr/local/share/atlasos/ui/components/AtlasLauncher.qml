import QtQuick
import QtQuick.Controls
import "../theme"

Item {
    id: launcher
    visible: false
    property string errorText: ""
    signal selected(string key)
    property var entries: [
        {key: "browser", title: "Web Tarayıcısı", detail: "Web sayfalarını ayrı pencerede aç"},
        {key: "books", title: "Ders Kitapları", detail: "Yerel ders kaynakları"},
        {key: "files", title: "Dosyalar", detail: "Bu cihazdaki dosyalar"},
        {key: "whiteboard", title: "Beyaz Tahta", detail: "Yaz ve çiz"},
        {key: "pdf", title: "PDF", detail: "Belge görüntüle"},
        {key: "video", title: "Video", detail: "Ders videosu oynat"},
        {key: "network", title: "Ağ Bağlantıları", detail: "Kablolu ve Wi-Fi durumu"},
        {key: "settings", title: "Ayarlar", detail: "Atlas içi sistem seçenekleri"},
        {key: "resources", title: "Kaynaklar", detail: "CPU ve bellek"},
        {key: "office", title: "Office", detail: "Düzenleme prototipi beklemede"}
    ]
    property var results: entries
    AtlasTheme { id: theme }

    function open() {
        visible = true
        query.text = ""
        errorText = ""
        filter()
        query.forceActiveFocus()
    }
    function close() { visible = false }
    function filter() {
        var needle = query.text.toLocaleLowerCase()
        results = entries.filter(function (entry) {
            return entry.title.toLocaleLowerCase().indexOf(needle) >= 0 ||
                   entry.detail.toLocaleLowerCase().indexOf(needle) >= 0
        })
    }
    function launch(key) {
        selected(key)
        close()
    }


    Rectangle { anchors.fill: parent; color: "#99081527"; MouseArea { anchors.fill: parent; onClicked: launcher.close() } }
    Rectangle {
        width: Math.min(620, parent.width - 40)
        height: Math.min(570, parent.height - 40)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: 20
        radius: 6; color: "white"; border.color: theme.line

        Column {
            anchors.fill: parent; anchors.margins: 20; spacing: 12
            Row {
                width: parent.width; height: 64
                Text { text: "Uygulamalar"; color: theme.ink; font.pixelSize: 24; font.bold: true; width: parent.width - 64 }
                Button { width: 64; height: 64; text: "×"; onClicked: launcher.close() }
            }
            TextField {
                id: query
                width: parent.width; height: 64
                placeholderText: "Uygulama ara"
                font.pixelSize: 18
                onTextChanged: launcher.filter()
                Keys.onEscapePressed: launcher.close()
                Keys.onReturnPressed: { if (launcher.results.length > 0) launcher.launch(launcher.results[0].key) }
            }
            Text { visible: launcher.errorText.length > 0; text: launcher.errorText; color: theme.red; font.pixelSize: 15 }
            Text { visible: launcher.results.length === 0; text: "Sonuç bulunamadı"; color: theme.muted; font.pixelSize: 16 }
            ListView {
                width: parent.width
                height: parent.height - 64 - 64 - 48 - (launcher.errorText.length > 0 ? 24 : 0)
                model: launcher.results
                spacing: 7
                clip: true
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    width: ListView.view.width - 12; height: 68; radius: 6
                    color: "#f0f5f8"; border.color: theme.line
                    Column {
                        anchors.left: parent.left; anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter; spacing: 2
                        Text { text: modelData.title; color: theme.ink; font.pixelSize: 17; font.bold: true }
                        Text { text: modelData.detail; color: theme.muted; font.pixelSize: 13 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: launcher.launch(modelData.key) }
                }
            }
        }
    }
}
