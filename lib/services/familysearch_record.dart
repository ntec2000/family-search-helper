import '../models/person.dart';
import 'unknown_spouse_name.dart';
import 'ganzhi_year_label.dart';
import 'export_relationship_validation.dart';
import 'name_export_review.dart';

/// 전송과 파일 내보내기에서 같은 성/이름·원문 날짜 필드를 사용한다.
class FamilySearchRecord {
  static Map<String, dynamic> person(Person person) {
    String? firstNonBlank(String? first, String? second) {
      if (first?.trim().isNotEmpty == true) return first;
      if (second?.trim().isNotEmpty == true) return second;
      return null;
    }
    final birthDate = firstNonBlank(person.birthDateSolar, person.birthDateLunar);
    final deathDate = firstNonBlank(person.deathDateSolar, person.deathDateLunar);
    final surnameHangul = person.surnameHangul ?? '';
    final surnameHanja = person.surnameHanja ?? '';
    String given(String full, String surname) => surname.isNotEmpty &&
        full.startsWith(surname) && full.length > surname.length
        ? full.substring(surname.length) : full;
    final givenHangul = given(person.nameHangul.trim(), surnameHangul);
    final givenHanja = given(person.nameHanja.trim(), surnameHanja);
    final givenKnown = givenHangul.isNotEmpty || givenHanja.isNotEmpty;
    final ambiguousHangul = NameExportReview.overlaps(person.nameHangul, surnameHangul);
    final ambiguousHanja = NameExportReview.overlaps(person.nameHanja, surnameHanja);
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
      if (ambiguousHangul || ambiguousHanja)
        '성씨와 입력 이름의 시작이 같아 전체 이름인지 개인 이름인지 원본 확인 필요.',
      if (ambiguousHangul) '입력된 이름(한글): ${person.nameHangul}',
      if (ambiguousHanja) '입력된 이름(한자): ${person.nameHanja}',
      if (!givenKnown) '개인 이름 미상. 성씨만 기록됨.',
      if (GanzhiYearLabel.fromDate(person.birthDateLunar) case final label?)
        '출생 간지 한글: $label',
      if (GanzhiYearLabel.fromDate(person.deathDateLunar) case final label?)
        '사망 간지 한글: $label',
      if (GanzhiYearLabel.fromDate(person.spouseBirth) case final label?)
        '배우자 출생 간지 한글: $label',
      if (GanzhiYearLabel.fromDate(person.spouseDeath) case final label?)
        '배우자 사망 간지 한글: $label',
      if (person.gender == 'M' && UnknownSpouseName.hasSpouseEvidence(person) && !UnknownSpouseName.hasPersonalNameCandidate(person))
        '아내 표시명(실제 개인 이름 아님): ${UnknownSpouseName.wifeDisplayName(person) ?? '미상'}',
      for (final entry in <String, String?>{
        '로마자 표기': person.nameRoman, '字': person.ja, '號': person.ho, '본관': person.bongwan,
        '묘 좌향': person.burialOrientation,
        '배우자': person.spouseHanja, '배우자 한글': person.spouseHangul,
        '배우자 본관': person.spouseBongwan,
        '출생 원문(간지·음력)': person.birthDateLunar,
        '사망 원문(간지·음력)': person.deathDateLunar,
        '배우자 출생': person.spouseBirth, '배우자 사망': person.spouseDeath,
        '배우자 부친': person.spouseFather, '배우자 모친': person.spouseMother,
        '배우자 조부': person.spouseGrandfather,
        '배우자 증조부': person.spouseGreatGrandfather,
        '배우자 외조부': person.spouseMaternalGrandfather,
        '특이사항': person.note, '근거': person.reasonStatement,
        '족보 원문': person.rawText,
        'PDF 페이지': person.sourcePageNumber?.toString(),
      }.entries)
        if (entry.value?.trim().isNotEmpty == true) '${entry.key}: ${entry.value}',
    ];
    Map<String, dynamic> fact(String type, String? date, String? place) => {
      'type': 'http://gedcomx.org/$type',
      if (date?.trim().isNotEmpty == true) 'date': {'original': date},
      if (place?.trim().isNotEmpty == true) 'place': {'original': place},
    };
    return {
      'id': person.id,
      if (deathDate != null) 'living': false,
      'gender': {'type': 'http://gedcomx.org/${person.gender == 'M' ? 'Male' : person.gender == 'F' ? 'Female' : 'Unknown'}'},
      if (forms.isNotEmpty) 'names': [{'type': 'http://gedcomx.org/BirthName', 'nameForms': forms}],
      'facts': [
        if (birthDate != null || person.birthPlace?.trim().isNotEmpty == true)
          fact('Birth', birthDate, person.birthPlace),
        if (deathDate != null || person.deathPlace?.trim().isNotEmpty == true)
          fact('Death', deathDate, person.deathPlace),
        if (person.burialPlace?.trim().isNotEmpty == true)
          fact('Burial', null, person.burialPlace),
      ],
      if (notes.isNotEmpty) 'notes': [{'text': notes.join('\n')}],
    };
  }

  /// 부부 관계는 검토자가 확인한 ID 쌍만 전달한다. OCR 메모에서 추정하지 않는다.
  static Map<String, dynamic> document(List<Person> persons,
      {List<(String, String)> reviewedCouples = const []}) {
    final ids = persons.map((p) => p.id).toSet();
    if (ids.length != persons.length) throw StateError('중복 인물 ID');
    for (final child in persons) {
      if (child.fatherId == child.id || child.motherId == child.id) {
        throw StateError('인물 ${child.id}이 자신의 부모로 지정되어 있습니다.');
      }
      if (child.fatherId != null && child.fatherId == child.motherId &&
          ids.contains(child.fatherId)) {
        throw StateError('같은 인물이 아버지와 어머니로 지정되어 있습니다.');
      }
    }
    ExportRelationshipValidation.rejectParentCycles(persons);
    final uniqueCouples = <(String, String)>{};
    for (final (first, second) in reviewedCouples) {
      if (first.isEmpty || second.isEmpty || first == second ||
          !ids.contains(first) || !ids.contains(second)) {
        throw StateError('부부 관계의 인물 ID를 확인하세요.');
      }
      final key = first.compareTo(second) < 0 ? (first, second) : (second, first);
      if (!uniqueCouples.add(key)) throw StateError('중복 부부 관계');
    }
    return {
      'persons': persons.map(person).toList(),
      'relationships': [
        for (final (first, second) in reviewedCouples)
          {'type': 'http://gedcomx.org/Couple',
            'person1': {'resource': '#$first'},
            'person2': {'resource': '#$second'}},
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
