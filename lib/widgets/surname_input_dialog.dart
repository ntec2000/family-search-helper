import 'package:flutter/material.dart';
import '../services/hanja_dict.dart';

/// v2.6 — 성씨(姓) 수동 입력 다이얼로그 (공용).
/// 한글 성을 입력하고 '입력'을 누르면 사전(HanjaDict)에서 해당 음의 한자 후보를
/// 아래에 칩으로 표시하고, 사용자가 한자를 선택해 '적용'하면
/// (선택 한자, 입력 한글)을 반환한다. 취소/건너뛰기 시 null.
Future<(String, String)?> showSurnameInputDialog(BuildContext context) {
  final hangul = TextEditingController();
  final dict = HanjaDict.instance;
  return showDialog<(String, String)?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      List<String> candidates = [];
      String? selected;
      bool searched = false;
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          void runSearch() {
            final h = hangul.text.trim();
            final list = h.isEmpty ? <String>[] : dict.byReading(h);
            setLocal(() {
              candidates = list;
              searched = true;
              selected = null;
            });
          }

          return AlertDialog(
            title: const Text('성씨(姓) 입력'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      '성을 알 수 없는 인물에 적용할 성씨를 입력하세요.\n'
                      '한글 성을 적고 [입력]을 누르면 아래에 한자 후보가 표시됩니다.\n'
                      '한자를 선택하면 한글 성과 한자 성이 족보의 성씨로 설정되어 자녀 이름에도 적용됩니다.',
                      style: TextStyle(fontSize: 13, height: 1.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hangul,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => runSearch(),
                          decoration: const InputDecoration(
                              labelText: '성 (한글) 예: 최',
                              border: OutlineInputBorder(),
                              isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                          onPressed: runSearch, child: const Text('입력')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (searched && candidates.isEmpty)
                    const Text('해당 음의 한자 후보가 없습니다. 한글만 적용됩니다.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  if (candidates.isNotEmpty) ...[
                    const Text('해당 한자를 선택하세요',
                        style: TextStyle(fontSize: 12, height: 1.4)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: candidates.map((c) {
                        final on = c == selected;
                        return ChoiceChip(
                          label: Text(c, style: const TextStyle(fontSize: 18)),
                          selected: on,
                          onSelected: (_) => setLocal(() => selected = c),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('건너뛰기')),
              FilledButton(
                  onPressed: () {
                    final h = hangul.text.trim();
                    if (h.isEmpty) {
                      Navigator.pop(ctx, null);
                      return;
                    }
                    Navigator.pop(ctx, (selected ?? '', h));
                  },
                  child: const Text('적용')),
            ],
          );
        },
      );
    },
  );
}
