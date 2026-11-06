# OCR device-log diagnosis and scheduling fix — 2026-11-07

The user supplied a device OCR log. All ten heading retries occurred in rows 2–5, including book/page titles (卷公源譜 / 卷之) and already readable names. Rows 6–7 had no heading retry.

## v3.0.6 fix

- Remove obvious book/page/generation labels before assigning retry priority.
- Strip only leading OCR punctuation for selection, retaining the original column.
- Interpret ordinal prefixes when ranking, without changing recognized names.
- Prioritize missing and structurally suspicious headings within each row.
- Reserve budget for later rows and cap each row at three attempts.
- Keep the total Android retry cap at ten; preserve existing Web behavior.
- Retain original readings and expose conflicting names through human review.

A synthetic seven-row fixture shaped like the device log verifies that rows 6 and 7 receive attempts and total attempts remain ten.
This verifies scheduling, not Android character-recognition accuracy. No sample-specific name replacement is implemented.
Unknown life events and relationships remain subject to source review.
