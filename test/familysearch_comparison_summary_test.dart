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
  test('자료가 누락되거나 잘못된 형태면 없는 값을 만들지 않는다', () {
    final lines = FamilySearchComparisonSummary.lines({'names': [null], 'facts': '잘못된 자료'});
    expect(lines.single, contains('전체 자료를 확인'));
  });
}
