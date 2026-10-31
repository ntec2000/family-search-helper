import 'package:flutter/material.dart';
import '../services/hanja_dict.dart';
import '../services/genealogy.dart';
import '../services/surname_review.dart';

/// v2.9 — 성씨(姓) 수동 입력 다이얼로그 (공용).
/// 한글 성을 입력하면 사전(HanjaDict)에서 해당 음의 한자 후보 중
/// **실제 성씨로 쓰이는 한자만** 필터링하여 칩으로 표시한다.
/// 사용자가 한자를 선택해 '적용'하면 (선택 한자, 입력 한글)을 반환한다.
/// 취소/건너뛰기 시 null.
Future<(String, String)?> showSurnameInputDialog(BuildContext context, {
  String initialHangul = '', String initialHanja = '', bool forAnalysis = false,
}) {
  final hangul = TextEditingController(text: SurnameReview.normalizeHangul(initialHangul));
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
      List<String> candidates = initialHanja.isEmpty ? [] : [initialHanja];
      String? selected = initialHanja.isEmpty ? null : initialHanja;
      bool searched = initialHanja.isNotEmpty;
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          void runSearch() {
            final h = SurnameReview.normalizeHangul(hangul.text);
            final all = h.isEmpty ? <String>[] : dict.byReading(h);
            // v2.9 #4 — 성씨로 사용하는 한자만 보여준다.
            //          후보가 없더라도 한글 성씨만 제출할 수 있다.
            final filtered = all.where(surnameSet.contains).toList();
            final list = filtered;
            setLocal(() {
              candidates = list;
              searched = true;
              selected = null;
            });
          }

          void submit() {
            final h = SurnameReview.normalizeHangul(hangul.text);
            if (h.isNotEmpty) Navigator.pop(ctx, (selected ?? '', h));
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
            title: Text(forAnalysis ? '족보 성씨 먼저 확인' : '성씨(姓) 입력'),
            content: SizedBox(
              width: double.maxFinite, // 다이얼로그 전폭 사용 → 한자가 잘리지 않음
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(forAnalysis
                        ? '어느 성씨의 족보인지 먼저 확인하세요. 이·김·최처럼 성만 입력하고 제출하면 됩니다.\n'
                          '한자 선택은 선택 사항입니다. 본손 아들·딸에만 적용하고 아내·사위 성씨는 구분합니다.'
                        : '성을 알 수 없는 인물에 적용할 한글 성씨를 입력하세요.\n'
                          '한자 선택은 선택 사항이며 확인한 한자 성씨만 추가하세요.',
                        style: const TextStyle(fontSize: 13, height: 1.5)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hangul,
                            textInputAction: forAnalysis ? TextInputAction.done : TextInputAction.search,
                            autofocus: true,
                            onChanged: (_) => runSearch(),
                            onSubmitted: (_) => forAnalysis ? submit() : runSearch(),
                            decoration: InputDecoration(
                                labelText: '성 (한글) 예: 최',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                errorText: hangul.text.trim().isNotEmpty &&
                                        SurnameReview.normalizeHangul(hangul.text).isEmpty
                                    ? '이·김·최처럼 성씨만 입력하세요.' : null),
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
                  child: Text(forAnalysis ? '취소' : '건너뛰기')),
              FilledButton(
                  onPressed: SurnameReview.normalizeHangul(hangul.text).isEmpty ? null : submit,
                  child: Text(forAnalysis ? '이 성씨로 분석' : '적용')),
            ],
          );
        },
      );
    },
  );
}
