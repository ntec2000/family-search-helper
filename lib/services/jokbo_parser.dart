import 'package:uuid/uuid.dart';
import '../models/person.dart';
import 'hanja_dict.dart';
import 'genealogy.dart';

/// 족보 OCR 텍스트 파서.
/// 표준 족보 표기 규칙(v2.5 체계화):
///   子○○ / 女○○            : 인물(성별 + 이름). 子=아들, 女=딸(→사위 표기)
///   子[二三四…]○○           : 둘째/세째/네째 등 차례 표기. 차례 글자는 이름에서
///                              제외하고 "○째 아들/딸" 로 메모에 기록. 차례 숫자가
///                              없으면 보통 첫째(장남/장녀).
///   字○○                    : 자(字) — 관례 때 받은 이름(본명 아님) → 메모에 기록
///   號○○                    : 호
///   干支(○月○日) 生/卒       : 본인 출생/사망 (월·일은 선택)
///   忌 ○月○日                : 기일(사망일, 연도 미상)
///   墓○○                     : 묘 위치
///   配○○郡 ○○氏 …父祖曾祖外祖: 배우자(아내) 정보 — 父/祖/曾祖/外祖는 모두
///                              아내 쪽(처가) 조상이다. 父=장인, 祖=장인의 아버지,
///                              曾祖=장인의 할아버지, 外祖=아내의 외할아버지.
///                              · 父/祖/曾祖(=아내의 친가 직계)는 아내 성씨를 붙여
///                                표기하고, 이름 앞 관직·품계(判官·通政 등)는 제거.
///                              · 外祖(아내의 외가)는 자체 성씨를 가지므로 앞의
///                                본관(지역) 두 글자를 제거하고 그대로 사용.
///   女○○ ○○人               : 딸 → 남편(사위) 이름 + 사위 본관. 딸 본인은 이름이
///                              없으므로 가문 성씨를 따라 "○씨" 로 표기.
class JokboParser {
  static const _uuid = Uuid();

  static const _gan = '甲乙丙丁戊己庚辛壬癸';
  static const _ji = '子丑寅卯辰巳午未申酉戌亥';

  /// 처가 직계(父·祖·曾祖) 이름 앞에 붙는 관직명·품계 — 이름에서 제거.
  /// 단, 同知 는 본 족보에서 이름(예: 변동지)으로 쓰이므로 제외한다.
  static const _titles = <String>[
    '判官', '通政', '通訓', '嘉善', '嘉靖', '折衝', '僉知', '僉正', '僉樞',
    '副護軍', '副司果', '司果', '主簿', '參奉', '縣監', '郡守', '牧使', '府使',
    '觀察使', '學生', '處士', '進士', '生員', '持平', '掌令', '正郞', '佐郞',
    '判書', '參判', '參議', '承旨', '監役', '護軍', '宣傳官', '贈',
  ];

  /// 차례(숫자 한자) → 서수 라벨.
  static const _ordinal = <String, String>{
    '一': '첫째', '二': '둘째', '三': '셋째', '四': '넷째', '五': '다섯째',
    '六': '여섯째', '七': '일곱째', '八': '여덟째', '九': '아홉째', '十': '열째',
  };

  /// 구획 사이에서 이름을 놓쳐도 앞 인물에게 다음 구획의 정보가 붙지 않게 한다.
  static List<Person> parseRegions(List<String> regions, {String? sourceImagePath,
      String? clanHanjaOverride, String? clanHangulOverride}) {
    if (regions.isEmpty) return [];
    final clan = Genealogy.detectClanSurname(regions.first.split('配').first);
    return [for (final region in regions) ...parse(region,
      sourceImagePath: sourceImagePath,
      clanHanjaOverride: clanHanjaOverride ?? clan?.$1,
      clanHangulOverride: clanHangulOverride ?? clan?.$2)];
  }

