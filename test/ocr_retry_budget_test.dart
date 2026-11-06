import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/ocr_service.dart';
import 'package:family_search_helper/services/ocr_regions.dart';

void main() {
  List<GenealogyColumnLayout> headings(int count) =>
      List.generate(count, (_) => (heading: true, startsLow: false));

  test('book titles and generation labels do not consume heading retries', () {
    for (final text in ['2卷公派譜', '卷之一終', '|卷之', '二十三世']) {
      expect(OcrService.shouldRetryHeading(text,
          heading: true, startsLow: false), isFalse, reason: text);
    }
    expect(OcrService.shouldRetryHeading('|子聖甲',
        heading: true, startsLow: false), isFalse);
    expect(OcrService.shouldRetryHeading('子二\n承勳',
        heading: true, startsLow: false), isFalse);
    expect(OcrService.shouldRetryHeading('|予賢束',
        heading: true, startsLow: false), isTrue);
    // An explicit personal heading is not rejected merely for a rare glyph.
    expect(OcrService.shouldRetryHeading('子譜明',
        heading: true, startsLow: false), isFalse);
  });

  test('structural suspicion outranks an already readable single-character name', () {
    final columns = ['子格', '卷公派譜', '女孝集', '|子聖甲', '女權', '女全免傑'];
    expect(OcrService.selectHeadingRetries(columns, headings(columns.length),
        limit: 2), [2, 4]);
    expect(OcrService.selectHeadingRetries(columns, headings(columns.length),
        limit: 3), [2, 4, 5]);
    expect(columns.last, '女全免傑');
  });

  test('device-log shaped rows leave attempts for the last two generations', () {
    final rows = <List<String>>[
      [],
      ['子四', '2卷公派譜'],
      ['子格', '子二\n核', '女權 頭', '卷之一終'],
      ['|子聖甲', '子顯五', '女權龜壽', '女孝集'],
      ['|子承烈', '子二\n承勳'],
      ['|予賢束'],
      ['子炳吉1', '子二\n炳旭', '子万', '子四\n炳直', '女全免傑', '女尹競秀'],
    ];
    var remaining = 10;
    final attempted = <List<int>>[];
    for (var row = 0; row < rows.length; row++) {
      final selected = OcrService.selectHeadingRetries(rows[row],
          headings(rows[row].length),
          limit: OcrService.rowRetryQuota(remaining, rows.length - row - 1));
      attempted.add(selected);
      remaining -= selected.length;
      expect(remaining, greaterThanOrEqualTo(0));
      expect(selected.length, lessThanOrEqualTo(3));
    }
    expect(attempted[5], [0]);
    expect(attempted[6], [4, 5, 2]);
    expect(remaining, 0);
  });

  test('budget caps and continuation exclusions hold on unusual pages', () {
    expect(OcrService.rowRetryQuota(0, 5), 0);
    expect(OcrService.rowRetryQuota(1, 20), 1);
    expect(OcrService.rowRetryQuota(10, 0), 3);
    expect(OcrService.selectHeadingRetries(['子賢東束'],
        [(heading: true, startsLow: true)], limit: 3), isEmpty);
    expect(OcrService.selectHeadingRetries(['子格'], headings(1), limit: 0),
        isEmpty);
    expect(() => OcrService.selectHeadingRetries(['子格'], [], limit: 1),
        throwsArgumentError);
  });
}
