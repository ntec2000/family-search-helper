# Changelog · 개발 히스토리

> **개발자**: Peter S. Choi
> **문의**: ntec21c@gmail.com

## 3.0.2+20 (2026-10-24) — 개발 변경, 배포 검증 대기

- GitHub 검증에서 확인한 내보내기 화면의 중복 코드·정규식 오류와 결과 화면의 가변 글자 크기 const 오류 수정.
- 정적 분석 경고 정리. 기기 OCR 정확도 및 APK 배포 완료 여부는 별도 확인 대상.
- GitHub에서 정적 분석 통과 확인. 날짜의 연·월·일 사이 공백 처리 보완 및 순서 미상 안전 규칙과 오래된 테스트의 불일치 수정.
- 검증 워크플로의 Flutter 버전을 기존 APK 워크플로와 동일한 3.41.9로 고정해 최신 버전 자동 변경에 따른 Gradle 충돌 방지.
- 원본·전처리 이미지 OCR 비교 및 실패 시 대체 입력 결과 사용.
- 영문 잡음·공백보다 한자 검출 수를 우선하고 호환 한자 포함. 검출량은 정확도 점수가 아니며 원문 대조 필요.
- 간지·날짜 공백 인식 보완, 촬영 원본 경로 보존, 인물 아닌 후보 제외 메뉴 안내 개선.
- 검토 인물 일괄 저장을 SQLite 트랜잭션으로 처리해 부분 저장 방지.
- 앱 정보의 버전별 히스토리, 다운로드·저장소 링크 복사 및 공유 추가.
- OCR 후보 선택 회귀 테스트 3개 추가. 커밋 08b00f8의 GitHub 정적 분석 및 자동 테스트 61개 통과 확인.
- APK 빌드 환경에 Android SDK 36 및 Flutter 3.41.9·JNI 모듈이 사용하는 NDK 28.2.13676358 설치 단계 추가. 앱·검증·릴리스 빌드의 NDK 버전 통일. 실제 기기 OCR 검증·APK 배포는 미완료.

다운로드: [GitHub Releases](https://github.com/ntec2000/family-search-helper/releases)
— 게시된 릴리스의 Assets에서 APK를 받습니다. 3.0.2 APK 게시 여부는 별도 확인이 필요합니다.

소스: [GitHub 저장소](https://github.com/ntec2000/family-search-helper),
[개발 브랜치](https://github.com/ntec2000/family-search-helper/tree/work/jokbo-update-20261024).

## 1.0.0 (2026-06-01) — 첫 릴리즈

### ✨ 신규 기능
- 카메라/갤러리에서 족보 이미지 입력
- Google ML Kit Chinese OCR (온디바이스, 무료)
- 족보 표준 표기 파서: 子/女/字/號/配/墓/生/卒
- 한자→한글 음 사전 8,528자 내장 (Unicode Unihan + 보강)
- 만세력 양력↔음력 + 干支(간지)→연도 추정 (1700-2100)
- 인물 카드 (FamilySearch 호환 항목)
- 가계도(家系圖) 세(世)별 시각화
- OCR 후보 한자 수정 위젯 (己/已/巳 등 혼동 한자 대안)
- SQLite 로컬 영속화 (모든 데이터 기기 내부 저장)
- GEDCOM 5.5.1 내보내기 (FamilySearch · Ancestry · MyHeritage 호환)
- 텍스트 공유 (가족역사기록서 수동 입력용)
- FamilySearch.org OAuth 2.0 직접 동기화 (선택 사항)
- 전통 한지·먹 테마 + Noto Serif KR 폰트

### 🔧 빌드/통합 트러블슈팅 기록
- Java 21 / Gradle 호환 이슈 (Unsupported class file major version 65)
  → Gradle 8.5 + Temurin JDK 17 으로 해결
- 단일 ABI(arm64-v8a) 빌드로 APK 크기 절감
- Unihan kHangul 누락 한자 보강 (尚, 元, 在, 斗, 淳 등 80자)
- 세로쓰기 OCR 블록 정렬: 우→좌, 상→하 순서로 재배치
- 干支 60갑자 주기 → 출생연도와의 정합성 검증
- image_cropper 의존성 검토 및 빌드 경량화

### 🔮 향후 계획 (Roadmap)
- 필사본/초서 OCR 정확도 개선 (별도 학습 모델 검토)
- 가계도 PDF 인쇄 및 공유
- 묘비 사진 전용 OCR 모드
- 음력↔양력 일괄 변환 (전체 인물)
- FamilySearch 양방향 동기화 (가져오기 + 내보내기)
- 다국어 UI (영어/일본어/중국어)

---

문의: **ntec21c@gmail.com** (Peter S. Choi)
