import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/genealogy_name_classifier.dart';

void main() {
  test('metadata is not a person', () {
    for (final text in ['父', '生父', '生父鈴', '初名元吉', '異名', '祖', '墓', '出系 顯龍后', '出后', '出繼', '系子', '繼子', '字君平']) {
      expect(GenealogyNameClassifier.classify(text).type,
          GenealogyCandidateType.annotation);
    }
  });

  test('son name follows the child marker', () {
    final result = GenealogyNameClassifier.classify('子 格');
    expect(result.type, GenealogyCandidateType.name);
    expect(result.label, '格');
  });

  test('unnamed daughter retains inferred surname flag in explanation', () {
    final result = GenealogyNameClassifier.classify('女', fatherSurname: '李');
    expect(result.label, '李씨');
    expect(result.explanation, contains('개인 이름'));
  });

  test('spouse clan label is not a personal given name', () {
    final result = GenealogyNameClassifier.classify('配 原州邊氏');
    expect(result.type, GenealogyCandidateType.spouse);
    expect(result.label, '原州邊氏');
  });

  test('isolated hanja must be reviewed', () {
    expect(GenealogyNameClassifier.classify('聖甲').type,
        GenealogyCandidateType.review);
  });
}
