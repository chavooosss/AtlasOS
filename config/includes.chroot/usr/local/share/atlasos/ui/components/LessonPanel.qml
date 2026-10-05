import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Rectangle {
    id: panel
    property var lessons: []
    property var timeline: []
    property var weeklySchedules: []
    property bool demo: true
    property string scheduleDay: ""
    property string classLabel: ""
    property int selectedWeekIndex: 0
    property date currentTime: new Date()
    property real scaleFactor: 1.0
    signal finishRequested()
    signal startRequested(string title, string start, string end)

    color: "#ffffff"
    border.color: theme.line
    AtlasTheme { id: theme }

    function lessonState(item, itemIndex) {
        var now = currentTime.getHours() * 60 + currentTime.getMinutes()
        var start = Number(item.start.slice(0, 2)) * 60 + Number(item.start.slice(3, 5))
        var end = Number(item.end.slice(0, 2)) * 60 + Number(item.end.slice(3, 5))
        if (now >= start && now < end) return "current"
        if (now < start) {
            for (var index = 0; index < panel.lessons.length; index++) {
                var candidate = panel.lessons[index]
                var candidateStart = Number(candidate.start.slice(0, 2)) * 60 + Number(candidate.start.slice(3, 5))
                if (candidateStart > now) return index === itemIndex ? "next" : "later"
            }
        }
        return "done"
    }

    function lessonToStart() {
        for (var index = 0; index < panel.lessons.length; index++) {
            var state = lessonState(panel.lessons[index], index)
            if (state === "current" || state === "next") return panel.lessons[index]
        }
        return null
    }

    Timer { interval: 30000; running: true; repeat: true; onTriggered: panel.currentTime = new Date() }

    Column {
        id: panelContent
        anchors.fill: parent
        anchors.margins: 19 * panel.scaleFactor
        spacing: 12 * panel.scaleFactor

        Item {
            width: parent.width
            height: 32 * panel.scaleFactor
            AtlasIcon { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 24 * panel.scaleFactor; height: 24 * panel.scaleFactor; name: "calendar"; strokeColor: theme.navy }
            Text { anchors.left: parent.left; anchors.leftMargin: 32 * panel.scaleFactor; anchors.verticalCenter: parent.verticalCenter; text: "Bugünkü Ders"; font.pixelSize: 20 * panel.scaleFactor; font.bold: true; color: theme.ink }
            Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "Tümünü Gör  →"; color: theme.blue; font.pixelSize: 13 * panel.scaleFactor; visible: panelContent.width >= 350 * panel.scaleFactor }
            MouseArea { anchors.fill: parent; onClicked: scheduleDialog.open() }
        }

        Rectangle {
            visible: panel.classLabel.length > 0
            width: parent.width
            height: 29 * panel.scaleFactor
            radius: 8 * panel.scaleFactor
            color: "#fff5df"
            Text { anchors.centerIn: parent; text: (panel.demo ? "ÖRNEK PROGRAM  ·  " : "SINIF PROGRAMI  ·  ") + panel.classLabel + (panel.scheduleDay.length > 0 ? "  ·  " + panel.scheduleDay : ""); color: "#835810"; font.pixelSize: 12 * panel.scaleFactor; font.bold: true; elide: Text.ElideRight; width: parent.width - 16 * panel.scaleFactor; horizontalAlignment: Text.AlignHCenter }
        }

        Text {
            visible: panel.lessons.length === 0
            width: parent.width
            text: panel.scheduleDay === "Hafta sonu" ? "Bugün ders yok" : "Henüz ders programı ayarlanmadı"
            color: theme.muted
            font.pixelSize: 14 * panel.scaleFactor
            wrapMode: Text.WordWrap
        }

        Flickable {
            id: scheduleList
            width: parent.width
            height: Math.max(112 * panel.scaleFactor, Math.min(scheduleColumn.implicitHeight, parent.height - (32 + (panel.demo ? 29 : 0) + 56 + (mottoCard.visible ? 112 : 0) + 60) * panel.scaleFactor))
            contentWidth: width
            contentHeight: scheduleColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: scheduleColumn
                width: parent.width
                spacing: 7 * panel.scaleFactor
                Repeater {
                    model: panel.lessons
                    delegate: Rectangle {
                        id: lessonCard
                        width: scheduleColumn.width
                        property string lessonStatus: panel.lessonState(modelData, index)
                        height: (lessonStatus === "current" ? 92 : 62) * panel.scaleFactor
                        radius: 10 * panel.scaleFactor
                        color: lessonStatus === "current" ? "#eaf7f4" : "#f7f9fb"
                        border.width: lessonStatus === "current" ? 2 : 1
                        border.color: lessonStatus === "current" ? theme.green : theme.line

                        Rectangle {
                            visible: lessonCard.lessonStatus === "current"
                            width: 6 * panel.scaleFactor
                            anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left
                            radius: 4 * panel.scaleFactor
                            color: theme.green
                        }
                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: 17 * panel.scaleFactor
                            anchors.rightMargin: 12 * panel.scaleFactor
                            anchors.topMargin: 8 * panel.scaleFactor
                            anchors.bottomMargin: 7 * panel.scaleFactor
                            spacing: 3 * panel.scaleFactor
                            Row {
                                width: parent.width
                                height: 20 * panel.scaleFactor
                                Text { width: parent.width - (lessonCard.lessonStatus === "current" ? 84 : 0) * panel.scaleFactor; text: modelData.start + " – " + modelData.end; color: lessonCard.lessonStatus === "current" ? theme.ink : theme.muted; font.pixelSize: 14 * panel.scaleFactor; font.bold: lessonCard.lessonStatus === "current"; elide: Text.ElideRight }
                                Rectangle {
                                    visible: lessonCard.lessonStatus === "current"
                                    width: visible ? 76 * panel.scaleFactor : 0; height: 25 * panel.scaleFactor; radius: 14 * panel.scaleFactor
                                    color: "#d5f2e8"
                                    Text { anchors.centerIn: parent; text: "Şu Anda"; color: theme.green; font.pixelSize: 11 * panel.scaleFactor; font.bold: true }
                                }
                            }
                            Text { width: parent.width; text: modelData.title; elide: Text.ElideRight; color: theme.ink; font.pixelSize: (lessonCard.lessonStatus === "current" ? 19 : 16) * panel.scaleFactor; font.bold: true }
                            Text { width: parent.width; text: modelData.class; elide: Text.ElideRight; color: theme.muted; font.pixelSize: 14 * panel.scaleFactor; visible: lessonCard.lessonStatus === "current" }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: panel.lessonToStart() !== null
            width: parent.width
            height: visible ? 54 * panel.scaleFactor : 0
            radius: 10 * panel.scaleFactor
            color: theme.navy
            Text { anchors.centerIn: parent; text: "Derse Başla  →"; color: "white"; font.pixelSize: 16 * panel.scaleFactor; font.bold: true }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    var lesson = panel.lessonToStart()
                    if (lesson) panel.startRequested(lesson.title, lesson.start, lesson.end)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 56 * panel.scaleFactor
            radius: 10 * panel.scaleFactor
            color: theme.red
            Row {
                anchors.centerIn: parent
                spacing: 10 * panel.scaleFactor
                Rectangle { width: 19 * panel.scaleFactor; height: 19 * panel.scaleFactor; radius: 3 * panel.scaleFactor; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Dersi Bitir"; color: "white"; font.pixelSize: 17 * panel.scaleFactor; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { anchors.fill: parent; onClicked: panel.finishRequested() }
        }

        Rectangle {
            id: mottoCard
            visible: panel.height >= 690 * panel.scaleFactor && panel.width >= 340 * panel.scaleFactor
            width: parent.width
            height: 112 * panel.scaleFactor
            radius: 10 * panel.scaleFactor
            color: "#edf5fc"
            AtlasIcon { x: 20 * panel.scaleFactor; anchors.verticalCenter: parent.verticalCenter; width: 48 * panel.scaleFactor; height: 48 * panel.scaleFactor; name: "bulb"; strokeColor: theme.blue }
            Column {
                anchors.left: parent.left; anchors.leftMargin: 84 * panel.scaleFactor
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * panel.scaleFactor
                Text { width: panelContent.width - 100 * panel.scaleFactor; text: "Merak eden, araştıran, üreten nesiller için."; color: theme.navy; font.pixelSize: 15 * panel.scaleFactor; font.italic: true; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                Text { text: "— AtlasOS"; color: theme.blue; font.pixelSize: 13 * panel.scaleFactor }
            }
        }
    }

    Controls.Dialog {
        id: scheduleDialog
        title: (panel.classLabel.length > 0 ? panel.scheduleDay + " · " + panel.classLabel : "Bugünkü Dersler")
        modal: true
        anchors.centerIn: parent
        width: Math.min(560, panel.width - 32)
        standardButtons: Controls.Dialog.Close
        onOpened: {
            for (var i = 0; i < panel.weeklySchedules.length; i++) {
                if (panel.weeklySchedules[i].day === panel.scheduleDay) {
                    panel.selectedWeekIndex = i
                    break
                }
            }
        }
        contentItem: Flickable {
            implicitWidth: 520
            implicitHeight: Math.min(460, scheduleDialogColumn.implicitHeight)
            contentWidth: width
            contentHeight: scheduleDialogColumn.implicitHeight
            clip: true
            Column {
                id: scheduleDialogColumn
                width: parent.width
                spacing: 8
                Controls.ComboBox {
                    width: parent.width
                    height: 56
                    visible: panel.weeklySchedules.length > 0
                    model: panel.weeklySchedules.map(function (entry) { return entry.day })
                    currentIndex: panel.selectedWeekIndex
                    onActivated: panel.selectedWeekIndex = currentIndex
                }
                Repeater {
                    model: panel.weeklySchedules.length > 0 && panel.selectedWeekIndex < panel.weeklySchedules.length ? panel.weeklySchedules[panel.selectedWeekIndex].timeline : (panel.timeline.length > 0 ? panel.timeline : panel.lessons)
                    delegate: Rectangle {
                        width: scheduleDialogColumn.width
                        height: modelData.kind === "break" ? 40 : 64
                        radius: 8
                        color: modelData.kind === "break" ? "#fff5df" : panel.lessonState(modelData, index) === "current" ? "#eaf7f4" : "#f7f9fb"
                        Row {
                            anchors.fill: parent; anchors.margins: 12; spacing: 18
                            Text { width: 110; text: modelData.start + " – " + modelData.end; color: theme.muted; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: parent.width - 150; text: modelData.kind === "break" ? modelData.title : modelData.period + ". ders  ·  " + modelData.title; color: theme.ink; font.bold: modelData.kind !== "break"; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }
    }
}
