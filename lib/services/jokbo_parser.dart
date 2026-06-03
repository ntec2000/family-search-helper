import 'package:uuid/uuid.dart';
import '../models/person.dart';
import 'hanja_dict.dart';
import 'lunar_service.dart';
import 'genealogy.dart';

/// 족보 OCR 텍스트 파서.
/// 표준 족보 표기 규칙:
///   子○○ / 女○○            : 인물(성별 + 이름). 子=아들, 女=딸(→사위 표기)
///   子[二三四]○○            : 둘째/세째/네째 등 차례 표기(차례 글자는 이름에서 제외)
///   字○○                    : 자(字)
///   號○○                    : 호
///   干支(○月○日) 生/卒       : 본인 출생/사망 (월·일은 선택)
///   忌 ○月○日                : 기일(사망일, 연도 미상)
///   墓○○                     : 묘 위치
///   配○○郡 ○○氏 …父祖曾祖外祖: 배우자(아내) 정보 — 父/祖/曾祖/外祖는 모두
///                              아내 쪽(처가) 조상이다. 父=장인, 祖=장인의 아버지,
///                              曾祖=장인의 할아버지, 外祖=아내의 외할아버지.
///   女○○ ○○人               : 딸 → 남편(사위) 이름 + 사위 본관. 딸 본인은 이름이
///                              없으므로 가문 성씨를 따라 "○씨"로 표기.
class JokboParser {
  static final _uuid = const Uuid();

  static const _gan = '甲乙丙丁戊己庚辛壬癸';
  static const _ji = '子丑寅卯辰巳午未申酉戌亥';

