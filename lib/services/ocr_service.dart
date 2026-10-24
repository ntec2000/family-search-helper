import 'dart:io';
import 'vertical_reading_order.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Google ML Kit 기반 한자 OCR (온디바이스 · 무료)
class OcrService {
  static final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.chinese);

  /// 이미지 경로에서 한자 텍스트 추출.
  /// 세로쓰기 족보의 경우, 블록 → 줄 → 단어 순으로 위→아래/우→좌 정렬.
  static Future<OcrResult> recognize(String imagePath) async {
    final input = InputImage.fromFile(File(imagePath));
    final result = await _recognizer.processImage(input);

    // 세로쓰기: 오른쪽 열부터, 같은 열에서는 위에서 아래로 읽는다.
    // 고정 30px 행 기준은 이미지 크기에 따라 순서를 뒤섞을 수 있다.
    final blocks = [...result.blocks];
    final order = verticalReadingOrder(
      blocks.map((block) => block.boundingBox).toList(),
    );
    final orderedBlocks = [for (final index in order) blocks[index]];

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
    if (processed == null) return original!;
    if (original == null) return processed;
    return selectCandidate(processed, original);
  }

  /// 공백이나 검출 블록 수가 늘어도 한자가 적은 후보를 우선하지 않는다.
  static OcrResult selectCandidate(OcrResult processed, OcrResult original) {
    final hanja = RegExp(r'[\u3400-\u9fff\uf900-\ufaff]');
    final processedCount = hanja.allMatches(processed.text).length;
    final originalCount = hanja.allMatches(original.text).length;
    return originalCount > processedCount ? original : processed;
  }

  static Future<void> dispose() async {
    await _recognizer.close();
  }
}

class OcrResult {
  final String text;
  final List<TextBlock> rawBlocks;
  OcrResult({required this.text, required this.rawBlocks});
}
