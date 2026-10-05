import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Controls.TextField {
    id: field
    property real controlScale: 1.0
    AtlasTheme { id: theme }
    font.family: theme.fontFamily
    font.pixelSize: theme.typeBody * controlScale
    color: theme.ink
    selectByMouse: true
    leftPadding: 46 * controlScale
    rightPadding: 16 * controlScale
    implicitHeight: theme.controlHeight * controlScale
    background: Rectangle {
        radius: theme.radiusSmall * controlScale
        color: theme.surface
        border.width: field.activeFocus ? 2 : 1
        border.color: field.activeFocus ? theme.focus : theme.line
    }
    AtlasIcon {
        x: 14 * field.controlScale
        anchors.verticalCenter: parent.verticalCenter
        width: 20 * field.controlScale
        height: width
        name: "search"
        strokeColor: field.activeFocus ? theme.blue : theme.muted
    }
}
