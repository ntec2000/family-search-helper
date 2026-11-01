import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/family_reference_text.dart';

void main() {
  test('부모의 자녀 목록만 있거나 다른 부친이 연결된 자녀는 아들로 확정하지 않는다', () {
    final parent = Person(id: 'p', gender: 'M', childrenIds: ['c', 'missing']);
    final child = Person(id: 'c', gender: 'M', surnameHangul: '이',
        nameHangul: '갑', fatherId: 'other');
    final before = parent.toMap();
    final text = FamilyReferenceText([parent, child]).lines(parent).join('\n');
    expect(text, contains('참고 아들 : 미연결'));
    expect(text, contains('자녀 연결 확인 필요 : c, missing'));
    expect(text, isNot(contains('이갑')));
    expect(parent.toMap(), before);
  });

  test('조회 불가·중복·성별 오류 부친 ID는 성명으로 확정하지 않는다', () {
    final child = Person(id: 'c', fatherId: 'f');
    expect(FamilyReferenceText([child]).lines(child).join('\n'),
        contains('앱 ID: f · 조회 불가/중복'));
    final female = Person(id: 'f', gender: 'F', nameHangul: '영희');
    expect(FamilyReferenceText([child, female]).lines(child).join('\n'),
        contains('연결 확인 필요 (앱 ID: f)'));
    final father = Person(id: 'f', gender: 'M', nameHangul: '갑');
    final duplicate = Person(id: 'f', gender: 'M', nameHangul: '을');
    final text = FamilyReferenceText([child, father, duplicate]).lines(child).join('\n');
    expect(text, contains('조회 불가/중복'));
    expect(text, isNot(contains('참고 아버지 : 갑')));
  });

  test('딸의 빈 한글 남편명은 한자로 보완하고 성별 미상 자녀는 구분한다', () {
    final parent = Person(id: 'p', gender: 'M');
    final daughter = Person(id: 'd', gender: 'F', surnameHangul: '이',
        relation: '첫째딸', fatherId: 'p', spouseHangul: '', spouseHanja: '金甲');
    final unknown = Person(id: 'u', gender: 'U', nameHangul: '정', fatherId: 'p');
    final text = FamilyReferenceText([parent, daughter, unknown]).lines(parent).join('\n');
    expect(text, contains('참고 딸 : 이씨 (첫째딸, 남편: 金甲, 앱 ID: d)'));
    expect(text, contains('참고 성별 미상 자녀 : 정 (앱 ID: u)'));
    expect(text, contains('참고 아들 : 미연결'));
  });
}
