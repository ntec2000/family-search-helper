import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:family_search_helper/services/ocr_regions.dart';
import 'package:family_search_helper/services/ocr_column_text.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  test('좁은 세로 열도 오른쪽부터 순서대로 추출한다', () {
    final image = img.Image(width: 320, height: 220);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    for (final x in [55, 105, 155, 205, 255]) {
      // 긴 실선은 테두리로 판정되므로 실제 글자처럼 중간을 띄운다.
      img.fillRect(image, x1: x, y1: 25, x2: x + 14, y2: 90,
          color: img.ColorRgb8(0, 0, 0));
      img.fillRect(image, x1: x, y1: 115, x2: x + 14, y2: 185,
          color: img.ColorRgb8(0, 0, 0));
    }
    final columns = genealogyOcrColumns(
        Uint8List.fromList(img.encodePng(image)));
    expect(columns, hasLength(5));
    for (final column in columns) {
      final decoded = img.decodePng(column)!;
      expect(decoded.width, greaterThan(24));
    }
  });

  test('224쪽 표제가 누락된 열은 다른 인물의 배우자로 합치지 않는다', () {
    final entries = assembleOcrEntries([
      '子昃', '字良甫丁未生',
      '', '子格', '字君平壬辰生',
      '子核', '字君實丁酉生',
    ], headings: [true, false, true, true, false, true, false]);
    expect(entries, hasLength(3));
    expect(entries[0], contains('昃'));
    expect(entries[1], startsWith('子格'));
    expect(entries[2], startsWith('子核'));
  });

  test('빈 표제 뒤의 생몰·배우자 기록을 앞 인물에 섞지 않는다', () {
    final entries = assembleOcrEntries([
      '子昃', '丁未生庚申卒', '配原州邊氏', '父國聖',
      '', '壬辰生甲子卒', '配豊壤趙氏', '父永復',
      '子核', '丁酉生戊戌卒', '配坡平尹氏', '父光岳',
    ], headings: [
      true, false, false, false,
      true, false, false, false,
      true, false, false, false,
    ]);
    expect(entries, hasLength(3));
    expect(entries[0], contains('丁未生庚申卒'));
    expect(entries[0], contains('父國聖'));
    expect(entries[0], isNot(contains('壬辰生')));
    expect(entries[0], isNot(contains('豊壤趙氏')));
    expect(entries[1], contains('壬辰生甲子卒'));
    expect(entries[1], contains('豊壤趙氏'));
    expect(entries[1], isNot(contains('坡平尹氏')));
    expect(entries[2], startsWith('子核'));
    expect(entries[2], contains('丁酉生戊戌卒'));
    expect(entries[2], contains('父光岳'));
  });

  test('이름이 누락된 표제에 글자가 남아도 앞뒤 인물 정보와 합치지 않는다', () {
    final entries = assembleOcrEntries([
      '子昃', '丁未生', '配原州邊氏',
      '□', '壬辰生', '配豊壤趙氏',
      '子核', '丁酉生', '配坡平尹氏',
    ], headings: [
      true, false, false,
      true, false, false,
      true, false, false,
    ]);
    expect(entries, hasLength(3));
    expect(entries[0], isNot(contains('豊壤趙氏')));
    expect(entries[1], contains('壬辰生'));
    expect(entries[1], contains('豊壤趙氏'));
    expect(entries[2], isNot(contains('豊壤趙氏')));
    final people = JokboParser.parseRegions(entries,
        clanHanjaOverride: '李', clanHangulOverride: '이');
    expect(people.map((p) => p.nameHanja).toList(), ['昃', '核']);
    expect(people[0].spouseHanja, '邊氏');
    expect(people[1].spouseHanja, '坡平尹氏');
  });

  test('이름이 누락된 중간 인물의 배우자 기록을 앞뒤 인물에 배정하지 않는다', () {
    final entries = assembleOcrEntries([
      '子昃', '字良甫丁未生', '配原州邊氏', '父國聖',
      '', '壬辰生甲子卒', '配豊壤趙氏', '父永復',
      '子核', '字君實丁酉生', '配坡平尹氏', '父光岳',
    ], headings: [
      true, false, false, false,
      true, false, false, false,
      true, false, false, false,
    ]);
    expect(entries, hasLength(3));
    // 이름을 모르는 중간 인물은 원문 검토 대상으로 남기되,
    // 주변 인물의 생몰·배우자 기록에 합치지 않는다.
    expect(entries[1], contains('豊壤趙氏'));
    final people = JokboParser.parseRegions(entries,
        clanHanjaOverride: '李', clanHangulOverride: '이');
    expect(people.map((p) => p.nameHanja).toList(), ['昃', '核']);
    expect(people[0].spouseHanja, '邊氏');
    expect(people[0].spouseFather, '國聖');
    expect(people[0].rawText, isNot(contains('豊壤趙氏')));
    expect(people[1].spouseHanja, '坡平尹氏');
    expect(people[1].spouseFather, '光岳');
    expect(people[1].rawText, isNot(contains('豊壤趙氏')));
  });

  test('연속된 빈 표제는 생몰 및 배우자 기록을 인접 인물에 혼입하지 않는다', () {
    final entries = assembleOcrEntries([
      '子昃', '丁未生', '配原州邊氏',
      '', '壬辰生', '配豊壤趙氏',
      '', '庚午卒', '配坡平尹氏',
      '子核', '丁酉生', '配務安朴氏',
    ], headings: [
      true, false, false,
      true, false, false,
      true, false, false,
      true, false, false,
    ]);
    expect(entries, hasLength(4));
    expect(entries[0], contains('原州邊氏'));
    expect(entries[0], isNot(contains('豊壤趙氏')));
    expect(entries[1], contains('壬辰生'));
    expect(entries[1], isNot(contains('庚午卒')));
    expect(entries[2], contains('庚午卒'));
    expect(entries[2], isNot(contains('務安朴氏')));
    expect(entries[3], startsWith('子核'));
    expect(entries[3], contains('務安朴氏'));
  });

  test('224쪽 세대별 인물과 처가 기록을 열 단위로 격리한다', () {
    final entries = assembleOcrEntries([
      '子昃', '字良甫丁未生庚申八月三日卒',
      '配原州邊氏壬戌生甲子十月二十八日卒', '父國聖',
      '子格', '字君平壬辰生', '配豊壤趙氏癸巳生', '父永復',
      '子核', '字君實丁酉生', '配坡平尹氏乙巳生', '父光岳',
      '子聖甲', '甲子生',
      '子顯五', '庚午生',
      '子承烈', '字聖模辛丑生', '配務安朴氏癸卯生', '父基豊',
      '子二承勳', '出系顯龍后',
      '子賢東', '字致安癸酉生庚午十二月十六日卒',
      '配交河盧氏丁亥生', '父愼',
      '子炳吉', '子二炳旭', '出系寅東后',
      '子三炳烈', '子四炳直',
    ]);
    final people = JokboParser.parseRegions(entries,
        clanHanjaOverride: '李', clanHangulOverride: '이');
    expect(entries, hasLength(12));
    expect(people.map((p) => p.nameHanja).toList(),
        ['昃', '格', '核', '聖甲', '顯五', '承烈', '承勳',
         '賢東', '炳吉', '炳旭', '炳烈', '炳直']);
    expect(people[0].spouseFather, '國聖');
    expect(people[1].spouseFather, '永復');
    expect(people[2].spouseFather, '光岳');
    expect(people[3].spouseFather, isNull);
    expect(people[5].spouseFather, '基豊');
    expect(people[6].spouseFather, isNull);
    expect(people[7].spouseFather, '愼');
    expect(people[8].spouseFather, isNull);
    expect(people[9].note, contains('出系'));
    expect(people[10].spouseFather, isNull);
  });

  test('224쪽 세로 열: 오른쪽 인물의 배우자 정보가 왼쪽 인물로 넘어가지 않는다', () {
    final entries = assembleOcrEntries([
      '子昃', '字良甫丁未生', '配原州邊氏壬戌生', '父國聖',
      '子格', '字君平壬辰生', '配豊壤趙氏癸巳生', '父永復',
      '子核', '字君實丁酉生', '配坡平尹氏乙巳生', '父光岳',
    ]);
    final people = JokboParser.parseRegions(entries,
        clanHanjaOverride: '李', clanHangulOverride: '이');
    expect(entries, hasLength(3));
    expect(people, hasLength(3));
    expect(people.map((p) => p.nameHanja).toList(), ['昃', '格', '核']);
    expect(people[0].spouseHanja, '邊氏');
    expect(people[0].spouseFather, '國聖');
    expect(people[1].spouseHanja, '豊壤趙氏');
    expect(people[1].spouseFather, '永復');
    expect(people[2].spouseHanja, '坡平尹氏');
    expect(people[2].spouseFather, '光岳');
  });

  test('빈 OCR 열은 건너뛰고 명시적 빈 표제는 경계로 유지한다', () {
    expect(assembleOcrEntries(['子格', '', '字君平', '子核']),
        ['子格 字君平', '子核']);
    expect(
      assembleOcrEntries(['子格', '', '字君平'],
          headings: [true, true, false]),
      ['子格', '字君平'],
    );
  });
  test('子 뒤의 주석 표기는 새로운 인물 경계로 취급하지 않는다', () {
    final entries = assembleOcrEntries([
      '子格', '字君平', '子配原州邊氏', '子墓山', '子核',
    ]);
    expect(entries, hasLength(2));
    expect(entries.first, contains('子配原州邊氏'));
    expect(entries.last, startsWith('子核'));
  });

  test('묘지 좌향의 子坐 표기는 새로운 인물 열이 아니다', () {
    final entries = assembleOcrEntries(['子格', '墓山', '子坐午向', '子核']);
    expect(entries, hasLength(2));
    expect(entries.first, contains('子坐午向'));
    expect(entries.last, startsWith('子核'));
  });
  test('공백을 포함한 자녀 표제도 별도 인물로 구분한다', () {
    final entries = assembleOcrEntries(['子格', '字君平', '子 核', '配原州邊氏']);
    expect(entries, hasLength(2));
    expect(entries.first, '子格 字君平');
    expect(entries.last, '子 核 配原州邊氏');
  });
  test('세로 주석은 잇고 다음 인물 열에서는 경계를 유지한다', () {
    final text = assembleOcrColumns(['子格', '字君平壬辰生', '配豊壤趙氏',
      '父永復', '子核', '字君實丁酉生']);
    expect(text, contains('父永復\n子核'));
    expect(text, contains('子格 字君平壬辰生配豊壤趙氏父永復'));
  });
  test('가로 구획으로 분리하고 원본 바이트는 변경하지 않는다', () {
    final image = img.Image(width: 300, height: 400);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    for (final y in [20, 140, 260, 380]) {
      img.drawLine(image, x1: 20, y1: y, x2: 285, y2: y,
          color: img.ColorRgb8(0, 0, 0), thickness: 2);
    }
    final bytes = Uint8List.fromList(img.encodePng(image));
    final before = Uint8List.fromList(bytes);
    final regions = genealogyOcrRegions(bytes);
    expect(regions, hasLength(3));
    expect(img.decodeJpg(regions.first)!.width, 1800);
    expect(bytes, before);
  });

  test('표제 오독과 빈 표제 뒤의 출계가 앞 인물에게 붙지 않는다', () {
    final entries = assembleOcrEntries(['子甲順', '字仁平', '了承熏',
      '出系乙順后', '', '字仲平'],
      headings: [true, false, true, false, true, false]);
    expect(entries, ['子甲順 字仁平', '了承熏 出系乙順后', '字仲平']);
    final person = JokboParser.parseRegions(entries).single;
    expect(person.nameHanja, '甲順');
    expect(person.note ?? '', isNot(contains('出系')));
    expect(() => assembleOcrEntries(['子甲順'], headings: []), throwsArgumentError);
  });

  test('표제 크기를 판단할 때 흰 여백을 제외한다', () {
    Uint8List column(int width) => Uint8List.fromList(
        img.encodePng(img.Image(width: width, height: 374)));
    expect(genealogyOcrColumnHeadings([column(120), column(80)]), [true, false]);
  });

  test('구획 없는 페이지는 전체 OCR로 남긴다', () {
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    expect(genealogyOcrRegions(Uint8List.fromList(img.encodePng(image))), isEmpty);
    expect(() => genealogyOcrRegions(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });

  test('구획선 아래 표제의 윗부분을 자르지 않는다', () {
    final image = img.Image(width: 300, height: 400);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    for (final y in [20, 140, 260, 380]) {
      img.drawLine(image, x1: 20, y1: y, x2: 285, y2: y,
          color: img.ColorRgb8(0, 0, 0), thickness: 2);
    }
    img.fillRect(image, x1: 160, y1: 145, x2: 190, y2: 148,
        color: img.ColorRgb8(0, 0, 0));
    final regions = genealogyOcrRegions(Uint8List.fromList(img.encodePng(image)));
    final second = img.decodeJpg(regions[1])!;
    expect(img.getLuminance(second.getPixel(950, 30)), lessThan(100));
  });

  const sample = String.fromEnvironment('JOKBO_SAMPLE');
  if (sample.isNotEmpty) {
    test('첨부 224쪽의 실제 가로 구획을 검출한다', () {
      final regions = genealogyOcrRegions(File(sample).readAsBytesSync());
      expect(regions.length, inInclusiveRange(6, 9));
      expect(genealogyOcrColumns(regions[1]).length, greaterThan(4));
    });
  }
}
