import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/screens/capture_screen.dart';
import 'package:family_search_helper/screens/result_screen.dart';

void main() {
  testWidgets('판독문 두 줄을 사진 OCR 없이 검토 목록으로 보낸다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CaptureScreen(
        surnameHanja: '李', surnameHangul: '이')));
    await tester.tap(find.byTooltip('직접 입력'));
    await tester.pumpAndSettle();
    const source = '子格 21世 壬辰生\n子核 21世 丁酉生';
    await tester.enterText(find.byType(TextField), source);
    await tester.pump();
    await tester.tap(find.text('판독문 검토'));
    await tester.pumpAndSettle();
    final result = tester.widget<ResultScreen>(find.byType(ResultScreen));
    expect(result.rawText, source);
    expect(result.persons.map((person) => person.nameHanja), ['格', '核']);
    expect(result.persons.map((person) => person.sega), [21, 21]);
    expect(result.persons.every((person) => person.fatherId == null), isTrue);
  });

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

  testWidgets('성씨 확인을 취소하면 기존 작업 성씨를 보존한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CaptureScreen(
        surnameHanja: '金', surnameHangul: '김')));
    await tester.tap(find.text('성씨: 김'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '최');
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('성씨: 김'), findsOneWidget);
  });
}
