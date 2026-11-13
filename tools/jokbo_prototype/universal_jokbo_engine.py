"""Conservative, provenance-preserving review layer for Korean genealogical records.

No names or sample-specific substitutions. This module does not perform OCR.
"""
from dataclasses import dataclass, asdict
import re
from typing import Optional

STEMS = "甲乙丙丁戊己庚辛壬癸"
BRANCHES = "子丑寅卯辰巳午未申酉戌亥"
GANJI = frozenset(STEMS[i % 10] + BRANCHES[i % 12] for i in range(60))
DIRECTIONS = frozenset("子丑寅卯辰巳午未申酉戌亥甲乙丙丁庚辛壬癸乾坤艮巽")
DATE_MARKERS = frozenset("生卒忌年")
GANJI_PAIR = re.compile(r"([甲乙丙丁戊己庚辛壬癸])\\s*([子丑寅卯辰巳午未申酉戌亥])")
DIRECTION = re.compile(r"([㐀-鿿])\\s*([坐向])")


@dataclass(frozen=True)
class Candidate:
    value: str
    score: float


@dataclass(frozen=True)
class ReviewTicket:
    field: str
    source_text: str
    proposed_value: str
    alternatives: tuple[str, ...]
    reason: str
    bbox: Optional[tuple[int, int, int, int]] = None
    confidence: Optional[float] = None

    def to_dict(self):
        return asdict(self)


def validate_context(text: str) -> list[ReviewTicket]:
    """Flag suspicious tokens, never rewrite historical source text."""
    tickets = []
    for match in GANJI_PAIR.finditer(text):
        pair = match.group(1) + match.group(2)
        nearby = text[max(0, match.start() - 2):match.end() + 4]
        if any(marker in nearby for marker in DATE_MARKERS) and pair not in GANJI:
            tickets.append(ReviewTicket(
                "date_ganji", match.group(), pair, (),
                "날짜 문맥에서 육십갑자에 없는 조합: 원문 대조 필요"))
    for match in DIRECTION.finditer(text):
        char = match.group(1)
        if char not in DIRECTIONS:
            tickets.append(ReviewTicket(
                "burial_direction", match.group(), match.group(), (),
                "좌향 표기에서 일반적인 24방위에 없는 글자: 복합 방위 또는 OCR 확인"))
    return tickets


def review_candidates(field: str, source_text: str,
                      candidates: list[Candidate],
                      bbox: Optional[tuple[int, int, int, int]] = None,
                      printed_reading: str = "",
                      dictionary_readings: tuple[str, ...] = (),
                      threshold: float = 0.88) -> list[ReviewTicket]:
    """Return unresolved review tasks; model scores are NOT calibrated probabilities."""
    if not candidates:
        return [ReviewTicket(field, source_text, "", (), "OCR 후보 없음", bbox)]
    ranked = sorted(candidates, key=lambda c: c.score, reverse=True)
    best = ranked[0]
    conflict = bool(printed_reading and dictionary_readings
                    and printed_reading not in dictionary_readings)
    low_score = best.score < threshold
    if not conflict and not low_score:
        return []
    reasons = []
    if conflict:
        reasons.append("원문 독음과 사전 독음 불일치; 어느 쪽도 자동 오기로 판정하지 않음")
    if low_score:
        reasons.append("OCR 모델 점수가 검수 기준 미만 (점수 보정 필요)")
    return [ReviewTicket(
        field, source_text, best.value,
        tuple(dict.fromkeys(c.value for c in ranked[1:4])),
        "; ".join(reasons), bbox, best.score)]


def analyze_transcript(raw: str) -> dict:
    """Non-destructive preliminary analysis of an OCR transcript."""
    return {"raw": raw, "review_tickets": [
        t.to_dict() for t in validate_context(raw)
    ], "verified": False}
