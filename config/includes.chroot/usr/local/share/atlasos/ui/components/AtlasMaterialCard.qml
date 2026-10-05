import QtQuick
import QtQuick.Controls
import "../theme"

Item {
    id: card
    property string title: ""
    property string detail: ""
    property string iconName: "books"
    property string kind: "Web"
    property color accent: "#17a982"
    property bool favorite: false
    property bool boardMode: false
    property real scaleFactor: 1.0
    signal activated()
    signal favoriteToggled(bool enabled)
    implicitHeight: (boardMode ? 128 : 112) * scaleFactor
    implicitWidth: 286 * scaleFactor
    AtlasTheme { id: theme }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: theme.radiusCard * card.scaleFactor
        color: cardArea.pressed ? theme.paleBlue : cardArea.containsMouse ? theme.surfaceRaised : theme.surface
        border.width: card.activeFocus ? 2 : 1
        border.color: card.activeFocus ? theme.focus : cardArea.containsMouse ? card.accent : theme.line
        Behavior on color { ColorAnimation { duration: theme.motionFast } }
    }
    Rectangle {
        x: 16 * card.scaleFactor
        anchors.verticalCenter: parent.verticalCenter
        width: 62 * card.scaleFactor; height: width
        radius: theme.radiusSmall * card.scaleFactor
        color: card.accent
        AtlasIcon { anchors.centerIn: parent; width: 31 * card.scaleFactor; height: width; name: card.iconName; strokeColor: "white" }
    }
    Column {
        anchors.left: parent.left; anchors.leftMargin: 92 * card.scaleFactor
        anchors.right: favoriteButton.left; anchors.rightMargin: 5 * card.scaleFactor
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5 * card.scaleFactor
        Text { width: parent.width; text: card.title; color: theme.ink; font.family: theme.fontFamily; font.pixelSize: 17 * card.scaleFactor; font.bold: true; elide: Text.ElideRight }
        Text { width: parent.width; text: card.detail; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 13 * card.scaleFactor; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
    }
    Rectangle {
        anchors.left: parent.left; anchors.leftMargin: 92 * card.scaleFactor
        anchors.bottom: parent.bottom; anchors.bottomMargin: 9 * card.scaleFactor
        width: kindText.implicitWidth + 16 * card.scaleFactor; height: 22 * card.scaleFactor
        radius: theme.radiusPill
        color: card.kind === "Cihazda" ? "#e5f6f1" : theme.paleBlue
        Text { id: kindText; anchors.centerIn: parent; text: card.kind; color: card.kind === "Cihazda" ? theme.green : theme.blue; font.family: theme.fontFamily; font.pixelSize: 10 * card.scaleFactor; font.bold: true }
    }
    Rectangle {
        id: favoriteButton
        z: 3
        anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: 8 * card.scaleFactor; anchors.rightMargin: 8 * card.scaleFactor
        width: card.boardMode ? 42 : 34; height: width; radius: width / 2
        color: favoriteArea.containsMouse ? theme.paleBlue : "transparent"
        AtlasIcon { anchors.centerIn: parent; width: 18; height: 18; name: "star"; strokeColor: card.favorite ? theme.amber : theme.muted }
        MouseArea { id: favoriteArea; anchors.fill: parent; hoverEnabled: true; onClicked: card.favoriteToggled(!card.favorite) }
        ToolTip.visible: favoriteArea.containsMouse
        ToolTip.text: card.favorite ? "Sık kullanılanlardan kaldır" : "Sık kullanılanlara ekle"
        Accessible.role: Accessible.Button
        Accessible.name: card.favorite ? "Sık kullanılanlardan kaldır" : "Sık kullanılanlara ekle"
        Accessible.onPressAction: card.favoriteToggled(!card.favorite)
    }
    MouseArea {
        id: cardArea
        anchors.fill: parent
        anchors.rightMargin: favoriteButton.width + 4
        hoverEnabled: true
        onClicked: card.activated()
    }
    focus: false
    activeFocusOnTab: true
    Keys.onReturnPressed: card.activated()
    Keys.onEnterPressed: card.activated()
    Accessible.role: Accessible.Button
    Accessible.name: card.title + ". " + card.detail
    Accessible.onPressAction: card.activated()
}
