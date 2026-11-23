import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/features/dialogue/dialogues_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/pump_app.dart';
import 'dialogue_fixtures.dart';

Finder _rich(String text) => find.textContaining(text, findRichText: true);

void main() {
  testWidgets('依種類分組', (tester) async {
    final backend = FakeBackend();
    backend.listening.dialoguesStub.returns([
      dialogueSummaryFixture(sceneZh: '第一次見面'),
      dialogueSummaryFixture(
        id: 'di.casual',
        kind: DialogueKindDto.casual,
        sceneZh: '朋友聊天',
      ),
    ]);

    await pumpApp(tester, backend: backend, child: const DialoguesScreen());

    expect(find.text('課文對話'), findsOneWidget);
    expect(find.text('常體對話'), findsOneWidget);
    expect(_rich('第一次見面'), findsOneWidget);
    expect(_rich('朋友聊天'), findsOneWidget);
  });

  testWidgets('未到的對話顯示課次，不寫「開放」', (tester) async {
    final backend = FakeBackend();
    backend.listening.dialoguesStub.returns([
      dialogueSummaryFixture(lessonId: 'le.l05', locked: true),
    ]);

    await pumpApp(tester, backend: backend, child: const DialoguesScreen());

    expect(find.text('第 5 課'), findsOneWidget);
    expect(find.textContaining('開放'), findsNothing);
  });

  // review_f F6：淡色對報讀無效，「第 5 課」聽起來只是課次。
  testWidgets('未到的對話，報讀念出「還沒學到」', (tester) async {
    final handle = tester.ensureSemantics();
    final backend = FakeBackend();
    backend.listening.dialoguesStub.returns([
      dialogueSummaryFixture(lessonId: 'le.l05', locked: true),
    ]);

    await pumpApp(tester, backend: backend, child: const DialoguesScreen());

    expect(find.bySemanticsLabel(RegExp('還沒學到第 5 課')), findsOneWidget);
    handle.dispose();
  });

  // review_f F9：列表有別的未到對話時，已學過的這一段不能被標成還沒學到。
  testWidgets('只比對這一段對話的 locked', (tester) async {
    final backend = FakeBackend();
    backend.listening.dialoguesStub.returns([
      dialogueSummaryFixture(),
      dialogueSummaryFixture(
        id: 'di.other',
        sceneZh: '別的對話',
        lessonId: 'le.l05',
        locked: true,
      ),
    ]);
    backend.listening.dialogueStub.returns(dialogueFixture());

    await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(autoComplete: false),
      location: '/session/dialogue/di.l01',
    );

    expect(find.textContaining('還沒學到'), findsNothing);
  });

  testWidgets('未到的對話也可點，進 S4 標「還沒學到」，與 L2 一致（裁決 U12）', (tester) async {
    final backend = FakeBackend();
    backend.listening.dialoguesStub.returns([
      dialogueSummaryFixture(lessonId: 'le.l05', locked: true),
    ]);
    backend.listening.dialogueStub.returns(dialogueFixture());

    await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(autoComplete: false),
      location: '/listen/dialogues',
    );
    await tester.tap(_rich('第一次見面'));
    await tester.pumpAndSettle();

    expect(backend.listening.dialogueStub.calls.single, ['di.l01']);
    expect(find.text('盲聽'), findsOneWidget);
    expect(find.text('還沒學到第 5 課，可以先聽聽看。'), findsOneWidget);
  });

  testWidgets('直接開 S4（深層連結）也由 dialogues() 的 locked 判斷', (tester) async {
    final backend = FakeBackend();
    backend.listening.dialoguesStub.returns([
      dialogueSummaryFixture(id: 'di.other', sceneZh: '別的對話'),
      dialogueSummaryFixture(lessonId: 'le.l05', locked: true),
    ]);
    backend.listening.dialogueStub.returns(dialogueFixture());

    await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(autoComplete: false),
      location: '/session/dialogue/di.l01',
    );

    expect(find.text('還沒學到第 5 課，可以先聽聽看。'), findsOneWidget);
  });

  testWidgets('讀不到列表時照常播放，不顯示說明', (tester) async {
    final backend = FakeBackend();
    backend.listening.dialoguesStub.throws(const StorageFailure());
    backend.listening.dialogueStub.returns(dialogueFixture());

    await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(autoComplete: false),
      location: '/session/dialogue/di.l01',
    );

    expect(find.text('盲聽'), findsOneWidget);
    expect(find.textContaining('還沒學到'), findsNothing);
    expect(find.text(const StorageFailure().userMessage), findsNothing);
  });

  testWidgets('沒有對話時顯示空狀態', (tester) async {
    await pumpApp(tester, child: const DialoguesScreen());

    expect(find.text('這一版還沒有對話。'), findsOneWidget);
  });

  testWidgets('超過 200ms 才顯示骨架', (tester) async {
    final backend = FakeBackend();
    final gate = Completer<void>();
    backend.listening.dialoguesStub.gate = gate.future;

    await pumpApp(
      tester,
      backend: backend,
      child: const DialoguesScreen(),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SkeletonLines), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('載入失敗可重試', (tester) async {
    final backend = FakeBackend();
    backend.listening.dialoguesStub.throws(const StorageFailure());

    await pumpApp(tester, backend: backend, child: const DialoguesScreen());
    expect(find.text(const StorageFailure().userMessage), findsOneWidget);

    backend.listening.dialoguesStub.returns([dialogueSummaryFixture()]);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(_rich('第一次見面'), findsOneWidget);
  });

  testWidgets('點開對話進入 S4 路由', (tester) async {
    final backend = FakeBackend();
    backend.listening.dialoguesStub.returns([dialogueSummaryFixture()]);
    backend.listening.dialogueStub.returns(dialogueFixture());

    await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(autoComplete: false),
      location: '/listen/dialogues',
    );
    await tester.tap(_rich('第一次見面'));
    await tester.pumpAndSettle();

    expect(backend.listening.dialogueStub.calls.single, ['di.l01']);
    expect(find.text('盲聽'), findsOneWidget);
    expect(find.textContaining('還沒學到'), findsNothing);
  });
}
