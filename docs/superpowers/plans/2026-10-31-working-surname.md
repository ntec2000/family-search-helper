# Working Surname Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Native execution; no parallel agents.

**Goal:** 작업 성씨를 먼저 확인하고 본손·딸·아내·사위 부친 이름 규칙을 신규 분석에 적용한다.
**Architecture:** 기존 성씨 입력창과 CaptureScreen에 작업 성씨 상태를 연결한다. 파서는 수동 우선 성씨를 전파하고 쪽 단위 딸 순번을 부여한다. 표시 도구는 사위 부친의 성씨 조합 후보와 원문을 구분한다.
**Tech Stack:** Flutter/Dart, 기존 한자 사전, GitHub Actions.
**Spec:** docs/superpowers/specs/2026-10-31-working-surname-design.md

## Global Constraints
- work/jokbo-update-20261024에서만 작업하며 원본·DB·확정 관계를 보존한다.
- 외부 유료 API, 새 DB 스키마, 개인 이미지 공개 게시를 사용하지 않는다.
- 한글 입력만으로 제출 가능하며 미확인 성씨 한자는 만들지 않는다.

## Review Focus
- 이/김/최와 이씨 입력 정규화, 성이 아닌 긴 문자열 거부.
- 수동 한글 성과 자동 감지 한자 성 충돌 방지.
- OCR 표제 공백과 상충 문중 표제의 확인 처리.
- 구획 간 딸 순번 유지 및 원문 명시 서수 보존.
- 본손과 사위/아내/처가 성씨 분리, 원문과 조합 후보 구분.

### Task 1: 입력·파서·표시 규칙을 하나의 분석 흐름으로 구현
**Files:** surname_input_dialog.dart, capture_screen.dart, surname_review.dart, jokbo_parser.dart, genealogy.dart, family_name_candidates.dart, spouse_parent_text.dart 및 해당 test 파일.
**Interfaces:** 기존 showSurnameInputDialog에 분석 목적·초깃값 옵션 추가. JokboParser.detectWorkingSurname(Iterable<String>)로 표제 후보를 제공한다. SpouseParentText.candidateFatherName(Person)로 원문을 변경하지 않는 조합 후보를 반환한다.
- [ ] 기존 API 기반 회귀 테스트로 성씨 혼합, 딸 순번, 사위 부친 누락, 입력 접미사 문제를 재현한다.
- [ ] 수동 입력과 표제 감지, 성씨 전파, 표시 규칙을 최소 변경으로 구현한다.
- [ ] CaptureScreen의 분석 전 확인과 사전 성씨 입력, 취소 및 한글만 제출을 위젯 테스트한다.
- [ ] 전체 Flutter 분석/테스트 및 웹 빌드의 실제 CI 결과를 확인한다. Android 빌드는 별도 상태로 보고한다.
- [ ] 변경 파일·커밋·실행 결과·미검증 범위를 한국어로 보고한다.
