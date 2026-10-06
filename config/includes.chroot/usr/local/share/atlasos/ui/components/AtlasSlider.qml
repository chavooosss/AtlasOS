import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Controls.Slider {
    id: control
    property real controlScale: 1.0
    property bool darkMode: false
    AtlasTheme { id: theme }
    implicitHeight: 42 * controlScale
    focusPolicy: Qt.StrongFocus

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - 4 * control.controlScale
        width: control.availableWidth
        height: 8 * control.controlScale
        radius: height / 2
        color: control.darkMode ? theme.shellLine : theme.softBlue
        Rectangle {
            width: parent.width * control.visualPosition
            height: parent.height
            radius: parent.radius
            color: theme.blue
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: (control.activeFocus || control.hovered ? 28 : 24) * control.controlScale
        height: width
        radius: width / 2
        color: control.darkMode ? theme.shellText : theme.surface
        border.width: control.activeFocus ? 3 : 2
        border.color: control.activeFocus ? theme.focus : theme.blue
    }
}
