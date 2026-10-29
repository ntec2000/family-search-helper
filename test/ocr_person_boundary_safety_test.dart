import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  test('구획이 분리되면 이전 인물의 배우자 정보가 다음 인물에게 넘어가지 않는다', () {
    final people = JokboParser.parseRegions([
      '子格 字君平 壬辰生 配原州邊氏 丁未生 父國聖',
      '子核 字君實 乙未生',
    ]);
    expect(people, hasLength(2));
    expect(people[0].spouseFather, '國聖');
    expect(people[1].spouseHanja, isNull);
    expect(people[1].spouseBirth, isNull);
    expect(people[1].spouseFather, isNull);
  });

  test('표제가 누락된 별도 구획은 앞 인물의 자·배우자 기록에 합치지 않는다', () {
    final people = JokboParser.parseRegions([
      '子格 字君平 壬辰生',
      '字君實 配坡平尹氏 父光岳',
      '子核 乙未生',
    ]);
    expect(people, hasLength(2));
    expect(people[0].ja, '君平');
    expect(people[0].spouseHanja, isNull);
    expect(people[1].ja, isNull);
    expect(people[1].spouseFather, isNull);
  });

  test('동일 OCR 텍스트의 인물 경계가 유지되고 간지 子를 별도 인물로 분리하지 않는다', () {
    final people = JokboParser.parse(
      '子格 甲子生 配原州邊氏 父國聖 子核 字君實 乙未生',
    );
    expect(people, hasLength(2));
    expect(people[0].nameHanja, '格');
    expect(people[0].spouseFather, '國聖');
    expect(people[1].nameHanja, '核');
    expect(people[1].spouseHanja, isNull);
    expect(people[1].spouseFather, isNull);
  });
}
