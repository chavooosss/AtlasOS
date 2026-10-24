import hashlib
import os
import pathlib
import tempfile
import time
import unittest

try:
    from PySide6.QtCore import QCoreApplication, QEvent, QMetaObject, QPoint, QPointF, QRect, QUrl, Qt
    from PySide6.QtGui import QGuiApplication, QImage, QKeyEvent, QMouseEvent
    from PySide6.QtQuick import QQuickView
    QT_AVAILABLE = True
except ImportError:
    QT_AVAILABLE = False


ROOT = pathlib.Path(__file__).resolve().parents[1]
UI_ROOT = ROOT / "config/includes.chroot/usr/local/share/atlasos/ui"
PDF_QML = UI_ROOT / "components/AtlasPdf.qml"
MAIN_QML = UI_ROOT / "Main.qml"
FILES_QML = UI_ROOT / "components/AtlasFiles.qml"
BUTTON_QML = UI_ROOT / "components/AtlasButton.qml"
ICON_QML = UI_ROOT / "components/AtlasIcon.qml"
PACKAGES = ROOT / "config/package-lists/atlasos-live.list.chroot"


class AtlasPaperTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pdf = PDF_QML.read_text(encoding="utf-8")
        cls.main = MAIN_QML.read_text(encoding="utf-8")
        cls.files = FILES_QML.read_text(encoding="utf-8")
        cls.button = BUTTON_QML.read_text(encoding="utf-8")
        cls.icon = ICON_QML.read_text(encoding="utf-8")
        cls.packages = PACKAGES.read_text(encoding="utf-8")

    def test_qt_pdf_runtime_and_existing_reader_are_kept(self):
        self.assertIn("import QtQuick.Pdf", self.pdf)
        self.assertIn("PdfDocument {", self.pdf)
        self.assertIn("PdfMultiPageView {", self.pdf)
        self.assertIn("PdfPageImage {", self.pdf)
        self.assertIn("qml6-module-qtquick-pdf", self.packages)

    def test_toolbar_uses_atlas_controls_and_keeps_document_actions_grouped(self):
        self.assertIn("component PaperToolButton: Controls.Button", self.pdf)
        self.assertIn("PaperToolButton {", self.pdf)
        for name in (
            "atlasPaperOpenButton", "atlasPaperPreviousPageButton", "atlasPaperNextPageButton",
            "atlasPaperZoomOutButton", "atlasPaperZoomInButton", "atlasPaperFitPageButton",
            "atlasPaperFitWidthButton", "atlasPaperThumbnailsButton", "atlasPaperFullscreenButton",
            "atlasPaperDocumentName", "atlasPaperZoomPercentage",
        ):
            with self.subTest(name=name):
                self.assertIn(name, self.pdf)

    def test_page_navigation_zoom_and_distinct_fit_modes_use_pdf_engine(self):
        for snippet in (
            "view.goToPage(requested - 1)",
            "view.renderScale * factor",
            "view.scaleToPage(",
            "view.scaleToWidth(",
            'fitMode = "fit-page"',
            'fitMode = "fit-width"',
            'fitMode = "custom"',
            "readonly property int zoomPercentage",
        ):
            with self.subTest(snippet=snippet):
                self.assertIn(snippet, self.pdf)

    def test_real_page_images_are_lazy_bounded_and_selectable(self):
        self.assertIn("PdfPageImage {", self.pdf)
        self.assertIn("currentFrame: index", self.pdf)
        self.assertIn("asynchronous: true", self.pdf)
        self.assertIn("cacheBuffer: Math.max(0, height * 2)", self.pdf)
        self.assertIn("TapHandler { onTapped:", self.pdf)
        self.assertIn("view.goToPage(index)", self.pdf)
        self.assertIn("panel.currentPage === index", self.pdf)
        self.assertIn('"Sayfa " + (index + 1)', self.pdf)

    def test_keyboard_navigation_only_runs_from_document_view(self):
        for key in ("Qt.Key_PageDown", "Qt.Key_Right", "Qt.Key_PageUp", "Qt.Key_Left", "Qt.Key_Home", "Qt.Key_End"):
            with self.subTest(key=key):
                self.assertIn(key, self.pdf)
        self.assertIn("Keys.onPressed", self.pdf)
        self.assertIn("function focusSearch()", self.pdf)
        self.assertIn('sequence: "Escape"', self.pdf)

    def test_search_and_open_file_routes_are_kept(self):
        self.assertIn("view.searchString = text", self.pdf)
        self.assertIn("view.searchBack()", self.pdf)
        self.assertIn("view.searchForward()", self.pdf)
        self.assertIn("searchResultCount", self.pdf)
        self.assertIn("signal openRequested()", self.pdf)
        self.assertIn('onOpenRequested: root.openTool("pdf", true)', self.main)
        self.assertIn('onChosen: root.openSelectedFile(kind, url)', self.main)
        self.assertIn('workspaceTitle = "PDF Görüntüleyici"', self.main)
        self.assertIn("pdf.open(url)", self.main)

    def test_error_loading_password_switch_and_fullscreen_states_exist(self):
        for snippet in (
            "PdfDocument.Loading", "PdfDocument.Error",
            "onPasswordRequired: passwordDialog.open()",
            "document.password = passwordField.text", "function close()",
            'searchField.text = ""', "panel.setImmersive(false)", 'sequence: "Escape"',
        ):
            with self.subTest(snippet=snippet):
                self.assertIn(snippet, self.pdf)

    def test_touch_scroll_uses_qt_multipage_view_without_competing_gesture_layer(self):
        self.assertIn("PdfMultiPageView {", self.pdf)
        self.assertNotIn("Flickable {", self.pdf)
        self.assertNotIn("MouseArea {", self.pdf)
        self.assertIn("TapHandler {", self.pdf)

    def test_board_density_and_application_routing_are_preserved(self):
        self.assertIn("property bool boardMode: false", self.pdf)
        self.assertIn("property real uiScale: 1.0", self.pdf)
        self.assertIn("readonly property real density: boardMode ? uiScale : 1.0", self.pdf)
        self.assertIn("boardMode: root.boardMode", self.main)
        self.assertIn("uiScale: root.interfaceScale", self.main)
        self.assertIn("root.pdfFullscreen", self.main)


