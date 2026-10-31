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

  test('날짜를 모르는 출생지와 사망지도 내보내고 날짜는 만들지 않는다', () {
    final output = GedcomExport.toGedcom([
      Person(id: 'p', birthPlace: '경주', deathPlace: '서울'),
    ]);
    expect(output, contains('1 BIRT\n2 PLAC 경주\n'));
    expect(output, contains('1 DEAT\n2 PLAC 서울\n'));
    expect(output, isNot(contains('2 DATE ')));
    final empty = GedcomExport.toGedcom([
      Person(id: 'empty', birthPlace: ' ', deathPlace: ''),
    ]);
    expect(empty, isNot(contains('1 BIRT')));
    expect(empty, isNot(contains('1 DEAT')));
  });

  test('공백 생몰 날짜는 사건이나 빈 DATE를 만들지 않는다', () {
    final output = GedcomExport.toGedcom([
      Person(id: 'empty', birthDateSolar: ' ', birthDateLunar: '',
          deathDateSolar: '', deathDateLunar: ' '),
    ]);
    expect(output, isNot(contains('1 BIRT')));
    expect(output, isNot(contains('1 DEAT')));
    expect(output, isNot(contains('2 DATE ')));
    final original = GedcomExport.toGedcom([
      Person(id: 'lunar', birthDateSolar: ' ', birthDateLunar: '丁未生'),
    ]);
    expect(original, contains('1 BIRT\n2 NOTE 음력: 丁未生'));
    expect(original, isNot(contains('2 DATE ')));
  });

  test('묘지 미상이어도 기록된 좌향은 메모에 보존한다', () {
    final output = GedcomExport.toGedcom([
      Person(id: 'p', burialPlace: ' ', burialOrientation: '壬坐'),
    ]);
    expect(output, contains('1 NOTE 묘 좌향: 壬坐'));
    expect(output, isNot(contains('1 BURI')));
    final withPlace = GedcomExport.toGedcom([
      Person(id: 'q', burialPlace: '謹峴', burialOrientation: '壬坐'),
    ]);
    expect(withPlace, contains('1 BURI\n2 PLAC 謹峴\n2 NOTE 좌향: 壬坐'));
  });

  test('duplicate person IDs are rejected', () {
    expect(
      () => GedcomExport.toGedcom(<Person>[
        Person(id: 'same'),
        Person(id: 'same'),
      ]),
      throwsStateError,
    );
  });

  test('한 사람을 아버지와 어머니에 중복 지정하면 내보내기를 차단한다', () {
    final people = [Person(id: 'parent'),
      Person(id: 'child', fatherId: 'parent', motherId: 'parent')];
    expect(() => GedcomExport.toGedcom(people), throwsStateError);
  });

  test('자기 자신을 부모로 지정한 기록은 조용히 누락하지 않고 차단한다', () {
    for (final person in [Person(id: 'p', fatherId: 'p'),
        Person(id: 'p', motherId: 'p')]) {
      expect(() => GedcomExport.toGedcom([person]), throwsStateError);
    }
  });

  test('여러 인물의 순환 부모 관계를 내보내지 않는다', () {
    final people = [Person(id: 'a', fatherId: 'b'),
      Person(id: 'b', fatherId: 'c'), Person(id: 'c', fatherId: 'a')];
    expect(() => GedcomExport.toGedcom(people), throwsStateError);
  });

  test('검토한 자녀 없는 부부도 하나의 가족으로 내보낸다', () {
    final people = [Person(id: 'a', gender: 'M'), Person(id: 'b', gender: 'F')];
    final ged = GedcomExport.toGedcom(people, reviewedCouples: [('b', 'a')]);
    expect(ged, contains('1 HUSB @Ia@'));
    expect(ged, contains('1 WIFE @Ib@'));
    expect(ged.split(' FAM\n').length - 1, 1);
    expect(ged.split('1 FAMS @F1@').length - 1, 2);
  });
  test('기존 부모 자녀 가족과 확인한 부부는 중복 생성하지 않는다', () {
    final people = [Person(id: 'a', gender: 'M'), Person(id: 'b', gender: 'F'),
      Person(id: 'c', fatherId: 'a', motherId: 'b')];
    final ged = GedcomExport.toGedcom(people, reviewedCouples: [('a', 'b')]);
    expect(ged.split(' FAM\n').length - 1, 1);
    expect(ged, contains('1 CHIL @Ic@'));
  });
  test('부모 역할을 추정해야 하는 관계는 차단한다', () {
    final people = [Person(id: 'a', gender: 'U'), Person(id: 'b', gender: 'F')];
    expect(() => GedcomExport.toGedcom(people, reviewedCouples: [('a', 'b')]),
        throwsStateError);
  });

  test('구분자가 포함된 부모 ID도 서로 다른 가족으로 유지한다', () {
    final ged = GedcomExport.toGedcom([
      Person(id: 'a|b', gender: 'M'), Person(id: 'c', gender: 'F'),
      Person(id: 'a', gender: 'M'), Person(id: 'b|c', gender: 'F'),
      Person(id: 'x', fatherId: 'a|b', motherId: 'c'),
      Person(id: 'y', fatherId: 'a', motherId: 'b|c'),
    ], reviewedCouples: [('a|b', 'c'), ('a', 'b|c')]);
    final families = RegExp(r'0 @F\d+@ FAM\n(?:1 [^\n]*\n)*')
        .allMatches(ged).map((match) => match.group(0)!).toList();
    expect(families, hasLength(2));
    expect(families[0], contains('1 HUSB @Ia_b@'));
    expect(families[0], contains('1 WIFE @Ic@'));
    expect(families[0], contains('1 CHIL @Ix@'));
    expect(families[1], contains('1 HUSB @Ia@'));
    expect(families[1], contains('1 WIFE @Ib_c@'));
    expect(families[1], contains('1 CHIL @Iy@'));
  });

}
