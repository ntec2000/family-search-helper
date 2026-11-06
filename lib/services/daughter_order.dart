import '../models/person.dart';

/// Parser-derived order is scoped to an explicitly linked father.
/// The displayed order is record order, not a newly asserted birth order.
class DaughterOrder {
  static const _labels = ['첫째', '둘째', '셋째', '넷째', '다섯째',
    '여섯째', '일곱째', '여덟째', '아홉째', '열째'];
  static String label(Person person, List<Person> people) {
    final original = (person.relation ?? '').trim();
    if (person.gender != 'F' || !original.contains('딸') ||
        (person.fatherId ?? '').isEmpty ||
        !(person.note ?? '').contains('女 등장 순서')) {
      return original;
    }
    final siblings = people.where((p) => p.gender == 'F' &&
        p.fatherId == person.fatherId && (p.relation ?? '').contains('딸')).toList();
    final index = siblings.indexWhere((p) => p.id == person.id);
    return index < 0 ? original :
        '${index < _labels.length ? _labels[index] : "${index + 1}번째"}딸';
  }
}
