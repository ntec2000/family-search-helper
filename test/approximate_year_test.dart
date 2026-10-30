import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/lunar_service.dart';
import 'package:family_search_helper/services/familysearch_record.dart';

void main() {
  test('간지와 근거 연도로 about 연도를 제안한다', () {
    expect(LunarService.approximateYear('庚戌生', referenceYear: 1852),
        'about 1850');
    expect(LunarService.approximateYear('庚戌生'), isNull);
    expect(LunarService.approximateYear('甲丑生', referenceYear: 1850), isNull);
  });

  test('기준 조상과 세대 차이로 추정하며 근거 없으면 공란', () {
    expect(LunarService.approximateYearByGeneration(
      ancestorBirthYear: 950, ancestorGeneration: 1,
      personGeneration: 32), 'about 1880');
    expect(LunarService.approximateYearByGeneration(
      ancestorBirthYear: null, ancestorGeneration: 1,
      personGeneration: 32), isNull);
  });

  test('FamilySearch 출생에 승인된 about 연도만 반영하고 원문은 유지', () {
    final person = Person(id: 'year-1', nameHanja: '昃',
      surnameHanja: '李', birthDateLunar: '庚戌生',
      birthDateSolar: 'about 1850');
    final record = FamilySearchRecord.person(person);
    final facts = record['facts'] as List;
    expect(facts.first['date']['original'], 'about 1850');
    expect(person.birthDateLunar, '庚戌生');
  });
  test('서기 추정과 간지 생몰 원문을 함께 내보낸다', () {
    final person = Person(id: 'p', nameHanja: '昃',
      birthDateSolar: 'about 1847', birthDateLunar: '丁未年 生',
      deathDateSolar: 'about 1920', deathDateLunar: '庚申八月三日 卒');
    final record = FamilySearchRecord.person(person);
    final facts = record['facts'] as List;
    expect(facts[0]['date']['original'], 'about 1847');
    expect(facts[1]['date']['original'], 'about 1920');
    final notes = (record['notes'] as List).first['text'] as String;
    expect(notes, contains('출생 원문(간지·음력): 丁未年 生'));
    expect(notes, contains('사망 원문(간지·음력): 庚申八月三日 卒'));
  });

  test('빈 양력 날짜 대신 입력된 간지 원문을 유지한다', () {
    final person = Person(id: 'p', birthDateSolar: ' ', birthDateLunar: '丁未生',
        deathDateSolar: '', deathDateLunar: '庚申卒');
    final record = FamilySearchRecord.person(person);
    final facts = record['facts'] as List;
    expect(facts[0]['date']['original'], '丁未生');
    expect(facts[1]['date']['original'], '庚申卒');
    expect(person.birthDateSolar, ' ');
    expect(person.deathDateSolar, '');
  });

  test('빈 날짜와 장소만 있으면 빈 생몰 기록을 만들지 않는다', () {
    final record = FamilySearchRecord.person(Person(id: 'p',
        birthDateSolar: '', birthPlace: ' ', deathDateLunar: ' ', deathPlace: ''));
    expect(record['facts'], isEmpty);
    expect(record.containsKey('living'), isFalse);
  });

  test('FamilySearch 자료에 묘 좌향을 보존하고 빈 묘지 사건은 생략한다', () {
    final record = FamilySearchRecord.person(Person(id: 'p', burialPlace: ' ',
        burialOrientation: '壬坐'));
    expect(record['facts'], isEmpty);
    expect((record['notes'] as List).first['text'], contains('묘 좌향: 壬坐'));
  });

}
