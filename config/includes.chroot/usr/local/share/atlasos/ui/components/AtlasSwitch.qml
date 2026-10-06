import QtQuick
import "../theme"

Item {
    id: control
    property bool checked: false
    property bool enabled: true
    property string label: ""
    signal toggled(bool checked)
    implicitWidth: 54
    implicitHeight: 34
    width: 54
    height: 34

    AtlasTheme { id: theme }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: !control.enabled ? theme.disabledSurface : control.checked ? theme.atlasBlue : theme.surfaceMuted
        border.width: control.checked ? 0 : 1
        border.color: !control.enabled ? theme.borderSubtle : theme.atlasNavy
        Behavior on color { ColorAnimation { duration: theme.motionFast } }
    }
    Rectangle {
        width: 26
        height: 26
        y: (parent.height - height) / 2
        x: control.checked ? parent.width - width - 4 : 4
        radius: width / 2
        color: control.enabled ? theme.surface : theme.disabledInk
        border.color: control.enabled ? theme.borderSubtle : theme.disabledInk
        Behavior on x { NumberAnimation { duration: theme.motionFast; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        enabled: control.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: control.toggled(!control.checked)
    }
}
