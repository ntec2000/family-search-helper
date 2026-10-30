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
  testWidgets('순환 관계가 있는 제외 후보 복원은 연결을 차단하고 경고한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final first = Person(id: 'first', nameHanja: '甲', gender: 'M',
        fatherId: 'second', childrenIds: ['second']);
    final second = Person(id: 'second', nameHanja: '乙', gender: 'M',
        fatherId: 'first', childrenIds: ['first']);
    await tester.pumpWidget(MaterialApp(home: ResultScreen(
        rawText: '甲乙', persons: [first, second], imagePath: 'missing-test-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('인물 아님 · 후보 제외').first);
    await tester.pumpAndSettle();
    expect(find.text('인식 결과 (1명)'), findsOneWidget);
    await tester.tap(find.byTooltip('제외 복원'));
    await tester.pumpAndSettle();
    expect(find.text('인식 결과 (2명)'), findsOneWidget);
    expect(find.textContaining('복원 실패'), findsOneWidget);
    expect(find.textContaining('순환 가족관계'), findsOneWidget);
    expect(first.fatherId, 'second');
    expect(second.fatherId, 'first');
    expect(tester.takeException(), isNull);
  });

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
  testWidgets('인물로 분류하지 못한 구획을 원문 검토 목록으로 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ResultScreen(
      rawText: 'm炳直', persons: [], imagePath: 'missing-test-image',
      unparsedRegions: ['m炳直'],
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('인물 미분류 구획'));
    await tester.pumpAndSettle();
    expect(find.text('인물 미분류 구획 (1건)'), findsOneWidget);
    expect(find.text('m炳直'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('미분류 구획에서 인물 추가 시 원문을 수정 화면에 보존한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ResultScreen(
      rawText: 'm炳直', persons: [], imagePath: 'missing-test-image',
      sourcePageNumber: 224, unparsedRegions: ['m炳直'],
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('인물 미분류 구획'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('인물 추가').last);
    await tester.pumpAndSettle();
    expect(find.text('인물 내용 수정'), findsOneWidget);
    expect(find.text('인식 원문 (보존)'), findsOneWidget);
    expect(find.text('m炳直'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사망 간지 연도를 검토해 추정하고 출생 기록은 바꾸지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = Person(id: 'p', nameHanja: '昃', gender: 'M',
      birthDateLunar: '丁未生', deathDateLunar: '庚申八月三日卒');
    await tester.pumpWidget(MaterialApp(home: ResultScreen(
      rawText: '원문', persons: [original], imagePath: 'missing-test-image')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('인물 작업 메뉴 · 인물 아님 제외').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('만세력 사망 연도 추정'));
    await tester.pumpAndSettle();
    expect(find.text('사망 연도 추정 검토'), findsOneWidget);
    expect(find.textContaining('가능한 간지 연도 (1700~2100):'), findsOneWidget);
    expect(find.textContaining('1920'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '1920');
    await tester.pumpAndSettle();
    expect(find.textContaining('about 1920'), findsOneWidget);
    await tester.tap(find.text('승인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('사망 서기 about 1920'), findsOneWidget);
    expect(original.deathDateSolar, isNull);
    expect(original.birthDateLunar, '丁未生');
    expect(original.deathDateLunar, '庚申八月三日卒');
    expect(tester.takeException(), isNull);
  });

}
