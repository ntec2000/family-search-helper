import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/widgets/familysearch_fact_review_dialog.dart';

void main() {
  testWidgets('기존 항목을 고르고 변경 전후를 검토한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const birth = 'http://gedcomx.org/Birth';
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      FamilySearchFactReviewDialog(remote: {'id': 'ABCD-123', 'facts': [
        {'id': 'old-1', 'type': birth, 'date': {'original': '1800'},
          'attribution': {'changeMessage': '기존 출처 대조'}},
      ]}, incoming: {'facts': [
        {'type': birth, 'date': {'original': 'about 1801'}},
      ]}),
    )));
    await tester.tap(find.text('기존 항목 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('old-1 · 1800').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '변경 근거'), '족보 224쪽');
    await tester.tap(find.text('변경안 보기'));
    await tester.pumpAndSettle();
    expect(find.text('변경 전후 검토'), findsOneWidget);
    expect(find.textContaining('날짜: 1800'), findsOneWidget);
    expect(find.textContaining('기존 변경 근거: 기존 출처 대조'), findsOneWidget);
    expect(find.textContaining('항목의 출처 참조: 응답에 없음'), findsOneWidget);
    expect(find.textContaining('날짜: about 1801'), findsOneWidget);
    expect(find.textContaining('FamilySearch 기록은 변경하지 않았습니다.'), findsOneWidget);
  });
}
