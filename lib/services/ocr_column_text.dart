/// 열의 자녀 표지는 경계로 남기고, 이어지는 주석 열은 위→아래/우→좌로 잇는다.
/// 오독된 표지나 누락된 인명을 추측해서 복원하지 않는다.
String assembleOcrColumns(List<String> columns) {
  return assembleOcrEntries(columns).join('\n');
}

/// 큰 글씨 표제는 판독에 실패해도 앞 인물의 주석과 합치지 않는다.
List<String> assembleOcrEntries(List<String> columns, {List<bool>? headings}) {
  if (headings != null && headings.length != columns.length) {
    throw ArgumentError('열과 표제 경계 수가 다릅니다.');
  }
  final entries = <String>[];
  final output = StringBuffer();
  for (var i = 0; i < columns.length; i++) {
    final text = columns[i].trim();
    if (headings?[i] == true || RegExp(r'^[子女男]').hasMatch(text)) {
      if (output.isNotEmpty) entries.add(output.toString().trim());
      output.clear();
      output.write('${text.replaceAll(RegExp(r'\s+'), ' ')} ');
    } else {
      output.write(text.replaceAll(RegExp(r'\s+'), ''));
    }
  }
  if (output.toString().trim().isNotEmpty) entries.add(output.toString().trim());
  return entries;
}
