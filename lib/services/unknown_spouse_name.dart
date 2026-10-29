import '../models/person.dart';

/// 표시 전용 규칙: 아내의 개인 이름이 확인되지 않으면 남편의 이름으로 표시한다.
/// 배우자 원문, 본관, 성씨 및 실제 이름 필드는 변경하지 않는다.
class UnknownSpouseName {
  static String? wifeDisplayName(Person husband, {String? confirmedWifeName}) {
    final known = confirmedWifeName?.trim();
    if (known != null && known.isNotEmpty) return known;
    if (husband.gender != 'M') return null;
    // Recorded clan and surname take precedence over a husband-based label.
    final spouse = (husband.spouseHanja ?? '').trim();
    final spouseKorean = (husband.spouseHangul ?? '').trim();
    if (RegExp(r'^[가-힣]{1,2}씨
    final surname = (husband.surnameHangul ?? '').trim();
    final fullName = name.isEmpty ? '' :
        (surname.isNotEmpty && !name.startsWith(surname) ? '$surname$name' : name);
    if (fullName.isEmpty) return null;
    return '$fullName의 부인';
  }
}
).hasMatch(spouseKorean)) {
      return spouseKorean;
    }
    const knownSurnames = <String, String>{
      '尹': '윤', '邊': '변', '金': '김', '李': '이',
      '朴': '박', '崔': '최', '趙': '조', '權': '권',
    };
    if (spouse.endsWith('氏')) {
      final surnameCharacter = spouse.substring(spouse.length - 2, spouse.length - 1);
      final reading = knownSurnames[surnameCharacter];
      if (reading != null) return '
    final surname = (husband.surnameHangul ?? '').trim();
    final fullName = name.isEmpty ? '' :
        (surname.isNotEmpty && !name.startsWith(surname) ? '$surname$name' : name);
    if (fullName.isEmpty) return null;
    return '$fullName의 부인';
  }
}
 + '{reading}씨';
      return spouse;
    }
    final name = husband.nameHangul.trim();
    final surname = (husband.surnameHangul ?? '').trim();
    final fullName = name.isEmpty ? '' :
        (surname.isNotEmpty && !name.startsWith(surname) ? '$surname$name' : name);
    if (fullName.isEmpty) return null;
    return '$fullName의 부인';
  }
}
