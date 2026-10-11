import QtQuick
import QtQuick.Effects

Item {
    id: icon

    property string name: "home"
    property color strokeColor: "white"
    readonly property var tablerNames: ({
        "home": "home",
        "books": "books",
        "lessons": "books",
        "files": "folder",
        "applications": "apps",
        "settings": "settings",
        "about": "info-circle",
        "help": "help-circle",
        "power": "power",
        "eba": "school",
        "ogm": "book-2",
        "mebi": "book-2",
        "pdf": "file-type-pdf",
        "presentation": "presentation",
        "video": "player-play",
        "whiteboard": "chalkboard",
        "screen-draw": "pencil",
        "calendar": "calendar",
        "clock": "clock",
        "network": "router",
        "wifi": "wifi",
        "ethernet": "plug-connected",
        "airplane": "plane",
        "airplane-mode": "plane",
        "logout": "logout",
        "restart": "refresh",
        "notifications": "bell",
        "volume": "volume",
        "volume-low": "volume-2",
        "volume-muted": "volume-off",
        "pen": "pencil",
        "bell": "bell",
        "bulb": "bulb",
        "arrow-right": "arrow-right",
        "arrow-left": "arrow-left",
        "arrow-up": "arrow-up",
        "arrow-down": "arrow-down",
        "chevron-down": "chevron-down",
        "chevron-up": "chevron-up",
        "refresh": "refresh",
        "folder": "folder",
        "search": "search",
        "browser": "world-www",
        "chemistry": "flask",
        "physics": "atom-2",
        "office": "file-description",
        "terminal": "terminal-2",
        "file": "file",
        "document": "file-description",
        "star": "star",
        "display": "device-desktop",
        "accessibility": "accessible",
        "developer": "code",
        "bluetooth": "bluetooth",
        "night-light": "moon",
        "cast": "cast",
        "close": "x",
        "check": "check",
        "warning": "alert-triangle",
        "error": "circle-x",
        "info": "info-circle",
        "download": "download",
        "upload": "upload",
        "trash": "trash",
        "menu": "menu-2",
        "list": "list",
        "grid": "layout-grid",
        "fullscreen": "maximize",
        "minimize": "minimize",
        "external-link": "external-link",
        "lock": "lock",
        "unlock": "lock-open",
        "usb": "usb",
        "book": "book-2",
        "school": "school"
    })

    width: 24
    height: 24

    Image {
        id: tablerSource
        anchors.fill: parent
        visible: false
        cache: true
        asynchronous: true
        smooth: true
        sourceSize: Qt.size(Math.max(1, Math.ceil(icon.width * 2)), Math.max(1, Math.ceil(icon.height * 2)))
        source: Qt.resolvedUrl("../icons/tabler/" + (icon.tablerNames[icon.name] || "help-circle") + ".svg")
    }

    MultiEffect {
        anchors.fill: parent
        source: tablerSource
        colorization: 1.0
        colorizationColor: icon.strokeColor
    }

    Component.onCompleted: {
        if (name.length > 0 && tablerNames[name] === undefined)
            console.warn("AtlasIcon: unmapped icon name", name)
    }
}
