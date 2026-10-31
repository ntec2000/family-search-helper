import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/familysearch_comparison_summary.dart';

void main() {
  test('기록된 이름과 생몰의 날짜·장소만 요약한다', () {
    final lines = FamilySearchComparisonSummary.lines({
      'names': [{'nameForms': [{'fullText': '이격'}]}],
      'facts': [
        {'type': 'http://gedcomx.org/Birth', 'date': {'original': '壬辰生'}},
        {'type': 'http://gedcomx.org/Death', 'place': {'original': '경주'}},
      ],
    });
    expect(lines, ['이름: 이격', '출생: 날짜: 壬辰生', '사망: 장소: 경주']);
  });
  test('원문이 없는 정규화 날짜도 차이 비교에 표시한다', () {
    final remote = {'facts': [
      {'type': 'http://gedcomx.org/Birth', 'date': {'formal': '+1800'}},
    ]};
    final app = {'facts': [
      {'type': 'http://gedcomx.org/Birth', 'date': {'original': '1801'}},
    ]};
    final diff = FamilySearchComparisonSummary.differences(remote, app);
    expect(diff.remoteOnly, ['출생: 날짜 정규화 값: +1800']);
    expect(diff.appOnly, ['출생: 날짜: 1801']);
  });
  test('자료가 누락되거나 잘못된 형태면 없는 값을 만들지 않는다', () {
    final lines = FamilySearchComparisonSummary.lines({'names': [null], 'facts': '잘못된 자료'});
    expect(lines.single, contains('전체 자료를 확인'));
  });
  test('기존과 앱에만 있는 표기를 분리하고 빈 자료 안내는 차이로 만들지 않는다', () {
    final remote = {'names': [{'nameForms': [{'fullText': '이격'}]}]};
    final app = {'names': [{'nameForms': [{'fullText': '이핵'}]}]};
    final diff = FamilySearchComparisonSummary.differences(remote, app);
    expect(diff.remoteOnly, ['이름: 이격']);
    expect(diff.appOnly, ['이름: 이핵']);
    final missing = FamilySearchComparisonSummary.differences({}, app);
    expect(missing.remoteOnly, isEmpty);
    expect(missing.appOnly, ['이름: 이핵']);
  });
}
