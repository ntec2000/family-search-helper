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
}
