import 'dart:io';
import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/hanja_dict.dart';
import '../theme/traditional_theme.dart';
import 'person_card_screen.dart';

class ResultScreen extends StatelessWidget {
  final String rawText;
  final List<Person> persons;
  final String imagePath;
  const ResultScreen(
      {super.key,
      required this.rawText,
      required this.persons,
      required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final hangulText = HanjaDict.instance.toHangul(rawText);
    return Scaffold(
      appBar: AppBar(
        title: Text('인식 결과 (${persons.length}명)'),
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(children: [
            const TabBar(
              tabs: [
                Tab(text: '추출 인물'),
                Tab(text: '한자/한글'),
                Tab(text: '원본 이미지'),
              ],
              labelColor: HanjiColors.muk,
              indicatorColor: HanjiColors.ju,
            ),
            Expanded(
              child: TabBarView(children: [
                _PersonList(persons: persons),
                _TextCompare(hanja: rawText, hangul: hangulText),
                Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    child: Image.file(File(imagePath), fit: BoxFit.contain),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PersonList extends StatelessWidget {
  final List<Person> persons;
  const _PersonList({required this.persons});

  // #3 한자(한글) 표기
  static String _a(String? s) =>
      (s == null || s.trim().isEmpty) ? '' : HanjaDict.instance.annotate(s.trim());

  @override
  Widget build(BuildContext context) {
    if (persons.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              '인물을 자동 추출하지 못했습니다.\n"한자/한글" 탭에서 원본 텍스트를 확인하여\n수동 입력으로 이어가실 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HanjiColors.mukSoft, height: 1.6)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      itemCount: persons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = persons[i];
        final nameLine = p.nameHanja.isNotEmpty
            ? '${HanjaDict.instance.annotate(p.nameHanja)}'
            : p.nameHangul;
        return Card(
          child: ListTile(
            title: Text(nameLine,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text([
              if (p.ja != null) '字 ${_a(p.ja)}',
              if (p.birthDateLunar != null) '生 ${p.birthDateLunar}',
              if (p.birthPlace != null) '生地 ${_a(p.birthPlace)}',
              if (p.marriageDate != null) '婚 ${p.marriageDate}',
              if (p.spouseHanja != null) '配 ${_a(p.spouseHanja)}',
              if (p.spouseFather != null) '配父 ${_a(p.spouseFather)}',
              if (p.deathDateLunar != null) '卒 ${p.deathDateLunar}',
              if (p.burialPlace != null) '墓 ${_a(p.burialPlace)}',
              if (p.childrenNote != null) '子女 ${_a(p.childrenNote)}',
              if (p.sonsInLawNote != null) '婿 ${_a(p.sonsInLawNote)}',
              if (p.inLawsNote != null) '査頓 ${_a(p.inLawsNote)}',
            ].where((s) => s.trim().isNotEmpty).join('\n'),
                style: const TextStyle(height: 1.5, fontSize: 12)),
            trailing: const Icon(Icons.edit_note),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PersonCardScreen(personId: p.id))),
          ),
        );
      },
    );
  }
}

class _TextCompare extends StatelessWidget {
  final String hanja;
  final String hangul;
  const _TextCompare({required this.hanja, required this.hangul});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(
                right: BorderSide(color: HanjiColors.mukSoft, width: 0.5)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('原文 (한자)',
                    style: TextStyle(color: HanjiColors.ju, fontWeight: FontWeight.bold)),
                const Divider(),
                SelectableText(hanja, style: const TextStyle(fontSize: 16, height: 1.8)),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('한글 음',
                    style: TextStyle(color: HanjiColors.ju, fontWeight: FontWeight.bold)),
                const Divider(),
                SelectableText(hangul, style: const TextStyle(fontSize: 16, height: 1.8)),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}
