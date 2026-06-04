import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // v3.0 — 족보 차례(형제 순서) 규칙
  //  · 아들: 차례 한자(二·三·四…)가 있으면 그 순서, 없으면 장남(첫째아들).
  //          족보 관례상 장남은 숫자를 생략하므로, 차례 표기가 없는 子는
  //          모두 '첫째아들'(각자 자기 아버지의 장남)로 본다.
  //  · 딸: 연속한 女 묶음 안의 등장 순서로 첫째딸·둘째딸… (아들이 나오면 초기화).

  test('차례 표기가 없는 아들은 모두 첫째아들(장남)로 표기된다', () {
    const text = '子相熙 子相奎 子相元';
    final persons = JokboParser.parse(text);
    final sons = persons.where((p) => p.gender == 'M').toList();
    expect(sons.length, 3);
    expect(sons[0].relation, '첫째아들');
    expect(sons[1].relation, '첫째아들');
    expect(sons[2].relation, '첫째아들');
  });

  test('차례 한자(二·三·四)가 있으면 해당 순서로 표기된다', () {
    const text = '子炳吉 子二炳旭 子三炳烈 子四炳直';
    final persons = JokboParser.parse(text);
    final sons = persons.where((p) => p.gender == 'M').toList();
    expect(sons.length, 4);
    expect(sons[0].relation, '첫째아들');
    expect(sons[1].relation, '둘째아들');
    expect(sons[2].relation, '셋째아들');
    expect(sons[3].relation, '넷째아들');
  });

  test('연속한 딸은 등장 순서대로 첫째딸·둘째딸이 부여된다', () {
    const text = '子相熙 女順任 女貞任';
    final persons = JokboParser.parse(text);
    final daughters = persons.where((p) => p.gender == 'F').toList();
    expect(daughters.length, 2);
    expect(daughters[0].relation, '첫째딸');
    expect(daughters[1].relation, '둘째딸');
  });

  test('아들이 등장하면 딸 연속 카운터가 초기화된다', () {
    const text = '子相熙 女順任 女貞任 子相奎 女惠任';
    final persons = JokboParser.parse(text);
    final daughters = persons.where((p) => p.gender == 'F').toList();
    expect(daughters.length, 3);
    expect(daughters[0].relation, '첫째딸'); // 첫 묶음 1
    expect(daughters[1].relation, '둘째딸'); // 첫 묶음 2
    expect(daughters[2].relation, '첫째딸'); // 아들 뒤 새 묶음 → 다시 첫째딸
  });
}
