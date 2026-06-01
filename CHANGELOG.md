# Changelog · 개발 히스토리

> **개발자**: Peter S. Choi
> **문의**: ntec21c@gmail.com

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
