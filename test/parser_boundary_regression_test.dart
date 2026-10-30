import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  test('224쪽 세대별 이름은 차례와 자·호·출계를 구분한다', () {
    final people = JokboParser.parseRegions([
      '子顯五 字行之 庚午生 配原州元氏 甲戌生 父載億',
      '子承烈 字聖模 辛丑生 配務安朴氏 癸卯生 父基豊 祖奎秀 曾祖師元 外祖丁若萬',
      '子二承勳 出系顯龍后',
      '子賢東 字致安 癸酉生 庚午十二月十六日卒 墓謹峴壬坐合窆 配交河盧氏 丁亥生 父愼',
      '子炳吉',
      '子二炳旭 出系寅東后',
      '子三炳烈',
      '子四炳直',
      '女金免傑 金海人',
      '女二尹兢秀',
    ], clanHanjaOverride: '李', clanHangulOverride: '이');
    expect(people, hasLength(10));
    expect(people.take(8).map((p) => p.nameHanja).toList(), [
      '顯五', '承烈', '承勳', '賢東', '炳吉', '炳旭', '炳烈', '炳直',
    ]);
    expect(people[1].spouseFather, '基豊');
    expect(people[1].spouseMaternalGrandfather, '丁若萬');
    expect(people[2].note, contains('出系'));
    expect(people[5].note, contains('寅東'));
    expect(people[7].relation, '넷째아들');
    expect(people[8].nameHanja, isEmpty);
    expect(people[8].spouseHanja, '金免傑');
    expect(people[8].spouseBongwan, '金海');
    expect(people[9].nameHanja, isEmpty);
    expect(people[9].spouseHanja, '尹兢秀');
  });

  test('224쪽 이름 판별: 본관과 주석은 인물로 만들지 않는다', () {
    for (final text in [
      '子原州邊氏',
      '子安東人',
      '子外祖文化柳承春',
      '子曾祖判官尙',
      '子墓白石面鶴洞',
      '子忌三月五日',
    ]) {
      expect(JokboParser.parse(text), isEmpty, reason: text);
    }
    final people = JokboParser.parseRegions([
      '子昃 字良甫 丁未生 庚申八月三日卒 配原州邊氏 壬戌生 甲子十月二十八日卒 父國聖',
      '子格 字君平 壬辰生 配豊壤趙氏 癸巳生 父永復',
      '子核 字君實 丁酉生 配坡平尹氏 乙巳生 父光岳',
      '子聖甲 甲子生',
      '女權頭 安東人',
    ], clanHanjaOverride: '李', clanHangulOverride: '이');
    expect(people, hasLength(5));
    expect(people[0].nameHanja, '昃');
    expect(people[1].nameHanja, '格');
    expect(people[2].nameHanja, '核');
    expect(people[3].nameHanja, '聖甲');
    expect(people[4].nameHanja, isEmpty);
    expect(people[4].spouseHanja, '權頭');
    expect(people[4].surnameHanja, '李');
  });

  test('다른 인물 표제가 없는 주석 구획은 인물로 생성하지 않는다', () {
    final people = JokboParser.parseRegions([
      '子格 字君平 壬辰生',
      '字君實 丁酉生 配原州邊氏 父國聖',
      '子核 乙未生',
    ]);
    expect(people, hasLength(2));
    expect(people.first.nameHanja, '格');
    expect(people.first.ja, '君平');
    expect(people.first.spouseHanja, isNull);
    expect(people.last.nameHanja, '核');
    expect(people.last.spouseHanja, isNull);
    expect(people.last.spouseFather, isNull);
  });
  test('배우자 외조부와 친가 조상은 다른 인물에게 넘어가지 않는다', () {
    final people = JokboParser.parseRegions([
      '子格 配原州邊氏 父國聖 祖同知 曾祖判官尙 外祖文化柳承春',
      '子核 字君實 乙未生',
    ]);
    expect(people, hasLength(2));
    expect(people.first.spouseHanja, '邊氏');
    expect(people.first.spouseFather, '國聖');
    expect(people.first.spouseGrandfather, '同知');
    expect(people.first.spouseGreatGrandfather, '尙');
    expect(people.first.spouseMaternalGrandfather, '柳承春');
    expect(people.last.spouseHanja, isNull);
    expect(people.last.spouseFather, isNull);
    expect(people.last.spouseMaternalGrandfather, isNull);
  });
  test('본인 字號와 배우자 생졸은 서로 섞이지 않는다', () {
    final people = JokboParser.parse(
      '子格 字君平 號松軒 壬辰生 甲午卒 配原州邊氏 丁未生 庚申卒 父國聖 '
      '子核 字君實 乙未生',
    );
    expect(people, hasLength(2));
    final first = people.first;
    expect(first.nameHanja, '格');
    expect(first.ja, '君平');
    expect(first.ho, '松軒');
    expect(first.birthDateLunar, contains('壬辰'));
    expect(first.deathDateLunar, contains('甲午'));
    expect(first.spouseBirth, contains('丁未'));
    expect(first.spouseDeath, contains('庚申'));
    expect(first.spouseFather, '國聖');
    final second = people.last;
    expect(second.nameHanja, '核');
    expect(second.ja, '君實');
    expect(second.birthDateLunar, contains('乙未'));
    expect(second.spouseBirth, isNull);
    expect(second.spouseFather, isNull);
  });
  test('묘지 좌향을 별도 인물로 나누지 않고 배우자 정보도 섞지 않는다', () {
    final people = JokboParser.parse(
      '子格 墓山 子坐午向 配原州邊氏 父國聖 子核 字君實 乙未生',
    );
    expect(people, hasLength(2));
    expect(people.first.nameHanja, '格');
    expect(people.first.spouseHanja, '邊氏');
    expect(people.first.spouseFather, '國聖');
    expect(people.last.nameHanja, '核');
    expect(people.last.spouseHanja, isNull);
    expect(people.last.spouseFather, isNull);
  });
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
  test('외조부 이름의 끝 글자가 성씨 한자여도 앞 이름을 삭제하지 않는다', () {
    final person = JokboParser.parse('子格 配原州邊氏 外祖李承金').single;
    expect(person.spouseMaternalGrandfather, '李承金');
    expect(person.rawText, contains('外祖李承金'));
  });

  test('인물별 원래 OCR 줄바꿈과 공백을 보존한다', () {
    const first = '子格\n字君平 壬 辰 生\n配原州邊氏 父國聖\n';
    const second = '子核\n字君實 丁酉生';
    final people = JokboParser.parse('$first$second');
    expect(people, hasLength(2));
    expect(people[0].nameHanja, '格');
    expect(people[0].rawText, first);
    expect(people[0].rawText, isNot(contains('君實')));
    expect(people[1].nameHanja, '核');
    expect(people[1].rawText, second);
  });

  test('인식된 인물과 미분류 표제가 같은 구획에 있어도 검토 대상으로 남긴다', () {
    const region = '子格 字君平\n子甲子生\n子核 字君實';
    final people = JokboParser.parseRegions([region]);
    final unresolved = JokboParser.unparsedRegions([region]);
    expect(people.map((p) => p.nameHanja), ['格', '核']);
    expect(unresolved, hasLength(1));
    expect(unresolved.single, contains('子甲子生'));
    expect(unresolved.single, isNot(contains('君實')));
  });
  test('인물 표제가 전혀 없는 구획도 그대로 검토 대상으로 남긴다', () {
    const raw = 'm炳直\n 出系';
    expect(JokboParser.unparsedRegions([raw]), [raw]);
  });

  test('첫 인물 앞의 미분류 OCR 원문을 잃지 않는다', () {
    const raw = 'm炳直\n配原州邊氏\n子格 字君平';
    final unresolved = JokboParser.unparsedRegions([raw]);
    expect(unresolved, ['m炳直\n配原州邊氏\n']);
    final people = JokboParser.parseRegions([raw]);
    expect(people, hasLength(1));
    expect(people.single.nameHanja, '格');
    expect(people.single.spouseHanja, isNull);
  });

  test('첫 인물 기록 안의 씨 표기를 가문 성씨로 상속하지 않는다', () {
    final people = JokboParser.parseRegions(['子格 字君平 坡平尹氏', '子核 丁酉生']);
    expect(people, hasLength(2));
    expect(people[0].surnameHanja, isNull);
    expect(people[1].surnameHanja, isNull);
  });
  test('첫 표제가 없고 개인 주석만 있는 구획의 배우자 성씨는 상속하지 않는다', () {
    final people = JokboParser.parseRegions(['字君平 壬辰生 坡平尹氏', '子核 丁酉生']);
    expect(people, hasLength(1));
    expect(people.single.surnameHanja, isNull);
  });

  test('첫 표제가 빠진 같은 구획의 배우자 성씨를 다음 인물에 상속하지 않는다', () {
    const raw = '字君平 壬辰生 坡平尹氏 子核 丁酉生';
    final people = JokboParser.parse(raw);
    expect(people, hasLength(1));
    expect(people.single.nameHanja, '核');
    expect(people.single.surnameHanja, isNull);
    expect(people.single.surnameHangul, isNull);
    expect(JokboParser.unparsedRegions([raw]).single, contains('坡平尹氏'));
  });

}
