import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/familysearch_service.dart';

void main() {
  test('테스트 서버와 운영 서버의 인물 ID 및 대기 기록은 분리한다', () {
    expect(FamilySearchService.personIdConfigKey('p', sandbox: true), 'fs_person_id_p');
    expect(FamilySearchService.personIdConfigKey('p', sandbox: false), 'fs_production_person_id_p');
    expect(FamilySearchService.pendingConfigKey('p', sandbox: true), 'fs_upload_pending_p');
    expect(FamilySearchService.pendingConfigKey('p', sandbox: false), 'fs_production_upload_pending_p');
  });
  test('잘못된 인물 ID는 조회하지 않는다', () async {
    for (final id in ['', '../ABC-123', 'ABC 123', 'ABC/123']) {
      expect(await FamilySearchService.readPerson(id), isNull, reason: id);
    }
  });
}
