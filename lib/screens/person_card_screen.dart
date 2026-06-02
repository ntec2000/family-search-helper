import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/person.dart';
import '../services/db_service.dart';
import '../services/hanja_dict.dart';
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
  late TextEditingController _birthLunar, _birthSolar, _birthPlace;
  late TextEditingController _deathLunar, _deathSolar, _deathPlace;
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
      _hangul = TextEditingController(text: p.nameHangul);
      _roman = TextEditingController(text: p.nameRoman);
      _ja = TextEditingController(text: p.ja ?? '');
      _ho = TextEditingController(text: p.ho ?? '');
      _bongwan = TextEditingController(text: p.bongwan ?? '');
      _birthLunar = TextEditingController(text: p.birthDateLunar ?? '');
      _birthSolar = TextEditingController(text: p.birthDateSolar ?? '');
      _birthPlace = TextEditingController(text: p.birthPlace ?? '');
      _deathLunar = TextEditingController(text: p.deathDateLunar ?? '');
      _deathSolar = TextEditingController(text: p.deathDateSolar ?? '');
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
      ..birthDateLunar = _birthLunar.text.isEmpty ? null : _birthLunar.text
      ..birthDateSolar = _birthSolar.text.isEmpty ? null : _birthSolar.text
      ..birthPlace = _birthPlace.text.isEmpty ? null : _birthPlace.text
      ..deathDateLunar = _deathLunar.text.isEmpty ? null : _deathLunar.text
      ..deathDateSolar = _deathSolar.text.isEmpty ? null : _deathSolar.text
      ..deathPlace = _deathPlace.text.isEmpty ? null : _deathPlace.text
      ..marriageDate = _marriage.text.isEmpty ? null : _marriage.text
      ..marriagePlace = _marriagePlace.text.isEmpty ? null : _marriagePlace.text
      ..spouseHanja = _spouse.text.isEmpty ? null : _spouse.text
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

  void _shareAsText() {
    if (_p == null) return;
    final p = _p!;
    final txt = StringBuffer()
      ..writeln('━━ 가족역사기록서 입력용 ━━')
      ..writeln('이름: ${p.nameHangul} ${p.nameHanja} ${p.nameRoman}')
      ..writeln('성별: ${p.gender == 'M' ? '남' : '여'}')
      ..writeln('출생: ${p.birthDateSolar ?? p.birthDateLunar ?? ''} ${p.birthPlace ?? ''}')
      ..writeln('결혼: ${p.marriageDate ?? ''}  배우자: ${p.spouseHanja ?? ''}')
      ..writeln('사망: ${p.deathDateSolar ?? p.deathDateLunar ?? ''} ${p.deathPlace ?? ''}')
      ..writeln('매장: ${p.burialPlace ?? ''}')
      ..writeln('字: ${p.ja ?? ''}   號: ${p.ho ?? ''}')
      ..writeln('本貫: ${p.bongwan ?? ''}');
    Share.share(txt.toString(), subject: '${p.nameHangul} 가족역사기록');
  }

  @override
  Widget build(BuildContext context) {
    if (_p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${_p!.nameHangul} 인물카드'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _shareAsText),
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section('Identity (정체)'),
              _row(_hanja, '이름 (한자)'),
              _row(_hangul, '이름 (한글)'),
              _row(_roman, '이름 (로마자)'),
              _row(_ja, '字 (자)'),
              _row(_ho, '號 (호)'),
              _row(_bongwan, '本貫 (본관)'),
              _section('Vitals (생몰)'),
              _row(_birthLunar, '출생 음력'),
              _row(_birthSolar, '출생 양력'),
              _row(_birthPlace, '출생지'),
              _row(_deathLunar, '사망 음력'),
              _row(_deathSolar, '사망 양력'),
              _row(_deathPlace, '사망지'),
              _row(_burial, '매장지 (墓)'),
              _section('Family (가족)'),
              _row(_marriage, '결혼일'),
              _row(_marriagePlace, '결혼 장소'),
              _row(_spouse, '배우자 (한자)'),
              _row(_spouseFather, '배우자 부친'),
              _row(_children, '자녀 (子女)'),
              _row(_sonsInLaw, '사위 (婿)'),
              _row(_inLaws, '사돈 (査頓)'),
              const SizedBox(height: 32),
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
            ],
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

  Widget _row(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          controller: c,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}
