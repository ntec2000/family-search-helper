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

  test('unnamed daughter remains unnamed', () {
    final father = person('昃', 20);
    final daughter = Person(id: 'daughter-1', gender: 'F',
        surnameHanja: '李', surnameHangul: '이', sega: 21);
    ParentChildReview.applyReviewedLink(father, daughter);
    expect(daughter.nameHanja, isEmpty);
    expect(daughter.nameHangul, isEmpty);
    expect(daughter.fatherId, '昃');
  });
}
