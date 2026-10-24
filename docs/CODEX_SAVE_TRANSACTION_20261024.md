# 저장 트랜잭션 연결 — 2026-10-24

- 기준 커밋: `5c4e0d9` (개발 브랜치).
- `result_screen.dart`의 개별 저장 반복문을 기존 `upsertPersonsAtomically` 호출로 교체했다. 기존 검증, 저장 확인, 중복 실행 방지, 실패 안내는 유지했다.
- `test/db_service_test.dart`: SQLite FFI로 가족관계·OCR 원문 저장과 중간 실패 롤백을 검증하는 테스트 2개를 추가했다. 실패 테스트는 SQLite 트리거로 세 번째 삽입을 거부하며 앞선 기존 레코드 수정과 신규 삽입까지 취소되는지 확인한다. 임시 디렉터리만 사용한다.
- 테스트용 개발 의존성 `sqflite_common_ffi`를 추가했다. 앱의 저장 엔진과 데이터 스키마는 변경하지 않았다.

## 실제 확인 결과

- `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`: 모두 `The term 'flutter' is not recognized`로 시작하지 못했다. 의존성 해결, 테스트 통과, APK 생성은 확인되지 않았다.
- `git diff --check`: 종료 코드 0.
- 개발 브랜치에서 중복 자녀 ID 검증, 부모 성별 검증, `unlink`의 `removeWhere` 및 관련 기존 테스트를 확인했다. 해당 기능을 다시 구현하지 않았다.
- 별도 작업 폴더에서 작업했으며 원래 main 체크아웃의 파서·테스트 미커밋 변경은 건드리지 않았다.

## 다음 실행

Flutter SDK가 있는 환경에서 `flutter pub get`, `flutter analyze`, `flutter test`를 실행한다. SQLite FFI 런타임 문제를 포함한 실제 오류를 해결한 뒤 Android SDK 환경에서 `flutter build apk --debug`를 실행한다. 저장 화면의 성공·실패 안내와 재시도는 기기에서 별도 검증이 필요하다.
