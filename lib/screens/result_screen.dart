import 'dart:io';
import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/hanja_dict.dart';
import '../services/db_service.dart';
import '../theme/traditional_theme.dart';
import 'person_card_screen.dart';

class ResultScreen extends StatefulWidget {
  final String rawText;
  final List<Person> persons;
  final String imagePath;
  const ResultScreen(
      {super.key,
      required this.rawText,
      required this.persons,
      required this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final List<Person> _persons;

  @override
  void initState() {
    super.initState();
    _persons = List<Person>.from(widget.persons);
  }

  /// v2.4 — 인물이 아닌 항목(오인식·제목 등) 삭제. DB 와 목록에서 함께 제거한다.
  Future<void> _deletePerson(Person p) async {
    final label = p.nameHanja.isNotEmpty
        ? HanjaDict.instance.annotate(p.nameHanja)
        : (p.spouseHanja != null
            ? '딸(사위 ${p.spouseHanja})'
            : '${p.surnameHangul ?? ''}씨');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('항목 삭제'),
        content: Text('"$label" 항목을 삭제할까요?\n사람 이름이 아닌 경우에만 삭제하세요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DbService.instance.deletePerson(p.id);
    } catch (_) {/* 미저장 항목이면 무시 */}
    if (!mounted) return;
    setState(() => _persons.remove(p));
  }

  Future<void> _addPerson() async {
    final now = DateTime.now();
    final np = Person(
      id: 'manual_${now.millisecondsSinceEpoch}',
      sourceImagePath: widget.imagePath,
      createdAt: now,
      updatedAt: now,
    );
    await DbService.instance.upsertPerson(np);
    if (!mounted) return;
    setState(() => _persons.add(np));
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PersonCardScreen(personId: np.id)));
  }

  @override
  Widget build(BuildContext context) {
    final hangulText = HanjaDict.instance.toHangul(widget.rawText);
    return Scaffold(
      appBar: AppBar(
        title: Text('인식 결과 (${_persons.length}명)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: '인물 추가',
            onPressed: _addPerson,
          ),
        ],
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                  '사람 이름이 아닌 항목은 오른쪽 🗑 버튼으로 삭제하세요. 인물만 남기면 됩니다.',
                  style: TextStyle(fontSize: 12, color: HanjiColors.mukSoft)),
            ),
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
                _PersonList(persons: _persons, onDelete: _deletePerson),
                _TextCompare(hanja: widget.rawText, hangul: hangulText),
                Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 6.0,
                    panEnabled: true,
                    child:
                        Image.file(File(widget.imagePath), fit: BoxFit.contain),
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
  final Future<void> Function(Person) onDelete;
  const _PersonList({required this.persons, required this.onDelete});

  // 한자(한글) 표기
  static String _a(String? s) =>
      (s == null || s.trim().isEmpty) ? '' : HanjaDict.instance.annotate(s.trim());

  @override
  Widget build(BuildContext context) {
    if (persons.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              '인물이 없습니다.\n"한자/한글" 탭에서 원본 텍스트를 확인하여\n수동 입력으로 이어가실 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HanjiColors.mukSoft, height: 1.6)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
      itemCount: persons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = persons[i];
        final isFemale = p.gender == 'F';
        final nameLine = p.nameHanja.isNotEmpty
            ? HanjaDict.instance.annotate(p.nameHanja)
            : (isFemale
                ? '${p.surnameHangul ?? ''}씨 (딸)'
                : (p.nameHangul.isEmpty ? '(이름 미상)' : p.nameHangul));
        return Card(
          child: ListTile(
            title: Text(nameLine,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text([
              if (p.sega != null) '${p.sega}世',
              if (p.ja != null) '字 ${_a(p.ja)}',
              if (p.birthDateLunar != null) '生 ${p.birthDateLunar}',
              if (p.birthPlace != null) '生地 ${_a(p.birthPlace)}',
              if (p.deathDateLunar != null) '卒 ${p.deathDateLunar}',
              if (p.burialPlace != null) '墓 ${_a(p.burialPlace)}',
              if (p.spouseHanja != null)
                (isFemale ? '夫(사위) ' : '配 ') + _a(p.spouseHanja) +
                    (p.spouseBongwan != null ? ' (${_a(p.spouseBongwan)})' : ''),
              if (!isFemale && p.spouseFather != null) '聘父(장인) ${_a(p.spouseFather)}',
              if (!isFemale && p.spouseGrandfather != null) '聘祖 ${_a(p.spouseGrandfather)}',
              if (!isFemale && p.spouseGreatGrandfather != null) '聘曾祖 ${_a(p.spouseGreatGrandfather)}',
              if (!isFemale && p.spouseMaternalGrandfather != null) '聘外祖 ${_a(p.spouseMaternalGrandfather)}',
              if (p.note != null) '※ ${p.note}',
            ].where((s) => s.trim().isNotEmpty).join('\n'),
                style: const TextStyle(height: 1.5, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_note),
                  tooltip: '수정',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PersonCardScreen(personId: p.id))),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  tooltip: '인물 아님 → 삭제',
                  onPressed: () => onDelete(p),
                ),
              ],
            ),
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
