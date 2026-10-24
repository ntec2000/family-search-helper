import '../models/person.dart';

/// Only an explicitly reviewed relationship can be linked.
/// OCR sequence alone is not sufficient evidence.
class ParentChildReview {
  static String? conflict(Person parent, Person child) {
    if (parent.id == child.id) return '동일 인물은 자신의 부모가 될 수 없습니다.';
    if (parent.gender != 'M' && parent.gender != 'F') {
      return '부모의 성별을 먼저 확인하세요.';
    }
    if (parent.sega != null && child.sega != null &&
        child.sega != parent.sega! + 1) {
      return '부모와 자녀의 세대가 연속하지 않습니다.';
    }
    if (parent.gender == 'M' &&
        child.fatherId != null && child.fatherId != parent.id) {
      return '기존 부친 연결과 충돌합니다.';
    }
    if (parent.gender == 'F' &&
        child.motherId != null && child.motherId != parent.id) {
      return '기존 모친 연결과 충돌합니다.';
    }
    return null;
  }

  static void unlink(Person parent, Person child) {
    if (child.fatherId == parent.id) child.fatherId = null;
    if (child.motherId == parent.id) child.motherId = null;
    parent.childrenIds.remove(child.id);
  }

  static void detachExcluded(Person excluded, Iterable<Person> remaining) {
    for (final person in remaining) {
      unlink(excluded, person);
      unlink(person, excluded);
    }
  }

  static bool hasAdoptionAnnotation(Person person) =>
      (person.note ?? '').contains('出系');

  static void restoreReviewedLink(Person parent, Person child) {
    if (parent.gender == 'M' && (child.fatherId == null || child.fatherId == parent.id)) {
      applyReviewedLink(parent, child);
    } else if (parent.gender == 'F' && (child.motherId == null || child.motherId == parent.id)) {
      applyReviewedLink(parent, child);
    }
  }

  static void applyReviewedLink(Person parent, Person child) {
    final error = conflict(parent, child);
    if (error != null) throw StateError(error);
    if (parent.gender == 'M') {
      child.fatherId = parent.id;
    } else {
      child.motherId = parent.id;
    }
    if (!parent.childrenIds.contains(child.id)) {
      parent.childrenIds.add(child.id);
    }
  }
}
