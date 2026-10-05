import QtQuick
import QtQuick.Controls as Controls
import QtMultimedia
import "../theme"

Rectangle {
    id: panel
    objectName: "atlasVideo"
    property url sourceUrl: ""
    property string fileName: ""
    readonly property bool playing: player.playing
    readonly property int duration: player.duration
    color: "#111820"
    AtlasTheme { id: theme }

    function open(url) {
        sourceUrl = url
        fileName = atlasFs.displayPath(url).split("/").pop()
        player.play()
    }
    function close() {
        player.stop()
        sourceUrl = ""
        fileName = ""
    }
    function timeLabel(milliseconds) {
        var seconds = Math.floor(milliseconds / 1000)
        return Math.floor(seconds / 60) + ":" + (seconds % 60 < 10 ? "0" : "") + seconds % 60
    }

    MediaPlayer {
        id: player
        source: panel.sourceUrl
        audioOutput: AudioOutput { id: audio; volume: 0.8 }
        videoOutput: output
    }
    VideoOutput {
        id: output
        anchors.top: parent.top; anchors.bottom: controls.top
        anchors.left: parent.left; anchors.right: parent.right
        fillMode: VideoOutput.PreserveAspectFit
    }
    Text {
        anchors.centerIn: output
        width: Math.min(output.width - 40, 600)
        visible: player.error !== MediaPlayer.NoError
        text: "Video açılamadı: " + player.errorString
        color: "white"; font.pixelSize: 18; wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
    Rectangle {
        id: controls
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 86; color: theme.deepNavy
        Row {
            anchors.fill: parent; anchors.margins: 10; spacing: 10
            Controls.Button {
                width: 76; height: 64
                text: player.playing ? "Duraklat" : "Oynat"
                font.pixelSize: 14
                onClicked: player.playing ? player.pause() : player.play()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: panel.timeLabel(player.position)
                color: "white"; font.pixelSize: 16
            }
            Controls.Slider {
                id: seek
                width: Math.max(120, controls.width - 475); height: 64
                from: 0; to: Math.max(1, player.duration)
                enabled: player.seekable
                onMoved: player.position = value
            }
            Binding { target: seek; property: "value"; value: player.position; when: !seek.pressed }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: panel.timeLabel(player.duration)
                color: "white"; font.pixelSize: 16
            }
            Controls.Button {
                width: 64; height: 64
                text: audio.muted ? "Ses aç" : "Sessiz"
                font.pixelSize: 13
                onClicked: audio.muted = !audio.muted
            }
            Controls.Slider {
                width: 100; height: 64
                from: 0; to: 1; value: audio.volume
                onMoved: audio.volume = value
            }
        }
    }
    Text {
        anchors.left: parent.left; anchors.leftMargin: 14
        anchors.bottom: controls.top; anchors.bottomMargin: 8
        width: parent.width - 28
        text: panel.fileName; color: "white"; font.pixelSize: 15; elide: Text.ElideMiddle
    }
}
