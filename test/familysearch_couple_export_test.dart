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
  test('성과 입력 이름이 겹치면 원래 표기와 확인 필요성을 기록한다', () {
    final p = Person(id: 'p', surnameHangul: '이', surnameHanja: '李',
        nameHangul: '이인', nameHanja: '李仁');
    final record = FamilySearchRecord.person(p);
    final note = ((record['notes'] as List).first as Map)['text'] as String;
    expect(note, contains('전체 이름인지 개인 이름인지 원본 확인 필요'));
    expect(note, contains('입력된 이름(한글): 이인'));
    expect(note, contains('입력된 이름(한자): 李仁'));
    expect(p.nameHangul, '이인');
    expect(p.nameHanja, '李仁');
  });
  test('겹침이 없는 이름에는 중복 확인 주석을 만들지 않는다', () {
    final p = Person(id: 'p', surnameHangul: '이', nameHangul: '격');
    expect(FamilySearchRecord.person(p).toString(), isNot(contains('입력된 이름(한글)')));
  });
  test('명시하지 않은 관계는 배우자 메모에서 추정하지 않는다', () {
    final people = [Person(id: 'a', spouseHangul: '조씨'), Person(id: 'b')];
    expect(FamilySearchRecord.document(people)['relationships'], isEmpty);
  });
  test('같은 인물이 양쪽 부모인 경우 중복 부모 관계를 내보내지 않는다', () {
    final people = [Person(id: 'parent'),
      Person(id: 'child', fatherId: 'parent', motherId: 'parent')];
    expect(() => FamilySearchRecord.document(people), throwsStateError);
  });
  test('자기 자신을 부모로 지정한 기록은 내보내기를 차단한다', () {
    for (final person in [Person(id: 'p', fatherId: 'p'),
        Person(id: 'p', motherId: 'p')]) {
      expect(() => FamilySearchRecord.document([person]), throwsStateError);
    }
  });
  test('여러 인물의 순환 부모 관계를 내보내지 않는다', () {
    final people = [Person(id: 'a', fatherId: 'b'),
      Person(id: 'b', fatherId: 'c'), Person(id: 'c', fatherId: 'a')];
    expect(() => FamilySearchRecord.document(people), throwsStateError);
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
