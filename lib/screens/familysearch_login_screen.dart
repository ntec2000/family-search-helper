import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/familysearch_service.dart';
import '../theme/traditional_theme.dart';

/// FamilySearch 로그인 안내 화면.
///
/// 외부 OAuth 흐름:
///   1) authorizationUrl() 을 브라우저(혹은 in-app webview)로 열기
///   2) 사용자가 LDS 계정 로그인 후 redirectUri 로 code 받기
///   3) exchangeCode(code) 호출하여 access_token 저장
///
/// 본 화면은 안내 + 수동 code 입력 옵션을 제공합니다.
/// (PKCE/Deep Link 자동 처리를 원하시면 flutter_appauth 패키지 도입 권장)
class FamilySearchLoginScreen extends StatefulWidget {
  const FamilySearchLoginScreen({super.key});
  @override
  State<FamilySearchLoginScreen> createState() => _State();
}

class _State extends State<FamilySearchLoginScreen> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String _status = '';
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    if (FamilySearchService.isLoggedIn) _loadMe();
  }

  Future<void> _loadMe() async {
    final u = await FamilySearchService.currentUser();
    if (mounted) setState(() => _user = u);
  }

  void _copyAuthUrl() {
    Clipboard.setData(ClipboardData(text: FamilySearchService.authorizationUrl().toString()));
    setState(() => _status = '로그인 URL이 클립보드에 복사되었습니다. 브라우저에 붙여넣어 로그인하세요.');
  }

  Future<void> _exchange() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    final ok = await FamilySearchService.exchangeCode(_codeCtrl.text.trim());
    if (ok) {
      await _loadMe();
      setState(() => _status = '로그인 성공');
    } else {
      setState(() => _status = '로그인 실패. Code 를 다시 확인하세요.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FamilySearch 연동')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 48), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HanjiColors.hanjiLight,
            border: Border.all(color: HanjiColors.mukSoft, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FamilySearch.org 연동은 선택사항입니다.',
                  style: TextStyle(fontWeight: FontWeight.bold, color: HanjiColors.ju)),
              const SizedBox(height: 8),
              const Text(
                '• 로그인 없이도 GEDCOM/텍스트 내보내기로 FamilySearch에 수동 업로드 가능합니다.\n'
                '• 직접 동기화를 원하시면 LDS 회원 계정(FamilySearch.org)으로 로그인하세요.\n'
                '• 본 앱은 토큰을 기기 내부에만 보관하며 외부로 전송하지 않습니다.',
                style: TextStyle(height: 1.6, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_user != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified, color: HanjiColors.cheong),
              title: Text('로그인됨: ${_user!['users']?[0]?['contactName'] ?? '?'}'),
              subtitle: const Text('FamilySearch.org'),
              trailing: TextButton(
                onPressed: () {
                  FamilySearchService.logout();
                  setState(() => _user = null);
                },
                child: const Text('로그아웃'),
              ),
            ),
          ),
        ] else ...[
          const Text('① 로그인 URL 복사 → 브라우저 열기',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _copyAuthUrl,
            icon: const Icon(Icons.link),
            label: const Text('FamilySearch 로그인 URL 복사'),
          ),
          const SizedBox(height: 24),
          const Text('② 로그인 후 redirect 된 URL 의 code 파라미터 입력',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _codeCtrl,
            decoration: const InputDecoration(
              labelText: 'Authorization Code',
              border: OutlineInputBorder(),
              hintText: '예: abc123...',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : _exchange,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('로그인'),
          ),
        ],
        if (_status.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_status,
                style: const TextStyle(color: HanjiColors.ju)),
          ),
        const SizedBox(height: 32),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.help_outline),
          title: Text('개발자 키 발급'),
          subtitle: Text(
              'https://www.familysearch.org/developers 에서 무료 등록 후 Client ID를 앱에 등록해야 합니다.',
              style: TextStyle(fontSize: 12)),
        ),
      ])),
    );
  }
}
