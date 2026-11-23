import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/tts/voice_help.dart';
import 'package:japanese_learn_app/features/settings/voice_settings_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'settings_harness.dart';

void main() {
  FakeTtsEngine readyTts({List<String> voices = const []}) => FakeTtsEngine(
    availability: TtsAvailability(
      TtsAvailabilityKind.ready,
      voiceName: 'Kyoko',
      voiceIds: voices,
    ),
  );

  Future<void> pumpVoice(
    WidgetTester tester, {
    FakeBackend? backend,
    FakeTtsEngine? tts,
    bool settle = true,
    double width = 375,
    double textScale = 1,
  }) => pumpApp(
    tester,
    backend: backend ?? settingsBackend(),
    tts: tts ?? readyTts(),
    child: const VoiceSettingsScreen(),
    settle: settle,
    width: width,
    textScale: textScale,
    height: 1400,
  );

  group('語音檢測', () {
    testWidgets('探測完成前顯示正在確認', (tester) async {
      final gate = Future<void>.delayed(const Duration(seconds: 1));
      final tts = FakeTtsEngine(probeGate: gate);
      await pumpVoice(tester, tts: tts, settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('正在確認語音'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('語音可以使用'), findsOneWidget);
    });

    testWidgets('可用時顯示語音名稱', (tester) async {
      await pumpVoice(tester);
      expect(find.text('語音可以使用'), findsOneWidget);
      expect(find.textContaining('Kyoko'), findsOneWidget);
    });

    for (final kind in [
      TtsAvailabilityKind.voiceNotDownloaded,
      TtsAvailabilityKind.noJapaneseVoice,
      TtsAvailabilityKind.engineMissing,
    ]) {
      testWidgets('$kind 時不靜默，帶到說明面板', (tester) async {
        final tts = FakeTtsEngine(availability: TtsAvailability(kind));
        await pumpVoice(tester, tts: tts);
        expect(find.text('語音可以使用'), findsNothing);

        await tapRow(tester, find.text('看設定步驟'));
        expect(find.byType(VoiceHelpSheet), findsOneWidget);
      });
    }

    testWidgets('重新檢查會再探測一次', (tester) async {
      final tts = readyTts();
      await pumpVoice(tester, tts: tts);
      final before = tts.probeCount;
      await tapRow(tester, find.text('重新檢查'));
      expect(tts.probeCount, before + 1);
    });
  });

  group('測試播放', () {
    testWidgets('可用時送出日文測試句', (tester) async {
      final tts = readyTts();
      await pumpVoice(tester, tts: tts);
      await tester.tap(find.bySemanticsLabel('播放'));
      await tester.pumpAndSettle();
      expect(tts.spoken.single.text, 'こんにちは');
    });

    testWidgets('不可用時按播放開說明面板', (tester) async {
      final tts = FakeTtsEngine(
        availability: const TtsAvailability(TtsAvailabilityKind.engineMissing),
      );
      await pumpVoice(tester, tts: tts);
      await tester.tap(find.bySemanticsLabel('語音無法使用，查看說明'));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceHelpSheet), findsOneWidget);
      expect(tts.spoken, isEmpty);
    });

    testWidgets('播放失敗時提示並可查看說明', (tester) async {
      final tts = readyTts()..speakError = Exception('boom');
      await pumpVoice(tester, tts: tts);
      await tester.tap(find.bySemanticsLabel('播放'));
      await tester.pumpAndSettle();
      expect(find.textContaining('沒有播出來'), findsOneWidget);
    });
  });

  group('偏好', () {
    testWidgets('無聲模式寫入 silent_mode 並說明影響', (tester) async {
      final backend = settingsBackend();
      await pumpVoice(tester, backend: backend);
      expect(find.textContaining('聽力題暫時不出現'), findsOneWidget);

      await tapRow(tester, find.text('無聲模式'));
      expect(lastPatch(backend).silentMode, isTrue);
    });

    testWidgets('無聲模式開著時也不算語音不可用的靜默狀態', (tester) async {
      final backend = settingsBackend();
      backend.settings.current = settingsFixture(silentMode: true);
      await pumpVoice(tester, backend: backend);
      expect(find.text('無聲模式開著'), findsOneWidget);
    });

    testWidgets('慢速預設在 0.7 與 1.0 之間切換', (tester) async {
      final backend = settingsBackend();
      await pumpVoice(tester, backend: backend);
      await tapRow(tester, find.text('慢速預設'));
      expect(lastPatch(backend).ttsRate, 0.7);

      await tapRow(tester, find.text('慢速預設'));
      expect(lastPatch(backend).ttsRate, 1.0);
    });

    testWidgets('自動播放可切換', (tester) async {
      final backend = settingsBackend();
      await pumpVoice(tester, backend: backend);
      await tapRow(tester, find.text('自動播放'));
      expect(lastPatch(backend).autoplay, isFalse);
    });

    testWidgets('寫入失敗顯示訊息', (tester) async {
      final backend = settingsBackend();
      backend.settings.patchStub.throws(const StorageFailure());
      await pumpVoice(tester, backend: backend);
      await tapRow(tester, find.text('自動播放'));
      expect(find.textContaining('資料暫時寫不進去'), findsOneWidget);
    });
  });

  group('語音選擇', () {
    testWidgets('只有一個語音時不顯示', (tester) async {
      await pumpVoice(tester, tts: readyTts(voices: ['ja-a']));
      expect(find.text('語音選擇'), findsNothing);
    });

    testWidgets('兩個以上可選擇，也可回到裝置預設', (tester) async {
      final backend = settingsBackend();
      await pumpVoice(
        tester,
        backend: backend,
        tts: readyTts(voices: ['ja-a', 'ja-b']),
      );
      await tapRow(tester, find.text('語音選擇'));
      await selectOption(tester, 'ja-b');
      expect(lastPatch(backend).voiceId, 'ja-b');
      expect(backend.settings.current.voiceId, 'ja-b');

      await tapRow(tester, find.text('語音選擇'));
      await selectOption(tester, '裝置預設');
      expect(lastPatch(backend).clearVoiceId, isTrue);
      expect(backend.settings.current.voiceId, isNull);
    });
  });

  testWidgets('寬 320、字級 1.5 倍不溢位', (tester) async {
    await pumpVoice(
      tester,
      tts: readyTts(voices: ['ja-a', 'ja-b']),
      width: 320,
      textScale: 1.5,
    );
    expect(tester.takeException(), isNull);
  });
}
