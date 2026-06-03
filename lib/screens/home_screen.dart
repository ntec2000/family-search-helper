import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/person.dart';
import '../services/db_service.dart';
import '../theme/traditional_theme.dart';
import 'capture_screen.dart';
import 'person_card_screen.dart';
import 'lunar_converter_screen.dart';
import 'export_screen.dart';
import 'settings_screen.dart';
import 'family_tree_screen.dart';
import 'familysearch_login_screen.dart';
import 'hanja_tools_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Person> _persons = [];
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await DbService.instance.listPersons(search: _search);
    if (mounted) setState(() => _persons = list);
  }

  /// #11 — 검색 버튼/엔터로만 검색 실행
  void _runSearch() {
    _search = _searchCtrl.text.trim();
    _reload();
  }

  /// #3 — 메인화면 리플레쉬: 검색 초기화 후 초기 화면으로
  void _refresh() {
    _searchCtrl.clear();
    _search = '';
    _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초기 화면으로 새로고침했습니다')),
      );
    }
  }

  /// v2.2 — 인물 직접 추가. 빈 인물을 만들고 인물카드(동일 입력항목)로 이동.
  Future<void> _addPerson() async {
    final now = DateTime.now();
    final person = Person(
      id: 'manual_${now.millisecondsSinceEpoch}',
      createdAt: now,
      updatedAt: now,
    );
    await DbService.instance.upsertPerson(person);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PersonCardScreen(personId: person.id)),
    );
    _reload();
  }

  /// #2 — 앱 종료
  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('앱 종료'),
        content: const Text('가족역사기록 도우미를 종료하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('종료')),
        ],
      ),
    );
    if (ok == true) {
      SystemNavigator.pop();
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
      );
      if (x != null && mounted) {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => CaptureScreen(imagePath: x.path)));
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 불러오지 못했습니다: $e')),
        );
      }
    }
  }

  void _openMenu(String route) {
    Widget? page;
    switch (route) {
      case 'tree': page = const FamilyTreeScreen(); break;
      case 'lunar': page = const LunarConverterScreen(); break;
      case 'hanja': page = const HanjaToolsScreen(); break;
      case 'export': page = const ExportScreen(); break;
      case 'familysearch': page = const FamilySearchLoginScreen(); break;
      case 'settings': page = const SettingsScreen(); break;
      case 'exit': _confirmExit(); return;
    }
    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page!))
          .then((_) => _reload());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가족역사기록 도우미'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: '인물 추가',
            onPressed: _addPerson,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _refresh,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _openMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'tree', child: Row(children: [Icon(Icons.account_tree, color: HanjiColors.muk), SizedBox(width: 12), Text('가계도')])),
              PopupMenuItem(value: 'hanja', child: Row(children: [Icon(Icons.translate, color: HanjiColors.muk), SizedBox(width: 12), Text('한자 도구')])),
              PopupMenuItem(value: 'lunar', child: Row(children: [Icon(Icons.calendar_month, color: HanjiColors.muk), SizedBox(width: 12), Text('만세력')])),
              PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.ios_share, color: HanjiColors.muk), SizedBox(width: 12), Text('내보내기')])),
              PopupMenuDivider(),
              PopupMenuItem(value: 'familysearch', child: Row(children: [Icon(Icons.church_outlined, color: HanjiColors.ju), SizedBox(width: 12), Text('FamilySearch 연동')])),
              PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_outlined, color: HanjiColors.muk), SizedBox(width: 12), Text('설정')])),
              PopupMenuDivider(),
              PopupMenuItem(value: 'exit', child: Row(children: [Icon(Icons.exit_to_app, color: HanjiColors.ju), SizedBox(width: 12), Text('앱 종료')])),
            ],
          ),
        ],
      ),
      body: SafeArea(child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '이름(한글/한자)으로 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: '검색',
                  onPressed: _runSearch,
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _runSearch(),
            ),
          ),
          _Banner(count: _persons.length),
          Expanded(
            child: _persons.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _persons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _PersonTile(
                      person: _persons[i],
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    PersonCardScreen(personId: _persons[i].id)));
                        _reload();
                      },
                    ),
                  ),
          ),
        ],
      )),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'gallery',
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('갤러리'),
            backgroundColor: HanjiColors.mukSoft,
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'camera',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CaptureScreen()));
              _reload();
            },
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('촬영'),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final int count;
  const _Banner({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: HanjiColors.hanjiLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HanjiColors.hanjiDark, width: 1),
      ),
      child: Row(children: [
        const Icon(Icons.family_restroom, color: HanjiColors.ju, size: 20),
        const SizedBox(width: 8),
        Text('등록된 인물 $count명',
            style: const TextStyle(color: HanjiColors.muk, fontSize: 14)),
        const Spacer(),
        const Text('族譜 → FamilySearch',
            style: TextStyle(color: HanjiColors.mukSoft, fontSize: 12, letterSpacing: 1)),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.menu_book_outlined, size: 80, color: HanjiColors.mukSoft),
            SizedBox(height: 16),
            Text('族譜', style: TextStyle(fontSize: 36, color: HanjiColors.muk, letterSpacing: 8)),
            SizedBox(height: 8),
            Text('족보 사진을 촬영하거나 갤러리에서 선택하여\n한자 인식을 시작하세요',
                textAlign: TextAlign.center,
                style: TextStyle(color: HanjiColors.mukSoft, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final Person person;
  final VoidCallback onTap;
  const _PersonTile({required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              person.gender == 'M' ? HanjiColors.muk : HanjiColors.ju,
          foregroundColor: HanjiColors.hanji,
          child: Text(person.nameHanja.isNotEmpty ? person.nameHanja[0] : '?',
              style: const TextStyle(fontSize: 18)),
        ),
        title: Row(children: [
          Text(person.nameHangul,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(person.nameHanja,
              style: const TextStyle(color: HanjiColors.mukSoft)),
        ]),
        subtitle: Text(
          [
            if (person.birthDateLunar != null) '生 ${person.birthDateLunar}',
            if (person.deathDateLunar != null) '卒 ${person.deathDateLunar}',
          ].join('  ·  '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: HanjiColors.mukSoft),
      ),
    );
  }
}
