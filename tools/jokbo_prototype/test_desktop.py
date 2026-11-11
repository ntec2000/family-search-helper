import importlib.util
import os
import socket
import sys
import tempfile
import types
import unittest
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from unittest.mock import patch

class Handler(BaseHTTPRequestHandler):
    ocr_engine = None
    web_root = None

engine = types.ModuleType("parser_engine")
engine.Handler = Handler
engine.PORT = 0
engine.ORIGIN = "http://127.0.0.1:0"
spec = importlib.util.spec_from_file_location("desktop", Path(__file__).with_name("desktop.py"))
desktop = importlib.util.module_from_spec(spec)
with patch.dict(sys.modules, {"parser_engine": engine}):
    spec.loader.exec_module(desktop)

class DesktopTest(unittest.TestCase):
    def test_window_uses_persistent_separate_profile_and_closes_server(self):
        events = []
        webview = types.SimpleNamespace(
            create_window=lambda *a, **k: events.append(("window", a, k)),
            start=lambda **k: events.append(("start", k)),
        )
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {"LOCALAPPDATA": directory}):
            desktop.run(webview)
            self.assertEqual(events[0][1][1], engine.ORIGIN)
            self.assertFalse(events[1][1]["private_mode"])
            self.assertEqual(events[1][1]["storage_path"], str(Path(directory) / "FamilyHistoryHelper" / "WebView"))
            self.assertTrue(Path(events[1][1]["storage_path"]).is_dir())
            self.assertEqual(Handler.ocr_engine, "rapidocr")

    def test_port_collision_does_not_open_untrusted_window(self):
        called = []
        webview = types.SimpleNamespace(create_window=lambda *a, **k: called.append(True))
        with socket.socket() as reserved:
            reserved.bind(("127.0.0.1", 0))
            reserved.listen()
            with patch.object(engine, "PORT", reserved.getsockname()[1]):
                with self.assertRaises(OSError):
                    desktop.run(webview)
        self.assertEqual(called, [])

if __name__ == "__main__":
    unittest.main()
