import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('차례 표기가 없는 아들들에게 형제 순서가 부여된다 (첫째/둘째/셋째)', () {
    // 차례(一二三) 없이 子가 연속으로 등장하는 전형적 족보 텍스트
    const text = '子相熙 子相奎 子相元';
    final persons = JokboParser.parse(text);
    final sons = persons.where((p) => p.gender == 'M').toList();
    expect(sons.length, 3);
    expect(sons[0].relation, '첫째아들');
    expect(sons[1].relation, '둘째아들');
    expect(sons[2].relation, '셋째아들');
  });

  test('아들/딸 순번은 성별별로 독립적으로 매겨진다', () {
    const text = '子相熙 女順任 子相奎';
    final persons = JokboParser.parse(text);
    final sons = persons.where((p) => p.gender == 'M').toList();
    final daughters = persons.where((p) => p.gender == 'F').toList();
    expect(sons[0].relation, '첫째아들');
    expect(sons[1].relation, '둘째아들');
    expect(daughters[0].relation, '첫째딸');
  });
}
