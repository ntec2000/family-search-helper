import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/screens/capture_screen.dart';

void main() {
  testWidgets('PDF 선택 오류를 안내하고 다시 선택할 수 있다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: CaptureScreen(
      surnameHangul: '이',
      pdfPicker: () async {
        calls++;
        if (calls == 1) throw StateError('picker unavailable');
        return null;
      },
    )));
    await tester.tap(find.text('PDF에서 페이지 선택'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PDF를 불러오지 못했습니다.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('PDF에서 페이지 선택'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('PDF를 불러오지 못했습니다.'), findsNothing);
    expect(find.text('성씨: 이'), findsOneWidget);
  });

  testWidgets('PDF 선택 대기 중 중복 입력을 막고 취소 후 잠금을 해제한다', (tester) async {
    final selected = Completer<FilePickerResult?>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: CaptureScreen(
      pdfPicker: () { calls++; return selected.future; },
    )));
    final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'PDF에서 페이지 선택'));
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    selected.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('PDF 파일 선택 중...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('빈 PDF 데이터는 문서 열기 전에 거부하고 입력을 복구한다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CaptureScreen(
      pdfPicker: () async => FilePickerResult([
        PlatformFile(name: 'empty.pdf', size: 0, bytes: Uint8List(0)),
      ]),
    )));
    await tester.tap(find.text('PDF에서 페이지 선택'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PDF 파일을 읽을 수 없습니다.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
