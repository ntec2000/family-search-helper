import '../models/person.dart';
import 'genealogy.dart';

/// 아내 표시명: 확인된 실제 이름 > 기록된 성씨 > 남편 이름의 부인.
/// 표시 전용이며 원본 OCR과 저장된 인명 필드를 변경하지 않는다.
class UnknownSpouseName {
  /// 명시된 배우자 관련 항목이 있을 때만 미상 표시 후보를 만든다.
  static bool hasSpouseEvidence(Person person) => [
    person.spouseHanja, person.spouseHangul, person.spouseBongwan,
    person.spouseFather, person.spouseMother, person.spouseBirth, person.spouseDeath,
  ].any((value) => (value ?? '').trim().isNotEmpty);

  /// 배우자 개인 이름으로 읽힌 후보가 있으면 미상 표시명을 내보내지 않는다.
  static bool hasPersonalNameCandidate(Person person) {
    final korean = (person.spouseHangul ?? '').trim();
    if (korean.isNotEmpty && !korean.endsWith('씨')) return true;
    final hanja = (person.spouseHanja ?? '').trim();
    return hanja.isNotEmpty && !hanja.endsWith('氏');
  }

  static String? wifeDisplayName(Person husband, {String? confirmedWifeName}) {
    final known = confirmedWifeName?.trim();
    if (known != null && known.isNotEmpty) return known;
    if (husband.gender != 'M') return null;
    final korean = (husband.spouseHangul ?? '').trim();
    if (RegExp(r'^[가-힣]{1,2}씨$').hasMatch(korean)) return korean;
    // 본관은 별도 필드 또는 공백으로 명확히 구분된 경우에만 제외한다.
    final bongwan = (husband.spouseBongwan ?? '').trim();
    if (bongwan.isNotEmpty && korean.startsWith(bongwan)) {
      final surname = korean.substring(bongwan.length).trim();
      if (RegExp(r'^[가-힣]{1,2}씨$').hasMatch(surname)) return surname;
    }
    final separated = RegExp(r'^[가-힣]+\s+([가-힣]{1,2}씨)$')
        .firstMatch(korean);
    if (separated != null) return separated.group(1);
    final hanja = (husband.spouseHanja ?? '').trim();
    // 한자 복성이 단독이거나 별도 본관과 분리되는 경우에만 읽는다.
    const compoundSurnames = <String, String>{
      '南宮': '남궁', '諸葛': '제갈', '皇甫': '황보',
      '鮮于': '선우', '司空': '사공', '西門': '서문', '東方': '동방',
    };
    final hanjaName = bongwan.isNotEmpty && hanja.startsWith(bongwan)
        ? hanja.substring(bongwan.length) : hanja;
    if (hanjaName.endsWith('氏')) {
      final compound = compoundSurnames[hanjaName.substring(0, hanjaName.length - 1)];
      if (compound != null) return '$compound씨';
    }
    if (hanja.endsWith('氏') && hanja.length >= 2) {
      final surname = Genealogy.spouseSurname(hanjaName);
      if (surname != null) return '${surname.$2}씨';
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
