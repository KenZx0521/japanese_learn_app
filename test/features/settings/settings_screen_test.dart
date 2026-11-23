import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/features/settings/settings_screen.dart';

import '../../support/fake_tts_engine.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'settings_harness.dart';

void main() {
  group('狀態', () {
    testWidgets('設定讀取失敗顯示 ErrorSlip，重試成功', (tester) async {
      final backend = settingsBackend();
      backend.settings.loadStub.throws(const StorageFailure());
      await pumpApp(tester, backend: backend, child: const SettingsScreen());
      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.settings.loadStub.returns(settingsFixture());
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorSlip), findsNothing);
      expect(find.text('羅馬字'), findsOneWidget);
    });

    testWidgets('寫入失敗保留舊值並顯示訊息', (tester) async {
      final backend = settingsBackend();
      backend.settings.patchStub.throws(const StorageFailure());
      await pumpApp(tester, backend: backend, child: const SettingsScreen());

      await tapRow(tester, find.text('評分鈕顯示間隔'));

      expect(find.textContaining('資料暫時寫不進去'), findsOneWidget);
      expect(backend.settings.current.showRatingIntervals, isFalse);
    });

    testWidgets('課程資訊讀取失敗時，其他設定仍可使用', (tester) async {
      final backend = settingsBackend();
      backend.course.overviewStub.throws(const ContentFailure());
      await pumpApp(tester, backend: backend, child: const SettingsScreen());
      expect(find.text('羅馬字'), findsOneWidget);
      expect(find.byType(ErrorSlip), findsNothing);
    });
  });

  group('顯示', () {
    testWidgets('羅馬字可覆寫，也可回到依課程', (tester) async {
      final backend = settingsBackend();
      await pumpApp(tester, backend: backend, child: const SettingsScreen());
      expect(find.text('依課程'), findsWidgets);

      await tapRow(tester, find.text('羅馬字'));
      await selectOption(tester, '不顯示');
      expect(lastPatch(backend).romajiOverride, RomajiMode.hidden);
      expect(backend.settings.current.romajiOverride, RomajiMode.hidden);

      await tapRow(tester, find.text('羅馬字'));
      await selectOption(tester, '依課程');
      expect(lastPatch(backend).clearRomajiOverride, isTrue);
      expect(backend.settings.current.romajiOverride, isNull);
    });

    testWidgets('羅馬字提供五種顯示與依課程', (tester) async {
      await pumpApp(
        tester,
        backend: settingsBackend(),
        child: const SettingsScreen(),
      );
      await tapRow(tester, find.text('羅馬字'));
      for (final label in ['永遠顯示', '預設顯示，可收起', '點一下才顯示', '長按單字才顯示', '不顯示']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('振假名可覆寫，也可清除', (tester) async {
      final backend = settingsBackend();
      await pumpApp(tester, backend: backend, child: const SettingsScreen());

      await tapRow(tester, find.text('振假名'));
      await selectOption(tester, '只標還不熟的字');
      expect(lastPatch(backend).furiganaOverride, FuriganaMode.unknownOnly);

      await tapRow(tester, find.text('振假名'));
      await selectOption(tester, '依課程');
      expect(lastPatch(backend).clearFuriganaOverride, isTrue);
    });

    testWidgets('主題寫入 theme_mode', (tester) async {
      final backend = settingsBackend();
      await pumpApp(tester, backend: backend, child: const SettingsScreen());
      await tapRow(tester, find.text('主題'));
      await selectOption(tester, '深色（墨夜）');
      expect(lastPatch(backend).themeMode, AppThemeMode.dark);
    });

    testWidgets('評分鈕顯示間隔可切換', (tester) async {
      final backend = settingsBackend();
      final container = await pumpApp(
        tester,
        backend: backend,
        child: const SettingsScreen(),
      );
      await tapRow(tester, find.text('評分鈕顯示間隔'));
      expect(lastPatch(backend).showRatingIntervals, isTrue);
      expect(
        container.read(settingsProvider).value?.showRatingIntervals,
        isTrue,
      );
    });

    testWidgets('字級預覽顯示日文範例與倍率', (tester) async {
      await pumpApp(
        tester,
        backend: settingsBackend(),
        child: const SettingsScreen(),
        textScale: 1.25,
      );
      await tester.scrollUntilVisible(find.text('字級預覽'), 160);
      expect(find.textContaining('1.25 倍'), findsOneWidget);
      expect(find.text('こんにちは'), findsOneWidget);
    });

    testWidgets('p0a 不顯示到不了的 L09 開關', (tester) async {
      await pumpApp(
        tester,
        backend: settingsBackend(),
        child: const SettingsScreen(),
      );
      expect(find.textContaining('L09'), findsNothing);
    });

    testWidgets('p0 可確認 L09 起收起羅馬字', (tester) async {
      final backend = settingsBackend(stage: ContentStage.p0);
      await pumpApp(tester, backend: backend, child: const SettingsScreen());
      await tapRow(tester, find.text('L09 起收起羅馬字'));
      expect(lastPatch(backend).romajiOffConfirmed, isTrue);
    });
  });

  group('學習與無障礙', () {
    testWidgets('換日時間只提供 0 到 12 點', (tester) async {
      final backend = settingsBackend();
      await pumpApp(tester, backend: backend, child: const SettingsScreen());
      expect(find.text('凌晨 4 點'), findsOneWidget);

      await tapRow(tester, find.text('換日時間'));
      expect(find.text('午夜 12 點'), findsOneWidget);
      expect(find.text('中午 12 點'), findsOneWidget);
      await selectOption(tester, '凌晨 2 點');
      expect(lastPatch(backend).dayRolloverHour, 2);
    });

    testWidgets('假名時限可關閉', (tester) async {
      final backend = settingsBackend();
      await pumpApp(tester, backend: backend, child: const SettingsScreen());
      await tapRow(tester, find.text('假名時限'));
      expect(lastPatch(backend).kanaTimeLimit, isFalse);
    });
  });

  group('關於（O7）', () {
    testWidgets('p0a 只宣稱假名與入門七課', (tester) async {
      await pumpApp(
        tester,
        backend: settingsBackend(),
        child: const SettingsScreen(),
        height: 2600,
      );
      expect(find.text('這一版涵蓋假名與入門七課。'), findsOneWidget);
      expect(find.textContaining('N4'), findsNothing);
      expect(find.textContaining('日劇'), findsNothing);
      expect(find.textContaining('專區'), findsNothing);
    });

    testWidgets('p0 的程度說明寫本版到 L30，不提 N4、L31 以後', (tester) async {
      await pumpApp(
        tester,
        backend: settingsBackend(stage: ContentStage.p0),
        child: const SettingsScreen(),
        height: 2600,
      );
      expect(find.text('本版到 L30，涵蓋參考 N5 範圍。'), findsOneWidget);
      for (final banned in ['入門七課', 'N4', 'L48', 'L31', '完整版']) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
    });

    testWidgets('進入授權與程度說明', (tester) async {
      await pumpApp(
        tester,
        backend: settingsBackend(),
        location: '/settings',
        tts: FakeTtsEngine(),
      );
      await tapRow(tester, find.text('授權'));
      expect(find.text('Klee One'), findsOneWidget);
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      await tapRow(tester, find.text('程度說明'));
      expect(find.text('關於程度'), findsOneWidget);
    });
  });

  testWidgets('寬 320、字級 1.5 倍不溢位', (tester) async {
    await pumpApp(
      tester,
      backend: settingsBackend(),
      child: const SettingsScreen(),
      width: 320,
      textScale: 1.5,
      height: 2800,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('深色模式可渲染', (tester) async {
    await pumpApp(
      tester,
      backend: settingsBackend(),
      child: const SettingsScreen(),
      dark: true,
    );
    expect(tester.takeException(), isNull);
  });
}
