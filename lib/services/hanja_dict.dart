import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// 한자 → 한글 음 사전 (내장).
/// 족보에 빈출하는 한자 + Unicode Unihan 데이터 기반.
class HanjaDict {
  HanjaDict._();
  static final HanjaDict instance = HanjaDict._();

  Map<String, String> _map = {};
  // 한글 음 → 해당 음을 가지는 한자 목록 (역색인). #12/#13 검색용.
  final Map<String, List<String>> _reverse = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/dict/hanja_kor.json');
    _map = Map<String, String>.from(jsonDecode(raw) as Map);
    // 역색인 구성
    _reverse.clear();
    _map.forEach((hanja, reading) {
      _reverse.putIfAbsent(reading, () => []).add(hanja);
    });
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

  /// 한글 음(한 글자)에 해당하는 한자 목록. (#13 한자음으로 검색)
  List<String> byReading(String reading) {
    final r = reading.trim();
    if (r.isEmpty) return const [];
    return List<String>.from(_reverse[r] ?? const []);
  }

  /// 한글 이름(여러 음절)을 음절별 후보 한자 목록으로 변환. (#12)
  /// 예) "최상희" → { '최': [崔,催,...], '상': [...], '희': [...] }
  Map<String, List<String>> nameToHanjaCandidates(String hangulName) {
    final result = <String, List<String>>{};
    for (final r in hangulName.trim().runes) {
      final syll = String.fromCharCode(r);
      if (syll.trim().isEmpty) continue;
      result[syll] = byReading(syll);
    }
    return result;
  }
}
