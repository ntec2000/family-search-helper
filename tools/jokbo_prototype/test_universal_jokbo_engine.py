import unittest
from universal_jokbo_engine import (
    Candidate, GANJI, analyze_transcript, review_candidates, validate_context
)


class UniversalReviewTests(unittest.TestCase):
    def test_sixty_cycle(self):
        self.assertEqual(len(GANJI), 60)

    def test_invalid_date_flagged_not_rewritten(self):
        raw = "申亥年生"
        result = analyze_transcript(raw)
        self.assertEqual(result["raw"], raw)
        self.assertTrue(result["review_tickets"])

    def test_valid_date(self):
        self.assertFalse(validate_context("庚申年生"))

    def test_no_unconditional_direction_replacement(self):
        self.assertTrue(validate_context("明坐合窆"))

    def test_reading_conflict_requires_review(self):
        tickets = review_candidates("name", "원문", [Candidate("甲", .96)],
                                   printed_reading="가", dictionary_readings=("갑",))
        self.assertEqual(len(tickets), 1)
        self.assertEqual(tickets[0].proposed_value, "甲")

    def test_alternatives_preserved(self):
        items = [Candidate(str(i), .8 - i * .1) for i in range(5)]
        self.assertEqual(len(review_candidates("name", "", items)[0].alternatives), 3)

    def test_no_candidate(self):
        self.assertEqual(review_candidates("name", "", [])[0].reason, "OCR 후보 없음")


if __name__ == "__main__":
    unittest.main()
