import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/today_view_provider.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/core/tts/audio_available.dart';
import 'package:japanese_learn_app/core/tts/tts_controller.dart';
import 'package:material_ui/material_ui.dart' show SizedBox;

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

/// Riverpod 的重建經過排程器，要多跑幾輪事件迴圈。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('探測完成前 fake backend 收不到 today_view', (tester) async {
    final gate = Completer<void>();
    final tts = FakeTtsEngine(probeGate: gate.future);
    final backend = FakeBackend();
    final c = await pumpApp(
      tester,
      backend: backend,
      tts: tts,
      settle: false,
      child: const SizedBox(),
    );

    final sub = c.listen(todayViewProvider, (_, _) {});
    addTearDown(sub.close);
    await _settle(tester);
    expect(c.read(todayViewProvider).isLoading, isTrue);
    expect(backend.today.todayStub.calls, isEmpty);

    gate.complete();
    await _settle(tester);

    expect(backend.today.todayStub.calls.single, [true]);
  });

  testWidgets('探測結果非 ready 時，完成後才收到且 audio = false', (tester) async {
    final gate = Completer<void>();
    final tts = FakeTtsEngine(
      probeGate: gate.future,
      availability: const TtsAvailability(TtsAvailabilityKind.noJapaneseVoice),
    );
    final backend = FakeBackend();
    final c = await pumpApp(
      tester,
      backend: backend,
      tts: tts,
      settle: false,
      child: const SizedBox(),
    );

    final sub = c.listen(todayViewProvider, (_, _) {});
    addTearDown(sub.close);
    await _settle(tester);
    expect(backend.today.todayStub.calls, isEmpty);

    gate.complete();
    await _settle(tester);

    expect(backend.today.todayStub.calls.single, [false]);
  });

  testWidgets('無聲模式傳 audio = false', (tester) async {
    final backend = FakeBackend()
      ..settings.current = settingsFixture(silentMode: true);
    final c = await pumpApp(
      tester,
      backend: backend,
      tts: FakeTtsEngine(),
      settle: false,
      child: const SizedBox(),
    );

    final sub = c.listen(todayViewProvider, (_, _) {});
    addTearDown(sub.close);
    await _settle(tester);

    expect(backend.today.todayStub.calls.single, [false]);
    expect(c.read(settingsProvider).hasValue, isTrue);
  });

  group('onResume', () {
    Future<void> resume(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    }

    testWidgets('先校時、await 重新探測，之後才重新取 today', (tester) async {
      final tts = FakeTtsEngine();
      final backend = FakeBackend();
      final container = await pumpApp(tester, backend: backend, tts: tts);
      final sub = container.listen(todayViewProvider, (_, _) {});
      addTearDown(sub.close);
      await _settle(tester);
      final before = backend.today.todayStub.calls.length;
      expect(before, greaterThanOrEqualTo(1));

      final gate = Completer<void>();
      tts.probeGate = gate.future;
      await resume(tester);

      expect(backend.clock.setUtcOffsetStub.calls, hasLength(1));
      expect(backend.today.todayStub.calls.length, before);

      gate.complete();
      await _settle(tester);

      expect(backend.today.todayStub.calls.length, before + 1);
      expect(container.read(resumeTickProvider), 1);
      expect(container.read(audioResolvedProvider), isTrue);
    });

    testWidgets('onHide 停止播放', (tester) async {
      final tts = FakeTtsEngine(autoComplete: false);
      final container = await pumpApp(tester, tts: tts);
      await container
          .read(ttsControllerProvider.notifier)
          .speak(const SpeechRequest(id: 'x', text: 'a', kana: 'a'));
      final stops = tts.stopCount;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      expect(tts.stopCount, greaterThan(stops));
      expect(container.read(ttsControllerProvider), isA<TtsIdle>());
    });
  });
}
