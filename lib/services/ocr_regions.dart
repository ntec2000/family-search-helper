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
  _joinHeadingFragments(image, spans);
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


typedef _InkRun = ({int top, int bottom, int inkRows});

/// Join only tall, narrow pieces sharing a large glyph's vertical band.
/// Ordinary note columns and two complete adjacent headings stay separate.
void _joinHeadingFragments(img.Image image, List<(int, int)> spans) {
  List<_InkRun> runs((int, int) span) {
    final width = span.$2 - span.$1 + 1;
    final minimum = (image.height * .14).ceil();
    final output = <_InkRun>[];
    int? top;
    var last = 0;
    var runInkRows = 0;
    var totalInkRows = 0;
    void finish() {
      if (top != null && last - top! + 1 >= minimum &&
          last - top! + 1 <= image.height * .45 &&
          last - top! + 1 >= width * 1.25) {
        output.add((top: top!, bottom: last, inkRows: runInkRows));
      }
      top = null;
      runInkRows = 0;
    }
    for (var y = (image.height * .03).ceil();
        y < image.height * .97; y++) {
      var dark = 0;
      for (var x = span.$1; x <= span.$2; x++) {
        if (img.getLuminance(image.getPixel(x, y)) < 180) dark++;
      }
      if (dark >= (width * .08).ceil().clamp(2, width)) {
        if (top != null && y - last > 4) finish();
        top ??= y;
        last = y;
        runInkRows++;
        totalInkRows++;
      }
    }
    finish();
    // Multiple equally sized runs usually indicate separate note columns.
    return output.length == 1 && output.single.inkRows >= totalInkRows * .5
        ? output : <_InkRun>[];
  }

  for (var i = 0; i + 1 < spans.length; i++) {
    final left = spans[i];
    final right = spans[i + 1];
    final gap = right.$1 - left.$2 - 1;
    final combinedWidth = right.$2 - left.$1 + 1;
    var join = false;
    for (final a in runs(left)) {
      for (final b in runs(right)) {
        final ah = a.bottom - a.top + 1;
        final bh = b.bottom - b.top + 1;
        final small = ah < bh ? ah : bh;
        final large = ah > bh ? ah : bh;
        final overlap = (a.bottom < b.bottom ? a.bottom : b.bottom) -
            (a.top > b.top ? a.top : b.top) + 1;
        if (overlap >= small * .75 && large <= small * 1.6 &&
            gap <= small * .4 && combinedWidth <= large * 1.45) {
          join = true;
        }
      }
    }
    if (join) {
      spans[i] = (left.$1, right.$2);
      spans.removeAt(i + 1);
      // A joined full glyph is no longer a narrow fragment; recheck safely.
      i--;
    }
  }
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

/// Reflow large heading glyphs into one horizontal line without rotating them.
/// Smaller printed Korean readings are excluded by relative glyph height.
/// This is a second OCR view, never a replacement for the source image.
Uint8List? genealogyOcrNameStrip(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('열 이미지를 해독할 수 없습니다.');
  if (image.width <= 24 || image.height <= 24) return null;
  final runs = <({int top, int bottom, int left, int right})>[];
  final gap = (image.height * .008).round().clamp(2, 5);
  int? top;
  var last = 0;
  var left = image.width;
  var right = 0;
  void finish() {
    if (top != null && last - top! + 1 >= 6 &&
        last - top! + 1 <= image.height * .5) {
      runs.add((top: top!, bottom: last, left: left, right: right));
    }
    top = null;
    left = image.width;
    right = 0;
  }
  for (var y = 12; y < image.height - 12; y++) {
    var count = 0;
    var rowLeft = image.width;
    var rowRight = 0;
    for (var x = 12; x < image.width - 12; x++) {
      if (img.getLuminance(image.getPixel(x, y)) >= 180) continue;
      count++;
      if (x < rowLeft) rowLeft = x;
      if (x > rowRight) rowRight = x;
    }
    if (count < 2) continue;
    if (top != null && y - last > gap + 1) finish();
    top ??= y;
    last = y;
    if (rowLeft < left) left = rowLeft;
    if (rowRight > right) right = rowRight;
  }
  finish();
  if (runs.length < 2) return null;
  final largest = runs.fold<int>(0, (value, run) {
    final height = run.bottom - run.top + 1;
    return height > value ? height : value;
  });
  final selected = <({int top, int bottom, int left, int right})>[];
  for (final run in runs) {
    final height = run.bottom - run.top + 1;
    if (height < largest * .65) {
      if (selected.isNotEmpty) break;
      continue;
    }
    final width = run.right - run.left + 1;
    if (width < height * .3 || width > height * 1.7) return null;
    selected.add(run);
    // Marker plus up to four name glyphs; never silently truncate more.
    if (selected.length > 5) return null;
  }
  if (selected.length < 2) return null;
  final strip = img.Image(width: selected.length * 80 + 24, height: 88);
  img.fill(strip, color: img.ColorRgb8(255, 255, 255));
  for (var i = 0; i < selected.length; i++) {
    final run = selected[i];
    final glyph = img.copyCrop(image, x: run.left, y: run.top,
        width: run.right - run.left + 1, height: run.bottom - run.top + 1);
    final scale = 64 / (glyph.width > glyph.height ? glyph.width : glyph.height);
    final resized = img.copyResize(glyph,
        width: (glyph.width * scale).round().clamp(1, 64),
        height: (glyph.height * scale).round().clamp(1, 64),
        interpolation: img.Interpolation.linear);
    img.compositeImage(strip, resized,
        dstX: 12 + i * 80 + (64 - resized.width) ~/ 2,
        dstY: 12 + (64 - resized.height) ~/ 2);
  }
  return Uint8List.fromList(img.encodePng(strip));
}
