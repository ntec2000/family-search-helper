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


def uncovered_ranges(height, bands):
    """Return half-open image rows that are not sent for segmented OCR."""
    missing = []
    cursor = 0
    for top, bottom in sorted(bands):
        if not (0 <= top < bottom <= height):
            raise ValueError("band bounds must be inside the image")
        if top > cursor:
            missing.append((cursor, top))
        cursor = max(cursor, bottom)
    if cursor < height:
        missing.append((cursor, height))
    return missing


def compare(image, gold, recognize=recognize_rapid, *, min_uncovered_height=10):
    """Evaluate each OCR line independently and retain region coordinates."""
    def read(sample):
        payload = io.BytesIO()
        sample.save(payload, format="PNG")
        return recognize(payload.getvalue())

    baseline = evaluate([read(image)], gold)
    bands = detect_bands(image)
    uncovered = uncovered_ranges(image.height, bands)
    band_results = [read(image.crop((0, top, image.width, bottom)))
                    for top, bottom in bands]
    # Keep OCR from gaps separate; a detector with no bands falls back to the
    # already-read full page rather than running the same OCR a second time.
    review_ranges = [(top, bottom) for top, bottom in uncovered
                     if bands and bottom - top >= min_uncovered_height]
    review_results = [read(image.crop((0, top, image.width, bottom)))
                      for top, bottom in review_ranges]
    segmented = evaluate(band_results, gold)
    review = evaluate(review_results, gold)
    baseline_names = set(baseline["matched_names"])
    segmented_names = set(segmented["matched_names"])
    return {
        "image_size": list(image.size),
        "band_bounds": bands,
        "uncovered_rows": uncovered,
        "reviewed_uncovered_rows": review_ranges,
        "uncovered_review": review,
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
