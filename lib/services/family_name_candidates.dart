import '../models/person.dart';
import 'unknown_spouse_name.dart';
import 'spouse_parent_text.dart';

/// 검토 화면 전용 목록. 별도 인물이나 관계를 저장하지 않는다.
class FamilyNameCandidate {
  final String role;
  final String display;
  final String sourcePersonId;
  final bool placeholder;
  const FamilyNameCandidate(this.role, this.display, this.sourcePersonId,
      {this.placeholder = false});
}

class FamilyNameCandidates {
  static List<FamilyNameCandidate> fromPerson(Person person) {
    final result = <FamilyNameCandidate>[];
    String value(String? s) => (s ?? '').trim();
    final surname = value(person.surnameHangul);
    final name = value(person.nameHangul);
    final hanja = value(person.nameHanja);
    final primary = name.isNotEmpty
        ? (surname.isNotEmpty && !name.startsWith(surname) ? '$surname$name' : name)
        : (hanja.isNotEmpty ? hanja : (surname.isNotEmpty ? '$surname씨' : '이름 미상'));
    result.add(FamilyNameCandidate('본인', primary, person.id,
        placeholder: name.isEmpty && hanja.isEmpty));
    final spouse = value(person.spouseHangul).isNotEmpty
        ? value(person.spouseHangul) : value(person.spouseHanja);
    if (spouse.isNotEmpty) {
      final surnameOnly = spouse.endsWith('씨') || spouse.endsWith('氏');
      final usePlaceholder = person.gender == 'M' && surnameOnly;
      final display = usePlaceholder
          ? (UnknownSpouseName.wifeDisplayName(person) ?? spouse) : spouse;
      result.add(FamilyNameCandidate(person.gender == 'F' ? '남편 후보' : '배우자 후보',
          display, person.id, placeholder: usePlaceholder));
    } else if (person.gender == 'M' && UnknownSpouseName.hasSpouseEvidence(person)) {
      final display = UnknownSpouseName.wifeDisplayName(person) ?? '이름 미상';
      result.add(FamilyNameCandidate('배우자 후보', display, person.id,
          placeholder: true));
    }
    final father = value(person.spouseFather);
    final fatherDisplay = SpouseParentText.candidateFatherName(person);
    final inferredSurname = fatherDisplay != father;
    if (father.isNotEmpty) {
      result.add(FamilyNameCandidate(
          inferredSurname ? '배우자의 아버지 후보 · 성씨 추정' : '배우자의 아버지 후보',
          fatherDisplay, person.id));
    }
    final mother = value(person.spouseMother);
    if (mother.isNotEmpty) {
      result.add(FamilyNameCandidate('배우자의 어머니 후보', mother, person.id));
    } else if (father.isNotEmpty) {
      result.add(FamilyNameCandidate('배우자의 어머니 · 이름 미상', '$fatherDisplay의 부인',
          person.id, placeholder: true));
    }
    for (final entry in <String, String?>{
      '배우자의 조부 후보': person.spouseGrandfather,
      '배우자의 증조부 후보': person.spouseGreatGrandfather,
      '배우자의 외조부 후보': person.spouseMaternalGrandfather,
    }.entries) {
      final name = value(entry.value);
      if (name.isNotEmpty) {
        result.add(FamilyNameCandidate(entry.key, name, person.id));
      }
    }
    return result;
  }
}
