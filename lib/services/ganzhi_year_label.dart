/// 간지 읽기와 검토된 추정 서기를 표시한다. 새로운 연도를 확정하지 않는다.
class GanzhiYearLabel {
  static const _stems = '甲乙丙丁戊己庚辛壬癸';
  static const _branches = '子丑寅卯辰巳午未申酉戌亥';
  static const _stemReads = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
  static const _branchReads = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];

  /// 검토자가 저장한 서기 추정값의 표시만 바꾼다. 원문이나 저장값은 수정하지 않는다.
  static String displayDate(String? solar, String? lunar, {String fallback = ''}) {
    final value = (solar ?? '').trim();
    if (value.isNotEmpty) {
      final approximate = RegExp(r'^about\s+([0-9]{1,4})$', caseSensitive: false)
          .firstMatch(value);
      if (approximate != null) {
        final year = approximate.group(1)!;
        return '약 $year년 (about $year)';
      }
      return value;
    }
    final original = (lunar ?? '').trim();
    return original.isEmpty ? fallback : original;
  }

  static String? reference(String? solar, String? lunar) {
    final label = fromDate(lunar);
    if (label == null) return null;
    final pending = (solar ?? '').trim().isEmpty
        ? ' · 추정 서기 미선택 · 기준 연도 검토 필요' : '';
    return '${lunar!.trim()} ($label)$pending';
  }

  /// 생몰 원문의 맨 앞에 명시된 간지만 읽는다. 기일·월일은 추측하지 않는다.
  static String? fromDate(String? raw) {
    final text = (raw ?? '').trim();
    if (!RegExp(r'^[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥](?=\s*(?:年|生|卒|[正冬臘閏零一二三四五六七八九十百○0-9]+月|$))').hasMatch(text)) {
      return null;
    }
    final stem = _stems.indexOf(text[0]);
    final branch = _branches.indexOf(text[1]);
    if (stem < 0 || branch < 0 || stem % 2 != branch % 2) return null;
    return '${_stemReads[stem]}${_branchReads[branch]}년';
  }
}
