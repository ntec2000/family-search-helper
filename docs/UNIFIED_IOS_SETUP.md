# 가족역사 기록 도우미 — Android · iOS · Web

기존 Flutter `lib/` 화면·인물 모델·검토·저장·내보내기를 공유합니다.
별도 족보 앱이나 복제 UI를 만들지 않습니다. 원본 이미지와 OCR, 검토 데이터는 보존합니다.

## iOS 추가 범위
- Flutter 3.41.9 공식 iOS 템플릿 기반 Runner/SceneDelegate/Xcode 프로젝트.
- bundle identifier: `com.peterchoi.familysearchhelper` (배포 전 Apple 계정에서 가용성 확인 필요).
- iOS 15.5 이상, CocoaPods, Chinese ML Kit 9.x. 공통 OcrService의 chinese 인식기와 연결합니다.
- 카메라·사진 접근 용도 및 permission_handler 매크로.
- 기존 Android 아이콘을 macOS sips로 1024px로 변환합니다. 원본은 변경하지 않습니다.
- iOS 종료 메뉴는 홈 화면 이동 안내만 표시합니다.

## Mac에서 실행
```sh
flutter config --no-enable-swift-package-manager
python3 tools/prepare_ios_assets.py
flutter pub get
flutter build ios --release --no-codesign
open ios/Runner.xcworkspace
```

서명 없는 Runner.app은 아이폰 설치용 IPA가 아닙니다. 실제 기기 실행은 Xcode의 Signing & Capabilities에서 Apple 팀과 장치를 설정해야 합니다. App Store/TestFlight 배포에는 적절한 Apple 개발자 계정·인증서·프로비저닝이 필요하며 현재 저장소에 자격증명을 넣지 않습니다.

## 검증 범위와 남은 작업
- iOS source configuration 검사와 macOS unsigned build workflow를 추가했습니다. 실제 실행 결과는 해당 Actions run을 확인합니다.
- 아이폰 실기기에서 카메라/사진/PDF/OCR/저장/공유 검증은 별도이며, 컴파일 성공으로 대체하지 않습니다.
- Android는 기존 ML Kit, iOS는 동일 Chinese ML Kit 선택, 웹은 Tesseract 및 연결된 로컬 RapidOCR를 사용합니다. OCR 결과가 플랫폼마다 같다고 보장하지 않습니다.
- 기기 사이 데이터 자동 동기화, Apple 배포, FamilySearch 실계정 연동 완료를 의미하지 않습니다.

## 원본 기술 출처
- Flutter iOS 템플릿: https://github.com/flutter/flutter/tree/3.41.9/packages/flutter_tools/templates/app/ios.tmpl
- Flutter CocoaPods 템플릿: https://github.com/flutter/flutter/blob/3.41.9/packages/flutter_tools/templates/cocoapods/Podfile-ios
- Flutter template license: `ios/FLUTTER_TEMPLATE_LICENSE`
- ML Kit plugin: https://pub.dev/packages/google_mlkit_text_recognition
