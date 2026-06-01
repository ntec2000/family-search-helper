import 'package:flutter/material.dart';
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Person> _persons = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await DbService.instance.listPersons(search: _search);
    if (mounted) setState(() => _persons = list);
  }

  Future<void> _pickFromGallery() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null && mounted) {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => CaptureScreen(imagePath: x.path)));
      _reload();
    }
  }

  void _openMenu(String route) {
    Widget? page;
    switch (route) {
      case 'tree': page = const FamilyTreeScreen(); break;
      case 'lunar': page = const LunarConverterScreen(); break;
      case 'export': page = const ExportScreen(); break;
      case 'familysearch': page = const FamilySearchLoginScreen(); break;
      case 'settings': page = const SettingsScreen(); break;
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _openMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'tree', child: Row(children: [Icon(Icons.account_tree, color: HanjiColors.muk), SizedBox(width: 12), Text('가계도')])),
              PopupMenuItem(value: 'lunar', child: Row(children: [Icon(Icons.calendar_month, color: HanjiColors.muk), SizedBox(width: 12), Text('만세력')])),
              PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.ios_share, color: HanjiColors.muk), SizedBox(width: 12), Text('내보내기')])),
              PopupMenuDivider(),
              PopupMenuItem(value: 'familysearch', child: Row(children: [Icon(Icons.church_outlined, color: HanjiColors.ju), SizedBox(width: 12), Text('FamilySearch 연동')])),
              PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_outlined, color: HanjiColors.muk), SizedBox(width: 12), Text('설정')])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '이름(한글/한자)으로 검색',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                _search = v;
                _reload();
              },
            ),
          ),
          _Banner(count: _persons.length),
          Expanded(
            child: _persons.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
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
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HanjiColors.hanjiLight,
        border: Border.all(color: HanjiColors.mukSoft, width: 0.5),
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
              style: const TextStyle(
                  color: HanjiColors.mukSoft, fontFamily: 'NotoSerifKR')),
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
