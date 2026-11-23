import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/tts/voice_help.dart';
import 'package:japanese_learn_app/design/widgets/speak_button.dart';
import 'package:japanese_learn_app/design/widgets/speaker_icon.dart';
import 'package:japanese_learn_app/design/widgets/speed_toggle.dart';
import 'package:japanese_learn_app/design/widgets/voice_banner.dart';
import 'package:japanese_learn_app/design/widgets/voice_failed_panel.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:material_ui/material_ui.dart';

import '../support/fake_backend.dart';
import '../support/fake_tts_engine.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

const _request = SpeechRequest(id: 's1', text: '猫', kana: 'ねこ');

Widget _button() => const Center(child: SpeakButton(request: _request));

Finder _semantics(String label) => find.bySemanticsLabel(label);

void main() {
  group('SpeakButton 狀態', () {
    testWidgets('idle：語意「播放」，點擊播放並套用慢速設定', (tester) async {
      final handle = tester.ensureSemantics();
      final tts = FakeTtsEngine();
      final backend = FakeBackend()
        ..settings.current = settingsFixture(ttsRate: 0.7);
      await pumpApp(tester, tts: tts, backend: backend, child: _button());
      expect(_semantics('播放'), findsOneWidget);

      await tester.tap(find.byType(SpeakButton));
      await tester.pump();

      expect(tts.spoken.single.speed, TtsSpeed.slow);
      handle.dispose();
    });

    testWidgets('已存的 1.2 倍設定當正常速度', (tester) async {
      final tts = FakeTtsEngine();
      final backend = FakeBackend()
        ..settings.current = settingsFixture(ttsRate: 1.2);
      await pumpApp(tester, tts: tts, backend: backend, child: _button());

      await tester.tap(find.byType(SpeakButton));
      await tester.pump();
      expect(tts.spoken.single.speed, TtsSpeed.normal);
    });

    testWidgets('speaking：語意「停止播放」，再按停止', (tester) async {
      final handle = tester.ensureSemantics();
      final tts = FakeTtsEngine(autoComplete: false);
      await pumpApp(tester, tts: tts, child: _button());

      await tester.tap(find.byType(SpeakButton));
      await tester.pump();
      expect(_semantics('停止播放'), findsOneWidget);

      await tester.tap(find.byType(SpeakButton));
      await tester.pump();
      expect(_semantics('播放'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('speaking 動畫在 reduced motion 改文字「播放中」', (tester) async {
      final tts = FakeTtsEngine(autoComplete: false);
      await pumpApp(
        tester,
        tts: tts,
        disableAnimations: true,
        child: _button(),
      );

      await tester.tap(find.byType(SpeakButton));
      await tester.pump();

      expect(find.text('播放中'), findsOneWidget);
    });

    testWidgets('preparing：200ms 後才顯示細環', (tester) async {
      final tts = FakeTtsEngine(autoStart: false);
      await pumpApp(tester, tts: tts, child: _button());

      await tester.tap(find.byType(SpeakButton));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('error：語意「播放失敗，查看說明」，點擊開說明', (tester) async {
      final handle = tester.ensureSemantics();
      final tts = FakeTtsEngine()..speakError = Exception('x');
      await pumpApp(tester, tts: tts, child: _button());

      await tester.tap(find.byType(SpeakButton));
      await tester.pump();
      expect(_semantics('播放失敗，查看說明'), findsOneWidget);

      await tester.tap(find.byType(SpeakButton));
      await tester.pumpAndSettle();

      expect(find.byType(VoiceHelpSheet), findsOneWidget);
      handle.dispose();
    });

    testWidgets('unavailable：斜線喇叭，點擊開說明，不靜默', (tester) async {
      final handle = tester.ensureSemantics();
      final tts = FakeTtsEngine(
        availability: const TtsAvailability(
          TtsAvailabilityKind.voiceNotDownloaded,
        ),
      );
      await pumpApp(tester, tts: tts, child: _button());

      expect(_semantics('語音無法使用，查看說明'), findsOneWidget);
      expect(
        tester.widget<SpeakerIcon>(find.byType(SpeakerIcon)).slashed,
        isTrue,
      );

      await tester.tap(find.byType(SpeakButton));
      await tester.pumpAndSettle();

      expect(find.byType(VoiceHelpSheet), findsOneWidget);
      expect(tts.spoken, isEmpty);
      handle.dispose();
    });

    testWidgets('unknown：不可點', (tester) async {
      final gate = Completer<void>();
      final tts = FakeTtsEngine(probeGate: gate.future);
      await pumpApp(tester, tts: tts, settle: false, child: _button());
      await tester.pump();

      await tester.tap(find.byType(SpeakButton), warnIfMissed: false);
      await tester.pump();

      expect(tts.spoken, isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('無聲模式：斜線喇叭，點擊開說明且可開回語音', (tester) async {
      final backend = FakeBackend()
        ..settings.current = settingsFixture(silentMode: true);
      await pumpApp(tester, backend: backend, child: _button());

      await tester.tap(find.byType(SpeakButton));
      await tester.pumpAndSettle();

      expect(find.text('無聲模式開著'), findsOneWidget);
      await tester.tap(find.text('開回語音'));
      await tester.pumpAndSettle();

      expect(backend.settings.current.silentMode, isFalse);
    });
  });

  group('VoiceHelpSheet', () {
    testWidgets('有「現在設定」與「先用無聲模式」兩個出口', (tester) async {
      final tts = FakeTtsEngine(
        availability: const TtsAvailability(
          TtsAvailabilityKind.voiceNotDownloaded,
        ),
      );
      final backend = FakeBackend();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpApp(tester, tts: tts, backend: backend, child: _button());

      await tester.tap(find.byType(SpeakButton));
      await tester.pumpAndSettle();

      expect(find.text('手機還沒下載日語語音'), findsOneWidget);
      expect(find.text('現在設定'), findsOneWidget);
      await tester.tap(find.text('先用無聲模式'));
      await tester.pumpAndSettle();

      expect(backend.settings.current.silentMode, isTrue);
      expect(find.byType(VoiceHelpSheet), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('按「現在設定」後，探測成功自動關閉', (tester) async {
      final tts = FakeTtsEngine(
        availability: const TtsAvailability(
          TtsAvailabilityKind.noJapaneseVoice,
        ),
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await pumpApp(tester, tts: tts, child: _button());
      await tester.tap(find.byType(SpeakButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('現在設定'));
      await tester.pump();
      expect(find.text('重新檢查'), findsOneWidget);

      tts.availability = const TtsAvailability(TtsAvailabilityKind.ready);
      await tester.tap(find.text('重新檢查'));
      await tester.pumpAndSettle();

      expect(find.byType(VoiceHelpSheet), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    test('voiceHelpCopy 對照 §6.4', () {
      final notDownloaded = voiceHelpCopy(
        TtsAvailabilityKind.voiceNotDownloaded,
        VoiceHelpPlatform.android,
      );
      expect(notDownloaded.title, '手機還沒下載日語語音');
      expect(notDownloaded.note, contains('不連網'));

      expect(
        voiceHelpCopy(
          TtsAvailabilityKind.engineMissing,
          VoiceHelpPlatform.android,
        ).steps.last,
        contains('Google 語音服務'),
      );
      expect(
        voiceHelpCopy(
          TtsAvailabilityKind.noJapaneseVoice,
          VoiceHelpPlatform.linux,
        ).title,
        contains('speech-dispatcher'),
      );
    });
  });

  group('SpeedToggle', () {
    testWidgets('循環切換並寫入 tts_rate', (tester) async {
      final backend = FakeBackend();
      await pumpApp(
        tester,
        backend: backend,
        child: const Center(child: SpeedToggle()),
      );
      expect(find.text('1 倍'), findsOneWidget);

      await tester.tap(find.byType(SpeedToggle));
      await tester.pumpAndSettle();

      expect(backend.settings.current.ttsRate, 0.7);
      expect(find.text('0.7 倍'), findsOneWidget);

      await tester.tap(find.byType(SpeedToggle));
      await tester.pumpAndSettle();
      expect(backend.settings.current.ttsRate, 1.0);
    });

    testWidgets('已存的 1.2 倍顯示 1 倍，下一段是 0.7 倍', (tester) async {
      final backend = FakeBackend()
        ..settings.current = settingsFixture(ttsRate: 1.2);
      await pumpApp(
        tester,
        backend: backend,
        child: const Center(child: SpeedToggle()),
      );
      expect(find.text('1 倍'), findsOneWidget);

      await tester.tap(find.byType(SpeedToggle));
      await tester.pumpAndSettle();

      expect(backend.settings.current.ttsRate, 0.7);
      expect(find.text('0.7 倍'), findsOneWidget);
    });
  });

  group('VoiceBanner', () {
    testWidgets('unknown 時不顯示', (tester) async {
      final gate = Completer<void>();
      final tts = FakeTtsEngine(probeGate: gate.future);
      await pumpApp(
        tester,
        tts: tts,
        settle: false,
        child: const VoiceBanner(),
      );
      await tester.pump();

      expect(find.textContaining('語音'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('語音不可用：可關閉', (tester) async {
      final tts = FakeTtsEngine(
        availability: const TtsAvailability(TtsAvailabilityKind.engineMissing),
      );
      await pumpApp(tester, tts: tts, child: const VoiceBanner());

      expect(find.text('語音無法使用，聽力題暫時不出現'), findsOneWidget);
      await tester.tap(find.text('關閉'));
      await tester.pump();

      expect(find.text('語音無法使用，聽力題暫時不出現'), findsNothing);
    });

    testWidgets('無聲模式：常駐，沒有關閉鈕', (tester) async {
      final backend = FakeBackend()
        ..settings.current = settingsFixture(silentMode: true);
      await pumpApp(tester, backend: backend, child: const VoiceBanner());

      expect(find.text('無聲模式：聽力題暫時不出現，語音恢復後會自動回來'), findsOneWidget);
      expect(find.text('關閉'), findsNothing);
      expect(find.text('設定語音'), findsOneWidget);
    });

    testWidgets('ready 時不顯示', (tester) async {
      await pumpApp(tester, child: const VoiceBanner());

      expect(find.textContaining('語音'), findsNothing);
    });
  });

  testWidgets('VoiceFailedPanel：重試與改用無聲模式', (tester) async {
    var retries = 0;
    var silent = 0;
    await pumpApp(
      tester,
      child: VoiceFailedPanel(
        onRetry: () => retries++,
        onSilent: () => silent++,
      ),
    );

    await tester.tap(find.text('重試'));
    await tester.tap(find.text('改用無聲模式'));

    expect(retries, 1);
    expect(silent, 1);
    expect(find.text('略過'), findsNothing);
  });
}
