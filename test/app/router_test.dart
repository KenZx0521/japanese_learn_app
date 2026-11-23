import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/app/shell/app_shell.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/design/widgets/ink_nav_bar.dart';
import 'package:japanese_learn_app/features/listen/listen_home_screen.dart';
import 'package:japanese_learn_app/features/plan/plan_screen.dart';
import 'package:japanese_learn_app/features/session/today_flow/today_flow_screen.dart';
import 'package:japanese_learn_app/features/vocab/vocab_list_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../support/pump_app.dart';

/// §2.2 全部路由：路徑、是否在 shell 內。
const _shellRoutes = {
  '/today': true,
  '/learn': true,
  '/learn/lesson/le.l01': true,
  '/learn/kana': true,
  '/learn/kana/rule/ka.rule.x': true,
  '/learn/vocab': true,
  '/learn/vocab/list?topic=a&only_introduced=true&only_starred=false&srs=review':
      true,
  '/learn/vocab/word/vo.neko': true,
  '/learn/grammar?q=x': true,
  '/learn/grammar/gr.wa': true,
  '/learn/notes?kind=term': true,
  '/learn/drills': true,
  '/listen': true,
  '/listen/sounds': true,
  '/listen/dialogues': true,
  '/plan': true,
  '/plan/about-level': true,
  '/settings': true,
  '/settings/voice': true,
  '/settings/licenses': true,
};

const _rootRoutes = [
  '/session/today?start=review',
  '/session/done',
  '/session/expectation',
  '/session/cards',
  '/session/drill?lesson=le.l01&target=gr.wa&drills=a,b',
  '/session/checkpoint/ms.hira',
  '/session/dialogue/di.l01',
  '/learn/kana/session/le.k01',
];

/// 專區已移除（RULINGS O13）：S5、S6 原本的路徑不再對應任何路由。
const _removedRoutes = ['/listen/zone/drama', '/listen/zone/drama/dz.x'];

GoRouter _routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).last));

void main() {
  group('路由表（§2.2）', () {
    _shellRoutes.forEach((location, _) {
      testWidgets('$location 在 shell 內，用 CustomTransitionPage', (tester) async {
        await pumpApp(tester, location: location);

        expect(tester.takeException(), isNull);
        expect(find.byType(InkNavBar), findsOneWidget);
        final navigator = tester.widget<Navigator>(find.byType(Navigator).last);
        expect(navigator.pages.last, isA<CustomTransitionPage<void>>());
      });
    });

    for (final location in _rootRoutes) {
      testWidgets('$location 推到 root，隱藏導覽列', (tester) async {
        await pumpApp(tester, location: location);

        expect(tester.takeException(), isNull);
        expect(find.byType(InkNavBar), findsNothing);
        final navigator = tester.widget<Navigator>(
          find.byType(Navigator).first,
        );
        expect(navigator.pages.last, isA<CustomTransitionPage<void>>());
      });
    }

    for (final location in _removedRoutes) {
      testWidgets('$location 不存在，走未知路徑處理', (tester) async {
        await pumpApp(tester, location: AppRoutes.listen);
        expect(find.byType(ListenHomeScreen), findsOneWidget);
        final router = _routerOf(tester);

        router.go(location);
        await tester.pumpAndSettle();

        final matches = router.routerDelegate.currentConfiguration;
        expect(matches.isError, isTrue);
        expect(matches.error, isA<GoException>());
        expect(find.byType(ListenHomeScreen), findsNothing);
        expect(find.byType(InkNavBar), findsNothing);
      });
    }

    testWidgets('/welcome/:step 與 placement 在未完成引導時可達', (tester) async {
      await pumpApp(tester, location: '/welcome/placement', onboarded: false);
      expect(find.text('平假名畢業考'), findsOneWidget);

      _routerOf(tester).go('/welcome/o3');
      await tester.pumpAndSettle();
      expect(find.text('你學過日文嗎？'), findsOneWidget);
    });
  });

  group('redirect', () {
    testWidgets('尚未完成引導一律到 /welcome', (tester) async {
      await pumpApp(tester, location: '/today', onboarded: false);

      expect(find.text('從五十音開始。'), findsOneWidget);
      expect(find.byType(InkNavBar), findsNothing);
    });

    testWidgets('完成引導後設 true 自動進 /today', (tester) async {
      final container = await pumpApp(
        tester,
        location: '/welcome',
        onboarded: false,
      );

      container.read(onboardingDoneProvider).value = true;
      await tester.pumpAndSettle();

      expect(find.text('今日'), findsWidgets);
      expect(find.byType(InkNavBar), findsOneWidget);
    });

    testWidgets('已完成引導時 /welcome 導回 /today', (tester) async {
      await pumpApp(tester, location: '/welcome', onboarded: true);

      expect(find.byType(InkNavBar), findsOneWidget);
    });
  });

  group('路由參數', () {
    testWidgets('query 參數傳給畫面', (tester) async {
      await pumpApp(
        tester,
        location: '/learn/vocab/list?topic=food&only_introduced=true',
      );

      final screen = tester.widget<VocabListScreen>(
        find.byType(VocabListScreen),
      );
      expect(screen.topic, 'food');
      expect(screen.onlyIntroduced, isTrue);
      expect(screen.onlyStarred, isFalse);
    });

    testWidgets('start 含 : 時編碼後能還原', (tester) async {
      final encoded = AppRoutes.sessionToday(start: 'new:le.k01:0');
      await pumpApp(tester, location: encoded);

      expect(
        tester.widget<TodayFlowScreen>(find.byType(TodayFlowScreen)).start,
        'new:le.k01:0',
      );
    });
  });

  group('AppRoutes', () {
    test('空參數不輸出', () {
      expect(AppRoutes.sessionToday(), '/session/today');
      expect(AppRoutes.grammar(), '/learn/grammar');
    });

    test('drills 以逗號分隔', () {
      expect(
        AppRoutes.sessionDrill(drills: ['a', 'b']),
        '/session/drill?drills=a%2Cb',
      );
    });
  });

  group('底部導覽', () {
    testWidgets('切換分頁並保留狀態', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('計畫'));
      await tester.pumpAndSettle();

      expect(find.byType(PlanScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('寬度 ≥1024 改為左側直欄', (tester) async {
      await pumpApp(tester, width: 1024);

      final nav = tester.widget<InkNavBar>(find.byType(InkNavBar));
      expect(nav.vertical, isTrue);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('寬度 <1024 在底部', (tester) async {
      await pumpApp(tester, width: 768);

      expect(
        tester.widget<InkNavBar>(find.byType(InkNavBar)).vertical,
        isFalse,
      );
    });

    testWidgets('語意標籤為中文，圖示字不唸', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);

      expect(tester.getSemantics(find.text('今').first).label, '今日');
      expect(find.bySemanticsLabel('今日'), findsWidgets);
      handle.dispose();
    });
  });

  testWidgets('320 寬、字級 2.0 倍時導覽不溢位', (tester) async {
    await pumpApp(tester, width: 320, textScale: 2);

    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion：路由轉場沒有動畫', (tester) async {
    await pumpApp(tester, disableAnimations: true);

    await tester.tap(find.text('設定'));
    await tester.pump();

    expect(find.text('設定'), findsWidgets);
    expect(find.byType(FadeTransition), findsNothing);
  });
}
