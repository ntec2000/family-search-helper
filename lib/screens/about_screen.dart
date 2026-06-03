import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/traditional_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('복사됨: $text'), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('앱 정보')),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        children: [
          // ─── 헤더 ──────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HanjiColors.hanjiLight,
              border: Border.all(color: HanjiColors.muk, width: 0.8),
            ),
            child: Column(
              children: const [
                Text('家族歷史記錄 助手',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: HanjiColors.muk,
                        letterSpacing: 6)),
                SizedBox(height: 8),
                Text('가족역사기록 도우미',
                    style: TextStyle(fontSize: 18, color: HanjiColors.mukSoft)),
                Text('Family Search Helper',
                    style: TextStyle(fontSize: 12, color: HanjiColors.mukSoft, letterSpacing: 2)),
                SizedBox(height: 16),
                Text('v2.0.0',
                    style: TextStyle(fontSize: 14, color: HanjiColors.ju, letterSpacing: 2)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── 개발자 정보 ──────────────────────
          _Section(title: '개발자 정보'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.person, color: HanjiColors.muk),
                  title: Text('Peter S. Choi'),
                  subtitle: Text('Lead Developer · 개발총괄'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: HanjiColors.ju),
                  title: const Text('버그 신고 / 기능 문의'),
                  subtitle: const Text('ntec21c@gmail.com'),
                  trailing: const Icon(Icons.copy, size: 18),
                  onTap: () => _copy(context, 'ntec21c@gmail.com'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.church_outlined, color: HanjiColors.cheong),
                  title: Text('The Church of Jesus Christ of Latter-day Saints'),
                  subtitle: Text('가족역사사업(Family History Work) 지원 앱'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── 개발 배경 ──────────────────────
          _Section(title: '개발 배경'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '본 앱은 한국의 족보(族譜) 한자 기록을 해석하여, '
                    'The Church of Jesus Christ of Latter-day Saints '
                    '회원의 가족역사사업에 필요한 인물 정보를 '
                    '쉽게 추출하고 정리하기 위해 개발되었습니다.',
                    style: TextStyle(height: 1.7, fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '족보 한자(이름·자·호·본관·생몰일·결혼·매장·자녀·사위·사돈)를 '
                    '카메라로 촬영하면 온디바이스 OCR과 내장 한자 사전(8,528자) '
                    '및 만세력(萬歲曆)을 이용해 자동으로 한글 음으로 변환하고, '
                    'FamilySearch.org 표준(GEDCOM 5.5.1 / GEDCOM-X)에 맞춰 '
                    '저장 또는 직접 동기화할 수 있도록 구현하였습니다.',
                    style: TextStyle(height: 1.7, fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '모든 처리는 전화기 내부에서 이루어지며, '
                    '인터넷 연결과 외부 서버가 없어도 동작합니다. '
                    'FamilySearch 직접 동기화 시에만 사용자 동의 하에 '
                    'OAuth 2.0 표준으로 통신합니다.',
                    style: TextStyle(height: 1.7, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── 기술 스택 ──────────────────────
          _Section(title: '기술 스택 (전부 무료/오픈소스)'),
          Card(
            child: Column(
              children: const [
                _KV('프레임워크', 'Flutter 3.41 · Dart 3.11'),
                _KV('OCR', 'Google ML Kit Text Recognition v2 16.0.1 (Chinese, 온디바이스 · 16KB 페이지 정렬)'),
                _KV('한자→한글 사전', '내장 9,000자+ · 한글 음(여러 음 포함)·뜻(訓) 수록'),
                _KV('만세력', 'lunar Dart 패키지 (KASI 데이터, 1700-2100)'),
                _KV('로컬 DB', 'SQLite (sqflite)'),
                _KV('내보내기', 'GEDCOM 5.5.1 / GEDCOM-X (FamilySearch 호환)'),
                _KV('테마', '전통 한지·먹 · Noto Serif KR'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── 개발 히스토리 / 버그 수정 ───────────────────
          _Section(title: '개발 히스토리 / 버그 수정 기록'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: const [
                  _Hist(
                    ver: 'v2.4.0',
                    date: '2026-06-03',
                    items: [
                      '✨ 인식 후 사람 이름이 아닌 항목(오인식·관직명 등)을 🗑 버튼으로 삭제 — 인물만 남겨 정리',
                      '✨ 女(딸) 인식 정교화 — 사위 이름과 본관(○○人) 분리 추출, 사위 이름이 없고 본관만 있으면 \'이름 미상\'으로 처리, 딸 본인은 가문 성(○씨)',
                      '✨ 出系(출계·양자) 자동 인식 — \'出系 ○○后\'를 특이사항으로 기록 (예: 承勳·炳旭)',
                      '✨ 이름 뒤에 키워드가 붙은 오인식 자동 보정(예: 承勳出 → 承勳), 干支 내부 子 오분리 방지',
                      '✨ 처가(配) 계열 父/祖/曾祖/外祖 추출 안정화(관직명·본관 포함), 忌(연도 미상)·墓(좌향·합폄) 인식 보강',
                      '✨ 한글 표기와 한자음 불일치 시 특이사항 메모(확인요망) — 예: 聖甲(성갑)을 \'성중\'으로 오기한 경우',
                      '✨ 내보내기·인물 목록에 특이사항(出系 등) 표시',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v2.3.0',
                    date: '2026-06-03',
                    items: [
                      '✨ 配(배우자) 블록의 父/祖/曾祖/外祖를 처가(아내 쪽) 계열로 정확히 귀속 — 장인·처조·처증조·처외조로 분리 표기',
                      '✨ 女(딸) 항목은 사위(남편)로 인식하고, 딸 본인은 이름이 없으므로 아버지(가문) 성을 따라 \'○씨\'로 표기 · 사위 본관은 ○○人에서 추출',
                      '✨ 성씨 미인식 시 한글 성 입력 → [입력] → 한자 후보 칸에서 직접 선택 → 선택한 한글+한자로 성씨 확정 후 전체 자녀에 적용',
                      '✨ 모든 이미지 화면(촬영 확인·결과)에 핀치 줌 적용 — 첨부·촬영한 족보 이미지를 확대하여 읽기 가능',
                      '✨ 干支生/干支卒(예: 壬辰生) 단순 표기 및 忌(기일, 연도 미상)·墓(매장지) 인식 보강',
                      '✨ 내보내기 텍스트를 FamilySearch 입력용 형식으로 정리 — 성/이름/로마자/字/출생/배우자·장인 등 처가 계열/사위/딸=○씨 포함',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v2.2.0',
                    date: '2026-06-03',
                    items: [
                      '✨ 가계도 전면 개선 — 아버지(중심) 기준으로 자녀를 아래에 선으로 연결, 장인 옆에 장모, 딸 아래 사위·사돈·사돈부인 표시',
                      '✨ 아들 이름은 성|이름 두 칸 + 로마자 두 칸으로 구분 표시, 딸(이름 없음)은 \'○씨\' 한 칸 + 로마자 한 칸 표시 (밑줄 구분은 칸 넓이만큼)',
                      '✨ 자식 이름만 있으면 아버지 성을 상속하여 표기, 족보에 성씨가 없으면 인식 시 수동 입력하여 전체 인물에 동일 적용',
                      '✨ 자녀는 출생연도순(첫째·둘째…) 정렬, 아들/딸 구분 표시',
                      '✨ 세대(世) 기반 출생연도 추정 — 한 세대 약 30년 기준, 추정 어려우면 \'대략 ○○○○\' 표시, 불가하면 공란',
                      '✨ 출생·사망지 미상 시 기본 \'대한민국\' 표기, 한글·로마자 병기',
                      '✨ 인물카드에 성(姓) 분리·장모·사돈부인·世·派·근거 진술(FamilySearch Reason) 항목 추가, 성/로마자 자동 변환 버튼',
                      '✨ 인식 후 인물 추가·수정 가능 — 인물 추가 입력항목 동일, 로마자 자동 변환',
                      '✨ 가계도 박스를 탭하면 해당 인물카드로 이동 (이름→실제 레코드 자동 매칭)',
                      '✨ 내보내기 텍스트에 모든 인물 정보(성·이름·로마자·世·장모·사돈부인·근거 등) 포함 및 칸 구분선 정리',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v2.1.0',
                    date: '2026-06-03',
                    items: [
                      '🛠 한글 필기 인식 정확도 개선 — 인식 영역에서 테두리 제외, 고해상도 캡처',
                      '🛠 인식 결과·인물카드·한자음 검색·필기 인식 등 모든 화면 하단 잘림 수정 (스크롤·SafeArea 적용)',
                      '✨ 모든 한자 항목을 한자(한글) 병기로 표시 — 배우자·배우자 부친 등 포함',
                      '✨ 이름 로마자 자동 표기 — 한글 이름을 알파벳(로마자)으로 변환 표시',
                      '✨ 인물카드 항목명 정비 — \'조상 신상정보\' / \'인물정보\' / \'출생 사망정보\' / \'가족정보\'',
                      '✨ 출생·사망일을 음력/양력 구분 없이 날짜 하나로 단순 표시',
                      '✨ 한자음 검색 예시를 \'최, 상, 희\' 로 변경, 인식된 예상 한자에 한글 음(여러 음)·뜻 표시',
                      '✨ [인식 버튼] → [결과 확인] 으로 명칭 변경',
                      '✨ 가계도 개선 — 본인·아버지·배우자·장인·자녀·사위·사돈을 관계 이름이 적힌 박스로 트리(선 연결) 표시',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v2.0.0',
                    date: '2026-06-02',
                    items: [
                      '✨ 카메라/갤러리 이미지에서 필요한 부분만 잘라서(영역 선택) 한자 인식 — 불필요한 여백·다른 단 제외로 정확도 향상',
                      '✨ 손으로 한자를 직접 써서 찾는 [필기 인식] 도구 추가 (네이버 한자 입력 방식 참조, 온디바이스)',
                      '✨ [한자 도구] 메뉴 신설 — 한글 이름→한자 후보, 한자음(한글)으로 한자 검색, 필기 인식 통합',
                      '✨ 이름 검색에 한글 입력 + 검색 버튼 추가 — 예) \'최상희\' 입력 시 음절별 한자·한글음 후보 표시',
                      '✨ 만세력에 간지 한글 입력 지원 — 예) \'갑오년\' 입력 시 추정 연도 표시',
                      '✨ 가계도를 한 화면에 보이도록 확대/축소(핀치 줌) 지원',
                      '✨ 족보 추출 정보 확대 — 출생지·매장지·결혼일/장소·자녀·사위(婿)·사돈(査頓) 정보 추출 및 정렬',
                      '✨ 내보내기 텍스트 서식 개선 — 이름·자(字)·배우자를 한글(한자) 병기로 보기 좋게 정렬 + 미리보기',
                      '🛠 [다시 선택] 오류 수정 — 갤러리에서 가져온 경우 무한 로딩되던 문제 해결',
                      '🛠 [직접 입력] 오류 수정 — 빈 인물 카드를 생성·저장해 바로 편집 가능하도록 수정',
                      '✨ [앱 종료] · [새로고침(초기화면)] 기능 추가',
                      '✨ 앱 로고를 FamilySearch 가계도 아이콘 스타일로 변경',
                      '✨ 전체 UI/디자인을 최신 트렌드(모던 한지·먹 테마, 둥근 모서리 카드)로 리프레시',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v1.0.6',
                    date: '2026-02-18',
                    items: [
                      '🛠 [한자 인식 시작]에서 강제 종료되던 진짜 원인 해결 — 한자(중국어) 인식 모델이 APK 에 들어있지 않았음. ML Kit Flutter 플러그인은 한자 모듈을 compileOnly(=컴파일만, APK 미포함)로만 선언하므로, 인식을 실행하는 순간 없는 네이티브 코드를 호출해 강제 종료(Dart try/catch 로 잡히지 않는 네이티브 크래시)가 발생했음',
                      '🛠 com.google.mlkit:text-recognition-chinese:16.0.1 (번들 모델)을 앱 빌드에 implementation 으로 직접 추가 — 한자 OCR 모델·네이티브 라이브러리를 APK 에 포함하여 완전 오프라인·온디바이스로 동작 (Google Play 서비스 모델 다운로드 불필요)',
                      '✅ 빌드된 APK 안에 한자 인식 모델 자산이 실제로 포함됐는지 직접 확인 + 네이티브 라이브러리 16KB 정렬 재확인 후 배포',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v1.0.5',
                    date: '2026-02-05',
                    items: [
                      '🛠 [한자 인식 시작]에서 강제 종료되던 네이티브 크래시 해결 — 근본 원인은 Android 15 / 16KB 메모리 페이지 단말에서 구버전 ML Kit 네이티브 라이브러리(.so)의 정렬 불일치(dlopen 실패)였음',
                      '🛠 ML Kit Text Recognition 플러그인을 16.0.1(16KB 페이지 정렬 빌드)로 업그레이드 — libmlkit_google_ocr_pipeline.so LOAD 정렬 0x4000(16KB) 확인',
                      '🛠 빌드 도구 현대화: Flutter 3.41 · AGP 8.7 · Gradle 8.11 · compileSdk/targetSdk 35 · NDK 27 — APK 내 모든 .so 16KB 정렬·비압축 저장(zipalign -P 16 통과)',
                      '✅ 실제 릴리즈 APK 빌드 시뮬레이션 완료 후 검증 배포 — 정적 분석 무오류 + 단위 테스트 6건 통과 + 네이티브 라이브러리 16KB 정렬 직접 확인',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v1.0.4',
                    date: '2026-01-20',
                    items: [
                      '🛠 사진 업로드 흐름 재설계 — 가져온 사진은 \'먼저 미리보기\'만 하고, [한자 인식 시작]을 누를 때만 인식 실행 (불러오기 단계 강제 종료 원천 차단)',
                      '🛠 네이티브 라이브러리 비압축 패키징(useLegacyPackaging) 적용 — ML Kit 로딩 시 네이티브 크래시 방지',
                      '🛠 AndroidManifest 에 extractNativeLibs=true, largeHeap 적용으로 메모리/네이티브 안정성 강화',
                      '🛠 인식 실패 시에도 [직접 입력] 경로 제공 — 막다른 길 없이 계속 작업 가능',
                      '✅ 빌드 전 정적 분석(flutter analyze) 무오류 + 단위 테스트 6건 전체 통과 검증 후 배포',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v1.0.3',
                    date: '2026-01-08',
                    items: [
                      '🛠 특정 사진 업로드 시 강제 종료(네이티브 크래시) 해결',
                      '🛠 OCR 전 이미지를 표준 JPEG 로 재인코딩(디코더 크래시 방지)',
                      '🛠 EXIF 회전 자동 보정 + 안전한 크기로 정규화',
                      '🛠 앱 전역 오류 핸들러 추가 — 예기치 못한 오류에도 앱 유지',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v1.0.2',
                    date: '2025-12-22',
                    items: [
                      '🔧 갤러리에서 큰 사진 업로드 시 강제 종료(크래시) 수정',
                      '🔧 업로드 이미지 자동 축소(최대 2400px)로 메모리 부족 방지',
                      '🔧 OCR/분석 전 구간 예외 처리 — 오류 시 안내 후 복귀',
                      '🔧 미리보기 이미지 메모리 캐시 제한(cacheWidth)',
                      '🔧 ML Kit 텍스트 인식 의존성 보정 (ica → ocr)',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v1.0.1',
                    date: '2025-12-05',
                    items: [
                      '✨ 작동 모드 선택 기능 추가 — 추출 전용 ↔ FamilySearch 연동',
                      '✨ 설정 화면에 FamilySearch 연동 On/Off 토글 추가 (기본 꺼짐)',
                      '✨ FamilySearch Client ID 를 앱 설정에서 직접 입력·저장 (SQLite)',
                      '🔧 연동을 끄면 완전한 추출 전용 모드로 동작 (로그인 불필요)',
                      '🔧 내보내기 화면이 연동 설정 상태를 반영하도록 정리',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: 'v1.0.0',
                    date: '2025-11-15',
                    items: [
                      '✨ 첫 릴리즈',
                      '✨ 카메라/갤러리 입력 + ML Kit 한자 OCR (온디바이스)',
                      '✨ 족보 표준 표기 파서 (子/女/字/號/配/墓/生/卒)',
                      '✨ Unihan 기반 한자→한글 음 사전 8,528자 내장',
                      '✨ 만세력 변환 + 干支(간지) → 연도 추정',
                      '✨ 인물 카드 (FamilySearch 호환 항목)',
                      '✨ 가계도(家系圖) 세대별 시각화',
                      '✨ OCR 후보 한자 수정 위젯 (己/已/巳, 戊/戌 등 혼동 한자 대안)',
                      '✨ SQLite 로컬 영속화',
                      '✨ GEDCOM 5.5.1 내보내기 / 텍스트 공유',
                      '✨ FamilySearch.org OAuth 2.0 직접 동기화 (선택)',
                      '✨ 전통 한지·먹 테마 + Noto Serif KR',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: '빌드 트러블슈팅 기록 (참고)',
                    date: '2025-11-10',
                    items: [
                      '🔧 Java 21 / Gradle 호환 이슈 (major version 65) → Gradle 8.5 + JDK 17 으로 해결',
                      '🔧 단일 ABI(arm64-v8a) 빌드로 APK 크기·디스크 절감',
                      '🔧 Unihan kHangul 누락 한자 보강(尚 등 80자 추가)',
                      '🔧 세로쓰기 OCR 블록 정렬: 우→좌, 상→하 순서로 재배치',
                      '🔧 干支 60갑자 주기 → 출생연도와의 정합성 검증 추가',
                      '🔧 image_cropper 의존성 검토 및 빌드 경량화',
                    ],
                  ),
                  Divider(),
                  _Hist(
                    ver: '향후 계획 (Roadmap)',
                    date: '예정',
                    items: [
                      '🔮 필사본/초서 OCR 정확도 개선 (별도 학습 모델 검토)',
                      '🔮 가계도 PDF 인쇄 및 공유',
                      '🔮 묘비 사진 전용 OCR 모드',
                      '🔮 음력↔양력 일괄 변환 (전체 인물)',
                      '🔮 FamilySearch 양방향 동기화 (가져오기 + 내보내기)',
                      '🔮 다국어 UI (영어/일본어/중국어)',
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── 참조 ───────────────────
          _Section(title: '참조 자료'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.link, color: HanjiColors.cheong),
                  title: const Text('FamilySearch Korea'),
                  subtitle: const Text('https://www.familysearch.org/ko/korea/'),
                  trailing: const Icon(Icons.copy, size: 18),
                  onTap: () => _copy(context, 'https://www.familysearch.org/ko/korea/'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link, color: HanjiColors.cheong),
                  title: const Text('FamilySearch Developer Portal'),
                  subtitle: const Text('https://www.familysearch.org/developers'),
                  trailing: const Icon(Icons.copy, size: 18),
                  onTap: () => _copy(context, 'https://www.familysearch.org/developers'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link, color: HanjiColors.cheong),
                  title: const Text('Unicode Unihan Database'),
                  subtitle: const Text('https://www.unicode.org/charts/unihan.html'),
                  trailing: const Icon(Icons.copy, size: 18),
                  onTap: () => _copy(context, 'https://www.unicode.org/charts/unihan.html'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ─── 라이센스 ───────────────────
          _Section(title: '라이센스'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '본 앱은 가족역사사업 지원 목적의 비상업적 프로젝트입니다.\n\n'
              '• Unihan Database: © Unicode, Inc. (Unicode License)\n'
              '• Google ML Kit: Apache License 2.0\n'
              '• Flutter / Dart: BSD 3-Clause\n'
              '• lunar (만세력): MIT\n'
              '• Noto Serif KR: SIL Open Font License\n\n'
              '© 2026 Peter S. Choi. All rights reserved.',
              style: TextStyle(height: 1.7, fontSize: 12, color: HanjiColors.mukSoft),
            ),
          ),
          const SizedBox(height: 24),
        ],
      )),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 12),
      child: Row(children: [
        Container(width: 4, height: 18, color: HanjiColors.ju),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: HanjiColors.muk,
                letterSpacing: 1)),
      ]),
    );
  }
}

class _KV extends StatelessWidget {
  final String k, v;
  const _KV(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 110,
            child: Text(k,
                style: const TextStyle(
                    color: HanjiColors.ju, fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 13, height: 1.5))),
      ]),
    );
  }
}

class _Hist extends StatelessWidget {
  final String ver, date;
  final List<String> items;
  const _Hist({required this.ver, required this.date, required this.items});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(ver,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: HanjiColors.muk,
                    fontSize: 15)),
            const SizedBox(width: 8),
            Text('· $date',
                style: const TextStyle(color: HanjiColors.mukSoft, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          ...items.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(s, style: const TextStyle(fontSize: 13, height: 1.4)),
              )),
        ],
      ),
    );
  }
}
