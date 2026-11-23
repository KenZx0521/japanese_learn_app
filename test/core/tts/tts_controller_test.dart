import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/core/tts/audio_available.dart';
import 'package:japanese_learn_app/core/tts/tts_controller.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';

const _a = SpeechRequest(id: 'a', text: '日本', kana: 'にほん');
const _b = SpeechRequest(id: 'b', text: '学校', kana: 'がっこう');

ProviderContainer _container(FakeTtsEngine engine, {FakeBackend? backend}) {
  final fake = backend ?? FakeBackend();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      ...repositoryOverrides(fake.repositories),
      ttsEngineProvider.overrideWithValue(engine),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('播放狀態機', () {
    testWidgets('Started 後為 Speaking，Completed 後回 Idle', (tester) async {
      final engine = FakeTtsEngine(autoComplete: false, autoStart: false);
      final c = _container(engine);
      final tts = c.read(ttsControllerProvider.notifier);

      unawaited(tts.toggle(_a));
      await tester.pump();
      expect(c.read(ttsControllerProvider), isA<TtsPreparing>());

      engine.emit(const TtsStarted('a'));
      expect(c.read(ttsControllerProvider), isA<TtsSpeaking>());

      engine.emit(const TtsCompleted('a'));
      expect(c.read(ttsControllerProvider), isA<TtsIdle>());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('同 id 再按一次是停止', (tester) async {
      final engine = FakeTtsEngine(autoComplete: false);
      final c = _container(engine);
      final tts = c.read(ttsControllerProvider.notifier);

      await tts.toggle(_a);
      expect(c.read(ttsControllerProvider), isA<TtsSpeaking>());
      await tts.toggle(_a);

      expect(c.read(ttsControllerProvider), isA<TtsIdle>());
    });

    testWidgets('不同 id 切換到新一句，舊事件被丟棄', (tester) async {
      final engine = FakeTtsEngine(autoComplete: false);
      final c = _container(engine);
      final tts = c.read(ttsControllerProvider.notifier);

      await tts.toggle(_a);
      await tts.toggle(_b);
      engine.emit(const TtsCompleted('a'));

      expect(c.read(ttsControllerProvider), isA<TtsSpeaking>());
      expect((c.read(ttsControllerProvider) as TtsSpeaking).id, 'b');
    });

    testWidgets('看門狗：5 秒沒有 Started 轉 TtsError', (tester) async {
      final engine = FakeTtsEngine(autoStart: false);
      final c = _container(engine);

      await c.read(ttsControllerProvider.notifier).toggle(_a);
      await tester.pump(const Duration(seconds: 4, milliseconds: 900));
      expect(c.read(ttsControllerProvider), isA<TtsPreparing>());

      await tester.pump(const Duration(milliseconds: 200));
      final state = c.read(ttsControllerProvider);
      expect(state, isA<TtsError>());
      expect((state as TtsError).reason, 'no-start-event');
    });

    testWidgets('speak 拋例外轉 TtsError', (tester) async {
      final engine = FakeTtsEngine()..speakError = Exception('nope');
      final c = _container(engine);

      await c.read(ttsControllerProvider.notifier).speak(_a);

      expect(c.read(ttsControllerProvider), isA<TtsError>());
    });

    testWidgets('TtsFailed 轉 TtsError', (tester) async {
      final engine = FakeTtsEngine(autoComplete: false);
      final c = _container(engine);

      await c.read(ttsControllerProvider.notifier).speak(_a);
      engine.emit(const TtsFailed('a', 'audio-error'));

      expect(c.read(ttsControllerProvider), isA<TtsError>());
    });

    testWidgets('每次播放前先 stop', (tester) async {
      final engine = FakeTtsEngine();
      final c = _container(engine);

      await c.read(ttsControllerProvider.notifier).speak(_a);

      expect(engine.stopCount, greaterThanOrEqualTo(1));
      expect(engine.spoken.single.id, 'a');
    });
  });

  group('playSequence', () {
    testWidgets('依序播完回傳 true，間隔用 gap', (tester) async {
      final engine = FakeTtsEngine();
      final c = _container(engine);
      final tts = c.read(ttsControllerProvider.notifier);
      bool? result;

      unawaited(
        tts
            .playSequence([_a, _b], fixedGap(const Duration(milliseconds: 400)))
            .then((value) => result = value),
      );
      await tester.pump();
      expect(engine.spoken.map((r) => r.id), ['a']);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(engine.spoken.map((r) => r.id), ['a', 'b']);
      expect(result, isTrue);
    });

    testWidgets('中途 stop 時回傳 false，不播下一句', (tester) async {
      final engine = FakeTtsEngine();
      final c = _container(engine);
      final tts = c.read(ttsControllerProvider.notifier);
      bool? result;

      unawaited(
        tts
            .playSequence([_a, _b], fixedGap(const Duration(seconds: 1)))
            .then((value) => result = value),
      );
      await tester.pump();
      await tts.stop();
      await tester.pump(const Duration(seconds: 2));

      expect(engine.spoken.map((r) => r.id), ['a']);
      expect(result, isFalse);
    });

    testWidgets('被新的播放打斷時停止序列', (tester) async {
      final engine = FakeTtsEngine();
      final c = _container(engine);
      final tts = c.read(ttsControllerProvider.notifier);
      bool? result;

      unawaited(
        tts
            .playSequence([_a, _b], fixedGap(const Duration(seconds: 1)))
            .then((value) => result = value),
      );
      await tester.pump();
      await tts.speak(_b);
      await tester.pump(const Duration(seconds: 2));

      expect(result, isFalse);
      expect(engine.spoken.map((r) => r.id), ['a', 'b']);
    });
  });

  group('語音可用性', () {
    testWidgets('探測完成前為 unknown，完成後轉 ready', (tester) async {
      final gate = Completer<void>();
      final engine = FakeTtsEngine(probeGate: gate.future);
      final c = _container(engine);

      expect(c.read(ttsAvailabilityProvider).kind, TtsAvailabilityKind.unknown);
      await tester.pump();
      expect(c.read(ttsAvailabilityProvider).kind, TtsAvailabilityKind.unknown);

      gate.complete();
      await tester.pump();
      expect(c.read(ttsAvailabilityProvider).kind, TtsAvailabilityKind.ready);
    });

    testWidgets('reprobe 期間保留上一次結果，不回 unknown', (tester) async {
      final engine = FakeTtsEngine();
      final c = _container(engine);
      c.read(ttsAvailabilityProvider);
      await tester.pump();

      final gate = Completer<void>();
      engine
        ..probeGate = gate.future
        ..availability = const TtsAvailability(
          TtsAvailabilityKind.noJapaneseVoice,
        );
      final future = c.read(ttsAvailabilityProvider.notifier).reprobe();
      await tester.pump();
      expect(c.read(ttsAvailabilityProvider).kind, TtsAvailabilityKind.ready);

      gate.complete();
      await future;
      expect(
        c.read(ttsAvailabilityProvider).kind,
        TtsAvailabilityKind.noJapaneseVoice,
      );
    });

    testWidgets('audioResolved 要等探測與設定都完成', (tester) async {
      final gate = Completer<void>();
      final engine = FakeTtsEngine(probeGate: gate.future);
      final backend = FakeBackend();
      final c = _container(engine, backend: backend);

      c.read(ttsAvailabilityProvider);
      c.read(settingsProvider);
      await tester.pump();
      expect(c.read(audioResolvedProvider), isFalse);
      expect(c.read(audioAvailableProvider), isFalse);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(c.read(audioResolvedProvider), isTrue);
      expect(c.read(audioAvailableProvider), isTrue);
    });

    testWidgets('無聲模式時 audioAvailable 為 false', (tester) async {
      final backend = FakeBackend()
        ..settings.current = settingsFixture(silentMode: true);
      final c = _container(FakeTtsEngine(), backend: backend);

      c.read(ttsAvailabilityProvider);
      c.read(settingsProvider);
      await tester.pump();
      await tester.pump();

      expect(c.read(audioResolvedProvider), isTrue);
      expect(c.read(audioAvailableProvider), isFalse);
    });

    testWidgets('引擎探測拋例外視為 engineMissing', (tester) async {
      final engine = _ThrowingProbe();
      final c = _container(engine);

      c.read(ttsAvailabilityProvider);
      await tester.pump();
      await tester.pump();

      expect(
        c.read(ttsAvailabilityProvider).kind,
        TtsAvailabilityKind.engineMissing,
      );
    });
  });

  group('speedFromRate', () {
    test('rate <= 0.85 為慢速', () {
      expect(speedFromRate(0.7), TtsSpeed.slow);
      expect(speedFromRate(0.85), TtsSpeed.slow);
    });

    test('已存的 1.2 倍當正常速度', () {
      expect(speedFromRate(1.2), TtsSpeed.normal);
    });

    test('其餘為正常', () {
      expect(speedFromRate(1.0), TtsSpeed.normal);
      expect(speedFromRate(1.14), TtsSpeed.normal);
    });
  });

  test('SpeechRequest.fromDto 直接取 text 與 kana', () {
    final request = SpeechRequest.fromDto(
      'se.1',
      const SpeechDto(text: '今日', kana: 'きょう'),
    );

    expect(request.text, '今日');
    expect(request.kana, 'きょう');
  });
}

final class _ThrowingProbe extends FakeTtsEngine {
  @override
  Future<TtsAvailability> probe() async => throw Exception('dead');
}
