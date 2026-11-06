# Android heading comparison OCR

The Chinese bundled ML Kit dependency remains 16.0.1, matching Google's current Android integration guide.
This change adds an image layout technique, not a new recognition model or an external API.

- Keep large glyphs upright and place them in one horizontal line.
- Exclude smaller printed Korean readings using relative run heights.
- Reject ambiguous, overlong, sparse or rule-like regions.
- Retry selected headings only, capped at ten additional Android recognitions per page.
- Preserve raw columns and primary names. Conflicting retry names go into the existing review alternatives UI.
- Alternative names never inherit birth, death, spouse or ancestry from the original candidate.
- No sample-specific substitutions such as 全→金 or 賢東束→賢東 are hardcoded.

## Validation boundary

Four manually cropped regions of the user's local page 224 were compared using the locally available RapidOCR recognizer (PP-OCRv6_rec_small) with identical recognition settings.
After reflow they returned 子賢東, 子顯五, 女權頭 and 女金免傑. The source crops and model binaries are not committed.
This is an exploratory local comparison on selected regions, NOT an Android ML Kit benchmark, a whole-page accuracy metric, or evidence that all missing people are recovered.
Synthetic Flutter tests cover glyph ordering/orientation, exclusion, rejection and non-destructive alternatives. Real-device ML Kit validation remains necessary.

## Verified public references

- Google Android ML Kit integration and input guidance: https://developers.google.com/ml-kit/vision/text-recognition/v2/android
- PaddleOCR PP-OCRv5 capabilities: https://github.com/PaddlePaddle/PaddleOCR/blob/main/docs/version3.x/algorithm/PP-OCRv5/PP-OCRv5.en.md
- PaddleOCR Apache-2.0 license: https://github.com/PaddlePaddle/PaddleOCR/blob/main/LICENSE
- The official Android demo currently documents PaddleLite 2.10 and a 2022 update: https://github.com/PaddlePaddle/PaddleOCR/blob/main/deploy/android_demo/README.md

PaddleOCR's newer text recognition models are not bundled into this APK. Their native runtime, model compatibility and device performance require separate validation.
