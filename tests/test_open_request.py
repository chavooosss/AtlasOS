import pathlib
import runpy
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import quote


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "config/includes.chroot/usr/local/bin/atlasos-open-request"
REQUEST = runpy.run_path(str(SCRIPT), run_name="atlasos_test_module")


class OpenRequestTests(unittest.TestCase):
    def test_pdf_dispatch_and_encoded_path(self):
        with tempfile.TemporaryDirectory(dir=pathlib.Path.home()) as folder:
            file = pathlib.Path(folder) / "ders notu.pdf"
            file.touch()
            with patch.object(REQUEST["subprocess"], "Popen") as launch:
                result = REQUEST["open_file"]({"kind": ["pdf"], "url": [file.as_uri()]})
            self.assertEqual(result, 0)
            launch.assert_called_once()
            self.assertEqual(launch.call_args.args[0], ["evince", str(file)])

    def test_mismatched_file_type_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=pathlib.Path.home()) as folder:
            file = pathlib.Path(folder) / "script.desktop"
            file.touch()
            with patch.dict(REQUEST["open_file"].__globals__, {"fail": lambda message: 1}):
                self.assertEqual(REQUEST["open_file"]({"kind": ["auto"], "url": [file.as_uri()]}), 1)

    def test_browser_rejects_local_scheme(self):
        with patch.dict(REQUEST["open_browser"].__globals__, {"fail": lambda message: 1}):
            self.assertEqual(REQUEST["open_browser"]({"url": ["file:///etc/passwd"]}), 1)

    def test_url_request_decoding(self):
        from urllib.parse import parse_qs, urlparse

        file_url = "file:///home/atlas/Ders%20Kitaplari/not.pdf"
        request = urlparse("atlasos://open-file?kind=pdf&url=" + quote(file_url, safe=""))
        self.assertEqual(parse_qs(request.query)["url"][0], file_url)


if __name__ == "__main__":
    unittest.main()
