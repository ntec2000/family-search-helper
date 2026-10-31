import '../models/person.dart';

/// Applies a verified surname only to explicitly selected, eligible records.
class SurnameReview {
  /// 한글 성씨만 받으며 '이씨'와 '이'를 같은 작업 성씨로 취급한다.
  static String normalizeHangul(String? input) {
    var value = (input ?? '').replaceAll(RegExp(r'\s+'), '');
    if (value.endsWith('씨')) value = value.substring(0, value.length - 1);
    return RegExp(r'^[가-힣]{1,2}$').hasMatch(value) ? value : '';
  }

  static bool eligible(Person person, String hanja, String hangul) =>
      (person.gender == 'M' || person.gender == 'F') &&
      ((person.surnameHanja ?? '').trim().isEmpty ||
       (hanja.isNotEmpty && person.surnameHanja!.trim() == hanja)) &&
      ((person.surnameHangul ?? '').trim().isEmpty ||
       (hangul.isNotEmpty && person.surnameHangul!.trim() == hangul)) &&
      (((person.surnameHanja ?? '').trim().isEmpty && hanja.isNotEmpty) ||
       ((person.surnameHangul ?? '').trim().isEmpty && hangul.isNotEmpty));

  /// All-or-nothing validation prevents partial changes for stale selections.
  static int applySelected(
    List<Person> persons,
    Set<String> selectedIds, {
    required String hanja,
    required String hangul,
  }) {
    if (selectedIds.isEmpty) return 0;
    if (selectedIds.contains('')) throw StateError('빈 인물 ID는 선택할 수 없습니다.');
    final selected = persons.where((p) => selectedIds.contains(p.id)).toList();
    if (selected.length != selectedIds.length ||
        selected.map((p) => p.id).toSet().length != selectedIds.length ||
        selected.any((p) => !eligible(p, hanja, hangul))) {
      throw StateError('선택한 인물 또는 성씨 정보가 변경되었습니다.');
    }
    for (final person in selected) {
      if ((person.surnameHanja ?? '').trim().isEmpty && hanja.isNotEmpty) {
        person.surnameHanja = hanja;
      }
      if ((person.surnameHangul ?? '').trim().isEmpty && hangul.isNotEmpty) {
        person.surnameHangul = hangul;
      }
      person.updatedAt = DateTime.now();
    }
    return selected.length;
  }
}
