import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/hanja_dict.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';
import 'package:family_search_helper/services/family_name_candidates.dart';
import 'package:family_search_helper/services/female_name_display.dart';
import 'package:family_search_helper/services/spouse_parent_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HanjaDict.instance.load());

  test('이·김·최 한글 작업 성씨는 아들·딸에 적용하고 다른 문중 한자를 섞지 않는다', () {
    for (final surname in ['이', '김', '최']) {
      final people = JokboParser.parseRegions([
        '固城金氏', '子格', '女金免傑 金海人',
      ], clanHangulOverride: surname);
      expect(people, hasLength(2));
      for (final person in people) {
        expect(person.surnameHangul, surname);
        expect(person.surnameHanja ?? '', isEmpty);
        expect(person.fatherId, isNull);
        expect(person.motherId, isNull);
      }
      expect(FamilyNameCandidates.fromPerson(people.first).first.display, '$surname격');
      expect(FemaleNameDisplay.forPerson(people.last), '$surname씨');
      expect(people.last.spouseHanja, '金免傑');
      expect(people.last.nameHangul, isEmpty);
    }
  });

  test('이씨라고 입력해도 성씨와 이름을 중복 조합하지 않는다', () {
    final people = JokboParser.parseRegions(['子格', '女金免傑'],
        clanHangulOverride: ' 이씨 ');
    expect(FamilyNameCandidates.fromPerson(people.first).first.display, '이격');
    expect(FemaleNameDisplay.forPerson(people.last), '이씨');
  });

  test('띄어진 족보 표제에서 작업 성씨를 읽고 배우자 성과 구분한다', () {
    final people = JokboParser.parseRegions([
      '固 城 李 氏 思菴公派譜', '子格 配原州邊氏', '女金免傑',
    ]);
    expect(people.map((p) => p.surnameHanja), everyElement('李'));
    expect(people.map((p) => p.surnameHangul), everyElement('이'));
    expect(people.first.spouseHanja, '邊氏');
    expect(people.last.spouseHanja, '金免傑');
  });

  test('확인한 성씨가 있으면 구획을 넘어 女 등장 순서를 표시하고 원문 서수는 보존한다', () {
    final people = JokboParser.parseRegions([
      '女金免傑 金海人', '子格 配原州邊氏', '女尹兢秀', '女三權頭',
    ], clanHanjaOverride: '李', clanHangulOverride: '이');
    final daughters = people.where((p) => p.gender == 'F').toList();
    expect(daughters.map((p) => p.relation), ['첫째딸', '둘째딸', '셋째딸']);
    expect(daughters.first.note, contains('등장 순서'));
    expect(daughters.first.rawText, '女金免傑 金海人');
    expect(daughters.last.rawText, '女三權頭');
    final explicit = JokboParser.parseRegions(['女十一金免傑'],
        clanHangulOverride: '이').single;
    expect(explicit.relation, '11번째딸');
    expect(explicit.spouseHanja, '金免傑');
    expect(explicit.note, isNot(contains('현재 분석 쪽')));
  });

  test('다음 족보 분석에서는 딸 순번을 다시 시작한다', () {
    for (final surname in ['이', '김']) {
      final daughter = JokboParser.parseRegions(['女金免傑'],
          clanHangulOverride: surname).single;
      expect(daughter.relation, '첫째딸');
    }
  });

  test('사위 부친을 추출하고 사위 성씨를 조합한 후보와 원문을 구분한다', () {
    const raw = '女金免傑 金海人父正明';
    final daughter = JokboParser.parseRegions([raw],
        clanHanjaOverride: '李', clanHangulOverride: '이').single;
    expect(daughter.spouseHanja, '金免傑');
    expect(daughter.spouseFather, '正明');
    final father = FamilyNameCandidates.fromPerson(daughter)
        .firstWhere((row) => row.role.contains('아버지'));
    expect(father.display, '金正明');
    expect(father.role, contains('성씨'));
    expect(SpouseParentText.lines(daughter).join('\n'), contains('김정명'));
    expect(daughter.rawText, raw);
    expect(daughter.spouseMother, isNull);
    expect(daughter.surnameHangul, '이');
  });

  test('본손 이측과 원주 변씨 아내 표시명은 성씨를 섞지 않는다', () {
    final son = JokboParser.parseRegions(['子昃 配原州邊氏'],
        clanHanjaOverride: '李', clanHangulOverride: '이').single;
    final rows = FamilyNameCandidates.fromPerson(son);
    expect(rows.first.display, '이측');
    expect(rows.firstWhere((row) => row.role == '배우자 후보').display, '변씨');
    expect(son.spouseHanja, '邊氏');
    expect(son.spouseBongwan, '原州');
  });

  test('표제 후보가 다르면 자동 확정하지 않고 배우자 본문은 표제로 사용하지 않는다', () {
    expect(JokboParser.detectWorkingSurname([
      '固城李氏 子格', '金海金氏 子正明',
    ]), isNull);
    expect(JokboParser.detectWorkingSurname(['子格 配原州邊氏']), isNull);
    expect(JokboParser.detectWorkingSurname([
      '固 城 李 氏 思菴公派譜', '子格 配原州邊氏',
    ]), ('李', '이'));
  });

  test('사위 복성과 이미 성이 있는 부친 원문은 중복 조합하지 않는다', () {
    final compound = JokboParser.parseRegions(['女南宮明 父正明'],
        clanHangulOverride: '이').single;
    expect(FamilyNameCandidates.fromPerson(compound)
        .firstWhere((row) => row.role.contains('아버지')).display, '南宮正明');
    final full = JokboParser.parseRegions(['女金免傑 父金正明'],
        clanHangulOverride: '이').single;
    expect(FamilyNameCandidates.fromPerson(full)
        .firstWhere((row) => row.role.contains('아버지')).display, '金正明');
    expect(full.spouseFather, '金正明');
  });
}
