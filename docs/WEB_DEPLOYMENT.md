# 가족역사 기록 도우미 — 웹 배포 기록

- 운영 대상: Android 앱 + PC·아이폰 공용 Flutter 웹앱.
- 웹 주소: https://family-history-record-helper.exquisitemica.chatgpt.site/
- 접근 범위: 소유자 본인 전용. ChatGPT 로그인 필요. 공개 배포로 변경하지 않았습니다.
- Sites project_id: `appgprj_6aed8d8501748191b800e62db2438eea`
- 배포 ID: `appgdep_6aed8e18f09c8191a1c6f93a30155677`
- 저장된 버전 ID: `appgprj_6aed8d8501748191b800e62db2438eea~appgver_e612549b4c888191a547efdc58cd80c5`
- 배포 결과: `succeeded` (게시 도구에서 확인).
- 원본 앱 커밋: `cdd520e07b4bb60a9be1a6a35ea067f95e982aaf`.
- 검증 빌드: GitHub Actions `42133454685`.
- 배포 소스 커밋: `99168f6bfaaa2461b728ef3c1d5aa72849852027` (Sites 배포 저장소).

## 확인 범위
미리보기 브라우저에서 기존 Flutter 첫 화면과 사진·PDF·카메라 입력 화면이 열리는 것을 확인했습니다. 게시 주소에서는 로그인 게이트를 확인했습니다. 로그인 이후의 실제 아이폰 Safari, 카메라, PDF, OCR, 저장 전 과정의 실기기 검증은 아직 완료되지 않았습니다.

웹앱의 인물과 이미지 데이터는 브라우저 로컬 저장소에 보관하며 기기 사이 자동 동기화가 아닙니다. 로컬 RapidOCR Python 서버는 PC 선택 기능이며, 아이폰에서는 기존 브라우저 OCR 경로를 사용합니다.

## 후속 업데이트
새 사이트를 만들지 말고 위 project_id로 get_site 및 기존 소스 저장소를 열어 같은 사이트에 게시합니다. 현재 접근 범위를 유지합니다. 원본 Flutter는 이 저장소 작업 브랜치에서 개발하고, 검증된 웹 빌드를 동일 사이트의 정적 파일로 배포합니다. 자격증명은 저장소에 기록하지 않습니다.
