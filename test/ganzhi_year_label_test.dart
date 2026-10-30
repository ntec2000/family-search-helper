import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/ganzhi_year_label.dart';
import 'package:family_search_helper/services/familysearch_record.dart';
import 'package:family_search_helper/models/person.dart';

void main() {
  test('출생·사망 간지의 한글 읽기만 표시한다', () {
    expect(GanzhiYearLabel.fromDate('丁未年 生'), '정미년');
    expect(GanzhiYearLabel.fromDate('庚申八月三日卒'), '경신년');
    expect(GanzhiYearLabel.fromDate('忌三月五日'), isNull);
    expect(GanzhiYearLabel.fromDate('甲丑生'), isNull);
  });
  test('추정 연도와 간지 원문 및 한글 읽기를 함께 내보낸다', () {
    final p = Person(id: 'p', birthDateSolar: 'about 1847',
        birthDateLunar: '丁未年 生', deathDateLunar: '庚申八月三日卒');
    final record = FamilySearchRecord.person(p);
    final note = (record['notes'] as List).first['text'] as String;
    expect(note, contains('출생 간지 한글: 정미년'));
    expect(note, contains('사망 간지 한글: 경신년'));
    expect(note, contains('출생 원문(간지·음력): 丁未年 生'));
    expect(note, contains('사망 원문(간지·음력): 庚申八月三日卒'));
    expect(p.birthDateSolar, 'about 1847');
  });
}
