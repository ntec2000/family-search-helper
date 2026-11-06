import '../models/person.dart';
import 'unknown_spouse_name.dart';
import 'spouse_parent_text.dart';
import 'genealogy.dart';
import 'hanja_dict.dart';

/// A source-scoped candidate. Generated labels never occupy personal-name fields.
class FamilyNameCandidate {
  final String role;
  final String display;
  final String sourcePersonId;
  final bool placeholder;
  final String kind;
  final String gender;
  final String? surnameHanja;
  final String? surnameHangul;
  const FamilyNameCandidate(this.role, this.display, this.sourcePersonId,
      {this.placeholder = false, this.kind = 'self', this.gender = 'U',
      this.surnameHanja, this.surnameHangul});

  String get candidateId => '$sourcePersonId::family::$kind';
  bool get canMaterialize => kind != 'self';

  Person materialize(Person source) {
    if (!canMaterialize || source.id != sourcePersonId) {
      throw StateError('가족 후보의 원본 인물을 확인하세요.');
    }
    final token = Genealogy.parseToken(display);
    final reading = token.$2.isNotEmpty ? token.$2 :
        HanjaDict.instance.toHangul(token.$1);
    final korean = RegExp(r'[㐀-鿿]').hasMatch(reading) ? '' : reading;
    return Person(
      id: candidateId, gender: gender,
      nameHanja: placeholder ? '' : token.$1,
      nameHangul: placeholder ? '' : korean,
      generatedName: placeholder ? display : null,
      surnameHanja: surnameHanja, surnameHangul: surnameHangul,
      bongwan: kind == 'spouse' ? source.spouseBongwan : null,
      birthDateLunar: kind == 'spouse' ? source.spouseBirth : null,
      deathDateLunar: kind == 'spouse' ? source.spouseDeath : null,
      sourceImagePath: source.sourceImagePath,
      sourceDocumentPath: source.sourceDocumentPath,
      sourcePageNumber: source.sourcePageNumber,
      rawText: source.rawText,
      reasonStatement: '가족 이름 후보 · 원본 인물 ID: ${source.id} · $role'
          '${placeholder ? " · 생성 표시명(원문 개인 이름 아님)" : ""}',
      note: '$role · 원문 및 가족관계 검토 필요.'
          '${placeholder ? " 개인 이름 미기재로 생성한 표시명: $display." : ""}'
          '${(source.note ?? "").isEmpty ? "" : "\n원본 참고: ${source.note}"}',
    );
  }
}

class FamilyNameCandidates {
  static String _value(String? text) => (text ?? '').trim();
  static String _readable(String text) => HanjaDict.instance.toHangul(text);

  static (String?, String?) _spouseSurname(Person person) {
    final explicit = person.gender == 'F'
        ? Genealogy.personalNameSurname(person.spouseHanja ?? '')
        : Genealogy.spouseSurname(person.spouseHanja);
    if (explicit != null) return (explicit.$1, explicit.$2);
    final korean = RegExp(r'^([가-힣]{1,2})씨$')
        .firstMatch(_value(person.spouseHangul));
    return (null, korean?.group(1));
  }

