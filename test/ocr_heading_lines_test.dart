import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/ocr_column_text.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  test('same-column single-glyph lines restore a complete heading candidate', () {
    const raw = '子\n顯\n五\n현오';
    final entries = assembleOcrEntries([raw, '字行之 庚午生'],
        headings: [true, false]);
    final people = JokboParser.parseRegions(entries);
    expect(people.single.nameHanja, '顯五');
    expect(people.single.ja, '行之');
    expect(people.single.birthDateLunar, '庚午年 生');
    expect(raw, '子\n顯\n五\n현오');
  });

  test('daughter husband glyphs join without inventing a daughter given name', () {
    final entries = assembleOcrEntries(['女\n權\n頭'],
        headings: [true]);
    final person = JokboParser.parseRegions(entries,
        clanHangulOverride: '이').single;
    expect(person.spouseHanja, '權頭');
    expect(person.nameHanja, isEmpty);
    expect(person.surnameHangul, '이');
  });

  test('split dates and structural markers are never appended to names', () {
    for (final tail in ['庚\n午\n生', '字\n行\n之', '配\n原州元氏']) {
      final normalized = joinFragmentedHeadingLines('子\n顯\n五\n$tail');
      expect(normalized, '子顯五\n$tail');
    }
  });

  test('spaces and adjacent OCR columns are not joined into a personal name', () {
    expect(joinFragmentedHeadingLines('子 顯 五'), '子 顯 五');
    final entries = assembleOcrEntries(['子顯', '五'],
        headings: [true, true]);
    expect(entries, ['子顯', '五']);
  });

  test('ambiguous and multiple-person columns stay unchanged', () {
    for (final raw in [
      '子\n格\n子\n核',
      '子\n賢\n東\n束\n山',
      '子\n格\n墓山',
      '字\n行\n之',
    ]) {
      if (raw == '子\n格\n墓山') {
        expect(joinFragmentedHeadingLines(raw), '子格\n墓山');
      } else {
        expect(joinFragmentedHeadingLines(raw), raw);
      }
    }
  });

  test('no sample-specific substitutions alter already recognized names', () {
    for (final raw in ['子賢東束', '女全免傑', '子顯', '字致安西']) {
      expect(joinFragmentedHeadingLines(raw), raw);
    }
  });
}
