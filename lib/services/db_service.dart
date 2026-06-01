import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/person.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  Database? _db;

  Future<void> open() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'family_search.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE persons (
            id TEXT PRIMARY KEY,
            name_hanja TEXT, name_hangul TEXT, name_roman TEXT,
            ja TEXT, ho TEXT, siho TEXT, bongwan TEXT, pa TEXT, sega INTEGER,
            gender TEXT,
            birth_date_lunar TEXT, birth_date_solar TEXT, birth_place TEXT,
            marriage_date TEXT, marriage_place TEXT,
            spouse_hanja TEXT, spouse_hangul TEXT, spouse_father TEXT, spouse_bongwan TEXT,
            death_date_lunar TEXT, death_date_solar TEXT, death_place TEXT,
            burial_place TEXT, burial_orientation TEXT,
            father_id TEXT, mother_id TEXT,
            children_ids TEXT, sons_in_law_ids TEXT, in_laws_ids TEXT,
            source_image_path TEXT, raw_text TEXT,
            created_at TEXT, updated_at TEXT
          )''');
        await db.execute(
            'CREATE INDEX idx_name_hangul ON persons(name_hangul)');
        await db.execute('CREATE INDEX idx_sega ON persons(sega)');
      },
    );
  }

  Database get db => _db!;

  Future<void> upsertPerson(Person p) async {
    await db.insert('persons', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Person>> listPersons({String? search}) async {
    final rows = search == null || search.isEmpty
        ? await db.query('persons', orderBy: 'updated_at DESC')
        : await db.query('persons',
            where: 'name_hangul LIKE ? OR name_hanja LIKE ?',
            whereArgs: ['%$search%', '%$search%'],
            orderBy: 'updated_at DESC');
    return rows.map(Person.fromMap).toList();
  }

  Future<Person?> getPerson(String id) async {
    final rows = await db.query('persons', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Person.fromMap(rows.first);
  }

  Future<void> deletePerson(String id) async {
    await db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM persons');
    return Sqflite.firstIntValue(r) ?? 0;
  }
}
