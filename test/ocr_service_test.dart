import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/ocr_service.dart';

void main() {
  OcrResult result(String text) => OcrResult(text: text, rawBlocks: []);

  test('빈 세로열만 있으면 세대 구획을 다시 인식한다', () {
    expect(OcrService.hasReadableText(['', ' \n ']), isFalse);
    expect(OcrService.hasReadableText(['', '子格']), isTrue);
  });

  test('세로열 하나가 실패하면 부분 OCR을 구획 결과로 사용하지 않는다', () async {
    final failed = await OcrService.readColumnsOrNull(3, (index) async {
      if (index == 1) throw StateError('OCR 실패');
      return '子格';
    });
    expect(failed, isNull);
    final success = await OcrService.readColumnsOrNull(2,
        (index) async => ['子格', '字君平'][index]);
    expect(success, ['子格', '字君平']);
  });

  test('구획 인식이 모두 비면 전체 페이지 OCR을 보존한다', () {
    final whole = result('子格 字君平');
    expect(OcrService.useSegmentedOrWhole(whole, ['', '  \n'], []), same(whole));
    expect(OcrService.useSegmentedOrWhole(whole, [], []), same(whole));
  });

  test('구획 인식이 있으면 전체 OCR도 비교 원문으로 유지한다', () {
    final whole = result('子格 字君平');
    final combined = OcrService.useSegmentedOrWhole(
        whole, ['子格 字君平'], ['子格\n字君平']);
    expect(combined.regionTexts, ['子格 字君平']);
    expect(combined.alternatives, ['子格 字君平', '子格\n字君平']);
  });

  test('원본과 전처리 OCR 중 선택되지 않은 결과도 보존한다', () {
    final processed = result('子格');
    final original = result('子聖甲');
    final whole = OcrService.retainWholePageAlternatives(processed, original);
    expect(whole.text, '子聖甲');
    expect(whole.alternatives, ['子格']);
    final combined = OcrService.useSegmentedOrWhole(whole, ['子格'], []);
    expect(combined.alternatives, ['子聖甲', '子格']);
  });

  test('같은 전체 페이지 OCR은 비교 원문에 중복하지 않는다', () {
    final whole = OcrService.retainWholePageAlternatives(result('子格'), result('子格'));
    expect(whole.alternatives, isEmpty);
  });

  test('Latin noise and whitespace cannot outweigh more Han characters', () {
    final processed = result('子聖甲');
    final original = result('子 abcdefghijklmnopqrstuvwxyz          ');
    expect(OcrService.selectCandidate(processed, original), same(processed));
  });

  test('more Han characters select original and ties preserve processed', () {
    final processed = result('子格');
    final original = result('子聖甲');
    expect(OcrService.selectCandidate(processed, original), same(original));
    expect(OcrService.selectCandidate(processed, result('子核')), same(processed));
  });

  test('족보 인물 표기가 있는 후보를 단순 한자 잡음보다 우선한다', () {
    final structured = result('子格 配原州邊氏 丁未生');
    final noise = result('山川天地日月星辰花鳥風雨春夏秋冬');
    expect(OcrService.selectCandidate(structured, noise), same(structured));
  });

  test('공백 뒤 인물 표제도 OCR 후보 점수에 반영한다', () {
    final structured = result('山川 子格');
    final noise = result('山川天地日');
    // structured: 4 Han + 4 heading points; noise: 5 Han.
    expect(OcrService.selectCandidate(structured, noise), same(structured));
  });

  test('구조 표지 뒤 OCR 공백이 있어도 같은 후보를 우선하고 원문을 보존한다', () {
    final spaced = result('子 格 配 原州邊氏 丁未 生');
    final noise = result('山川天地日月星辰花鳥風雨春夏秋冬');
    final combined = OcrService.retainWholePageAlternatives(spaced, noise);
    expect(combined.text, spaced.text);
    expect(combined.alternatives, [noise.text]);
    expect(spaced.text, '子 格 配 原州邊氏 丁未 生');
  });

  test('인물·배우자·간지 표지의 공백을 각각 후보 점수에 반영한다', () {
    for (final pair in [
      ('山川 子 格', '山川天地日'),
      ('配 原州邊氏', '山川天地日月'),
      ('丁 未 生', '山川天地'),
    ]) {
      final structured = result(pair.$1);
      expect(OcrService.selectCandidate(structured, result(pair.$2)),
          same(structured), reason: pair.$1);
    }
  });

  test('공백으로 나뉜 묘지 좌향에는 인물 표제 점수를 주지 않는다', () {
    final orientation = result('子 坐午向');
    final other = result('山川天地日');
    expect(OcrService.selectCandidate(orientation, other), same(other));
  });

  test('compatibility Han characters count as Han characters', () {
    final processed = result('子');
    final original = result('子\uF900');
    expect(OcrService.selectCandidate(processed, original), same(original));
  });
}
