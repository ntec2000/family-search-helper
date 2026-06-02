import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/hanja_dict.dart';
import '../theme/traditional_theme.dart';
import 'handwriting_screen.dart';

/// 한자 도구 화면.
/// 탭 1) 한글 이름 → 음절별 한자 후보 (#12)
/// 탭 2) 한자음(한글 한 글자) → 해당 한자 목록 (#13)
/// 탭 3) 필기 인식 (#14)
class HanjaToolsScreen extends StatelessWidget {
  const HanjaToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('한자 도구'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '이름 찾기'),
              Tab(text: '한자음 검색'),
              Tab(text: '필기 인식'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(
            children: [
              _NameSearchTab(),
              _ReadingSearchTab(),
              _HandwritingTab(),
            ],
          ),
        ),
      ),
    );
  }
}

/// #12 한글 이름 → 음절별 한자 후보 & 한글음
class _NameSearchTab extends StatefulWidget {
  const _NameSearchTab();
  @override
  State<_NameSearchTab> createState() => _NameSearchTabState();
}

class _NameSearchTabState extends State<_NameSearchTab> {
  final _ctrl = TextEditingController();
  Map<String, List<String>> _result = {};
  bool _searched = false;

  void _search() {
    setState(() {
      _result = HanjaDict.instance.nameToHanjaCandidates(_ctrl.text);
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
        const Text('한글 이름을 입력하면 음절별로 해당하는 한자와 한글음·뜻을 종류별로 보여줍니다.',
            style: TextStyle(color: HanjiColors.mukSoft, height: 1.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                hintText: '예) 최상희',
                prefixIcon: Icon(Icons.badge_outlined),
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
                child: Text('한글 이름을 입력해 주세요.',
                    style: TextStyle(color: HanjiColors.mukSoft))),
          ),
        ..._result.entries.map((e) => _SyllableCard(syll: e.key, hanja: e.value)),
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

/// #13 한자음(한글 한 글자) → 해당 한자 목록
class _ReadingSearchTab extends StatefulWidget {
  const _ReadingSearchTab();
  @override
  State<_ReadingSearchTab> createState() => _ReadingSearchTabState();
}

class _ReadingSearchTabState extends State<_ReadingSearchTab> {
  final _ctrl = TextEditingController();
  List<String> _result = [];
  bool _searched = false;

  void _search() {
    final q = _ctrl.text.trim();
    setState(() {
      _result = q.isEmpty ? [] : HanjaDict.instance.byReading(q[0]);
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
        const Text('한자음(한글 한 글자)을 입력하면 그 음을 가진 한자를 음·뜻과 함께 모두 보여줍니다.',
            style: TextStyle(color: HanjiColors.mukSoft, height: 1.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: const InputDecoration(
                hintText: '예) 최, 상, 희',
                prefixIcon: Icon(Icons.translate),
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
        if (_searched)
          Text('"${_ctrl.text.trim()}" — ${_result.length}자',
              style: const TextStyle(
                  color: HanjiColors.ju, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _result
              .map((c) => _HanjaChip(ch: c, reading: _ctrl.text.trim()))
              .toList(),
        ),
      ],
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
