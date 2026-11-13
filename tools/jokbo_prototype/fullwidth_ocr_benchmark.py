"""Evaluate OCR coverage across the complete horizontal page width.

Use independently verified names only for scoring, never for OCR generation.
Requires Pillow and installed Tesseract language packs.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from PIL import Image
import argparse
import json
import os
import re
import subprocess
import tempfile

BANDS = [(118,311),(312,502),(503,693),(694,884),(885,1073),(1074,1263),(1264,1459)]


def ocr_one(image, job):
    band, psm, language = job
    top, bottom = BANDS[band]
    crop = image.crop((40, top, image.width - 20, bottom))
    crop = crop.resize((crop.width * 2, crop.height * 2))
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        path = tmp.name
    try:
        crop.save(path)
        process = subprocess.run(
            ["tesseract", path, "stdout", "-l", language, "--psm", str(psm)],
            capture_output=True, text=True, timeout=28,
            env={**os.environ, "OMP_THREAD_LIMIT": "1"})
        return {"band": band, "psm": psm, "language": language,
                "raw": process.stdout if process.returncode == 0 else "",
                "error": process.stderr[-300:] if process.returncode else ""}
    except (subprocess.TimeoutExpired, OSError) as exc:
        return {"band": band, "psm": psm, "language": language,
                "raw": "", "error": str(exc)}
    finally:
        Path(path).unlink(missing_ok=True)


def run(image_path, output, gold_path=None):
    image = Image.open(image_path).convert("RGB")
    if image.size != (1070, 1536):
        raise ValueError("Preset bands are calibrated only for the 1070x1536 page")
    jobs = [(band, psm, lang) for band in range(len(BANDS))
            for psm in (3, 5, 6) for lang in ("HanT_vert", "HanS_vert")]
    with ThreadPoolExecutor(max_workers=8) as executor:
        runs = list(executor.map(lambda job: ocr_one(image, job), jobs))
    result = {"attempts": len(runs), "successful": sum(not r["error"] for r in runs),
              "runs": runs}
    if gold_path:
        gold = json.loads(Path(gold_path).read_text(encoding="utf-8"))
        if not isinstance(gold, list) or not all(isinstance(x, str) and x for x in gold):
            raise ValueError("Gold must be a JSON array of nonempty strings")
        transcripts = [re.sub(r"\s+", "", r["raw"]) for r in runs]
        hits = [name for name in gold if any(name in t for t in transcripts)]
        result["evaluation"] = {"verified_name_count": len(gold),
                                "exact_hits": hits,
                                "ensemble_recall": len(hits) / len(gold) if gold else None,
                                "warning": "Ensemble exact-name recall is not character accuracy"}
    Path(output).write_text(json.dumps(result, ensure_ascii=False, indent=2),
                            encoding="utf-8")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("--output", required=True)
    parser.add_argument("--gold")
    args = parser.parse_args()
    result = run(args.image, args.output, args.gold)
    print(json.dumps({k: v for k, v in result.items() if k != "runs"}, ensure_ascii=False))
