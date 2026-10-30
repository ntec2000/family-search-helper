import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/place_display.dart';

void main() {
  test('출생·사망 장소 미상은 특정 국가로 추정하지 않는다', () {
    expect(placeDisplay(null), '미상');
    expect(placeDisplay('  '), '미상');
    expect(placeDisplay('서울'), '서울');
  });
}
