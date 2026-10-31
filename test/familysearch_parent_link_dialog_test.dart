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

  testWidgets('인물 ID를 바꾸면 해당 인물과 기존 관계 확인을 다시 요구한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: FamilySearchParentLinkDialog(),
    )));
    final childField = find.widgetWithText(TextField, '자녀 FamilySearch ID');
    final parentField = find.widgetWithText(TextField, '부모 FamilySearch ID');
    await tester.enterText(childField, 'ABCD-123');
    await tester.enterText(parentField, 'WXYZ-456');
    await tester.tap(find.text('자녀 ID의 인물을 확인했습니다'));
    await tester.tap(find.text('부모 ID의 인물을 확인했습니다'));
    await tester.tap(find.text('기존 부모·자녀 관계를 확인했습니다'));
    await tester.pump();
    await tester.enterText(childField, 'ABCD-789');
    await tester.pump();
    bool checked(String label) => tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, label)).value!;
    expect(checked('자녀 ID의 인물을 확인했습니다'), isFalse);
    expect(checked('부모 ID의 인물을 확인했습니다'), isTrue);
    expect(checked('기존 부모·자녀 관계를 확인했습니다'), isFalse);
  });

  testWidgets('저장된 인물을 선택해 ID를 채우되 관계는 확정하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: FamilySearchParentLinkDialog(linkedPeople: [(name: '아버지', id: 'ABCD-123')]),
    )));
    await tester.tap(find.text('저장된 부모 ID 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('아버지 · ABCD-123'));
    await tester.pumpAndSettle();
    expect(find.text('ABCD-123'), findsOneWidget);
    final tile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, '부모 ID의 인물을 확인했습니다'));
    expect(tile.value, isFalse);
  });
}
