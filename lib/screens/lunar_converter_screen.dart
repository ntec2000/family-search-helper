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

  void _guessGanzhi() {
    final g = _ganzhiCtrl.text.trim();
    if (!LunarService.isValidGanzhi(g)) {
      setState(() => _guessYears = []);
      return;
    }
    setState(() => _guessYears = LunarService.estimateYearsFromGanzhi(g));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('만세력')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
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
            labelText: '干支 (예: 乙卯, 己巳)',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _guessGanzhi(),
        ),
        const SizedBox(height: 8),
        if (_guessYears.isNotEmpty)
          Wrap(
            spacing: 8,
            children: _guessYears
                .map((y) => Chip(label: Text('$y년')))
                .toList(),
          ),
      ]),
    );
  }
}

class _ResultBox extends StatelessWidget {
  final Map<String, String> map;
  const _ResultBox({required this.map});
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
                  child: Text('${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 14, height: 1.6)),
                ))
            .toList(),
      ),
    );
  }
}
