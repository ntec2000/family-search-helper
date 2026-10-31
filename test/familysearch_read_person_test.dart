import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/familysearch_service.dart';

void main() {
  test('잘못된 인물 ID는 조회하지 않는다', () async {
    for (final id in ['', '../ABC-123', 'ABC 123', 'ABC/123']) {
      expect(await FamilySearchService.readPerson(id), isNull, reason: id);
    }
  });
}
