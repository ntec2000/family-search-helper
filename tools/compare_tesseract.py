#!/usr/bin/env python3
"""Compare page, scaled page, and optional manually selected horizontal bands.

Names are local reference strings, not a measure of person or relationship accuracy.
"""
import argparse
import io
import json
import re
import subprocess

from PIL import Image, ImageOps


def recognize(image, tessdata, language):
    data = io.BytesIO()
    image.save(data, format="PNG")
    result = subprocess.run(
        ["tesseract", "stdin", "stdout", "--tessdata-dir", tessdata,
         "-l", language, "--psm", "5"],
        input=data.getvalue(), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        check=True,
    )
    return [re.sub(r"\s+", "", line) for line in result.stdout.decode("utf-8").splitlines()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", help="Local image; never modified")
    parser.add_argument("--tessdata", required=True)
    parser.add_argument("--language", default="chi_tra_vert")
    parser.add_argument("--names", required=True, help="Local JSON array of distinct reference names")
    parser.add_argument("--bands", action="append", default=[],
                        help="Local JSON array of [top, bottom] pixel coordinates; repeat to compare")
    parser.add_argument("--threshold", type=int,
                        help="Optional 0–255 threshold for extra 2x binary comparisons")
    args = parser.parse_args()
    if args.threshold is not None and not 0 <= args.threshold <= 255:
        parser.error("threshold must be between 0 and 255")
    with open(args.names, encoding="utf-8") as source:
        names = json.load(source)
    if (not isinstance(names, list) or not names or
            any(not isinstance(name, str) or not name.strip() for name in names)):
        parser.error("names must be a non-empty JSON array of strings")
    names = [name.strip() for name in names]
    if len(set(names)) != len(names):
        parser.error("reference names must be distinct")
    with Image.open(args.image) as source:
        image = ImageOps.exif_transpose(source).convert("L")
    def scaled(img):
        return img.resize((img.width * 2, img.height * 2), Image.Resampling.LANCZOS)

    variants = {"original": [image], "scaled_2x": [scaled(image)]}
    for band_index, bands_path in enumerate(args.bands):
        with open(bands_path, encoding="utf-8") as source:
            bands = json.load(source)
        if not isinstance(bands, list) or not bands:
            parser.error("bands must be a non-empty JSON array")
        crops = []
        for band in bands:
            if (not isinstance(band, list) or len(band) != 2 or
                    any(type(value) is not int for value in band)):
                parser.error("each band must contain integer top and bottom coordinates")
            top, bottom = band
            if not 0 <= top < bottom <= image.height:
                parser.error("band coordinates must be within the image")
            crops.append(scaled(image.crop((0, top, image.width, bottom))))
        label = "manual_bands_scaled_2x" if band_index == 0 else f"manual_bands_{band_index + 1}_scaled_2x"
        variants[label] = crops
    if args.threshold is not None:
        def binary(img):
            enhanced = ImageOps.autocontrast(img, cutoff=1)
            return enhanced.point(lambda pixel: 255 if pixel > args.threshold else 0)
        # Keep the original variants; thresholding is a comparison, not a replacement.
        variants.update({f"{label}_binary_{args.threshold}": [binary(part) for part in parts]
                         for label, parts in list(variants.items())
                         if label != "original"})
    results = {}
    for label, images in variants.items():
        lines = [line for part in images for line in recognize(part, args.tessdata, args.language)]
        found = [name for name in names if any(name in line for line in lines)]
        results[label] = {
            "found": found,
            "missing": [name for name in names if name not in found],
            "found_count": len(found),
            "reference_count": len(names),
        }
    for label, result in results.items():
        other_names = {name for other_label, other in results.items()
                       if other_label != label for name in other["found"]}
        result["only_in_this_variant"] = [name for name in result["found"]
                                          if name not in other_names]
    any_found = [name for name in names if any(name in result["found"] for result in results.values())]
    print(json.dumps({"image_size": [image.width, image.height],
                      "measure": "exact reference strings within one OCR line; not person accuracy",
                      "found_in_any_variant": any_found,
                      "results": results}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
