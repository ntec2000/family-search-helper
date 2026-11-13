"""Resumable, evidence-preserving Tesseract OCR sweep for a local genealogy image.

No verified names are inserted into OCR output. Source images remain local.
Requires Pillow, Tesseract and explicitly installed language models.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from PIL import Image, ImageEnhance, ImageOps
import argparse
import json
import os
import subprocess
import tempfile

DEFAULT_BANDS = ((300, 484), (485, 662), (664, 840),
                 (842, 1024), (1026, 1207), (1210, 1390))


def configurations(count=100):
    for i in range(count):
        yield (i, i % 6, (i // 6) % 5, (2, 3, 4)[(i // 30) % 3],
               (3, 5, 6, 11)[(i // 15) % 4],
               ("HanT_vert", "chi_tra_vert", "HanS_vert")[(i // 20) % 3])


def run_one(image, job):
    index, band, variant, scale, psm, lang = job
    y0, y1 = DEFAULT_BANDS[band]
    left = (390, 470, 550, 620, 700)[variant]
    if image.width < 940 or image.height < y1:
        raise ValueError("Input image dimensions are smaller than preset ROI")
    crop = image.crop((left, y0, 940, y1))
    crop = crop.resize((crop.width * scale, crop.height * scale))
    if variant == 1:
        crop = ImageEnhance.Contrast(ImageOps.grayscale(crop)).enhance(1.7)
    elif variant == 2:
        crop = ImageEnhance.Sharpness(crop).enhance(2.5)
    elif variant == 3:
        crop = ImageOps.autocontrast(ImageOps.grayscale(crop))
    elif variant == 4:
        crop = ImageEnhance.Contrast(ImageOps.grayscale(crop)).enhance(2.4)
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as file:
        filename = file.name
    try:
        crop.save(filename)
        result = subprocess.run(
            ["tesseract", filename, "stdout", "-l", lang, "--psm", str(psm)],
            capture_output=True, text=True, timeout=28,
            env={**os.environ, "OMP_THREAD_LIMIT": "1"})
        return {"id": index, "band": band, "variant": variant, "scale": scale,
                "psm": psm, "language": lang,
                "raw": result.stdout if result.returncode == 0 else "",
                "error": result.stderr[-300:] if result.returncode else ""}
    except (subprocess.TimeoutExpired, OSError) as error:
        return {"id": index, "band": band, "variant": variant, "scale": scale,
                "psm": psm, "language": lang, "raw": "", "error": str(error)}
    finally:
        Path(filename).unlink(missing_ok=True)


def execute(image_path, checkpoint, batch=20, workers=6):
    image = Image.open(image_path).convert("RGB")
    checkpoint = Path(checkpoint)
    stored = json.loads(checkpoint.read_text(encoding="utf-8")) if checkpoint.exists() else {}
    if stored and stored.get("source") != str(Path(image_path).resolve()):
        raise ValueError("Checkpoint source image mismatch")
    runs = stored.get("runs", {})
    remaining = [job for job in configurations() if str(job[0]) not in runs][:batch]
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for future in as_completed([pool.submit(run_one, image, job) for job in remaining]):
            result = future.result()
            runs[str(result["id"])] = result
            temporary = checkpoint.with_suffix(".tmp")
            temporary.write_text(json.dumps(
                {"source": str(Path(image_path).resolve()), "runs": runs},
                ensure_ascii=False), encoding="utf-8")
            temporary.replace(checkpoint)
    return {"completed": len(runs),
            "success": sum(not item["error"] for item in runs.values())}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--batch", type=int, default=20)
    parser.add_argument("--workers", type=int, default=6)
    args = parser.parse_args()
    print(json.dumps(execute(args.image, args.checkpoint,
                             args.batch, args.workers)))
