import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/familysearch_record.dart';

void main() {
  test('검토한 부부 및 기존 부모 자녀 관계를 별도로 출력한다', () {
    final father = Person(id: 'father', gender: 'M', spouseHanja: '趙氏');
    final mother = Person(id: 'mother', gender: 'F');
    final child = Person(id: 'child', fatherId: 'father', motherId: 'mother');
    final doc = FamilySearchRecord.document([father, mother, child],
      reviewedCouples: [('father', 'mother')]);
    final relationships = doc['relationships'] as List;
    final couple = relationships.singleWhere((r) => r['type'] == 'http://gedcomx.org/Couple');
    expect(couple['person1']['resource'], '#father');
    expect(couple['person2']['resource'], '#mother');
    expect(relationships.where((r) => r['type'] == 'http://gedcomx.org/ParentChild').length, 2);
    expect(father.spouseHanja, '趙氏');
  });
  test('명시하지 않은 관계는 배우자 메모에서 추정하지 않는다', () {
    final people = [Person(id: 'a', spouseHangul: '조씨'), Person(id: 'b')];
    expect(FamilySearchRecord.document(people)['relationships'], isEmpty);
  });
  test('자기 자신, 누락 ID, 역순 중복 관계를 거부한다', () {
    final people = [Person(id: 'a'), Person(id: 'b')];
    for (final couples in <List<(String, String)>>[
      [('a', 'a')], [('a', 'missing')], [('a', 'b'), ('b', 'a')],
    ]) {
      expect(() => FamilySearchRecord.document(people, reviewedCouples: couples),
          throwsStateError);
    }
  });
}
