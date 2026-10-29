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
  test('필드 불일치는 인물·항목·정답·실제 값을 기록한다', () {
    final mismatches = <Map<String, String>>[];
    _recordFieldMismatch(
      mismatches,
      name: '昃',
      field: 'ja',
      expected: '良甫',
      actual: '良浦',
    );
    _recordFieldMismatch(
      mismatches,
      name: '昃',
      field: 'ho',
      expected: '竹軒',
      actual: '竹軒',
    );
    expect(mismatches, [
      {
        'nameHanja': '昃',
        'field': 'ja',
        'expected': '良甫',
        'actual': '良浦',
      },
    ]);
  });

  test('정답에 없는 인물 후보와 누락 인물은 별도 집합으로 분리한다', () {
    const reference = {'昃', '格', '核'};
    const parsed = {'昃', '核', '誤'};
    expect(reference.difference(parsed), {'格'});
    expect(parsed.difference(reference), {'誤'});
  });

  test('OCR 정답의 이름 앞뒤 공백은 같은 인물로 비교한다', () {
    final names = _referenceNameCounts([
      {'nameHanja': ' 昃 '},
      {'nameHanja': '昃'},
      {'nameHanja': ' 格 '},
    ]);
    expect(names['昃'], 2);
    expect(names['格'], 1);
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

  test('실제 정답 인물이 있으면 고정된 224쪽 이름 목록을 사용하지 않는다', () {
    expect(_evaluationReferenceNames({
      'referencePersons': [
        {'nameHanja': '甲'},
        {'nameHanja': ' 乙 '},
        {'nameHanja': '甲'},
        {'nameHanja': ''},
      ],
    }), ['甲', '乙']);
    expect(_evaluationReferenceNames({'referencePersons': []}), isEmpty);
    expect(_evaluationReferenceNames({'results': []}), isEmpty);
    expect(_evaluationReferenceNames({'referencePersons': [
      {'nameHanja': ''},
    ]}), isEmpty);
  });

  test('정답이 없는 OCR 평가는 커버리지를 산출하지 않는다', () {
    final reference = _evaluationReferenceNames({'results': [
      {'text': '子昃字良甫'},
    ]});
    expect(reference, isEmpty);
    expect(_referenceCoverage(0, reference.length), isNull);
    expect(_referenceCoverage(1, reference.length), isNull);
    expect(_referenceCoverage(1, 2), 0.5);
  });

  test('정답 유무에 따라 OCR 평가 상태와 사유를 명시한다', () {
    expect(_referenceEvaluationStatus(const []), {
      'evaluationStatus': 'unavailable',
      'evaluationReason': 'No reference persons supplied',
      'verifiedReferenceNameCount': 0,
    });
    expect(_referenceEvaluationStatus(['昃', '格']), {
      'evaluationStatus': 'available',
      'evaluationReason': null,
      'verifiedReferenceNameCount': 2,
    });
  });

  test('필드 일치율은 실제 비교한 항목만 분모로 사용한다', () {
    expect(_fieldMatchRate({'checked': 4, 'matched': 3, 'mismatched': 1}), 0.75);
    expect(_fieldMatchRate({'checked': 0, 'matched': 0, 'mismatched': 0}), isNull);
  });

  test('동명이인과 누락 인물의 평가 제외 사유를 구분한다', () {
    expect(_unresolvedReason('', 0, 0), 'missing_reference_name');
    expect(_unresolvedReason('昃', 2, 1), 'duplicate_reference_name');
    expect(_unresolvedReason('昃', 1, 2), 'duplicate_parsed_name');
    expect(_unresolvedReason('昃', 1, 0), 'parsed_name_not_found');
    expect(_unresolvedReason('昃', 1, 1), isNull);
  });

  test('OCR 평가 입력의 잘못된 열과 정답 필드 형식을 거부한다', () {
    expect(
      () => _validateOcrEvaluationInput({'results': '잘못된 자료'}),
      throwsFormatException,
    );
    expect(
      () => _validateOcrEvaluationInput({
        'results': [{'columns': [{'text': 123}]}],
      }),
      throwsFormatException,
    );
    expect(
      () => _validateOcrEvaluationInput({
        'results': [{'text': '子昃'}],
        'referencePersons': [{'nameHanja': '昃', 'ja': 123}],
      }),
      throwsFormatException,
    );
    expect(
      () => _validateOcrEvaluationInput({
        'results': [{'text': '子昃'}],
        'referencePersons': [{'nameHanja': '昃', 'ja': '良甫'}],
      }),
      returnsNormally,
    );
  });

  if (path.isEmpty) return;
  test('실제 OCR과 정답 전사의 인식·파싱 결과를 따로 기록한다', () async {
    await HanjaDict.instance.load();
    final data = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    _validateOcrEvaluationInput(data);
    final regions = (data['results'] as List).expand((r) {
      if (r['columns'] == null) return [r['text'] as String];
      final columns = r['columns'] as List;
      return assembleOcrEntries(columns.map((c) => c['text'] as String).toList(),
        headings: columns.any((c) => c.containsKey('heading'))
          ? columns.map((c) => c['heading'] == true).toList() : null);
    }).toList();
    final people = JokboParser.parseRegions(regions);
    // 실제 정답이 제공되면 해당 페이지의 정답 이름을 우선 사용한다.
    // 정답이 없으면 커버리지 값은 null이며, 특정 페이지 이름을 대입하지 않는다.
    final reference = _evaluationReferenceNames(data);
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
      ..._referenceEvaluationStatus(reference),
      'rawNamesPresent': rawNamesPresent,
      'rawNamesMissing': rawNamesMissing,
      'parsedNamesCorrect': parsedNamesCorrect,
      'parsedNamesMissing': parsedNamesMissing,
      'parsedOtherCandidates': parsedOtherCandidates,
      'rawReferenceNameCoverage': _referenceCoverage(rawNamesPresent.length, reference.length),
      'parsedReferenceNameCoverage': reference.isEmpty ? null : _referenceCoverage(parsedNamesCorrect.length, reference.length),
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
        byName.putIfAbsent(person.nameHanja.trim(), () => []).add(person);
      }
      final fieldScores = <String, Map<String, int>>{};
      final fieldMismatches = <Map<String, String>>[];
      final unresolved = <String>[];
      final unresolvedDetails = <Map<String, String>>[];
      final referenceNameCounts = _referenceNameCounts(referencePersons);
      for (final field in fields.keys) {
        fieldScores[field] = {'checked': 0, 'matched': 0, 'mismatched': 0};
      }
      for (final item in referencePersons) {
        final expected = Map<String, dynamic>.from(item as Map);
        final name = expected['nameHanja']?.toString().trim() ?? '';
        final matches = byName[name] ?? const [];
        final reason = _unresolvedReason(
          name, referenceNameCounts[name] ?? 0, matches.length);
        if (reason != null) {
          final label = name.isEmpty ? '(정답 이름 없음)' : name;
          if (!unresolved.contains(label)) {
            unresolved.add(label);
            unresolvedDetails.add({'nameHanja': label, 'reason': reason});
          }
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
          _recordFieldMismatch(
            fieldMismatches,
            name: name,
            field: field,
            expected: target,
            actual: found,
          );
        }
      }
      // 정답 이름의 누락과 추가 인식 후보를 별도로 보고한다.
      // 문자열 기반 후보이므로 잘못 읽힌 이름의 실제 대응 인물은 추정하지 않는다.
      final referenceNames = referenceNameCounts.keys.toSet();
      final parsedNames = byName.keys.where((name) => name.isNotEmpty).toSet();
      final missingReferenceNames = referenceNames.difference(parsedNames).toList()..sort();
      final extraParsedNames = parsedNames.difference(referenceNames).toList()..sort();
      report['referenceFieldEvaluation'] = {
        'fieldScores': fieldScores,
        'fieldMatchRates': fieldScores.map((field, score) =>
            MapEntry(field, _fieldMatchRate(score))),
        'fieldMismatches': fieldMismatches,
        'missingReferenceNames': missingReferenceNames,
        'extraParsedNames': extraParsedNames,
        'unresolvedNames': unresolved,
        'unresolvedCount': unresolved.length,
        'unresolvedDetails': unresolvedDetails,
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

void _recordFieldMismatch(
  List<Map<String, String>> mismatches, {
  required String name,
  required String field,
  required String expected,
  required String actual,
}) {
  if (expected == actual) return;
  mismatches.add({
    'nameHanja': name,
    'field': field,
    'expected': expected,
    'actual': actual,
  });
}

void _validateOcrEvaluationInput(Map<String, dynamic> data) {
  final results = data['results'];
  if (results is! List) {
    throw const FormatException('results must be a list');
  }
  for (final result in results) {
    if (result is! Map) {
      throw const FormatException('each OCR result must be an object');
    }
    if (result.containsKey('columns')) {
      final columns = result['columns'];
      if (columns is! List) {
        throw const FormatException('columns must be a list');
      }
      for (final column in columns) {
        if (column is! Map || column['text'] is! String ||
            (column.containsKey('heading') && column['heading'] is! bool)) {
          throw const FormatException('each column needs text and optional boolean heading');
        }
      }
    } else if (result['text'] is! String) {
      throw const FormatException('each OCR result needs text or columns');
    }
  }
  final references = data['referencePersons'];
  if (references == null) return;
  if (references is! List) {
    throw const FormatException('referencePersons must be a list');
  }
  const fields = [
    'nameHanja', 'ja', 'ho', 'spouseHanja', 'spouseFather',
    'birthDateLunar', 'deathDateLunar', 'spouseBirth', 'spouseDeath',
  ];
  for (final person in references) {
    if (person is! Map) {
      throw const FormatException('each reference person must be an object');
    }
    for (final field in fields) {
      if (person.containsKey(field) &&
          person[field] != null && person[field] is! String) {
        throw FormatException('$field must be a string or null');
      }
    }
  }
}

List<String> _evaluationReferenceNames(Map<String, dynamic> data) {
  // 정답이 없으면 정확도·커버리지의 분모를 추정하지 않는다.
  final references = data['referencePersons'] as List?;
  if (references == null || references.isEmpty) return const [];
  return _referenceNameCounts(references).keys.toList();
}

// 정답이 없는 경우에는 정확도처럼 보이는 숫자를 만들지 않는다.
double? _referenceCoverage(int matched, int total) {
  if (total == 0) return null;
  return matched / total;
}

Map<String, dynamic> _referenceEvaluationStatus(List<String> reference) {
  return {
    'evaluationStatus': reference.isEmpty ? 'unavailable' : 'available',
    'evaluationReason': reference.isEmpty ? 'No reference persons supplied' : null,
    'verifiedReferenceNameCount': reference.length,
  };
}

double? _fieldMatchRate(Map<String, int> score) {
  final checked = score['checked'] ?? 0;
  if (checked == 0) return null;
  return (score['matched'] ?? 0) / checked;
}

String? _unresolvedReason(String name, int referenceCount, int parsedCount) {
  if (name.isEmpty) return 'missing_reference_name';
  if (referenceCount != 1) return 'duplicate_reference_name';
  if (parsedCount == 0) return 'parsed_name_not_found';
  if (parsedCount != 1) return 'duplicate_parsed_name';
  return null;
}
