import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/hanja_dict.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';
import 'package:family_search_helper/services/ocr_column_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const path = String.fromEnvironment('OCR_RESULTS');
  if (path.isEmpty) return;
  test('실제 OCR과 정답 전사의 인식·파싱 결과를 따로 기록한다', () async {
    await HanjaDict.instance.load();
    final data = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final regions = (data['results'] as List).map((r) => r['columns'] == null
        ? r['text'] as String : assembleOcrColumns(
            (r['columns'] as List).map((c) => c['text'] as String).toList())).toList();
    final people = JokboParser.parseRegions(regions);
    const reference = ['昃','格','聖甲','核','顯五','承烈','承勳','賢東',
      '炳吉','炳旭','炳烈','炳直','權頭','權龜壽','李集','金免傑','尹兢秀'];
    final raw = (data['results'] as List).map((r) => r['text']).join().replaceAll(RegExp(r'\s+'), '');
    final names = people.expand((p) => [p.nameHanja,
      if (p.gender == 'F') p.spouseHanja ?? '']).where((n) => n.isNotEmpty).toSet();
    final report = {
      'metric': 'Exact reference-name strings present; not overall OCR accuracy',
      'referenceNameCount': reference.length,
      'rawNamesPresent': reference.where(raw.contains).toList(),
      'parsedNamesCorrect': names.where(reference.contains).toList(),
      'parsedOtherCandidates': names.where((n) => !reference.contains(n)).toList(),
      'persons': people.map((p) => p.toMap()).toList(),
      'regionsAssembled': regions,
    };
    File('$path.evaluation.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    expect(names.contains('四'), isFalse);
    expect(names.contains('甲子十'), isFalse);
    expect(people.every((p) => p.fatherId == null && p.motherId == null), isTrue);
  });
}
