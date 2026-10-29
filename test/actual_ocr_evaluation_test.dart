import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/hanja_dict.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';
import 'package:family_search_helper/services/ocr_column_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const path = String.fromEnvironment('OCR_RESULTS');
  test('서로 다른 OCR 열의 끝과 시작을 하나의 이름으로 오인하지 않는다', () {
    const reference = '聖甲';
    final rawColumns = ['子聖', '甲子生'];
    final normalizedColumns = rawColumns
        .map((column) => column.replaceAll(RegExp(r'\s+'), ''))
        .toList();
    expect(normalizedColumns.any((column) => column.contains(reference)), isFalse);
    expect(normalizedColumns.join().contains(reference), isTrue);
  });

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
  test('중복된 정답 이름은 횟수로 식별하며 누락 이름은 제외한다', () {
    final counts = _referenceNameCounts([
      {'nameHanja': '昃'},
      {'nameHanja': '昃'},
      {'nameHanja': '格'},
      {'nameHanja': ''},
      <String, String>{},
    ]);
    expect(counts['昃'], 2);
    expect(counts['格'], 1);
    expect(counts.containsKey(''), isFalse);
    expect(counts.length, 2);
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
    final rawColumns = (data['results'] as List).expand<String>((result) {
      final columns = result['columns'] as List?;
      if (columns != null) {
        return columns.map((column) => column['text'] as String);
      }
      return [result['text'] as String];
    }).map((column) => column.replaceAll(RegExp(r'\s+'), '')).toList();
    final names = people.expand((p) => [p.nameHanja,
      if (p.gender == 'F') p.spouseHanja ?? '']).where((n) => n.isNotEmpty).toSet();
    // 열 경계에서 서로 다른 문자열이 합쳐져 가짜 이름이 생기지 않도록 한다.
    final rawNamesPresent = reference
        .where((name) => rawColumns.any((column) => column.contains(name))).toList();
    final rawNamesMissing = reference
        .where((name) => !rawColumns.any((column) => column.contains(name))).toList();
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
    // 선택적으로 제공된 인물별 정답과 대조한다. 정답이 없는 필드는
    // 평가 대상에서 제외하며, 이름이 중복되면 임의로 인물을 연결하지 않는다.
    // JSON: "referencePersons": [{"nameHanja":"昃","ja":"良甫",...}]
    final referencePersons = (data['referencePersons'] as List?) ?? const [];
    if (referencePersons.isNotEmpty) {
      const fields = <String, String>{
        'nameHanja': 'nameHanja',
        'ja': 'ja',
        'ho': 'ho',
        'spouseHanja': 'spouseHanja',
        'spouseFather': 'spouseFather',
        'birthDateLunar': 'birthDateLunar',
        'deathDateLunar': 'deathDateLunar',
        'spouseBirth': 'spouseBirth',
        'spouseDeath': 'spouseDeath',
      };
      final byName = <String, List<dynamic>>{};
      for (final person in people) {
        byName.putIfAbsent(person.nameHanja, () => []).add(person);
      }
      final fieldScores = <String, Map<String, int>>{};
      final unresolved = <String>[];
      final referenceNameCounts = _referenceNameCounts(referencePersons);
      for (final field in fields.keys) {
        fieldScores[field] = {'checked': 0, 'matched': 0, 'mismatched': 0};
      }
      for (final item in referencePersons) {
        final expected = Map<String, dynamic>.from(item as Map);
        final name = expected['nameHanja']?.toString() ?? '';
        final matches = byName[name] ?? const [];
        if (name.isEmpty || matches.length != 1 ||
            referenceNameCounts[name] != 1) {
          final label = name.isEmpty ? '(정답 이름 없음)' : name;
          if (!unresolved.contains(label)) unresolved.add(label);
          continue;
        }
        final actual = matches.single.toMap();
        for (final field in fields.keys) {
          if (!expected.containsKey(field)) continue;
          final target = expected[field]?.toString().trim() ?? '';
          final found = actual[_fieldColumn(field)]?.toString().trim() ?? '';
          final score = fieldScores[field]!;
          score['checked'] = score['checked']! + 1;
          final key = target == found ? 'matched' : 'mismatched';
          score[key] = score[key]! + 1;
        }
      }
      report['referenceFieldEvaluation'] = {
        'fieldScores': fieldScores,
        'unresolvedNames': unresolved,
        'note': 'Only explicitly supplied ground truth is evaluated. '
            'Duplicate or missing names are excluded from field comparisons.',
      };
    }
    File('$path.evaluation.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    expect(names.contains('四'), isFalse);
    expect(names.contains('甲子十'), isFalse);
    expect(people.every((p) => p.fatherId == null && p.motherId == null), isTrue);
  });
}

String _fieldColumn(String field) {
  const columns = <String, String>{
    'nameHanja': 'name_hanja',
    'ja': 'ja',
    'ho': 'ho',
    'spouseHanja': 'spouse_hanja',
    'spouseFather': 'spouse_father',
    'birthDateLunar': 'birth_date_lunar',
    'deathDateLunar': 'death_date_lunar',
    'spouseBirth': 'spouse_birth',
    'spouseDeath': 'spouse_death',
  };
  return columns[field]!;
}


Map<String, int> _referenceNameCounts(List<dynamic> referencePersons) {
  final counts = <String, int>{};
  for (final item in referencePersons) {
    final name = (item as Map)['nameHanja']?.toString().trim() ?? '';
    if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
  }
  return counts;
}
