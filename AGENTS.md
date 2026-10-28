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

## Web / mobile AI token-saving workflow
- For this project, including follow-up requests like '다음', read [docs/WEB_AI_COST_RULES.md](docs/WEB_AI_COST_RULES.md) and apply it before modifying files.
- Prefer scoped file reads, verified free/local tools where available, minimal diffs, targeted tests and concise status reports.
- Do not assume external free API calls reduce Codex subscription usage; obtain approval for paid API calls or private-data transmission.

## Consolidated prompt auto-invocation
- On EVERY task, including short follow-ups, read [docs/AI_WORKFLOW_MASTER.md](docs/AI_WORKFLOW_MASTER.md) and apply the relevant project-specific and shared prompts. This rule supplements, not replaces, the existing handoff and cost rules.
- Reuse unchanged context; do not repeatedly reload long prompts in a single task. Record and use progress between sessions.

## Mandatory genealogy development rules (2026-10-29)
Apply on every genealogy task, including a follow-up saying "다음". This section supplements the existing handoff, cost, and master workflow documents.

### Work sequence
1. Confirm the active branch, repository structure, completed work, and latest CI state; avoid duplicate implementation.
2. Analyze the defect and write a minimal, reversible change plan.
3. Preserve the original images/PDFs, raw OCR, confirmed records, and existing database; request approval before destructive changes, migrations, or merges.
4. Make scoped code changes and add focused regression tests.
5. Run available automated tests and inspect GitHub Actions; verify desktop/mobile browser UI and storage/recovery only when an actual execution environment is available.
6. Report changed files, commit SHA, actual test results, unresolved issues, and next step. Never report unexecuted checks as passed.

### Genealogy and OCR correctness
- Prefer accurate person boundaries to maximizing detected Han-character count. Keep raw OCR and corrected values distinct.
- Distinguish personal name, 字, 號, spouse, father, mother, children, birth, death, burial, and adoption; do not attach a neighboring person's facts to the current person.
- Treat spouse-side 父/祖/曾祖/外祖 as spouse ancestry when in a spouse block. Do not invent unnamed daughters' given names or infer kinship from layout alone.
- Distinguish 世, 世孫, generation order, and generation-name characters; do not infer a Gregorian birth year from generation number alone without an anchored historical reference.
- Convert sexagenary dates using verified calendrical logic. When multiple Gregorian years fit, present candidates and request review rather than arbitrarily choosing one. For supported approximate years display "약 YYYY년 (about YYYY)" with source, reasoning, and confidence; preserve the original date.
- Map verified facts to FamilySearch-oriented name, birth, death, parents, spouse, and children. Check official FamilySearch formats and integration permissions before implementing any live sync.

### UX and QA
- Preserve current brand and flow: 소개 → 이미지·PDF·카메라 입력 → OCR 분석 → 인물별 내용 수정 → 가족관계 검토 → 검토 완료 → 인물 저장.
- Prioritize legible Korean/Hanja, accessible touch targets, clear guidance for older users, and real functional screens; avoid generic purple gradients, excessive emoji, and overly rounded cards.
- Research available Awwwards, Dribbble, GDWeb, and Mobbin references when doing design work; do not copy copyrighted layouts or imply inaccessible references were reviewed.
- Compare OCR output against source images when available; test cross-person contamination, relationship logic, calendar ambiguity, and save/edit/restore behavior.
- Use only the relevant verified-creative-workbench skills and actually connected tools; do not assume plugins or local environments are available.
