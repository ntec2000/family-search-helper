import 'package:flutter/material.dart';
import '../services/hanja_dict.dart';
import '../services/genealogy.dart';

/// v2.9 — 성씨(姓) 수동 입력 다이얼로그 (공용).
/// 한글 성을 입력하면 사전(HanjaDict)에서 해당 음의 한자 후보 중
/// **실제 성씨로 쓰이는 한자만** 필터링하여 칩으로 표시한다.
/// 사용자가 한자를 선택해 '적용'하면 (선택 한자, 입력 한글)을 반환한다.
/// 취소/건너뛰기 시 null.
Future<(String, String)?> showSurnameInputDialog(BuildContext context) {
  final hangul = TextEditingController();
  final dict = HanjaDict.instance;

  // 성씨로 사용되는 한자 전체 집합(상수 세트 + 대표 매핑 키).
  final surnameSet = <String>{
    ...Genealogy.surnamesHanja,
    ...Genealogy.surnameHanjaToHangul.keys,
  };

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
            final all = h.isEmpty ? <String>[] : dict.byReading(h);
            // v2.9 #4 — 성씨로 사용하는 한자만 보여준다.
            //          필터 결과가 비면(드문 성) 전체 후보로 폴백.
            final filtered = all.where(surnameSet.contains).toList();
            final list = filtered.isNotEmpty ? filtered : all;
            setLocal(() {
              candidates = list;
              searched = true;
              selected = null;
            });
          }

          final media = MediaQuery.of(ctx);
          // v2.9 #1 — 한자가 화면에 다 보이도록 다이얼로그를 넓게,
          //          칩 영역은 화면 높이에 맞춰 스크롤 가능하게.
          final maxChipHeight = media.size.height * 0.5;

          return AlertDialog(
            // v3.0.1 — 한자가 잘리지 않도록 다이얼로그를 화면 거의 전폭으로 넓힌다.
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            title: const Text('성씨(姓) 입력'),
            content: SizedBox(
              width: double.maxFinite, // 다이얼로그 전폭 사용 → 한자가 잘리지 않음
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        '성을 알 수 없는 인물에 적용할 성씨를 입력하세요.\n'
                        '한글 성을 적으면 아래에 성씨로 쓰이는 한자 후보가 표시됩니다.\n'
                        '한자를 선택하면 한글 성과 한자 성이 족보의 성씨로 설정되어 자녀 이름에도 적용됩니다.',
                        style: TextStyle(fontSize: 13, height: 1.5)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hangul,
                            textInputAction: TextInputAction.search,
                            autofocus: true,
                            onChanged: (_) => runSearch(),
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
                      const Text('해당 음의 성씨 한자 후보가 없습니다. 한글만 적용됩니다.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    if (candidates.isNotEmpty) ...[
                      const Text('성씨 한자를 선택하세요',
                          style: TextStyle(fontSize: 12, height: 1.4)),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxChipHeight),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: candidates.map((c) {
                              final on = c == selected;
                              final hg = Genealogy.surnameHanjaToHangul[c];
                              return ChoiceChip(
                                label: Text(
                                  hg != null ? '$c ($hg)' : c,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                selected: on,
                                onSelected: (_) =>
                                    setLocal(() => selected = c),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
