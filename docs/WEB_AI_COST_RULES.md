# WEB_AI_COST_RULES — genealogy project

## Invocation
On requests about family-search-helper, including "다음", read AGENTS.md and docs/CODEX_HANDOFF_20261024.md, then this file. Continue the existing task, never start from scratch.

## Flow
Request → identify target → check previous progress → inspect only related files → choose cheapest verified tool → minimal change → targeted tests → concise report.

## Safety
- Only branch work/jokbo-update-20261024; never change main without approval.
- Preserve original images/PDFs, OCR, reviewed people, relationships, database and existing features.
- Do not fabricate names, dates, sex, kinship or FamilySearch information.
- Before destructive changes, backup and obtain explicit approval.
- Keep OCR candidates distinct from verified genealogy facts; ambiguous sexagenary dates remain estimates with supporting reasoning.

## Token / credit limits
- No repetitive repository-wide scan; avoid node_modules, .git, generated outputs and verbose logs.
- Prefer local Git, shell scripts, existing OCR and deterministic validation before AI.
- Use verified free/local model only if actually available and safe for private data; never assume Codex usage can be replaced by a third-party API.
- Activate only necessary skills/MCP; no parallel agents by default.
- Work one scoped issue at a time; review diff; run focused regression tests and broader tests only when necessary.
- Stop on recurring failure, unexpected large changes, external payment, private data export or data-loss risk.

## Priorities
1. Wrong-person data contamination and OCR names.
2. Parent/spouse/child links, duplicate child backlinks, transaction safety.
3. Sexagenary-to-Gregorian year candidates, preserving uncertainty.
4. FamilySearch-compatible reviewed fields.
5. Accessible review UI: introduction → image/PDF/camera → analysis → edit → relationship review → save.

## Tools
- GitHub connector: remote file, branch, commit or PR operations only.
- Local scripts/CI: deterministic checks.
- Design reference tools: UI tasks only.
- Never claim a test passed without a recorded execution result.

## Report (short)
Changed files | commit SHA | executed tests and results | remaining issues | next step.
