import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// 한자 사전 (내장).
/// - hanja_kor.json : 한자 → 대표 한글 음 (단일)
/// - hanja_info.json: 한자 → { e:[음...], h:[훈음...] }  (#15 음·뜻, 복수음)
class HanjaInfo {
  final List<String> eum;   // 한글 음 목록 (대표음이 첫번째)
  final List<String> hun;   // 훈음 문자열 목록 (예: "뫼 산")
  const HanjaInfo(this.eum, this.hun);

  /// 대표 음
  String get primary => eum.isNotEmpty ? eum.first : '';

  /// "음1·음2" 형태 (복수음 표기)
  String get eumLabel => eum.join('·');

  /// "뜻 음" 형태 한 줄 요약 (대표 훈음)
  String get glossLine => hun.isNotEmpty ? hun.first : (eum.isNotEmpty ? eum.first : '');
}

class HanjaDict {
  HanjaDict._();
  static final HanjaDict instance = HanjaDict._();

  Map<String, String> _map = {};
  final Map<String, HanjaInfo> _info = {};
  // 한글 음 → 해당 음을 가지는 한자 목록 (역색인). #12/#13 검색용.
  final Map<String, List<String>> _reverse = {};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/dict/hanja_kor.json');
    _map = Map<String, String>.from(jsonDecode(raw) as Map);

    // 풍부한 정보(복수음·훈음) 로드 (#15)
    try {
      final rawInfo =
          await rootBundle.loadString('assets/dict/hanja_info.json');
      final m = jsonDecode(rawInfo) as Map<String, dynamic>;
      m.forEach((ch, v) {
        final map = v as Map<String, dynamic>;
        final eum = List<String>.from(map['e'] as List? ?? const []);
        final hun = List<String>.from(map['h'] as List? ?? const []);
        _info[ch] = HanjaInfo(eum, hun);
      });
    } catch (_) {
      // info 사전이 없어도 기본 동작 유지
    }

    // 역색인 구성: 대표음 + 모든 복수음 포함
    _reverse.clear();
    _map.forEach((hanja, reading) {
      _reverse.putIfAbsent(reading, () => []).add(hanja);
    });
    _info.forEach((hanja, info) {
      for (final e in info.eum) {
        final list = _reverse.putIfAbsent(e, () => []);
        if (!list.contains(hanja)) list.add(hanja);
      }
    });
    _loaded = true;
  }

  /// 단일 한자의 대표 음 (없으면 그대로 반환)
  String reading(String ch) =>
      _map[ch] ?? (_info[ch]?.primary.isNotEmpty == true ? _info[ch]!.primary : ch);

  /// 한자의 모든 음 목록 (#15 음이 여러개일 때)
  List<String> readingsAll(String ch) {
    final info = _info[ch];
    if (info != null && info.eum.isNotEmpty) return info.eum;
    final r = _map[ch];
    return r != null ? [r] : const [];
  }

  /// 한자의 훈음(뜻) 목록 (#15)
  List<String> meanings(String ch) => _info[ch]?.hun ?? const [];

  /// 한자의 상세 정보 (음·훈음)
  HanjaInfo? info(String ch) => _info[ch];

  /// "한자(음)" 또는 "한자(음1·음2)" 라벨. 한자가 아니면 그대로.
  /// (#3 모든 한자에 한자(한글) 병기)
  String withReadingLabel(String ch) {
    final info = _info[ch];
    if (info != null && info.eum.isNotEmpty) return '$ch(${info.eumLabel})';
    final r = _map[ch];
    return r != null ? '$ch($r)' : ch;
  }

  /// 한자 문자열을 한글 음으로 변환. 한자가 아닌 글자는 그대로.
  String toHangul(String text) {
    final buf = StringBuffer();
    for (final r in text.runes) {
      final ch = String.fromCharCode(r);
      buf.write(_map[ch] ?? (_info[ch]?.primary ?? ch));
    }
    return buf.toString();
  }

  /// "崔海斗" → "崔海斗(최해두)" 형태로 한자 뒤에 한글음을 괄호로 병기. (#3)
  /// 한자가 하나도 없으면 원문 그대로.
  String annotate(String text) {
    if (text.trim().isEmpty) return text;
    final hangul = toHangul(text);
    final hasHanja = text.runes.any((r) {
      final ch = String.fromCharCode(r);
      return _map.containsKey(ch) || _info.containsKey(ch);
    });
    if (!hasHanja || hangul == text) return text;
    return '$text($hangul)';
  }

  /// 사전에 등록된 한자 여부
  bool contains(String ch) => _map.containsKey(ch) || _info.containsKey(ch);

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
