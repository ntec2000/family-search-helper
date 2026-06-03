import 'romanizer.dart';
import '../models/person.dart';

/// v2.2 — 성(姓)/이름 분리, 성씨 상속, 세대 기반 연도 추정 등 가계도 계산 로직.
/// 순수 Dart(플러터 비의존) — 단위 시뮬레이션(테스트) 가능.
class Genealogy {
  Genealogy._();

  /// 출생/사망지 미상 시 기본값.
  static const defaultPlace = '대한민국';
  static const defaultPlaceRoman = 'Republic of Korea';

  /// 한 세대 평균 연수 (출생연도 추정 기준).
  static const generationYears = 30;

  /// 흔한 한국 성씨 — 한자.
  static const surnamesHanja = <String>{
    '金','李','朴','崔','鄭','姜','趙','尹','張','林','韓','吳','徐','申','權','黃',
    '安','宋','全','洪','柳','高','文','孫','白','許','盧','南','沈','禹','具','閔',
    '劉','羅','池','車','朱','郭','成','方','桂','都','咸','卞','廉','梁','表','馬',
    '蔡','元','千','玄','明','邊','嚴','蘇','陳','丁','魏','石','宣','薛','卓','周',
    '延','秋','睦','陰','夫','余','印','諸','楊','王','陸','章','尚','孟','潘','奇',
  };

  /// 흔한 한국 성씨 — 한글.
  static const surnamesHangul = <String>{
    '김','이','박','최','정','강','조','윤','장','임','한','오','서','신','권','황',
    '안','송','전','홍','류','유','고','문','손','백','허','노','남','심','우','구',
    '민','라','지','차','주','곽','성','방','계','도','함','변','염','양','표','마',
    '채','원','천','현','명','엄','소','진','위','석','선','설','탁','연','추','목',
    '음','부','여','인','제','맹','반','기','왕','육',
  };

  /// 대표 성씨 한자 → 한글 (순수 Dart 내장 — 사전 미로드 환경에서도 동작).
  static const surnameHanjaToHangul = <String, String>{
    '金':'김','李':'이','朴':'박','崔':'최','鄭':'정','姜':'강','趙':'조','尹':'윤',
    '張':'장','林':'임','韓':'한','吳':'오','徐':'서','申':'신','權':'권','黃':'황',
    '安':'안','宋':'송','全':'전','洪':'홍','柳':'류','高':'고','文':'문','孫':'손',
    '白':'백','許':'허','盧':'노','南':'남','沈':'심','禹':'우','具':'구','閔':'민',
    '劉':'유','羅':'라','池':'지','車':'차','朱':'주','郭':'곽','成':'성','方':'방',
    '桂':'계','都':'도','咸':'함','卞':'변','廉':'염','梁':'양','表':'표','馬':'마',
    '蔡':'채','元':'원','千':'천','玄':'현','明':'명','邊':'변','嚴':'엄','蘇':'소',
    '陳':'진','丁':'정','魏':'위','石':'석','宣':'선','薛':'설','卓':'탁','周':'주',
    '延':'연','秋':'추','睦':'목','陰':'음','夫':'부','余':'여','印':'인','諸':'제',
    '楊':'양','王':'왕','陸':'육','章':'장','尚':'상','孟':'맹','潘':'반','奇':'기',
    '慶':'경','邕':'옹','龐':'방','賓':'빈',
  };

  /// 문서 전체에서 가문(본관) 성씨 자동 감지.
  /// 예) "固城李氏思菴公派譜" → ('李','이').  찾지 못하면 null.
  static (String hanja, String hangul)? detectClanSurname(String text) {
    for (final m in RegExp(r'([㐀-鿿])氏').allMatches(text)) {
      final ch = m.group(1)!;
      final hg = surnameHanjaToHangul[ch];
      if (hg != null) return (ch, hg);
    }
    return null;
  }

