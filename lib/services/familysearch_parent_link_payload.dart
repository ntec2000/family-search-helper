import 'familysearch_parent_link_plan.dart';

/// 테스트용 요청 자료만 구성한다. 이 클래스는 네트워크 전송을 하지 않는다.
class FamilySearchParentLinkPayload {
  static Map<String, dynamic> build(FamilySearchParentLinkPlan plan, Uri apiBase) {
    if (apiBase.scheme != 'https' ||
        !const {'api-integ.familysearch.org', 'apibeta.familysearch.org'}
            .contains(apiBase.host) ||
        apiBase.hasPort || apiBase.userInfo.isNotEmpty ||
        (apiBase.path.isNotEmpty && apiBase.path != '/') ||
        apiBase.hasQuery || apiBase.hasFragment) {
      throw StateError('FamilySearch 테스트 서버 주소를 확인하세요.');
    }
    // 미확인 관계를 생물학적 관계로 암시하지 않는다.
    if (plan.relationship == '미확인') {
      throw StateError('친생 또는 양자 관계를 확인한 뒤 검토하세요.');
    }
    final type = plan.relationship == '친생' ? 'BiologicalParent' : 'AdoptiveParent';
    Map<String, String> reference(String id) => {
      'resource': apiBase.resolve('/platform/tree/persons/$id').toString(),
      'resourceId': id,
    };
    return {
      'childAndParentsRelationships': [
        {
          'parent1': reference(plan.parentId),
          'child': reference(plan.childId),
          'parent1Facts': [
            {'type': 'http://gedcomx.org/$type',
             'attribution': {'changeMessage': plan.reason}},
          ],
        },
      ],
    };
  }
}
