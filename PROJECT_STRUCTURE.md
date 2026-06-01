# 프로젝트 구조

```
family-search-helper/
├── README.md                      # 프로젝트 개요
├── BUILD.md                       # 빌드 가이드
├── CHANGELOG.md
├── PROJECT_STRUCTURE.md           # 이 문서
├── pubspec.yaml                   # Flutter 의존성 정의
├── analysis_options.yaml
├── .gitignore
│
├── lib/
│   ├── main.dart                  # 앱 진입점
│   ├── app.dart                   # MaterialApp / 테마 적용
│   │
│   ├── theme/
│   │   └── traditional_theme.dart # 한지·먹 컬러 + Noto Serif KR
│   │
│   ├── models/
│   │   └── person.dart            # 인물 데이터 모델 (GEDCOM 호환)
│   │
│   ├── services/                  # ── 도메인 서비스 (팀 분담) ──
│   │   ├── hanja_dict.dart        # [DEV-HANJA] 한자→한글 음 사전
│   │   ├── lunar_service.dart     # [DEV-LUNAR] 만세력·干支 변환
│   │   ├── ocr_service.dart       # [DEV-OCR] ML Kit 래퍼
│   │   ├── jokbo_parser.dart      # [DEV-PARSER] 족보 표기 파싱
│   │   ├── db_service.dart        # [DEV-DB] SQLite 영속화
│   │   └── gedcom_export.dart     # [DEV-DB] GEDCOM 5.5.1 내보내기
│   │
│   └── screens/                   # ── UI ── [DEV-UI]
│       ├── home_screen.dart       # 홈 / 인물 리스트
│       ├── capture_screen.dart    # 카메라·크롭·OCR 진행
│       ├── result_screen.dart     # 인식 결과 (인물/한자한글/원본)
│       ├── person_card_screen.dart# 인물 카드 편집
│       ├── lunar_converter_screen.dart # 만세력 도구
│       ├── export_screen.dart     # GEDCOM/텍스트 내보내기
│       └── settings_screen.dart
│
├── test/
│   └── parser_test.dart           # 단위 테스트
│
├── assets/
│   ├── dict/
│   │   └── hanja_kor.json         # 한자→한글 사전 (8,528자, 100KB)
│   ├── fonts/                     # Noto Serif KR (사용자가 추가)
│   └── images/
│
└── android/
    ├── build.gradle.kts
    ├── settings.gradle.kts
    ├── gradle.properties
    └── app/
        ├── build.gradle.kts
        └── src/main/
            ├── AndroidManifest.xml
            └── kotlin/com/peterchoi/familysearchhelper/MainActivity.kt
```

## 모듈간 의존 관계

```
        ┌──────────┐
        │  main    │
        └────┬─────┘
             ▼
        ┌──────────┐
        │   app    │  ── theme/traditional_theme
        └────┬─────┘
             ▼
   ┌─────────┴───────────┐
   │      screens/        │
   │  home → capture →    │
   │  result → person_card│
   └────┬──────┬──────────┘
        ▼      ▼
   ┌────────┐ ┌─────────────┐
   │ models │ │  services   │
   │ Person │ │ OcrService  │
   └────────┘ │ JokboParser │── HanjaDict
              │ DbService   │── LunarService
              │ GedcomExport│
              └─────────────┘
```

## 팀 분담 매트릭스

| 팀원 | 담당 파일 | 핵심 책임 |
|---|---|---|
| **PM-01 (팀장)** | `app.dart` `main.dart` | 통합·코드리뷰·릴리즈 |
| **DEV-UI** | `screens/*` `theme/*` | UI/UX 7개 화면 |
| **DEV-OCR** | `services/ocr_service.dart` | ML Kit · 세로쓰기 정렬 |
| **DEV-PARSER** | `services/jokbo_parser.dart` | 족보 정규표현 엔진 |
| **DEV-HANJA** | `services/hanja_dict.dart` + JSON | Unihan 8,528자 |
| **DEV-LUNAR** | `services/lunar_service.dart` | 양음력·干支 추정 |
| **DEV-DB** | `services/db_service.dart` `gedcom_export.dart` | SQLite·GEDCOM |
| **QA-01** | `test/*` `BUILD.md` 체크리스트 | 시뮬레이션·결함 보고 |
