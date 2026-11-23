import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/boot_error_app.dart';
import 'app/font_licenses.dart';
import 'core/backend/boot.dart';
import 'core/backend/failures.dart';
import 'core/backend/local_log.dart';
import 'core/backend/providers.dart';
import 'core/settings/settings_controller.dart';
import 'core/tts/tts_controller.dart';

typedef RunApp = void Function(Widget app);

/// 真實入口：main.dart 只呼叫這裡（architecture §5.1）。
Future<void> bootstrap(BootGateway gateway) async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHooks();
  registerFontLicenses();
  await startApp(gateway);
}

/// 開資料庫、決定進哪個畫面；DB 打不開時改跑 `BootErrorApp`（可重試、重設資料）。
Future<void> startApp(BootGateway gateway, {RunApp run = runApp}) async {
  try {
    final boot = await gateway.open();
    run(buildBootedApp(boot));
  } on AppFailure catch (failure, stack) {
    logLocal(failure, stack);
    run(
      BootErrorApp(
        failure: failure,
        onRetry: () => startApp(gateway, run: run),
        onResetData: () async {
          await gateway.resetDatabase();
          await startApp(gateway, run: run);
        },
      ),
    );
  }
}

/// 同一份組裝給 bootstrap 與測試用：只換 repository，不改注入順序。
Widget buildBootedApp(BootResult boot) => ProviderScope(
  // Riverpod 3 預設會自動重試；一律關閉，由使用者按「重試」（實證 #4）
  retry: (_, _) => null,
  overrides: bootOverrides(boot),
  child: const App(),
);

List<Override> bootOverrides(BootResult boot) => [
  ...repositoryOverrides(boot.repositories),
  ttsEngineProvider.overrideWithValue(boot.ttsEngine),
  firstRunMarkerProvider.overrideWithValue(boot.firstRunMarker),
  settingsSeedProvider.overrideWithValue(SettingsSeed(boot.settings)),
  onboardingDoneProvider.overrideWithValue(ValueNotifier(boot.onboardingDone)),
];

void _installErrorHooks() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    logLocal(details.exception, details.stack);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logLocal(error, stack);
    return true;
  };
}
