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

  const twoRows = <Rect>[
    Rect.fromLTWH(10, 90, 20, 20),
    Rect.fromLTWH(100, 10, 20, 20),
    Rect.fromLTWH(10, 10, 20, 20),
    Rect.fromLTWH(100, 90, 20, 20),
  ];

  test('full pages read the upper band before the lower band', () {
    expect(verticalReadingOrder(twoRows, splitRows: true), [1, 2, 3, 0]);
  });

  test('row crops keep reading down each column across gaps', () {
    expect(verticalReadingOrder(twoRows), [1, 3, 2, 0]);
  });

  test('a box spanning the gap prevents a split', () {
    final boxes = [...twoRows, const Rect.fromLTWH(55, 10, 20, 100)];
    expect(verticalReadingOrder(boxes, splitRows: true), [1, 3, 4, 2, 0]);
  });

  test('a lone fragment does not create a band', () {
    final boxes = [...twoRows.take(3), const Rect.fromLTWH(10, 120, 20, 20)];
    expect(verticalReadingOrder(boxes, splitRows: true), [1, 2, 0, 3]);
  });
}
