import importlib.util
import json
import tempfile
import threading
import unittest
from http.client import HTTPConnection
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "integrated_ocr_server", Path(__file__).parent / "jokbo_prototype/parser_engine.py")
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


class IntegratedServerTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)
        (self.root / "index.html").write_text("<title>Family History</title>")
        (self.root / "app.js").write_text("window.started=true")
        (self.root / "module.wasm").write_bytes(b"\x00asm")
        class Handler(engine.Handler):
            web_root = self.root
            ocr_engine = "rapidocr"
        self.server = engine.HTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.folder.cleanup()

    def request(self, method, path, body=None, origin=engine.ORIGIN):
        client = HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        client.request(method, path, body,
                       {"Host":"127.0.0.1:8765", "Origin":origin})
        response = client.getresponse()
        result = response.status, response.read(), response.getheader("Content-Type")
        client.close()
        return result

    def test_flutter_assets_and_no_directory_escape(self):
        status, body, _ = self.request("GET", "/")
        self.assertEqual(status, 200)
        self.assertIn(b"Family History", body)
        self.assertEqual(self.request("GET", "/app.js?v=1")[0], 200)
        self.assertEqual(self.request("GET", "/module.wasm")[2], "application/wasm")
        self.assertEqual(self.request("GET", "/%2e%2e/parser_engine.py")[0], 404)

    def test_same_origin_glyph_endpoint(self):
        with patch.object(engine, "recognize_rapid", return_value="核") as ocr:
            for image in (b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff"):
                status, body, _ = self.request("POST", "/api/ocr/glyph", image)
                self.assertEqual(status, 200)
                self.assertEqual(json.loads(body)["raw"], "核")
                self.assertEqual(ocr.call_args.kwargs, {"glyph":True})
        self.assertEqual(self.request("POST", "/api/ocr/glyph", b"x", origin="https://example.com")[0], 403)

    def test_full_page_endpoint(self):
        with patch.object(engine, "recognize", return_value={"raw":"子格","candidates":[]}) as ocr:
            status, body, _ = self.request("POST", "/api/ocr", b"image-bytes")
            self.assertEqual(status, 200)
            self.assertEqual(json.loads(body)["raw"], "子格")
            self.assertEqual(ocr.call_args.args[1], "rapidocr")


if __name__ == "__main__":
    unittest.main()
