import QtQuick
import QtQuick.Controls as Controls
import "../theme"

Rectangle {
    id: board
    signal saved(string path)
    signal saveFailed()
    property real scaleFactor: 1.0
    property color ink: "#163a5b"
    property real strokeWidth: 5 * scaleFactor
    property var strokes: []
    objectName: "atlasWhiteboard"
    color: theme.canvas
    AtlasTheme { id: theme }

    function redraw() {
        canvas.requestPaint()
    }
    function save() {
        canvas.requestPaint()
        Qt.callLater(function() {
            var path = atlasFs.saveWhiteboard(canvas.toDataURL("image/png"))
            if (path.length > 0) board.saved(path)
            else board.saveFailed()
        })
    }
    function clear() {
        strokes = []
        redraw()
    }

    Rectangle {
        id: toolbar
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 76 * board.scaleFactor; color: "white"; border.color: theme.line
        Row {
            anchors.left: parent.left; anchors.leftMargin: 12 * board.scaleFactor
            anchors.verticalCenter: parent.verticalCenter; spacing: 8 * board.scaleFactor
            Repeater {
                model: ["#163a5b", "#d9414e", "#138567", "#347fc4", "#111111"]
                delegate: Rectangle {
                    width: 64 * board.scaleFactor; height: 64 * board.scaleFactor; radius: width / 2
                    color: modelData
                    border.width: board.ink === modelData ? 4 : 1
                    border.color: board.ink === modelData ? "#e6a735" : "#dce6eb"
                    MouseArea { anchors.fill: parent; onClicked: board.ink = modelData }
                }
            }
            Controls.Button {
                width: 88 * board.scaleFactor; height: 64 * board.scaleFactor; text: "Geri al"; font.pixelSize: 14 * board.scaleFactor
                enabled: board.strokes.length > 0
                onClicked: { board.strokes = board.strokes.slice(0, -1); board.redraw() }
            }
            Controls.Button {
                width: 104 * board.scaleFactor; height: 64 * board.scaleFactor; text: "Temizle"; font.pixelSize: 14 * board.scaleFactor
                onClicked: board.clear()
            }
            Controls.Button {
                width: 144 * board.scaleFactor; height: 64 * board.scaleFactor; text: "PNG kaydet"; font.pixelSize: 15 * board.scaleFactor
                onClicked: board.save()
            }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 16 * board.scaleFactor
            anchors.verticalCenter: parent.verticalCenter
            text: "Ders klasörüne PNG olarak kaydeder"
            color: theme.muted; font.pixelSize: 14 * board.scaleFactor
            visible: parent.width > 1050
        }
    }

    Rectangle {
        anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 12 * board.scaleFactor
        color: "white"; border.color: theme.line; radius: 5
        Canvas {
            id: canvas
            anchors.fill: parent; anchors.margins: 1
            renderTarget: Canvas.Image
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = "white"
                ctx.fillRect(0, 0, width, height)
                for (var i = 0; i < board.strokes.length; ++i) {
                    var stroke = board.strokes[i]
                    if (stroke.points.length < 2) continue
                    ctx.beginPath()
                    ctx.strokeStyle = stroke.color
                    ctx.lineWidth = stroke.width
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.moveTo(stroke.points[0].x * width, stroke.points[0].y * height)
                    if (stroke.points.length === 2) {
                        ctx.lineTo(stroke.points[1].x * width, stroke.points[1].y * height)
                    } else {
                        for (var j = 1; j < stroke.points.length - 1; ++j) {
                            var current = stroke.points[j]
                            var next = stroke.points[j + 1]
                            var middleX = (current.x + next.x) * width / 2
                            var middleY = (current.y + next.y) * height / 2
                            ctx.quadraticCurveTo(current.x * width, current.y * height, middleX, middleY)
                        }
                        var lastPoint = stroke.points[stroke.points.length - 1]
                        ctx.lineTo(lastPoint.x * width, lastPoint.y * height)
                    }
                    ctx.stroke()
                }
            }
            property int activeStroke: -1
            MultiPointTouchArea {
                anchors.fill: parent
                minimumTouchPoints: 1
                maximumTouchPoints: 1
                touchPoints: [ TouchPoint { id: touchPoint } ]
                onPressed: {
                    var list = board.strokes.slice()
                    list.push({color: board.ink, width: board.strokeWidth,
                               points: [{x: touchPoint.x / canvas.width, y: touchPoint.y / canvas.height}]})
                    board.strokes = list
                    canvas.activeStroke = list.length - 1
                    canvas.requestPaint()
                }
                onUpdated: {
                    if (canvas.activeStroke < 0) return
                    var list = board.strokes.slice()
                    var stroke = list[canvas.activeStroke]
                    stroke.points = stroke.points.concat([{x: touchPoint.x / canvas.width, y: touchPoint.y / canvas.height}])
                    list[canvas.activeStroke] = stroke
                    board.strokes = list
                    canvas.requestPaint()
                }
                onReleased: canvas.activeStroke = -1
                onCanceled: canvas.activeStroke = -1
            }
        }
    }
}
