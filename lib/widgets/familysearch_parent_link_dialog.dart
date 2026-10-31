import 'package:flutter/material.dart';
import '../services/familysearch_parent_link_plan.dart';

/// 관계 전송은 수행하지 않는 검토용 입력 화면.
class FamilySearchParentLinkDialog extends StatefulWidget {
  const FamilySearchParentLinkDialog({super.key});

  @override
  State<FamilySearchParentLinkDialog> createState() => _FamilySearchParentLinkDialogState();
}

class _FamilySearchParentLinkDialogState extends State<FamilySearchParentLinkDialog> {
  final _child = TextEditingController();
  final _parent = TextEditingController();
  final _reason = TextEditingController();
  bool _childConfirmed = false;
  bool _parentConfirmed = false;
  bool _reviewed = false;
  String _relationship = '미확인';
  String? _error;

  @override
  void dispose() {
    _child.dispose();
    _parent.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _review() {
    try {
      final plan = FamilySearchParentLinkPlan.prepare(
        childId: _child.text, parentId: _parent.text,
        relationship: _relationship, reason: _reason.text,
        childConfirmed: _childConfirmed, parentConfirmed: _parentConfirmed,
        existingRelationshipsReviewed: _reviewed,
      );
      showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('부모 연결 검토 내용'),
        content: Text('자녀 ID: ${plan.childId}\n부모 ID: ${plan.parentId}\n'
            '관계: ${plan.relationship}\n근거: ${plan.reason}\n\n'
            '검토 내용입니다. FamilySearch에 전송하거나 관계를 생성하지 않았습니다.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기'))],
      ));
    } on StateError catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('부모·자녀 연결 준비'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FamilySearch에서 두 인물과 기존 관계를 확인한 뒤 입력하세요. '
            '이 화면은 새 인물을 만들거나 연결하지 않습니다.'),
        TextField(controller: _child, decoration: const InputDecoration(labelText: '자녀 FamilySearch ID')),
        TextField(controller: _parent, decoration: const InputDecoration(labelText: '부모 FamilySearch ID')),
        DropdownButton<String>(value: _relationship, isExpanded: true,
          items: const [DropdownMenuItem(value: '미확인', child: Text('관계 미확인')),
            DropdownMenuItem(value: '친생', child: Text('친생 관계')),
            DropdownMenuItem(value: '양자', child: Text('양자 관계'))],
          onChanged: (value) => setState(() => _relationship = value ?? '미확인')),
        TextField(controller: _reason, decoration: const InputDecoration(labelText: '연결 근거')),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _childConfirmed,
          title: const Text('자녀 ID의 인물을 확인했습니다'),
          onChanged: (value) => setState(() => _childConfirmed = value == true)),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _parentConfirmed,
          title: const Text('부모 ID의 인물을 확인했습니다'),
          onChanged: (value) => setState(() => _parentConfirmed = value == true)),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _reviewed,
          title: const Text('기존 부모·자녀 관계를 확인했습니다'),
          onChanged: (value) => setState(() => _reviewed = value == true)),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
    ))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      FilledButton(onPressed: _review, child: const Text('검토 내용 보기'))],
  );
}
