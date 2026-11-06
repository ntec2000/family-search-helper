import 'package:flutter/material.dart';
import '../services/family_name_candidates.dart';

/// Select names to add to the existing person/relationship review flow.
class FamilyCandidatesDialog extends StatefulWidget {
  final List<FamilyNameCandidate> rows;
  final Set<String> existingIds;
  const FamilyCandidatesDialog({super.key, required this.rows,
      required this.existingIds});
  @override
  State<FamilyCandidatesDialog> createState() => _FamilyCandidatesDialogState();
}

class _FamilyCandidatesDialogState extends State<FamilyCandidatesDialog> {
  final _selected = <String>{};
  bool _available(FamilyNameCandidate row) => row.canMaterialize &&
      !widget.existingIds.contains(row.candidateId);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('가족 이름 후보 (${widget.rows.length}건)'),
    content: SizedBox(width: double.maxFinite, child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('추출 이름과 생성 표시명을 함께 표시합니다. 선택한 인물을 검토 목록에 '
            '추가한 뒤 내용·가족관계를 확인하고 저장하세요. 같은 이름이라도 다른 사람일 수 있습니다. 한자 사전 음은 검수본과 대조하세요.'),
        const SizedBox(height: 8),
        TextButton(onPressed: () => setState(() {
          _selected.addAll(widget.rows.where(_available).map((r) => r.candidateId));
        }), child: const Text('추가 가능한 후보 모두 선택')),
        Flexible(child: ListView.builder(shrinkWrap: true,
          itemCount: widget.rows.length, itemBuilder: (_, index) {
            final row = widget.rows[index];
            return CheckboxListTile(
              value: _selected.contains(row.candidateId),
              onChanged: !_available(row) ? null : (selected) => setState(() {
                if (selected == true) { _selected.add(row.candidateId); }
                else { _selected.remove(row.candidateId); }
              }),
              title: Text('${index + 1}. ${row.displayLabel}'),
              subtitle: Text('${row.role}${row.placeholder ? " · 생성 표시명" : ""}'
                  '${!_available(row) ? " · 이미 목록에 있음" : ""}'
                  ' · 원본 인물 ID: ${row.sourcePersonId}'),
            );
          })),
      ],
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('닫기')),
      FilledButton(onPressed: _selected.isEmpty ? null : () =>
          Navigator.pop(context, widget.rows.where((r) =>
              _selected.contains(r.candidateId)).toList()),
          child: Text('선택한 ${_selected.length}명 추가')),
    ],
  );
}
