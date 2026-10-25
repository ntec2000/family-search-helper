import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';

Future<Uint8List> renderPdfPage(PdfDocument document, int number) async {
  if (number < 1 || number > document.pagesCount) {
    throw RangeError.range(number, 1, document.pagesCount, 'page');
  }
  final page = await document.getPage(number);
  try {
    final scale = math.min(3.0, 3000 / math.max(page.width, page.height));
    final image = await page.render(width: page.width * scale,
        height: page.height * scale, format: PdfPageImageFormat.png,
        backgroundColor: '#ffffff');
    if (image == null) throw StateError('PDF 페이지를 이미지로 변환하지 못했습니다.');
    return image.bytes;
  } finally {
    await page.close();
  }
}
