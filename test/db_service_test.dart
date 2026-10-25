import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  final service = DbService.instance;
  late Directory directory;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('jokbo-db-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return directory.path;
      }
      throw MissingPluginException(call.method);
    });
    final legacy = await openDatabase('${directory.path}/family_search.db', version: 7,
        onCreate: (db, version) async {
      final columns = Person(id: 'legacy').toMap().keys.where((key) =>
          key != 'source_document_path' && key != 'source_page_number');
      await db.execute('CREATE TABLE persons (${columns.map((key) =>
          '$key ${key == 'id' ? 'TEXT PRIMARY KEY' : key == 'sega' ? 'INTEGER' : 'TEXT'}').join(',')})');
      await db.execute('CREATE TABLE app_config (k TEXT PRIMARY KEY, v TEXT)');
      await db.insert('persons', Person(id: 'legacy', rawText: '기존 원문 보존').toMap()
        ..remove('source_document_path')..remove('source_page_number'));
    });
    await legacy.close();
    await service.open();
    expect((await service.getPerson('legacy'))!.rawText, '기존 원문 보존');
    expect(await service.db.getVersion(), 8);
  });

  tearDownAll(() async {
    await service.db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    await directory.delete(recursive: true);
  });

  setUp(() async => service.clearAll());

  test('PDF 출처·페이지·OCR 원문을 인물과 함께 보존한다', () async {
    final person = Person(id: 'pdf-person', nameHanja: '格',
        sourceDocumentPath: 'original.pdf', sourcePageNumber: 2,
        sourceImagePath: 'page-2.png', rawText: '子格');
    await service.upsertPersonsAtomically([person], sourceOcrText: 'OCR 원문 전체');
    final saved = (await service.getPerson(person.id))!;
    expect(saved.sourceDocumentPath, 'original.pdf');
    expect(saved.sourcePageNumber, 2);
    expect(saved.sourceImagePath, 'page-2.png');
    expect(await service.getConfig('ocr_source:${person.id}'), 'OCR 원문 전체');
  });

  test('일괄 저장은 가족관계와 OCR 원문을 함께 보존한다', () async {
    final parent = Person(id: 'parent', childrenIds: ['child'], rawText: '원본 父');
    final child = Person(id: 'child', fatherId: parent.id, rawText: '원본 子');

    await service.upsertPersonsAtomically([parent, child]);

    expect(await service.count(), 2);
    expect((await service.getPerson(parent.id))!.childrenIds, ['child']);
    final savedChild = (await service.getPerson(child.id))!;
    expect(savedChild.fatherId, parent.id);
    expect(savedChild.rawText, child.rawText);
  });

  test('중간 저장 실패 시 수정과 신규 삽입을 모두 롤백한다', () async {
    await service.upsertPerson(Person(id: 'existing', rawText: '보존할 원문'));
    await service.db.execute('''
      CREATE TEMP TRIGGER fail_person BEFORE INSERT ON persons
      WHEN NEW.id = 'fail'
      BEGIN SELECT RAISE(ABORT, 'forced test failure'); END
    ''');
    try {
      await expectLater(
        service.upsertPersonsAtomically([
          Person(id: 'existing', rawText: '저장 실패할 수정'),
          Person(id: 'new'),
          Person(id: 'fail'),
          Person(id: 'after-failure'),
        ]),
        throwsA(isA<DatabaseException>()),
      );

      expect(await service.count(), 1);
      expect((await service.getPerson('existing'))!.rawText, '보존할 원문');
      expect(await service.getPerson('new'), isNull);
      expect(await service.getPerson('after-failure'), isNull);
    } finally {
      await service.db.execute('DROP TRIGGER fail_person');
    }
  });
}
