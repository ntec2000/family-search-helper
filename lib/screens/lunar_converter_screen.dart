import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/lunar_service.dart';
import '../theme/traditional_theme.dart';

class LunarConverterScreen extends StatefulWidget {
  const LunarConverterScreen({super.key});
  @override
  State<LunarConverterScreen> createState() => _LunarConverterScreenState();
}

class _LunarConverterScreenState extends State<LunarConverterScreen> {
  DateTime _solar = DateTime.now();
  Map<String, String>? _result;
  final _ganzhiCtrl = TextEditingController();
  List<int> _guessYears = [];

  void _convert() {
    setState(() => _result = LunarService.solarToLunar(_solar));
  }

  String? _normalized;

  void _guessGanzhi() {
    final input = _ganzhiCtrl.text.trim();
    final gz = LunarService.normalizeGanzhi(input);
    setState(() {
      _normalized = gz;
      _guessYears =
          gz == null ? [] : LunarService.estimateYearsFromInput(input);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('만세력')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 48), children: [
        const Text('① 양력 → 음력·간지',
            style: TextStyle(fontWeight: FontWeight.bold, color: HanjiColors.ju, fontSize: 16)),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('선택된 양력: ${DateFormat('yyyy-MM-dd').format(_solar)}'),
          trailing: ElevatedButton(
            onPressed: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: _solar,
                  firstDate: DateTime(1700),
                  lastDate: DateTime(2100));
              if (d != null) setState(() => _solar = d);
            },
            child: const Text('날짜 선택'),
          ),
        ),
        ElevatedButton(onPressed: _convert, child: const Text('변환')),
        if (_result != null) _ResultBox(map: _result!),
        const SizedBox(height: 32),
        const Text('② 干支 → 가능한 양력 연도 추정',
            style: TextStyle(fontWeight: FontWeight.bold, color: HanjiColors.ju, fontSize: 16)),
        const Divider(),
        TextField(
          controller: _ganzhiCtrl,
          decoration: const InputDecoration(
            labelText: '간지 입력 (한글/한자) — 예: 갑오년, 乙卯, 기사',
            hintText: '갑오년',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _guessGanzhi(),
        ),
        const SizedBox(height: 8),
        if (_normalized != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('표준 간지: $_normalized',
                style: const TextStyle(
                    color: HanjiColors.muk, fontWeight: FontWeight.bold)),
          ),
        if (_normalized != null && _guessYears.isEmpty)
          const Text('해당 간지의 연도를 찾을 수 없습니다.',
              style: TextStyle(color: HanjiColors.mukSoft)),
        if (_guessYears.isNotEmpty)
          Wrap(
            spacing: 8,
            children: _guessYears
                .map((y) => Chip(label: Text('$y년')))
                .toList(),
          ),
      ])),
    );
  }
}

class _ResultBox extends StatelessWidget {
  final Map<String, String> map;
  const _ResultBox({required this.map});

  /// 만세력 변환 결과 키(영문)를 한글 표기로 변환한다.
  static const _labels = <String, String>{
    'lunar_year': '음력 연(年)',
    'lunar_month': '음력 월(月)',
    'lunar_day': '음력 일(日)',
    'ganzhi_year': '간지(干支) 연 — 세차(歲次)',
    'ganzhi_month': '간지(干支) 월 — 월건(月建)',
    'ganzhi_day': '간지(干支) 일 — 일진(日辰)',
    'animal': '띠(十二支)',
    'lunar_text': '음력 표기',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HanjiColors.hanjiLight,
        border: Border.all(color: HanjiColors.mukSoft, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: map.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${_labels[e.key] ?? e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 14, height: 1.6)),
                ))
            .toList(),
      ),
    );
  }
}