  static List<FamilyNameCandidate> fromPerson(Person person) {
    final result = <FamilyNameCandidate>[];
    result.add(FamilyNameCandidate('본인', person.displayName, person.id,
        placeholder: person.nameHangul.isEmpty && person.nameHanja.isEmpty,
        gender: person.gender));
    final family = _spouseSurname(person);
    final spouse = _value(person.spouseHangul).isNotEmpty
        ? _value(person.spouseHangul) : _value(person.spouseHanja);
    if (spouse.isNotEmpty) {
      final surnameOnly = spouse.endsWith('씨') || spouse.endsWith('氏');
      final generated = person.gender == 'M' && surnameOnly;
      final display = generated
          ? (UnknownSpouseName.wifeDisplayName(person) ?? spouse) : spouse;
      result.add(FamilyNameCandidate(person.gender == 'F' ? '남편 후보' : '배우자 후보',
          display, person.id, placeholder: generated, kind: 'spouse',
          gender: person.gender == 'F' ? 'M' : person.gender == 'M' ? 'F' : 'U',
          surnameHanja: family.$1, surnameHangul: family.$2));
    } else if (UnknownSpouseName.hasSpouseEvidence(person) &&
        (person.gender == 'M' || person.gender == 'F')) {
      final display = person.gender == 'M'
          ? UnknownSpouseName.wifeDisplayName(person) ?? '이름 미상'
          : '${person.displayName}의 남편';
      result.add(FamilyNameCandidate(person.gender == 'F' ? '남편 후보' : '배우자 후보',
          display, person.id, placeholder: true, kind: 'spouse',
          gender: person.gender == 'F' ? 'M' : 'F',
          surnameHanja: family.$1, surnameHangul: family.$2));
    }

    void relative(String kind, String role, String raw, {bool paternal = true,
        String? knownWife}) {
      if (raw.isEmpty) return;
      final combined = paternal
          ? SpouseParentText.candidatePaternalName(person, raw) : raw;
      final ownSurname = Genealogy.personalNameSurname(combined);
      final surnameHanja = ownSurname?.$1 ?? (paternal ? family.$1 : null);
      final surnameHangul = ownSurname?.$2 ?? (paternal ? family.$2 : null);
      final clan = combined.endsWith('氏') ? Genealogy.spouseSurname(combined)
          : !paternal && combined.length == 1
              ? Genealogy.spouseSurname('$combined氏') : null;
      final maleDisplay = clan == null ? combined : '${clan.$2}씨';
      result.add(FamilyNameCandidate(
          combined == raw ? role : '$role · 성씨 추정',
          maleDisplay, person.id, kind: kind, gender: 'M', placeholder: clan != null,
          surnameHanja: clan?.$1 ?? surnameHanja,
          surnameHangul: clan?.$2 ?? surnameHangul));
      final wife = _value(knownWife);
      if (wife.isNotEmpty) {
        final clan = Genealogy.spouseSurname(wife);
        final isLabel = wife.endsWith('의 부인') || wife.endsWith('씨') ||
            wife.endsWith('氏') || wife.contains('이름 미상');
        result.add(FamilyNameCandidate('배우자의 어머니 후보', wife, person.id,
            kind: '${kind}Wife', gender: 'F', placeholder: isLabel,
            surnameHanja: clan?.$1, surnameHangul: clan?.$2 ??
                RegExp(r'^([가-힣]{1,2})씨$').firstMatch(wife)?.group(1)));
      } else {
        var full = clan == null ? _readable(combined) : '${clan.$2}씨';
        // Only combine a separately recorded Korean family name after reading.
        if (paternal && surnameHangul != null &&
            RegExp(r'^[가-힣]+$').hasMatch(full) && !full.startsWith(surnameHangul)) {
          full = '$surnameHangul$full';
        }
        result.add(FamilyNameCandidate(
            kind == 'father' ? '배우자의 어머니 · 이름 미상' : '$role의 부인 · 이름 미상',
            '$full의 부인', person.id, placeholder: true,
            kind: '${kind}Wife', gender: 'F'));
      }
    }

    relative('father', '배우자의 아버지 후보', _value(person.spouseFather),
        knownWife: person.spouseMother);
    if (_value(person.spouseFather).isEmpty && _value(person.spouseMother).isNotEmpty) {
      final mother = _value(person.spouseMother);
      final clan = Genealogy.spouseSurname(mother);
      result.add(FamilyNameCandidate('배우자의 어머니 후보',
          mother, person.id, kind: 'mother', gender: 'F',
          placeholder: mother.endsWith('씨') || mother.endsWith('氏') ||
              mother.endsWith('의 부인') || mother.contains('이름 미상'),
          surnameHanja: clan?.$1, surnameHangul: clan?.$2 ??
              RegExp(r'^([가-힣]{1,2})씨$').firstMatch(mother)?.group(1)));
    }
    relative('grandfather', '배우자의 조부 후보', _value(person.spouseGrandfather));
    relative('greatGrandfather', '배우자의 증조부 후보',
        _value(person.spouseGreatGrandfather));
    relative('maternalGrandfather', '배우자의 외조부 후보',
        _value(person.spouseMaternalGrandfather), paternal: false);
    return result;
  }
}
