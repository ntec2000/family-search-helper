import 'package:flutter/material.dart';
import '../models/person.dart';

/// 출력할 관계만 선택한다. 이 대화상자는 DB를 수정하지 않는다.
class CoupleExportDialog extends StatefulWidget {
  final List<Person> people;
  const CoupleExportDialog({super.key, required this.people});

  @override
  State<CoupleExportDialog> createState() => _CoupleExportDialogState();
}

class _CoupleExportDialogState extends State<CoupleExportDialog> {
  final List<(String, String)> _couples = [];
  String? _first;
  String? _second;
  String? _error;

  String _label(Person p) {
    final name = p.nameHangul.trim().isNotEmpty ? p.nameHangul.trim()
        : p.nameHanja.trim().isNotEmpty ? p.nameHanja.trim()
        : (p.surnameHangul?.trim().isNotEmpty == true ? '${p.surnameHangul}씨' : '이름 미상');
    return '$name (${p.id})';
  }

  void _add() {
    final a = _first;
    final b = _second;
    if (a == null || b == null || a == b) {
      setState(() => _error = '서로 다른 두 인물을 선택하세요.');
      return;
    }
    if (_couples.any((pair) => (pair.$1 == a && pair.$2 == b) ||
        (pair.$1 == b && pair.$2 == a))) {
      setState(() => _error = '이미 추가된 관계입니다.');
      return;
    }
    setState(() {
      _couples.add((a, b));
      _first = null;
      _second = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final peopleById = {for (final p in widget.people) p.id: p};
    return AlertDialog(
      title: const Text('부부 관계 확인'),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('원문에서 확인한 두 인물만 선택하세요. 이 선택은 이번 JSON에만 포함되며 앱에 저장되지 않습니다.'),
          for (final item in [(true, _first), (false, _second)])
            DropdownButtonFormField<String>(
              key: ValueKey('${item.$1}-${item.$2}'),
              initialValue: item.$2,
              decoration: InputDecoration(labelText: item.$1 ? '첫 번째 인물' : '두 번째 인물'),
              isExpanded: true,
              items: [for (final p in widget.people)
                DropdownMenuItem(value: p.id, child: Text(_label(p), overflow: TextOverflow.ellipsis))],
              onChanged: (id) => setState(() {
                if (item.$1) { _first = id; } else { _second = id; }
                _error = null;
              }),
            ),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: _add, child: const Text('선택한 관계 추가')),
          for (var i = 0; i < _couples.length; i++)
            ListTile(
              title: Text('${_label(peopleById[_couples[i].$1]!)} ↔ ${_label(peopleById[_couples[i].$2]!)}'),
              trailing: IconButton(tooltip: '관계 제거', icon: const Icon(Icons.close),
                onPressed: () => setState(() => _couples.removeAt(i))),
            ),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _first != null || _second != null ? null :
            () => Navigator.pop(context, List<(String, String)>.of(_couples)),
          child: Text(_couples.isEmpty ? '관계 없이 내보내기' : '선택한 관계로 내보내기')),
      ],
    );
  }
}
