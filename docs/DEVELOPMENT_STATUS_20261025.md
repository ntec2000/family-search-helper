# 2026-10-25 개발 검증 기록

기존 work/jokbo-update-20261024 작업과 미추적 파일을 보존하여 이어서 구현했다.
원격 브랜치는 1b75557이며 사위 정규식 수정 cc255e9 이후 로컬에서만 작업했다.
파서 경계 수정은 4c6e91d에 기록했다. GitHub 게시 및 웹 배포는 하지 않았다.
루트 main의 기존 수정 파일 2개는 시작 시 SHA256과 종료 시 SHA256이 일치한다.

## 구현 범위 (B: 코드 검토)

- 이미지·PDF 페이지·카메라 입력부터 시작하며 성씨 사전 입력을 제거했다.
- 분석 → 인물 내용 수정/추가/제외/복원 → 관계 검토 → 최종 저장 흐름이다.
- 원본 이미지/PDF, 페이지 번호, OCR 원문, 사용자 수정과 확인한 관계를 보존한다.
- 성/이름, 한글/한자, 본관, 자, 배우자와 처가, 간지와 출계를 별도 필드 또는 원문 메모로 보존한다.
- FamilySearch 자료 JSON과 GEDCOM을 내려받는다. 직접 전송은 기존 로그인 흐름을 유지한다.
- 브라우저 IndexedDB 저장과 CJK 글꼴을 추가했다. DB v8 업그레이드는 기존 자료를 유지한다.
- OCR은 구획/열 분리와 세로 한자 모델을 사용하며 이미지 자체를 외부 API로 전송하지 않는다.
  첫 웹 실행에는 공개 CDN의 엔진/보조 모델/PDF 라이브러리 다운로드가 필요하다.

## 실행 검증 (A)

Flutter 3.41.9 / Dart 3.11.5 / JDK 17.0.20.1+1.

- `flutter analyze`: No issues found.
- `flutter test --reporter expanded`: 기본 전체 테스트 89개 통과.
- 실제 사진 경로를 JOKBO_SAMPLE, 저장된 실제 OCR 결과를 OCR_RESULTS로 지정하여
  `flutter test test/actual_ocr_evaluation_test.dart test/ocr_regions_test.dart`: 5개 통과.
  기본 테스트와 중복되는 검사가 있으므로 두 개수를 합산하지 않는다.
- `flutter build web --no-pub --release --no-wasm-dry-run --no-web-resources-cdn`: 성공.
- `flutter build apk --debug --no-pub`: 성공. Windows 한글 경로 도구 문제를 피하기 위해
  현재 소스 스냅샷을 C:\tmp\jokbo-resume-20261025-verified에 복사하여 빌드했다.
  원래 작업 트리를 새 프로젝트로 대체하지 않았다.
- `apksigner verify --verbose`: v2 서명 검증 성공.
- Chrome: 실제 사진 OCR → 검토, PDF 2쪽 → 수정 → 제외/복원 → 관계 검토 → 저장 →
  재시작 유지 → JSON/GEDCOM 다운로드와 이름/페이지 출처 검사 성공, pageerror 없음.
- Chrome 390x844 화면 검사도 별도 실행한다. 이 검사는 iOS 네이티브 검증이 아니다.

## 실제 OCR 결과와 남은 오류

사용자 제공 224쪽 사진을 실제로 처리했다. 7개 구획 검출은 이름 인식 성공을 뜻하지 않는다.
기존 구획 OCR 원문에는 기준 이름 문자열 17개 중 4개가 있었고,
열 분리 + tessdata_best 세로 한자 모델의 원문에는 10개가 있었다.
이 수치는 전체 문자 정확도나 인물 추출 정확도가 아니다.
구조화된 인물 후보는 3개이며 정확한 이름은 格 1개였다. 李集一, 媽吉 등의 오독이 남는다.
사용자 정답을 운영 코드에 넣지 않았으며 기준 이름은 평가 테스트에만 존재한다.
현재 결과는 원문 대조와 수동 수정/추가가 필요하다. 자동 족보 복원 완료로 판단하면 안 된다.

## 산출물과 실행 로그

도구/산출물 폴더:
`C:\Users\phfoo\Documents\Codex\2026-10-25\family-search-helper-work-jokbo-update\artifacts`

- family-search-helper-resume-debug.apk (debug 서명, 223395778 bytes)
- SHA256: E75772BAEBB1F3CB8A7C677E96DC23ACF5BC4E1F94516048A5B4335F23F82694
- final-analyze.txt / final-tests.txt / final-actual-tests.txt
- final-android-build.txt / final-web-build.txt / final-apk-signature.txt
- final-browser-flow.txt / final-mobile-layout.txt
- ocr-regions-columnsbest.json.evaluation.json (원문과 구조화 결과를 분리한 평가)
- resume-export.json / resume-export.ged / resume-*.png (로컬 검증용, 비공개)

## 미검증 (C)

실제 Android 기기, iPhone/Safari/Mac 실기기, 네이티브 iOS 앱,
FamilySearch 실계정 전송, 배포/오프라인 최초 실행은 검증하지 않았다.
다음 우선 작업은 잘못 읽힌 子/女 표제와 열 위치를 결합하여 인물 경계를 복원하고,
이 샘플 이외의 대표 사진에서도 이름과 관계를 각각 평가하는 것이다.
