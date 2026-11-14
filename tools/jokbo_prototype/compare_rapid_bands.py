"""Compare full-page and detected-band OCR without changing source images.

Gold names are supplied locally for evaluation only.  This tool does not
assign names or relationships and does not write OCR text or image files.
"""
import argparse
import io
import json
from pathlib import Path

from PIL import Image, ImageOps

from jokbo_layout import detect_bands
from ocr_benchmark_224 import evaluate
from parser_engine import recognize_rapid


def compare(image, gold, recognize=recognize_rapid):
    """Evaluate each OCR line independently and retain region coordinates."""
    def read(sample):
        payload = io.BytesIO()
        sample.save(payload, format="PNG")
        return recognize(payload.getvalue())

    baseline = evaluate([read(image)], gold)
    bands = detect_bands(image)
    band_results = [read(image.crop((0, top, image.width, bottom)))
                    for top, bottom in bands]
    segmented = evaluate(band_results, gold)
    baseline_names = set(baseline["matched_names"])
    segmented_names = set(segmented["matched_names"])
    return {
        "image_size": list(image.size),
        "band_bounds": bands,
        "baseline": baseline,
        "segmented": segmented,
        "baseline_only": sorted(baseline_names - segmented_names),
        "segmented_only": sorted(segmented_names - baseline_names),
        "warning": "Name substring coverage is not OCR accuracy or relationship accuracy; bands require review.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", help="local source image")
    parser.add_argument("--gold", required=True, help="local UTF-8 JSON list of reviewed names")
    args = parser.parse_args()
    gold = json.loads(Path(args.gold).read_text(encoding="utf-8"))
    if not isinstance(gold, list) or not all(isinstance(name, str) and name.strip() for name in gold):
        raise ValueError("gold must be a JSON list of nonempty names")
    if len(set(gold)) != len(gold):
        raise ValueError("duplicate names cannot represent independently identified people")
    with Image.open(args.image) as source:
        image = ImageOps.exif_transpose(source).convert("RGB")
    print(json.dumps(compare(image, gold), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
