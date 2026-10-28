# AI_WORKFLOW_MASTER — consolidated instructions

This file consolidates the previously agreed prompts for Codex/web development. Apply on EVERY request about this repository, including short follow-ups ("다음"). Do not reload the entire file repeatedly within the same task if unchanged.

## Trigger / flow
User request → identify project and task → read AGENTS.md, handoff and progress → select only relevant skill/tool/model → inspect relevant files → small plan → minimal patch → targeted tests → brief report → update progress.

## Global instructions
- Preserve original files, databases, images, PDFs, OCR text, links, business facts and existing working behavior. No invented facts, names, relationships, dates, metrics, ratings or tests.
- Back up before destructive edits; do not modify main. User approval required for risky scope changes, paid API use or sending private data to external services.
- Reuse previous decisions and work; no redundant repository-wide analysis, full-file dumps, repeated logs or needless multi-agent runs.
- Use cheapest verified execution: local Git/shell/test/OCR/deterministic rules first; proven free/local models next; paid Codex only when complexity warrants. An external free API does NOT automatically replace Codex's billed usage.
- Check available skills and MCP without loading everything. GitHub for remote operations; browser for actual UI QA; design references only for design; image/video tools only for requested creative assets.
- Use existing verified-creative-workbench skills selectively: coding/planning, OCR/validation, UI/UX, website-human-polish, web-design-reference-research, frontend design, code review. Plugin skills are guidance unless executable tools are actually connected.
- Stop and report repeated failure, unexpected mass changes, data risk, unapproved cost or missing access.

## Genealogy app specialization
- Project: ntec2000/family-search-helper, branch work/jokbo-update-20261024.
- Priority: wrong-person OCR contamination → Hanja name accuracy → parent/spouse/child relations and duplicate backlinks → DB transaction safety → sexagenary date candidate conversions → FamilySearch-compatible verified fields → accessible UI.
- Flow: introduction → image/PDF/camera input → OCR analysis → edit → family relationship review → reviewed save.
- Preserve uncertainty: distinguish candidates from human-confirmed data; Gregorian years are estimates when evidence is insufficient.
- Run focused tests first; flutter analyze/test/build as relevant and available; report exact commands and results.

## Website/KAKABA instructions (only when working on that project)
- Preserve HTML/CSS/JS, brand, logo, navigation, voice, app screenshots, language switching, STEP animations, discount/delivery terms, and existing links.
- Improve accessibility, Korean readability, senior usability, responsive layout, real-app visual fidelity. Avoid generic purple gradients, fake reviews, excess emojis, gratuitous cards.
- Reference Awwwards for motion, Dribbble for UI detail, GDWeb for Korean layouts, Mobbin for app patterns only when needed; do not copy designs or browse repeatedly.
- Minimal HTML/CSS patch → syntax check → page-specific desktop/mobile/browser tests, plus regression checks for logo navigation, images, voice, translations, animations, order guide, discounts.

## Translation / image / video / slides tasks (when explicitly requested)
- Translation: faithful to source, terminology consistency, no omissions; LDS scriptures use official Korean wording, never invented translations.
- Images: source-faithful, high-quality and distinguish AI reproductions from authentic works; only generate when user requests.
- Video: storyboard, scene prompts, sound/subtitles, factual fidelity; never claim render or QA without execution; Genie access only if confirmed.
- PPT: evidence-based, editable PPTX, optional PDF proof, no fabricated financial or exhibition data; verify visual output.

## Cost reporting
Keep response concise: target | changed files | tool/model actually used | tests actually executed | blockers | next action. No false claim of savings without measured baseline.
