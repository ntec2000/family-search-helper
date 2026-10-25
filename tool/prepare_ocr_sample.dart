import 'dart:io';
import 'dart:convert';
import 'package:family_search_helper/services/ocr_regions.dart';

/// 로컬 이미지에서 평가용 구획만 출력하고 원본은 보존한다.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    throw ArgumentError('Usage: dart run tool/prepare_ocr_sample.dart <image> <output-directory>');
  }
  final regions = genealogyOcrRegions(await File(arguments[0]).readAsBytes());
  final directory = await Directory(arguments[1]).create(recursive: true);
  final manifest = <Map<String, dynamic>>[];
  for (var i = 0; i < regions.length; i++) {
    await File('${directory.path}/region-${i + 1}.jpg').writeAsBytes(regions[i]);
    final columns = genealogyOcrColumns(regions[i]);
    final headings = genealogyOcrColumnHeadings(columns);
    for (var j = 0; j < columns.length; j++) {
      await File('${directory.path}/region-${i + 1}-column-${j + 1}.png')
          .writeAsBytes(columns[j]);
      manifest.add({'file': 'region-${i + 1}-column-${j + 1}.png',
        'heading': headings[j]});
    }
  }
  await File('${directory.path}/columns.json').writeAsString(jsonEncode(manifest));
  stdout.writeln('${regions.length} regions prepared; source unchanged.');
}
