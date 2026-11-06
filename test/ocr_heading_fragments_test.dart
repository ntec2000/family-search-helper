import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:family_search_helper/services/ocr_regions.dart';

void main() {
  img.Image blank() {
    final image = img.Image(width: 400, height: 200);
    return img.fill(image, color: img.ColorRgb8(255, 255, 255));
  }

  void ink(img.Image image, int x1, int y1, int x2, int y2) =>
      img.fillRect(image, x1: x1, y1: y1, x2: x2, y2: y2,
          color: img.ColorRgb8(0, 0, 0));

  Uint8List bytes(img.Image image) => Uint8List.fromList(img.encodePng(image));

  test('large heading split into matching narrow radicals stays in one crop', () {
    final image = blank();
    ink(image, 40, 20, 58, 36);
    ink(image, 40, 55, 58, 71);
    ink(image, 240, 65, 250, 130);
    ink(image, 268, 65, 295, 130);
    expect(genealogyOcrColumns(bytes(image)), hasLength(2));
  });

  test('two complete neighboring headings remain independent', () {
    final image = blank();
    ink(image, 40, 20, 58, 36);
    ink(image, 40, 55, 58, 71);
    ink(image, 180, 65, 234, 130);
    ink(image, 254, 65, 308, 130);
    expect(genealogyOcrColumns(bytes(image)), hasLength(3));
  });

  test('small note columns and vertically mismatched fragments do not merge', () {
    final image = blank();
    ink(image, 50, 20, 65, 38);
    ink(image, 50, 55, 65, 73);
    ink(image, 80, 20, 95, 38);
    ink(image, 80, 55, 95, 73);
    ink(image, 240, 20, 250, 85);
    ink(image, 268, 105, 295, 170);
    expect(genealogyOcrColumns(bytes(image)), hasLength(4));
  });
  test('dense parallel note columns are not mistaken for one split glyph', () {
    final image = img.Image(width: 400, height: 400);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    for (final y in [30, 125, 220]) {
      ink(image, 240, y, 250, y + 65);
      ink(image, 268, y, 295, y + 65);
    }
    expect(genealogyOcrColumns(bytes(image)), hasLength(2));
  });

}
