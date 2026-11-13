import unittest
from ocr_consensus_audit import audit


class AuditTests(unittest.TestCase):
    def test_repeated_same_language_not_cross_engine(self):
        self.assertEqual(audit([{'job':[0,5,'HanT_vert'],'raw':'賢東'}, {'job':[0,6,'HanT_vert'],'raw':'賢東'}]), [])

    def test_two_languages(self):
        self.assertEqual(audit([{'job':[0,5,'HanT_vert'],'raw':'賢東'}, {'job':[0,5,'HanS_vert'],'raw':'賢東'}])[0]['text'], '賢東')

    def test_bad_result_excluded(self):
        self.assertEqual(audit([{'job':[0,5,'HanT_vert'],'raw':'賢東','ok':False}, {'job':[0,5,'HanS_vert'],'raw':'賢東'}]), [])

    def test_no_fabricated_character(self):
        self.assertEqual(audit([{'job':[0,5,'HanT_vert'],'raw':'賢束'}, {'job':[0,5,'HanS_vert'],'raw':'賢東'}]), [])

    def test_duplicate_job_not_double_count(self):
        self.assertEqual(audit([{'job':[0,5,'HanT_vert'],'raw':'賢東'}, {'job':[0,5,'HanT_vert'],'raw':'賢東'}, {'job':[0,5,'HanS_vert'],'raw':'賢東'}])[0]['config_count'], 2)

    def test_separate_lines_not_joined(self):
        self.assertEqual(audit([{'job':[0,5,'HanT_vert'],'raw':'賢\n東'}, {'job':[0,5,'HanS_vert'],'raw':'賢\n東'}]), [])


if __name__ == '__main__':
    unittest.main()
