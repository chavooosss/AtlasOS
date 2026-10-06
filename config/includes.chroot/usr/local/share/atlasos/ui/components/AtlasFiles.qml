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
    readonly property int navWidth: boardMode ? 248 : 218
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

    function chooseUsb() {
        usbMessage = ""
        var result = atlasFs.mountRemovableVolumes()
        if (result.ok && result.volumes.length > 0) {
            currentFolder = "file://" + encodeURI(result.volumes[0].folder)
            usbMessage = result.volumes.length > 1 ? result.volumes.length + " USB birimi bulundu; seçili: " + result.volumes[0].title : "USB belleği hazır: " + result.volumes[0].title
        } else {
            currentFolder = homeFolder
            usbMessage = result.message
        }
    }

    function selectLocation(key) {
        if (key === "usb") {
            chooseUsb()
            return
        }
        usbMessage = ""
        currentFolder = key === "books" ? booksFolder : key === "downloads" ? downloadsFolder : homeFolder
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

    Row {
        anchors.fill: parent
        anchors.margins: files.boardMode ? 22 : 18
        spacing: files.boardMode ? 20 : 16

        Rectangle {
            id: locationRail
            width: files.navWidth
            height: parent.height
            radius: theme.radiusPanel
            gradient: Gradient {
                GradientStop { position: 0; color: theme.shell }
                GradientStop { position: 1; color: theme.navy }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 9
                Text { x: 8; text: "KONUM"; color: theme.shellMutedText; font.family: theme.fontFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.1 }
                Repeater {
                    model: [
                        {key: "home", label: "Ana klasör", icon: "home"},
                        {key: "books", label: "Ders kitapları", icon: "books"},
                        {key: "downloads", label: "İndirilenler", icon: "file"},
                        {key: "usb", label: "USB bellek", icon: "folder"}
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: files.boardMode ? 68 : 60
                        radius: theme.radiusCard
                        property bool selected: modelData.key === "usb" ? files.isUsbLocation() : files.currentFolder.toString() === (modelData.key === "books" ? files.booksFolder.toString() : modelData.key === "downloads" ? files.downloadsFolder.toString() : files.homeFolder.toString())
                        color: selected ? theme.shellRaised : locationTouch.pressed ? "#23496f" : "transparent"
                        AtlasIcon {
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 23; height: 23; name: modelData.icon
                            strokeColor: parent.selected ? "#77cbff" : theme.shellMutedText
                        }
                        Text {
                            x: 48; width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label; color: theme.shellText
                            font.family: theme.fontFamily; font.pixelSize: 15; font.bold: parent.selected
                            elide: Text.ElideRight
                        }
                        Rectangle { visible: parent.selected; x: 0; width: 4; height: 34; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: "#61c5ff" }
                        MouseArea {
                            id: locationTouch
                            anchors.fill: parent
                            onClicked: files.selectLocation(modelData.key)
                        }
                    }
                }
                Item { width: 1; height: Math.max(0, parent.height - 390) }
                Rectangle { width: parent.width; height: 1; color: theme.shellLine }
                Text {
                    width: parent.width
                    text: files.usbMessage.length > 0 ? files.usbMessage : "Bağlı USB bellekler güvenli çıkarılabilir."
                    color: theme.shellMutedText; font.family: theme.fontFamily; font.pixelSize: 12
                    wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                }
            }
        }

        Column {
            id: workspace
            width: parent.width - locationRail.width - parent.spacing
            height: parent.height
            spacing: files.boardMode ? 16 : 13

            Row {
                width: parent.width
                height: files.boardMode ? 66 : 58
                spacing: 14
                Column {
                    width: parent.width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        text: files.kind === "books" ? "Ders Kitapları" : files.kind === "library" ? "Kaynak Rafı" : files.kind === "files" ? "Dosyalar" : files.kind === "pdf" ? "PDF Seç" : files.kind === "presentation" ? "Sunum Seç" : "Video Seç"
                        color: theme.ink; font.family: theme.fontFamily; font.pixelSize: files.boardMode ? 30 : 27; font.bold: true
                    }
                    Text { text: "Ders materyallerinize düzenli biçimde göz atın."; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 14 }
                }
            }

            Row {
                width: parent.width; height: files.boardMode ? 68 : 60; spacing: 10
                Rectangle {
                    width: files.boardMode ? 68 : 60; height: parent.height; radius: theme.radiusCard; color: theme.surface
                    AtlasIcon { anchors.centerIn: parent; name: "arrow-left"; strokeColor: theme.navy }
                    MouseArea { anchors.fill: parent; onClicked: files.goParent() }
                }
                Rectangle {
                    width: parent.width - (files.isUsbLocation() ? (files.boardMode ? 260 : 230) : (files.boardMode ? 78 : 70)); height: parent.height
                    radius: theme.radiusCard; color: theme.surface; border.color: theme.line
                    Text { anchors.fill: parent; anchors.margins: 16; verticalAlignment: Text.AlignVCenter; text: atlasFs.displayPath(files.currentFolder.toString()); color: theme.ink; font.pixelSize: 15; elide: Text.ElideMiddle }
                }
                AtlasButton {
                    visible: files.isUsbLocation(); width: visible ? (files.boardMode ? 182 : 160) : 0; height: parent.height
                    text: "USB'yi Çıkar"; iconName: "folder"; variant: "secondary"
                    onClicked: {
                        var result = atlasFs.ejectRemovableVolume(files.currentFolder.toString())
                        files.usbMessage = result.message
                        if (result.ok) files.currentFolder = files.homeFolder
                    }
                }
            }

            Controls.TextField {
                width: parent.width; height: files.boardMode ? 68 : 60
                visible: files.kind === "library" || files.kind === "books" || files.kind === "files"
                placeholderText: "Bu klasörde kaynak ara"
                font.family: theme.fontFamily; font.pixelSize: files.boardMode ? 18 : 16
                onTextChanged: files.searchText = text.trim().toLocaleLowerCase()
                background: Rectangle { radius: theme.radiusCard; color: theme.surface; border.color: theme.line }
            }

            Rectangle {
                width: parent.width; height: Math.max(100, parent.height - (files.kind === "library" || files.kind === "books" || files.kind === "files" ? 220 : 146))
                radius: theme.radiusPanel; color: theme.surfaceRaised
                ListView {
                    id: list
                    visible: files.folderAvailable
                    anchors.fill: parent; anchors.margins: 10
                    clip: true; spacing: 4; model: folderModel
                    delegate: Rectangle {
                        property bool matchesSearch: files.searchText.length === 0 || fileIsDir || fileName.toLocaleLowerCase().indexOf(files.searchText) >= 0
                        width: list.width; height: matchesSearch ? (files.boardMode ? 74 : 66) : 0
                        visible: matchesSearch; radius: 12
                        color: touch.pressed ? theme.paleBlue : touch.containsMouse ? theme.surface : "transparent"
                        AtlasIcon {
                            x: 14; anchors.verticalCenter: parent.verticalCenter
                            width: files.boardMode ? 30 : 27; height: width
                            name: fileIsDir ? "folder" : files.fileKind(fileName) === "pdf" ? "pdf" : files.fileKind(fileName) === "presentation" ? "presentation" : files.fileKind(fileName) === "video" ? "video" : "books"
                            strokeColor: fileIsDir ? theme.blue : theme.navy
                        }
                        Text {
                            x: 58; width: parent.width - 100; anchors.verticalCenter: parent.verticalCenter
                            text: fileName; color: theme.ink; font.family: theme.fontFamily; font.pixelSize: files.boardMode ? 18 : 16; elide: Text.ElideRight
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
                    anchors.centerIn: parent; width: parent.width - 48; spacing: 9
                    visible: !files.folderAvailable || (folderModel.status !== FolderListModel.Loading && folderModel.count === 0)
                    Text {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: files.folderAvailable && folderModel.status === FolderListModel.Ready ? "Bu konumda dosya yok" : "Bu konum okunamıyor veya bağlı değil"
                        color: theme.ink; font.pixelSize: 18; font.bold: true; wrapMode: Text.WordWrap
                    }
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: files.usbMessage.length > 0 ? files.usbMessage : "Başka bir klasör seçin."; color: theme.muted; font.pixelSize: 14; wrapMode: Text.WordWrap }
                }
            }
        }
    }
}
