"""Windows desktop shell for the local OCR review prototype."""
import os
import sys
import threading
from pathlib import Path
from http.server import HTTPServer

import parser_engine


def profile_path():
    base = Path(os.environ.get("LOCALAPPDATA", Path.home()))
    return base / "FamilyHistoryHelper" / "WebView"


def run(webview):
    # A fixed origin is required by the existing request validation and storage.
    # Fail closed if the port is occupied; never display an unknown local server.
    parser_engine.Handler.ocr_engine = "rapidocr"
    parser_engine.Handler.web_root = None
    with HTTPServer(("127.0.0.1", parser_engine.PORT), parser_engine.Handler) as server:
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            storage = profile_path()
            storage.mkdir(parents=True, exist_ok=True)
            webview.create_window(
                "가족역사 기록 도우미 — OCR 검수",
                parser_engine.ORIGIN,
                width=1280, height=850, min_size=(900, 600),
            )
            webview.start(private_mode=False, storage_path=str(storage))
        finally:
            server.shutdown()
            worker.join(timeout=5)


def main():
    try:
        import webview
        run(webview)
    except Exception as exc:
        message = (
            "데스크톱 창을 시작하지 못했습니다.\n"
            "다른 실행 창을 닫고 WebView2 및 설치 상태를 확인하세요.\n\n"
            + str(exc)
        )
        if sys.platform == "win32":
            import ctypes
            ctypes.windll.user32.MessageBoxW(0, message, "가족역사 기록 도우미", 0x10)
        else:
            print(message, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
