import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/hanja_dict.dart';
import 'package:family_search_helper/widgets/surname_input_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HanjaDict loads and byReading returns candidates', () async {
    await HanjaDict.instance.load();
    final c = HanjaDict.instance.byReading('최');
    print('byReading(최) -> ${c.length}');
    expect(HanjaDict.instance.size, greaterThan(0));
    expect(c, isNotEmpty);
  });

  testWidgets('surname dialog: typing 최 shows hanja chips LIVE (no 입력 tap)',
      (tester) async {
    await HanjaDict.instance.load();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => showSurnameInputDialog(ctx),
            child: const Text('open'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // 타이핑만으로 (입력 버튼 누르지 않고) 후보가 떠야 한다
    await tester.enterText(find.byType(TextField).first, '최');
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsWidgets,
        reason: '타이핑 즉시 한자 후보가 표시되어야 한다');
  });

  testWidgets('surname dialog: 입력 button also shows chips and 적용 returns value',
      (tester) async {
    await HanjaDict.instance.load();
    (String, String)? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () async { result = await showSurnameInputDialog(ctx); },
            child: const Text('open'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '최');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '입력'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsWidgets);
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '적용'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.$2, '최');
    print('dialog result = $result');
  });
}
