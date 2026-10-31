import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/familysearch_service.dart';

void main() {
  test('조회할 인물 ID의 앞뒤 공백과 대소문자를 정리한다', () {
    expect(FamilySearchService.normalizePersonId(' abcd-123 '), 'ABCD-123');
    expect(FamilySearchService.normalizePersonId('../bad'), isNull);
  });

  test('미확인 등록 또는 잘못된 ID는 부모 연결 선택 목록에서 제외한다', () {
    expect(FamilySearchService.selectableLinkedId('abcd-123', '1'), isNull);
    expect(FamilySearchService.selectableLinkedId('../bad', '0'), isNull);
    expect(FamilySearchService.selectableLinkedId(null, '0'), isNull);
    expect(FamilySearchService.selectableLinkedId(' abcd-123 ', '0'), 'ABCD-123');
  });
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
