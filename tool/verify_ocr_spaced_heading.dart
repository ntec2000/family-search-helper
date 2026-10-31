import '../lib/services/ocr_column_text.dart';

void main() {
  var checks = 0;
  for (final orientation in ['子坐午向', '子 坐午向', '子\t坐午向']) {
    final columns = ['子格', '墓山', '$orientation 配原州邊氏 父國聖', '子核'];
    final before = List<String>.of(columns);
    final entries = assembleOcrEntries(columns);
    void check(bool condition, String message) {
      if (!condition) throw StateError('$orientation: $message; $entries');
      checks++;
    }
    check(entries.length == 2, '좌향을 별도 인물로 나누면 안 됩니다');
    check(entries.first.contains('配原州邊氏父國聖'), '배우자 주석은 앞 인물에 남아야 합니다');
    check(entries.last == '子核', '다음 인물에게 주석이 넘어가면 안 됩니다');
    check(columns.join('|') == before.join('|'), '입력 원문을 변경하면 안 됩니다');
  }
  print('PASS: $checks checks');
}
