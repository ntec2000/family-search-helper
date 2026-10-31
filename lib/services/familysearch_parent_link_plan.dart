/// 사용자가 확인한 FamilySearch 인물 간 연결을 전송 전에 검토하는 자료.
/// 이 클래스는 API 요청이나 실제 관계 생성을 수행하지 않는다.
class FamilySearchParentLinkPlan {
  final String childId;
  final String parentId;
  final String relationship;
  final String reason;

  const FamilySearchParentLinkPlan._(
      this.childId, this.parentId, this.relationship, this.reason);

  static FamilySearchParentLinkPlan prepare({
    required String childId,
    required String parentId,
    required String relationship,
    required String reason,
    required bool childConfirmed,
    required bool parentConfirmed,
    required bool existingRelationshipsReviewed,
  }) {
    final child = childId.trim().toUpperCase();
    final parent = parentId.trim().toUpperCase();
    final validId = RegExp(r'^[A-Z0-9-]{4,40}$');
    if (!validId.hasMatch(child) || !validId.hasMatch(parent) || child == parent) {
      throw StateError('서로 다른 자녀와 부모의 FamilySearch ID를 확인하세요.');
    }
    if (!childConfirmed || !parentConfirmed || !existingRelationshipsReviewed) {
      throw StateError('두 인물과 기존 가족관계를 먼저 확인하세요.');
    }
    if (!const {'친생', '양자', '미확인'}.contains(relationship)) {
      throw StateError('부모 관계 유형을 확인하세요.');
    }
    if (reason.trim().isEmpty) throw StateError('연결 근거를 입력하세요.');
    return FamilySearchParentLinkPlan._(child, parent, relationship, reason.trim());
  }
}
