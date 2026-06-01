# GitHub Actions 워크플로우

`build-apk.yml` 은 다음 상황에서 자동으로 APK 를 빌드합니다:

- `main` 또는 `master` 브랜치에 푸시
- Pull Request 생성
- 수동 실행 (Actions 탭 → "Run workflow" 버튼)
- 태그 푸시 (예: `v1.0.0`) → 자동으로 GitHub Release 생성

빌드 결과는 Actions 페이지 하단의 **Artifacts** 에서 30일간 다운로드 가능합니다.
