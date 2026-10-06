import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Controls.ComboBox {
    id: control
    AtlasTheme { id: theme }
    property real controlScale: 1.0
    implicitHeight: 52 * controlScale
    height: implicitHeight
    font.family: theme.fontFamily
    font.pixelSize: 15 * controlScale
    leftPadding: 16 * controlScale
    rightPadding: 42 * controlScale
    topPadding: 8 * controlScale
    bottomPadding: 8 * controlScale

    contentItem: Text {
        leftPadding: 0
        rightPadding: 0
        text: control.displayText
        color: control.enabled ? theme.ink : theme.disabledInk
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: theme.radiusSmall
        color: !control.enabled ? theme.disabledSurface : control.popup.visible ? theme.atlasBlueSoft : theme.surface
        border.width: control.activeFocus || control.popup.visible ? 2 : 1
        border.color: control.activeFocus || control.popup.visible ? theme.atlasBlue : theme.borderSubtle
        Behavior on color { ColorAnimation { duration: theme.motionFast } }
    }
    indicator: AtlasIcon {
        x: control.width - width - 14 * control.controlScale
        y: (control.height - height) / 2
        width: 18 * control.controlScale
        height: width
        name: control.popup.visible ? "chevron-up" : "chevron-down"
        strokeColor: control.enabled ? theme.atlasNavy : theme.disabledInk
    }
    popup: Controls.Popup {
        y: control.height + 6
        width: control.width
        padding: 6
        implicitHeight: Math.min(contentItem.implicitHeight + padding * 2, 260)
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        background: Rectangle { radius: theme.radiusSmall; color: theme.surface; border.color: theme.borderSubtle }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            spacing: 2
            delegate: Controls.ItemDelegate {
                width: ListView.view.width
                height: 44
                highlighted: control.highlightedIndex === index
                padding: 12
                background: Rectangle {
                    radius: theme.radiusSmall
                    color: highlighted ? theme.atlasBlueSoft : hovered ? theme.surfaceMuted : "transparent"
                }
                contentItem: Text {
                    text: control.textRole && model && model[control.textRole] !== undefined ? model[control.textRole] : modelData
                    color: theme.ink
                    font.family: theme.fontFamily
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    control.currentIndex = index
                    control.activated(index)
                    control.popup.close()
                }
            }
        }
    }
}
