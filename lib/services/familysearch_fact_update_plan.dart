/// 기존 생몰 항목에 대한 로컬 변경안. 실제 FamilySearch 전송은 수행하지 않는다.
class FamilySearchFactUpdatePlan {
  final String personId;
  final String factId;
  final String type;
  final Map<String, dynamic> previous;
  final Map<String, dynamic> proposed;
  final String reason;
  final String priorContributor;
  final String priorModified;
  final String priorReason;
  final List<String> priorSourceReferences;

  const FamilySearchFactUpdatePlan._(this.personId, this.factId, this.type,
      this.previous, this.proposed, this.reason, this.priorContributor,
      this.priorModified, this.priorReason, this.priorSourceReferences);

  static FamilySearchFactUpdatePlan prepare({required Map<String, dynamic> remote,
      required Map<String, dynamic> incoming, required String factId,
      required String type, required String reason}) {
    if (!const {'http://gedcomx.org/Birth', 'http://gedcomx.org/Death'}.contains(type)) {
      throw StateError('출생 또는 사망 항목을 선택하세요.');
    }
    final personId = remote['id'];
    if (personId is! String || personId.trim().isEmpty || factId.trim().isEmpty) {
      throw StateError('기존 인물과 항목 ID를 확인하세요.');
    }
    if (reason.trim().isEmpty) throw StateError('변경 근거를 입력하세요.');
    final remoteFacts = remote['facts'];
    final incomingFacts = incoming['facts'];
    if (remoteFacts is! List || incomingFacts is! List) {
      throw StateError('기존 기록과 앱 기록을 확인하세요.');
    }
    final matches = remoteFacts.whereType<Map>().where((fact) =>
        fact['id'] == factId && fact['type'] == type).toList();
    final candidates = incomingFacts.whereType<Map>().where((fact) => fact['type'] == type).toList();
    if (matches.length != 1 || candidates.length != 1) {
      throw StateError('수정할 기존 항목과 앱 항목을 각각 하나씩 확인하세요.');
    }
    Map<String, dynamic> knownValues(Map fact, {bool preserveExisting = false}) {
      final result = <String, dynamic>{};
      for (final field in ['date', 'place']) {
        final value = fact[field];
        if (preserveExisting && value is Map && value.isNotEmpty) {
          result[field] = Map<String, dynamic>.from(value);
        } else if (value is Map && value['original'] is String &&
            (value['original'] as String).trim().isNotEmpty) {
          result[field] = {'original': value['original']};
        }
      }
      return result;
    }
    final oldValues = knownValues(matches.single, preserveExisting: true);
    final newValues = knownValues(candidates.single);
    if (newValues.isEmpty) throw StateError('수정할 날짜 또는 장소가 없습니다.');
    final fact = matches.single;
    final attribution = fact['attribution'];
    String nonempty(dynamic value) => value is String && value.trim().isNotEmpty
        ? value.trim() : '응답에 없음';
    final contributor = attribution is Map ? attribution['contributor'] : null;
    final contributorReference = contributor is Map
        ? nonempty(contributor['resourceId'] ?? contributor['resource']) : '응답에 없음';
    final modified = attribution is Map ? attribution['modified'] : null;
    final modifiedText = modified is num ? modified.toString() : nonempty(modified);
    final priorReason = attribution is Map ? nonempty(attribution['changeMessage']) : '응답에 없음';
    final sources = fact['sources'];
    final references = <String>[];
    if (sources is List) {
      for (final source in sources) {
        if (source is! Map) continue;
        final reference = source['description'] ?? source['id'];
        if (reference is String && reference.trim().isNotEmpty) references.add(reference.trim());
      }
    }
    return FamilySearchFactUpdatePlan._(personId, factId, type,
        Map.unmodifiable(oldValues), Map.unmodifiable({...oldValues, ...newValues}), reason.trim(),
        contributorReference, modifiedText, priorReason, List.unmodifiable(references));
  }
}
