/// 열의 자녀 표지는 경계로 남기고, 이어지는 주석 열은 위→아래/우→좌로 잇는다.
/// 오독된 표지나 누락된 인명을 추측해서 복원하지 않는다.
String assembleOcrColumns(List<String> columns) {
  return assembleOcrEntries(columns).join('\n');
}

/// 큰 글씨 표제는 판독에 실패해도 앞 인물의 주석과 합치지 않는다.
List<String> assembleOcrEntries(List<String> columns,
    {List<bool>? headings, List<bool>? startsLow}) {
  if ((headings != null && headings.length != columns.length) ||
      (startsLow != null && startsLow.length != columns.length)) {
    throw ArgumentError('열과 표제 경계 수가 다릅니다.');
  }
  final entries = <String>[];
  final output = StringBuffer();
  for (var i = 0; i < columns.length; i++) {
    final text = joinFragmentedHeadingLines(columns[i]);
    // 명시적인 표제는 OCR이 인명을 놓쳤어도 경계를 유지한다.
    // 빈 열은 새로운 인물 경계를 만들지 않는다.
    if (text.isEmpty) {
      if (headings?[i] == true && output.isNotEmpty) {
        entries.add(output.toString().trim());
        output.clear();
      }
      continue;
    }
    // 子坐午向 같은 묘지 표기와 干支의 子를 이름 표제로 보지 않는다.
    final adoptedHeading = RegExp(r'^[系繼]\s*子\s*(?![生卒字配墓忌父祖])[一-鿿]').hasMatch(text);
    final personMarker = adoptedHeading || RegExp(r'^[子女男]\s*(?!坐|向|孫|女|男|配|字|號|墓|忌|生|卒|父|祖)[一-鿿]').hasMatch(text);
    // Keep low person-like text in rawColumns only. Feeding it back into
    // the parser could attach its facts to either the wrong person or a new one.
    if (startsLow?[i] == true && personMarker) continue;
    if (headings?[i] == true || personMarker) {
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

/// Join only line-separated glyphs within one OCR heading column.
/// Plain spaces and adjacent columns are not evidence of one personal name.
/// Original OCR remains in OcrResult.alternatives before assembly.
String joinFragmentedHeadingLines(String raw) {
  final lines = raw.trim().split(RegExp(r'\r?\n')).map((line) => line.trim())
      .where((line) => line.isNotEmpty).toList();
  if (lines.length < 2) return raw.trim();
  final head = RegExp(r'^([子女男])\s*([一-鿿]{0,4})$').firstMatch(lines.first);
  if (head == null) return raw.trim();
  const structural = '子女男字號墓配生卒父祖系繼坐向忌出娶贈';
  var name = head.group(2)!;
  if (name.runes.any((r) => structural.contains(String.fromCharCode(r)))) {
    return raw.trim();
  }
  final limit = head.group(1) == '女' ? 4 : 3;
  var end = 1;
  while (end < lines.length && RegExp(r'^[一-鿿]$').hasMatch(lines[end])) {
    final glyph = lines[end];
    if (structural.contains(glyph)) break;
    // A split sexagenary birth/death date starts a field, not another name.
    if (end + 2 < lines.length &&
        RegExp(r'^[甲乙丙丁戊己庚辛壬癸]$').hasMatch(glyph) &&
        RegExp(r'^[子丑寅卯辰巳午未申酉戌亥]$').hasMatch(lines[end + 1]) &&
        RegExp(r'^[年生卒]').hasMatch(lines[end + 2])) break;
    if (name.length >= limit) return raw.trim();
    name += glyph;
    end++;
  }
  if (end == 1 || name.isEmpty) return raw.trim();
  if (end < lines.length) {
    final next = lines[end];
    // Require an explicit field or printed Korean reading after the heading.
    // Another person marker may belong to a different column: do not merge.
    if (!RegExp(r'^(?:[가-힣]|[字號墓配生卒父祖忌出娶贈]|[甲乙丙丁戊己庚辛壬癸])')
        .hasMatch(next)) return raw.trim();
  }
  return ['${head.group(1)}$name', ...lines.skip(end)].join('\n');
}
