import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/parent_child_review.dart';

void main() {
  Person person(String id, int generation, {String gender = 'M'}) =>
      Person(id: id, nameHanja: id, gender: gender, sega: generation);

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
    father.childrenIds.clear();
    expect(ParentChildReview.validateReviewedBatch([father, mother, child]), isNotEmpty);
  });

}
