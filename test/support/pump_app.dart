import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/router.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/settings/settings_controller.dart';
import 'package:japanese_learn_app/core/tts/fake_tts_engine.dart';
import 'package:japanese_learn_app/core/tts/tts_controller.dart';
import 'package:japanese_learn_app/design/theme.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_backend.dart';

const defaultTestHeight = 800.0;

/// 測試注入點（flutter-app-testing.md §8）：
/// - 傳 `child`：包 `MaterialApp`＋主題，測單一畫面或元件。
/// - 不傳 `child`：走完整路由，`location` 指定起始路徑，`onboarded` 決定 redirect。
/// `settings` 非 null 時當成啟動已載入（`settingsProvider` 同步有值）。
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  FakeBackend? backend,
  FakeTtsEngine? tts,
  Widget? child,
  String location = '/today',
  bool onboarded = true,
  double width = 375,
  double height = defaultTestHeight,
  double textScale = 1,
  bool dark = false,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
  bool highContrast = false,
  SettingsDto? settings,
  List<Override> extraOverrides = const [],
  bool settle = true,
}) async {
  final fake = backend ?? FakeBackend();
  final onboardedNotifier = ValueNotifier(onboarded);
  addTearDown(onboardedNotifier.dispose);
  tester.view
    ..physicalSize = Size(width, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter? router = child == null
      ? buildRouter(onboarded: onboardedNotifier, initialLocation: location)
      : null;
  if (router != null) addTearDown(router.dispose);

  final scoped = ProviderScope(
    retry: (_, _) => null,
    overrides: [
      ...repositoryOverrides(fake.repositories),
      firstRunMarkerProvider.overrideWithValue(fake.firstRunMarker),
      ttsEngineProvider.overrideWithValue(tts ?? FakeTtsEngine()),
      onboardingDoneProvider.overrideWithValue(onboardedNotifier),
      if (settings != null)
        settingsSeedProvider.overrideWithValue(SettingsSeed(settings)),
      if (router != null) appRouterProvider.overrideWith((ref) => router),
      ...extraOverrides,
    ],
    child: _MediaOverride(
      textScale: textScale,
      disableAnimations: disableAnimations,
      accessibleNavigation: accessibleNavigation,
      highContrast: highContrast,
      child: child == null ? const App() : _TestShell(dark: dark, child: child),
    ),
  );
  await tester.pumpWidget(scoped);
  if (settle) await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byWidget(scoped.child)));
}

class _MediaOverride extends StatelessWidget {
  const _MediaOverride({
    required this.textScale,
    required this.disableAnimations,
    required this.accessibleNavigation,
    required this.highContrast,
    required this.child,
  });

  final double textScale;
  final bool disableAnimations, accessibleNavigation, highContrast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    return MediaQuery(
      data: MediaQueryData.fromView(view).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
        accessibleNavigation: accessibleNavigation,
        highContrast: highContrast,
      ),
      child: child,
    );
  }
}

class _TestShell extends StatelessWidget {
  const _TestShell({required this.dark, required this.child});
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(dark ? AppTokens.dark : AppTokens.light),
    locale: const Locale('zh', 'TW'),
    supportedLocales: const [Locale('zh', 'TW'), jaLocale],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(body: child),
  );
}
