import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/db_service.dart';
import '../services/gedcom_export.dart';
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

  Future<void> _exportText() async {
    final list = await DbService.instance.listPersons();
    final buf = StringBuffer();
    for (final p in list) {
      buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━');
      buf.writeln('${p.nameHangul} ${p.nameHanja} ${p.nameRoman}');
      buf.writeln('성별: ${p.gender == 'M' ? '남' : '여'}');
      if (p.bongwan != null) buf.writeln('本貫: ${p.bongwan}');
      if (p.ja != null) buf.writeln('字: ${p.ja}');
      if (p.birthDateSolar != null || p.birthDateLunar != null) {
        buf.writeln('출생: ${p.birthDateSolar ?? ''} ${p.birthDateLunar ?? ''} ${p.birthPlace ?? ''}');
      }
      if (p.marriageDate != null || p.spouseHanja != null) {
        buf.writeln('결혼: ${p.marriageDate ?? ''} / 배우자: ${p.spouseHanja ?? ''}');
      }
      if (p.deathDateSolar != null || p.deathDateLunar != null) {
        buf.writeln('사망: ${p.deathDateSolar ?? ''} ${p.deathDateLunar ?? ''} ${p.deathPlace ?? ''}');
      }
      if (p.burialPlace != null) buf.writeln('매장: ${p.burialPlace}');
      buf.writeln();
    }
    await Share.share(buf.toString(), subject: '가족역사기록');
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
                subtitle: const Text('복사·붙여넣기로 가족역사기록서에 입력'),
                trailing: const Icon(Icons.share),
                onTap: _exportText,
              ),
            ),
            const SizedBox(height: 32),
            const Text('② FamilySearch 직접 동기화 (로그인 필요)',
                style: TextStyle(fontWeight: FontWeight.bold, color: HanjiColors.ju)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_upload, color: HanjiColors.ju),
                title: const Text('FamilySearch.org 직접 업로드'),
                subtitle: Text(FamilySearchService.isLoggedIn
                    ? '로그인됨 — 인물 등록 가능'
                    : 'LDS 회원 계정 로그인 필요'),
                trailing: const Icon(Icons.upload),
                onTap: _busy ? null : _syncFamilySearch,
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
