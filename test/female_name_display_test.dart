import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/female_name_display.dart';

void main() {
  test('기록된 여성 이름을 이름 미상으로 바꾸지 않는다', () {
    final p = Person(id: 'p', gender: 'F', surnameHangul: '김', nameHangul: '영희');
    expect(FemaleNameDisplay.forPerson(p), '김영희');
    expect(p.nameHangul, '영희');
  });
  test('이름이 없으면 성씨 또는 성씨 미상을 표시한다', () {
    expect(FemaleNameDisplay.forPerson(Person(id: 'a', gender: 'F', surnameHangul: '이')), '이씨');
    expect(FemaleNameDisplay.forPerson(Person(id: 'b', gender: 'F')), '성씨 미상');
    expect(FemaleNameDisplay.forPerson(Person(id: 'c', gender: 'F', surnameHanja: '李', nameHanja: '貞')), '李貞');
  });
}
