import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/person.dart';
import '../services/db_service.dart';
import '../services/hanja_dict.dart';
import '../services/romanizer.dart';
import '../theme/traditional_theme.dart';

class PersonCardScreen extends StatefulWidget {
  final String personId;
  const PersonCardScreen({super.key, required this.personId});
  @override
  State<PersonCardScreen> createState() => _PersonCardScreenState();
}

class _PersonCardScreenState extends State<PersonCardScreen> {
  Person? _p;
  final _form = GlobalKey<FormState>();
  late TextEditingController _hanja, _hangul, _roman, _ja, _ho, _bongwan;
  late TextEditingController _birth, _birthPlace;
  late TextEditingController _death, _deathPlace;
  late TextEditingController _marriage, _marriagePlace, _spouse, _spouseFather, _burial;
  late TextEditingController _children, _sonsInLaw, _inLaws;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await DbService.instance.getPerson(widget.personId);
    if (p == null) return;
    setState(() {
      _p = p;
      _hanja = TextEditingController(text: p.nameHanja);
      _hangul = TextEditingController(
          text: p.nameHangul.isEmpty
              ? HanjaDict.instance.toHangul(p.nameHanja)
              : p.nameHangul);
      // #4 로마자 자동 인식 (비어있으면 한글 이름으로부터 생성)
      final roman = p.nameRoman.isNotEmpty
          ? p.nameRoman
          : Romanizer.romanizeName(_hangulOf(p));
      _roman = TextEditingController(text: roman);
      _ja = TextEditingController(text: p.ja ?? '');
      _ho = TextEditingController(text: p.ho ?? '');
      _bongwan = TextEditingController(text: p.bongwan ?? '');
      // #9 날짜만 보이게 — 음력/양력 구분 없이 한 칸
      _birth = TextEditingController(
          text: p.birthDateSolar ?? p.birthDateLunar ?? '');
      _birthPlace = TextEditingController(text: p.birthPlace ?? '');
      _death = TextEditingController(
          text: p.deathDateSolar ?? p.deathDateLunar ?? '');
      _deathPlace = TextEditingController(text: p.deathPlace ?? '');
      _marriage = TextEditingController(text: p.marriageDate ?? '');
      _marriagePlace = TextEditingController(text: p.marriagePlace ?? '');
      _spouse = TextEditingController(text: p.spouseHanja ?? '');
      _spouseFather = TextEditingController(text: p.spouseFather ?? '');
      _burial = TextEditingController(text: p.burialPlace ?? '');
      _children = TextEditingController(text: p.childrenNote ?? '');
      _sonsInLaw = TextEditingController(text: p.sonsInLawNote ?? '');
      _inLaws = TextEditingController(text: p.inLawsNote ?? '');
    });
  }

  String _hangulOf(Person p) => p.nameHangul.isNotEmpty
      ? p.nameHangul
      : HanjaDict.instance.toHangul(p.nameHanja);

  Future<void> _save() async {
    if (_p == null) return;
    _p!
      ..nameHanja = _hanja.text
      ..nameHangul = _hangul.text.isEmpty
          ? HanjaDict.instance.toHangul(_hanja.text)
          : _hangul.text
      ..nameRoman = _roman.text
      ..ja = _ja.text.isEmpty ? null : _ja.text
      ..ho = _ho.text.isEmpty ? null : _ho.text
      ..bongwan = _bongwan.text.isEmpty ? null : _bongwan.text
      ..birthDateSolar = _birth.text.isEmpty ? null : _birth.text
      ..birthPlace = _birthPlace.text.isEmpty ? null : _birthPlace.text
      ..deathDateSolar = _death.text.isEmpty ? null : _death.text
      ..deathPlace = _deathPlace.text.isEmpty ? null : _deathPlace.text
      ..marriageDate = _marriage.text.isEmpty ? null : _marriage.text
      ..marriagePlace = _marriagePlace.text.isEmpty ? null : _marriagePlace.text
      ..spouseHanja = _spouse.text.isEmpty ? null : _spouse.text
      ..spouseHangul = _spouse.text.isEmpty
          ? null
          : HanjaDict.instance.toHangul(_spouse.text)
      ..spouseFather = _spouseFather.text.isEmpty ? null : _spouseFather.text
      ..burialPlace = _burial.text.isEmpty ? null : _burial.text
      ..childrenNote = _children.text.isEmpty ? null : _children.text
      ..sonsInLawNote = _sonsInLaw.text.isEmpty ? null : _sonsInLaw.text
      ..inLawsNote = _inLaws.text.isEmpty ? null : _inLaws.text
      ..updatedAt = DateTime.now();
    await DbService.instance.upsertPerson(_p!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다')));
    }
  }

  void _autoRoman() {
    setState(() => _roman.text = Romanizer.romanizeName(_hangul.text));
  }

  void _shareAsText() {
    if (_p == null) return;
    final d = HanjaDict.instance;
    final p = _p!;
    final txt = StringBuffer()
      ..writeln('━━ 가족역사기록서 입력용 ━━')
      ..writeln('이름: ${p.nameHangul} ${p.nameHanja} ${p.nameRoman}')
      ..writeln('성별: ${p.gender == 'M' ? '남' : '여'}')
      ..writeln('출생: ${_birth.text} ${p.birthPlace ?? ''}')
      ..writeln('결혼: ${p.marriageDate ?? ''}  배우자: ${d.annotate(p.spouseHanja ?? '')}')
      ..writeln('배우자 부친: ${d.annotate(p.spouseFather ?? '')}')
      ..writeln('사망: ${_death.text} ${p.deathPlace ?? ''}')
      ..writeln('매장: ${p.burialPlace ?? ''}')
      ..writeln('字: ${d.annotate(p.ja ?? '')}   號: ${d.annotate(p.ho ?? '')}')
      ..writeln('本貫: ${d.annotate(p.bongwan ?? '')}');
    Share.share(txt.toString(), subject: '${p.nameHangul} 가족역사기록');
  }

  @override
  Widget build(BuildContext context) {
    if (_p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_p!.nameHangul} 조상 신상정보'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareAsText),
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // #10 하단까지 보이도록 충분한 바닥 여백 + 키보드 회피
          padding: EdgeInsets.fromLTRB(16, 16, 16, 48 + bottomInset),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('인물 정보'),
                _row(_hanja, '이름 (한자)', annotate: true),
                _row(_hangul, '이름 (한글)'),
                _row(_roman, '이름 (로마자)',
                    suffix: IconButton(
                      tooltip: '한글 이름에서 로마자 자동 변환',
                      icon: const Icon(Icons.auto_fix_high, size: 20),
                      onPressed: _autoRoman,
                    )),
                _row(_ja, '字 (자)', annotate: true),
                _row(_ho, '號 (호)', annotate: true),
                _row(_bongwan, '本貫 (본관)', annotate: true),
                _section('출생·사망 정보'),
                _row(_birth, '출생일'),
                _row(_birthPlace, '출생지'),
                _row(_death, '사망일'),
                _row(_deathPlace, '사망지'),
                _row(_burial, '매장지 (墓)', annotate: true),
                _section('가족 정보'),
                _row(_marriage, '결혼일'),
                _row(_marriagePlace, '결혼 장소'),
                _row(_spouse, '배우자 (한자)', annotate: true),
                _row(_spouseFather, '배우자 부친', annotate: true),
                _row(_children, '자녀 (子女)', annotate: true),
                _row(_sonsInLaw, '사위 (婿)', annotate: true),
                _row(_inLaws, '사돈 (査頓)', annotate: true),
                const SizedBox(height: 24),
                if (_p!.rawText != null)
                  ExpansionTile(
                    title: const Text('원본 OCR 텍스트',
                        style: TextStyle(color: HanjiColors.mukSoft)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(_p!.rawText!,
                            style: const TextStyle(fontSize: 13, height: 1.6)),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: HanjiColors.ju,
                letterSpacing: 1)),
      );

  // annotate=true 이면 입력된 한자의 한글음을 helperText 로 병기 (#3)
  Widget _row(TextEditingController c, String label,
          {bool annotate = false, Widget? suffix}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          controller: c,
          onChanged: annotate ? (_) => setState(() {}) : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: suffix,
            helperText: annotate ? _hangulHelper(c.text) : null,
            helperStyle: const TextStyle(
                color: HanjiColors.cheong, fontWeight: FontWeight.w600),
          ),
        ),
      );

  String? _hangulHelper(String text) {
    if (text.trim().isEmpty) return null;
    final h = HanjaDict.instance.toHangul(text);
    if (h == text) return null; // 한자가 없으면 표시 안 함
    return '한글음: $h';
  }
}
