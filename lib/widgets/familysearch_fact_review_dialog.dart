import 'package:flutter/material.dart';
import '../services/familysearch_fact_update_plan.dart';

/// 생몰 정보 변경안을 보여 주며 서버에는 전송하지 않는다.
class FamilySearchFactReviewDialog extends StatefulWidget {
  final Map<String, dynamic> remote;
  final Map<String, dynamic> incoming;
  const FamilySearchFactReviewDialog({super.key, required this.remote, required this.incoming});

  @override
  State<FamilySearchFactReviewDialog> createState() => _FamilySearchFactReviewDialogState();
}

class _FamilySearchFactReviewDialogState extends State<FamilySearchFactReviewDialog> {
  static const _birth = 'http://gedcomx.org/Birth';
  static const _death = 'http://gedcomx.org/Death';
  final _reason = TextEditingController();
  String _type = _birth;
  String? _factId;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Map<String, String> _choices() {
    final choices = <String, String>{};
    final facts = widget.remote['facts'];
    if (facts is! List) return choices;
    for (final fact in facts) {
      if (fact is! Map || fact['type'] != _type || fact['id'] is! String) continue;
      final id = (fact['id'] as String).trim();
      if (id.isEmpty) continue;
      final date = fact['date'];
      final original = date is Map && date['original'] is String &&
          (date['original'] as String).trim().isNotEmpty
          ? date['original'] as String
          : date is Map && date['formal'] is String && (date['formal'] as String).trim().isNotEmpty
              ? '정규화 값: ${date['formal']}' : '날짜 표기 없음';
      choices[id] = '$id · $original';
    }
    return choices;
  }

  String _describe(Map<String, dynamic> values) {
    String value(String key) {
      final entry = values[key];
      if (entry is Map && entry['original'] is String &&
          (entry['original'] as String).trim().isNotEmpty) return entry['original'] as String;
      if (entry is Map && entry['formal'] is String &&
          (entry['formal'] as String).trim().isNotEmpty) return '정규화 값: ${entry['formal']}';
      return '응답에 표시 가능한 값 없음';
    }
    return '날짜: ${value('date')}\n장소: ${value('place')}';
  }

  void _preview() {
    try {
      final plan = FamilySearchFactUpdatePlan.prepare(remote: widget.remote,
          incoming: widget.incoming, factId: _factId ?? '', type: _type, reason: _reason.text);
      showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('변경 전후 검토'),
        content: SingleChildScrollView(child: Text('기존 기록\n${_describe(plan.previous)}\n\n'
            '기존 기여자 참조: ${plan.priorContributor}\n'
            '기존 변경 시각 원문: ${plan.priorModified}\n'
            '기존 변경 근거: ${plan.priorReason}\n'
            '항목의 출처 참조: ${plan.priorSourceReferences.isEmpty ? '응답에 없음' : plan.priorSourceReferences.join(', ')}\n\n'
            '변경안\n${_describe(plan.proposed)}\n\n새 변경 근거: ${plan.reason}\n\n'
            '검토용 화면이며 FamilySearch 기록은 변경하지 않았습니다.')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기'))],
      ));
    } on StateError catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = _choices();
    return AlertDialog(
      title: const Text('생몰 정보 변경안 검토'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('기존 항목을 선택하고 근거를 입력하세요. 이 화면은 전송하지 않습니다.'),
          DropdownButton<String>(value: _type, isExpanded: true,
            items: const [DropdownMenuItem(value: _birth, child: Text('출생')),
              DropdownMenuItem(value: _death, child: Text('사망'))],
            onChanged: (value) => setState(() { _type = value ?? _birth; _factId = null; _error = null; })),
          if (choices.isEmpty) const Text('선택한 종류의 기존 항목 ID가 없습니다.')
          else DropdownButton<String>(value: _factId, isExpanded: true,
            hint: const Text('기존 항목 선택'),
            items: [for (final entry in choices.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))],
            onChanged: (value) => setState(() { _factId = value; _error = null; })),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: '변경 근거')),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        FilledButton(onPressed: _preview, child: const Text('변경안 보기'))],
    );
  }
}
