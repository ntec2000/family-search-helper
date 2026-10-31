/// FamilySearch GEDCOM-X 자료에서 확인 가능한 값만 읽기 쉽게 요약한다.
class FamilySearchComparisonSummary {
  static List<String> lines(Map<String, dynamic> person) {
    final result = <String>[];
    final names = person['names'];
    if (names is List) {
      for (final name in names) {
        if (name is! Map || name['nameForms'] is! List) continue;
        for (final form in name['nameForms'] as List) {
          if (form is! Map) continue;
          final value = form['fullText'];
          if (value is String && value.trim().isNotEmpty) {
            result.add('이름: ${value.trim()}');
          }
        }
      }
    }
    final facts = person['facts'];
    if (facts is List) {
      for (final fact in facts) {
        if (fact is! Map) continue;
        final type = fact['type'];
        final label = switch (type) {
          'http://gedcomx.org/Birth' => '출생',
          'http://gedcomx.org/Death' => '사망',
          'http://gedcomx.org/Burial' => '묘지',
          _ => null,
        };
        if (label == null) continue;
        final date = fact['date'];
        final place = fact['place'];
        final values = <String>[];
        if (date is Map && date['original'] is String &&
            (date['original'] as String).trim().isNotEmpty) {
          values.add('날짜: ${(date['original'] as String).trim()}');
        }
        if (place is Map && place['original'] is String &&
            (place['original'] as String).trim().isNotEmpty) {
          values.add('장소: ${(place['original'] as String).trim()}');
        }
        result.add('$label: ${values.isEmpty ? '상세 내용 없음' : values.join(' · ')}');
      }
    }
    return result.isEmpty ? ['표시할 이름·생몰 정보가 없습니다. 전체 자료를 확인하세요.'] : result;
  }
}
