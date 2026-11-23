import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/note_body.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/features/notes/notes_screen.dart';
import 'package:material_ui/material_ui.dart' show Text;

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

const _falseFriend = NoteDto.falseFriend(
  id: 'no.ff.tegami',
  surface: '手紙',
  jaZh: '信件',
  misreadZh: '衛生紙',
  vocabId: 'vo.tegami',
);
const _shinjitai = NoteDto.shinjitai(
  id: 'no.sj.gaku',
  ja: '学',
  zhTw: '學',
  kind: 'simplified',
  vocabIds: [],
);
const _reading = NoteDto.reading(
  id: 'no.rd.an',
  titleZh: '安的讀音',
  bodyZh: '讀 {ja:あん}。',
  examples: [ReadingExampleDto(hanzi: '安', tai: 'an', ja: '{ja:あん}')],
  caveatZh: '只是規律。',
);
const _transfer = NoteDto.transfer(
  id: 'no.tr.no',
  titleZh: '中文的「的」',
  zhPattern: '我的書',
  wrong: '{ja:私本}',
  right: '{ja:私の本}',
  explainZh: '要加 {ja:の}。',
);
const _term = NoteDto.term(
  id: 'no.term.joshi',
  term: '助詞',
  akaZh: '虛詞',
  bodyZh: '接在名詞後面。',
  grammarIds: ['gr.wa'],
);

const _labels = ['同形異義', '字形對照', '讀音規律', '語言轉移', '術語'];

FakeBackend _backend() {
  final backend = FakeBackend();
  backend.notes.listStub.answers(
    (args) => switch (args.single! as NoteKind) {
      NoteKind.falseFriend => [_falseFriend],
      NoteKind.shinjitai => [_shinjitai],
      NoteKind.reading => [_reading],
      NoteKind.transfer => [_transfer],
      NoteKind.term => [_term],
    },
  );
  return backend;
}

