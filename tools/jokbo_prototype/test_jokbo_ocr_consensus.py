import unittest
from jokbo_ocr_consensus import han_sequences, candidate_support

class ConsensusTests(unittest.TestCase):
    def test_no_fabrication(self):
        self.assertEqual(candidate_support(['賢束','賢東'],2),[])
    def test_repeated_lines_not_multiple_votes(self):
        self.assertEqual(candidate_support(['賢東\n賢東'],2),[])
    def test_independent_runs(self):
        self.assertEqual(candidate_support(['賢東','賢東'],2),[{'text':'賢東','support':2}])
    def test_failed_ocr_excluded(self):
        self.assertEqual(candidate_support([{'raw':'賢東','error':'failed'},{'raw':'賢東','error':''}],2),[])
    def test_does_not_join_separate_lines(self):
        self.assertEqual(candidate_support(['賢\n東','賢\n東'],2),[])
    def test_non_han_removed(self):
        self.assertEqual(han_sequences('子 賢 東\n123 ABC\n'),['子賢東'])
    def test_no_empty_minimum(self):
        with self.assertRaises(ValueError): candidate_support(['賢東'],0)
    def test_same_job_not_double_count(self):
        self.assertEqual(candidate_support([{'job':[1,5],'raw':'賢東'},{'job':[1,5],'raw':'賢東'}],2),[])

if __name__=='__main__':
    unittest.main()
