import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:family_search_helper/services/ocr_regions.dart';
import 'package:family_search_helper/services/ocr_column_text.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  test('묘지 좌향의 子坐 표기는 새로운 인물 열이 아니다', () {
    final entries = assembleOcrEntries(['子格', '墓山', '子坐午向', '子核']);
    expect(entries, hasLength(2));
    expect(entries.first, contains('子坐午向'));
    expect(entries.last, startsWith('子核'));
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
