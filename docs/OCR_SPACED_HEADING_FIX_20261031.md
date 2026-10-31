# OCR 좌향 표제 경계 수정 (2026-10-31)

## 기준과 변경

- 원격 기준: b5e74aff0bb75cff5df1e7d819d3aeee803deb61.
- 기존 로컬 c439c59는 backup/local-wife-display-c439c59 태그로 보존했다.
- 이미 원격에 반영된 배우자 성씨 코드는 최신 버전을 유지했다. 독립 Dart 검사와 이전 검증 기록만 26c838b로 보존했다.
- 열 조합 및 인물 분리 정규식이 子 뒤의 공백보다 앞에서 좌향 제외 조건을 검사하여 `子 坐午向`을 별도 인물로 분리할 수 있었다.
- 제외 조건을 공백 뒤에 검사하도록 정규식 두 곳만 변경했다. 명시적인 이미지 표제 경계는 기존 동작을 유지한다.
- 원본 이미지/PDF, 원문, DB, 확정 관계는 변경하지 않았다.

## 실제 실행

- 수정 전 `dart tool/verify_ocr_spaced_heading.dart`: exit 255. `子 坐午向`이 세 번째 구획을 만드는 문제를 재현했다.
- 수정 후 같은 명령: `PASS: 12 checks`, exit 0. 공백 없음/공백/탭의 좌향, 배우자 주석 유지, 다음 인물 분리, 입력 배열 보존을 확인했다.
- `dart tool/verify_wife_display.dart`: `PASS: 15 checks`, exit 0.
- `dart analyze lib/services/ocr_column_text.dart`: `No issues found!`, exit 0.
- `git diff --check`: exit 0.
- Dart SDK 3.11.5를 독립 실행했다. Flutter 초기화나 메타데이터 접근은 시도하지 않았다.

## 미실행과 범위 제한

- `test/ocr_spaced_heading_test.dart`에 열 조합 및 파서 통합 회귀 테스트 2개를 추가했으나 Flutter가 없어 실행하지 않았다.
- 따라서 파서 통합 테스트, 전체 Flutter 분석/테스트, APK/웹 빌드, 실제 OCR 이미지·모바일 UI는 검증하지 않았다.
- 이 검사는 입력 텍스트 경계 처리 검증이며 OCR 문자 인식률 개선의 증거가 아니다.
- 이번 새 수정은 로컬 커밋이며 GitHub 게시는 아직 수행하지 않았다.
