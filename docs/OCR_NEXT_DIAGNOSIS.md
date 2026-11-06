# OCR follow-up from user device log — 2026-11-07

The user's v3.0.4 comparison text includes heading retries for rows 2 through 5, but none for rows 6 and 7.
The ten-retry budget was consumed by earlier headings, including page-title text (卷公源譜 / 卷之) and already readable names.
This is evidence of a retry-selection/budget distribution issue. It does not prove whether ML Kit can read the later headings after reflow.

Next OCR scope:
- Exclude book/page headers before spending name-retry budget.
- Prioritize structurally suspicious headings across the entire page, rather than exhausting retries in early rows.
- Retain every original reading and human review for conflicting names.
- Do not replace 全免傑, 賢東束 or other names with sample answers.

The v3.0.5 change is global app magnification only. It does not claim to fix these remaining OCR errors.
