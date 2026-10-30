import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/widgets/couple_export_dialog.dart';

void main() {
  testWidgets('두 인물을 직접 선택한 관계만 반환한다', (tester) async {
    List<(String, String)>? result;
    final people = [Person(id: 'a', nameHangul: '홍길동'), Person(id: 'b', nameHangul: '김영희')];
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        result = await showDialog<List<(String, String)>>(context: context,
          builder: (_) => CoupleExportDialog(people: people));
      }, child: const Text('열기'))))));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('홍길동 (a)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('김영희 (b)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택한 관계 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('선택한 관계로 내보내기'));
    await tester.pumpAndSettle();
    expect(result, [('a', 'b')]);
    expect(tester.takeException(), isNull);
  });
}
