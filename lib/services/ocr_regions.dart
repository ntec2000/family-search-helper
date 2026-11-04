import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// 가로 구획선으로 나누어 다른 세대의 열이 서로 섞이지 않게 한다.
/// shortcut: 직선 구획이 없는 문서는 전체 이미지 OCR과 수동 영역 선택을 사용한다.
List<Uint8List> genealogyOcrRegions(Uint8List bytes) =>
    genealogyOcrRows(bytes).map((row) => row.body).toList();

typedef GenealogyOcrRow = ({Uint8List body, Uint8List? generationMargin});

List<GenealogyOcrRow> genealogyOcrRows(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('이미지를 해독할 수 없습니다.');
  final image = img.bakeOrientation(decoded);
  final left = (image.width * .08).round();
  final right = (image.width * .94).round();
  final tolerance = (image.height * .005).round().clamp(2, 20);
  final rows = <int>[];
  int? ruleStart;
  var ruleEnd = 0;
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
      if (ruleStart != null && y - ruleEnd > tolerance * 2 + 2) {
        rows.add((ruleStart + ruleEnd) ~/ 2);
        ruleStart = null;
      }
      ruleStart ??= y;
      ruleEnd = y;
    }
  }
  if (ruleStart != null) rows.add((ruleStart + ruleEnd) ~/ 2);
  if (rows.length < 3 || rows.length > 16) return [];
  final regions = <GenealogyOcrRow>[];
  for (var i = 0; i < rows.length - 1; i++) {
    // 허용 폭의 아래 끝에서 자르면 선 바로 아래 子/女 표제가 잘린다.
    final top = rows[i] + 2;
    final height = rows[i + 1] - top - 2;
    if (height < image.height * .045) continue;
    final frame = _rightFrame(image, top, height);
    var crop = img.copyCrop(image, x: left, y: top,
        width: right - left, height: height);
    if (crop.width < 1800) {
      crop = img.copyResize(crop, width: 1800,
          interpolation: img.Interpolation.linear);
    }
    regions.add((
      body: Uint8List.fromList(img.encodeJpg(crop, quality: 96)),
      generationMargin: frame == null ? null : _generationMargin(image, frame, top, height),
    ));
  }
  return regions;
}

/// A ruled frame separates the 世 label from the person columns.
int? _rightFrame(img.Image image, int top, int height) {
  for (var x = (image.width * .97).floor(); x >= image.width * .8; x--) {
    var dark = 0;
    for (var y = top; y < top + height; y++) {
      if (img.getLuminance(image.getPixel(x, y)) < 180) dark++;
    }
    if (dark >= height * .75) return x;
  }
  return null;
}

Uint8List? _generationMargin(img.Image image, int frame, int top, int height) {
  final left = frame + 3;
  if (image.width - left < 8) return null;
  final margin = img.copyCrop(image, x: left, y: top,
      width: image.width - left, height: height);
  final resized = height < 720 ? img.copyResize(margin, height: 720,
      interpolation: img.Interpolation.linear) : margin;
  for (final pixel in resized) {
    final value = img.getLuminance(pixel) < 205 ? 0 : 255;
    pixel.setRgb(value, value, value);
  }
  return Uint8List.fromList(img.encodePng(img.copyExpandCanvas(resized,
      newWidth: resized.width + 32, newHeight: resized.height + 32,
      position: img.ExpandCanvasPosition.center,
      backgroundColor: img.ColorRgb8(255, 255, 255))));
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
    // OCR 열의 오른쪽 가장자리 글자를 포함하되 이웃 열을 침범하지 않는다.
    // 폭이 매우 좁은 열에서도 crop 범위가 유효하도록 경계를 보정한다.
    final safeEdge = edge.clamp(end + 1, image.width);
    final columnRight = (end + 14).clamp(end, safeEdge - 1);
    final crop = img.copyCrop(image, x: left, y: 0,
        width: columnRight - left + 1, height: image.height);
    columns.add(Uint8List.fromList(img.encodePng(img.copyExpandCanvas(crop,
        newWidth: crop.width + 24, newHeight: crop.height + 24,
        position: img.ExpandCanvasPosition.center,
        backgroundColor: img.ColorRgb8(255, 255, 255)))));
  }
  return columns;
}

typedef GenealogyColumnLayout = ({bool heading, bool startsLow});

/// 빈 윗부분이 충분히 큰 열은 독립 표제보다 이어지는 기록일 가능성이 높다.
List<GenealogyColumnLayout> genealogyOcrColumnLayouts(List<Uint8List> columns) {
  return columns.map((bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) throw const FormatException('열 이미지를 해독할 수 없습니다.');
    // 열 이미지 생성 시 더한 상하좌우 여백을 제외한다.
    final width = image.width - 24;
    final height = image.height - 24;
    final earlyEnd = 12 + (height * .32).floor();
    var earlyInk = 0;
    var lateInk = 0;
    for (var y = 12; y < image.height - 12; y++) {
      var dark = 0;
      for (var x = 12; x < image.width - 12; x++) {
        if (img.getLuminance(image.getPixel(x, y)) < 180) dark++;
      }
      if (dark < (width * .08).ceil()) continue;
      if (y < earlyEnd) {
        earlyInk++;
      } else {
        lateInk++;
      }
    }
    final startsLow = earlyInk == 0 && lateInk >= 3;
    return (heading: !startsLow && width > height * .19, startsLow: startsLow);
  }).toList();
}

List<bool> genealogyOcrColumnHeadings(List<Uint8List> columns) =>
    genealogyOcrColumnLayouts(columns).map((layout) => layout.heading).toList();

/// Magnify only the top of a vertical column, where the person marker appears.
Uint8List genealogyOcrNameCrop(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('열 이미지를 해독할 수 없습니다.');
  final height = (12 + (image.width - 24) * 4).clamp(1, image.height);
  final crop = img.copyCrop(image, x: 0, y: 0, width: image.width, height: height);
  final enlarged = img.copyResize(crop, width: crop.width * 2,
      interpolation: img.Interpolation.linear);
  return Uint8List.fromList(img.encodePng(enlarged));
}
