import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/db_service.dart';
import '../theme/traditional_theme.dart';
import 'person_card_screen.dart';

/// 가계도(Family Tree) 시각화 화면.
/// 등록된 인물들을 부-자-손 관계로 트리 형태로 표시.
/// (관계가 미설정된 인물은 동일 세대 그룹으로 표시)
class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});
  @override
  State<FamilyTreeScreen> createState() => _State();
}

class _State extends State<FamilyTreeScreen> {
  List<Person> _persons = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DbService.instance.listPersons();
    setState(() => _persons = list);
  }

  /// 세(世) 별로 그룹핑. 세 정보 없으면 0세대.
  Map<int, List<Person>> _bySega() {
    final map = <int, List<Person>>{};
    for (final p in _persons) {
      final s = p.sega ?? 0;
      map.putIfAbsent(s, () => []).add(p);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _bySega();
    return Scaffold(
      appBar: AppBar(title: const Text('가계도 (家系圖)')),
      body: _persons.isEmpty
          ? const Center(
              child: Text('등록된 인물이 없습니다.',
                  style: TextStyle(color: HanjiColors.mukSoft)))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: grouped.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: HanjiColors.muk, width: 0.5),
                              color: HanjiColors.hanjiLight,
                            ),
                            child: Column(
                              children: [
                                Text(
                                    e.key == 0
                                        ? '?'
                                        : '${e.key}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: HanjiColors.muk)),
                                const Text('世',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: HanjiColors.mukSoft)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children:
                                e.value.map((p) => _PersonNode(person: p)).toList(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}

class _PersonNode extends StatelessWidget {
  final Person person;
  const _PersonNode({required this.person});

  @override
  Widget build(BuildContext context) {
    final isMale = person.gender == 'M';
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PersonCardScreen(personId: person.id))),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: HanjiColors.hanjiLight,
          border: Border.all(
              color: isMale ? HanjiColors.muk : HanjiColors.ju,
              width: 1.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Text(person.nameHanja,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isMale ? HanjiColors.muk : HanjiColors.ju,
                    letterSpacing: 2)),
            const SizedBox(height: 2),
            Text(person.nameHangul,
                style: const TextStyle(
                    fontSize: 12, color: HanjiColors.mukSoft)),
            if (person.ja != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('字 ${person.ja}',
                    style: const TextStyle(
                        fontSize: 10, color: HanjiColors.mukSoft)),
              ),
            if (person.birthDateLunar != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(person.birthDateLunar!.split(' ').first,
                    style: const TextStyle(fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }
}
