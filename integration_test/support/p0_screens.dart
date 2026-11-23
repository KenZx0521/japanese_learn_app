// p0 才露出的畫面：N1 筆記。J4（全分頁可達）與 J9（L21 之後）共用。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/design/widgets/note_body.dart';
import 'package:japanese_learn_app/features/notes/notes_screen.dart';
import 'package:material_ui/material_ui.dart';

import 'e2e_harness.dart';
import 'journeys.dart';
import 'screenshots.dart';

/// N1 的五個分頁（§3.11），標籤與 `NoteKind` 對應。
const noteTabs = <(String, NoteKind)>[
  ('同形異義', NoteKind.falseFriend),
  ('字形對照', NoteKind.shinjitai),
  ('讀音規律', NoteKind.reading),
  ('語言轉移', NoteKind.transfer),
  ('術語', NoteKind.term),
];

/// RULINGS O10：台語讀音旁的說明。
const taiLegend = '台語讀音為台羅拼音，字尾數字是聲調';
const kokujiCaption = '日本自創的漢字，台灣不用；右邊是意思最接近的中文字';

/// 和製漢字在筆記清單的最後幾筆，捲動距離要夠遠。
const _noteScrollStep = 600.0;
const _maxNoteScrolls = 200;

T readOf<T>(WidgetTester tester, ProviderListenable<T> provider) =>
    ProviderScope.containerOf(tester.element(find.byType(App))).read(provider);

Finder richText(String text) => find.textContaining(text, findRichText: true);

NoteKind noteKindOf(NoteDto note) => switch (note) {
  NoteDto_FalseFriend() => NoteKind.falseFriend,
  NoteDto_Shinjitai() => NoteKind.shinjitai,
  NoteDto_Reading() => NoteKind.reading,
  NoteDto_Transfer() => NoteKind.transfer,
  NoteDto_Term() => NoteKind.term,
};

List<NoteDto> _shownNotes(WidgetTester tester) => [
  for (final body in tester.widgetList<NoteBody>(find.byType(NoteBody)))
    body.note,
];

/// N1 裡的筆記清單（垂直捲動）；分頁列是水平的，下層頁面的捲動區也不算。
/// 換分頁是 `replace`，轉場中新頁在後面，取最後一個。
Finder get _noteList => find
    .descendant(
      of: find.byType(NotesScreen),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    )
    .last;

/// 從 L1 的「筆記」入口進 N1，五個分頁逐一確認是真實內容，最後回到 L1。
Future<void> visitNotes(WidgetTester tester, {ShotBook? shots}) async {
  await tester.pumpUntilFound(find.text('筆記'));
  await tester.tapWidget(find.text('筆記'));
  await tester.pumpPage(find.text('漢字陷阱'));
  expectBackLine(tester, 'N1');
  for (final (label, kind) in noteTabs) {
    await tester.tapWidget(find.text(label));
    await tester.pumpUntil(() {
      final notes = _shownNotes(tester);
      return notes.isNotEmpty && notes.every((n) => noteKindOf(n) == kind);
    }, reason: 'N1 $label 載入真實筆記');
    await tester.pumpFor(const Duration(milliseconds: 350));
    expectNoErrorSlip(tester, 'N1 $label');
    expect(find.text('這一版還沒有這類筆記'), findsNothing, reason: label);
    await _expectTabDetails(tester, kind);
    await shots?.take(tester, 'notes_${kind.name}');
    if (kind == NoteKind.shinjitai) await _expectKokuji(tester, shots);
  }
  await back(tester);
}

Future<void> _expectTabDetails(WidgetTester tester, NoteKind kind) async {
  final first = (await readOf(tester, noteRepositoryProvider).list(kind)).first;
  switch (first) {
    case NoteDto_FalseFriend():
      expect(find.text('日文意思'), findsWidgets);
      expect(find.text('容易誤解成'), findsWidgets);
    case NoteDto_Shinjitai(:final zhTw):
      expect(find.text(zhTw), findsWidgets, reason: '字形對照的台灣字形');
    case NoteDto_Reading(:final examples):
      expect(examples, isNotEmpty, reason: '第一則讀音筆記應有台語例字');
      expect(find.text(taiLegend), findsWidgets, reason: 'O10 台羅說明');
      expect(find.text(examples.first.tai), findsWidgets);
    case NoteDto_Transfer(:final zhPattern):
      expect(find.text(zhPattern), findsWidgets);
    case NoteDto_Term(:final grammarIds):
      expect(grammarIds, isNotEmpty);
      expect(find.text('看文法'), findsWidgets);
  }
}

/// 和製漢字沒有對應的台灣字，標籤要寫「意思近」而不是「對照」（note_body.dart）。
/// 和製漢字有好幾筆，同一畫面可能同時出現多個說明，所以不用 `scrollUntilVisible`。
Future<void> _expectKokuji(WidgetTester tester, ShotBook? shots) async {
  final caption = find.text(kokujiCaption);
  for (var i = 0; i < _maxNoteScrolls && caption.evaluate().isEmpty; i++) {
    await tester.drag(_noteList, const Offset(0, -_noteScrollStep));
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(caption, findsWidgets, reason: '字形對照清單捲到底仍沒有和製漢字');
  await tester.ensureVisible(caption.first);
  await tester.pumpFor(const Duration(milliseconds: 200));
  expect(find.text('意思近'), findsWidgets);
  expectNoErrorSlip(tester, 'N1 和製漢字');
  await shots?.take(tester, 'notes_shinjitai_kokuji');
}
