import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/gender_label.dart';

void main() {
  test('성별 미상과 예상 밖 값은 남성으로 바꾸지 않는다', () {
    expect(genderLabel('M'), '남');
    expect(genderLabel('F'), '여');
    expect(genderLabel('U'), '미상');
    expect(genderLabel(''), '미상');
  });
}
