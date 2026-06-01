# 가족역사기록 도우미 (Family Search Helper)

> 족보(族譜)의 한자를 카메라로 인식하여 가족역사기록서 작성을 돕는 Android 앱.
> The Church of Jesus Christ of Latter-day Saints 가족역사사업(Family History Work) 지원.

**개발자**: Peter Choi
**참조**: [FamilySearch Korea](https://www.familysearch.org/ko/korea/)
**패키지**: `com.peterchoi.familysearchhelper`

## 핵심 원칙

✅ **완전 독립 실행** — 설치된 전화기에서 모든 기능이 자체 구동 (외부 서버 의존 0)
✅ **무료/오픈소스만 사용** — Flutter + ML Kit + Unihan + lunar (전부 무료)
✅ **온디바이스 처리** — OCR·사전·만세력·DB 모두 전화기 내부에서 처리
✅ **프라이버시 우선** — 데이터 외부 송신 없음

## 주요 기능

| # | 기능 | 설명 | 외부 연결 |
|---|---|---|---|
| 1 | 📷 족보 촬영/업로드 | 카메라 또는 갤러리 | ❌ |
| 2 | 🔍 한자 OCR | ML Kit Chinese (온디바이스) | ❌ |
| 3 | 📖 한자→한글 음 | Unihan 8,528자 내장 | ❌ |
| 4 | 📅 만세력 변환 | 양↔음력, 干支→연도 | ❌ |
| 5 | 👤 인물 카드 | FamilySearch 호환 항목 | ❌ |
| 6 | 🌳 가계도 (家系圖) | 세대별 트리 시각화 | ❌ |
| 7 | ✏️ OCR 후보 수정 | 한자 다중 후보 선택 | ❌ |
| 8 | 💾 SQLite 로컬 저장 | 영구 보존 | ❌ |
| 9 | 📤 GEDCOM 5.5.1 내보내기 | FamilySearch 등 호환 | ❌ |
| 10 | ☁️ FamilySearch.org 직접 동기화 | OAuth 로그인 (선택) | ✅ 로그인 필요 |

## FamilySearch 연동 방식

본 앱은 **두 가지 방식 모두 지원**합니다:

### 방식 A — 로그인 불필요 (기본 권장)
1. 앱에서 GEDCOM(.ged) 파일 내보내기
2. https://www.familysearch.org → "트리" → "GEDCOM 가져오기"
3. 끝

### 방식 B — 직접 동기화 (선택)
1. https://www.familysearch.org/developers 에서 무료 개발자 등록
2. Client ID 발급받아 `lib/services/familysearch_service.dart` 의 `clientId` 에 입력
3. 앱 내 "FamilySearch 연동" 메뉴에서 OAuth 로그인
4. 인물 카드를 FamilySearch.org 의 가족나무에 직접 등록

> ⚠️ FamilySearch API 는 OAuth 2.0 인증이 필수입니다. LDS 회원 계정으로만 사용 가능합니다.

## 파서 인식 규칙 (실제 샘플 검증 완료)

```
子○○ / 女○○        → 성별 + 이름(한자)
字○○                → 자(字)
號○○                → 호(號)
配○○郡 ○○氏 父 ○○○ → 배우자
墓○○郡 ○○面 ○○山   → 묘 위치
○坐○向              → 좌향
干支○月○日 生        → 출생 (음력 干支)
干支○月○日 卒        → 사망 (음력 干支)
```

## 빌드

자세한 내용은 [`BUILD.md`](BUILD.md) 참조.

```bash
flutter pub get
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

**APK 만 전화기에 설치하면 모든 기능 작동.**

## 개인정보 / 가족역사사업 준수

- 모든 데이터는 **기기 내부에만 저장**, 외부 송신 없음
- FamilySearch 직접 동기화 시에만 사용자 토큰을 OAuth 표준으로 사용
- 가족역사사업 관련 [FamilySearch 정책](https://www.familysearch.org/legal/) 준수

## 라이센스

비상업적 가족역사사업 지원 프로젝트.
- Unihan: © Unicode, Inc. (Unicode License)
- ML Kit / Flutter: Apache 2.0 / BSD
- lunar: MIT
