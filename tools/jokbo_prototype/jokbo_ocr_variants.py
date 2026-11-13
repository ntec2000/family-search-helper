"""Run real Tesseract OCR on supplied horizontal genealogy bands.

No ground-truth data is used to generate OCR. This is an experiment runner,
not an OCR accuracy claim. Requires Pillow and Tesseract HanT_vert.
"""
import argparse
import json
import subprocess
import tempfile
from PIL import Image, ImageEnhance, ImageOps


def run(image_path, bands, output):
    image = Image.open(image_path).convert("RGB")
    runs = []
    for index, (top, bottom) in enumerate(bands):
        if not (0 <= top < bottom <= image.height):
            raise ValueError("Band bounds outside image")
        region = image.crop((0, top, image.width, bottom))
        region = region.resize((region.width * 3, region.height * 3))
        for variant in ("original", "contrast", "sharp"):
            processed = (region if variant == "original" else
                         ImageEnhance.Contrast(ImageOps.grayscale(region)).enhance(2)
                         if variant == "contrast" else
                         ImageEnhance.Sharpness(region).enhance(2.5))
            with tempfile.NamedTemporaryFile(suffix=".png") as temp:
                processed.save(temp.name)
                for psm in (3, 5):
                    proc = subprocess.run(
                        ["tesseract", temp.name, "stdout", "-l", "HanT_vert",
                         "--psm", str(psm)], capture_output=True, text=True,
                        timeout=60, check=False)
                    runs.append({"band": index, "bounds": [top, bottom],
                                 "variant": variant, "psm": psm,
                                 "returncode": proc.returncode,
                                 "raw": proc.stdout if proc.returncode == 0 else "",
                                 "error": proc.stderr[-300:] if proc.returncode else ""})
    with open(output, "w", encoding="utf-8") as file:
        json.dump({"image": image_path, "runs": runs}, file, ensure_ascii=False, indent=2)
    return runs


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("--bands", required=True, help="Comma-separated top:bottom pixel pairs")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    bounds = [tuple(map(int, entry.split(":"))) for entry in args.bands.split(",")]
    run(args.image, bounds, args.output)
