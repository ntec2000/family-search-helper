# 🚀 APK 빌드 가이드 — 3가지 경로

> 본 ZIP의 모든 코드는 검증 완료 상태입니다.
> 아래 3가지 경로 중 **편하신 방법 하나만** 따라하시면 APK가 생성됩니다.

---

## 🥇 경로 ①: GitHub Actions (권장 · 무료 · 5분 · 클릭만으로 가능)

> Peter Choi 님 PC 에 Flutter/Android SDK 설치 불필요.
> GitHub 가 클라우드에서 빌드 후 APK 파일을 다운로드 가능하게 해줍니다.

### Step 1. GitHub 레포지토리 생성

1. https://github.com/new 접속
2. Repository name: `family-search-helper`
3. Public 또는 Private 아무거나
4. "Create repository" 클릭

### Step 2. 본 ZIP 의 내용을 레포에 업로드

**방법 A — 웹에서 드래그앤드롭 (가장 쉬움)**
1. 새로 만든 레포의 "Add file → Upload files" 클릭
2. ZIP 압축 푼 폴더의 **모든 파일·폴더** 를 드래그앤드롭
3. ⚠️ `.github` 폴더가 반드시 포함되어 있어야 합니다 (숨김 폴더이므로 주의)
4. "Commit changes" 클릭

**방법 B — git 명령 (개발자에게 익숙)**
```bash
unzip family-search-helper-v1.0.0-FINAL.zip
cd family-search-helper
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/family-search-helper.git
git push -u origin main
```

### Step 3. APK 빌드 자동 시작 확인

1. 레포지토리 상단 **"Actions"** 탭 클릭
2. "Build APK" 워크플로우가 자동 실행됨 (노란색 → 녹색 체크 표시)
3. 약 **5-10분** 후 완료

### Step 4. APK 다운로드

1. 완료된 워크플로우 실행을 클릭
2. 페이지 하단 **"Artifacts"** 섹션에서:
   - `family-search-helper-universal-apk` (모든 기기 호환, 약 80MB)
   - `family-search-helper-split-apks` (기기별 작은 APK, 약 25MB씩)
3. 원하는 파일 클릭하여 다운로드
4. 압축 풀면 `.apk` 파일이 나옴

### Step 5. 전화기 설치

1. APK 파일을 전화기로 전송 (이메일 / 카카오톡 / USB 등)
2. 전화기 설정 → 보안 → "출처를 알 수 없는 앱 설치 허용"
3. APK 파일을 탭하여 설치

✅ **끝. 모든 기능 작동.**

---

## 🥈 경로 ②: Docker (Docker 있는 PC 사용자)

```bash
unzip family-search-helper-v1.0.0-FINAL.zip
cd family-search-helper
mkdir output

# 빌드 (Docker 가 Flutter 환경 자동 구성)
docker build -t fsh-builder .
docker run --rm -v $(pwd)/output:/output fsh-builder

# 결과
ls -lh output/family-search-helper-v1.0.0.apk
```

---

## 🥉 경로 ③: 로컬 Flutter 설치 (Peter Choi 님 PC 직접 빌드)

### Step 1. Flutter SDK 설치
- Windows / macOS / Linux: https://docs.flutter.dev/get-started/install

### Step 2. Android SDK 설치
- Android Studio: https://developer.android.com/studio
- 설치 후 `flutter doctor --android-licenses` 실행

### Step 3. 빌드
```bash
unzip family-search-helper-v1.0.0-FINAL.zip
cd family-search-helper
flutter pub get
flutter build apk --release
```

### Step 4. APK 위치
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## ⚡ 가장 빠른 경로 (요약)

| 경로 | 소요시간 | PC 설정 필요 |
|---|---|---|
| **① GitHub Actions** | 5-10분 | 없음 (GitHub 계정만) |
| ② Docker | 15분 | Docker 설치 |
| ③ 로컬 Flutter | 30-60분 (첫 설치 시) | Flutter + Android SDK |

→ **경로 ①을 강력히 추천드립니다.**

---

## ❓ 문제 발생 시

- **GitHub Actions 빌드 실패**: 워크플로우 페이지에서 로그 확인 후 Peter Choi (ntec21c@gmail.com) 로 전달
- **Docker 빌드 실패**: 로그 전체를 동일 주소로 전달
- **로컬 빌드 실패**: `flutter doctor -v` 결과와 함께 전달
