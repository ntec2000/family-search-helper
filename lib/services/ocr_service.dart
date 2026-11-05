import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'image_store.dart';
import 'ocr_regions.dart';
import 'ocr_column_text.dart';
import 'jokbo_parser.dart';
import 'browser_ocr_stub.dart' if (dart.library.js_interop) 'browser_ocr.dart';
import 'vertical_reading_order.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Google ML Kit 기반 한자 OCR (온디바이스 · 무료)
class OcrService {
  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.chinese);

  /// 이미지 경로에서 한자 텍스트 추출.
  /// 세로쓰기 족보의 경우, 블록 → 줄 → 단어 순으로 위→아래/우→좌 정렬.
  static Future<OcrResult> recognize(String imagePath, {
    bool singleColumn = false,
    bool fullPage = false,
  }) async {
    if (kIsWeb) {
      return OcrResult(text: await recognizeInBrowser(imagePath, singleColumn: singleColumn), rawBlocks: []);
    }
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);

    // 세로쓰기: 오른쪽 열부터, 같은 열에서는 위에서 아래로 읽는다.
    // 고정 30px 행 기준은 이미지 크기에 따라 순서를 뒤섞을 수 있다.
    final lines = [for (final block in result.blocks) ...block.lines];
    final order = verticalReadingOrder(
      lines.map((line) => line.boundingBox).toList(),
      splitRows: fullPage,
    );
    final orderedBlocks = [for (final index in order) lines[index]];

    final buf = StringBuffer();
    for (final b in orderedBlocks) {
      buf.writeln(b.text);
    }

    return OcrResult(text: buf.toString(), rawBlocks: result.blocks);
  }

  /// A manually selected glyph is a review candidate, never a saved person.
  static Future<String> recognizeGlyph(String imagePath) async {
    if (kIsWeb) return recognizeGlyphInBrowser(imagePath);
    return (await recognize(imagePath, singleColumn: true)).text;
  }

  /// 원본과 전처리본을 모두 시도해 한자 정보가 더 많은 결과를 선택한다.
  /// shortcut: 검출량 비교는 정확도 측정이 아니므로 저장 전 원문 검토가 필요하다.
  static Future<OcrResult> recognizeBest(
    String processedPath, {
    String? originalPath,
    void Function(String)? onProgress,
  }) async {
    OcrResult? processed;
    try {
      processed = await recognize(processedPath, fullPage: true);
    } catch (_) {
      // 손상된 전처리본이어도 원본 인식은 계속 시도한다.
    }
    if (originalPath == null || originalPath == processedPath) {
      if (processed == null) throw StateError('OCR 입력을 읽을 수 없습니다');
      return processed;
    }

    OcrResult? original;
    try {
      original = await recognize(originalPath, fullPage: true);
    } catch (_) {
      // 원본 형식이 ML Kit에서 거부되면 전처리 결과를 사용한다.
    }
    final wholePage = processed == null ? original : original == null
        ? processed : retainWholePageAlternatives(processed, original);
    late final List<GenealogyOcrRow> regions;
    try {
      regions = await compute(genealogyOcrRows,
          await readImageBytes(originalPath));
    } catch (_) {
      return useSegmentedOrWhole(wholePage, [], []);
    }
    if (regions.length < 2) return useSegmentedOrWhole(wholePage, [], []);
    final texts = <String>[];
    final rawColumns = <String>[];
    final generationLabels = <String?>[];
    var nameRetriesLeft = 2;
    for (var i = 0; i < regions.length; i++) {
      final row = regions[i];
      onProgress?.call('세대 구획 ${i + 1}/${regions.length} 한자 인식 중...');
      try {
        final columns = await compute(genealogyOcrColumns, row.body);
        var entries = <String>[];
        if (columns.isNotEmpty) {
          final columnTexts = await readColumnsOrNull(columns.length, (j) async {
            onProgress?.call('구획 ${i + 1}/${regions.length} · 세로 열 ${j + 1}/${columns.length} 인식 중...');
            return (await recognize(await storeImageBytes(columns[j], extension: 'png'),
                singleColumn: true)).text;
          });
          if (columnTexts != null && hasReadableText(columnTexts)) {
            rawColumns.add(columnTexts.join('\n'));
            final layouts = await compute(genealogyOcrColumnLayouts, columns);
            for (var j = 0; j < columns.length && nameRetriesLeft > 0; j++) {
              if (layouts[j].startsLow || !_barePersonMarker.hasMatch(columnTexts[j].trim())) {
                continue;
              }
              nameRetriesLeft--;
              try {
                final crop = await compute(genealogyOcrNameCrop, columns[j]);
                final retry = await recognize(
                    await storeImageBytes(crop, extension: 'png'),
                    singleColumn: true);
                if (retry.text.trim().isNotEmpty) {
                  rawColumns.add('[구획 ${i + 1} · 열 ${j + 1} 인명 재판독] ${retry.text.trim()}');
                }
                final candidate = recoverBareName(columnTexts[j], retry.text);
                if (candidate != null) columnTexts[j] = candidate;
              } catch (_) {
                // A retry failure does not discard the first pass.
              }
            }
            entries = assembleOcrEntries(columnTexts,
                headings: layouts.map((layout) => layout.heading).toList(),
                startsLow: layouts.map((layout) => layout.startsLow).toList());
          }
        }
        if (JokboParser.parseRegions(entries).isEmpty) {
          final wholeRow = (await recognize(await storeImageBytes(row.body),
              singleColumn: wholePage == null)).text;
          // Keep readable column evidence when neither path finds a person.
          if (entries.isEmpty || JokboParser.parseRegions([wholeRow]).isNotEmpty) {
            entries = [wholeRow];
          } else if (wholeRow.trim().isNotEmpty) {
            rawColumns.add(wholeRow);
          }
        }
        String? label;
        final margin = row.generationMargin;
        if (margin != null && hasReadableText(entries)) {
          try {
            final marginText = (await recognize(
                await storeImageBytes(margin, extension: 'png'),
                singleColumn: true)).text.trim();
            if (marginText.isNotEmpty) {
              rawColumns.add('[구획 ${i + 1} 세대 여백] $marginText');
              label = marginText;
            }
          } catch (_) {
            // A failed margin must not discard the recognized people.
          }
        }
        texts.addAll(entries);
        generationLabels.addAll(List<String?>.filled(entries.length, label));
      } catch (_) {
        if (wholePage != null) return wholePage;
        // A failed row cannot replace previously recognized rows.
      }
    }
    return useSegmentedOrWhole(wholePage, texts, rawColumns,
        generationLabels: generationLabels);
  }

  static final _barePersonMarker = RegExp(r'^[子女男]$');
  static final _shortPersonName = RegExp(r'^[子女男][一-鿿]{1,3}$');
  static final _detailMarker = RegExp(r'[子女男字號墓配生卒父祖系繼坐向忌]');

  /// Only restore missing text. Keep already recognized names unchanged.
  static String? recoverBareName(String first, String retry) {
    final marker = first.trim();
    final candidate = retry.trim().replaceAll(RegExp(r'[ \t]+'), '');
    if (!_barePersonMarker.hasMatch(marker) ||
        !_shortPersonName.hasMatch(candidate) ||
        !candidate.startsWith(marker) ||
        _detailMarker.hasMatch(candidate.substring(1))) {
      return null;
    }
    return candidate;
  }

  /// 구획 결과가 전부 비었다면 읽힌 전체 페이지 결과를 잃지 않는다.
  static bool hasReadableText(List<String> texts) =>
      texts.any((text) => text.trim().isNotEmpty);

  /// 일부 열의 예외는 부분 결과를 사용하지 않고 구획 재인식을 요청한다.
  static Future<List<String>?> readColumnsOrNull(
      int count, Future<String> Function(int) readColumn) async {
    final texts = <String>[];
    try {
      for (var i = 0; i < count; i++) {
        texts.add(await readColumn(i));
      }
      return texts;
    } catch (_) {
      return null;
    }
  }

  /// 선택하지 않은 전체 페이지 OCR도 사용자가 원문 비교에 활용할 수 있다.
  static OcrResult retainWholePageAlternatives(OcrResult processed, OcrResult original) {
    final selected = selectCandidate(processed, original);
    final other = identical(selected, processed) ? original : processed;
    return OcrResult(text: selected.text, rawBlocks: selected.rawBlocks,
        alternatives: [
          ...selected.alternatives,
          if (other.text.trim().isNotEmpty && other.text != selected.text) other.text,
          ...other.alternatives,
        ], wholePageAlternatives: [
          ...selected.wholePageAlternatives,
          if (other.text.trim().isNotEmpty && other.text != selected.text) other.text,
          ...other.wholePageAlternatives,
        ], regionTexts: selected.regionTexts, generationLabels: selected.generationLabels);
  }

  static OcrResult useSegmentedOrWhole(OcrResult? wholePage,
      List<String> regions, List<String> rawColumns, {List<String?>? generationLabels}) {
    if (!hasReadableText(regions)) {
      if (wholePage != null) return wholePage;
      throw StateError('OCR 입력을 읽을 수 없습니다');
    }
    // 구획과 전체 인식은 원문 탭에서 함께 보존한다. 파싱은 구획 결과를 사용한다.
    return OcrResult(text: regions.join('\n'), rawBlocks: wholePage?.rawBlocks ?? [],
        alternatives: [
          if (wholePage != null) ...[wholePage.text, ...wholePage.alternatives],
          ...rawColumns,
        ],
        wholePageAlternatives: [
          if (wholePage != null) ...[wholePage.text, ...wholePage.wholePageAlternatives],
        ],
        regionTexts: regions, generationLabels: generationLabels);
  }

  /// 공백이나 검출 블록 수가 늘어도 한자가 적은 후보를 우선하지 않는다.
  static OcrResult selectCandidate(OcrResult processed, OcrResult original) {
    final hanja = RegExp(r'[\u3400-\u9fff\uf900-\ufaff]');
    final processedCount = hanja.allMatches(processed.text).length;
    final originalCount = hanja.allMatches(original.text).length;
    // 족보의 인물·배우자·간지 문맥을 우선하되 원문은 변경하지 않는다.
    int score(String value, int count) {
      final person = RegExp(r'(?:^|\s)[子女男]\s*(?!坐|向|孫|女|男)[一-鿿]{1,3}');
      final spouse = RegExp(r'配\s*[一-鿿]{1,8}氏');
      final birth = RegExp(r'[甲乙丙丁戊己庚辛壬癸]\s*[子丑寅卯辰巳午未申酉戌亥]\s*[生卒]');
      return count + person.allMatches(value).length * 4 +
          spouse.allMatches(value).length * 4 +
          birth.allMatches(value).length * 3;
    }
    return score(original.text, originalCount) >
            score(processed.text, processedCount)
        ? original : processed;
  }

  static Future<void> dispose() async {
    if (!kIsWeb) await _recognizer.close();
  }
}

class OcrResult {
  final String text;
  final List<TextBlock> rawBlocks;
  final List<String> alternatives;
  final List<String> wholePageAlternatives;
  final List<String> regionTexts;
  final List<String?>? generationLabels;
  OcrResult({required this.text, required this.rawBlocks,
      this.alternatives = const [], this.wholePageAlternatives = const [], this.regionTexts = const [], this.generationLabels});
}

