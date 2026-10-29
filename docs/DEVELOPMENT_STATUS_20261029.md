# 2026-10-29 후속 작업: 한글 배우자 성씨 표시

- 기준 브랜치: work/jokbo-update-20261024, 시작 커밋 a9ac304.
- 기준 커밋의 Flutter validation 실행 40881543196은 success로 확인했다. 이는 이번 수정의 검증 결과가 아니다.
- 기존 함수는 `파평 윤씨`를 `홍길동의 부인`으로 표시했다. 실제 production Dart 함수 호출로 수정 전 실패를 확인했다.
- 명시된 본관 필드 또는 공백으로 구분된 한글 본관을 제거하여 `윤씨`를 표시한다. 복성은 유지한다.
- 본관 필드도 공백도 없는 모호한 붙여쓰기는 새로 해석하지 않는다.
- 원문과 저장 필드는 수정하지 않으며 FamilySearch/GEDCOM에서 표시명을 새 인물 이름으로 만들지 않는다.

## 실행 검증

- 캐시 Dart SDK로 실제 production 함수, 원문 보존, 확정 이름 우선, 복성, 모호한 입력, 내보내기를 검사했다: `PASS: 18 assertions (actual production Dart code)`.
- 수정 전 재현: `expected 윤씨; actual 홍길동의 부인` (exit 255). 수정 후 동일 재현: `PASS` (exit 0).
- `dart analyze lib/services/unknown_spouse_name.dart lib/services/familysearch_record.dart lib/services/gedcom_export.dart`: `No issues found!`.
- `git diff --check`: exit 0.
- Flutter 전용 회귀 테스트 4개 추가. Flutter SDK는 PATH에 없고, /tmp/jokbo-flutter의 도구 초기화를 시도했다. 전체 Flutter 분석/테스트, APK, 브라우저 UI는 이 기록 시점 미실행. 새 커밋의 GitHub Actions 결과는 별도로 확인해야 한다.

## 다음 작업

- 새 커밋의 CI 결과 확인 후 한자 복성 및 알려진 성씨 외의 표시 처리를 별도 이슈로 점검한다.
- 원본 샘플을 확보하면 OCR 인물 경계와 이름 정확도를 원문에 대조한다. 이번 변경은 OCR 엔진 정확도 개선을 의미하지 않는다.
