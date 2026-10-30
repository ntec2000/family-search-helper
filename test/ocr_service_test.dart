import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/ocr_service.dart';

void main() {
  OcrResult result(String text) => OcrResult(text: text, rawBlocks: []);

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

  test('compatibility Han characters count as Han characters', () {
    final processed = result('子');
    final original = result('子\uF900');
    expect(OcrService.selectCandidate(processed, original), same(original));
  });
}
