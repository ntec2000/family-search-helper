import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/familysearch_parent_link_payload.dart';
import 'package:family_search_helper/services/familysearch_parent_link_plan.dart';

void main() {
  FamilySearchParentLinkPlan plan(String relationship) => FamilySearchParentLinkPlan.prepare(
    childId: 'ABCD-123', parentId: 'EFGH-456', relationship: relationship,
    reason: '족보 224쪽', childConfirmed: true, parentConfirmed: true,
    existingRelationshipsReviewed: true,
  );

  test('확인된 양자 관계의 인물 ID와 근거를 요청 후보에 담는다', () {
    final payload = FamilySearchParentLinkPayload.build(
        plan('양자'), Uri.parse('https://apibeta.familysearch.org'));
    final relationship = (payload['childAndParentsRelationships'] as List).single;
    expect(relationship['child']['resourceId'], 'ABCD-123');
    expect(relationship['parent1']['resourceId'], 'EFGH-456');
    expect(relationship['parent1Facts'][0]['type'], 'http://gedcomx.org/AdoptiveParent');
    expect(relationship['parent1Facts'][0]['attribution']['changeMessage'], '족보 224쪽');
    expect(relationship.containsKey('parent2'), isFalse);
  });

  test('미확인 관계와 운영 서버 주소는 요청 후보를 만들지 않는다', () {
    expect(() => FamilySearchParentLinkPayload.build(
        plan('미확인'), Uri.parse('https://apibeta.familysearch.org')), throwsStateError);
    expect(() => FamilySearchParentLinkPayload.build(
        plan('친생'), Uri.parse('https://api.familysearch.org')), throwsStateError);
  });
}
