import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/unknown_spouse_name.dart';

void main() {
  test('남편 홍길동, 아내 이름 미상 -> 홍길동의 부인', () {
    final husband = Person(id: 'husband', gender: 'M', nameHangul: '홍길동');
    expect(UnknownSpouseName.wifeDisplayName(husband), '홍길동의 부인');
  });

  test('남편 성과 이름이 별도 필드면 합쳐 표시한다', () {
    final husband = Person(id: 'husband', gender: 'M',
        surnameHangul: '이', nameHangul: '격');
    expect(UnknownSpouseName.wifeDisplayName(husband), '이격의 부인');
  });

  test('확인된 아내 이름은 우선하고 원문 배우자 필드를 보존한다', () {
    final husband = Person(id: 'husband', gender: 'M',
        nameHangul: '홍길동', spouseHanja: '原州邊氏');
    expect(UnknownSpouseName.wifeDisplayName(husband,
        confirmedWifeName: '김영희'), '김영희');
    expect(husband.spouseHanja, '原州邊氏');
    expect(husband.spouseHangul, isNull);
  });

  test('남편 이름 미상이나 성별 불일치면 이름을 추측하지 않는다', () {
    expect(UnknownSpouseName.wifeDisplayName(
        Person(id: 'x', gender: 'M')), isNull);
    expect(UnknownSpouseName.wifeDisplayName(
        Person(id: 'y', gender: 'F', nameHangul: '홍길동')), isNull);
  });
}
