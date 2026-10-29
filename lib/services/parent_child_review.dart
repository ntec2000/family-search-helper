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

  /// Returns an error if the proposed parent is already a descendant of the
  /// child. Checks both parent references and child lists without changing data.
  static String? cycleConflict(
      Person parent, Person child, Iterable<Person> persons) {
    if (parent.id == child.id) {
      return '동일 인물은 자신의 부모가 될 수 없습니다.';
    }
    final entries = persons.toList(growable: false);
    final byId = {for (final person in entries) person.id: person};
    // Index reverse links once rather than scanning the entire genealogy
    // for every ancestor visited in a large family tree.
    final parentsByChild = <String, List<String>>{};
    for (final candidate in entries) {
      for (final childId in candidate.childrenIds) {
        parentsByChild.putIfAbsent(childId, () => <String>[]).add(candidate.id);
      }
    }
    final visited = <String>{};
    final pending = <String>[parent.id];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!visited.add(id)) continue;
      if (id == child.id) {
        return '순환 가족관계가 발생합니다. 부모와 자녀의 연결을 확인하세요.';
      }
      final current = byId[id];
      if (current == null) continue;
      for (final ancestorId in [current.fatherId, current.motherId]) {
        if (ancestorId != null && ancestorId.isNotEmpty) {
          pending.add(ancestorId);
        }
      }
      // A recorded parent-to-child link also proves ancestry, even when
      // the reciprocal parent ID has not yet been filled in.
      pending.addAll(parentsByChild[id] ?? const <String>[]);
    }
    return null;
  }

  static void unlink(Person parent, Person child) {
    if (child.fatherId == parent.id) child.fatherId = null;
    if (child.motherId == parent.id) child.motherId = null;
    parent.childrenIds.removeWhere((id) => id == child.id);
  }

  static void detachExcluded(Person excluded, Iterable<Person> remaining) {
    for (final person in remaining) {
      unlink(excluded, person);
      unlink(person, excluded);
    }
  }

  /// Checks only relationships within the reviewed batch; external IDs are
  /// left untouched because their records may already exist in storage.
  static List<String> validateReviewedBatch(Iterable<Person> persons) {
    final entries = persons.toList();
    final byId = <String, Person>{};
    final issues = <String>[];
    for (final person in entries) {
      if (person.id.trim().isEmpty) {
        issues.add('빈 인물 ID가 있습니다.');
        continue;
      }
      if (byId.containsKey(person.id)) {
        issues.add('중복 인물 ID: ${person.id}');
      } else {
        byId[person.id] = person;
      }
    }
    for (final child in entries) {
      if (child.fatherId != null && child.fatherId == child.motherId) {
        issues.add('동일 인물이 양쪽 부모로 지정됨: ${child.id}');
      }
      if (child.fatherId == child.id || child.motherId == child.id) {
        issues.add('자기 자신을 부모로 지정함: ${child.id}');
      }
    }
    // Reject a parent reference to a known person with the wrong generation,
    // even if the reverse children list is missing.
    for (final child in entries) {
      for (final parentId in [child.fatherId, child.motherId]) {
        if (parentId == null) continue;
        final parent = byId[parentId];
        if (parent == null) continue;
        if ((parentId == child.fatherId && parent.gender != 'M') ||
            (parentId == child.motherId && parent.gender != 'F') ||
            conflict(parent, child) != null ||
            !parent.childrenIds.contains(child.id)) {
          issues.add('부모-자녀 연결 확인 필요: $parentId → ${child.id}');
        }
      }
    }
    for (final parent in entries) {
      for (final childId in parent.childrenIds) {
        final child = byId[childId];
        if (child == null) continue;
        final linked = parent.gender == 'M'
            ? child.fatherId == parent.id
            : parent.gender == 'F' && child.motherId == parent.id;
        if (!linked) {
          issues.add('자녀-부모 역방향 연결 확인 필요: ${parent.id} → $childId');
        }
      }
    }
    for (final parent in entries) {
      for (final childId in parent.childrenIds) {
        final child = byId[childId];
        if (child == null) continue;
        if (parent.sega != null && child.sega != null &&
            child.sega != parent.sega! + 1) {
          issues.add('자녀 세대 불일치: ${parent.id} → $childId');
        }
      }
    }
    for (final parent in entries) {
      final ids = parent.childrenIds;
      if (ids.length != ids.toSet().length) {
        issues.add('중복 자녀 연결: ${parent.id}');
      }
    }
    // Detect parent cycles even when generation numbers are unavailable.
    for (final person in entries) {
      final visited = <String>{};
      final pending = <String>[person.id];
      while (pending.isNotEmpty) {
        final id = pending.removeLast();
        if (!visited.add(id)) continue;
        final current = byId[id];
        if (current == null) continue;
        for (final parentId in [current.fatherId, current.motherId]) {
          if (parentId == null || !byId.containsKey(parentId)) continue;
          if (parentId == person.id) {
            issues.add('순환 부모 관계 확인 필요: ${person.id}');
            pending.clear();
            break;
          }
          pending.add(parentId);
        }
      }
    }
    return issues;
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
