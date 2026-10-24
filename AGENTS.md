# Codex repository instructions

Read [docs/CODEX_HANDOFF_20261024.md](docs/CODEX_HANDOFF_20261024.md) before editing this project.

## Scope and safety
- Flutter genealogy OCR review app. Preserve original source images and OCR text.
- Never invent names, kinship, dates, genders, adoption, or genealogy facts.
- Keep candidate recognition separate from human-confirmed relationships.
- Work only on `work/jokbo-update-20261024`; do not edit or merge `main` without explicit user approval.
- Do not silently delete or overwrite reviewed relationships.
- Commit small, verifiable changes and report exact command outputs; never claim tests or APK builds passed unless executed.

## Immediate priorities
1. Run `flutter pub get`, `flutter analyze`, and `flutter test`; investigate failures.
2. Validate duplicate child IDs and correct father/mother gender, including tests. Check current implementation before modifying: these were added in commits `48f3a5e`, `2989c90`, with tests.
3. Fix `ParentChildReview.unlink` to remove all duplicate child backlinks, with a regression test.
4. Inspect DB save transaction behavior to prevent partial writes.
5. Run `flutter build apk --debug` where Android tooling is available.
6. Provide Korean status updates listing changed files, commit SHAs, test results and blockers.

Current development branch and additional history are documented in the handoff file.