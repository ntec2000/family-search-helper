import '../models/person.dart';
import 'genealogy.dart';
import 'hanja_dict.dart';

/// 배우자 부모 기록을 원문 그대로 표시하며 이름 미상 표시는 구분한다.
class SpouseParentText {
  /// 배우자의 성씨를 부친의 짧은 이름에 조합한 표시 후보. 원문 필드는 보존한다.
  static String candidateFatherName(Person person) {
    final father = (person.spouseFather ?? '').trim();
    final surname = person.gender == 'F'
        ? Genealogy.personalNameSurname(person.spouseHanja ?? '')
        : Genealogy.spouseSurname(person.spouseHanja);
    if (father.isEmpty || surname == null || father.length > 2 ||
        !RegExp(r'^[㐀-鿿]+$').hasMatch(father) ||
        Genealogy.surnamesHanja.contains(father[0])) {
      return father;
    }
    return Genealogy.surnamePrefixedName(father, surname.$1);
  }

  static List<String> lines(Person person) {
    final father = (person.spouseFather ?? '').trim();
    final mother = (person.spouseMother ?? '').trim();
    final combined = candidateFatherName(person);
    final inferred = person.gender == 'F' && combined != father;
    final display = inferred
        ? '$combined (${HanjaDict.instance.toHangul(combined)}) · 성씨 조합 후보'
        : father;
    return [
      if (father.isNotEmpty) '배우자 부친: $display',
      if (mother.isNotEmpty) '배우자 모친: $mother'
      else if (father.isNotEmpty)
        inferred ? '배우자 모친 표시명(원문 미확인): $combined의 부인 (이름 미상)'
            : '배우자 모친: $father의 부인 (이름 미상)',
    ];
  }
}
