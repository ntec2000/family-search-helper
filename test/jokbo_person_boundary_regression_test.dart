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

  test('천간 글자로 끝나는 이름과 다음 子 표제를 합치지 않는다', () {
    const source = '子聖甲\n子顯五 甲 子 年 十 一 月 十 日 生';
    final people = JokboParser.parse(source);
    expect(people.map((person) => person.nameHanja), ['聖甲', '顯五']);
    expect(people.first.rawText?.trim(), '子聖甲');
    expect(people.first.birthDateLunar, isNull);
    expect(people.last.rawText?.trim(), '子顯五 甲 子 年 十 一 月 十 日 生');
    expect(people.last.birthDateLunar, '甲子年 十一月十日 生');
  });

  test('unrecognized OCR region is retained for human review', () {
    const unknown = '判讀不能 原文確認必要';
    final people = JokboParser.parseRegions(
      [unknown], clanHangulOverride: '이');
    expect(people, isEmpty);
    expect(JokboParser.unparsedRegions([unknown]), contains(unknown));
  });
}
