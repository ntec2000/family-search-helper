/// 저장 전 가족관계 참조 무결성을 검사하는 순수 검증기.
/// 이 파일은 기존 DB나 인물 레코드를 수정하지 않습니다.
/// 호출부에서 오류가 없을 때만 트랜잭션 저장을 수행해야 합니다.
class PersonRelationValidator {
  const PersonRelationValidator._();

  static List<String> validate({
    required String personId,
    String? fatherId,
    String? motherId,
    Iterable<String> childrenIds = const [],
    Iterable<String> sonsInLawIds = const [],
    Iterable<String> inLawsIds = const [],
    required Set<String> knownPersonIds,
    Map<String, String> knownPersonGenders = const {},
  }) {
    final errors = <String>[];
    final id = personId.trim();
    if (id.isEmpty) {
      errors.add('인물 ID가 비어 있습니다.');
      return errors;
    }

    void check(String label, String? value) {
      if (value == null || value.trim().isEmpty) return;
      final target = value.trim();
      if (target == id) {
        errors.add('$label 관계에 본인 ID를 지정할 수 없습니다.');
      } else if (!knownPersonIds.contains(target)) {
        errors.add('$label 관계 대상 ID가 존재하지 않습니다: $target');
      }
    }

    check('아버지', fatherId);
    check('어머니', motherId);
    void checkParentGender(String label, String? value, String expected) {
      final target = value?.trim();
      if (target == null || target.isEmpty ||
          !knownPersonGenders.containsKey(target)) return;
      if (knownPersonGenders[target] != expected) {
        errors.add('$label 관계 대상의 성별을 먼저 확인하세요: $target');
      }
    }
    checkParentGender('아버지', fatherId, 'M');
    checkParentGender('어머니', motherId, 'F');
    if (fatherId != null &&
        motherId != null &&
        fatherId.trim().isNotEmpty &&
        fatherId.trim() == motherId.trim()) {
      errors.add('아버지와 어머니가 동일한 인물 ID입니다.');
    }

    void checkMany(String label, Iterable<String> ids) {
      final seen = <String>{};
      for (final raw in ids) {
        final target = raw.trim();
        if (target.isEmpty) {
          errors.add('$label 관계에 빈 ID가 있습니다.');
          continue;
        }
        if (!seen.add(target)) {
          errors.add('$label 관계에 중복 ID가 있습니다: $target');
        }
        check(label, target);
      }
    }

    checkMany('자녀', childrenIds);
    checkMany('사위', sonsInLawIds);
    checkMany('사돈', inLawsIds);
    return errors;
  }
}
