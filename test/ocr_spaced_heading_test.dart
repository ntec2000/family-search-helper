import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/ocr_column_text.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  test('공백으로 나뉜 좌향은 열 조합에서 인물 경계를 만들지 않는다', () {
    for (final orientation in ['子坐午向', '子 坐午向', '子\t坐午向']) {
      final entries = assembleOcrEntries([
        '子格', '墓山', '$orientation 配原州邊氏 父國聖', '子核',
      ]);
      expect(entries, hasLength(2), reason: orientation);
      expect(entries.first, contains('配原州邊氏父國聖'));
      expect(entries.last, '子核');
    }
  });

  test('공백으로 나뉜 좌향 때문에 배우자 정보가 다른 인물에 붙지 않는다', () {
    for (final orientation in ['子坐午向', '子 坐午向', '子\t坐午向']) {
      final raw = '子格 墓山 $orientation 配原州邊氏 父國聖 子核 字君實 乙未生';
      final people = JokboParser.parse(raw);
      expect(people.map((p) => p.nameHanja).toList(), ['格', '核'], reason: orientation);
      expect(people.first.spouseHanja, '邊氏');
      expect(people.first.spouseFather, '國聖');
      expect(people.first.rawText, contains(orientation));
      expect(people.last.spouseHanja, isNull);
      expect(people.last.spouseFather, isNull);
    }
  });
}
