import '../models/person.dart';

/// 내보내는 인물 사이의 명시된 부모 ID만 검사하며 원본은 변경하지 않는다.
class ExportRelationshipValidation {
  static void rejectParentCycles(List<Person> persons) {
    final byId = {for (final person in persons) person.id: person};
    final incoming = {for (final id in byId.keys) id: 0};
    final children = <String, List<String>>{};
    for (final child in persons) {
      for (final parent in {child.fatherId, child.motherId}) {
        if (parent == null || !byId.containsKey(parent)) continue;
        children.putIfAbsent(parent, () => <String>[]).add(child.id);
        incoming[child.id] = incoming[child.id]! + 1;
      }
    }
    final queue = [for (final entry in incoming.entries) if (entry.value == 0) entry.key];
    var visited = 0;
    for (var i = 0; i < queue.length; i++) {
      visited++;
      for (final child in children[queue[i]] ?? const <String>[]) {
        incoming[child] = incoming[child]! - 1;
        if (incoming[child] == 0) queue.add(child);
      }
    }
    if (visited != byId.length) {
      throw StateError('부모 관계가 순환합니다. 인물의 부모 연결을 확인하세요.');
    }
  }
}
