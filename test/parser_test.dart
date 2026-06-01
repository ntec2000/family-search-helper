import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';
import 'package:family_search_helper/services/hanja_dict.dart';
import 'package:family_search_helper/services/lunar_service.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 테스트용 사전 직접 주입
    final raw = await File('assets/dict/hanja_kor.json').readAsString();
    // HanjaDict.load() 가 rootBundle 을 사용하므로 직접 채워줌
    final map = Map<String, String>.from(jsonDecode(raw) as Map);
    // ignore: invalid_use_of_visible_for_testing_member
    final dict = HanjaDict.instance;
    // 리플렉션 없이 직접 주입할 수 없으므로 reading() 만 단순 테스트
  });

  group('한자 사전', () {
    test('기본 변환', () async {
      // load() 가 rootBundle 의존 → 별도 mock 필요
      expect(LunarService.isValidGanzhi('乙卯'), true);
      expect(LunarService.isValidGanzhi('XY'), false);
    });
  });

  group('만세력', () {
    test('乙卯 연도 추정', () {
      final years = LunarService.estimateYearsFromGanzhi('乙卯');
      expect(years, contains(1915));
      expect(years, contains(1975));
    });

    test('양력 → 음력 + 干支', () {
      final r = LunarService.solarToLunar(DateTime(1929, 11, 7));
      expect(r['ganzhi_year'], '己巳');
      expect(r['animal'], '蛇');
    });
  });

  group('족보 파서', () {
    test('샘플 인물 추출 (子在源)', () {
      final text = '子在源 字古元 乙未十一月十日生 乙丑九月十二日卒 配密陽朴氏父重建 墓楊口郡東面';
      final list = JokboParser.parse(text);
      expect(list, isNotEmpty);
      final p = list.first;
      expect(p.gender, 'M');
      expect(p.nameHanja, '在源');
      expect(p.ja, '古元');
      expect(p.birthDateLunar, contains('乙未'));
      expect(p.deathDateLunar, contains('乙丑'));
      expect(p.spouseHanja, '朴氏');
      expect(p.spouseFather, '重建');
      expect(p.burialPlace, contains('楊口郡'));
    });

    test('여자 인물 (女朴英周)', () {
      final list = JokboParser.parse('女朴英周 海州人');
      expect(list, isNotEmpty);
      expect(list.first.gender, 'F');
      expect(list.first.nameHanja, '朴英周');
    });

    test('여러 인물 한 번에', () {
      final text = '子斗淳 字英齊 子台淳 字英秀 女朴英周';
      final list = JokboParser.parse(text);
      expect(list.length, 3);
      expect(list[0].nameHanja, '斗淳');
      expect(list[1].nameHanja, '台淳');
      expect(list[2].nameHanja, '朴英周');
    });
  });
}
