import QtQuick
import QtWebEngine
import "../theme"
import "."

Item {
    id: browser
    objectName: "atlasBrowser"

    property var currentView: null
    property string errorText: ""
    property string errorTitle: "Sayfa açılamadı"

    // Browser chrome density and page zoom are independent.
    property real uiScale: 1.0
    property real suggestedContentZoomFactor: 1.0
    property real userContentZoomFactor: 1.0
    property bool customContentZoom: false
    readonly property real effectiveContentZoomFactor: customContentZoom
        ? userContentZoomFactor : suggestedContentZoomFactor

    property string activePlatformKey: "eba"
    readonly property var platformDefinitions: ({
        eba: {
            title: "EBA — Eğitim Bilişim Ağı",
            host: "eba.gov.tr",
            url: "https://eba.gov.tr/",
            icon: "eba"
        },
        meb: {
            title: "MEB — Millî Eğitim Bakanlığı",
            host: "meb.gov.tr",
            url: "https://meb.gov.tr/",
            icon: "school"
        },
        ogm: {
            title: "OGM Materyal",
            host: "ogmmateryal.eba.gov.tr",
            url: "https://ogmmateryal.eba.gov.tr/",
            icon: "ogm"
        },
        mebi: {
            title: "MEBİ — Bireysel Öğrenme Platformu",
            host: "mebi.eba.gov.tr",
            url: "https://mebi.eba.gov.tr/",
            icon: "mebi"
        },
        geogebra: {
            title: "GeoGebra",
            host: "www.geogebra.org",
            url: "https://www.geogebra.org/calculator",
            icon: "chemistry"
        }
    })
    readonly property var platformTabs: ["eba", "meb", "ogm", "mebi"]
    readonly property var activePlatform: platformDefinitions[activePlatformKey] || platformDefinitions.eba
    readonly property string addressHost: currentView && currentView.url && currentView.url.host
        ? currentView.url.host : activePlatform.host
    readonly property string currentUrl: currentView ? currentView.url.toString() : ""
    readonly property bool securePage: currentUrl.toLowerCase().indexOf("https://") === 0
    readonly property bool networkPage: currentUrl.toLowerCase().indexOf("http://") === 0 || securePage
    readonly property bool canGoBack: currentView ? currentView.canGoBack : false
    readonly property bool canGoForward: currentView ? currentView.canGoForward : false
    readonly property bool loading: currentView ? currentView.loading : false

    AtlasTheme { id: theme }

    WebEngineProfile {
        id: lessonProfile
        offTheRecord: true
    }

    function isAllowedHost(hostName) {
        var host = String(hostName || "").toLowerCase().replace(/\.$/, "")
        if (!host.length) return false
        var trustedRoots = ["eba.gov.tr", "meb.gov.tr", "turkiye.gov.tr", "geogebra.org"]
        for (var i = 0; i < trustedRoots.length; ++i) {
            var rootHost = trustedRoots[i]
            if (host === rootHost || host.endsWith("." + rootHost)) return true
        }
        return false
    }

    function isAllowedUrl(urlValue) {
        var url = String(urlValue || "")
        if (!/^https:\/\//i.test(url)) return false
        var authority = url.replace(/^https:\/\//i, "").split(/[/?#]/)[0].toLowerCase()
        var host = authority.substring(authority.lastIndexOf("@") + 1).replace(/:\d+$/, "")
        return isAllowedHost(host)
    }

    function ensureView() {
        if (currentView) return currentView
        var view = webComponent.createObject(webArea)
        if (!view) {
            errorTitle = "Tarayıcı açılamadı"
            errorText = "Web görünümü başlatılamadı."
            return null
        }
        currentView = view
        return view
    }

    // Only named, application-defined education targets can be opened here.
    function open(platformKey) {
        return openPlatform(platformKey)
    }

    function openPlatform(platformKey) {
        var platform = platformDefinitions[platformKey]
        if (!platform) {
            errorTitle = "Eğitim hedefi bulunamadı"
            errorText = "Bu tarayıcıda yalnızca tanımlı eğitim platformları açılabilir."
            return false
        }
        var view = ensureView()
        if (!view) return false
        activePlatformKey = platformKey
        errorText = ""
        view.url = platform.url
        return true
    }

    function home() {
        var platform = platformDefinitions[activePlatformKey] || platformDefinitions.eba
        var view = ensureView()
        if (!view) return
        errorText = ""
        view.url = platform.url
    }

    function back() { if (currentView && currentView.canGoBack) currentView.goBack() }
    function forward() { if (currentView && currentView.canGoForward) currentView.goForward() }
    function reload() { if (currentView) { errorText = ""; currentView.reload() } }

    function adjustContentZoom(delta) {
        if (!customContentZoom) userContentZoomFactor = effectiveContentZoomFactor
        customContentZoom = true
        userContentZoomFactor = Math.max(0.75, Math.min(2.0,
            Math.round((userContentZoomFactor + delta) * 100) / 100))
    }

    function resetContentZoom() { customContentZoom = false }

    Component {
        id: webComponent
        WebEngineView {
            anchors.fill: parent
            profile: lessonProfile
            zoomFactor: browser.effectiveContentZoomFactor
            settings.fullScreenSupportEnabled: true

            onNavigationRequested: function(request) {
                if (!request.isMainFrame || browser.isAllowedUrl(request.url.toString())) {
                    request.accept()
                    return
                }
                request.reject()
                browser.errorTitle = "Bu bağlantı açılamadı"
                browser.errorText = "Hedef, Eğitim Tarayıcısı'nın güvenli eğitim adresleri arasında değil. EBA, MEB veya OGM'nin giriş ve içerik akışı farklı bir resmî alan adına yönleniyorsa bu alan ayrıca doğrulanmalıdır."
            }

            onNewWindowRequested: function(request) {
                var destination = request.requestedUrl ? request.requestedUrl.toString() : ""
                if (browser.currentView && browser.isAllowedUrl(destination)) {
                    // Keep one visible browser tab while allowing trusted sign-in/content popups.
                    request.openIn(browser.currentView)
                } else {
                    browser.errorTitle = "Yeni sayfa açılamadı"
                    browser.errorText = "Bu bağlantı güvenli eğitim adresleri dışında yeni bir sayfa açmak istedi ve engellendi."
                }
            }

            onUrlChanged: {
                if (this === browser.currentView)
                    browser.errorText = ""
            }
            onLoadingChanged: function(loadRequest) {
                if (this !== browser.currentView) return
                if (loadRequest.status === WebEngineView.LoadFailedStatus) {
                    browser.errorTitle = "Sayfa yüklenemedi"
                    browser.errorText = "Bağlantıyı kontrol edin. Sertifika doğrulaması devrede kalır; güvenilmeyen sertifikalar atlatılmaz."
                } else if (loadRequest.status === WebEngineView.LoadSucceededStatus) {
                    browser.errorText = ""
                }
            }
        }
    }

    Rectangle {
        id: brandBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48 * browser.uiScale
        color: "#f7faff"
        border.color: theme.line

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20 * browser.uiScale
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * browser.uiScale

            Image {
                width: 30 * browser.uiScale
                height: 30 * browser.uiScale
                source: "../branding/atlas-symbol.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Atlas OS"
                color: theme.ink
                font.family: theme.fontFamily
                font.pixelSize: 17 * browser.uiScale
                font.bold: true
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 22 * browser.uiScale
                color: theme.line
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Eğitim Tarayıcısı"
                color: theme.navy
                font.family: theme.fontFamily
                font.pixelSize: 15 * browser.uiScale
            }
        }
    }

    Rectangle {
        id: tabStrip
        anchors.top: brandBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 42 * browser.uiScale
        color: "#edf4fb"
        border.color: theme.line

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12 * browser.uiScale
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * browser.uiScale

            Repeater {
                model: browser.platformTabs
                delegate: Rectangle {
                    readonly property var platform: browser.platformDefinitions[modelData]
                    width: Math.max(142 * browser.uiScale, tabText.implicitWidth + 58 * browser.uiScale)
                    height: 34 * browser.uiScale
                    radius: 9 * browser.uiScale
                    color: browser.activePlatformKey === modelData ? "white" : "transparent"
                    border.color: browser.activePlatformKey === modelData ? theme.line : "transparent"

                    AtlasIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 10 * browser.uiScale
                        anchors.verticalCenter: parent.verticalCenter
                        width: 19 * browser.uiScale
                        height: 19 * browser.uiScale
                        name: platform.icon
                        strokeColor: modelData === "eba" ? "#df2148" : theme.navy
                    }
                    Text {
                        id: tabText
                        anchors.left: parent.left
                        anchors.leftMargin: 36 * browser.uiScale
                        anchors.right: parent.right
                        anchors.rightMargin: 10 * browser.uiScale
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData === "eba" ? "EBA — Eğitim Bilişim Ağı"
                            : modelData === "meb" ? "MEB — Millî Eğitim Bakanlığı"
                            : modelData === "ogm" ? "OGM Materyal" : "MEBİ"
                        color: browser.activePlatformKey === modelData ? theme.ink : theme.muted
                        font.family: theme.fontFamily
                        font.pixelSize: 13 * browser.uiScale
                        font.bold: browser.activePlatformKey === modelData
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: browser.openPlatform(modelData)
                    }
                }
            }
        }
    }

    Rectangle {
        id: navigationBar
        anchors.top: tabStrip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 66 * browser.uiScale
        color: "#fbfdff"
        border.color: theme.line

        Row {
            id: navigationButtons
            anchors.left: parent.left
            anchors.leftMargin: 14 * browser.uiScale
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7 * browser.uiScale

            Repeater {
                model: [
                    { icon: "arrow-left", enabled: browser.canGoBack, action: "back" },
                    { icon: "arrow-right", enabled: browser.canGoForward, action: "forward" },
                    { icon: "home", enabled: true, action: "home" },
                ]
                delegate: Rectangle {
                    width: 48 * browser.uiScale
                    height: 48 * browser.uiScale
                    radius: 12 * browser.uiScale
                    color: modelData.enabled ? "#edf4fb" : "#f1f4f7"
                    AtlasIcon {
                        anchors.centerIn: parent
                        width: 23 * browser.uiScale
                        height: 23 * browser.uiScale
                        name: modelData.icon
                        strokeColor: modelData.enabled ? theme.navy : theme.disabledInk
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: modelData.enabled
                        onClicked: {
                            if (modelData.action === "back") browser.back()
                            else if (modelData.action === "forward") browser.forward()
                            else if (modelData.action === "home") browser.home()
                            else browser.reload()
                        }
                    }
                }
            }
        }

        Row {
            id: zoomControls
            anchors.right: reloadButton.left
            anchors.rightMargin: 10 * browser.uiScale
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * browser.uiScale

            Rectangle {
                width: 40 * browser.uiScale; height: 44 * browser.uiScale
                radius: 9 * browser.uiScale; color: "#edf4fb"
                Text { anchors.centerIn: parent; text: "−"; color: theme.ink; font.pixelSize: 22 * browser.uiScale }
                MouseArea { anchors.fill: parent; onClicked: browser.adjustContentZoom(-0.1) }
            }
            Rectangle {
                width: 68 * browser.uiScale; height: 44 * browser.uiScale
                radius: 9 * browser.uiScale
                color: browser.customContentZoom ? "#e4eef8" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: Math.round(browser.effectiveContentZoomFactor * 100) + "%"
                    color: theme.ink; font.family: theme.fontFamily
                    font.pixelSize: 14 * browser.uiScale; font.bold: true
                }
                MouseArea { anchors.fill: parent; onClicked: browser.resetContentZoom() }
            }
            Rectangle {
                width: 40 * browser.uiScale; height: 44 * browser.uiScale
                radius: 9 * browser.uiScale; color: "#edf4fb"
                Text { anchors.centerIn: parent; text: "+"; color: theme.ink; font.pixelSize: 22 * browser.uiScale }
                MouseArea { anchors.fill: parent; onClicked: browser.adjustContentZoom(0.1) }
            }
        }

        Rectangle {
            id: addressBar
            anchors.left: navigationButtons.right
            anchors.leftMargin: 12 * browser.uiScale
            anchors.right: zoomControls.left
            anchors.rightMargin: 10 * browser.uiScale
            anchors.verticalCenter: parent.verticalCenter
            height: 48 * browser.uiScale
            radius: 24 * browser.uiScale
            color: "white"
            border.color: theme.line

            AtlasIcon {
                anchors.left: parent.left
                anchors.leftMargin: 14 * browser.uiScale
                anchors.verticalCenter: parent.verticalCenter
                width: 21 * browser.uiScale
                height: 21 * browser.uiScale
                name: browser.securePage ? "lock" : "info"
                strokeColor: browser.securePage ? theme.green : theme.muted
            }
            Text {
                objectName: "browserAddressDisplay"
                anchors.left: parent.left
                anchors.leftMargin: 44 * browser.uiScale
                anchors.right: parent.right
                anchors.rightMargin: 14 * browser.uiScale
                anchors.verticalCenter: parent.verticalCenter
                text: browser.addressHost
                color: theme.navy
                font.family: theme.fontFamily
                font.pixelSize: 16 * browser.uiScale
                elide: Text.ElideMiddle
            }
        }

        Rectangle {
            id: reloadButton
            anchors.right: parent.right
            anchors.rightMargin: 14 * browser.uiScale
            anchors.verticalCenter: parent.verticalCenter
            width: 48 * browser.uiScale
            height: 48 * browser.uiScale
            radius: 12 * browser.uiScale
            color: "#edf4fb"
            AtlasIcon { anchors.centerIn: parent; width: 24 * browser.uiScale; height: 24 * browser.uiScale; name: "refresh"; strokeColor: theme.ink }
            MouseArea { anchors.fill: parent; onClicked: browser.reload() }
        }
    }

    Rectangle {
        id: webArea
        anchors.top: navigationBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "white"
    }

    Rectangle {
        anchors.centerIn: webArea
        width: Math.min(webArea.width - 40 * browser.uiScale, 560 * browser.uiScale)
        height: errorColumn.implicitHeight + 48 * browser.uiScale
        radius: 16 * browser.uiScale
        color: "white"
        border.color: theme.line
        visible: browser.errorText.length > 0
        z: 5
        Column {
            id: errorColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 24 * browser.uiScale
            spacing: 10 * browser.uiScale
            Text {
                width: parent.width
                text: browser.errorTitle
                color: theme.ink
                font.family: theme.fontFamily
                font.pixelSize: 19 * browser.uiScale
                font.bold: true
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: browser.errorText
                color: theme.muted
                font.family: theme.fontFamily
                font.pixelSize: 14 * browser.uiScale
                wrapMode: Text.WordWrap
            }
        }
    }
}
