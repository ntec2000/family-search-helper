"""Local-only OCR and review prototype."""
import argparse
import threading
import webbrowser
import mimetypes
import importlib.util
from importlib.metadata import version, PackageNotFoundError
import io
from functools import lru_cache
import json
import re
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parents[1] / "web" / "ocr-models"
LIMIT = 12 * 1024 * 1024
PORT = 8765
ORIGIN = f"http://127.0.0.1:{PORT}"
HAN = r"[㐀-䶿一-鿿𠀀-𲎯]"
GENERATION = re.compile(r"^\s*([0-9]{1,3}|[〇零一二三四五六七八九十百]{1,6})\s*[世세]\s*")
PERSON_MARKER = re.compile(r"^\s*(?P<marker>휘\(諱\)|諱|휘|子|男|女)\s*")
NAME = re.compile(rf"^(?P<name>{HAN}{{1,4}}?|[가-힣]{{1,5}}?)(?=\s|$|[字号號墓配]|[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥](?:年)?[生卒])")
DATE = re.compile(r"(?:[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥](?:年)?|[0-9]{4}年)\s*[生卒]")
NOTE_START = re.compile(r"^(?:坐|向|孫|女|男|配|字|號|墓|忌|生|卒|父|祖)")


def generation_number(value):
    if value.isascii() and value.isdigit():
        return str(int(value))
    digits = dict(zip("〇零一二三四五六七八九", [0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]))
    total, current = 0, 0
    for char in value:
        if char in digits:
            current = digits[char]
        elif char in "十百":
            total += (current or 1) * (10 if char == "十" else 100)
            current = 0
    return str(total + current)


def parse_candidates(raw, surname=""):
    """Recognize explicit line headings; preserve the complete transcript."""
    surname = surname.strip()
    if surname.endswith("씨"):
        surname = surname[:-1]
    if surname and not re.fullmatch(r"[가-힣]{1,2}", surname):
        raise ValueError("작업 성씨를 한글 한두 글자로 입력하세요.")
    generation = ""
    candidates = []
    for original in raw.lstrip("\ufeff").splitlines():
        line = original.strip()
        gen = GENERATION.match(line)
        if gen:
            generation = generation_number(gen[1])
            line = line[gen.end():]
        heading = PERSON_MARKER.match(line)
        if not heading:
            continue
        marker = heading["marker"]
        rest = line[heading.end():].strip()
        if not rest or NOTE_START.match(rest):
            continue
        name_match = NAME.match(rest)
        if not name_match:
            continue
        name = name_match["name"]
        daughter = marker == "女"
        tail = rest[name_match.end():].split("配", 1)[0].strip()
        is_han = re.fullmatch(HAN + "+", name) is not None
        candidates.append({
            "generation": generation,
            "name_hanja": "" if daughter or not is_han else name,
            "name_korean": (surname + "씨" if surname else "이름 미상") if daughter
                else ("" if is_han else surname + name if surname and not name.startswith(surname) else name),
            "surname": surname,
            "relation": "딸 후보" if daughter else "아들 후보" if marker in ("子", "男") else "인물 후보",
            "birth_death": "" if daughter else " · ".join(DATE.findall(tail)),
            "details": ("사위 후보 원문 · " + rest) if daughter else tail,
            "verified": False,
        })
    return candidates


def order_rotated_lines(boxes, texts):
    """Group fragments of a rotated single band, then read right to left."""
    fragments = []
    for points, text in zip(boxes, texts):
        xs, ys = zip(*points)
        if max(ys) > min(ys) and text.strip():
            fragments.append((min(ys), max(ys), min(xs), text))
    fragments.sort(key=lambda item: (item[0] + item[1]) / 2)
    lines = []
    for top, bottom, left, text in fragments:
        for line in lines:
            line_top, line_bottom, parts = line
            overlap = min(bottom, line_bottom) - max(top, line_top)
            if overlap >= min(bottom - top, line_bottom - line_top) / 2:
                parts.append((left, text))
                break
        else:
            lines.append((top, bottom, [(left, text)]))
    return "\n".join(" ".join(text for _, text in sorted(parts))
                     for _, _, parts in lines)


@lru_cache(maxsize=1)
def rapid_engine():
    from rapidocr import ModelType, OCRVersion, RapidOCR

    return RapidOCR(params={
        "Det.ocr_version": OCRVersion.PPOCRV5,
        "Det.model_type": ModelType.MOBILE,
        "Rec.ocr_version": OCRVersion.PPOCRV6,
        "Rec.model_type": ModelType.SMALL,
    })


@lru_cache(maxsize=4)
def recognize_rapid(image, *, glyph=False):
    try:
        import numpy as np
        from PIL import Image, ImageOps, UnidentifiedImageError
    except ImportError as error:
        raise RuntimeError("RapidOCR 실행에는 rapidocr, onnxruntime, pillow가 필요합니다.") from error
    try:
        with Image.open(io.BytesIO(image)) as original:
            turned = ImageOps.exif_transpose(original).convert("RGB")
            if not glyph:
                turned = turned.transpose(Image.Transpose.ROTATE_90)
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError) as error:
        raise ValueError("이미지 파일을 읽지 못했습니다.") from error
    try:
        # RapidOCR accepts an OpenCV-style BGR array.
        pixels = np.ascontiguousarray(np.asarray(turned)[:, :, ::-1])
        if glyph:
            output = rapid_engine()(pixels, use_det=False, use_cls=False, use_rec=True)
            return "".join(output.txts or ())
        output = rapid_engine()(pixels)
    except ImportError as error:
        raise RuntimeError("RapidOCR 실행에는 rapidocr, onnxruntime, pillow가 필요합니다.") from error
    except Exception as error:
        raise RuntimeError("RapidOCR 판독에 실패했습니다. 모델 설치와 로그를 확인하세요.") from error
    if output.boxes is None or not output.txts:
        return ""
    return order_rotated_lines(output.boxes, output.txts)


