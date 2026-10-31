import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/db_service.dart';
import 'package:family_search_helper/screens/home_screen.dart';
import 'package:family_search_helper/screens/export_screen.dart';
import 'package:family_search_helper/screens/person_card_screen.dart';
import 'package:family_search_helper/screens/family_tree_screen.dart';
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
        sourceImagePath: 'page-2.png', rawText: '子格',
        reasonStatement: '사용자가 선택한 OCR 문장 · 원본 대조 필요 · 입력 문서 2쪽');
    await service.upsertPersonsAtomically([person], sourceOcrText: 'OCR 원문 전체');
    final saved = (await service.getPerson(person.id))!;
    expect(saved.sourceDocumentPath, 'original.pdf');
    expect(saved.sourcePageNumber, 2);
    expect(saved.sourceImagePath, 'page-2.png');
    expect(saved.rawText, '子格');
    expect(saved.reasonStatement, '사용자가 선택한 OCR 문장 · 원본 대조 필요 · 입력 문서 2쪽');
    expect(await service.getConfig('ocr_source:${person.id}'), 'OCR 원문 전체');
  });

  testWidgets('텍스트 미리보기는 이름 독음을 성씨로 추측하거나 이름을 지우지 않는다', (tester) async {
    final people = [
      Person(id: 'name-wood', gender: 'M', nameHanja: '木', nameHangul: '목'),
      Person(id: 'name-hyeon', gender: 'M', nameHanja: '顯', nameHangul: '현'),
    ];
    await tester.runAsync(() async {
      for (final person in people) {
        await service.upsertPerson(person);
      }
    });
    await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
    await tester.ensureVisible(find.text('텍스트 (수동 입력용)'));
    await tester.tap(find.text('텍스트 (수동 입력용)'));
    await tester.runAsync(() => service.listPersons());
    await tester.pumpAndSettle();
    final text = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(text, contains('목 木'));
    expect(text, contains('현 顯'));
    expect(RegExp(r'성\(姓\)\s*:\s*목').hasMatch(text), isFalse);
    expect(RegExp(r'성\(姓\)\s*:\s*현').hasMatch(text), isFalse);
    for (final person in people) {
      final saved = await tester.runAsync(() => service.getPerson(person.id));
      expect(saved!.toMap(), person.toMap());
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('인물 카드를 열어 저장해도 미확인 성씨를 만들지 않고 확인한 성씨는 유지한다', (tester) async {
    for (final person in [
      Person(id: 'card-unknown', gender: 'M', nameHanja: '木', nameHangul: '목', rawText: 'OCR 원문'),
      Person(id: 'card-known', gender: 'M', nameHanja: '格', nameHangul: '격',
          surnameHanja: '李', surnameHangul: '이', rawText: '확인한 원문'),
    ]) {
      await tester.runAsync(() => service.upsertPerson(person));
      await tester.pumpWidget(MaterialApp(home: PersonCardScreen(
          key: ValueKey(person.id), personId: person.id)));
      await tester.runAsync(() => service.getPerson(person.id));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.save));
      final saved = await tester.runAsync(() => service.getPerson(person.id));
      await tester.pumpAndSettle();
      expect(saved!.surnameHangul, person.surnameHangul);
      expect(saved.surnameHanja, person.surnameHanja);
      expect(saved.nameHangul, person.nameHangul);
      expect(saved.nameHanja, person.nameHanja);
      expect(saved.rawText, person.rawText);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('가계도는 이름 독음을 본인 성씨나 자녀의 상속 성씨로 추측하지 않는다', (tester) async {
    final person = Person(id: 'tree-unknown', gender: 'M',
        nameHanja: '木', nameHangul: '목', childrenNote: '火(화)', rawText: '원문');
    await tester.runAsync(() => service.upsertPerson(person));
    await tester.pumpWidget(const MaterialApp(home: FamilyTreeScreen()));
    await tester.runAsync(() => service.listPersons());
    await tester.pumpAndSettle();
    expect(find.text('木\n목'), findsOneWidget);
    expect(find.text('목'), findsNothing);
    final saved = await tester.runAsync(() => service.getPerson(person.id));
    expect(saved!.toMap(), person.toMap());
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<void> openTree(WidgetTester tester, List<Person> people) async {
    await tester.runAsync(() async {
      for (final person in people) {
        await service.upsertPerson(person);
      }
    });
    await tester.pumpWidget(const MaterialApp(home: FamilyTreeScreen()));
    await tester.runAsync(() => service.listPersons());
    await tester.pumpAndSettle();
  }

  testWidgets('가계도는 동명이인 자녀 후보를 임의 카드에 연결하지 않는다', (tester) async {
    final people = [
      Person(id: 'duplicate-focus', nameHanja: '正明', nameHangul: '정명',
          gender: 'M', childrenNote: '甲順(갑순)'),
      Person(id: 'duplicate-a', nameHanja: '甲順', nameHangul: '갑순', gender: 'M'),
      Person(id: 'duplicate-b', nameHanja: '甲順', nameHangul: '갑순', gender: 'M'),
    ];
    await openTree(tester, people);
    expect(find.byIcon(Icons.touch_app), findsOneWidget);
    expect(find.text('자녀 후보 · 확인 필요'), findsOneWidget);
    for (final person in people) {
      final saved = await tester.runAsync(() => service.getPerson(person.id));
      expect(saved!.toMap(), person.toMap());
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('가계도는 같은 한글보다 입력된 한자가 맞는 인물 카드로 이동한다', (tester) async {
    final right = Person(id: 'hanja-right', nameHanja: '格', nameHangul: '격',
        gender: 'M', updatedAt: DateTime(2000));
    final wrong = Person(id: 'hanja-wrong', nameHanja: '珏', nameHangul: '격',
        gender: 'M', updatedAt: DateTime(2020));
    await openTree(tester, [
      Person(id: 'hanja-focus', nameHanja: '正明', nameHangul: '정명',
          gender: 'M', childrenNote: '格(격)'), right, wrong,
    ]);
    await tester.tap(find.text('格\n격'));
    await tester.pump();
    await tester.runAsync(() => service.getPerson(right.id));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == '이름 (한자)'));
    expect(field.controller!.text, '格');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.runAsync(() => service.listPersons());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('가계도 자녀 메모의 같은 이름을 중심 인물 본인에게 연결하지 않는다', (tester) async {
    await openTree(tester, [Person(id: 'self-focus', gender: 'M',
        nameHanja: '正明', nameHangul: '정명', childrenNote: '正明(정명)')]);
    expect(find.byIcon(Icons.touch_app), findsOneWidget);
    expect(find.text('자녀 후보 · 확인 필요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('텍스트 배우자는 성씨로 표시하고 자동 모친 표시는 원문 미확인으로 구분한다', (tester) async {
    final person = Person(id: 'spouse-display', gender: 'M',
        nameHanja: '格', nameHangul: '격', spouseHangul: '파평윤씨',
        spouseHanja: '坡平尹氏', spouseBongwan: '坡平', spouseFather: '光岳');
    await tester.runAsync(() => service.upsertPerson(person));
    await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
    await tester.ensureVisible(find.text('텍스트 (수동 입력용)'));
    await tester.tap(find.text('텍스트 (수동 입력용)'));
    await tester.runAsync(() => service.listPersons());
    await tester.pumpAndSettle();
    final text = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    expect(text, contains('배우자    : 윤씨 (坡平尹氏)'));
    expect(text, contains('배우자 모친 표시명(원문 미확인)'));
    expect(text, isNot(contains('배우자 모친 :')));
    final saved = await tester.runAsync(() => service.getPerson(person.id));
    expect(saved!.toMap(), person.toMap());
    await tester.pumpWidget(const SizedBox.shrink());
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

  test('기존 DB 부모의 성별이 역할과 다르면 두 저장 경로 모두 거부한다', () async {
    for (final atomic in [true, false]) {
      for (final father in [true, false]) {
        final suffix = '$atomic-$father';
        final parent = Person(id: 'parent-$suffix',
            gender: father ? 'F' : 'M', rawText: '기존 부모 원문');
        final existing = Person(id: 'existing-$suffix', rawText: '기존 인물 원문');
        await service.upsertPerson(parent);
        await service.upsertPerson(existing);
        final pending = [
          Person(id: existing.id, rawText: '저장되면 안 되는 수정'),
          Person(id: 'child-$suffix', fatherId: father ? parent.id : null,
              motherId: father ? null : parent.id),
        ];
        await expectLater(atomic
            ? service.upsertPersonsAtomically(pending, sourceOcrText: '저장 금지 OCR')
            : service.upsertPersonsValidated(pending), throwsStateError);
        expect((await service.getPerson(existing.id))!.rawText, '기존 인물 원문');
        expect((await service.getPerson(parent.id))!.rawText, '기존 부모 원문');
        expect(await service.getPerson('child-$suffix'), isNull);
        expect(await service.getConfig('ocr_source:${existing.id}'), isNull);
      }
    }
  });

  test('기존 DB 부모 성별이 미확정이면 저장 전에 검토를 요구한다', () async {
    for (final atomic in [true, false]) {
      final parent = Person(id: 'unknown-parent-$atomic', gender: 'U');
      await service.upsertPerson(parent);
      final child = Person(id: 'unknown-child-$atomic', fatherId: parent.id);
      await expectLater(atomic
          ? service.upsertPersonsAtomically([child])
          : service.upsertPersonsValidated([child]), throwsStateError);
      expect(await service.getPerson(child.id), isNull);
      expect((await service.getPerson(parent.id))!.gender, 'U');
    }
  });

  test('기존 DB의 확인된 부모와 연결할 때 부모 원문을 바꾸지 않는다', () async {
    for (final atomic in [true, false]) {
      final father = Person(id: 'father-ok-$atomic', gender: 'M', rawText: '부친 원문');
      final mother = Person(id: 'mother-ok-$atomic', gender: 'F', rawText: '모친 원문');
      await service.upsertPerson(father);
      await service.upsertPerson(mother);
      final child = Person(id: 'child-ok-$atomic', fatherId: father.id,
          motherId: mother.id, rawText: '자녀 원문');
      if (atomic) {
        await service.upsertPersonsAtomically([child]);
      } else {
        await service.upsertPersonsValidated([child]);
      }
      final saved = (await service.getPerson(child.id))!;
      expect(saved.fatherId, father.id);
      expect(saved.motherId, mother.id);
      expect(saved.rawText, '자녀 원문');
      expect((await service.getPerson(father.id))!.toMap(), father.toMap());
      expect((await service.getPerson(mother.id))!.toMap(), mother.toMap());
    }
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
