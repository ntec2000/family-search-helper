import 'dart:convert';

/// 가족역사기록서(FamilySearch Person) 호환 인물 모델
class Person {
  String id;
  // 이름
  String nameHanja;       // 崔海斗
  String nameHangul;      // 최해두
  String nameRoman;       // CHOI HAE-DU
  // v2.2 — 성(姓)/이름 분리 표기 및 성씨 상속
  String? surnameHanja;   // 姓 한자 — 예: 崔
  String? surnameHangul;  // 성 한글 — 예: 최
  String? ja;             // 字 (자)
  String? ho;             // 號 (호)
  String? siho;           // 諡號 (시호)
  String? bongwan;        // 本貫 (본관) — 예: 慶州崔氏
  String? pa;             // 派 (파)
  int? sega;              // 世 (세대)
  String gender;          // 'M' / 'F' / 'U'

  // 출생
  String? birthDateLunar;   // 干支 음력 표기
  String? birthDateSolar;   // 1929-11-07 / "대략 1800" (추정)
  String? birthPlace;       // 경북 경주시 강동면

  // 결혼
  String? marriageDate;
  String? marriagePlace;
  String? spouseHanja;
  String? spouseHangul;
  String? spouseFather;     // 配 ○○○氏 父 ○○○ (장인)
  String? spouseMother;     // v2.2 — 장모(배우자 모친) "○○○의 부인"
  String? spouseBongwan;
  // v2.3 — 처가(妻家) 계열: 配 블록의 祖/曾祖/外祖는 배우자(아내)의 조상이다.
  String? spouseGrandfather;        // 配 祖   — 장인의 아버지
  String? spouseGreatGrandfather;   // 配 曾祖 — 장인의 할아버지(처증조)
  String? spouseMaternalGrandfather;// 配 外祖 — 아내의 외할아버지
  String? spouseBirth;              // 配 干支生 (배우자 출생)
  String? spouseDeath;              // 配 干支卒 (배우자 사망)

  // 사망/매장
  String? deathDateLunar;
  String? deathDateSolar;
  String? deathPlace;
  String? burialPlace;      // 墓 위치
  String? burialOrientation; // 좌향 (예: 子坐午向)

  // 가족 관계 (관계 ID)
  String? fatherId;
  String? motherId;
  List<String> childrenIds;
  List<String> sonsInLawIds;   // 사위
  List<String> inLawsIds;      // 사돈

  // 가족 관계 (추출 텍스트 — 족보 평문에서 추출한 정보) #16
  String? childrenNote;        // 자녀 정보
  String? sonsInLawNote;       // 사위 정보 (婿/壻)
  String? inLawsNote;          // 사돈 정보 (査頓/姻)
  String? inLawsSpouseNote;    // v2.2 — 사돈부인 정보

  // v2.2 — FamilySearch 정합용 근거 진술 (Reason This Information Is Correct)
  String? reasonStatement;

  // 메타
  String? sourceImagePath;
  String? rawText;
  DateTime createdAt;
  DateTime updatedAt;

