"""Local-only OCR and review prototype."""
import argparse
import io
from functools import lru_cache
import json
import re
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE.parents[1] / "web" / "ocr-models"
LIMIT = 12 * 1024 * 1024
PORT = 8765
ORIGIN = f"http://127.0.0.1:{PORT}"
HAN = r"[㐀-䶿一-鿿𠀀-𲎯]"
HEADING = re.compile(rf"^[ \t]*(?:(?P<generation>[0-9]+)[ \t]*[世세][ \t]*)?(?:諱|휘)(?:\(諱\))?[ \t]*(?P<name>{HAN}{{1,5}}?|[가-힣]{{1,5}}?)(?=[ \t]|$|[字号號墓配]|[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥](?:年)?[生卒])", re.M)


def parse_candidates(raw):
    """Only explicit person headings delimit candidates. Keep all OCR separately."""
    headings = list(HEADING.finditer(raw))
    candidates = []
    for index, heading in enumerate(headings):
        end = headings[index + 1].start() if index + 1 < len(headings) else len(raw)
        # Only the heading line has an unambiguous person context in this
        # narrow parser. Multiline or spouse notes remain in the OCR transcript.
        line = raw[heading.end():end].split("\n", 1)[0].split("配", 1)[0]
        dates = re.findall(r"(?:[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥](?:年)?|[0-9]{4}年)[ \t]*[生卒]", line)
        name = heading["name"]
        is_han = re.fullmatch(HAN + "+", name) is not None
        candidates.append({
            "generation": heading["generation"] or "",
            "name_hanja": name if is_han else "",
            "name_korean": "" if is_han else name,
            "birth_death": " · ".join(dates),
            "details": line.strip(),
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


def recognize(image, engine="tesseract"):
    if not image.startswith((b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff")):
        raise ValueError("JPG 또는 PNG 이미지를 선택하세요.")
    if engine == "rapidocr":
        raw = recognize_rapid(image)
        return {"raw": raw, "candidates": parse_candidates(raw)}
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
    return {"raw": raw, "candidates": parse_candidates(raw)}


class Handler(BaseHTTPRequestHandler):
    ocr_engine = "tesseract"

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
        if self.path == "/":
            self.respond(200, (HERE / "index.html").read_bytes(), "text/html")
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path not in ("/ocr", "/ocr/glyph"):
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
            if self.path == "/ocr/glyph":
                if not image.startswith(b"\x89PNG\r\n\x1a\n"):
                    raise ValueError("한 글자 영역을 다시 선택하세요.")
                raw = recognize_rapid(image, glyph=True)
                self.send_json(200, {"raw": raw})
            else:
                self.send_json(200, recognize(image, self.ocr_engine))
        except ValueError as error:
            self.send_json(400, {"error": str(error)})
        except RuntimeError as error:
            self.send_json(422, {"error": str(error)})
        except TimeoutError:
            self.send_json(408, {"error": "이미지 전송 시간이 초과되었습니다."})


if __name__ == "__main__":
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--engine", choices=("tesseract", "rapidocr"), default="tesseract")
    Handler.ocr_engine = cli.parse_args().engine
    with HTTPServer(("127.0.0.1", PORT), Handler) as server:
        print(ORIGIN, flush=True)
        server.serve_forever()
