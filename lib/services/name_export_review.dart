import '../models/person.dart';

/// 성씨와 이름의 경계가 불명확한 입력을 검토 대상으로만 표시한다.
class NameExportReview {
  static bool overlaps(String name, String? surname) {
    final value = name.trim();
    final family = (surname ?? '').trim();
    return family.isNotEmpty && value.length >= family.length && value.startsWith(family);
  }

  static bool needsReview(Person person) =>
      overlaps(person.nameHangul, person.surnameHangul) ||
      overlaps(person.nameHanja, person.surnameHanja);
}
