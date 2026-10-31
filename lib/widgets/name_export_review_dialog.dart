import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/name_export_review.dart';

/// 입력한 이름의 성 포함 여부를 사용자가 직접 확인하도록 한다.
Future<bool> showNameExportReview(BuildContext context, List<Person> persons) async {
  final candidates = persons.where(NameExportReview.needsReview).toList();
  if (candidates.isEmpty) return true;
  return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: const Text('성씨와 이름 구분 확인'),
    content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('아래 이름은 성씨로 시작합니다. 내보내기에서 성과 이름이 잘못 분리되거나 중복될 수 있습니다. '
          '입력값이 개인 이름이라면 원본을 확인하고 성을 포함한 전체 이름으로 수정하세요. '
          '예: 성 이, 개인 이름 이인 → 전체 이름 이이인.'),
        const SizedBox(height: 8),
        Flexible(child: ListView.builder(shrinkWrap: true, itemCount: candidates.length,
          itemBuilder: (_, index) {
            final p = candidates[index];
            return ListTile(title: Text('인물 ID: ${p.id}'),
              subtitle: Text('성: ${p.surnameHangul ?? ""} ${p.surnameHanja ?? ""}\n'
                  '입력 이름: ${p.nameHangul} ${p.nameHanja}'));
          })),
      ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('수정하러 가기')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인 후 계속')),
    ],
  )) ?? false;
}
