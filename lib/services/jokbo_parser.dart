import 'package:uuid/uuid.dart';
import '../models/person.dart';
import 'hanja_dict.dart';
import 'lunar_service.dart';
import 'genealogy.dart';

/// 족보 OCR 텍스트 파서.
/// 표준 족보 표기 규칙:
///   子○○ / 女○○        : 인물(성별 + 이름)
///   字○○                : 자(字)
///   號○○                : 호
///   配○○郡 ○○氏 父 ○○○: 배우자 정보
///   娶○○                : 결혼(취)
///   居/籍/生於 ○○        : 출생/거주지
///   墓○○郡 ○○面 ○○山   : 묘 위치
///   ○○坐○○向            : 좌향
///   干支○月○日 生        : 생일 (음력)
///   干支○月○日 卒        : 사망일 (음력)
///   婿/壻 ○○○           : 사위
///   査頓/姻 ○○○         : 사돈
///   ○○世                : 세
class JokboParser {
  static final _uuid = const Uuid();

  static const _gan = '甲乙丙丁戊己庚辛壬癸';
  static const _ji = '子丑寅卯辰巳午未申酉戌亥';

  /// OCR 인식 텍스트(세로쓰기 → 정렬된 평문)를 받아 인물 카드 목록 추출
  static List<Person> parse(String rawText, {String? sourceImagePath}) {
    final normalized = _normalize(rawText);
    final entries = _splitByPerson(normalized);

    final persons = <Person>[];
    for (final block in entries) {
      final p = _parsePersonBlock(block, sourceImagePath: sourceImagePath);
      if (p != null) persons.add(p);
    }
    // v2.2 — 세(世) 기반 출생연도 추정 보완
    Genealogy.fillGenerationEstimates(persons);
    return persons;
  }

