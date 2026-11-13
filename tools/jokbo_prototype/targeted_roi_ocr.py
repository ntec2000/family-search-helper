"""Page-224 ROI OCR diagnostic. Never uses expected names as OCR input.

This intentionally stores all raw outputs so failures can be reviewed.
Coordinates are calibrated to the 1070x1536 reference scan only.
"""
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageEnhance, ImageOps
from pathlib import Path
import argparse
import json
import os
import subprocess
import tempfile

RECTS = [(835,300,920,485),(665,485,810,663),(825,660,920,845),
         (335,842,435,1025),(660,842,810,1025),(685,1024,815,1210)]


def recognize(image, job):
    index, scale, variant, psm, lang = job
    left, top, right, bottom = RECTS[index]
    region = image.crop((left, top, right, bottom))
    region = region.resize((region.width * scale, region.height * scale))
    if variant:
        region = ImageEnhance.Contrast(
            ImageOps.autocontrast(ImageOps.grayscale(region))).enhance(2)
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as handle:
        path = handle.name
    try:
        region.save(path)
        process = subprocess.run(
            ["tesseract", path, "stdout", "-l", lang, "--psm", str(psm)],
            capture_output=True, text=True, timeout=20,
            env={**os.environ, "OMP_THREAD_LIMIT": "1"})
        return {"job": job, "raw": process.stdout if process.returncode == 0 else "",
                "error": process.stderr[-300:] if process.returncode else ""}
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"job": job, "raw": "", "error": str(exc)}
    finally:
        Path(path).unlink(missing_ok=True)


def run(image_path, output_path):
    image = Image.open(image_path).convert("RGB")
    if image.size != (1070, 1536):
        raise ValueError("ROI calibration requires 1070x1536 image")
    jobs = [(i, scale, variant, psm, lang)
            for i in range(len(RECTS))
            for scale in (3, 5) for variant in (0, 1)
            for psm in (5, 6) for lang in ("HanT_vert", "HanS_vert")]
    with ThreadPoolExecutor(max_workers=12) as executor:
        runs = list(executor.map(lambda job: recognize(image, job), jobs))
    Path(output_path).write_text(
        json.dumps({"source": image_path, "rectangles": RECTS, "runs": runs},
                   ensure_ascii=False, indent=2), encoding="utf-8")
    return {"attempts": len(runs),
            "success": sum(not r["error"] for r in runs)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    print(json.dumps(run(args.image, args.output)))
