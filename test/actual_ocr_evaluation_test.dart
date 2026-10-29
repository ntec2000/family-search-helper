import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/hanja_dict.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';
import 'package:family_search_helper/services/ocr_column_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const path = String.fromEnvironment('OCR_RESULTS');
  test('기준 이름 발견·누락 계산은 실제 OCR 파일 없이도 검증한다', () {
    const reference = ['昃', '格', '核'];
    const raw = '子昃字良甫子核丁酉生';
    const parsed = <String>{'昃', '核', '誤'};
    final rawPresent = reference.where(raw.contains).toList();
    final rawMissing = reference.where((name) => !raw.contains(name)).toList();
    final parsedCorrect = reference.where(parsed.contains).toList();
    final parsedMissing = reference.where((name) => !parsed.contains(name)).toList();
    final extraCandidates = parsed.where((name) => !reference.contains(name)).toList();
    expect(rawPresent, ['昃', '核']);
    expect(rawMissing, ['格']);
    expect(parsedCorrect, ['昃', '核']);
    expect(parsedMissing, ['格']);
    expect(extraCandidates, ['誤']);
    expect(rawPresent.length / reference.length, closeTo(2 / 3, 0.000001));
    expect(parsedCorrect.length / reference.length, closeTo(2 / 3, 0.000001));
  });
  if (path.isEmpty) return;
  test('실제 OCR과 정답 전사의 인식·파싱 결과를 따로 기록한다', () async {
    await HanjaDict.instance.load();
    final data = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final regions = (data['results'] as List).expand((r) {
      if (r['columns'] == null) return [r['text'] as String];
      final columns = r['columns'] as List;
      return assembleOcrEntries(columns.map((c) => c['text'] as String).toList(),
        headings: columns.any((c) => c.containsKey('heading'))
          ? columns.map((c) => c['heading'] == true).toList() : null);
    }).toList();
    final people = JokboParser.parseRegions(regions);
    const reference = ['昃','格','聖甲','核','顯五','承烈','承勳','賢東',
      '炳吉','炳旭','炳烈','炳直','權頭','權龜壽','李集','金免傑','尹兢秀'];
    // 열 단위 OCR에는 text 필드가 없을 수 있다. 실제 인식된 열만 모아 비교한다.
    final raw = (data['results'] as List).expand<String>((result) {
      final columns = result['columns'] as List?;
      if (columns != null) {
        return columns.map((column) => column['text'] as String);
      }
      return [result['text'] as String];
    }).join().replaceAll(RegExp(r'\s+'), '');
    final names = people.expand((p) => [p.nameHanja,
      if (p.gender == 'F') p.spouseHanja ?? '']).where((n) => n.isNotEmpty).toSet();
    final rawNamesPresent = reference.where(raw.contains).toList();
    final rawNamesMissing = reference.where((name) => !raw.contains(name)).toList();
    final parsedNamesCorrect = reference.where(names.contains).toList();
    final parsedNamesMissing = reference.where((name) => !names.contains(name)).toList();
    final parsedOtherCandidates = names.where((name) => !reference.contains(name)).toList();
    final report = {
      'metric': 'Exact reference-name strings present; not overall OCR accuracy',
      'referenceNameCount': reference.length,
      'rawNamesPresent': rawNamesPresent,
      'rawNamesMissing': rawNamesMissing,
      'parsedNamesCorrect': parsedNamesCorrect,
      'parsedNamesMissing': parsedNamesMissing,
      'parsedOtherCandidates': parsedOtherCandidates,
      'rawReferenceNameCoverage': rawNamesPresent.length / reference.length,
      'parsedReferenceNameCoverage': parsedNamesCorrect.length / reference.length,
      'note': 'Name-string coverage only; missing and extra candidates require manual review.',
      'persons': people.map((p) => p.toMap()).toList(),
      'regionsAssembled': regions,
    };
    File('$path.evaluation.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    expect(names.contains('四'), isFalse);
    expect(names.contains('甲子十'), isFalse);
    expect(people.every((p) => p.fatherId == null && p.motherId == null), isTrue);
  });
}
