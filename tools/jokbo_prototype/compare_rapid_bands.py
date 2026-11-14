"""Compare full-page and detected-band OCR without changing source images.

Gold names are supplied locally for evaluation only.  This tool does not
assign names or relationships and does not write OCR text or image files.
"""
import argparse
import io
import json
import math
from pathlib import Path

from PIL import Image, ImageOps

from jokbo_layout import detect_bands
from ocr_benchmark_224 import evaluate
from parser_engine import parse_candidates, recognize_rapid


def rotate_for_experiment(image, angle):
    """Rotate a copy only; output coordinates refer to the processed image."""
    if not math.isfinite(angle) or abs(angle) > 5:
        raise ValueError('rotation must be finite and within -5 to 5 degrees')
    if angle == 0:
        return image.copy()
    return image.rotate(angle, resample=Image.Resampling.BICUBIC, fillcolor='white')


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


def candidate_coverage(raws, gold):
    """Count exact candidate name fields; never infer identity or kinship."""
    names = [person.get('name_hanja', '') for raw in raws
             for person in parse_candidates(raw)]
    matches = [name for name in gold if name in names]
    return {'reference_count': len(gold), 'matched_count': len(matches),
            'matched_names': matches, 'unmatched_names': [name for name in gold if name not in names],
            'candidate_count': len(names),
            'warning': 'Exact name-field coverage is not person identity or relationship accuracy.'}


def compare(image, gold, recognize=recognize_rapid, *, min_uncovered_height=10, candidate_gold=None):
    """Evaluate each OCR line independently and retain region coordinates."""
    def read(sample):
        payload = io.BytesIO()
        sample.save(payload, format="PNG")
        return recognize(payload.getvalue())

    baseline_raw = read(image)
    baseline = evaluate([baseline_raw], gold)
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
    result = {
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
    if candidate_gold is not None:
        result['baseline_candidates'] = candidate_coverage([baseline_raw], candidate_gold)
        result['segmented_candidates'] = candidate_coverage(band_results, candidate_gold)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", help="local source image")
    parser.add_argument("--gold", required=True, help="local UTF-8 JSON list of reviewed names")
    parser.add_argument("--candidate-gold", help="optional local JSON list of expected parser name fields")
    parser.add_argument("--rotation-degrees", type=float, default=0,
                        help="experimental rotation of image copy; coordinates refer to rotated pixels")
    args = parser.parse_args()
    gold = json.loads(Path(args.gold).read_text(encoding="utf-8"))
    if not isinstance(gold, list) or not all(isinstance(name, str) and name.strip() for name in gold):
        raise ValueError("gold must be a JSON list of nonempty names")
    if len(set(gold)) != len(gold):
        raise ValueError("duplicate names cannot represent independently identified people")
    candidate_gold = None
    if args.candidate_gold:
        candidate_gold = json.loads(Path(args.candidate_gold).read_text(encoding='utf-8'))
        if (not isinstance(candidate_gold, list)
                or not all(isinstance(name, str) and name.strip() for name in candidate_gold)
                or len(set(candidate_gold)) != len(candidate_gold)):
            raise ValueError('candidate gold must be a JSON list of distinct nonempty names')
    with Image.open(args.image) as source:
        image = ImageOps.exif_transpose(source).convert("RGB")
    processed = rotate_for_experiment(image, args.rotation_degrees)
    report = compare(processed, gold, candidate_gold=candidate_gold)
    report['rotation_degrees'] = args.rotation_degrees
    report['coordinate_space'] = 'rotated image copy; not original source coordinates'
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
