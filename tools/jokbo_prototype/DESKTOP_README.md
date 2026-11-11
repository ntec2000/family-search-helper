# Windows 데스크톱 OCR 검수 실험판

기존 OCR 실험실을 별도 데스크톱 창으로 실행하는 초기 개발판입니다. 새로 제공된 웹 화면은 아직 연결되지 않았으며 원본은 `reference/family_search_helper_v3_0_5_v5.html`에 보존되어 있습니다. 샘플을 실제 OCR 결과로 내보내지 않도록 해당 화면을 그대로 실행하지 않습니다.

Windows 11에서 저장소를 받은 뒤 Python 3.12 및 Microsoft Edge WebView2 런타임을 준비하고 `start_desktop_windows.cmd`를 실행합니다. 첫 실행에는 패키지와 OCR 모델 다운로드를 위해 인터넷이 필요합니다. 이후 사용 가능 여부는 모델 캐시와 환경에 따라 확인해야 합니다. 원본 이미지와 JSON 백업은 사용자가 별도 보관합니다. 임시 OCR 및 관계는 반드시 원문과 대조하십시오.

이 실행 방식은 Python을 사용하는 개발판이며 설치형 EXE가 아닙니다. 실기기 실행, 파일 선택, OCR 모델 다운로드, 편집, 저장·종료·재실행, 백업 복원, 다운로드와 Windows WebView2 저장 동작을 검증해야 합니다. 브라우저에 저장된 기존 정보는 자동 이전되지 않습니다. 다른 프로그램이 포트 8765를 사용하면 안전을 위해 실행이 중단됩니다.

로컬 웹뷰 저장 경로는 `%LOCALAPPDATA%\FamilyHistoryHelper\WebView`입니다. 기존 Flutter 앱이나 기존 브라우저 저장소를 변경하지 않습니다. 새 디자인, EXE/설치 프로그램, FamilySearch 연동과 Cython은 아직 미구현입니다.
