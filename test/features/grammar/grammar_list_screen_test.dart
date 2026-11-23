import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'grammar_fixtures.dart';

Uri _location(ProviderContainer c) =>
    c.read(appRouterProvider).routerDelegate.currentConfiguration.uri;

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  String? query,
  double width = 375,
  double textScale = 1,
  bool settle = true,
}) => pumpApp(
  tester,
  backend: backend,
  location: AppRoutes.grammar(query: query),
  settings: settingsFixture(),
  width: width,
  textScale: textScale,
  settle: settle,
);

Finder _richText(String text) => find.textContaining(text, findRichText: true);

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.course.overviewStub.returns(overviewFixture());
    backend.grammar.listStub.returns([
      grammarSummaryFixture(lessonId: 'le.l05'),
      grammarSummaryFixture(
        id: 'gr.desu',
        titleZh: '{ja:です}：說「是」',
        status: GrammarStatus.introduced,
      ),
      grammarSummaryFixture(
        id: 'gr.kana',
        titleZh: '假名規則',
        stageId: 'st.s0',
        status: GrammarStatus.practiced,
      ),
    ]);
  });

  testWidgets('依階段順序分組，只列有內容的階段', (tester) async {
    await _pump(tester, backend);

    final kana = tester.getTopLeft(find.text('假名與發音'));
    final polite = tester.getTopLeft(find.text('敬體基礎'));
    expect(kana.dy, lessThan(polite.dy));
    expect(find.text('參考 N4 口語核心'), findsNothing);
    expect(backend.grammar.listStub.calls.single, [null, null]);
  });

  testWidgets('狀態：未學顯示課次、讀過、練過', (tester) async {
    await _pump(tester, backend);

    expect(find.text('第 5 課'), findsOneWidget);
    expect(find.text('讀過'), findsOneWidget);
    expect(find.text('練過'), findsOneWidget);
    expect(_richText('提出主題'), findsOneWidget);
  });

  testWidgets('搜尋停頓後才查詢，並寫進網址', (tester) async {
    final container = await _pump(tester, backend);

    await tester.enterText(find.byType(TextField), 'は');
    await tester.pump(const Duration(milliseconds: 50));
    expect(backend.grammar.listStub.calls, hasLength(1));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(backend.grammar.listStub.calls.last, [null, 'は']);
    expect(_location(container).queryParameters['q'], 'は');
    expect(find.text('は'), findsOneWidget);
  });

  testWidgets('清空搜尋後網址不帶 q', (tester) async {
    final container = await _pump(tester, backend, query: 'は');

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(_location(container).queryParameters.containsKey('q'), isFalse);
    expect(backend.grammar.listStub.calls.last, [null, null]);
  });

  testWidgets('網址帶 q 時預填搜尋框並查詢', (tester) async {
    await _pump(tester, backend, query: 'です');

    expect(backend.grammar.listStub.calls.single, [null, 'です']);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'です');
  });

  testWidgets('搜尋無結果顯示提示', (tester) async {
    backend.grammar.listStub.returns(const []);
    await _pump(tester, backend, query: 'xyz');

    expect(find.text('找不到，試試中文或假名'), findsOneWidget);
  });

  testWidgets('沒有搜尋也沒有內容時顯示空狀態', (tester) async {
    backend.grammar.listStub.returns(const []);
    await _pump(tester, backend);

    expect(find.text('這一版還沒有文法點'), findsOneWidget);
  });

  testWidgets('載入超過 200ms 顯示骨架', (tester) async {
    final gate = Completer<void>();
    backend.grammar.listStub.gate = gate.future;
    await _pump(tester, backend, settle: false);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SkeletonLines), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonLines), findsNothing);
  });

  testWidgets('換搜尋字時保留上一批結果，不閃空白', (tester) async {
    await _pump(tester, backend);
    final gate = Completer<void>();
    backend.grammar.listStub.gate = gate.future;

    await tester.enterText(find.byType(TextField), 'は');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('讀過'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('錯誤顯示 ErrorSlip，重試後恢復', (tester) async {
    backend.grammar.listStub.throws(const StorageFailure());
    await _pump(tester, backend);
    expect(find.byType(ErrorSlip), findsOneWidget);

    backend.grammar.listStub.returns([grammarSummaryFixture()]);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorSlip), findsNothing);
    expect(find.text('第 1 課'), findsOneWidget);
  });

  testWidgets('點文法進 G2；返回後搜尋字還在', (tester) async {
    backend.grammar.detailStub.returns(grammarDetailOf());
    final container = await _pump(tester, backend, query: 'は');

    await tester.tap(find.text('讀過'));
    await tester.pumpAndSettle();
    expect(backend.grammar.detailStub.calls.single, ['gr.desu']);

    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(_location(container).queryParameters['q'], 'は');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'は');
  });

  testWidgets('320 寬、1.5 倍字級不溢位', (tester) async {
    await _pump(tester, backend, width: 320, textScale: 1.5);

    expect(tester.takeException(), isNull);
    expect(find.text('讀過'), findsOneWidget);
  });
}
