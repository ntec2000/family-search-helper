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

## 사용자 요청: 공통 실행 원칙
- 이어서 작업할 때 최신 작업 브랜치와 검증 상태를 먼저 확인하고, 이미 구현된 내용과 관련 파일만 살펴 중복 분석을 줄인다.
- 샘플의 사용자 해석과 원문 판독이 충돌하면 두 내용을 구분하여 보존하고, 날짜·이름·관계는 자동 확정하지 않는다.
- 변경은 작은 단위로 수행하며 원본 이미지·OCR·기존 확정 데이터 및 개인정보를 보존한다. 테스트와 빌드 결과는 실제 확인된 범위만 보고한다.

## 모델·도구 및 검증 효율 원칙
- 모델 선택은 사용자 계정의 선택 화면에서 가능한 항목에 한한다. 에이전트가 모델을 자동 전환하거나 비용 절감을 보장한다고 주장하지 않는다.
- 명확한 범위의 반복 작업은 사용 가능한 경량 모델을 고려하고, 족보 관계·OCR 오류·데이터 보존·FamilySearch 설계처럼 판단과 검증이 중요한 작업은 충분한 성능의 모델을 사용한다. 추론 수준은 기본값에서 시작해 필요할 때만 높인다.
- 일반적인 작업에서는 Standard 속도를 우선하고, Fast·Max·Ultra·병렬 에이전트는 실제 필요와 사용 권한을 확인한 경우에만 쓴다. 사용자 지시가 우선한다.
- 각 작업은 현재 브랜치·관련 변경·마지막 검증을 확인한 뒤 관련 파일만 검색하고, 변경과 회귀 테스트를 하나의 검증 가능한 단위로 묶는다. 진행 중인 유효한 CI를 불필요한 연속 커밋으로 취소하지 않는다.
- 반복 가능한 검색·계산·검증은 우선 로컬 도구나 기존 테스트를 사용한다. 실제 족보 이미지와 개인정보를 허가 없이 외부 API·공개 저장소에 전송하지 않는다.
- 관련 스킬은 필요한 경우에만 지침을 한 번 읽어 사용하고, GitHub는 저장소 작업, OCR 로컬 도구는 실측, 디자인 도구는 디자인 작업에 한정한다. 플러그인 자체가 토큰 사용을 없애거나 비용을 절감한다고 보장하지 않는다.
- 품질·보존·회귀 테스트를 생략해 토큰을 줄이지 않는다. 실행한 테스트와 미실행 검증, 실제 커밋 및 제한 사항을 구분해 보고한다.
- 비용·모델 가용성·사용량은 사용자 환경과 시점에 따라 달라진다. [OpenAI 모델 안내](https://learn.chatgpt.com/docs/models)와 [Work·Codex 요금 안내](https://learn.chatgpt.com/docs/pricing)를 필요할 때 확인한다.
