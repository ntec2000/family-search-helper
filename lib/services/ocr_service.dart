import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'dart:typed_data';
import 'image_store.dart';
import 'ocr_regions.dart';
import 'ocr_column_text.dart';
import 'browser_ocr_stub.dart' if (dart.library.js_interop) 'browser_ocr.dart';
import 'vertical_reading_order.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Google ML Kit 기반 한자 OCR (온디바이스 · 무료)
class OcrService {
  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.chinese);

  /// 이미지 경로에서 한자 텍스트 추출.
  /// 세로쓰기 족보의 경우, 블록 → 줄 → 단어 순으로 위→아래/우→좌 정렬.
  static Future<OcrResult> recognize(String imagePath, {bool singleColumn = false}) async {
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
    );
    final orderedBlocks = [for (final index in order) lines[index]];

    final buf = StringBuffer();
    for (final b in orderedBlocks) {
      buf.writeln(b.text);
    }

    return OcrResult(text: buf.toString(), rawBlocks: result.blocks);
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
      processed = await recognize(processedPath);
    } catch (_) {
      // 손상된 전처리본이어도 원본 인식은 계속 시도한다.
    }
    if (originalPath == null || originalPath == processedPath) {
      if (processed == null) throw StateError('OCR 입력을 읽을 수 없습니다');
      return processed;
    }

    OcrResult? original;
    try {
      original = await recognize(originalPath);
    } catch (_) {
      // 원본 형식이 ML Kit에서 거부되면 전처리 결과를 사용한다.
    }
    if (processed == null && original == null) {
      throw StateError('OCR 입력을 읽을 수 없습니다');
    }
    final wholePage = processed == null ? original! : original == null
        ? processed : selectCandidate(processed, original);
    late final List<Uint8List> regions;
    try {
      regions = await compute(genealogyOcrRegions,
          await readImageBytes(originalPath));
    } catch (_) {
      return wholePage;
    }
    if (regions.length < 2) return wholePage;
    final texts = <String>[];
    final rawColumns = <String>[];
    for (var i = 0; i < regions.length; i++) {
      onProgress?.call('세대 구획 ${i + 1}/${regions.length} 한자 인식 중...');
      try {
        final columns = await compute(genealogyOcrColumns, regions[i]);
        if (columns.isEmpty) {
          texts.add((await recognize(await storeImageBytes(regions[i]))).text);
        } else {
          final columnTexts = <String>[];
          for (var j = 0; j < columns.length; j++) {
            onProgress?.call('구획 ${i + 1}/${regions.length} · 세로 열 ${j + 1}/${columns.length} 인식 중...');
            columnTexts.add((await recognize(await storeImageBytes(columns[j], extension: 'png'),
                singleColumn: true)).text);
          }
          final headings = await compute(genealogyOcrColumnHeadings, columns);
          texts.addAll(assembleOcrEntries(columnTexts, headings: headings));
          rawColumns.add(columnTexts.join('\n'));
        }
      } catch (_) {
        // 구획 하나가 실패하면 일부 누락된 결과로 전체 원문을 대체하지 않는다.
        return wholePage;
      }
    }
    // 구획과 전체 인식은 원문 탭에서 함께 보존한다. 파싱은 구획 결과를 사용한다.
    return OcrResult(text: texts.join('\n'), rawBlocks: wholePage.rawBlocks,
        alternatives: [wholePage.text, ...rawColumns], regionTexts: texts);
  }

  /// 공백이나 검출 블록 수가 늘어도 한자가 적은 후보를 우선하지 않는다.
  static OcrResult selectCandidate(OcrResult processed, OcrResult original) {
    final hanja = RegExp(r'[\u3400-\u9fff\uf900-\ufaff]');
    final processedCount = hanja.allMatches(processed.text).length;
    final originalCount = hanja.allMatches(original.text).length;
    // 족보의 인물·배우자·간지 문맥을 우선하되 원문은 변경하지 않는다.
    int score(String value, int count) {
      final person = RegExp(r'(?:^|\\s)[子女男][一-鿿]{1,3}');
      final spouse = RegExp(r'配[一-鿿]{1,8}氏');
      final birth = RegExp(r'[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥][生卒]');
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
  final List<String> regionTexts;
  OcrResult({required this.text, required this.rawBlocks,
      this.alternatives = const [], this.regionTexts = const []});
}
