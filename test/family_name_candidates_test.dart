import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/family_name_candidates.dart';

void main() {
  test('배우자 부모 후보를 표시하고 원문을 보존한다', () {
    final p = Person(id: 'p', gender: 'M', surnameHangul: '이', nameHangul: '격',
        spouseHangul: '조씨', spouseFather: '永復', rawText: '원문');
    final rows = FamilyNameCandidates.fromPerson(p);
    expect(rows.map((r) => r.display).toList(), ['이격', '조씨', '永復', '永復의 부인']);
    expect(rows.last.placeholder, isTrue);
    expect(p.rawText, '원문');
  });
  test('이름 없는 딸과 사위 후보를 구분하며 없는 부모를 생성하지 않는다', () {
    final p = Person(id: 'd', gender: 'F', surnameHangul: '이', spouseHanja: '權龜壽');
    final rows = FamilyNameCandidates.fromPerson(p);
    expect(rows.map((r) => r.display).toList(), ['이씨', '權龜壽']);
    expect(rows.first.placeholder, isTrue);
    expect(rows.last.role, '남편 후보');
  });
}
