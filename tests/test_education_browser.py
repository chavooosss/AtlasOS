import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
BROWSER = ROOT / "config/includes.chroot/usr/local/share/atlasos/ui/components/AtlasBrowser.qml"
MAIN = ROOT / "config/includes.chroot/usr/local/share/atlasos/ui/Main.qml"


class EducationBrowserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.browser = BROWSER.read_text(encoding="utf-8")
        cls.main = MAIN.read_text(encoding="utf-8")

    def test_named_platforms_use_the_official_start_urls(self):
        for expected in (
            'url: "https://eba.gov.tr/"',
            'url: "https://meb.gov.tr/"',
            'url: "https://ogmmateryal.eba.gov.tr/"',
            'url: "https://mebi.eba.gov.tr/"',
        ):
            self.assertIn(expected, self.browser)
        self.assertIn("browser.open(sources[target].platform)", self.main)

    def test_address_is_display_only_and_arbitrary_url_entry_is_absent(self):
        self.assertIn('objectName: "browserAddressDisplay"', self.browser)
        self.assertNotIn("TextInput", self.browser)
        self.assertNotIn("navigateAddress", self.browser)
        self.assertNotIn("property string addressText", self.browser)

    def test_main_frame_navigation_is_https_and_domain_allowlisted(self):
        self.assertIn("function isAllowedHost(hostName)", self.browser)
        self.assertIn('["eba.gov.tr", "meb.gov.tr", "turkiye.gov.tr", "geogebra.org"]', self.browser)
        self.assertIn("function isAllowedUrl(urlValue)", self.browser)
        self.assertIn("request.isMainFrame || browser.isAllowedUrl", self.browser)
        self.assertIn("request.reject()", self.browser)
        self.assertNotIn("--ignore-certificate-errors", self.browser)

    def test_trusted_popup_reuses_the_single_view_and_untrusted_popup_is_blocked(self):
        self.assertIn("request.openIn(browser.currentView)", self.browser)
        self.assertIn("browser.isAllowedUrl(destination)", self.browser)
        self.assertNotIn("function newTab()", self.browser)
        self.assertNotIn("function openNewView(", self.browser)

    def test_main_does_not_bind_removed_external_browser_signal(self):
        self.assertNotIn("onExternalBrowserRequested", self.main)
        self.assertIn("request.reject()", self.browser)
        self.assertIn("onNewWindowRequested", self.browser)

    def test_navigation_controls_and_site_home_are_real_actions(self):
        self.assertIn("currentView.goBack()", self.browser)
        self.assertIn("currentView.goForward()", self.browser)
        self.assertIn("currentView.reload()", self.browser)
        self.assertIn("function home()", self.browser)
        self.assertIn("view.url = platform.url", self.browser)
        self.assertIn('else if (modelData.action === "home") browser.home()', self.browser)

    def test_accepted_scale_and_page_zoom_remain_separate(self):
        self.assertIn("if (physicalScale >= 1.9) return 1.75", self.main)
        self.assertIn("return physicalScale >= 1.9 ? browserUiScale : interfaceScale", self.main)
        self.assertIn("zoomFactor: browser.effectiveContentZoomFactor", self.browser)
        self.assertIn("property real suggestedContentZoomFactor", self.browser)


if __name__ == "__main__":
    unittest.main()