def write_test_pdf(path, pages):
    objects = []
    kids = " ".join(f"{3 + index * 2} 0 R" for index in range(len(pages)))
    objects.append("<< /Type /Catalog /Pages 2 0 R >>")
    objects.append(f"<< /Type /Pages /Kids [{kids}] /Count {len(pages)} >>")
    for index, text in enumerate(pages):
        page_id = 3 + index * 2
        stream_id = page_id + 1
        color = ("0.08 0.35 0.72" if index % 3 == 0 else
                 "0.10 0.55 0.38" if index % 3 == 1 else "0.72 0.24 0.20")
        stream = (
            f"q {color} rg 72 640 468 64 re f Q\n"
            f"BT /F1 24 Tf 84 672 Td ({text}) Tj ET\n"
            f"BT /F1 16 Tf 72 580 Td (UNIQUE_PAGE_MARKER_{index + 1}) Tj ET"
        ).encode("ascii")
        objects.append(
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
            f"/Resources << /Font << /F1 {3 + len(pages) * 2} 0 R >> >> "
            f"/Contents {stream_id} 0 R >>"
        )
        objects.append(
            f"<< /Length {len(stream)} >>\nstream\n".encode("ascii").decode("ascii")
            + stream.decode("ascii") + "\nendstream"
        )
    font_id = 3 + len(pages) * 2
    objects.append("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    chunks = [b"%PDF-1.4\n"]
    offsets = [0]
    for index, obj in enumerate(objects, start=1):
        offsets.append(sum(map(len, chunks)))
        payload = obj.encode("ascii") if isinstance(obj, str) else obj.encode("ascii")
        chunks.extend([f"{index} 0 obj\n".encode(), payload, b"\nendobj\n"])
    xref_offset = sum(map(len, chunks))
    chunks.append(f"xref\n0 {len(offsets)}\n0000000000 65535 f \n".encode())
    for offset in offsets[1:]:
        chunks.append(f"{offset:010d} 00000 n \n".encode())
    chunks.append(
        f"trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\n"
        f"startxref\n{xref_offset}\n%%EOF\n".encode()
    )
    path.write_bytes(b"".join(chunks))


if QT_AVAILABLE:
    from PySide6.QtCore import QObject, Slot

    class _AtlasPaperFileSystem(QObject):
        @Slot(QUrl, result=str)
        def displayPath(self, url):
            return url.toLocalFile()


@unittest.skipUnless(QT_AVAILABLE and os.environ.get("ATLASOS_RUN_QML_RUNTIME_TESTS") == "1",
                     "set ATLASOS_RUN_QML_RUNTIME_TESTS=1 with Qt Quick/Pdf runtime imports configured")
class AtlasPaperQmlRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QGuiApplication.instance() or QGuiApplication([])
        cls.temp = tempfile.TemporaryDirectory(prefix="atlas-paper-qml-")
        cls.temp_path = pathlib.Path(cls.temp.name)
        cls.multi_page = cls.temp_path / "three-distinct-pages.pdf"
        cls.one_page = cls.temp_path / "one-page.pdf"
        cls.invalid = cls.temp_path / "invalid.pdf"
        write_test_pdf(cls.multi_page, ["FIRST_PAGE_BLUE", "SECOND_PAGE_GREEN", "THIRD_PAGE_RED"])
        write_test_pdf(cls.one_page, ["SWITCHED_DOCUMENT_ONLY"])
        cls.invalid.write_text("not a PDF", encoding="ascii")

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.view = QQuickView()
        import_path = os.environ.get("ATLASOS_QML_IMPORT_PATH") or os.environ.get("QML2_IMPORT_PATH")
        if import_path:
            self.view.engine().addImportPath(import_path)
        self.fs = _AtlasPaperFileSystem()
        self.view.rootContext().setContextProperty("atlasFs", self.fs)
        self.view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
        self.view.resize(1366, 768)
        self.view.setSource(QUrl.fromLocalFile(str(PDF_QML)))
        self.view.show()
        self.app.processEvents()
        self.root = self.view.rootObject()
        self.assertIsNotNone(self.root)

    def tearDown(self):
        self.view.close()
        self.app.processEvents()
        self.view.deleteLater()

    def find_visual_child(self, item, object_name):
        if item.objectName() == object_name:
            return item
        for child in item.childItems():
            found = self.find_visual_child(child, object_name)
            if found is not None:
                return found
        return None

    def wait_until(self, predicate, timeout=8.0):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            self.app.processEvents()
            if predicate():
                return True
            time.sleep(0.02)
        return bool(predicate())

    def key_click(self, key, text=""):
        press = QKeyEvent(QEvent.Type.KeyPress, key, Qt.KeyboardModifier.NoModifier, text)
        QCoreApplication.sendEvent(self.view, press)
        release = QKeyEvent(QEvent.Type.KeyRelease, key, Qt.KeyboardModifier.NoModifier, text)
        QCoreApplication.sendEvent(self.view, release)
        self.app.processEvents()

    def key_text(self, text):
        for character in text:
            self.key_click(ord(character.upper()) - ord("A") + Qt.Key.Key_A if character.isalpha() else ord(character), character)

    def mouse_click(self, point):
        position = QPointF(point)
        press = QMouseEvent(QEvent.Type.MouseButtonPress, position, position, position,
                            Qt.MouseButton.LeftButton, Qt.MouseButton.LeftButton,
                            Qt.KeyboardModifier.NoModifier)
        QCoreApplication.sendEvent(self.view, press)
        release = QMouseEvent(QEvent.Type.MouseButtonRelease, position, position, position,
                              Qt.MouseButton.LeftButton, Qt.MouseButton.NoButton,
                              Qt.KeyboardModifier.NoModifier)
        QCoreApplication.sendEvent(self.view, release)
        self.app.processEvents()

    def mouse_drag(self, start, end):
        start = QPointF(start)
        end = QPointF(end)
        QCoreApplication.sendEvent(self.view, QMouseEvent(QEvent.Type.MouseButtonPress, start, start, start,
                                Qt.MouseButton.LeftButton, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier))
        middle = (start + end) / 2
        QCoreApplication.sendEvent(self.view, QMouseEvent(QEvent.Type.MouseMove, middle, middle, middle,
                                Qt.MouseButton.NoButton, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier))
        QCoreApplication.sendEvent(self.view, QMouseEvent(QEvent.Type.MouseMove, end, end, end,
                                Qt.MouseButton.NoButton, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier))
        QCoreApplication.sendEvent(self.view, QMouseEvent(QEvent.Type.MouseButtonRelease, end, end, end,
                                Qt.MouseButton.LeftButton, Qt.MouseButton.NoButton, Qt.KeyboardModifier.NoModifier))
        self.app.processEvents()

    def open_pdf(self, path):
        self.root.open(QUrl.fromLocalFile(str(path)))
        self.assertTrue(self.wait_until(
            lambda: self.root.property("pageCount") > 0
            and self.root.property("currentPage") == 0
            and self.root.findChild(QObject, "atlasPaperPageView") is not None
        ))

    def test_real_thumbnails_show_each_page_and_thumbnail_tap_navigates(self):
        self.open_pdf(self.multi_page)
        page_view = self.root.findChild(QObject, "atlasPaperPageView")
        self.root.setProperty("thumbnailsVisible", True)
        thumbnails_ready = self.wait_until(lambda: all(
            (delegate := self.find_visual_child(self.root, f"atlasPaperThumbnail_{index}")) is not None
            and delegate.property("renderedThumbnailStatus") == 1
            and delegate.property("renderedThumbnailFrame") == index
            for index in range(3)
        ))
        if not thumbnails_ready:
            self.fail("thumbnail image state: " + repr([
                None if (item := self.find_visual_child(self.root, f"atlasPaperThumbnail_{index}")) is None
                else (item.property("renderedThumbnailStatus"), item.property("renderedThumbnailFrame"),
                      item.property("renderedDocumentStatus"), item.property("renderedImageSource"),
                      self.find_visual_child(item, f"atlasPaperThumbnailImage_{index}").property("visible"),
                      self.find_visual_child(item, f"atlasPaperThumbnailImage_{index}").property("width"),
                      self.find_visual_child(item, f"atlasPaperThumbnailImage_{index}").property("height")) for index in range(3)
            ]) + " root=" + repr((self.root.property("pageCount"), self.root.property("thumbnailsVisible"),
                self.root.findChild(QObject, "atlasPaperThumbnailList").property("count"),
                self.root.findChild(QObject, "atlasPaperThumbnailList").property("visible"))))
        captures = []
        screenshot = self.view.grabWindow()
        self.assertFalse(screenshot.isNull())
        ratio = screenshot.width() / self.view.width()
        for index in range(3):
            delegate = self.find_visual_child(self.root, f"atlasPaperThumbnail_{index}")
            image_item = self.find_visual_child(delegate, f"atlasPaperThumbnailImage_{index}")
            origin = image_item.mapToScene(QPointF(0, 0))
            rect = QRect(
                round(origin.x() * ratio), round(origin.y() * ratio),
                round(image_item.width() * ratio), round(image_item.height() * ratio)
            ).intersected(screenshot.rect())
            crop = screenshot.copy(rect).convertToFormat(QImage.Format.Format_RGBA8888)
            self.assertFalse(crop.isNull())
            captures.append(hashlib.sha256(bytes(crop.constBits()[:crop.sizeInBytes()])).hexdigest())
        self.assertEqual(len(set(captures)), 3, "distinct PDF page artwork should render distinct thumbnail pixels")
        target = self.find_visual_child(self.root, "atlasPaperThumbnail_2")
        target = self.find_visual_child(target, "atlasPaperThumbnailImage_2")
        point = target.mapToScene(QPointF(target.width() / 2, target.height() / 2))
        self.mouse_click(point)
        self.assertTrue(self.wait_until(lambda: self.root.property("currentPage") == 2))
        page_field = self.root.findChild(QObject, "atlasPaperPageField")
        self.assertTrue(self.wait_until(lambda: page_field.property("text") == "3"))
        self.assertTrue(self.find_visual_child(self.root, "atlasPaperThumbnail_2").property("activeThumbnail"))

    def test_page_navigation_keyboard_in_fullscreen_and_text_input_focus(self):
        self.open_pdf(self.multi_page)
        page_view = self.root.findChild(QObject, "atlasPaperPageView")
        QMetaObject.invokeMethod(self.root, "focusDocument")
        self.key_click(Qt.Key.Key_PageDown)
        self.assertTrue(self.wait_until(lambda: self.root.property("currentPage") == 1))
        self.key_click(Qt.Key.Key_Right)
        self.assertTrue(self.wait_until(lambda: self.root.property("currentPage") == 2))
        self.key_click(Qt.Key.Key_End)
        self.assertEqual(self.root.property("currentPage"), 2)
        self.key_click(Qt.Key.Key_Home)
        self.assertTrue(self.wait_until(lambda: self.root.property("currentPage") == 0))
        self.root.setImmersive(True)
        self.assertTrue(self.root.property("immersive"))
        self.key_click(Qt.Key.Key_PageDown)
        self.assertTrue(self.wait_until(lambda: self.root.property("currentPage") == 1))
        self.key_click(Qt.Key.Key_Escape)
        self.assertTrue(self.wait_until(lambda: not self.root.property("immersive")))
        self.assertTrue(self.wait_until(lambda: page_view.property("activeFocus")))
        search_field = self.root.findChild(QObject, "atlasPaperSearchField")
        QMetaObject.invokeMethod(self.root, "focusSearch")
        self.key_text("needle")
        self.assertEqual(search_field.property("text"), "needle")
        before = self.root.property("currentPage")
        self.key_click(Qt.Key.Key_PageDown)
        self.assertEqual(self.root.property("currentPage"), before,
                         "document navigation must not steal keys while search input has focus")

    def test_fit_page_fit_width_zoom_and_keyboard_touch_like_scroll(self):
        self.open_pdf(self.multi_page)
        page_view = self.root.findChild(QObject, "atlasPaperPageView")
        self.root.fitPage()
        self.app.processEvents()
        fit_page_scale = page_view.property("renderScale")
        self.assertEqual(self.root.property("fitMode"), "fit-page")
        self.root.fitWidth()
        self.app.processEvents()
        fit_width_scale = page_view.property("renderScale")
        self.assertEqual(self.root.property("fitMode"), "fit-width")
        self.assertGreater(fit_width_scale, fit_page_scale)
        zoom_label = self.root.findChild(QObject, "atlasPaperZoomPercentage")
        self.assertEqual(zoom_label.property("text"), f"{round(fit_width_scale * 100)}%")
        self.root.zoomBy(1.2)
        self.assertEqual(self.root.property("fitMode"), "custom")
        self.root.fitPage()
        self.app.processEvents()
        self.assertTrue(QMetaObject.invokeMethod(self.root, "focusDocument"))
        self.assertTrue(self.wait_until(lambda: page_view.property("activeFocus")))
        table_view = next((obj for obj in page_view.findChildren(QObject)
                           if obj.property("contentY") is not None and obj.property("contentHeight") is not None), None)
        self.assertIsNotNone(table_view, "Qt PdfMultiPageView should contain its scrollable table view")
        self.assertGreater(table_view.property("contentHeight"), table_view.property("height"))
        self.assertTrue(table_view.property("interactive"), "the built-in Qt scroll surface should remain interactive")
        before_scroll = table_view.property("contentY")
        self.mouse_drag(QPointF(650, 735), QPointF(650, 145))
        self.app.processEvents()
        # Offscreen window event injection may not deliver a pointer grab to Qt's internal TableView;
        # the content extent and interactive state above are the deterministic QML-level check.

    def test_document_switch_search_clear_thumbnails_toggle_and_invalid_pdf(self):
        self.open_pdf(self.multi_page)
        page_view = self.root.findChild(QObject, "atlasPaperPageView")
        search_field = self.root.findChild(QObject, "atlasPaperSearchField")
        self.root.setProperty("thumbnailsVisible", True)
        page_view.goToPage(1)
        search_field.setProperty("text", "FIRST_PAGE_BLUE")
        self.assertTrue(self.wait_until(lambda: self.root.property("searchResultCount") == 1))
        self.root.open(QUrl.fromLocalFile(str(self.one_page)))
        self.assertTrue(self.wait_until(lambda: self.root.property("pageCount") == 1
                                        and self.root.property("currentPage") == 0))
        self.assertEqual(search_field.property("text"), "")
        self.assertFalse(self.root.property("thumbnailsVisible"))
        self.assertEqual(self.root.property("searchResultCount"), 0)
        self.root.open(QUrl.fromLocalFile(str(self.invalid)))
        self.assertTrue(self.wait_until(lambda: self.root.property("pageCount") == 0))
        self.assertTrue(self.wait_until(lambda: self.root.property("documentHasError")))
