import unittest
from unittest.mock import patch
from PIL import Image
from compare_rapid_bands import compare


class ComparisonTests(unittest.TestCase):
    def test_evaluates_regions_separately_and_reports_losses(self):
        image = Image.new("RGB", (80, 100), "white")
        outputs = iter(["甲\n乙", "丙", "乙"])
        with patch("compare_rapid_bands.detect_bands", return_value=[(0, 40), (40, 100)]):
            result = compare(image, ["甲", "乙", "丙"], lambda _: next(outputs))
        self.assertEqual(result["baseline"]["matched_count"], 2)
        self.assertEqual(result["segmented"]["matched_count"], 2)
        self.assertEqual(result["baseline_only"], ["甲"])
        self.assertEqual(result["segmented_only"], ["丙"])
        self.assertEqual(result["band_bounds"], [(0, 40), (40, 100)])

    def test_no_detected_bands_is_not_success(self):
        with patch("compare_rapid_bands.detect_bands", return_value=[]):
            result = compare(Image.new("RGB", (20, 20)), ["甲"], lambda _: "甲")
        self.assertEqual(result["segmented"]["matched_count"], 0)
        self.assertEqual(result["band_bounds"], [])


if __name__ == "__main__":
    unittest.main()
