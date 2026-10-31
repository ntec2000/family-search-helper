import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/widgets/familysearch_parent_link_dialog.dart';

void main() {
  testWidgets('ID가 없으면 연결 검토를 진행하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: FamilySearchParentLinkDialog(),
    )));
    await tester.tap(find.text('검토 내용 보기'));
    await tester.pumpAndSettle();
    expect(find.text('서로 다른 자녀와 부모의 FamilySearch ID를 확인하세요.'), findsOneWidget);
    expect(find.text('부모 연결 검토 내용'), findsNothing);
  });
}
