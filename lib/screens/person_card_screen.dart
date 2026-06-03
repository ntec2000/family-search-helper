import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/person.dart';
import '../services/db_service.dart';
import '../services/hanja_dict.dart';
import '../services/romanizer.dart';
import '../services/genealogy.dart';
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
  late TextEditingController _hanja, _hangul, _roman, _ja, _ho, _bongwan, _pa;
  late TextEditingController _surnameHanja, _surnameHangul, _sega;
  late TextEditingController _birth, _birthPlace;
  late TextEditingController _death, _deathPlace;
  late TextEditingController _marriage, _marriagePlace, _spouse, _spouseFather,
      _spouseMother, _burial;
  late TextEditingController _children, _sonsInLaw, _inLaws, _inLawsSpouse;
  late TextEditingController _reason;
  String _gender = 'U';

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
      _gender = p.gender;
      _hanja = TextEditingController(text: p.nameHanja);
      _hangul = TextEditingController(
          text: p.nameHangul.isEmpty
              ? HanjaDict.instance.toHangul(p.nameHanja)
              : p.nameHangul);
      final roman = p.nameRoman.isNotEmpty
          ? p.nameRoman
          : Romanizer.romanizeName(_hangulOf(p));
      _roman = TextEditingController(text: roman);
      // v2.2 성씨 분리 (비어있으면 이름에서 자동 추론)
      final np = Genealogy.split(
          hanja: p.nameHanja,
          hangul: _hangulOf(p),
          surnameHanja: p.surnameHanja,
          surnameHangul: p.surnameHangul);
      _surnameHanja = TextEditingController(
          text: p.surnameHanja ?? np.surnameHanja);
      _surnameHangul = TextEditingController(
          text: p.surnameHangul ?? np.surnameHangul);
      _sega = TextEditingController(text: p.sega?.toString() ?? '');
      _ja = TextEditingController(text: p.ja ?? '');
      _ho = TextEditingController(text: p.ho ?? '');
      _bongwan = TextEditingController(text: p.bongwan ?? '');
      _pa = TextEditingController(text: p.pa ?? '');
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
      _spouseMother = TextEditingController(text: p.spouseMother ?? '');
      _burial = TextEditingController(text: p.burialPlace ?? '');
      _children = TextEditingController(text: p.childrenNote ?? '');
      _sonsInLaw = TextEditingController(text: p.sonsInLawNote ?? '');
      _inLaws = TextEditingController(text: p.inLawsNote ?? '');
      _inLawsSpouse = TextEditingController(text: p.inLawsSpouseNote ?? '');
      _reason = TextEditingController(text: p.reasonStatement ?? '');
    });
  }

  String _hangulOf(Person p) => p.nameHangul.isNotEmpty
      ? p.nameHangul
      : HanjaDict.instance.toHangul(p.nameHanja);

  String? _orNull(String s) => s.trim().isEmpty ? null : s.trim();

  Future<void> _save() async {
    if (_p == null) return;
    _p!
      ..nameHanja = _hanja.text
      ..nameHangul = _hangul.text.isEmpty
          ? HanjaDict.instance.toHangul(_hanja.text)
          : _hangul.text
      ..nameRoman = _roman.text
      ..surnameHanja = _orNull(_surnameHanja.text)
      ..surnameHangul = _orNull(_surnameHangul.text)
      ..sega = int.tryParse(_sega.text.trim())
      ..gender = _gender
      ..ja = _orNull(_ja.text)
      ..ho = _orNull(_ho.text)
      ..bongwan = _orNull(_bongwan.text)
      ..pa = _orNull(_pa.text)
      ..birthDateSolar = _orNull(_birth.text)
      ..birthPlace = _orNull(_birthPlace.text)
      ..deathDateSolar = _orNull(_death.text)
      ..deathPlace = _orNull(_deathPlace.text)
      ..marriageDate = _orNull(_marriage.text)
      ..marriagePlace = _orNull(_marriagePlace.text)
      ..spouseHanja = _orNull(_spouse.text)
      ..spouseHangul = _spouse.text.isEmpty
          ? null
          : HanjaDict.instance.toHangul(_spouse.text)
      ..spouseFather = _orNull(_spouseFather.text)
      ..spouseMother = _orNull(_spouseMother.text)
      ..burialPlace = _orNull(_burial.text)
      ..childrenNote = _orNull(_children.text)
      ..sonsInLawNote = _orNull(_sonsInLaw.text)
      ..inLawsNote = _orNull(_inLaws.text)
      ..inLawsSpouseNote = _orNull(_inLawsSpouse.text)
      ..reasonStatement = _orNull(_reason.text)
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

  /// 한글 이름에서 성(姓) 자동 채우기.
  void _autoSurname() {
    final np = Genealogy.split(
        hanja: _hanja.text, hangul: _hangul.text);
    setState(() {
      if (np.surnameHangul.isNotEmpty) _surnameHangul.text = np.surnameHangul;
      if (np.surnameHanja.isNotEmpty) _surnameHanja.text = np.surnameHanja;
    });
  }

  void _shareAsText() {
    if (_p == null) return;
    final d = HanjaDict.instance;
    final p = _p!;
    final birthPlace = p.birthPlace ?? Genealogy.defaultPlace;
    final deathPlace = p.deathPlace ?? Genealogy.defaultPlace;
    final txt = StringBuffer()
      ..writeln('━━ 가족역사기록서 입력용 ━━')
      ..writeln('이름: ${p.nameHangul} ${p.nameHanja} ${p.nameRoman}')
      ..writeln('성(姓): ${_surnameHangul.text} ${_surnameHanja.text}')
      ..writeln('성별: ${p.gender == 'M' ? '남' : p.gender == 'F' ? '여' : '미상'}'
          '${p.sega != null ? '   世: ${p.sega}' : ''}')
      ..writeln('출생: ${_birth.text}   출생지: $birthPlace')
      ..writeln('결혼: ${p.marriageDate ?? ''}   배우자: ${d.annotate(p.spouseHanja ?? '')}')
      ..writeln('장인: ${d.annotate(p.spouseFather ?? '')}'
          '   장모: ${p.spouseMother ?? '${d.annotate(p.spouseFather ?? '')}의 부인'}')
      ..writeln('사망: ${_death.text}   사망지: $deathPlace')
      ..writeln('매장: ${p.burialPlace ?? ''}')
      ..writeln('字: ${d.annotate(p.ja ?? '')}   號: ${d.annotate(p.ho ?? '')}')
      ..writeln('本貫: ${d.annotate(p.bongwan ?? '')}   派: ${p.pa ?? ''}')
      ..writeln('자녀: ${p.childrenNote ?? ''}')
      ..writeln('사위: ${p.sonsInLawNote ?? ''}')
      ..writeln('사돈: ${p.inLawsNote ?? ''}   사돈부인: ${p.inLawsSpouseNote ?? ''}');
    if ((p.reasonStatement ?? '').isNotEmpty) {
      txt.writeln('근거(Reason): ${p.reasonStatement}');
    }
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
          padding: EdgeInsets.fromLTRB(16, 16, 16, 48 + bottomInset),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('인물 정보'),
                _genderRow(),
                Row(children: [
                  Expanded(
                      child: _row(_surnameHangul, '성 (한글)',
                          suffix: IconButton(
                            tooltip: '이름에서 성 자동 채우기',
                            icon: const Icon(Icons.auto_fix_high, size: 20),
                            onPressed: _autoSurname,
                          ))),
                  const SizedBox(width: 8),
                  Expanded(child: _row(_surnameHanja, '성 (한자)', annotate: true)),
                ]),
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
                Row(children: [
                  Expanded(child: _row(_bongwan, '本貫 (본관)', annotate: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _row(_pa, '派 (파)')),
                  const SizedBox(width: 8),
                  SizedBox(
                      width: 80,
                      child: _row(_sega, '世 (세)', keyboard: TextInputType.number)),
                ]),
                _section('출생·사망 정보'),
                _row(_birth, '출생일 (추정 시 "대략 ○○○○")'),
                _row(_birthPlace, '출생지 (미상 시 ${Genealogy.defaultPlace})'),
                _row(_death, '사망일 (추정 가능 시 "대략 ○○○○")'),
                _row(_deathPlace, '사망지 (미상 시 ${Genealogy.defaultPlace})'),
                _row(_burial, '매장지 (墓)', annotate: true),
                _section('가족 정보'),
                _row(_marriage, '결혼일'),
                _row(_marriagePlace, '결혼 장소'),
                _row(_spouse, '배우자 (한자)', annotate: true),
                _row(_spouseFather, '장인 (배우자 부친)', annotate: true),
                _row(_spouseMother, '장모 (배우자 모친 / "○○○의 부인")'),
                _row(_children, '자녀 (子女)', annotate: true),
                _row(_sonsInLaw, '사위 (婿)', annotate: true),
                _row(_inLaws, '사돈 (査頓)', annotate: true),
                _row(_inLawsSpouse, '사돈부인'),
                _section('FamilySearch 정합'),
                _row(_reason, '근거 진술 (Reason This Is Correct)', maxLines: 3),
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

  Widget _genderRow() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const Text('성별  ',
              style: TextStyle(color: HanjiColors.muk, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'M', label: Text('남')),
              ButtonSegment(value: 'F', label: Text('여')),
              ButtonSegment(value: 'U', label: Text('미상')),
            ],
            selected: {_gender},
            onSelectionChanged: (s) => setState(() => _gender = s.first),
          ),
        ]),
      );

  Widget _row(TextEditingController c, String label,
          {bool annotate = false,
          Widget? suffix,
          int maxLines = 1,
          TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboard,
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
    if (h == text) return null;
    return '한글음: $h';
  }
}
