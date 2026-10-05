import QtQuick
import QtWebEngine
import "../theme"

Item {
    id: browser
    objectName: "atlasBrowser"
    property var currentView: null
    property var views: []
    property string errorText: ""
    readonly property bool canGoBack: currentView && (currentView.canGoBack || views.length > 1)
    readonly property bool canGoForward: currentView && currentView.canGoForward
    readonly property bool loading: currentView && currentView.loading
    readonly property string currentUrl: currentView ? currentView.url.toString() : ""
    signal externalBrowserRequested(string url)
    AtlasTheme { id: theme }

    WebEngineProfile { id: lessonProfile; offTheRecord: true }

    function open(url) {
        errorText = ""
        if (currentView) {
            while (views.length > 1) closePopup()
            currentView.url = url
            return
        }
        var view = webComponent.createObject(webArea)
        if (!view) {
            errorText = "Web görünümü başlatılamadı."
            return
        }
        views = [view]
        currentView = view
        view.url = url
    }

    function openNewView(request) {
        var view = webComponent.createObject(webArea)
        if (!view) return
        if (currentView) currentView.visible = false
        views = views.concat([view])
        currentView = view
        view.acceptAsNewWindow(request)
    }

    function closePopup() {
        if (views.length < 2) return false
        var old = views[views.length - 1]
        views = views.slice(0, views.length - 1)
        currentView = views[views.length - 1]
        currentView.visible = true
        old.destroy()
        errorText = ""
        return true
    }

    function back() {
        if (currentView && currentView.canGoBack) currentView.goBack()
        else closePopup()
    }

    function forward() { if (currentView && currentView.canGoForward) currentView.goForward() }
    function reload() { if (currentView) { errorText = ""; currentView.reload() } }

    Component {
        id: webComponent
        WebEngineView {
            anchors.fill: parent
            profile: lessonProfile
            settings.fullScreenSupportEnabled: true
            onNewWindowRequested: function(request) { browser.openNewView(request) }
            onWindowCloseRequested: browser.closePopup()
            onLoadingChanged: function(loadRequest) {
                if (this === browser.currentView) {
                    if (loadRequest.status === WebEngineView.LoadFailedStatus)
                        browser.errorText = "Sayfa yüklenemedi. Bağlantınızı kontrol edin veya harici tarayıcıda açın."
                    else if (loadRequest.status === WebEngineView.LoadSucceededStatus)
                        browser.errorText = ""
                }
            }
        }
    }

    Rectangle { id: webArea; anchors.fill: parent; color: "white" }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 510); height: 188
        radius: 7; color: "white"; border.color: theme.line
        visible: browser.errorText.length > 0
        Column {
            anchors.centerIn: parent; width: parent.width - 40; spacing: 16
            Text { width: parent.width; text: "Kaynak açılamadı"; color: theme.ink; font.pixelSize: 21; font.bold: true }
            Text { width: parent.width; text: browser.errorText; color: theme.muted; font.pixelSize: 15; wrapMode: Text.WordWrap }
            Rectangle {
                width: 200; height: 64; radius: 6; color: theme.navy
                Text { anchors.centerIn: parent; text: "Harici tarayıcıda aç"; color: "white"; font.pixelSize: 15; font.bold: true }
                MouseArea { anchors.fill: parent; onClicked: browser.externalBrowserRequested(browser.currentUrl) }
            }
        }
    }
}
