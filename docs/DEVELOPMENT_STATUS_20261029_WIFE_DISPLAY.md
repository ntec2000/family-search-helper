# 2026-10-29 한글 배우자 성씨 표시 수정

- 기준 커밋: a9ac30456cf0b25d117b73e4a75bf2f386443d2f
- 작업 브랜치: work/jokbo-update-20261024
- 한글 배우자 입력 `파평 윤씨`를 `홍길동의 부인`으로 표시하던 문제를 재현하고 수정했다.
- 명시된 본관이 있으면 `파평윤씨`도 분리한다. 본관 근거 없이 붙여 쓴 긴 문자열은 분리하지 않는다.
- 표시명만 계산하며 원본 OCR, 배우자 원문, 본관, DB와 확정 관계를 변경하지 않는다.
- FamilySearch/GEDCOM 내보내기에서는 메모로 사용하며 아내 인물을 자동 생성하지 않는다.

## 실제 실행 검증

- 수정 전 독립 Dart 실행: `Expected 윤씨; actual 홍길동의 부인` 오류로 종료 코드 255.
- 수정 후 `dart tool/verify_wife_display.dart`: PASS: 15 checks, 종료 코드 0.
- `dart analyze lib/services/unknown_spouse_name.dart lib/services/familysearch_record.dart lib/services/gedcom_export.dart lib/models/person.dart`: No issues found!, 종료 코드 0.
- `git diff --check`: 종료 코드 0.
- Flutter 회귀 테스트 4개 추가. Flutter 테스트 실행은 미완료.
- Flutter 3.41.9 준비 중 의존성 처리 과정의 불필요한 클라우드 메타데이터 접근을 자동 승인 검토가 차단했다. 우회하지 않았다.
- `flutter analyze`, `flutter test`, APK 및 웹 빌드, 브라우저 UI 검증은 이번 작업에서 실행 완료하지 않았다.
- 기준 커밋에 대한 GitHub 조회에서 workflow_runs 및 combined statuses는 빈 배열이었다. CI 통과로 해석하지 않는다.

## 다음 작업

- Flutter 실행 가능한 환경에서 `flutter pub get`, `flutter analyze`, `flutter test`를 수행한다.
- 배우자 표시 규칙과 별도로 실제 OCR 자료를 대조하여 인물 간 정보 혼입 사례를 평가한다. 이번 수정으로 OCR 인식률 개선을 주장하지 않는다.
