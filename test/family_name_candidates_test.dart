import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/family_name_candidates.dart';

void main() {
  test('배우자 부모 후보를 표시하고 원문을 보존한다', () {
    final p = Person(id: 'p', gender: 'M', surnameHangul: '이', nameHangul: '격',
        spouseHangul: '조씨', spouseFather: '永復', rawText: '원문');
    final rows = FamilyNameCandidates.fromPerson(p);
    expect(rows.map((r) => r.display).toList(), ['이격', '조씨', '永復', '永復의 부인']);
    expect(rows.last.placeholder, isTrue);
    expect(p.rawText, '원문');
  });
  test('이름 없는 딸과 사위 후보를 구분하며 없는 부모를 생성하지 않는다', () {
    final p = Person(id: 'd', gender: 'F', surnameHangul: '이', spouseHanja: '權龜壽');
    final rows = FamilyNameCandidates.fromPerson(p);
    expect(rows.map((r) => r.display).toList(), ['이씨', '權龜壽']);
    expect(rows.first.placeholder, isTrue);
    expect(rows.last.role, '남편 후보');
  });
  test('실제 배우자 이름 후보를 남편의 부인이라는 표시명으로 덮지 않는다', () {
    final p = Person(id: 'p', gender: 'M', nameHangul: '홍길동',
        spouseHangul: '김영희');
    final spouse = FamilyNameCandidates.fromPerson(p)[1];
    expect(spouse.display, '김영희');
    expect(spouse.placeholder, isFalse);
    expect(p.spouseHangul, '김영희');
  });
  test('한자 배우자 이름 후보도 원문대로 보존한다', () {
    final p = Person(id: 'p', gender: 'M', nameHangul: '홍길동',
        spouseHanja: '金英姬');
    final spouse = FamilyNameCandidates.fromPerson(p)[1];
    expect(spouse.display, '金英姬');
    expect(spouse.placeholder, isFalse);
  });

  test('배우자 기록이 있으면 이름 미상 아내를 표시하되 인물을 생성하지 않는다', () {
    final p = Person(id: 'p', gender: 'M', surnameHangul: '홍', nameHangul: '길동',
        spouseFather: '光岳');
    final before = p.toMap();
    final rows = FamilyNameCandidates.fromPerson(p);
    final spouse = rows.firstWhere((row) => row.role == '배우자 후보');
    expect(spouse.display, '홍길동의 부인');
    expect(spouse.placeholder, isTrue);
    expect(p.toMap(), before);
    final unrelated = FamilyNameCandidates.fromPerson(
        Person(id: 'q', gender: 'M', nameHangul: '홍길동'));
    expect(unrelated.where((row) => row.role == '배우자 후보'), isEmpty);
    final unnamed = FamilyNameCandidates.fromPerson(
        Person(id: 'u', gender: 'M', spouseBirth: '乙巳'));
    expect(unnamed.firstWhere((row) => row.role == '배우자 후보').display, '이름 미상');
  });

  test('배우자 측 조상은 원문을 유지하고 관계별 후보로 표시한다', () {
    final p = Person(id: 'p', gender: 'M', nameHangul: '이핵',
        spouseGrandfather: '東憶', spouseGreatGrandfather: '道經',
        spouseMaternalGrandfather: '高');
    final original = p.toMap();
    final rows = FamilyNameCandidates.fromPerson(p);
    expect(rows.firstWhere((r) => r.role == '배우자의 조부 후보').display, '東憶');
    expect(rows.firstWhere((r) => r.role == '배우자의 증조부 후보').display, '道經');
    expect(rows.firstWhere((r) => r.role == '배우자의 외조부 후보').display, '高');
    expect(rows.where((r) => r.role.contains('아버지')), isEmpty);
    expect(rows.firstWhere((r) => r.role == '배우자 후보').display, '이핵의 부인');
    expect(p.toMap(), original);
  });

  test('배우자 성씨를 이용한 부친 이름은 추정 후보로 표시한다', () {
    final p = Person(id: 'p', gender: 'M', spouseHanja: '豊壤趙氏',
        spouseFather: '永復');
    final rows = FamilyNameCandidates.fromPerson(p);
    final father = rows.firstWhere((r) => r.role.contains('아버지'));
    expect(father.display, '趙永復');
    expect(father.role, contains('성씨 추정'));
    expect(rows.last.display, '趙永復의 부인');
    expect(rows.last.placeholder, isTrue);
    expect(p.spouseFather, '永復');
  });
  test('배우자 부친의 성씨가 모호하면 추가하지 않는다', () {
    final p = Person(id: 'p', gender: 'M', spouseHanja: '豊壤趙氏',
        spouseFather: '金復');
    final father = FamilyNameCandidates.fromPerson(p)
        .firstWhere((r) => r.role.contains('아버지'));
    expect(father.display, '金復');
    expect(father.role, isNot(contains('성씨 추정')));
  });

}
