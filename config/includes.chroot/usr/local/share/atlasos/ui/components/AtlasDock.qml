import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "../theme"

Window {
    id: dock
    property var atlasPreferences: null
    property var atlasWindows: null
    property bool showValidationContextMenu: false
    readonly property var groups: atlasWindows ? atlasWindows.dockGroups : []
    readonly property int taskCount: groups ? groups.length : 0
    readonly property bool boardMode: atlasPreferences !== null &&
        (atlasPreferences.displayMode === "board" ||
         (atlasPreferences.displayMode === "auto" && atlasPreferences.touchscreenDetected))
    readonly property real itemScale: boardMode ? 1.06 : 1.0
    readonly property real iconSlot: 56 * itemScale
    readonly property real itemGap: 8 * itemScale
    readonly property real sideInset: 12 * itemScale
    readonly property real dockHeight: 64 * itemScale
    readonly property real bottomFloat: 14 * itemScale
    readonly property real contentWidth: sideInset * 2 + taskCount * iconSlot + Math.max(0, taskCount - 1) * itemGap
    visible: taskCount > 0
    width: Math.min(Math.max(1, Screen.width - 24), contentWidth)
    height: dockHeight
    x: Math.round((Screen.width - width) / 2)
    y: Math.round(Screen.height - height - bottomFloat)
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    // The native capsule mask clips the outside; an opaque matching base avoids
    // black antialias fringes when XFWM's compositor is disabled for the session.
    color: "#f5f9fe"
    title: "AtlasOS Dock"
    AtlasTheme { id: theme }
    Behavior on width { NumberAnimation { duration: theme.motionNormal; easing.type: Easing.OutCubic } }

    // Keep the capsule's native window bounds clean; a separately offset,
    // translucent shadow exposed dark crescents at the shaped window edge.
    Rectangle {
        id: dockSurface
        objectName: "atlasDockSurface"
        anchors.fill: parent
        radius: theme.radiusPill
        color: "#f5f9fe"
        border.color: "#ffffff"
        border.width: 1

        Behavior on width { NumberAnimation { duration: theme.motionNormal; easing.type: Easing.OutCubic } }

        Flickable {
            id: taskViewport
            anchors.fill: parent
            anchors.leftMargin: dock.sideInset
            anchors.rightMargin: dock.sideInset
            contentWidth: taskRow.implicitWidth
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: taskRow
                height: taskViewport.height
                spacing: dock.itemGap

                Repeater {
                    model: dock.groups
                    delegate: Item {
                        id: taskSlot
                        width: dock.iconSlot
                        height: taskViewport.height
                        property bool hovered: taskMouse.containsMouse
                        function openMenu() {
                            var globalPoint = taskSlot.mapToGlobal(taskSlot.width / 2, 0)
                            appMenu.x = Math.max(4, Math.min(globalPoint.x - appMenu.width / 2, Screen.width - appMenu.width - 4))
                            appMenu.y = Math.max(4, dock.y - appMenu.height - 5)
                            appMenu.visible = true
                            appMenu.requestActivate()
                        }

                        Rectangle {
                            id: hoverSurface
                            anchors.centerIn: parent
                            width: 48 * dock.itemScale
                            height: width
                            radius: theme.radiusCard * dock.itemScale
                            color: taskSlot.hovered ? "#e5effa" : "transparent"
                            Behavior on color { ColorAnimation { duration: theme.motionFast } }
                            Behavior on scale { NumberAnimation { duration: theme.motionFast; easing.type: Easing.OutCubic } }
                            scale: taskSlot.hovered ? 1.08 : 1.0

                            Image {
                                id: appImage
                                anchors.centerIn: parent
                                width: 44 * dock.itemScale
                                height: width
                                source: modelData.iconData || ""
                                visible: status === Image.Ready
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }
                            AtlasIcon {
                                anchors.centerIn: parent
                                width: 36 * dock.itemScale
                                height: width
                                name: modelData.icon || "applications"
                                strokeColor: theme.navy
                                visible: appImage.status !== Image.Ready
                            }
                        }

                        Rectangle {
                            visible: modelData.active
                            width: 8 * dock.itemScale
                            height: width
                            radius: width / 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3 * dock.itemScale
                            color: theme.blue
                        }

                        MouseArea {
                            id: taskMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    taskSlot.openMenu()
                                } else {
                                    atlasWindows.activate(modelData.windowId)
                                }
                            }
                        }

                        ToolTip.visible: taskMouse.containsMouse && !appMenu.visible
                        ToolTip.delay: 450
                        ToolTip.text: modelData.title + (modelData.count > 1 ? " · " + modelData.count + " pencere" : "")

                        Window {
                            id: appMenu
                            objectName: "atlasDockContextMenu"
                            transientParent: dock
                            flags: Qt.FramelessWindowHint | Qt.Tool | Qt.WindowStaysOnTopHint
                            visible: false
                            color: "#fbfdff"
                            width: 204 * dock.itemScale
                            height: (40 + (modelData.count > 1 ? modelData.count * 36 : 0) + 1 + 36 +
                                     ((modelData.count > 1 ? modelData.count : 0) + 2) * 3 + 14) * dock.itemScale
                            onActiveChanged: if (visible && !active) visible = false

                            Rectangle {
                                anchors.fill: parent
                                radius: theme.radiusCard
                                color: "#fbfdff"
                                border.color: theme.line
                                border.width: 1
                            }

                            Column {
                                x: 7 * dock.itemScale
                                y: 7 * dock.itemScale
                                width: parent.width - 14 * dock.itemScale
                                height: parent.height - 14 * dock.itemScale
                                spacing: 3 * dock.itemScale

                                Rectangle {
                                    width: parent.width
                                    height: 40 * dock.itemScale
                                    radius: theme.radiusSmall
                                    color: menuActivate.containsMouse ? theme.paleBlue : "transparent"
                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 11 * dock.itemScale
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Uygulamaya Geç"
                                        color: theme.ink
                                        font.family: theme.fontFamily
                                        font.pixelSize: 13 * dock.itemScale
                                    }
                                    MouseArea {
                                        id: menuActivate
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: { atlasWindows.activate(modelData.windowId); appMenu.visible = false }
                                    }
                                }

                                Repeater {
                                    model: modelData.count > 1 ? modelData.windows : []
                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 36 * dock.itemScale
                                        radius: theme.radiusSmall
                                        color: memberMouse.containsMouse ? theme.paleBlue : "transparent"
                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 11 * dock.itemScale
                                            anchors.rightMargin: 9 * dock.itemScale
                                            verticalAlignment: Text.AlignVCenter
                                            text: modelData.title + (modelData.minimized ? " · simge durumunda" : "")
                                            color: theme.muted
                                            font.family: theme.fontFamily
                                            font.pixelSize: 12 * dock.itemScale
                                            elide: Text.ElideRight
                                        }
                                        MouseArea {
                                            id: memberMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: { atlasWindows.activate(modelData.id); appMenu.visible = false }
                                        }
                                    }
                                }

                                Rectangle { width: parent.width - 10 * dock.itemScale; height: 1; color: theme.line; anchors.horizontalCenter: parent.horizontalCenter }

                                Rectangle {
                                    width: parent.width
                                    height: 36 * dock.itemScale
                                    radius: theme.radiusSmall
                                    color: menuClose.containsMouse ? "#fff0f1" : "transparent"
                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 11 * dock.itemScale
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Kapat"
                                        color: theme.red
                                        font.family: theme.fontFamily
                                        font.pixelSize: 13 * dock.itemScale
                                    }
                                    MouseArea {
                                        id: menuClose
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: { atlasWindows.closeWindow(modelData.windowId); appMenu.visible = false }
                                    }
                                }
                            }
                        }

                        Connections {
                            target: dock
                            function onShowValidationContextMenuChanged() {
                                if (dock.showValidationContextMenu && index === 0)
                                    taskSlot.openMenu()
                            }
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.title + (modelData.count > 1 ? ", " + modelData.count + " pencere" : "")
                        Accessible.onPressAction: atlasWindows.activate(modelData.windowId)
                    }
                }
            }
        }
    }
}
