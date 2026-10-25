import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/screens/result_screen.dart';

void main() {
  testWidgets('노출된 인물 아님 버튼으로 제외·복원하고 원래 후보는 보존한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final father = Person(id: 'p', nameHanja: '昃', gender: 'M', childrenIds: ['c']);
    final child = Person(id: 'c', nameHanja: '格', gender: 'M', fatherId: 'p');
    await tester.pumpWidget(MaterialApp(home: ResultScreen(
        rawText: '子昃 子格', persons: [father, child], imagePath: 'missing-test-image')));
    await tester.pumpAndSettle();
    expect(find.text('인식 결과 (2명)'), findsOneWidget);
    await tester.tap(find.byTooltip('인물 아님 · 후보 제외').first);
    await tester.pumpAndSettle();
    expect(find.text('인식 결과 (1명)'), findsOneWidget);
    expect(father.childrenIds, ['c']);
    expect(child.fatherId, 'p');
    await tester.tap(find.byTooltip('마지막 제외 후보 복원'));
    await tester.pumpAndSettle();
    expect(find.text('인식 결과 (2명)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
