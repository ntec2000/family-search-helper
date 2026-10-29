import 'package:flutter/material.dart';
import '../models/person.dart';

/// DB에 쓰지 않고 검토 중인 인물의 복사본만 수정한다.
class CandidateEditor extends StatefulWidget {
  final Person person;
  const CandidateEditor({super.key, required this.person});
  @override
  State<CandidateEditor> createState() => _CandidateEditorState();
}

class _CandidateEditorState extends State<CandidateEditor> {
  static const fields = {
    'surname_hanja': '성씨 한자', 'surname_hangul': '성씨 한글',
    'name_hanja': '한자 이름', 'name_hangul': '한글 이름',
    'bongwan': '본관', 'ja': '자(字)', 'ho': '호(號)',
    'birth_date_lunar': '출생 · 간지/음력 원문',
    'death_date_lunar': '사망 · 간지/기일 원문',
    'burial_place': '묘지', 'spouse_hanja': '배우자/사위 표기',
    'spouse_bongwan': '배우자/사위 본관',
    'spouse_birth': '배우자 출생', 'spouse_death': '배우자 사망/기일',
    'spouse_father': '배우자 부친', 'spouse_mother': '배우자 모친',
    'spouse_grandfather': '배우자 조부',
    'spouse_great_grandfather': '배우자 증조부',
    'spouse_maternal_grandfather': '배우자 외조부',
    'note': '특이사항 · 출계 · 오독 의견', 'reason_statement': '출처 · 확인 근거',
  };
  late final Map<String, TextEditingController> _fields;
  late final TextEditingController _generation;
  late String _gender;
  String? _error;
  @override
  void initState() {
    super.initState();
    final data = widget.person.toMap();
    _fields = {for (final key in fields.keys)
      key: TextEditingController(text: data[key] as String? ?? '')};
    _generation = TextEditingController(text: widget.person.sega?.toString() ?? '');
    _gender = widget.person.gender;
  }
  @override
  void dispose() {
    for (final controller in _fields.values) { controller.dispose(); }
    _generation.dispose();
    super.dispose();
  }
  void _apply() {
    final generation = _generation.text.trim();
    if (generation.isNotEmpty && (int.tryParse(generation) ?? 0) <= 0) {
      setState(() => _error = '세대는 양의 정수로 입력하세요.');
      return;
    }
    final data = widget.person.toMap();
    for (final entry in _fields.entries) {
      final value = entry.value.text.trim();
      data[entry.key] = value.isEmpty && !entry.key.startsWith('name_') ? null : value;
    }
    data['sega'] = generation.isEmpty ? null : int.parse(generation);
    data['gender'] = _gender;
    data['updated_at'] = DateTime.now().toIso8601String();
    Navigator.pop(context, Person.fromMap(data));
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('인물 내용 수정'),
    content: SizedBox(width: 560, child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('개인 이름 미상인 딸은 성씨만 입력하세요. 원문에 없는 정보는 만들지 않습니다.'),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: const InputDecoration(labelText: '성별'),
          items: const [DropdownMenuItem(value: 'M', child: Text('남')),
            DropdownMenuItem(value: 'F', child: Text('여')),
            DropdownMenuItem(value: 'U', child: Text('미상'))],
          onChanged: (value) => setState(() => _gender = value ?? 'U'),
        ),
        TextField(controller: _generation, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: '세대(世)', errorText: _error)),
        for (final entry in fields.entries)
          TextField(controller: _fields[entry.key], maxLines: entry.key == 'note' ? 3 : 1,
            decoration: InputDecoration(labelText: entry.value)),
        if (widget.person.rawText?.isNotEmpty == true) ...[
          const SizedBox(height: 16), const Text('인식 원문 (보존)'),
          SelectableText(widget.person.rawText!),
        ],
      ]),
    )),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
      FilledButton(onPressed: _apply, child: const Text('내용 적용'))],
  );
}
