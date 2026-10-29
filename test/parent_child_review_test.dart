import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/parent_child_review.dart';

void main() {
  Person person(String id, int generation, {String gender = 'M'}) =>
      Person(id: id, nameHanja: id, gender: gender, sega: generation);

  test('checks long ancestor chains with one-way child references', () {
    final people = List.generate(150, (i) =>
        Person(id: 'person-$i', gender: 'M'));
    for (var i = 0; i < people.length - 1; i++) {
      people[i].childrenIds.add(people[i + 1].id);
    }
    expect(ParentChildReview.cycleConflict(
        people.last, people.first, people), contains('순환'));
    expect(ParentChildReview.cycleConflict(
        people.first, people.last, people), isNull);
    expect(people.first.fatherId, isNull);
    expect(people.last.childrenIds, isEmpty);
  });

  test('blocks a two-person cycle before changing either relationship', () {
    final first = Person(id: 'first', gender: 'M');
    final second = Person(id: 'second', gender: 'M');
    ParentChildReview.applyReviewedLink(first, second);
    expect(ParentChildReview.cycleConflict(second, first, [first, second]),
        contains('순환'));
    expect(first.fatherId, isNull);
    expect(second.fatherId, first.id);
    expect(first.childrenIds, [second.id]);
  });

  test('blocks an indirect cycle across three generations', () {
    final grandparent = Person(id: 'grandparent', gender: 'M');
    final parent = Person(id: 'parent', gender: 'M');
    final child = Person(id: 'child', gender: 'M');
    ParentChildReview.applyReviewedLink(grandparent, parent);
    ParentChildReview.applyReviewedLink(parent, child);
    expect(ParentChildReview.cycleConflict(child, grandparent,
        [grandparent, parent, child]), contains('순환'));
    expect(ParentChildReview.cycleConflict(grandparent, child,
        [grandparent, parent, child]), isNull);
  });

  test('detects cycles from one-way children lists', () {
    final first = Person(id: 'first', gender: 'M');
    final second = Person(id: 'second', gender: 'M');
    first.childrenIds.add(second.id);
    expect(ParentChildReview.cycleConflict(second, first, [first, second]),
        contains('순환'));
  });

  test('rejects cyclic parent references without generation data', () {
    final first = Person(id: 'first', nameHanja: '甲', gender: 'M');
    final second = Person(id: 'second', nameHanja: '乙', gender: 'M');
    first.fatherId = second.id;
    second.childrenIds.add(first.id);
    second.fatherId = first.id;
    first.childrenIds.add(second.id);
    final errors = ParentChildReview.validateReviewedBatch([first, second]);
    expect(errors.any((error) => error.contains('순환 부모 관계')), isTrue);
  });

  test('invalid parent assignments are flagged', () {
    final child = person('child', 22);
    child.fatherId = 'parent';
    child.motherId = 'parent';
    expect(ParentChildReview.validateReviewedBatch([child]), isNotEmpty);
    child.fatherId = child.id;
    child.motherId = null;
    expect(ParentChildReview.validateReviewedBatch([child]), isNotEmpty);
  });

  test('page 224 verified paternal chains', () {
    final cheuk = person('昃', 20);
    final gyeok = person('格', 21);
    final haek = person('核', 21);
    final seonggap = person('聖甲', 22);
    final hyeono = person('顯五', 22);
    final seungyeol = person('承烈', 23);
    final hyeondong = person('賢東', 24);
    ParentChildReview.applyReviewedLink(cheuk, gyeok);
    ParentChildReview.applyReviewedLink(cheuk, haek);
    ParentChildReview.applyReviewedLink(gyeok, seonggap);
    ParentChildReview.applyReviewedLink(haek, hyeono);
    ParentChildReview.applyReviewedLink(hyeono, seungyeol);
    ParentChildReview.applyReviewedLink(seungyeol, hyeondong);
    expect(cheuk.childrenIds, containsAll(['格', '核']));
    expect(seonggap.fatherId, '格');
    expect(hyeondong.fatherId, '承烈');
  });

  test('reject generation mismatch and existing father conflict', () {
    final father = person('昃', 20);
    final child = person('顯五', 22);
    expect(ParentChildReview.conflict(father, child), isNotNull);
    child.sega = 21;
    child.fatherId = 'another';
    expect(ParentChildReview.conflict(father, child), isNotNull);
    expect(child.fatherId, 'another');
  });

  test('adoption annotation never changes father automatically', () {
    final child = person('承勳', 23);
    child.note = '出系 顯龍后';
    child.fatherId = '顯五';
    expect(ParentChildReview.hasAdoptionAnnotation(child), isTrue);
    expect(child.fatherId, '顯五');
  });

  test('unlink and restore preserves confirmed relationship', () {
    final father = person('核', 21);
    final child = person('顯五', 22);
    ParentChildReview.applyReviewedLink(father, child);
    father.childrenIds.add(child.id);
    ParentChildReview.unlink(father, child);
    expect(child.fatherId, isNull);
    expect(father.childrenIds, isEmpty);
    expect(child.fatherId, isNull);
    ParentChildReview.restoreReviewedLink(father, child);
    expect(child.fatherId, father.id);
    expect(father.childrenIds, contains(child.id));
  });

  test('unnamed daughter remains unnamed', () {
    final father = person('昃', 20);
    final daughter = Person(id: 'daughter-1', gender: 'F',
        surnameHanja: '李', surnameHangul: '이', sega: 21);
    ParentChildReview.applyReviewedLink(father, daughter);
    expect(daughter.nameHanja, isEmpty);
    expect(daughter.nameHangul, isEmpty);
    expect(daughter.fatherId, '昃');
    expect(father.childrenIds, contains(daughter.id));
  });
  test('review copy does not mutate original OCR candidate or family links', () {
    final original = person('昃', 20);
    original.nameHangul = '이측';
    original.rawText = '昃';
    original.childrenIds.add('格');

    final reviewed = Person.fromMap(original.toMap());
    reviewed.nameHangul = '수정 후보';
    reviewed.childrenIds.remove('格');
    reviewed.fatherId = '검토 중 임시 관계';

    expect(original.nameHangul, '이측');
    expect(original.rawText, '昃');
    expect(original.childrenIds, contains('格'));
    expect(original.fatherId, isNull);
    expect(reviewed.nameHangul, '수정 후보');
  });

  test('restoring an existing father link repairs the reverse list', () {
    final father = person('核', 21);
    final child = person('顯五', 22);
    child.fatherId = father.id;
    ParentChildReview.restoreReviewedLink(father, child);
    ParentChildReview.restoreReviewedLink(father, child);
    expect(father.childrenIds, [child.id]);
    expect(child.fatherId, father.id);
  });

  test('unlink father preserves mother link', () {
    final father = person('father', 21);
    final mother = person('mother', 21, gender: 'F');
    final child = person('child', 22);
    ParentChildReview.applyReviewedLink(father, child);
    ParentChildReview.applyReviewedLink(mother, child);
    ParentChildReview.unlink(father, child);
    expect(child.fatherId, isNull);
    expect(child.motherId, mother.id);
    expect(mother.childrenIds, contains(child.id));
    expect(father.childrenIds, isEmpty);
    ParentChildReview.restoreReviewedLink(father, child);
    expect(child.fatherId, father.id);
    expect(child.motherId, mother.id);
    expect(father.childrenIds, contains(child.id));
    expect(mother.childrenIds, contains(child.id));
    expect(father.childrenIds.where((id) => id == child.id).length, 1);
    expect(ParentChildReview.validateReviewedBatch([father, mother, child]), isEmpty);
    father.childrenIds.add(child.id);
    expect(ParentChildReview.validateReviewedBatch([father, mother, child]), isNotEmpty);
    father.childrenIds.removeLast();
    child.fatherId = mother.id;
    expect(ParentChildReview.validateReviewedBatch([father, mother, child]), isNotEmpty);
    child.fatherId = father.id;
    father.childrenIds.clear();
    expect(ParentChildReview.validateReviewedBatch([father, mother, child]), isNotEmpty);
    father.childrenIds.add(child.id);
    child.fatherId = null;
    expect(ParentChildReview.validateReviewedBatch([father, mother, child]), isNotEmpty);
  });

  test('동명이인도 고유 ID 기준으로 부모를 연결한다', () {
    final first = Person(id: 'p1', nameHanja: '格', gender: 'M', sega: 20);
    final second = Person(id: 'p10', nameHanja: '格', gender: 'M', sega: 20);
    final child = Person(id: 'child', gender: 'M', sega: 21);
    ParentChildReview.applyReviewedLink(second, child);
    expect(child.fatherId, 'p10');
    expect(second.childrenIds, ['child']);
    expect(first.childrenIds, isEmpty);
    expect(ParentChildReview.validateReviewedBatch([first, second, child]), isEmpty);
  });

  test('성별 미확인과 세대 불일치 후보는 부모로 허용하지 않는다', () {
    final child = Person(id: 'child', gender: 'M', sega: 21);
    final unknown = Person(id: 'unknown', gender: 'U', sega: 20);
    final wrongGeneration = Person(id: 'wrong', gender: 'M', sega: 18);
    expect(ParentChildReview.conflict(unknown, child), isNotNull);
    expect(ParentChildReview.conflict(wrongGeneration, child), isNotNull);
    expect(child.fatherId, isNull);
    expect(child.motherId, isNull);
  });

  test('기존 부친과 충돌하는 다른 후보를 거부하고 관계를 보존한다', () {
    final father = Person(id: 'father', gender: 'M', sega: 20);
    final other = Person(id: 'other', gender: 'M', sega: 20);
    final child = Person(id: 'child', gender: 'M', sega: 21);
    ParentChildReview.applyReviewedLink(father, child);
    expect(ParentChildReview.conflict(other, child), isNotNull);
    expect(child.fatherId, 'father');
    expect(father.childrenIds, ['child']);
    expect(other.childrenIds, isEmpty);
  });

  test('동명이인 두 명 중 잘못된 부친 연결을 감지한다', () {
    final first = Person(id: 'person-1', nameHanja: '格', gender: 'M', sega: 20);
    final second = Person(id: 'person-2', nameHanja: '格', gender: 'M', sega: 20);
    final child = Person(id: 'child', gender: 'M', sega: 21);
    ParentChildReview.applyReviewedLink(second, child);
    first.childrenIds.add(child.id);
    final errors = ParentChildReview.validateReviewedBatch([first, second, child]);
    expect(errors.any((error) => error.contains('역방향')), isTrue);
    expect(child.fatherId, second.id);
    expect(second.childrenIds, [child.id]);
  });

  test('부친과 모친을 모두 연결해도 자녀 정보는 유지된다', () {
    final father = Person(id: 'father', gender: 'M', sega: 20);
    final mother = Person(id: 'mother', gender: 'F', sega: 20);
    final child = Person(id: 'child', nameHanja: '核', gender: 'M', sega: 21,
        rawText: '核 字君平');
    ParentChildReview.applyReviewedLink(father, child);
    ParentChildReview.applyReviewedLink(mother, child);
    expect(ParentChildReview.validateReviewedBatch([father, mother, child]), isEmpty);
    expect(child.rawText, '核 字君平');
    expect(child.nameHanja, '核');
    expect(child.fatherId, 'father');
    expect(child.motherId, 'mother');
  });

  test('역방향 자녀 목록의 세대 불일치를 감지한다', () {
    final parent = Person(id: 'p20', gender: 'M', sega: 20);
    final child = Person(id: 'p22', gender: 'M', sega: 22);
    parent.childrenIds.add(child.id);
    final issues = ParentChildReview.validateReviewedBatch([parent, child]);
    expect(issues.any((issue) => issue.contains('자녀 세대 불일치')), isTrue);
    expect(child.fatherId, isNull);
  });

  test('세대가 올바른 역방향 연결은 세대 불일치로 신고하지 않는다', () {
    final parent = Person(id: 'p20', gender: 'M', sega: 20);
    final child = Person(id: 'p21', gender: 'M', sega: 21);
    ParentChildReview.applyReviewedLink(parent, child);
    final issues = ParentChildReview.validateReviewedBatch([parent, child]);
    expect(issues.any((issue) => issue.contains('세대 불일치')), isFalse);
    expect(issues, isEmpty);
  });

  test('중복 자녀 ID를 감지하고 기존 관계는 유지한다', () {
    final parent = Person(id: 'father', gender: 'M', sega: 20);
    final child = Person(id: 'child', gender: 'M', sega: 21);
    ParentChildReview.applyReviewedLink(parent, child);
    parent.childrenIds.add(child.id);
    final issues = ParentChildReview.validateReviewedBatch([parent, child]);
    expect(issues.any((issue) => issue.contains('중복 자녀 연결')), isTrue);
    expect(child.fatherId, parent.id);
    expect(parent.childrenIds, ['child', 'child']);
  });

}
