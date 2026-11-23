import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/backend/failures.dart';
import '../core/backend/frb/dto.dart';
import '../core/backend/local_log.dart';
import '../core/backend/providers.dart';
import '../core/settings/settings_controller.dart';
import '../core/tts/audio_available.dart';
import '../core/tts/tts_controller.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import 'router.dart';

const _zhTw = Locale('zh', 'TW');

ThemeMode materialThemeMode(AppThemeMode? mode) => switch (mode) {
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
  AppThemeMode.system || null => ThemeMode.system,
};

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(onboarded: ref.watch(onboardingDoneProvider));
  ref.onDispose(router.dispose);
  return router;
});

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => unawaited(_handleResume()),
    onHide: () => unawaited(ref.read(ttsControllerProvider.notifier).stop()),
  );

  /// 先校正時區、await 重新探測，才通知取今日資料，否則跨日的 `today_view`
  /// 可能用舊的 `audio_available` 寫入當日快照（architecture §5.4）。
  Future<void> _handleResume() async {
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    try {
      await ref.read(clockRepositoryProvider).setUtcOffset(offset);
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
    }
    await ref.read(ttsAvailabilityProvider.notifier).reprobe();
    if (mounted) ref.read(resumeTickProvider.notifier).bump();
  }

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(
      settingsProvider.select((s) => s.value?.themeMode),
    );
    // 第一次探測要在 App 啟動時發生，不等第一個畫面呼叫
    ref.watch(ttsAvailabilityProvider);
    return MaterialApp.router(
      title: '日文學習',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(AppTokens.light),
      darkTheme: buildTheme(AppTokens.dark),
      themeMode: materialThemeMode(themeMode),
      locale: _zhTw,
      supportedLocales: const [_zhTw, jaLocale],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
    );
  }
}
