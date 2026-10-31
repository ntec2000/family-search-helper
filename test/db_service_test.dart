import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/db_service.dart';
import 'package:family_search_helper/screens/home_screen.dart';
import 'package:family_search_helper/theme/traditional_theme.dart';

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

  test('확인한 FamilySearch ID는 기존 연결·대기·중복을 원자적으로 보호한다', () async {
    await service.upsertPerson(Person(id: 'bind-a'));
    await service.upsertPerson(Person(id: 'bind-b'));
    await service.bindConfirmedFamilySearchId(personId: 'bind-a',
        targetId: 'abcd-123', sandbox: true);
    expect(await service.getConfig('fs_person_id_bind-a'), 'ABCD-123');
    await expectLater(service.bindConfirmedFamilySearchId(personId: 'bind-a',
        targetId: 'OTHER-1', sandbox: true), throwsStateError);
    await expectLater(service.bindConfirmedFamilySearchId(personId: 'bind-b',
        targetId: 'abcd-123', sandbox: true), throwsStateError);
    await service.setConfig('fs_upload_pending_bind-b', '1');
    await expectLater(service.bindConfirmedFamilySearchId(personId: 'bind-b',
        targetId: 'NEWID-1', sandbox: true), throwsStateError);
    expect(await service.getConfig('fs_person_id_bind-a'), 'ABCD-123');
    expect(await service.getConfig('fs_person_id_bind-b'), isNull);
    expect(await service.getConfig('fs_upload_pending_bind-b'), '1');
    await service.bindConfirmedFamilySearchId(personId: 'bind-b',
        targetId: 'ABCD-123', sandbox: false);
    expect(await service.getConfig('fs_production_person_id_bind-b'), 'ABCD-123');
  });

  testWidgets('홈 화면은 좁은 화면과 큰 글씨에서도 가로로 넘치지 않는다', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(360, 740), const Size(740, 360)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(ProviderScope(child: MaterialApp(
        theme: TraditionalTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.7)),
          child: child!), home: const HomeScreen())));
      await tester.runAsync(() => service.listPersons());
      await tester.pumpAndSettle();
      expect(find.text('등록된 인물 0명'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
    final parent = Person(id: 'parent', gender: 'M', childrenIds: ['child'], rawText: '원본 父');
    final child = Person(id: 'child', fatherId: parent.id, rawText: '원본 子');

    await service.upsertPersonsAtomically([parent, child]);

    expect(await service.count(), 2);
    expect((await service.getPerson(parent.id))!.childrenIds, ['child']);
    final savedChild = (await service.getPerson(child.id))!;
    expect(savedChild.fatherId, parent.id);
    expect(savedChild.rawText, child.rawText);
  });

  test('잘못된 관계 ID는 인물과 OCR 원문을 모두 저장하지 않는다', () async {
    await service.upsertPerson(Person(id: 'existing', rawText: '기존 원문'));
    await expectLater(
      service.upsertPersonsAtomically([
        Person(id: 'existing', rawText: '변경 시도'),
        Person(id: 'new-child', fatherId: 'missing-father'),
      ], sourceOcrText: '저장되면 안 되는 OCR'),
      throwsA(isA<StateError>()),
    );
    expect((await service.getPerson('existing'))!.rawText, '기존 원문');
    expect(await service.getPerson('new-child'), isNull);
    expect(await service.getConfig('ocr_source:existing'), isNull);
  });

  test('기존 DB 인물과의 관계는 OCR 원문과 함께 저장한다', () async {
    await service.upsertPerson(Person(id: 'existing-father', gender: 'M'));
    await service.upsertPersonsAtomically([
      Person(id: 'new-child', fatherId: 'existing-father'),
    ], sourceOcrText: '원본 족보 OCR');
    expect((await service.getPerson('new-child'))!.fatherId, 'existing-father');
    expect(await service.getConfig('ocr_source:new-child'), '원본 족보 OCR');
  });

  test('중복 인물 ID는 기존 기록을 덮어쓰지 않고 저장을 거부한다', () async {
    await service.upsertPerson(Person(id: 'same', rawText: '원본 보존'));
    await expectLater(
      service.upsertPersonsAtomically([
        Person(id: 'same', rawText: '첫 번째 후보'),
        Person(id: 'same', rawText: '두 번째 후보'),
      ], sourceOcrText: '중복 OCR'),
      throwsA(isA<StateError>()),
    );
    expect((await service.getPerson('same'))!.rawText, '원본 보존');
    expect(await service.getConfig('ocr_source:same'), isNull);
  });

  test('자녀 참조가 저장 대상에 포함되면 함께 저장한다', () async {
    final parent = Person(id: 'batch-parent', gender: 'M',
        childrenIds: ['batch-child']);
    final child = Person(id: 'batch-child', fatherId: parent.id);
    await service.upsertPersonsAtomically([parent, child],
        sourceOcrText: '父子 원문');
    expect((await service.getPerson(parent.id))!.childrenIds, ['batch-child']);
    expect((await service.getPerson(child.id))!.fatherId, parent.id);
    expect(await service.getConfig('ocr_source:batch-parent'), '父子 원문');
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
  test('순환 가족관계 오류는 기존 인물과 OCR 원문을 보존한다', () async {
    await service.upsertPerson(Person(id: 'existing', rawText: '기존 족보 원문'));
    final a = Person(id: 'cycle-a', gender: 'M', childrenIds: ['cycle-b']);
    final b = Person(id: 'cycle-b', gender: 'M', childrenIds: ['cycle-a']);
    await expectLater(
      service.upsertPersonsAtomically([
        Person(id: 'existing', rawText: '잘못된 덮어쓰기'),
        a, b,
      ], sourceOcrText: '저장 금지 OCR'),
      throwsA(isA<StateError>()),
    );
    expect((await service.getPerson('existing'))!.rawText, '기존 족보 원문');
    expect(await service.getPerson('cycle-a'), isNull);
    expect(await service.getPerson('cycle-b'), isNull);
    expect(await service.getConfig('ocr_source:existing'), isNull);
  });

  test('세대 불일치 저장 실패 시 기존 기록과 신규 기록을 보존한다', () async {
    await service.upsertPerson(Person(id: 'original', rawText: '원본 보존'));
    final parent = Person(id: 'p20', gender: 'M', sega: 20,
        childrenIds: ['p22']);
    final child = Person(id: 'p22', gender: 'M', sega: 22,
        fatherId: parent.id);
    await expectLater(
      service.upsertPersonsAtomically([
        Person(id: 'original', rawText: '변경 시도'), parent, child,
      ], sourceOcrText: '잘못된 OCR'),
      throwsA(isA<StateError>()),
    );
    expect((await service.getPerson('original'))!.rawText, '원본 보존');
    expect(await service.getPerson('p20'), isNull);
    expect(await service.getPerson('p22'), isNull);
    expect(await service.getConfig('ocr_source:original'), isNull);
  });

}
