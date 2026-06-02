import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/db_service.dart';
import '../services/hanja_dict.dart';
import '../theme/traditional_theme.dart';
import 'person_card_screen.dart';

/// #17 가계도(Family Tree) — 관계 중심 트리.
/// 중심 인물을 고르면 아버지 / 본인 / 배우자 / 장인(배우자 부친) / 자녀 / 사위 / 사돈을
/// 관계 이름이 적힌 박스로, 위→아래 트리 구조로 선으로 연결해 한 화면에 보여줍니다.
class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});
  @override
  State<FamilyTreeScreen> createState() => _State();
}

class _State extends State<FamilyTreeScreen> {
  List<Person> _persons = [];
  Person? _focus;
  bool _fit = true; // 한 화면에 맞추기 (기본 ON)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DbService.instance.listPersons();
    setState(() {
      _persons = list;
      _focus = list.isNotEmpty ? list.first : null;
    });
  }

  Person? _findById(String? id) {
    if (id == null) return null;
    for (final p in _persons) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 자유 텍스트(자녀/사위/사돈 메모)에서 이름들을 분리.
  List<String> _splitNames(String? note) {
    if (note == null) return const [];
    final parts = note
        .split(RegExp(r'[,、·/\n;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가계도 (家系圖)'),
        actions: [
          IconButton(
            tooltip: _fit ? '확대/이동 모드' : '한 화면에 맞추기',
            icon: Icon(_fit ? Icons.zoom_out_map : Icons.fit_screen),
            onPressed: () => setState(() => _fit = !_fit),
          ),
        ],
      ),
      body: SafeArea(
        child: _persons.isEmpty
            ? const Center(
                child: Text('등록된 인물이 없습니다.',
                    style: TextStyle(color: HanjiColors.mukSoft)))
            : Column(
                children: [
                  _focusPicker(),
                  const Divider(height: 1),
                  Expanded(child: _buildTree()),
                ],
              ),
      ),
    );
  }

  Widget _focusPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Text('중심 인물 ',
              style: TextStyle(
                  color: HanjiColors.ju, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _focus?.id,
              items: _persons
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.nameHanja} (${p.nameHangul})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (id) =>
                  setState(() => _focus = _findById(id) ?? _focus),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTree() {
    final f = _focus;
    if (f == null) return const SizedBox.shrink();

    final father = _findById(f.fatherId);
    final spouseName = (f.spouseHanja != null && f.spouseHanja!.isNotEmpty)
        ? f.spouseHanja!
        : (f.spouseHangul ?? '');
    final fatherInLaw = f.spouseFather; // 장인/장모
    final children = _splitNames(f.childrenNote);
    final sonsInLaw = _splitNames(f.sonsInLawNote);
    final inLaws = _splitNames(f.inLawsNote);

    const vLine = _VLine();

    // 본인 + 배우자 + 장인 (가로 연결)
    final coupleRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _RelBox(
          relation: '본인',
          name: f.nameHanja.isNotEmpty ? f.nameHanja : f.nameHangul,
          highlight: true,
          gender: f.gender,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PersonCardScreen(personId: f.id))),
        ),
        if (spouseName.isNotEmpty) ...[
          const _HLine(),
          _RelBox(relation: '배우자', name: spouseName, gender: 'F'),
        ],
        if (fatherInLaw != null && fatherInLaw.isNotEmpty) ...[
          const _HLine(),
          _RelBox(relation: '장인(배우자 부친)', name: fatherInLaw, gender: 'M'),
        ],
      ],
    );

    // 자녀/사위/사돈 묶음
    final descendants = <_RelSpec>[
      for (var i = 0; i < children.length; i++)
        _RelSpec(_childLabel(i, children.length), children[i], 'M'),
      for (final s in sonsInLaw) _RelSpec('사위', s, 'M'),
      for (final s in inLaws) _RelSpec('사돈', s, 'M'),
    ];

    final tree = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (father != null) ...[
            _RelBox(
              relation: '아버지',
              name:
                  father.nameHanja.isNotEmpty ? father.nameHanja : father.nameHangul,
              gender: 'M',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PersonCardScreen(personId: father.id))),
            ),
            vLine,
          ],
          coupleRow,
          if (descendants.isNotEmpty) ...[
            vLine,
            _DescendantsBus(specs: descendants),
          ],
        ],
      ),
    );

    final scrollable = SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: tree,
      ),
    );

    if (_fit) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: tree,
        ),
      );
    }
    return scrollable;
  }

  String _childLabel(int i, int n) {
    const ord = ['첫째', '둘째', '셋째', '넷째', '다섯째', '여섯째', '일곱째', '여덟째'];
    final o = i < ord.length ? ord[i] : '${i + 1}째';
    return '$o 자녀';
  }
}

class _RelSpec {
  final String relation;
  final String name;
  final String gender;
  _RelSpec(this.relation, this.name, this.gender);
}

/// 자녀/사위/사돈을 가로 버스(수평선)로 연결해 아래로 나열.
class _DescendantsBus extends StatelessWidget {
  final List<_RelSpec> specs;
  const _DescendantsBus({required this.specs});

  @override
  Widget build(BuildContext context) {
    if (specs.length == 1) {
      return _RelBox(
          relation: specs.first.relation,
          name: specs.first.name,
          gender: specs.first.gender);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 수평 버스 라인
        Container(
          height: 2,
          width: (specs.length - 1) * 156.0 + 2,
          color: HanjiColors.muk,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: specs
              .map((s) => SizedBox(
                    width: 156,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _VLine(height: 18),
                        _RelBox(
                            relation: s.relation,
                            name: s.name,
                            gender: s.gender),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _VLine extends StatelessWidget {
  final double height;
  const _VLine({this.height = 24});
  @override
  Widget build(BuildContext context) =>
      Container(width: 2, height: height, color: HanjiColors.muk);
}

class _HLine extends StatelessWidget {
  const _HLine();
  @override
  Widget build(BuildContext context) =>
      Container(width: 18, height: 2, color: HanjiColors.muk);
}

/// 관계 라벨 + 한자(한글) 이름 박스.
class _RelBox extends StatelessWidget {
  final String relation;
  final String name;
  final String? gender;
  final bool highlight;
  final VoidCallback? onTap;
  const _RelBox({
    required this.relation,
    required this.name,
    this.gender,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFemale = gender == 'F';
    final accent = isFemale ? HanjiColors.ju : HanjiColors.muk;
    final annotated = HanjaDict.instance.annotate(name);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: highlight ? HanjiColors.ju.withValues(alpha: 0.10) : HanjiColors.hanjiLight,
          border: Border.all(
              color: accent, width: highlight ? 2.0 : 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(relation,
                  style: const TextStyle(
                      fontSize: 11,
                      color: HanjiColors.hanji,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 6),
            Text(annotated,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: accent,
                    height: 1.25)),
          ],
        ),
      ),
    );
  }
}
