import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/hanja_dict.dart';
import '../services/familysearch_service.dart';
import '../theme/traditional_theme.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _count = 0;
  bool _fsEnabled = FamilySearchService.enabled;
  late final TextEditingController _idCtrl =
      TextEditingController(text: FamilySearchService.clientId);

  @override
  void initState() {
    super.initState();
    DbService.instance.count().then((c) => mounted ? setState(() => _count = c) : null);
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveFs() async {
    await FamilySearchService.saveConfig(
        isEnabled: _fsEnabled, id: _idCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('FamilySearch 연동 설정이 저장되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 48), children: [
        ListTile(
          leading: const Icon(Icons.info_outline, color: HanjiColors.muk),
          title: const Text('앱 정보 / 개발자 / 히스토리'),
          subtitle: const Text('v2.2.0 · Peter S. Choi · ntec21c@gmail.com'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AboutScreen())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('등록 인물 수'),
          trailing: Text('$_count'),
        ),
        ListTile(
          leading: const Icon(Icons.menu_book),
          title: const Text('내장 한자 사전'),
          trailing: Text('${HanjaDict.instance.size}자'),
        ),
        const Divider(),

        // ─── 작동 모드 선택 ──────────────────────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('작동 모드',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: HanjiColors.ju)),
        ),
        SwitchListTile(
          secondary: Icon(
              _fsEnabled ? Icons.cloud_done : Icons.cloud_off,
              color: HanjiColors.ju),
          title: const Text('FamilySearch 연동 사용'),
          subtitle: Text(_fsEnabled
              ? '추출 + FamilySearch 가계도 직접 등록 (로그인 필요)'
              : '추출 전용 모드 — 정보 추출 후 GEDCOM·텍스트로만 내보내기'),
          value: _fsEnabled,
          activeColor: HanjiColors.ju,
          onChanged: (v) => setState(() => _fsEnabled = v),
        ),
        if (_fsEnabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _idCtrl,
              decoration: const InputDecoration(
                labelText: 'FamilySearch Client ID',
                helperText:
                    'familysearch.org/developers 에서 무료 발급 후 입력',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saveFs,
              icon: const Icon(Icons.save),
              label: const Text('연동 설정 저장'),
            ),
          ),
        ),
        const Divider(),

        const ListTile(
          leading: Icon(Icons.lock_outline, color: HanjiColors.cheong),
          title: Text('개인정보 보호'),
          subtitle: Text('모든 데이터는 기기 내부에만 저장되며, FamilySearch 연동을 켠 경우에만 사용자가 직접 업로드합니다.'),
        ),
        const ListTile(
          leading: Icon(Icons.church_outlined, color: HanjiColors.ju),
          title: Text('가족역사사업'),
          subtitle: Text('FamilySearch.org/ko/korea/ 의 권장사항을 준수합니다.'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.email_outlined, color: HanjiColors.ju),
          title: const Text('버그 신고 / 기능 문의'),
          subtitle: const Text('ntec21c@gmail.com'),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const AboutScreen())),
        ),
      ])),
    );
  }
}