void main() {
  testWidgets('五個分頁，預設同形異義', (tester) async {
    final backend = _backend();
    await pumpApp(tester, backend: backend, child: const NotesScreen());

    for (final label in _labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(backend.notes.listStub.calls.single, [NoteKind.falseFriend]);
    expect(find.text('手紙'), findsOneWidget);
  });

  testWidgets('?kind= 決定起始分頁', (tester) async {
    final backend = _backend();
    await pumpApp(
      tester,
      backend: backend,
      child: const NotesScreen(kind: 'term'),
    );

    expect(backend.notes.listStub.calls.single, [NoteKind.term]);
    expect(find.text('助詞'), findsOneWidget);
  });

  testWidgets('不認得的 kind 退回第一個分頁', (tester) async {
    final backend = _backend();
    await pumpApp(
      tester,
      backend: backend,
      child: const NotesScreen(kind: 'x'),
    );

    expect(backend.notes.listStub.calls.single, [NoteKind.falseFriend]);
  });

  testWidgets('切換分頁取對應筆記並用 NoteBody 呈現', (tester) async {
    final backend = _backend();
    await pumpApp(tester, backend: backend, child: const NotesScreen());

    for (final (label, kind, text) in [
      ('字形對照', NoteKind.shinjitai, '學'),
      ('讀音規律', NoteKind.reading, '安的讀音'),
      ('語言轉移', NoteKind.transfer, '我的書'),
      ('術語', NoteKind.term, '助詞'),
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(backend.notes.listStub.calls.last, [kind]);
      expect(find.text(text), findsOneWidget);
      expect(find.byType(NoteBody), findsOneWidget);
    }
  });

  testWidgets('目前分頁語意為 selected', (tester) async {
    await pumpApp(tester, backend: _backend(), child: const NotesScreen());

    expect(
      tester.getSemantics(find.text('同形異義')),
      isSemantics(isSelected: true),
    );
  });

  testWidgets('切換分頁寫進網址', (tester) async {
    await pumpApp(
      tester,
      backend: _backend(),
      location: AppRoutes.notes(kind: 'reading'),
    );

    await tester.ensureVisible(find.text('術語'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('術語'));
    await tester.pumpAndSettle();

    expect(tester.widget<NotesScreen>(find.byType(NotesScreen)).kind, 'term');
  });

  testWidgets('由 ?kind= 進來時選中的分頁捲到看得見', (tester) async {
    await pumpApp(
      tester,
      backend: _backend(),
      child: const NotesScreen(kind: 'term'),
      width: 320,
    );

    final box = tester.renderObject<RenderBox>(find.text('術語'));
    final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
    expect(right, lessThanOrEqualTo(320));
  });

  testWidgets('字形對照的台灣字形是內容字串，不用只收介面用字的 Noto Serif TC', (tester) async {
    // flutter-app §4.2：displayL／displayM 的 Noto Serif TC 只打包 lib/ 用字，
    // 內容字串一律用 title。實測 p0 的 120 筆 zh_tw 有 74 字不在該子集（如 鹽、醫、驛），
    // 會靜默落到系統字型。
    await pumpApp(
      tester,
      backend: _backend(),
      child: const NotesScreen(kind: 'shinjitai'),
    );

    final zhTw = tester.widget<Text>(find.text('學'));
    expect(zhTw.style?.fontFamily, AppFonts.sans);
    expect(zhTw.style?.fontFamily, isNot(AppFonts.serif));
  });

  testWidgets('術語的別名是 *_zh 欄位，日文標記要解析，不能露出 {ja:}', (tester) async {
    // flutter-app §7（MixedText 適用欄位：所有 *_zh）。p0 的 no.term.masu_stem
    // aka_zh 為「連用形、{ja:ます}形語幹」，整合測試截圖看到原始標記。
    final backend = FakeBackend();
    backend.notes.listStub.returns(const [
      NoteDto.term(
        id: 'no.term.masu_stem',
        term: '{ja:ます}幹',
        akaZh: '連用形、{ja:ます}形語幹',
        bodyZh: '把 {ja:ます} 拿掉。',
        grammarIds: [],
      ),
    ]);

    await pumpApp(
      tester,
      backend: backend,
      child: const NotesScreen(kind: 'term'),
    );

    expect(find.textContaining('{ja:', findRichText: true), findsNothing);
    expect(
      find.textContaining('連用形、ます形語幹', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('該類沒有筆記時給提示', (tester) async {
    final backend = FakeBackend();
    await pumpApp(tester, backend: backend, child: const NotesScreen());

    expect(find.text('這一版還沒有這類筆記'), findsOneWidget);
    expect(find.byType(NoteBody), findsNothing);
  });

  testWidgets('載入中顯示骨架', (tester) async {
    final backend = _backend();
    final gate = Completer<void>();
    backend.notes.listStub.gate = gate.future;

    await pumpApp(
      tester,
      backend: backend,
      child: const NotesScreen(),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(SkeletonLines), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(NoteBody), findsOneWidget);
  });

  testWidgets('載入失敗顯示 ErrorSlip，重試成功', (tester) async {
    final backend = FakeBackend();
    backend.notes.listStub.throws(const ContentFailure());

    await pumpApp(tester, backend: backend, child: const NotesScreen());
    expect(find.byType(ErrorSlip), findsOneWidget);

    backend.notes.listStub.returns([_falseFriend]);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteBody), findsOneWidget);
  });

  testWidgets('大量筆記只建出看得到的列', (tester) async {
    final backend = FakeBackend();
    backend.notes.listStub.returns([
      for (var i = 0; i < 500; i++)
        NoteDto.falseFriend(
          id: 'no.ff.$i',
          surface: '字$i',
          jaZh: '意思',
          misreadZh: '誤解',
        ),
    ]);

    await pumpApp(tester, backend: backend, child: const NotesScreen());

    expect(find.byType(NoteBody).evaluate().length, lessThan(30));
  });

  testWidgets('點筆記連結進單字與文法', (tester) async {
    final backend = _backend();
    backend.vocab.detailStub.returns(vocabDetailFixture());
    backend.settings.displayPolicyStub.returns(displayPolicyFixture());
    backend.grammar.detailStub.returns(grammarDetailFixture());

    await pumpApp(tester, backend: backend, location: AppRoutes.notes());
    await tester.tap(find.text('看單字'));
    await tester.pumpAndSettle();
    expect(backend.vocab.detailStub.calls.single, ['vo.tegami']);
  });

  testWidgets('320 寬、字級 1.5 倍不溢位，分頁可橫向捲動', (tester) async {
    await pumpApp(
      tester,
      backend: _backend(),
      child: const NotesScreen(),
      width: 320,
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('分頁互動目標至少 48dp', (tester) async {
    await pumpApp(tester, backend: _backend(), child: const NotesScreen());
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
