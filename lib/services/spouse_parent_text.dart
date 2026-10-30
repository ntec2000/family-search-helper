import '../models/person.dart';

/// 배우자 부모 기록을 원문 그대로 표시하며 이름 미상 표시는 구분한다.
class SpouseParentText {
  static List<String> lines(Person person) {
    final father = (person.spouseFather ?? '').trim();
    final mother = (person.spouseMother ?? '').trim();
    return [
      if (father.isNotEmpty) '배우자 부친: $father',
      if (mother.isNotEmpty) '배우자 모친: $mother'
      else if (father.isNotEmpty) '배우자 모친: $father의 부인 (이름 미상)',
    ];
  }
}
