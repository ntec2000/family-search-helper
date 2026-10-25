import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/screens/result_screen.dart';
import 'package:family_search_helper/theme/traditional_theme.dart';

void main() {
  for (final size in [const Size(360, 740), const Size(740, 360)]) {
  testWidgets('$size 확대 글씨에서도 안내와 인물 목록을 스크롤한다', (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: TraditionalTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.7)),
        child: child!),
      home: ResultScreen(rawText: '子甲順',
        persons: List.generate(12, (i) => Person(id: '$i', nameHanja: '甲順', gender: 'M')),
        imagePath: 'missing-test-image')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('검토 안내 펼치기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('검토 안내 펼치기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('2. 관계 검토'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. 관계 검토'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.fling(find.byType(NestedScrollView), const Offset(0, -1200), 1000);
    await tester.pumpAndSettle();
    expect(find.byTooltip('인물 작업 메뉴 · 인물 아님 제외').hitTestable(), findsWidgets);
    expect(find.text('추출 인물').hitTestable(), findsOneWidget);
    expect(find.text('원본 이미지'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  }
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
    await tester.tap(find.byTooltip('제외 복원'));
    await tester.pumpAndSettle();
    expect(find.text('인식 결과 (2명)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
