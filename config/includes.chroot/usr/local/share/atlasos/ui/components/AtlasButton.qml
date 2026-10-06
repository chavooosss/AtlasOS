import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Controls.Button {
    id: control
    property string variant: "secondary" // primary, secondary, quiet, danger
    property string iconName: ""
    property real controlScale: 1.0
    property bool loading: false
    AtlasTheme { id: theme }
    font.family: theme.fontFamily
    font.pixelSize: 15 * controlScale
    font.bold: variant === "primary" || checked
    padding: 14 * controlScale
    spacing: 9 * controlScale
    implicitHeight: Math.max(theme.controlHeight * controlScale, contentItem.implicitHeight + padding * 2)
    focusPolicy: Qt.StrongFocus

    background: Rectangle {
        radius: theme.radiusSmall * controlScale
        color: !control.enabled ? (control.variant === "darkSecondary" ? theme.shellRaised : theme.disabledSurface) :
               control.down ? (control.variant === "primary" ? theme.deepNavy : control.variant === "darkSecondary" ? theme.shellRaised : theme.softBlue) :
               control.hovered || control.checked ? (control.variant === "primary" ? theme.deepNavy : control.variant === "darkSecondary" ? theme.shellRaised : theme.paleBlue) :
               control.variant === "primary" ? theme.navy :
               control.variant === "danger" ? theme.red :
               control.variant === "darkSecondary" ? theme.shellRaised :
               control.variant === "quiet" ? "transparent" : theme.surface
        border.width: control.activeFocus ? 2 : control.variant === "quiet" || control.variant === "primary" || control.variant === "danger" ? 0 : 1
        border.color: control.activeFocus ? theme.focus : control.variant === "darkSecondary" ? theme.shellLine : theme.line
        Behavior on color { ColorAnimation { duration: theme.motionFast } }
    }

    contentItem: Row {
        spacing: control.spacing
        anchors.centerIn: parent
        AtlasIcon {
            visible: control.iconName !== ""
            width: 20 * control.controlScale
            height: width
            anchors.verticalCenter: parent.verticalCenter
            name: control.iconName
            strokeColor: !control.enabled ? (control.variant === "darkSecondary" ? theme.shellMutedText : theme.disabledInk) : (control.variant === "primary" || control.variant === "danger") ? theme.surface : control.variant === "darkSecondary" ? theme.shellText : theme.ink
        }
        Text {
            text: control.loading ? "Yükleniyor…" : control.text
            color: !control.enabled ? (control.variant === "darkSecondary" ? theme.shellMutedText : theme.disabledInk) : (control.variant === "primary" || control.variant === "danger") ? theme.surface : control.variant === "darkSecondary" ? theme.shellText : theme.ink
            font: control.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
