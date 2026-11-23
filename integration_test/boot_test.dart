// 真實 Rust 後端的啟動冒煙測試。執行方式見 flutter-app-testing.md：
//   JLA_DATA_DIR=$(mktemp -d) xvfb-run -a flutter test integration_test/boot_test.dart \
//     -d linux --dart-define=JLA_TTS=fake
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:japanese_learn_app/bootstrap.dart';
import 'package:japanese_learn_app/core/backend/frb/frb_boot_gateway.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('全新資料庫啟動後進新手引導', (tester) async {
    final gateway = FrbBootGateway();
    Widget? root;

    await tester.runAsync(() => startApp(gateway, run: (app) => root = app));
    await tester.pumpWidget(root!);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('從五十音開始。'), findsOneWidget);
  });
}
