import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../design/motion.dart';
import '../features/grammar/grammar_detail_screen.dart';
import '../features/grammar/grammar_list_screen.dart';
import '../features/kana/kana_chart_screen.dart';
import '../features/kana/kana_session_screen.dart';
import '../features/kana/rule_card_screen.dart';
import '../features/learn/drills_entry_screen.dart';
import '../features/learn/learn_home_screen.dart';
import '../features/learn/lesson_detail_screen.dart';
import '../features/listening/dialogues_screen.dart';
import '../features/listening/listen_home_screen.dart';
import '../features/listening/sounds_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/onboarding/placement_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/plan/about_level_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/session/cards/cards_screen.dart';
import '../features/session/dialogue/dialogue_screen.dart';
import '../features/session/drill/checkpoint_screen.dart';
import '../features/session/drill/drill_screen.dart';
import '../features/session/today_flow/done_screen.dart';
import '../features/session/today_flow/expectation_screen.dart';
import '../features/session/today_flow/today_flow_screen.dart';
import '../features/settings/licenses_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/voice_settings_screen.dart';
import '../features/today/today_screen.dart';
import '../features/vocab/vocab_detail_screen.dart';
import '../features/vocab/vocab_list_screen.dart';
import '../features/vocab/vocab_topics_screen.dart';
import 'routes.dart';
import 'shell/app_shell.dart';

/// 全部路由的轉場：淡入＋上移 2%，280ms，reduced motion 時無動畫（§2.2）。
CustomTransitionPage<void> paperPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, _, child) {
        final motion = AppMotion.of(context);
        if (motion.reduced) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: motion.page.curve,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

GoRoute _page(
  String path,
  Widget Function(GoRouterState state) screen, {
  List<RouteBase> routes = const [],
  GlobalKey<NavigatorState>? parentKey,
}) => GoRoute(
  path: path,
  parentNavigatorKey: parentKey,
  routes: routes,
  pageBuilder: (context, state) => paperPage(state, screen(state)),
);

bool _flag(GoRouterState state, String name) =>
    state.uri.queryParameters[name] == 'true';

String _param(GoRouterState state, String name) =>
    state.pathParameters[name] ?? '';

List<String>? _csv(GoRouterState state, String name) {
  final raw = state.uri.queryParameters[name];
  if (raw == null || raw.isEmpty) return null;
  return raw.split(',');
}

GoRouter buildRouter({
  required ValueListenable<bool> onboarded,
  String initialLocation = AppRoutes.today,
}) {
  final rootKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    refreshListenable: onboarded,
    redirect: (context, state) => _redirect(onboarded.value, state),
    routes: [
      _welcomeRoutes(rootKey),
      ..._sessionRoutes(rootKey),
      StatefulShellRoute.indexedStack(
        // 不用 builder：go_router 會包 MaterialPage，失去自訂轉場
        pageBuilder: (context, state, shell) =>
            paperPage(state, AppShell(shell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [_page(AppRoutes.today, (_) => const TodayScreen())],
          ),
          StatefulShellBranch(routes: [_learnRoutes(rootKey)]),
          StatefulShellBranch(routes: [_listenRoutes()]),
          StatefulShellBranch(routes: [_planRoutes()]),
          StatefulShellBranch(routes: [_settingsRoutes()]),
        ],
      ),
    ],
  );
}

/// 只看 `onboardingDone`，不另存旗標（§2.2）。`/` 不存在實體頁。
String? _redirect(bool onboarded, GoRouterState state) {
  final location = state.matchedLocation;
  if (location == '/') {
    return onboarded ? AppRoutes.today : AppRoutes.welcome;
  }
  final inOnboarding = location.startsWith(AppRoutes.welcome);
  if (!onboarded) return inOnboarding ? null : AppRoutes.welcome;
  return inOnboarding ? AppRoutes.today : null;
}

