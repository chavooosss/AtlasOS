import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Item {
    id: page
    property bool boardMode: false
    property var diagnostics: atlasDiagnostics
    property var snapshotData: ({})
    property var exportTargets: []
    property string selectedTargetId: ""
    property string notice: ""
    property bool noticeError: false
    implicitHeight: content.implicitHeight

    AtlasTheme { id: theme }

    function refreshSnapshot() {
        snapshotData = diagnostics.snapshot()
        exportTargets = diagnostics.refreshExportTargets()
        if (exportTargets.length === 0)
            selectedTargetId = ""
        else
            selectedTargetId = exportTargets[0].id
    }

    function safeText(value) {
        if (value === undefined || value === null || value === "")
            return "Mevcut değil"
        if (typeof value === "object")
            return JSON.stringify(value)
        return String(value)
    }

    Component.onCompleted: refreshSnapshot()

    Column {
        id: content
        width: page.width
        spacing: 18

        Column {
            width: parent.width; spacing: 5
            Text { text: "Atlas Geliştirici Merkezi"; color: theme.ink; font.family: theme.fontFamily; font.pixelSize: theme.typePageTitle; font.bold: true }
            Text {
                width: parent.width
                text: "Salt okunur sistem bilgileri, güvenli performans anlık görüntüleri ve fiziksel boot kanıtları."
                color: theme.muted; font.family: theme.fontFamily; font.pixelSize: theme.typeSecondary; wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            width: parent.width; height: 94; radius: theme.radiusCard; color: theme.paleBlue; border.color: theme.line
            Row {
                anchors.fill: parent; anchors.margins: 18; spacing: 14
                Text { text: "◉"; color: theme.blue; font.pixelSize: 27; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 5
                    Text { text: "Korumalı dahili depolama"; color: theme.ink; font.pixelSize: 17; font.bold: true }
                    Text { text: "Dahili diskler salt okunur envanterdir. Disk yazma testi, otomatik mount ve onarım yoktur."; color: theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap; width: content.width - 90 }
                }
            }
        }

        Text { text: "Sistem Durumu · Donanım ve Sürücüler"; color: theme.ink; font.pixelSize: 19; font.bold: true }
        Grid {
            width: parent.width; columns: width >= 680 ? 2 : 1; spacing: 12
            Repeater {
                model: [
                    {title: "Sürüm / kernel", value: "AtlasOS " + (snapshotData.atlas_version || "0.6.3") + " · " + (snapshotData.kernel || "Mevcut değil")},
                    {title: "İşlemci", value: snapshotData.cpu && snapshotData.cpu.model ? snapshotData.cpu.model : "Mevcut değil"},
                    {title: "Bellek", value: snapshotData.memory && snapshotData.memory.total_bytes ? Math.round(snapshotData.memory.total_bytes / 1048576) + " MB toplam · " + Math.round(snapshotData.memory.available_bytes / 1048576) + " MB kullanılabilir" : "Mevcut değil"},
                    {title: "Grafik / sürücü", value: snapshotData.gpu && snapshotData.gpu.length ? snapshotData.gpu[0].device + " · " + (snapshotData.gpu[0].driver || "Sürücü mevcut değil") + (snapshotData.gpu[0].pci_vendor_id ? " · " + snapshotData.gpu[0].pci_vendor_id + ":" + snapshotData.gpu[0].pci_device_id : "") : "Mevcut değil"},
                    {title: "Boot kaynağı", value: snapshotData.boot_source && snapshotData.boot_source.devices ? snapshotData.boot_source.devices.join(", ") : (snapshotData.boot_source ? snapshotData.boot_source.state : "Mevcut değil")},
                    {title: "Atlas UI", value: !snapshotData.atlas_ui || snapshotData.atlas_ui.running === null ? "Mevcut değil" : snapshotData.atlas_ui.running ? "Çalışıyor" : "Çalışmıyor"},
                    {title: "Depolama güvenliği", value: "Internal: READ ONLY · Unknown: PROTECTED"}
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: (parent.width - parent.spacing) / parent.columns
                    height: page.boardMode ? 102 : 88
                    radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                    Column {
                        anchors.fill: parent; anchors.margins: 16; spacing: 6
                        Text { text: modelData.title; color: theme.muted; font.pixelSize: 13 }
                        Text { width: parent.width; text: page.safeText(modelData.value); color: theme.ink; font.pixelSize: 15; font.bold: true; wrapMode: Text.WordWrap; elide: Text.ElideRight; maximumLineCount: 2 }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width; height: diagnostics.busy ? 242 : 194
            radius: theme.radiusCard; color: theme.surface; border.color: theme.line
            Column {
                anchors.fill: parent; anchors.margins: 18; spacing: 12
                Text { text: "Boot Tanılama · Atlas Servisleri · Günlükler"; color: theme.ink; font.pixelSize: 19; font.bold: true }
                Text { width: parent.width; text: "Kernel, framebuffer/DRM, Plymouth, display manager ve Atlas oturum günlüklerini toplar. Sorunu otomatik çözmez; kanıt üretir."; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
                Row {
                    spacing: 10
                    AtlasButton { text: "Tüm Tanılamaları Çalıştır"; variant: "primary"; enabled: !diagnostics.busy; controlScale: page.boardMode ? 1.1 : 1.0; onClicked: { notice = ""; diagnostics.runAll() } }
                    AtlasButton { text: "İptal"; variant: "quiet"; visible: diagnostics.busy; onClicked: diagnostics.cancel() }
                }
                Text { visible: diagnostics.busy || diagnostics.bundleName.length > 0; text: diagnostics.stage + (diagnostics.bundleName.length > 0 ? " · " + diagnostics.bundleName : ""); color: theme.muted; font.pixelSize: 13; elide: Text.ElideMiddle; width: parent.width }
                Rectangle { visible: diagnostics.busy; width: parent.width; height: 8; radius: 4; color: theme.disabledSurface
                    Rectangle { width: parent.width * diagnostics.progress / 100; height: parent.height; radius: 4; color: theme.blue }
                }
            }
        }

        Rectangle {
            width: parent.width; height: 168; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
            Column {
                anchors.fill: parent; anchors.margins: 18; spacing: 10
                Text { text: "Performans"; color: theme.ink; font.pixelSize: 18; font.bold: true }
                Text { width: parent.width; text: "CPU, bellek, yük ve işlem listesi o an okunur. Sistem kısa aralıklarla ölçülür; disk yazma benchmark'ı yoktur ve bellek ayırmaz."; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
                Row {
                    spacing: 10
                    AtlasButton { text: "Anlık Görüntüyü Yenile"; variant: "secondary"; controlScale: page.boardMode ? 1.1 : 1.0; onClicked: refreshSnapshot() }
                }
            }
        }

        Rectangle {
            width: parent.width; height: 188; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
            Column {
                anchors.fill: parent; anchors.margins: 18; spacing: 10
                Text { text: "Tanılama Paketi · USB dışa aktarımı"; color: theme.ink; font.pixelSize: 18; font.bold: true }
                Text { width: parent.width; text: "Paket önce yalnızca geçici /run alanında oluşturulur. Live boot aygıtı tanımlanamıyorsa dışa aktarım kapalı kalır; yalnızca ayrı ve doğrulanmış USB kabul edilir."; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
                Row {
                    width: parent.width
                    spacing: 10
                    Controls.ComboBox {
                        id: targetSelector; width: Math.max(180, Math.min(300, parent.width - 360))
                        model: page.exportTargets; textRole: "device"
                        displayText: currentIndex >= 0 && currentIndex < page.exportTargets.length ? page.exportTargets[currentIndex].device + " · USB · " + Math.round(page.exportTargets[currentIndex].size_bytes / 1073741824 * 10) / 10 + " GB" : "Harici USB bellek bekleniyor"
                        onActivated: page.selectedTargetId = page.exportTargets[index].id
                    }
                    AtlasButton { id: refreshButton; text: "USB Tara"; variant: "secondary"; controlScale: page.boardMode ? 1.1 : 1.0; onClicked: refreshSnapshot() }
                    AtlasButton { id: exportButton; text: "Tanılama Paketini Dışa Aktar"; variant: "primary"; controlScale: page.boardMode ? 1.1 : 1.0; enabled: page.selectedTargetId.length > 0 && diagnostics.bundleName.length > 0; onClicked: { var result = diagnostics.exportBundle(page.selectedTargetId); notice = result.message || ""; noticeError = !result.ok; refreshSnapshot() } }
                }
            }
        }
        Text { visible: notice.length > 0; width: parent.width; text: notice; color: noticeError ? theme.red : theme.blue; font.pixelSize: 14; wrapMode: Text.WordWrap }

        Connections {
            target: diagnostics
            function onProgressChanged(label, value) { page.notice = label + " · %" + value; page.noticeError = false }
            function onCompleted(result) {
                if (result.ok) {
                    page.notice = "Paket /run altında hazır. Dahili diske yazılmadı.";
                    page.noticeError = false;
                    page.refreshSnapshot()
                } else {
                    page.notice = result.error || "Tanılama tamamlanamadı.";
                    page.noticeError = true
                }
            }
        }
    }
}
