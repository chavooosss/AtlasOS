import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Controls.Dialog {
    id: dialog
    property real dialogScale: 1.0
    AtlasTheme { id: theme }
    modal: true
    padding: 24 * dialogScale
    spacing: 18 * dialogScale
    focus: true
    Controls.Overlay.modal: Rectangle { color: theme.deepNavy; opacity: 0.42 }
    header: Rectangle {
        implicitHeight: 58 * dialog.dialogScale
        color: "transparent"
        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: dialog.title
            color: theme.ink
            font.family: theme.fontFamily
            font.pixelSize: 22 * dialog.dialogScale
            font.bold: true
            wrapMode: Text.WordWrap
        }
    }
    background: Rectangle {
        color: theme.surface
        radius: theme.radiusPanel * dialog.dialogScale
        border.color: theme.line
        border.width: 1
    }
}
