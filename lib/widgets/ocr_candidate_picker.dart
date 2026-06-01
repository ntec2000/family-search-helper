import 'package:flutter/material.dart';
import '../services/hanja_dict.dart';
import '../theme/traditional_theme.dart';

/// OCR 인식 결과 한자의 다중 후보를 선택할 수 있는 위젯.
/// 필사본·초서 등 인식이 불확실한 경우 사용자가 직접 수정 가능.
class OcrCandidatePicker extends StatefulWidget {
  final String original;
  final ValueChanged<String> onChanged;
  const OcrCandidatePicker(
      {super.key, required this.original, required this.onChanged});

  @override
  State<OcrCandidatePicker> createState() => _State();
}

class _State extends State<OcrCandidatePicker> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.original);
  }

  // 한자가 시각적으로 유사한 후보를 표시 (간단한 부수 기반 + 자주 혼동되는 짝)
  static const Map<String, List<String>> _confused = {
    '己': ['已', '巳'],
    '已': ['己', '巳'],
    '巳': ['己', '已'],
    '戌': ['戊', '戍'],
    '戊': ['戌', '戍'],
    '日': ['曰', '目'],
    '土': ['士'],
    '士': ['土'],
    '末': ['未'],
    '未': ['末'],
    '太': ['大', '夫'],
    '大': ['太', '犬'],
    '王': ['玉', '主'],
  };

  List<String> _candidates(String ch) {
    if (ch.isEmpty) return [];
    return _confused[ch] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          style: const TextStyle(fontSize: 22, letterSpacing: 4),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '한자 (수정 가능)',
          ),
          onChanged: (v) {
            widget.onChanged(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 8),
        Text('한글 음: ${HanjaDict.instance.toHangul(_ctrl.text)}',
            style: const TextStyle(color: HanjiColors.cheong, fontSize: 14)),
        if (_ctrl.text.length == 1) ...[
          const SizedBox(height: 12),
          const Text('혼동 가능 후보:',
              style: TextStyle(fontSize: 12, color: HanjiColors.mukSoft)),
          Wrap(
            spacing: 8,
            children: _candidates(_ctrl.text)
                .map((c) => ActionChip(
                      label: Text(c, style: const TextStyle(fontSize: 18)),
                      onPressed: () {
                        _ctrl.text = c;
                        widget.onChanged(c);
                        setState(() {});
                      },
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}
