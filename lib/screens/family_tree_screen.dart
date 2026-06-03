import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/db_service.dart';
import '../services/hanja_dict.dart';
import '../services/genealogy.dart';
import '../theme/traditional_theme.dart';
import 'person_card_screen.dart';

/// #17 / v2.2 가계도(Family Tree) — 아버지(중심)를 기준으로 자녀를 아래에 연결.
/// · 아들: 성|이름 두 칸 + 로마자 두 칸
/// · 딸(이름 없음): "○씨" 한 칸
/// · 장인 옆에 장모, 자녀(딸) 아래 사위·사돈·사돈부인 연결
/// · 자녀는 출생연도순(첫째·둘째) 정렬, 아들/딸 구분
/// · 박스를 탭하면 인물카드로 이동 (이름→레코드 자동 매칭)
class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});
  @override
  State<FamilyTreeScreen> createState() => _State();
}

class _State extends State<FamilyTreeScreen> {
  List<Person> _persons = [];
  Person? _focus;
  bool _fit = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DbService.instance.listPersons();
    setState(() {
      _persons = list;
      // 중심 인물 = 자녀가 있는 아버지를 우선
      _focus = list.firstWhere(
        (p) => (p.childrenNote ?? '').isNotEmpty,
        orElse: () => list.isNotEmpty ? list.first : _empty(),
      );
      if (list.isEmpty) _focus = null;
    });
  }

  Person _empty() => Person(id: '');

  Person? _findById(String? id) {
    if (id == null) return null;
    for (final p in _persons) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 이름(한자/한글) 으로 실제 인물 레코드 매칭 (ID 연결).
  Person? _matchByName(String hanja, String hangul) {
    for (final p in _persons) {
      if (hanja.isNotEmpty &&
          (p.nameHanja == hanja ||
              (p.surnameHanja ?? '') + (p.nameHanja) == hanja)) {
        return p;
      }
      if (hangul.isNotEmpty && p.nameHangul == hangul) return p;
    }
    return null;
  }

  List<String> _splitNames(String? note) {
    if (note == null) return const [];
    return note
        .split(RegExp(r'[,、·/\n;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 중심 인물(아버지)의 성(姓) — 자녀 상속용.
  (String, String) _focusSurname(Person f) {
    final np = Genealogy.split(
      hanja: f.nameHanja,
      hangul: f.nameHangul.isNotEmpty
          ? f.nameHangul
          : HanjaDict.instance.toHangul(f.nameHanja),
      surnameHanja: f.surnameHanja,
      surnameHangul: f.surnameHangul,
    );
    return (np.surnameHanja, np.surnameHangul);
  }

  /// 토큰 → 표시 스펙(성 분리·성별·정렬연도·매칭ID).
  _ChildSpec _buildChild(String token, String fbHanja, String fbHangul) {
    final parsed = Genealogy.parseToken(token);
    var hanja = parsed.$1;
    var hangul = parsed.$2;
    if (hangul.isEmpty && hanja.isNotEmpty) {
      hangul = HanjaDict.instance.toHangul(hanja);
    }
    final matched = _matchByName(hanja, hangul);
    final isFemale = matched?.gender == 'F' ||
        hangul.endsWith('씨') ||
        hanja.endsWith('氏');
    final np = Genealogy.split(
      hanja: hanja,
      hangul: hangul,
      surnameHanja: matched?.surnameHanja,
      surnameHangul: matched?.surnameHangul,
      fallbackSurnameHanja: fbHanja,
      fallbackSurnameHangul: fbHangul,
      isFemale: isFemale,
    );
    final year = Genealogy.yearOf(matched?.birthDateSolar);
    return _ChildSpec(
      parts: np,
      isFemale: isFemale,
      birthYear: year,
      personId: matched?.id,
      rawHangul: hangul,
      rawHanja: hanja,
    );
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
          const Text('중심(아버지) ',
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
                        child: Text('${p.nameHanja} (${p.nameHangul})',
                            overflow: TextOverflow.ellipsis),
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
    final (fbHanja, fbHangul) = _focusSurname(f);

    // 본인(아버지)
    final selfParts = Genealogy.split(
      hanja: f.nameHanja,
      hangul: f.nameHangul.isNotEmpty
          ? f.nameHangul
          : HanjaDict.instance.toHangul(f.nameHanja),
      surnameHanja: f.surnameHanja,
      surnameHangul: f.surnameHangul,
    );

    // 배우자(부인)
    Widget? spouseBox;
    final spHanja = f.spouseHanja ?? '';
    final spHangul = (f.spouseHangul != null && f.spouseHangul!.isNotEmpty)
        ? f.spouseHangul!
        : HanjaDict.instance.toHangul(spHanja);
    if (spHanja.isNotEmpty || spHangul.isNotEmpty) {
      final sp = Genealogy.split(hanja: spHanja, hangul: spHangul, isFemale: true);
      spouseBox = _PersonBox(relation: '배우자', parts: sp, female: true);
    }

    // 장인 + 장모
    final inLawBoxes = <Widget>[];
    final filRaw = f.spouseFather ?? '';
    if (filRaw.isNotEmpty) {
      final fp = Genealogy.split(
          hanja: filRaw,
          hangul: HanjaDict.instance.toHangul(filRaw),
          isFemale: false);
      inLawBoxes.add(_PersonBox(relation: '장인', parts: fp, female: false));
      // 장모: 명시값 없으면 "○○○의 부인"
      final motherRaw = f.spouseMother;
      final NameParts mp;
      if (motherRaw != null && motherRaw.isNotEmpty) {
        mp = Genealogy.split(
            hanja: motherRaw.contains(RegExp(r'[㐀-鿿]')) ? motherRaw : '',
            hangul: motherRaw.contains(RegExp(r'[㐀-鿿]'))
                ? HanjaDict.instance.toHangul(motherRaw)
                : motherRaw,
            isFemale: true);
        inLawBoxes.add(_PersonBox(relation: '장모', parts: mp, female: true));
      } else {
        inLawBoxes.add(_PersonBox.literal(
            relation: '장모',
            hangul: '${fp.singleHangul}의 부인',
            roman: '${fp.surnameRoman}\'s wife',
            female: true));
      }
    }

    // 자녀 — 출생연도순 정렬 + 첫째/둘째 + 아들/딸
    final childSpecs = _splitNames(f.childrenNote)
        .map((t) => _buildChild(t, fbHanja, fbHangul))
        .toList();
    childSpecs.sort((a, b) {
      final ya = a.birthYear, yb = b.birthYear;
      if (ya == null && yb == null) return 0;
      if (ya == null) return 1;
      if (yb == null) return -1;
      return ya.compareTo(yb);
    });

    // 사위 / 사돈 / 사돈부인
    final sonsInLaw = _splitNames(f.sonsInLawNote)
        .map((t) => _buildChild(t, '', ''))
        .toList();
    final inLaws = _splitNames(f.inLawsNote)
        .map((t) => _buildChild(t, '', ''))
        .toList();
    final inLawSpouses = _splitNames(f.inLawsSpouseNote)
        .map((t) => _buildChild(t, '', ''))
        .toList();

    // descendant 박스 묶음
    final descendants = <Widget>[];
    for (var i = 0; i < childSpecs.length; i++) {
      final c = childSpecs[i];
      descendants.add(_PersonBox(
        relation: _childLabel(i, c.isFemale),
        parts: c.parts,
        female: c.isFemale,
        onTap: c.personId != null ? () => _openPerson(c.personId!) : null,
      ));
    }
    for (final s in sonsInLaw) {
      descendants.add(_PersonBox(
          relation: '사위',
          parts: s.parts,
          female: false,
          onTap: s.personId != null ? () => _openPerson(s.personId!) : null));
    }
    for (final s in inLaws) {
      descendants.add(_PersonBox(relation: '사돈', parts: s.parts, female: false));
    }
    for (final s in inLawSpouses) {
      descendants
          .add(_PersonBox(relation: '사돈부인', parts: s.parts, female: true));
    }

    final coupleRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _PersonBox(
          relation: '본인(父)',
          parts: selfParts,
          female: f.gender == 'F',
          highlight: true,
          onTap: () => _openPerson(f.id),
        ),
        if (spouseBox != null) ...[const _HLine(), spouseBox],
        for (final b in inLawBoxes) ...[const _HLine(), b],
      ],
    );

    final tree = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (father != null) ...[
            _PersonBox(
              relation: '아버지',
              parts: Genealogy.split(
                hanja: father.nameHanja,
                hangul: father.nameHangul.isNotEmpty
                    ? father.nameHangul
                    : HanjaDict.instance.toHangul(father.nameHanja),
                surnameHanja: father.surnameHanja,
                surnameHangul: father.surnameHangul,
              ),
              female: false,
              onTap: () => _openPerson(father.id),
            ),
            const _VLine(),
          ],
          coupleRow,
          if (descendants.isNotEmpty) ...[
            const _VLine(),
            _DescendantsBus(boxes: descendants),
          ],
        ],
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
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: tree,
      ),
    );
  }

  void _openPerson(String id) {
    Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PersonCardScreen(personId: id)))
        .then((_) => _load());
  }

  String _childLabel(int i, bool female) {
    const ord = ['첫째', '둘째', '셋째', '넷째', '다섯째', '여섯째', '일곱째', '여덟째', '아홉째', '열째'];
    final o = i < ord.length ? ord[i] : '${i + 1}째';
    return '$o ${female ? '딸' : '아들'}';
  }
}

