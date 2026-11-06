import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/widgets/app_pinch_zoom.dart';

void main() {
  double scale(WidgetTester tester, {Key key = const ValueKey('app-pinch-viewer')}) {
    final viewer = tester.widget<InteractiveViewer>(find.byKey(key));
    return viewer.transformationController!.value.getMaxScaleOnAxis();
  }

  Future<void> pinch(WidgetTester tester,
      {Offset center = const Offset(200, 300), double distance = 160}) async {
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(center - const Offset(40, 0));
    await second.down(center + const Offset(40, 0));
    await tester.pump();
    await first.moveTo(center - Offset(distance / 2, 0));
    await second.moveTo(center + Offset(distance / 2, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
  }

  Widget app(Widget home) => MaterialApp(
    builder: (_, child) => AppPinchZoom(child: child!),
    home: home,
  );

  testWidgets('whole app pinch is bounded and reset stays outside magnification',
      (tester) async {
    await tester.pumpWidget(app(const Scaffold(
      body: ColoredBox(color: Colors.white, child: SizedBox.expand()),
    )));
    expect(scale(tester), 1);
    await pinch(tester, distance: 800);
    expect(scale(tester), greaterThan(1));
    expect(scale(tester), lessThanOrEqualTo(4.001));
    await tester.tap(find.byKey(const ValueKey('app-pinch-reset')));
    await tester.pumpAndSettle();
    expect(scale(tester), closeTo(1, .001));
    expect(find.byKey(const ValueKey('app-pinch-reset')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single finger scroll still works without changing app scale',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(app(Scaffold(
      body: ListView(controller: controller, children: [
        for (var i = 0; i < 80; i++) SizedBox(height: 70, child: Text('record $i')),
      ]),
    )));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(50));
    expect(scale(tester), closeTo(1, .001));
  });

  testWidgets('zoom persists across routes and dialogs and their controls stay tappable',
      (tester) async {
    await tester.pumpWidget(app(Scaffold(body: Builder(
      builder: (context) => Center(child: FilledButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (context) => Scaffold(body: Center(child: FilledButton(
            onPressed: () => showDialog<void>(context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('dialog'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx),
                    child: const Text('close'))],
              )),
            child: const Text('open dialog'),
          ))),
        )),
        child: const Text('next'),
      )),
    ))));
    await pinch(tester, center: tester.getCenter(find.text('next')), distance: 120);
    final before = scale(tester);
    expect(before, greaterThan(1));
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    expect(scale(tester), closeTo(before, .001));
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOneWidget);
    expect(scale(tester), closeTo(before, .001));
    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an existing image viewer receives pinch before the whole app',
      (tester) async {
    final imageTransform = TransformationController();
    addTearDown(imageTransform.dispose);
    await tester.pumpWidget(app(Scaffold(body: InteractiveViewer(
      key: const ValueKey('image-viewer'),
      transformationController: imageTransform,
      minScale: 1, maxScale: 8,
      child: const ColoredBox(color: Colors.blue, child: SizedBox.expand()),
    ))));
    await pinch(tester);
    expect(scale(tester, key: const ValueKey('image-viewer')), greaterThan(1));
    expect(scale(tester), closeTo(1, .001));
    expect(tester.takeException(), isNull);
  });
}
