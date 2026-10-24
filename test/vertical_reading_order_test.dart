import 'dart:ui' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/vertical_reading_order.dart';

void main() {
  test('empty list', () => expect(verticalReadingOrder(<Rect>[]), isEmpty));
  test('right column first and top first', () {
    final boxes = <Rect>[
      const Rect.fromLTWH(10, 60, 20, 20),
      const Rect.fromLTWH(100, 60, 20, 20),
      const Rect.fromLTWH(10, 10, 20, 20),
      const Rect.fromLTWH(100, 10, 20, 20),
    ];
    expect(verticalReadingOrder(boxes), <int>[3, 1, 2, 0]);
  });
}
