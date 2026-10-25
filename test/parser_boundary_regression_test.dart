import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  test('첫 구획의 표제가 누락되어도 배우자 성을 본손에게 상속하지 않는다', () {
    final person = JokboParser.parseRegions(['字良甫丁未生配原州邊氏', '子甲順']).single;
    expect(person.surnameHanja, isNull);
    expect(person.surnameHangul, isNull);
  });
  test('이름 뒤 OCR 문장부호는 이름에 넣지 않고 원문에 남긴다', () {
    final people = JokboParser.parseRegions(['子甲順: 字仁平', '女金免傑: 金海人', '女尹兢秀-']);
    expect(people, hasLength(3));
    expect(people.first.nameHanja, '甲順');
    expect(people[1].spouseHanja, '金免傑');
    expect(people[1].spouseBongwan, '金海');
    expect(people[2].spouseHanja, '尹兢秀');
    expect(people[1].rawText, contains(':'));
  });
  test('차례와 간지 날짜를 가짜 이름으로 만들지 않는다', () {
    for (final text in ['子 四', '子四', '子 甲子十月二十八日卒', '子甲子生']) {
      expect(JokboParser.parse(text), isEmpty, reason: text);
    }
  });
  test('이름 뒤에 붙은 자와 생졸은 이름에서 분리한다', () {
    final person = JokboParser.parse('子格字君平壬辰生').single;
    expect(person.nameHanja, '格');
    expect(person.ja, '君平');
    expect(person.birthDateLunar, '壬辰年 生');
  });
  test('구획에서 인물 표지를 놓쳐도 앞 구획 인물에 정보를 섞지 않는다', () {
    final people = JokboParser.parseRegions(['固城李氏', '子格 字君平 壬辰生',
      '字君實 丁酉生 配坡平尹氏 父光岳', '子核 乙未生']);
    expect(people, hasLength(2));
    expect(people.first.ja, '君平');
    expect(people.first.spouseHanja, isNull);
    expect(people.last.ja, isNull);
    expect(people.last.birthDateLunar, '乙未年 生');
    expect(people.first.surnameHanja, '李');
  });
  test('띄어쓰기 없는 처가 조상 표지끼리 이름을 침범하지 않는다', () {
    final person = JokboParser.parse('子格 配原州邊氏父國聖祖同知曾祖判官尙外祖文化柳承春').single;
    expect(person.spouseFather, '國聖');
    expect(person.spouseGrandfather, '同知');
    expect(person.spouseGreatGrandfather, '尙');
    expect(person.spouseMaternalGrandfather, '柳承春');
  });
}
