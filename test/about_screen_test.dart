import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/screens/about_screen.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('app history wraps at width $width and text scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 740),
                textScaler: TextScaler.linear(scale)),
            child: const AboutScreen(),
          ),
        ));
        expect(find.text('v3.0.4'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final scrollable = tester.state<ScrollableState>(
            find.byType(Scrollable).first);
        for (var step = 0; step < 120; step++) {
          final position = scrollable.position;
          if (position.pixels >= position.maxScrollExtent) break;
          position.jumpTo(math.min(position.pixels + 600,
              position.maxScrollExtent));
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(scrollable.position.pixels,
            closeTo(scrollable.position.maxScrollExtent, 0.5));
      });
    }
  }
}
