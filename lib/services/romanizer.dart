/// 한글 이름 → 로마자(알파벳) 변환. (#4 이름 로마자 자동 표시)
/// 국립국어원 로마자 표기법(Revised Romanization) 기반의 간이 구현.
/// 성(姓)과 이름을 공백으로 구분하여 각 음절 첫 글자를 대문자로 표기.
class Romanizer {
  Romanizer._();

  static const _cho = [
    'g','kk','n','d','tt','r','m','b','pp','s','ss','','j','jj','ch','k','t','p','h'
  ];
  static const _jung = [
    'a','ae','ya','yae','eo','e','yeo','ye','o','wa','wae','oe','yo','u',
    'wo','we','wi','yu','eu','ui','i'
  ];
  static const _jong = [
    '','k','k','k','n','n','n','t','l','l','l','l','l','l','l','l','m','p','p',
    't','t','ng','t','t','k','t','p','t'
  ];

  /// 한 음절(가-힣)을 로마자로.
  static String _syllable(int code) {
    final s = code - 0xAC00;
    if (s < 0 || s > 11171) return String.fromCharCode(code);
    final cho = s ~/ 588;
    final jung = (s % 588) ~/ 28;
    final jong = s % 28;
    return _cho[cho] + _jung[jung] + _jong[jong];
  }

  static String _cap(String w) =>
      w.isEmpty ? w : w[0].toUpperCase() + w.substring(1);

  /// 한글 이름 문자열을 로마자로 변환.
  /// "최해두" → "Choi Hae-du" (성 1글자 가정, 나머지는 하이픈 연결)
  static String romanizeName(String hangul) {
    final clean = hangul.trim();
    if (clean.isEmpty) return '';
    // 한글 음절만 추출
    final syl = <String>[];
    for (final r in clean.runes) {
      if (r >= 0xAC00 && r <= 0xD7A3) {
        syl.add(_syllable(r));
      }
    }
    if (syl.isEmpty) return '';
    // 성(첫 음절) 관용 표기 보정
    final famRaw = syl.first;
    final surnameMap = {
      'gim': 'Kim', 'i': 'Lee', 'bak': 'Park', 'choe': 'Choi',
      'jeong': 'Jung', 'gang': 'Kang', 'jo': 'Cho', 'yun': 'Yoon',
      'jang': 'Jang', 'lim': 'Lim', 'im': 'Lim', 'han': 'Han',
      'o': 'Oh', 'seo': 'Seo', 'sin': 'Shin', 'gwon': 'Kwon',
      'hwang': 'Hwang', 'an': 'Ahn', 'song': 'Song', 'jeon': 'Jeon',
      'hong': 'Hong', 'yu': 'Yoo', 'go': 'Ko', 'mun': 'Moon',
      'son': 'Son', 'baek': 'Baek', 'heo': 'Heo', 'no': 'Noh',
    };
    final surname = surnameMap[famRaw] ?? _cap(famRaw);
    if (syl.length == 1) return surname;
    final givenSyl = syl.skip(1).toList();
    final given = [
      _cap(givenSyl.first),
      ...givenSyl.skip(1).map((w) => w.toLowerCase()),
    ].join('-');
    return '$surname $given';
  }
}
