import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/lunar_service.dart';

void main() {
  group('만세력 기반 서기 연도 추정', () {
    test('경술년은 기준 1850년 근처에서 about 1850', () {
      expect(LunarService.approximateYear('庚戌生', referenceYear: 1852),
          'about 1850');
    });

    test('기준 연도가 없으면 임의 추정하지 않는다', () {
      expect(LunarService.approximateYear('庚戌生'), isNull);
    });

    test('불가능한 간지 조합은 거부한다', () {
      expect(LunarService.approximateYear('甲丑生', referenceYear: 1850),
          isNull);
    });

    test('기준 연도와 후보 차이가 크면 거부한다', () {
      expect(LunarService.approximateYear('庚戌生',
          referenceYear: 1880, maxDistance: 10), isNull);
    });

    test('기준 연도가 두 후보의 중간이면 어느 연도도 확정하지 않는다', () {
      expect(LunarService.approximateYear('庚戌生', referenceYear: 1880), isNull);
      expect(LunarService.approximateYear('庚戌生', referenceYear: 1879), 'about 1850');
      expect(LunarService.approximateYear('庚戌生', referenceYear: 1881), 'about 1910');
    });

    test('기일과 간지 일자는 생몰 연도로 추정하지 않는다', () {
      expect(LunarService.approximateYear('忌三月五日 庚戌', referenceYear: 1850), isNull);
      expect(LunarService.approximateYear('庚戌日', referenceYear: 1850), isNull);
      expect(LunarService.approximateYear('庚戌月', referenceYear: 1850), isNull);
    });

    test('세대 차이로 about 연도 계산', () {
      expect(LunarService.approximateYearByGeneration(
          ancestorBirthYear: 950,
          ancestorGeneration: 1,
          personGeneration: 32), 'about 1880');
    });

    test('기준 조상 연도나 세대 정보가 없으면 공란', () {
      expect(LunarService.approximateYearByGeneration(
          ancestorBirthYear: null,
          ancestorGeneration: 1,
          personGeneration: 32), isNull);
    });
  });
}
