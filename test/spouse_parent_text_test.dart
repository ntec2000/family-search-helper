import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/spouse_parent_text.dart';

void main() {
  test('딸의 남편 부모 정보를 독립적으로 보존한다', () {
    final p = Person(id: 'p', gender: 'F', spouseMother: '박씨');
    expect(SpouseParentText.lines(p), ['배우자 모친: 박씨']);
    expect(p.spouseFather, isNull);
  });
  test('이름 없는 모친은 표시명임을 알리고 부모가 없으면 생성하지 않는다', () {
    expect(SpouseParentText.lines(Person(id: 'p', gender: 'F', spouseFather: '權某')),
        ['배우자 부친: 權某', '배우자 모친: 權某의 부인 (이름 미상)']);
    expect(SpouseParentText.lines(Person(id: 'q', gender: 'F')), isEmpty);
  });
}
