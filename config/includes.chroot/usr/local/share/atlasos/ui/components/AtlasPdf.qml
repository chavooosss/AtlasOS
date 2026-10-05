import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Pdf
import "../theme"

Rectangle {
    id: panel
    objectName: "atlasPdf"
    property url sourceUrl: ""
    property string fileName: ""
    readonly property int pageCount: document.pageCount
    color: theme.canvas
    AtlasTheme { id: theme }

    function open(url) {
        sourceUrl = url
        fileName = atlasFs.displayPath(url).split("/").pop()
        fitTimer.restart()
    }
    function close() {
        sourceUrl = ""
        document.password = ""
        fileName = ""
    }

    PdfDocument {
        id: document
        source: panel.sourceUrl
        onPasswordRequired: passwordDialog.open()
        onStatusChanged: { if (document.status === PdfDocument.Ready) fitTimer.restart() }
    }
    Timer {
        id: fitTimer
        interval: 300
        onTriggered: {
            if (document.status === PdfDocument.Ready && view.width > 50 && view.height > 50)
                view.scaleToWidth(view.width - 24, view.height)
        }
    }

    Rectangle {
        id: controls
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 76; color: "white"; border.color: theme.line
        Row {
            anchors.left: parent.left; anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter; spacing: 8
            Controls.Button {
                width: 64; height: 64; text: "‹"; font.pixelSize: 24
                enabled: view.currentPage > 0
                onClicked: view.goToPage(view.currentPage - 1)
            }
            Controls.Button {
                width: 64; height: 64; text: "›"; font.pixelSize: 24
                enabled: view.currentPage >= 0 && view.currentPage + 1 < document.pageCount
                onClicked: view.goToPage(view.currentPage + 1)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: document.pageCount > 0 ? (view.currentPage + 1) + " / " + document.pageCount : "Sayfa yok"
                color: theme.ink; font.pixelSize: 18
            }
            Controls.Button {
                width: 64; height: 64; text: "−"; font.pixelSize: 22
                onClicked: view.renderScale = Math.max(0.5, view.renderScale / 1.25)
            }
            Controls.Button {
                width: 64; height: 64; text: "+"; font.pixelSize: 22
                onClicked: view.renderScale = Math.min(4, view.renderScale * 1.25)
            }
            Controls.Button {
                width: 140; height: 64; text: "Sığdır"; font.pixelSize: 17
                onClicked: view.scaleToWidth(view.width - 24, view.height)
            }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(100, parent.width - 570)
            text: panel.fileName; color: theme.muted; font.pixelSize: 16
            horizontalAlignment: Text.AlignRight; elide: Text.ElideMiddle
        }
    }

    PdfMultiPageView {
        id: view
        anchors.top: controls.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        document: document
    }

    Text {
        anchors.centerIn: view
        visible: document.status === PdfDocument.Error
        width: Math.min(view.width - 40, 600)
        text: "PDF açılamadı. " + document.error
        color: theme.red; font.pixelSize: 18; wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    Controls.Dialog {
        id: passwordDialog
        title: "PDF parolası"
        modal: true
        anchors.centerIn: parent
        standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel
        width: Math.min(400, parent.width - 40)
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
