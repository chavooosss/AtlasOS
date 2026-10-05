import QtQuick
import QtQuick.Controls
import "../theme"

Rectangle {
    id: panel
    objectName: "atlasTextViewer"
    color: theme.canvas
    AtlasTheme { id: theme }
    property string fileUrl: ""
    property string fileName: ""
    property string contents: ""
    property string editDraft: ""
    property string errorText: ""
    property bool canEdit: false
    property bool editing: false
    property bool discardForNavigation: false
    readonly property bool hasUnsavedChanges: editing && editDraft !== contents
    signal navigationDiscarded()

    function open(url) {
        fileUrl = url
        fileName = decodeURIComponent(url.split("/").pop() || "Metin dosyası")
        var response = atlasFs.readText(url)
        contents = response.text || ""
        editDraft = contents
        editing = false
        discardForNavigation = false
        errorText = response.error || ""
        canEdit = atlasFs.canOpen("text", url)
    }

    function startEditing() {
        errorText = ""
        editDraft = contents
        editing = true
    }

    function cancelEditing() {
        if (hasUnsavedChanges) {
            discardForNavigation = false
            discardDialog.open()
        } else {
            editing = false
        }
    }

    function requestNavigationDiscard() {
        discardForNavigation = true
        discardDialog.open()
    }

    function discardChanges() {
        editing = false
        editDraft = contents
        discardDialog.close()
        if (discardForNavigation) {
            discardForNavigation = false
            navigationDiscarded()
        }
    }

    function saveChanges() {
        var response = atlasFs.writeText(fileUrl, editDraft)
        if (response.ok) {
            contents = editDraft
            editing = false
            errorText = ""
            atlasAlerts.add("Metin düzenleyici", fileName + " Atlas içinde kaydedildi.")
        } else {
            errorText = response.error || "Dosya kaydedilemedi."
            atlasAlerts.add("Metin düzenleyici", errorText)
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        Row {
            width: parent.width
            height: 64
            Text {
                width: parent.width - actionGroup.width - 12
                anchors.verticalCenter: parent.verticalCenter
                text: panel.editing ? "Metin Düzenleyici · " + panel.fileName : panel.fileName
                color: theme.ink
                font.pixelSize: 20
                font.bold: true
                elide: Text.ElideMiddle
            }
            Row {
                id: actionGroup
                width: panel.editing ? 244 : 132
                height: 64
                spacing: 8
                Button {
                    width: 132
                    height: 64
                    visible: !panel.editing
                    text: "Düzenle"
                    font.pixelSize: 17
                    enabled: panel.canEdit
                    onClicked: panel.startEditing()
                }
                Button {
                    width: 112
                    height: 64
                    visible: panel.editing
                    text: "Vazgeç"
                    font.pixelSize: 16
                    onClicked: panel.cancelEditing()
                }
                Button {
                    width: 116
                    height: 64
                    visible: panel.editing
                    text: "Kaydet"
                    font.pixelSize: 16
                    enabled: panel.hasUnsavedChanges
                    onClicked: panel.saveChanges()
                }
            }
        }
        Text {
            id: errorBanner
            visible: panel.errorText.length > 0
            width: parent.width
            text: panel.errorText
            color: theme.red
            font.pixelSize: 16
            wrapMode: Text.WordWrap
        }
        ScrollView {
            width: parent.width
            height: Math.max(220, parent.height - 76 - (errorBanner.visible ? errorBanner.implicitHeight + parent.spacing : 0))
            clip: true
            TextArea {
                text: panel.editing ? panel.editDraft : panel.contents
                onTextChanged: if (panel.editing && panel.editDraft !== text) panel.editDraft = text
                readOnly: !panel.editing
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                font.pixelSize: 17
                color: theme.ink
                background: Rectangle { color: "white"; border.color: theme.line; radius: 6 }
                padding: 16
            }
        }
    }

    Dialog {
        id: discardDialog
        modal: true
        anchors.centerIn: parent
        width: 440
        title: "Kaydedilmemiş değişiklikler"
        contentItem: Column {
            width: parent.width
            spacing: 16
            Label {
                width: parent.width
                text: "Değişiklikler kaydedilmedi. Düzenlemeye dönmek mi, yoksa değişiklikleri atmak mı istiyorsunuz?"
                wrapMode: Text.WordWrap
            }
            Row {
                spacing: 10
                Button { text: "Düzenlemeye dön"; onClicked: discardDialog.close() }
                Button { text: "Değişiklikleri at"; onClicked: panel.discardChanges() }
            }
        }
    }
}
