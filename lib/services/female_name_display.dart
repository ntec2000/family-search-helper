import '../models/person.dart';

/// 여성의 이름이 기록돼 있다면 이를 우선하고, 없을 때만 성씨 표시를 쓴다.
class FemaleNameDisplay {
  static String forPerson(Person person) {
    final hangul = person.nameHangul.trim();
    final hanja = person.nameHanja.trim();
    final surname = (person.surnameHangul ?? '').trim();
    if (hangul.isNotEmpty) {
      return surname.isNotEmpty && !hangul.startsWith(surname)
          ? '$surname$hangul' : hangul;
    }
    if (hanja.isNotEmpty) {
      final hanjaSurname = (person.surnameHanja ?? '').trim();
      return hanjaSurname.isNotEmpty && !hanja.startsWith(hanjaSurname)
          ? '$hanjaSurname$hanja' : hanja;
    }
    final value = surname.isNotEmpty ? surname : (person.surnameHanja ?? '').trim();
    return value.isEmpty ? '성씨 미상' : (value.endsWith('씨') || value.endsWith('氏') ? value : '$value씨');
  }
}
