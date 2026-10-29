import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/surname_review.dart';

void main() {
  test('selected man only is updated; women and unselected men remain unchanged', () {
    final chosen = Person(id: 'p1', gender: 'M');
    final other = Person(id: 'p2', gender: 'M');
    final woman = Person(id: 'p3', gender: 'F');
    final people = [chosen, other, woman];
    expect(SurnameReview.eligible(woman, '李', '이'), isFalse);
    expect(SurnameReview.applySelected(
      people, {'p1'}, hanja: '李', hangul: '이',
    ), 1);
    expect(chosen.surnameHanja, '李');
    expect(chosen.surnameHangul, '이');
    expect(other.surnameHangul, isNull);
    expect(woman.surnameHangul, isNull);
  });

  test('existing surname cannot be overwritten', () {
    final person = Person(id: 'p1', gender: 'M',
        surnameHanja: '崔', surnameHangul: '최');
    expect(SurnameReview.eligible(person, '李', '이'), isFalse);
    expect(() => SurnameReview.applySelected(
      [person], {'p1'}, hanja: '李', hangul: '이',
    ), throwsStateError);
    expect(person.surnameHanja, '崔');
    expect(person.surnameHangul, '최');
  });

  test('unknown ID prevents partial updates', () {
    final person = Person(id: 'p1', gender: 'M');
    expect(() => SurnameReview.applySelected(
      [person], {'p1', 'missing'}, hanja: '李', hangul: '이',
    ), throwsStateError);
    expect(person.surnameHanja, isNull);
  });

  test('duplicate IDs prevent ambiguous updates', () {
    final first = Person(id: 'same', gender: 'M');
    final second = Person(id: 'same', gender: 'M');
    expect(() => SurnameReview.applySelected(
      [first, second], {'same'}, hanja: '李', hangul: '이',
    ), throwsStateError);
    expect(first.surnameHangul, isNull);
    expect(second.surnameHangul, isNull);
  });
}
