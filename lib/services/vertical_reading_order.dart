import 'dart:ui' show Rect;

/// Returns indexes in traditional vertical reading order:
/// columns right to left, then blocks top to bottom within each column.
/// Coordinates are kept separate from ML Kit to allow deterministic tests.
List<int> verticalReadingOrder(List<Rect> boxes) {
  if (boxes.isEmpty) return <int>[];
  final indexes = List<int>.generate(boxes.length, (i) => i);
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
