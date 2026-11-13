# Universal Jokbo review engine — phase 1

This is an additive, non-destructive Python review module. It is not wired into the Flutter UI or OCR HTTP endpoint yet.

- Original OCR text is preserved verbatim.
- Invalid date-context sexagenary pairs and unusual burial-direction glyphs generate review tickets, not silent corrections.
- OCR candidate scores are treated as uncalibrated model scores.
- Conflicting printed readings are not declared typographical errors.
- No person names, clan names, or sample-image substitutions are embedded.
- Review tickets are proposals only; `verified` remains false.
- Tests: `cd tools/jokbo_prototype && python -m unittest test_universal_jokbo_engine.py`

Next: inspect existing OCR output schemas, add glyph bounding boxes and candidate distributions, then integrate review UI without changing original Person records. Evaluate on independently transcribed documents before reporting CER, extraction F1, or review coverage.