  static String _normalize(String raw) {
    final lines = raw.split(RegExp(r'[\r\n]+'));
    final buf = StringBuffer();
    for (var l in lines) {
      l = l.trim();
      if (l.isEmpty) continue;
      buf.write(l);
      buf.write(' ');
    }
    var s = buf.toString();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  static List<String> _splitByPerson(String text) {
    final pattern = RegExp(r'(?=[子女])');
    final parts = text.split(pattern).where((s) => s.trim().isNotEmpty).toList();
    return parts.where((p) {
      final t = p.trim();
      return t.startsWith('子') || t.startsWith('女');
    }).toList();
  }

  static Person? _parsePersonBlock(String block, {String? sourceImagePath}) {
    final t = block.trim();
    if (t.length < 2) return null;

    final dict = HanjaDict.instance;
    final person = Person(
      id: _uuid.v4(),
      sourceImagePath: sourceImagePath,
      rawText: t,
    );

    // 성별 + 이름: 子○ or 女○ 다음의 한자 1~3자
    final nameMatch = RegExp(r'^([子女])([一-鿿]{1,3})').firstMatch(t);
    if (nameMatch == null) return null;
    person.gender = nameMatch.group(1) == '子' ? 'M' : 'F';
    person.nameHanja = nameMatch.group(2)!;
    person.nameHangul = dict.toHangul(person.nameHanja);

    // 字 (자)
    final ja = RegExp(r'字([一-鿿]{1,3})').firstMatch(t);
    if (ja != null) person.ja = ja.group(1);

    // 號 (호)
    final ho = RegExp(r'號([一-鿿]{1,3})').firstMatch(t);
    if (ho != null) person.ho = ho.group(1);

    // 諡號 (시호)
    final siho = RegExp(r'諡號?([一-鿿]{1,3})').firstMatch(t);
    if (siho != null) person.siho = siho.group(1);

    // 世 (세대 번호) — v2.2 세대 기반 연도 추정용
    final segaM = RegExp(r'([0-9]+|[一二三四五六七八九十百]+)\s*世').firstMatch(t);
    if (segaM != null) {
      final n = _segaToInt(segaM.group(1)!);
      if (n != null) person.sega = n;
    }

    // 生 (출생) - 干支 + 월일 + 生
    final birth = RegExp(
            '([$_gan][$_ji])([一-鿿零一二三四五六七八九十百○]{1,3}月[一-鿿零一二三四五六七八九十○]{1,3}日)\\s*生')
        .firstMatch(t);
    if (birth != null) {
      person.birthDateLunar = '${birth.group(1)}年 ${birth.group(2)} 生';
      final candidates = LunarService.estimateYearsFromGanzhi(birth.group(1)!);
      if (candidates.isNotEmpty) {
        final mostRecent =
            candidates.where((y) => y <= DateTime.now().year).lastOrNull;
        if (mostRecent != null) {
          person.birthDateSolar = '$mostRecent (干支 추정)';
        }
      }
    }

    // 卒 (사망)
    final death = RegExp(
            '([$_gan][$_ji])([一-鿿零一二三四五六七八九十百○]{1,3}月[一-鿿零一二三四五六七八九十○]{1,3}日)\\s*卒')
        .firstMatch(t);
    if (death != null) {
      person.deathDateLunar = '${death.group(1)}年 ${death.group(2)} 卒';
      final candidates = LunarService.estimateYearsFromGanzhi(death.group(1)!);
      if (candidates.isNotEmpty && person.birthDateSolar != null) {
        final birthYearStr = RegExp(r'(\d{4})').firstMatch(person.birthDateSolar!);
        if (birthYearStr != null) {
          final by = int.parse(birthYearStr.group(1)!);
          final dy = candidates.firstWhere(
              (y) => y > by && y <= DateTime.now().year,
              orElse: () => -1);
          if (dy > 0) person.deathDateSolar = '$dy (干支 추정)';
        }
      }
    }

    // 居/籍/生於/生于 (출생·거주지) #16
    final place = RegExp(
            r'(?:居|籍|生於|生于|貫鄕|本生)\s*([一-鿿]{1,4}[道郡州府縣面里洞]?[一-鿿]{0,4}[面里洞山]?)')
        .firstMatch(t);
    if (place != null) {
      final v = place.group(1);
      if (v != null && v.isNotEmpty) person.birthPlace = v;
    }

    // 娶 (결혼) — 干支年 #16
    final marry = RegExp('娶\\s*([$_gan][$_ji])?年?').firstMatch(t);
    if (marry != null && marry.group(1) != null) {
      person.marriageDate = '${marry.group(1)}年 (婚)';
    }

    // 配 (배우자)  配○○郡 ○○氏 父 ○○○
    final pae = RegExp(
            r'配\s*([一-鿿]{1,4}[郡州府])?\s*([一-鿿]{1,3}氏)\s*(?:父\s*([一-鿿]{1,4}))?')
        .firstMatch(t);
    if (pae != null) {
      person.spouseBongwan = pae.group(1);
      person.spouseHanja = pae.group(2);
      person.spouseHangul = pae.group(2) != null
          ? dict.toHangul(pae.group(2)!)
          : null;
      person.spouseFather = pae.group(3);
    }

    // 墓 (묘 위치)
    final myo = RegExp(
            r'墓\s*([一-鿿]{1,4}[郡州府])?\s*([一-鿿]{0,3}[面里洞])?\s*([一-鿿]{0,4}[山谷洞])?')
        .firstMatch(t);
    if (myo != null) {
      final parts = [myo.group(1), myo.group(2), myo.group(3)]
          .where((s) => s != null && s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) person.burialPlace = parts.join(' ');
    }

    // 좌향: ○坐○向
    final jwa = RegExp(r'([一-鿿])坐([一-鿿])向').firstMatch(t);
    if (jwa != null) {
      person.burialOrientation = '${jwa.group(1)}坐${jwa.group(2)}向';
    }

    // 사위 (婿/壻) #16 — 婿 다음 이름 한자
    final sonsInLaw = RegExp(r'[婿壻]\s*([一-鿿]{2,4})')
        .allMatches(t)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
    if (sonsInLaw.isNotEmpty) {
      person.sonsInLawNote = sonsInLaw
          .map((n) => '$n (${dict.toHangul(n)})')
          .join(', ');
    }

    // 사돈 (査頓/姻/親家) #16
    final inLaws = RegExp(r'(?:査頓|姻|親家)\s*([一-鿿]{2,5})')
        .allMatches(t)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
    if (inLaws.isNotEmpty) {
      person.inLawsNote = inLaws
          .map((n) => '$n (${dict.toHangul(n)})')
          .join(', ');
    }

    // 사돈부인 (査頓婦/姻家婦) v2.2
    final inLawWives = RegExp(r'(?:査頓婦|姻家婦|사돈부인)\s*([一-鿿]{2,5})')
        .allMatches(t)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
    if (inLawWives.isNotEmpty) {
      person.inLawsSpouseNote =
          inLawWives.map((n) => '$n (${dict.toHangul(n)})').join(', ');
    }

    // 자녀 (子/女 + 이름) — 본인 표기 이후 등장하는 자녀 표기 #16
    // 첫 마커(본인)는 제외하고 이후 子/女 표기를 자녀로 간주.
    final childMatches = RegExp(r'[子女]([一-鿿]{2,3})').allMatches(t).toList();
    if (childMatches.length > 1) {
      final kids = childMatches
          .skip(1)
          .map((m) => '${m.group(1)} (${dict.toHangul(m.group(1)!)})')
          .toSet()
          .toList();
      if (kids.isNotEmpty) person.childrenNote = kids.join(', ');
    }

    // v2.2 — 성(姓) 자동 분리 (자녀 상속 표기용)
    final np = Genealogy.split(
        hanja: person.nameHanja, hangul: person.nameHangul);
    if (np.surnameHanja.isNotEmpty) person.surnameHanja = np.surnameHanja;
    if (np.surnameHangul.isNotEmpty) person.surnameHangul = np.surnameHangul;

    return person;
  }

  /// 한자/아라비아 숫자 세(世) → 정수.
  static int? _segaToInt(String s) {
    final a = int.tryParse(s);
    if (a != null) return a;
    const m = {'一':1,'二':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9};
    if (s == '十') return 10;
    if (s.length == 1) return m[s];
    if (s.length == 2 && s[0] == '十') return 10 + (m[s[1]] ?? 0);
    if (s.length == 2 && s[1] == '十') return (m[s[0]] ?? 0) * 10;
    if (s.length == 3 && s[1] == '十') return (m[s[0]] ?? 0) * 10 + (m[s[2]] ?? 0);
    return null;
  }
}

extension _FirstLastOrNull<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
