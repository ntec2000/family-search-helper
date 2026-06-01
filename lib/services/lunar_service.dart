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

  static bool isValidGanzhi(String s) {
    if (s.length != 2) return false;
    return tianGan.contains(s[0]) && diZhi.contains(s[1]);
  }
}