  /// 배우자 표기(예: "原州邊氏" / "邊氏")에서 (성한자, 성한글) 추출.
  /// 장인·장인 부친 등 처가 인물에 성을 붙여 표기할 때 사용.
  static (String hanja, String hangul)? spouseSurname(String? spouseHanja) {
    if (spouseHanja == null) return null;
    final m = RegExp(r'([㐀-鿿])氏$').firstMatch(spouseHanja.trim());
    final ch = m != null
        ? m.group(1)!
        : (spouseHanja.trim().isNotEmpty
            ? spouseHanja.trim().substring(spouseHanja.trim().length - 1)
            : '');
    if (ch.isEmpty) return null;
    final hg = surnameHanjaToHangul[ch];
    if (hg == null) return null;
    return (ch, hg);
  }

  /// 자유 텍스트 토큰 "海원 (해원)" / "崔海斗(최해두)" / "최씨" 등에서
  /// (한자이름, 한글이름) 추출.
  static (String hanja, String hangul) parseToken(String token) {
    final m = RegExp(r'^\s*([^()（）]+?)\s*[(（]([^)）]*)[)）]\s*$')
        .firstMatch(token);
    if (m != null) {
      return (m.group(1)!.trim(), m.group(2)!.trim());
    }
    final t = token.trim();
    // 괄호 없는 토큰: 한자/한글 자동 판별
    final hasHanja = t.runes.any((c) => c >= 0x3400 && c <= 0x9FFF);
    final hasHangul = t.runes.any((c) => c >= 0xAC00 && c <= 0xD7A3);
    if (hasHanja && !hasHangul) return (t, '');
    if (hasHangul && !hasHanja) return ('', t);
    return (t, '');
  }

  /// 인물 이름을 성/이름으로 분리. 성이 토큰에 없으면 상속 성씨를 사용.
  static NameParts split({
    String hanja = '',
    String hangul = '',
    String? surnameHanja,
    String? surnameHangul,
    String? fallbackSurnameHanja,
    String? fallbackSurnameHangul,
    bool isFemale = false,
  }) {
    var hj = hanja.trim();
    var hg = hangul.trim();

    // 딸 "최씨"/"崔氏" 처리 — 이름 없는 부인/딸
    final ssHangul = hg.endsWith('씨');
    final ssHanja = hj.endsWith('氏');
    if (ssHangul) hg = hg.substring(0, hg.length - 1).trim();
    if (ssHanja) hj = hj.substring(0, hj.length - 1).trim();

    // ── 한자 성/이름 분리 ──
    String shanja = surnameHanja ?? '';
    String ghanja = '';
    if (shanja.isEmpty && hj.isNotEmpty) {
      final chars = hj.runes.map(String.fromCharCode).toList();
      if (chars.length >= 2 && surnamesHanja.contains(chars.first)) {
        shanja = chars.first;
        ghanja = chars.skip(1).join();
      } else if (chars.length == 1 && surnamesHanja.contains(chars.first)) {
        shanja = chars.first;
        ghanja = '';
      } else {
        shanja = fallbackSurnameHanja ?? '';
        ghanja = hj;
      }
    } else if (shanja.isNotEmpty && hj.isNotEmpty) {
      if (hj.startsWith(shanja) && hj.length > shanja.length) {
        ghanja = hj.substring(shanja.length);
      } else {
        ghanja = hj;
      }
    }
    shanja = shanja.isEmpty ? (fallbackSurnameHanja ?? '') : shanja;

    // ── 한글 성/이름 분리 ──
    String shangul = surnameHangul ?? '';
    String ghangul = '';
    if (shangul.isEmpty && hg.isNotEmpty) {
      final chars = hg.runes.map(String.fromCharCode).toList();
      if (chars.length >= 2 && surnamesHangul.contains(chars.first)) {
        shangul = chars.first;
        ghangul = chars.skip(1).join();
      } else if (chars.length == 1 && surnamesHangul.contains(chars.first)) {
        shangul = chars.first; // 성씨 한 글자만 (예: "최")
        ghangul = '';
      } else {
        shangul = fallbackSurnameHangul ?? '';
        ghangul = hg;
      }
    } else if (shangul.isNotEmpty && hg.isNotEmpty) {
      if (hg.startsWith(shangul) && hg.length > shangul.length) {
        ghangul = hg.substring(shangul.length);
      } else {
        ghangul = hg;
      }
    }
    shangul = shangul.isEmpty ? (fallbackSurnameHangul ?? '') : shangul;

    final givenKnown =
        !(ssHangul || ssHanja) && (ghangul.isNotEmpty || ghanja.isNotEmpty);

    final surnameRoman = Romanizer.romanizeSurname(shangul);
    final givenRoman =
        givenKnown ? Romanizer.romanizeGiven(ghangul) : '';

    return NameParts(
      surnameHanja: shanja,
      surnameHangul: shangul,
      givenHanja: ghanja,
      givenHangul: ghangul,
      givenKnown: givenKnown,
      surnameRoman: surnameRoman,
      givenRoman: givenRoman,
    );
  }

