import '../models/person.dart';
import 'genealogy.dart';
import 'hanja_dict.dart';
import 'female_name_display.dart';

/// 저장된 ID 연결만 참고용으로 표시한다. OCR 순서·성씨로 관계를 만들지 않는다.
class FamilyReferenceText {
  final _byId = <String, List<Person>>{};
  final _children = <String, List<Person>>{};

  FamilyReferenceText(Iterable<Person> people) {
    for (final person in people) {
      _byId.putIfAbsent(person.id, () => []).add(person);
      for (final parent in {person.fatherId, person.motherId}) {
        if (parent == null || parent.trim().isEmpty) continue;
        _children.putIfAbsent(parent, () => []).add(person);
      }
    }
  }

  Person? _unique(String id) {
    final records = _byId[id];
    if (records == null || records.length != 1) return null;
    return records.single;
  }

  String _name(Person person) {
    final parts = Genealogy.split(
        hanja: person.nameHanja,
        hangul: person.nameHangul.trim().isNotEmpty
            ? person.nameHangul : HanjaDict.instance.toHangul(person.nameHanja),
        surnameHanja: person.surnameHanja, surnameHangul: person.surnameHangul,
        inferSurnameFromName: false);
    final fullName = '${parts.surnameHangul}${parts.givenHangul}';
    final display = person.gender == 'F' ? FemaleNameDisplay.forPerson(person)
        : fullName.trim().isEmpty ? '이름 미상' : fullName;
    final husband = (person.spouseHangul ?? '').trim().isNotEmpty
        ? person.spouseHangul!.trim() : (person.spouseHanja ?? '').trim();
    final details = <String>[
      if (person.gender == 'F' && (person.relation ?? '').trim().isNotEmpty)
        person.relation!,
      if (person.gender == 'F' &&
          husband.isNotEmpty)
        '남편: $husband',
      '앱 ID: ${person.id}',
    ];
    return '$display (${details.join(', ')})';
  }

  List<String> lines(Person person) {
    final fatherId = (person.fatherId ?? '').trim();
    final father = _unique(fatherId);
    final fatherText = fatherId.isEmpty
        ? '미연결 · 원문/관계 검토 필요'
        : father == null
            ? '확인 필요 (앱 ID: $fatherId · 조회 불가/중복)'
            : father.id == person.id || father.gender != 'M'
                ? '연결 확인 필요 (앱 ID: $fatherId)'
                : _name(father);
    final linked = (_children[person.id] ?? const <Person>[]).where((child) =>
        child.id != person.id && _unique(child.id) != null &&
        ((person.gender == 'M' && child.fatherId == person.id) ||
         (person.gender == 'F' && child.motherId == person.id))).toList();
    String children(String gender) {
      final names = linked.where((child) => child.gender == gender).map(_name);
      return names.isEmpty
          ? '미연결 · 자녀 없음으로 확정하지 않음' : names.join(' · ');
    }
    final unresolved = person.childrenIds.toSet().where((id) =>
        !linked.any((child) => child.id == id));
    final unknown = linked.where((child) => child.gender != 'M' && child.gender != 'F');
    return [
      '가족 참고 기준 : 앱에 저장된 관계 · 원문 대조 필요',
      '참고 아버지 : $fatherText',
      '참고 아들 : ${children('M')}',
      '참고 딸 : ${children('F')}',
      if (unknown.isNotEmpty) '참고 성별 미상 자녀 : ${unknown.map(_name).join(' · ')}',
      if (unresolved.isNotEmpty) '자녀 연결 확인 필요 : ${unresolved.join(', ')}',
      if ((person.childrenNote ?? '').trim().isNotEmpty)
        '자녀 원문 메모(관계 미확정) : ${person.childrenNote}',
    ];
  }
}
