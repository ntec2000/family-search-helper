import 'dart:io';
import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/hanja_dict.dart';
import '../services/db_service.dart';
import '../services/parent_child_review.dart';
import '../theme/traditional_theme.dart';
import '../widgets/surname_input_dialog.dart';
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
  bool _saved = false;
  bool _saving = false;
  bool _largeText = false;
  bool _showReviewGuide = false;
  final TransformationController _imageTransform = TransformationController();
  final List<(Person, int, List<(String, String)>)> _excluded = [];

  @override
  void initState() {
    super.initState();
    _persons = widget.persons.map((person) => Person.fromMap(person.toMap())).toList();
  }

  @override
  void dispose() {
    _imageTransform.dispose();
    super.dispose();
  }

  void _resetImageZoom() {
    _imageTransform.value = Matrix4.identity();
  }

  Future<void> _deletePerson(Person person) async {
    if (_saved || _saving) return;
    final index = _persons.indexOf(person);
    if (index < 0) return;
    setState(() {
      final links = <(String, String)>[];
      for (final other in _persons) {
        if (other.id == person.id) continue;
        if (other.fatherId == person.id || other.motherId == person.id) {
          links.add((person.id, other.id));
        }
        if (person.fatherId == other.id || person.motherId == other.id) {
          links.add((other.id, person.id));
        }
      }
      _excluded.add((person, index, links));
      ParentChildReview.detachExcluded(person, _persons);
      _persons.removeAt(index);
    });
  }

  void _restoreLastExcluded() {
    if (_saved || _saving || _excluded.isEmpty) return;
    final (person, index, links) = _excluded.removeLast();
    setState(() {
      _persons.insert(index.clamp(0, _persons.length), person);
      for (final (parentId, childId) in links) {
        final parents = _persons.where((p) => p.id == parentId);
        final children = _persons.where((p) => p.id == childId);
        if (parents.isEmpty || children.isEmpty) continue;
        final parent = parents.first;
        final child = children.first;
        if (ParentChildReview.conflict(parent, child) == null) {
          ParentChildReview.restoreReviewedLink(parent, child);
        }
      }
    });
  }

  Future<void> _editCandidate(Person person) async {
    if (_saved || _saving) return;
    final hanja = TextEditingController(text: person.nameHanja);
    final hangul = TextEditingController(text: person.nameHangul);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이름 후보 수정'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: hanja,
              decoration: const InputDecoration(labelText: '한자 이름')),
          TextField(controller: hangul,
              decoration: const InputDecoration(labelText: '한글 이름')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx,
              [hanja.text.trim(), hangul.text.trim()]),
              child: const Text('적용')),
        ],
      ),
    );
    if (result != null && mounted && !_saved && !_saving && _persons.contains(person)) {
      setState(() {
        person.nameHanja = result[0];
        person.nameHangul = result[1];
        person.updatedAt = DateTime.now();
      });
    }
    hanja.dispose();
    hangul.dispose();
  }

  Future<void> _chooseParent(Person child) async {
    if (_saved || _saving) return;
    final options = _persons.where((p) => p.id != child.id).toList();
    if (options.isEmpty) return;
    final parent = await showDialog<Person>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('원문을 확인한 부모 선택'),
        children: options.map((p) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, p),
          child: Text('${p.nameHanja} ${p.nameHangul} (${p.sega ?? "세대 미상"}世)'),
        )).toList(),
      ),
    );
    if (parent == null || !mounted) return;
    final error = ParentChildReview.conflict(parent, child);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => ParentChildReview.applyReviewedLink(parent, child));
  }

  void _clearParentLinks(Person child) {
    if (_saved || _saving) return;
    setState(() {
      for (final parent in _persons) {
        ParentChildReview.unlink(parent, child);
      }
    });
  }

  Future<void> _saveReviewedPersons() async {
    if (_saved || _saving) return;
    setState(() => _saving = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('검토한 인물 저장 확인'),
        content: Text('인물 ${_persons.length}명과 확인된 가족관계를 저장하시겠습니까? 원본 이미지와 OCR 원문은 변경하지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _saving = false);
      return;
    }
    try {
      for (final person in _persons) {
        await DbService.instance.upsertPerson(person);
      }
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('검토한 인물 ${_persons.length}명을 저장했습니다.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중 오류가 발생했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _addPerson() async {
    if (_saved || _saving) return;
    final now = DateTime.now();
    final np = Person(
      id: 'manual_${now.millisecondsSinceEpoch}',
      sourceImagePath: widget.imagePath,
      createdAt: now,
      updatedAt: now,
    );
    if (!mounted) return;
    setState(() => _persons.add(np));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('새 인물 후보를 추가했습니다. 저장 후 수정할 수 있습니다.')),
    );
  }

  /// v2.6(#7) — 성을 알 수 없는 인물에 성씨(한글+한자)를 수동 적용한다.
  /// 입력한 성씨를 족보의 기본 성으로 삼아, 성이 없는 모든 인물(자녀 포함)에
  /// 적용하고 DB 에 저장한다. 화면의 이름 표기는 \"성+이름\" 으로 갱신된다.
  Future<void> _applySurname() async {
    if (_saved || _saving) return;
    final entered = await showSurnameInputDialog(context);
    if (entered == null || !mounted || _saved || _saving) return;
    final sHanja = entered.$1, sHangul = entered.$2;
    var applied = 0;
    for (final p in _persons) {
      final noHanja = (p.surnameHanja ?? '').isEmpty;
      final noHangul = (p.surnameHangul ?? '').isEmpty;
      if (noHanja || noHangul) {
        if (noHanja && sHanja.isNotEmpty) p.surnameHanja = sHanja;
        if (noHangul && sHangul.isNotEmpty) p.surnameHangul = sHangul;
        p.updatedAt = DateTime.now();
        // 검토 전 후보는 데이터베이스에 저장하지 않습니다.
        applied++;
      }
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(applied == 0
              ? '성씨를 적용할 인물이 없습니다.'
              : '성씨 ${sHangul}${sHanja.isNotEmpty ? '($sHanja)' : ''} 을(를) $applied명에 적용했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hangulText = HanjaDict.instance.toHangul(widget.rawText);
    return Scaffold(
      appBar: AppBar(
        title: Text('인식 결과 (${_persons.length}명)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline),
            tooltip: '성씨 입력 (성 미상 인물에 적용)',
            onPressed: _saved || _saving ? null : _applySurname,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: '마지막 제외 후보 복원',
            onPressed: _saved || _saving || _excluded.isEmpty ? null : _restoreLastExcluded,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: '인물 추가',
            onPressed: _saved || _saving ? null : _addPerson,
          ),
        ],
      ),
      floatingActionButton: _saved ? null : FloatingActionButton.extended(
        onPressed: _saving ? null : _saveReviewedPersons,
        icon: const Icon(Icons.save),
        label: Text(_saving ? '저장 중...' : '검토한 인물 저장'),
      ),
      body: SafeArea(
        child: DefaultTabController(
          length: 3,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: HanjiColors.hanjiLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HanjiColors.hanjiDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('족보 원문 대조 · 인물 검토',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                            color: HanjiColors.muk)),
                    const SizedBox(height: 8),
                    Text('검토 대상 ${_persons.length}명  ·  제외 ${_excluded.length}명',
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: HanjiColors.ju)),
                    TextButton.icon(
                      onPressed: () => setState(() => _showReviewGuide = !_showReviewGuide),
                      icon: Icon(_showReviewGuide ? Icons.expand_less : Icons.expand_more),
                      label: Text(_showReviewGuide ? '검토 안내 접기' : '검토 안내 펼치기'),
                    ),
                    if (_showReviewGuide)
                      const Text('원본 이미지와 한자 OCR을 대조한 뒤 이름과 가족관계를 확인하세요. '
                        '인물이 아닌 후보는 제외할 수 있으며 저장 전까지 데이터베이스에 반영되지 않습니다.',
                        style: TextStyle(fontSize: 13, height: 1.5,
                            color: HanjiColors.mukSoft)),
                  ],
                ),
              ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const Icon(Icons.format_size, size: 19,
                    color: HanjiColors.mukSoft),
                const SizedBox(width: 8),
                const Expanded(child: Text('큰 글씨로 인물 확인',
                    style: TextStyle(fontSize: 14))),
                Switch(
                  value: _largeText,
                  onChanged: (value) => setState(() => _largeText = value),
                ),
              ]),
            ),
            Builder(builder: (tabContext) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                Expanded(child: TextButton.icon(
                  onPressed: () => DefaultTabController.of(tabContext).animateTo(2),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('원본 족보 보기'),
                )),
                Expanded(child: TextButton.icon(
                  onPressed: () => DefaultTabController.of(tabContext).animateTo(0),
                  icon: const Icon(Icons.people_outline),
                  label: const Text('인물 검토로 이동'),
                )),
              ]),
            )),
            if (_imageTransform.value.getMaxScaleOnAxis() > 1.01)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _resetImageZoom,
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('이미지 확대 초기화'),
                ),
              ),
            Expanded(
              child: TabBarView(children: [
                _PersonList(persons: _persons, onDelete: _deletePerson, onEdit: _editCandidate, onParent: _chooseParent, onUnlink: _clearParentLinks, saved: _saved || _saving, largeText: _largeText),
                _TextCompare(hanja: widget.rawText, hangul: hangulText),
                Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    transformationController: _imageTransform,
                    minScale: 1.0,
                    maxScale: 8.0,
                    panEnabled: true,
                    onInteractionEnd: (_) => setState(() {}),
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
  final Future<void> Function(Person) onEdit;
  final Future<void> Function(Person) onParent;
  final void Function(Person) onUnlink;
  final bool saved;
  final bool largeText;
  const _PersonList({required this.persons, required this.onDelete, required this.onEdit, required this.onParent, required this.onUnlink, required this.saved, required this.largeText});

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
    final generationCounts = <int?, int>{};
    for (final person in persons) {
      generationCounts.update(person.sega, (n) => n + 1, ifAbsent: () => 1);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: persons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = persons[i];
        final isFemale = p.gender == 'F';
        // v2.6(#7) — 아들은 \"성+이름\" 으로 합쳐 표기 (성씨가 있으면).
        final sHanja = p.surnameHanja ?? '';
        var fullHanja = p.nameHanja;
        if (!isFemale &&
            sHanja.isNotEmpty &&
            p.nameHanja.isNotEmpty &&
            !p.nameHanja.startsWith(sHanja)) {
          fullHanja = sHanja + p.nameHanja;
        }
        final sHangul = p.surnameHangul ?? '';
        final fullHangul = (!isFemale &&
                sHangul.isNotEmpty &&
                p.nameHangul.isNotEmpty &&
                !p.nameHangul.startsWith(sHangul))
            ? sHangul + p.nameHangul
            : p.nameHangul;
        // v3.0.1 — 형제 순서 라벨은 아들에게는 표시하지 않고(이름만), 딸은
        //          이름이 없으므로 '첫째딸/둘째딸'을 식별자로 사용한다.
        final segaPrefix = p.sega != null ? '[${p.sega}世] ' : '';
        final String nameLine;
        if (isFemale) {
          final ord = (p.relation ?? '').isNotEmpty ? p.relation! : '딸';
          final nm = p.nameHangul.trim().isNotEmpty ? p.nameHangul.trim() : (p.nameHanja.trim().isNotEmpty ? p.nameHanja.trim() : (sHangul.isNotEmpty ? '$sHangul씨 (개인 이름 미상)' : '이름 미상'));
          nameLine = '$segaPrefix$ord (이름: $nm)';
        } else if (p.nameHanja.isNotEmpty) {
          final nm = fullHangul.isNotEmpty ? fullHangul : p.nameHanja;
          nameLine = '$segaPrefix${p.nameHanja} (이름: $nm)';
        } else {
          nameLine = '$segaPrefix${fullHangul.isEmpty ? '(이름 미상)' : fullHangul}';
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i == 0 || persons[i - 1].sega != p.sega)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
                child: Row(children: [
                  const Icon(Icons.account_tree_outlined, size: 18,
                      color: HanjiColors.ju),
                  const SizedBox(width: 8),
                  Text(p.sega == null ? '세대 미확인' : '${p.sega}세대',
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HanjiColors.muk)),
                  const Spacer(),
                  Text('전체 ${generationCounts[p.sega]}명',
                      style: const TextStyle(fontSize: 13,
                          color: HanjiColors.mukSoft)),
                ]),
              ),
            Card(
          child: ListTile(
            title: Text(nameLine,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: largeText ? 21 : 16, height: 1.4)),
            subtitle: Text([
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
                style: TextStyle(height: 1.55, fontSize: largeText ? 17 : 12)),
            trailing: PopupMenuButton<String>(
              tooltip: '인물 작업 메뉴',
              icon: const Icon(Icons.more_vert),
              onSelected: (action) {
                switch (action) {
                  case 'parent':
                    onParent(p);
                    break;
                  case 'unlink':
                    onUnlink(p);
                    break;
                  case 'edit':
                    if (saved) {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PersonCardScreen(personId: p.id)));
                    } else {
                      onEdit(p);
                    }
                    break;
                  case 'exclude':
                    onDelete(p);
                    break;
                }
              },
              itemBuilder: (_) => [
                if (!saved)
                  const PopupMenuItem(value: 'parent',
                      child: ListTile(leading: Icon(Icons.account_tree_outlined),
                          title: Text('부모 관계 연결'))),
                if (!saved && (p.fatherId != null || p.motherId != null))
                  const PopupMenuItem(value: 'unlink',
                      child: ListTile(leading: Icon(Icons.link_off),
                          title: Text('부모 연결 해제'))),
                PopupMenuItem(value: 'edit',
                    child: ListTile(leading: const Icon(Icons.edit_note),
                        title: Text(saved ? '인물 상세 보기' : '이름 수정'))),
                if (!saved)
                  const PopupMenuItem(value: 'exclude',
                      child: ListTile(leading: Icon(Icons.person_remove_outlined),
                          title: Text('인물 후보 제외'))),
              ],
            ),
            onTap: saved ? () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PersonCardScreen(personId: p.id))) : null,
          ),
            ),
          ],
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

