import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import QtMultimedia
import Qt.labs.platform
import "components"
import "theme"

Window {
    id: root
    visible: true
    width: Screen.width
    height: Screen.height
    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint
    title: "AtlasOS"
    color: theme.canvas
    property string page: "home"
    property string viewMode: "dashboard"
    property var atlasPreferences: null
    property bool boardMode: atlasPreferences !== null && (atlasPreferences.displayMode === "board" || (atlasPreferences.displayMode === "auto" && atlasPreferences.touchscreenDetected))
    // Keep board targets generous while allowing the timetable and workspace to reflow.
    property real interfaceScale: root.boardMode ? (root.width < 1440 ? 1.0 : 1.08) : root.width >= 1600 ? 1.08 : root.width >= 1366 ? 0.90 : 0.82
    property string workspaceTitle: ""
    property var lessons: []
    property var scheduleTimeline: []
    property var weeklySchedules: []
    property string scheduleDay: ""
    property string scheduleClass: ""
    property bool demoSchedule: true
   property var systemStatus: ({network: "Bilinmiyor", audio: "Bilinmiyor", pen: "Algılanmadı", usb: "Bilinmiyor"})
    property string settingsError: ""
    property string pendingToolTarget: ""
    property bool pendingLeaveWorkspace: false
    property bool toastVisible: false
    property string toastTitle: ""
    property string toastMessage: ""
    property string activeLessonTitle: ""
    property string activeLessonTime: ""
    property int activeLessonElapsedSeconds: 0
    AtlasTheme { id: theme }
    // Atlas uygulamaları tek ana pencere içinde gezinilir.

    function openTool(target, bypassTextGuard) {
        if (!bypassTextGuard && viewMode === "text" && textViewer.hasUnsavedChanges) {
            pendingToolTarget = target
            pendingLeaveWorkspace = false
            textViewer.requestNavigationDiscard()
            return
        }
        atlasApps.track(target)
        var sources = {
            eba: {title: "EBA", url: "https://www.eba.gov.tr/"},
            ogm: {title: "OGM Materyal", url: "https://ogmmateryal.eba.gov.tr/"},
            mebi: {title: "MEBİ", url: "https://mebi.eba.gov.tr/"},
            geogebra: {title: "GeoGebra", url: "https://www.geogebra.org/calculator"}
        }
        if (sources[target]) {
            workspaceTitle = sources[target].title
            viewMode = "web"
            browser.open(sources[target].url)
        } else if (target === "launcher") {
            launcher.open()
        } else if (target === "browser") {
            atlasApps.open("browser")
        } else if (["kig", "kalzium", "step"].indexOf(target) >= 0) {
            atlasApps.open(target)
        } else if (target === "network") {
            workspaceTitle = "Ağ Bağlantıları"
            viewMode = "network"
            atlasNetwork.refresh()
        } else if (target === "settings") {
            workspaceTitle = "Ayarlar"
            settingsError = ""
            viewMode = "settings"
        } else if (target === "notifications") {
            workspaceTitle = "Bildirimler"
            viewMode = "notifications"
            atlasAlerts.markRead()
        } else if (target === "whiteboard") {
            workspaceTitle = "Beyaz Tahta"
            viewMode = "whiteboard"
        } else if (["books", "pdf", "presentation", "video"].indexOf(target) >= 0) {
            workspaceTitle = target === "books" ? "Ders Kitapları" : "Dosya Seç"
            viewMode = "files"
            filesView.open(target)
        } else if (target === "power") {
            powerDialog.open()
        } else if (target === "finish") {
            finishDialog.open()
        } else if (target === "resources") {
            workspaceTitle = "Sistem Kaynakları"; viewMode = "resources"
        } else if (target === "files") {
            workspaceTitle = "Dosyalar"; viewMode = "files"; filesView.open("files")
        } else if (target === "library") {
            workspaceTitle = "Kaynak Rafı"; viewMode = "files"; filesView.open("library")
        } else if (target === "office") {
            atlasAlerts.add("Office", "Atlas içi Office düzenlemesi henüz doğrulanmadı; bu dosya türü açılamıyor.")
        } else {
            atlasAlerts.add("Uygulama", "Bu araç Atlas çalışma alanında henüz kullanıma hazır değil.")
        }
    }

    function leaveWorkspace(bypassTextGuard) {
        if (!bypassTextGuard && viewMode === "text" && textViewer.hasUnsavedChanges) {
            pendingToolTarget = ""
            pendingLeaveWorkspace = true
            textViewer.requestNavigationDiscard()
            return
        }
        if (viewMode === "pdf") pdf.close()
        if (viewMode === "video") videoPlayer.close()
        viewMode = "dashboard"
    }

    function continueAfterTextDiscard() {
        var target = pendingToolTarget
        var shouldLeave = pendingLeaveWorkspace
        pendingToolTarget = ""
        pendingLeaveWorkspace = false
        if (shouldLeave)
            leaveWorkspace(true)
        else if (target !== "")
            openTool(target, true)
    }
    function showToast(title, message) {
        toastTitle = title
        toastMessage = message
        toastVisible = true
        toastTimer.restart()
    }

    function startLesson(title, start, end) {
        activeLessonTitle = title
        activeLessonTime = start + " – " + end
        activeLessonElapsedSeconds = 0
        lessonDashboard.subject = title
        page = "lessons"
        viewMode = "dashboard"
        showToast("Ders başladı", title + " · " + activeLessonTime)
    }

    function workspaceBack() {
        if (viewMode === "web" && browser.canGoBack) browser.back()
        else if (viewMode === "files" && filesView.back()) return
        else if (viewMode === "pdf") { pdf.close(); viewMode = "files"; return }
        else if (viewMode === "video") { videoPlayer.close(); viewMode = "files"; return }
        else leaveWorkspace()
    }

    function openSelectedFile(kind, url) {
        if (kind === "text") {
            if (!atlasFs.canOpen("text", url)) {
                atlasAlerts.add("Metin dosyası", "Dosya bu konumdan açılamıyor veya desteklenen metin biçiminde değil.")
                return
            }
            workspaceTitle = "Metin Çalışma Alanı"
            textViewer.open(url)
            viewMode = "text"
            if (atlasValidateTextEdit)
                textViewer.startEditing()
            return
        }
        if (kind === "pdf" || kind === "video") {
            if (!atlasFs.canOpen(kind, url)) {
                atlasAlerts.add("Dosya", "Dosya açılamıyor veya izin verilen konumda değil.")
                return
            }
            if (kind === "pdf") {
                workspaceTitle = "PDF Görüntüleyici"
                pdf.open(url)
                viewMode = "pdf"
            } else {
                workspaceTitle = "Video Oynatıcı"
                videoPlayer.open(url)
                viewMode = "video"
            }
            return
        }
        atlasAlerts.add("Dosya", "Bu dosya türü Atlas çalışma alanında henüz desteklenmiyor.")
    }

    function readFile(path) {
        var request = new XMLHttpRequest()
        try {
            var url = path.indexOf("file://") === 0 ? path : "file://" + path
            request.open("GET", url, false)
            request.send()
        } catch (error) {
            return {found: false, data: null}
        }
        if (request.responseText.length === 0) return {found: false, data: null}
        try {
            return {found: true, data: JSON.parse(request.responseText)}
        } catch (error) {
            console.warn("AtlasOS JSON bozuk: " + path + ": " + error)
            return {found: true, data: null}
        }
    }

    function loadLessons() {
        var data = JSON.parse(atlasLessonDataJson)
        if (!data) {
            lessons = []
            scheduleTimeline = []
            return
        }
        demoSchedule = data.demo === true
        if (data.version === 1 && Array.isArray(data.today)) {
            lessons = data.today.filter(function (lesson) {
                return lesson && typeof lesson.start === "string" && typeof lesson.end === "string" &&
                       typeof lesson.title === "string" && lesson.title.trim().length > 0 &&
                       typeof lesson.class === "string"
            })
            scheduleTimeline = lessons.map(function (lesson) { return Object.assign({kind: "lesson"}, lesson) })
            scheduleClass = data.profile && data.profile.classLabel ? data.profile.classLabel : ""
            scheduleDay = ""
            return
        }
        if (data.version !== 2 || !data.days || !data.profile) {
            lessons = []
            scheduleTimeline = []
            return
        }
        var dayNames = {1: "Pazartesi", 2: "Salı", 3: "Çarşamba", 4: "Perşembe", 5: "Cuma"}
        var dayNumber = new Date().getDay()
        scheduleDay = dayNames[dayNumber] || "Hafta sonu"
        scheduleClass = data.profile.classLabel || (data.profile.grade + "/" + data.profile.branch)
        var startParts = String(data.schoolStart || "08:00").split(":")
        var startMinute = Number(startParts[0]) * 60 + Number(startParts[1])
        var lessonLength = Number(data.lessonMinutes || 40)
        var breakLength = Number(data.breakMinutes || 10)
        var lunchAfter = Number(data.lunchAfterPeriod || 5)
        var lunchLength = Number(data.lunchMinutes || 45)
        function clockString(value) {
            var hour = Math.floor(value / 60)
            var minute = value % 60
            return (hour < 10 ? "0" : "") + hour + ":" + (minute < 10 ? "0" : "") + minute
        }
        function buildDaySchedule(number) {
            var titles = data.days[String(number)]
            if (!Array.isArray(titles)) return null
            var cursor = startMinute
            var dayLessons = []
            var dayTimeline = []
            for (var period = 0; period < titles.length; period++) {
                var start = cursor
                var end = start + lessonLength
                var lesson = {kind: "lesson", period: period + 1, start: clockString(start), end: clockString(end), title: String(titles[period]), class: scheduleClass}
                dayLessons.push(lesson)
                dayTimeline.push(lesson)
                cursor = end
                if (period < titles.length - 1) {
                    var isLunch = period + 1 === lunchAfter
                    var pauseLength = isLunch ? lunchLength : breakLength
                    dayTimeline.push({kind: "break", start: clockString(cursor), end: clockString(cursor + pauseLength), title: isLunch ? "Öğle Arası" : "Teneffüs"})
                    cursor += pauseLength
                }
            }
            return {day: dayNames[number], lessons: dayLessons, timeline: dayTimeline}
        }
        weeklySchedules = []
        for (var day = 1; day <= 5; day++) {
            var schedule = buildDaySchedule(day)
            if (schedule) weeklySchedules.push(schedule)
        }
        var todaySchedule = buildDaySchedule(dayNumber)
        lessons = todaySchedule ? todaySchedule.lessons : []
        scheduleTimeline = todaySchedule ? todaySchedule.timeline : []
    }

    function loadStatus() {
        var cache = StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)
        var response = readFile(cache + "/atlasos/status.json")
        if (response.data && typeof response.data.network === "string" &&
                typeof response.data.audio === "string" && typeof response.data.pen === "string") {
            if (systemStatus.network !== "Bilinmiyor" && systemStatus.network !== response.data.network)
                atlasAlerts.add("Ağ durumu", response.data.network)
            if (typeof response.data.usb === "string" && systemStatus.usb !== "Bilinmiyor" && systemStatus.usb !== response.data.usb) {
                atlasAlerts.add("USB belleği", response.data.usb)
                root.showToast("USB belleği", response.data.usb)
            }
            systemStatus = {network: response.data.network, audio: response.data.audio, pen: response.data.pen, usb: response.data.usb || "Bilinmiyor"}
        }
    }

    Component.onCompleted: { loadLessons(); loadStatus() }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.loadStatus() }
    Timer { interval: 1000; running: root.activeLessonTitle.length > 0; repeat: true; onTriggered: root.activeLessonElapsedSeconds++ }
    Timer {
        id: startupSoundTimer
        interval: 1800
        running: true
        repeat: false
        onTriggered: {
            if (atlasPreferences && atlasPreferences.startupSoundEnabled && atlasPreferences.startupSoundAvailable && root.systemStatus.audio === "Açık")
                startupSound.play()
        }
    }
    Timer { id: toastTimer; interval: 4200; onTriggered: root.toastVisible = false }
    SoundEffect { id: startupSound; source: atlasPreferences && atlasPreferences.startupSoundAvailable ? Qt.resolvedUrl("sounds/atlasos-startup.wav") : ""; volume: 0.20 }

    AtlasDialog {
        id: finishDialog
        title: "Dersi Bitir"
        modal: true
        anchors.centerIn: parent
        width: Math.min(500 * root.interfaceScale, root.width - 48)
        dialogScale: root.interfaceScale
        Column {
            width: parent.width
            spacing: 16
            Controls.Label {
                width: parent.width
                text: "AtlasOS yalnızca kendi örnek oturum geçici klasörlerini temizleyecek. Belgeleriniz ve açık oturumunuz korunur."
                wrapMode: Text.WordWrap
                color: theme.ink
                font.family: theme.fontFamily
                font.pixelSize: theme.typeBody * root.interfaceScale
            }
            Row {
                spacing: 10
                AtlasButton { text: "Vazgeç"; controlScale: root.interfaceScale; onClicked: finishDialog.close() }
                AtlasButton {
                    variant: "danger"
                    controlScale: root.interfaceScale
                    text: "Dersi Bitir"
                    onClicked: {
                        var result = atlasFs.finishDemoLesson()
                    root.activeLessonTitle = ""
                    root.activeLessonTime = ""
                    root.activeLessonElapsedSeconds = 0
                    if (result.ok)
                        {
                            var doneMessage = result.removed.length > 0 ? "Örnek geçici veriler temizlendi. Live oturum açık." : "Temizlenecek örnek geçici veri yoktu. Belgeleriniz korundu; Live oturum açık."
                            root.showToast("Ders tamamlandı", doneMessage)
                            atlasAlerts.add("Ders oturumu", doneMessage)
                        }
                    else
                        {
                            var failureMessage = "Bazı örnek klasörler temizlenemedi: " + result.failed.join(", ")
                            root.showToast("Temizlik tamamlanamadı", failureMessage)
                            atlasAlerts.add("Ders oturumu", failureMessage)
                        }
                        finishDialog.close()
                    }
                }
            }
        }
    }

    AtlasDialog {
        id: powerDialog
        title: "Oturum ve güç"
        modal: true
        anchors.centerIn: parent
        width: Math.min(440 * root.interfaceScale, root.width - 48)
        dialogScale: root.interfaceScale
        property string pendingAction: ""
        Column {
            spacing: 10
            width: parent.width
            Controls.Label {
                text: powerDialog.pendingAction === "" ? "Bir işlem seçin" : "Bu işlem şimdi uygulanacak. Onaylıyor musunuz?"
                wrapMode: Text.WordWrap
                width: parent.width
                color: theme.ink
                font.family: theme.fontFamily
                font.pixelSize: theme.typeBody * root.interfaceScale
            }
            Row {
                visible: powerDialog.pendingAction === ""
                spacing: 7
                AtlasButton { text: "Çıkış"; controlScale: root.interfaceScale; onClicked: powerDialog.pendingAction = "logout" }
                AtlasButton { text: "Yeniden başlat"; controlScale: root.interfaceScale; onClicked: powerDialog.pendingAction = "restart" }
                AtlasButton { text: "Kapat"; variant: "danger"; controlScale: root.interfaceScale; onClicked: powerDialog.pendingAction = "shutdown" }
            }
            AtlasButton {
                variant: "primary"
                controlScale: root.interfaceScale
                visible: powerDialog.pendingAction !== ""
                text: "Onayla"
                onClicked: { atlasPower.run(powerDialog.pendingAction); powerDialog.close() }
            }
            AtlasButton { visible: powerDialog.pendingAction !== ""; text: "Vazgeç"; controlScale: root.interfaceScale; onClicked: powerDialog.pendingAction = "" }
        }
        onOpened: pendingAction = ""
    }

    AtlasHeader {
        id: header
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        networkState: root.systemStatus.network
        audioState: root.systemStatus.audio
        audioController: atlasAudio
        boardMode: root.boardMode
        penState: root.systemStatus.pen
        onNetworkRequested: root.openTool("network")
        notificationCount: atlasAlerts.unread
        onNotificationsRequested: root.openTool("notifications")
    }
    AtlasSidebar {
        id: sidebar
        visible: root.viewMode === "dashboard"
        width: root.boardMode ? Math.max(142, Math.min(166, root.width * 0.09)) : Math.max(112, Math.min(144, root.width * 0.086))
        anchors.top: header.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left
        currentPage: root.page
        itemScale: root.interfaceScale
        onPageSelected: {
            if (page === "settings") root.openTool("settings")
            else { root.page = page; root.viewMode = "dashboard" }
        }
        onPowerRequested: root.openTool("power")
    }
    LessonPanel {
        id: lessonPanel
        visible: root.viewMode === "dashboard"
        width: root.boardMode ? Math.min(470, Math.max(350, root.width * 0.285)) : Math.min(452, Math.max(300, root.width * 0.27))
        anchors.top: header.bottom; anchors.bottom: parent.bottom; anchors.right: parent.right
        lessons: root.lessons
        timeline: root.scheduleTimeline
        weeklySchedules: root.weeklySchedules
        scheduleDay: root.scheduleDay
        classLabel: root.scheduleClass
        demo: root.demoSchedule
        scaleFactor: root.interfaceScale
        onFinishRequested: root.openTool("finish")
        onStartRequested: function(title, start, end) { root.startLesson(title, start, end) }
    }

    Rectangle {
        id: workArea
        visible: root.viewMode === "dashboard"
        anchors.top: header.bottom; anchors.bottom: parent.bottom
        anchors.left: sidebar.right; anchors.right: lessonPanel.left
        color: theme.canvas
        AtlasHomeDashboard {
            visible: root.page !== "lessons"
            anchors.fill: parent
            page: root.page
            scaleFactor: root.interfaceScale
            boardMode: root.boardMode
            onOpenRequested: function(target) { root.openTool(target) }
            onAllResourcesRequested: root.openTool("launcher")
        }
        AtlasLessonDashboard {
            id: lessonDashboard
            visible: root.page === "lessons"
            anchors.fill: parent
            scaleFactor: root.interfaceScale
            boardMode: root.boardMode
            activeLessonTitle: root.activeLessonTitle
            activeLessonTime: root.activeLessonTime
            activeLessonElapsedSeconds: root.activeLessonElapsedSeconds
            favoriteKeys: atlasApps.favoriteKeys
            recentKeys: atlasApps.recentKeys
            onToolRequested: function(target) { root.openTool(target) }
        }
    }

    Rectangle {
        id: workspace
        visible: root.viewMode !== "dashboard"
        anchors.top: header.bottom; anchors.bottom: parent.bottom; 
        anchors.left: parent.left; anchors.right: parent.right
        color: theme.canvas

        Rectangle {
            id: toolbar
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            height: 70 * root.interfaceScale; color: "#f7faff"; border.color: theme.line
            Row {
                anchors.left: parent.left; anchors.leftMargin: 18 * root.interfaceScale
                anchors.verticalCenter: parent.verticalCenter; spacing: 9 * root.interfaceScale
                Rectangle {
                    width: 64 * root.interfaceScale; height: 64 * root.interfaceScale; radius: 10; color: "#edf4fa"
                    AtlasIcon { anchors.centerIn: parent; name: "arrow-left"; strokeColor: theme.ink }
                    MouseArea { anchors.fill: parent; onClicked: root.workspaceBack() }
                }
                Rectangle {
                    width: 64 * root.interfaceScale; height: 64 * root.interfaceScale; radius: 10; color: "#edf4fa"
                    AtlasIcon { anchors.centerIn: parent; name: "home"; strokeColor: theme.ink }
                    MouseArea { anchors.fill: parent; onClicked: root.leaveWorkspace() }
                }
                Text {
                    width: Math.max(150, Math.min(400, root.width - 540))
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.workspaceTitle; color: theme.ink; font.pixelSize: 20 * root.interfaceScale; font.bold: true
                    elide: Text.ElideRight
                }
            }
            Row {
                visible: root.viewMode === "web"
                anchors.right: parent.right; anchors.rightMargin: 18 * root.interfaceScale
                anchors.verticalCenter: parent.verticalCenter; spacing: 9 * root.interfaceScale
                Rectangle {
                    width: 64 * root.interfaceScale; height: 64 * root.interfaceScale; radius: 10; color: browser.canGoForward ? "#edf4fa" : "#edf0f2"
                    AtlasIcon { anchors.centerIn: parent; name: "arrow-right"; strokeColor: browser.canGoForward ? theme.ink : theme.muted }
                    MouseArea { anchors.fill: parent; enabled: browser.canGoForward; onClicked: browser.forward() }
                }
                Rectangle {
                    width: 64 * root.interfaceScale; height: 64 * root.interfaceScale; radius: 10; color: "#edf4fa"
                    AtlasIcon { anchors.centerIn: parent; name: "refresh"; strokeColor: theme.ink }
                    MouseArea { anchors.fill: parent; onClicked: browser.reload() }
                }
                Rectangle {
                    width: 164 * root.interfaceScale; height: 64 * root.interfaceScale; radius: 10; color: theme.navy
                    Text { anchors.centerIn: parent; text: "Yenile"; color: "white"; font.pixelSize: 15 * root.interfaceScale; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: browser.reload()
                    }
                }
            }
        }

        AtlasBrowser {
            id: browser
            visible: root.viewMode === "web"
            anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            onExternalBrowserRequested: atlasApps.openExternalBrowser(url)
        }
        AtlasFiles {
            id: filesView
            visible: root.viewMode === "files"
            anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            homeFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)
            booksFolder: homeFolder + "/Ders%20Kitaplari"
            downloadsFolder: StandardPaths.writableLocation(StandardPaths.DownloadLocation)
            onChosen: root.openSelectedFile(kind, url)
        }
        AtlasPdf {
            id: pdf
            visible: root.viewMode === "pdf"
            anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
        }
        AtlasVideo {
            id: videoPlayer
            visible: root.viewMode === "video"
            anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
        }
        AtlasText {
            id: textViewer
            visible: root.viewMode === "text"
            anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            onNavigationDiscarded: root.continueAfterTextDiscard()
        }
        AtlasWhiteboard {
            id: whiteboard
            scaleFactor: root.interfaceScale
            visible: root.viewMode === "whiteboard"
            anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            onSaved: function(path) { atlasAlerts.add("Beyaz Tahta", "Çizim kaydedildi: " + path) }
            onSaveFailed: function() { atlasAlerts.add("Beyaz Tahta", "Çizim PNG olarak kaydedilemedi.") }
        }
        AtlasNetwork {
            visible: root.viewMode === "network"
            anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
        }
    AtlasSettings {
            visible: root.viewMode === "settings"
            anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
      networkState: root.systemStatus.network
      audioState: root.systemStatus.audio
      penState: root.systemStatus.pen
      errorText: root.settingsError
      startupSoundEnabled: atlasPreferences ? atlasPreferences.startupSoundEnabled : true
      startupSoundAvailable: atlasPreferences ? atlasPreferences.startupSoundAvailable : false
      displayMode: atlasPreferences ? atlasPreferences.displayMode : "auto"
      touchscreenDetected: atlasPreferences ? atlasPreferences.touchscreenDetected : false
      boardMode: root.boardMode
      onNetworkRequested: root.openTool("network")
      onStartupSoundChanged: function(enabled) { atlasPreferences.setStartupSoundEnabled(enabled) }
      onDisplayModeRequested: function(mode) { atlasPreferences.setDisplayMode(mode) }
      onAppRequested: key === "network-settings" ? root.openTool("network") : key === "resources" || key === "htop" ? root.openTool("resources") : atlasAlerts.add("Ayarlar", "Bu ayar Atlas arayüzüne henüz taşınmadı.")
        }
        Rectangle {
            visible: root.viewMode === "resources"
            anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            color: theme.canvas
            Column {
                anchors.fill: parent; anchors.margins: 30; spacing: 20
                Text { text: "Sistem Kaynakları"; color: theme.ink; font.pixelSize: 28; font.bold: true }
                Text { text: "Canlı ölçüm · yaklaşık iki saniyede bir yenilenir"; color: theme.muted; font.pixelSize: 15 }
                Row {
                    width: parent.width; spacing: 16
                    Repeater {
                        model: [
                            {title: "İşlemci", value: Math.round(atlasResources.cpuPercent) + "%", ratio: atlasResources.cpuPercent, hint: "Anlık kullanım"},
                            {title: "Bellek", value: atlasResources.memoryUsedMb + " / " + atlasResources.memoryTotalMb + " MB", ratio: atlasResources.memoryPercent, hint: Math.round(atlasResources.memoryPercent) + "% kullanılıyor"}
                        ]
                        delegate: Rectangle {
                            width: (parent.width - 16) / 2; height: 170; radius: 10; color: "white"; border.color: theme.line
                            Column {
                                anchors.fill: parent; anchors.margins: 20; spacing: 12
                                Text { text: modelData.title; color: theme.muted; font.pixelSize: 16 }
                                Text { text: modelData.value; color: theme.ink; font.pixelSize: 28; font.bold: true }
                                Rectangle {
                                    width: parent.width; height: 10; radius: 5; color: "#e6edf1"
                                    Rectangle { width: parent.width * Math.max(0, Math.min(1, Number(modelData.ratio) / 100)); height: parent.height; radius: 5; color: theme.green }
                                }
                                Text { text: modelData.hint; color: theme.muted; font.pixelSize: 13 }
                            }
                        }
                    }
                }
            }
        }
        AtlasNotifications {
            visible: root.viewMode === "notifications"
            anchors.top: toolbar.bottom; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
        }
    }
    AtlasLauncher {
        id: launcher
        onSelected: function(key) { root.openTool(key) }
        anchors.top: header.bottom; anchors.bottom: parent.bottom; 
        anchors.left: parent.left; anchors.right: parent.right
    }

    Rectangle {
        id: toast
        visible: root.toastVisible
        opacity: root.toastVisible ? 1 : 0
        z: 1000
        anchors.top: parent.top
        anchors.topMargin: header.height + 18
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(620, root.width - 40)
        height: 88
        radius: theme.radiusCard
        color: theme.surface
        border.color: theme.line
        Behavior on opacity { NumberAnimation { duration: theme.motionNormal } }
        Row {
            anchors.fill: parent; anchors.margins: 18; spacing: 14
            Rectangle { width: 42; height: 42; radius: 21; color: "#e5f6f1"; anchors.verticalCenter: parent.verticalCenter; Text { anchors.centerIn: parent; text: "✓"; color: theme.green; font.pixelSize: 22; font.bold: true } }
            Column {
                width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Text { width: parent.width; text: root.toastTitle; color: theme.ink; font.pixelSize: 16; font.bold: true; elide: Text.ElideRight }
                Text { width: parent.width; text: root.toastMessage; color: theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
            }
        }
    }
}

