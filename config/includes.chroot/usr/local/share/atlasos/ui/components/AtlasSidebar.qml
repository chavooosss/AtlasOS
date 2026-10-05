import QtQuick
import "../theme"

Rectangle {
    id: sidebar
    property string currentPage: "home"
    property real itemScale: 1.0
    signal pageSelected(string page)
    signal powerRequested()
    gradient: Gradient {
        GradientStop { position: 0.0; color: "#102d49" }
        GradientStop { position: 1.0; color: "#1b3d5d" }
    }
    AtlasTheme { id: theme }

    Column {
        id: navigation
        anchors.fill: parent
        anchors.bottom: footer.top
        anchors.bottomMargin: 5 * sidebar.itemScale
        anchors.topMargin: 15 * sidebar.itemScale
        anchors.leftMargin: 8 * sidebar.itemScale
        anchors.rightMargin: 8 * sidebar.itemScale
        spacing: 5 * sidebar.itemScale
        Repeater {
            model: [
                { label: "Ana Sayfa", icon: "home", page: "home", active: true },
                { label: "Dersler", icon: "books", page: "lessons", active: true },
                { label: "Dosyalar", icon: "books", page: "books", active: true },
                { label: "Uygulamalar", icon: "applications", page: "tools", active: true },
                { label: "Ayarlar", icon: "settings", page: "settings", active: true },
                { label: "Hakkında", icon: "help", page: "about", active: true }
            ]
            delegate: Rectangle {
                width: parent.width; height: Math.min(88 * sidebar.itemScale, (parent.height - parent.spacing * 5) / 6); radius: 13
                color: currentPage === modelData.page ? "#285b8a" : "transparent"
                opacity: modelData.active ? 1 : 0.55
                Rectangle { width: 4; height: 45 * sidebar.itemScale; radius: 2; color: "#8edfd1"; visible: currentPage === modelData.page; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                AtlasIcon { id: menuIcon; anchors.horizontalCenter: parent.horizontalCenter; y: 14 * sidebar.itemScale; width: 28 * sidebar.itemScale; height: 28 * sidebar.itemScale; name: modelData.icon }
                Text { width: parent.width - 8; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12 * sidebar.itemScale; horizontalAlignment: Text.AlignHCenter; text: modelData.label; color: "white"; font.pixelSize: 13 * sidebar.itemScale; font.bold: currentPage === modelData.page; elide: Text.ElideRight }
                MouseArea { anchors.fill: parent; enabled: modelData.active; onClicked: sidebar.pageSelected(modelData.page) }
            }
        }
    }
    Column {
        id: footer
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 10 * sidebar.itemScale; spacing: 9 * sidebar.itemScale
        Rectangle { width: parent.width; height: 1; color: "#44637d" }
        Rectangle {
            width: parent.width; height: 66 * sidebar.itemScale; radius: 10; color: "transparent"
            AtlasIcon { id: powerIcon; anchors.horizontalCenter: parent.horizontalCenter; y: 8 * sidebar.itemScale; width: 25 * sidebar.itemScale; height: 25 * sidebar.itemScale; name: "power" }
            Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 7 * sidebar.itemScale; text: "Kapat"; color: "white"; font.pixelSize: 13 * sidebar.itemScale }
            MouseArea { anchors.fill: parent; onClicked: sidebar.powerRequested() }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "AtlasOS 0.6.3"; color: "#a6bdcf"; font.pixelSize: 10 * sidebar.itemScale }
    }
}
