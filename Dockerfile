# 가족역사기록 도우미 - 로컬 Docker 빌드
# 사용법:
#   docker build -t fsh-builder .
#   docker run --rm -v $(pwd)/output:/output fsh-builder
#   → output/app-release.apk 생성됨

FROM cirrusci/flutter:3.24.5

# Android SDK 라이센스 자동 동의
RUN yes | sdkmanager --licenses > /dev/null || true
RUN sdkmanager "platforms;android-35" "build-tools;34.0.0" "platform-tools" > /dev/null

WORKDIR /app
COPY . /app

RUN flutter config --no-analytics --no-cli-animations
RUN flutter pub get

# APK 빌드
RUN flutter build apk --release

# 출력 디렉토리 정리
CMD ["sh", "-c", "mkdir -p /output && cp build/app/outputs/flutter-apk/app-release.apk /output/family-search-helper-v1.0.0.apk && echo 'APK 빌드 완료: /output/family-search-helper-v1.0.0.apk' && ls -lh /output/"]
