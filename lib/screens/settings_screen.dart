import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/hanja_dict.dart';
import '../theme/traditional_theme.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    DbService.instance.count().then((c) => mounted ? setState(() => _count = c) : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.info_outline, color: HanjiColors.muk),
          title: const Text('앱 정보 / 개발자 / 히스토리'),
          subtitle: const Text('v1.0.0 · Peter S. Choi · ntec21c@gmail.com'),
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
        const ListTile(
          leading: Icon(Icons.lock_outline, color: HanjiColors.cheong),
          title: Text('개인정보 보호'),
          subtitle: Text('모든 데이터는 기기 내부에만 저장되며 외부로 전송되지 않습니다.'),
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
      ]),
    );
  }
}