def recognize(image, engine="tesseract", surname=""):
    if not image.startswith((b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff")):
        raise ValueError("JPG 또는 PNG 이미지를 선택하세요.")
    if engine == "rapidocr":
        raw = recognize_rapid(image)
        return {"raw": raw, "candidates": parse_candidates(raw, surname)}
    try:
        result = subprocess.run(
            ["tesseract", "stdin", "stdout", "--tessdata-dir", str(MODEL_DIR),
             "-l", "chi_tra_vert", "--oem", "1", "--psm", "5"],
            input=image, capture_output=True, timeout=45,
        )
    except FileNotFoundError as error:
        raise RuntimeError("Tesseract 5를 설치하고 PATH에 추가하세요.") from error
    except subprocess.TimeoutExpired as error:
        raise RuntimeError("OCR 처리 시간이 초과되었습니다. 더 작은 구획 이미지를 선택하세요.") from error
    if result.returncode:
        raise RuntimeError("이미지 또는 세로쓰기 모델을 읽지 못했습니다.")
    raw = result.stdout.decode("utf-8")
    return {"raw": raw, "candidates": parse_candidates(raw, surname)}


class Handler(BaseHTTPRequestHandler):
    ocr_engine = "tesseract"
    web_root = None

    def respond(self, status, body, kind="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", f"{kind}; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_json(self, status, payload):
        self.respond(status, json.dumps(payload, ensure_ascii=False).encode("utf-8"))

    def do_GET(self):
        route = unquote(urlsplit(self.path).path)
        if route == "/api/ocr/capabilities":
            engine = None
            installed_version = None
            if self.ocr_engine == "rapidocr" and importlib.util.find_spec("rapidocr"):
                try:
                    installed_version = version("rapidocr")
                    engine = "rapidocr"
                except PackageNotFoundError:
                    pass
            self.send_json(200, {"engine": engine, "version": installed_version,
                                 "glyph": engine is not None})
            return
        if self.web_root is not None:
            target = (self.web_root / route.lstrip("/")).resolve()
            if route == "/":
                target = self.web_root / "index.html"
            if not target.is_relative_to(self.web_root) or not target.is_file():
                self.send_error(404)
                return
            content_type = mimetypes.guess_type(target.name)[0] or "application/octet-stream"
            self.respond(200, target.read_bytes(), content_type)
        elif route == "/":
            self.respond(200, (HERE / "index.html").read_bytes(), "text/html")
        else:
            self.send_error(404)

    def do_POST(self):
        route = {"/api/ocr": "/ocr", "/api/ocr/glyph": "/ocr/glyph"}.get(self.path, self.path)
        if route not in ("/ocr", "/ocr/glyph", "/parse"):
            self.send_error(404)
            return
        if self.headers.get("Host") != f"127.0.0.1:{PORT}" or self.headers.get("Origin") != ORIGIN:
            self.send_json(403, {"error": "로컬 앱 화면에서 OCR을 실행하세요."})
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= LIMIT:
                raise ValueError("12 MiB 이하 이미지를 선택하세요.")
            self.connection.settimeout(10)
            image = self.rfile.read(size)
            if route == "/parse":
                try:
                    data = json.loads(image.decode("utf-8-sig"))
                except (UnicodeDecodeError, json.JSONDecodeError) as error:
                    raise ValueError("원문 요청을 읽지 못했습니다.") from error
                if not isinstance(data, dict) or not isinstance(data.get("raw"), str) or not isinstance(data.get("surname", ""), str):
                    raise ValueError("원문과 성씨를 문자열로 입력하세요.")
                raw = data["raw"]
                self.send_json(200, {"raw": raw, "candidates": parse_candidates(raw, data.get("surname", ""))})
            elif route == "/ocr/glyph":
                if not image.startswith((b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff")):
                    raise ValueError("한 글자 영역을 다시 선택하세요.")
                raw = recognize_rapid(image, glyph=True)
                self.send_json(200, {"raw": raw})
            else:
                self.send_json(200, recognize(image, self.ocr_engine, unquote(self.headers.get("X-Jokbo-Surname", ""))))
        except ValueError as error:
            self.send_json(400, {"error": str(error)})
        except RuntimeError as error:
            self.send_json(422, {"error": str(error)})
        except TimeoutError:
            self.send_json(408, {"error": "이미지 전송 시간이 초과되었습니다."})


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--engine", choices=("tesseract", "rapidocr"), default="tesseract")
    cli.add_argument("--open-browser", action="store_true")
    cli.add_argument("--web-build", type=Path,
                     help="Serve the main Flutter web build with same-origin RapidOCR")
    args = cli.parse_args()
    if args.web_build is not None:
        Handler.web_root = args.web_build.resolve()
        if not (Handler.web_root / "index.html").is_file():
            cli.error("Flutter 웹 빌드의 index.html을 찾지 못했습니다.")
    Handler.ocr_engine = args.engine
    with HTTPServer(("127.0.0.1", PORT), Handler) as server:
        print(ORIGIN, flush=True)
        if args.open_browser:
            threading.Timer(0.5, webbrowser.open, args=(ORIGIN,)).start()
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


