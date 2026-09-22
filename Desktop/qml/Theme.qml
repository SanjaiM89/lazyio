pragma Singleton
import QtQuick

// Sonance design tokens (mirrors FrontEnd/tailwind.config.js).
QtObject {
    // surfaces
    readonly property color background: "#151316"
    readonly property color surface: "#151316"
    readonly property color surfaceLow: "#1d1b1e"
    readonly property color surfaceContainer: "#211f22"
    readonly property color surfaceHigh: "#2c292c"
    readonly property color surfaceHighest: "#373437"
    // brand
    readonly property color primary: "#ffb4a4"
    readonly property color primaryContainer: "#e0836e"
    readonly property color onPrimary: "#5a1b0d"
    readonly property color onPrimaryContainer: "#5e1e10"
    readonly property color secondary: "#ffb3b0"
    readonly property color secondaryContainer: "#862025"
    readonly property color tertiary: "#ffb3b6"
    // text
    readonly property color onSurface: "#e7e1e5"
    readonly property color onVariant: "#dac1bc"
    readonly property color outline: "#a28c87"
    readonly property color error: "#ffb4ab"
    // type
    readonly property string fontMain: "Plus Jakarta Sans"
    readonly property string fontIcon: "Material Symbols Outlined"
    // layout
    readonly property int sideWidth: 256
    readonly property int queueWidth: 320
    readonly property int headerH: 64
    readonly property int playerH: 80

    function fmtTime(s) {
        if (s === undefined || s === null || isNaN(s) || s < 0)
            return "0:00";
        var m = Math.floor(s / 60), sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }
    function fmtLeft(progress, duration) {
        var left = Math.max(0, (duration || 0) - (progress || 0));
        return "-" + fmtTime(left).padStart(4, "0");
    }
}
