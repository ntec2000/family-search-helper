import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/unknown_spouse_name.dart';
import 'package:family_search_helper/services/familysearch_record.dart';
import 'package:family_search_helper/services/gedcom_export.dart';

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
  test('본관과 성씨가 있으면 남편 이름 대신 성씨만 표시한다', () {
    final husband = Person(id: 'h', gender: 'M', nameHangul: '홍길동',
        spouseHanja: '坡平尹氏', spouseBongwan: '坡平');
    expect(UnknownSpouseName.wifeDisplayName(husband), '윤씨');
    expect(husband.spouseHanja, '坡平尹氏');
    expect(husband.spouseBongwan, '坡平');
  });

  test('원주 변씨와 성씨만 기록된 김씨를 구분한다', () {
    expect(UnknownSpouseName.wifeDisplayName(Person(id: 'b', gender: 'M',
        nameHangul: '홍길동', spouseHanja: '原州邊氏')), '변씨');
    expect(UnknownSpouseName.wifeDisplayName(Person(id: 'k', gender: 'M',
        nameHangul: '홍길동', spouseHanja: '金氏')), '김씨');
  });

  test('FamilySearch: 성씨 표시명은 메모로만 내보낸다', () {
    final husband = Person(id: 'h', gender: 'M', nameHangul: '홍길동',
        spouseHanja: '坡平尹氏', spouseBongwan: '坡平');
    final record = FamilySearchRecord.person(husband);
    final notes = (record['notes'] as List).first['text'] as String;
    expect(notes, contains('아내 표시명(실제 개인 이름 아님): 윤씨'));
    expect(notes, contains('배우자: 坡平尹氏'));
    expect(record['names'].toString(), isNot(contains('윤씨')));
  });

  test('GEDCOM: 아내 표시명은 NOTE이고 새 인물로 만들지 않는다', () {
    final husband = Person(id: 'h', gender: 'M', nameHangul: '홍길동',
        spouseHanja: '坡平尹氏');
    final gedcom = GedcomExport.toGedcom([husband]);
    expect(gedcom, contains('1 NOTE 아내 표시명(실제 개인 이름 아님): 윤씨'));
    expect(gedcom, isNot(contains('1 NAME 윤씨')));
    expect(RegExp(r' INDI$' , multiLine: true).allMatches(gedcom).length, 1);
  });

  test('한글 본관과 성씨 입력은 성씨만 표시하고 원문을 보존한다', () {
    for (final input in ['파평 윤씨', '파평윤씨', '파평  윤씨']) {
      final husband = Person(id: 'h', gender: 'M', nameHangul: '홍길동',
          spouseHangul: input, spouseBongwan: '파평');
      final original = husband.toMap();
      expect(UnknownSpouseName.wifeDisplayName(husband), '윤씨');
      expect(husband.toMap(), original);
    }
  });

  test('본관 필드가 없어도 공백으로 구분된 성씨를 표시한다', () {
    final husband = Person(id: 'h', gender: 'M', nameHangul: '홍길동',
        spouseHangul: '파평 윤씨');
    expect(UnknownSpouseName.wifeDisplayName(husband), '윤씨');
  });

  test('복성은 유지하고 불명확한 붙여쓰기는 추측하지 않는다', () {
    expect(UnknownSpouseName.wifeDisplayName(Person(id: 'h', gender: 'M',
        nameHangul: '홍길동', spouseHangul: '함열 남궁씨')), '남궁씨');
    expect(UnknownSpouseName.wifeDisplayName(Person(id: 'h', gender: 'M',
        nameHangul: '홍길동', spouseHangul: '파평윤씨')), '홍길동의 부인');
  });

  test('한글 본관 성씨도 내보내기에 실제 이름으로 추가하지 않는다', () {
    final husband = Person(id: 'h', gender: 'M', nameHangul: '홍길동',
        spouseHangul: '파평 윤씨', spouseBongwan: '파평');
    final record = FamilySearchRecord.person(husband);
    final notes = (record['notes'] as List).first['text'] as String;
    expect(notes, contains('아내 표시명(실제 개인 이름 아님): 윤씨'));
    expect(record['names'].toString(), isNot(contains('윤씨')));
    final gedcom = GedcomExport.toGedcom([husband]);
    expect(gedcom, contains('1 NOTE 아내 표시명(실제 개인 이름 아님): 윤씨'));
    expect(RegExp(r' INDI$', multiLine: true).allMatches(gedcom).length, 1);
  });

}