  /// OCR 인식 텍스트(세로쓰기 → 정렬된 평문)를 받아 인물 카드 목록 추출
  static List<Person> parse(String rawText,
      {String? sourceImagePath,
      String? clanHanjaOverride,
      String? clanHangulOverride}) {
    final normalized = _normalize(rawText);
    // 문서 전체에서 가문(본관) 성씨 자동 감지 — 예: "固城李氏…" → 李/이
    final firstPerson = RegExp(r'(?<!\S)[子女男]\s*[一-鿿]').firstMatch(normalized);
    final detected = Genealogy.detectClanSurname(firstPerson == null
        ? normalized : normalized.substring(0, firstPerson.start));
    // v2.7 — [족보작성]에서 미리 입력받은 성씨가 있으면 자동 감지보다 우선 적용한다.
    final clanHanja = (clanHanjaOverride != null && clanHanjaOverride.isNotEmpty)
        ? clanHanjaOverride
        : detected?.$1;
    final clanHangul =
        (clanHangulOverride != null && clanHangulOverride.isNotEmpty)
            ? clanHangulOverride
            : detected?.$2;
    final entries = _splitByPerson(normalized);
    final originalEntries = _splitByPerson(rawText);

    final persons = <Person>[];
    for (var index = 0; index < entries.length; index++) {
      final block = entries[index];
      // 원본과 파싱 경계가 일치할 때만 개별 원문으로 사용한다.
      // 일치하지 않으면 다른 인물의 원문을 붙이는 대신 기존 안전 경로를 쓴다.
      final original = originalEntries.length == entries.length &&
              _normalize(originalEntries[index]).trim() == block.trim()
          ? originalEntries[index] : null;
      final p = _parsePersonBlock(block,
          sourceRawText: original,
          sourceImagePath: sourceImagePath,
          clanHanja: clanHanja,
          clanHangul: clanHangul);
      if (p != null) persons.add(p);
    }
    // OCR 등장 순서만으로 형제 순서나 부모를 추론하지 않습니다.
    // 각 인물의 명시적 순서 표기는 _parsePersonBlock에서 보존합니다.
    // 간지만으로 서기 연도를 확정할 수 없으므로 세대별 연도 자동 추정은 하지 않습니다.
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
    // 세로 OCR은 간지와 날짜 숫자를 글자별로 나누기도 한다. 원문은
    // Person.rawText에 보존하고, 파싱용 문자열에서만 구조 토큰을 복원한다.
    s = s.replaceAllMapped(
        RegExp('([$_gan])\\s+([$_ji])'), (m) => '${m[1]}${m[2]}');
    s = s.replaceAllMapped(
        RegExp('([$_gan][$_ji])\\s*年'), (m) => '${m[1]}年');
    s = s.replaceAllMapped(
        RegExp(r'[零一二三四五六七八九十百○0-9](?:\s*[零一二三四五六七八九十百○0-9])*\s*[月日]'),
        (m) => m[0]!.replaceAll(RegExp(r'\s+'), ''));
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  static List<String> _splitByPerson(String text) {
    // 子 가 干支(甲子·壬子 등)의 일부일 때는 분리하지 않는다(앞 글자가 天干이면 제외)
    // 子·男=아들, 女=딸. (일부 족보는 아들을 男으로 표기)
    // 인물 시작 표지는 독립 토큰일 때만 인정한다.
    // 子坐午向의 子, 본문 속 女/男 및 간지의 子를 인물로 오인하지 않는다.
    // OCR가 공백 없이 붙여 놓은 애매한 후보는 자동 분리하지 않고 원문에 남긴다.
    final pattern = RegExp(r'(?<!\S)(?=[子女男](?!坐|向|孫|女|男)\s*[一-鿿])');
    final parts = text.split(pattern).where((s) => s.trim().isNotEmpty).toList();
    return parts.where((p) {
      final t = p.trim();
      return t.startsWith('子') || t.startsWith('女') || t.startsWith('男');
    }).toList();
  }

  /// 처가 직계(父·祖·曾祖) 이름 앞 관직·품계 제거.
  static String _stripTitle(String s) {
    var r = s.trim();
    for (final t in _titles) {
      if (r.startsWith(t) && r.length > t.length) {
        r = r.substring(t.length).trim();
        break;
      }
    }
    return r;
  }

  /// 外祖(아내의 외가) 이름에서 앞의 본관(지역) 두 글자 제거.
  /// 예) 文化柳承春 → 柳承春,  濟州高 → 高,  丁若萬 → 丁若萬(그대로)
  static String _stripBongwanPrefix(String s) {
    final r = s.trim();
    final ch = r.runes.map(String.fromCharCode).toList();
    // [본관(지역) 2자][성씨 1자][이름…] 구조이면 3번째 글자가 성씨 → 앞 2자 제거.
    // (예: 文化柳承春 → 柳承春, 濟州高 → 高).  丁若萬처럼 3번째가 이름이면 유지.
    // 세 글자가 모두 개인 이름일 수 있다(예: 李承金). 첫 글자도
    // 성씨로 쓰이면 본관인지 단정할 근거가 없으므로 원문을 보존한다.
    if (ch.length == 3 && Genealogy.surnamesHanja.contains(ch[0])) {
      return r;
    }
    if (ch.length >= 3 && Genealogy.surnamesHanja.contains(ch[2])) {
      return ch.sublist(2).join();
    }
    return r;
  }

  static Person? _parsePersonBlock(String block,
      {String? sourceImagePath, String? sourceRawText, String? clanHanja, String? clanHangul}) {
    final t = block.trim();
    if (t.length < 2) return null;

    final dict = HanjaDict.instance;
    final person = Person(
      id: _uuid.v4(),
      sourceImagePath: sourceImagePath,
      rawText: sourceRawText ?? t,
    );

    // 메모(특이사항) 누적 헬퍼
    void addNote(String s) {
      final v = s.trim();
      if (v.isEmpty) return;
      person.note =
          (person.note == null || person.note!.isEmpty) ? v : '${person.note} / $v';
    }

    // 성별 + (차례) + 이름: 子/女 [차례한자] 이름(한자 1~3자)
    // 子/男=아들, 女=딸 + (차례) + 이름(한자 1~3자)
    final nameMatch =
        RegExp('^([子女男])\\s*([一二三四五六七八九十]+)?\\s*([一-鿿]{1,3}?)(?=\\s|\$|[、。:：;；,，.!?！？「」-]|[出字配生卒墓忌號娶贈系]|[$_gan][$_ji](?:年|[一二三四五六七八九十正閏0-9]|生|卒)|[一二三四五六七八九十百0-9]+世)')
            .firstMatch(t);
    if (nameMatch == null) return null;
    final isFemale = nameMatch.group(1) == '女';
    person.gender = isFemale ? 'F' : 'M';
    final orderChar = nameMatch.group(2);
    var headName = nameMatch.group(3)!;
    // 이름 뒤에 구조 키워드가 붙어버린 경우 잘라낸다 (예: 承勳出 → 承勳)
    for (final kw in const ['出', '字', '配', '生', '卒', '墓', '忌', '號', '娶', '贈', '系']) {
      final ki = headName.indexOf(kw);
      if (ki >= 0) headName = headName.substring(0, ki);
    }
    if (!isFemale && (headName.isEmpty ||
        RegExp(r'^(?:父|祖|曾祖|外祖|判官|通政|[零一二三四五六七八九十百]+世?|[一-鿿]*氏)$')
            .hasMatch(headName))) {
      return null;
    }
    if (!isFemale && RegExp('^[$_gan][$_ji](?:[一二三四五六七八九十百]+)?\$')
        .hasMatch(headName)) {
      return null;
    }

    // 인물 표제에 뒤따르는 구조어·본관·날짜를 본명으로 채택하지 않는다.
    // OCR에서 子 다음에 이름 대신 주석이 붙는 경우를 보수적으로 제외한다.
    if (!isFemale && (headName.endsWith('氏') ||
        headName.endsWith('人') ||
        headName.startsWith('外祖') ||
        headName.startsWith('曾祖') ||
        headName.startsWith('配') ||
        headName.startsWith('墓') ||
        headName.startsWith('忌'))) {
      return null;
    }

    // 차례 숫자가 명시된 경우에만 순서를 부여한다.
    final orderLab = (orderChar != null &&
            orderChar.length == 1 &&
            _ordinal[orderChar] != null)
        ? _ordinal[orderChar]!
        : '순서 미상';
    person.relation = '$orderLab${isFemale ? '딸' : '아들'}';
    if (orderChar != null &&
        orderChar.length == 1 &&
        _ordinal[orderChar] != null) {
      addNote('$orderLab ${isFemale ? '딸' : '아들'}');
    }

    // 配(배우자) 위치 기준으로 본인부 / 배우자부 분리
    final paeIdx = t.indexOf('配');
    final personPart = paeIdx >= 0 ? t.substring(0, paeIdx) : t;
    final spousePart = paeIdx >= 0 ? t.substring(paeIdx) : '';
    final segaMatch = RegExp(r'([0-9]+|[一二三四五六七八九十百]+)\s*世').firstMatch(personPart);
    if (segaMatch != null) person.sega = _segaToInt(segaMatch[1]!);

    // ── 딸(女): 표기된 한자는 남편(사위) 이름, 딸 본인은 이름이 없으므로
    //    아버지(가문) 성을 따라 "○씨" 로 표기한다. 사위 본관(○○人)도 추출.
    //    표기가 본관(○○人)뿐이면 사위 이름은 미상으로 둔다.
    if (isFemale) {
      person.nameHanja = '';
      person.nameHangul = '';
      // 女 다음 첫 이름 토큰만 사위 후보로 사용한다.
      // 본관(安東人)은 별도로 읽고, 뒤따르는 卒/墓/配 등은 포함하지 않는다.
      final body = t.replaceFirst(
          RegExp(r'^女\s*[一二三四五六七八九十]?\s*'), '').trim();
      final husbandMatch = RegExp(r'^(?![一-鿿]*人)([一-鿿]{1,4})(?=\s|$|[、。:：;；,，.!?！？「」-]|[生卒墓忌配字號娶出系])')
          .firstMatch(body);
      final husband = husbandMatch?.group(1) ?? '';
      final afterHusband = body.substring(husbandMatch?.end ?? 0);
      final bgM = RegExp(r'^[\s、。:：;；,，.!?！？「」-]*([一-鿿]{2,3})人').firstMatch(afterHusband);
      if (bgM != null) {
        person.spouseBongwan = bgM.group(1);
      }
      person.spouseHanja = husband.isEmpty ? null : husband;
      person.spouseHangul = husband.isEmpty ? null : dict.toHangul(husband);
      addNote('딸의 개인 이름 미상. 女 뒤 표기는 사위 후보이며 원문 대조가 필요합니다.');
      // 딸의 성은 가문 성씨 상속 (이름 없음 → 내보내기에서 "○씨")
      if ((clanHanja ?? '').isNotEmpty) person.surnameHanja = clanHanja;
      if ((clanHangul ?? '').isNotEmpty) person.surnameHangul = clanHangul;
      return person;
    }

    // ── 아들(子, 본손) ──
    person.nameHanja = headName;
    person.nameHangul = dict.toHangul(headName);

    // 出系(출계, 양자로 나감): "出系 ○○后" → 특이사항 메모
    final chulgye = RegExp(r'出\s*系\s*([一-鿿]{2,4})\s*后').firstMatch(t);
    if (chulgye != null) {
      final who = chulgye.group(1)!;
      addNote('出系 $who后 — ${dict.toHangul(who)}의 후사(後嗣)로 출계(양자)');
    }

    // 字 / 號 / 諡號 (본인부에서만). 字는 본명이 아닌 관례명이므로 메모에도 기록.
    final ja = RegExp(r'字\s*([一-鿿]{1,3}?)(?=\s|$|[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥]|[配生卒墓忌號娶出系])').firstMatch(personPart);
    if (ja != null) {
      person.ja = ja.group(1);
      addNote('字(자) ${dict.toHangul(ja.group(1)!)}(${ja.group(1)}) — 관례 때 받은 이름(본명 아님)');
    }
    final ho = RegExp(r'(?<!諡)號\s*([一-鿿]{1,3}?)(?=\s|$|[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥]|[配生卒墓忌字娶出系])').firstMatch(personPart);
    if (ho != null) person.ho = ho.group(1);
    final siho = RegExp(r'諡號?([一-鿿]{1,3})').firstMatch(personPart);
    if (siho != null) person.siho = siho.group(1);

    // 본인 출생 (干支 + 월·일 선택)
    final pb = _matchGanzhiDate(personPart, '生');
    if (pb != null) {
      person.birthDateLunar = pb.label;
    }
    // 본인 사망 (卒)
    final pd = _matchGanzhiDate(personPart, '卒');
    if (pd != null) {
      person.deathDateLunar = pd.label;
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
        // 아내는 이름을 거의 기록하지 않으므로 본관+성씨를 메모에 보존
        if ((pae.group(1) ?? '').isNotEmpty) {
          addNote('아내 본관: ${pae.group(1)}${pae.group(2)} '
              '(${dict.toHangul(pae.group(1)! + pae.group(2)!)})');
        }
      }
      // 배우자 출생/사망
      final sb = _matchGanzhiDate(spousePart, '生');
      if (sb != null) person.spouseBirth = sb.label;
      final sd = _matchGanzhiDate(spousePart, '卒');
      if (sd != null) person.spouseDeath = sd.label;
      final spouseGi = RegExp(r'忌\s*([正冬臘閏零一二三四五六七八九十百○0-9]{1,4}月\s*[初廿卅零一二三四五六七八九十○0-9]{1,4}日)')
          .firstMatch(spousePart);
      if (person.spouseDeath == null && spouseGi != null) {
        person.spouseDeath = '忌 ${spouseGi[1]} (연도 미상)';
      }

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

      // 外祖(외가) — 자체 성씨 보유 → 앞 본관(지역) 두 글자만 제거
      final outer = grab(RegExp(r'(?:聘\s*)?外祖\s*([一-鿿]{2,6}?)(?=\s|$|[·父祖配生卒忌墓]|曾祖)'));
      person.spouseMaternalGrandfather =
          outer == null ? null : _stripBongwanPrefix(outer);
      // 曾祖/祖/父(친가 직계) — 관직·품계 제거(아내 성씨는 내보내기에서 부여)
      final gGf = grab(RegExp(r'曾祖\s*([一-鿿]{2,5}?)(?=\s|$|[·父祖配生卒忌墓]|外祖)'));
      person.spouseGreatGrandfather = gGf == null ? null : _stripTitle(gGf);
      final gf = grab(RegExp(r'祖\s*([一-鿿]{2,4}?)(?=\s|$|[·父配生卒忌墓]|曾祖|外祖)'));
      person.spouseGrandfather = gf == null ? null : _stripTitle(gf);
      final fa = grab(RegExp(r'父\s*([一-鿿]{1,4}?)(?=\s|$|[·祖配生卒忌墓]|曾祖|外祖)'));
      person.spouseFather = fa == null ? null : _stripTitle(fa);
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

    // 한글 표기 오기 점검: 블록 내 한글 음(같은 글자 수)이 한자 사전음과 다르면 메모
    final hangulShown = RegExp(r'[가-힣]{2,3}').firstMatch(personPart);
    if (hangulShown != null && person.nameHanja.isNotEmpty) {
      final shown = hangulShown.group(0)!;
      final reading = dict.toHangul(person.nameHanja);
      final isReadable = reading != person.nameHanja; // 사전 로드 시에만 의미
      if (isReadable &&
          shown.length == person.nameHanja.runes.length &&
          shown != reading) {
        addNote("한글표기 '$shown' ↔ 한자음 '$reading' 불일치(확인요망)");
      }
    }

    // 성(姓) 분리 — 본인 이름은 외자/이름만(예: 格) → 가문 성씨 상속
    // 子 뒤는 이름이다. 첫 글자가 金·安 등이어도 성씨라고 추측하지 않는다.
    person.surnameHanja = clanHanja;
    person.surnameHangul = clanHangul;

    return person;
  }

  /// 干支(+月日) + 接尾(生/卒) 매칭. 월·일은 선택.
  static _GzDate? _matchGanzhiDate(String text, String suffix) {
    final re = RegExp(
        '([$_gan][$_ji])年?\\s*(?:((?:閏)?[正冬臘零一二三四五六七八九十百○0-9]{1,3}月\\s*[初廿卅零一二三四五六七八九十○0-9]{1,3}日))?\\s*$suffix');
    final m = re.firstMatch(text);
    if (m == null) return null;
    final gz = m.group(1)!;
    final md = m.group(2)?.replaceAll(RegExp(r'\s+'), '');
    final label = md != null ? '$gz年 $md $suffix' : '$gz年 $suffix';
    return _GzDate(gz, label);
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
