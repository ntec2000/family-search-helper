import '../models/person.dart';
import 'unknown_spouse_name.dart';

/// 전송과 파일 내보내기에서 같은 성/이름·원문 날짜 필드를 사용한다.
class FamilySearchRecord {
  static Map<String, dynamic> person(Person person) {
    final surnameHangul = person.surnameHangul ?? '';
    final surnameHanja = person.surnameHanja ?? '';
    String given(String full, String surname) => surname.isNotEmpty &&
        full.startsWith(surname) && full.length > surname.length
        ? full.substring(surname.length) : full;
    final givenHangul = given(person.nameHangul.trim(), surnameHangul);
    final givenHanja = given(person.nameHanja.trim(), surnameHanja);
    final givenKnown = givenHangul.isNotEmpty || givenHanja.isNotEmpty;
    Map<String, dynamic> form(String lang, String surname, String given) => {
      'lang': lang, 'fullText': '$surname$given',
      'parts': [
        if (surname.isNotEmpty) {'type': 'http://gedcomx.org/Surname', 'value': surname},
        if (given.isNotEmpty) {'type': 'http://gedcomx.org/Given', 'value': given},
      ],
    };
    final forms = [
      if ('$surnameHangul$givenHangul'.isNotEmpty)
        form('ko', surnameHangul, givenHangul),
      if ('$surnameHanja$givenHanja'.isNotEmpty)
        form('ko-Hani', surnameHanja, givenHanja),
    ];
    final notes = <String>[
      if (!givenKnown) '개인 이름 미상. 성씨만 기록됨.',
      if (person.gender == 'M' && (person.spouseHanja?.isNotEmpty == true || person.spouseHangul?.isNotEmpty == true))
        '아내 표시명(실제 개인 이름 아님): ${UnknownSpouseName.wifeDisplayName(person) ?? '미상'}',
      for (final entry in <String, String?>{
        '로마자 표기': person.nameRoman, '字': person.ja, '號': person.ho, '본관': person.bongwan,
        '배우자': person.spouseHanja, '배우자 본관': person.spouseBongwan,
        '배우자 출생': person.spouseBirth, '배우자 사망': person.spouseDeath,
        '배우자 부친': person.spouseFather, '배우자 조부': person.spouseGrandfather,
        '배우자 증조부': person.spouseGreatGrandfather,
        '배우자 외조부': person.spouseMaternalGrandfather,
        '특이사항': person.note, '근거': person.reasonStatement,
        '족보 원문': person.rawText,
        'PDF 페이지': person.sourcePageNumber?.toString(),
      }.entries)
        if (entry.value?.isNotEmpty == true) '${entry.key}: ${entry.value}',
    ];
    Map<String, dynamic> fact(String type, String? date, String? place) => {
      'type': 'http://gedcomx.org/$type',
      if (date?.isNotEmpty == true) 'date': {'original': date},
      if (place?.isNotEmpty == true) 'place': {'original': place},
    };
    return {
      'id': person.id,
      if (person.deathDateSolar?.isNotEmpty == true ||
          person.deathDateLunar?.isNotEmpty == true) 'living': false,
      'gender': {'type': 'http://gedcomx.org/${person.gender == 'M' ? 'Male' : person.gender == 'F' ? 'Female' : 'Unknown'}'},
      if (forms.isNotEmpty) 'names': [{'type': 'http://gedcomx.org/BirthName', 'nameForms': forms}],
      'facts': [
        if (person.birthDateSolar != null || person.birthDateLunar != null || person.birthPlace != null)
          fact('Birth', person.birthDateSolar ?? person.birthDateLunar, person.birthPlace),
        if (person.deathDateSolar != null || person.deathDateLunar != null || person.deathPlace != null)
          fact('Death', person.deathDateSolar ?? person.deathDateLunar, person.deathPlace),
        if (person.burialPlace != null) fact('Burial', null, person.burialPlace),
      ],
      if (notes.isNotEmpty) 'notes': [{'text': notes.join('\n')}],
    };
  }

  static Map<String, dynamic> document(List<Person> persons) {
    final ids = persons.map((p) => p.id).toSet();
    if (ids.length != persons.length) throw StateError('중복 인물 ID');
    return {
      'persons': persons.map(person).toList(),
      'relationships': [
        for (final child in persons)
          for (final parent in [child.fatherId, child.motherId])
            if (parent != null && parent != child.id && ids.contains(parent))
              {'type': 'http://gedcomx.org/ParentChild',
                'person1': {'resource': '#$parent'},
                'person2': {'resource': '#${child.id}'}},
      ],
    };
  }
}
