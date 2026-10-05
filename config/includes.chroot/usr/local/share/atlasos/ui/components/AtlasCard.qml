import QtQuick
import "../theme"

Rectangle {
    id: card
    property string title: ""
    property string detail: ""
    property string iconName: "books"
    property string target: ""
    property color accent: "#17a77b"
    property bool available: true
    property real cardHeight: 104
    property real iconSize: 64
    property real scaleFactor: 1.0
    property bool hovered: false
    property bool pressed: false
    signal activated(string target)
    height: card.cardHeight * card.scaleFactor
    radius: theme.radiusCard * card.scaleFactor
    color: available ? (card.pressed ? theme.paleBlue : theme.surface) : theme.disabledSurface
    border.color: theme.line
    AtlasTheme { id: theme }

    Rectangle {
        id: iconBox
        x: 14 * card.scaleFactor; y: (parent.height - height) / 2
        width: card.iconSize * card.scaleFactor; height: card.iconSize * card.scaleFactor; radius: theme.radiusSmall * card.scaleFactor
        color: available ? card.accent : "#9daeba"
        AtlasIcon { anchors.centerIn: parent; width: card.iconSize * 0.48; height: card.iconSize * 0.48; name: card.iconName }
    }
    Column {
        anchors.left: iconBox.right
        anchors.leftMargin: 13 * card.scaleFactor
        anchors.right: arrow.left
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5 * card.scaleFactor
        Text { width: parent.width; text: card.title; color: theme.ink; font.family: theme.fontFamily; font.pixelSize: (card.title.length > 10 ? 16 : theme.typeCard) * card.scaleFactor; font.bold: true; elide: Text.ElideRight }
        Text { width: parent.width; text: card.available ? card.detail : "Yakında"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: theme.typeSecondary * card.scaleFactor; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
    }
    AtlasIcon {
        id: arrow
        anchors.right: parent.right
        anchors.rightMargin: 14 * card.scaleFactor
        anchors.verticalCenter: parent.verticalCenter
        width: 20 * card.scaleFactor; height: 20 * card.scaleFactor
        name: "arrow-right"
        strokeColor: card.available ? theme.muted : "#aebcc5"
    }
    MouseArea {
        anchors.fill: parent
        enabled: card.available
        hoverEnabled: true
        onPressed: card.pressed = true
        onReleased: card.pressed = false
        onCanceled: card.pressed = false
        onClicked: card.activated(card.target)
        onEntered: { card.hovered = true; card.border.color = card.accent }
        onExited: { card.hovered = false; card.pressed = false; card.border.color = theme.line }
    }
    Accessible.role: Accessible.Button
    Accessible.name: card.title + ". " + card.detail
}
