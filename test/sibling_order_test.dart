import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 원문에 순서가 없으면 배열의 등장 순서로 장남·장녀를 추측하지 않는다.

  test('차례 표기가 없는 아들은 순서 미상으로 표시한다', () {
    const text = '子相熙 子相奎 子相元';
    final persons = JokboParser.parse(text);
    final sons = persons.where((p) => p.gender == 'M').toList();
    expect(sons.length, 3);
    expect(sons[0].relation, '순서 미상아들');
    expect(sons[1].relation, '순서 미상아들');
    expect(sons[2].relation, '순서 미상아들');
  });

  test('차례 한자(二·三·四)가 있으면 해당 순서로 표기된다', () {
    const text = '子炳吉 子二炳旭 子三炳烈 子四炳直';
    final persons = JokboParser.parse(text);
    final sons = persons.where((p) => p.gender == 'M').toList();
    expect(sons.length, 4);
    expect(sons[0].relation, '순서 미상아들');
    expect(sons[1].relation, '둘째아들');
    expect(sons[2].relation, '셋째아들');
    expect(sons[3].relation, '넷째아들');
  });

  test('딸도 명시된 순서 한자는 보존한다', () {
    final daughters = JokboParser.parse('女一權頭 女二李集');
    expect(daughters.map((p) => p.relation), ['첫째딸', '둘째딸']);
  });

  test('연속한 딸도 원문에 순서가 없으면 순서 미상으로 표시한다', () {
    const text = '子相熙 女順任 女貞任';
    final persons = JokboParser.parse(text);
    final daughters = persons.where((p) => p.gender == 'F').toList();
    expect(daughters.length, 2);
    expect(daughters[0].relation, '순서 미상딸');
    expect(daughters[1].relation, '순서 미상딸');
  });

  test('아들 전후의 딸에게 배열 순서로 차례를 부여하지 않는다', () {
    const text = '子相熙 女順任 女貞任 子相奎 女惠任';
    final persons = JokboParser.parse(text);
    final daughters = persons.where((p) => p.gender == 'F').toList();
    expect(daughters.length, 3);
    expect(daughters[0].relation, '순서 미상딸');
    expect(daughters[1].relation, '순서 미상딸');
    expect(daughters[2].relation, '순서 미상딸');
  });
}
