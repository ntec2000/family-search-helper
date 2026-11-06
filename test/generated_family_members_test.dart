import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/hanja_dict.dart';
import 'package:family_search_helper/services/family_name_candidates.dart';
import 'package:family_search_helper/services/daughter_order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HanjaDict.instance.load());

  test('처가 남자와 각 부인을 후보로 만들고 가문 성씨를 섞지 않는다', () {
    final source = Person(id:'source', gender:'M', nameHangul:'핵',
        surnameHangul:'이', spouseHanja:'坡平尹氏', spouseHangul:'윤씨',
        spouseFather:'光岳', spouseGrandfather:'東憶', spouseGreatGrandfather:'道經',
        spouseMaternalGrandfather:'丁若萬(정약만)', rawText:'원본 족보');
    final before = source.toMap();
    final rows = FamilyNameCandidates.fromPerson(source);
    for (final name in ['윤광악의 부인','윤동억의 부인','윤도경의 부인','정약만의 부인']) {
      final row = rows.firstWhere((r) => r.display == name);
      final wife = row.materialize(source);
      expect(wife.generatedName, name);
      expect(wife.nameHanja, isEmpty);
      expect(wife.nameHangul, isEmpty);
      expect(wife.surnameHangul, isNull);
      expect(wife.fatherId, isNull);
      expect(wife.motherId, isNull);
      expect(Person.fromMap(wife.toMap()).displayName, name);
    }
    final father = rows.firstWhere((r) => r.kind == 'father').materialize(source);
    expect(father.displayName, '윤광악');
    expect(father.surnameHangul, '윤');
    expect(source.toMap(), before);
  });

  test('본관만 있는 아내는 성씨로 표시하고 개인 이름을 만들지 않는다', () {
    final source = Person(id:'s',gender:'M',nameHangul:'측',surnameHangul:'이',
        spouseHanja:'原州邊氏');
    final wife = FamilyNameCandidates.fromPerson(source)
        .firstWhere((r) => r.kind == 'spouse').materialize(source);
    expect(wife.displayName, '변씨');
    expect(wife.surnameHangul, '변');
    expect(wife.nameHangul, isEmpty);
  });

  test('동명이 같은 표시명이라도 원본 인물이 다르면 합치지 않는다', () {
    final a = Person(id:'a',gender:'M',spouseHangul:'윤씨');
    final b = Person(id:'b',gender:'M',spouseHangul:'윤씨');
    final first = FamilyNameCandidates.fromPerson(a).firstWhere((r)=>r.kind=='spouse');
    final second = FamilyNameCandidates.fromPerson(b).firstWhere((r)=>r.kind=='spouse');
    expect(first.display, second.display);
    expect(first.candidateId, isNot(second.candidateId));
    expect(() => first.materialize(b), throwsStateError);
  });

  test('실제 개인 이름을 입력하면 생성 표시명보다 우선한다', () {
    final person = Person(id:'w',gender:'F',generatedName:'홍길동의 부인');
    expect(person.displayName, '홍길동의 부인');
    person.nameHangul = '김영희';
    expect(person.displayName, '김영희');
    expect(person.generatedName, '홍길동의 부인');
  });

  test('딸의 기록 순번은 연결한 아버지별로 다시 표시한다', () {
    final a = Person(id:'a',gender:'F',fatherId:'father-a',surnameHangul:'이',
        relation:'첫째딸',note:'女 등장 순서');
    final b = Person(id:'b',gender:'F',fatherId:'father-b',surnameHangul:'이',
        relation:'둘째딸',note:'女 등장 순서');
    final c = Person(id:'c',gender:'F',fatherId:'father-b',surnameHangul:'이',
        relation:'셋째딸',note:'女 등장 순서');
    final people=[a,b,c];
    expect(DaughterOrder.label(a,people),'첫째딸');
    expect(DaughterOrder.label(b,people),'첫째딸');
    expect(DaughterOrder.label(c,people),'둘째딸');
    expect(people.map((p)=>p.displayName),everyElement('이씨'));
    expect(b.relation,'둘째딸'); // raw parser label remains unchanged
  });
  test('외조부 기록이 성씨 한 글자뿐이면 개인 이름 대신 씨 표시를 쓴다', () {
    final source = Person(id:'s',gender:'M',spouseMaternalGrandfather:'高');
    final rows = FamilyNameCandidates.fromPerson(source);
    final grandfather = rows.firstWhere((r)=>r.kind=='maternalGrandfather')
        .materialize(source);
    expect(grandfather.displayName,'고씨');
    expect(grandfather.nameHangul,isEmpty);
    expect(rows.firstWhere((r)=>r.kind=='maternalGrandfatherWife').display,
        '고씨의 부인');
  });

}
