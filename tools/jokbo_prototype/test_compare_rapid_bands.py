import unittest
from unittest.mock import patch
from PIL import Image
from compare_rapid_bands import candidate_coverage, compare, uncovered_ranges


class ComparisonTests(unittest.TestCase):
    def test_candidate_coverage_requires_exact_name_field(self):
        result = candidate_coverage(['子明\n子明\n女和'], ['明', '和'])
        self.assertEqual(result['matched_names'], ['明'])
        self.assertEqual(result['unmatched_names'], ['和'])
        self.assertEqual(result['candidate_count'], 3)

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
        self.assertEqual(result["uncovered_rows"], [])

    def test_no_detected_bands_is_not_success(self):
        with patch("compare_rapid_bands.detect_bands", return_value=[]):
            result = compare(Image.new("RGB", (20, 20)), ["甲"], lambda _: "甲")
        self.assertEqual(result["segmented"]["matched_count"], 0)
        self.assertEqual(result["band_bounds"], [])
        self.assertEqual(result["uncovered_rows"], [(0, 20)])

    def test_uncovered_edges_and_gaps(self):
        self.assertEqual(uncovered_ranges(100, [(10, 40), (41, 80)]),
                         [(0, 10), (40, 41), (80, 100)])

    def test_uncovered_text_is_kept_separate_from_band_results(self):
        outputs = iter(["甲", "甲", "乙"])
        with patch("compare_rapid_bands.detect_bands", return_value=[(0, 80)]):
            result = compare(Image.new("RGB", (30, 100)), ["甲", "乙"], lambda _: next(outputs))
        self.assertEqual(result["segmented"]["matched_names"], ["甲"])
        self.assertEqual(result["uncovered_review"]["matched_names"], ["乙"])
        self.assertEqual(result["reviewed_uncovered_rows"], [(80, 100)])

    def test_overlaps_and_invalid_coordinates(self):
        self.assertEqual(uncovered_ranges(100, [(40, 80), (0, 50)]), [(80, 100)])
        for bands in [[(-1, 20)], [(50, 50)], [(90, 101)]]:
            with self.subTest(bands=bands), self.assertRaises(ValueError):
                uncovered_ranges(100, bands)


if __name__ == "__main__":
    unittest.main()
