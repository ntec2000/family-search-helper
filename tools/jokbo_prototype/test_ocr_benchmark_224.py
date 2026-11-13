import unittest
from ocr_benchmark_224 import evaluate


class BenchmarkTests(unittest.TestCase):
    def test_no_ground_truth_injection(self):
        self.assertEqual(evaluate(['聖皿'], ['聖甲'])['matched_count'], 0)

    def test_combination_and_denominator(self):
        result = evaluate(['聖甲', '顯 五'], ['聖甲', '顯五', '炳吉'])
        self.assertEqual(result['matched_count'], 2)
        self.assertAlmostEqual(result['exact_name_recall'], 2 / 3)

    def test_empty_gold(self):
        self.assertIsNone(evaluate(['anything'], [])['exact_name_recall'])


if __name__ == '__main__':
    unittest.main()
