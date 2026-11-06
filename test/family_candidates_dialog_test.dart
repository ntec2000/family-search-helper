import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/screens/result_screen.dart';
import 'package:family_search_helper/services/hanja_dict.dart';

void main() {
  testWidgets('선택한 가족과 생성 표시명을 검토 목록에 추가하고 중복 추가를 막는다',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => HanjaDict.instance.load());
    final original = Person(id:'source',gender:'M',nameHanja:'格',
        surnameHanja:'李',surnameHangul:'이',spouseHanja:'豊壤趙氏',
        spouseFather:'永復',rawText:'원본');
    await tester.pumpWidget(MaterialApp(home: ResultScreen(
        persons:[original],rawText:'원본',imagePath:'missing-test-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('가족 이름 후보 목록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('추가 가능한 후보 모두 선택'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택한 3명 추가'));
    await tester.pumpAndSettle();
    expect(find.textContaining('조영복의 부인'),findsWidgets);
    expect(original.childrenIds,isEmpty);
    expect(original.spouseFather,'永復');
    await tester.tap(find.byTooltip('가족 이름 후보 목록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('추가 가능한 후보 모두 선택'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(
        find.widgetWithText(FilledButton,'선택한 0명 추가')).onPressed,isNull);
    expect(tester.takeException(),isNull);
  });
}
