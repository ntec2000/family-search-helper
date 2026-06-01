# 빌드 가이드 — 가족역사기록 도우미

## 요구 사항

| 항목 | 버전 |
|---|---|
| Flutter SDK | 3.24.0 이상 (Dart 3.5+) |
| Android SDK | API 34 (compileSdk), API 24 (minSdk) |
| JDK | 17 |
| Gradle | 8.1+ (Flutter가 자동 설치) |

## 1. Flutter 설치

```bash
# Linux
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz -o flutter.tar.xz
tar xf flutter.tar.xz -C $HOME
export PATH="$HOME/flutter/bin:$PATH"

# macOS
brew install --cask flutter

# Windows
# https://docs.flutter.dev/get-started/install/windows
```

## 2. Android SDK 설치

Android Studio 설치 후 `Tools → SDK Manager` 에서:
- Android SDK Platform 34
- Android SDK Build-Tools 34.0.0
- Android SDK Platform-Tools
- Android SDK Command-line Tools

또는 명령행:
```bash
sdkmanager "platforms;android-34" "build-tools;34.0.0" "platform-tools"
flutter config --android-sdk $ANDROID_HOME
yes | flutter doctor --android-licenses
```

## 3. 프로젝트 셋업

```bash
cd family-search-helper
flutter pub get
```

`android/local.properties` 파일 생성:
```properties
sdk.dir=/path/to/Android/sdk
flutter.sdk=/path/to/flutter
flutter.buildMode=release
flutter.versionName=1.0.0
flutter.versionCode=1
```

## 4. 폰트 파일 추가 (선택)

Noto Serif KR 폰트를 `assets/fonts/` 에 넣습니다:
- `NotoSerifKR-Regular.ttf`
- `NotoSerifKR-Bold.ttf`

다운로드: https://fonts.google.com/noto/specimen/Noto+Serif+KR

(없어도 빌드되며, Google Fonts 패키지가 런타임에 다운로드합니다.)

## 5. APK 빌드

```bash
flutter doctor                    # 환경 점검
flutter analyze                   # 정적 분석
flutter test                      # 단위 테스트
flutter build apk --release       # 단일 APK
# 또는 ABI별 분할
flutter build apk --release --split-per-abi
```

산출물 위치:
```
build/app/outputs/flutter-apk/app-release.apk
```

## 6. 디바이스 설치 & 시뮬레이션

```bash
# USB 연결 + 개발자 모드
flutter devices
flutter install
# 또는
adb install build/app/outputs/flutter-apk/app-release.apk

# 에뮬레이터
flutter emulators
flutter emulators --launch <id>
flutter run --release
```

## 7. 시뮬레이션 체크리스트 (QA)

- [ ] 카메라 권한 요청 정상 동작
- [ ] 갤러리에서 이미지 선택 가능
- [ ] 이미지 크롭 화면 정상
- [ ] OCR 인식 진행 표시
- [ ] 한자/한글 비교 화면 표시
- [ ] 인물 카드 자동 추출 (子/女/字/配/墓/生/卒 패턴)
- [ ] 인물 카드 수동 편집·저장
- [ ] 만세력 양력→음력 변환
- [ ] 干支 → 연도 추정 (예: 乙卯 입력)
- [ ] GEDCOM 내보내기 (.ged 파일 공유)
- [ ] 텍스트 내보내기 (공유 시트)
- [ ] 앱 재시작 후 데이터 유지 (SQLite)
- [ ] 다크 모드 동작

## 트러블슈팅

| 증상 | 해결 |
|---|---|
| `gradle build failed` | `cd android && ./gradlew clean` |
| ML Kit 모델 다운로드 실패 | 첫 실행 시 인터넷 연결 필요 (이후 오프라인 동작) |
| 카메라 권한 거부 | 설정 → 앱 → 권한에서 허용 |
| 한자 인식 정확도 낮음 | 인쇄체 권장. 필사본/초서는 80% 미만 가능 |
