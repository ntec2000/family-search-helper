# Windows 전환 검토 — 2026-11-11

제공받은 `reference/family_search_helper_v3_0_5_v5.html`은 검토용 웹 화면 원본이다.
원본 SHA-256: d7df725d7930b0568f64526c59b34ee2e27ec241a4fd018facd4ee059109262c.

## 확인 사항
- `executeRoiOcrExtraction`은 OCR 엔진을 실행하지 않고 선택 위치와 사전 정의된 데이터를 이용한다. 업로드 이미지에도 고정 데이터가 적용돼 다른 인물이 실제 결과처럼 표시될 위험이 있다.
- 화면의 99.2%는 측정 결과가 아닌 고정 문자열이다. 실제 인식률은 확인되지 않았다.
- 세대 간격만으로 생년을 확정하지 않는다. 원문과 후보를 보존한다.
- Tailwind CDN, Google Fonts, 원격 샘플 이미지에 의존하므로 오프라인 지원은 확인되지 않았다.
- 저장·복원, PDF, 내보내기, FamilySearch 연동은 별도 검증이 필요하다.

## Windows 전환 순서
1. 고정 데이터를 실제 OCR 결과로 표시하지 않도록 수정하고, 인식 엔진 부재 시 분석 불가를 명시한다.
2. Python + pywebview(WebView2) 데스크톱 창과 로컬 OCR을 연결한다. 이는 웹 기술을 내장한 데스크톱 앱이며 네이티브 위젯으로 새로 작성한 UI는 아니다.
3. 원본, OCR 원문, 후보, 사용자가 검토한 기록 및 관계를 분리해 보존한다.
4. Windows에서 PyInstaller로 빌드하고 설치, WebView2, 업데이트, 삭제, 데이터 저장·백업·복원, 오프라인 동작을 검증한다. 브라우저 데이터를 자동 이전한다고 가정하지 않는다.
5. Cython은 실제 측정한 Python 병목에만 선택 적용한다. HTML/JavaScript를 직접 컴파일하거나 OCR 정확도를 자동 향상시키지 않는다.

참고: https://pywebview.flowrl.com/guide/ , https://pywebview.flowrl.com/guide/freezing , https://pyinstaller.org/en/latest/usage.html , https://docs.cython.org/en/latest/src/quickstart/overview.html

Windows 설치 프로그램 제작 및 실기기 테스트는 아직 수행하지 않았다. 기존 Flutter 코드와 데이터는 변경하지 않는다.
