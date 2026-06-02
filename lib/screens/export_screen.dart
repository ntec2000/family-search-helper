import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/person.dart';
import '../services/db_service.dart';
import '../services/gedcom_export.dart';
import '../services/hanja_dict.dart';
import '../services/familysearch_service.dart';
import '../theme/traditional_theme.dart';
import 'familysearch_login_screen.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});
  @override
  State<ExportScreen> createState() => _State();
}

class _State extends State<ExportScreen> {
  bool _busy = false;
  String _status = '';

  Future<void> _exportGedcom() async {
    final list = await DbService.instance.listPersons();
    final ged = GedcomExport.toGedcom(list);
    final dir = await getTemporaryDirectory();
    final f = File(path.join(dir.path,
        'family_${DateTime.now().millisecondsSinceEpoch}.ged'));
    await f.writeAsString(ged);
    await Share.shareXFiles([XFile(f.path)],
        subject: '가족역사기록 GEDCOM');
  }

  /// 한자 → "한글 (한자)" 표기. 한자가 비어있으면 빈 문자열.
  static String _kh(String? hanja) {
    if (hanja == null || hanja.trim().isEmpty) return '';
    final h = HanjaDict.instance.toHangul(hanja);
    return h == hanja ? hanja : '$h ($hanja)';
  }

  /// #15 보기 좋게 정렬된 텍스트 생성.
  String _buildText(List<Person> list) {
    final buf = StringBuffer();
    buf.writeln('가족역사기록');
    buf.writeln();
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      // 이름: 한글 한자
      final name = [p.nameHangul, p.nameHanja]
          .where((s) => s.trim().isNotEmpty)
          .join(' ');
      buf.writeln('━━━━━━━━━━━━━━━━━━━━');
      buf.writeln('${i + 1}. $name');
      buf.writeln('  성별   : ${p.gender == 'M' ? '남' : p.gender == 'F' ? '여' : '미상'}');
      if (p.bongwan != null) buf.writeln('  본관   : ${_kh(p.bongwan)}');
      if (p.ja != null) buf.writeln('  字(자) : ${_kh(p.ja)}');
      if (p.ho != null) buf.writeln('  號(호) : ${_kh(p.ho)}');
      final birth = [
        p.birthDateSolar,
        p.birthDateLunar,
        p.birthPlace,
      ].where((s) => s != null && s.isNotEmpty).join(' · ');
      if (birth.isNotEmpty) buf.writeln('  출생   : $birth');
      if (p.marriageDate != null || p.spouseHanja != null) {
        buf.writeln(
            '  결혼   : ${p.marriageDate ?? ''} / 배우자: ${_kh(p.spouseHanja)}'
                .replaceAll(RegExp(r'\s+/'), ' /'));
      }
      final death = [
        p.deathDateSolar,
        p.deathDateLunar,
        p.deathPlace,
      ].where((s) => s != null && s.isNotEmpty).join(' · ');
      if (death.isNotEmpty) buf.writeln('  사망   : $death');
      if (p.burialPlace != null) {
        final ori = p.burialOrientation != null ? ' (${p.burialOrientation})' : '';
        buf.writeln('  매장   : ${p.burialPlace}$ori');
      }
      if (p.childrenNote != null) buf.writeln('  자녀   : ${p.childrenNote}');
      if (p.sonsInLawNote != null) buf.writeln('  사위   : ${p.sonsInLawNote}');
      if (p.inLawsNote != null) buf.writeln('  사돈   : ${p.inLawsNote}');
      buf.writeln();
    }
    return buf.toString();
  }

  Future<void> _exportText() async {
    final list = await DbService.instance.listPersons();
    await Share.share(_buildText(list), subject: '가족역사기록');
  }

  void _previewText() async {
    final list = await DbService.instance.listPersons();
    final text = _buildText(list);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('내보내기 미리보기'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(text,
                style: const TextStyle(fontSize: 13, height: 1.6)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Share.share(text, subject: '가족역사기록');
            },
            icon: const Icon(Icons.share),
            label: const Text('공유'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncFamilySearch() async {
    if (!FamilySearchService.isLoggedIn) {
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => const FamilySearchLoginScreen()));
      if (!FamilySearchService.isLoggedIn) return;
    }
    setState(() {
      _busy = true;
      _status = 'FamilySearch 로 인물 동기화 중...';
    });
    final list = await DbService.instance.listPersons();
    int ok = 0, fail = 0;
    for (final p in list) {
      final id = await FamilySearchService.createPerson(p);
      if (id != null) {
        ok++;
        setState(() => _status = '진행 중: $ok명 등록 / 전체 ${list.length}명');
      } else {
        fail++;
      }
    }
    setState(() {
      _busy = false;
      _status = '완료: 성공 $ok명 / 실패 $fail명';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내보내기 / 동기화')),
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('① 파일로 내보내기 (로그인 불필요)',
                style: TextStyle(fontWeight: FontWeight.bold, color: HanjiColors.ju)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_tree, color: HanjiColors.muk),
                title: const Text('GEDCOM 5.5.1 (.ged)'),
                subtitle: const Text('FamilySearch · Ancestry · MyHeritage 호환'),
                trailing: const Icon(Icons.download),
                onTap: _exportGedcom,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.text_snippet, color: HanjiColors.muk),
                title: const Text('텍스트 (수동 입력용)'),
                subtitle: const Text('정렬된 텍스트 · 字/배우자 한글 표기 · 복사·공유'),
                trailing: const Icon(Icons.visibility),
                onTap: _previewText,
              ),
            ),
            const SizedBox(height: 32),
            const Text('② FamilySearch 직접 동기화',
                style: TextStyle(fontWeight: FontWeight.bold, color: HanjiColors.ju)),
            const SizedBox(height: 8),
            if (FamilySearchService.enabled)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload, color: HanjiColors.ju),
                  title: const Text('FamilySearch.org 직접 업로드'),
                  subtitle: Text(!FamilySearchService.isConfigured
                      ? 'Client ID 미입력 — 설정에서 입력하세요'
                      : (FamilySearchService.isLoggedIn
                          ? '로그인됨 — 인물 등록 가능'
                          : 'LDS 회원 계정 로그인 필요')),
                  trailing: const Icon(Icons.upload),
                  onTap: (_busy || !FamilySearchService.isConfigured)
                      ? null
                      : _syncFamilySearch,
                ),
              )
            else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.cloud_off, color: HanjiColors.muk),
                  title: Text('FamilySearch 연동 꺼짐'),
                  subtitle: Text('설정 → FamilySearch 연동에서 켜면 사용할 수 있습니다.'),
                ),
              ),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_status,
                    style: const TextStyle(color: HanjiColors.ju)),
              ),
          ],
        ),
        if (_busy)
          Container(
            color: Colors.black54,
            child: const Center(
                child: CircularProgressIndicator(color: HanjiColors.hanji)),
          ),
      ]),
    );
  }
}
