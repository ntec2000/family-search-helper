import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/hanja_dict.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';
import 'package:family_search_helper/services/familysearch_record.dart';
import 'package:family_search_helper/services/gedcom_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HanjaDict.instance.load());

  test('처가 성을 본손 성으로 자동 적용하지 않는다', () {
    final person = JokboParser.parse('子格 配豊壤趙氏 父永復').single;
    expect(person.surnameHanja, isNull);
  });

  test('확인된 배우자 본관을 원문에서 분리하고 인물별 기록을 보존한다', () {
    final cases = <String, String>{
      '坡平尹氏': '坡平', '豊壤趙氏': '豊壤', '豐壤趙氏': '豐壤',
      '交河盧氏': '交河', '務安朴氏': '務安',
    };
    for (final entry in cases.entries) {
      final raw = '子核 配${entry.key} 父光岳';
      final person = JokboParser.parse(raw).single;
      expect(person.spouseBongwan, entry.value, reason: raw);
      expect(person.spouseHanja, entry.key, reason: raw);
      expect(person.rawText, contains(entry.key));
    }
    final ambiguous = JokboParser.parse('子核 配未知南宮氏').single;
    expect(ambiguous.spouseBongwan, isNull);
    expect(ambiguous.spouseHanja, '未知南宮氏');
    expect(ambiguous.rawText, contains('配未知南宮氏'));
  });

  test('성씨 미상 이름의 첫 글자를 FamilySearch 성씨로 추정하지 않는다', () {
    final person = JokboParser.parse('子金秀').single;
    final record = FamilySearchRecord.person(person);
    final forms = (record['names'] as List).first['nameForms'] as List;
    expect(forms.every((f) => (f['parts'] as List).every((p) =>
        p['type'] != 'http://gedcomx.org/Surname')), isTrue);
    expect(person.surnameHanja, isNull);
  });

  test('가문 성을 먼저 적용하고 이름 첫 글자를 다른 성으로 떼지 않는다', () {
    final person = JokboParser.parse('固城李氏 子金秀').single;
    expect(person.surnameHanja, '李');
    expect(person.surnameHangul, '이');
    expect(person.nameHanja, '金秀');
  });

  test('인물 표지 뒤 주석을 가짜 이름으로 만들지 않는다', () {
    for (final text in ['子字君平', '子配原州邊氏', '子墓白石面', '子判官']) {
      expect(JokboParser.parse(text), isEmpty, reason: text);
    }
  });

  test('본인과 배우자 기일, 관직과 인명을 분리한다', () {
    final person = JokboParser.parse('固城李氏 子賢東 二十四世 字致安 癸酉生 '
        '庚午十二月十六日卒 墓謹峴壬坐合窆 '
        '配交河盧氏 丁亥生 忌四月十三日 父愼').single;
    expect(person.deathDateLunar, '庚午年 十二月十六日 卒');
    expect(person.spouseDeath, '忌 四月十三日 (연도 미상)');
    expect(person.spouseFather, '愼');
    expect(person.birthDateSolar, isNull);
  });

  test('배우자 세대 표기를 본인 세대로 가져오지 않는다', () {
    final person = JokboParser.parse('子格 二十一世 配豊壤趙氏 二十二世').single;
    expect(person.sega, 21);
  });

  test('세손과 대손은 세대 수로 자동 확정하지 않는다', () {
    for (final notation in ['二十一世孫', '21世 孫', '二十一代孫', '二十一世祖']) {
      final raw = '子格 $notation';
      final person = JokboParser.parse(raw).single;
      expect(person.sega, isNull, reason: notation);
      expect(person.note, contains(notation), reason: notation);
      expect(person.rawText, contains(notation));
    }
    final explicit = JokboParser.parse('子格 二十一世孫 二十二世').single;
    expect(explicit.sega, 22);
    expect(explicit.note, contains('二十一世孫'));
  });

  test('聖甲과 성중 불일치는 원문과 메모에 보존한다', () {
    final person = JokboParser.parse('固城李氏 子聖甲 성중 二十二世 甲子生').single;
    expect(person.nameHangul, '성갑');
    expect(person.note, contains('성중'));
    expect(person.note, contains('성갑'));
    expect(person.rawText, contains('聖甲 성중'));
  });

  test('딸은 성만 내보내고 사위와 출계는 메모로 보존한다', () {
    final people = JokboParser.parse('固城李氏 女二 金免傑 金海人 二十五世 '
        '子二 炳旭 二十五世 出系寅東后');
    final daughter = people.first;
    expect(daughter.nameHanja, isEmpty);
    expect(daughter.sega, 25);
    expect(daughter.spouseHanja, '金免傑');
    final output = GedcomExport.toGedcom(people);
    expect(output, contains('1 NAME  /이/'));
    expect(output, isNot(contains('1 NAME 이씨')));
    expect(output, contains('出系'));
    expect(output, contains('金免傑'));
    final json = FamilySearchRecord.person(daughter);
    final form = (json['names'] as List).first['nameForms'].first;
    expect(form['fullText'], '이');
    expect(form['parts'], hasLength(1));
    expect(form['parts'].first['type'], 'http://gedcomx.org/Surname');
    expect(json.containsKey('living'), isFalse);
  });

  test('출계 표기 변형은 원문과 후보로 보존하고 배우자 기록과 구분한다', () {
    for (final marker in ['出系', '出后', '出繼', '出 系']) {
      final person = JokboParser.parse('子承勳 $marker').single;
      expect(person.note, contains(marker.replaceAll(' ', '')));
      expect(person.rawText, contains(marker));
      expect(person.fatherId, isNull);
      expect(person.motherId, isNull);
    }
    final person = JokboParser.parse('子承勳 配坡平尹氏 出后').single;
    expect(person.note ?? '', isNot(contains('出后')));
    expect(person.rawText, contains('出后'));
  });

  test('계자 표기는 입양 후보로 기록하고 출계와 부모 관계를 혼동하지 않는다', () {
    for (final marker in ['系子', '繼子', '系 子']) {
      final person = JokboParser.parse('子承勳 $marker').single;
      expect(person.note, contains(marker.replaceAll(' ', '')));
      expect(person.note, contains('입양 표기 후보'));
      expect(person.note ?? '', isNot(contains('출계 표기')));
      expect(person.rawText, contains(marker));
      expect(person.fatherId, isNull);
      expect(person.motherId, isNull);
    }
    final out = JokboParser.parse('子承勳 出 系子').single;
    expect(out.note ?? '', isNot(contains('입양 표기 후보')));
    final spouse = JokboParser.parse('子承勳 配坡平尹氏 系子').single;
    expect(spouse.note ?? '', isNot(contains('입양 표기 후보')));
  });

  test('이름만 있는 본손도 성과 이름을 분리하여 내보낸다', () {
    final person = JokboParser.parse('固城李氏 子顯五 庚午生').single;
    expect(GedcomExport.toGedcom([person]), contains('1 NAME 현오 /이/'));
    final record = FamilySearchRecord.person(person);
    expect((record['names'] as List).first['nameForms'][0]['fullText'], '이현오');
    expect(record['facts'].first['date']['original'], '庚午年 生');
    expect(record['facts'].first.containsKey('place'), isFalse);
  });
}
