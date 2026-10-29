import '../models/person.dart';

/// 아내 표시명: 확인된 실제 이름 > 기록된 성씨 > 남편 이름의 부인.
/// 표시 전용이며 원본 OCR과 저장된 인명 필드를 변경하지 않는다.
class UnknownSpouseName {
  static String? wifeDisplayName(Person husband, {String? confirmedWifeName}) {
    final known = confirmedWifeName?.trim();
    if (known != null && known.isNotEmpty) return known;
    if (husband.gender != 'M') return null;
    final korean = (husband.spouseHangul ?? '').trim();
    if (RegExp(r'^[가-힣]{1,2}씨$').hasMatch(korean)) return korean;
    final hanja = (husband.spouseHanja ?? '').trim();
    const surnames = <String, String>{
      '尹': '윤', '邊': '변', '金': '김', '李': '이',
      '朴': '박', '崔': '최', '趙': '조', '權': '권',
    };
    if (hanja.endsWith('氏') && hanja.length >= 2) {
      final character = hanja.substring(hanja.length - 2, hanja.length - 1);
      final reading = surnames[character];
      if (reading != null) return '$reading씨';
      return hanja;
    }
    final name = husband.nameHangul.trim();
    final surname = (husband.surnameHangul ?? '').trim();
    final fullName = name.isEmpty ? '' :
        (surname.isNotEmpty && !name.startsWith(surname) ? '$surname$name' : name);
    if (fullName.isEmpty) return null;
    return '$fullName의 부인';
  }
}
