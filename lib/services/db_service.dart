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
      version: 7,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE persons (
            id TEXT PRIMARY KEY,
            name_hanja TEXT, name_hangul TEXT, name_roman TEXT,
            surname_hanja TEXT, surname_hangul TEXT,
            ja TEXT, ho TEXT, siho TEXT, bongwan TEXT, pa TEXT, sega INTEGER,
            gender TEXT,
            birth_date_lunar TEXT, birth_date_solar TEXT, birth_place TEXT,
            marriage_date TEXT, marriage_place TEXT,
            spouse_hanja TEXT, spouse_hangul TEXT, spouse_father TEXT,
            spouse_mother TEXT, spouse_bongwan TEXT,
            spouse_grandfather TEXT, spouse_great_grandfather TEXT,
            spouse_maternal_grandfather TEXT, spouse_birth TEXT, spouse_death TEXT,
            death_date_lunar TEXT, death_date_solar TEXT, death_place TEXT,
            burial_place TEXT, burial_orientation TEXT,
            father_id TEXT, mother_id TEXT,
            children_ids TEXT, sons_in_law_ids TEXT, in_laws_ids TEXT,
            children_note TEXT, sons_in_law_note TEXT, in_laws_note TEXT,
            in_laws_spouse_note TEXT, reason_statement TEXT, note TEXT,
            relation TEXT,
            source_image_path TEXT, raw_text TEXT,
            created_at TEXT, updated_at TEXT
          )''');
        await db.execute(
            'CREATE INDEX idx_name_hangul ON persons(name_hangul)');
        await db.execute('CREATE INDEX idx_sega ON persons(sega)');
        await db.execute(
            'CREATE TABLE app_config (k TEXT PRIMARY KEY, v TEXT)');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS app_config (k TEXT PRIMARY KEY, v TEXT)');
        }
        if (oldV < 3) {
          // #16 추가 컬럼 — 기존 사용자 데이터 보존하며 안전하게 추가
          for (final col in const [
            'children_note',
            'sons_in_law_note',
            'in_laws_note',
          ]) {
            try {
              await db.execute('ALTER TABLE persons ADD COLUMN $col TEXT');
            } catch (_) {
              // 이미 존재하면 무시
            }
          }
        }
        if (oldV < 4) {
          // v2.2 추가 컬럼 — 성씨 분리·장모·사돈부인·근거 진술
          for (final col in const [
            'surname_hanja',
            'surname_hangul',
            'spouse_mother',
            'in_laws_spouse_note',
            'reason_statement',
          ]) {
            try {
              await db.execute('ALTER TABLE persons ADD COLUMN $col TEXT');
            } catch (_) {
              // 이미 존재하면 무시
            }
          }
        }
        if (oldV < 5) {
          // v2.3 추가 컬럼 — 처가(妻家) 계열(장인의 부·증조·아내 외조) + 배우자 생·졸
          for (final col in const [
            'spouse_grandfather',
            'spouse_great_grandfather',
            'spouse_maternal_grandfather',
            'spouse_birth',
            'spouse_death',
          ]) {
            try {
              await db.execute('ALTER TABLE persons ADD COLUMN $col TEXT');
            } catch (_) {
              // 이미 존재하면 무시
            }
          }
        }
        if (oldV < 6) {
          // v2.4 추가 컬럼 — 특이사항/메모(出系·양자·한글 오기 등)
          try {
            await db.execute('ALTER TABLE persons ADD COLUMN note TEXT');
          } catch (_) {
            // 이미 존재하면 무시
          }
        }
        if (oldV < 7) {
          // v2.6 추가 컬럼 — 아버지와의 가족관계(첫째아들/둘째딸 등)
          try {
            await db.execute('ALTER TABLE persons ADD COLUMN relation TEXT');
          } catch (_) {
            // 이미 존재하면 무시
          }
        }
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

  /// v2.6 — 등록된 인물 전체 삭제 (새로고침/초기화 시 사용)
  Future<void> clearAll() async {
    await db.delete('persons');
  }

  Future<int> count() async {
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM persons');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // ─── 앱 설정 (키-값) ──────────────────────────────────────
  Future<String?> getConfig(String key) async {
    final rows =
        await db.query('app_config', where: 'k = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['v'] as String?;
  }

  Future<void> setConfig(String key, String value) async {
    await db.insert('app_config', {'k': key, 'v': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
