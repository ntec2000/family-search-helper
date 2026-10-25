/// 열의 자녀 표지는 경계로 남기고, 이어지는 주석 열은 위→아래/우→좌로 잇는다.
/// 오독된 표지나 누락된 인명을 추측해서 복원하지 않는다.
String assembleOcrColumns(List<String> columns) {
  final output = StringBuffer();
  for (final column in columns) {
    final text = column.trim();
    if (text.isEmpty) continue;
    if (RegExp(r'^[子女男]').hasMatch(text)) {
      output.write('\n${text.replaceAll(RegExp(r'\s+'), ' ')} ');
    } else {
      output.write(text.replaceAll(RegExp(r'\s+'), ''));
    }
  }
  return output.toString().trim();
}
