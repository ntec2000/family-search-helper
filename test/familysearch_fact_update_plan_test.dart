import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/familysearch_fact_update_plan.dart';

void main() {
  const birth = 'http://gedcomx.org/Birth';
  final remote = <String, dynamic>{'id': 'ABCD-123', 'facts': [
    {'id': 'old-1', 'type': birth, 'date': {'original': '1800'},
      'place': {'original': '경주'}},
  ]};
  final incoming = <String, dynamic>{'facts': [
    {'type': birth, 'date': {'original': 'about 1801'}},
  ]};
  test('기존 날짜와 새 날짜를 구분하고 입력하지 않은 장소를 보존한다', () {
    final plan = FamilySearchFactUpdatePlan.prepare(remote: remote, incoming: incoming,
        factId: 'old-1', type: birth, reason: '족보 224쪽');
    expect(plan.previous['date']['original'], '1800');
    expect(plan.proposed['date']['original'], 'about 1801');
    expect(plan.proposed['place']['original'], '경주');
    expect(plan.factId, 'old-1');
  });
  test('기존 항목 ID가 다르거나 근거가 없으면 변경안을 만들지 않는다', () {
    expect(() => FamilySearchFactUpdatePlan.prepare(remote: remote, incoming: incoming,
        factId: 'missing', type: birth, reason: '족보'), throwsStateError);
    expect(() => FamilySearchFactUpdatePlan.prepare(remote: remote, incoming: incoming,
        factId: 'old-1', type: birth, reason: ''), throwsStateError);
  });
}
