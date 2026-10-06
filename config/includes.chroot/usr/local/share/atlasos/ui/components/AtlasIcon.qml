import QtQuick

Canvas {
    id: icon
    property string name: "home"
    property color strokeColor: "white"
    width: 24
    height: 24
    antialiasing: true
    onNameChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onPaint: {
        var c = getContext("2d")
        c.clearRect(0, 0, width, height)
        c.save()
        c.scale(width / 24, height / 24)
        c.strokeStyle = strokeColor
        c.fillStyle = strokeColor
        c.lineWidth = 1.8
        c.lineCap = "round"
        c.lineJoin = "round"
        function path(points) {
            c.beginPath(); c.moveTo(points[0], points[1])
            for (var i = 2; i < points.length; i += 2) c.lineTo(points[i], points[i + 1])
            c.stroke()
        }
        function rect(x, y, w, h) { c.strokeRect(x, y, w, h) }
        function circle(x, y, r) { c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.stroke() }
        switch (name) {
        case "home": path([3,11,12,4,21,11]); path([5,10,5,20,19,20,19,10]); path([10,20,10,14,14,14,14,20]); break
        case "books": rect(4,4,6,16); rect(10,4,6,16); path([17,5,21,19]); path([5,8,9,8,11,8,15,8]); break
        case "applications": rect(3,3,7,7); rect(14,3,7,7); rect(3,14,7,7); rect(14,14,7,7); break
        case "settings": circle(12,12,3); circle(12,12,8); path([12,2,12,5,12,19,12,22,2,12,5,12,19,12,22,12]); break
        case "help": circle(12,12,9); path([9,9,10,7,13,7,15,9,15,11,12,13,12,15]); circle(12,18,0.7); break
        case "power": path([12,2,12,12]); c.beginPath(); c.arc(12,12,9,-2.35,-0.79,true); c.stroke(); path([5,5,3,9,3,14,6,19,12,21,18,19,21,14,21,9,19,5]); break
        case "eba": rect(3,5,18,15); path([7,10,17,10,7,14,15,14]); break
        case "ogm": path([3,6,12,3,21,6,21,18,12,21,3,18,3,6]); path([7,10,12,8,17,10,17,15,12,17,7,15,7,10]); break
        case "mebi": path([4,5,12,8,20,5,20,19,12,21,4,19,4,5]); path([12,8,12,21]); break
        case "pdf": path([6,2,15,2,20,7,20,22,6,22,6,2]); path([15,2,15,7,20,7]); path([9,13,15,13,9,17,15,17]); break
        case "presentation": rect(3,3,18,14); path([12,17,12,22,8,22,16,22]); path([7,13,10,10,13,12,17,7]); break
        case "video": rect(3,4,18,16); path([10,8,16,12,10,16,10,8]); break
        case "whiteboard": rect(3,4,18,15); path([8,19,6,22,18,22,16,19]); path([7,14,10,11,13,13,17,8]); break
        case "screen-draw": rect(2,3,20,16); path([8,22,16,22,12,19]); path([7,14,16,5]); break
        case "calendar": rect(3,5,18,16); path([3,10,21,10,8,3,8,7,16,3,16,7]); break
        case "network": circle(12,19,1); path([5,13,8,10,12,9,16,10,19,13]); path([2,9,6,5,12,3,18,5,22,9]); break
        case "volume": path([3,9,7,9,12,5,12,19,7,15,3,15,3,9]); path([16,9,18,12,16,15]); path([19,6,22,12,19,18]); break
        case "volume-low": path([3,9,7,9,12,5,12,19,7,15,3,15,3,9]); path([16,10,18,12,16,14]); break
        case "volume-muted": path([3,9,7,9,12,5,12,19,7,15,3,15,3,9]); path([16,9,22,15]); path([22,9,16,15]); break
        case "pen": path([4,20,8,19,20,7,17,4,5,16,4,20]); path([14,7,17,10]); break
        case "bell": path([5,17,7,15,7,9,8,6,10,4,14,4,16,6,17,9,17,15,19,17,5,17]); path([10,20,14,20]); break
        case "bulb": circle(12,10,6); path([9,16,9,18,15,18,15,16]); path([10,21,14,21]); path([12,1,12,2]); path([3,10,5,10]); path([19,10,21,10]); path([5,3,7,5]); path([17,5,19,3]); break
        case "arrow-right": path([4,12,20,12,14,6]); path([20,12,14,18]); break
        case "arrow-left": path([20,12,4,12,10,6]); path([4,12,10,18]); break
        case "chevron-down": path([5,9,12,16,19,9]); break
        case "chevron-up": path([5,15,12,8,19,15]); break
        case "refresh": path([20,8,20,3,15,3]); c.beginPath(); c.arc(12,12,8,-2.3,0.15); c.stroke(); path([4,16,4,21,9,21]); c.beginPath(); c.arc(12,12,8,0.85,3.3); c.stroke(); break
        case "folder": path([2,7,2,20,22,20,22,8,11,8,9,5,2,5,2,7]); break
        case "search": circle(10,10,6); path([14.5,14.5,21,21]); break
        case "browser": circle(12,12,9); path([3,12,21,12]); path([12,3,9,7,8,12,9,17,12,21]); path([12,3,15,7,16,12,15,17,12,21]); break
        case "chemistry": path([9,3,15,3]); path([10,3,10,10,5,18,6,21,18,21,19,18,14,10,14,3]); path([8,16,16,16]); circle(10,18,0.7); circle(14,19,0.7); break
        case "physics": circle(12,12,2); c.beginPath(); c.ellipse(12,12,9,4,0,0,Math.PI*2); c.stroke(); c.beginPath(); c.ellipse(12,12,9,4,Math.PI/3,0,Math.PI*2); c.stroke(); break
        case "office": path([5,3,15,3,20,8,20,21,5,21,5,3]); path([15,3,15,8,20,8]); path([8,12,17,12]); path([8,16,17,16]); break
        case "terminal": path([4,6,10,12,4,18]); path([12,18,20,18]); break
        case "file": path([6,2,15,2,20,7,20,22,6,22,6,2]); path([15,2,15,7,20,7]); path([9,13,17,13]); path([9,17,17,17]); break
        case "star": path([12,3,14.8,8.8,21,9.6,16.5,14,17.6,20.5,12,17.4,6.4,20.5,7.5,14,3,9.6,9.2,8.8,12,3]); break
        }
        c.restore()
    }
}
