import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/screens/capture_screen.dart';

void main() {
  testWidgets('이미지 분석 전에 이만 입력해 작업 성씨를 제출할 수 있다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CaptureScreen()));
    await tester.tap(find.text('성씨 입력'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '이');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '이 성씨로 분석'));
    await tester.pumpAndSettle();
    expect(find.text('성씨: 이'), findsOneWidget);
    expect(find.text('족보 성씨 먼저 확인'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('다른 작업 성씨를 제출하면 이전 성씨가 화면에 남지 않는다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CaptureScreen(
        surnameHanja: '金', surnameHangul: '김')));
    await tester.tap(find.text('성씨: 김'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '최');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '이 성씨로 분석'));
    await tester.pumpAndSettle();
    expect(find.text('성씨: 최'), findsOneWidget);
    expect(find.textContaining('적용 성씨: 金'), findsNothing);
  });
}