  /// OCR 인식 텍스트(세로쓰기 → 정렬된 평문)를 받아 인물 카드 목록 추출
  static List<Person> parse(String rawText, {String? sourceImagePath}) {
    final normalized = _normalize(rawText);
    // 문서 전체에서 가문(본관) 성씨 자동 감지 — 예: "固城李氏…" → 李/이
    final clan = Genealogy.detectClanSurname(normalized);
    final entries = _splitByPerson(normalized);

    final persons = <Person>[];
    for (final block in entries) {
      final p = _parsePersonBlock(block,
          sourceImagePath: sourceImagePath,
          clanHanja: clan?.$1,
          clanHangul: clan?.$2);
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
    // 子 가 干支(甲子·壬子 등)의 일부일 때는 분리하지 않는다(앞 글자가 天干이면 제외)
    final pattern = RegExp(r'(?<![甲乙丙丁戊己庚辛壬癸])(?=[子女])');
    final parts = text.split(pattern).where((s) => s.trim().isNotEmpty).toList();
    return parts.where((p) {
      final t = p.trim();
      return t.startsWith('子') || t.startsWith('女');
    }).toList();
  }

  static Person? _parsePersonBlock(String block,
      {String? sourceImagePath, String? clanHanja, String? clanHangul}) {
    final t = block.trim();
    if (t.length < 2) return null;

    final dict = HanjaDict.instance;
    final person = Person(
      id: _uuid.v4(),
      sourceImagePath: sourceImagePath,
      rawText: t,
    );

    // 성별 + (차례) + 이름: 子/女 [차례한자] 이름(한자 1~3자)
    final nameMatch =
        RegExp(r'^([子女])\s*([一二三四五六七八九十]+)?\s*([一-鿿]{1,3})')
            .firstMatch(t);
    if (nameMatch == null) return null;
    final isFemale = nameMatch.group(1) == '女';
    person.gender = isFemale ? 'F' : 'M';
    final headName = nameMatch.group(3)!;

    // 配(배우자) 위치 기준으로 본인부 / 배우자부 분리
    final paeIdx = t.indexOf('配');
    final personPart = paeIdx >= 0 ? t.substring(0, paeIdx) : t;
    final spousePart = paeIdx >= 0 ? t.substring(paeIdx) : '';

    // ── 딸(女): 표기된 이름은 남편(사위), 딸 본인은 이름 없음 → 가문 성씨+씨 ──
    if (isFemale) {
      person.nameHanja = '';
      person.nameHangul = '';
      person.spouseHanja = headName; // 남편(사위)
      person.spouseHangul = dict.toHangul(headName);
      // 사위 본관: ○○人 (예: 安東人, 金海人, 全州人)
      final bg = RegExp(r'([一-鿿]{1,3})人').firstMatch(t);
      if (bg != null) person.spouseBongwan = bg.group(1);
      // 딸의 성은 가문 성씨를 상속
      if ((clanHanja ?? '').isNotEmpty) person.surnameHanja = clanHanja;
      if ((clanHangul ?? '').isNotEmpty) person.surnameHangul = clanHangul;
      return person;
    }

    // ── 아들(子, 본손) ──
    person.nameHanja = headName;
    person.nameHangul = dict.toHangul(headName);

    // 字 / 號 / 諡號 (본인부에서만)
    final ja = RegExp(r'字([一-鿿]{1,3})').firstMatch(personPart);
    if (ja != null) person.ja = ja.group(1);
    final ho = RegExp(r'號([一-鿿]{1,3})').firstMatch(personPart);
    if (ho != null) person.ho = ho.group(1);
    final siho = RegExp(r'諡號?([一-鿿]{1,3})').firstMatch(personPart);
    if (siho != null) person.siho = siho.group(1);

    // 世 (세대 번호)
    final segaM =
        RegExp(r'([0-9]+|[一二三四五六七八九十百]+)\s*世').firstMatch(t);
    if (segaM != null) {
      final n = _segaToInt(segaM.group(1)!);
      if (n != null) person.sega = n;
    }

    // 본인 출생 (干支 + 월·일 선택)
    final pb = _matchGanzhiDate(personPart, '生');
    if (pb != null) {
      person.birthDateLunar = pb.label;
      person.birthDateSolar = _estimateBirthYear(pb.ganzhi);
    }
    // 본인 사망 (卒)
    final pd = _matchGanzhiDate(personPart, '卒');
    if (pd != null) {
      person.deathDateLunar = pd.label;
      person.deathDateSolar =
          _estimateDeathYear(pd.ganzhi, person.birthDateSolar);
    }
    // 忌(기일) — 연도 미상, 월·일만
    final gi = RegExp(
            r'忌\s*([零一二三四五六七八九十百○]{1,3}月[零一二三四五六七八九十○]{1,3}日)')
        .firstMatch(personPart);
    if (gi != null && person.deathDateLunar == null) {
      person.deathDateLunar = '忌 ${gi.group(1)} (연도 미상)';
    }

    // 居/籍/生於 (출생·거주지)
    final place = RegExp(
            r'(?:居|籍|生於|生于|貫鄕|本生)\s*([一-鿿]{1,4}[道郡州府縣面里洞]?[一-鿿]{0,4}[面里洞山]?)')
        .firstMatch(personPart);
    if (place != null) {
      final v = place.group(1);
      if (v != null && v.isNotEmpty) person.birthPlace = v;
    }

    // 墓 (묘 위치) — 묘 뒤 한자 덩어리(좌향·합폄 포함)
    final myo = RegExp(r'墓\s*([一-鿿]{2,10})').firstMatch(personPart);
    if (myo != null) person.burialPlace = myo.group(1);
    // 좌향: ○坐○向 (있을 때만)
    final jwa = RegExp(r'([一-鿿])坐([一-鿿])向').firstMatch(personPart);
    if (jwa != null) {
      person.burialOrientation = '${jwa.group(1)}坐${jwa.group(2)}向';
    }

    // ── 配 (배우자/처가 계열) ──
    if (spousePart.isNotEmpty) {
      final pae = RegExp(
              r'配\s*([一-鿿]{1,4}[郡州府])?\s*([一-鿿]{1,3}氏)')
          .firstMatch(spousePart);
      if (pae != null) {
        person.spouseBongwan = pae.group(1);
        person.spouseHanja = pae.group(2);
        person.spouseHangul = dict.toHangul(pae.group(2)!);
      }
      // 배우자 출생/사망
      final sb = _matchGanzhiDate(spousePart, '生');
      if (sb != null) person.spouseBirth = sb.label;
      final sd = _matchGanzhiDate(spousePart, '卒');
      if (sd != null) person.spouseDeath = sd.label;

      // 처가 조상: 外祖 → 曾祖 → 祖 → 父 순으로 추출(겹침 방지 위해 추출 후 제거)
      var w = spousePart;
      String? grab(RegExp re) {
        final m = re.firstMatch(w);
        if (m != null) {
          final g = m.group(1);
          w = w.replaceRange(m.start, m.end, '·');
          return (g != null && g.trim().isNotEmpty) ? g.trim() : null;
        }
        return null;
      }

      person.spouseMaternalGrandfather =
          grab(RegExp(r'(?:聘\s*)?外祖\s*([一-鿿]{2,6})'));
      person.spouseGreatGrandfather = grab(RegExp(r'曾祖\s*([一-鿿]{2,5})'));
      person.spouseGrandfather = grab(RegExp(r'祖\s*([一-鿿]{2,4})'));
      person.spouseFather = grab(RegExp(r'父\s*([一-鿿]{1,4})'));
    }

    // 娶 (결혼) — 干支年
    final marry = RegExp('娶\\s*([$_gan][$_ji])?年?').firstMatch(personPart);
    if (marry != null && marry.group(1) != null) {
      person.marriageDate = '${marry.group(1)}年 (婚)';
    }

    // 사위 (婿/壻)
    final sonsInLaw = RegExp(r'[婿壻]\s*([一-鿿]{2,4})')
        .allMatches(t)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
    if (sonsInLaw.isNotEmpty) {
      person.sonsInLawNote =
          sonsInLaw.map((n) => '$n (${dict.toHangul(n)})').join(', ');
    }

    // 사돈 (査頓/姻/親家) — 사돈부인은 별도
    final inLaws = RegExp(r'(?:査頓|姻家?|親家)\s*([一-鿿]{2,5})')
        .allMatches(t)
        .where((m) => !m.group(0)!.contains('婦'))
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
    if (inLaws.isNotEmpty) {
      person.inLawsNote =
          inLaws.map((n) => '$n (${dict.toHangul(n)})').join(', ');
    }

    // 사돈부인 (査頓婦/姻家婦/사돈부인)
    final inLawWives = RegExp(r'(?:査頓婦|姻家婦|사돈부인)\s*([一-鿿]{2,5})')
        .allMatches(t)
        .map((m) => m.group(1)!)
        .toSet()
        .toList();
    if (inLawWives.isNotEmpty) {
      person.inLawsSpouseNote =
          inLawWives.map((n) => '$n (${dict.toHangul(n)})').join(', ');
    }

    // 성(姓) 분리 — 본인 이름은 외자/이름만(예: 格) → 가문 성씨 상속
    final np = Genealogy.split(
      hanja: person.nameHanja,
      hangul: person.nameHangul,
      fallbackSurnameHanja: clanHanja,
      fallbackSurnameHangul: clanHangul,
    );
    if (np.surnameHanja.isNotEmpty) person.surnameHanja = np.surnameHanja;
    if (np.surnameHangul.isNotEmpty) person.surnameHangul = np.surnameHangul;

    return person;
  }

  /// 干支(+月日) + 接尾(生/卒) 매칭. 월·일은 선택.
  static _GzDate? _matchGanzhiDate(String text, String suffix) {
    final re = RegExp(
        '([$_gan][$_ji])(?:([零一二三四五六七八九十百○]{1,3}月[零一二三四五六七八九十○]{1,3}日))?\\s*$suffix');
    final m = re.firstMatch(text);
    if (m == null) return null;
    final gz = m.group(1)!;
    final md = m.group(2);
    final label = md != null ? '$gz年 $md $suffix' : '$gz年 $suffix';
    return _GzDate(gz, label);
  }

  static String? _estimateBirthYear(String gz) {
    final c = LunarService.estimateYearsFromGanzhi(gz);
    final r = c.where((y) => y <= DateTime.now().year).toList();
    if (r.isEmpty) return null;
    return '${r.last} (干支 추정)';
  }

  static String? _estimateDeathYear(String gz, String? birthSolar) {
    if (birthSolar == null) return null;
    final c = LunarService.estimateYearsFromGanzhi(gz);
    final bm = RegExp(r'(\d{4})').firstMatch(birthSolar);
    if (bm == null) return null;
    final by = int.parse(bm.group(1)!);
    final dy = c.firstWhere((y) => y > by && y <= DateTime.now().year,
        orElse: () => -1);
    return dy > 0 ? '$dy (干支 추정)' : null;
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

class _GzDate {
  final String ganzhi;
  final String label;
  _GzDate(this.ganzhi, this.label);
}
