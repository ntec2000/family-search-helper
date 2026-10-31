import '../lib/models/person.dart';
import '../lib/services/unknown_spouse_name.dart';
import '../lib/services/familysearch_record.dart';
import '../lib/services/gedcom_export.dart';
void main() {
  var checks = 0;
  void check(Object? actual, Object? expected) {
    if (actual != expected) throw StateError('Expected $expected; actual $actual');
    checks++;
  }
  for (final input in ['파평 윤씨', '파평윤씨', '파평  윤씨']) {
    final h = Person(id: 'h', gender: 'M', nameHangul: '홍길동', spouseHangul: input, spouseBongwan: '파평');
    final original = h.toMap().toString();
    check(UnknownSpouseName.wifeDisplayName(h), '윤씨');
    check(h.toMap().toString(), original);
  }
  final h = Person(id: 'h', gender: 'M', nameHangul: '홍길동', spouseHangul: '파평 윤씨');
  check(UnknownSpouseName.wifeDisplayName(h), '윤씨');
  h.spouseHangul = '파평윤씨';
  check(UnknownSpouseName.wifeDisplayName(h), '홍길동의 부인');
  h.spouseHangul = '윤씨';
  check(UnknownSpouseName.wifeDisplayName(h), '윤씨');
  h.spouseHangul = null;
  h.spouseHanja = '坡平尹氏';
  check(UnknownSpouseName.wifeDisplayName(h), '윤씨');
  check(UnknownSpouseName.wifeDisplayName(h, confirmedWifeName: '김영희'), '김영희');
  h.spouseHanja = null;
  h.spouseHangul = '파평 윤씨';
  final record = FamilySearchRecord.person(h);
  check(record['notes'].toString().contains('아내 표시명(실제 개인 이름 아님): 윤씨'), true);
  check(record['names'].toString().contains('윤씨'), false);
  final gedcom = GedcomExport.toGedcom([h]);
  check(gedcom.contains('1 NOTE 아내 표시명(실제 개인 이름 아님): 윤씨'), true);
  check(RegExp(r' INDI$', multiLine: true).allMatches(gedcom).length, 1);
  print('PASS: $checks checks');
}
