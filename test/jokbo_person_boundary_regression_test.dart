import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  test('separate OCR regions do not mix neighboring persons raw evidence', () {
    const first = '子 格 字君平';
    const second = '子 核 字君實';
    final people = JokboParser.parseRegions(
      [first, second],
      clanHanjaOverride: '李',
      clanHangulOverride: '이',
    );

    expect(people, hasLength(2));
    expect(people[0].nameHanja, '格');
    expect(people[1].nameHanja, '核');
    expect(people[0].rawText, contains('君平'));
    expect(people[0].rawText, isNot(contains('君實')));
    expect(people[1].rawText, contains('君實'));
    expect(people[1].rawText, isNot(contains('君平')));
    expect(people[0].surnameHangul, '이');
    expect(people[1].surnameHangul, '이');
    expect(people[0].fatherId, isNull);
    expect(people[1].fatherId, isNull);
  });

  test('unrecognized OCR region is retained for human review', () {
    const unknown = '判讀不能 原文確認必要';
    final people = JokboParser.parseRegions(
      [unknown], clanHangulOverride: '이');
    expect(people, isEmpty);
    expect(JokboParser.unparsedRegions([unknown]), contains(unknown));
  });
}
