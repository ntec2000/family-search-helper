/// OCR 결과를 자동 저장하지 않고 검토용 이름 후보로 분류합니다.
enum GenealogyCandidateType { name, spouse, annotation, review }

class GenealogyCandidate {
  final String source;
  final String label;
  final GenealogyCandidateType type;
  final String explanation;
  const GenealogyCandidate(this.source, this.label, this.type, this.explanation);
}

class GenealogyNameClassifier {
  static const annotations = <String>{
    '子', '配', '父', '生父', '祖', '曾祖', '外祖', '字', '號',
    '生', '卒', '忌', '墓', '初名', '一名', '兒名', '異名', '出系', '出后', '出繼', '系子', '繼子', '世', '同知', '判官',
  };

  static GenealogyCandidate classify(String input, {String? fatherSurname}) {
    final value = input.trim();
    if (annotations.contains(value) || RegExp(r'^(?:初名|一名|兒名|異名)').hasMatch(value) || RegExp(r'^生\s*父').hasMatch(value) || RegExp(r'^(?:出\s*[系后繼]|[系繼]\s*子)').hasMatch(value) ||
        value.startsWith('墓') || value.startsWith('字')) {
      return GenealogyCandidate(value, value, GenealogyCandidateType.annotation,
          '족보 기록 표지이며 사람 이름이 아닙니다.');
    }
    if (value == '女') {
      final surname = (fatherSurname ?? '').trim();
      return GenealogyCandidate(value,
          surname.isEmpty ? '이름 미상' : '$surname씨',
          GenealogyCandidateType.name, '딸의 개인 이름이 기록되지 않았습니다.');
    }
    if (value.startsWith('配') && value.endsWith('氏')) {
      return GenealogyCandidate(value, value.substring(1).trim(),
          GenealogyCandidateType.spouse, '배우자의 본관과 성씨입니다.');
    }
    if (value.startsWith('子 ')) {
      return GenealogyCandidate(value, value.substring(2).trim(),
          GenealogyCandidateType.name, '子 뒤에 기재된 아들 이름 후보입니다.');
    }
    return GenealogyCandidate(value, value, GenealogyCandidateType.review,
        '문맥 확인 전에는 인물로 자동 확정하지 않습니다.');
  }
}
