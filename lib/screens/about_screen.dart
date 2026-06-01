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
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                Text('v1.0.0',
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
                    '회원의 가족역사사업(사족역사사업)에 필요한 인물 정보를 '
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
                _KV('프레임워크', 'Flutter 3.24 · Dart 3.5'),
                _KV('OCR', 'Google ML Kit Text Recognition v2 (Chinese, 온디바이스)'),
                _KV('한자→한글 사전', 'Unicode Unihan 8,528자 (내장)'),
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
                    ver: 'v1.0.0',
                    date: '2026-06-01',
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
                    date: '2026-06-01',
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
      ),
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
