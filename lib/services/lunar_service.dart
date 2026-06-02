import 'package:lunar/lunar.dart';

/// 만세력(음력↔양력 + 60갑자) 변환 서비스
class LunarService {
  /// 양력 → 음력 정보
  /// returns: { 'lunar_date': '己巳年九月初七日', 'ganzhi_year': '己巳', ... }
  static Map<String, String> solarToLunar(DateTime solar) {
    final s = Solar.fromYmd(solar.year, solar.month, solar.day);
    final l = s.getLunar();
    return {
      'lunar_year': l.getYearInChinese(),
      'lunar_month': l.getMonthInChinese(),
      'lunar_day': l.getDayInChinese(),
      'ganzhi_year': l.getYearInGanZhi(),
      'ganzhi_month': l.getMonthInGanZhi(),
      'ganzhi_day': l.getDayInGanZhi(),
      'animal': l.getYearShengXiao(),
      'lunar_text':
          '${l.getYearInGanZhi()}年 ${l.getMonthInChinese()}月 ${l.getDayInChinese()}日',
    };
  }

  /// 음력 → 양력
  static DateTime lunarToSolar(int year, int month, int day,
      {bool isLeap = false}) {
    final l = Lunar.fromYmd(year, isLeap ? -month : month, day);
    final s = l.getSolar();
    return DateTime(s.getYear(), s.getMonth(), s.getDay());
  }

  /// 干支(예: "乙卯")로부터 가능한 양력 연도 목록 추정
  /// 60갑자는 60년 주기. 시작연도 ~ 현재까지 일치하는 연도들 반환.
  static List<int> estimateYearsFromGanzhi(String ganzhi,
      {int from = 1700, int to = 2100}) {
    final results = <int>[];
    for (int y = from; y <= to; y++) {
      final l = Solar.fromYmd(y, 6, 15).getLunar();
      if (l.getYearInGanZhi() == ganzhi) results.add(y);
    }
    return results;
  }

  /// 천간(天干) 10
  static const tianGan = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];

  /// 지지(地支) 12
  static const diZhi = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];

  /// 천간 한글 음 (甲=갑 …)
  static const tianGanKor = ['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];

  /// 지지 한글 음 (子=자 …)
  static const diZhiKor = ['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];

  static bool isValidGanzhi(String s) {
    if (s.length != 2) return false;
    return tianGan.contains(s[0]) && diZhi.contains(s[1]);
  }

  /// 한글/한자 혼용 간지 입력을 표준 干支(한자 2자)로 정규화.
  /// 예) "갑오년" → "甲午", "갑오" → "甲午", "甲午年" → "甲午", "甲午" → "甲午"
  /// 인식 불가 시 null.
  static String? normalizeGanzhi(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    // 뒤따르는 '년' / '年' / 공백 제거
    s = s.replaceAll(RegExp(r'[년年\s]'), '');
    if (s.length != 2) return null;
    final g0 = s[0];
    final j0 = s[1];

    // 이미 한자
    final ganHanja = tianGan.contains(g0)
        ? g0
        : (tianGanKor.contains(g0) ? tianGan[tianGanKor.indexOf(g0)] : null);
    final jiHanja = diZhi.contains(j0)
        ? j0
        : (diZhiKor.contains(j0) ? diZhi[diZhiKor.indexOf(j0)] : null);

    if (ganHanja == null || jiHanja == null) return null;
    final gz = '$ganHanja$jiHanja';
    // 60갑자 유효성: 천간·지지 인덱스 패리티가 맞아야 실제 간지
    final gi = tianGan.indexOf(ganHanja);
    final ji = diZhi.indexOf(jiHanja);
    if ((gi % 2) != (ji % 2)) return null; // 불가능한 조합 (예: 甲丑)
    return gz;
  }

  /// 한글/한자 혼용 간지 입력 → 추정 양력 연도 목록 (#8)
  static List<int> estimateYearsFromInput(String input,
      {int from = 1700, int to = 2100}) {
    final gz = normalizeGanzhi(input);
    if (gz == null) return const [];
    return estimateYearsFromGanzhi(gz, from: from, to: to);
  }
}
