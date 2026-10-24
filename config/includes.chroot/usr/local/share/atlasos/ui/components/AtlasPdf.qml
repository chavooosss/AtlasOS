import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Pdf
import "../theme"

Rectangle {
    id: panel
    objectName: "atlasPdf"
    property url sourceUrl: ""
    property string fileName: ""
    property bool boardMode: false
    property real uiScale: 1.0
    property bool thumbnailsVisible: false
    property bool immersive: false
    property string fitMode: "fit-width"
    readonly property real density: boardMode ? uiScale : 1.0
    readonly property alias pdfDocument: document
    readonly property int pageCount: document.pageCount
    readonly property bool documentHasError: document.status === PdfDocument.Error
    readonly property int currentPage: document.pageCount > 0 && view.currentPage >= 0
        ? Math.min(view.currentPage, document.pageCount - 1) : -1
    readonly property int searchResultCount: view.searchModel.count
    readonly property int zoomPercentage: Math.round(view.renderScale * 100)
    signal openRequested()
    signal immersiveRequested(bool enabled)
    color: theme.canvas
    AtlasTheme { id: theme }

    component PaperToolButton: Controls.Button {
        id: toolButton
        property real scaleFactor: 1.0
        property bool primary: false
        font.family: "Noto Sans"
        font.pixelSize: 14 * scaleFactor
        font.bold: primary || checked
        padding: 8 * scaleFactor
        focusPolicy: Qt.StrongFocus
        background: Rectangle {
            radius: 8 * toolButton.scaleFactor
            color: !toolButton.enabled ? theme.disabledSurface :
                   toolButton.down ? theme.softBlue :
                   toolButton.primary || toolButton.checked ? theme.navy :
                   toolButton.hovered ? theme.paleBlue : theme.surface
            border.width: toolButton.activeFocus ? 2 : toolButton.primary || toolButton.checked ? 0 : 1
            border.color: toolButton.activeFocus ? theme.focus : theme.line
        }
        contentItem: Text {
            text: toolButton.text
            color: !toolButton.enabled ? theme.disabledInk :
                   toolButton.primary || toolButton.checked ? theme.surface : theme.ink
            font: toolButton.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
    }

    function open(url) {
        // Drop thumbnail delegates before PdfDocument switches sources.
        thumbnailsVisible = false
        sourceUrl = url
        view.renderScale = 1.0
        fitMode = "fit-width"
        fileName = atlasFs.displayPath(url).split("/").pop()
        searchField.text = ""
        pageField.text = ""
        immersive = false
        fitTimer.restart()
        Qt.callLater(view.forceActiveFocus)
    }
    function close() {
        sourceUrl = ""
        document.password = ""
        fileName = ""
        searchField.text = ""
        pageField.text = ""
        immersive = false
        immersiveRequested(false)
    }
    function setImmersive(enabled) {
        if (immersive === enabled) return
        immersive = enabled
        immersiveRequested(enabled)
        if (!enabled) fitTimer.restart()
        else Qt.callLater(view.forceActiveFocus)
    }
    function focusDocument() { view.forceActiveFocus() }
    function focusSearch() { searchField.forceActiveFocus(); searchField.selectAll() }
    function navigateByKey(key) {
        if (document.status !== PdfDocument.Ready || panel.currentPage < 0) return false
        if (key === Qt.Key_PageDown || key === Qt.Key_Right) view.goToPage(Math.min(document.pageCount - 1, panel.currentPage + 1))
        else if (key === Qt.Key_PageUp || key === Qt.Key_Left) view.goToPage(Math.max(0, panel.currentPage - 1))
        else if (key === Qt.Key_Home) view.goToPage(0)
        else if (key === Qt.Key_End) view.goToPage(document.pageCount - 1)
        else return false
        return true
    }
    function fitWidth() {
        if (document.status === PdfDocument.Ready && view.width > 50 && view.height > 50)
            view.scaleToWidth(view.width - 32 * density, view.height - 24 * density)
        if (document.status === PdfDocument.Ready) fitMode = "fit-width"
    }
    function fitPage() {
        if (document.status === PdfDocument.Ready && view.width > 50 && view.height > 50)
            view.scaleToPage(view.width - 32 * density, view.height - 24 * density)
        if (document.status === PdfDocument.Ready) fitMode = "fit-page"
    }
    function zoomBy(factor) {
        view.renderScale = Math.max(0.25, Math.min(6, view.renderScale * factor))
        fitMode = "custom"
    }
    function goToEnteredPage() {
        var requested = parseInt(pageField.text, 10)
        if (!isNaN(requested) && requested >= 1 && requested <= document.pageCount)
            view.goToPage(requested - 1)
        pageField.text = document.pageCount > 0 ? String(panel.currentPage + 1) : ""
    }
    function syncPageField() {
        pageField.text = document.pageCount > 0 && panel.currentPage >= 0 ? String(panel.currentPage + 1) : ""
    }

    PdfDocument {
        id: document
        source: panel.sourceUrl
        onPasswordRequired: passwordDialog.open()
        onStatusChanged: {
            if (document.status === PdfDocument.Ready) fitTimer.restart()
            else if (document.status === PdfDocument.Null) view.renderScale = 1.0
        }
    }
    Timer {
        id: fitTimer
        interval: 220
        onTriggered: {
            if (document.status === PdfDocument.Ready) {
                if (panel.fitMode === "fit-page") panel.fitPage()
                else if (panel.fitMode === "fit-width") panel.fitWidth()
                panel.syncPageField()
            }
        }
    }
    Shortcut {
        sequence: "Ctrl+f"
        enabled: panel.visible && document.status === PdfDocument.Ready
        onActivated: { searchField.forceActiveFocus(); searchField.selectAll() }
    }
    Shortcut {
        sequence: "Escape"
        enabled: panel.visible && panel.immersive
        onActivated: panel.setImmersive(false)
    }

    Rectangle {
        id: controls
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: panel.immersive ? 0 : 126 * panel.density
        visible: !panel.immersive
        color: theme.surface; border.color: theme.line

        Column {
            anchors.fill: parent
            anchors.leftMargin: 12 * panel.density
            anchors.rightMargin: 12 * panel.density
            anchors.topMargin: 6 * panel.density
            anchors.bottomMargin: 6 * panel.density
            spacing: 6 * panel.density

            Row {
                id: documentRow
                width: parent.width
                height: 52 * panel.density
                spacing: 8 * panel.density
                PaperToolButton {
                    objectName: "atlasPaperOpenButton"
                    width: 132 * panel.density; height: parent.height
                    text: "Dosya Aç"; primary: true
                    scaleFactor: panel.density
                    enabled: document.status !== PdfDocument.Loading
                    onClicked: panel.openRequested()
                }
                Text {
                    objectName: "atlasPaperDocumentName"
                    width: Math.max(120 * panel.density, parent.width - 460 * panel.density)
                    height: parent.height
                    text: panel.fileName || "Atlas Paper · PDF okuyucu"
                    color: panel.fileName ? theme.ink : theme.muted
                    font.family: theme.fontFamily; font.pixelSize: 15 * panel.density
                    font.bold: panel.fileName !== ""
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideMiddle
                }
                Rectangle {
                    width: 300 * panel.density; height: parent.height
                    radius: 10 * panel.density; color: theme.surfaceRaised; border.color: theme.line
                    Row {
                        anchors.fill: parent; anchors.margins: 3 * panel.density
                        spacing: 4 * panel.density
                        PaperToolButton {
                            objectName: "atlasPaperPreviousPageButton"
                            width: 48 * panel.density; height: 46 * panel.density
                            text: "‹"; scaleFactor: panel.density
                            enabled: panel.currentPage > 0
                            onClicked: { view.goToPage(panel.currentPage - 1); view.forceActiveFocus() }
                        }
                        Controls.TextField {
                            id: pageField
                            objectName: "atlasPaperPageField"
                            width: 74 * panel.density; height: 46 * panel.density
                            text: document.pageCount > 0 && panel.currentPage >= 0 ? String(panel.currentPage + 1) : ""
                            placeholderText: "Sayfa"
                            horizontalAlignment: TextInput.AlignHCenter
                            font.family: theme.fontFamily; font.pixelSize: 15 * panel.density
                            enabled: document.status === PdfDocument.Ready
                            onAccepted: panel.goToEnteredPage()
                        }
                        Text {
                            width: 66 * panel.density; height: 46 * panel.density
                            verticalAlignment: Text.AlignVCenter
                            text: "/ " + (document.pageCount > 0 ? document.pageCount : "—")
                            color: theme.muted; font.family: theme.fontFamily
                            font.pixelSize: 14 * panel.density
                        }
                        PaperToolButton {
                            objectName: "atlasPaperNextPageButton"
                            width: 48 * panel.density; height: 46 * panel.density
                            text: "›"; scaleFactor: panel.density
                            enabled: panel.currentPage >= 0 && panel.currentPage + 1 < document.pageCount
                            onClicked: { view.goToPage(panel.currentPage + 1); view.forceActiveFocus() }
                        }
                    }
                }
            }

            Row {
                id: actionRow
                width: parent.width
                height: 52 * panel.density
                spacing: 8 * panel.density
                Rectangle {
                    id: viewActions
                    width: 524 * panel.density; height: parent.height
                    radius: 10 * panel.density; color: theme.surfaceRaised; border.color: theme.line
                    Row {
                        anchors.fill: parent; anchors.margins: 3 * panel.density
                        spacing: 3 * panel.density
                        PaperToolButton {
                            objectName: "atlasPaperZoomOutButton"
                            width: 44 * panel.density; height: 46 * panel.density
                            text: "−"; scaleFactor: panel.density
                            enabled: document.status === PdfDocument.Ready
                            onClicked: panel.zoomBy(1 / 1.2)
                        }
                        Text {
                            objectName: "atlasPaperZoomPercentage"
                            width: 62 * panel.density; height: 46 * panel.density
                            text: panel.zoomPercentage + "%"
                            color: theme.ink; font.family: theme.fontFamily
                            font.pixelSize: 14 * panel.density; font.bold: true
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        }
                        PaperToolButton {
                            objectName: "atlasPaperZoomInButton"
                            width: 44 * panel.density; height: 46 * panel.density
                            text: "+"; scaleFactor: panel.density
                            enabled: document.status === PdfDocument.Ready
                            onClicked: panel.zoomBy(1.2)
                        }
                        PaperToolButton {
                            objectName: "atlasPaperFitPageButton"
                            width: 116 * panel.density; height: 46 * panel.density
                            text: "Sayfa"; checkable: true; checked: panel.fitMode === "fit-page"
                            scaleFactor: panel.density
                            enabled: document.status === PdfDocument.Ready
                            onClicked: panel.fitPage()
                        }
                        PaperToolButton {
                            objectName: "atlasPaperFitWidthButton"
                            width: 126 * panel.density; height: 46 * panel.density
                            text: "Genişlik"; checkable: true; checked: panel.fitMode === "fit-width"
                            scaleFactor: panel.density
                            enabled: document.status === PdfDocument.Ready
                            onClicked: panel.fitWidth()
                        }
                        PaperToolButton {
                            objectName: "atlasPaperThumbnailsButton"
                            width: 112 * panel.density; height: 46 * panel.density
                            text: panel.thumbnailsVisible ? "Sayfaları gizle" : "Sayfalar"
                            checkable: true; checked: panel.thumbnailsVisible
                            scaleFactor: panel.density
                            enabled: document.status === PdfDocument.Ready
                            onClicked: panel.thumbnailsVisible = !panel.thumbnailsVisible
                        }
                    }
                }
                Rectangle {
                    id: searchActions
                    width: Math.max(240 * panel.density, parent.width - viewActions.width - 8 * panel.density)
                    height: parent.height
                    radius: 10 * panel.density; color: theme.surfaceRaised; border.color: theme.line
                    Row {
                        anchors.fill: parent; anchors.margins: 3 * panel.density
                        spacing: 5 * panel.density
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Ara"; color: theme.muted
                            font.family: theme.fontFamily; font.pixelSize: 12 * panel.density
                        }
                        Controls.TextField {
                            id: searchField
                            objectName: "atlasPaperSearchField"
                            width: Math.max(90 * panel.density, searchActions.width - 368 * panel.density)
                            height: 46 * panel.density
                            placeholderText: "Belgede ara…"
                            font.family: theme.fontFamily; font.pixelSize: 14 * panel.density
                            enabled: document.status === PdfDocument.Ready
                            onTextChanged: view.searchString = text
                            onAccepted: if (view.searchModel.count > 0) view.searchForward()
                        }
                        Text {
                            objectName: "atlasPaperSearchResultCount"
                            width: 72 * panel.density; height: 46 * panel.density
                            text: searchField.text.length === 0 ? "" : searchResultCount > 0 ? (view.searchModel.currentResult + 1) + " / " + searchResultCount : "Yok"
                            color: theme.muted; font.family: theme.fontFamily
                            font.pixelSize: 12 * panel.density
                            verticalAlignment: Text.AlignVCenter
                        }
                        PaperToolButton {
                            width: 78 * panel.density; height: 46 * panel.density
                            text: "Önceki"; scaleFactor: panel.density
                            enabled: searchResultCount > 0; onClicked: view.searchBack()
                        }
                        PaperToolButton {
                            width: 78 * panel.density; height: 46 * panel.density
                            text: "Sonraki"; scaleFactor: panel.density
                            enabled: searchResultCount > 0; onClicked: view.searchForward()
                        }
                        PaperToolButton {
                            objectName: "atlasPaperFullscreenButton"
                            width: 116 * panel.density; height: 46 * panel.density
                            text: "Tam ekran"; scaleFactor: panel.density
                            enabled: document.status === PdfDocument.Ready
                            onClicked: panel.setImmersive(true)
                        }
                    }
                }
            }
        }
    }

    Row {
        anchors.top: controls.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 0
        Rectangle {
            id: thumbnailRail
            visible: panel.thumbnailsVisible && !panel.immersive && document.status === PdfDocument.Ready
            width: visible ? 190 * panel.density : 0
            height: parent.height; color: theme.surfaceRaised; border.color: theme.line
            ListView {
                id: thumbnailList
                objectName: "atlasPaperThumbnailList"
                anchors.fill: parent; anchors.margins: 8 * panel.density
                clip: true; spacing: 10 * panel.density
                cacheBuffer: Math.max(0, height * 2)
                model: document.pageCount
                delegate: Rectangle {
                    objectName: "atlasPaperThumbnail_" + index
                    width: thumbnailList.width - 4 * panel.density
                    height: 168 * panel.density
                    radius: 10 * panel.density
                    property bool activeThumbnail: panel.currentPage === index
                    property int renderedThumbnailStatus: pagePreview.status
                    property int renderedThumbnailFrame: pagePreview.currentFrame
                    property int renderedDocumentStatus: panel.pdfDocument.status
                    property int renderedImageDocumentPageCount: pagePreview.document ? pagePreview.document.pageCount : -1
                    property string renderedImageSource: pagePreview.source.toString()
                    color: panel.currentPage === index ? theme.atlasBlueSoft : theme.surface
                    border.width: panel.currentPage === index ? 2 * panel.density : 1
                    border.color: panel.currentPage === index ? theme.atlasBlue : theme.line
                    PdfPageImage {
                        id: pagePreview
                        objectName: "atlasPaperThumbnailImage_" + index
                        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top
                        anchors.topMargin: 8 * panel.density
                        width: parent.width - 18 * panel.density; height: 126 * panel.density
                        document: panel.pdfDocument; currentFrame: index; asynchronous: true
                        retainWhileLoading: true
                        cache: true
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                        sourceSize.height: 0
                    }
                    Text {
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 6 * panel.density
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Sayfa " + (index + 1); color: theme.ink
                        font.family: theme.fontFamily; font.pixelSize: 12 * panel.density
                    }
                    TapHandler { onTapped: { view.goToPage(index); view.forceActiveFocus() } }
                }
            }
        }
        PdfMultiPageView {
            id: view
            objectName: "atlasPaperPageView"
            width: parent.width - thumbnailRail.width
            height: parent.height
            document: panel.pdfDocument
            clip: true
            focus: true
            Keys.onPressed: function(event) {
                if (panel.navigateByKey(event.key)) event.accepted = true
            }
            onWidthChanged: if (document.status === PdfDocument.Ready && panel.fitMode !== "custom") fitTimer.restart()
            onHeightChanged: if (document.status === PdfDocument.Ready && panel.fitMode !== "custom") fitTimer.restart()
            onCurrentPageChanged: Qt.callLater(panel.syncPageField)
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48 * panel.density, 620 * panel.density)
        spacing: 14 * panel.density
        visible: document.status === PdfDocument.Null || document.status === PdfDocument.Loading || document.status === PdfDocument.Error
        Controls.BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: document.status === PdfDocument.Loading
            visible: running
            width: 56 * panel.density; height: 56 * panel.density
        }
        Text {
            width: parent.width
            visible: document.status === PdfDocument.Null
            text: "Atlas Paper\nPDF okumak için bir belge açın."
            color: theme.ink; font.pixelSize: 22 * panel.density; font.bold: true
            wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
        }
        Text {
            width: parent.width
            visible: document.status === PdfDocument.Loading
            text: "Belge açılıyor…"; color: theme.muted
            font.pixelSize: 18 * panel.density; horizontalAlignment: Text.AlignHCenter
        }
        Text {
            width: parent.width
            visible: document.status === PdfDocument.Error
            text: "PDF açılamadı.\n" + document.error
            color: theme.red; font.pixelSize: 18 * panel.density; wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        PaperToolButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: document.status === PdfDocument.Null || document.status === PdfDocument.Error
            width: 150 * panel.density; height: 54 * panel.density
            text: "PDF Aç"; onClicked: panel.openRequested()
        }
    }

    PaperToolButton {
        visible: panel.immersive
        z: 10
        anchors.top: parent.top; anchors.right: parent.right
        anchors.margins: 18 * panel.density
        width: 132 * panel.density; height: 58 * panel.density
        text: "Tam ekrandan çık"; primary: true; scaleFactor: panel.density
        onClicked: panel.setImmersive(false)
    }

    Controls.Dialog {
        id: passwordDialog
        title: "PDF parolası"
        modal: true
        anchors.centerIn: parent
        standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel
        width: Math.min(420 * panel.density, parent.width - 40)
        Controls.TextField {
            id: passwordField
            width: parent.width
            echoMode: TextInput.Password
            placeholderText: "Parola"
        }
        onAccepted: {
            document.password = passwordField.text
            passwordField.text = ""
        }
        onRejected: passwordField.text = ""
    }
}
