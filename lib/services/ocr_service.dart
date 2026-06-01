import 'dart:io';
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

    // 블록의 좌표를 기준으로 우→좌, 상→하 정렬 (세로쓰기 족보 표준)
    final blocks = [...result.blocks];
    blocks.sort((a, b) {
      // 같은 행 (y 차이 < 30) 이면 x 큰 쪽 우선 (우→좌)
      final yDiff = (a.boundingBox.top - b.boundingBox.top).abs();
      if (yDiff < 30) {
        return b.boundingBox.left.compareTo(a.boundingBox.left);
      }
      return a.boundingBox.top.compareTo(b.boundingBox.top);
    });

    final buf = StringBuffer();
    for (final b in blocks) {
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
