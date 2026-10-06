import QtQuick
import QtQuick.Controls as Controls
import Qt.labs.folderlistmodel
import "../theme"

Item {
    id: files
    objectName: "filesView"
    property bool boardMode: false
    property string kind: ""
    property url homeFolder: "file:///home/atlas"
    property url booksFolder: "file:///home/atlas/Ders%20Kitaplari"
    property url downloadsFolder: "file:///home/atlas/Downloads"
    property url currentFolder: homeFolder
    property string usbMessage: ""
    property string searchText: ""
    property bool gridMode: true
    property var selectedFile: ({})
    property var history: []
    property int historyIndex: -1
    readonly property bool folderAvailable: atlasFs.directoryExists(currentFolder.toString())
    signal chosen(string kind, string url)
    AtlasTheme { id: theme }

    readonly property var locations: [
        {key: "home", label: "Ana Klasör", icon: "home", url: homeFolder.toString()},
        {key: "books", label: "Ders Kitapları", icon: "books", url: booksFolder.toString()},
        {key: "documents", label: "Belgeler", icon: "file", url: homeFolder + "/Documents"},
        {key: "downloads", label: "İndirilenler", icon: "folder", url: downloadsFolder.toString()},
        {key: "desktop", label: "Masaüstü", icon: "screen-draw", url: homeFolder + "/Desktop"},
        {key: "pictures", label: "Resimler", icon: "file", url: homeFolder + "/Pictures"},
        {key: "videos", label: "Videolar", icon: "video", url: homeFolder + "/Videos"},
        {key: "music", label: "Müzikler", icon: "volume", url: homeFolder + "/Music"},
        {key: "templates", label: "Şablonlar", icon: "folder", url: homeFolder + "/Templates"}
    ]
    function navigate(url) {
        if (!url || !atlasFs.directoryExists(url.toString())) return
        var target = url.toString()
        if (currentFolder.toString() === target) return
        history = history.slice(0, historyIndex + 1).concat([target])
        historyIndex = history.length - 1
        currentFolder = target
        selectedFile = ({})
        searchText = ""
        searchField.text = ""
    }
    function open(kindName) {
        kind = kindName
        selectedFile = ({})
        var target = kindName === "books" || kindName === "library" && atlasFs.directoryExists(booksFolder.toString()) ? booksFolder.toString() : homeFolder.toString()
        currentFolder = target
        history = [target]
        historyIndex = 0
        searchText = ""
        searchField.text = ""
    }
    function back() {
        if (historyIndex < 1) return false
        historyIndex--
        currentFolder = history[historyIndex]
        selectedFile = ({})
        return true
    }
    function forward() {
        if (historyIndex >= history.length - 1) return
        historyIndex++
        currentFolder = history[historyIndex]
        selectedFile = ({})
    }
    function goParent() {
        if (folderModel.parentFolder.toString().length) navigate(folderModel.parentFolder)
    }
    function chooseUsb() {
        var result = atlasFs.mountRemovableVolumes()
        usbMessage = result.message || ""
        if (result.ok && result.volumes.length > 0) navigate("file://" + encodeURI(result.volumes[0].folder))
    }
    function isUsbLocation() {
        var path = currentFolder.toString()
        return path.indexOf("file:///media/") === 0 || path.indexOf("file:///run/media/") === 0
    }
    function fileKind(name) {
        var suffix = name.toLowerCase().split(".").pop()
        if (suffix === "pdf") return "pdf"
        if (["odp", "ppt", "pptx"].indexOf(suffix) >= 0) return "presentation"
        if (["mp4", "mkv", "webm", "avi"].indexOf(suffix) >= 0) return "video"
        if (["txt", "md", "csv", "log", "json", "xml", "yaml", "yml", "ini", "cfg", "conf", "html", "css", "sh", "py", "js", "ts"].indexOf(suffix) >= 0) return "text"
        return "unsupported"
    }
    function openItem(item) {
        if (!item.url) return
        if (item.directory) navigate(item.url)
        else chosen((kind === "books" || kind === "files" || kind === "library") ? fileKind(item.name) : kind, item.url)
    }
    function formatBytes(n) {
        if (!n) return "0 B"
        if (n >= 1048576) return (n / 1048576).toFixed(1) + " MB"
        if (n >= 1024) return (n / 1024).toFixed(1) + " KB"
        return n + " B"
    }
    FolderListModel {
        id: folderModel; folder: files.currentFolder
        showDirs: true; showFiles: true; showDotAndDotDot: false; showHidden: false
        showDirsFirst: true; caseSensitive: false
        nameFilters: files.kind === "pdf" ? ["*.pdf"] : files.kind === "presentation" ? ["*.odp", "*.ppt", "*.pptx"] :
                     files.kind === "video" ? ["*.mp4", "*.mkv", "*.webm", "*.avi"] : ["*"]
    }
    Rectangle { anchors.fill: parent; color: theme.canvas }
    Column {
        anchors.fill: parent; anchors.margins: files.width < 1450 ? 16 : 24; spacing: 14
        Row { width: parent.width; height: files.width < 1450 ? 72 : 84; spacing: 16
            AtlasIcon { anchors.verticalCenter: parent.verticalCenter; width: 45; height: 45; name: "folder"; strokeColor: theme.atlasNavy }
            Column { anchors.verticalCenter: parent.verticalCenter; spacing: 3
                Text { text: files.kind === "books" ? "Ders Kitapları" : files.kind === "library" ? "Kaynak Rafı" : files.kind === "pdf" ? "PDF Seç" : files.kind === "presentation" ? "Sunum Seç" : files.kind === "video" ? "Video Seç" : "Dosyalar"; color: theme.ink; font.pixelSize: 30; font.bold: true }
                Text { text: "Gerçek klasör ve dosyalarınızı görüntüleyin."; color: theme.muted; font.pixelSize: 14 }
            }
        }
        Row {
            width: parent.width; height: parent.height - (files.width < 1450 ? 86 : 98); spacing: 16
            Rectangle {
                id: locationRail; width: files.width < 1450 ? 221 : 270; height: parent.height
                radius: theme.radiusLarge; color: theme.surfaceRaised; border.color: theme.borderSubtle
                Flickable { anchors.fill: parent; anchors.margins: 10; clip: true; contentWidth: width; contentHeight: railItems.implicitHeight + 10
                    Column { id: railItems; width: parent.width; spacing: 5
                        Text { x: 10; width: parent.width - 20; height: 34; verticalAlignment: Text.AlignVCenter; text: "KONUM"; color: theme.muted; font.pixelSize: 12; font.bold: true }
                        Repeater { model: files.locations; delegate: Rectangle { required property var modelData
                            width: railItems.width; height: 50; radius: 9
                            property bool available: atlasFs.directoryExists(modelData.url)
                            color: files.currentFolder.toString() === modelData.url ? theme.atlasBlueSoft : "transparent"
                            AtlasIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: modelData.icon; width: 22; height: 22; strokeColor: parent.available ? theme.atlasBlue : theme.disabledInk }
                            Text { x: 46; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 54; text: modelData.label; color: parent.available ? theme.ink : theme.disabledInk; font.pixelSize: 14; font.bold: files.currentFolder.toString() === modelData.url; elide: Text.ElideRight }
                            MouseArea { anchors.fill: parent; enabled: parent.available; onClicked: files.navigate(modelData.url) }
                        } }
                        Rectangle { width: parent.width; height: 1; color: theme.borderSubtle }
                        Text { x: 10; height: 30; text: "CİHAZLAR"; color: theme.muted; font.pixelSize: 12; font.bold: true; verticalAlignment: Text.AlignVCenter }
                        Rectangle { width: parent.width; height: 50; radius: 9; color: files.isUsbLocation() ? theme.atlasBlueSoft : "transparent"
                            AtlasIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "folder"; width: 22; height: 22; strokeColor: theme.atlasBlue }
                            Text { x: 46; anchors.verticalCenter: parent.verticalCenter; text: "USB Bellek"; color: theme.ink; font.pixelSize: 14 }
                            MouseArea { anchors.fill: parent; onClicked: files.chooseUsb() }
                        }
                    }
                }
            }
            Rectangle {
                id: browserPane; width: parent.width - locationRail.width - parent.spacing; height: parent.height
                radius: theme.radiusLarge; color: theme.surface; border.color: theme.borderSubtle
                Row {
                    id: topBar; x: 14; y: 14; width: parent.width - 28; height: 56; spacing: 8
                    Rectangle { width: 48; height: 48; radius: 9; color: theme.surfaceMuted
                        AtlasIcon { anchors.centerIn: parent; name: "arrow-left"; strokeColor: theme.atlasNavy; width: 22; height: 22 }
                        MouseArea { anchors.fill: parent; onClicked: files.back() }
                    }
                    Rectangle { width: 48; height: 48; radius: 9; color: theme.surfaceMuted
                        AtlasIcon { anchors.centerIn: parent; name: "arrow-right"; strokeColor: theme.atlasNavy; width: 22; height: 22 }
                        MouseArea { anchors.fill: parent; onClicked: files.forward() }
                    }
                    Rectangle { width: 48; height: 48; radius: 9; color: theme.surfaceMuted
                        AtlasIcon { anchors.centerIn: parent; name: "home"; strokeColor: theme.atlasNavy; width: 22; height: 22 }
                        MouseArea { anchors.fill: parent; onClicked: files.navigate(files.homeFolder) }
                    }
                    Rectangle { width: files.width < 1450 ? 164 : 244; height: 48; radius: 9; color: theme.surfaceMuted
                        Text { anchors.fill: parent; anchors.margins: 10; verticalAlignment: Text.AlignVCenter; text: atlasFs.displayPath(files.currentFolder.toString()); color: theme.ink; font.pixelSize: 13; elide: Text.ElideMiddle }
                        MouseArea { anchors.fill: parent; onClicked: files.goParent() }
                    }
                    Controls.TextField { id: searchField; width: Math.max(90, parent.width - 48 * 5 - (files.width < 1450 ? 164 : 244) - 6 * 8); height: 48; placeholderText: "Bu klasörde ara…"; font.pixelSize: 14
                        onTextChanged: files.searchText = text.trim().toLocaleLowerCase()
                        background: Rectangle { radius: 9; color: theme.surface; border.color: theme.borderSubtle }
                    }
                    Rectangle { width: 48; height: 48; radius: 9; color: files.gridMode ? theme.atlasBlueSoft : theme.surfaceMuted
                        Text { anchors.centerIn: parent; text: "▦"; color: theme.atlasBlue; font.pixelSize: 25 }
                        MouseArea { anchors.fill: parent; onClicked: files.gridMode = true }
                    }
                    Rectangle { width: 48; height: 48; radius: 9; color: !files.gridMode ? theme.atlasBlueSoft : theme.surfaceMuted
                        Text { anchors.centerIn: parent; text: "☷"; color: theme.atlasBlue; font.pixelSize: 25 }
                        MouseArea { anchors.fill: parent; onClicked: files.gridMode = false }
                    }
                }
                Rectangle { x: 0; y: 82; width: parent.width; height: 1; color: theme.borderSubtle }
                Rectangle {
                    id: detailsPane; anchors.right: parent.right; anchors.top: topBar.bottom; anchors.topMargin: 18; anchors.bottom: parent.bottom
                    width: files.width < 1450 ? 215 : 275; color: theme.surfaceRaised
                    Column { anchors.fill: parent; anchors.margins: 16; spacing: 13
                        Rectangle { width: parent.width; height: files.width < 1450 ? 116 : 145; radius: theme.radiusMedium; color: theme.atlasBlueSoft
                            AtlasIcon { anchors.centerIn: parent; width: 58; height: 58; name: files.selectedFile.directory ? "folder" : files.selectedFile.name ? (files.fileKind(files.selectedFile.name) === "pdf" ? "pdf" : "file") : "folder"; strokeColor: theme.atlasBlue }
                        }
                        Text { width: parent.width; text: files.selectedFile.name || "Dosya seçin"; color: theme.ink; font.pixelSize: 18; font.bold: true; elide: Text.ElideRight }
                        Text { width: parent.width; text: files.selectedFile.name ? (files.selectedFile.directory ? "Klasör" : "Dosya") : "Ayrıntılar burada görünür"; color: theme.muted; font.pixelSize: 13; elide: Text.ElideRight }
                        Rectangle { width: parent.width; height: 1; color: theme.borderSubtle }
                        Text { text: "BİLGİLER"; color: theme.ink; font.pixelSize: 13; font.bold: true }
                        Text { width: parent.width; text: "Konum: " + atlasFs.displayPath(files.currentFolder.toString()); color: theme.muted; font.pixelSize: 12; elide: Text.ElideMiddle }
                        Text { visible: !!files.selectedFile.name && !files.selectedFile.directory; text: "Boyut: " + files.formatBytes(files.selectedFile.size || 0); color: theme.muted; font.pixelSize: 12 }
                        Text { visible: !!files.selectedFile.name; width: parent.width; text: "Değiştirildi: " + (files.selectedFile.modified || "Bilinmiyor"); color: theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap }
                        AtlasButton { width: parent.width; height: 50; text: "Aç"; iconName: "arrow-right"; enabled: !!files.selectedFile.url; onClicked: files.openItem(files.selectedFile) }
                        AtlasButton { visible: files.isUsbLocation(); width: parent.width; height: 50; text: "USB'yi Çıkar"; iconName: "folder"; variant: "secondary"; onClicked: { var result = atlasFs.ejectRemovableVolume(files.currentFolder.toString()); files.usbMessage = result.message; if (result.ok) files.navigate(files.homeFolder) } }
                        Text { visible: files.usbMessage.length > 0; width: parent.width; text: files.usbMessage; color: theme.muted; font.pixelSize: 12; wrapMode: Text.WordWrap }
                    }
                }
                GridView {
                    id: grid
                    visible: files.gridMode && files.folderAvailable
                    x: 12; y: 93; width: parent.width - detailsPane.width - 23; height: parent.height - 105
                    clip: true; model: folderModel
                    cellWidth: width >= 760 ? width / 4 : width >= 550 ? width / 3 : width / 2
                    cellHeight: files.width < 1450 ? 118 : 135
                    delegate: Rectangle {
                        property bool matchesSearch: files.searchText.length === 0 || fileName.toLocaleLowerCase().indexOf(files.searchText) >= 0
                        width: grid.cellWidth - 9; height: grid.cellHeight - 9
                        visible: matchesSearch; radius: theme.radiusMedium
                        color: files.selectedFile.url === fileUrl.toString() ? theme.atlasBlueSoft : hover.containsMouse ? theme.surfaceMuted : theme.surface
                        border.color: files.selectedFile.url === fileUrl.toString() ? theme.atlasBlue : "transparent"
                        AtlasIcon { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 54; height: 54; name: fileIsDir ? "folder" : files.fileKind(fileName) === "pdf" ? "pdf" : files.fileKind(fileName) === "video" ? "video" : "file"; strokeColor: fileIsDir ? theme.atlasBlue : theme.atlasNavy }
                        Text { x: 6; y: 72; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; text: fileName; color: theme.ink; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
                        Text { x: 6; y: 94; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; text: fileIsDir ? "Klasör" : files.formatBytes(fileSize); color: theme.muted; font.pixelSize: 12 }
                        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true
                            onClicked: files.selectedFile = {name: fileName, url: fileUrl.toString(), directory: fileIsDir, size: fileSize, modified: fileModified ? Qt.formatDateTime(fileModified, "dd.MM.yyyy HH:mm") : ""}
                            onDoubleClicked: files.openItem({name: fileName, url: fileUrl.toString(), directory: fileIsDir})
                        }
                    }
                }
                ListView {
                    id: list; visible: !files.gridMode && files.folderAvailable
                    x: 12; y: 93; width: parent.width - detailsPane.width - 23; height: parent.height - 105
                    clip: true; model: folderModel; spacing: 4
                    delegate: Rectangle { property bool matchesSearch: files.searchText.length === 0 || fileName.toLocaleLowerCase().indexOf(files.searchText) >= 0
                        width: list.width; height: matchesSearch ? 58 : 0; visible: matchesSearch; radius: 8
                        color: files.selectedFile.url === fileUrl.toString() ? theme.atlasBlueSoft : theme.surface
                        AtlasIcon { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; name: fileIsDir ? "folder" : "file"; strokeColor: theme.atlasBlue }
                        Text { x: 51; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 135; text: fileName; color: theme.ink; font.pixelSize: 15; elide: Text.ElideRight }
                        Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: fileIsDir ? "Klasör" : files.formatBytes(fileSize); color: theme.muted; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent
                            onClicked: files.selectedFile = {name: fileName, url: fileUrl.toString(), directory: fileIsDir, size: fileSize, modified: fileModified ? Qt.formatDateTime(fileModified, "dd.MM.yyyy HH:mm") : ""}
                            onDoubleClicked: files.openItem({name: fileName, url: fileUrl.toString(), directory: fileIsDir})
                        }
                    }
                }
                Text { anchors.centerIn: parent; visible: !files.folderAvailable || folderModel.count === 0; text: files.folderAvailable ? "Bu klasör boş" : "Bu konum okunamıyor"; color: theme.muted; font.pixelSize: 17 }
            }
        }
    }
}
