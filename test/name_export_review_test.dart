import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/name_export_review.dart';
import 'package:family_search_helper/widgets/name_export_review_dialog.dart';

void main() {
  test('성씨로 시작하는 입력만 원문 확인 대상으로 분류한다', () {
    expect(NameExportReview.needsReview(Person(id: 'a', surnameHangul: '이', nameHangul: '이인')), isTrue);
    expect(NameExportReview.needsReview(Person(id: 'b', surnameHanja: '李', nameHanja: '李仁')), isTrue);
    expect(NameExportReview.needsReview(Person(id: 'c', surnameHangul: '이', nameHangul: '격')), isFalse);
    expect(NameExportReview.needsReview(Person(id: 'd', surnameHangul: '이', nameHangul: '이')), isTrue);
  });

  testWidgets('검토에서 취소하면 진행하지 않고 입력을 바꾸지 않는다', (tester) async {
    final p = Person(id: 'p', surnameHangul: '이', nameHangul: '이인');
    bool? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async { result = await showNameExportReview(context, [p]); },
          child: const Text('내보내기'))))));
    await tester.tap(find.text('내보내기'));
    await tester.pumpAndSettle();
    expect(find.text('성씨와 이름 구분 확인'), findsOneWidget);
    expect(find.textContaining('전체 이름 이이인'), findsOneWidget);
    await tester.tap(find.text('수정하러 가기'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(p.nameHangul, '이인');
    expect(p.surnameHangul, '이');
    await tester.tap(find.text('내보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인 후 계속'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(p.nameHangul, '이인');
  });
}