GoRoute _welcomeRoutes(GlobalKey<NavigatorState> rootKey) => _page(
  AppRoutes.welcome,
  (_) => const WelcomeScreen(),
  parentKey: rootKey,
  routes: [
    _page('placement', (_) => const PlacementScreen(), parentKey: rootKey),
    _page(
      ':step',
      (state) => WelcomeScreen(step: _param(state, 'step')),
      parentKey: rootKey,
    ),
  ],
);

List<RouteBase> _sessionRoutes(GlobalKey<NavigatorState> rootKey) {
  GoRoute root(String path, Widget Function(GoRouterState) screen) =>
      _page(path, screen, parentKey: rootKey);
  return [
    root(
      '/session/today',
      (state) => TodayFlowScreen(start: state.uri.queryParameters['start']),
    ),
    root(AppRoutes.sessionDone, (_) => const DoneScreen()),
    root(AppRoutes.sessionExpectation, (_) => const ExpectationScreen()),
    root(AppRoutes.sessionCards, (_) => const CardsScreen()),
    root(
      '/session/drill',
      (state) => DrillScreen(
        lesson: state.uri.queryParameters['lesson'],
        target: state.uri.queryParameters['target'],
        drills: _csv(state, 'drills'),
      ),
    ),
    root(
      '/session/checkpoint/:milestoneId',
      (state) => CheckpointScreen(milestoneId: _param(state, 'milestoneId')),
    ),
    root(
      '/session/dialogue/:dialogueId',
      (state) => DialogueScreen(dialogueId: _param(state, 'dialogueId')),
    ),
  ];
}

GoRoute _learnRoutes(GlobalKey<NavigatorState> rootKey) => _page(
  AppRoutes.learn,
  (_) => const LearnHomeScreen(),
  routes: [
    _page(
      'lesson/:lessonId',
      (state) => LessonDetailScreen(lessonId: _param(state, 'lessonId')),
    ),
    _page(
      'kana',
      (_) => const KanaChartScreen(),
      routes: [
        _page(
          'session/:lessonId',
          (state) => KanaSessionScreen(lessonId: _param(state, 'lessonId')),
          parentKey: rootKey,
        ),
        _page(
          'rule/:ruleId',
          (state) => RuleCardScreen(ruleId: _param(state, 'ruleId')),
        ),
      ],
    ),
    _vocabRoutes(),
    _grammarRoutes(),
    _page(
      'notes',
      (state) => NotesScreen(kind: state.uri.queryParameters['kind']),
    ),
    _page('drills', (_) => const DrillsEntryScreen()),
  ],
);

GoRoute _vocabRoutes() => _page(
  'vocab',
  (_) => const VocabTopicsScreen(),
  routes: [
    _page(
      'list',
      (state) => VocabListScreen(
        topic: state.uri.queryParameters['topic'],
        onlyIntroduced: _flag(state, 'only_introduced'),
        onlyStarred: _flag(state, 'only_starred'),
        srs: state.uri.queryParameters['srs'],
      ),
    ),
    _page(
      'word/:wordId',
      (state) => VocabDetailScreen(wordId: _param(state, 'wordId')),
    ),
  ],
);

GoRoute _grammarRoutes() => _page(
  'grammar',
  (state) => GrammarListScreen(query: state.uri.queryParameters['q']),
  routes: [
    _page(
      ':grammarId',
      (state) => GrammarDetailScreen(grammarId: _param(state, 'grammarId')),
    ),
  ],
);

GoRoute _listenRoutes() => _page(
  AppRoutes.listen,
  (_) => const ListenHomeScreen(),
  routes: [
    _page('sounds', (_) => const SoundsScreen()),
    _page('dialogues', (_) => const DialoguesScreen()),
  ],
);

GoRoute _planRoutes() => _page(
  AppRoutes.plan,
  (_) => const PlanScreen(),
  routes: [_page('about-level', (_) => const AboutLevelScreen())],
);

GoRoute _settingsRoutes() => _page(
  AppRoutes.settings,
  (_) => const SettingsScreen(),
  routes: [
    _page('voice', (_) => const VoiceSettingsScreen()),
    _page('licenses', (_) => const LicensesScreen()),
  ],
);
