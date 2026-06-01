import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// 한자 → 한글 음 사전 (내장).
/// 족보에 빈출하는 한자 + Unicode Unihan 데이터 기반.
class HanjaDict {
  HanjaDict._();
  static final HanjaDict instance = HanjaDict._();

  Map<String, String> _map = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/dict/hanja_kor.json');
    _map = Map<String, String>.from(jsonDecode(raw) as Map);
    _loaded = true;
  }

  /// 단일 한자의 첫번째 음 (없으면 그대로 반환)
  String reading(String ch) => _map[ch] ?? ch;

  /// 한자 문자열을 한글 음으로 변환. 한자가 아닌 글자는 그대로.
  String toHangul(String text) {
    final buf = StringBuffer();
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      buf.write(_map[ch] ?? ch);
    }
    return buf.toString();
  }

  /// 사전에 등록된 한자 여부
  bool contains(String ch) => _map.containsKey(ch);

  int get size => _map.length;
}