class _ChildSpec {
  final NameParts parts;
  final bool isFemale;
  final int? birthYear;
  final String? personId;
  final String rawHangul;
  final String rawHanja;
  _ChildSpec({
    required this.parts,
    required this.isFemale,
    required this.birthYear,
    required this.personId,
    required this.rawHangul,
    required this.rawHanja,
  });
}

/// 자녀/사위/사돈을 가로 버스(수평선)로 연결해 아래로 나열.
class _DescendantsBus extends StatelessWidget {
  final List<Widget> boxes;
  const _DescendantsBus({required this.boxes});

  @override
  Widget build(BuildContext context) {
    if (boxes.length == 1) return boxes.first;
    const cell = 184.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 2,
          width: (boxes.length - 1) * cell + 2,
          color: HanjiColors.muk,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: boxes
              .map((b) => SizedBox(
                    width: cell,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [const _VLine(height: 18), b],
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

/// 인물 박스 — 성|이름 두 칸(아들·장인) 또는 한 칸(딸 "○씨").
/// 밑줄 구분은 칸 넓이만큼 표시, 로마자도 칸별로 표시.
class _PersonBox extends StatelessWidget {
  final String relation;
  final NameParts? parts;
  final bool female;
  final bool highlight;
  final VoidCallback? onTap;
  // literal 모드 (장모 "○의 부인" 등)
  final String? literalHangul;
  final String? literalRoman;

  const _PersonBox({
    required this.relation,
    required this.parts,
    this.female = false,
    this.highlight = false,
    this.onTap,
  })  : literalHangul = null,
        literalRoman = null;

  const _PersonBox.literal({
    required this.relation,
    required String hangul,
    required String roman,
    this.female = false,
  })  : parts = null,
        literalHangul = hangul,
        literalRoman = roman,
        highlight = false,
        onTap = null;

  static const double _cellW = 84;

  @override
  Widget build(BuildContext context) {
    final accent = female ? HanjiColors.ju : HanjiColors.muk;
    final twoCol = parts != null && parts!.twoColumn;

    Widget body;
    if (literalHangul != null) {
      body = _oneCell(literalHangul!, literalRoman ?? '', accent, double.nan);
    } else if (twoCol) {
      body = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _twoColCell(parts!.surnameCell, parts!.surnameRoman, accent),
          Container(width: 1.2, height: 56, color: accent.withValues(alpha: 0.5)),
          _twoColCell(parts!.givenCell, parts!.givenRoman, accent),
        ],
      );
    } else {
      body = _oneCell(parts!.singleHangul, parts!.singleRoman, accent, _cellW * 1.4);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: highlight
              ? HanjiColors.ju.withValues(alpha: 0.10)
              : HanjiColors.hanjiLight,
          border: Border.all(color: accent, width: highlight ? 2.0 : 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.touch_app, size: 12, color: accent.withValues(alpha: 0.7)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            body,
          ],
        ),
      ),
    );
  }

  Widget _twoColCell(String main, String roman, Color accent) {
    return SizedBox(
      width: _cellW,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(main,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accent,
                  height: 1.2)),
          // 밑줄 구분 — 칸 넓이만큼
          Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              height: 1.2,
              width: _cellW - 8,
              color: accent.withValues(alpha: 0.6)),
          Text(roman,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: accent.withValues(alpha: 0.85),
                  height: 1.1)),
        ],
      ),
    );
  }

  Widget _oneCell(String main, String roman, Color accent, double width) {
    final w = width.isNaN ? null : width;
    return SizedBox(
      width: w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(main,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: accent,
                  height: 1.2)),
          if (roman.isNotEmpty) ...[
            Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                height: 1.2,
                width: (w ?? 100) - 8,
                color: accent.withValues(alpha: 0.6)),
            Text(roman,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: accent.withValues(alpha: 0.85),
                    height: 1.1)),
          ],
        ],
      ),
    );
  }
}
