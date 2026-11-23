import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/features/today/today_screen.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('完成頁轉場中按回到今日，等轉場結束才回到殼層（不撞 GlobalKey）', (tester) async {
    final container = await pumpApp(tester, backend: FakeBackend());
    final router = container.read(appRouterProvider);

    router.go(AppRoutes.sessionDone);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('回到今日'), findsOneWidget);

    await tester.tap(find.text('回到今日'), warnIfMissed: false);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TodayScreen), findsOneWidget);
  });
}
