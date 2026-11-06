import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:family_search_helper/services/ocr_regions.dart';

void main() {
  img.Image blank({int height = 290}) =>
      img.fill(img.Image(width: 100, height: height),
          color: img.ColorRgb8(255, 255, 255));
  void ink(img.Image image, int x1, int y1, int x2, int y2) =>
      img.fillRect(image, x1: x1, y1: y1, x2: x2, y2: y2,
          color: img.ColorRgb8(0, 0, 0));
  Uint8List bytes(img.Image image) => Uint8List.fromList(img.encodePng(image));

  test('large glyphs reflow in source order and exclude small printed readings', () {
    final image = blank();
    for (final y in [20, 85, 150]) {
      ink(image, 30, y, 69, y + 49);
    }
    ink(image, 38, 220, 57, 239);
    final original = bytes(image);
    final saved = Uint8List.fromList(original);
    final strip = img.decodeImage(genealogyOcrNameStrip(original)!)!;
    expect((strip.width, strip.height), (264, 88));
    expect(original, orderedEquals(saved));
    for (var i = 0; i < 3; i++) {
      expect(img.getLuminance(strip.getPixel(44 + 80 * i, 44)), lessThan(50));
    }
  });

  test('an asymmetric glyph stays upright rather than rotating with the line', () {
    final image = blank();
    ink(image, 32, 20, 37, 69);
    ink(image, 32, 64, 61, 69);
    ink(image, 30, 90, 69, 139);
    final strip = img.decodeImage(genealogyOcrNameStrip(bytes(image))!)!;
    int dark(int top, int bottom) {
      var count = 0;
      for (var y = top; y < bottom; y++) {
        for (var x = 12; x < 76; x++) {
          if (img.getLuminance(strip.getPixel(x, y)) < 180) count++;
        }
      }
      return count;
    }
    expect(dark(44, 76), greaterThan(dark(12, 44)));
  });

  test('blank, a single glyph and a continuous rule do not create a strip', () {
    expect(genealogyOcrNameStrip(bytes(blank())), isNull);
    final image = blank();
    ink(image, 30, 20, 69, 69);
    expect(genealogyOcrNameStrip(bytes(image)), isNull);
    ink(image, 20, 80, 22, 270);
    expect(genealogyOcrNameStrip(bytes(image)), isNull);
  });

  test('more than five large glyphs are rejected rather than truncated', () {
    final image = blank(height: 400);
    for (var i = 0; i < 6; i++) {
      ink(image, 30, 20 + i * 55, 59, 49 + i * 55);
    }
    expect(genealogyOcrNameStrip(bytes(image)), isNull);
  });
}
