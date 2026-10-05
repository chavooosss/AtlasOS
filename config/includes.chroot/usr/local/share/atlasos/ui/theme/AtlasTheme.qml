import QtQuick

QtObject {
    // Atlas Design Language: a small set of shared semantic tokens.
    // Values extend the existing 0.6.0 palette rather than replacing it.
    readonly property color navy: "#123d68"
    readonly property color deepNavy: "#0d2948"
    readonly property color blue: "#3e86e6"
    readonly property color paleBlue: "#eaf4fc"
    readonly property color softBlue: "#dceaf8"
    readonly property color ink: "#10294d"
    readonly property color muted: "#647997"
    readonly property color canvas: "#f3f8fd"
    readonly property color surface: "#ffffff"
    readonly property color surfaceRaised: "#f7faff"
    readonly property color line: "#e2eaf2"
    readonly property color red: "#f05261"
    readonly property color green: "#17a982"
    readonly property color amber: "#f0aa32"
    readonly property color disabledSurface: "#edf2f7"
    readonly property color disabledInk: "#8a9bb0"
    readonly property color focus: "#236fcb"
    readonly property real space1: 4
    readonly property real space2: 8
    readonly property real space3: 12
    readonly property real space4: 16
    readonly property real space5: 24
    readonly property real space6: 32
    readonly property real radiusSmall: 8
    readonly property real radiusCard: 14
    readonly property real radiusPanel: 20
    readonly property real radiusPill: 999
    readonly property int touch: 64
    readonly property int touchBoard: 76
    readonly property int controlHeight: 52
    readonly property int controlHeightBoard: 68
    readonly property int motionFast: 120
    readonly property int motionNormal: 180
    readonly property string fontFamily: "Noto Sans"
    readonly property real typeDisplay: 34
    readonly property real typePageTitle: 28
    readonly property real typeSection: 21
    readonly property real typeCard: 18
    readonly property real typeBody: 16
    readonly property real typeSecondary: 14
    readonly property real typeCaption: 12
}
