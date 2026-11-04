import 'dart:math' as math;
import 'dart:ui' show Rect;

/// Returns indexes in traditional vertical reading order:
/// columns right to left, then blocks top to bottom within each column.
/// Coordinates are kept separate from ML Kit to allow deterministic tests.
List<int> verticalReadingOrder(List<Rect> boxes, {bool splitRows = false}) {
  final indexes = List<int>.generate(boxes.length, (i) => i);
  if (!splitRows || boxes.length < 4) return _orderColumns(boxes, indexes);

  // Adapt the whitespace partitioning idea from National Diet Library,
  // NDLOCR reading_order (CC BY 4.0):
  // https://github.com/ndl-lab/reading_order/tree/master/reading_order/xy_cut
  // This implementation only cuts horizontal gaps in full genealogy pages.
  final widths = boxes.map((box) => box.width).toList()..sort();
  final gapThreshold = widths[widths.length ~/ 2];
  final byTop = [...indexes]
    ..sort((a, b) => boxes[a].top.compareTo(boxes[b].top));
  final bands = <List<int>>[];
  var band = <int>[];
  var bottom = boxes[byTop.first].top;
  for (final index in byTop) {
    final box = boxes[index];
    if (band.isNotEmpty && box.top - bottom > gapThreshold) {
      bands.add(band);
      band = <int>[];
    }
    band.add(index);
    bottom = math.max(bottom, box.bottom);
  }
  bands.add(band);

  // A lone heading or isolated OCR fragment is weak evidence of a new row.
  if (bands.length == 1 ||
      !bands.every((band) => _hasSeparateColumns(boxes, band))) {
    return _orderColumns(boxes, indexes);
  }
  return [for (final band in bands) ..._orderColumns(boxes, band)];
}

bool _hasSeparateColumns(List<Rect> boxes, List<int> band) {
  var rightmostLeft = boxes[band.first].left;
  var leftmostRight = boxes[band.first].right;
  for (final index in band.skip(1)) {
    rightmostLeft = math.max(rightmostLeft, boxes[index].left);
    leftmostRight = math.min(leftmostRight, boxes[index].right);
  }
  return rightmostLeft >= leftmostRight;
}

List<int> _orderColumns(List<Rect> boxes, List<int> indexes) {
  indexes.sort((a, b) => boxes[b].center.dx.compareTo(boxes[a].center.dx));

  final columns = <List<int>>[];
  for (final index in indexes) {
    final rect = boxes[index];
    var bestColumn = -1;
    var bestOverlap = 0.0;
    for (var i = 0; i < columns.length; i++) {
      final members = columns[i];
      final left = members.map((j) => boxes[j].left).reduce((a, b) => a > b ? a : b);
      final right = members.map((j) => boxes[j].right).reduce((a, b) => a < b ? a : b);
      final overlap = (right < rect.right ? right : rect.right) -
          (left > rect.left ? left : rect.left);
      final minWidth = rect.width < boxes[members.first].width
          ? rect.width
          : boxes[members.first].width;
      if (minWidth > 0 && overlap / minWidth >= 0.5 && overlap > bestOverlap) {
        bestOverlap = overlap;
        bestColumn = i;
      }
    }
    if (bestColumn == -1) {
      columns.add(<int>[index]);
    } else {
      columns[bestColumn].add(index);
    }
  }
  columns.sort((a, b) {
    final ax = a.map((i) => boxes[i].center.dx).reduce((x, y) => x + y) / a.length;
    final bx = b.map((i) => boxes[i].center.dx).reduce((x, y) => x + y) / b.length;
    return bx.compareTo(ax);
  });
  for (final column in columns) {
    column.sort((a, b) {
      final top = boxes[a].top.compareTo(boxes[b].top);
      return top != 0 ? top : boxes[b].center.dx.compareTo(boxes[a].center.dx);
    });
  }
  return <int>[for (final column in columns) ...column];
}
