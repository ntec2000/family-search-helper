"""Regression checks for local OCR comparison; no real genealogy data needed."""
import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image


spec = importlib.util.spec_from_file_location(
    "compare_tesseract", Path(__file__).with_name("compare_tesseract.py")
)
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)


class ComparisonTest(unittest.TestCase):
    def test_threshold_adds_candidate_and_keeps_original_variants(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image = root / "input.png"
            names = root / "names.json"
            sample = Image.new("L", (2, 1))
            sample.putdata([50, 220])
            sample.save(image)
            before = image.read_bytes()
            names.write_text(json.dumps(["甲乙"], ensure_ascii=False), encoding="utf-8")
            seen = []

            def recognize(candidate, tessdata, language):
                seen.append((candidate.size, [candidate.getpixel((x, y)) for y in range(candidate.height)
                                              for x in range(candidate.width)]))
                return ["甲乙"]

            output = io.StringIO()
            args = ["compare_tesseract.py", str(image), "--tessdata", str(root),
                    "--names", str(names), "--threshold", "170"]
            with patch.object(sys, "argv", args), patch.object(compare, "recognize", recognize), \
                    contextlib.redirect_stdout(output):
                compare.main()
            report = json.loads(output.getvalue())
            self.assertEqual(list(report["results"]),
                             ["original", "scaled_2x", "scaled_2x_binary_170"])
            self.assertEqual([row["found_count"] for row in report["results"].values()], [1, 1, 1])
            self.assertEqual(seen[0], ((2, 1), [50, 220]))
            self.assertLessEqual(set(seen[-1][1]), {0, 255})
            self.assertEqual(image.read_bytes(), before)

    def test_threshold_outside_range_is_rejected_before_reading_files(self):
        args = ["compare_tesseract.py", "missing", "--tessdata", "missing",
                "--names", "missing", "--threshold", "256"]
        with patch.object(sys, "argv", args), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:
                compare.main()
        self.assertEqual(error.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
