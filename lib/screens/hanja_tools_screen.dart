import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/hanja_dict.dart';
import '../theme/traditional_theme.dart';
import 'handwriting_screen.dart';

/// 한자 도구 화면 (v2.6 — 이름 찾기 + 한자음 검색 통합).
/// 탭 1) 통합 검색: 한글(이름·단어)을 입력하면 음절별로 해당 한자·한글음·뜻을 모두 표시.
///        예) "최상희" → 최/상/희,  "후기성도" → 후/기/성/도 각 음절의 한자음을 찾아 표시.
/// 탭 2) 필기 인식 (#14)
class HanjaToolsScreen extends StatelessWidget {
  const HanjaToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('한자 도구'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '통합 검색'),
              Tab(text: '필기 인식'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              _UnifiedSearchTab(),
              _HandwritingTab(),
            ],
          ),
        ),
      ),
    );
  }
}

/// v2.6 통합 검색 — 이름 찾기 + 한자음 검색 통합.
/// 한글 문자열을 음절 단위로 분해하여, 각 음절의 한자음에 해당하는 한자를 모두 표시.
class _UnifiedSearchTab extends StatefulWidget {
  const _UnifiedSearchTab();
  @override
  State<_UnifiedSearchTab> createState() => _UnifiedSearchTabState();
}

class _UnifiedSearchTabState extends State<_UnifiedSearchTab> {
  final _ctrl = TextEditingController();
  // 음절(순서 유지) → 한자 후보 목록
  final List<MapEntry<String, List<String>>> _result = [];
  bool _searched = false;

  void _search() {
    final raw = _ctrl.text.trim();
    // 한글 음절만 추출 (순서 유지)
    final syllables =
        RegExp(r'[가-힣]').allMatches(raw).map((m) => m.group(0)!).toList();
    final dict = HanjaDict.instance;
    setState(() {
      _result
        ..clear()
        ..addAll(syllables
            .map((s) => MapEntry<String, List<String>>(s, dict.byReading(s))));
      _searched = true;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 48 + bottom),
      children: [
        const Text(
            '한글(이름·단어)을 입력하고 검색하면 각 음절의 한자음에 해당하는 한자를 음·뜻과 함께 모두 보여줍니다.\n'
            '예) "최상희" → 최/상/희,  "후기성도" → 후/기/성/도',
            style: TextStyle(color: HanjiColors.mukSoft, height: 1.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                hintText: '예) 최상희 · 후기성도',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search),
            label: const Text('검색'),
          ),
        ]),
        const SizedBox(height: 16),
        if (_searched && _result.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
                child: Text('한글(이름·단어)을 입력해 주세요.',
                    style: TextStyle(color: HanjiColors.mukSoft))),
          ),
        ..._result.map((e) => _SyllableCard(syll: e.key, hanja: e.value)),
      ],
    );
  }
}

class _SyllableCard extends StatelessWidget {
  final String syll;
  final List<String> hanja;
  const _SyllableCard({required this.syll, required this.hanja});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: HanjiColors.ju,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(syll,
                    style: const TextStyle(
                        color: HanjiColors.hanji,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Text('${hanja.length}자',
                  style: const TextStyle(color: HanjiColors.mukSoft)),
            ]),
            const SizedBox(height: 10),
            if (hanja.isEmpty)
              const Text('해당 음의 한자가 사전에 없습니다.',
                  style: TextStyle(color: HanjiColors.mukSoft))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hanja
                    .map((c) => _HanjaChip(ch: c, reading: syll))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

/// #15 한자 1자 + 한글음(여러개) + 뜻 표시 칩
class _HanjaChip extends StatelessWidget {
  final String ch;
  final String reading;
  const _HanjaChip({required this.ch, required this.reading});

  @override
  Widget build(BuildContext context) {
    final dict = HanjaDict.instance;
    final readings = dict.readingsAll(ch);
    final eumLabel = readings.isEmpty ? reading : readings.join('·');
    final meanings = dict.meanings(ch);
    final gloss = meanings.isEmpty ? '' : meanings.take(2).join(', ');

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Clipboard.setData(ClipboardData(text: ch));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$ch ($eumLabel) 복사됨'),
              duration: const Duration(seconds: 1)),
        );
      },
      child: Container(
        width: 132,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: HanjiColors.hanjiLight,
          border: Border.all(color: HanjiColors.hanjiDark),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(ch,
                    style: const TextStyle(
                        fontSize: 30, color: HanjiColors.muk, height: 1.0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('음: $eumLabel',
                      style: const TextStyle(
                          fontSize: 13,
                          color: HanjiColors.ju,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (gloss.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(gloss,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: HanjiColors.mukSoft, height: 1.3)),
            ],
          ],
        ),
      ),
    );
  }
}

/// #14 필기 인식 진입 탭
class _HandwritingTab extends StatelessWidget {
  const _HandwritingTab();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.draw_outlined, size: 72, color: HanjiColors.mukSoft),
            const SizedBox(height: 16),
            const Text('손으로 한자를 그려서 찾기',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: HanjiColors.muk)),
            const SizedBox(height: 8),
            const Text(
              '한자음을 모를 때, 직접 그려서 인식할 수 있습니다.\n(내장 OCR · 오프라인 · 한글 음과 뜻 함께 표시)',
              textAlign: TextAlign.center,
              style: TextStyle(color: HanjiColors.mukSoft, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HandwritingScreen()),
              ),
              icon: const Icon(Icons.gesture),
              label: const Text('필기 인식 시작'),
            ),
          ],
        ),
      ),
    );
  }
}
