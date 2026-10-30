/// 간지 연도의 읽기만 표시한다. 연도·음양력 변환은 하지 않는다.
class GanzhiYearLabel {
  static const _stems = '甲乙丙丁戊己庚辛壬癸';
  static const _branches = '子丑寅卯辰巳午未申酉戌亥';
  static const _stemReads = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
  static const _branchReads = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];

  /// 생몰 원문의 맨 앞에 명시된 간지만 읽는다. 기일·월일은 추측하지 않는다.
  static String? fromDate(String? raw) {
    final text = (raw ?? '').trim();
    if (text.length < 2) return null;
    final stem = _stems.indexOf(text[0]);
    final branch = _branches.indexOf(text[1]);
    if (stem < 0 || branch < 0 || stem % 2 != branch % 2) return null;
    return '${_stemReads[stem]}${_branchReads[branch]}년';
  }
}
