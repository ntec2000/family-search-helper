import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/gedcom_export.dart';

void main() {
  test('exports known parent-child links', () {
    final people = <Person>[
      Person(id: 'father', nameHangul: '아버지', gender: 'M'),
      Person(id: 'mother', nameHangul: '어머니', gender: 'F'),
      Person(id: 'child', nameHangul: '자녀', fatherId: 'father', motherId: 'mother'),
    ];
    final output = GedcomExport.toGedcom(people);
    expect(output, contains('0 @F1@ FAM'));
    expect(output, contains('1 HUSB @Ifather@'));
    expect(output, contains('1 WIFE @Imother@'));
    expect(output, contains('1 CHIL @Ichild@'));
    expect(output, contains('1 FAMC @F1@'));
    expect(output.split('1 FAMS @F1@').length - 1, 2);
  });

  test('ignores parent ids missing from exported people', () {
    final output = GedcomExport.toGedcom(<Person>[
      Person(id: 'child', fatherId: 'not-exported'),
    ]);
    expect(output, isNot(contains('0 @F1@ FAM')));
  });
  test('short and colliding normalized IDs have unique cross-references', () {
    final output = GedcomExport.toGedcom(<Person>[
      Person(id: 'a'),
      Person(id: 'a-b'),
      Person(id: 'a_b'),
    ]);
    expect(output, contains('0 @Ia@ INDI'));
    expect(output, contains('0 @Ia_b@ INDI'));
    expect(output, contains('0 @Ia_b_3@ INDI'));
  });

  test('does not invent relationships from unrelated people', () {
    final output = GedcomExport.toGedcom(<Person>[
      Person(id: 'one', nameHangul: '첫째'),
      Person(id: 'two', nameHangul: '둘째'),
    ]);
    expect(output, isNot(contains(' FAM')));
    expect(output, isNot(contains('1 FAMC ')));
    expect(output, isNot(contains('1 FAMS ')));
  });

  test('GEDCOM surname is Hangul surname, not Hanja full name', () {
    final output = GedcomExport.toGedcom(<Person>[
      Person(id: 'p', nameHangul: '최해두', surnameHangul: '최', nameHanja: '崔海斗'),
    ]);
    expect(output, contains('1 NAME 해두 /최/'));
    expect(output, contains('1 NOTE 한자 이름: 崔海斗'));
    expect(output, isNot(contains('1 NAME 최해두 /崔海斗/')));
  });

  test('empty export has a header and trailer', () {
    final output = GedcomExport.toGedcom(<Person>[]);
    expect(output, contains('0 HEAD'));
    expect(output, contains('0 TRLR'));
    expect(output, isNot(contains('0 @I')));
  });

}
