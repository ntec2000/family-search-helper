import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// 가로 구획선으로 나누어 다른 세대의 열이 서로 섞이지 않게 한다.
/// shortcut: 직선 구획이 없는 문서는 전체 이미지 OCR과 수동 영역 선택을 사용한다.
List<Uint8List> genealogyOcrRegions(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('이미지를 해독할 수 없습니다.');
  final image = img.bakeOrientation(decoded);
  final left = (image.width * .08).round();
  final right = (image.width * .94).round();
  final tolerance = (image.height * .005).round().clamp(2, 20);
  final rows = <int>[];
  for (var y = (image.height * .03).round(); y < image.height * .98; y++) {
    var dark = 0;
    var samples = 0;
    for (var x = left; x < right; x += 3) {
      for (var dy = (y - tolerance).clamp(0, image.height - 1);
          dy <= (y + tolerance).clamp(0, image.height - 1); dy++) {
        if (img.getLuminance(image.getPixel(x, dy)) < 205) {
          dark++;
          break;
        }
      }
      samples++;
    }
    if (samples > 0 && dark / samples > .72) {
      if (rows.isEmpty || y - rows.last > tolerance * 2 + 2) {
        rows.add(y);
      } else {
        rows[rows.length - 1] = y;
      }
    }
  }
  if (rows.length < 3 || rows.length > 16) return [];
  final regions = <Uint8List>[];
  for (var i = 0; i < rows.length - 1; i++) {
    final top = rows[i] + 5;
    final height = rows[i + 1] - top - 4;
    if (height < image.height * .045) continue;
    var crop = img.copyCrop(image, x: left, y: top,
        width: right - left, height: height);
    if (crop.width < 1800) {
      crop = img.copyResize(crop, width: 1800,
          interpolation: img.Interpolation.linear);
    }
    regions.add(Uint8List.fromList(img.encodeJpg(crop, quality: 96)));
  }
  return regions;
}

/// 구획의 흰 세로 간격으로 열을 나누고 테두리 바깥의 글자는 분리한다.
List<Uint8List> genealogyOcrColumns(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('이미지를 해독할 수 없습니다.');
  final counts = List<int>.filled(image.width, 0);
  final top = (image.height * .03).round();
  final bottom = (image.height * .97).round();
  for (var x = 0; x < image.width; x++) {
    for (var y = top; y < bottom; y++) {
      if (img.getLuminance(image.getPixel(x, y)) < 180) counts[x]++;
    }
  }
  final rules = [for (var x = 0; x < image.width; x++)
    if (counts[x] > (bottom - top) * .75) x];
  final right = rules.where((x) => x > image.width * .8).firstOrNull ?? image.width;
  final spans = <(int, int)>[];
  int? start;
  var last = 0;
  final gap = (image.width * .003).round().clamp(2, 10);
  for (var x = 0; x <= right; x++) {
    if (x < right && counts[x] > image.height * .05) {
      start ??= x;
      last = x;
    } else if (start != null && (x - last > gap || x == right)) {
      if (last - start > gap && !rules.any((r) => r >= start! && r <= last)) {
        spans.add((start, last));
      }
      start = null;
    }
  }
  if (spans.length < 2 || spans.length > 80) return [];
  final columns = <Uint8List>[];
  for (var i = spans.length - 1; i >= 0; i--) {
    final (start, end) = spans[i];
    final left = (start - 14).clamp(i == 0 ? 0 : (spans[i - 1].$2 + start) ~/ 2, start);
    final edge = i == spans.length - 1 ? right : (end + spans[i + 1].$1) ~/ 2;
    final columnRight = (end + 14).clamp(end, edge - 1);
    final crop = img.copyCrop(image, x: left, y: 0,
        width: columnRight - left + 1, height: image.height);
    columns.add(Uint8List.fromList(img.encodePng(img.copyExpandCanvas(crop,
        newWidth: crop.width + 24, newHeight: crop.height + 24,
        position: img.ExpandCanvasPosition.center,
        backgroundColor: img.ColorRgb8(255, 255, 255)))));
  }
  return columns;
}
