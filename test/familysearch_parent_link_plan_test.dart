import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/familysearch_parent_link_plan.dart';

void main() {
  FamilySearchParentLinkPlan prepare({String child = 'ABCD-123',
      String parent = 'WXYZ-456', String relationship = '친생',
      String reason = '족보 224쪽', bool childConfirmed = true,
      bool parentConfirmed = true, bool reviewed = true}) =>
      FamilySearchParentLinkPlan.prepare(childId: child, parentId: parent,
          relationship: relationship, reason: reason,
          childConfirmed: childConfirmed, parentConfirmed: parentConfirmed,
          existingRelationshipsReviewed: reviewed);

  test('확인한 부모와 자녀 ID 및 근거를 검토 자료에 보존한다', () {
    final plan = prepare(child: 'abcd-123', relationship: '양자');
    expect(plan.childId, 'ABCD-123');
    expect(plan.parentId, 'WXYZ-456');
    expect(plan.relationship, '양자');
    expect(plan.reason, '족보 224쪽');
  });

  test('잘못되거나 같은 ID, 미확인 인물·관계, 빈 근거는 차단한다', () {
    expect(() => prepare(parent: 'abcd-123'), throwsStateError);
    expect(() => prepare(parent: '../bad'), throwsStateError);
    expect(() => prepare(childConfirmed: false), throwsStateError);
    expect(() => prepare(parentConfirmed: false), throwsStateError);
    expect(() => prepare(reviewed: false), throwsStateError);
    expect(() => prepare(relationship: '임의'), throwsStateError);
    expect(() => prepare(reason: '  '), throwsStateError);
  });
}
