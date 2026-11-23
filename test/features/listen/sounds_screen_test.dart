import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/design/widgets/sound_pair_view.dart';
import 'package:japanese_learn_app/design/widgets/speak_button.dart';
import 'package:japanese_learn_app/features/listen/sounds_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/pump_app.dart';

Finder _rich(String text) => find.textContaining(text, findRichText: true);

SoundSideDto _side(String text) => SoundSideDto(
  text: text,
  zh: '$text的意思',
  speech: SpeechDto(text: text, kana: text),
);

SoundGroupDto _group({
  String id = 'ka.sg.voicing',
  SoundGroupKindDto kind = SoundGroupKindDto.voicing,
  String title = '清音與濁音',
  bool listenDisabled = false,
  List<String> testDrillIds = const [],
}) => SoundGroupDto(
  id: id,
  lessonId: 'le.k11',
  kind: kind,
  titleZh: title,
  bodyZh: '聲帶有沒有振動',
  pairs: [
    SoundPairDto(a: _side('か'), b: _side('が'), listenDisabled: listenDisabled),
  ],
  testDrillIds: testDrillIds,
);

void main() {
  testWidgets('依種類分區顯示，固定順序', (tester) async {
    final backend = FakeBackend();
    backend.listening.soundGroupsStub.returns([
      _group(id: 'b', kind: SoundGroupKindDto.length, title: '長短'),
      _group(id: 'a', title: '清濁組'),
    ]);

    await pumpApp(tester, backend: backend, child: const SoundsScreen());

    expect(find.text('清濁'), findsOneWidget);
    expect(find.text('長短音'), findsOneWidget);
    expect(find.byType(SoundPairView), findsNWidgets(2));
    final voicing = tester.getTopLeft(find.text('清濁')).dy;
    final length = tester.getTopLeft(find.text('長短音')).dy;
    expect(voicing, lessThan(length));
  });

  testWidgets('頁首標示語音由裝置合成', (tester) async {
    await pumpApp(tester, child: const SoundsScreen());

    expect(find.text('語音由裝置合成，音調可能不完全正確'), findsOneWidget);
  });

  testWidgets('音調組固定標註僅供參考，其他組沒有', (tester) async {
    final backend = FakeBackend();
    backend.listening.soundGroupsStub.returns([
      _group(id: 'a', kind: SoundGroupKindDto.accent, title: '音調組'),
      _group(id: 'b'),
    ]);

    await pumpApp(tester, backend: backend, child: const SoundsScreen());

    expect(find.text('由裝置合成，僅供參考'), findsOneWidget);
  });

  testWidgets('listen_disabled 的配對只顯示文字', (tester) async {
    final backend = FakeBackend();
    backend.listening.soundGroupsStub.returns([_group(listenDisabled: true)]);

    await pumpApp(tester, backend: backend, child: const SoundsScreen());

    expect(find.text('か'), findsOneWidget);
    expect(find.byType(SpeakButton), findsNothing);
  });

  testWidgets('有 test_drill_ids 才顯示測試一下', (tester) async {
    final backend = FakeBackend();
    backend.listening.soundGroupsStub.returns([
      _group(id: 'a', testDrillIds: const ['dr.k11.001']),
    ]);

    await pumpApp(tester, backend: backend, child: const SoundsScreen());

    expect(find.text('測試一下'), findsOneWidget);
  });

  testWidgets('沒有 test_drill_ids 時不顯示測試一下', (tester) async {
    final backend = FakeBackend();
    backend.listening.soundGroupsStub.returns([_group()]);

    await pumpApp(tester, backend: backend, child: const SoundsScreen());

    expect(find.text('測試一下'), findsNothing);
  });

  testWidgets('語音不可用時播放鈕開說明，不靜默', (tester) async {
    final backend = FakeBackend();
    backend.listening.soundGroupsStub.returns([_group()]);

    await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(
        availability: const TtsAvailability(
          TtsAvailabilityKind.noJapaneseVoice,
        ),
      ),
      child: const SoundsScreen(),
    );

    await tester.tap(find.byType(SpeakButton).first);
    await tester.pumpAndSettle();

    expect(find.text('先用無聲模式'), findsOneWidget);
  });

  testWidgets('沒有資料時顯示空狀態', (tester) async {
    await pumpApp(tester, child: const SoundsScreen());

    expect(find.text('這一版還沒有語音示範。'), findsOneWidget);
  });

  testWidgets('載入中顯示骨架', (tester) async {
    final backend = FakeBackend();
    final gate = Completer<void>();
    backend.listening.soundGroupsStub.gate = gate.future;

    await pumpApp(
      tester,
      backend: backend,
      child: const SoundsScreen(),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SkeletonLines), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('載入失敗可重試', (tester) async {
    final backend = FakeBackend();
    backend.listening.soundGroupsStub.throws(const StorageFailure());

    await pumpApp(tester, backend: backend, child: const SoundsScreen());
    expect(find.text(const StorageFailure().userMessage), findsOneWidget);

    backend.listening.soundGroupsStub.returns([_group()]);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(_rich('清音與濁音'), findsOneWidget);
  });

  testWidgets('字級放大 1.5 倍不破版', (tester) async {
    final backend = FakeBackend();
    backend.listening.soundGroupsStub.returns([
      _group(kind: SoundGroupKindDto.accent),
    ]);

    await pumpApp(
      tester,
      backend: backend,
      width: 320,
      textScale: 1.5,
      child: const SoundsScreen(),
    );

    expect(tester.takeException(), isNull);
  });
}