  Person({
    required this.id,
    this.nameHanja = '',
    this.nameHangul = '',
    this.nameRoman = '',
    this.surnameHanja,
    this.surnameHangul,
    this.ja,
    this.ho,
    this.siho,
    this.bongwan,
    this.pa,
    this.sega,
    this.gender = 'U',
    this.birthDateLunar,
    this.birthDateSolar,
    this.birthPlace,
    this.marriageDate,
    this.marriagePlace,
    this.spouseHanja,
    this.spouseHangul,
    this.spouseFather,
    this.spouseMother,
    this.spouseBongwan,
    this.spouseGrandfather,
    this.spouseGreatGrandfather,
    this.spouseMaternalGrandfather,
    this.spouseBirth,
    this.spouseDeath,
    this.deathDateLunar,
    this.deathDateSolar,
    this.deathPlace,
    this.burialPlace,
    this.burialOrientation,
    this.fatherId,
    this.motherId,
    List<String>? childrenIds,
    List<String>? sonsInLawIds,
    List<String>? inLawsIds,
    this.childrenNote,
    this.sonsInLawNote,
    this.inLawsNote,
    this.inLawsSpouseNote,
    this.reasonStatement,
    this.sourceImagePath,
    this.rawText,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : childrenIds = childrenIds ?? [],
        sonsInLawIds = sonsInLawIds ?? [],
        inLawsIds = inLawsIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name_hanja': nameHanja,
        'name_hangul': nameHangul,
        'name_roman': nameRoman,
        'surname_hanja': surnameHanja,
        'surname_hangul': surnameHangul,
        'ja': ja,
        'ho': ho,
        'siho': siho,
        'bongwan': bongwan,
        'pa': pa,
        'sega': sega,
        'gender': gender,
        'birth_date_lunar': birthDateLunar,
        'birth_date_solar': birthDateSolar,
        'birth_place': birthPlace,
        'marriage_date': marriageDate,
        'marriage_place': marriagePlace,
        'spouse_hanja': spouseHanja,
        'spouse_hangul': spouseHangul,
        'spouse_father': spouseFather,
        'spouse_mother': spouseMother,
        'spouse_bongwan': spouseBongwan,
        'spouse_grandfather': spouseGrandfather,
        'spouse_great_grandfather': spouseGreatGrandfather,
        'spouse_maternal_grandfather': spouseMaternalGrandfather,
        'spouse_birth': spouseBirth,
        'spouse_death': spouseDeath,
        'death_date_lunar': deathDateLunar,
        'death_date_solar': deathDateSolar,
        'death_place': deathPlace,
        'burial_place': burialPlace,
        'burial_orientation': burialOrientation,
        'father_id': fatherId,
        'mother_id': motherId,
        'children_ids': jsonEncode(childrenIds),
        'sons_in_law_ids': jsonEncode(sonsInLawIds),
        'in_laws_ids': jsonEncode(inLawsIds),
        'children_note': childrenNote,
        'sons_in_law_note': sonsInLawNote,
        'in_laws_note': inLawsNote,
        'in_laws_spouse_note': inLawsSpouseNote,
        'reason_statement': reasonStatement,
        'source_image_path': sourceImagePath,
        'raw_text': rawText,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Person.fromMap(Map<String, dynamic> m) => Person(
        id: m['id'] as String,
        nameHanja: m['name_hanja'] ?? '',
        nameHangul: m['name_hangul'] ?? '',
        nameRoman: m['name_roman'] ?? '',
        surnameHanja: m['surname_hanja'],
        surnameHangul: m['surname_hangul'],
        ja: m['ja'],
        ho: m['ho'],
        siho: m['siho'],
        bongwan: m['bongwan'],
        pa: m['pa'],
        sega: m['sega'] as int?,
        gender: m['gender'] ?? 'U',
        birthDateLunar: m['birth_date_lunar'],
        birthDateSolar: m['birth_date_solar'],
        birthPlace: m['birth_place'],
        marriageDate: m['marriage_date'],
        marriagePlace: m['marriage_place'],
        spouseHanja: m['spouse_hanja'],
        spouseHangul: m['spouse_hangul'],
        spouseFather: m['spouse_father'],
        spouseMother: m['spouse_mother'],
        spouseBongwan: m['spouse_bongwan'],
        spouseGrandfather: m['spouse_grandfather'],
        spouseGreatGrandfather: m['spouse_great_grandfather'],
        spouseMaternalGrandfather: m['spouse_maternal_grandfather'],
        spouseBirth: m['spouse_birth'],
        spouseDeath: m['spouse_death'],
        deathDateLunar: m['death_date_lunar'],
        deathDateSolar: m['death_date_solar'],
        deathPlace: m['death_place'],
        burialPlace: m['burial_place'],
        burialOrientation: m['burial_orientation'],
        fatherId: m['father_id'],
        motherId: m['mother_id'],
        childrenIds: m['children_ids'] != null
            ? List<String>.from(jsonDecode(m['children_ids']))
            : [],
        sonsInLawIds: m['sons_in_law_ids'] != null
            ? List<String>.from(jsonDecode(m['sons_in_law_ids']))
            : [],
        inLawsIds: m['in_laws_ids'] != null
            ? List<String>.from(jsonDecode(m['in_laws_ids']))
            : [],
        childrenNote: m['children_note'],
        sonsInLawNote: m['sons_in_law_note'],
        inLawsNote: m['in_laws_note'],
        inLawsSpouseNote: m['in_laws_spouse_note'],
        reasonStatement: m['reason_statement'],
        sourceImagePath: m['source_image_path'],
        rawText: m['raw_text'],
        createdAt: DateTime.parse(m['created_at']),
        updatedAt: DateTime.parse(m['updated_at']),
      );
}
