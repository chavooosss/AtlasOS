import QtQuick
import QtQuick.Controls as Controls
import Qt.labs.folderlistmodel
import "../theme"

Item {
    id: files
    property bool boardMode: false
    property string kind: ""
    property url homeFolder: "file:///home/atlas"
    property url booksFolder: "file:///home/atlas/Ders%20Kitaplari"
    property url downloadsFolder: "file:///home/atlas/Downloads"
    property url currentFolder: booksFolder
    property string usbMessage: ""
    property string searchText: ""
    readonly property bool folderAvailable: atlasFs.directoryExists(currentFolder.toString())
    signal chosen(string kind, string url)
    AtlasTheme { id: theme }

    function open(kindName) {
        kind = kindName
        searchText = ""
        currentFolder = kindName === "books" ? booksFolder : kindName === "library" && atlasFs.directoryExists(booksFolder) ? booksFolder : homeFolder
    }

    function goParent() {
        if (folderModel.parentFolder.toString().length)
            currentFolder = folderModel.parentFolder
    }

    function back() {
        var start = kind === "books" ? booksFolder : homeFolder
        if (currentFolder.toString() === start.toString()) return false
        goParent()
        return true
    }

    function fileKind(name) {
        var suffix = name.toLowerCase().split(".").pop()
        if (suffix === "pdf") return "pdf"
        if (["odp", "ppt", "pptx"].indexOf(suffix) >= 0) return "presentation"
        if (["mp4", "mkv", "webm", "avi"].indexOf(suffix) >= 0) return "video"
        if (["txt", "md", "csv", "log", "json", "xml", "yaml", "yml", "ini", "cfg", "conf", "html", "css", "sh", "py", "js", "ts"].indexOf(suffix) >= 0) return "text"
        return "unsupported"
    }

    FolderListModel {
        id: folderModel
        folder: files.currentFolder
        showDirs: true
        showFiles: true
        showDotAndDotDot: false
        showHidden: false
        showDirsFirst: true
        caseSensitive: false
        nameFilters: files.kind === "pdf" ? ["*.pdf"] :
                     files.kind === "presentation" ? ["*.odp", "*.ppt", "*.pptx"] :
                     files.kind === "video" ? ["*.mp4", "*.mkv", "*.webm", "*.avi"] : ["*"]
    }

    Rectangle { anchors.fill: parent; color: theme.canvas }
    Column {
        anchors.fill: parent
        anchors.margins: 22
        spacing: files.boardMode ? 18 : 14
        Text {
            text: files.kind === "books" ? "Ders Kitapları" : files.kind === "library" ? "Kaynak Rafı" : files.kind === "files" ? "Dosyalar" :
                  files.kind === "pdf" ? "PDF Seç" :
                  files.kind === "presentation" ? "Sunum Seç" : "Video Seç"
            color: theme.ink; font.family: theme.fontFamily; font.pixelSize: files.boardMode ? 32 : 28; font.bold: true
        }
        Row {
            width: parent.width; height: files.boardMode ? 76 : 68; spacing: 10
            Repeater {
                model: [
                    {title: "Kitaplık", folder: files.booksFolder},
                    {title: "Ev", folder: files.homeFolder},
                    {title: "İndirilenler", folder: files.downloadsFolder},
                    {title: "USB", folder: "usb://removable"}
                ]
                delegate: Rectangle {
                    width: Math.max(112, (files.width - 90) / 4); height: files.boardMode ? 76 : 68; radius: theme.radiusCard
                    color: (modelData.folder === "usb://removable" ? files.currentFolder.toString().indexOf("file:///media/") === 0 || files.currentFolder.toString().indexOf("file:///run/media/") === 0 : files.currentFolder.toString() === modelData.folder.toString()) ? theme.navy : "white"
                    border.color: theme.line
                    Text { anchors.centerIn: parent; text: modelData.title; color: parent.color === theme.navy ? "white" : theme.ink; font.family: theme.fontFamily; font.pixelSize: files.boardMode ? 17 : 16; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            files.usbMessage = ""
                            if (modelData.folder === "usb://removable") {
                                var result = atlasFs.mountRemovableVolumes()
                                if (result.ok && result.volumes.length > 0) {
                                    files.currentFolder = "file://" + encodeURI(result.volumes[0].folder)
                                    files.usbMessage = result.volumes.length > 1 ? result.volumes.length + " USB birimi bulundu; seçili: " + result.volumes[0].title : "USB belleği hazır: " + result.volumes[0].title
                                } else {
                                    files.currentFolder = files.homeFolder
                                    files.usbMessage = result.message
                                }
                            } else {
                                files.currentFolder = modelData.folder
                            }
                        }
                    }
                }
            }
        }
        Controls.TextField {
            width: parent.width
            height: files.boardMode ? 72 : 64
            visible: files.kind === "library" || files.kind === "books" || files.kind === "files"
            placeholderText: "Bu klasörde kaynak ara"
            font.family: theme.fontFamily; font.pixelSize: files.boardMode ? 19 : 17
            onTextChanged: files.searchText = text.trim().toLocaleLowerCase()
            background: Rectangle { radius: 10; color: "white"; border.color: theme.line }
        }
        Text {
            visible: files.kind === "library" && files.searchText.length > 0
            width: parent.width; height: visible ? 24 : 0
            text: "Arama geçerli klasörle sınırlıdır: " + atlasFs.displayPath(files.currentFolder.toString())
            color: theme.muted; font.pixelSize: 12; elide: Text.ElideMiddle
        }
        Text {
            visible: files.usbMessage.length > 0
            width: parent.width; height: visible ? 32 : 0
            text: files.usbMessage; color: theme.blue; font.pixelSize: 14; elide: Text.ElideRight
        }
        Row {
            width: parent.width; height: files.boardMode ? 76 : 68; spacing: 10
            Rectangle {
                width: files.boardMode ? 76 : 68; height: files.boardMode ? 76 : 68; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                AtlasIcon { anchors.centerIn: parent; name: "arrow-left"; strokeColor: theme.ink }
                MouseArea { anchors.fill: parent; onClicked: files.goParent() }
            }
            Rectangle {
                width: parent.width - (files.boardMode ? 86 : 78) - (files.currentFolder.toString().indexOf("file:///media/") === 0 || files.currentFolder.toString().indexOf("file:///run/media/") === 0 ? 198 : 0); height: files.boardMode ? 76 : 68; radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                Text {
                    anchors.fill: parent; anchors.margins: 14; verticalAlignment: Text.AlignVCenter
                    text: atlasFs.displayPath(files.currentFolder.toString())
                    color: theme.muted; font.pixelSize: 15; elide: Text.ElideMiddle
                }
            }
            Controls.Button {
                visible: files.currentFolder.toString().indexOf("file:///media/") === 0 || files.currentFolder.toString().indexOf("file:///run/media/") === 0
                width: visible ? 188 : 0; height: files.boardMode ? 76 : 68
                text: "USB'yi Çıkar"; font.pixelSize: 14
                onClicked: {
                    var result = atlasFs.ejectRemovableVolume(files.currentFolder.toString())
                    files.usbMessage = result.message
                    if (result.ok) files.currentFolder = files.homeFolder
                }
            }
        }
        Rectangle {
            width: parent.width; height: Math.max(100, parent.height - 190); radius: theme.radiusCard
            color: theme.surface; border.color: theme.line
            ListView {
                id: list
                visible: files.folderAvailable
                anchors.fill: parent; anchors.margins: 8
                clip: true; spacing: 2
                model: folderModel
                delegate: Rectangle {
                    property bool matchesSearch: files.searchText.length === 0 || fileIsDir || fileName.toLocaleLowerCase().indexOf(files.searchText) >= 0
                    width: list.width; height: matchesSearch ? (files.boardMode ? 76 : 68) : 0; radius: 10
                    visible: matchesSearch
                    color: touch.pressed ? theme.softBlue : touch.containsMouse ? theme.surfaceRaised : theme.surface
                    AtlasIcon {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        width: files.boardMode ? 32 : 28; height: width
                        name: fileIsDir ? "folder" : files.fileKind(fileName) === "pdf" ? "pdf" :
                              files.fileKind(fileName) === "presentation" ? "presentation" :
                              files.fileKind(fileName) === "video" ? "video" : "books"
                        strokeColor: fileIsDir ? theme.blue : theme.ink
                    }
                    Text {
                        x: files.boardMode ? 64 : 56; width: parent.width - (files.boardMode ? 122 : 110); anchors.verticalCenter: parent.verticalCenter
                        text: fileName; color: theme.ink; font.family: theme.fontFamily; font.pixelSize: files.boardMode ? 19 : 17; elide: Text.ElideRight
                    }
                    AtlasIcon { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; name: "arrow-right"; strokeColor: theme.muted }
                    MouseArea {
                        id: touch; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (fileIsDir) files.currentFolder = fileUrl
                            else files.chosen((files.kind === "books" || files.kind === "files") ? files.fileKind(fileName) : files.kind, fileUrl.toString())
                        }
                    }
                }
            }
            Column {
                anchors.centerIn: parent; width: parent.width - 40; spacing: 10
                visible: !files.folderAvailable || (folderModel.status !== FolderListModel.Loading && folderModel.count === 0)
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: files.folderAvailable && folderModel.status === FolderListModel.Ready ? "Bu konumda dosya yok" : "Bu konum okunamıyor veya bağlı değil"
                    color: theme.ink; font.pixelSize: 19; font.bold: true; wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: files.usbMessage.length > 0 ? files.usbMessage : "Başka bir klasör seçin."
                    color: theme.muted; font.pixelSize: 14
                }
            }
        }
    }
}
