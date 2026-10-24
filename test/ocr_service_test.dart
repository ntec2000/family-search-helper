import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/ocr_service.dart';

void main() {
  OcrResult result(String text) => OcrResult(text: text, rawBlocks: []);

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

  test('compatibility Han characters count as Han characters', () {
    final processed = result('子');
    final original = result('子\uF900');
    expect(OcrService.selectCandidate(processed, original), same(original));
  });
}
