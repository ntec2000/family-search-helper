import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/widgets/candidate_editor.dart';

void main() {
  testWidgets('내용을 적용하기 전 검증하고 원문·확정 관계·원본 후보는 보존한다', (tester) async {
    tester.view.physicalSize = const Size(1100, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = Person(id: 'person', nameHanja: '核', fatherId: 'father',
        childrenIds: ['child'], rawText: '子核', sourceDocumentPath: 'source.pdf',
        sourcePageNumber: 2, gender: 'M');
    Person? edited;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async => edited = await showDialog<Person>(
          context: context, builder: (_) => CandidateEditor(person: original)),
          child: const Text('수정'))))));
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == label);
    await tester.enterText(field('세대(世)'), '잘못된 값');
    await tester.tap(find.text('내용 적용'));
    await tester.pumpAndSettle();
    expect(find.text('세대는 양의 정수로 입력하세요.'), findsOneWidget);
    expect(edited, isNull);
    await tester.enterText(field('세대(世)'), '21');
    await tester.ensureVisible(field('배우자 부친'));
    await tester.enterText(field('배우자 부친'), '光岳');
    await tester.tap(find.text('내용 적용'));
    await tester.pumpAndSettle();
    expect(edited!.spouseFather, '光岳');
    expect(edited!.sega, 21);
    expect(edited!.fatherId, 'father');
    expect(edited!.childrenIds, ['child']);
    expect(edited!.rawText, '子核');
    expect(edited!.sourceDocumentPath, 'source.pdf');
    expect(edited!.sourcePageNumber, 2);
    expect(original.spouseFather, isNull);
    expect(original.sega, isNull);
  });
}
