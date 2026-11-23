// 裁決 U9：次層畫面的返回統一成同一個元件 `PageBackLink`（箭頭＋「返回」），
// 有上一頁就回去，深層連結進來時退回上一層。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/design/widgets/back_line.dart';

import '../features/dialogue/dialogue_fixtures.dart';
import '../support/fake_backend.dart';
import '../support/fake_tts_engine.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

/// 畫面、路徑、按「返回」後該到的上一層。
const _screens = <(String, String, String)>[
  ('V1 單字主題', AppRoutes.vocab, AppRoutes.learn),
  ('V2 單字列表', '/learn/vocab/list', AppRoutes.vocab),
  ('V3 單字詳情', '/learn/vocab/word/vo.neko', AppRoutes.vocab),
  ('N1 漢字陷阱', '/learn/notes', AppRoutes.learn),
  ('L2 課程詳情', '/learn/lesson/le.l01', AppRoutes.learn),
  ('G1 文法列表', '/learn/grammar', AppRoutes.learn),
  ('G2 文法點', '/learn/grammar/gr.wa', '/learn/grammar'),
  ('D1 句型演練入口', AppRoutes.drills, AppRoutes.learn),
  ('K1 五十音表', AppRoutes.kana, AppRoutes.learn),
  ('S2 語音示範', AppRoutes.sounds, AppRoutes.listen),
  ('S3 對話列表', AppRoutes.dialogues, AppRoutes.listen),
];

String _path(ProviderContainer container) =>
    container.read(appRouterProvider).state.uri.path;

void main() {
  for (final (name, location, parent) in _screens) {
    testWidgets('$name：箭頭＋「返回」，回到上一層', (tester) async {
      final container = await pumpApp(
        tester,
        location: location,
        settings: settingsFixture(),
      );

      final back = find.byType(PageBackLink);
      expect(back, findsOneWidget);
      final label = find.descendant(of: back, matching: find.text('返回'));
      expect(label, findsOneWidget);

      await tester.tap(label);
      await tester.pumpAndSettle();

      expect(_path(container), parent);
    });
  }

  testWidgets('沒有上一頁（S4 深層連結）時退回 fallback', (tester) async {
    final backend = FakeBackend();
    backend.listening.dialogueStub.returns(dialogueFixture());
    final container = await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(autoComplete: false),
      location: AppRoutes.sessionDialogue('di.l01'),
      settings: settingsFixture(),
    );

    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();

    expect(_path(container), AppRoutes.dialogues);
  });
}
