// 真實 Rust＋真實 p0 內容的端到端測試共用工具。執行方式見 integration_test/README.md。
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/bootstrap.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/frb/frb_boot_gateway.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/design/widgets/ink_buttons.dart';
import 'package:material_ui/material_ui.dart';

/// 2026-03-02（週一）台北 09:00，邏輯日就是當天。
final e2eStart = DateTime.utc(2026, 3, 2, 1);
const e2eUtcOffsetMinutes = 480;

/// 預設內容版本（`jp_content` 的 `DEFAULT_STAGE`）；旅程的文案與內容都以它為前提。
const e2eContentStage = ContentStage.p0;

const _pollStep = Duration(milliseconds: 40);
const _defaultTimeout = Duration(seconds: 45);

/// 等不到可點時照舊點下去，行為與加這個等待之前相同。
const _hittableTimeout = Duration(seconds: 1);

/// 一個資料目錄上的 App；同目錄重開就是「關掉再開」。
final class E2eApp {
  E2eApp(this.tester, {required this.dataDir, DateTime? now})
    : nowUtc = now ?? e2eStart;

  final WidgetTester tester;
  final Directory dataDir;
  DateTime nowUtc;

  static Future<Directory> newDataDir() =>
      Directory.systemTemp.createTemp('jla_e2e_');

  Future<void> boot({
    Size size = const Size(375, 812),
    double textScale = 1,
  }) async {
    expect(
      const bool.fromEnvironment('JLA_TEST_HOOKS'),
      isTrue,
      reason:
          '要加 --dart-define=JLA_TEST_HOOKS=true，見 integration_test/README.md',
    );
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpFreshApp();
    await _expectBundledContent();
  }

  /// App 在 Linux 會先載執行檔旁 `lib/` 裡打包的函式庫（`native_library.dart`），
  /// 找不到才交回 FRB 預設，那時可能載到工作目錄下舊的
  /// `rust/target/release/libjp_core.so`。這裡確認載到的內容版本是對的。
  Future<void> _expectBundledContent() async {
    final course = await read(courseRepositoryProvider).overview();
    expect(
      course.contentStage,
      e2eContentStage,
      reason:
          '載入的 Rust 函式庫不是 ${e2eContentStage.name}；'
          '多半是 rust/target/release 的舊建置，見 integration_test/README.md',
    );
  }

  Future<void> _pumpFreshApp() async {
    final gateway = FrbBootGateway(
      testOptions: BootTestOptions(
        dataDir: dataDir.path,
        fixedNowUtc: nowUtc,
        utcOffsetMinutes: e2eUtcOffsetMinutes,
      ),
    );
    Widget? root;
    await tester.runAsync(() => startApp(gateway, run: (app) => root = app));
    await tester.pumpWidget(root!);
    await tester.pump();
  }

  /// 卸載整棵樹再用同一個資料目錄重開；AppCore 也會重開。
  Future<void> restart({Duration advance = Duration.zero}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    nowUtc = nowUtc.add(advance);
    await _pumpFreshApp();
  }

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(App)));

  T read<T>(ProviderListenable<T> provider) => container.read(provider);
}

/// `Text` 的純文字（`data` 或 `textSpan`）。
String textOf(Text text) => switch (text) {
  Text(data: final data?) => data,
  Text(textSpan: final span?) => span.toPlainText(),
  _ => '',
};

extension E2eTester on WidgetTester {
  /// 真實 FFI 回應不會讓 `pumpAndSettle` 等，所以輪詢到條件成立。
  Future<void> pumpUntil(
    bool Function() condition, {
    Duration timeout = _defaultTimeout,
    String? reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail(
          '等待逾時${reason == null ? '' : '：$reason'}\n畫面文字：\n'
          '${visibleTexts().join('\n')}',
        );
      }
      await pump(_pollStep);
    }
  }

  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = _defaultTimeout,
  }) => pumpUntil(
    () => finder.evaluate().isNotEmpty,
    timeout: timeout,
    reason: finder.describeMatch(Plurality.one),
  );

  /// 頁面出現後再等轉場走完；上一頁還在時 `find` 會找到兩頁的同名文字。
  Future<void> pumpPage(Finder finder) async {
    await pumpUntilFound(finder);
    await pumpFor(const Duration(milliseconds: 350));
  }

  /// 動畫走完但不等 FFI。
  Future<void> pumpFor(Duration duration) async {
    final deadline = DateTime.now().add(duration);
    while (DateTime.now().isBefore(deadline)) {
      await pump(_pollStep);
    }
  }

  /// 進場動畫或頁內捲動還在走時，捲到的位置會再變；中心點可能落在底部導覽上，
  /// 點下去就換了分頁（答題後的回饋條實測過）。等目標真的接得到點擊再點。
  Future<void> tapWidget(Finder finder) async {
    await ensureVisible(finder);
    await pump();
    final element = finder.evaluate().single;
    final deadline = DateTime.now().add(_hittableTimeout);
    while (element.mounted &&
        _centerIfHittable(element) == null &&
        DateTime.now().isBefore(deadline)) {
      await pump(_pollStep);
      if (element.mounted) await Scrollable.ensureVisible(element);
    }
    // 目標已經換掉（例如淡出中的舊內容）：原本那一下點了也不會有作用，交給呼叫端重找
    if (!element.mounted) return;
    final box = element.renderObject;
    if (box is! RenderBox) return;
    await tapAt(box.localToGlobal(box.size.center(Offset.zero)));
    await pump();
  }

  Offset? _centerIfHittable(Element element) {
    final target = element.renderObject;
    if (target is! RenderBox || !target.hasSize) return null;
    final center = target.localToGlobal(target.size.center(Offset.zero));
    final hit = hitTestOnBinding(center).path
        .any((entry) => identical(entry.target, target));
    return hit ? center : null;
  }

  Finder enabledButton(String label) => find.byWidgetPredicate(
    (widget) => switch (widget) {
      InkButton(label: final l, onPressed: final cb) =>
        l == label && cb != null,
      GhostButton(label: final l, onPressed: final cb) =>
        l == label && cb != null,
      ShuButton(label: final l, onPressed: final cb) =>
        l == label && cb != null,
      _ => false,
    },
  );

  bool hasEnabledButton(String label) =>
      enabledButton(label).evaluate().isNotEmpty;

  Future<void> tapButton(String label) async {
    await pumpUntilFound(enabledButton(label));
    await tapWidget(enabledButton(label).first);
  }

  /// 目前畫面上所有 `Text` 的內容，逾時訊息用。
  List<String> visibleTexts() => [
    for (final element in find.byType(Text).evaluate())
      textOf(element.widget as Text),
  ].where((text) => text.isNotEmpty).toList();

  bool hasVisibleText(String text) =>
      visibleTexts().any((line) => line.contains(text));
}