  /// 세대수 차이로 출생연도 추정 (한 세대 ≈ 30년).
  static int? estimateBirthYearByGeneration({
    required int anchorYear,
    required int anchorSega,
    required int targetSega,
  }) {
    final diff = targetSega - anchorSega;
    final y = anchorYear + diff * generationYears;
    if (y < 1 || y > DateTime.now().year + 1) return null;
    return (y / 10).round() * 10; // 10년 단위 반올림
  }

  /// 세(世) 기반 출생연도 추정 — 동일 족보 내 기준 인물(세+연도)을 찾아
  /// 한 세대 ≈ 30년으로 연도가 비어있는 인물의 출생연도를 "대략 YYYY"로 채움.
  static void fillGenerationEstimates(List<Person> persons) {
    Person? anchor;
    for (final p in persons) {
      if (p.sega != null && yearOf(p.birthDateSolar) != null) {
        anchor = p;
        break;
      }
    }
    if (anchor == null) return;
    final ay = yearOf(anchor.birthDateSolar)!;
    final asega = anchor.sega!;
    for (final p in persons) {
      final hasYear = (p.birthDateSolar ?? '').isNotEmpty;
      if (p.sega != null && !hasYear) {
        final est = estimateBirthYearByGeneration(
            anchorYear: ay, anchorSega: asega, targetSega: p.sega!);
        if (est != null) p.birthDateSolar = '대략 $est';
      }
    }
  }

  /// 추정 연도 라벨 — 값 없으면 빈칸, 있으면 "대략 YYYY".
  static String approxYearLabel(int? year) =>
      (year == null || year <= 0) ? '' : '대략 $year';

  /// "1929-11-07 (干支 추정)" / "대략 1810" 등에서 4자리 연도 추출.
  static int? yearOf(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(\d{4})').firstMatch(s);
    return m == null ? null : int.parse(m.group(1)!);
  }
}

class NameParts {
  final String surnameHanja;
  final String surnameHangul;
  final String givenHanja;
  final String givenHangul;
  final bool givenKnown;
  final String surnameRoman;
  final String givenRoman;
  const NameParts({
    required this.surnameHanja,
    required this.surnameHangul,
    required this.givenHanja,
    required this.givenHangul,
    required this.givenKnown,
    required this.surnameRoman,
    required this.givenRoman,
  });

  /// 두 칸 표시 여부 (이름이 있으면 성|이름 두 칸, 없으면 "성씨" 한 칸).
  bool get twoColumn => givenKnown;

  /// 한 칸 표시용 한글 (딸 이름 없음 → "최씨").
  String get singleHangul {
    final s = surnameHangul.isNotEmpty ? surnameHangul : surnameHanja;
    return givenKnown ? '$surnameHangul$givenHangul' : '$s씨';
  }

  /// 한 칸 표시용 로마자.
  String get singleRoman => surnameRoman;

  /// 성 칸 한글 (한자 병기).
  String get surnameCell {
    if (surnameHangul.isEmpty && surnameHanja.isEmpty) return '';
    if (surnameHanja.isNotEmpty && surnameHangul.isNotEmpty) {
      return '$surnameHanja\n$surnameHangul';
    }
    return surnameHangul.isNotEmpty ? surnameHangul : surnameHanja;
  }

  /// 이름 칸 한글 (한자 병기).
  String get givenCell {
    if (givenHanja.isNotEmpty && givenHangul.isNotEmpty) {
      return '$givenHanja\n$givenHangul';
    }
    return givenHangul.isNotEmpty ? givenHangul : givenHanja;
  }
}
