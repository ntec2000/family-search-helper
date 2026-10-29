import '../models/person.dart';

/// 표시 전용 규칙: 아내의 개인 이름이 확인되지 않으면 남편의 이름으로 표시한다.
/// 배우자 원문, 본관, 성씨 및 실제 이름 필드는 변경하지 않는다.
class UnknownSpouseName {
  static String? wifeDisplayName(Person husband, {String? confirmedWifeName}) {
    final known = confirmedWifeName?.trim();
    if (known != null && known.isNotEmpty) return known;
    if (husband.gender != 'M') return null;
    final name = husband.nameHangul.trim();
    final surname = (husband.surnameHangul ?? '').trim();
    final fullName = name.isEmpty ? '' :
        (surname.isNotEmpty && !name.startsWith(surname) ? '$surname$name' : name);
    if (fullName.isEmpty) return null;
    return '$fullName의 부인';
  }
}
