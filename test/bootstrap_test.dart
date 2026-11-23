import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/boot_error_app.dart';
import 'package:japanese_learn_app/bootstrap.dart';
import 'package:japanese_learn_app/core/backend/boot.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:material_ui/material_ui.dart' show Widget;

import 'support/fake_backend.dart';
import 'support/fake_tts_engine.dart';
import 'support/fixtures.dart';

final class _FakeGateway implements BootGateway {
  _FakeGateway(this._results);

  final List<Object> _results;
  int openCount = 0;
  int resetCount = 0;
  bool resetShouldFail = false;

  @override
  Future<BootResult> open() async {
    final next = _results[openCount.clamp(0, _results.length - 1)];
    openCount++;
    if (next is AppFailure) throw next;
    return next as BootResult;
  }

  @override
  Future<void> resetDatabase() async {
    if (resetShouldFail) throw const StorageFailure();
    resetCount++;
  }
}

BootResult _boot({bool onboarded = true}) {
  final backend = FakeBackend();
  return BootResult(
    repositories: backend.repositories,
    settings: settingsFixture(),
    onboardingDone: onboarded,
    ttsEngine: FakeTtsEngine(),
    firstRunMarker: backend.firstRunMarker,
  );
}

/// startApp 的 run 回呼不能在裡面 await pumpWidget，先存起來再 pump。
final class _Launcher {
  _Launcher(this.tester, this.gateway);

  final WidgetTester tester;
  final _FakeGateway gateway;
  Widget? _latest;

  Future<void> start() async {
    await startApp(gateway, run: (app) => _latest = app);
    await pumpLatest();
  }

  Future<void> pumpLatest() async {
    await tester.pumpWidget(_latest!);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('正常啟動：已完成引導進今日，有導覽列', (tester) async {
    await _Launcher(tester, _FakeGateway([_boot()])).start();

    expect(find.text('今日'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('尚未完成引導時進新手引導', (tester) async {
    await _Launcher(tester, _FakeGateway([_boot(onboarded: false)])).start();

    expect(find.text('從五十音開始。'), findsOneWidget);
  });

  testWidgets('DB 打不開時顯示救援畫面', (tester) async {
    await _Launcher(tester, _FakeGateway([const ContentFailure()])).start();

    expect(find.byType(BootErrorApp), findsOneWidget);
    expect(find.text('沒辦法開啟學習資料'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
    expect(find.text('重設資料'), findsOneWidget);
  });

  testWidgets('重試成功後進 App', (tester) async {
    final gateway = _FakeGateway([const StorageFailure(), _boot()]);
    final launcher = _Launcher(tester, gateway);
    await launcher.start();

    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    await launcher.pumpLatest();

    expect(gateway.openCount, 2);
    expect(find.byType(BootErrorApp), findsNothing);
  });

  testWidgets('重設資料要兩段式確認', (tester) async {
    final gateway = _FakeGateway([const ContentFailure(), _boot()]);
    final launcher = _Launcher(tester, gateway);
    await launcher.start();

    await tester.tap(find.text('重設資料'));
    await tester.pump();
    expect(gateway.resetCount, 0);

    await tester.tap(find.text('刪除並重新開始'));
    await tester.pumpAndSettle();
    await launcher.pumpLatest();

    expect(gateway.resetCount, 1);
    expect(find.byType(BootErrorApp), findsNothing);
  });

  testWidgets('重設失敗時留在救援畫面並提示', (tester) async {
    final gateway = _FakeGateway([const ContentFailure()])
      ..resetShouldFail = true;
    await _Launcher(tester, gateway).start();

    await tester.tap(find.text('重設資料'));
    await tester.pump();
    await tester.tap(find.text('刪除並重新開始'));
    await tester.pumpAndSettle();

    expect(find.byType(BootErrorApp), findsOneWidget);
    expect(find.text(const StorageFailure().userMessage), findsOneWidget);
  });
}
