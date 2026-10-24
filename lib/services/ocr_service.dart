import 'dart:io';
import 'dart:ui' show Rect;
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

  static Future<void> dispose() async {
    await _recognizer.close();
  }
}

class OcrResult {
  final String text;
  final List<TextBlock> rawBlocks;
  OcrResult({required this.text, required this.rawBlocks});
}
